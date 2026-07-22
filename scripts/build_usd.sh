#!/usr/bin/env bash
# Build OpenUSD locally (too slow for CI image builds).
# Run INSIDE the deps-heavy container, which already has the prerequisites
# (oneTBB + OpenSubdiv in ${INSTALL_ROOT}, boost/python/mesa from apt).
#
# RESUMABLE: point WORK at a persistent mount so a multi-hour build survives
# a container restart. The USD checkout is kept and the cmake build is
# incremental, so re-running this script continues where it left off.
#
#   docker run -it \
#       -v moonray-installs:/opt/MoonRay/installs \   # named vol: keeps the install (seeded from image)
#       -v /home/user/moonray-work:/work \            # WSL ext4: keeps USD src + build tree
#       -v /home/user/Build-OpenMoonRay-Arm64/scripts:/scripts \
#       newton2022/moonray:deps-heavy-ubuntu26.04 bash
#   WORK=/work /scripts/build_usd.sh                  # re-run after a crash to resume
#
# WARNING (WSL): use a native ext4 path (/home/...) for WORK, NOT /mnt/c or
# /mnt/d — drvfs is very slow and mishandles symlinks/case, and USD will crawl.
#
# Afterwards run build_light_deps.sh + pack_and_upload_deps.sh in a container
# with the SAME moonray-installs volume to publish the full dep tree to HF.
set -euo pipefail

INSTALL_ROOT="${INSTALL_ROOT:-/opt/MoonRay/installs}"
JOBS="${JOBS:-$(nproc)}"
USD_VERSION="${USD_VERSION:-v26.03}"
WORK="${WORK:-/work}"    # override with a persistent mount to resume
CLEAN="${CLEAN:-0}"               # set to 1 to delete WORK after a successful install

# Preflight: the build tools must resolve to real executables. If cmake is
# missing/shadowed the configure line's arg becomes argv[0] and bash reports
# a confusing "<path>: Is a directory" — check up front instead.
for tool in cmake git; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "ERROR: '${tool}' not found in PATH (${PATH}). Are you inside the" >&2
        echo "deps-heavy image? Try: apt-get update && apt-get install -y ${tool}" >&2
        exit 1
    fi
done
echo "cmake: $(command -v cmake) ($(cmake --version | head -1))"

# USD imaging hard-requires OpenSubdiv — fail early with a clear message
if [ ! -d "${INSTALL_ROOT}/include/opensubdiv" ]; then
    echo "ERROR: OpenSubdiv not found in ${INSTALL_ROOT} — run inside the" >&2
    echo "deps-heavy image (it is baked in), or build OpenSubdiv first." >&2
    exit 1
fi

mkdir -p "${WORK}"
if [ -d "${WORK}/USD/.git" ]; then
    echo "Resuming: reusing existing USD checkout at ${WORK}/USD"
else
    git clone --depth=1 -b "${USD_VERSION}" https://github.com/PixarAnimationStudios/OpenUSD "${WORK}/USD"
fi
cmake -S "${WORK}/USD" -B "${WORK}/USD/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_ROOT}" \
    -DCMAKE_PREFIX_PATH="${INSTALL_ROOT}" \
    -DPXR_BUILD_MONOLITHIC=ON \
    -DPXR_ENABLE_PYTHON_SUPPORT=ON \
    -DPython3_EXECUTABLE=/usr/bin/python3 \
    -DTBB_DIR="${INSTALL_ROOT}/lib/cmake/TBB" \
    -DPXR_BUILD_TESTS=OFF \
    -DPXR_BUILD_EXAMPLES=OFF \
    -DPXR_BUILD_TUTORIALS=OFF \
    -DPXR_BUILD_USD_TOOLS=ON \
    -DPXR_ENABLE_PTEX_SUPPORT=OFF \
    -DPXR_ENABLE_OPENVDB_SUPPORT=OFF \
    -DPXR_BUILD_USDVIEW=OFF \
    -DPXR_ENABLE_GL_SUPPORT=ON \
    -DPXR_BUILD_IMAGING=ON \
    -DPXR_BUILD_USD_IMAGING=ON \
    -DPXR_BUILD_DOCUMENTATION=OFF \
    -DTBB_SUPPRESS_DEPRECATED_MESSAGES=1
cmake --build "${WORK}/USD/build" -j"${JOBS}"   # incremental — resumes after a crash
cmake --install "${WORK}/USD/build"
[ "${CLEAN}" = "1" ] && rm -rf "${WORK}"

echo "OpenUSD ${USD_VERSION} installed to ${INSTALL_ROOT}"
ls "${INSTALL_ROOT}/lib" | grep -i usd || true
