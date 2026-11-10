class_name BuildingDefinitionCatalog
extends Resource

const BuildingDefinitionScript = preload("res://scripts/building_definition.gd")
const BuildingDefinitionValidatorScript = preload("res://scripts/building_definition_validator.gd")

@export var definitions: Array[BuildingDefinitionScript] = []


func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	for index in range(definitions.size()):
		var definition: BuildingDefinitionScript = definitions[index]
		if definition == null:
			errors.append("Building catalog entry %d is null." % index)
			continue
		for definition_error: String in BuildingDefinitionValidatorScript.validate_definition(definition):
			errors.append("Building catalog entry %d: %s" % [index, definition_error])
		var definition_id: StringName = definition.definition_id
		if seen_ids.has(definition_id):
			errors.append("Building catalog contains duplicate definition ID '%s'." % String(definition_id))
		else:
			seen_ids[definition_id] = true
	return errors


func get_definition_by_id(definition_id: StringName) -> BuildingDefinitionScript:
	for definition: BuildingDefinitionScript in definitions:
		if definition != null and definition.definition_id == definition_id:
			return definition
	return null
