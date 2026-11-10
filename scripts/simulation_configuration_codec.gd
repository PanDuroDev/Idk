class_name SimulationConfigurationCodec
extends RefCounted
## Versioned JSON codec for simulation test configurations.
## Building and material authoring stays in native Resources; JSON files only
## reference stable IDs from trusted catalogs.

const SimulationConfigurationScript = preload("res://scripts/simulation_configuration.gd")
const SimulationMaterialOverrideScript = preload("res://scripts/simulation_material_override.gd")
const BuildingDefinitionValidatorScript = preload("res://scripts/building_definition_validator.gd")
const BuildingDefinitionCatalogScript = preload("res://scripts/building_definition_catalog.gd")
const MaterialProfileCatalogScript = preload("res://scripts/material_profile_catalog.gd")
const BuildingDefinitionScript = preload("res://scripts/building_definition.gd")

const FORMAT: String = "worldbreak.simulation"
const CURRENT_SCHEMA_VERSION: int = 1
const MIN_BLAST_RADIUS: float = 0.5
const MAX_BLAST_RADIUS: float = 12.0
const MIN_BLAST_DAMAGE: float = 0.1
const MAX_BLAST_DAMAGE: float = 10.0
const MIN_BLAST_IMPULSE: float = 1.0
const MAX_BLAST_IMPULSE: float = 100.0
const MIN_GRAVITY: float = 0.0
const MAX_GRAVITY: float = 50.0
const MIN_TIME_SCALE: float = 0.05
const MAX_TIME_SCALE: float = 10.0

const TOP_LEVEL_FIELDS: Array[String] = [
	"format", "schema_version", "configuration_id", "display_name",
	"building_definition_id", "building_transform", "material_overrides",
	"impact", "environment"
]
const IMPACT_FIELDS: Array[String] = ["radius", "damage", "impulse", "upward_bias"]
const ENVIRONMENT_FIELDS: Array[String] = ["gravity", "time_scale"]
const TRANSFORM_FIELDS: Array[String] = ["position", "rotation_degrees", "scale"]
const OVERRIDE_FIELDS: Array[String] = ["cell", "material_id"]


static func to_dictionary(configuration: SimulationConfigurationScript) -> Dictionary:
	if configuration == null:
		return {}
	var overrides: Array[Dictionary] = []
	var sorted_overrides: Array[SimulationMaterialOverrideScript] = configuration.material_overrides.duplicate()
	sorted_overrides.sort_custom(_sort_overrides)
	for override: SimulationMaterialOverrideScript in sorted_overrides:
		if override == null:
			continue
		overrides.append({
			"cell": [override.cell.x, override.cell.y, override.cell.z],
			"material_id": String(override.material_id)
		})
	var transform: Transform3D = configuration.building_transform
	var scale: Vector3 = transform.basis.get_scale()
	var euler: Vector3 = transform.basis.orthonormalized().get_euler()
	return {
		"format": FORMAT,
		"schema_version": CURRENT_SCHEMA_VERSION,
		"configuration_id": String(configuration.configuration_id),
		"display_name": configuration.display_name,
		"building_definition_id": String(configuration.building_definition_id),
		"building_transform": {
			"position": [transform.origin.x, transform.origin.y, transform.origin.z],
			"rotation_degrees": [rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)],
			"scale": [scale.x, scale.y, scale.z]
		},
		"material_overrides": overrides,
		"impact": {
			"radius": configuration.blast_radius,
			"damage": configuration.blast_damage,
			"impulse": configuration.blast_impulse,
			"upward_bias": configuration.blast_upward_bias
		},
		"environment": {
			"gravity": configuration.gravity,
			"time_scale": configuration.time_scale
		}
	}


