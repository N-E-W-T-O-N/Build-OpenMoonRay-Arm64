FROM newton2022/moonray:acl
# ============================================================
# OpenUSD
# ============================================================
RUN git clone -b  v25.11  --depth=1 https://github.com/PixarAnimationStudios/USD /tmp/USD && cd /tmp/USD && \
    mkdir build && cd build && \
    cmake .. \
      -DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT} \
      -DCMAKE_PREFIX_PATH=${INSTALL_ROOT} \
      -DPXR_ENABLE_PYTHON_SUPPORT=ON \
      -DPXR_USE_PYTHON_3=ON \
      -DPython3_EXECUTABLE=/usr/bin/python3 \
      -DBoost_LIBRARY_DIR=/usr/lib64 \
      -DBoost_INCLUDE_DIR=/usr/include \
      -DTBB_USE_DEBUG_BUILD=OFF \
      -DTBB_DIR=${INSTALL_ROOT}/lib/cmake/TBB \
      -DPXR_BUILD_TESTS=OFF \
      -DPXR_BUILD_EXAMPLES=OFF \
      -DPXR_BUILD_TUTORIALS=OFF \
      -DPXR_BUILD_USD_TOOLS=ON \
      -DPXR_BUILD_ANIMX_TESTS=OFF \
      -DPXR_ENABLE_PTEX_SUPPORT=OFF \
      -DPXR_ENABLE_OPENVDB_SUPPORT=OFF \
      -DPXR_BUILD_USDVIEW=OFF \
      -DBoost_NO_BOOST_CMAKE=ON \
      -DBoost_NO_SYSTEM_PATHS=ON \
      -DPXR_BUILD_DOCUMENTATION=OFF \
      -DPXR_BUILD_HTML_DOCUMENTATION=OFF \
      -DPXR_BUILD_PYTHON_DOCUMENTATION=OFF \
      -DTBB_SUPPRESS_DEPRECATED_MESSAGES=1 && \
    cmake --build .   && \
    cmake --install .