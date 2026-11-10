extends Node3D

const WIDTH: int = 7
const HEIGHT: int = 5
const DEPTH: int = 2
const BLOCK_SIZE: Vector3 = Vector3(1.0, 1.0, 1.0)
const SPACING: float = 1.04

const SUPPORT_GRAPH_SCRIPT = preload("res://scripts/structural_support_graph.gd")
const DestructionMaterialProfileScript = preload("res://scripts/destruction_material_profile.gd")
const FOUNDATION_PROFILE: DestructionMaterialProfileScript = preload("res://resources/materials/foundation_concrete.tres")
const MASONRY_PROFILE: DestructionMaterialProfileScript = preload("res://resources/materials/masonry.tres")
const LIGHTWEIGHT_PROFILE: DestructionMaterialProfileScript = preload("res://resources/materials/lightweight_panel.tres")

var _fragments: Array[RigidBody3D] = []
var _initial_transforms: Array[Transform3D] = []
var _cells: Array[Vector3i] = []
var _fragments_by_cell: Dictionary = {}
var _material_by_cell: Dictionary = {}
var _damage_by_cell: Dictionary = {}
var _broken_cells: Dictionary = {}
var _supported_cells: Dictionary = {}
var _unsupported_cells: Dictionary = {}

var _shared_mesh: BoxMesh
var _shared_collision_shape: BoxShape3D
var _shared_materials: Dictionary = {}


func _ready() -> void:
	name = "DestructibleStructure"
	_create_shared_resources()
	_build_structure()
	_refresh_support_state()


func _create_shared_resources() -> void:
	_shared_mesh = BoxMesh.new()
	_shared_mesh.size = BLOCK_SIZE

	_shared_collision_shape = BoxShape3D.new()
	_shared_collision_shape.size = BLOCK_SIZE

	for profile: DestructionMaterialProfileScript in [
		FOUNDATION_PROFILE,
		MASONRY_PROFILE,
		LIGHTWEIGHT_PROFILE
	]:
		_shared_materials[profile.material_id] = profile.create_surface_material()


func _get_profile_for_layer(layer: int) -> DestructionMaterialProfileScript:
	if layer == 0:
		return FOUNDATION_PROFILE
	if layer == HEIGHT - 1:
		return LIGHTWEIGHT_PROFILE
	return MASONRY_PROFILE


func _build_structure() -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			for z in range(DEPTH):
				var cell := Vector3i(x, y, z)
				var profile: DestructionMaterialProfileScript = _get_profile_for_layer(y)
				var fragment := RigidBody3D.new()
				fragment.name = "Fragment_%02d_%02d_%02d" % [x, y, z]
				fragment.position = Vector3(
					(float(x) - float(WIDTH - 1) * 0.5) * SPACING,
					0.5 + float(y) * SPACING,
					(float(z) - float(DEPTH - 1) * 0.5) * SPACING
				)
				fragment.mass = maxf(profile.density_multiplier, 0.1)
				fragment.freeze = true
				fragment.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
				fragment.collision_layer = 1
				fragment.collision_mask = 1
				fragment.add_to_group("destructible")
				fragment.add_to_group("blastable")
				add_child(fragment)

				var mesh_instance := MeshInstance3D.new()
				mesh_instance.mesh = _shared_mesh
				mesh_instance.material_override = _shared_materials[profile.material_id]
				fragment.add_child(mesh_instance)

				var collision := CollisionShape3D.new()
				collision.shape = _shared_collision_shape
				fragment.add_child(collision)

				_cells.append(cell)
				_fragments.append(fragment)
				_fragments_by_cell[cell] = fragment
				_material_by_cell[cell] = profile
				_initial_transforms.append(fragment.transform)