static func from_dictionary(
	data: Variant,
	building_catalog: BuildingDefinitionCatalogScript,
	material_catalog: MaterialProfileCatalogScript
) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var result := {
		"ok": false,
		"configuration": null,
		"errors": errors,
		"warnings": warnings
	}
	if not data is Dictionary:
		errors.append("Configuration root must be a JSON object.")
		return result
	if building_catalog == null:
		errors.append("Building definition catalog is required.")
	if material_catalog == null:
		errors.append("Material profile catalog is required.")
	if not errors.is_empty():
		return result
	if String(data.get("format", "")) != FORMAT:
		errors.append("Unsupported configuration format; expected '%s'." % FORMAT)
		return result

	var schema_version: int = _read_integral_int(data.get("schema_version"), "schema_version", errors)
	if errors.is_empty() and schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("Unsupported configuration schema version: %d." % schema_version)
		return result

	for key: String in data.keys():
		if not TOP_LEVEL_FIELDS.has(key):
			warnings.append("Unknown top-level configuration field '%s' was ignored." % key)

	var configuration: SimulationConfigurationScript = SimulationConfigurationScript.new()
	configuration.configuration_id = StringName(_read_required_string(data, "configuration_id", errors))
	configuration.display_name = String(data.get("display_name", String(configuration.configuration_id))).strip_edges()
	if configuration.display_name.is_empty():
		configuration.display_name = String(configuration.configuration_id)
	configuration.building_definition_id = StringName(_read_required_string(data, "building_definition_id", errors))
	configuration.building_transform = _read_transform(data.get("building_transform"), errors, warnings)

	_read_impact(data.get("impact"), configuration, errors, warnings)
	_read_environment(data.get("environment"), configuration, errors, warnings)
	_read_material_overrides(data.get("material_overrides"), configuration, errors, warnings)

	for catalog_error: String in building_catalog.validate_catalog():
		errors.append("Building catalog: " + catalog_error)
	for catalog_error: String in material_catalog.validate_catalog():
		errors.append("Material catalog: " + catalog_error)
	if not errors.is_empty():
		return result

	var definition: BuildingDefinitionScript = building_catalog.get_definition_by_id(configuration.building_definition_id)
	if definition == null:
		errors.append("Unknown building definition ID '%s'." % String(configuration.building_definition_id))
	else:
		_validate_overrides_against_definition(configuration, definition, material_catalog, errors)

	_validate_ranges(configuration, errors)
	if not errors.is_empty():
		return result

	result["ok"] = true
	result["configuration"] = configuration
	return result


static func validate_configuration(
	configuration: SimulationConfigurationScript,
	building_catalog: BuildingDefinitionCatalogScript,
	material_catalog: MaterialProfileCatalogScript
) -> Dictionary:
	if configuration == null:
		var null_errors: Array[String] = ["Configuration is null."]
		var null_warnings: Array[String] = []
		return {"ok": false, "errors": null_errors, "warnings": null_warnings}
	return from_dictionary(to_dictionary(configuration), building_catalog, material_catalog)


