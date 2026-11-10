class_name TerrainEditJournal
extends RefCounted
## Stores compact world-space density edits. The same journal and deterministic
## base-density function can rebuild duplicated border samples in any chunk.

var _sphere_edits: Array[Dictionary] = []

func add_sphere(center_world: Vector3, radius: float, density_delta: float) -> bool:
	if radius <= 0.0 or is_zero_approx(density_delta):
		return false
	_sphere_edits.append({
		"center": center_world,
		"radius": radius,
		"delta": density_delta
	})
	return true

func clear() -> void:
	_sphere_edits.clear()

func edit_count() -> int:
	return _sphere_edits.size()

func evaluate_density(base_density: float, world_position: Vector3) -> float:
	var density := base_density
	for edit in _sphere_edits:
		var center: Vector3 = edit["center"]
		var radius: float = edit["radius"]
		var distance := world_position.distance_to(center)
		if distance >= radius:
			continue
		var falloff := 1.0 - distance / radius
		density += float(edit["delta"]) * falloff
	return density

func rebuild_chunk_samples(data: Variant, base_field: Callable) -> void:
	var dimensions: Vector3i = data.sample_dimensions()
	for z in range(dimensions.z):
		for y in range(dimensions.y):
			for x in range(dimensions.x):
				var local_sample := Vector3i(x, y, z)
				var world_position: Vector3 = data.world_sample_position(local_sample)
				var base_density: float = base_field.call(world_position)
				data.set_density(local_sample, evaluate_density(base_density, world_position))

func get_affected_chunks(center_world: Vector3, radius: float, cells: Vector3i, cell_size: float) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if radius <= 0.0 or cell_size <= 0.0:
		return result
	var chunk_world_size := Vector3(cells) * cell_size
	var min_chunk := Vector3i(
		floori((center_world.x - radius) / chunk_world_size.x),
		floori((center_world.y - radius) / chunk_world_size.y),
		floori((center_world.z - radius) / chunk_world_size.z)
	)
	var max_chunk := Vector3i(
		floori((center_world.x + radius) / chunk_world_size.x),
		floori((center_world.y + radius) / chunk_world_size.y),
		floori((center_world.z + radius) / chunk_world_size.z)
	)
	for z in range(min_chunk.z, max_chunk.z + 1):
		for y in range(min_chunk.y, max_chunk.y + 1):
			for x in range(min_chunk.x, max_chunk.x + 1):
				var coord := Vector3i(x, y, z)
				var bounds_min := Vector3(coord * cells) * cell_size
				var bounds_max := Vector3((coord + Vector3i.ONE) * cells) * cell_size
				var closest := Vector3(
					clampf(center_world.x, bounds_min.x, bounds_max.x),
					clampf(center_world.y, bounds_min.y, bounds_max.y),
					clampf(center_world.z, bounds_min.z, bounds_max.z)
				)
				if closest.distance_squared_to(center_world) <= radius * radius:
					result.append(coord)
	return result
