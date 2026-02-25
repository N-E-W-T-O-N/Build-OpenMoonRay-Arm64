#!/usr/bin/env bash
# reproducible SDK builder (up to OptiX headers)
# usage:
#   ./repro_sdk_builder.sh [--dry-run] [--prefix /opt/MoonRay/installs] [--only jsoncpp,opensubdiv,...] [--skip optix]
set -euo pipefail

######################
# 🎛️ Defaults (override via env or args)
######################
NINJA_VERSION="${NINJA_VERSION:-1.13.2}"
ISPC_VERSION="${ISPC_VERSION:-1.30.0}"
SIMDE_VERSION="${SIMDE_VERSION:-0.8.2}"
INSTALL_ROOT="${INSTALL_ROOT:-/opt/MoonRay/installs}"
CACHE_DIR="${CACHE_DIR:-$(pwd)/.cache}"
STATE_DIR="${STATE_DIR:-$(pwd)/.state}"
BUILD_DIR="$(pwd)/build"
VENV_DIR="$(pwd)/venv"
LOGFILE="${LOGFILE:-$(pwd)/build.log}"
DRY_RUN="${DRY_RUN:-0}"
ONLY="${ONLY:-}"   # comma-separated list of targets to run (default: all)
SKIP="${SKIP:-}"   # comma-separated list of targets to skip

# Versions / refs used for reproducibility (these match your Dockerfile inputs)
# For git repos we'll checkout these refs exactly
REFS_jsoncpp="1.9.6"
REFS_opensubdiv="v3_7_0"
REFS_onetbb="v2022.3.0"
REFS_openexr="v3.4.5"
REFS_random123="v1.14.0"
REFS_embree="v4.4.0"
REFS_ocio="v2.5.1"
REFS_oiio="v3.1.10.0"
REFS_glfw="3.4"
REFS_optix="v7.6.0"

# lockfile path
LOCKFILE="${LOCKFILE:-$(pwd)/repro-lock.json}"

# apt package list (your list merged)
PACKAGES="build-essential cmake meson tar unzip zip bison libjsoncpp-dev pkg-config libblosc-dev \
libboost-all-dev libcppunit-dev ccache libcurl4-openssl-dev libfmt-dev flex libfreetype6-dev g++ \
libgif-dev git lsb-release lua5.3 liblua5.3-dev make libssl-dev patch pybind11-dev python3 python3-dev \
wget zlib1g-dev freeglut3-dev libglfw3-dev libatomic1 libglvnd-dev libheif-dev libjpeg-dev \
libturbojpeg0-dev libmng-dev libmicrohttpd-dev libsquish-dev libtiff-dev uuid-dev libwebp-dev \
libraw-dev libegl1-mesa-dev libopenexr-dev libgbm-dev libgl1-mesa-dev libglu1-mesa-dev libosmesa6-dev \
libx11-dev libxcursor-dev libxi-dev libxinerama-dev libxmu-dev libxpm-dev libxrandr-dev \
libopenjp2-7-dev libopenvdb-dev libptexenc-dev ffmpeg liblog4cplus-dev autoconf automake libtool \
libwayland-dev libxkbcommon-dev wayland-protocols extra-cmake-modules qtbase5-dev qtscript5-dev"

# internal helpers
mkdir -p "$CACHE_DIR" "$STATE_DIR" "$BUILD_DIR"
: > "$LOGFILE"

echo "Logfile: $LOGFILE"
exec 3>&1 1>>"$LOGFILE" 2>&1   # redirect stdout/stderr to logfile; keep fd3 as console echo for interactive prompts

############################################
# 🧰 Helpers
############################################
# Helper: print to console (fd3) with emoji
info() { printf "\n📌 %s\n" "$*" >&3; }
step() { printf "\n➡️  %s\n" "$*" >&3; }
die() { printf "\n❌ %s\n" "$*" >&3; exit 1; }

