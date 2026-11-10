class_name WorldDefinitionValidator
extends RefCounted
## Validates a world preset and resolves its simulation configuration before
## any runtime state is changed.

const WorldDefinitionScript = preload("res://scripts/world_definition.gd")
const SimulationConfigurationCodecScript = preload("res://scripts/simulation_configuration_codec.gd")
const BuildingDefinitionCatalogScript = preload("res://scripts/building_definition_catalog.gd")
const MaterialProfileCatalogScript = preload("res://scripts/material_profile_catalog.gd")

const MAX_AMBIENT_ENERGY: float = 4.0
const MAX_SUN_ENERGY: float = 8.0


static func validate_definition(
	world: WorldDefinitionScript,
	building_catalog: BuildingDefinitionCatalogScript,
	material_catalog: MaterialProfileCatalogScript
) -> Dictionary:
	var errors: Array[String] = []
	var configuration = null
	if world == null:
		errors.append("World definition is null.")
		return {"ok": false, "errors": errors, "configuration": configuration}

	if world.schema_version != WorldDefinitionScript.CURRENT_SCHEMA_VERSION:
		errors.append("Unsupported world schema version: %d." % world.schema_version)
	if String(world.world_id).strip_edges().is_empty():
		errors.append("World ID must not be empty.")
	if world.display_name.strip_edges().is_empty():
		errors.append("World display name must not be empty.")
	if not world.player_spawn.is_finite():
		errors.append("World player spawn must contain finite values.")
	if not _is_valid_color(world.background_color):
		errors.append("World background color must contain finite channels within 0..1.")
	if not _is_valid_color(world.ambient_color):
		errors.append("World ambient color must contain finite channels within 0..1.")
	if not is_finite(world.ambient_energy) or world.ambient_energy < 0.0 or world.ambient_energy > MAX_AMBIENT_ENERGY:
		errors.append("World ambient energy must be finite and within 0..%.1f." % MAX_AMBIENT_ENERGY)
	if not world.sun_rotation_degrees.is_finite():
		errors.append("World sun rotation must contain finite values.")
	if not is_finite(world.sun_energy) or world.sun_energy < 0.0 or world.sun_energy > MAX_SUN_ENERGY:
		errors.append("World sun energy must be finite and within 0..%.1f." % MAX_SUN_ENERGY)
	if not world.terrain_position.is_finite():
		errors.append("World terrain position must contain finite values.")
	if not _is_valid_color(world.terrain_surface_color):
		errors.append("World terrain surface color must contain finite channels within 0..1.")

	var configuration_path: String = world.simulation_configuration_path.strip_edges()
	if configuration_path.is_empty():
		errors.append("World simulation configuration path must not be empty.")
	elif not configuration_path.begins_with("res://") or not configuration_path.ends_with(".json"):
		errors.append("World simulation configuration must be a res:// JSON file.")
	elif not FileAccess.file_exists(configuration_path):
		errors.append("World simulation configuration does not exist: '%s'." % configuration_path)
	else:
		var loaded: Dictionary = SimulationConfigurationCodecScript.load_from_file(
			configuration_path,
			building_catalog,
			material_catalog
		)
		if not loaded["ok"]:
			for configuration_error: String in loaded["errors"]:
				errors.append("World simulation configuration: %s" % configuration_error)
		else:
			configuration = loaded["configuration"]

	return {"ok": errors.is_empty(), "errors": errors, "configuration": configuration}


static func _is_valid_color(color: Color) -> bool:
	if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
		return false
	return (
		color.r >= 0.0 and color.r <= 1.0
		and color.g >= 0.0 and color.g <= 1.0
		and color.b >= 0.0 and color.b <= 1.0
		and color.a >= 0.0 and color.a <= 1.0
	)
