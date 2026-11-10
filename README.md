# WORLDBREAK

WORLDBREAK is a 3D physics and destruction sandbox in active prototyping. The long-term goal is to let users experiment with impacts, forces, structural collapse, terrain damage, and multiple simulation worlds.

## Current prototype
- First-person movement and a generated 3D test arena.
- A 7 x 5 x 2 modular block structure (70 rigid-body fragments).
- Six-axis support graph rooted at surviving ground anchors.
- Per-fragment accumulated damage with distance falloff and material-specific integrity/resistance.
- Three editable material profiles: Foundation Concrete, Masonry, and Lightweight Panel.
- Radial impacts that break damaged cells and release sections that lose all support paths.
- A small resident chunked terrain patch that blasts carve through bounded mesh and static-collision rebuild queues.
- Six movable physics props, bounded loose-debris lifetime/sleeping, reset-safe cleanup, lightweight dust bursts, and runtime HUD.
- Two reusable building-definition Resources: the classic 70-piece layout and a sparse 11-cell pillar-and-beam sample.
- Versioned JSON simulation configurations that resolve building and material IDs through trusted catalogs, with transactional save/load and live application.
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
| Left mouse button or F | Trigger radial impact |
| R | Reset structure |
| Escape | Release/capture mouse |

The in-game Impact Settings panel adjusts blast radius, damage, and physical impulse. Each value has bounded +/- controls; Reset impact defaults restores the prototype values. Controls are defined through Godot InputMap and can be remapped in Project Settings.

The current prototype retains all 70 original structure nodes for reset. Released fragments use a 30-second default lifetime and a 70-awake-fragment budget; excess bodies are parked until an impact wakes them. Impact dust is capped at eight concurrent bursts (six motes each) with a 0.55-second lifetime.

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
The workflow runs on both Linux and Windows for pull requests to `main` and pushes to `main`.

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

Manual visual and interaction testing on the target Windows PC is still required.

## Project documentation
- [Project status](docs/PROJECT_STATUS.md)
- [Building definition authoring](docs/BUILDING_DEFINITIONS.md)
- [Material profile authoring](docs/MATERIAL_AUTHORING.md)
- [Simulation configuration persistence](docs/CONFIGURATION_PERSISTENCE.md)
- [Work log](docs/WORK_LOG.md)
- [Manual Windows validation checklist](docs/MANUAL_WINDOWS_VALIDATION.md)
- [Technical direction](docs/TECHNICAL_DIRECTION.md)
- [Roadmap](docs/ROADMAP.md)
