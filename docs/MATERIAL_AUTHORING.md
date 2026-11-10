# Material Authoring

WORLDBREAK material profiles remain native Godot Resources. The workflow uses the Inspector for authoring, a shared catalog for discoverability/duplicate checks, an EditorScript for validation, and a small preview scene. It deliberately avoids a runtime material editor or a large EditorPlugin.

## Included material resources

The catalog is `resources/materials/material_profile_catalog.tres`. It references the three existing profiles:

- `foundation_concrete.tres`
- `masonry.tres`
- `lightweight_panel.tres`

The catalog does not copy profile data. Existing building definitions and the classic sample continue to reference the same Resource assets.

## Create or edit a profile

1. In the FileSystem dock, select `scripts/destruction_material_profile.gd` and create a new Resource of that script type, then save it under `resources/materials/`.
2. Alternatively, duplicate an existing `.tres` profile from the FileSystem dock and rename the copy. Do not overwrite one of the shared samples when making a variant.
3. Edit the Resource in the Inspector:
   - `material_id`: unique, stable ID used by definitions and configurations.
   - `display_name`: readable name.
   - `integrity`: accumulated damage required to break a cell.
   - `blast_resistance`: scales blast damage received.
   - `density_multiplier`: scales the fragment mass.
   - `surface_color`: visual tint.
4. Add the new Resource to the `profiles` array in `material_profile_catalog.tres`.

The exported ranges guide Inspector editing, but files can also be malformed or edited outside the Inspector. Always run catalog validation after changing a profile or the catalog.

## Duplicate a profile programmatically

`MaterialProfileCatalog.duplicate_profile(source_id, new_material_id, new_display_name)` returns an independent deep copy with the requested new ID and display name. It returns null for an unknown source, blank ID/name, or an ID already present in the catalog. Add the returned Resource to the catalog and save it as a new `.tres` asset; the helper never silently overwrites an existing profile.

`add_profile(profile)` validates the profile and rejects an existing ID before appending it to the in-memory catalog. Save the catalog Resource after an intentional addition.

## Validate the catalog

Open `tools/validate_material_catalog.gd` in Godot's Script Editor and use **File → Run**. A valid catalog prints:

```text
WORLDBREAK_MATERIAL_CATALOG_OK: profiles=3
```

Invalid values, blank IDs/names, duplicate IDs, invalid colors, and null entries are reported as actionable errors. The shared validation logic is also used when building definitions are validated, so a profile cannot pass one route and bypass the other.

## Preview a profile

Open `scenes/material_profile_preview.tscn` in Godot. Select the root `MaterialProfilePreview` node and assign a profile to its `material_profile` property in the Inspector. The preview updates the block tint and displays the ID and tuning values. Invalid profiles are labeled in the preview instead of being presented as valid.

Run the scene with F6 for a camera/light preview. The preview script is editor-enabled but the scene is separate from the gameplay scene; it does not add preview geometry or editor behavior to WORLDBREAK's normal runtime.

## Tuning values are experimental

Integrity, blast resistance, and density are prototype tuning values. They are not measured engineering constants and must not be interpreted as real material specifications.
