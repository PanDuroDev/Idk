class_name TerrainTetraMesher
extends RefCounted
## Compact isosurface mesher. A fixed six-tetrahedra decomposition avoids a
## large lookup table. Border samples are duplicated between adjacent chunks.

const CORNERS: Array[Vector3i] = [
	Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 0),
	Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(0, 1, 1)
]
const TETRAHEDRA: Array[Array] = [
	[0, 5, 1, 6], [0, 1, 2, 6], [0, 2, 3, 6],
	[0, 3, 7, 6], [0, 7, 4, 6], [0, 4, 5, 6]
]

static func build_mesh(data: TerrainChunkData, iso_level: float = 0.0) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(data.cells.z):
		for y in range(data.cells.y):
			for x in range(data.cells.x):
				var base := Vector3i(x, y, z)
				var positions: Array[Vector3] = []
				var densities: Array[float] = []
				for corner in CORNERS:
					var sample_coord: Vector3i = base + corner
					positions.append(data.local_sample_position(sample_coord))
					densities.append(data.get_density(sample_coord))
				for tetra in TETRAHEDRA:
					_polygonize_tetra(surface, positions, densities, tetra, iso_level)
	return surface.commit()

static func _polygonize_tetra(surface: SurfaceTool, positions: Array[Vector3], densities: Array[float], tetra: Array, iso_level: float) -> void:
	var inside: Array[int] = []
	var outside: Array[int] = []
	var inside_center := Vector3.ZERO
	var outside_center := Vector3.ZERO
	for local_index in range(4):
		var corner_index: int = tetra[local_index]
		if densities[corner_index] >= iso_level:
			inside.append(corner_index)
			inside_center += positions[corner_index]
		else:
			outside.append(corner_index)
			outside_center += positions[corner_index]
	if inside.is_empty() or outside.is_empty():
		return
	inside_center /= float(inside.size())
	outside_center /= float(outside.size())
	var outward := outside_center - inside_center
	if inside.size() == 1:
		var a: int = inside[0]
		var p0 := _interpolate(positions[a], positions[outside[0]], densities[a], densities[outside[0]], iso_level)
		var p1 := _interpolate(positions[a], positions[outside[1]], densities[a], densities[outside[1]], iso_level)
		var p2 := _interpolate(positions[a], positions[outside[2]], densities[a], densities[outside[2]], iso_level)
		_add_oriented_triangle(surface, p0, p1, p2, outward)
	elif inside.size() == 3:
		var a: int = outside[0]
		var p0 := _interpolate(positions[a], positions[inside[0]], densities[a], densities[inside[0]], iso_level)
		var p1 := _interpolate(positions[a], positions[inside[1]], densities[a], densities[inside[1]], iso_level)
		var p2 := _interpolate(positions[a], positions[inside[2]], densities[a], densities[inside[2]], iso_level)
		_add_oriented_triangle(surface, p0, p1, p2, outward)
	else:
		var a: int = inside[0]
		var b: int = inside[1]
		var c: int = outside[0]
		var d: int = outside[1]
		var ac := _interpolate(positions[a], positions[c], densities[a], densities[c], iso_level)
		var ad := _interpolate(positions[a], positions[d], densities[a], densities[d], iso_level)
		var bc := _interpolate(positions[b], positions[c], densities[b], densities[c], iso_level)
		var bd := _interpolate(positions[b], positions[d], densities[b], densities[d], iso_level)
		_add_oriented_triangle(surface, ac, ad, bc, outward)
		_add_oriented_triangle(surface, ad, bd, bc, outward)

static func _interpolate(a: Vector3, b: Vector3, density_a: float, density_b: float, iso_level: float) -> Vector3:
	var denominator := density_b - density_a
	if is_zero_approx(denominator):
		return (a + b) * 0.5
	return a.lerp(b, clampf((iso_level - density_a) / denominator, 0.0, 1.0))

static func _add_oriented_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() <= 0.0000001:
		return
	surface.add_vertex(a)
	if normal.dot(outward) < 0.0:
		surface.add_vertex(c)
		surface.add_vertex(b)
	else:
		surface.add_vertex(b)
		surface.add_vertex(c)
