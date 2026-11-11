# WORLDBREAK Project Status

**Last updated:** 2026-11-11  
**Current branch:** `ai/phase-5/simulation-tools`  
**PR #2:** [Merged](https://github.com/PanDuroDev/Idk/pull/2) into `main`  
**Merge commit (PR #2):** `0911466d40115e835815d4072c2f075843369027`  
**PR #3:** [Merged](https://github.com/PanDuroDev/Idk/pull/3) into `main`  
**Merge commit (PR #3):** `328595ede6470700a16574bd1461e1b37d3dbe58`  
**PR #4:** [Merged](https://github.com/PanDuroDev/Idk/pull/4) into `main`  
**Merge commit (PR #4):** `9aaf496c74b49a7e8bc8008043731ba08918eaa2`

## Project idea

WORLDBREAK is a 3D physics and destruction sandbox. The long-term goal is to let users create or choose simulation worlds, apply impacts and forces, and observe props, buildings, and eventually terrain breaking under configurable conditions. Multiple fictional environments and reusable simulation tools are planned. These are goals, not completed features.

## Technical baseline

- Godot 4.7.2 stable.
- GDScript and standard Godot editor; no .NET SDK required.
- Compatibility renderer and Godot Physics 3D.
- Target includes desktop GPUs such as GTX 1660 SUPER 6 GB.

## Current implementation

- Generated arena and first-person controller.
- 70 modular rigid-body fragments and six physics props.
- Reusable blast service and physics-tick request processing.
- Shared mesh, material, and collision resources.
- Six-axis support graph; fragments with no path to a surviving ground anchor are released.
- Per-cell accumulated damage with distance falloff.
- Three data-driven `DestructionMaterialProfile` resources:
  - Foundation Concrete: integrity 1.6, blast resistance 1.2, density multiplier 1.3.
  - Masonry: integrity 1.0, blast resistance 1.0, density multiplier 1.0.
  - Lightweight Panel: integrity 0.65, blast resistance 0.8, density multiplier 0.75.
- Material profiles determine per-cell integrity, blast resistance, rigid-body mass multiplier, and shared visual tint.
- Blast damage remains separate from physical impulse strength.
- Reset restores damage history, support state, transforms, velocities, and frozen states.
- Runtime HUD and headless smoke tests.

## Validation

Godot 4.7.2 CI passed on the merged implementation. The final pre-merge validation was [Actions #42859271503](https://github.com/PanDuroDev/Idk/actions/runs/42859271503).

Verified:
- Godot imported the custom Resource script and all three `.tres` material profiles.
- The final PR #3 workflow passed on both `ubuntu-latest` and `windows-latest` at head `351db972746837ebb4ade2d3ab067239b0dfd64a` ([Actions #42865744560](https://github.com/PanDuroDev/Idk/actions/runs/42865744560)). It imports the project before launch, scans Godot logs for script/runtime errors, and requires the gameplay smoke-test success marker.
- CI now runs on pull requests targeting `main` and pushes to `main`; this closes the previous gap where the push trigger only watched the retired feature branch.
- PR #4 was squash-merged as `9aaf496c74b49a7e8bc8008043731ba08918eaa2`; the post-merge push run [Actions #42869641317](https://github.com/PanDuroDev/Idk/actions/runs/42869641317) passed on Linux and Windows.
- The post-merge push run [Actions #42866260328](https://github.com/PanDuroDev/Idk/actions/runs/42866260328) passed on both Linux and Windows at merge commit `328595ede6470700a16574bd1461e1b37d3dbe58`.
- Project launched headlessly.
- Material profile assignment for foundation, middle, and top layers.
- Foundation has higher integrity, blast resistance, and density than masonry.
- Masonry breaks after two centered weak hits.
- Foundation resists three weak hits and breaks on the fourth.
- A centered weak hit breaks the lightweight panel at its own integrity/resistance threshold; the follow-up reset restores the fragment.
- Full base-row collapse, support graph behavior, and reset pass.
- The headless integration test then simulates 120 additional physics frames: all 70 fragments moved, position/velocity values remained finite, and no fragment center crossed below the ground threshold.
- A further headless regression passes five consecutive collapse/reset cycles: all 70 fragments move in every cycle, complete 120 physics frames with finite state and ground containment, and return to the initial state after each reset ([post-merge Actions #42869641317](https://github.com/PanDuroDev/Idk/actions/runs/42869641317)).

## Current limitations

- Material profile values are editable prototype values, not measured real-world material constants.
- Profiles are assigned by layer in the test structure; the Phase 5 panel can apply catalog material presets, but there is no free-form in-game material editor yet.
- Damage uses fragment-center distance and simple falloff.
- Support graph remains a topological approximation, not a stress solver or physical joint network.
- No arbitrary mesh fracture, terrain chunk streaming, or debris pooling.
- The user reported that the manual Windows gameplay/visual/control validation passed on 2026-11-10. Exact FPS/CPU/GPU telemetry values were not supplied, so no numerical performance baseline is claimed.

## Phase 1 progress

Implementation PRs [#11](https://github.com/PanDuroDev/Idk/pull/11), [#16](https://github.com/PanDuroDev/Idk/pull/16), and [#17](https://github.com/PanDuroDev/Idk/pull/17) are merged into `main` in dependency order.

- Runtime impact controls: radius, damage, and impulse are adjustable with bounded ranges and reset-to-default behavior.
- Debris lifecycle: released fragments have a 30-second default lifetime, sleeping/wake-up behavior, a 70-awake-fragment default cap, and reset-safe retirement.
- Effects and diagnostics: dust bursts are capped at eight concurrent effects, six motes each, with a 0.55-second lifetime; F3 toggles the diagnostics overlay.

### Remaining Phase 1 acceptance checks

Issue [#5](https://github.com/PanDuroDev/Idk/issues/5) remains open. Its implementation PRs being merged does not complete the phase. Still outstanding:
- Interactive verification of impact controls, dust appearance/fade, and F3 overlay readability.
- Long-duration settling and repeated interactive collapse/reset checks.
- Actual idle/collapse/settled FPS, CPU, GPU, and VRAM observations on the target Windows PC. The overlay reports runtime counters but is not a benchmark; no target-PC telemetry values are currently recorded.

## Phase 2 progress

- [PR #14](https://github.com/PanDuroDev/Idk/pull/14) merged the architecture and schema proposal only.
- [PR #18](https://github.com/PanDuroDev/Idk/pull/18) implemented reusable building definitions: versioned Resource types, validation, the classic 70-cell preset, an 11-cell sparse sample, and data-driven fragment generation. Merged to `main` as `422b923` after Linux + Windows CI passed.
- [PR #19](https://github.com/PanDuroDev/Idk/pull/19) added a native material profile catalog, safe duplicate/add helpers, an EditorScript catalog validator, and an isolated preview scene. Merged to `main` as `f61c731`.
- [PR #20](https://github.com/PanDuroDev/Idk/pull/20) added versioned JSON simulation configuration persistence, trusted building/material catalog resolution, transactional save/load, live apply/reset, two sample configurations, and a dedicated cross-platform regression. Merged to `main` as `7096dd3`.
- Optional breakable-joint feasibility remains deferred until profiling provides evidence.

## AI phase delegation

Five dedicated implementation issues are open:
- Phase 1: [#5 - Destruction vertical slice](https://github.com/PanDuroDev/Idk/issues/5) - implementation PRs #11, #16, and #17 are merged; full acceptance verification remains open.
- Phase 2: [#6 - Reusable structures and material authoring](https://github.com/PanDuroDev/Idk/issues/6) - merged via PRs #18, #19, and #20.
- Phase 3: [#7 - Chunked terrain deformation](https://github.com/PanDuroDev/Idk/issues/7) - merged via PRs #10, #12, #13, #15, and #21.
- Phase 4: [#8 - Multiple worlds](https://github.com/PanDuroDev/Idk/issues/8) - merged via [PR #22](https://github.com/PanDuroDev/Idk/pull/22) as `a61fe2e`.
- Phase 5: [#9 - Simulation tools](https://github.com/PanDuroDev/Idk/issues/9) - merged via [PR #23](https://github.com/PanDuroDev/Idk/pull/23) as `94c71b4`; settled-outcome runs merged via [PR #24](https://github.com/PanDuroDev/Idk/pull/24) as `09c5602`.

Each issue contains its own AI prompt, PR breakdown, acceptance criteria, and common engineering rules. Agents may implement and open PRs proactively without asking between ordinary subtasks, but they must not merge. One integration maintainer reviews and merges PRs in dependency order. See [AI_PHASE_ASSIGNMENTS.md](AI_PHASE_ASSIGNMENTS.md).

## Phase 3 isolated terrain prototype

- [PR #10](https://github.com/PanDuroDev/Idk/pull/10) added the chunk density model, duplicated global border samples, deterministic six-tetrahedra mesher, outward normals, and shared-face seam regression. Merged to `main` as `b89198d` after Linux + Windows validation passed.
- [PR #12](https://github.com/PanDuroDev/Idk/pull/12) added the deterministic world-space sphere edit journal, affected-chunk AABB query, shared-border density recomputation, and reset. Merged to `main` as `5e3a43c`.
- [PR #13](https://github.com/PanDuroDev/Idk/pull/13) added the coalescing static collision rebuild queue, one-rebuild-per-physics-frame budget, deferred collider replacement, and stale-shape removal. Merged to `main` as `b8a90b8`.
- [PR #15](https://github.com/PanDuroDev/Idk/pull/15) added validated budgets, an 8-cell low-end profile, a bounded mesh rebuild queue, and repeatable 8³/16³ CPU and payload profiling. Merged to `main` as `15467f0` after merging `main` and resolving an append-only Work Log conflict.
- [PR #21](https://github.com/PanDuroDev/Idk/pull/21) added `TerrainWorld`: a bounded resident chunk patch with synchronous initial meshes/colliders, localized blast carving, bounded mesh and collision rebuild queues, terrain reset, and gameplay integration. Merged to `main` as `cb2a9bf` after Linux + Windows CI passed. The patch is now centered on the arena with a configurable radius (4x4 chunks in the shipped worlds) so the whole ground is carveable.
- Local Windows validation on the merged tree passed `WORLDBREAK_TERRAIN_CHUNK_MESH_OK`, `WORLDBREAK_TERRAIN_DEFORMATION_OK`, `WORLDBREAK_TERRAIN_COLLISION_OK`, `WORLDBREAK_TERRAIN_BUDGETS_OK`, `WORLDBREAK_TERRAIN_MESH_QUEUE_OK`, `WORLDBREAK_TERRAIN_WORLD_OK`, and `WORLDBREAK_TERRAIN_INTEGRATION_OK`, plus the gameplay smoke suite.
- This is a fixed resident patch, not a chunk streamer, and the tests do not establish visual quality or target-PC frame rate.

## Phase 4 world loading

- `WorldDefinition` is a versioned native Resource (schema version 1) with metadata, a `res://` JSON simulation-configuration path, player spawn, environment/sun preset, and terrain preset. It does not duplicate building, material, or terrain formats.
- `WorldCatalog` references both sample worlds. `WorldDefinitionValidator` resolves and validates the referenced configuration through the existing catalogs before the active scene is touched.
- `main.gd` loads one resident world at a time, reuses the existing structure/configuration/terrain paths, applies environment and spawn presets, supports reset, and releases structure, terrain, and active state on unload. A failed load leaves the current world unchanged.
- Samples: `Classic Yard` (70-piece building, default terrain profile) and `Sparse Quarry` (11-cell building, low-end terrain profile, warmer environment, heavier gravity, altered spawn).
- Dedicated local Windows regression `WORLDBREAK_WORLD_LOADING_OK` covers catalog validation, initial load, switching, invalid-ID rejection, resident bounds, unload, reload, reset, and malformed-resource validation. Linux + Windows CI passed in [Actions run #42907322740](https://github.com/PanDuroDev/Idk/actions/runs/42907322740); PR #22 merged to `main` as `a61fe2e`.
- Limitations: loading is synchronous and there is no world streamer, terrain-edit persistence, or cross-world budget beyond one resident world. Interactive world selection is provided by the Phase 5 Simulation Control panel.

## Phase 5 simulation tools

- The Simulation Control panel reuses Phase 1 impact controls, Phase 2 material/configuration APIs, and Phase 4 world presets. It adds world/scenario/material selection, gravity/time-scale controls, pause/resume, run/reset, and JSON/CSV export.
- `ExperimentScenario` (schema version 1), `ScenarioCatalog`, and three samples (`foundation_strike`, `terrain_crater`, `sparse_beam_shear`) provide repeatable setup through the existing world/structure/terrain paths.
- `ExperimentHistory` keeps a bounded 50-run history, compares the latest two runs, records impact/world/building/material metadata, and exports versioned JSON or CSV through a temporary-file verify/rename path.
- `run_scenario_settled` repeats a scenario and waits a bounded physics window (default 120 frames, clamped 1-600) before recording final broken/released counts, awake and sleeping loose bodies, moved fragments, and settle frames. The synchronous `run_scenario` remains for cheap compatibility checks. The reset setup is deterministic; observed post-impact physics is not promised to be bit-identical across runs or platforms.
- Material selection applies an existing catalog profile through the Phase 2 per-cell override path; `default` restores the building definition's materials. Pause uses `SceneTree.paused` while the UI canvas remains processable, without overwriting `Engine.time_scale`.
- `tests/phase5/simulation_tools_test.gd` reports `WORLDBREAK_SIMULATION_TOOLS_OK`. Local Windows validation passed the full regression (smoke, configuration persistence, all terrain markers, world loading, and simulation tools). [PR #23](https://github.com/PanDuroDev/Idk/pull/23) merged as `94c71b4` after Linux + Windows CI passed; the settled-run follow-up merged as `09c5602` via [PR #24](https://github.com/PanDuroDev/Idk/pull/24) after Linux + Windows CI passed.
- Limitations: scenarios provide deterministic setup, not bit-identical cross-platform physics; settled counts and timing are observational; material selection is catalog-preset based, not a free-form material editor; headless tests do not prove interactive button ergonomics, visual quality, or target-PC frame rate.

## Presentation pass

- [PR #26](https://github.com/PanDuroDev/Idk/pull/26) adds a blast core flash plus ground shockwave ring to the existing dust bursts, a rocket that flies into the impact point before settled scenario runs, first-person/orbit/overview camera modes (panel row or C), and centers a radius-configurable terrain patch under the arena so the whole play area is carveable.
- The previous flat ground box is now a far safety floor at y=-6; debris may legitimately settle in craters below y=0.
- Limits: effects are mesh-and-tween based with the existing eight-burst cap, the rocket is visual-only (no trajectory physics), and the terrain remains a bounded resident patch without streaming.

## Realism and interface pass

- [PR #27](https://github.com/PanDuroDev/Idk/pull/27) fires the rocket from the player toward the aim point captured at fire time and detonates it on arrival; every blast also carves the terrain beneath the hit, adds debris chips, and applies a short decaying camera shake.
- The scene now uses a procedural sky (blue zenith, warm horizon, filmic tonemapping, sky-based ambient light); world presets tint the sky rather than replacing it with a flat background color. The prop set is nine varied crates, barrels, and cones with shared resources.
- HUD and control panel share a dark theme with sectioned rows, hover/pressed states, a top-right anchored panel, a first-person crosshair, and a control-hint line.
- Limits: no downloaded external art, models, or HDRI; effects remain mesh-and-tween; the rocket is visual only and the blast is applied on arrival rather than by a simulated projectile body; no target-PC frame-rate claim.

## Required update protocol

Every substantial session updates this file and `WORK_LOG.md` at three points:
1. **Before:** starting commit, current state, intended scope, references, and risks.
2. **During:** completed units, changed architecture, blockers, and tests already run.
3. **After:** exact changes, CI/manual test results, unverified limitations, current milestone, and one concrete next step.

Never mark a feature complete just because code was committed. State whether it passed CI, manual testing, or remains unverified.
