# MoonRay Linux arm64 Port — Sprint Plan

Target: fully working **CPU renderer** (scalar + vectorized/NEON) on Linux aarch64, built inside
Docker, based on upstream 2026.29.1 (`OpenMoonray/`). Mali/GPU deferred to a final spike.
Estimates assume one experienced C++ developer; ranges cover rebase drift and arm-device build times.
Prior work is harvested in `arm64-port-salvage/` — most tasks are *rebase + verify*, not greenfield.

---

## Sprint 0 — Dependency image (Docker)  — **3–5 days**

The deps come first; nothing else can start without the image.

| # | Task | Est. |
|---|------|------|
| 0.1 | Fix `ubuntu.Dockerfile`: add `ENV INSTALL_ROOT=/opt/MoonRay/installs`, remove duplicated SIMDe block, align apt list with the verified `24.04` image's package set | 0.5 d |
| 0.2 | Fold **USD (monolithic) + OIDN 2.4.1 ARM64** into the image (currently only in `deps_CMakeLists.txt` runtime step) so the deps image is complete | 1 d |
| 0.3 | Build `moonray:deps-ubuntu26.04` for linux/arm64 (buildx or native); USD alone is hours on an arm box — run overnight | 1–2 d wall |
| 0.4 | Smoke-test image: `ispc --version`, `find_package` sanity for Embree/TBB/OIIO/OIDN/pxr, `checkInt128AtomicLockFree` try_run | 0.5 d |
| 0.5 | Push to Docker Hub + tag scheme (`deps-ubuntu26.04-v1`); document rebuild procedure | 0.5 d |

**Fallback:** `newton2022/moonray:base` (Rocky9) is verified current — usable on day 1 while the
Ubuntu image bakes (still needs USD+OIDN via `deps_CMakeLists.txt` in `/build`).

**Exit criteria:** container in which `cmake` configure of OpenMoonray finds every required dep.

---

## Sprint 1 — Build-system architecture axis  — **4–6 days**

Patch series: `port-2026.29.1/` (applied to `OpenMoonray/`).

| # | Task | Est. | Status |
|---|------|------|--------|
| 1.1 | `OMR_Platform.cmake` aarch64 branch (`CMAKE_SYSTEM_PROCESSOR`→`IsArm64`, `neon-i32x4`, `__ARM_NEON__` not `__AVX__`, Linux rpaths kept) | 0.5 d | ✅ done |
| 1.2 | Arch-guard all 15 `*CompileOptions.cmake`/MoonrayDso (`-march=core-avx2`→genex `armv8.2-a` on aarch64; drop redundant `-mavx/-mfma/-msse/-mf16c`) | 1.5–2 d | ✅ done |
| 1.3 | v3 **FindTBB fix**: `.so.12` soname (oneTBB 2021+) + aarch64 lib paths | 0.5 d | ✅ done |
| 1.4 | `MOONRAY_USE_OPTIX=NO` on aarch64 (done in 1.1); still: guard CUDA `check_language`, audit `MOONRAY_DENOISER_TARGET_ARCHITECTURE` (SSE default) | 0.5 d | ◑ partial |
| 1.5 | Fix `materialx_shaders` hardcoded `avx2-i32x8` → `${GLOBAL_ISPC_INSTRUCTION_SETS}` | 0.5 d | ✅ done |
| 1.6 | `ubuntu-arm64-release` preset (Ninja, NO_USD, OptiX/CUDA off, policy-min 3.5) + `scripts/check_arch_flags.sh` (fails if x86 flags leak) | 0.5 d | ✅ done |

**Exit criteria:** full configure passes in-container AND generated flags are pure aarch64.
**✅ SPRINT 1 COMPLETE (2026-07-23):** configure succeeds in `moonray:ubuntu-final`;
`check_arch_flags.sh` **PASS** (zero x86 flags, NEON confirmed). Extra fixes landed during
verification: Boost 1.90 removed-`system` component (3 files + header-only compat target),
FindTBB delegates to oneTBB config (fixes USD find_dependency clash), hardcoded `__AVX__`
in ArrasCore/MaterialxShaders CompileDefinitions → `${GLOBAL_CPP_FLAGS}`, preset generator
Ninja → Unix Makefiles (ninja `-t restat` segfaults under QEMU). All in `port-2026.29.1/`.

---

## Sprint 2 — Source fixes & first full build  — **8–12 days**

**✅ SPRINT 2 COMPLETE (2026-07-27):** `moonray` executable built AND runs (`-help` → EXIT=0)
on Linux arm64 under QEMU; 472 shared libraries; 26 error classes fixed (see BUILD-ERRORS.md).
Exit criteria exceeded — `moonray -help` ran in-container. Sole straggler: moonray_gui link retry.

The long tail. v2 died in scene_rdl2's ISPC/math layer; the core renderer has never compiled on arm64-Linux.

