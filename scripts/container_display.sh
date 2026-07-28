#!/usr/bin/env bash
# Run the MoonRay GUI inside an arm64 container, displaying on THIS machine.
#
#   ./container_display.sh                          # Qt viewer, sphere.rdla
#   ./container_display.sh curves                    # another testdata scene
#   ./container_display.sh sphere v2                 # the GLFW/ImGui viewer
#   ./container_display.sh sphere qt 300             # run for 300s
#   BUNDLE=1 ./container_display.sh                  # test the released bundle
#                                                    # instead of the build tree
#
# ── How container↔display plumbing works ─────────────────────────────────────
#   -e DISPLAY                     which X server the app should talk to
#   -v /tmp/.X11-unix:/tmp/.X11-unix   the X server's unix socket (WSLg puts X0 here)
#   -e QT_X11_NO_MITSHM=1          MIT-SHM shared memory can't cross the container
#                                  boundary; without this Qt may crash or corrupt
#   --device /dev/dri              hardware GL (omit → software rendering)
#   -e XDG_RUNTIME_DIR             silences Qt/GLFW warnings
#
# Wayland instead of X11: pass WAYLAND_DISPLAY plus $XDG_RUNTIME_DIR/wayland-0,
# or force X11 with QT_QPA_PLATFORM=xcb (usually simplest under WSLg).
#
# Verified working 2026-07-28 under WSLg: a moonray_gui window rendered a
# path-traced sphere with software GL (this host has no /dev/dri).
set -euo pipefail

SCENE="${1:-sphere}"
WHICH="${2:-qt}"          # qt | v2
SECS="${3:-120}"
IMAGE="${IMAGE:-newton2022/moonray:ubuntu-final}"
SRC="${SRC:-/home/user/openmoonray/OpenMoonray}"
BUILD="${BUILD:-/home/user/openmoonray/build}"
BUNDLE_DIR="${BUNDLE_DIR:-/home/user/openmoonray/bundle}"

# --- sanity: is a display actually reachable? -------------------------------
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "ERROR: neither DISPLAY nor WAYLAND_DISPLAY is set — no display to use." >&2
    exit 1
fi
if [ ! -e /tmp/.X11-unix/X0 ]; then
    echo "WARNING: /tmp/.X11-unix/X0 not found; X11 forwarding will likely fail." >&2
    echo "         (On WSL, WSLg provides it. On a headless box, use xvfb.)" >&2
fi

# hardware GL only if the host exposes a GPU
GPU_ARGS=()
if [ -e /dev/dri ]; then
    GPU_ARGS=(--device /dev/dri)
    echo ">> /dev/dri present — hardware GL available"
else
    echo ">> no /dev/dri — using software OpenGL (slower, always works)"
fi

if [ "${BUNDLE:-0}" = "1" ]; then
    # test the shipped artifact
    EXE=$([ "$WHICH" = v2 ] && echo /out/moonray-gui-arm64/moonray-gui-v2 \
                            || echo /out/moonray-gui-arm64/moonray-gui)
    MOUNTS=(-v "${BUNDLE_DIR}:/out" -v "${SRC}/testdata:/scenes:ro")
    echo ">> testing RELEASED BUNDLE: $EXE"
else
    # test the build tree
    EXE=$([ "$WHICH" = v2 ] \
        && echo /build/moonray/moonray_gui/cmd/moonray_gui_v2/moonray_gui_v2 \
        || echo /build/moonray/moonray_gui/cmd/moonray_gui/moonray_gui)
    MOUNTS=(-v "${BUILD}:/build" -v "${SRC}:/source:ro" -v "${SRC}/testdata:/scenes:ro")
    echo ">> testing BUILD TREE: $EXE"
fi

echo ">> scene: ${SCENE}.rdla   timeout: ${SECS}s   DISPLAY=${DISPLAY:-<wayland>}"

exec docker run --rm --platform linux/arm64 \
    -e DISPLAY="${DISPLAY:-:0}" \
    -e QT_X11_NO_MITSHM=1 \
    -e XDG_RUNTIME_DIR=/tmp/moonray-runtime \
    -e LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    "${GPU_ARGS[@]}" "${MOUNTS[@]}" \
    "${IMAGE}" bash -c '
        mkdir -p /tmp/moonray-runtime && chmod 700 /tmp/moonray-runtime
        if [ -d /build ]; then
            export LD_LIBRARY_PATH=$(find /build -name "*.so" -printf "%h\n" | sort -u | tr "\n" ":")
            export RDL2_DSO_PATH=$(find /build -name "*.so" ! -name "*proxy*" -path "*/dso/*" -printf "%h\n" | sort -u | tr "\n" ":")
        fi
        timeout '"${SECS}"' '"${EXE}"' -in /scenes/'"${SCENE}"'.rdla 2>&1 | head -30
        echo "--- viewer exited (timeout ${0##*/} or window closed) ---"
    '
