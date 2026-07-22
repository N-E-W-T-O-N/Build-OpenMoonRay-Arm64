#!/bin/bash

#docker pull --platform arm64 newton2022/moonray:acl

docker run \
  --pull always \
  -v "$(pwd)/source:/source" \
  -v "$(pwd)/build:/build" \
  -v /tmp:/tmp \
  -w /build/deps \
  --platform arm64 \
  --security-opt seccomp=unconfined \
   -v "$(pwd)/bash_history:/root/.bash_history:rw" \
  --rm -it \
  newton2022/moonray:acl bash

#  -v "$(pwd)/deps_CMakeLists.txt:/source/building/Rocky9/CMakeLists.txt:ro" \
  
#  docker buildx build --platform arm64,amd64 -t newton2022/moonray:code --push   -f code.Dockerfile  .

# export ARMPL_ROOT=/opt/arm-performance-libs/armpl_26.01_gcc


# ccmake .. \
#   -DCMAKE_INSTALL_PREFIX=/opt/MoonRay/installs \
#   -DCMAKE_BUILD_TYPE=Release \
#   -DCMAKE_C_COMPILER=/usr/bin/gcc \
#   -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
#   -DENABLE_ARMPL_BACKEND=ON \
#   -DENABLE_MKLCPU_BACKEND=OFF \
#   -DENABLE_MKLGPU_BACKEND=OFF \
#   -DONEMATH_ENABLE_SYCL=OFF \
#   -DARMPL_ROOT=${ARMPL_ROOT} \
#   -DARMPL_INCLUDE=${ARMPL_ROOT}/include \
#   -DARMPL_LIBRARY=${ARMPL_ROOT}/lib/libarmpl_lp64_mp.so \
#   -DBUILD_FUNCTIONAL_TESTS=OFF
