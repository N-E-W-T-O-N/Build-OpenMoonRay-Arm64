# syntax=docker/dockerfile:1
############################################################
# MoonRay arm64 deps image — Ubuntu 26.04
#
# Stages:
#   base  : distro packages
#   tools : ninja / ISPC / sse2neon / SIMDe
#   deps  : ALL non-USD deps — oneTBB, OpenSubdiv, OIDN, Embree, OCIO,
#           OIIO, GLFW, Random123, OptiX headers
#
# This whole image is built in CI (.github/workflows/build-ubuntu26-deps-image.yml)
# on a native arm64 runner = "all major deps built in CI/CD".
#
# OpenUSD is the ONLY dep NOT built here (too slow for CI). It is built
# locally with scripts/build_usd.sh (against this image's TBB+OpenSubdiv)
# and carried as the deps-usd middle image (deps-usd.Dockerfile), consumed
# via COPY --from. No Hugging Face / tarball hosting is used.
############################################################
FROM ubuntu:26.04 AS base
ENV DEBIAN_FRONTEND=noninteractive
ENV INSTALL_ROOT=/opt/MoonRay/installs
RUN apt-get update &&  \
    apt-get install -y \
# Build essentials
    build-essential \
    cmake meson tar unzip zip zstd \
    bison libjsoncpp-dev \
    pkg-config \
    libblosc-dev \
    libboost-all-dev \
    libcppunit-dev ccache \
    libcurl4-openssl-dev \
    libfmt-dev \
    flex \
    libfreetype6-dev \
    g++ \
    libgif-dev \
    git \
    lsb-release \
    lua5.3 liblua5.3-dev \
    make \
    libssl-dev \
    patch \
    pybind11-dev \
    python3 python3-dev python3-full python3-jinja2 python3-pip \
    wget \
# Graphics, imaging, and rendering
    zlib1g-dev \
    freeglut3-dev \
    libatomic1 \
    libglvnd-dev \
    libheif-dev \
    libjpeg-dev \
    libturbojpeg0-dev \
    libmng-dev \
    libmicrohttpd-dev \
    libsquish-dev \
    libtiff-dev \
    uuid-dev \
    libwebp-dev \
    libraw-dev \
    libegl1-mesa-dev libopenexr-dev \
    libgbm-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libosmesa6-dev \
# X11 libraries
    libx11-dev \
    libxcursor-dev \
    libxi-dev \
    libxinerama-dev \
    libxmu-dev \
    libxpm-dev \
    libxrandr-dev \
# File and 3D format support
    libopenjp2-7-dev \
    libopenvdb-dev \
    libptexenc-dev \
# Logging, testing, and multimedia
    ffmpeg \
    liblog4cplus-dev \
# ARM-specific dependencies
    autoconf \
    automake \
    libtool \
    libwayland-dev \
    libxkbcommon-dev \
    wayland-protocols \
    extra-cmake-modules \
