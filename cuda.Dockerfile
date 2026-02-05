# syntax=docker/dockerfile:1
FROM rockylinux:9

# Disable HTTP2 & parallel downloads for DNF \
RUN printf "[main]\nhttp2=False\nmax_parallel_downloads=1\n" > /etc/dnf/dnf.conf && \
    dnf clean all && \
    dnf config-manager --add-repo \
      https://developer.download.nvidia.com/compute/cuda/repos/rhel9/sbsa/cuda-rhel9.repo && \
    dnf install -y cuda-runtime-13-0 cuda-toolkit-13 && \
    dnf clean all

ENV PATH=/usr/local/cuda/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