############################################
# 🧭 Parse CLI args
############################################
# parse args (simple)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --prefix) INSTALL_ROOT="$2"; shift 2 ;;
    --cache) CACHE_DIR="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --skip) SKIP="$2"; shift 2 ;;
    --lockfile) LOCKFILE="$2"; shift 2 ;;
    --help|-h) cat >&3 <<'USAGE'
Usage: repro_sdk_builder.sh [options]
  --dry-run            : print commands but don't execute
  --prefix <path>      : install root (default /opt/MoonRay/installs)
  --only <csv>         : comma-separated targets to build (e.g. jsoncpp,embree)
  --skip <csv>         : comma-separated targets to skip
  --cache <dir>        : cache directory (default ./.cache)
  --lockfile <file>    : where to write reproducible lockfile (default repro-lock.json)
USAGE
  exit 0 ;;
    *) die "Unknown arg $1" ;;
  esac
done

############################################
# 🧪 Dry run executor
############################################
run() {
  # usage: run "command string..."
  local cmd="$*"
  printf "\n👉 %s\n" "$cmd" >&3
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "🧪 dry-run (skipped)\n" >&3
    return 0
  fi
  bash -c "$cmd"
}

############################################
# 🗣️ Interactive confirmation
############################################
# simple set helpers for only/skip
contains_csv() {
  local csv="$1" val="$2"
  [[ -z "$csv" ]] && return 1
  IFS=',' read -ra A <<< "$csv"
  for x in "${A[@]}"; do [[ "$x" == "$val" ]] && return 0; done
  return 1
}
should_run_target() {
  local t="$1"
  if contains_csv "$SKIP" "$t"; then return 1; fi
  if [[ -n "$ONLY" ]]; then
    contains_csv "$ONLY" "$t"
    return $?
  fi
  return 0
}

# caching + idempotency helpers
download_if_missing() {
  local url="$1" out="$2"
  if [[ -f "$out" ]]; then
    printf "📦 cache hit: %s\n" "$out" >&3
  else
    run "wget -q -O '$out' '$url'"
    # record checksum for lockfile
    sha256sum "$out" | awk '{print $1}' >> "$CACHE_DIR/checksums.txt"
  fi
}

git_clone_at_ref() {
  local repo="$1" dir="$2" ref="$3" shallow="${4:-1}"
  if [[ -d "$dir/.git" ]]; then
    printf "📦 git cached: %s\n" "$dir" >&3
  else
    if [[ "$shallow" == "1" ]]; then
      run "git clone --depth=1 --branch '$ref' '$repo' '$dir' || git clone '$repo' '$dir'"
    else
      run "git clone '$repo' '$dir'"
      run "cd '$dir' && git fetch --all && git checkout '$ref'"
    fi
  fi
  # record actual HEAD sha for lockfile
  if [[ -d "$dir/.git" ]]; then
    (cd "$dir" && git rev-parse HEAD) >> "$CACHE_DIR/git-shas.txt"
  fi
}

mark_done() { touch "$STATE_DIR/$1.done"; }
is_done() { [[ -f "$STATE_DIR/$1.done" ]]; }

# reproducible tar options
TAR_FLAGS="--sort=name --mtime='UTC 2025-01-01' --owner=0 --group=0 --numeric-owner"

# Start
info "Reproducible SDK builder starting"
info "INSTALL_ROOT: $INSTALL_ROOT"
info "CACHE_DIR: $CACHE_DIR  STATE_DIR: $STATE_DIR  BUILD_DIR: $BUILD_DIR  VENV: $VENV_DIR"
info "DRY_RUN: $DRY_RUN"

read -rp $'Continue? (y/N): ' yn
[[ "$yn" =~ ^[Yy]$ ]] || die "Aborted by user"

# Check required commands
CRITICAL_CMDS=(git wget tar gzip sha256sum python3)
MISSING=0
for c in "${CRITICAL_CMDS[@]}"; do
  if ! command -v "$c" &>/dev/null; then
    printf "❌ missing: %s\n" "$c" >&3
    MISSING=1
  else
    printf "✅ %-12s %s\n" "$c" "$(command -v "$c")" >&3
  fi
