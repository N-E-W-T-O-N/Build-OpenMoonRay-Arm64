# Portable MoonRay for arm64 — single-file distribution

**`bundle/moonray-arm64.run`** — 234 MB, self-extracting, no installation, no dependencies.

```bash
./moonray-arm64.run -in scene.rdla -out image.exr -size 512 512
./moonray-arm64.run --extract-only      # just unpack, print the directory
MOONRAY_DIR=/opt/mr ./moonray-arm64.run # choose extraction target
```

First run extracts ~430 MB next to the file (or to `$MOONRAY_DIR`), then execs the renderer;
later runs reuse the extraction.

## Why a bundle and not one static binary

MoonRay's architecture *is* runtime plugin loading: it `dlopen`s 176 RDL2 DSOs (every shader,
light, geometry type and display filter) plus OIIO/USD plugins. A single static ELF is therefore
not possible without rearchitecting the renderer. The bundle is the practical equivalent —
one file to copy, nothing to install.

## Contents (430 MB extracted)

| part | what |
|---|---|
| `bin/moonray` | the renderer executable |
| `lib/` (113 files, 408 MB) | full transitive closure **+ the dynamic loader itself** |
| `dso/` (176 files, 22 MB) | RDL2 plugins — shaders, lights, geometry, display filters |
| `moonray` | launcher: runs the bundled loader with `--library-path`, sets `RDL2_DSO_PATH` |

Biggest libs: `librendering_pbr.so` 190 MB (embedded Monte-Carlo sampler tables — data, so
stripping doesn't shrink it), `libusd_ms.so` 91 MB, `libopenvdb.so` 29 MB. Dropping the
USD-dependent DSOs would save ~91 MB if USD geometry isn't needed.

## Portability: why host glibc doesn't matter

The launcher invokes the **bundled** `ld-linux-aarch64.so.1` with `--library-path lib`, so the
host's loader and libraries are never consulted. Requirement is just an aarch64 Linux kernel.

**Verified:** built on Ubuntu 26.04 (glibc 2.4x), then rendered successfully on **Ubuntu 22.04
(glibc 2.35)** — a 4-year-older distro with none of MoonRay's dependencies installed:

```
=== host: Ubuntu 22.04.5 LTS | glibc 2.35 | tar 1.34 ===
extracting MoonRay (~430MB) to /home/dev/moonray-arm64 ... extracted.
Render time = 00:00:04.857   Wrote /tmp/old.exr
```

## Runtime dependencies (what a *non*-bundled binary needs)

On bare Ubuntu 26.04 arm64 the raw binary fails immediately — 17 libraries missing:
`libatomic`, `libboost_{atomic,chrono,container,date_time,filesystem,regex,thread}.so.1.90.0`,
`libembree4.so.4`, `libjpeg.so.8`, `libjsoncpp.so.26`, `liblog4cplus-2.0.so.3`,
`liblua5.3.so.0`, `libopenvdb.so.10.0`, `libosd{CPU,GPU}.so.3.7.0`, `libtbb.so.12`.
Plus `RDL2_DSO_PATH` must point at the DSOs or no shaders load. The bundle removes all of this.

## Known caveat (emulation only)

Under **QEMU** user-mode emulation, GNU tar ≥ 1.35 can't extract: it uses `openat2()`, which
qemu-user returns `ENOSYS` for (`Cannot open: Function not implemented`). Real arm64 kernels
implement it, and tar ≤ 1.34 doesn't use it — hence the successful Ubuntu 22.04 run. If you ever
hit this on an emulator, extract manually:

```bash
tail -c +606 moonray-arm64.run | tar xz    # payload starts at byte 606
```

## Rebuilding the bundle

Staging + packaging is scripted in this session's history; inputs are the build tree
(`build/`) and the deps image. Steps: collect DSOs → `ldd` closure (recursive) → copy libs +
loader → write launcher → `tar czf` → prepend the byte-offset header.


---

# GUI bundle — display-verified (2026-07-28)

`moonray-gui-arm64.run` (~860 MB) contains `moonray_gui` (Qt), `moonray_gui_v2` (GLFW/ImGui)
and `moonray`. **Confirmed working interactively**: a `moonray_gui` window rendered a
path-traced sphere under WSLg, from the bundle, in a container, with software OpenGL.

## Running the GUI in a container with a display

Use `container_display.sh` (also in `Build-OpenMoonRay-Arm64/scripts/`):

```bash
./container_display.sh                 # Qt viewer, sphere scene, build tree
./container_display.sh curves v2 300   # ImGui viewer, curves scene, 300s
BUNDLE=1 ./container_display.sh        # test the released bundle instead
```

The plumbing it sets up, and why each part is needed:

| flag | purpose |
|---|---|
| `-e DISPLAY` | which X server the app talks to |
| `-v /tmp/.X11-unix:/tmp/.X11-unix` | the X server's unix socket (WSLg exposes `X0` here) |
| `-e QT_X11_NO_MITSHM=1` | MIT-SHM shared memory can't cross the container boundary — without this Qt may crash or corrupt |
| `--device /dev/dri` | hardware GL; omit for software rendering |
| `-e XDG_RUNTIME_DIR` | silences Qt/GLFW warnings |

Wayland: pass `WAYLAND_DISPLAY` and the socket, or force X11 with `QT_QPA_PLATFORM=xcb`
(simplest under WSLg).

## The `dlopen` trap — twice

`ldd` lists only *link-time* dependencies. Two runtime-loaded families are invisible to it, and
both had to be bundled explicitly after they broke:

1. **Qt platform plugins** — Qt `dlopen`s `libqxcb.so`. Missing → *"could not load the Qt
   platform plugin"* despite every library being present. Bundled in `qt-plugins/` (11 plugins:
   xcb, Wayland variants, EGL, offscreen, linuxfb, VNC) with `QT_PLUGIN_PATH` +
   `QT_QPA_PLATFORM_PLUGIN_PATH`.
2. **Mesa DRI drivers** — Mesa `dlopen`s `swrast_dri.so`. The bundle initially shipped the GL
   *dispatch* libs (`libGL.so.1`, `libGLX.so.0`) but no driver, so GL context creation failed on
   any host without matching system Mesa. Bundled in `lib/dri/` with `libGLX_mesa`, `libgallium`
   and `libLLVM.so.21.1` (gallium JITs shaders through LLVM), wired via `LIBGL_DRIVERS_PATH`.

That second one is why the bundle is 860 MB rather than 553 MB. A redundant second LLVM copy
(264 MB) was trimmed after checking which version gallium actually links.

## Software vs hardware GL

The bundle defaults to **software GL** (`LIBGL_ALWAYS_SOFTWARE=1`) so the viewers work on any
machine with no drivers installed. On a device with working GL drivers — e.g. a Mali board with
panfrost or the vendor blob — prefer hardware:

```bash
LIBGL_ALWAYS_SOFTWARE=0 LIBGL_DRIVERS_PATH= ./moonray-gui
```

Software rasterization is correct but slow for interactive viewport use.
