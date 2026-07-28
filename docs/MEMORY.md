# MoonRay Linux arm64 Port — Tricks & Notes

Working notes for porting OpenMoonRay to Linux aarch64 (+ Mali later). Companion docs:
[arm64-port-salvage/README.md](arm64-port-salvage/README.md) (recovered prior work),
[agent-reports/](agent-reports/) (full code analyses). Builds run inside Docker.

## The one root cause to never forget

`cmake_modules/cmake/OMR_Platform.cmake` decides architecture by **OS, not CPU**:
Darwin → arm64/NEON (`neon-i32x4`), anything else → x86 (`__AVX__` define + ISPC `avx2-i32x8`).
Every past attempt that failed at compile time failed here. The fix (exists as a patch in
`arm64-port-salvage/v1-oct2025-code-fixes/patches/cmake_modules.patch`):

```cmake
elseif(IsLinuxPlatform AND CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
    set(GLOBAL_CPP_FLAGS "")
    set(GLOBAL_ISPC_FLAGS -D__aarch64__ -D__ARM_NEON__)
    set(GLOBAL_ISPC_INSTRUCTION_SETS "neon-i32x4")
```

`GLOBAL_ISPC_INSTRUCTION_SETS` is **the** ISPC knob. Top-level variables like `ISPC_TARGET`,
`SIMD_FLAGS`, `MOONRAY_SIMD_NEON` are consumed by **nothing** — setting them does nothing (v3 mistake).

## Macro gotchas (each one cost days)

- **`__ARM_NEON` vs `__ARM_NEON__`**: GCC on Linux defines only `__ARM_NEON` (no trailing
  underscores). MoonRay code gates on `__ARM_NEON__` (AppleClang defines both). Add
  `-D__ARM_NEON__` globally for Linux-aarch64, or normalize the code.
- **boost.predef "Multiple SIMD architectures detected" (`boost/predef/hardware/simd.h:126`)**:
  happens when `__ARM_NEON__` is defined while sse2neon/avx2neon leak x86 macros (`__SSE__` etc.).
  Fix: add `-U__SSE__ -U__SSE2__ -U__SSE3__ -U__SSE4_1__ -U__SSE4_2__ -U__AVX__ -U__AVX2__`
  on aarch64 targets that include boost. (v1 did this in SceneRdl2/McrtDenoise/MoonshineUsd
  CompileOptions.)
- **`__APPLE__` used as an arm64 proxy** in ~8 files — on Linux-aarch64 these fall into x86 paths:
  `scene_rdl2/lib/common/fb_util/TileExtrapolation.h` (raw `bsfq` asm → use `__builtin_ctzll`),
  `rec_time/RecTime.h` (`__rdtscp`), `render/util/Atomic128.h` (ARMv8.1 `casp` gated on
  PLATFORM_APPLE), `moonray/lib/common/mcrt_util/CPUID.cc` (`<cpuid.h>`),
  `mcrt_util/Wait.h` (GCC path uses `__builtin_ia32_pause()` → need `yield`),
  `grid_util/PackTiles.cc` / `ShmFb.cc` (FP16 include guards). All fixed in
  `v1-oct2025-code-fixes/patches/moonray-scene_rdl2.patch` — rebase, don't rediscover.
- On `__aarch64__`, `Platform.hh` *pretends to be x86*: defines `__SSE4_2__` → `VLEN=4`, and the
  SIMD math classes compile through `scene_rdl2/lib/common/arm/{sse2neon.h,avx2neon.h,emulation.h}`.
  Don't "clean up" those fake SSE defines — the whole math layer depends on them.
- `avx2neon.h` has int32x4/int64x2 type mismatches under Linux GCC — v1 patch wraps results in
  `vreinterpretq_s64_s32` (and disables avx2neon entirely, SSE2NEON-only, since VLEN=4).

## Compiler/flag notes

