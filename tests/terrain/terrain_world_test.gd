extends SceneTree
const TerrainWorldScript = preload("res://terrain/terrain_world.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = TerrainWorldScript.new()
	root.add_child(world)
	await process_frame

	if world.get_resident_chunk_count() != 4:
		_fail("Expected 4 resident terrain chunks, got %d" % world.get_resident_chunk_count())
		return
	if int(world.get_budget().validate_limits().size()) != 0:
		_fail("Default terrain budget failed validation")
		return
	if world.get_estimated_density_bytes() > int(world.get_budget().max_density_memory_mib) * 1024 * 1024:
		_fail("Resident terrain density exceeds the configured memory budget")
		return

	var affected_coord := Vector3i(0, 0, 0)
	var untouched_coord := Vector3i(-1, 0, 0)
	var affected_data = world.get_chunk_data(affected_coord)
	var untouched_data = world.get_chunk_data(untouched_coord)
	if affected_data == null or untouched_data == null:
		_fail("Resident terrain chunk data is missing")
		return
	if world.get_chunk_mesh(affected_coord) == null:
		_fail("Initial terrain chunk mesh was not built")
		return
	if not (world.get_chunk_collision_shape(affected_coord) is ConcavePolygonShape3D):
		_fail("Initial terrain chunk collision is not a static trimesh")
		return

	var top_sample := Vector3i(8, 1, 8)
	var untouched_sample := Vector3i(4, 1, 4)
	var initial_top: float = affected_data.get_density(top_sample)
	var initial_untouched: float = untouched_data.get_density(untouched_sample)
	if not is_equal_approx(initial_top, 0.0):
		_fail("Terrain top border did not start at the iso level")
		return

	var first_result: Dictionary = world.carve_sphere(Vector3(8.0, 1.0, 8.0), 3.0, 4.0)
	if not bool(first_result.get("ok", false)):
		_fail("Valid terrain carve was rejected: %s" % first_result.get("reason", "unknown"))
		return
	if world.get_terrain_edit_count() != 1:
		_fail("Terrain carve did not add exactly one journal edit")
		return
	var last_affected: Array[Vector3i] = world.get_last_affected_chunks()
	if last_affected.size() != 1 or last_affected[0] != affected_coord:
		_fail("Carve did not stay localized to the intersected chunk")
		return
	if not (affected_data.get_density(top_sample) < initial_top):
		_fail("Carve did not lower density in the affected chunk")
		return
	if not is_equal_approx(untouched_data.get_density(untouched_sample), initial_untouched):
		_fail("Carve modified an unaffected chunk")
		return
	if world.get_mesh_queue().pending_count() != 1:
		_fail("Carve did not queue one coalesced mesh rebuild")
		return

	world.get_mesh_queue()._process(0.0)
	if world.get_mesh_queue().total_rebuilds != 1:
		_fail("Mesh queue did not apply the queued rebuild")
		return
	if world.get_collision_queue().pending_count() != 1:
		_fail("Completed mesh rebuild did not queue a collision rebuild")
		return
	world.get_collision_queue()._physics_process(0.0)
	if world.get_collision_queue().total_rebuilds != 1:
		_fail("Collision queue did not apply the rebuilt mesh")
		return
	await process_frame

	# Repeated edits in the same frame coalesce to one pending mesh rebuild.
	if not bool(world.carve_sphere(Vector3(9.0, 1.0, 9.0), 3.0, 2.0).get("ok", false)):
		_fail("Second terrain carve was rejected")
		return
	if not bool(world.carve_sphere(Vector3(9.0, 1.0, 9.0), 2.0, 1.0).get("ok", false)):
		_fail("Third terrain carve was rejected")
		return
	if world.get_terrain_edit_count() != 3 or world.get_mesh_queue().pending_count() != 1:
		_fail("Repeated edits did not coalesce into one pending mesh rebuild")
		return
	world.get_mesh_queue()._process(0.0)
	world.get_collision_queue()._physics_process(0.0)
	if world.get_mesh_queue().total_rebuilds != 2 or world.get_collision_queue().total_rebuilds != 2:
		_fail("Repeated edit rebuild did not stay within the per-frame budget")
		return

	var rejected_before: int = world.get_rejected_carve_count()
	if bool(world.carve_sphere(Vector3(8.0, 1.0, 8.0), 13.0, 4.0).get("ok", false)):
		_fail("Carve larger than max_edit_radius should be rejected")
		return
	if bool(world.carve_sphere(Vector3(200.0, 1.0, 200.0), 2.0, 4.0).get("ok", false)):
		_fail("Carve outside resident chunks should be rejected")
		return
	if world.get_rejected_carve_count() != rejected_before + 2:
		_fail("Rejected carves were not counted")
		return
	if world.get_terrain_edit_count() != 3:
		_fail("Rejected carves must not modify the edit journal")
		return

	world.reset_terrain()
	if world.get_terrain_edit_count() != 0 or not world.is_reset_to_initial_state():
		_fail("Terrain reset did not restore base density")
		return
	if world.get_mesh_queue().pending_count() != 0 or world.get_collision_queue().pending_count() != 0:
		_fail("Terrain reset left stale bounded rebuild requests")
		return
	if not is_equal_approx(affected_data.get_density(top_sample), 0.0):
		_fail("Terrain reset did not restore the carved top sample")
		return
	if not (world.get_chunk_collision_shape(affected_coord) is ConcavePolygonShape3D):
		_fail("Terrain reset did not restore chunk collision")
		return

	var low_end = TerrainWorldScript.new()
	low_end.use_low_end_fallback = true
	root.add_child(low_end)
	await process_frame
	if low_end.get_resident_chunk_count() != 4:
		_fail("Low-end terrain profile did not keep the bounded resident patch")
		return
	if low_end.get_budget().chunk_resolution != 8 or not is_equal_approx(low_end.get_chunk_cell_size(), 2.0):
		_fail("Low-end terrain profile did not select 8-cell chunks and a larger cell size")
		return
	if low_end.get_estimated_density_bytes() > int(low_end.get_budget().max_density_memory_mib) * 1024 * 1024:
		_fail("Low-end terrain density exceeds its memory budget")
		return
	if not bool(low_end.carve_sphere(Vector3(8.0, 1.0, 8.0), 4.5, 4.0).get("ok", false)):
		_fail("Low-end terrain rejected a blast within its edit radius")
		return
	var low_data = low_end.get_chunk_data(Vector3i(0, 0, 0))
	if low_data == null or not (low_data.get_density(Vector3i(4, 1, 4)) < 0.0):
		_fail("Low-end terrain carve did not modify its chunk samples")
		return
	low_end.reset_terrain()
	if not low_end.is_reset_to_initial_state():
		_fail("Low-end terrain reset did not restore base density")
		return

	print("WORLDBREAK_TERRAIN_WORLD_OK: chunks=4; localized_carve=passed; coalescing=passed; reset=passed; low_end=passed")
	quit(0)

func _fail(message: String) -> void:
	push_error("WORLDBREAK_TERRAIN_WORLD_FAILED: " + message)
	quit(1)
