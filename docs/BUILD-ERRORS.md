
## Upstream merge — 2026-08-20 (cmake_modules, scene_rdl2)

Two submodules had drifted 1 commit each since v2026.29.1, and upstream had touched exactly one
file in each — the same two files this port modifies. `git submodule update --remote` refused to
proceed ("local changes would be overwritten"), which was git protecting the work, not a failure.

Resolved by 3-way merge (stash → checkout new commit → stash pop), **0 conflicts**. Both sides kept:

| file | upstream brought | we keep |
|---|---|---|
| `cmake_modules/cmake/FindTBB.cmake` | `cmake_minimum_required 3.1 → 3.5` (CMake 4 support) | oneTBB CONFIG delegation, aarch64 lib paths, `.so.12` soname |
| `scene_rdl2/mod/python/py_scene_rdl2/CMakeLists.txt` | `add_library SHARED → MODULE`, `Python_FOUND` guard, explicit LIBRARY/RUNTIME output dirs | `system` dropped from Boost components + header-only `Boost::system` shim (Boost >= 1.89) |

Note: upstream's 3.1→3.5 bump is the *proper* fix for the CMake-4 policy error this port had worked
around with `CMAKE_POLICY_VERSION_MINIMUM=3.5` in the preset. That workaround can likely be dropped
once the whole dependency chain is on >= 3.5.

Submodule pointers now: `cmake_modules` → 1b1b7af, `moonray/scene_rdl2` → 1229d3e.
All other 14 submodules were already at their remote tips. 90 port-modified files preserved.

## Golden-image (RaTS) validation + real upstream bug — 2026-07-28

**RaTS subset: 28/28 pass** (was 26/28). First rigorous validation: renders compared against
DreamWorks' reference images.

Two prerequisites had to be fixed first — one mine, one upstream's:

| # | Issue | Class | Action |
|---|-------|-------|--------|
| 30 | All 3417 RaTS tests "failed": `No such file or directory: 'moonray'` | **my harness error** — RaTS invokes `moonray`/`hd_render` by bare name; I set LD_LIBRARY_PATH + RDL2_DSO_PATH but never PATH | **FIXED**: export PATH with the built exe dirs. Nothing was wrong with the port. |
| 31 | `camera/bake/{normal,reflection}`: **SIGSEGV** in `BakeCamera::createRayImpl` → `TextureSystem::get_perthread_info+0` | **UPSTREAM BUG, not arm64**: in `BakeCamera.h` the `NormalMap()` initializer `: mTextureHandle(nullptr)` sits *inside* `#if OIIO_VERSION < 3.0`, so on OIIO>=3.0 the raw pointer is uninitialized garbage → `haveNormalMap()` (tests handle only) returns true → dereferences the empty `mTextureSystem` shared_ptr. Crashes identically on x86 with OIIO>=3.0. | **FIXED**: initialize `mTextureHandle` unconditionally; `haveNormalMap()` now requires handle **and** texture system |

Also (hygiene, not the cause): OIIO macro-scrub guards were present in only 10 of 22 files that
include OIIO headers — inconsistent `__SSE__`/`__AVX__` state across TUs. Now 18/22 (remaining 4
are OSL headers + an unused brdf_cmd tool). **My ODR hypothesis for the bake crash was wrong** —
making it consistent did not fix the crash; the uninitialized pointer did.


## GUI fixes (v1.1, 2026-07-28)
| # | Component | Error | Class | Action |
|---|-----------|-------|-------|--------|
| 28 | moonray_gui 3D-LUT embedding | `objcopy: architecture i386 unknown` | 2nd hardcoded-x86 objcopy site (1st was pbr sampler tables) | **FIXED** arch-conditional |
| 29 | moonray_gui Qt TUs | `oneapi/tbb/profiling.h:229: expected unqualified-id before ')'` — Qt's empty `emit` macro mangles oneTBB's `void emit()` | **NOT arm64-specific**: consequence of oneTBB 2021+; upstream will hit it on x86 too when it leaves TBB 2020 | **FIXED**: force-include `-include oneapi/tbb/profiling.h` on the target so TBB parses before the macro exists; zero source edits, covers generated MOC files. (Existing `QtQuirks.h` handles the sibling `slots`/`signals` clashes.) |

