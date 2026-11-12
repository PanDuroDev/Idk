# WORLDBREAK

WORLDBREAK is a 3D physics and destruction sandbox in active prototyping. The long-term goal is to let users experiment with impacts, forces, structural collapse, terrain damage, and multiple simulation worlds.

## Current prototype
- First-person movement with switchable first-person, orbit, and overview cameras (panel row or C). Orbit and overview aim and fire from their own view, lock player movement, and support right-drag rotation/pan plus wheel zoom.
- A 7 x 5 x 2 modular block structure (70 rigid-body fragments).
- Six-axis support graph rooted at surviving ground anchors.
- Per-fragment accumulated damage with distance falloff and material-specific integrity/resistance.
- Three editable material profiles: Foundation Concrete, Masonry, and Lightweight Panel.
- Radial impacts that break damaged cells and release sections that lose all support paths.
- A resident chunked terrain patch under the whole arena whose surface blasts carve through bounded mesh and static-collision rebuild queues. The shipped worlds use a configurable 4x4 patch (64x64 units); a floor far below only catches debris.
- Nine movable physics props (crates, barrels, and cones), bounded loose-debris lifetime/sleeping, reset-safe cleanup, a blast flash/shockwave look with dust and debris chips, and a runtime HUD.
- A Garry's-Mod-style sandbox layer: Tab spawn menu with CC0 Kenney rockets, barrels, meteors, rocks, and machines; E carry/drop; left-mouse throw with aim and momentum; thrown rockets detonate on contact.
- Two reusable building-definition Resources: the classic 70-piece layout and a sparse 11-cell pillar-and-beam sample.
- Versioned JSON simulation configurations that resolve building and material IDs through trusted catalogs, with transactional save/load and live application.
- Two data-driven world presets (`Classic Yard`, `Sparse Quarry`) that reuse those building, material, configuration, terrain, and environment systems, with runtime load, unload, reset, and a one-resident-world bound.
- A unified Simulation Control panel for world, scenario, and material selection; blast/gravity/time-scale controls; pause/resume/reset; settled-outcome runs; and a bounded 50-run experiment history with JSON/CSV export.
- Three versioned experiment scenarios (`Foundation Strike`, `Terrain Crater`, `Sparse Beam Shear`) with repeatable setup, run comparison, and result metadata.
- A procedural sky with filmic tonemapping and sky-based ambient light, plus a compact monochrome game UI: rounded near-black panels, subtle borders, consistent control states, one control hint line, a bounded scrollable Simulation Control panel, and a matching Spawn Menu/debug overlay.
- Optional destruction/physics diagnostics overlay toggled with F3.

The support graph is a deterministic topology approximation. The material profiles are tunable prototype values, not calibrated material data. There is no arbitrary mesh fracture. Terrain deformation is limited to the resident prototype patch described in `docs/TERRAIN_ARCHITECTURE.md`.

## Requirements
- Godot **4.7.2 stable**, standard edition.
- No .NET SDK required.
- Compatibility renderer baseline.

## Run
1. Open `project.godot` in Godot 4.7.2.
2. Press **F5**.

## Controls
| Input | Action |
|---|---|
| WASD | Move |
| Space | Jump |
| Mouse | Look |
| Left mouse button or F | Blast tool impact, or throw the carried prop |
| E | Pick up or drop a prop |
| Tab | Toggle the spawn menu |
| R | Reset structure |
| P | Pause/resume simulation |
| F3 | Toggle destruction/physics diagnostics |
| C | Cycle first-person / orbit / overview cameras |
| Right mouse drag | Orbit: rotate. Overview: pan |
| Mouse wheel | Orbit/overview: zoom in or out |
| Escape | Release/capture mouse |

The in-game Simulation Control panel adjusts blast radius, damage, physical impulse, gravity, and time scale; selects world, scenario, material, and camera presets; runs settled scenarios and resets them; pauses/resumes physics; and exports the bounded run history as JSON or CSV. Its contents are vertically scrollable. Settled runs wait a bounded physics window and record broken/loose counts, awake/sleeping bodies, moved fragments, and settle frames. Material selection applies an existing catalog profile to the resident building through the Phase 2 override path; `default` restores the building definition's materials. Pause stops scene-tree physics without overwriting the experiment time scale. Movement and impact inputs are defined through Godot InputMap and can be remapped in Project Settings.

