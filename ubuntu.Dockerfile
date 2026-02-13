FROM ubuntu:26.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update &&  \
    apt-get install -y \
# Build essentials
    build-essential \
    cmake meson tar \
    bison \
    pkg-config \
    libblosc-dev \
    libboost-all-dev \
    libcppunit-dev \
    libcurl4-openssl-dev \
    libfmt-dev \
    flex \
    libfreetype6-dev \
    g++ \
    libgif-dev \
    git \
    libjsoncpp-dev \
    lsb-release \
    lua5.3 liblua5.3-dev \
    make \
    libssl-dev \
    patch \
    pybind11-dev \
    python3 python3-dev  \
    libtbb-dev \
    wget \
# Graphics, imaging, and rendering    
    zlib1g-dev \
    freeglut3-dev \
    libglfw3-dev \
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
    libegl1-mesa-dev \
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
# Install Qt if requested in separate layer    
    qtbase5-dev \
    qtscript5-dev \
    && rm -rf /var/lib/apt/lists/*

ARG NINJA_VERSION=1.13.2
ARG ISPC_VERSION=1.30.0
ARG SIMDE_VERSION=0.8.2
    
# Install SSE2NEON for ARM compatibility
RUN git clone --depth=1 https://github.com/DLTcollab/sse2neon.git /tmp/sse2neon && \
    mkdir -p /usr/local/include/sse2neon && \
    mv /tmp/sse2neon/sse2neon.h /usr/local/include/sse2neon/sse2neon.h && \
    rm -rf /tmp/sse2neon
    
RUN wget https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-linux-aarch64.zip -O /tmp/ninja-linux.zip && \
    unzip /tmp/ninja-linux.zip -d /tmp && \
    mv /tmp/ninja /usr/local/bin/ninja && \
    chmod +x /usr/local/bin/ninja && \
    rm -rf /tmp/ninja-linux.zip
    
RUN mkdir -p /opt/MoonRay/installs/bin && \
    wget -q https://github.com/ispc/ispc/releases/download/v${ISPC_VERSION}/ispc-v${ISPC_VERSION}-linux.aarch64.tar.gz \
        -O /tmp/ispc.tar.gz && \
    tar -xzf /tmp/ispc.tar.gz \
        -C /tmp \
        --strip-components=2 \
        ispc-v${ISPC_VERSION}-linux.aarch64/bin/ispc && \
    mv /tmp/ispc /opt/MoonRay/installs/bin/ispc && \
    chmod +x /opt/MoonRay/installs/bin/ispc && \
    rm -f /tmp/ispc.tar.gz

RUN mkdir -p /tmp/simde \
    && wget -q https://github.com/simd-everywhere/simde/archive/refs/tags/v${SIMDE_VERSION}.tar.gz \
        -O /tmp/simde.tar.gz \
    && tar -xzf /tmp/simde.tar.gz -C /tmp \
    && meson setup /tmp/simde-build /tmp/simde-${SIMDE_VERSION} \
        --prefix=/opt/MoonRay/installs \
        --buildtype=release \
        -Dtests=false \
    && meson compile -C /tmp/simde-build \
    && meson install -C /tmp/simde-build \
    && rm -rf /tmp/simde*

VOLUME /build
WORKDIR /source

CMD ["bash"]