done

if [[ "$MISSING" -eq 1 ]]; then
  info "Attempt apt-get install of needed packages (requires sudo). This will install many packages."
  read -rp $'Install apt packages? (y/N): ' aptyn
  if [[ "$aptyn" =~ ^[Yy]$ ]]; then
    run "sudo apt-get update"
    run "sudo apt-get install -y $PACKAGES"
  else
    die "Missing tools; install them and rerun"
  fi
fi

# create venv and install meson/cmake into it
if [[ ! -d "$VENV_DIR" ]]; then
  step "Creating python venv at $VENV_DIR"
  run "python3 -m venv '$VENV_DIR'"
fi
PIP="$VENV_DIR/bin/pip"
PY="$VENV_DIR/bin/python"
run "'$PIP' install --upgrade pip setuptools wheel"
run "'$PIP' install meson cmake"

# Use venv meson if available
MESON_CMD="$VENV_DIR/bin/meson"
if [[ ! -x "$MESON_CMD" ]]; then MESON_CMD="meson"; fi

# ensure install root exists
run "sudo mkdir -p '$INSTALL_ROOT'"
run "sudo chown -R \"$(id -u):$(id -g)\" '$INSTALL_ROOT' || true"

# enable ccache if present
if command -v ccache &>/dev/null; then
  info "ccache detected; enabling for builds (if used by CMake)"
  export CC="ccache gcc"
  export CXX="ccache g++"
fi

############################################
# 📂 Prep
############################################

# helper: cmake build function (uses BUILD_DIR per target)
cmake_build_install() {
  local srcdir="$1" instprefix="$2" extra_cmake_args="${3:-}"
  mkdir -p "$srcdir/build"
  run "cd '$srcdir/build' && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX='$instprefix' $extra_cmake_args"
  run "cmake --build '$srcdir/build' -j$(nproc)"
  run "cmake --install '$srcdir/build'"
}

##################
# TARGETS (in order)
##################

# 0) SSE2NEON (header)
target="sse2neon"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: install sse2neon header"
    git_clone_at_ref "https://github.com/DLTcollab/sse2neon.git" "/tmp/sse2neon" "master"
    run "sudo mkdir -p /usr/local/include/sse2neon"
    run "sudo cp /tmp/sse2neon/sse2neon.h /usr/local/include/sse2neon/"
    mark_done "$target"
  fi
fi

# 1) Ninja binary (cached)
target="ninja"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: install ninja ${NINJA_VERSION}"
    ZIP="$CACHE_DIR/ninja-${NINJA_VERSION}.zip"
    download_if_missing "https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-linux-aarch64.zip" "$ZIP"
    run "unzip -o '$ZIP' -d /tmp"
    run "sudo mv /tmp/ninja /usr/local/bin/"
    run "sudo chmod +x /usr/local/bin/ninja"
    mark_done "$target"
  fi
fi

# 2) ISPC (cached tar)
target="ispc"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: install ispc ${ISPC_VERSION}"
    TAR="$CACHE_DIR/ispc-${ISPC_VERSION}.tar.gz"
    download_if_missing "https://github.com/ispc/ispc/releases/download/v${ISPC_VERSION}/ispc-v${ISPC_VERSION}-linux.aarch64.tar.gz" "$TAR"
    run "tar -xzf '$TAR' -C /tmp --strip-components=2 ispc-v${ISPC_VERSION}-linux.aarch64/bin/ispc"
    run "mkdir -p '$INSTALL_ROOT/bin'"
    run "mv /tmp/ispc '$INSTALL_ROOT/bin/'"
    run "chmod +x '$INSTALL_ROOT/bin/ispc'"
    mark_done "$target"
  fi
fi

# 3) Meson+pip already installed in venv above