The monochrome interface uses one shared Theme across the HUD, Simulation Control, Spawn Menu, and diagnostics. Panels use rounded near-black surfaces with subtle borders; controls use consistent normal/hover/pressed/focus/disabled states, heights, and spacing; the settled scenario action is visually primary; and a single muted line lists the main controls. The window starts maximized, renders its UI on a 1920x1080 canvas that scales with the window, and expands to the display aspect, so panels stay pinned to their corners on any modern resolution. The Simulation Control panel has a bounded height instead of a full-height column and shows a slim custom scrollbar only when its content grows.

The sandbox spawn menu (Tab) spawns weighted CC0 Kenney props — rockets, barrels, meteors, rocks, and machines — in front of the active camera, up to 24 bodies. Each loaded world places two starter rockets near its configured player spawn; switching worlds removes the previous world's spawned props, and unloading a world clears them. E carries the prop under the crosshair; the left mouse button throws it with the camera's aim and the player's momentum, and E drops it. A thrown rocket detonates on its first solid contact, using the same crater, damage, impulse, chips, and shake path as the blast tool, and any rockets inside a blast radius chain-detonate. The blast is queued from the contact callback and applied on the next physics tick. The left mouse button still fires the blast tool when nothing is carried, and in orbit or overview the blast starts at the active camera instead of the player.

The current prototype retains all 70 original structure nodes for reset. Released fragments use a 30-second default lifetime and a 70-awake-fragment budget; excess bodies are parked until an impact wakes them. Impact effects are capped at eight concurrent bursts, each with an emissive core, a ground shockwave ring, and six dust motes, with a 0.55-second lifetime; the meshes and dust/chip materials are created once and reused across bursts. Blasts carve the terrain under the hit point, so craters remain until the world is reset. Bundled CC0 assets are credited in `assets/CREDITS.md`.

## Architecture
- GDScript and Godot Physics 3D.
- `BlastService` handles reusable radial shape queries and physical impulse falloff.
- `TerrainWorld` owns a bounded resident patch, delegates blasts to the terrain edit journal, and drains mesh/collision rebuild queues.
- `StructuralSupportGraph` computes cells connected to bottom-layer anchors.
- `DestructionMaterialProfile` Resources define integrity, blast resistance, density multiplier, and tint.
- Cells accumulate damage until their material-specific integrity threshold is reached.
- Blast damage and physical impulse strength are independent settings.
- Physics queries and rigid-body mutations run in the physics tick.
- Generated fragments share mesh, collision, and material resources.
- `SimulationConfigurationCodec` reads and writes versioned JSON; unknown fields warn, malformed or unsupported data rejects the whole file, and failed loads leave the running simulation untouched.
- Configurations reference building and material IDs from `BuildingDefinitionCatalog` and `MaterialProfileCatalog`; they never load arbitrary resource paths.

## Validation
The workflow runs on both Linux and Windows for pull requests to any branch and pushes to `main`, `ai/phase-3/**`, `ai/phase-4/**`, and `ai/phase-5/**`.

GitHub Actions imports and launches the project headlessly, then tests:
- Support graph connectivity and alternate support paths.
- Base-row failure and collapse, followed by 120 physics frames of live rigid-body simulation.
- Five consecutive collapse/reset cycles, with 120 physics frames and ground/finite-state checks per cycle.
- Finite fragment transforms/velocities and ground-containment checks after the collapse.
- Material profile assignment and relative integrity/resistance values.
- First weak hit accumulating without break.
- Repeated weak hits crossing the masonry and concrete thresholds.
- A single weak hit crossing the lightweight panel threshold.
- Reset clearing damage and restoring fragment/graph state.
- Configuration catalog validation, documented defaults, unknown-field warnings, unsupported/malformed/corrupt rejection, save/load round-trips, building-definition round-trips, and live apply/reset behavior.
- Every save is re-read and validated before the destination file is replaced.
- Scenario catalog validation, scenario load/repeat/reset, settled post-impact metrics, run comparison, terrain-only carving, material selection, pause/resume, JSON/CSV export metadata and escaping, unsupported-extension rejection, and the 50-run history bound.

Manual visual and interaction testing on the target Windows PC is still required.

## Project documentation
- [Project status](docs/PROJECT_STATUS.md)
- [Building definition authoring](docs/BUILDING_DEFINITIONS.md)
- [Material profile authoring](docs/MATERIAL_AUTHORING.md)
- [Simulation configuration persistence](docs/CONFIGURATION_PERSISTENCE.md)
- [World definitions and loading](docs/WORLD_DEFINITIONS.md)
- [Work log](docs/WORK_LOG.md)
- [Manual Windows validation checklist](docs/MANUAL_WINDOWS_VALIDATION.md)
- [Technical direction](docs/TECHNICAL_DIRECTION.md)
- [Roadmap](docs/ROADMAP.md)
