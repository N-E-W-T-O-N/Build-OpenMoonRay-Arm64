# OpenMoonRay — What Each Sub-Project Does

MoonRay is DreamWorks' production path-tracing renderer. The top-level repo is just a CMake
superbuild; the real code lives in ~20 git submodules. Mental model:

> **scene_rdl2** is the language, **moonray** is the engine, **moonshine** is the content,
> **hydra / moonray_gui** are the frontends, **arras** is the cluster, **rats** is QA.

---

## 1. Rendering core (the actual path tracer)

### `moonray/moonray` — the renderer engine
The heart of the project. Key parts under `lib/rendering/`:

| dir | role |
|---|---|
| `pbr` | The path-tracing **integrator**: light transport, BSDF/light sampling, volumes, AOVs. Contains the precomputed sampler point-set tables (embedded as binary objects — the objcopy fix). Heavy ISPC vectorization. |
| `shading` | **Material evaluation** machinery: BSDF lobes, shader network execution, bundled/deferred shading queues. ~50 ISPC kernels. |
| `geom` + `rt` | **Geometry & ray intersection**: procedural geometry API, tessellation, motion blur; `rt` wraps **Embree** for CPU ray tracing and hosts the GPU (XPU) backends — OptiX (NVIDIA) and Metal (Apple), both disabled on our arm64 build; a future **Vulkan backend here** would be the Mali path. |
| `texturing` | Texture sampling on top of **OpenImageIO**'s texture system (udims, mip selection). |
| `mcrt_common` | Vectorization plumbing shared by pbr/shading: SoA data layouts (`RayDifferentialv` etc.), thread-local state, execution modes (scalar / vectorized / XPU). |
| `rndr` | The **render driver**: frame loop orchestration, tiling, adaptive sampling, checkpoint/resume, render output (EXR) writing, render statistics. |
| `lib/application`, `cmd/` | App scaffolding and the CLI tools — `moonray` (batch render), `moonray_info`, denoise cmd, etc. |

### `moonray/scene_rdl2` — foundation + scene description
Everything else is built on this.
- **RDL2** ("Rendering Description Language 2"): the scene graph — SceneObjects, attributes,
  binary/ascii scene files (`.rdlb`/`.rdla`), the DSO plugin ABI that shaders/lights implement.
- **Platform layer**: `common/platform` (Platform.hh ISA selection & the SSE-masquerade-on-ARM,
  intrinsics), `common/math` (the Embree-derived SIMD math library: `ssef/avxf/...` wrapper
  classes; on arm64 these compile through `common/arm/sse2neon.h`), `render/util` (atomics,
  allocators), `render/logging`, `common/fb_util` (framebuffers, tiling), `common/grid_util`
  (multi-machine merge/snapshot utilities), `common/rec_time` (timers).
- Python bindings (`py_scene_rdl2`) and scene tools (`rdl2_print`, `rdl2_convert`, ...).

## 2. Content library (what materials/lights ship with it)

- **`moonray/moonshine`** — the production **shader library**: DSO plugins for materials
  (DwaBase-derived), maps/textures, lights, displacements, volumes. ~112 ISPC files.
- **`moonray/moonshine_usd`** — USD-specific geometry/shader DSOs (UsdGeometry, UsdInstance...).
- **`moonray/materialx_shaders`** — generated MaterialX shader implementations (optional,
  `BUILD_MATERIALX_SHADERS=OFF` by default).

## 3. Pipeline integrations (the "frontends")

- **`moonray/hydra/hdMoonray`** — the **USD Hydra render delegate**: makes MoonRay a render
  backend for any Hydra host (usdview, Houdini Solaris, Maya...). `plugin/hd_moonray` is the
  delegate plugin; `cmd/hd_cmd` has `hd_render` (render a USD stage from CLI) and `hd_usd2rdl`
  (convert USD → RDL2 scene).
- **`moonray/hydra/moonray_sdr_plugins`** — Sdr (Shader Definition Registry) discovery/parser
  plugins so USD can enumerate MoonRay's shaders and their parameters (our ndr→sdr port).
- **`moonray/moonray_gui`** — interactive desktop viewer: v1 is Qt5 + OpenGL, v2 is GLFW +
  Dear ImGui. Progressive preview, camera navigation, denoiser toggle.
- **`moonray/moonray_dcc_plugins`** — DCC-side integration assets (Houdini HDAs etc.).

## 4. Distributed rendering (the "network layer")

- **`arras/arras4_core`** — DreamWorks' generic distributed-computation framework: sessions,
  computations, message passing, logging (Athena). Not renderer-specific.
- **`arras/distributed/arras4_node` + `minicoord`** — per-host node service and a minimal
  session coordinator for multi-machine setups.
- **`moonray/moonray_arras/mcrt_computation`** — MoonRay wrapped as an Arras computation
  (progressive/batch render nodes, the merge node).
- **`moonray/moonray_arras/mcrt_dataio`** — image/data transport between nodes: snapshot
  delta encoding, multi-machine frame **merge**, client receiver, telemetry.
- **`moonray/moonray_arras/mcrt_messages`** — the wire-protocol message types.
- **`arras/arras_render`** — the thin desktop client that connects to an Arras session and
  displays the streamed render.

## 5. Supporting cast

- **`cmake_modules`** — shared build logic: `OMR_Platform.cmake` (platform/arch selection —
  the single most important file of the arm64 port), `MoonrayDso.cmake` (how every shader DSO
  is built + its ISPC rules), Find modules (`FindTBB`, `FindOptiX`, ...).
- **`moonray/mcrt_denoise`** — denoiser wrapper library: Open Image Denoise (CPU, our path),
  OptiX denoiser (NVIDIA), or Metal (Apple).
- **`rats`** — Render Acceptance Test Suite: golden-image regression tests (Sprint 3 uses this).
- **`moonray/render_profile_viewer`** — web-based viewer for render profiling stats.
- **`testdata`** — sample scenes used by tests/smoke renders.

---

## How a frame flows through the pieces

1. A frontend (CLI `moonray`, `hd_render` via Hydra, or a DCC) produces/loads an **RDL2 scene**
   (`scene_rdl2`), pulling shader DSOs from **moonshine**.
2. `rndr::RenderDriver` (moonray) preps the frame: geometry procedurals run (`geom`),
   Embree BVH is built (`rt`), textures open (`texturing` → OIIO).
3. The **pbr integrator** traces paths in vectorized bundles (`mcrt_common` SoA queues,
   ISPC kernels), shading evaluates via **shading** + moonshine DSOs.
4. Pixels accumulate into `fb_util` framebuffers → optional **mcrt_denoise** → EXR output;
   in distributed mode, per-node results stream through **mcrt_dataio** to a merge node and
   on to **arras_render**/Hydra for display.
