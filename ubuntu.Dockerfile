# syntax=docker/dockerfile:1
############################################################
# MoonRay arm64 deps image — Ubuntu 26.04
#
# Stages:
#   base  : distro packages
#   tools : ninja / ISPC / sse2neon / SIMDe
#   heavy : oneTBB + OpenSubdiv + OpenImageDenoise  (baked in)
#
# OpenUSD is NOT built here — it is too slow for CI image builds.
# Build it locally inside this image with scripts/build_usd.sh
# (OpenSubdiv lives in this image because USD imaging requires it).
#
# Light deps (embree, OCIO, OIIO, GLFW, Random123, OptiX headers)
# are built by scripts/build_light_deps.sh in CI
# (.github/workflows/build-deps-artifact.yml) on top of this image,
# then the complete ${INSTALL_ROOT} is packaged and uploaded to HF.
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
# Stage 3: heavy — the long builds, baked into the image
############################################################
FROM tools AS heavy

ARG TBB_VERSION=v2022.3.0
ARG OPENSUBDIV_VERSION=v3_7_0
ARG OIDN_VERSION=2.5.0

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

VOLUME /build
WORKDIR /source

CMD ["bash"]