Both GUIs build: `moonray_gui` (Qt, 3.7 MB) and `moonray_gui_v2` (GLFW/ImGui, 2.0 MB).
# 🎉🎉 FIRST RENDER (2026-07-27): MoonRay RENDERS AN IMAGE on Linux arm64

`moonray -in testdata/box.rdla -size 64 80 -exec_mode scalar` → **`box_smoke.exr` written, EXIT=0**
- valid OpenEXR, dataWindow 0,0..63,79 (**64x80**), channels R G B A + I, lin_rec709_scene
- render prep 0.797s · render 70.4s · total 71.3s (under QEMU emulation, 4 threads)
- error #27 (NUMA `mbind` ENOSYS) warned and continued as designed — no abort
- artifacts: `logs/box_smoke.exr`, `logs/smoke.log`

**End-to-end proven on aarch64: RDL2 scene parse → DSO load (177 dirs) → geometry → Embree BVH
→ path tracing (6 bounces) → shading → framebuffer → OpenEXR output.**

# 🎉 OUTCOME (2026-07-27): MoonRay COMPILES AND RUNS on Linux arm64

`/build/moonray/moonray/cmd/raas_cmd/moonray/moonray -help` → full usage, **EXIT=0**.
472 shared libraries. 26 error classes fixed across the campaign (all below).
Final two: #25 RenderOutputWriter fp16 TODO-blocks (OOB + missing reinterpret, same as
PackTiles); #26 Ubuntu's default `--as-needed` dropped pbr from executable link lines,
breaking the rt↔pbr circular design → `-Wl,--no-as-needed` in GLOBAL_LINK_FLAGS (aarch64).
Sole straggler: `moonray_gui` (one QEMU link flake — retries clean).

# First arm64 build — error harvest (run 1, QEMU, -k keep-going)

Build: detached container `moonray-build`, `cmake --build /build -j4 -- -k`,
log at `build/build.log`. Source: patched OpenMoonray 2026.29.1.

| # | Component | Error | Class | Action |
|---|-----------|-------|-------|--------|
| 1 | moonray_sdr_plugins / discoveryPlugin.cpp | cc1plus killed (ICE, signal) | QEMU/OOM artifact | retry `-j2` or on native board; not a source bug |
| 2 | moonray_sdr_plugins / parserPlugin.cpp | `pxr/usd/ndr/declare.h` missing | **USD drift**: ndr removed in USD 25.02+ (merged into sdr); code targets USD 23.08 | **FIXED** (agent-ported ndr→sdr: Parse→ParseShaderNode, GetInvalidShaderNode, SdrShaderNodeDiscoveryResult, GetTypeAsSdfType→SdrSdfTypeIndicator, plugInfo.json.in "bases", CMake `ar ndr sdr`→`ar sdr`; all 5 TUs syntax-PASS vs USD 26.03) |

| 3 | scene_rdl2 / shmFbDump/main.cc | `x86intrin.h` not found | `__APPLE__`-as-arch include guard | **FIXED** (→ `__aarch64__` gate); swept tree: all other x86 includes properly guarded |
| 4 | arras4_athena / UdpSyslog_boost.h | `boost/asio/io_service.hpp` missing | Boost drift: io_service removed in 1.87+ | **FIXED** (→ `io_context`) |

| 5 | scene_rdl2 / tests/common/simd/test_simd.cc | `__m256`/`_mm256_*`/SVML `atan(__m128)` undeclared | x86-only test; guard was `!__APPLE__` (OS-as-arch again) — mac compiles it out the same way | **FIXED** (→ `__x86_64__` gate, mirrors mac behavior) |

