cd /build/oneMath/
mkdir one*/build
mkdir build
cd build
ccmake ..
ccmake ..  -DCMAKE_INSTALL_PREFIX=/opt/MoonRay/installs -DBUILD_FUNCTIONAL_TESTS=OFF -DCMAKE_SYSTEM_PROCESSOR=AARCH64  -DENABLE_ARMPL_BACKEND=ON -DENABLE_MKLCPU_BACKEND=OFF -DCMAKE_CXX_COMPILER=/opt/MoonRay/installs/bin/ispc openOneAPI -DARMPL_LIBRARY=/opt**
ls
cd ..
rm -rf build/
mkdir mathBuild
cd mathBuild/
export ARMPL_ROOT=/opt/arm/armpl_26.01_gcc
  ccmake ..   -DCMAKE_INSTALL_PREFIX=/opt/MoonRay/installs   -DBUILD_FUNCTIONAL_TESTS=OFF   -DENABLE_ARMPL_BACKEND=ON   -DENABLE_MKLCPU_BACKEND=OFF   -DENABLE_ROCRAND_BACKEND=OFF   -DENABLE_ROCSOLVER_BACKEND=OFF   -DENABLE_ROCSPARSE_BACKEND=OFF \ 
  -DENABLE_MKLCPU_BACKEND=OFF   -DENABLE_MKLCPU_BACKEND=OFF   -DONEMATH_ENABLE_SYCL=OFF   -DCMAKE_C_COMPILER=gcc   -DCMAKE_CXX_COMPILER=g++   -DISPC_EXECUTABLE=/opt/MoonRay/installs/bin/ispc   -DARMPL_ROOT=${ARMPL_ROOT}
c
clear
export ARMPL_ROOT=/opt/arm/armpl_26.01_gcc
  ccmake ..   -DCMAKE_INSTALL_PREFIX=/opt/MoonRay/installs   -DBUILD_FUNCTIONAL_TESTS=OFF   -DENABLE_ARMPL_BACKEND=ON   -DENABLE_MKLCPU_BACKEND=OFF   -DENABLE_ROCRAND_BACKEND=OFF   -DENABLE_ROCSOLVER_BACKEND=OFF   -DENABLE_ROCSPARSE_BACKEND=OFF \ 
  -DENABLE_MKLCPU_BACKEND=OFF   -DENABLE_MKLGPU_BACKEND=OFF   -DONEMATH_ENABLE_SYCL=OFF   -DCMAKE_C_COMPILER=gcc   -DCMAKE_CXX_COMPILER=g++   -D ICX_PATH =/opt/MoonRay/installs/bin/ispc   -DARMPL_ROOT=${ARMPL_ROOT}
