extends SceneTree
const ChunkData = preload("res://terrain/terrain_chunk_data.gd")
const Mesher = preload("res://terrain/terrain_tetra_mesher.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var left = ChunkData.create(Vector3i(0, 0, 0), Vector3i(4, 4, 4), 0.5)
	var right = ChunkData.create(Vector3i(1, 0, 0), Vector3i(4, 4, 4), 0.5)
	if not _expect(left.sample_dimensions() == Vector3i(5, 5, 5), "Chunk sample dimensions are incorrect"):
		return
	if not _expect(left.global_sample_coord(Vector3i(4, 2, 1)) == Vector3i(4, 2, 1), "Left chunk global sample coordinate is incorrect"):
		return
	if not _expect(right.global_sample_coord(Vector3i(0, 2, 1)) == Vector3i(4, 2, 1), "Right chunk global sample coordinate is incorrect"):
		return
	if not _expect(left.world_sample_position(Vector3i(4, 2, 1)) == right.world_sample_position(Vector3i(0, 2, 1)), "Duplicated chunk border world positions differ"):
		return
	for z in range(5):
		for y in range(5):
			for x in range(5):
				left.set_density(Vector3i(x, y, z), 2.0 - float(x))
	var mesh: ArrayMesh = Mesher.build_mesh(left)
	if not _expect(mesh != null, "Mesher returned a null mesh"):
		return
	if not _expect(mesh.get_surface_count() == 1, "Planar field did not produce exactly one surface"):
		return
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if not _expect(vertices.size() > 0, "Planar field produced no vertices"):
		return
	if not _expect(normals.size() == vertices.size(), "Mesh normals do not match vertex count"):
		return
	for index in range(vertices.size()):
		var vertex := vertices[index]
		var normal := normals[index]
		if not _expect(is_finite(vertex.x) and is_finite(vertex.y) and is_finite(vertex.z), "Mesh contains a non-finite vertex"):
			return
		if not _expect(normal.x > 0.9, "Planar surface normals must face toward the empty (+X) side"):
			return

	# Two adjacent chunks must emit the exact same vertices along their shared
	# face when a planar isosurface crosses that face.
	var seam_left = ChunkData.create(Vector3i(0, 0, 0), Vector3i(4, 4, 4), 1.0)
	var seam_right = ChunkData.create(Vector3i(1, 0, 0), Vector3i(4, 4, 4), 1.0)
	for z in range(5):
		for y in range(5):
			for x in range(5):
				var left_sample := Vector3i(x, y, z)
				var right_sample := Vector3i(x, y, z)
				seam_left.set_density(left_sample, 2.5 - float(seam_left.global_sample_coord(left_sample).y))
				seam_right.set_density(right_sample, 2.5 - float(seam_right.global_sample_coord(right_sample).y))
	var left_mesh: ArrayMesh = Mesher.build_mesh(seam_left)
	var right_mesh: ArrayMesh = Mesher.build_mesh(seam_right)
	var left_origin := Vector3(seam_left.chunk_coord * seam_left.cells)
	var right_origin := Vector3(seam_right.chunk_coord * seam_right.cells)
	var left_edge: Array[Vector3] = []
	var right_edge: Array[Vector3] = []
	for vertex in left_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var world_vertex: Vector3 = vertex + left_origin
		if is_equal_approx(world_vertex.x, 4.0):
			left_edge.append(world_vertex)
	for vertex in right_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var world_vertex: Vector3 = vertex + right_origin
		if is_equal_approx(world_vertex.x, 4.0):
			right_edge.append(world_vertex)
	if left_edge.is_empty() or right_edge.is_empty():
		_fail("Chunk seam produced no shared-face vertices: left=%d right=%d" % [left_edge.size(), right_edge.size()])
		return
	for vertex in left_edge:
		if not _contains_approx(right_edge, vertex):
			_fail("Right chunk is missing shared-face vertex %s" % str(vertex))
			return
	for vertex in right_edge:
		if not _contains_approx(left_edge, vertex):
			_fail("Left chunk is missing shared-face vertex %s" % str(vertex))
			return

	print("WORLDBREAK_TERRAIN_CHUNK_MESH_OK: samples=125; mesh_seam=passed; vertices=%d" % vertices.size())
	quit(0)

func _contains_approx(vertices: Array[Vector3], target: Vector3) -> bool:
	for candidate in vertices:
		if candidate.distance_squared_to(target) <= 0.00000001:
			return true
	return false

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
