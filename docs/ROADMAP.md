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
- [x] GitHub Actions validates Godot 4.7.2 headlessly on Linux and Windows, including pushes to `main`, with checked logs and simulated post-collapse rigid-body checks.
- [x] Headless regression for five consecutive full collapse/reset cycles.
- [x] Manual visual, controls, collapse/reset, and gameplay verification on target Windows PC (user-reported 2026-11-10; numeric performance telemetry not supplied).

## Phase 1 - Destruction vertical slice ([AI issue #5](https://github.com/PanDuroDev/Idk/issues/5), implementation PRs merged)
- [ ] Verify impact controls, dust appearance/fade, F3 overlay readability, long-duration settling, and repeated interactive collapse/reset.
- [ ] Record target-PC idle/collapse/settled FPS, CPU, GPU, and VRAM. No numeric telemetry is currently recorded.
- [x] Add in-game impact radius/damage/impulse controls ([PR #11](https://github.com/PanDuroDev/Idk/pull/11), merged).
- [x] Add fragment lifetime, sleeping, wake-up, and active-fragment budgets ([PR #16](https://github.com/PanDuroDev/Idk/pull/16), merged).
- [x] Add bounded dust/debris effects and opt-in diagnostics ([PR #17](https://github.com/PanDuroDev/Idk/pull/17), merged).

## Phase 2 - Structural authoring and reusable configurations ([AI issue #6](https://github.com/PanDuroDev/Idk/issues/6), architecture merged; implementation underway)
- [x] Deterministic six-axis support graph.
- [x] Detect loss of all paths to ground and release unsupported sections.
- [x] Restore support graph on reset.
- [x] Add accumulated per-cell damage with distance falloff.
- [x] Separate blast damage amount from physical impulse strength.
- [x] Add data-driven material profiles for integrity, blast resistance, density, and tint.
- [ ] Add optional physical breakable joints after graph/damage profiling.
- [x] Add reusable building definitions and data-driven generation ([PR #18](https://github.com/PanDuroDev/Idk/pull/18), open for review; Linux/Windows CI passed).
- [x] Add material authoring validation, duplicate workflow, and preview ([PR #19](https://github.com/PanDuroDev/Idk/pull/19), open for review and stacked on PR #18; Linux/Windows CI passed).
- [x] Add versioned save/load for test configurations. ([PR #20](https://github.com/PanDuroDev/Idk/pull/20), open for review and stacked on PR #19; local Windows validation passed)

## Phase 3 - Terrain deformation ([AI issue #7](https://github.com/PanDuroDev/Idk/issues/7), design may run in parallel; gameplay integration after Phases 1-2)
- [x] PR #10: isolated chunk data, deterministic tetrahedral mesher, and architecture decision (Linux + Windows CI passed; review open).
- [x] PR #12: localized sphere edits, affected-chunk query, shared-border density equality, and journal reset (Linux + Windows CI passed; stacked PR ready for review).
- [x] PR #13: coalesced static collision replacement with a bounded physics-safe queue (Linux + Windows CI passed; stacked draft PR).
- [x] PR #15: budgets, low-end fallback, bounded mesh queue, and repeatable CPU/memory-payload profiling (Linux + Windows CI passed; stacked draft PR).
- [ ] Integrate terrain with BlastService and the active gameplay scene only after Phase 1 and Phase 2 have merged and their interfaces are stable.

## Phase 4 - Multiple worlds ([AI issue #8](https://github.com/PanDuroDev/Idk/issues/8), after Phase 2-3 contracts stabilize)
- [ ] Data-driven world configurations.
- [ ] World selection and streaming boundaries.
- [ ] Reusable environment, material, and destruction presets.

## Phase 5 - Simulation tools ([AI issue #9](https://github.com/PanDuroDev/Idk/issues/9), final integration phase)
- [ ] Expose blast, gravity, material, and environment controls.
- [ ] Add repeatable experiments and resettable scenarios.
- [ ] Profile before considering native extensions.
