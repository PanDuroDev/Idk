extends SceneTree
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var terrain: Node = main.get_node_or_null("TerrainWorld")
	var structure: Node = main.get_node_or_null("DestructibleStructure")
	if terrain == null or structure == null:
		_fail("Gameplay scene did not create both the terrain patch and destructible structure")
		return
	if terrain.get_resident_chunk_count() != 16:
		_fail("Integrated terrain patch did not build its bounded resident chunks")
		return
	if not terrain.is_reset_to_initial_state():
		_fail("Integrated terrain patch did not start in its base state")
		return

	for cycle in range(3):
		var mesh_rebuilds_before: int = terrain.get_mesh_queue().total_rebuilds
		var collision_rebuilds_before: int = terrain.get_collision_queue().total_rebuilds
		main.call("request_blast", Vector3(20.0, 8.0, -30.0), Vector3.DOWN)
		await physics_frame
		await process_frame
		await physics_frame
		await process_frame
		await physics_frame

		if terrain.get_terrain_edit_count() != 1:
			_fail("Blast cycle %d did not carve exactly one terrain edit" % (cycle + 1))
			return
		if int(structure.call("get_broken_fragment_count")) != 0:
			_fail("Terrain blast cycle %d damaged the distant structure" % (cycle + 1))
			return
		var affected: Array[Vector3i] = terrain.get_last_affected_chunks()
		if affected.is_empty() or affected.size() > int(terrain.get_budget().max_dirty_chunks_per_edit):
			_fail("Terrain blast cycle %d exceeded the dirty-chunk budget" % (cycle + 1))
			return
		var extent: float = float(terrain.get_chunk_cell_size()) * float(terrain.get_budget().chunk_resolution)
		var chunk_coord := Vector3i(floori(20.0 / extent), 0, floori(-30.0 / extent))
		var local_cell := Vector3i(floori(20.0 - extent * chunk_coord.x), 1, floori(-30.0 - extent * chunk_coord.z))
		var top_data = terrain.get_chunk_data(chunk_coord)
		if top_data == null or not (top_data.get_density(local_cell) < 0.0):
			_fail("Terrain blast cycle %d did not deform the impact chunk" % (cycle + 1))
			return
		if terrain.get_mesh_queue().total_rebuilds <= mesh_rebuilds_before:
			_fail("Terrain blast cycle %d did not apply a mesh rebuild" % (cycle + 1))
			return
		if terrain.get_collision_queue().total_rebuilds <= collision_rebuilds_before:
			_fail("Terrain blast cycle %d did not apply a collision rebuild" % (cycle + 1))
			return
		if terrain.get_mesh_queue().pending_count() > int(terrain.get_budget().max_pending_mesh_rebuilds):
			_fail("Terrain mesh queue exceeded its pending bound")
			return
		if terrain.get_collision_queue().pending_count() > int(terrain.get_budget().max_pending_collision_rebuilds):
			_fail("Terrain collision queue exceeded its pending bound")
			return

		main.call("request_structure_reset")
		await physics_frame
		await process_frame
		await physics_frame
		if not terrain.is_reset_to_initial_state():
			_fail("Reset did not restore the terrain after blast cycle %d" % (cycle + 1))
			return
		if not bool(structure.call("is_reset_to_initial_state")):
			_fail("Reset did not restore the structure after blast cycle %d" % (cycle + 1))
			return

	print("WORLDBREAK_TERRAIN_INTEGRATION_OK: blasts=3; chunks=16; localized_rebuilds=passed; reset=passed")
	quit(0)

func _fail(message: String) -> void:
	push_error("WORLDBREAK_TERRAIN_INTEGRATION_FAILED: " + message)
	quit(1)
