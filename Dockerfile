# syntax=docker/dockerfile:1

############################################################
# Stage 1: Base image and core packages
############################################################
FROM rockylinux:9 AS base

ARG INSTALL_QT=1
#ARG INSTALL_CGROUP=1
ENV INSTALL_ROOT=/opt/MoonRay/installs
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
        python3 python3-devel  \
#        tbb tbb-devel python3-tbb \
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

RUN mkdir -p ${INSTALL_ROOT}

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

# ============================================================
# 1️⃣ JsonCpp (1.9.5)
# ============================================================
RUN git clone https://github.com/open-source-parsers/jsoncpp.git /tmp/jsoncpp && \
    cd /tmp/jsoncpp && \
    git checkout 5defb4ed1a4293b8e2bf641e16b156fb9de498cc && \
    mkdir build && cd build && \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
    -DBUILD_SHARED_LIBS=ON \
    -DPYTHON_EXECUTABLE=/usr/bin/python3 \
    -DJSONCPP_LIB_BUILD_SHARED=ON \
    -DJSONCPP_WITH_PKGCONFIG_SUPPORT=OFF && \
    cmake --build .  && \
    cmake --install . && \
    rm -rf /tmp/jsoncpp


# ============================================================
# 2️⃣ OpenSubdiv (v3_5_0)
# ============================================================
RUN git clone -b v3_7_0 https://github.com/PixarAnimationStudios/OpenSubdiv /tmp/opensubdiv && \
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

# ============================================================
# oneTBB (v2022.3.0)
# ============================================================
RUN git clone https://github.com/uxlfoundation/oneTBB /tmp/onetbb && \
    cd /tmp/onetbb && \
    git checkout v2022.3.0 && \
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

# ============================================================
# 3️⃣ OpenEXR (v3.1.8)
# ============================================================
RUN git clone https://github.com/AcademySoftwareFoundation/openexr /tmp/openexr && \
    cd /tmp/openexr && \
    git checkout 68d9e1e17620cef00e59b43fa42c97fbcf90e72b && \
    mkdir build && cd build && \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
    -DBUILD_SHARED_LIBS=OFF && \
    cmake --build . -j$(nproc) && \
    cmake --install . && \
    rm -rf /tmp/openexr


# ============================================================
# 4️⃣ Random123 (v1.14.0)
# ============================================================
RUN git clone -b v1.14.0 https://github.com/DEShawResearch/random123 /tmp/random123 && \
    cd /tmp/random123 && \
    make install-include prefix=${INSTALL_ROOT} && \
    rm -rf /tmp/random123


# ============================================================
# 5️⃣ Embree (v4.4.0)
# ============================================================
RUN git clone -b v4.4.0 --depth=1  https://github.com/embree/embree /tmp/embree && \
    cd /tmp/embree && \
    mkdir build && cd build && \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
    -DEMBREE_ISPC_SUPPORT=OFF \
    -DEMBREE_ARM=ON \
    -DEMBREE_SYCL_SUPPORT=OFF \
    -DEMBREE_IGNORE_INVALID_RAYS=ON \
    -DEMBREE_RAY_MASK=ON \
    -DEMBREE_TUTORIALS=OFF \
    -DBUILD_SHARED_LIBS=ON && \
    cmake --build . -j$(nproc) && \
    cmake --install . && \
    rm -rf /tmp/embree


# ============================================================
# 6️⃣ OpenColorIO (v2.5.1)
# ============================================================
RUN git clone -b v2.5.1 --depth=1 https://github.com/AcademySoftwareFoundation/OpenColorIO /tmp/ocio && \
    cd /tmp/ocio && \
    mkdir build && cd build && \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
    -DOCIO_BUILD_APPS=OFF \
    -DOCIO_BUILD_TESTS=OFF \
    -DOCIO_BUILD_GPU_TESTS=OFF \
    -DOCIO_BUILD_PYTHON=OFF \
    -DOCIO_USE_SIMD=ON \
    -DOCIO_BUILD_STATIC=OFF \
    -DOCIO_WARNING_AS_ERROR=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_CXX_STANDARD=17 && \
    cmake --build . && \
    cmake --install . && \
    rm -rf /tmp/ocio

# -DOCIO_USE_SSE=ON \
# -DOCIO_USE_SSE2=ON  \
# ============================================================
# 7️⃣ OpenImageIO (v3.1.10.0 ARM)
# ============================================================
RUN git clone -b v3.1.10.0 --depth=1 https://github.com/OpenImageIO/oiio /tmp/oiio && \
    cd /tmp/oiio && \
    mkdir build && cd build && \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
    -DOpenEXR_ROOT=${INSTALL_ROOT} \
    -DUSE_QT=0 \
    -DOpenImageIO_BUILD_MISSING_DEPS=all \
    -DUSE_PYTHON=1 \
    -DBUILD_DOCS=OFF \
    -DOIIO_BUILD_TESTS=OFF \
    -D__ARM_NEON__=1 \
    -DOIIO_NO_SSE=1 \
    -DOIIO_NO_AVX=1 \
    -DOIIO_NO_AVX2=1 \
    -DOIIO_NO_AVX512=1 \
    -DOIIO_NO_F16C=1 \
    -DSIMD_FLAGS=-march=armv8.2-a \
    -DCMAKE_CXX_FLAGS="-D__ARM_NEON__=1 -U__SSE__ -U__SSE2__ -U__AVX__ -U__AVX2__ -U__SSE4_1__ -U__SSE4_2__ -UFARMHASH_ASSUME_SSSE3 -UFARMHASH_ASSUME_SSE41" \
    -DCMAKE_C_FLAGS="-D__ARM_NEON__=1 -U__SSE__ -U__SSE2__ -U__AVX__ -U__AVX2__ -U__SSE4_1__ -U__SSE4_2__ -UFARMHASH_ASSUME_SSSE3 -UFARMHASH_ASSUME_SSE41" && \
    cmake --build . -j$(nproc) && \
    cmake --install . && \
    rm -rf /tmp/oiio




# ============================================================
# GLFW (3.4)
# ============================================================
RUN git clone https://github.com/glfw/glfw /tmp/glfw && \
    cd /tmp/glfw && \
    git checkout 3.4 && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_PREFIX_PATH=${INSTALL_ROOT} \
        -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
        -DGLFW_BUILD_EXAMPLES=OFF \
        -DGLFW_BUILD_TESTS=OFF \
        -DGLFW_BUILD_DOCS=OFF \
        -DGLFW_INSTALL=ON \
        -DBUILD_SHARED_LIBS=ON && \
    cmake --build . -j$(nproc) && \
    cmake --install . && \
    rm -rf /tmp/glfw

# ============================================================
# OptiX Headers (v7.6.0)
# ============================================================
RUN git clone https://github.com/NVIDIA/optix-dev /tmp/optix && \
    cd /tmp/optix && \
    git checkout v7.6.0 && \
    mkdir -p ${INSTALL_ROOT}/include && \
    cp -r include/* ${INSTALL_ROOT}/include/ && \
    rm -rf /tmp/optix


ENV LD_LIBRARY_PATH=${INSTALL_ROOT}/lib:${LD_LIBRARY_PATH}

VOLUME /build
WORKDIR /source

CMD ["bash"]
