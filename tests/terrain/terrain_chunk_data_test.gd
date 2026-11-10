extends SceneTree
const ChunkData = preload("res://terrain/terrain_chunk_data.gd")
const Mesher = preload("res://terrain/terrain_tetra_mesher.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var left = ChunkData.create(Vector3i(0, 0, 0), Vector3i(4, 4, 4), 0.5)
	var right = ChunkData.create(Vector3i(1, 0, 0), Vector3i(4, 4, 4), 0.5)
	assert(left.sample_dimensions() == Vector3i(5, 5, 5))
	assert(left.global_sample_coord(Vector3i(4, 2, 1)) == Vector3i(4, 2, 1))
	assert(right.global_sample_coord(Vector3i(0, 2, 1)) == Vector3i(4, 2, 1))
	assert(left.world_sample_position(Vector3i(4, 2, 1)) == right.world_sample_position(Vector3i(0, 2, 1)))
	for z in range(5):
		for y in range(5):
			for x in range(5):
				left.set_density(Vector3i(x, y, z), 2.0 - float(x))
	var mesh: ArrayMesh = Mesher.build_mesh(left)
	assert(mesh != null)
	assert(mesh.get_surface_count() == 1)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert(vertices.size() > 0)
	assert(normals.size() == vertices.size())
	for index in range(vertices.size()):
		var vertex := vertices[index]
		var normal := normals[index]
		assert(is_finite(vertex.x) and is_finite(vertex.y) and is_finite(vertex.z))
		assert(normal.x > 0.9, "Planar surface normals must face toward the empty (+X) side")

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
	assert(left_edge.size() > 0 and left_edge.size() == right_edge.size())
	for vertex in left_edge:
		assert(right_edge.has(vertex), "Adjacent chunk meshes must share identical boundary vertices")

	print("WORLDBREAK_TERRAIN_CHUNK_MESH_OK: samples=125; mesh_seam=passed; vertices=%d" % vertices.size())
	quit(0)
