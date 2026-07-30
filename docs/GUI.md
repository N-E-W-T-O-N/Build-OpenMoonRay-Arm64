# Using the MoonRay GUI

## First, what it is — and isn't

The GUIs are **interactive render viewers**, not modelling applications. There is no modelling,
no scene editing, no node graph, no outliner. You give one a finished scene and it
**progressively path-traces it**, refining as samples accumulate, while you fly the camera around,
inspect pixels, and adjust exposure/gamma live.

If you expected something Blender-shaped: the Blender-equivalent step happens *before* MoonRay.
You author in Houdini / Maya / USD, export, and MoonRay renders it.

**A scene argument is mandatory.** With no `-in`, the viewer prints its usage block and exits —
that is the help text, not a crash.

```bash
./moonray-gui-arm64.run -in scenes/sphere.rdla
```

The bundle now ships `scenes/` (sphere, box, rectangle, curves, sphere2, multi-level-instances)
so you have something to open immediately.

## There are two viewers — which to use

| | `moonray_gui` (**v1**, Qt) | `moonray_gui_v2` (GLFW + Dear ImGui) |
|---|---|---|
| UI | Qt widgets around a GL viewport | ImGui panels drawn inside the viewport |
| Needs | **OpenGL 3.3** (`#version 330 core`) | **OpenGL 3.0** (`#version 130`) |
| On Mali-G610 / Panfrost (GL 3.1) | ❌ shaders won't compile → software GL only | ✅ runs on the real GPU |
| Feature depth | fuller: denoising, OCIO, path visualizer, render-output cycling | lighter: exposure/gamma/help/keybindings/pixel + scene inspector/snapshot panels, selectable **Default** or **Maya** keymap |
| Maturity | the original, more complete | newer, leaner rewrite |

Both are in the same bundle. v1 is the default entry point; v2 is one command away.

```bash
# v1 — Qt viewer. Software GL (correct default on Mali).
./moonray-gui-arm64.run -in scenes/sphere.rdla

# v2 — ImGui viewer, hardware GL on a Mali board
./moonray-gui-arm64.run --extract-only
cd moonray-gui-arm64
LIBGL_ALWAYS_SOFTWARE=0 LIBGL_DRIVERS_PATH= ./moonray-gui-v2 -in scenes/sphere.rdla
```

Useful flags (both): `-size W H` · `-threads N` · `-exec_mode scalar|vectorized` · `-free_cam`
(start in fly mode instead of orbit) · `-snap_path DIR` · `-no_tile_progress`.

## v1 controls — the app's own hotkey table

Press **H** in the window to print this list at any time.

**Camera — fly / free cam**

| key | action |
|---|---|
| `W` `S` `A` `D` | forward · backward · left · right |
| `Space` / `C` | up / down |
| `Q` / `E` | slow down / speed up |
| `R` | reset to original world location |
| `U` | upright the camera |
| `T` | print current camera matrix |
| LMB drag | rotate around camera position |
| `Alt`+LMB+RMB | roll |

**Camera — orbit cam** (the default; `O` toggles between orbit and free)

| input | action |
|---|---|
| `Alt`+LMB | orbit around pivot |
| `Alt`+MMB | pan |
| `Alt`+RMB | dolly |
| `Alt`+LMB+RMB | roll |
| `Ctrl`+LMB, or `F` | refocus on the point under the cursor |

**Channels / display**

| key | action |
|---|---|
| `` ` `` | RGB |
| `1` `2` `3` `4` `5` | red · green · blue · alpha · luminance |
| `7` | normalized RGB |
| `,` / `.` | previous / next render output |
| `P` | toggle tiled-progress outlines |
| `L` | toggle fast progressive mode |
| `Alt`+Up/Down | switch between fast render modes |

**Exposure / gamma / color**

| input | action |
|---|---|
| hold `X` + LMB drag | scrub exposure |
| hold `Y` + LMB drag | scrub gamma |
| `X` / `Y` + LMB tap | reset exposure / gamma |
| `X` / `Y` tap | set exposure / gamma |
| `Shift`+Up/Down | exposure ±1 |
| `Z` | toggle OCIO color management |

**Inspection / output / denoising**

| key | action |
|---|---|
| `I` | cycle pixel inspector: none → light contributions → geometry → geometry part → material |
| `V` | toggle path visualizer GUI |
| `K` | take a snapshot (`snapshot.N.exr`, see `-snap_path`) |
| `N` | denoising on/off |
| `Shift`+`N` | denoiser: OptiX ↔ Open Image Denoise |
| `B` | denoising buffers: Beauty → +Albedo → +Albedo+Normals |

> On this arm64 build the OptiX denoiser is unavailable (CPU-only build) — **Open Image Denoise**
> is the working option.

## v2 controls

v2 ships its bindings in-app: open the **Key Bindings** and **Help** windows from its panels, and
pick the **Default** or **Maya** keymap. Panels available: Exposure, Gamma, Pixel Inspector,
Scene Inspector, Snapshot, Path Visualizer, Axis Display, Status Bar.

## Requirements and troubleshooting

**Display.** X11 (`$DISPLAY`) or Wayland. Under Wayland, forcing X11 is usually simplest:
`QT_QPA_PLATFORM=xcb`. In a container you need
`-e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -e QT_X11_NO_MITSHM=1` and, for hardware GL,
`--device /dev/dri` — `scripts/container_display.sh` wires all of it.

| symptom | cause |
|---|---|
| Prints the `Usage:` block and exits | no `-in scene.rdla` — that's the help text |
| `could not load the Qt platform plugin "xcb"` | `QT_PLUGIN_PATH` unset — use the bundled launcher, not `bin/moonray_gui` directly |
| GLSL compile errors / blank viewport on Mali | v1 needs GL 3.3; Panfrost gives 3.1. Use software GL, or use v2 |
| Viewport very slow | software rasterization. On a GPU-capable board use v2 with hardware GL |
| `XDG_RUNTIME_DIR not set` warning | harmless; the launcher creates one |

**Software GL is the default** (`LIBGL_ALWAYS_SOFTWARE=1`) so the viewers work on machines with no
drivers at all. Override only where the GPU can actually satisfy the required GL version — which,
on Mali-G610, means v2. See **[NATIVE-DEVICE.md](NATIVE-DEVICE.md)**.

Note the GPU only *displays* here: MoonRay's path tracing is entirely CPU. GPU ray tracing would
need a Vulkan `GPUAccelerator` backend, which doesn't exist.
