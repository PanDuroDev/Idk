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

	if not _expect(journal.add_sphere(Vector3(4.0, 2.0, 2.0), 1.25, -2.0), "Sphere edit was rejected"):
		return
	var affected := journal.get_affected_chunks(Vector3(4.0, 2.0, 2.0), 1.25, cells, 1.0)
	if not _expect(affected.size() == 2, "Expected exactly two affected chunks, got %d" % affected.size()):
		return
	if not _expect(affected.has(Vector3i(0, 0, 0)), "Left adjacent chunk was not invalidated"):
		return
	if not _expect(affected.has(Vector3i(1, 0, 0)), "Right adjacent chunk was not invalidated"):
		return
	if not _expect(not affected.has(Vector3i(2, 0, 0)), "Unaffected chunk was incorrectly invalidated"):
		return

	# Only the two returned chunks are rebuilt by the caller.
	journal.rebuild_chunk_samples(left, base_field)
	journal.rebuild_chunk_samples(right, base_field)
	var left_border := left.get_density(Vector3i(4, 2, 2))
	var right_border := right.get_density(Vector3i(0, 2, 2))
	if not _expect(is_equal_approx(left_border, right_border), "Duplicated shared-border densities differ"):
		return
	if not _expect(left_border < 0.0, "Sphere edit did not carve the shared boundary sample"):
		return
	if not _expect(is_equal_approx(untouched.get_density(Vector3i(0, 2, 2)), 1.0), "Untouched chunk data changed"):
		return

	journal.clear()
	journal.rebuild_chunk_samples(left, base_field)
	journal.rebuild_chunk_samples(right, base_field)
	if not _expect(is_equal_approx(left.get_density(Vector3i(4, 2, 2)), 1.0), "Left chunk did not restore after journal reset"):
		return
	if not _expect(is_equal_approx(right.get_density(Vector3i(0, 2, 2)), 1.0), "Right chunk did not restore after journal reset"):
		return
	print("WORLDBREAK_TERRAIN_DEFORMATION_OK: affected_chunks=2; shared_border=passed; reset=passed")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