- 15 `*CompileOptions.cmake` files hardcode `-march=core-avx2 -mavx -mfma -msse` in the
  GNU/Clang/Intel branches — fatal on aarch64 gcc. Replace with `-march=armv8-a` (v1 used
  armv8.2-a for scene_rdl2). AppleClang branches are clean (that's how mac works).
- **`-neon` is NOT a compiler flag** (v3 mistake — instant gcc error).
- FP16 conversions (`_mm_cvtps_ph`) → NEON `vcvt_f32_f16` paths need `-march=armv8.2-a+fp16`
  or the scalar fallback; several NEON alternates are marked `// TODO: Verify this` — written for
  mac, never validated on Linux: `RenderOutputWriter.cc`, `PackTiles.cc`, `RecTick.h`.
- `mcrt_denoise` has `MOONRAY_DENOISER_TARGET_ARCHITECTURE` (STRINGS SSE/AVX/AVX2, default SSE).
  SSE default configure-passes on arm (v3 evidence) but audit what flags it injects.
- Link `-latomic` on Linux (already handled for non-Darwin); int128 lock-free CAS try_run
  passes on ARMv8.1+ (`ATOMIC128_RUN_RESULT=1` on the Vicharak board).
- `MOONRAY_ISA_NEON2X` (Platform.hh:80) = dormant double-pumped NEON VLEN=8 mode; pairs with
  Embree `EMBREE_MAX_ISA=NEON2X`. Optimization phase only — get VLEN=4 working first.

## ISPC

- ISPC source (.ispc) is arch-clean; retargeting is purely `--target=neon-i32x4`.
- Linux uses CMake's native ISPC language support (the hand-rolled custom command with
  `--target-os=macos` is Xcode-generator-only — irrelevant in Docker).
- One rogue hardcode: `moonray/materialx_shaders/lib/map/CMakeLists.txt:31` pins `avx2-i32x8`
  (only matters if `BUILD_MATERIALX_SHADERS=ON`, default OFF).
- Official aarch64 Linux binaries exist: `ispc-v1.30.0-linux.aarch64.tar.gz`.

## Dependencies (proven arm64 matrix — all built successfully before)

| Dep | Version | Key flags |
|---|---|---|
| Embree | 4.4.0 | `-DEMBREE_ARM=ON -DEMBREE_ISPC_SUPPORT=OFF -DEMBREE_RAY_MASK=ON -DEMBREE_IGNORE_INVALID_RAYS=ON` (NEON2X: `-DEMBREE_MAX_ISA=NEON2X`) |
| ISPC | 1.30.0 | prebuilt linux.aarch64 tarball |
| oneTBB | **2022.3.0** (decided) | `-DTBB_TEST=OFF -DTBB_STRICT=OFF` — needs the FindTBB fix (below) |

**TBB version decision (2026-07-22): oneTBB 2022.3.0, NOT upstream's 2020.3.**
Reason: USD 26.03 targets oneTBB 2021+ (VFX Ref Platform CY2025) and was already built against
2022.3.0 in the image; USD + MoonRay must share ONE TBB ABI in-process. Cost: MoonRay 2026.29.1
still uses oneTBB-REMOVED APIs that must be ported (Sprint 2 task):
- `tbb::task_scheduler_init` (removed in 2021) → `tbb::global_control` + `tbb::task_arena`:
  `rndr/RenderDriver.h/.cc`, `mcrt_common/ThreadLocalState.cc`,
  `moonray_arras/.../ProgMcrtMergeComputation.h/.cc`, `scene_rdl2/tests/.../TestMemPool.cc`.
- `tbb::atomic<uint32_t>` (removed) → `std::atomic`: `moonray_gui/.../RenderGui.h`.
- `tbb::mutex`/`scoped_lock` are only DEPRECATED, not removed — compile fine (warnings silenced
  by -w); leave them. RenderDriver.cc comments already hint at the global_control migration.
| OpenImageIO | 3.1.10.0 | `-DOIIO_NO_SSE/AVX/AVX2/AVX512/F16C=1 -DSIMD_FLAGS=-march=armv8.2-a` + C/CXX flags `-D__ARM_NEON__=1 -U__SSE__ … -UFARMHASH_ASSUME_SSE41` |
| OpenColorIO | 2.5.1 | `-DOCIO_USE_SIMD=ON` (SSE/AVX auto-off on arm) |
| OIDN | 2.4.1 | `-DOIDN_ARCH=ARM64`, CPU device only, needs ISPC |
| OpenSubdiv | 3.7.0 | NO_TBB/OMP/CUDA/OPENCL/PTEX/METAL |
| OpenUSD | 25.11–26.03 | monolithic (`PXR_BUILD_MONOLITHIC=ON`); v26.03 config in salvage dep-configs |
| OpenEXR | 3.1.8 pin (Rocky) / distro (Ubuntu) | — |
| sse2neon | DLTcollab HEAD | header → /usr/local/include/sse2neon |

