extends SceneTree
const ChunkData = preload("res://terrain/terrain_chunk_data.gd")
const MeshQueue = preload("res://terrain/terrain_mesh_rebuild_queue.gd")
const BudgetConfig = preload("res://terrain/terrain_budget_config.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data = ChunkData.create(Vector3i.ZERO, Vector3i(4, 4, 4), 1.0)
	for z in range(5):
		for y in range(5):
			for x in range(5):
				data.set_density(Vector3i(x, y, z), 2.5 - float(y))

	var low = BudgetConfig.low_end_fallback()
	var queue = MeshQueue.new()
	root.add_child(queue)
	low.configure_mesh_queue(queue)
	assert(queue.max_rebuilds_per_frame == 1)
	assert(queue.max_pending_mesh_rebuilds == 2)

	var first := MeshInstance3D.new()
	var second := MeshInstance3D.new()
	var third := MeshInstance3D.new()
	root.add_child(first)
	root.add_child(second)
	root.add_child(third)
	assert(queue.request_rebuild(first, data))
	assert(queue.request_rebuild(first, data)) # Coalesces, does not add work.
	assert(queue.request_rebuild(second, data))
	assert(not queue.request_rebuild(third, data))
	assert(queue.pending_count() == 2)
	assert(queue.rejected_requests == 1)

	# Drive the frame-budget method directly for deterministic headless checks.
	queue._process(0.0)
	assert(queue.total_rebuilds == 1)
	assert(queue.pending_count() == 1)
	queue._process(0.0)
	assert(queue.total_rebuilds == 2)
	assert(queue.pending_count() == 0)
	assert(first.mesh != null and second.mesh != null)
	print("WORLDBREAK_TERRAIN_MESH_QUEUE_OK: coalescing=passed; per_frame_budget=passed; overflow=bounded")
	quit(0)