| # | Task | Est. |
|---|------|------|
| 2.1 | Rebase v1 scene_rdl2 patch: `emulation.h`/`avx2neon.h` type fixes, `TileExtrapolation.h` → `__builtin_ctzll`, `PackTiles`/`ShmFb`/`RunLenBitTable`/`Intrinsics.h` gate widening | 2–3 d |
| 2.2 | Fix remaining `__APPLE__`-as-arm proxies: `RecTime.h` (cntvct timer), `Atomic128.h` (casp path on Linux), `CPUID.cc` (`__x86_64__` guard), `Wait.h` (GCC `yield`) | 1–2 d |
| 2.3 | boost.predef SIMD-clash mitigation (`-U__SSE__…` on boost-including targets) — known fix, apply preemptively | 0.5 d |
| 2.3b | **oneTBB API port** (chose TBB 2022.3.0): `task_scheduler_init`→`global_control`/`task_arena` (RenderDriver, ThreadLocalState, ProgMcrtMergeComputation, TestMemPool); `tbb::atomic`→`std::atomic` (RenderGui). tbb::mutex is only deprecated, leave it | 1–1.5 d |
| 2.4 | Compile-error iteration through **scene_rdl2 math/ISPC → moonray core → moonshine → arras** (uncharted territory beyond scene_rdl2; budget for sse2neon gaps, OIIO 3.x API drift vs pinned 2.x-era code) | 3–5 d |
| 2.5 | Link phase: `-latomic`, undefined symbols, DSO proxy targets | 0.5–1 d |
| 2.6 | Build remaining executables: `moonray`, `moonray_gui` (Qt5), `hd_moonray` (USD), arras stack | 1 d |

**Exit criteria:** `moonray -info` runs in-container; all target libs/binaries build.

---

## Sprint 3 — Runtime validation  — **7–10 days**

| # | Task | Est. |
|---|------|------|
| 3.1 | First renders: scalar mode (`exec_mode=scalar`) on `testdata/` scenes; fix crashes | 1–2 d |
| 3.2 | Vectorized mode (NEON ISPC): render-diff vs scalar output; chase divergences into sse2neon/ISPC kernels | 2–3 d |
| 3.3 | Validate the `// TODO: Verify this` NEON paths: `RenderOutputWriter` FP16, `PackTiles`, `GammaF2C` LUT, `SnapshotUtil` | 1–2 d |
| 3.4 | Unit tests (cppunit targets) + RaTS regression subset on arm64; triage failures | 2–3 d |
| 3.5 | OIDN CPU denoise end-to-end check | 0.5 d |

**Exit criteria:** vectorized == scalar within tolerance on test scenes; test suite green (or waivers documented).

---

## Sprint 4 — Performance & CI  — **5–7 days**

| # | Task | Est. |
|---|------|------|
| 4.1 | Benchmark vs x86 reference (samples/sec); profile hotspots (perf on-device) | 1–2 d |
| 4.2 | Experiment: `MOONRAY_ISA_NEON2X` (VLEN=8) + Embree `NEON2X` — measure, keep if wins | 2–3 d |
| 4.3 | `-mcpu` tuning for target silicon; thread-affinity sanity on big.LITTLE | 1 d |
| 4.4 | CI: GitHub Actions arm64 workflow (build image + compile + smoke render) on the Build-OpenMoonRay-Arm64 repo | 1 d |

**Exit criteria:** reproducible CI-built arm64 artifacts; documented perf baseline.

---

## Sprint 5 (deferred) — Mali GPU spike — **2–3 weeks, go/no-go first**

Only after CPU port ships. Renderer is fully functional CPU-only; XPU adds speed, not features.

- Spike: Vulkan compute / `VK_KHR_ray_query` occlusion-ray backend implementing the ~10-method
  `GPUAccelerator` contract, mirroring `lib/rendering/rt/gpu/metal/` (~5–6 KLOC template).
- Go/no-go input: Sprint 4 benchmarks — on Mali-class SoCs the CPU load-balancer may win anyway;
  hardware ray query exists only on newer Immortalis parts.

---

## Totals

| Phase | Estimate |
|---|---|
| Sprint 0 (deps image) | 3–5 days |
| Sprint 1 (build system) | 4–6 days |
| Sprint 2 (source + first build) | 8–12 days |
| Sprint 3 (validation) | 7–10 days |
| Sprint 4 (perf + CI) | 5–7 days |
| **CPU port total** | **~5.5–8 working weeks** |
| Sprint 5 (Mali spike, optional) | +2–3 weeks after go decision |

Biggest schedule risks: (1) Sprint 2.4 — the never-compiled moonray core on a new arch;
(2) OIIO 3.x API drift vs what 2026.29.1 expects (upstream pins 2.4.x; deps image ships 3.1.10 —
may need to downgrade OIIO in the image, decide in Sprint 0.4); (3) slow native arm builds —
mitigate with ccache volume + overnight jobs.
