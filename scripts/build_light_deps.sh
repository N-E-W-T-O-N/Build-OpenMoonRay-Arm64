#!/usr/bin/env bash
# Build the "light" MoonRay deps (fast builds) into ${INSTALL_ROOT}.
# Runs in CI (GitHub Actions arm64 runner) inside the deps-heavy image,
# or natively on any aarch64 Ubuntu 26.04 box with the same apt packages.
#
# Heavy deps (oneTBB, OIDN, USD) are already baked into the image by
# ubuntu.Dockerfile.
set -euo pipefail

INSTALL_ROOT="${INSTALL_ROOT:-/opt/MoonRay/installs}"
JOBS="${JOBS:-$(nproc)}"
WORK="${WORK:-/tmp/light-deps}"
mkdir -p "${INSTALL_ROOT}" "${WORK}"

EMBREE_VERSION=v4.4.1
OCIO_VERSION=v2.5.2
OIIO_VERSION=v3.1.15.0
OPENSUBDIV_VERSION=v3_7_0
GLFW_VERSION=3.4
RANDOM123_VERSION=v1.14.0
OPTIX_VERSION=v7.6.0

ARM_SCRUB_FLAGS="-D__ARM_NEON__=1 -U__SSE__ -U__SSE2__ -U__AVX__ -U__AVX2__ -U__SSE4_1__ -U__SSE4_2__ -UFARMHASH_ASSUME_SSSE3 -UFARMHASH_ASSUME_SSE41"

build() { # name git-url tag extra-cmake-args...
    local name=$1 url=$2 tag=$3; shift 3
    echo "==================== ${name} ${tag} ===================="
    git clone --depth=1 -b "${tag}" "${url}" "${WORK}/${name}"
    cmake -S "${WORK}/${name}" -B "${WORK}/${name}/build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_ROOT}" \
        -DCMAKE_PREFIX_PATH="${INSTALL_ROOT}" \
        "$@"
    cmake --build "${WORK}/${name}/build" -j"${JOBS}"
    cmake --install "${WORK}/${name}/build"
    rm -rf "${WORK:?}/${name}"
}

# ---- Embree (NEON; switch to -DEMBREE_MAX_ISA=NEON2X for double-pumped exp.) ----
build embree https://github.com/embree/embree "${EMBREE_VERSION}" \
    -DEMBREE_ISPC_SUPPORT=OFF \
    -DEMBREE_ARM=ON \
    -DEMBREE_SYCL_SUPPORT=OFF \
    -DEMBREE_IGNORE_INVALID_RAYS=ON \
    -DEMBREE_RAY_MASK=ON \
    -DEMBREE_TUTORIALS=OFF \
    -DEMBREE_TASKING_SYSTEM=TBB \
    -DBUILD_SHARED_LIBS=ON

# ---- OpenColorIO ----
build ocio https://github.com/AcademySoftwareFoundation/OpenColorIO "${OCIO_VERSION}" \
    -DOCIO_BUILD_APPS=OFF \
    -DOCIO_BUILD_TESTS=OFF \
    -DOCIO_BUILD_GPU_TESTS=OFF \
    -DOCIO_BUILD_PYTHON=OFF \
    -DOCIO_USE_SIMD=ON \
    -DOCIO_BUILD_STATIC=OFF \
    -DOCIO_WARNING_AS_ERROR=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_CXX_STANDARD=17

# ---- OpenImageIO (x86-macro scrub is mandatory: prevents farmhash/simd misdetect) ----
build oiio https://github.com/OpenImageIO/oiio "${OIIO_VERSION}" \
    -DUSE_QT=0 \
    -DOpenImageIO_BUILD_MISSING_DEPS=all \
    -DUSE_PYTHON=1 \
    -DBUILD_DOCS=OFF \
    -DOIIO_BUILD_TESTS=OFF \
    -DOIIO_NO_SSE=1 -DOIIO_NO_AVX=1 -DOIIO_NO_AVX2=1 -DOIIO_NO_AVX512=1 -DOIIO_NO_F16C=1 \
    -DSIMD_FLAGS=-march=armv8.2-a \
    -DCMAKE_CXX_FLAGS="${ARM_SCRUB_FLAGS}" \
    -DCMAKE_C_FLAGS="${ARM_SCRUB_FLAGS}"

# ---- OpenSubdiv ----
build opensubdiv https://github.com/PixarAnimationStudios/OpenSubdiv "${OPENSUBDIV_VERSION}" \
    -DNO_PTEX=1 -DNO_OMP=1 -DNO_TBB=1 -DNO_CUDA=1 \
    -DNO_GLFW_X11=1 -DNO_DOC=1 -DNO_OPENCL=1 \
    -DNO_CLEW=1 -DNO_REGRESSION=1 -DNO_EXAMPLES=1 \
    -DNO_TUTORIALS=1 -DNO_GLTESTS=1 -DNO_MACOS_FRAMEWORK=1 -DNO_METAL=1 -DNO_TESTS=1

# ---- GLFW ----
build glfw https://github.com/glfw/glfw "${GLFW_VERSION}" \
    -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF \
    -DGLFW_INSTALL=ON -DBUILD_SHARED_LIBS=ON

# ---- Random123 (header-only) ----
git clone --depth=1 -b "${RANDOM123_VERSION}" https://github.com/DEShawResearch/random123 "${WORK}/random123"
make -C "${WORK}/random123" install-include prefix="${INSTALL_ROOT}"
rm -rf "${WORK}/random123"

# ---- OptiX headers (build-time only; OptiX is disabled on arm64) ----
git clone --depth=1 -b "${OPTIX_VERSION}" https://github.com/NVIDIA/optix-dev "${WORK}/optix"
mkdir -p "${INSTALL_ROOT}/include"
cp -r "${WORK}/optix/include/." "${INSTALL_ROOT}/include/"
rm -rf "${WORK}/optix"

echo "==================== done ===================="
"${INSTALL_ROOT}/bin/ispc" --version || true
ls "${INSTALL_ROOT}/lib" | head -30
