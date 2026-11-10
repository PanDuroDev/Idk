extends SceneTree
const ChunkData = preload("res://terrain/terrain_chunk_data.gd")
const Mesher = preload("res://terrain/terrain_tetra_mesher.gd")
const CollisionQueue = preload("res://terrain/terrain_collision_queue.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data = ChunkData.create(Vector3i.ZERO, Vector3i(4, 4, 4), 1.0)
	for z in range(5):
		for y in range(5):
			for x in range(5):
				data.set_density(Vector3i(x, y, z), 2.0 - float(x))
	var mesh: ArrayMesh = Mesher.build_mesh(data)
	assert(mesh.get_surface_count() == 1)

	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var queue = CollisionQueue.new()
	root.add_child(body)
	body.add_child(collision)
	root.add_child(queue)

	assert(queue.request_rebuild(body, collision, mesh))
	assert(queue.pending_count() == 1)
	await physics_frame
	await process_frame
	assert(collision.shape != null)
	assert(queue.total_rebuilds == 1)

	# Multiple edits before processing collapse into one latest-state request.
	assert(queue.request_rebuild(body, collision, mesh))
	assert(queue.request_rebuild(body, collision, ArrayMesh.new()))
	assert(queue.pending_count() == 1)
	await physics_frame
	await process_frame
	assert(collision.shape == null)
	assert(queue.total_rebuilds == 2)
	print("WORLDBREAK_TERRAIN_COLLISION_OK: bounded_queue=passed; stale_shape_removed=passed")
	quit(0)
