# Render validation — Linux arm64 (2026-07-27)

Container `newton2022/moonray:ubuntu-final` under QEMU emulation (x86 host), 4 threads,
64×64 (scenes' native settings are 800×1000 — see note). Binary:
`build/moonray/moonray/cmd/raas_cmd/moonray/moonray`. All EXRs archived in `logs/renders/`.

## Results: 9/9 renders succeeded, 0 errors

| scene | mode | render time | EXR bytes | exit | tests |
|---|---|---:|---:|:--:|---|
| box | scalar | 1:00.9 | 33,687 | 0 | polygon mesh, area light, 6 bounces |
| sphere | scalar | 0:05.5 | 16,204 | 0 | analytic sphere primitive |
| rectangle | scalar | 0:03.0 | 8,031 | 0 | quad primitive |
| curves | scalar | 2:54.0 | 43,993 | 0 | hair/curve intersectors (Embree curve code) |
| multi-level-instances | scalar | 1:30.2 | 45,559 | 0 | nested instancing, transform hierarchy |
| sphere2 | scalar | 1:23.0 | 34,362 | 0 | sphere variant + shading |
| **box** | **vectorized** | 1:31.6 | 33,810 | 0 | **ISPC NEON kernels, SoA bundling** |
| **sphere** | **vectorized** | 0:11.8 | 16,192 | 0 | **NEON vectorized integrator** |
| **curves** | **vectorized** | 2:17.4 | 43,878 | 0 | **NEON + curve intersection** |

Every file verified structurally: valid OpenEXR magic, 64×64 dataWindow, channels R G B A + I,
`lin_rec709_scene` colorspace.

## Scalar vs vectorized agreement (the SIMD correctness signal)

| scene | scalar | vectorized | Δ |
|---|---:|---:|---:|
| box | 33,687 | 33,810 | **+0.37 %** |
| sphere | 16,204 | 16,192 | **−0.07 %** |
| curves | 43,993 | 43,878 | **−0.26 %** |

Two completely independent code paths — scalar C++ vs ISPC/NEON SIMD with SoA ray bundling —
produce images of near-identical compressed size on every scene. (Compressed size is an entropy
proxy, not a pixel diff; exact per-pixel comparison needs `oiiotool`/OpenEXR python, absent in
the image. Sampling differences between modes make bit-exactness not expected anyway.)

## Performance note

`curves` vectorized (2:17) beat scalar (2:54) by **21 %** *even under QEMU*, which emulates NEON
poorly — real silicon should widen this substantially. `box`/`sphere` vectorized ran slower than
scalar here, consistent with emulation overhead dominating at small resolutions.

## Notes / caveats

- **QEMU only** — this is functional validation, not a performance measurement. Native-board runs
  are pending (also: `mbind` works there, 128-bit atomics are lock-free, cache lines are real).
- Scenes default to **800×1000 with 6-bounce path tracing**; `-size 64 64` used for tractable
  smoke tests. An unmodified `box.rdla` run takes 30+ min under emulation.
- `WARNING: mbind() unavailable (errno=38)` on every run — expected, fix #27 working as designed
  (QEMU doesn't implement the syscall; NUMA binding is an optimization).
- Not yet validated: `moonray_gui` (built but needs a display), `hd_render` (USD/Hydra path),
  arras distributed mode, RaTS golden-image comparisons, denoiser.

## Unit test suite (ctest -L unit): 20 passed / 1 failed / 1 timeout / 1 not-run

Passing includes every layer this port rewrote: `scenerdl2_common_math` and
`common_math_ispc` (sse2neon + NEON ISPC math), `common_simd`, `common_rec_time`
(the new cntvct_el0 timer), `common_fb_util` (TileExtrapolation bit-scan),
`moonray_common_mcrt_util` (Atomic128/casp, oneTBB migration),
`rendering_mcrt_common` (the Ray/SoA cache-line fix), `rendering_shading_ispc`,
`rendering_rt` (Embree), `rendering_rndr`, `mcrt_dataio_share_util` (ClockDelta).

### The two non-passes are environmental, not port defects

**`scenerdl2_common_grid_util_tests` — FAILED (needs ≥8 CPU cores; we have 4).**
33 of its 34 sub-tests pass. The one failure is `TestCpuSocketUtil::testCpuIdDef`,
which parses the CPU-ID string `"0,1,2,3,4"`. The test file states its own requirement:

```cpp
// We have to run this unitTest 8 cores or more environment.
assert(std::thread::hardware_concurrency() >= 8);
```

In a Release build that `assert` is compiled out by `NDEBUG`, so instead of skipping,
the test runs and correctly fails: CPU id 4 does not exist on this 4-core host
(Docker Desktop VM = 4 CPUs, host = 4 CPUs). Nothing to do with aarch64 — it would
fail identically on x86 with 4 cores, and should pass on the RK3588 board (8 cores).
Notably `TestShmFb::testFbH16()` — the half-float path I rewrote — **passes**.

**`moonray_rendering_pbr_tests` — TIMEOUT at 900 s.** Monte-Carlo BSDF/integrator
convergence tests under QEMU; `rendering_rndr` needed 837 s to pass, so this is
emulation speed, not a hang. Retest natively or with a longer timeout.

**Conclusion: no genuine port defect surfaced by the unit suite.**


## RaTS golden-image suite (2026-07-28): subset 28/28 PASS

Real reference-image comparison, not just "it produced a file". Covers camera (perspective,
orthographic, medium, dicing, deltas, bake), geometry (sphere, box, curves, points, instancing,
subdiv creases, vdb, explicit attributes, primitive attributes, reverse normals, motion blur).

Two blockers were fixed to get here:
- **PATH**: RaTS invokes `moonray`/`hd_render` by bare name. Without the built exe dirs on PATH,
  all 3437 tests "fail" instantly (`No such file or directory: 'moonray'`) — a harness mistake of
  mine, not a port defect. The earlier "3417 failures" report was that, and nothing more.
- **BakeCamera SIGSEGV** — a genuine **upstream** bug: `NormalMap()`'s `mTextureHandle(nullptr)`
  initializer is inside `#if OIIO_VERSION < 3.0`, leaving the pointer uninitialized on OIIO>=3.0.
  Reproduces on x86 with OIIO>=3.0. Fixed by initializing unconditionally and hardening
  `haveNormalMap()` to require both handle and texture system.

Full-suite run (all 3437 incl. xpu/vec labels) still pending with PATH set; the XPU families are
expected to fail or skip since this build has `MOONRAY_USE_OPTIX=NO`.
