extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const WORLD_CATALOG: Resource = preload("res://resources/worlds/world_catalog.tres")
const WorldDefinitionScript = preload("res://scripts/world_definition.gd")
const WorldDefinitionValidatorScript = preload("res://scripts/world_definition_validator.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog_errors: Array[String] = WORLD_CATALOG.validate_catalog()
	if not catalog_errors.is_empty():
		_fail("World catalog is invalid: %s" % "\n".join(catalog_errors))
		return
	if WORLD_CATALOG.worlds.size() != 2:
		_fail("Expected two sample worlds")
		return

	var main: Node = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	if not _check_world(main, &"classic_yard", &"classic_70_piece", 70, 9.8):
		return
	if not _check_single_world_nodes(main):
		return
	var classic_definition: WorldDefinitionScript = main.call("get_active_world_definition")
	if classic_definition == null or not is_equal_approx(float(main.call("get_simulation_gravity")), 9.8):
		_fail("Classic world did not apply its gravity preset")
		return
	var classic_environment := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if classic_environment == null or classic_environment.environment == null:
		_fail("Classic world did not expose the shared environment")
		return
	if not classic_environment.environment.background_color.is_equal_approx(classic_definition.background_color):
		_fail("Classic world did not apply its background preset")
		return

	var switch_errors: Array = main.call("load_world", &"sparse_quarry")
	if not switch_errors.is_empty():
		_fail("Sparse world load failed: %s" % "\n".join(switch_errors))
		return
	await process_frame
	if not _check_world(main, &"sparse_quarry", &"sparse_pillar_beam_11", 11, 12.5):
		return
	if not _check_single_world_nodes(main):
		return
	var sparse_definition: WorldDefinitionScript = main.call("get_active_world_definition")
	var sparse_terrain: Node = main.get_node_or_null("TerrainWorld")
	if sparse_terrain == null or sparse_terrain.get_chunk_cell_size() != 2.0:
		_fail("Sparse world did not apply its low-end terrain profile")
		return
	if not is_equal_approx(Engine.time_scale, 0.85):
		_fail("Sparse world did not apply its time scale")
		return
	var sparse_player := main.get_node_or_null("Player") as CharacterBody3D
	if sparse_player == null or sparse_player.global_position.distance_to(sparse_definition.player_spawn) > 0.5:
		_fail("Sparse world did not place the player at its spawn")
		return
	if not sparse_environment_matches(main, sparse_definition):
		return

	var invalid_errors: Array = main.call("load_world", &"missing_world")
	if invalid_errors.is_empty():
		_fail("Unknown world ID was accepted")
		return
	if main.call("get_active_world_definition") != sparse_definition:
		_fail("Failed world load changed the active world")
		return
	if not _check_structure_count(main, 11):
		return

	main.call("unload_world")
	await process_frame
	if main.call("get_active_world_definition") != null or int(main.call("get_resident_world_count")) != 0:
		_fail("Unload did not release the active world")
		return
	if main.get_node_or_null("DestructibleStructure") != null or main.get_node_or_null("TerrainWorld") != null:
		_fail("Unload left world nodes resident")
		return
	if not is_equal_approx(Engine.time_scale, 1.0):
		_fail("Unload did not restore the time scale")
		return

	var reload_errors: Array = main.call("load_world", &"classic_yard")
	if not reload_errors.is_empty():
		_fail("Classic world reload failed: %s" % "\n".join(reload_errors))
		return
	await process_frame
	if not _check_world(main, &"classic_yard", &"classic_70_piece", 70, 9.8):
		return

	var structure: Node = main.get_node_or_null("DestructibleStructure")
	var terrain: Node = main.get_node_or_null("TerrainWorld")
	structure.call("apply_blast_damage", Vector3(0.0, 0.5, -11.48), 2.0, 10.0)
	terrain.call("carve_sphere", Vector3(20.0, 1.06, -30.0), 2.0, 2.0)
	await physics_frame
	await process_frame
	await physics_frame
	if int(structure.call("get_broken_fragment_count")) <= 0:
		_fail("Reloaded world could not be damaged")
		return
	if int(terrain.call("get_terrain_edit_count")) <= 0:
		_fail("Reloaded world terrain could not be edited")
		return
	main.call("request_world_reset")
	await physics_frame
	await process_frame
	await physics_frame
	if not bool(structure.call("is_reset_to_initial_state")):
		_fail("World reset did not restore the structure")
		return
	if terrain == null or not terrain.is_reset_to_initial_state():
		_fail("World reset did not restore the terrain")
		return
	var player := main.get_node_or_null("Player") as CharacterBody3D
	var world_definition: WorldDefinitionScript = main.call("get_active_world_definition")
	if player == null or player.global_position.distance_to(world_definition.player_spawn) > 0.5:
		_fail("World reset did not restore the player spawn")
		return

	var invalid_world := WorldDefinitionScript.new()
	invalid_world.schema_version = 99
	invalid_world.world_id = &""
	invalid_world.display_name = ""
	invalid_world.simulation_configuration_path = "res://missing/location.json"
	invalid_world.ambient_energy = 99.0
	var validation: Dictionary = WorldDefinitionValidatorScript.validate_definition(
		invalid_world,
		main.call("get_building_definition_catalog"),
		main.call("get_material_profile_catalog")
	)
	if validation["ok"] or (validation["errors"] as Array).size() < 4:
		_fail("Invalid world definition was not rejected with all errors")
		return
	if int(main.call("get_world_load_count")) != 3 or int(main.call("get_world_unload_count")) != 1:
		_fail("World load/unload counters are incorrect")
		return
	if int(main.call("get_max_resident_worlds")) != 1:
		_fail("World residency bound is not one")
		return

	print("WORLDBREAK_WORLD_LOADING_OK: worlds=2; switch=passed; unload=passed; reset=passed; validation=passed")
	quit(0)


func _check_world(main: Node, world_id: StringName, building_id: StringName, fragments: int, gravity: float) -> bool:
	var definition: WorldDefinitionScript = main.call("get_active_world_definition")
	if definition == null or definition.world_id != world_id:
		_fail("Expected active world '%s'" % String(world_id))
		return false
	if int(main.call("get_resident_world_count")) != 1:
		_fail("Expected one resident world for '%s'" % String(world_id))
		return false
	if not _check_structure_count(main, fragments):
		return false
	var structure: Node = main.get_node_or_null("DestructibleStructure")
	if structure == null or structure.call("get_building_definition_id") != building_id:
		_fail("World '%s' did not apply building '%s'" % [String(world_id), String(building_id)])
		return false
	var terrain: Node = main.get_node_or_null("TerrainWorld")
	if terrain == null or terrain.get_resident_chunk_count() != 16:
		_fail("World '%s' did not build its resident terrain patch" % String(world_id))
		return false
	if not is_equal_approx(float(main.call("get_simulation_gravity")), gravity):
		_fail("World '%s' did not apply gravity %.2f" % [String(world_id), gravity])
		return false
	return true


func _check_structure_count(main: Node, expected: int) -> bool:
	var structure: Node = main.get_node_or_null("DestructibleStructure")
	if structure == null or int(structure.call("get_fragment_count")) != expected:
		_fail("Expected %d fragments in the active structure" % expected)
		return false
	return true


func _check_single_world_nodes(main: Node) -> bool:
	var structures := 0
	var terrains := 0
	for child in main.get_children():
		if child.name == "DestructibleStructure":
			structures += 1
		elif child.name == "TerrainWorld":
			terrains += 1
	if structures != 1 or terrains != 1:
		_fail("Expected exactly one structure and one terrain node, found %d and %d" % [structures, terrains])
		return false
	return true


func sparse_environment_matches(main: Node, definition: WorldDefinitionScript) -> bool:
	var environment := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment == null or environment.environment == null:
		_fail("Sparse world did not expose the shared environment")
		return false
	if not environment.environment.background_color.is_equal_approx(definition.background_color):
		_fail("Sparse world did not apply its background preset")
		return false
	var sun := main.get_node_or_null("Sun") as DirectionalLight3D
	if sun == null or not is_equal_approx(sun.light_energy, definition.sun_energy):
		_fail("Sparse world did not apply its sun preset")
		return false
	return true


func _fail(message: String) -> void:
	push_error("WORLDBREAK_WORLD_LOADING_FAILED: " + message)
	quit(1)
