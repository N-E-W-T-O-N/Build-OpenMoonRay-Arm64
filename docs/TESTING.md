# Testing MoonRay arm64 on a native device

Everything here uses the released `.run` bundles — no build required.

```bash
# 1. get the bundles (v1.2)
R=https://github.com/N-E-W-T-O-N/Build-OpenMoonRay-Arm64/releases/download/v1.2
wget $R/moonray-cli-arm64.run   && chmod +x moonray-cli-arm64.run    # 234 MB
wget $R/moonray-gui-arm64.run   && chmod +x moonray-gui-arm64.run    # 362 MB

# 2. get the test scenes (the bundles do NOT contain them)
git clone --depth 1 https://github.com/N-E-W-T-O-N/Build-OpenMoonRay-Arm64 omr
```

## 1 — Smoke test (1 minute)

```bash
./moonray-cli-arm64.run -in omr/source/testdata/sphere.rdla -out /tmp/s.exr -size 128 128
```
Expect `Wrote /tmp/s.exr` and exit 0.

## 2 — RaTS scene corpus: 361 scenes (`scripts/rats_native.sh`)

```bash
./scripts/rats_native.sh ./moonray-cli-arm64.run omr/source/rats scalar
./scripts/rats_native.sh ./moonray-cli-arm64.run omr/source/rats vectorized    # NEON path
./scripts/rats_native.sh ./moonray-cli-arm64.run omr/source/rats scalar camera # one family

SIZE="128 128" ./scripts/rats_native.sh ...        # faster first pass
THREADS=8 TIMEOUT=1800 OUT_DIR=/tmp/rats ./scripts/rats_native.sh ...
```

`RATS_ASSETS_DIR` is exported automatically by the script — it is **mandatory**. Every scene begins
`rats_assets_dir = os.getenv("RATS_ASSETS_DIR")` and concatenates it, so without the var every
scene fails at parse time in ~1 s with `rc=1`.

Covers camera, geometry, light, material, map, motion_blur, displacement, displayfilter, deep,
differentials, pixel_filter, misc. Writes `rats-results-<mode>/results.csv` with per-scene
**status + render seconds** — that CSV is your native performance baseline.

### What this does and does not verify

| | |
|---|---|
| ✔ crash/error detection over 361 scenes | how the BakeCamera SIGSEGV was found |
| ✔ native render timings; scalar vs vectorized | Sprint 4 perf data |
| ✘ **pixel-exact golden comparison** | canonicals are **not** in this repo |

**RaTS reference images ("canonicals") ship separately from DreamWorks.** `rats/cmake/diff.cmake`
hard-requires `$RATS_CANONICAL_DIR`; `rats/` here holds only 22 EXRs, all *input* assets (HDRIs,
textures). Without canonicals the `diff-*` tests cannot run — earlier runs that reported
"28/28 pass" were **render-only** tests, not image comparison.

With canonicals in hand, comparison turns on:
```bash
sudo apt install openimageio-tools          # provides idiff
RATS_CANONICAL_DIR=/path/to/canonicals IDIFF=$(which idiff) \
  ./scripts/rats_native.sh ./moonray-cli-arm64.run omr/source/rats scalar
```
Expected canonical layout: `<canonical_dir>/<test_rel_path>/<mode>/<image>.exr`,
e.g. `.../moonray/camera/perspective/scalar/scene.exr`.

## 3 — Correctness cross-check without canonicals

Render the same scene both ways and compare — scalar barely touches the vectorized kernels, so
agreement is real evidence the NEON/ISPC path is correct:

```bash
D=omr/source/rats/tests/moonray/geometry/curves
./moonray-cli-arm64.run -in $D/*.rdla -out /tmp/sca.exr -exec_mode scalar     -size 256 256
./moonray-cli-arm64.run -in $D/*.rdla -out /tmp/vec.exr -exec_mode vectorized -size 256 256
idiff -a -abs /tmp/sca.exr /tmp/vec.exr     # if idiff is installed
```

## 4 — GUI

The GUIs are interactive **render viewers**, not modelling apps — they need a scene, and print
their usage block if you give them none (that is not a crash):

```bash
./moonray-gui-arm64.run -in omr/source/testdata/sphere.rdla     # Qt viewer, software GL

./moonray-gui-arm64.run --extract-only && cd moonray-gui-arm64
LIBGL_ALWAYS_SOFTWARE=0 LIBGL_DRIVERS_PATH= ./moonray-gui-v2 -in .../sphere.rdla   # ImGui, GPU
```

**GL version ceiling matters.** `moonray_gui` (Qt) compiles `#version 330 core`, i.e. it requires
OpenGL **3.3**. Mali-G610/Panfrost exposes GL **3.1** — so the Qt viewer *cannot* run on that GPU
and must use the bundled software GL (llvmpipe, GL 4.5). `moonray_gui_v2` needs only GL 3.0/GLSL 130
on Linux, so it runs on the real GPU. See **[NATIVE-DEVICE.md](NATIVE-DEVICE.md)**.
In a container: `-e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -e QT_X11_NO_MITSHM=1 --device /dev/dri`
(see `scripts/container_display.sh`).

## 5 — Unit tests

These need the build tree (ctest), not the bundle. If you build on the device:
```bash
export PATH=$(find /build -type f -perm -111 -name moonray -printf '%h\n' | sort -u | tr '\n' ':')$PATH
ctest -L unit --output-on-failure          # RaTS invokes moonray by BARE NAME - PATH is mandatory
```
Without that `PATH`, every render test fails instantly with
`No such file or directory: 'moonray'`.

## What to watch for on real hardware

These were QEMU artifacts and should disappear natively — if they don't, that's a real finding:

| under emulation | expected on hardware |
|---|---|
| `WARNING: mbind() unavailable (errno=38)` | gone (kernel implements `mbind`) |
| `grid_util` unit test fails (needs ≥8 cores) | passes on RK3588 (8 cores) |
| `pbr_tests` times out at 900 s | completes |
| vectorized only ~21 % faster than scalar | substantially better |
| int128 atomics "not lock-free" | lock-free on ARMv8.1+ |
