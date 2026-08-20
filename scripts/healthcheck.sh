#!/usr/bin/env bash
# MoonRay arm64 — pre-flight health check.
#
#   ./scripts/healthcheck.sh                       # auto-find an extracted bundle nearby
#   ./scripts/healthcheck.sh /path/to/moonray-arm64
#   ./scripts/healthcheck.sh /path/to/moonray-cli-arm64.run     # extracts if needed
#   ./scripts/healthcheck.sh --render              # also do a real 64x64 test render
#
# Answers one question: will MoonRay actually run here, and if not, why.
# Checks CPU/ISA (the SIGILL traps), kernel, memory, bundle integrity, the
# dlopen-invisible plugin families, GPU/OpenGL version vs what each GUI needs,
# and display availability.
#
# Exit 0 = no FAILs.  Exit 1 = at least one FAIL.
set -uo pipefail

if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
    R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[1m'; D=$'\e[2m'; N=$'\e[0m'
else R=""; G=""; Y=""; B=""; D=""; N=""; fi

nPASS=0; nWARN=0; nFAIL=0
pass() { printf '  %sPASS%s  %-30s %s\n' "$G" "$N" "$1" "${2-}"; nPASS=$((nPASS+1)); }
warn() { printf '  %sWARN%s  %-30s %s\n' "$Y" "$N" "$1" "${2-}"; nWARN=$((nWARN+1)); }
fail() { printf '  %sFAIL%s  %-30s %s\n' "$R" "$N" "$1" "${2-}"; nFAIL=$((nFAIL+1)); }
info() { printf '  %s····%s  %-30s %s\n' "$D" "$N" "$1" "${2-}"; }
head_() { printf '\n%s%s%s\n' "$B" "$1" "$N"; }

DO_RENDER=0; TARGET=""
for a in "$@"; do
    case "$a" in
        --render) DO_RENDER=1 ;;
        -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) TARGET="$a" ;;
    esac
done

printf '%s=== MoonRay arm64 health check ===%s  %s\n' "$B" "$N" "$(date '+%Y-%m-%d %H:%M')"

# ─────────────────────────────────────────────────────────── CPU / instruction set
head_ "CPU / instruction set"
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    pass "architecture" "$ARCH"
else
    fail "architecture" "$ARCH — these binaries are aarch64 only (would be 'Exec format error')"
fi

CPUFEAT=$(grep -m1 '^Features' /proc/cpuinfo 2>/dev/null | cut -d: -f2-)
CPUMODEL=$(grep -m1 -E '^(model name|Model)' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//')
[ -n "$CPUMODEL" ] && info "model" "$CPUMODEL"

has_feat() { printf '%s' " $CPUFEAT " | grep -q " $1 "; }
if [ -n "$CPUFEAT" ]; then
    has_feat asimd   && pass "NEON (asimd)"        "required for all SIMD paths" \
                     || fail "NEON (asimd)"        "missing — vectorized mode cannot work"
    # This build uses -march=armv8.2-a and ARMv8.1 LSE 'casp' 128-bit atomics.
    # On an ARMv8.0 core (e.g. RK3399 A72/A53) those are ILLEGAL INSTRUCTIONS.
    has_feat atomics && pass "LSE atomics (ARMv8.1+)" "casp is safe here" \
                     || fail "LSE atomics (ARMv8.1+)" "MISSING — 'casp' will SIGILL; this build needs ARMv8.1+ (A76/A55 ok, A72/A53 not)"
    if has_feat asimdhp || has_feat fphp; then
        pass "fp16 (asimdhp/fphp)" "half-float conversions native"
    else
        warn "fp16 (asimdhp/fphp)" "not advertised — fp16 paths may be emulated"
    fi
else
    warn "cpu features" "/proc/cpuinfo has no Features line — cannot verify ISA"
fi

CORES=$(nproc 2>/dev/null || echo 0)
if   [ "$CORES" -ge 8 ]; then pass "cores" "$CORES (grid_util unit test needs >=8)"
elif [ "$CORES" -ge 4 ]; then warn "cores" "$CORES — renders fine; grid_util unit test will fail (needs >=8)"
else                          warn "cores" "$CORES — renders will be slow"; fi

# ─────────────────────────────────────────────────────────── kernel / memory
head_ "Kernel & memory"
info "kernel"    "$(uname -r)"
info "page size" "$(getconf PAGESIZE 2>/dev/null) bytes"
[ -r /etc/os-release ] && info "distro" "$(. /etc/os-release && echo "$PRETTY_NAME")"

MEMKB=$(awk '/^MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo 0)
MEMGB=$(( MEMKB / 1048576 ))
if   [ "$MEMGB" -ge 8 ]; then pass "RAM" "${MEMGB} GiB"
elif [ "$MEMGB" -ge 4 ]; then warn "RAM" "${MEMGB} GiB — big scenes may swap/OOM; use -size to shrink"
else                          fail "RAM" "${MEMGB} GiB — too little for most scenes"; fi

if [ -d /sys/devices/system/node/node1 ]; then
    info "NUMA" "multi-node — mbind() used for page placement"
else
    info "NUMA" "single node (normal on SBCs)"
fi

# ─────────────────────────────────────────────────────────── locate the bundle
head_ "Bundle"
BUNDLE=""
if [ -n "$TARGET" ]; then
    case "$TARGET" in
        *.run) if [ -x "$TARGET" ]; then BUNDLE=$("$TARGET" --extract-only 2>/dev/null); fi ;;
        *)     BUNDLE="$TARGET" ;;
    esac
else
    for c in ./moonray-arm64 ./moonray-gui-arm64 ../moonray-arm64 ../moonray-gui-arm64 \
             "$HOME/moonray-arm64" "$HOME/Desktop/moonray-arm64"; do
        [ -x "$c/moonray" ] && { BUNDLE=$c; break; }
    done
fi

if [ -z "$BUNDLE" ] || [ ! -d "$BUNDLE" ]; then
    warn "bundle" "not found — pass a path, or run from where you extracted it"
    warn "bundle" "skipping library/plugin/scene checks"
    BUNDLE=""
else
    BUNDLE=$(cd "$BUNDLE" && pwd)
    pass "bundle" "$BUNDLE"

    LOADER="$BUNDLE/lib/ld-linux-aarch64.so.1"
    [ -x "$LOADER" ] && pass "bundled loader" "host glibc is irrelevant" \
                     || fail "bundled loader" "lib/ld-linux-aarch64.so.1 missing — bundle is incomplete"

    NLIB=$(ls "$BUNDLE/lib" 2>/dev/null | grep -c '\.so' || echo 0)
    [ "$NLIB" -ge 100 ] && pass "libraries" "$NLIB in lib/" \
                        || fail "libraries" "only $NLIB — expected 100+"

    NDSO=$(ls "$BUNDLE/dso"/*.so 2>/dev/null | wc -l)
    [ "$NDSO" -ge 170 ] && pass "RDL2 DSO plugins" "$NDSO (shaders/lights/geometry)" \
                        || fail "RDL2 DSO plugins" "$NDSO — expected ~176; shaders will fail to load"

    NSCN=$(ls "$BUNDLE/scenes"/*.rdla 2>/dev/null | wc -l)
    [ "$NSCN" -gt 0 ] && pass "sample scenes" "$NSCN in scenes/" \
                      || warn "sample scenes" "none — get the v1.3+ bundle, or supply your own .rdla"

    # Resolve every executable through the BUNDLED loader: catches a truncated
    # or mis-staged bundle before you hit it mid-render.
    for exe in moonray moonray_gui moonray_gui_v2; do
        [ -f "$BUNDLE/bin/$exe" ] || continue
        if [ -x "$LOADER" ]; then
            MISS=$("$LOADER" --library-path "$BUNDLE/lib" --list "$BUNDLE/bin/$exe" 2>&1 | grep -c 'not found' || true)
            [ "${MISS:-0}" -eq 0 ] && pass "link: $exe" "all libraries resolve" \
                                  || fail "link: $exe" "$MISS library(ies) NOT FOUND"
        fi
    done

    # dlopen-invisible families — ldd never shows these, and their absence is a
    # startup failure rather than a link error.
    if [ -d "$BUNDLE/qt-plugins/platforms" ]; then
        NQT=$(ls "$BUNDLE/qt-plugins/platforms"/*.so 2>/dev/null | wc -l)
        [ "$NQT" -ge 1 ] && pass "Qt platform plugins" "$NQT (dlopen'd; incl. libqxcb.so)" \
                         || fail "Qt platform plugins" "none — Qt GUI aborts at startup"
    fi
    if [ -d "$BUNDLE/lib/dri" ]; then
        NDRI=$(ls "$BUNDLE/lib/dri"/*.so 2>/dev/null | wc -l)
        [ "$NDRI" -ge 1 ] && pass "Mesa DRI (software GL)" "$NDRI driver(s) bundled" \
                          || fail "Mesa DRI (software GL)" "none — GL context creation fails"
    fi
fi

# ─────────────────────────────────────────────────────────── GPU / OpenGL
head_ "GPU / OpenGL  (display only — path tracing is CPU)"
if [ -d /dev/dri ]; then
    pass "DRM devices" "$(ls /dev/dri | tr '\n' ' ')"
else
    warn "DRM devices" "no /dev/dri — software GL only (fine for headless rendering)"
fi
DRV=$(grep -ohE 'panthor|panfrost|mali|lima|v3d|amdgpu|i915|nouveau|nvidia' /proc/modules 2>/dev/null | sort -u | tr '\n' ' ')
[ -n "$DRV" ] && info "GPU kernel driver" "$DRV"

if command -v glxinfo >/dev/null 2>&1 && { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }; then
    GLREND=$(glxinfo -B 2>/dev/null | grep -m1 -i 'OpenGL renderer' | cut -d: -f2- | sed 's/^ *//')
    GLCORE=$(glxinfo -B 2>/dev/null | grep -m1 -i 'Max core profile version' | grep -oE '[0-9]+\.[0-9]+')
    [ -n "$GLREND" ] && info "renderer" "$GLREND"
    if [ -n "$GLCORE" ]; then
        GLMAJ=${GLCORE%%.*}; GLMIN=${GLCORE##*.}
        GLNUM=$(( GLMAJ * 10 + GLMIN ))
        info "max GL core profile" "$GLCORE"
        # moonray_gui compiles '#version 330 core' -> needs GL 3.3
        [ "$GLNUM" -ge 33 ] && pass "moonray_gui (Qt) on GPU"  "GL >= 3.3 — hardware GL usable" \
                            || warn "moonray_gui (Qt) on GPU"  "needs GL 3.3, GPU gives $GLCORE — use bundled SOFTWARE GL (the default)"
        # moonray_gui_v2 uses '#version 130' on Linux -> needs GL 3.0
        [ "$GLNUM" -ge 30 ] && pass "moonray_gui_v2 on GPU"    "GL >= 3.0 — LIBGL_ALWAYS_SOFTWARE=0 LIBGL_DRIVERS_PATH= works" \
                            || warn "moonray_gui_v2 on GPU"    "needs GL 3.0, GPU gives $GLCORE — software GL only"
    fi
else
    command -v glxinfo >/dev/null 2>&1 \
        || info "glxinfo" "not installed (apt install mesa-utils) — cannot read GL version"
fi

# ─────────────────────────────────────────────────────────── display
head_ "Display (GUI only)"
if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    pass "display" "DISPLAY=${DISPLAY:-<unset>} WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-<unset>}"
    [ -n "${DISPLAY:-}" ] && { [ -S "/tmp/.X11-unix/X${DISPLAY##*:}" ] 2>/dev/null \
        && pass "X11 socket" "/tmp/.X11-unix/X${DISPLAY##*:}" \
        || warn "X11 socket" "not found for $DISPLAY — GUI may fail to connect"; }
    [ -n "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ] && \
        info "Wayland" "force X11 with QT_QPA_PLATFORM=xcb if the Qt viewer misbehaves"
    [ -n "${XDG_RUNTIME_DIR:-}" ] || info "XDG_RUNTIME_DIR" "unset — launcher creates one (harmless warnings)"
else
    warn "display" "none — GUI cannot run; headless CLI rendering is unaffected"
fi

# ─────────────────────────────────────────────────────────── optional real render
if [ "$DO_RENDER" = 1 ] && [ -n "$BUNDLE" ] && [ -x "$BUNDLE/moonray" ]; then
    head_ "Smoke render (--render)"
    SCENE=$(ls "$BUNDLE/scenes"/sphere.rdla "$BUNDLE/scenes"/*.rdla 2>/dev/null | head -1)
    if [ -z "$SCENE" ]; then
        warn "smoke render" "no scene available to render"
    else
        OUT=$(mktemp -d)/hc.exr
        S=$(date +%s)
        if "$BUNDLE/moonray" -in "$SCENE" -out "$OUT" -size 64 64 -threads "$CORES" >"$OUT.log" 2>&1 && [ -s "$OUT" ]; then
            pass "smoke render" "$(basename "$SCENE") in $(( $(date +%s) - S ))s → $(stat -c%s "$OUT") bytes"
            grep -q 'mbind() unavailable' "$OUT.log" \
                && warn "mbind()" "unavailable — NUMA binding skipped (expected in containers/emulators, NOT on real hardware)" \
                || pass "mbind()" "no NUMA warning — kernel path healthy"
        else
            fail "smoke render" "failed — see $OUT.log"
            sed -n '1,6p' "$OUT.log" | sed 's/^/         /'
        fi
    fi
fi

# ─────────────────────────────────────────────────────────── verdict
head_ "Summary"
printf '  %spass %d%s   %swarn %d%s   %sfail %d%s\n' "$G" "$nPASS" "$N" "$Y" "$nWARN" "$N" "$R" "$nFAIL" "$N"
if [ "$nFAIL" -eq 0 ]; then
    printf '  %sREADY%s — MoonRay should run here.\n' "$G" "$N"
    [ -n "$BUNDLE" ] && printf '  %s\n' "$D try: $BUNDLE/moonray -in $BUNDLE/scenes/sphere.rdla -out out.exr -size 512 512 -info$N"
    exit 0
else
    printf '  %sNOT READY%s — fix the FAIL lines above.\n' "$R" "$N"
    exit 1
fi
