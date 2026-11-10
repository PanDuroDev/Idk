# Phase 2 Architecture Proposal

**Status:** Design-only proposal; Phase 2 runtime implementation remains gated on full Phase 1 acceptance verification and inspection of its merged interfaces, not merely the presence of merged PRs.  
**Baseline reviewed:** `main` at `70da82274da67faf034afb9d98932f4fe1db03f4`.  
**Phase 1 update (2026-11-10):** PRs [#11](https://github.com/PanDuroDev/Idk/pull/11), [#16](https://github.com/PanDuroDev/Idk/pull/16), and [#17](https://github.com/PanDuroDev/Idk/pull/17) are now merged. Issue #5 remains open for full-scope verification; interactive effect/overlay validation and target-PC performance measurements are not established by headless CI. This proposal remains documentation-only.

## Goals and non-goals

Phase 2 should replace the fixed 7 x 5 x 2 construction loop with data-driven definitions while preserving the existing support graph, cumulative damage, blast pipeline, material behavior, and reset semantics. It should make the existing material Resources practical to author and should persist reproducible test configurations safely.

This proposal is not a stress solver, arbitrary mesh fracture system, runtime building editor, or physical-joint conversion. Material values remain prototype tuning values, not real-world constants.

## Current architecture findings

- `scripts/destructible_structure.gd` owns generation, per-cell fragment lookup, material lookup, damage, broken/supported/unsupported state, and reset. Its `_build_structure()` hard-codes 7 x 5 x 2 cells, unit box geometry, 1.04 spacing, and layer-based material selection.
- Cell identity is already represented as `Vector3i`; this is a suitable stable grid coordinate for definitions and support-graph input.
- `StructuralSupportGraph.find_supported_cells(cells, broken_cells)` is a stateless deterministic BFS over six face-adjacent neighbors. It should remain independent of scene nodes and material resources.
- `DestructionMaterialProfile` is already a custom Godot `Resource` with `material_id`, `display_name`, `integrity`, `blast_resistance`, `density_multiplier`, and `surface_color`. Its exported ranges and `create_surface_material()` provide a good native authoring foundation.
- Three shared material assets exist under `resources/materials/`. Current assignment is foundation concrete on the bottom layer, masonry in the middle, and lightweight panels on the top layer.
- `BlastService` owns radial physical impulse queries. Damage is applied separately by the structure, which is important to preserve.
- `main.gd` owns environment/player setup, impact requests, impact settings, HUD, and structure reset. Phase 1 runtime controls were integrated through PR #11, debris lifecycle/budgets through PR #16, and effects/diagnostics through PR #17. Phase 2 must inspect the resulting merged API and preserve those ownership boundaries.
- Existing headless coverage lives in `tests/headless_smoke_test.gd`; the Linux and Windows workflow imports the project, launches headlessly, scans logs, and requires explicit smoke-test markers.

## Proposed resource model

Use native Godot Resources, not JSON dictionaries as the editor's authoring format.

### `BuildingCellDefinition`

One resource per occupied grid cell:

| Field | Type | Meaning |
|---|---|---|
| `coordinate` | `Vector3i` | Unique cell coordinate inside the definition dimensions |
| `material_profile` | `DestructionMaterialProfile` reference, optional | Per-cell override; null means use the building default |
| `use_custom_transform` | `bool` | Whether this cell overrides the regular grid transform |
| `local_transform` | `Transform3D` | Optional local transform for rotated/offset pieces |

Keep this resource small. Do not add per-cell physics tuning until a real use case requires it.

### `BuildingDefinition`

A versioned `Resource` containing:

- `schema_version` (initially 1), stable `definition_id`, and human-readable `display_name`.
- Positive integer `dimensions` (`Vector3i`) defining the grid bounds.
- `cell_size` and `cell_spacing` as positive `Vector3` values. Spacing is the center-to-center pitch; size controls mesh/collision dimensions.
- `origin_offset` as a `Vector3`.
- Optional `default_material_profile`.
- `cells: Array[BuildingCellDefinition]`; sparse layouts are supported by listing only occupied cells.

The builder computes a regular cell center from coordinate, dimensions, spacing, cell size, and origin offset. A custom transform replaces that computed local transform only when explicitly enabled. The resource transform remains separate from the runtime Node3D transform so definitions can be reused at different world positions/rotations.

### Validation contract

Validate the complete definition before creating any fragment. Return all actionable validation messages rather than silently skipping bad entries.

Reject:
- unsupported schema versions, empty IDs/names, non-positive dimensions, non-finite or non-positive cell size/spacing;
- an empty cell list, null cell entries, duplicate coordinates, or coordinates outside `[0, dimensions)`;
- invalid/non-finite custom transforms;
- missing material assignment when neither a cell override nor a default profile exists;
- invalid profile values or duplicate material IDs in a loaded catalog.

Warnings may identify unusually large definitions, but must not silently truncate them. Apply a documented upper bound to occupied cells after profiling and use the same bound in runtime validation and tests.

## Existing 70-piece preset

Represent the current 7 x 5 x 2 layout as a checked-in `BuildingDefinition` resource. It must contain exactly 70 occupied cells and preserve current centers:

`x = (cell.x - 3) * 1.04`  
`y = 0.5 + cell.y * 1.04`  
`z = (cell.z - 0.5) * 1.04`

Assign the existing concrete profile to y=0, lightweight panel to y=4, and masonry to y=1..3. This makes the sample's current behavior data-driven instead of relying on a hidden layer rule.

Add at least one materially different sparse/compact sample layout (for example a 3 x 3 x 3 pillar-and-beam arrangement) to prove that generation is not tied to the original dimensions. Keep test expectations derived from the selected definition rather than hard-coded 70-piece assumptions except in the backward-compatibility test.

## Runtime integration boundary (after Phase 1 acceptance verification)

The future builder should consume a validated definition and create the fragment set from its occupied cells. It should populate the same cell-indexed collections currently used by damage and support logic, and preserve:
- one stable cell-to-fragment mapping;
- per-cell material profile resolution;
- shared mesh, collision, and visual resources where compatible;
- material integrity/resistance/density behavior;
- the existing support graph input and unsupported-fragment release;
- full reset of transforms, velocities, damage, broken state, and support state.

Do not implement a second blast or damage system. Do not make the support graph depend on Resources or scene nodes.

Before implementation, inspect the merged Phase 1 API and explicitly settle ownership of loose-debris cleanup, active-fragment budgets, reset/rebuild sequencing, and impact settings. A building rebuild must not bypass Phase 1 lifecycle rules. Avoid changing `main.gd` unless the final integration contract requires a small, coordinated call-site change.

## Material authoring workflow

Start with Godot-native `.tres` Resources and the Inspector:

1. Create a `DestructionMaterialProfile` resource from the existing script.
2. Set a unique stable `material_id`, display name, integrity, blast resistance, density multiplier, and tint.
3. Duplicate an existing `.tres` file for variants; never edit a built-in sample in place when a separate variant is intended.
4. Validate the profile before assigning it to a building cell.
5. Preview the profile in a tiny editor-only preview scene/tool that uses `create_surface_material()`; do not add preview meshes to the gameplay scene.

Add a reusable validation function that reports invalid IDs, blank names, non-finite/out-of-range values, and duplicate catalog IDs. Keep the current exported fields and their serialized names to preserve compatibility with the three existing assets. The existing `@export_range` hints are helpful Inspector controls but are not a substitute for validation of files loaded from disk.

Do not build a large runtime editor. Add a small `EditorPlugin` only if the Inspector plus validation/preview tool proves insufficient in actual use. Any tuning presets must clearly state that values are experimental and not measured physical constants.

## Save/load format

Use a versioned JSON file for portable simulation test configurations, while keeping reusable building and material authoring assets as Godot Resources.

Suggested top-level shape:

```json
{
  "format": "worldbreak.simulation",
  "schema_version": 1,
  "configuration_id": "masonry-impact-test",
  "display_name": "Masonry impact test",
  "building_definition_id": "sample_70_piece",
  "building_transform": {
    "position": [0.0, 0.0, -12.0],
    "rotation_degrees": [0.0, 0.0, 0.0],
    "scale": [1.0, 1.0, 1.0]
  },
  "material_overrides": [
    { "cell": [3, 2, 0], "material_id": "masonry" }
  ],
  "impact": {
    "radius": 4.5,
    "damage": 4.0,
    "impulse": 22.0,
    "upward_bias": 0.3
  },
  "environment": {
    "gravity": 9.8,
    "time_scale": 1.0
  }
}
```

The example is illustrative; field names and ranges must be finalized against the merged Phase 1 controls before runtime implementation. Keep resource IDs stable and resolve them through an explicit trusted catalog. Never load arbitrary `res://` or filesystem paths supplied by a configuration file.

### Compatibility and failure behavior

- Missing optional fields use documented defaults.
- Missing required fields, invalid types, unknown building/material IDs, invalid numeric ranges, non-finite values, malformed JSON, and unsupported schema versions reject the entire configuration.
- Unknown fields within a supported schema version are ignored with a warning to permit additive evolution.
- Do not mutate the running simulation while parsing or validating. Build a complete candidate configuration, resolve all resource references, validate it, then apply it once at a safe physics boundary.
- A failed load leaves the current simulation untouched and returns a useful error.
- Save to a temporary file, flush and re-read/validate it, then replace the destination. Report write/rename failures; do not report success until replacement succeeds.
- Use deterministic ordering for cell overrides and stable IDs so saved files are reviewable and diff-friendly.

## Test plan

Add pure validation and round-trip tests before integrating with live physics. Extend the existing smoke test only after Phase 1's full acceptance scope is verified and its merged interfaces are reviewed.

Required cases:
- 70-piece preset has 70 unique in-bounds cells and retains the existing material-by-layer mapping and computed centers.
- A second definition produces a different expected cell count/layout without editing gameplay code.
- Sparse cells, custom transforms, and per-cell material overrides are honored.
- Duplicate/out-of-range cells, null entries, invalid dimensions, missing profiles, duplicate IDs, and invalid material values fail with actionable errors.
- Save -> load -> save preserves normalized configuration data.
- Missing optional values default correctly; unknown fields warn and remain harmless; unsupported schema versions reject.
- Corrupt/truncated JSON and failed file operations never partially alter the active simulation.
- Damage, collapse, reset, and Phase 1 loose-debris lifecycle remain correct for definitions with different cell counts.
- Both Linux and Windows CI must require explicit success markers and be inspected for script/runtime errors.

## Optional breakable-joint study

Do not prototype joints yet. The current support graph is deterministic and inexpensive, but no numeric CPU/physics baseline is recorded. First collect Phase 1 profiling data on representative intact, partially damaged, and fully collapsed structures.

Only then compare a small controlled joint prototype against the topology graph. Record body/joint counts, physics-step p50/p95, active bodies, settling time, reset reliability, and solver instability over repeated runs. Do not create a joint for every touching pair by default. If the measured benefit is not clear and repeatable within the target hardware budget, publish a short recommendation to retain the graph and close the optional research item without adding runtime joints.

## Proposed PR sequence

1. **PR 1 - Reusable building definitions:** Resource types, validator, two sample definitions, builder integration, generation/damage/reset tests. Blocked until Phase 1's full acceptance scope is verified and the merged lifecycle/control interfaces are reviewed.
2. **PR 2 - Material authoring:** validation, native Resource/Inspector workflow, duplicate/preview tooling, documentation, material compatibility tests. Keep it isolated from Phase 1-owned files and do not use it to imply that Phase 1 acceptance is complete.
3. **PR 3 - Configuration persistence:** versioned JSON model, catalog resolution, transactional load/apply, safe save, samples, round-trip/error tests. Depends on stable building and Phase 1 impact/environment interfaces.
4. **Optional PR 4 - Joint feasibility decision:** profiling-backed prototype or evidence-based no-go recommendation.

Each implementation PR will use its own `ai/phase-2/<short-scope>` branch and target `main` only when its dependencies are merged. If it depends on an unmerged Phase 2 PR, use an explicit stacked PR.

## Current gate

**Phase 2 runtime implementation is underway.** Phase 1 PRs #11, #16, and #17 are merged, and the final merged control, debris cleanup/budget, reset, and diagnostics interfaces were inspected before implementation. Issue #5 remains open for interactive effect/overlay verification and target-PC FPS/CPU/GPU measurements; these remain explicit Phase 1 acceptance checks and are not claimed as verified by headless CI. Phase 2 PR 1, [#18](https://github.com/PanDuroDev/Idk/pull/18), implements reusable building definitions and has passed the Linux/Windows headless gates. It remains unmerged and does not complete Phase 2.


## Implementation progress: reusable building definitions

The first implementation slice is open as [PR #18](https://github.com/PanDuroDev/Idk) on `ai/phase-2/building-definitions`. It adds `BuildingDefinition` and `BuildingCellDefinition` Resources, shared definition/material validation, data-driven generation in `DestructibleStructure`, the backward-compatible 70-cell preset, and an 11-cell sparse sample. Tests cover compatibility positions/material mapping, sparse generation, per-cell override/custom transform, invalid dimensions/schema/null cells/transforms/material values/catalog IDs, collapse, and reset. Godot 4.7.2 CI passed on Linux and Windows in run #42894517616. The PR remains unmerged pending integration review.
