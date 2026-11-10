# WORLDBREAK Project Status

**Last updated:** 2026-11-10  
**Current branch:** `main`  
**PR #2:** [Merged](https://github.com/PanDuroDev/Idk/pull/2) into `main`  
**Merge commit:** `0911466d40115e835815d4072c2f075843369027`

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
- Project launched headlessly.
- Material profile assignment for foundation, middle, and top layers.
- Foundation has higher integrity, blast resistance, and density than masonry.
- Masonry breaks after two centered weak hits.
- Foundation resists three weak hits and breaks on the fourth.
- A centered weak hit breaks the lightweight panel at its own integrity/resistance threshold; the follow-up reset restores the fragment.
- Full base-row collapse, support graph behavior, and reset pass.
- The headless integration test then simulates 120 additional physics frames: all 70 fragments moved, position/velocity values remained finite, and no fragment center crossed below the ground threshold.

## Current limitations

- Material profile values are editable prototype values, not measured real-world material constants.
- Profiles are assigned by layer in the test structure; there is no in-game material editor yet.
- Damage uses fragment-center distance and simple falloff.
- Support graph remains a topological approximation, not a stress solver or physical joint network.
- No arbitrary mesh fracture, bending, crack propagation, terrain deformation, world streaming, or debris pooling.
- Manual visual/input/performance testing on the target Windows PC remains outstanding.

## Exact next step

Manually open the project in Godot 4.7.2 and test the three material layers, repeated impacts, collapse, debris settling, and reset on the target PC. Then add material authoring/building presets and evaluate optional physical breakable joints. Terrain deformation remains later.

## Required update protocol

Every substantial session updates this file and `WORK_LOG.md` at three points:
1. **Before:** starting commit, current state, intended scope, references, and risks.
2. **During:** completed units, changed architecture, blockers, and tests already run.
3. **After:** exact changes, CI/manual test results, unverified limitations, current milestone, and one concrete next step.

Never mark a feature complete just because code was committed. State whether it passed CI, manual testing, or remains unverified.
