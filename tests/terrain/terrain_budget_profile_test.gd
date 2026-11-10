extends SceneTree
const ChunkData = preload("res://terrain/terrain_chunk_data.gd")
const Mesher = preload("res://terrain/terrain_tetra_mesher.gd")
const BudgetConfig = preload("res://terrain/terrain_budget_config.gd")
const CollisionQueue = preload("res://terrain/terrain_collision_queue.gd")
const MeshQueue = preload("res://terrain/terrain_mesh_rebuild_queue.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var normal = BudgetConfig.new()
	assert(normal.validate_limits().is_empty())
	assert(normal.accepts_edit(8.0, 8))
	assert(not normal.accepts_edit(13.0, 1))
	assert(not normal.accepts_edit(2.0, 9))
	assert(normal.can_reside(31, 1))
	assert(not normal.can_reside(32, 1))
	assert(normal.within_density_memory_budget(32))

	var low = BudgetConfig.low_end_fallback()
	assert(low.validate_limits().is_empty())
	assert(low.chunk_resolution == 8)
	assert(low.max_resident_chunks == 8)
	assert(low.max_dirty_chunks_per_edit == 4)
	assert(low.max_pending_collision_rebuilds == 2)
	assert(low.max_pending_mesh_rebuilds == 2)
	assert(low.estimated_density_bytes(8) < normal.estimated_density_bytes(32))

	var invalid = BudgetConfig.new()
	invalid.max_edit_radius = 0.0
	invalid.max_dirty_chunks_per_edit = 0
	assert(not invalid.validate_limits().is_empty())
	assert(not invalid.accepts_edit(1.0, 1))

	var queue = CollisionQueue.new()
	normal.configure_collision_queue(queue)
	assert(queue.max_rebuilds_per_physics_frame == 1)
	assert(queue.max_pending_collision_rebuilds == 8)
	var mesh_queue = MeshQueue.new()
	low.configure_mesh_queue(mesh_queue)
	assert(mesh_queue.max_rebuilds_per_frame == 1)
	assert(mesh_queue.max_pending_mesh_rebuilds == 2)

	# Repeatable CPU-side spike: fixed planar density field at two resolutions.
	for resolution in [8, 16]:
		var data = ChunkData.create(Vector3i.ZERO, Vector3i(resolution, resolution, resolution), 1.0)
		for z in range(resolution + 1):
			for y in range(resolution + 1):
				for x in range(resolution + 1):
					data.set_density(Vector3i(x, y, z), float(resolution) * 0.5 - float(y))
		var start_usec := Time.get_ticks_usec()
		var mesh: ArrayMesh = Mesher.build_mesh(data)
		var elapsed_usec := Time.get_ticks_usec() - start_usec
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var sample_bytes: int = data.samples.size() * 4
		var vertex_payload_bytes: int = vertices.size() * 12
		print("WORLDBREAK_TERRAIN_PROFILE: resolution=%d; samples=%d; density_bytes=%d; vertices=%d; vertex_payload_bytes=%d; mesh_usec=%d" % [resolution, data.samples.size(), sample_bytes, vertices.size(), vertex_payload_bytes, elapsed_usec])
	print("WORLDBREAK_TERRAIN_BUDGETS_OK: validation=passed; low_end_fallback=passed; profile=recorded")
	quit(0)
