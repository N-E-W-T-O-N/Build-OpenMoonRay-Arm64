#!/usr/bin/env bash
# Build OpenUSD locally (too slow for CI image builds).
# Run INSIDE the deps-heavy container, which already has the prerequisites
# (oneTBB + OpenSubdiv in ${INSTALL_ROOT}, boost/python/mesa from apt):
#
#   docker run -it --rm -v moonray-installs:/opt/MoonRay \
#       newton2022/moonray:deps-heavy-ubuntu26.04 bash
#   # first time: seed the volume from the image if empty (see README)
#   /source/scripts/build_usd.sh
#
# Afterwards run build_light_deps.sh + pack_and_upload_deps.sh in the same
# container to publish the complete dependency tree to Hugging Face.
set -euo pipefail

INSTALL_ROOT="${INSTALL_ROOT:-/opt/MoonRay/installs}"
JOBS="${JOBS:-$(nproc)}"
USD_VERSION="${USD_VERSION:-v26.03}"
WORK="${WORK:-/tmp/usd-build}"

# USD imaging hard-requires OpenSubdiv — fail early with a clear message
if [ ! -d "${INSTALL_ROOT}/include/opensubdiv" ]; then
    echo "ERROR: OpenSubdiv not found in ${INSTALL_ROOT} — run inside the" >&2
    echo "deps-heavy image (it is baked in), or build OpenSubdiv first." >&2
    exit 1
fi

rm -rf "${WORK}" && mkdir -p "${WORK}"
git clone --depth=1 -b "${USD_VERSION}" https://github.com/PixarAnimationStudios/OpenUSD "${WORK}/USD"
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
cmake --build "${WORK}/USD/build" -j"${JOBS}"
cmake --install "${WORK}/USD/build"
rm -rf "${WORK}"

echo "OpenUSD ${USD_VERSION} installed to ${INSTALL_ROOT}"
ls "${INSTALL_ROOT}/lib" | grep -i usd || true
