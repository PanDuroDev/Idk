# Simulation Configuration Persistence

**Status:** Implemented on `ai/phase-2/configuration-persistence`, stacked on PR #19. Building and material authoring remains in native Godot Resources; this layer only saves reproducible simulation settings.

## Format

Configurations are JSON files with `format: "worldbreak.simulation"` and `schema_version: 1`.

```json
{
  "format": "worldbreak.simulation",
  "schema_version": 1,
  "configuration_id": "sparse_pillar_beam_test",
  "display_name": "Sparse pillar and beam material test",
  "building_definition_id": "sparse_pillar_beam_11",
  "building_transform": {
    "position": [0.0, 0.0, -12.0],
    "rotation_degrees": [0.0, 15.0, 0.0],
    "scale": [1.0, 1.0, 1.0]
  },
  "material_overrides": [
    { "cell": [0, 0, 1], "material_id": "lightweight_panel" }
  ],
  "impact": {
    "radius": 6.0,
    "damage": 6.5,
    "impulse": 30.0,
    "upward_bias": 0.45
  },
  "environment": {
    "gravity": 12.5,
    "time_scale": 0.85
  }
}
```

Samples:

- `resources/configurations/classic_default.json`
- `resources/configurations/sparse_pillar_beam_test.json`

## Resolution rules

- `building_definition_id` resolves through `resources/buildings/building_definition_catalog.tres`.
- `material_id` resolves through `resources/materials/material_profile_catalog.tres`.
- A configuration never supplies a `res://` or filesystem path for a building or material.
- Material overrides must name an occupied cell inside the referenced building definition.

## Validation

`SimulationConfigurationCodec` rejects the entire file when:

- `format` is wrong, `schema_version` is unsupported, or required fields are missing;
- a building/material ID is unknown;
- an override cell is duplicated, outside the building, or unoccupied;
- a number is non-finite or outside its documented range;
- the building transform is non-finite or degenerate;
- JSON is malformed or the file cannot be read.

Unknown fields inside a supported schema version are ignored with warnings so the format can evolve additively. Missing optional fields use the documented defaults: blast radius 4.5, damage 4.0, impulse 22.0, upward bias 0.3, gravity 9.8, time scale 1.0, identity transform, and no material overrides.

## Save behavior

- Only `.json` configuration paths and `.tres` building-definition paths are accepted.
- Save validates first, writes a temporary file, re-reads and re-validates it, then replaces the destination while keeping a short-lived backup.
- Failed validation or I/O returns actionable errors and does not claim success.
- Load validates the complete candidate before applying anything.

## Live application

`main.gd` exposes:

- `apply_simulation_configuration(configuration) -> Array[String]`
- `load_simulation_configuration(path) -> Dictionary`
- `save_simulation_configuration(path) -> Dictionary`
- `get_active_simulation_configuration()`

Applying rebuilds the `DestructibleStructure` from the resolved definition and per-cell overrides, applies the building transform and impact settings, and applies gravity per rigid body plus `Engine.time_scale`. Invalid configurations leave the active building and settings untouched. Reset still restores the rebuilt building to its new initial state.

Gravity is applied as a rigid-body `gravity_scale` relative to the 9.8 project baseline instead of mutating global physics settings at runtime.

## Tests

`tests/phase2/configuration_persistence_test.gd` covers catalog validation, both samples, defaults, additive warnings, unsupported versions, malformed/corrupt files, invalid IDs/ranges/cells/transforms, save/load round-trips, building-definition save/load, live apply/reset, and the guarantee that an invalid apply leaves the active simulation unchanged. Linux and Windows CI run the test and require `WORLDBREAK_CONFIGURATION_PERSISTENCE_OK`.

## Limitations

- Runtime selection/file picker UI is not part of this PR.
- The configuration format does not itself store world IDs or experiment/scenario metadata; Phase 4 world definitions reference configurations, and Phase 5 experiment history records world/building/material/scenario metadata separately.
- Headless tests do not prove inspector ergonomics or visual correctness.
