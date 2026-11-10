# World Definitions

## Purpose

A world is a reusable preset that selects and configures existing systems. It does not own a parallel building, material, terrain, or simulation-configuration format. Phase 4 adds versioned world data, a catalog, two sample worlds, runtime load/unload/reset, and a one-resident-world bound.

## Data model

`scripts/world_definition.gd` (`WorldDefinition`, schema version 1) stores:

- Identity: `world_id`, `display_name`, optional description.
- Simulation: a `res://` JSON path consumed by the existing `SimulationConfigurationCodec`. Building definitions, material overrides, impact settings, gravity, and time scale remain in that versioned document.
- Spawn: `player_spawn`.
- Environment: background color, ambient color/energy, sun rotation/energy/shadow flag.
- Terrain presentation: enabled flag, patch position, surface color, and the existing low-end profile flag.

`scripts/world_catalog.gd` (`WorldCatalog`) groups world definitions and enforces unique non-empty IDs. `scripts/world_definition_validator.gd` validates schema version, identity, finite transforms, color/energy bounds, the `res://` JSON path, and the referenced simulation configuration. It resolves the configuration before the scene is changed.

Sample resources:

- `resources/worlds/classic_yard.tres` uses `classic_default.json`, the 70-piece building, default terrain, and default environment.
- `resources/worlds/sparse_quarry.tres` uses `sparse_pillar_beam_test.json`, the 11-cell building, the low-end terrain profile, a warmer environment, and heavier gravity.

`resources/worlds/world_catalog.tres` references both.

## Runtime behavior

`main.gd` exposes `load_world(world_id)`, `unload_world()`, `request_world_reset()`, `get_world_ids()`, `get_active_world_definition()`, `get_resident_world_count()`, and `get_max_resident_worlds()`.

`load_world` validates the definition and its configuration first, then applies the existing simulation configuration, environment, terrain preset, and spawn. A failure leaves the active world unchanged. Loading another world releases the previous terrain and structure first.

`unload_world` releases the structure and terrain, restores default environment, gravity, time scale, and spawn, and clears pending blasts. Shared arena ground, props, player, and UI remain.

Reset restores the active structure, terrain, and player spawn without reloading the world preset.

The residency bound is one world. Loading is synchronous; there is no background streamer or load queue. Terrain edits and prop positions are not persisted across world switches.

## Known gaps

- No interactive world selector yet; selection is a runtime API used by tests and available to the Phase 5 panel.
- No world streaming or distance-based chunk residency.
- No save/load of world-local deformation or prop state.
- Headless tests verify state transitions and resource wiring, not visual quality or target-PC frame rate.
