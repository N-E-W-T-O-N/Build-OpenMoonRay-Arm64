#!/usr/bin/env bash
# Render a test scene with the arm64 MoonRay build, with LIVE + PERSISTENT logs.
#
#   ./render.sh                          # box.rdla, scalar
#   ./render.sh sphere vectorized        # <scene-basename> <exec_mode>
#
# Logging lesson (cost us two blind runs):
#   * plain `> file` inside the container = stdio BLOCK buffering (~4KB) → the
#     log looks frozen mid-line for many minutes; and `docker logs` shows
#     nothing at all because stdout was redirected away.
#   * fix = `stdbuf -oL -eL` (line-buffered) + `tee` → live in `docker logs`
#     AND persisted on the mounted volume (survives container removal).
set -euo pipefail

SCENE="${1:-box}"
MODE="${2:-scalar}"
IMAGE="${IMAGE:-newton2022/moonray:ubuntu-final}"
SRC="${SRC:-/home/user/openmoonray/OpenMoonray}"
BUILD="${BUILD:-/home/user/openmoonray/build}"
NAME="moonray-render-${SCENE}-${MODE}"
LOG="render-${SCENE}-${MODE}.log"

docker rm -f "${NAME}" >/dev/null 2>&1 || true
docker run -d --name "${NAME}" --platform linux/arm64 \
    -v "${SRC}":/source -v "${BUILD}":/build \
    "${IMAGE}" bash -c "
export LD_LIBRARY_PATH=\$(find /build -name '*.so' -printf '%h\n' | sort -u | tr '\n' ':')
export RDL2_DSO_PATH=\$(find /build -name '*.so' ! -name '*proxy*' -path '*/dso/*' -printf '%h\n' | sort -u | tr '\n' ':')
cd /tmp
stdbuf -oL -eL /build/moonray/moonray/cmd/raas_cmd/moonray/moonray \
    -in /source/testdata/${SCENE}.rdla \
    -out /build/${SCENE}_${MODE}.exr \
    -threads 4 -exec_mode ${MODE} 2>&1 | stdbuf -oL tee /build/${LOG}
echo \"EXIT=\${PIPESTATUS[0]}\" | tee -a /build/${LOG}
ls -la /build/${SCENE}_${MODE}.exr 2>&1 | tee -a /build/${LOG}
"

cat <<EOF
started ${NAME}
  live:       docker logs -f ${NAME}
  persistent: tail -f ${BUILD}/${LOG}
  output:     ${BUILD}/${SCENE}_${MODE}.exr
EOF
