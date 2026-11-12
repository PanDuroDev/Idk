extends Node3D

const SUPPORT_GRAPH_SCRIPT = preload("res://scripts/structural_support_graph.gd")
const BUILDING_DEFINITION_VALIDATOR = preload("res://scripts/building_definition_validator.gd")
const BuildingDefinitionScript = preload("res://scripts/building_definition.gd")
const BuildingCellDefinitionScript = preload("res://scripts/building_cell_definition.gd")
const DestructionMaterialProfileScript = preload("res://scripts/destruction_material_profile.gd")
const DEFAULT_BUILDING_DEFINITION: BuildingDefinitionScript = preload("res://resources/buildings/classic_70_piece.tres")

var _fragments: Array[RigidBody3D] = []
var _initial_transforms: Array[Transform3D] = []
var _cells: Array[Vector3i] = []
var _fragments_by_cell: Dictionary = {}
var _material_by_cell: Dictionary = {}
var _material_overrides_by_cell: Dictionary = {}
var _damage_by_cell: Dictionary = {}
var _broken_cells: Dictionary = {}
var _removed_cells: Dictionary = {}
var _supported_cells: Dictionary = {}
var _unsupported_cells: Dictionary = {}
var _ground_sampler: Callable = Callable()
var _loose_age_by_fragment: Dictionary = {}
var _retired_fragment_ids: Dictionary = {}
var _initial_collision_layers: Array[int] = []
var _initial_collision_masks: Array[int] = []
var _initial_visibility: Array[bool] = []

@export var building_definition: BuildingDefinitionScript = DEFAULT_BUILDING_DEFINITION
@export_range(1, 256, 1) var max_active_loose_fragments: int = 70
@export_range(0.0, 300.0, 1.0) var loose_debris_lifetime_seconds: float = 30.0

var _build_validation_errors: Array[String] = []

var _shared_mesh: BoxMesh
var _shared_collision_shape: BoxShape3D
var _shared_materials: Dictionary = {}


func _ready() -> void:
	name = "DestructibleStructure"
	_build_validation_errors = BUILDING_DEFINITION_VALIDATOR.validate_definition(building_definition)
	if not _build_validation_errors.is_empty():
		push_error("Invalid building definition '%s': %s" % [
			String(building_definition.definition_id) if building_definition != null else "<null>",
			"\n".join(_build_validation_errors)
		])
		set_physics_process(false)
		return
	_create_shared_resources()
	_build_structure()
	_refresh_support_state()


func get_build_validation_errors() -> Array[String]:
	return _build_validation_errors.duplicate()


func configure_definition(
	new_definition: BuildingDefinitionScript,
	material_overrides: Dictionary = {}
) -> Array[String]:
	## Validate the complete candidate before removing any existing fragment.
	if new_definition == null:
		var null_errors: Array[String] = ["Building definition is null."]
		return null_errors
	var errors: Array[String] = BUILDING_DEFINITION_VALIDATOR.validate_definition(new_definition)
	for cell_variant: Variant in material_overrides.keys():
		if not cell_variant is Vector3i:
			errors.append("Material override keys must be Vector3i cells.")
			continue
		var profile: Variant = material_overrides[cell_variant]
		if not profile is DestructionMaterialProfileScript:
			errors.append("Material override for cell %s is not a DestructionMaterialProfile." % cell_variant)
			continue
		for profile_error: String in BUILDING_DEFINITION_VALIDATOR.validate_material_profile(profile):
			errors.append("Material override for cell %s: %s" % [cell_variant, profile_error])
	if not errors.is_empty():
		return errors

	_release_existing_fragments()
	_material_overrides_by_cell = material_overrides.duplicate()
	building_definition = new_definition
	_build_validation_errors.clear()
	_create_shared_resources()
	_build_structure()
	_refresh_support_state()
	return _build_validation_errors.duplicate()


func get_building_definition() -> BuildingDefinitionScript:
	return building_definition


func get_material_override_count() -> int:
	return _material_overrides_by_cell.size()


func set_ground_sampler(sampler: Callable) -> void:
	## The sampler returns terrain density (> 0 is solid) for a world position.
	## Without one, every bottom cell counts as grounded.
	_ground_sampler = sampler
	_refresh_support_state()


func refresh_support() -> void:
	_refresh_support_state()


