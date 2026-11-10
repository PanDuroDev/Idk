class_name BuildingDefinitionScriptValidator
extends RefCounted

const BuildingDefinitionScript = preload("res://scripts/building_definition.gd")
const BuildingCellDefinitionScript = preload("res://scripts/building_cell_definition.gd")
const DestructionMaterialProfileScript = preload("res://scripts/destruction_material_profile.gd")

const MAX_OCCUPIED_CELLS: int = 256
const MIN_MATERIAL_INTEGRITY: float = 0.1
const MAX_MATERIAL_INTEGRITY: float = 100.0
const MIN_MATERIAL_RESISTANCE: float = 0.1
const MAX_MATERIAL_RESISTANCE: float = 10.0
const MIN_DENSITY_MULTIPLIER: float = 0.1
const MAX_DENSITY_MULTIPLIER: float = 10.0


static func validate_definition(
	definition: BuildingDefinition,
	max_occupied_cells: int = MAX_OCCUPIED_CELLS
) -> Array[String]:
	var errors: Array[String] = []
	if definition == null:
		errors.append("Building definition is null.")
		return errors

	if definition.schema_version != BuildingDefinitionScript.CURRENT_SCHEMA_VERSION:
		errors.append("Unsupported building schema version: %d." % definition.schema_version)
	if String(definition.definition_id).strip_edges().is_empty():
		errors.append("Building definition ID must not be empty.")
	if definition.display_name.strip_edges().is_empty():
		errors.append("Building display name must not be empty.")
	if definition.dimensions.x <= 0 or definition.dimensions.y <= 0 or definition.dimensions.z <= 0:
		errors.append("Building dimensions must be positive on all axes.")
	if not _is_positive_finite_vector(definition.cell_size):
		errors.append("Cell size must contain finite positive values on all axes.")
	if not _is_positive_finite_vector(definition.cell_spacing):
		errors.append("Cell spacing must contain finite positive values on all axes.")
	if not definition.origin_offset.is_finite():
		errors.append("Building origin offset must contain finite values.")
	if max_occupied_cells <= 0:
		errors.append("Maximum occupied-cell limit must be positive.")
	elif definition.cells.size() > max_occupied_cells:
		errors.append(
			"Building has %d occupied cells; the configured limit is %d."
			% [definition.cells.size(), max_occupied_cells]
		)
	if definition.cells.is_empty():
		errors.append("Building definition must contain at least one occupied cell.")

	var occupied: Dictionary = {}
	var profiles_by_id: Dictionary = {}
	var checked_profile_instances: Dictionary = {}
	if definition.default_material_profile != null:
		_register_profile(
			definition.default_material_profile,
			"default material profile",
			profiles_by_id,
			checked_profile_instances,
			errors
		)

	for index in range(definition.cells.size()):
		var cell: BuildingCellDefinition = definition.cells[index]
		if cell == null:
			errors.append("Cell entry %d is null." % index)
			continue

		var coordinate: Vector3i = cell.coordinate
		if occupied.has(coordinate):
			errors.append("Cell entry %d duplicates coordinate %s." % [index, coordinate])
		else:
			occupied[coordinate] = true

		if (
			coordinate.x < 0 or coordinate.x >= definition.dimensions.x
			or coordinate.y < 0 or coordinate.y >= definition.dimensions.y
			or coordinate.z < 0 or coordinate.z >= definition.dimensions.z
		):
			errors.append("Cell entry %d coordinate %s is outside the definition dimensions." % [index, coordinate])

		if cell.use_custom_transform and not _is_valid_transform(cell.local_transform):
			errors.append("Cell entry %d has a non-finite or degenerate custom transform." % index)

		var profile: DestructionMaterialProfile = definition.get_cell_material_profile(cell)
		if profile == null:
			errors.append("Cell entry %d has no material profile and no building default." % index)
		else:
			_register_profile(
				profile,
				"cell entry %d" % index,
				profiles_by_id,
				checked_profile_instances,
				errors
			)

	return errors


static func validate_material_profile(profile: DestructionMaterialProfile) -> Array[String]:
	var errors: Array[String] = []
	if profile == null:
		errors.append("Material profile is null.")
		return errors

	if String(profile.material_id).strip_edges().is_empty():
		errors.append("Material ID must not be empty.")
	if profile.display_name.strip_edges().is_empty():
		errors.append("Material display name must not be empty.")
	if not is_finite(profile.integrity) or profile.integrity < MIN_MATERIAL_INTEGRITY or profile.integrity > MAX_MATERIAL_INTEGRITY:
		errors.append("Material integrity must be finite and within 0.1..100.")
	if not is_finite(profile.blast_resistance) or profile.blast_resistance < MIN_MATERIAL_RESISTANCE or profile.blast_resistance > MAX_MATERIAL_RESISTANCE:
		errors.append("Material blast resistance must be finite and within 0.1..10.")
	if not is_finite(profile.density_multiplier) or profile.density_multiplier < MIN_DENSITY_MULTIPLIER or profile.density_multiplier > MAX_DENSITY_MULTIPLIER:
		errors.append("Material density multiplier must be finite and within 0.1..10.")
	var color: Color = profile.surface_color
	if (
		not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a)
		or color.r < 0.0 or color.r > 1.0
		or color.g < 0.0 or color.g > 1.0
		or color.b < 0.0 or color.b > 1.0
		or color.a < 0.0 or color.a > 1.0
	):
		errors.append("Material surface color must contain finite channels within 0..1.")
	return errors


static func validate_material_catalog(profiles: Array[DestructionMaterialProfile]) -> Array[String]:
	var errors: Array[String] = []
	var profiles_by_id: Dictionary = {}
	var checked_profile_instances: Dictionary = {}
	for index in range(profiles.size()):
		var profile: DestructionMaterialProfile = profiles[index]
		if profile == null:
			errors.append("Material catalog entry %d is null." % index)
			continue
		_register_profile(
			profile,
			"material catalog entry %d" % index,
			profiles_by_id,
			checked_profile_instances,
			errors
		)
	return errors


static func _register_profile(
	profile: DestructionMaterialProfile,
	source_label: String,
	profiles_by_id: Dictionary,
	checked_profile_instances: Dictionary,
	errors: Array[String]
) -> void:
	var instance_id: int = profile.get_instance_id()
	if not checked_profile_instances.has(instance_id):
		checked_profile_instances[instance_id] = true
		for profile_error: String in validate_material_profile(profile):
			errors.append("%s: %s" % [source_label, profile_error])

	var material_id: StringName = profile.material_id
	if String(material_id).strip_edges().is_empty():
		return
	if profiles_by_id.has(material_id):
		var existing: DestructionMaterialProfile = profiles_by_id[material_id] as DestructionMaterialProfile
		if existing != profile:
			errors.append("Material ID '%s' is assigned to multiple profile resources." % String(material_id))
	else:
		profiles_by_id[material_id] = profile


static func _is_positive_finite_vector(value: Vector3) -> bool:
	return (
		value.is_finite()
		and value.x > 0.0
		and value.y > 0.0
		and value.z > 0.0
	)


static func _is_valid_transform(value: Transform3D) -> bool:
	var basis: Basis = value.basis
	return (
		value.origin.is_finite()
		and basis.x.is_finite()
		and basis.y.is_finite()
		and basis.z.is_finite()
		and absf(basis.determinant()) > 0.000001
	)