## Run 1 verdict (ended [9%], 59 errors)

**Every error traced to the 5 issues above — zero unknowns.** ISPC NEON kernels compiled and
`scenerdl2_common_math_ispc_tests` LINKED (the layer v2 died in). Build stalled early because
CMake Makefile directory-targets cascade: failing scene_rdl2 *tests* blocked all downstream dirs.
Run 2 relaunched incrementally with fixes #3/#4/#5 applied (only ndr + possible ICE remain).

## Run 2 (incremental, fixes applied)
| # | Component | Error | Class | Action |
|---|-----------|-------|-------|--------|
| 6 | shmFbDump/main.cc:27 (h16tof32) | `uint16x4_t`→`float16x4_t` conversion; latent OOB write (vst1q 4 floats into 1) | GCC NEON strictness + real bug | **FIXED** (vreinterpret + lane extract) |
| 7 | UdpSyslog_boost.h:41 | `resolver::query` removed | Boost 1.87+ drift (same wave as io_service) | **FIXED** (modern resolve() overload) |
| — | discoveryPlugin.cpp "ICE" from run 1 | actually the same ndr error | reclassified: USD drift, not QEMU | folds into #2 (ndr→sdr port) |

| 8 | AffinityResourceControl.cc | std::sort/max_element missing | GCC-15 missing `<algorithm>` | **FIXED** |
| 9 | BinPacketDictionary.h | std::function missing | GCC-15 missing `<functional>` | **FIXED** |
| 10 | PackTiles.cc ftoh/htof | NEON type error + OOB accesses ("TODO: Verify this" block) | GCC NEON strictness + real bug | **FIXED** (dup/convert/lane) |
| 11 | OIIO farmhash → `immintrin.h` (ImageDisplayFilter + 12 more OIIO consumers) | Platform.hh ISA-masquerade macros leak into OIIO headers; clang-only include-guard trick fails on GCC | mac workaround insufficient | **FIXED**: added `#undef __SSE__…__AVX2__` to all 13 guard blocks. WATCH: undefs in shared headers (Texture.h etc.) change later `#if __SSE4_1__` branches to fallback paths — semantically fine, revisit if odd errors |
| 12 | py_scene_rdl2 "failure" | none of its own — skipped via failed prerequisite (grid_util) | cascade, not an error | no action |
| 13 | MeshLight.so link, ThrowDuringConstruct attributes.cc, SphereLight proxy | collect2/cc1plus segfaults | QEMU flakes | retry in run 3 |
| — | `CACHE_LINE_SIZE` redefined 64→128 warning (Platform.h vs Platform.hh) | benign but inconsistent | warning | later: unify (alignment audit, Sprint 3) |