func apply_blast_damage(origin: Vector3, radius: float, damage_amount: float = 1.0) -> int:
	var safe_radius: float = maxf(radius, 0.0)
	var safe_damage: float = maxf(damage_amount, 0.0)
	if safe_radius <= 0.0 or safe_damage <= 0.0:
		return 0

	var newly_broken: int = 0
	for cell: Vector3i in _cells:
		if _broken_cells.has(cell):
			continue

		var fragment: RigidBody3D = _fragments_by_cell[cell] as RigidBody3D
		var profile: DestructionMaterialProfileScript = _material_by_cell[cell] as DestructionMaterialProfileScript
		var distance: float = fragment.global_position.distance_to(origin)
		if distance >= safe_radius:
			continue

		var falloff: float = 1.0 - distance / safe_radius
		var resistance: float = maxf(profile.blast_resistance, 0.1)
		var damage_added: float = safe_damage * falloff / resistance
		var integrity: float = maxf(profile.integrity, 0.1)
		var accumulated_damage: float = float(_damage_by_cell.get(cell, 0.0)) + damage_added
		accumulated_damage = minf(accumulated_damage, integrity)
		_damage_by_cell[cell] = accumulated_damage

		if accumulated_damage < integrity:
			continue

		_broken_cells[cell] = true
		fragment.freeze = false
		newly_broken += 1

	if newly_broken > 0:
		_refresh_support_state()

	return newly_broken


func get_cell_damage(cell: Vector3i) -> float:
	return float(_damage_by_cell.get(cell, 0.0))


func get_cell_damage_ratio(cell: Vector3i) -> float:
	return clampf(get_cell_damage(cell) / get_cell_integrity(cell), 0.0, 1.0)


func get_cell_material_id(cell: Vector3i) -> StringName:
	var profile: DestructionMaterialProfileScript = _material_by_cell.get(cell) as DestructionMaterialProfileScript
	return profile.material_id if profile != null else &""


func get_cell_material_name(cell: Vector3i) -> String:
	var profile: DestructionMaterialProfileScript = _material_by_cell.get(cell) as DestructionMaterialProfileScript
	return profile.display_name if profile != null else ""


func get_cell_integrity(cell: Vector3i) -> float:
	var profile: DestructionMaterialProfileScript = _material_by_cell.get(cell) as DestructionMaterialProfileScript
	return maxf(profile.integrity, 0.1) if profile != null else 0.1


func get_cell_blast_resistance(cell: Vector3i) -> float:
	var profile: DestructionMaterialProfileScript = _material_by_cell.get(cell) as DestructionMaterialProfileScript
	return maxf(profile.blast_resistance, 0.1) if profile != null else 0.1


func get_cell_density_multiplier(cell: Vector3i) -> float:
	var profile: DestructionMaterialProfileScript = _material_by_cell.get(cell) as DestructionMaterialProfileScript
	return maxf(profile.density_multiplier, 0.1) if profile != null else 0.1


func _refresh_support_state() -> void:
	_supported_cells = SUPPORT_GRAPH_SCRIPT.find_supported_cells(_cells, _broken_cells)
	_unsupported_cells.clear()

	for cell: Vector3i in _cells:
		if _broken_cells.has(cell) or _supported_cells.has(cell):
			continue

		_unsupported_cells[cell] = true
		var fragment: RigidBody3D = _fragments_by_cell[cell] as RigidBody3D
		if fragment.freeze:
			fragment.freeze = false


func get_fragment_count() -> int:
	return _fragments.size()


func get_released_fragment_count() -> int:
	var released_count: int = 0
	for fragment: RigidBody3D in _fragments:
		if is_instance_valid(fragment) and not fragment.freeze:
			released_count += 1
	return released_count


func get_broken_fragment_count() -> int:
	return _broken_cells.size()


func get_supported_fragment_count() -> int:
	return _supported_cells.size()


func get_unsupported_fragment_count() -> int:
	return _unsupported_cells.size()


func reset_structure() -> void:
	_damage_by_cell.clear()
	_broken_cells.clear()
	_unsupported_cells.clear()

	for index in range(_fragments.size()):
		var fragment: RigidBody3D = _fragments[index]
		if not is_instance_valid(fragment):
			continue
		fragment.freeze = true
		fragment.transform = _initial_transforms[index]
		fragment.linear_velocity = Vector3.ZERO
		fragment.angular_velocity = Vector3.ZERO
		fragment.sleeping = true

	_refresh_support_state()


func is_reset_to_initial_state() -> bool:
	if not _damage_by_cell.is_empty() or not _broken_cells.is_empty() or not _unsupported_cells.is_empty():
		return false
	if _supported_cells.size() != _fragments.size():
		return false

	for index in range(_fragments.size()):
		var fragment: RigidBody3D = _fragments[index]
		if not is_instance_valid(fragment) or not fragment.freeze:
			return false
		if fragment.position.distance_to(_initial_transforms[index].origin) > 0.001:
			return false
		if not fragment.linear_velocity.is_zero_approx():
			return false
		if not fragment.angular_velocity.is_zero_approx():
			return false
	return true
