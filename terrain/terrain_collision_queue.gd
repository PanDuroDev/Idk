class_name TerrainCollisionQueue
extends Node
## Applies static chunk collider replacements at a bounded rate.
## Requests are coalesced by CollisionShape3D so stale intermediate meshes
## are never installed when several edits arrive before the next physics tick.

@export_range(1, 8, 1) var max_rebuilds_per_physics_frame: int = 1
@export_range(1, 32, 1) var max_pending_collision_rebuilds: int = 8

var _pending_order: Array[int] = []
var _pending_by_shape: Dictionary = {}
var total_rebuilds: int = 0
var rejected_requests: int = 0

func configure_from_budget(budget: TerrainBudgetConfig) -> void:
	budget.configure_collision_queue(self)

func request_rebuild(body: StaticBody3D, collision_node: CollisionShape3D, mesh: ArrayMesh) -> bool:
	if not is_instance_valid(body) or not is_instance_valid(collision_node):
		return false
	if collision_node.get_parent() != body:
		return false
	var key := collision_node.get_instance_id()
	if not _pending_by_shape.has(key):
		if _pending_by_shape.size() >= maxi(1, max_pending_collision_rebuilds):
			rejected_requests += 1
			return false
		_pending_order.append(key)
	_pending_by_shape[key] = {
		"body": body,
		"collision_node": collision_node,
		"mesh": mesh
	}
	return true

func pending_count() -> int:
	return _pending_by_shape.size()

func clear_pending() -> void:
	_pending_order.clear()
	_pending_by_shape.clear()

func _physics_process(_delta: float) -> void:
	var budget := maxi(1, max_rebuilds_per_physics_frame)
	var processed := 0
	while processed < budget and not _pending_order.is_empty():
		var key: int = _pending_order.pop_front()
		if not _pending_by_shape.has(key):
			continue
		var request: Dictionary = _pending_by_shape[key]
		_pending_by_shape.erase(key)
		_apply_request(request)
		processed += 1

func _apply_request(request: Dictionary) -> void:
	var body: StaticBody3D = request["body"]
	var collision_node: CollisionShape3D = request["collision_node"]
	if not is_instance_valid(body) or not is_instance_valid(collision_node):
		return
	if collision_node.get_parent() != body:
		return
	var mesh: ArrayMesh = request["mesh"]
	var new_shape: Shape3D
	if mesh != null and mesh.get_surface_count() > 0:
		new_shape = mesh.create_trimesh_shape()
	# Deferred property writes run after the active physics query/step. The
	# old collider is disabled before the replacement is installed.
	collision_node.set_deferred("disabled", true)
	collision_node.set_deferred("shape", new_shape)
	collision_node.set_deferred("disabled", new_shape == null)
	total_rebuilds += 1
