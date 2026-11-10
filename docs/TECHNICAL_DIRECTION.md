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

### Measured prototype counts

| Metric | Existing baseline | Bounded implementation |
|---|---:|---:|
| Original structure bodies | 70 | 70 retained for reset |
| Loose bodies after full release | 70 | 70 maximum in the current structure |
| Awake loose-body cap | Unbounded by a lifecycle manager | 70 by default; configurable 1-256 |
| Loose-debris expiry | None | 30 seconds by default |
| Concurrent impact effects | Transient light, no explicit count cap | 8 bursts x 6 motes = 48 motes maximum |
| Effect lifetime | 0.16-second light fade | 0.55-second dust fade |

These are object/count budgets derived from the actual prototype and implementation, not FPS/CPU/GPU measurements. No numerical performance improvement is claimed until the target PC is profiled.

### Loose debris lifecycle

- Only fragments released by damage or loss of support enter the loose-debris lifecycle; intact supported structure remains frozen and is never eligible for retirement.
- Loose fragments naturally use Godot rigid-body sleeping. A radial impulse continues to unfreeze and wake an affected sleeping body.
- Loose debris has a configurable 30-second lifetime by default. Expiry retires the released fragment by hiding it, disabling collision, and clearing its motion; the original node and initial transform/collision/visibility state remain retained so reset restores all 70 original fragments deterministically.
- The active loose-fragment budget defaults to 70, matching the current 70-piece prototype. The budget is configurable up to 256 and deterministically puts excess awake fragments to sleep. This is a baseline guardrail, not evidence that 70 is the optimal target-PC budget; profile larger structures before raising it.
- Reset clears all age/retirement state and restores visibility, collision layers/masks, groups, transforms, velocities, and frozen state.

### Lightweight effects and diagnostics

- Each impact emits a short-lived dust/debris burst made from six small shared-mesh instances. At most eight bursts are alive at once; the oldest burst is evicted when the cap is reached.
- The effect lifetime is 0.55 seconds and uses Compatibility-renderer-friendly mesh instances rather than GPU particles or expensive screen-space effects.
- F3 toggles an opt-in diagnostics panel. The normal HUD remains unchanged while the panel is hidden. Diagnostics include intact/broken/supported/loose/awake/sleeping/retired counts, the configured active-fragment and effect budgets, debris lifetime, impact settings, FPS, physics tick rate, active physics objects, and collision pairs.
- The overlay is a diagnostic view, not a performance benchmark. Collect target-PC measurements separately.

### Explicit limitations
- GitHub Actions runs Godot 4.7.2 headless import, launch, and smoke validation on Linux and Windows. The smoke test simulates an initial 120-frame collapse, then five consecutive 120-frame collapse/reset cycles, checking finite fragment transforms/velocities and ground containment after each cycle. This still does not verify interactive rendering quality, long-duration settling, or target-PC performance.
- The support graph is topological, not a physical bond network.
- Damage uses distance to fragment centers and a linear falloff.
- No force distribution, stress, bending, crack propagation, or physical joint break thresholds.
- No arbitrary mesh fracture or runtime terrain deformation.
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
Runtime terrain deformation is a separate subsystem. The planned direction is chunked mesh/voxel terrain with localized mesh and collision updates. World definitions should be data-driven.

## Research references
- Godot 4.7 RigidBody3D: https://docs.godotengine.org/en/4.7/classes/class_rigidbody3d.html
- Godot 4.7 Joint3D: https://docs.godotengine.org/en/4.7/classes/class_joint3d.html
- Godot 4.7 physics-space access: https://docs.godotengine.org/en/4.7/tutorials/physics/ray-casting.html
- Godot 4.7 performance: https://docs.godotengine.org/en/4.7/tutorials/performance/