# Qt
    qtbase5-dev \
    qtscript5-dev \
    && rm -rf /var/lib/apt/lists/*

############################################################
# Stage 2: tools
############################################################
FROM base AS tools

ARG NINJA_VERSION=1.13.2
ARG ISPC_VERSION=1.31.0
ARG SIMDE_VERSION=0.8.2
ARG SSE2NEON_VERSION=v1.9.1

RUN mkdir -p ${INSTALL_ROOT}/bin

# sse2neon (pinned release, not HEAD, for reproducibility)
RUN git clone --depth=1 -b ${SSE2NEON_VERSION} https://github.com/DLTcollab/sse2neon.git /tmp/sse2neon && \
    mkdir -p /usr/local/include/sse2neon && \
    mv /tmp/sse2neon/sse2neon.h /usr/local/include/sse2neon/sse2neon.h && \
    rm -rf /tmp/sse2neon

RUN wget https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-linux-aarch64.zip -O /tmp/ninja-linux.zip && \
    unzip /tmp/ninja-linux.zip -d /tmp && \
    mv /tmp/ninja /usr/local/bin/ninja && \
    chmod +x /usr/local/bin/ninja && \
    rm -rf /tmp/ninja-linux.zip

RUN wget -q https://github.com/ispc/ispc/releases/download/v${ISPC_VERSION}/ispc-v${ISPC_VERSION}-linux.aarch64.tar.gz \
        -O /tmp/ispc.tar.gz && \
    tar -xzf /tmp/ispc.tar.gz \
        -C /tmp \
        --strip-components=2 \
        ispc-v${ISPC_VERSION}-linux.aarch64/bin/ispc && \
    mv /tmp/ispc ${INSTALL_ROOT}/bin/ispc && \
    chmod +x ${INSTALL_ROOT}/bin/ispc && \
    rm -f /tmp/ispc.tar.gz

RUN mkdir -p /tmp/simde \
    && wget -q https://github.com/simd-everywhere/simde/archive/refs/tags/v${SIMDE_VERSION}.tar.gz \
        -O /tmp/simde.tar.gz \
    && tar -xzf /tmp/simde.tar.gz -C /tmp \
    && meson setup /tmp/simde-build /tmp/simde-${SIMDE_VERSION} \
        --prefix=${INSTALL_ROOT} \
        --buildtype=release \
        -Dtests=false \
    && meson compile -C /tmp/simde-build \
    && meson install -C /tmp/simde-build \
    && rm -rf /tmp/simde*

############################################################
# Stage 3: deps — all MoonRay deps except OpenUSD
############################################################
FROM tools AS deps

ARG TBB_VERSION=v2022.3.0
ARG OPENSUBDIV_VERSION=v3_7_0
ARG OIDN_VERSION=2.5.0
ARG EMBREE_VERSION=v4.4.1
ARG OCIO_VERSION=v2.5.2
ARG OIIO_VERSION=v3.1.15.0
ARG GLFW_VERSION=3.4
ARG RANDOM123_VERSION=v1.14.0
ARG OPTIX_VERSION=v7.6.0
# x86-macro scrub for OIIO on aarch64 (prevents farmhash/simd misdetection)
ARG ARM_SCRUB_FLAGS="-D__ARM_NEON__=1 -U__SSE__ -U__SSE2__ -U__AVX__ -U__AVX2__ -U__SSE4_1__ -U__SSE4_2__ -UFARMHASH_ASSUME_SSSE3 -UFARMHASH_ASSUME_SSE41"

# oneTBB first — required by both OIDN (CPU device) and USD
RUN git clone --depth=1 -b ${TBB_VERSION} https://github.com/uxlfoundation/oneTBB /tmp/onetbb && \
    cd /tmp/onetbb && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
        -DTBB_TEST=OFF \
        -DTBB_STRICT=OFF \
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
        -DCMAKE_CXX_FLAGS="-Wno-error=stringop-overflow" && \
    cmake --build . -j$(nproc) && \
    cmake --install . && \
    rm -rf /tmp/onetbb

# OpenSubdiv — required by OpenUSD imaging (built locally later via
# scripts/build_usd.sh), so it must already be in the image
RUN git clone --depth=1 -b ${OPENSUBDIV_VERSION} https://github.com/PixarAnimationStudios/OpenSubdiv /tmp/opensubdiv && \
    cd /tmp/opensubdiv && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
        -DPYTHON_EXECUTABLE=/usr/bin/python3 \
        -DNO_PTEX=1 -DNO_OMP=1 -DNO_TBB=1 -DNO_CUDA=1 \
        -DNO_GLFW_X11=1 -DNO_DOC=1 -DNO_OPENCL=1 \
        -DNO_CLEW=1 -DNO_REGRESSION=1 -DNO_EXAMPLES=1 \
        -DNO_TUTORIALS=1 -DNO_GLTESTS=1 \
        -DNO_MACOS_FRAMEWORK=1 -DNO_METAL=1 \
        -DNO_TESTS=1 && \
    cmake --build . -j$(nproc) && \
    cmake --install . && \
    rm -rf /tmp/opensubdiv

# OpenImageDenoise — use the release .src tarball (includes trained weights;
# a plain git clone would need submodules/LFS for them)
RUN wget -q https://github.com/RenderKit/oidn/releases/download/v${OIDN_VERSION}/oidn-${OIDN_VERSION}.src.tar.gz \
        -O /tmp/oidn.tar.gz && \
    tar -xzf /tmp/oidn.tar.gz -C /tmp && \
    cd /tmp/oidn-${OIDN_VERSION} && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
        -DCMAKE_PREFIX_PATH=${INSTALL_ROOT} \
        -DOIDN_DEVICE_CPU=ON \
        -DOIDN_DEVICE_CUDA=OFF \
        -DOIDN_DEVICE_HIP=OFF \
        -DOIDN_DEVICE_SYCL=OFF \
        -DOIDN_DEVICE_METAL=OFF \
        -DOIDN_APPS=OFF \
        -DISPC_EXECUTABLE=${INSTALL_ROOT}/bin/ispc && \
    cmake --build . -j$(nproc) && \
    cmake --install . && \
    rm -rf /tmp/oidn*

# Embree (NEON). Uses TBB tasking -> must come after oneTBB above.
RUN git clone --depth=1 -b ${EMBREE_VERSION} https://github.com/embree/embree /tmp/embree && \
    cmake -S /tmp/embree -B /tmp/embree/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
        -DCMAKE_PREFIX_PATH=${INSTALL_ROOT} \
        -DEMBREE_ISPC_SUPPORT=OFF \
        -DEMBREE_ARM=ON \
        -DEMBREE_SYCL_SUPPORT=OFF \
        -DEMBREE_IGNORE_INVALID_RAYS=ON \
        -DEMBREE_RAY_MASK=ON \
        -DEMBREE_TUTORIALS=OFF \
        -DEMBREE_TASKING_SYSTEM=TBB \
        -DBUILD_SHARED_LIBS=ON && \
    cmake --build /tmp/embree/build -j$(nproc) && \
    cmake --install /tmp/embree/build && \
    rm -rf /tmp/embree

# OpenColorIO
RUN git clone --depth=1 -b ${OCIO_VERSION} https://github.com/AcademySoftwareFoundation/OpenColorIO /tmp/ocio && \
    cmake -S /tmp/ocio -B /tmp/ocio/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
        -DCMAKE_PREFIX_PATH=${INSTALL_ROOT} \
        -DOCIO_BUILD_APPS=OFF -DOCIO_BUILD_TESTS=OFF -DOCIO_BUILD_GPU_TESTS=OFF \
        -DOCIO_BUILD_PYTHON=OFF -DOCIO_USE_SIMD=ON -DOCIO_BUILD_STATIC=OFF \
        -DOCIO_WARNING_AS_ERROR=OFF -DBUILD_SHARED_LIBS=ON -DCMAKE_CXX_STANDARD=17 && \
    cmake --build /tmp/ocio/build -j$(nproc) && \
    cmake --install /tmp/ocio/build && \
    rm -rf /tmp/ocio

# OpenImageIO (x86-macro scrub mandatory on aarch64)
RUN git clone --depth=1 -b ${OIIO_VERSION} https://github.com/OpenImageIO/oiio /tmp/oiio && \
    cmake -S /tmp/oiio -B /tmp/oiio/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
        -DCMAKE_PREFIX_PATH=${INSTALL_ROOT} \
        -DUSE_QT=0 -DOpenImageIO_BUILD_MISSING_DEPS=all -DUSE_PYTHON=1 \
        -DBUILD_DOCS=OFF -DOIIO_BUILD_TESTS=OFF \
        -DOIIO_NO_SSE=1 -DOIIO_NO_AVX=1 -DOIIO_NO_AVX2=1 -DOIIO_NO_AVX512=1 -DOIIO_NO_F16C=1 \
        -DSIMD_FLAGS=-march=armv8.2-a \
        -DCMAKE_CXX_FLAGS="${ARM_SCRUB_FLAGS}" \
        -DCMAKE_C_FLAGS="${ARM_SCRUB_FLAGS}" && \
    cmake --build /tmp/oiio/build -j$(nproc) && \
    cmake --install /tmp/oiio/build && \
    rm -rf /tmp/oiio

# GLFW
RUN git clone --depth=1 -b ${GLFW_VERSION} https://github.com/glfw/glfw /tmp/glfw && \
    cmake -S /tmp/glfw -B /tmp/glfw/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
        -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF \
        -DGLFW_INSTALL=ON -DBUILD_SHARED_LIBS=ON && \
    cmake --build /tmp/glfw/build -j$(nproc) && \
    cmake --install /tmp/glfw/build && \
    rm -rf /tmp/glfw

# Random123 (header-only)
RUN git clone --depth=1 -b ${RANDOM123_VERSION} https://github.com/DEShawResearch/random123 /tmp/random123 && \
    make -C /tmp/random123 install-include prefix=${INSTALL_ROOT} && \
    rm -rf /tmp/random123

# OptiX headers (build-time only; OptiX disabled at runtime on arm64)
RUN git clone --depth=1 -b ${OPTIX_VERSION} https://github.com/NVIDIA/optix-dev /tmp/optix && \
    mkdir -p ${INSTALL_ROOT}/include && \
    cp -r /tmp/optix/include/. ${INSTALL_ROOT}/include/ && \
    rm -rf /tmp/optix

VOLUME /build
WORKDIR /source

CMD ["bash"]