func _release_existing_fragments() -> void:
	for fragment: RigidBody3D in _fragments:
		if is_instance_valid(fragment):
			remove_child(fragment)
			fragment.free()
	_fragments.clear()
	_initial_transforms.clear()
	_cells.clear()
	_fragments_by_cell.clear()
	_material_by_cell.clear()
	_damage_by_cell.clear()
	_broken_cells.clear()
	_removed_cells.clear()
	_supported_cells.clear()
	_unsupported_cells.clear()
	_loose_age_by_fragment.clear()
	_retired_fragment_ids.clear()
	_initial_collision_layers.clear()
	_initial_collision_masks.clear()
	_initial_visibility.clear()
	_shared_materials.clear()


func _get_cell_profile(cell_definition: BuildingCellDefinitionScript) -> DestructionMaterialProfileScript:
	if _material_overrides_by_cell.has(cell_definition.coordinate):
		return _material_overrides_by_cell[cell_definition.coordinate] as DestructionMaterialProfileScript
	return building_definition.get_cell_material_profile(cell_definition)


func _physics_process(delta: float) -> void:
	_update_loose_debris(delta)
	_enforce_active_fragment_budget()


func _create_shared_resources() -> void:
	_shared_mesh = BoxMesh.new()
	_shared_mesh.size = building_definition.cell_size

	_shared_collision_shape = BoxShape3D.new()
	_shared_collision_shape.size = building_definition.cell_size

	_shared_materials.clear()
	for cell_definition: BuildingCellDefinitionScript in building_definition.cells:
		var profile: DestructionMaterialProfileScript = _get_cell_profile(cell_definition)
		if not _shared_materials.has(profile.material_id):
			_shared_materials[profile.material_id] = profile.create_surface_material()


func _build_structure() -> void:
	for cell_definition: BuildingCellDefinitionScript in building_definition.cells:
		var cell: Vector3i = cell_definition.coordinate
		var profile: DestructionMaterialProfileScript = _get_cell_profile(cell_definition)
		var fragment := RigidBody3D.new()
		fragment.name = "Fragment_%02d_%02d_%02d" % [cell.x, cell.y, cell.z]
		fragment.transform = building_definition.get_cell_local_transform(cell_definition)
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
		_initial_collision_layers.append(fragment.collision_layer)
		_initial_collision_masks.append(fragment.collision_mask)
		_initial_visibility.append(fragment.visible)


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
		newly_broken += 1

	if newly_broken > 0 or _ground_sampler.is_valid():
		# Re-check even without new broken cells: a terrain carve can remove the
		# ground under a still-intact base.
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
	for cell: Vector3i in _broken_cells:
		_removed_cells[cell] = true
	var grounded: Dictionary = _find_grounded_bottom_cells()
	_supported_cells = SUPPORT_GRAPH_SCRIPT.find_supported_cells(
		_cells, _removed_cells, grounded, _ground_sampler.is_valid()
	)
	_unsupported_cells.clear()

	for cell: Vector3i in _cells:
		var fragment: RigidBody3D = _fragments_by_cell[cell] as RigidBody3D
		if _removed_cells.has(cell):
			_release_fragment(fragment)
			continue
		if _supported_cells.has(cell):
			continue

		_unsupported_cells[cell] = true
		_removed_cells[cell] = true
		_release_fragment(fragment)


func _find_grounded_bottom_cells() -> Dictionary:
	var grounded: Dictionary = {}
	if not _ground_sampler.is_valid() or building_definition == null:
		return grounded
	var probe_depth: float = building_definition.cell_size.y * 0.5 + 0.08
	for cell: Vector3i in _cells:
		if cell.y != 0 or _removed_cells.has(cell):
			continue
		var fragment: RigidBody3D = _fragments_by_cell.get(cell) as RigidBody3D
		if not is_instance_valid(fragment):
			continue
		var probe: Vector3 = fragment.global_position - Vector3(0.0, probe_depth, 0.0)
		if float(_ground_sampler.call(probe)) > 0.0:
			grounded[cell] = true
	return grounded


func _release_fragment(fragment: RigidBody3D) -> void:
	if not is_instance_valid(fragment):
		return
	var fragment_id: int = fragment.get_instance_id()
	if _retired_fragment_ids.has(fragment_id):
		return
	if not _loose_age_by_fragment.has(fragment_id):
		_loose_age_by_fragment[fragment_id] = 0.0
		fragment.add_to_group("loose_debris")
		fragment.freeze = false
		fragment.sleeping = false


