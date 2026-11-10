# Roadmap

## Phase 0 — Foundation
- [x] Select engine, language, and technical direction.
- [x] Add Unreal project descriptor and C++ module scaffold.
- [x] Add a reusable radial physics-impact actor.
- [x] Document performance targets and system boundaries.
- [ ] Generate project files and compile with Unreal Engine 5.8.
- [ ] Add build validation on a machine with Unreal installed.

## Phase 1 — First playable test range
- [ ] Create a minimal test-range map.
- [ ] Add first-person movement and interaction.
- [ ] Add physics props with varied mass and material response.
- [ ] Author one small Chaos Geometry Collection building.
- [ ] Connect impact events to physics, fracture, Niagara, and audio.
- [ ] Add reset/replay controls.
- [ ] Profile CPU, GPU, memory, and physics cost on the 6 GB GPU target.

## Phase 2 — Destruction framework
- [ ] Add data-driven impact and material-response profiles.
- [ ] Add distance-based simulation quality and debris budgets.
- [ ] Add structural damage accumulation and staged collapse.
- [ ] Add event logging and repeatable scenarios.
- [ ] Add visual debug tools for radius, impulse, and affected objects.

## Phase 3 — Deformable terrain
- [ ] Prototype a local crater on bounded terrain.
- [ ] Implement chunked mesh and collision updates.
- [ ] Add terrain material blending and displaced debris.
- [ ] Persist and reset terrain modifications.
- [ ] Benchmark crater size, chunk resolution, and collision rebuild time.

## Phase 4 — Multiple worlds
- [ ] Define world profiles and world selection.
- [ ] Build a second distinct environment.
- [ ] Add streaming and memory budgets.
- [ ] Prototype a spherical/cube-sphere world.
- [ ] Add world-specific gravity and atmosphere profiles.

## Phase 5 — Sandbox tools
- [ ] Add a data-driven library of fictional impact devices.
- [ ] Add a scenario editor and saved presets.
- [ ] Add side-by-side run comparison and telemetry export.
- [ ] Add replayable event timelines.
- [ ] Add quality presets and hardware benchmark profiles.

A phase is complete only when it compiles, runs, is repeatable, and has measured performance on target hardware.
