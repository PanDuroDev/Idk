class_name TerrainChunkData
extends RefCounted
## CPU-side scalar field for one terrain chunk.
## Samples include the positive border (cells + 1), so adjacent chunks can
## evaluate their shared boundary from the same global lattice coordinates.

var chunk_coord: Vector3i
var cells: Vector3i
var cell_size: float
var samples: PackedFloat32Array

static func create(p_chunk_coord: Vector3i, p_cells: Vector3i = Vector3i(16, 16, 16), p_cell_size: float = 1.0) -> TerrainChunkData:
	var data := TerrainChunkData.new()
	data.chunk_coord = p_chunk_coord
	data.cells = Vector3i(maxi(1, p_cells.x), maxi(1, p_cells.y), maxi(1, p_cells.z))
	data.cell_size = maxf(0.001, p_cell_size)
	var dimensions := data.sample_dimensions()
	data.samples.resize(dimensions.x * dimensions.y * dimensions.z)
	data.samples.fill(-1.0)
	return data

func sample_dimensions() -> Vector3i:
	return cells + Vector3i.ONE

func sample_index(local_sample: Vector3i) -> int:
	var dimensions := sample_dimensions()
	assert(local_sample.x >= 0 and local_sample.x < dimensions.x and local_sample.y >= 0 and local_sample.y < dimensions.y and local_sample.z >= 0 and local_sample.z < dimensions.z, "Terrain sample coordinate is outside the chunk")
	return local_sample.x + dimensions.x * (local_sample.y + dimensions.y * local_sample.z)

func get_density(local_sample: Vector3i) -> float:
	return samples[sample_index(local_sample)]

func set_density(local_sample: Vector3i, density: float) -> void:
	samples[sample_index(local_sample)] = density

func global_sample_coord(local_sample: Vector3i) -> Vector3i:
	return chunk_coord * cells + local_sample

func local_sample_position(local_sample: Vector3i) -> Vector3:
	return Vector3(local_sample) * cell_size

func world_sample_position(local_sample: Vector3i) -> Vector3:
	return Vector3(global_sample_coord(local_sample)) * cell_size
