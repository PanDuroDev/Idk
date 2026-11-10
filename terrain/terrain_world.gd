class_name TerrainWorld
extends Node3D
## Small resident terrain patch that owns chunk data, meshes, colliders, and
## bounded rebuild queues. Initial chunks are built synchronously; edits and
## resets rebuild only the affected resident chunks.

const ChunkData = preload("res://terrain/terrain_chunk_data.gd")
const EditJournal = preload("res://terrain/terrain_edit_journal.gd")
const Mesher = preload("res://terrain/terrain_tetra_mesher.gd")
const MeshQueue = preload("res://terrain/terrain_mesh_rebuild_queue.gd")
const CollisionQueue = preload("res://terrain/terrain_collision_queue.gd")
const BudgetConfig = preload("res://terrain/terrain_budget_config.gd")

const CHUNK_LAYER: int = 0
const CHUNK_MIN: int = -1
const CHUNK_MAX: int = 1

@export var use_low_end_fallback: bool = false
@export var surface_color: Color = Color(0.26, 0.31, 0.25)

var _budget: TerrainBudgetConfig
var _cells: Vector3i
var _cell_size: float
var _journal: TerrainEditJournal
var _mesh_queue: TerrainMeshRebuildQueue
var _collision_queue: TerrainCollisionQueue
var _chunks: Dictionary = {}
var _coord_by_mesh_id: Dictionary = {}
var _material: StandardMaterial3D
var _carve_count: int = 0
var _rejected_carve_count: int = 0
var _last_affected_chunks: Array[Vector3i] = []


func _ready() -> void:
	_budget = BudgetConfig.low_end_fallback() if use_low_end_fallback else BudgetConfig.new()
	_cells = Vector3i.ONE * _budget.chunk_resolution
	_cell_size = 2.0 if use_low_end_fallback else 1.0
	_journal = EditJournal.new()

	_material = StandardMaterial3D.new()
	_material.albedo_color = surface_color
	_material.roughness = 0.95

	_mesh_queue = MeshQueue.new()
	_mesh_queue.name = "TerrainMeshRebuildQueue"
	_budget.configure_mesh_queue(_mesh_queue)
	add_child(_mesh_queue)
	_mesh_queue.mesh_rebuilt.connect(_on_mesh_rebuilt)

	_collision_queue = CollisionQueue.new()
	_collision_queue.name = "TerrainCollisionRebuildQueue"
	_budget.configure_collision_queue(_collision_queue)
	add_child(_collision_queue)

	for z in range(CHUNK_MIN, CHUNK_MAX):
		for x in range(CHUNK_MIN, CHUNK_MAX):
			_create_chunk(Vector3i(x, CHUNK_LAYER, z))


func carve_sphere(center_world: Vector3, radius: float, strength: float) -> Dictionary:
	if not is_inside_tree() or radius <= 0.0 or strength <= 0.0:
		return _reject("invalid_parameters")
	var local_center := to_local(center_world)
	var affected: Array[Vector3i] = _journal.get_affected_chunks(local_center, radius, _cells, _cell_size)
	var resident: Array[Vector3i] = []
	for coord in affected:
		if _chunks.has(coord):
			resident.append(coord)
	if resident.is_empty():
		return _reject("no_resident_chunks")
	if not _budget.accepts_edit(radius, resident.size()):
		return _reject("budget_limit")

	_journal.add_sphere(local_center, radius, -absf(strength))
	_carve_count += 1
	_last_affected_chunks = resident
	var queued := 0
	for coord in resident:
		var chunk: Dictionary = _chunks[coord]
		_journal.rebuild_chunk_samples(chunk["data"], Callable(self, "_base_density"))
		if _mesh_queue.request_rebuild(chunk["mesh"], chunk["data"]):
			queued += 1
	return {
		"ok": true,
		"affected_chunks": resident.size(),
		"queued_mesh_rebuilds": queued
	}


