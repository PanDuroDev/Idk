class_name MaterialProfileCatalog
extends Resource

const DestructionMaterialProfileScript = preload("res://scripts/destruction_material_profile.gd")
const BuildingDefinitionValidatorScript = preload("res://scripts/building_definition_validator.gd")

@export var profiles: Array[DestructionMaterialProfileScript] = []


func validate_catalog() -> Array[String]:
	return BuildingDefinitionValidatorScript.validate_material_catalog(profiles)


func get_profile_by_id(material_id: StringName) -> DestructionMaterialProfileScript:
	for profile: DestructionMaterialProfileScript in profiles:
		if profile != null and profile.material_id == material_id:
			return profile
	return null


func add_profile(profile: DestructionMaterialProfileScript) -> Array[String]:
	var errors: Array[String] = []
	if profile == null:
		errors.append("Cannot add a null material profile.")
		return errors

	errors = BuildingDefinitionValidatorScript.validate_material_profile(profile)
	if not errors.is_empty():
		return errors
	if get_profile_by_id(profile.material_id) != null:
		errors.append("Material ID '%s' already exists in this catalog." % String(profile.material_id))
		return errors

	profiles.append(profile)
	return []


func duplicate_profile(
	source_id: StringName,
	new_material_id: StringName,
	new_display_name: String
) -> DestructionMaterialProfileScript:
	if String(new_material_id).strip_edges().is_empty():
		return null
	if new_display_name.strip_edges().is_empty():
		return null
	if get_profile_by_id(new_material_id) != null:
		return null

	var source: DestructionMaterialProfileScript = get_profile_by_id(source_id)
	if source == null:
		return null

	var copy: DestructionMaterialProfileScript = source.duplicate(true) as DestructionMaterialProfileScript
	if copy == null:
		return null
	copy.material_id = new_material_id
	copy.display_name = new_display_name
	return copy