- **FindTBB fix** (`v3-mar2026-cmake/patches/cmake_modules.patch`): upstream FindTBB only knows
  `libtbb.so.2` (TBB 2020); oneTBB 2021+ ships `.so.12`. Patch adds soname fallbacks and
  reuses pre-existing imported targets. Do NOT use the `$HOME/.local` hardcoded stub variant.
- Optional/skip: CUDA+OptiX (`-DMOONRAY_USE_OPTIX=NO` — mandatory on arm64), MKL (auto-skipped),
  Amorphous (absent), ArmPL/ACL/oneDNN/oneMath (abandoned experiments — nothing needs them).

## Deps artifact flow (branch `26` of Build-OpenMoonRay-Arm64, Jul 2026)

- **Heavy image** `ubuntu.Dockerfile` (multi-stage base/tools/heavy): Ubuntu 26.04 + apt + ninja/ISPC
  1.31/sse2neon v1.9.1/SIMDe + **oneTBB 2022.3 + OpenSubdiv 3.7 + OIDN 2.5.0 baked in**.
  Tag: `newton2022/moonray:deps-heavy-ubuntu26.04`. **USD is NOT in the image** — too slow for CI;
  build locally with `scripts/build_usd.sh` (USD imaging requires OpenSubdiv → that's why
  OpenSubdiv is in the image, not the CI script; USD configure fails without it).
- **Light deps in CI** (`scripts/build_light_deps.sh` via `build-deps-artifact.yml`): Embree 4.4.1
  (ARM), OCIO 2.5.2, OIIO 3.1.15 (scrub flags), GLFW 3.4, Random123, OptiX headers.
  Pack script appends `-nousd` to the artifact label when USD is absent.
- **Workflows use NATIVE arm64 runners (`ubuntu-24.04-arm`)** — the old QEMU-based workflows were
  10–20× slower; that's why USD "took so much time" in CI.
- **HF artifact**: `scripts/pack_and_upload_deps.sh` → tar.zst of `/opt/MoonRay/installs` →
  `hf upload Prince-1/Codes <file> moonray-deps/<file> --token $HF_TOKEN`.
  Use **tar.zst, never zip** — zip breaks `.so` symlink chains and permission bits.
- **glibc caveat for native reuse**: binaries built on Ubuntu 26.04 need Ubuntu 26.04+ glibc on the
  device. The Vicharak board ran 24.04 (glibc 2.39) — either upgrade the board, run the same Docker
  image on it, or rebase the image on 24.04. Extract to the same prefix `/opt/MoonRay/installs`.
- OIDN: use the release `.src.tar.gz` (contains trained weights); a bare git clone lacks them.
- **USD build persistence (WSL)**: USD is a multi-hour build — mount for persistence + resume:
  - `-v moonray-installs:/opt/MoonRay/installs` — **named volume** (Docker seeds it from the image's
    baked-in deps on first mount, then persists USD installed into it). NEVER bind-mount an empty host
    dir here — it shadows the baked-in oneTBB/OpenSubdiv/OIDN and USD configure fails.
  - `-v /home/user/moonray-work:/work` + `WORK=/work` — keeps USD src + build tree on host; script is
    now resumable (reuses checkout, incremental cmake). Re-run `build_usd.sh` after a crash to continue.
  - **Use native ext4 (`/home/...`), NOT `/mnt/c` or `/mnt/d`** — drvfs is slow and breaks symlinks/case.
  - Pack from a container mounting the SAME `moonray-installs` volume (pack script tars that path).
- Version drift note: upstream 2026.29.1 pins ancient deps (Embree 4.2, ISPC 1.21, OIIO 2.4.8,
  USD 23.08, TBB 2020.3) — we intentionally run newer; OIIO 2.4→3.1 API drift is the main risk.

## USD version decision (2026-07-22, provisional)

