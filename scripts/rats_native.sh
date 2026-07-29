#!/usr/bin/env bash
# Run the RaTS scene corpus on a native arm64 device using the portable bundle.
#
#   ./rats_native.sh /path/to/moonray-cli-arm64.run /path/to/openmoonray/rats [exec_mode] [filter]
#
#   exec_mode : scalar | vectorized   (default: scalar)
#   filter    : substring of the test path, e.g. "camera" or "geometry/curves"
#
# Examples
#   ./rats_native.sh ./moonray-cli-arm64.run ~/omr/source/rats
#   SIZE="256 256" ./rats_native.sh ./moonray-cli-arm64.run ~/omr/source/rats vectorized camera
#
# Env knobs: SIZE ("256 256") · THREADS · TIMEOUT · OUT_DIR · MOONRAY_DIR
#            RATS_ASSETS_DIR (auto) · RATS_CANONICAL_DIR + IDIFF (enables pixel diff)
#
# WHAT THIS DOES (and doesn't)
#   ✔ runs each declared RaTS test and reports crash / error / success
#   ✔ records render seconds per test → CSV, i.e. real native performance data
#   ✔ optional pixel comparison IF you have canonical reference images
#   ✘ no golden comparison by default: RaTS canonicals are NOT in the openmoonray
#     repo (diff.cmake requires $RATS_CANONICAL_DIR, shipped separately by
#     DreamWorks). Without them only crash/error detection is possible.
set -uo pipefail

RUN_FILE="${1:?usage: $0 <moonray-cli-arm64.run> <rats-dir> [scalar|vectorized] [filter]}"
RATS_DIR="${2:?need the rats/ directory from the openmoonray repo}"
MODE="${3:-scalar}"
FILTER="${4:-}"
OUT_DIR="${OUT_DIR:-$PWD/rats-results-$MODE}"
THREADS="${THREADS:-$(nproc)}"
SIZE="${SIZE:-}"
TIMEOUT="${TIMEOUT:-900}"

[ -d "$RATS_DIR/tests" ] || { echo "ERROR: $RATS_DIR/tests not found (wrong rats dir?)" >&2; exit 1; }
RATS_DIR=$(cd "$RATS_DIR" && pwd)

# MANDATORY: every RaTS scene starts with
#     rats_assets_dir = os.getenv("RATS_ASSETS_DIR")
# and then concatenates it (rats_assets_dir.."/textures/foo.tx"). Without this
# env var os.getenv returns nil, the concat is a Lua error, and EVERY scene dies
# at parse time in ~1s with rc=1. RatsTest.cmake:156 sets it; a standalone
# runner must do the same.
export RATS_ASSETS_DIR="${RATS_ASSETS_DIR:-$RATS_DIR/assets}"
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

# Read a test's declaration out of its CMakeLists.txt. RaTS tests are declared,
# not inferred: `add_rats_test(INPUTS a.rdla DELTAS b.rdla CANONICALS ...)`.
# Globbing *.rdla instead treats fragments like common.rdla / deltas.rdla as
# standalone scenes (22 of them in the corpus) and reports false failures.
read_spec() {   # $1 = test dir  →  "INPUTS=a.rdla,b.rdla DELTAS=c.rdla"
    sed 's/#.*//' "$1/CMakeLists.txt" 2>/dev/null | tr '\n' ' ' | awk '
    {
        n = split($0, t, /[ \t]+/); key = ""; ins = ""; dls = ""; inb = 0
        for (i = 1; i <= n; i++) {
            tok = t[i]
            if (!inb) { if (tok ~ /add_rats_test/) inb = 1; continue }
            closing = (tok ~ /\)/)
            gsub(/[()]/, "", tok)
            if (tok != "") {
                if (tok == "INPUTS" || tok == "DELTAS" || tok == "CANONICALS" ||
                    tok == "ENVIRONMENT" || tok == "LABELS" || tok == "TIMEOUT" ||
                    tok == "EXEC_MODES" || tok == "ARGS" || tok == "DISABLED") {
                    key = tok
                } else if (key == "INPUTS") { ins = ins tok "," }
                else if (key == "DELTAS")   { dls = dls tok "," }
            }
            if (closing) break
        }
        if (inb) printf "INPUTS=%s DELTAS=%s\n", ins, dls
    }'
}

pass=0; fail=0; crash=0; diffbad=0; skip=0; n=0

