class_name WorldCatalog
extends Resource

const WorldDefinitionScript = preload("res://scripts/world_definition.gd")

@export var worlds: Array[WorldDefinitionScript] = []


func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	for index in range(worlds.size()):
		var world: WorldDefinitionScript = worlds[index]
		if world == null:
			errors.append("World catalog entry %d is null." % index)
			continue
		var world_id: StringName = world.world_id
		if String(world_id).strip_edges().is_empty():
			errors.append("World catalog entry %d has an empty ID." % index)
			continue
		if seen_ids.has(world_id):
			errors.append("World catalog contains duplicate world ID '%s'." % String(world_id))
		else:
			seen_ids[world_id] = true
	return errors


func get_world_by_id(world_id: StringName) -> WorldDefinitionScript:
	for world: WorldDefinitionScript in worlds:
		if world != null and world.world_id == world_id:
			return world
	return null


func get_world_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for world: WorldDefinitionScript in worlds:
		if world != null:
			ids.append(world.world_id)
	return ids