func reset_terrain() -> void:
	_journal.clear()
	_mesh_queue.clear_pending()
	_collision_queue.clear_pending()
	for coord in _chunks:
		var chunk: Dictionary = _chunks[coord]
		_journal.rebuild_chunk_samples(chunk["data"], Callable(self, "_base_density"))
		var mesh: ArrayMesh = Mesher.build_mesh(chunk["data"])
		chunk["mesh"].mesh = mesh
		_apply_collision(chunk["collision"], mesh)
	_carve_count = 0
	_rejected_carve_count = 0
	_last_affected_chunks.clear()


func is_reset_to_initial_state() -> bool:
	if _journal.edit_count() != 0:
		return false
	for coord in _chunks:
		var data: TerrainChunkData = _chunks[coord]["data"]
		var dimensions := data.sample_dimensions()
		for z in range(dimensions.z):
			for y in range(dimensions.y):
				for x in range(dimensions.x):
					var local_sample := Vector3i(x, y, z)
					var expected := _base_density(data.world_sample_position(local_sample))
					if not is_equal_approx(data.get_density(local_sample), expected):
						return false
	return true


func get_budget() -> TerrainBudgetConfig:
	return _budget


func get_resident_chunk_count() -> int:
	return _chunks.size()


func get_chunk_coords() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for coord in _chunks:
		result.append(coord)
	return result


func get_chunk_data(coord: Vector3i) -> TerrainChunkData:
	if not _chunks.has(coord):
		return null
	return _chunks[coord]["data"]


func get_chunk_mesh(coord: Vector3i) -> Mesh:
	if not _chunks.has(coord):
		return null
	return _chunks[coord]["mesh"].mesh


func get_chunk_collision_shape(coord: Vector3i) -> Shape3D:
	if not _chunks.has(coord):
		return null
	return _chunks[coord]["collision"].shape


func get_mesh_queue() -> TerrainMeshRebuildQueue:
	return _mesh_queue


func get_collision_queue() -> TerrainCollisionQueue:
	return _collision_queue


func get_terrain_edit_count() -> int:
	return _journal.edit_count()


func get_carve_count() -> int:
	return _carve_count


func get_rejected_carve_count() -> int:
	return _rejected_carve_count


func get_last_affected_chunks() -> Array[Vector3i]:
	return _last_affected_chunks.duplicate()


func get_estimated_density_bytes() -> int:
	return _budget.estimated_density_bytes(_chunks.size())


func get_chunk_cell_size() -> float:
	return _cell_size


func _base_density(local_position: Vector3) -> float:
	return 1.0 - local_position.y


func _create_chunk(coord: Vector3i) -> void:
	var data := ChunkData.create(coord, _cells, _cell_size)
	_journal.rebuild_chunk_samples(data, Callable(self, "_base_density"))

	var root := Node3D.new()
	root.name = "Chunk_%d_%d_%d" % [coord.x, coord.y, coord.z]
	root.position = Vector3(coord * _cells) * _cell_size
	add_child(root)

	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("terrain")
	root.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.material_override = _material
	root.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	body.add_child(collision)

	var mesh := Mesher.build_mesh(data)
	mesh_instance.mesh = mesh
	_apply_collision(collision, mesh)
	_chunks[coord] = {
		"data": data,
		"root": root,
		"body": body,
		"mesh": mesh_instance,
		"collision": collision
	}
	_coord_by_mesh_id[mesh_instance.get_instance_id()] = coord


func _on_mesh_rebuilt(target: MeshInstance3D, mesh: ArrayMesh) -> void:
	var key := target.get_instance_id()
	if not _coord_by_mesh_id.has(key):
		return
	var chunk: Dictionary = _chunks.get(_coord_by_mesh_id[key], {})
	if chunk.is_empty():
		return
	_collision_queue.request_rebuild(chunk["body"], chunk["collision"], mesh)


func _apply_collision(collision: CollisionShape3D, mesh: ArrayMesh) -> void:
	if mesh != null and mesh.get_surface_count() > 0:
		collision.shape = mesh.create_trimesh_shape()
		collision.disabled = false
	else:
		collision.shape = null
		collision.disabled = true


func _reject(reason: String) -> Dictionary:
	_rejected_carve_count += 1
	return {
		"ok": false,
		"reason": reason,
		"affected_chunks": 0,
		"queued_mesh_rebuilds": 0
	}
