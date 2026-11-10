# Building Definitions

WORLDBREAK structures are authored as Godot Resources under `resources/buildings/`. A definition is independent of its world transform and can be assigned to any `DestructibleStructure` node through its `building_definition` property.

## Resource model

- `BuildingDefinition`: version, stable ID, display name, grid dimensions, cell size, center-to-center spacing, origin offset, default material, and occupied-cell array.
- `BuildingCellDefinition`: grid coordinate, optional material override, and optional custom local transform.
- `DestructionMaterialProfile`: the existing material Resource. A cell override wins; otherwise the building default is used.

The regular local center is:

```text
origin_offset + coordinate * cell_spacing
```

`cell_size` controls the shared box mesh and collision shape. `cell_spacing` controls center placement. They are separate so a definition can intentionally leave gaps or overlap cells. A custom transform replaces the regular transform for that cell.

Only occupied cells need to be listed, so layouts may be sparse. The six-axis support graph still receives the occupied `Vector3i` coordinates and remains independent of Resources and scene nodes.

## Included samples

| Resource | Dimensions | Occupied cells | Purpose |
|---|---:|---:|---|
| `classic_70_piece.tres` | 7 × 5 × 2 | 70 | Preserves the original prototype's centers and material-by-layer mapping |
| `sparse_pillar_beam_11.tres` | 5 × 4 × 3 | 11 | Demonstrates a sparse pillar-and-beam layout, one material override, and one custom transform |

The classic preset uses:
- Foundation Concrete at `y = 0`.
- Masonry at `y = 1..3`.
- Lightweight Panel at `y = 4`.

Its original center positions remain:
- `x = (cell.x - 3) * 1.04`
- `y = 0.5 + cell.y * 1.04`
- `z = (cell.z - 0.5) * 1.04`

## Creating another building

1. In Godot's FileSystem dock, create a Resource of type `BuildingDefinition` and save it under `resources/buildings/`.
2. Set a unique `definition_id`, display name, positive dimensions, cell size, spacing, origin offset, and default material profile.
3. Add one `BuildingCellDefinition` per occupied coordinate. Keep coordinates inside the dimensions and avoid duplicates.
4. Assign a per-cell material only where it differs from the default. Enable `use_custom_transform` only when the regular grid transform is insufficient.
5. Run the project validation. The builder validates the entire definition before creating any rigid bodies; invalid definitions fail with actionable errors rather than producing partial structures.

Definitions currently have schema version 1. The validator enforces a 256 occupied-cell ceiling as a conservative implementation guardrail, not as a measured performance target. Do not increase it without profiling on the target hardware.

## Validation rules

The validator rejects unsupported schema versions, blank IDs/names, invalid dimensions, non-finite or non-positive size/spacing, non-finite origin offsets, empty or oversized cell lists, null entries, duplicate/out-of-range coordinates, invalid custom transforms, missing material assignments, invalid material values, and conflicting material IDs across different profile resources.

Material tuning values remain experimental prototype values. They are not calibrated physical constants.

## Runtime behavior

The definition feeds the existing fragment generator. It does not create a second blast, damage, debris-lifecycle, or support system. Each generated fragment remains indexed by its `Vector3i` coordinate, and existing damage accumulation, six-axis support calculation, loose-debris budgets, retirement, and reset behavior are reused.

Phase 2 implementation is split into separate PRs. This document covers building definitions; material authoring and configuration save/load are separate follow-up work.
