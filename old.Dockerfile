# syntax=docker/dockerfile:1
FROM rockylinux:9

# Build arguments for optional components
ARG INSTALL_QT=1
ARG INSTALL_CUDA=0
ARG INSTALL_CGROUP=1

# Ensure system tools and repos
RUN dnf install -y epel-release && \
    dnf config-manager --enable crb

# Core development dependencies
RUN dnf install -y \
        libglvnd-devel \
        gcc gcc-c++ \
        bison git flex wget python3 python3-devel pybind11-devel patch \
        giflib-devel libmng libtiff-devel libjpeg-devel \
        libatomic libuuid-devel openssl-devel curl-devel jsoncpp-devel \
        freetype-devel zlib-devel lsb_release \
# Libraries for MoonRay build
        blosc blosc-devel tbb tbb-devel python3-tbb \
        boost boost-chrono boost-date-time boost-filesystem boost-python3 boost-program-options boost-regex boost-thread boost-system boost-devel \
        lua lua-libs lua-devel libmicrohttpd libmicrohttpd-devel fmt-devel freeglut freeglut-devel \
        glfw glfw-devel \
        mesa-libGL mesa-libGL-devel     \
        mesa-libGLES mesa-libGLES-devel \
        mesa-libGLU mesa-libGLU-devel   \
        mesa-libEGL mesa-libEGL-devel   \
        libX11-devel libXrandr libXrandr-devel libwebp-devel \
        libXinerama libXinerama-devel libXcursor libXcursor-devel libXi-devel libheif-devel libsquish-devel openjpeg2-devel \
        openvdb openvdb-libs openvdb-devel libXmu libXpm  ptex-devel \
        log4cplus log4cplus-devel cppunit cppunit-devel ffmpeg-free-devel   LibRaw-devel
        
WORKDIR /installs  
RUN  mkdir -p /installs/{bin,lib,include}        

RUN git clone --depth=1 https://github.com/DLTcollab/sse2neon.git /tmp/sse2neon && \
    mkdir -p /usr/local/include/sse2neon && \
    cp /tmp/sse2neon/sse2neon.h /usr/local/include/sse2neon/ && \
    rm -rf /tmp/sse2neon

# Install CMake
RUN wget https://github.com/Kitware/CMake/releases/download/v4.1.2/cmake-4.1.2-linux-aarch64.tar.gz && \
    tar xzf cmake-4.1.2-linux-aarch64.tar.gz && \
    ln -s /installs/cmake-4.1.2-linux-aarch64/bin/cmake /usr/local/bin/cmake && \
    rm cmake-4.1.2-linux-aarch64.tar.gz

# Install libcgroup if requested
RUN if [ "${INSTALL_CGROUP}" -eq "1" ]; then \
        wget https://kojihub.stream.centos.org/kojifiles/packages/libcgroup/0.41/19.el8/aarch64/libcgroup-0.41-19.el8.aarch64.rpm && \
        wget https://kojihub.stream.centos.org/kojifiles/packages/libcgroup/0.41/19.el8/aarch64/libcgroup-devel-0.41-19.el8.aarch64.rpm && \
        dnf install -y libcgroup-0.41-19.el8.aarch64.rpm libcgroup-devel-0.41-19.el8.aarch64.rpm ; \
    fi

# Install Qt if requested
RUN if [ "${INSTALL_QT}" -eq "1" ]; then \
        dnf install -y qt5-qtbase-devel qt5-qtscript-devel ; \
    fi

# Install CUDA if requested
RUN if [ "${INSTALL_CUDA}" -eq "1" ]; then \
        dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/sbsa/cuda-rhel9.repo && \
        dnf install -y cuda-runtime-11-8 cuda-toolkit-11-8 ; \
    fi

RUN dnf clean all

# CUDA environment
ENV PATH=/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

# Expose build directory
VOLUME /build
WORKDIR /source
