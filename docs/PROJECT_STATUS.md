# WORLDBREAK Project Status

**Last updated:** 2026-11-10  
**Update point:** After material-profile engineering pass 05  
**Branch:** `feature/worldbreak-godot-foundation`  
**PR:** [#2 - Godot foundation](https://github.com/PanDuroDev/Idk/pull/2) (draft, not merged)

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

## Session 04 result: cumulative damage

Godot 4.7.2 CI passed: [Actions #42857896663](https://github.com/PanDuroDev/Idk/actions/runs/42857896663). It tested one weak hit accumulating damage without breaking, a second hit crossing integrity, support retention, collapse, and reset.

## Session 05 result: data-driven material profiles

<badge color="success">Godot CI passed</badge>

Final full-project validation: [Actions #42859021645](https://github.com/PanDuroDev/Idk/actions/runs/42859021645).

Verified:
- Godot 4.7.2 imported the custom Resource script and all three `.tres` material profiles.
- Project launched headlessly.
- Structure assigned the correct material profile to foundation, middle, and top layers.
- Foundation profile has higher integrity, blast resistance, and density than masonry.
- Masonry breaks after two centered weak hits.
- Foundation resists three such hits and breaks on the fourth.
- Full base-row collapse, support graph behavior, and reset still pass.

The first material test expected foundation concrete to break after three weak hits. The configured integrity/resistance values correctly required a fourth; the assertion was fixed, not the material model weakened.

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