# 4) SIMDE (meson build)
target="simde"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: build simde v${SIMDE_VERSION}"
    TAR="$CACHE_DIR/simde-${SIMDE_VERSION}.tar.gz"
    download_if_missing "https://github.com/simd-everywhere/simde/archive/refs/tags/v${SIMDE_VERSION}.tar.gz" "$TAR"
    run "rm -rf /tmp/simde-${SIMDE_VERSION} /tmp/simde-build"
    run "tar -xzf '$TAR' -C /tmp"
    run "'$MESON_CMD' setup /tmp/simde-build /tmp/simde-${SIMDE_VERSION} --prefix='$INSTALL_ROOT' --buildtype=release -Dtests=false"
    run "meson compile -C /tmp/simde-build -j$(nproc)"
    run "meson install -C /tmp/simde-build"
    mark_done "$target"
  fi
fi

# 5) JsonCpp
target="jsoncpp"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: build jsoncpp"
    git_clone_at_ref "https://github.com/open-source-parsers/jsoncpp.git" "/tmp/jsoncpp" "$REFS_jsoncpp" 0
    cmake_build_install "/tmp/jsoncpp" "$INSTALL_ROOT" "-DPYTHON_EXECUTABLE='$VENV_DIR/bin/python' -DJSONCPP_LIB_BUILD_SHARED=ON -DJSONCPP_WITH_PKGCONFIG_SUPPORT=OFF"
    mark_done "$target"
  fi
fi

# 6) OpenSubdiv (v3_7_0)
target="opensubdiv"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: build OpenSubdiv"
    git_clone_at_ref "https://github.com/PixarAnimationStudios/OpenSubdiv" "/tmp/opensubdiv" "$REFS_opensubdiv" 1
    mkdir -p /tmp/opensubdiv/build
    run "cd /tmp/opensubdiv/build && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX='$INSTALL_ROOT' -DPYTHON_EXECUTABLE='$VENV_DIR/bin/python' -DNO_PTEX=1 -DNO_OMP=1 -DNO_TBB=1 -DNO_CUDA=1 -DNO_GLFW_X11=1 -DNO_DOC=1 -DNO_OPENCL=1 -DNO_CLEW=1 -DNO_REGRESSION=1 -DNO_EXAMPLES=1 -DNO_TUTORIALS=1 -DNO_GLTESTS=1 -DNO_MACOS_FRAMEWORK=1 -DNO_METAL=1 -DNO_TESTS=1"
    run "cmake --build /tmp/opensubdiv/build -j$(nproc)"
    run "cmake --install /tmp/opensubdiv/build"
    mark_done "$target"
  fi
fi

# 7) oneTBB
target="onetbb"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: build oneTBB"
    git_clone_at_ref "https://github.com/uxlfoundation/oneTBB" "/tmp/onetbb" "$REFS_onetbb" 1
    mkdir -p /tmp/onetbb/build
    run "cd /tmp/onetbb/build && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX='$INSTALL_ROOT' -DTBB_TEST=OFF -DTBB_STRICT=OFF -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF -DCMAKE_CXX_FLAGS='-Wno-error=stringop-overflow'"
    run "cmake --build /tmp/onetbb/build -j$(nproc)"
    run "cmake --install /tmp/onetbb/build"
    mark_done "$target"
  fi
fi

# 8) OpenEXR
target="openexr"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: build OpenEXR"
    git_clone_at_ref "https://github.com/AcademySoftwareFoundation/openexr" "/tmp/openexr" "$REFS_openexr" 1
    cmake_build_install "/tmp/openexr" "$INSTALL_ROOT" "-DBUILD_SHARED_LIBS=OFF"
    mark_done "$target"
  fi
fi

# 9) Random123
target="random123"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: install Random123"
    git_clone_at_ref "https://github.com/DEShawResearch/random123" "/tmp/random123" "$REFS_random123" 1
    run "cd /tmp/random123 && make install-include prefix='$INSTALL_ROOT'"
    mark_done "$target"
  fi
