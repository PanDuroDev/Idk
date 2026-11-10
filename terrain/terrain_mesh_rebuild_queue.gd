class_name TerrainMeshRebuildQueue
extends Node
## Builds only queued dirty chunks and applies ArrayMesh resources on the main
## thread. Requests for the same MeshInstance3D are coalesced to the latest data.

const Mesher = preload("res://terrain/terrain_tetra_mesher.gd")

@export_range(1, 8, 1) var max_rebuilds_per_frame: int = 1
@export_range(1, 32, 1) var max_pending_mesh_rebuilds: int = 8

var _pending_order: Array[int] = []
var _pending_by_target: Dictionary = {}
var total_rebuilds: int = 0
var rejected_requests: int = 0

signal mesh_rebuilt(target: MeshInstance3D, mesh: ArrayMesh)

func request_rebuild(target: MeshInstance3D, data: TerrainChunkData) -> bool:
	if not is_instance_valid(target) or data == null:
		return false
	var key := target.get_instance_id()
	if not _pending_by_target.has(key):
		if _pending_by_target.size() >= maxi(1, max_pending_mesh_rebuilds):
			rejected_requests += 1
			return false
		_pending_order.append(key)
	_pending_by_target[key] = {
		"target": target,
		"data": data
	}
	return true

func pending_count() -> int:
	return _pending_by_target.size()

func clear_pending() -> void:
	_pending_order.clear()
	_pending_by_target.clear()

func _process(_delta: float) -> void:
	var budget := maxi(1, max_rebuilds_per_frame)
	var processed := 0
	while processed < budget and not _pending_order.is_empty():
		var key: int = _pending_order.pop_front()
		if not _pending_by_target.has(key):
			continue
		var request: Dictionary = _pending_by_target[key]
		_pending_by_target.erase(key)
		var target: MeshInstance3D = request["target"]
		var data: TerrainChunkData = request["data"]
		if is_instance_valid(target) and data != null:
			var mesh: ArrayMesh = Mesher.build_mesh(data)
			target.mesh = mesh
			total_rebuilds += 1
			mesh_rebuilt.emit(target, mesh)
		processed += 1
