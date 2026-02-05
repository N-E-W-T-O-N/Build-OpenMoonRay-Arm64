# syntax=docker/dockerfile:1
FROM --platform=arm64 newton2022/moonray:base

# Disable HTTP2 & parallel downloads for DNF 
RUN printf "[main]\nhttp2=False\nmax_parallel_downloads=1\n" > /etc/dnf/dnf.conf && \
    dnf clean all && \
    dnf install -y dnf-plugins-core && \
    dnf config-manager --add-repo \
      https://developer.download.nvidia.com/compute/cuda/repos/rhel9/sbsa/cuda-rhel9.repo && \
    dnf install -y cuda && dnf clean all
    
ENV PATH=/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64



# RUN printf "[main]\nhttp2=False\nmax_parallel_downloads=1\n" > /etc/dnf/dnf.conf && \
#     dnf clean all && \
#     dnf install -y dnf-plugins-core && \
#     dnf config-manager --add-repo \
#       https://developer.download.nvidia.com/compute/cuda/repos/rhel9/sbsa/cuda-rhel9.repo && \
#     dnf install -y \
#       cuda-toolkit-13-1 \
#       cuda-cudart \
#       libcublas \
#       libcufft \
#       libcurand \
#       libcusolver \
#       libcusparse && \
#     dnf clean all


# RUN dnf install -y wget && \
#     wget https://developer.download.nvidia.com/compute/cuda/13.1.1/local_installers/cuda-repo-rhel9-13-1-local-13.1.1_590.48.01-1.aarch64.rpm && \
#     rpm -i cuda-repo-rhel9-13-1-local-13.1.1_590.48.01-1.aarch64.rpm && \
#     dnf clean all && \
#     dnf install -y \
#         cuda-toolkit-13-1 \
#         cuda-cudart \
#         libcublas \
#         libcufft \
#         libcurand \
#         libcusolver \
#         libcusparse && \
#     dnf clean all

ENV PATH=/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64


# ENV PATH=/usr/local/cuda/bin:$PATH \
#     LD_LIBRARY_PATH=/usr/local/cuda/lib64


# ENV PATH=/usr/local/cuda/bin:${PATH} \
#     LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

