# MoonRay Linux arm64 port — patch series (base: 2026.29.1)

Fresh port work implemented directly on upstream 2026.29.1 (`../OpenMoonray`), using the
historical `../arm64-port-salvage/` patches as reference. These are the **Sprint 1
(build-system architecture axis)** changes — see `../SPRINTS.md`.

## How to apply
Each patch applies inside its submodule (paths are submodule-relative):

```bash
cd <checkout>/cmake_modules            && git apply .../patches/cmake_modules.patch
cd <checkout>/moonray/scene_rdl2       && git apply .../patches/moonray-scene_rdl2.patch
# ...one per submodule listed below
```
(The working tree at `../OpenMoonray` already has them applied.)

## What's in this series (Sprint 1.1 / 1.2 / 1.5)

**`cmake_modules.patch`** — the root-cause fix, two files:
- `OMR_Platform.cmake`: adds `IsArm64` (from `CMAKE_SYSTEM_PROCESSOR`), a new
  `elseif(IsLinuxPlatform AND IsArm64)` branch (ISPC `neon-i32x4`, `GLOBAL_CPP_FLAGS
  __ARM_NEON__` instead of `__AVX__`, Linux ELF rpaths/new-dtags kept), and defaults
  `MOONRAY_USE_OPTIX=NO` on aarch64. x86 and Darwin branches unchanged.
- `MoonrayDso.cmake`: arch-conditional march (below).

**13 `*CompileOptions.cmake` + MoonrayDso** — every hardcoded `-march=core-avx2` replaced by
`$<IF:$<STREQUAL:${CMAKE_SYSTEM_PROCESSOR},aarch64>,-march=armv8.2-a,-march=core-avx2>`, and the
redundant `-mavx/-mfma/-msse/-mf16c` sub-flags dropped (all implied by core-avx2 on x86; fatal
on aarch64). AppleClang branches were already clean and are untouched. armv8.2-a chosen for FP16
support (matches the OIIO deps build; RK3588 and all real aarch64 targets support it).

**`moonray-materialx_shaders.patch`** — `lib/map/CMakeLists.txt` now uses
`${GLOBAL_ISPC_INSTRUCTION_SETS}` instead of a hardcoded `avx2-i32x8` ISPC target.

**`cmake_modules.patch` also includes `FindTBB.cmake`** (Sprint 1.3): prefer soname
`libtbb.so.12` (oneTBB 2021+, we use 2022.3) with `.so.2` fallback; add `aarch64-linux-gnu`
lib search paths.

**`00-superproject.patch`** (Sprint 1.6) — adds a `ubuntu-arm64-release` configure+build preset
to `CMakeLinuxPresets.json`: Ninja generator, `NO_USD=TRUE` (core-renderer-first plan),
`MOONRAY_USE_OPTIX=NO`, `CMAKE_CUDA_COMPILER=OFF`, `CMAKE_POLICY_VERSION_MINIMUM=3.5` (CMake 4.x
accepts the submodules' old `cmake_minimum_required`). Note: Python/boost-python component names
are left to defaults — set them if/when USD/python bindings are enabled for the container's python.

Also `scripts/check_arch_flags.sh` (in the Build-OpenMoonRay-Arm64 repo): run after configure to
fail loudly if any `-march=core-avx2`/`__AVX__`/`avx2-i32x8` leaked into the generated build files.

## Design notes / rationale
- Genex keyed on `CMAKE_SYSTEM_PROCESSOR` (a guaranteed-global cmake var) rather than the
  `IsArm64` variable, so it's robust regardless of whether OMR_Platform ran in that scope.
- `__ARM_NEON__` is defined the same way x86 defines `__AVX__` because GCC on aarch64 only
  defines `__ARM_NEON` (no trailing underscores) while MoonRay code gates on `__ARM_NEON__`.
- NOT yet done (Sprint 2, at first compile): boost.predef `-U__SSE__…` mitigation; the
  `__APPLE__`-as-arm source fixes (TileExtrapolation/RecTime/Atomic128/CPUID/Wait); the oneTBB
  API port (task_scheduler_init→global_control, tbb::atomic→std::atomic); OIIO 2.4→3.1 drift.

## Verification done
- `OMR_Platform.cmake` branch logic traced for Linux/aarch64, Linux/x86, Darwin (cmake unavailable
  in the authoring sandbox — verify with a real configure in the deps container).
- All 15 genex sites confirmed: applied once, no nesting, no residual bare `-march=core-avx2`,
  no leftover x86 sub-flags. (One file, McrtMessagesCompileOptions.cmake, was initially rewritten
  through a self-referential `include -> .` symlink and re-applied cleanly.)
