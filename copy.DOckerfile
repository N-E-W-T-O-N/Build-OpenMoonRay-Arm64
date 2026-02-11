# syntax=docker/dockerfile:1

############################################################
# Stage 1: Base image and core packages
############################################################
FROM rockylinux:9 AS base

ARG INSTALL_QT=1
ARG INSTALL_CUDA=0
ARG INSTALL_CGROUP=1

# Enable repos and install core dependencies in one layer
RUN dnf install -y epel-release && \
    dnf config-manager --enable crb && \
    dnf install -y \
        gcc gcc-c++ git wget bison flex patch \
        python3 python3-devel pybind11-devel \
        libglvnd-devel lsb_release \
        boost boost-devel \
        blosc blosc-devel tbb tbb-devel python3-tbb \
        lua lua-devel libmicrohttpd-devel fmt-devel \
        freeglut freeglut-devel glfw-devel \
        mesa-libGL-devel mesa-libGLES-devel mesa-libGLU-devel mesa-libEGL-devel \
        libX11-devel libXrandr-devel libXinerama-devel libXcursor-devel libXi-devel \
        libwebp-devel libheif-devel libsquish-devel openjpeg2-devel \
        openvdb-devel ptex-devel \
        log4cplus-devel cppunit-devel ffmpeg-free-devel LibRaw-devel \
        giflib-devel libmng libtiff-devel libjpeg-devel \
        libatomic libuuid-devel openssl-devel curl-devel jsoncpp-devel \
        freetype-devel zlib-devel && \
    dnf clean all

# Install libcgroup if requested in separate layer
RUN if [ "$INSTALL_CGROUP" -eq "1" ]; then \
        dnf install -y \
          https://kojihub.stream.centos.org/kojifiles/packages/libcgroup/0.41/19.el8/aarch64/libcgroup-0.41-19.el8.aarch64.rpm \
          https://kojihub.stream.centos.org/kojifiles/packages/libcgroup/0.41/19.el8/aarch64/libcgroup-devel-0.41-19.el8.aarch64.rpm; \
    fi

# Install Qt if requested in separate layer
RUN if [ "$INSTALL_QT" -eq "1" ]; then \
        dnf install -y qt5-qtbase-devel qt5-qtscript-devel; \
    fi

# Install CUDA if requested in separate layer
RUN if [ "$INSTALL_CUDA" -eq "1" ]; then \
        dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/sbsa/cuda-rhel9.repo && \
        dnf install -y cuda ; \
    fi && \
    dnf clean all

############################################################
# Stage 2: Tools installation
############################################################
FROM base AS tools

WORKDIR /opt

RUN mkdir -p /opt/cmake \
  && wget -q https://github.com/Kitware/CMake/releases/download/v4.1.2/cmake-4.1.2-linux-aarch64.sh -O /tmp/cmake-install.sh \
  && chmod +x /tmp/cmake-install.sh \
  && /tmp/cmake-install.sh --skip-license --prefix=/opt/cmake \
  && ln -s /opt/cmake/bin/* /usr/local/bin/ \
  && rm /tmp/cmake-install.sh \
  && echo "Done Installing CMake"

RUN git clone --depth=1 https://github.com/DLTcollab/sse2neon.git /tmp/sse2neon && \
    mkdir -p /usr/local/include/sse2neon && \
    mv /tmp/sse2neon/sse2neon.h /usr/local/include/sse2neon/sse2neon.h && \
    rm -rf /tmp/sse2neon

############################################################
# Stage 3: Builder setup
############################################################
FROM tools AS builder

ENV PATH=/usr/local/cuda/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

VOLUME /build
WORKDIR /source

CMD ["bash"]
