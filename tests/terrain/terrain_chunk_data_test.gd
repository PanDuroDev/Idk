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
	print("WORLDBREAK_TERRAIN_CHUNK_MESH_OK: samples=125; shared_border=passed; vertices=%d" % vertices.size())
	quit(0)
