FROM newton2022/moonray:base

ARG ARM_COMPUTE_VERSION=52.8.0
ARG ARM_PERFORMANCE_VERSION=26.01
ARG ARM_GNU_TOOLCHAIN_VERSION=15.2.Rel1

# Needed to extract .tar.xz
RUN dnf install -y xz && dnf clean all

WORKDIR /opt

RUN set -eux; \
    \
    # -------------------------------
    # ARM Compute Library → /opt/acl
    # -------------------------------
    mkdir -p /opt/acl; \
    cd /opt/acl; \
    wget -q \
      https://sourceforge.net/projects/compute-library.mirror/files/v${ARM_COMPUTE_VERSION}/arm_compute-v${ARM_COMPUTE_VERSION}-linux-aarch64-cpu-gpu-bin.tar.gz/download \
      -O acl.tar.gz; \
    tar -xzf acl.tar.gz --strip-components=1; \
    rm acl.tar.gz; \
    \
    # ---------------------------------
    # ARM GNU Toolchain → /opt/arm-toolkit
    # ---------------------------------
    mkdir -p /opt/arm-toolkit; \
    cd /opt/arm-toolkit; \
    wget -q \
      https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_GNU_TOOLCHAIN_VERSION}/binrel/arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-aarch64-aarch64-none-linux-gnu.tar.xz; \
    tar -xJf arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-aarch64-aarch64-none-linux-gnu.tar.xz --strip-components=1; \
    rm arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-aarch64-aarch64-none-linux-gnu.tar.xz; \
    ln -s /opt/arm-toolkit/bin/* /usr/local/bin/; \
    \
    # ---------------------------------
    # Arm Performance Libraries → /opt/apl
    # ---------------------------------
    mkdir -p /tmp/apl; \
    cd /tmp/apl; \
    wget -q \
      https://developer.arm.com/-/cdn-downloads/permalink/Arm-Performance-Libraries/Version_${ARM_PERFORMANCE_VERSION}/arm-performance-libraries_${ARM_PERFORMANCE_VERSION}_rpm_gcc.tar; \
    tar -xf arm-performance-libraries_${ARM_PERFORMANCE_VERSION}_rpm_gcc.tar; \
    bash arm-performance-libraries_${ARM_PERFORMANCE_VERSION}_rpm/arm-performance-libraries_${ARM_PERFORMANCE_VERSION}_rpm.sh \
      -a -i /opt/apl; \
    rm -rf /tmp/apl


# RUN mkdir -p /opt/arm-compute-library && \
#     cd /opt/arm-compute-library && \
#     wget -q \
#       https://sourceforge.net/projects/compute-library.mirror/files/v${ARM_COMPUTE_VERSION}/arm_compute-v${ARM_COMPUTE_VERSION}-linux-aarch64-cpu-gpu-bin.tar.gz/download \
#       -O acl.tar.gz && \
#     tar -xzf acl.tar.gz && \
#     rm acl.tar.gz

# # ------------------------------------------------------------
# # ARM GNU Toolchain (native aarch64)
# # ------------------------------------------------------------
# RUN mkdir -p /opt/arm-gnu-toolchain && \
#     cd /opt/arm-gnu-toolchain && \
#     wget -q \
#       https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_GNU_TOOLCHAIN_VERSION}/binrel/arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-aarch64-aarch64-none-linux-gnu.tar.xz && \
#     tar -xJf arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-aarch64-aarch64-none-linux-gnu.tar.xz && \
#     rm arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-aarch64-aarch64-none-linux-gnu.tar.xz

# # Resolve toolchain dir once (no glob in ENV)
# RUN TOOLCHAIN_DIR=$(ls -d /opt/arm-gnu-toolchain/* | head -n1) && \
#     ln -s ${TOOLCHAIN_DIR}/bin/* /usr/local/bin/

# # ------------------------------------------------------------
# # Arm Performance Libraries
# # ------------------------------------------------------------
# RUN mkdir -p /tmp/arm && \
#     cd /tmp/arm && \
#     wget -q \
#       https://developer.arm.com/-/cdn-downloads/permalink/Arm-Performance-Libraries/Version_${ARM_PERFORMANCE_VERSION}/arm-performance-libraries_${ARM_PERFORMANCE_VERSION}_rpm_gcc.tar && \
#     tar -xf arm-performance-libraries_${ARM_PERFORMANCE_VERSION}_rpm_gcc.tar && \
#     bash arm-performance-libraries_${ARM_PERFORMANCE_VERSION}_rpm/arm-performance-libraries_${ARM_PERFORMANCE_VERSION}_rpm.sh \
#       -a -i /opt/arm-performance-libs && \
#     rm -rf /tmp/arm

# ------------------------------------------------------------
# Environment
# ------------------------------------------------------------
ENV ACL_ROOT_DIR=/opt/acl \
  ARM_TOOLCHAIN_ROOT=/opt/arm-toolkit \
  APL_ROOT_DIR=/opt/apl \
  LD_LIBRARY_PATH=/opt/acl/lib:/opt/apl/lib:${LD_LIBRARY_PATH}

WORKDIR /source
CMD ["bash"]
