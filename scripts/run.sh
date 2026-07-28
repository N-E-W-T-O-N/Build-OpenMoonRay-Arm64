#!/usr/bin/env bash
# Enter the MoonRay arm64 build container — or run a one-shot command in it.
#
#   ./run.sh                       # interactive shell (bash)
#   ./run.sh bash -c '<command>'   # one-shot
#
# Common commands inside the container:
#   cmake --preset ubuntu-arm64-release -B /build /source   # configure
#   /scripts/check_arch_flags.sh /build                     # verify no x86 flags leaked
#   cmake --build /build -j$(nproc)                         # build (SLOW under qemu;
#                                                           #  prefer CI / native arm device)
#
# IMPORTANT: use THIS script (plain docker run), never `docker debug` — docker
# debug injects x86 /nix tools that shadow the container's aarch64 toolchain.
# Symptom of that mistake:  ld: unrecognised emulation mode: aarch64linux
set -euo pipefail

IMAGE="${IMAGE:-newton2022/moonray:ubuntu-final}"
SRC="${SRC:-/home/user/openmoonray/OpenMoonray}"      # patched source -> /source
BUILD="${BUILD:-/home/user/openmoonray/build}"        # build tree     -> /build
SCRIPTS="${SCRIPTS:-/home/user/Build-OpenMoonRay-Arm64/scripts}"  #    -> /scripts

mkdir -p "${BUILD}"

# One-time: register arm64 emulation (qemu binfmt). No-op if already present;
# needed again after any Docker/WSL restart (binfmt does not persist).
echo ">> checking arm64 emulation..."
if ! docker run --rm --platform linux/arm64 "${IMAGE}" true >/dev/null 2>&1; then
    echo ">> registering arm64 binfmt (qemu)..."
    docker run --privileged --rm tonistiigi/binfmt --install arm64 >/dev/null
fi

# -t only when we actually have a terminal (lets run.sh work in scripts/CI too)
TTY_FLAGS="-i"; [ -t 0 ] && TTY_FLAGS="-it"
echo ">> starting ${IMAGE}  (src=${SRC} build=${BUILD})"
exec docker run ${TTY_FLAGS} --rm --platform linux/arm64 \
    -v "${SRC}":/source \
    -v "${BUILD}":/build \
    -v "${SCRIPTS}":/scripts \
    "${IMAGE}" "${@:-bash}"
