#!/usr/bin/env bash
# Run the RaTS scene corpus on a native arm64 device using the portable bundle.
#
#   ./rats_native.sh /path/to/moonray-cli-arm64.run /path/to/openmoonray/rats [exec_mode] [filter]
#
#   exec_mode : scalar | vectorized   (default: scalar)
#   filter    : substring of the test path, e.g. "camera" or "geometry/curves"
#
# Examples
#   ./rats_native.sh ./moonray-cli-arm64.run ~/openmoonray/rats
#   ./rats_native.sh ./moonray-cli-arm64.run ~/openmoonray/rats vectorized camera
#
# WHAT THIS DOES (and doesn't)
#   ✔ renders every RaTS scene and reports crash / error / success per scene  ("render" tests)
#   ✔ records render time per scene, so you get real native performance data
#   ✔ optional pixel comparison IF you have canonical reference images
#   ✘ does NOT do golden comparison by default: RaTS canonicals are NOT in the
#     openmoonray repo (diff.cmake requires $RATS_CANONICAL_DIR, distributed
#     separately by DreamWorks). Without them only crash/error detection is possible.
#
#   To enable comparison, set both:
#       RATS_CANONICAL_DIR=/path/to/canonicals   # layout: <test_rel_path>/<mode>/<image>.exr
#       IDIFF=/path/to/idiff                     # from OpenImageIO (apt install openimageio-tools)
set -uo pipefail

RUN_FILE="${1:?usage: $0 <moonray-cli-arm64.run> <rats-dir> [scalar|vectorized] [filter]}"
RATS_DIR="${2:?need the rats/ directory from the openmoonray repo}"
MODE="${3:-scalar}"
FILTER="${4:-}"
OUT_DIR="${OUT_DIR:-$PWD/rats-results-$MODE}"
THREADS="${THREADS:-$(nproc)}"
SIZE="${SIZE:-}"          # e.g. SIZE="128 128" to shrink every render
TIMEOUT="${TIMEOUT:-900}"

[ -d "$RATS_DIR/tests" ] || { echo "ERROR: $RATS_DIR/tests not found (wrong rats dir?)" >&2; exit 1; }

# MANDATORY: every RaTS scene starts with
#     rats_assets_dir = os.getenv("RATS_ASSETS_DIR")
# and then concatenates it (rats_assets_dir.."/textures/foo.tx"). Without this
# env var os.getenv returns nil, the concat is a Lua error, and EVERY scene dies
# at parse time in ~1s with rc=1. The CMake harness sets it via
# RatsTest.cmake:156; a standalone runner must do the same.
export RATS_ASSETS_DIR="${RATS_ASSETS_DIR:-$(cd "$RATS_DIR/assets" && pwd)}"
[ -d "$RATS_ASSETS_DIR" ] || { echo "ERROR: assets dir not found: $RATS_ASSETS_DIR" >&2; exit 1; }

# --- unpack the bundle once, then use its moonray directly -------------------
BUNDLE_DIR=$(MOONRAY_DIR="${MOONRAY_DIR:-$PWD/moonray-arm64}" "$RUN_FILE" --extract-only)
MOONRAY="$BUNDLE_DIR/moonray"
[ -x "$MOONRAY" ] || { echo "ERROR: $MOONRAY not executable" >&2; exit 1; }
echo ">> renderer : $MOONRAY"
echo ">> mode     : $MODE   threads: $THREADS   ${SIZE:+size: $SIZE}"
echo ">> results  : $OUT_DIR"
echo ">> assets   : $RATS_ASSETS_DIR"
[ -n "${RATS_CANONICAL_DIR:-}" ] && echo ">> canonicals: $RATS_CANONICAL_DIR (comparison ENABLED)" \
                                 || echo ">> canonicals: none — crash/error detection only"

mkdir -p "$OUT_DIR"
CSV="$OUT_DIR/results.csv"
echo "test,status,seconds,notes" > "$CSV"

pass=0; fail=0; crash=0; diffbad=0; n=0

# RaTS scenes are .rdla files under rats/tests/**
while IFS= read -r scene; do
    rel="${scene#"$RATS_DIR"/tests/}"; rel="${rel%/*}"        # e.g. moonray/camera/perspective
    [ -n "$FILTER" ] && case "$rel" in *"$FILTER"*) ;; *) continue ;; esac
    n=$((n+1))
    work="$OUT_DIR/$rel/$MODE"; mkdir -p "$work"
    img="$work/$(basename "${scene%.rdla}").exr"
    log="$work/render.log"

    start=$(date +%s)
    # shellcheck disable=SC2086
    timeout "$TIMEOUT" "$MOONRAY" -in "$scene" -out "$img" \
        -exec_mode "$MODE" -threads "$THREADS" ${SIZE:+-size $SIZE} >"$log" 2>&1
    rc=$?
    secs=$(( $(date +%s) - start ))

    if [ $rc -ne 0 ] || ! [ -s "$img" ]; then
        if grep -qE 'SIGSEGV|SIGABRT|callstack|Aborted' "$log"; then
            printf '  CRASH   %-58s %4ds\n' "$rel" "$secs"
            echo "$rel,CRASH,$secs,$(grep -m1 -oE 'SIG[A-Z]+' "$log" | head -1)" >> "$CSV"
            crash=$((crash+1))
        else
            printf '  FAIL    %-58s %4ds  rc=%s\n' "$rel" "$secs" "$rc"
            echo "$rel,FAIL,$secs,rc=$rc" >> "$CSV"
            fail=$((fail+1))
        fi
        continue
    fi

    # optional golden comparison
    if [ -n "${RATS_CANONICAL_DIR:-}" ] && [ -n "${IDIFF:-}" ]; then
        canon="$RATS_CANONICAL_DIR/$rel/$MODE/$(basename "$img")"
        if [ -f "$canon" ]; then
            if "$IDIFF" -a -abs "$img" "$canon" >"$work/idiff.log" 2>&1; then
                printf '  PASS    %-58s %4ds  (matches canonical)\n' "$rel" "$secs"
                echo "$rel,PASS,$secs,diff-ok" >> "$CSV"; pass=$((pass+1))
            else
                printf '  DIFF    %-58s %4ds  pixels differ\n' "$rel" "$secs"
                echo "$rel,DIFF,$secs,see idiff.log" >> "$CSV"; diffbad=$((diffbad+1))
            fi
            continue
        fi
    fi
    printf '  RENDER  %-58s %4ds  %s bytes\n' "$rel" "$secs" "$(stat -c%s "$img")"
    echo "$rel,RENDER_OK,$secs," >> "$CSV"; pass=$((pass+1))
done < <(find "$RATS_DIR/tests" -name '*.rdla' | sort)

echo
echo "===== SUMMARY ($MODE) ====="
printf '  scenes:%d  ok:%d  crash:%d  fail:%d  pixel-diff:%d\n' "$n" "$pass" "$crash" "$fail" "$diffbad"
echo "  per-test CSV: $CSV"
[ $((crash+fail+diffbad)) -eq 0 ] && echo "  ALL GOOD" || echo "  see logs under $OUT_DIR"
exit $(( crash + fail + diffbad > 0 ? 1 : 0 ))
