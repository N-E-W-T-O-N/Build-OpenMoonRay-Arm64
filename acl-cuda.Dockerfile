FROM newton2022/moonray:cuda-all AS  arm_support

# Install xz so we can extract .tar.xz archives
RUN dnf install -y xz && dnf clean all


# ARM Compute Library
RUN if [ "$INSTALL_ARM_SUPPORT" -eq "1" ]; then \
    echo "Installing ARM Compute Library v${ARM_COMPUTE_VERSION}..."; \
    mkdir -p /opt/arm-compute-library; \
    cd /opt/arm-compute-library; \
    wget -q https://sourceforge.net/projects/compute-library.mirror/files/v${ARM_COMPUTE_VERSION}/arm_compute-v${ARM_COMPUTE_VERSION}-linux-aarch64-cpu-gpu-bin.tar.gz/download -O arm_compute.tar.gz; \
    tar -xzf arm_compute.tar.gz; \
    rm arm_compute.tar.gz; \
    echo 'export ACL_ROOT_DIR=/opt/arm-compute-library' >> /etc/environment; \
    echo 'export LD_LIBRARY_PATH=/opt/arm-compute-library/lib:${LD_LIBRARY_PATH}' >> /etc/environment; \
    echo "ARM Compute Library installation completed"; \
    fi

# ARM GNU Toolchain
RUN if [ "$INSTALL_ARM_SUPPORT" -eq "1" ]; then \
    echo "Installing ARM GNU Toolchain v${ARM_GNU_TOOLCHAIN_VERSION}..."; \
    mkdir -p /opt/arm-gnu-toolchain; \
    cd /opt/arm-gnu-toolchain; \
    wget -q https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_GNU_TOOLCHAIN_VERSION}/binrel/arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-x86_64-aarch64-none-linux-gnu.tar.xz; \
    wget -q https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_GNU_TOOLCHAIN_VERSION}/binrel/arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-x86_64-aarch64-none-elf.tar.xz; \
    tar -xJf arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-x86_64-aarch64-none-linux-gnu.tar.xz; \
    tar -xJf arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-x86_64-aarch64-none-elf.tar.xz; \
    rm *.tar.xz; \
    echo "ARM GNU Toolchain installation completed"; \
    fi

# Arm Performance Libraries
RUN if [ "$INSTALL_ARM_SUPPORT" -eq "1" ]; then \
    echo "Installing Arm Performance Libraries v25.07..."; \
    mkdir -p /opt/arm-performance-libs /tmp/arm ; \
    cd /tmp/arm; \
    wget -q https://developer.arm.com/-/cdn-downloads/permalink/Arm-Performance-Libraries/Version_25.07/arm-performance-libraries_25.07_rpm_gcc.tar ;\
    tar -xf arm-performance-libraries_25.07_rpm_gcc.tar ; \
    bash arm-performance-libraries_25.07_rpm/arm-performance-libraries_25.07_rpm.sh -a -i /opt/arm-performance-libs && rm -rf arm-performance-libraries_25.07_rpm; \
    echo "Arm Performance Libraries installation completed"; \
    fi



############################################################
# Stage 4: Builder setup with ARM environment
############################################################
FROM arm_support AS builder

# Set up comprehensive environment for ARM and CUDA development
ENV PATH=/usr/local/cuda/bin:/opt/arm-gnu-toolchain/arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-x86_64-aarch64-none-linux-gnu/bin:/opt/arm-gnu-toolchain/arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-x86_64-aarch64-none-elf/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:/opt/arm-compute-library/lib:${LD_LIBRARY_PATH} \
    ACL_ROOT_DIR=/opt/arm-compute-library \
    ARM_COMPUTE_LIB_DIR=/opt/arm-compute-library/lib \
    ARM_COMPUTE_INCLUDE_DIR=/opt/arm-compute-library/include \
    ARM_TOOLCHAIN_ROOT=/opt/arm-gnu-toolchain \
    PKG_CONFIG_PATH=/opt/arm-compute-library/lib/pkgconfig:/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}

# Create convenience scripts for cross-compilation
RUN echo '#!/bin/bash' > /usr/local/bin/arm-cross-compile && \
    echo 'export CC=aarch64-linux-gnu-gcc' >> /usr/local/bin/arm-cross-compile && \
    echo 'export CXX=aarch64-linux-gnu-g++' >> /usr/local/bin/arm-cross-compile && \
    echo 'export AR=aarch64-linux-gnu-ar' >> /usr/local/bin/arm-cross-compile && \
    echo 'export STRIP=aarch64-linux-gnu-strip' >> /usr/local/bin/arm-cross-compile && \
    echo 'export CMAKE_SYSTEM_NAME=Linux' >> /usr/local/bin/arm-cross-compile && \
    echo 'export CMAKE_SYSTEM_PROCESSOR=AARCH64' >> /usr/local/bin/arm-cross-compile && \
    echo 'export CMAKE_LIBRARY_PATH=/usr/aarch64-linux-gnu/lib' >> /usr/local/bin/arm-cross-compile && \
    echo 'echo "ARM cross-compilation environment set up"' >> /usr/local/bin/arm-cross-compile && \
    chmod +x /usr/local/bin/arm-cross-compile

# Create a script to verify ARM installations
RUN echo '#!/bin/bash' > /usr/local/bin/verify-arm-install && \
    echo 'echo "=== ARM Environment Verification ==="' >> /usr/local/bin/verify-arm-install && \
    echo 'echo "ARM Compute Library:"' >> /usr/local/bin/verify-arm-install && \
    echo 'if [ -d "$ACL_ROOT_DIR" ]; then echo "  ✓ Found at $ACL_ROOT_DIR"; else echo "  ✗ Not found"; fi' >> /usr/local/bin/verify-arm-install && \
    echo 'echo "ARM GNU Toolchain:"' >> /usr/local/bin/verify-arm-install && \
    echo 'if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then echo "  ✓ $(aarch64-linux-gnu-gcc --version | head -n1)"; else echo "  ✗ Not found"; fi' >> /usr/local/bin/verify-arm-install && \
    echo 'echo "oneDNN:"' >> /usr/local/bin/verify-arm-install && \
    echo 'if [ -f "/usr/local/lib/libdnnl.so" ]; then echo "  ✓ Found at /usr/local/lib/libdnnl.so"; else echo "  ✗ Not found"; fi' >> /usr/local/bin/verify-arm-install && \
    echo 'echo "oneMath:"' >> /usr/local/bin/verify-arm-install && \
    echo 'if [ -f "/usr/local/lib/libonemkl.so" ]; then echo "  ✓ Found at /usr/local/lib/libonemkl.so"; else echo "  ✗ Not found"; fi' >> /usr/local/bin/verify-arm-install && \
    echo 'echo "=== Environment Variables ==="' >> /usr/local/bin/verify-arm-install && \
    echo 'env | grep -E "(ARM|ACL|PATH|LD_LIBRARY)" | sort' >> /usr/local/bin/verify-arm-install && \
    chmod +x /usr/local/bin/verify-arm-install

VOLUME /build
WORKDIR /source

CMD ["bash"]