## Run 3 (ended; only 2 raw error lines — tree almost clean)
| # | Component | Error | Class | Action |
|---|-----------|-------|-------|--------|
| 14 | mcrt_common/Ray.h:395 | static assert `sizeof(RayDifferential)*VLEN == sizeof(RayDifferentialv)` → 1216 vs 1280 | **CACHE_LINE_SIZE=128 is Apple-M-series-specific**; keyed off `__ARM_NEON__` so Linux arm64 inherited it; Cortex-A/RK3588 use 64B lines. CACHE_ALIGN rounded the SoA wrapper up | **FIXED**: Platform.hh now 128 only on `__APPLE__&&__ARM_NEON__`, else 64 (+#undef kills the redefine warning). Probe-verified 1216==1216 |
| 15 | mcrt_dataio ClockDelta.h | `uint64_t` not declared | GCC-15 missing `<cstdint>` | **FIXED** |
| 16 | py_scene_rdl2 | links `libboost_python27` (!) — stale component default `python` | Ubuntu 26.04 ships `libboost_python314` | **FIXED**: preset sets `BOOST_PYTHON_COMPONENT_NAME=python314` |

## Run 4 (in progress)
| # | Component | Error | Class | Action |
|---|-----------|-------|-------|--------|
| 17 | hd_render link: mass undefined pxr symbols | USD 26.x **monolithic export quirk**: component INTERFACE targets (arch/tf/hd/…) never link `usd_m` itself | USD packaging bug | **FIXED**: `set_property(TARGET arch APPEND … usd_m)` after each of the 3 `find_package(pxr)` sites — all components reach arch transitively |
| ✓ | mcrt_common | Ray.h assert passed, tests linking | — | CACHE_LINE_SIZE fix confirmed in-build |
| ✓ | boost_python314 | on hd_render link line | — | preset fix confirmed in-build |

## Runs 5–8 + self-heal loop
| # | Component | Error | Class | Action |
|---|-----------|-------|-------|--------|
| 18 | regen: pxr garch → `OpenGL::GL` not found | usd_m interface walk reaches garch | consequence of #17 fix | **FIXED**: `find_package(OpenGL)` guard inside the 3 usd_m snippets |
| 19 | regen: rats `find_package(Python)` fails on re-run | FindPython cached-artifact clash (multiple component sets) | CMake quirk | **FIXED**: `Python_EXECUTABLE=/usr/bin/python3` pinned in cache + preset |
| 20 | render_logging exported no symbols; hydramoonray/grid_util mystery failures | **zero-byte `.o` corpses**: QEMU-killed cc1plus leaves empty timestamped objects that make trusts and links | QEMU + make hazard | **FIXED**: sweep `find /build -name '*.o' -size 0 -delete`; now automated between passes (self-heal loop) |
| 21 | OrbitCam.h/.cc std::function | GCC-15 `<functional>` | **FIXED** | |
| ✓ | **Run 8: ZERO real errors.** sdr plugins BUILT (port works), hydramoonray BUILT, render_logging restored. Only QEMU ICEs remain → self-heal loop (build+sweep ×5) running | | | |

| 22 | hdMoonray RendererPlugin (both variants) | abstract class: USD 26 made `IsSupported(HdRendererCreateArgs const&,std::string*)` pure virtual | Hydra API drift | **FIXED**: version-guarded override chain (≥2603 / ≥2302 / older) |
| 23 | pbr sampler embedding (90%, the last error) | `objcopy: architecture i386 unknown` — sampler .bin→.o embedding hardcoded `--binary-architecture=i386 --output-target=elf64-x86-64` | build system x86 hardcode | **FIXED**: arch-conditional (`aarch64`/`elf64-littleaarch64` on arm) in pbr/CMakeLists.txt |

## Final stretch (2026-07-27)
| # | Component | Error | Class | Action |
|---|-----------|-------|-------|--------|
| 24 | geom/prim/MotionTransform.h via geom/Types.h | `simdf` does not name a type | **self-inflicted**: our OIIO-guard `#undef __SSSE3__…` (fix #11) leaked past the OIIO includes; geom/Types.h dispatches its simdf/simdi/simdb typedefs on those macros | **FIXED**: restore-block re-defining Platform.hh's masquerade macros immediately after the OIIO includes in all 13 guard files (push/pop pattern), + defensive `#elif defined(__aarch64__)` → ssef fallback in geom/Types.h |
| ✓ | objcopy sampler fix (#23) confirmed: build passed 90% → 92%, sampler tables embedded | | | |

**STATUS: 92%, 776 targets, 462+ .so. ONE fix pending compile (#24), zero other known errors
in the whole tree. Final v2 self-heal loop running — expected outcome: BUILD CLEAN + the
`moonray` executable (container prints executable check + .so count at end).**

Notes:
- `-k` keeps the build going past failures; each entry above only skips its own target.
- Core renderer (scene_rdl2 → moonray) has no USD dependency — separate track.
