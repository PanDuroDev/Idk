class_name BlastService
extends RefCounted

const BLASTABLE_GROUP: StringName = &"blastable"
const MAX_QUERY_RESULTS: int = 256

var _sphere_shape: SphereShape3D = SphereShape3D.new()
var _query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()


func _init() -> void:
	_query.shape = _sphere_shape
	_query.collision_mask = 1
	_query.collide_with_bodies = true
	_query.collide_with_areas = false


func apply_radial_impulse(
	space_state: PhysicsDirectSpaceState3D,
	origin: Vector3,
	radius: float,
	impulse_strength: float,
	upward_bias: float = 0.25
) -> int:
	if space_state == null or impulse_strength <= 0.0:
		return 0

	var safe_radius: float = maxf(radius, 0.05)
	_sphere_shape.radius = safe_radius
	_query.transform = Transform3D(Basis.IDENTITY, origin)

	var affected: Array[Dictionary] = space_state.intersect_shape(_query, MAX_QUERY_RESULTS)
	var activated_count: int = 0

	for hit: Dictionary in affected:
		var body: RigidBody3D = hit.get("collider") as RigidBody3D
		if body == null or not body.is_in_group(BLASTABLE_GROUP):
			continue

		var offset: Vector3 = body.global_position - origin
		var distance: float = offset.length()
		var falloff: float = 1.0 - clampf(distance / safe_radius, 0.0, 1.0)
		falloff *= falloff
		if falloff <= 0.0:
			continue

		var impulse_direction: Vector3 = Vector3.UP
		if distance > 0.0001:
			impulse_direction = offset / distance
		impulse_direction = (impulse_direction + Vector3.UP * maxf(upward_bias, 0.0)).normalized()

		if body.freeze:
			body.freeze = false
		body.apply_central_impulse(impulse_direction * impulse_strength * falloff)
		activated_count += 1

	return activated_count
