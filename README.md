# MoonRay on Linux arm64 (aarch64)

A working port of DreamWorks' **[MoonRay](https://github.com/dreamworksanimation/openmoonray)**
production path-tracing renderer to **Linux arm64**, plus the build environment and portable
binaries. Based on OpenMoonRay **2026.29.1**.

Upstream supports x86-64 Linux and Apple-Silicon macOS. Its build system infers architecture from
the OS (`Darwin` ⇒ arm64/NEON, anything else ⇒ x86/AVX2), so Linux-on-arm64 was not a reachable
combination. This repo makes it one.

## Quick start — no build, no dependencies

Grab a bundle from the [latest release](../../releases) and run it:

```bash
chmod +x moonray-cli-arm64.run
./moonray-cli-arm64.run -in scene.rdla -out image.exr -size 512 512
```

| asset | contents | download |
|---|---|---|
| `moonray-cli-arm64.run` | headless renderer + 176 RDL2 DSO plugins | 234 MB |
| `moonray-gui-arm64.run` | `moonray_gui` (Qt), `moonray_gui_v2` (ImGui), `moonray`, Qt platform plugins, Mesa GL | 362 MB |

Each is a self-extracting archive carrying **its own dynamic loader and libraries**, so the host's
glibc / Qt / Mesa versions don't matter — only an aarch64 Linux kernel. Verified building on
Ubuntu 26.04 and running on Ubuntu 22.04 (glibc 2.35) with nothing installed.

```bash
./moonray-cli-arm64.run -help              # all renderer options
./moonray-cli-arm64.run --extract-only     # unpack without running
MOONRAY_DIR=/opt/mr ./moonray-cli-arm64.run   # choose where it unpacks

./moonray-gui-arm64.run                                              # GUI, software GL
LIBGL_ALWAYS_SOFTWARE=0 LIBGL_DRIVERS_PATH= ./moonray-gui-arm64.run  # GUI, hardware GL (Mali)
```

Useful render flags: `-size W H` · `-threads N` · `-exec_mode scalar|vectorized` (vectorized =
NEON SIMD) · `-in`/`-out` may repeat.

## Testing on your device

**[docs/TESTING.md](docs/TESTING.md)** — smoke test, the 361-scene RaTS corpus, scalar-vs-vectorized
cross-check, GUI with hardware GL, unit tests, and what should change on real silicon vs emulation.

```bash
./scripts/rats_native.sh ./moonray-cli-arm64.run source/rats scalar
```

> **Note on golden images:** RaTS reference images ("canonicals") are **not** in this repo —
> DreamWorks distributes them separately, and `rats/cmake/diff.cmake` requires
> `$RATS_CANONICAL_DIR`. Without them you get crash detection and timings across 361 scenes, not
> pixel-exact comparison. See docs/TESTING.md.

## Repository layout

| path | what |
|---|---|
| `source/` | the patched OpenMoonRay tree that builds and renders on arm64 |
| `port-patches/` | the port as 17 git patches against upstream 2026.29.1 |
| `upstream-patches/` | 8 **architecture-neutral** bug fixes worth sending upstream |
| `docs/` | testing guide, fix ledger, render results, bundle internals, architecture map |
| `scripts/` | native RaTS runner, container-with-display helper, render/build helpers |
| `ubuntu.Dockerfile` | Ubuntu 26.04 arm64 deps image (all non-USD dependencies) |
| `usd.Dockerfile`, `final.Dockerfile` | USD carrier image and the assembled build image |
| `.github/workflows/` | CI: builds the deps image on native arm64 runners |

## Building it yourself

```bash
docker pull newton2022/moonray:ubuntu-final     # deps prebuilt (TBB, Embree, OIIO, OIDN, USD…)
./run.sh                                        # enters the container with source/ + build/ mounted
# inside:
cmake --preset ubuntu-arm64-release -B /build /source
cmake --build /build -j$(nproc)
/scripts/check_arch_flags.sh /build             # fails if any x86 flag leaked in
```

## What the port required

31 classes of fix. The ones that mattered most:

- **`OMR_Platform.cmake`** — an actual architecture axis (`CMAKE_SYSTEM_PROCESSOR`), ISPC retargeted
  to `neon-i32x4`, `-march=armv8.2-a` across 15 CompileOptions files, OptiX off on arm
- **`CACHE_LINE_SIZE` 128 → 64** on non-Apple ARM — 128-byte lines are an Apple-M trait; the wrong
  value broke the C++↔ISPC SoA layout contract (`RayDifferentialv` static assert)
- **`objcopy` binary embedding** made arch-conditional in **two** places (pbr sampler tables, GUI
  3D LUTs) — both hardcoded `i386`/`elf64-x86-64`
- **`__APPLE__`-as-architecture** fixes: x86 `bsfq` asm → `__builtin_ctzll`, `__rdtscp` →
  `cntvct_el0`, ARMv8.1 `casp` atomics, `pause` → `yield`, x86 CPUID gating
- **NEON correctness**: sse2neon/avx2neon type fixes; **three fp16 conversion sites had latent
  out-of-bounds accesses**
- **Dependency drift**: USD 26 (ndr→sdr port, monolithic link, Hydra `IsSupported`), Boost 1.87/1.90
  (`io_service`, `resolver::query`, `system`), oneTBB 2021+ (`task_scheduler_init`, `tbb::atomic`),
  OIIO 3.x, GCC 15 includes
- **`NumaUtil`**: `mbind()` failure no longer aborts — MoonRay previously could not render inside a
  stock container on *any* architecture

Full ledger with symptoms and diagnoses: **[docs/BUILD-ERRORS.md](docs/BUILD-ERRORS.md)**.

## Status

| | |
|---|---|
| Builds | ✅ `moonray`, `moonray_gui`, `moonray_gui_v2`, 472 shared libraries |
| Renders | ✅ scalar **and** vectorized (NEON); meshes, spheres, quads, curves/hair, instancing |
| Unit tests | 20/23 (2 non-passes environmental — needs ≥8 cores / emulator timeout) |
| GUI | ✅ display-verified: window opened, path-traced sphere rendered |
| GPU / XPU | ❌ CPU only — needs CUDA+OptiX (x86/NVIDIA). A Vulkan backend would be the Mali path; not implemented |
| Native perf | ⬜ pending — validation so far is under QEMU emulation |
| Golden-image diffs | ⬜ pending — requires RaTS canonicals (not publicly distributed) |

## License

MoonRay is Apache-2.0 (DreamWorks Animation). This repository carries the same license for the
port changes.