Upstream 2026.29.1 validates against **USD 23.08** (PXR_VERSION 2308); we built **26.03** — a big
jump. hdMoonray source guards only reach ~2311 + a `PXR_VERSION>=2505 → find_package(Vulkan REQUIRED)`
hook, so it's tested ~23.11–25.05, NOT 26.03 → real API-drift risk in hdMoonray/moonshine_usd.
USD is OPTIONAL for the core renderer (only hdMoonray/moonshine_usd/moonray_sdr_plugins need it).
**Provisional plan: DEFER USD** — build core (moonray/scene_rdl2/moonshine/gui) with `-DNO_USD`
first to prove NEON rendering; keep USD 26.03 in the image; wire up Hydra later.
When USD IS enabled with ≥25.05: **add `libvulkan-dev` to the deps image** (hdMoonray CMake requires
it; Mali has Vulkan; aligns with future GPU work). Fallback if drift is too painful: rebuild USD 23.08
(but 23.08 predates oneTBB 2021 → would force TBB back to 2020.3, re-opening the TBB decision).

## Docker (build environment)

- Registry: `docker.io/newton2022/moonray`. **`:base` (Feb 2026, Rocky9) verified layer-by-layer
  identical to the clone's `Dockerfile`** — full toolchain + all deps above EXCEPT USD & OIDN.
  Usable immediately.
- USD + OIDN are built at runtime by `deps_CMakeLists.txt` into the `/build` volume — fold them
  into the next image so the deps image is complete.
- `ubuntu.Dockerfile` (ubuntu:26.04) bugs before building: **missing
  `ENV INSTALL_ROOT=/opt/MoonRay/installs`** (all install prefixes expand empty!), duplicated
  SIMDe RUN block. Tags `ubuntu`/`24.04` on the Hub are stale stubs — do not use.
- Working main configure line (v2/v3, adapt paths):
  `cmake /source -DCMAKE_PREFIX_PATH=/opt/MoonRay/installs -Dpxr_DIR=/opt/MoonRay/installs
  -DMOONRAY_USE_OPTIX=OFF -DCMAKE_CUDA_COMPILER=OFF -DCMAKE_BUILD_TYPE=Release
  -DBOOST_PYTHON_COMPONENT_NAME=python3XX -DABI_VERSION=0 -Wno-dev`
- Verify flags before building: check any generated
  `CMakeFiles/<tgt>.dir/flags.make` for `-march=core-avx2` / `-D__AVX__` — if present, the
  platform fix didn't take. (This exact check would have caught v3's zero-compile failure at
  configure time.)

## Sprint 1 rebase note

Apply only the **content edits** from the v1 salvage patches. The prior attempts' file
DELETIONS (Houdini `.hda` binaries in moonray_dcc_plugins, include symlinks, arras4_node
router) were drvfs/Windows-copy damage + graphics files the user never touched — NOT port
changes. Do not reapply any deletions. (`.deleted.txt` lists were removed from the bundle.)

## Furthest verified progress (baseline to beat)

v2 (Oct 2025, base c53bf67): all deps + arras + mcrt_denoise + most of scene_rdl2 compiled
(~15 .so); died in scene_rdl2's ISPC/math layer. The core `moonray/moonray` renderer has
**never compiled** on Linux arm64. GPU/XPU: OptiX & Metal only — CPU-only build is fully
functional (XPU adds speed, not features). Mali = future Vulkan backend mirroring
`lib/rendering/rt/gpu/metal/` (~5-6 KLOC); deferred until CPU port is validated.

## Logging in containers (cost 2 blind runs)

- `cmd > /build/x.log 2>&1` inside a container = **stdio block buffering** (~4KB): the log
  sits frozen mid-line for many minutes, and `docker logs` is empty because stdout was
  redirected away. Looks like a hang; isn't.
- Always: `stdbuf -oL -eL <cmd> 2>&1 | stdbuf -oL tee /build/x.log` → live in `docker logs`
  AND persisted on the mounted volume (survives container removal, which has eaten our
  diagnostics twice).
- Verify a "silent" process is alive with CPU time, not log output:
  `docker exec <c> ps -o etime,time,rss,cmd -p <pid>` — 394% CPU / 119min TIME = working fine.
- Wrapper implementing this: `render.sh <scene> <scalar|vectorized>`.
