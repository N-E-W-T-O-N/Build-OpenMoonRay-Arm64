# syntax=docker/dockerfile:1

############################################################
# Stage 1: Base image and core packages
############################################################
FROM rockylinux:9 AS base

ARG INSTALL_QT=1
#ARG INSTALL_CGROUP=1

# Enable repos and install core dependencies in one layer
# Enable EPEL and CRB repos, then install all core dependencies
RUN dnf install -y epel-release && \
    dnf config-manager --enable crb && \
    dnf install -y \
        # Build essentials
        bison \
        blosc blosc-devel \
        boost boost-chrono boost-date-time boost-devel boost-filesystem boost-program-options boost-python3 boost-regex boost-system boost-thread \
        cppunit cppunit-devel \
        curl-devel \
        fmt-devel \
        flex unzip  \
        freetype-devel \
        gcc gcc-c++ \
        giflib-devel \
        git \
        jsoncpp-devel \
        lsb_release \
        lua lua-devel lua-libs \
        make \
        openssl-devel \
        patch \
        pybind11-devel \
        python3 python3-devel python3-tbb \
        tbb tbb-devel \
        wget \
        zlib-devel \
        # Graphics, imaging, and rendering
        freeglut freeglut-devel \
        glfw glfw-devel \
        libatomic \
        libglvnd-devel \
        libheif-devel \
        libjpeg-devel \
        turbojpeg-devel \
        libjpeg-turbo-devel \
        libmng \
        libmicrohttpd libmicrohttpd-devel \
        libsquish-devel \
        libtiff-devel \
        libuuid-devel \
        libwebp-devel \
        LibRaw-devel \
        cmake \
        mesa-dri-drivers \
        mesa-libEGL mesa-libEGL-devel \
        mesa-libgbm mesa-libgbm-devel \
        mesa-libGL mesa-libGL-devel \
        mesa-libGLU mesa-libGLU-devel \
        mesa-libGLw mesa-libGLw-devel \
        mesa-libGLES mesa-libGLES-devel \
        mesa-libOSMesa mesa-libOSMesa-devel \
        # X11 libraries
        libX11-devel \
        libXcursor libXcursor-devel \
        libXi-devel \
        libXinerama libXinerama-devel \
        libXmu \
        libXpm \
        libXrandr libXrandr-devel \
        # File and 3D format support
        openjpeg2-devel \
        openvdb openvdb-devel openvdb-libs \
        ptex-devel \
        # Logging, testing, and multimedia
        ffmpeg-free-devel \
        log4cplus log4cplus-devel \
        # ARM-specific dependencies
        autoconf \
        automake \
        libtool \
        wayland-devel \
        libxkbcommon-devel \
        wayland-protocols-devel \
        extra-cmake-modules \
# Install Qt if requested in separate layer        
        qt5-qtbase-devel qt5-qtscript-devel \
        && \
    dnf clean all

# Install libcgroup if requested in separate layer
# RUN if [ "$INSTALL_CGROUP" -eq "1" ]; then \
#         dnf install -y libcgroup libcgroup-devel && \
#         dnf clean all; \
#         #   https://kojihub.stream.centos.org/kojifiles/packages/libcgroup/0.41/19.el8/aarch64/libcgroup-0.41-19.el8.aarch64.rpm \
#         #   https://kojihub.stream.centos.org/kojifiles/packages/libcgroup/0.41/19.el8/aarch64/libcgroup-devel-0.41-19.el8.aarch64.rpm; \
#     fi



############################################################
# Stage 2: Tools and ARM Support installation
############################################################
FROM base AS tools

WORKDIR /opt

# Install CMake
# RUN mkdir -p /opt/cmake \
#   && wget -q https://github.com/Kitware/CMake/releases/download/v4.2.3/cmake-4.2.3-linux-aarch64.sh -O /tmp/cmake-install.sh \
#   && chmod +x /tmp/cmake-install.sh \
#   && /tmp/cmake-install.sh --skip-license --prefix=/opt/cmake \
#   && ln -s /opt/cmake/bin/* /usr/local/bin/ \
#   && rm /tmp/cmake-install.sh \
#   && echo "Done Installing CMake"

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


RUN python3 -m pip install --no-cache-dir  meson 

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