fi

# 10) Embree
target="embree"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: build Embree"
    git_clone_at_ref "https://github.com/embree/embree" "/tmp/embree" "$REFS_embree" 1
    mkdir -p /tmp/embree/build
    run "cd /tmp/embree/build && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX='$INSTALL_ROOT' -DEMBREE_ISPC_SUPPORT=OFF -DEMBREE_ARM=ON -DEMBREE_SYCL_SUPPORT=OFF -DEMBREE_IGNORE_INVALID_RAYS=ON -DEMBREE_RAY_MASK=ON -DEMBREE_TUTORIALS=OFF -DBUILD_SHARED_LIBS=ON"
    run "cmake --build /tmp/embree/build -j$(nproc)"
    run "cmake --install /tmp/embree/build"
    mark_done "$target"
  fi
fi

# 11) OpenColorIO
target="ocio"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: build OpenColorIO"
    git_clone_at_ref "https://github.com/AcademySoftwareFoundation/OpenColorIO" "/tmp/ocio" "$REFS_ocio" 1
    mkdir -p /tmp/ocio/build
    run "cd /tmp/ocio/build && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX='$INSTALL_ROOT' -DOCIO_BUILD_APPS=OFF -DOCIO_BUILD_TESTS=OFF -DOCIO_BUILD_GPU_TESTS=OFF -DOCIO_BUILD_PYTHON=OFF -DOCIO_USE_SIMD=ON -DOCIO_BUILD_STATIC=OFF -DOCIO_WARNING_AS_ERROR=OFF -DBUILD_SHARED_LIBS=ON -DCMAKE_CXX_STANDARD=17"
    run "cmake --build /tmp/ocio/build -j$(nproc)"
    run "cmake --install /tmp/ocio/build"
    mark_done "$target"
  fi
fi

# 12) OpenImageIO
target="oiio"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: build OpenImageIO"
    git_clone_at_ref "https://github.com/OpenImageIO/oiio" "/tmp/oiio" "$REFS_oiio" 1
    mkdir -p /tmp/oiio/build
    run "cd /tmp/oiio/build && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX='$INSTALL_ROOT' -DOpenEXR_ROOT='$INSTALL_ROOT' -DUSE_QT=0 -DOpenImageIO_BUILD_MISSING_DEPS=all -DUSE_PYTHON=1 -DBUILD_DOCS=OFF -DOIIO_BUILD_TESTS=OFF -D__ARM_NEON__=1 -DOIIO_NO_SSE=1 -DOIIO_NO_AVX=1 -DOIIO_NO_AVX2=1 -DOIIO_NO_AVX512=1 -DOIIO_NO_F16C=1 -DSIMD_FLAGS='-march=armv8.2-a' -DCMAKE_CXX_FLAGS=\"-D__ARM_NEON__=1 -U__SSE__ -U__SSE2__ -U__AVX__ -U__AVX2__ -U__SSE4_1__ -U__SSE4_2__ -UFARMHASH_ASSUME_SSSE3 -UFARMHASH_ASSUME_SSE41\" -DCMAKE_C_FLAGS=\"-D__ARM_NEON__=1 -U__SSE__ -U__SSE2__ -U__AVX__ -U__AVX2__ -U__SSE4_1__ -U__SSE4_2__ -UFARMHASH_ASSUME_SSSE3 -UFARMHASH_ASSUME_SSE41\""
    run "cmake --build /tmp/oiio/build -j$(nproc)"
    run "cmake --install /tmp/oiio/build"
    mark_done "$target"
  fi
fi

# 13) GLFW
target="glfw"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: build GLFW"
    git_clone_at_ref "https://github.com/glfw/glfw" "/tmp/glfw" "$REFS_glfw" 1
    mkdir -p /tmp/glfw/build
    run "cd /tmp/glfw/build && cmake .. -DCMAKE_PREFIX_PATH='$INSTALL_ROOT' -DCMAKE_INSTALL_PREFIX='$INSTALL_ROOT' -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF -DGLFW_INSTALL=ON -DBUILD_SHARED_LIBS=ON"
    run "cmake --build /tmp/glfw/build -j$(nproc)"
    run "cmake --install /tmp/glfw/build"
    mark_done "$target"
  fi