# Iterate over DECLARED tests (dirs whose CMakeLists.txt calls add_rats_test)
while IFS= read -r cml; do
    dir=$(dirname "$cml")
    rel=${dir#"$RATS_DIR"/tests/}
    [ -n "$FILTER" ] && case "$rel" in *"$FILTER"*) ;; *) continue ;; esac

    spec=$(read_spec "$dir"); [ -n "$spec" ] || continue
    inputs=$(printf '%s' "$spec" | sed 's/.*INPUTS=//; s/ DELTAS=.*//' | tr ',' ' ')
    deltas=$(printf '%s' "$spec" | sed 's/.*DELTAS=//'               | tr ',' ' ')
    [ -n "${inputs// /}" ] || continue

    n=$((n+1))
    work="$OUT_DIR/$rel/$MODE"; mkdir -p "$work"
    img="$work/result.exr"; log="$work/render.log"

    # build the arg list the way RatsTest.cmake does
    args=(); for f in $inputs; do args+=(-in "$dir/$f"); done
             for f in $deltas; do args+=(-deltas "$dir/$f"); done
    args+=(-out "$img" -exec_mode "$MODE" -threads "$THREADS")
    # shellcheck disable=SC2206
    [ -n "$SIZE" ] && args+=(-size ${SIZE})

    start=$(date +%s)
    ( cd "$work" && timeout "$TIMEOUT" "$MOONRAY" "${args[@]}" ) >"$log" 2>&1
    rc=$?
    secs=$(( $(date +%s) - start ))

    if [ $rc -ne 0 ] || ! [ -s "$img" ]; then
        if grep -qE 'SIGSEGV|SIGABRT|SIGILL|callstack|Aborted|Illegal instruction' "$log"; then
            sig=$(grep -m1 -oE 'SIG[A-Z]+|Illegal instruction' "$log" | head -1)
            printf '  CRASH   %-56s %5ds  %s\n' "$rel" "$secs" "$sig"
            echo "$rel,CRASH,$secs,$sig" >> "$CSV"; crash=$((crash+1))
        elif [ $rc -eq 124 ]; then
            printf '  TIMEOUT %-56s %5ds  (>%ss — try SIZE="128 128")\n' "$rel" "$secs" "$TIMEOUT"
            echo "$rel,TIMEOUT,$secs,limit=$TIMEOUT" >> "$CSV"; fail=$((fail+1))
        else
            printf '  FAIL    %-56s %5ds  rc=%s  %s\n' "$rel" "$secs" "$rc" \
                   "$(grep -m1 -iE 'error|cannot|unable|nil value' "$log" | cut -c1-60)"
            echo "$rel,FAIL,$secs,rc=$rc" >> "$CSV"; fail=$((fail+1))
        fi
        continue
    fi

    if [ -n "${RATS_CANONICAL_DIR:-}" ] && [ -n "${IDIFF:-}" ]; then
        canon="$RATS_CANONICAL_DIR/$rel/$MODE/$(basename "$img")"
        if [ -f "$canon" ]; then
            if "$IDIFF" -a -abs "$img" "$canon" >"$work/idiff.log" 2>&1; then
                printf '  PASS    %-56s %5ds  (matches canonical)\n' "$rel" "$secs"
                echo "$rel,PASS,$secs,diff-ok" >> "$CSV"; pass=$((pass+1))
            else
                printf '  DIFF    %-56s %5ds  pixels differ\n' "$rel" "$secs"
                echo "$rel,DIFF,$secs,see idiff.log" >> "$CSV"; diffbad=$((diffbad+1))
            fi
            continue
        fi
        skip=$((skip+1))
    fi
    printf '  RENDER  %-56s %5ds  %s bytes\n' "$rel" "$secs" "$(stat -c%s "$img")"
    echo "$rel,RENDER_OK,$secs," >> "$CSV"; pass=$((pass+1))
done < <(grep -rl 'add_rats_test' "$RATS_DIR/tests" --include=CMakeLists.txt | sort)

echo
echo "===== SUMMARY ($MODE) ====="
printf '  tests:%d  ok:%d  crash:%d  fail/timeout:%d  pixel-diff:%d\n' \
       "$n" "$pass" "$crash" "$fail" "$diffbad"
[ "$skip" -gt 0 ] && printf '  (%d had no canonical to compare against)\n' "$skip"
echo "  per-test CSV: $CSV"
[ $((crash+fail+diffbad)) -eq 0 ] && echo "  ALL GOOD" || echo "  see logs under $OUT_DIR"
exit $(( crash + fail + diffbad > 0 ? 1 : 0 ))