static func save_to_file(
	configuration: SimulationConfigurationScript,
	path: String,
	building_catalog: BuildingDefinitionCatalogScript,
	material_catalog: MaterialProfileCatalogScript
) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if not path.to_lower().ends_with(".json"):
		errors.append("Configuration files must use the .json extension.")
		return {"ok": false, "errors": errors, "warnings": warnings}
	var validation: Dictionary = validate_configuration(configuration, building_catalog, material_catalog)
	warnings.assign(validation["warnings"])
	if not validation["ok"]:
		errors.assign(validation["errors"])
		return {"ok": false, "errors": errors, "warnings": warnings}

	var payload: String = JSON.stringify(to_dictionary(configuration), "\t", true)
	var temp_path: String = path + ".tmp"
	var directory: String = path.get_base_dir()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if directory_error != OK:
		errors.append("Could not create configuration directory '%s' (error %d)." % [directory, directory_error])
		return {"ok": false, "errors": errors, "warnings": warnings}

	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		errors.append("Could not open temporary configuration file for writing: %s" % temp_path)
		return {"ok": false, "errors": errors, "warnings": warnings}
	file.store_string(payload)
	file.flush()
	file.close()

	# Re-read and validate the bytes before replacing the destination.
	var verify_file: FileAccess = FileAccess.open(temp_path, FileAccess.READ)
	if verify_file == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		errors.append("Temporary configuration file could not be re-read.")
		return {"ok": false, "errors": errors, "warnings": warnings}
	var verify_text: String = verify_file.get_as_text()
	verify_file.close()
	var verify_parser := JSON.new()
	if verify_parser.parse(verify_text) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		errors.append("Written configuration is not valid JSON.")
		return {"ok": false, "errors": errors, "warnings": warnings}
	var verify: Dictionary = from_dictionary(verify_parser.data, building_catalog, material_catalog)
	if not verify["ok"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		errors.append("Written configuration failed re-validation.")
		errors.append_array(verify["errors"])
		return {"ok": false, "errors": errors, "warnings": warnings}

	var absolute_path: String = ProjectSettings.globalize_path(path)
	var backup_path: String = ProjectSettings.globalize_path(temp_path + ".bak")
	var had_existing: bool = FileAccess.file_exists(path)
	if had_existing:
		DirAccess.remove_absolute(backup_path)
		var backup_error: Error = DirAccess.rename_absolute(absolute_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
			errors.append("Could not prepare the destination for replacement (error %d)." % backup_error)
			return {"ok": false, "errors": errors, "warnings": warnings}
	var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), absolute_path)
	if rename_error != OK:
		if had_existing:
			DirAccess.rename_absolute(backup_path, absolute_path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		errors.append("Could not replace the configuration file (error %d)." % rename_error)
		return {"ok": false, "errors": errors, "warnings": warnings}
	if had_existing:
		DirAccess.remove_absolute(backup_path)
	return {"ok": true, "errors": errors, "warnings": warnings}


static func load_from_file(
	path: String,
	building_catalog: BuildingDefinitionCatalogScript,
	material_catalog: MaterialProfileCatalogScript
) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if not path.to_lower().ends_with(".json"):
		errors.append("Configuration files must use the .json extension.")
		return {"ok": false, "configuration": null, "errors": errors, "warnings": warnings}
	if not FileAccess.file_exists(path):
		errors.append("Configuration file does not exist: %s" % path)
		return {"ok": false, "configuration": null, "errors": errors, "warnings": warnings}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Could not open configuration file: %s" % path)
		return {"ok": false, "configuration": null, "errors": errors, "warnings": warnings}
	var text: String = file.get_as_text()
	file.close()

	var parser := JSON.new()
	var parse_error: Error = parser.parse(text)
	if parse_error != OK:
		errors.append("Malformed JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return {"ok": false, "configuration": null, "errors": errors, "warnings": warnings}
	return from_dictionary(parser.data, building_catalog, material_catalog)


static func save_building_definition(definition: BuildingDefinitionScript, path: String) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if definition == null:
		errors.append("Building definition is null.")
		return {"ok": false, "errors": errors, "warnings": warnings}
	if not path.to_lower().ends_with(".tres"):
		errors.append("Building definition files must use the .tres extension.")
		return {"ok": false, "errors": errors, "warnings": warnings}
	for error_text: String in BuildingDefinitionValidatorScript.validate_definition(definition):
		errors.append(error_text)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "warnings": warnings}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var save_error: Error = ResourceSaver.save(definition, path)
	if save_error != OK:
		errors.append("Could not save building definition (error %d)." % save_error)
		return {"ok": false, "errors": errors, "warnings": warnings}
	return {"ok": true, "errors": errors, "warnings": warnings}


static func load_building_definition(path: String, max_occupied_cells: int = 256) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if not path.to_lower().ends_with(".tres"):
		errors.append("Building definition files must use the .tres extension.")
		return {"ok": false, "definition": null, "errors": errors, "warnings": warnings}
	if not ResourceLoader.exists(path):
		errors.append("Building definition file does not exist: %s" % path)
		return {"ok": false, "definition": null, "errors": errors, "warnings": warnings}
	var resource: Resource = ResourceLoader.load(path)
	if not resource is BuildingDefinitionScript:
		errors.append("File did not load a BuildingDefinition resource: %s" % path)
		return {"ok": false, "definition": null, "errors": errors, "warnings": warnings}
	var definition: BuildingDefinitionScript = resource as BuildingDefinitionScript
	for error_text: String in BuildingDefinitionValidatorScript.validate_definition(definition, max_occupied_cells):
		errors.append(error_text)
	if not errors.is_empty():
		return {"ok": false, "definition": null, "errors": errors, "warnings": warnings}
	return {"ok": true, "definition": definition, "errors": errors, "warnings": warnings}


static func _read_transform(value: Variant, errors: Array[String], warnings: Array[String]) -> Transform3D:
	if value == null:
		return Transform3D.IDENTITY
	if not value is Dictionary:
		errors.append("building_transform must be an object.")
		return Transform3D.IDENTITY
	for key: String in value.keys():
		if not TRANSFORM_FIELDS.has(key):
			warnings.append("Unknown building_transform field '%s' was ignored." % key)
	var position: Vector3 = _read_vector3(value.get("position", [0.0, 0.0, 0.0]), "building_transform.position", errors)
	var rotation_degrees: Vector3 = _read_vector3(value.get("rotation_degrees", [0.0, 0.0, 0.0]), "building_transform.rotation_degrees", errors)
	var scale: Vector3 = _read_vector3(value.get("scale", [1.0, 1.0, 1.0]), "building_transform.scale", errors)
	if scale.x <= 0.0 or scale.y <= 0.0 or scale.z <= 0.0:
		errors.append("building_transform.scale must be positive on all axes.")
	var euler := Vector3(deg_to_rad(rotation_degrees.x), deg_to_rad(rotation_degrees.y), deg_to_rad(rotation_degrees.z))
	return Transform3D(Basis.from_euler(euler).scaled(scale), position)


static func _read_impact(value: Variant, configuration: SimulationConfigurationScript, errors: Array[String], warnings: Array[String]) -> void:
	if value == null:
		return
	if not value is Dictionary:
		errors.append("impact must be an object.")
		return
	for key: String in value.keys():
		if not IMPACT_FIELDS.has(key):
			warnings.append("Unknown impact field '%s' was ignored." % key)
	configuration.blast_radius = _read_number(value, "radius", configuration.blast_radius, "impact.radius", errors)
	configuration.blast_damage = _read_number(value, "damage", configuration.blast_damage, "impact.damage", errors)
	configuration.blast_impulse = _read_number(value, "impulse", configuration.blast_impulse, "impact.impulse", errors)
	configuration.blast_upward_bias = _read_number(value, "upward_bias", configuration.blast_upward_bias, "impact.upward_bias", errors)


static func _read_environment(value: Variant, configuration: SimulationConfigurationScript, errors: Array[String], warnings: Array[String]) -> void:
	if value == null:
		return
	if not value is Dictionary:
		errors.append("environment must be an object.")
		return
	for key: String in value.keys():
		if not ENVIRONMENT_FIELDS.has(key):
			warnings.append("Unknown environment field '%s' was ignored." % key)
	configuration.gravity = _read_number(value, "gravity", configuration.gravity, "environment.gravity", errors)
	configuration.time_scale = _read_number(value, "time_scale", configuration.time_scale, "environment.time_scale", errors)


static func _read_material_overrides(value: Variant, configuration: SimulationConfigurationScript, errors: Array[String], warnings: Array[String]) -> void:
	if value == null:
		return
	if not value is Array:
		errors.append("material_overrides must be an array.")
		return
	var seen_cells: Dictionary = {}
	for index in range(value.size()):
		var entry: Variant = value[index]
		if not entry is Dictionary:
			errors.append("material_overrides[%d] must be an object." % index)
			continue
		for key: String in entry.keys():
			if not OVERRIDE_FIELDS.has(key):
				warnings.append("Unknown material_overrides[%d] field '%s' was ignored." % [index, key])
		var cell: Vector3i = _read_vector3i(entry.get("cell"), "material_overrides[%d].cell" % index, errors)
		var material_id: String = _read_required_string(entry, "material_id", errors, "material_overrides[%d]" % index)
		if seen_cells.has(cell):
			errors.append("material_overrides contains duplicate cell %s." % cell)
			continue
		seen_cells[cell] = true
		var override: SimulationMaterialOverrideScript = SimulationMaterialOverrideScript.new()
		override.cell = cell
		override.material_id = StringName(material_id)
		configuration.material_overrides.append(override)


static func _validate_overrides_against_definition(
	configuration: SimulationConfigurationScript,
	definition: BuildingDefinitionScript,
	material_catalog: MaterialProfileCatalogScript,
	errors: Array[String]
) -> void:
	var occupied: Dictionary = {}
	for cell_definition in definition.cells:
		if cell_definition != null:
			occupied[cell_definition.coordinate] = true
	for override: SimulationMaterialOverrideScript in configuration.material_overrides:
		if override == null:
			errors.append("Material override entry is null.")
			continue
		if material_catalog.get_profile_by_id(override.material_id) == null:
			errors.append("Unknown material profile ID '%s' for cell %s." % [String(override.material_id), override.cell])
		if (
			override.cell.x < 0 or override.cell.x >= definition.dimensions.x
			or override.cell.y < 0 or override.cell.y >= definition.dimensions.y
			or override.cell.z < 0 or override.cell.z >= definition.dimensions.z
		):
			errors.append("Material override cell %s is outside the building dimensions." % override.cell)
		elif not occupied.has(override.cell):
			errors.append("Material override cell %s is not occupied in the building definition." % override.cell)


static func _validate_ranges(configuration: SimulationConfigurationScript, errors: Array[String]) -> void:
	_validate_range(configuration.blast_radius, MIN_BLAST_RADIUS, MAX_BLAST_RADIUS, "impact.radius", errors)
	_validate_range(configuration.blast_damage, MIN_BLAST_DAMAGE, MAX_BLAST_DAMAGE, "impact.damage", errors)
	_validate_range(configuration.blast_impulse, MIN_BLAST_IMPULSE, MAX_BLAST_IMPULSE, "impact.impulse", errors)
	_validate_range(configuration.blast_upward_bias, 0.0, 1.0, "impact.upward_bias", errors)
	_validate_range(configuration.gravity, MIN_GRAVITY, MAX_GRAVITY, "environment.gravity", errors)
	_validate_range(configuration.time_scale, MIN_TIME_SCALE, MAX_TIME_SCALE, "environment.time_scale", errors)
	if String(configuration.configuration_id).strip_edges().is_empty():
		errors.append("configuration_id must not be empty.")
	var transform: Transform3D = configuration.building_transform
	if (
		not transform.origin.is_finite()
		or not transform.basis.x.is_finite()
		or not transform.basis.y.is_finite()
		or not transform.basis.z.is_finite()
		or absf(transform.basis.determinant()) <= 0.000001
	):
		errors.append("building_transform must be finite and non-degenerate.")


static func _validate_range(value: float, minimum: float, maximum: float, label: String, errors: Array[String]) -> void:
	if not is_finite(value) or value < minimum or value > maximum:
		errors.append("%s must be finite and within %.2f..%.2f." % [label, minimum, maximum])


static func _read_required_string(data: Dictionary, key: String, errors: Array[String], prefix: String = "") -> String:
	var label: String = key if prefix.is_empty() else "%s.%s" % [prefix, key]
	if not data.has(key):
		errors.append("Missing required field '%s'." % label)
		return ""
	var value: Variant = data[key]
	if not value is String or String(value).strip_edges().is_empty():
		errors.append("Field '%s' must be a non-empty string." % label)
		return ""
	return String(value).strip_edges()


static func _read_number(data: Dictionary, key: String, fallback: float, label: String, errors: Array[String]) -> float:
	if not data.has(key):
		return fallback
	var value: Variant = data[key]
	if not (value is int or value is float):
		errors.append("Field '%s' must be a number." % label)
		return fallback
	var number: float = float(value)
	if not is_finite(number):
		errors.append("Field '%s' must be finite." % label)
		return fallback
	return number


static func _read_vector3(value: Variant, label: String, errors: Array[String]) -> Vector3:
	if not value is Array or value.size() != 3:
		errors.append("Field '%s' must be an array of three numbers." % label)
		return Vector3.ZERO
	for component: Variant in value:
		if not (component is int or component is float) or not is_finite(float(component)):
			errors.append("Field '%s' must contain finite numbers." % label)
			return Vector3.ZERO
	var result := Vector3(float(value[0]), float(value[1]), float(value[2]))
	if not result.is_finite():
		errors.append("Field '%s' must contain finite numbers." % label)
		return Vector3.ZERO
	return result


static func _read_vector3i(value: Variant, label: String, errors: Array[String]) -> Vector3i:
	if not value is Array or value.size() != 3:
		errors.append("Field '%s' must be an array of three integers." % label)
		return Vector3i.ZERO
	var components: Array[int] = []
	for component: Variant in value:
		if not (component is int or component is float):
			errors.append("Field '%s' must contain three integers." % label)
			return Vector3i.ZERO
		var number: float = float(component)
		if not is_finite(number) or not is_equal_approx(number, roundf(number)):
			errors.append("Field '%s' must contain three integers." % label)
			return Vector3i.ZERO
		components.append(int(roundf(number)))
	return Vector3i(components[0], components[1], components[2])


static func _read_integral_int(value: Variant, label: String, errors: Array[String]) -> int:
	if not (value is int or value is float):
		errors.append("Field '%s' must be an integer." % label)
		return -1
	var number: float = float(value)
	if not is_finite(number) or not is_equal_approx(number, roundf(number)):
		errors.append("Field '%s' must be an integer." % label)
		return -1
	return int(roundf(number))


static func _sort_overrides(a: SimulationMaterialOverrideScript, b: SimulationMaterialOverrideScript) -> bool:
	if a == null or b == null:
		return a != null
	if a.cell.x != b.cell.x:
		return a.cell.x < b.cell.x
	if a.cell.y != b.cell.y:
		return a.cell.y < b.cell.y
	return a.cell.z < b.cell.z