fi

# 14) OptiX headers (copy only)
target="optix"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "$target: fetch OptiX headers"
    git_clone_at_ref "https://github.com/NVIDIA/optix-dev" "/tmp/optix" "$REFS_optix" 1
    run "mkdir -p '$INSTALL_ROOT/include'"
    run "cp -r /tmp/optix/include/* '$INSTALL_ROOT/include/'"
    mark_done "$target"
  fi
fi

####################
# SDK Packaging
####################
target="package_sdk"
if should_run_target "$target"; then
  if is_done "$target"; then step "$target: done; skipping"; else
    step "Creating reproducible SDK tarball"

    SDKNAME="moonray-sdk-$(date +%Y%m%d)-$(hostname -s).tar.gz"
    OUT="$PWD/$SDKNAME"

    # Use tar reproducible flags; copy install root into a temp dir to avoid absolute paths
    TMPPACK="$(mktemp -d)"
    run "mkdir -p '$TMPPACK/opt'"
    run "cp -a --no-preserve=ownership '$INSTALL_ROOT' '$TMPPACK/opt/'"

    # create lockfile with gathered info (versions + git shas + checksums)
    info "Generating lockfile: $LOCKFILE"
    {
      echo "{"
      echo "  \"generated_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
      echo "  \"install_root\": \"${INSTALL_ROOT}\","
      echo "  \"components\": {"
      # write the versions we used
      echo "    \"ninja\": \"${NINJA_VERSION}\","
      echo "    \"ispc\": \"${ISPC_VERSION}\","
      echo "    \"simde\": \"${SIMDE_VERSION}\","
      echo "    \"jsoncpp_ref\": \"${REFS_jsoncpp}\","
      echo "    \"opensubdiv_ref\": \"${REFS_opensubdiv}\","
      echo "    \"onetbb_ref\": \"${REFS_onetbb}\","
      echo "    \"openexr_ref\": \"${REFS_openexr}\","
      echo "    \"random123_ref\": \"${REFS_random123}\","
      echo "    \"embree_ref\": \"${REFS_embree}\","
      echo "    \"ocio_ref\": \"${REFS_ocio}\","
      echo "    \"oiio_ref\": \"${REFS_oiio}\","
      echo "    \"glfw_ref\": \"${REFS_glfw}\","
      echo "    \"optix_ref\": \"${REFS_optix}\""
      echo "  },"
      echo "  \"git_shas\": ["
      # dump git-shas file contents if available
      if [[ -f "$CACHE_DIR/git-shas.txt" ]]; then
        awk '{print "    \""$0"\","}' "$CACHE_DIR/git-shas.txt" | sed '$s/,$//'
      fi
      echo "  ],"
      echo "  \"tar_checksums\": ["
      if [[ -f "$CACHE_DIR/checksums.txt" ]]; then
        awk '{print "    \""$0"\","}' "$CACHE_DIR/checksums.txt" | sed '$s/,$//'
      fi
      echo "  ]"
      echo "}"
    } > "$LOCKFILE"
    printf "Lockfile written to %s\n" "$LOCKFILE" >&3

    run "cd '$TMPPACK' && tar $TAR_FLAGS -czf '$OUT' opt"
    run "rm -rf '$TMPPACK'"

    info "SDK tarball: $OUT"
    mark_done "$target"
  fi
fi

info "All done. build.log contains full details."
info "To reproduce later: use the same lockfile and rerun this script (it will reuse cached downloads in $CACHE_DIR and markers in $STATE_DIR)."

# Print summary to console from logfile tail
printf "\nLast 40 log lines:\n" >&3
tail -n 40 "$LOGFILE" >&3
