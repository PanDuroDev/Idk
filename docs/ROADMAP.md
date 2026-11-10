# Roadmap

## Phase 0 - Reliable Godot foundation
- [x] Godot 4.7.2 project with GDScript and standard editor.
- [x] Compatibility renderer baseline.
- [x] First-person arena and modular rigid-body structure.
- [x] Physics requests processed in `_physics_process()`.
- [x] Reusable blast service.
- [x] Shared generated mesh, collision, and material resources.
- [x] Named InputMap actions.
- [x] Headless gameplay smoke test.
- [x] GitHub Actions validates Godot 4.7.2 headlessly on Linux and Windows, including pushes to `main`.
- [ ] Manual visual, controls, and performance verification on target Windows PC.

## Phase 1 - Destruction vertical slice
- [ ] Validate collision stability and resets in interactive play.
- [ ] Add in-game impact radius/strength controls.
- [ ] Add fragment lifetime, sleeping, and active-fragment budgets.
- [ ] Add low-cost dust/debris effects.
- [ ] Add detailed physics/rendering debug overlay.

## Phase 2 - Structural behavior
- [x] Deterministic six-axis support graph.
- [x] Detect loss of all paths to ground and release unsupported sections.
- [x] Restore support graph on reset.
- [x] Add accumulated per-cell damage with distance falloff.
- [x] Separate blast damage amount from physical impulse strength.
- [x] Add data-driven material profiles for integrity, blast resistance, density, and tint.
- [ ] Add optional physical breakable joints after graph/damage profiling.
- [ ] Add reusable building definitions and material authoring tools.
- [ ] Add save/load for test configurations.

## Phase 3 - Terrain deformation
- [ ] Prototype chunked terrain.
- [ ] Deform only affected chunks.
- [ ] Rebuild collision selectively and safely.
- [ ] Add low-end hardware budgets and fallback behavior.

## Phase 4 - Multiple worlds
- [ ] Data-driven world configurations.
- [ ] World selection and streaming boundaries.
- [ ] Reusable environment, material, and destruction presets.

## Phase 5 - Simulation tools
- [ ] Expose blast, gravity, material, and environment controls.
- [ ] Add repeatable experiments and resettable scenarios.
- [ ] Profile before considering native extensions.
