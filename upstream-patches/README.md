# Upstream-worthy fixes (architecture-neutral)

These 8 patches (329 lines) fix bugs that are **not arm64-specific** — they affect upstream
MoonRay on x86 too, given a modern dependency stack. Extracted from the Linux arm64 port so they
can be submitted independently of it.

Apply inside the relevant submodule, e.g.:
```bash
cd moonray/moonray && git apply .../01-bakecamera-uninitialized-texturehandle.patch
```

## 01 — BakeCamera: uninitialized `mTextureHandle` (crash, OIIO ≥ 3.0)

`moonray/moonray` · `lib/rendering/pbr/camera/BakeCamera.h`

```cpp
NormalMap()
#   if OIIO_VERSION < OIIO_MAKE_VERSION(3,0,0)
    : mTextureHandle(nullptr)      // ← initializer trapped inside the guard
#   endif
{ }
```
On OIIO ≥ 3.0 the raw pointer is never initialized. `haveNormalMap()` tests only that handle;
garbage reads as non-null, so `createRayImpl` dereferences the genuinely-empty `mTextureSystem`
shared_ptr → **SIGSEGV in `TextureSystem::get_perthread_info`**.

*Repro (any arch):* build against OIIO ≥ 3.0, run RaTS `camera/bake/normal` or
`camera/bake/reflection`. Both crash.
*Fix:* initialize unconditionally; `haveNormalMap()` now requires handle **and** texture system.

## 02 / 02b — fp16 conversion out-of-bounds reads/writes (3 sites)

`RenderOutputWriter.cc`, `grid_util/PackTiles.cc`, `cmd/mcrt_cmd/shmFbDump/main.cc`

The NEON blocks (marked `// TODO: Verify this`) load/store 4-wide vectors through pointers to a
**single scalar**:
```cpp
vst1q_f32(&output, vcvt_f32_f16(vld1_u16(&h)));   // writes 16 bytes into a 4-byte float
```
That's a buffer overflow on any aarch64 build (Apple Silicon included), plus it doesn't compile
under GCC's stricter NEON type checking. *Fix:* dup the scalar, convert, extract lane 0.

## 03 — `NumaUtil`: `mbind()` failure is fatal → cannot render in a container

`scene_rdl2` · `lib/common/grid_util/NumaUtil.cc`

A failed `mbind()` throws `RuntimeError`, aborting the render. But `mbind` is legitimately
unavailable in containers without `CAP_SYS_NICE`, under seccomp filtering, in emulators, and on
kernels without `CONFIG_NUMA`. **MoonRay currently cannot render inside a stock Docker container
on any architecture.** NUMA binding is an optimization, not a correctness requirement.
*Fix:* warn once and continue with default kernel page placement.

## 04a/b/c — GCC 15: missing `<algorithm>`, `<functional>`, `<cstdint>`

`AffinityResourceControl.cc` (`std::sort`, `std::max_element`), `BinPacketDictionary.h`
(`std::function`), `mcrt_dataio/ClockDelta.h` (`uint64_t`), `arras_render/OrbitCam.h`
(`std::function`). Older libstdc++ pulled these in transitively; GCC 15 does not.

## 05 — Qt `emit` macro vs oneTBB ≥ 2021 `void emit()`

`moonray_gui` · `cmd/moonray_gui/CMakeLists.txt`

Qt defines `emit` as an empty macro; `oneapi/tbb/profiling.h` declares `void emit()`, which then
parses as `void ()`:
```
oneapi/tbb/profiling.h:229: error: expected unqualified-id before ')' token
```
Any TU including Qt before TBB fails. Upstream pins TBB 2020 today, so it will hit this on
**x86** the moment it moves to oneTBB 2021+. *Fix:* force-include the TBB header first on the
target (`-include oneapi/tbb/profiling.h`) — no source edits, covers generated MOC files.
The existing `QtQuirks.h` handles the sibling `slots`/`signals` clashes the same way.

---

Discovered while porting OpenMoonRay 2026.29.1 to Linux arm64 against OIIO 3.1, oneTBB 2022.3,
USD 26.03, Boost 1.90, GCC 15. Full port: https://github.com/N-E-W-T-O-N/Build-OpenMoonRay-Arm64
