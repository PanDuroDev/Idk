# Technical Direction

## Engine and language
- Godot 4.7.2 stable is the project baseline.
- GDScript is the primary language.
- The standard (non-.NET) editor is sufficient; no .NET SDK is required.
- C++ GDExtension is reserved for measured bottlenecks after profiling.

## Rendering and target hardware
- Compatibility renderer is the required baseline.
- Keep the project usable on the target GTX 1660 SUPER 6 GB system.
- Avoid mandatory ray tracing, heavy global illumination, or high-cost screen-space effects.
- Keep particle counts, material complexity, shadow distance, and active-fragment counts configurable.
- Profile CPU physics cost as well as GPU rendering cost.

## Physics-query discipline
Input callbacks queue intent only. The main scene consumes queued requests in `_physics_process()`, where ray/shape queries, impulses, and rigid-body resets execute. `BlastService` reuses its sphere shape and query parameters.

## Destruction architecture

### StructuralSupportGraph
`StructuralSupportGraph` is a deterministic topology solver, not a force solver. It runs breadth-first search from intact bottom-layer anchors through six face-adjacent intact cells.

This provides a predictable approximation:
- Removing one base cell need not collapse a section if an alternate path to ground remains.
- Removing a section's only base path releases the unsupported fragments.
- The test suite verifies complete collapse when the base row is removed.

### Cumulative damage
Each cell tracks accumulated damage. Damage added by a blast is:

`damage_added = blast_damage * max(1 - distance_to_cell_center / blast_radius, 0) / blast_resistance`

A fragment is marked broken only when accumulated damage reaches that cell's profile integrity. Blast damage is independent of physical impulse strength. Reset clears accumulated damage and restores support/body state.

### Data-driven material profiles
`DestructionMaterialProfile` is a custom Godot Resource containing:
- `material_id` and display name.
- Integrity threshold.
- Blast resistance.
- Density multiplier.
- Surface tint.

Current profiles:
| Profile | Integrity | Blast resistance | Density multiplier |
|---|---:|---:|---:|
| Foundation Concrete | 1.6 | 1.2 | 1.3 |
| Masonry | 1.0 | 1.0 | 1.0 |
| Lightweight Panel | 0.65 | 0.8 | 0.75 |

The current test structure assigns profiles by layer: the base uses foundation concrete, the middle uses masonry, and the top uses lightweight panels. Profile Resources are loaded once and reused; their visual materials are shared between fragments. The density multiplier changes each fragment's rigid-body mass. The smoke test checks repeated-hit thresholds for masonry and concrete, plus a one-hit break for the lightweight panel.

These values are editable prototype tuning, not measured real-world material constants. The material assignment is currently layer-based, not an in-game material editor.

### Explicit limitations
- GitHub Actions runs Godot 4.7.2 headless import, launch, and smoke validation on Linux and Windows. The smoke test simulates an initial 120-frame collapse, then five consecutive 120-frame collapse/reset cycles, checking finite fragment transforms/velocities and ground containment after each cycle. This still does not verify interactive rendering quality, long-duration settling, or target-PC performance.
- The support graph is topological, not a physical bond network.
- Damage uses distance to fragment centers and a linear falloff.
- No force distribution, stress, bending, crack propagation, or physical joint break thresholds.
- No arbitrary mesh fracture. Runtime terrain deformation is limited to the resident prototype patch.
- Headless tests verify logic and state transitions, not visual quality or real-world frame rate.

### Future physical-bond model
Godot `Joint3D` can constrain pairs of physics bodies. Optional breakable links may be added after graph and integrity models are validated and profiled. That layer needs explicit strength thresholds and solver-stability tests.

## Resource and performance strategy
- Share immutable meshes, collision shapes, and materials.
- Keep primitive collision shapes for modular blocks.
- Cap query results, queued impacts, active fragments, and effect instances.
- Add debris lifetime/pooling after defining an active-fragment budget.
- Avoid PhysicsServer3D or native extensions until profiling shows a real bottleneck.

## Terrain and worlds
Runtime terrain deformation is a separate subsystem. The Phase 3 prototype uses chunked scalar density fields with a fixed tetrahedral isosurface mesher, duplicated global border samples, a deterministic edit journal, and bounded static-collider and mesh replacement queues. Heightfields are insufficient for caves/overhangs; Marching Tetrahedra is a compact spike with a higher triangle-count trade-off versus Marching Cubes. `TerrainWorld` now coordinates a small resident patch in the gameplay scene: blasts carve only the resident chunks they intersect, and reset clears the journal and restores base density. This is an encounter-sized resident patch, not a chunk streamer. See docs/TERRAIN_ARCHITECTURE.md for the current API, limits, and known gaps. World definitions should be data-driven.

## Research references
- Godot 4.7 RigidBody3D: https://docs.godotengine.org/en/4.7/classes/class_rigidbody3d.html
- Godot 4.7 Joint3D: https://docs.godotengine.org/en/4.7/classes/class_joint3d.html
- Godot 4.7 physics-space access: https://docs.godotengine.org/en/4.7/tutorials/physics/ray-casting.html
- Godot 4.7 performance: https://docs.godotengine.org/en/4.7/tutorials/performance/
