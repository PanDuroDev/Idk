extends SceneTree
const ChunkData = preload("res://terrain/terrain_chunk_data.gd")
const EditJournal = preload("res://terrain/terrain_edit_journal.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var cells := Vector3i(4, 4, 4)
	var left = ChunkData.create(Vector3i(0, 0, 0), cells, 1.0)
	var right = ChunkData.create(Vector3i(1, 0, 0), cells, 1.0)
	var untouched = ChunkData.create(Vector3i(2, 0, 0), cells, 1.0)
	var base_field := func(_position: Vector3) -> float: return 1.0
	var journal = EditJournal.new()
	journal.rebuild_chunk_samples(left, base_field)
	journal.rebuild_chunk_samples(right, base_field)
	journal.rebuild_chunk_samples(untouched, base_field)

	assert(journal.add_sphere(Vector3(4.0, 2.0, 2.0), 1.25, -2.0))
	var affected := journal.get_affected_chunks(Vector3(4.0, 2.0, 2.0), 1.25, cells, 1.0)
	assert(affected.size() == 2)
	assert(affected.has(Vector3i(0, 0, 0)))
	assert(affected.has(Vector3i(1, 0, 0)))
	assert(not affected.has(Vector3i(2, 0, 0)))

	# Only the two returned chunks are rebuilt by the caller.
	journal.rebuild_chunk_samples(left, base_field)
	journal.rebuild_chunk_samples(right, base_field)
	var left_border := left.get_density(Vector3i(4, 2, 2))
	var right_border := right.get_density(Vector3i(0, 2, 2))
	assert(is_equal_approx(left_border, right_border))
	assert(left_border < 0.0)
	assert(is_equal_approx(untouched.get_density(Vector3i(0, 2, 2)), 1.0))

	journal.clear()
	journal.rebuild_chunk_samples(left, base_field)
	journal.rebuild_chunk_samples(right, base_field)
	assert(is_equal_approx(left.get_density(Vector3i(4, 2, 2)), 1.0))
	assert(is_equal_approx(right.get_density(Vector3i(0, 2, 2)), 1.0))
	print("WORLDBREAK_TERRAIN_DEFORMATION_OK: affected_chunks=2; shared_border=passed; reset=passed")
	quit(0)
