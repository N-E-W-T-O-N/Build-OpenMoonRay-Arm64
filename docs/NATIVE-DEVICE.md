# Native test device — Vicharak RK3588 AXON

The reference board this port is validated on.

| | |
|---|---|
| Board | **Vicharak RK3588 AXON V0.2 LINUX** |
| SoC | Rockchip **RK3588** — 4× Cortex-A76 + 4× Cortex-A55 (**8 cores**) @ 2.26 GHz |
| Architecture | **ARMv8.2-A** (A76/A55) — NEON, FP16, LSE atomics all present |
| RAM | 7.74 GiB, swap disabled |
| GPU | **Mali-G610** — `panthor` DRM 1.2.0 kernel driver, Mesa **25.2.8 Panfrost** |
| OS | **Ubuntu 24.04.4 LTS (Noble)** aarch64, glibc 2.39 |
| Kernel | **6.1.75-axon** (vendor) |
| Display | X11 (Marco/MATE), 1024×768 |
| NPU | RKNPU 0.9.8 present (not used by MoonRay) |

## Why the architecture matters

A76/A55 is **ARMv8.2-A**, which validates two aggressive choices in this port:

- **`-march=armv8.2-a`** across the CompileOptions files — legal here
- **LSE `casp` 128-bit atomics** (`Atomic128.h`, gated on `__aarch64__`) — `casp` is ARMv8.1-A,
  so it is legal on A76/A55

⚠️ **Both would be illegal instructions on an ARMv8.0-A board** — e.g. RK3399 (Cortex-A72/A53,
as in the Vicharak *Vaaman*). Running these binaries there would `SIGILL` immediately. A truly
portable build needs `-march=armv8-a` plus `casp` gated on `__ARM_FEATURE_ATOMICS`. Not yet done —
this port targets ARMv8.2-A hardware.

Kernel NEON is confirmed live: the kernel's own xor benchmark picks `arm64_neon` at 9393 MB/s.

## GPU / OpenGL: what actually runs on Mali-G610

Panfrost on G610 provides **OpenGL 3.1 core (GLSL 1.40)** and **OpenGL ES 3.1** — direct
rendering, 7927 MB video memory, unified. Both GUIs were checked against that ceiling:

| binary | needs | on Mali-G610 hardware GL |
|---|---|---|
| `moonray_gui` (Qt) | `#version 330 core` → **OpenGL 3.3** | ❌ **shaders will not compile** — GL 3.1 < 3.3 |
| `moonray_gui_v2` (GLFW/ImGui) | GL 3.0 / `#version 130` on Linux | ✅ **should work** |

So on this board:

```bash
# Qt viewer — MUST use the bundled software GL (llvmpipe gives GL 4.5)
./moonray-gui-arm64.run -in scene.rdla

# ImGui viewer — can use the real GPU
./moonray-gui-arm64.run --extract-only
cd moonray-gui-arm64
LIBGL_ALWAYS_SOFTWARE=0 LIBGL_DRIVERS_PATH= ./moonray-gui-v2 -in scene.rdla
```

**Correction to earlier docs:** `LIBGL_ALWAYS_SOFTWARE=0` was recommended generally for "a Mali
board". That is wrong for the **Qt** GUI — it needs GL 3.3, which Panfrost does not expose, so
forcing hardware GL makes it fail. Software GL is the correct default for `moonray_gui`.

Note this is only about the **viewport display** path. MoonRay's *rendering* is entirely CPU
(path tracing on the 8 cores); the GPU here just blits and tone-maps the framebuffer. GPU-accelerated
ray tracing would need a Vulkan `GPUAccelerator` backend, which does not exist.

## Environment gotchas found on this board

1. **`RATS_ASSETS_DIR` is mandatory.** Every RaTS scene opens with
   `rats_assets_dir = os.getenv("RATS_ASSETS_DIR")` and then concatenates it. Without the var,
   `os.getenv` returns nil, the concat is a Lua error, and **every** scene fails at parse time in
   ~1 s with `rc=1`. `scripts/rats_native.sh` now exports it automatically.
2. **`moonray_gui` requires `-in scene.rdla`.** With no arguments it prints its usage block and
   exits — that is not a crash, it is the help text.
3. Both bundles extract and execute correctly here: kernel 6.1.75 + glibc 2.39 host, bundle
   carrying its own loader and glibc. No `openat2`/tar problem (that was a QEMU artifact).

## What should differ from the QEMU results

| under QEMU (x86 host) | expected on this board |
|---|---|
| `WARNING: mbind() unavailable (errno=38)` | gone — real kernel implements `mbind` |
| `grid_util` unit test fails (needs ≥8 cores, had 4) | **passes** — 8 cores |
| `pbr_tests` times out at 900 s | should complete |
| vectorized only ~21 % faster than scalar | expect substantially more (real NEON) |
| 128-bit atomics not lock-free | lock-free (LSE on A76/A55) |