/opt/MoonRay/installs/bin/ispc --version
cmake ..
cmake .. -DICX_PATH=/opt/MoonRay/installs/bin/ispc
cmake .. -DICX_PATH=/opt/MoonRay/installs/bin/
python
python3
whereis python
whereis python3
clear
export ARMPL_ROOT=/opt/arm/armpl_26.01_gcc
cmake ..   -DCMAKE_INSTALL_PREFIX=/opt/MoonRay/installs   -DCMAKE_BUILD_TYPE=Release   -DCMAKE_C_COMPILER=/usr/bin/gcc   -DCMAKE_CXX_COMPILER=/usr/bin/g++   -DENABLE_ARMPL_BACKEND=ON   -DENABLE_MKLCPU_BACKEND=OFF   -DENABLE_MKLGPU_BACKEND=OFF   -DENABLE_ROCRAND_BACKEND=OFF   -DENABLE_ROCSOLVER_BACKEND=OFF   -DENABLE_ROCSPARSE_BACKEND=OFF   -DENABLE_CUBLAS_BACKEND=OFF   -DENABLE_CUFFT_BACKEND=OFF   -DENABLE_CURAND_BACKEND=OFF   -DENABLE_CUSOLVER_BACKEND=OFF   -DENABLE_CUSPARSE_BACKEND=OFF   -DONEMATH_ENABLE_SYCL=OFF   -DARMPL_ROOT=${ARMPL_ROOT}   -DBUILD_FUNCTIONAL_TESTS=OFF
ccmake ..   -DCMAKE_INSTALL_PREFIX=/opt/MoonRay/installs   -DCMAKE_BUILD_TYPE=Release   -DCMAKE_C_COMPILER=/usr/bin/gcc   -DCMAKE_CXX_COMPILER=/usr/bin/g++   -DENABLE_ARMPL_BACKEND=ON   -DENABLE_MKLCPU_BACKEND=OFF   -DENABLE_MKLGPU_BACKEND=OFF   -DENABLE_ROCRAND_BACKEND=OFF   -DENABLE_ROCSOLVER_BACKEND=OFF   -DENABLE_ROCSPARSE_BACKEND=OFF   -DENABLE_CUBLAS_BACKEND=OFF   -DENABLE_CUFFT_BACKEND=OFF   -DENABLE_CURAND_BACKEND=OFF   -DENABLE_CUSOLVER_BACKEND=OFF   -DENABLE_CUSPARSE_BACKEND=OFF   -DONEMATH_ENABLE_SYCL=OFF   -DARMPL_ROOT=${ARMPL_ROOT}   -DBUILD_FUNCTIONAL_TESTS=OFF
rm CMakeCache.txt 
export ARMPL_ROOT=/opt/arm-performance-libs/armpl_26.01_gcc
ccmake ..   -DCMAKE_INSTALL_PREFIX=/opt/MoonRay/installs   -DCMAKE_BUILD_TYPE=Release   -DCMAKE_C_COMPILER=/usr/bin/gcc   -DCMAKE_CXX_COMPILER=/usr/bin/g++   -DENABLE_ARMPL_BACKEND=ON   -DENABLE_MKLCPU_BACKEND=OFF   -DENABLE_MKLGPU_BACKEND=OFF   -DONEMATH_ENABLE_SYCL=OFF   -DARMPL_ROOT=${ARMPL_ROOT}   -DARMPL_INCLUDE=${ARMPL_ROOT}/include   -DARMPL_LIBRARY=${ARMPL_ROOT}/lib/libarmpl_lp64_mp.so   -DBUILD_FUNCTIONAL_TESTS=OFF sddsawde
export ARMPL_ROOT=/opt/arm-performance-libs/armpl_26.01_gcc
cmake ..   -DCMAKE_INSTALL_PREFIX=/opt/MoonRay/installs   -DCMAKE_BUILD_TYPE=Release   -DCMAKE_C_COMPILER=/usr/bin/gcc   -DCMAKE_CXX_COMPILER=/usr/bin/g++   -DENABLE_ARMPL_BACKEND=ON   -DENABLE_MKLCPU_BACKEND=OFF   -DENABLE_MKLGPU_BACKEND=OFF   -DONEMATH_ENABLE_SYCL=OFF   -DARMPL_ROOT=${ARMPL_ROOT}   -DARMPL_INCLUDE=${ARMPL_ROOT}/include   -DARMPL_LIBRARY=${ARMPL_ROOT}/lib/libarmpl_lp64_mp.so   -DARMPL_VERSION=26.01   -DBUILD_FUNCTIONAL_TESTS=OFF
rm CMakeCache.txt 
cmake ..   -DCMAKE_INSTALL_PREFIX=/opt/MoonRay/installs   -DCMAKE_BUILD_TYPE=Release   -DCMAKE_C_COMPILER=/usr/bin/gcc   -DCMAKE_CXX_COMPILER=/usr/bin/g++   -DENABLE_ARMPL_BACKEND=ON   -DENABLE_MKLCPU_BACKEND=OFF   -DENABLE_MKLGPU_BACKEND=OFF   -DONEMATH_ENABLE_SYCL=OFF   -DARMPL_ROOT=${ARMPL_ROOT}   -DARMPL_INCLUDE=${ARMPL_ROOT}/include   -DARMPL_LIBRARY=${ARMPL_ROOT}/lib/libarmpl_lp64_mp.so   -DARMPL_VERSION=26.01   -DBUILD_FUNCTIONAL_TESTS=OFF
rm CMakeCache.txt 
export ARMPL_ROOT=/opt/arm-performance-libs/armpl_26.01_gcc
cmake ..   -DCMAKE_INSTALL_PREFIX=/opt/MoonRay/installs   -DCMAKE_BUILD_TYPE=Release   -DCMAKE_C_COMPILER=/usr/bin/gcc   -DCMAKE_CXX_COMPILER=/usr/bin/g++   -DENABLE_ARMPL_BACKEND=ON   -DENABLE_MKLCPU_BACKEND=OFF   -DENABLE_MKLGPU_BACKEND=OFF   -DONEMATH_ENABLE_SYCL=OFF   -DARMPL_INCLUDE_DIR=${ARMPL_ROOT}/include   -DARMPL_LIBRARIES=${ARMPL_ROOT}/lib/libarmpl_lp64_mp.so   -DARMPL_SKIP_VERSION_CHECK=ON   -DBUILD_FUNCTIONAL_TESTS=OFF
cmake ..   -DCMAKE_INSTALL_PREFIX=/opt/MoonRay/installs   -DCMAKE_BUILD_TYPE=Release   -DCMAKE_C_COMPILER=/usr/bin/gcc   -DCMAKE_CXX_COMPILER=/usr/bin/g++   -DENABLE_ARMPL_BACKEND=ON   -DENABLE_MKLCPU_BACKEND=OFF   -DENABLE_MKLGPU_BACKEND=OFF   -DONEMATH_ENABLE_SYCL=OFF   -DARMPL_INCLUDE_DIR=${ARMPL_ROOT}/include   -DARMPL_LIBRARIES=${ARMPL_ROOT}/lib/libarmpl_lp64_mp.so   -DARMPL_SKIP_VERSION_CHECK=ON   -DBUILD_FUNCTIONAL_TESTS=OFF
rm CMakeCache.txt 
rm CMakeCache.txt cmake/ CMakeFiles/
rm CMakeCache.txt cmake/ CMakeFiles/ -rf
ccmake ..   -DCMAKE_INSTALL_PREFIX=/opt/MoonRay/installs   -DCMAKE_BUILD_TYPE=Release   -DCMAKE_C_COMPILER=/usr/bin/gcc   -DCMAKE_CXX_COMPILER=/usr/bin/g++   -DENABLE_ARMPL_BACKEND=ON   -DENABLE_MKLCPU_BACKEND=OFF   -DENABLE_MKLGPU_BACKEND=OFF   -DONEMATH_ENABLE_SYCL=OFF   -DBUILD_FUNCTIONAL_TESTS=OFF
cmake --build .
grep -Rl "sycl.hpp" . 
grep -Rl "sycl.hpp" ..
cd /source
grep -Rl "armpl.h" ..
exit
bash
exit
ls /opt/MoonRay/installs/
ls /opt/MoonRay/installs/bin 
ls /opt/MoonRay/installs/bin/
ispc
tree /opt/MoonRay/installs
find
clear
find /opt/MoonRay/installs
ls /opt/arm-performance-libs/
ls /opt/arm-gnu-toolchain/arm-gnu-toolchain-15.2.rel1-aarch64-aarch64-none-linux-gnu/
ls /opt/arm-gnu-toolchain/arm-gnu-toolchain-15.2.rel1-aarch64-aarch64-none-linux-gnu/li
ls /opt/arm-gnu-toolchain/arm-gnu-toolchain-15.2.rel1-aarch64-aarch64-none-linux-gnu/lib
ls /opt/arm-gnu-toolchain/arm-gnu-toolchain-15.2.rel1-aarch64-aarch64-none-linux-gnu/bin/
clear
ls
pwd
cd /ls /opt/arm/armpl_26.01_gcc/lib
ls /opt/arm/armpl_26.01_gcc/lib
ls /opt/arm-performance-libs/armpl_26.01_gcc/lib/
mkdir /build/oneDNN/dnnBuild
cd /build/oneDNN/dnnBuild
ls /opt/arm-compute-library/arm_compute-v52.8.0-linux-aarch64-cpu-gpu-bin/
ccmake ..  -DCMAKE_SYSTEM_PROCESSOR=AARCH64   -DDNNL_BUILD_DOC=OFF  -DDNNL_BUILD_EXAMPLES=OFF -DNNL_BUILD_TESTS=OFF  -DDNNL_AARCH64_USE_ACL=ON -DACL_ROOT_DIR= /opt/arm-compute-library/arm_compute-v52.8.0-linu
x-aarch64-cpu-gpu-bin/
ccmake ..  -DCMAKE_SYSTEM_PROCESSOR=AARCH64   -DDNNL_BUILD_DOC=OFF  -DDNNL_BUILD_EXAMPLES=OFF -DNNL_BUILD_TESTS=OFF  -DDNNL_AARCH64_USE_ACL=ON -DACL_ROOT_DIR= /opt/acl/  -DDNNL_ACL_VERSION=52
rm -rf CMakeCache.txt src/ CMakeFiles/
clear
rm -rf build
cmake ..   -DACL_ROOT_DIR=/opt/acl   -DACL_INCLUDE_DIR=/opt/acl/include   -DACL_LIBRARY=/opt/acl/lib/armv8a-neon-cl/libarm_compute.so   -DACL_GRAPH_LIBRARY=/opt/acl/lib/armv8a-neon-cl/libarm_compute_graph.so
crm -rf build
cmake ..   -DACL_ROOT_DIR=/opt/acl   -DACL_INCLUDE_DIR=/opt/acl/include   -DACL_LIBRARY=/opt/acl/lib/armv8a-neon-cl/libarm_compute.so   -DACL_GRAPH_LIBRARY=/opt/acl/lib/armv8a-neon-cl/libarm_compute_graph.so
ccmake ..   -DACL_ROOT_DIR=/opt/acl   -DACL_INCLUDE_DIR=/opt/acl/include   -DACL_LIBRARY=/opt/acl/lib/armv8a-neon-cl/libarm_compute.so   -DACL_GRAPH_LIBRARY=/opt/acl/lib/armv8a-neon-cl/libarm_compute_graph.so
ccmake ..  -DCMAKE_SYSTEM_PROCESSOR=AARCH64 
ccmake ..  -DCMAKE_SYSTEM_PROCESSOR=AARCH64 
ccmake --build .
cmake --build .
cmake /source/building/Rocky9
cd /build
mv oneDNN/dnnBuild/CMakeCache.txt DnnCMakeCache.txt
rm -rf oneDNN/
mv oneMath/mathBuild/CMakeCache.txt mathCMakeCache.txt
rm -rf oneMath/
exit
tree
cd /build/deps/
cmake --build .
cmake /source/building/Rocky9
cmake /source/building/Rocky9
cmake --build .
mkdir -p /opt/MoonRay/installs/bin/ispc
cmake --build .
rm -rf ISPC-prefix/ CMakeCache.txt 
cmake --build .
cmake /source/building/Rocky9
cmake --build .
rm -rf SIMDe-prefix/
cmake --build .
rm -rf CMakeCache.txt MesonTool-prefix/ SIMDe-prefix/ 
cmake --build .
rm -rf CMakeCache.txt MesonTool-prefix/ SIMDe-prefix/ 
cmake /source/building/Rocky9
cmake --build .
cd ..
cd deps/
rm -rf CMakeCache.txt SIMDe-prefix/
rm -rf CMakeCache.txt SIMDe-prefix/ CMakeFiles/
cmake /source/building/Rocky9
cmake --build .
exit
mkdir -p /opt/MoonRay/installs/bin 
cd /build/deps/
cmake --build .
clear
cmake --build .
exit
cd /build/deps/
cmake --build .
cp ISPC-prefix/src/ISPC/bin/ispc /opt/MoonRay/installs/bin/ispc
cp ISPC-prefix/src/ISPC/bin/ispc /opt/MoonRay/installs/bin/ispc
cmake --build .
cmake --build .
cp ISPC-prefix/src/ISPC/bin/ispc /opt/MoonRay/installs/bin/ispc
mkdir /opt/MoonRay/installs/bin/
cp ISPC-prefix/src/ISPC/bin/ispc /opt/MoonRay/installs/bin/ispc
cmake --build .
ls /usr/lib64/libturbojpeg.so.
ls /usr/lib64
find /usr/lib64 -name "libturbojpeg.so.*"
find /usr/lib64 -name "libturbojpeg*"
find /usr/lib64 -name "libturbo*"
find /usr/lib64 -name "lib*"
find /usr/lib64 -name "libt*"
find /usr/lib64 -name "libj*"
cat /usr/lib64/cmake/libjpeg-turbo/libjpeg-turboConfig.cmake 
find /usr -name "libturbo*"
find /usr -name "libjpeg*"
exit
exit
mkdir /opt/MoonRay/installs/bin/
cp ISPC-prefix/src/ISPC/bin/ispc /opt/MoonRay/installs/bin/ispc
exit
bash
exit
cmake --build .
exit
mkdir /opt/MoonRay/installs/bin/
mkdir -r /opt/MoonRay/installs/bin/
mkdir --help  /opt/MoonRay/installs/bin/
mkdir -p  /opt/MoonRay/installs/bin/
cp ISPC-prefix/src/ISPC/bin/ispc /opt/MoonRay/installs/bin/ispc
exit
mkdir -p  /opt/MoonRay/installs/bin/
cp ISPC-prefix/src/ISPC/bin/ispc /opt/MoonRay/installs/bin/ispc
cmake --build .
exit
mkdir -p  /opt/MoonRay/installs/bin/
cp ISPC-prefix/src/ISPC/bin/ispc /opt/MoonRay/installs/bin/ispc
ispc
/opt/MoonRay/installs/bin/ispc
ls/opt/MoonRay/installs/
 ls /opt/MoonRay/installs/
ninja
meson
exit
cmake --build .
cmake --build .
cmake --build .
exit
cmake --build .
exit
cmake --build .
exit
cmake --build .
exit