func _update_loose_debris(delta: float) -> void:
	for fragment: RigidBody3D in _fragments:
		if not is_instance_valid(fragment):
			continue
		var fragment_id: int = fragment.get_instance_id()
		if not _loose_age_by_fragment.has(fragment_id) or _retired_fragment_ids.has(fragment_id):
			continue
		var age: float = float(_loose_age_by_fragment[fragment_id]) + delta
		_loose_age_by_fragment[fragment_id] = age
		if loose_debris_lifetime_seconds > 0.0 and age >= loose_debris_lifetime_seconds:
			_retire_fragment(fragment, fragment_id)


func _retire_fragment(fragment: RigidBody3D, fragment_id: int) -> void:
	# Retire only released fragments. Keep the original node and transform data so reset is lossless.
	_retired_fragment_ids[fragment_id] = true
	fragment.freeze = true
	fragment.linear_velocity = Vector3.ZERO
	fragment.angular_velocity = Vector3.ZERO
	fragment.sleeping = true
	fragment.visible = false
	fragment.collision_layer = 0
	fragment.collision_mask = 0
	fragment.remove_from_group("blastable")
	fragment.remove_from_group("loose_debris")


func _enforce_active_fragment_budget() -> void:
	var active_count: int = 0
	for fragment: RigidBody3D in _fragments:
		if not is_instance_valid(fragment):
			continue
		var fragment_id: int = fragment.get_instance_id()
		if not _loose_age_by_fragment.has(fragment_id) or _retired_fragment_ids.has(fragment_id) or fragment.freeze or fragment.sleeping:
			continue
		active_count += 1
		if active_count > max_active_loose_fragments:
			# Park excess bodies so collisions cannot push the awake count over budget.
			# BlastService explicitly unfreezes a parked body when a new impact hits it.
			fragment.freeze = true
			fragment.sleeping = true


func get_fragment_count() -> int:
	return _fragments.size()


func get_building_definition_id() -> StringName:
	return building_definition.definition_id if building_definition != null else &""


func get_released_fragment_count() -> int:
	return _loose_age_by_fragment.size() - _retired_fragment_ids.size()


func get_broken_fragment_count() -> int:
	return _broken_cells.size()


func get_active_loose_fragment_count() -> int:
	var count: int = 0
	for fragment: RigidBody3D in _fragments:
		if not is_instance_valid(fragment):
			continue
		var fragment_id: int = fragment.get_instance_id()
		if _loose_age_by_fragment.has(fragment_id) and not _retired_fragment_ids.has(fragment_id) and not fragment.freeze and not fragment.sleeping:
			count += 1
	return count


func get_sleeping_loose_fragment_count() -> int:
	var count: int = 0
	for fragment: RigidBody3D in _fragments:
		if not is_instance_valid(fragment):
			continue
		var fragment_id: int = fragment.get_instance_id()
		if _loose_age_by_fragment.has(fragment_id) and not _retired_fragment_ids.has(fragment_id) and not fragment.freeze and fragment.sleeping:
			count += 1
	return count


func get_retired_fragment_count() -> int:
	return _retired_fragment_ids.size()


func get_budget_parked_fragment_count() -> int:
	var count: int = 0
	for fragment: RigidBody3D in _fragments:
		if not is_instance_valid(fragment):
			continue
		var fragment_id: int = fragment.get_instance_id()
		if _loose_age_by_fragment.has(fragment_id) and not _retired_fragment_ids.has(fragment_id) and fragment.freeze:
			count += 1
	return count


func get_fragment_for_cell(cell: Vector3i) -> RigidBody3D:
	return _fragments_by_cell.get(cell) as RigidBody3D


func get_supported_fragment_count() -> int:
	return _supported_cells.size()


func get_unsupported_fragment_count() -> int:
	return _unsupported_cells.size()


func reset_structure() -> void:
	_damage_by_cell.clear()
	_broken_cells.clear()
	_removed_cells.clear()
	_unsupported_cells.clear()
	_loose_age_by_fragment.clear()
	_retired_fragment_ids.clear()

	for index in range(_fragments.size()):
		var fragment: RigidBody3D = _fragments[index]
		if not is_instance_valid(fragment):
			continue
		fragment.freeze = true
		fragment.visible = _initial_visibility[index]
		fragment.collision_layer = _initial_collision_layers[index]
		fragment.collision_mask = _initial_collision_masks[index]
		fragment.remove_from_group("loose_debris")
		fragment.add_to_group("blastable")
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
