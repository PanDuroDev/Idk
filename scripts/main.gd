extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player_controller.gd")
const STRUCTURE_SCRIPT = preload("res://scripts/destructible_structure.gd")
const BLAST_SERVICE_SCRIPT = preload("res://scripts/blast_service.gd")

const BLAST_DISTANCE: float = 70.0
const MAX_PENDING_BLASTS: int = 4

@export_range(0.5, 12.0, 0.25) var blast_radius: float = 4.5
@export_range(1.0, 100.0, 1.0) var blast_impulse: float = 22.0
@export_range(0.0, 1.0, 0.05) var blast_upward_bias: float = 0.3
@export_range(0.1, 10.0, 0.1) var blast_damage: float = 4.0

var _structure: Node3D
var _player: CharacterBody3D
var _blast_service: RefCounted
var _pending_blasts: Array[Dictionary] = []
var _reset_requested: bool = false
var _hud_label: Label
var _ui_canvas: CanvasLayer
var _hud_refresh_timer: float = 0.0
var _total_impacts: int = 0
var _last_affected_count: int = 0
var _last_broken_count: int = 0
var _impact_value_labels: Dictionary = {}

const DEFAULT_BLAST_RADIUS: float = 4.5
const DEFAULT_BLAST_DAMAGE: float = 4.0
const DEFAULT_BLAST_IMPULSE: float = 22.0


func _ready() -> void:
	_blast_service = BLAST_SERVICE_SCRIPT.new()
	_build_environment()
	_build_ground()

	_structure = STRUCTURE_SCRIPT.new()
	_structure.position = Vector3(0.0, 0.0, -12.0)
	add_child(_structure)

	_spawn_physics_props()

	_player = PLAYER_SCRIPT.new()
	_player.position = Vector3(0.0, 0.1, 6.0)
	add_child(_player)
	_player.blast_requested.connect(request_blast)

	_build_hud()
	_build_impact_controls()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_structure"):
		request_structure_reset()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _reset_requested:
		if is_instance_valid(_structure):
			_structure.call("reset_structure")
		_reset_requested = false
		_last_broken_count = 0
		_last_affected_count = 0

	while not _pending_blasts.is_empty():
		var request: Dictionary = _pending_blasts.pop_front()
		_process_blast(request["origin"], request["direction"])


func _process(delta: float) -> void:
	_hud_refresh_timer += delta
	if _hud_refresh_timer < 0.25 or not is_instance_valid(_hud_label):
		return
	_hud_refresh_timer = 0.0
	var fragment_total: int = int(_structure.call("get_fragment_count")) if is_instance_valid(_structure) else 0
	var fragment_released: int = int(_structure.call("get_released_fragment_count")) if is_instance_valid(_structure) else 0
	var fragment_broken: int = int(_structure.call("get_broken_fragment_count")) if is_instance_valid(_structure) else 0
	var fragment_unsupported: int = int(_structure.call("get_unsupported_fragment_count")) if is_instance_valid(_structure) else 0
	_hud_label.text = "WORLDBREAK  |  FPS %d  |  Loose %d/%d  |  Broken %d (+%d)  |  Unsupported %d  |  Targets %d" % [
		Engine.get_frames_per_second(),
		fragment_released,
		fragment_total,
		fragment_broken,
		_last_broken_count,
		fragment_unsupported,
		_last_affected_count
	]
	_refresh_impact_controls()


func request_blast(ray_origin: Vector3, ray_direction: Vector3) -> void:
	if _pending_blasts.size() >= MAX_PENDING_BLASTS or ray_direction.is_zero_approx():
		return
	_pending_blasts.append({
		"origin": ray_origin,
		"direction": ray_direction.normalized()
	})


func request_structure_reset() -> void:
	_reset_requested = true


func _process_blast(ray_origin: Vector3, ray_direction: Vector3) -> void:
	var ray_end: Vector3 = ray_origin + ray_direction * BLAST_DISTANCE
	var ray_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1)
	if is_instance_valid(_player):
		ray_query.exclude = [_player.get_rid()]

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ray_hit: Dictionary = space_state.intersect_ray(ray_query)
	var impact_position: Vector3 = ray_hit.get("position", ray_end)

	_last_broken_count = int(_structure.call("apply_blast_damage", impact_position, blast_radius, blast_damage))
	_last_affected_count = int(_blast_service.call(
		"apply_radial_impulse",
		space_state,
		impact_position,
		blast_radius,
		blast_impulse,
		blast_upward_bias
	))
	_total_impacts += 1
	_spawn_blast_flash(impact_position)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.045, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.59, 0.68)
	environment.ambient_light_energy = 0.7
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 1
	add_child(ground)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100.0, 1.0, 100.0)
	collision.shape = shape
	collision.position.y = -0.5
	ground.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.14, 0.17)
	material.roughness = 0.95
	mesh.material = material
	ground.add_child(mesh_instance)


func _spawn_physics_props() -> void:
	var prop_mesh := BoxMesh.new()
	prop_mesh.size = Vector3(0.8, 0.8, 0.8)
	var prop_shape := BoxShape3D.new()
	prop_shape.size = prop_mesh.size
	var prop_material := StandardMaterial3D.new()
	prop_material.albedo_color = Color(0.22, 0.48, 0.68)
	prop_material.roughness = 0.72
	prop_mesh.material = prop_material

	for index in range(6):
		var prop := RigidBody3D.new()
		prop.name = "PhysicsProp_%02d" % index
		prop.position = Vector3(-5.0 + float(index) * 1.8, 1.2, -3.0)
		prop.mass = 1.5
		prop.collision_layer = 1
		prop.collision_mask = 1
		prop.add_to_group("blastable")
		add_child(prop)

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = prop_mesh
		prop.add_child(mesh_instance)

		var collision := CollisionShape3D.new()
		collision.shape = prop_shape
		prop.add_child(collision)


func _spawn_blast_flash(position: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.58, 0.25)
	flash.light_energy = 2.8
	flash.omni_range = 7.0
	add_child(flash)
	flash.global_position = position
	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.16)
	tween.finished.connect(flash.queue_free)


func _build_hud() -> void:
	_ui_canvas = CanvasLayer.new()
	add_child(_ui_canvas)

	_hud_label = Label.new()
	_hud_label.position = Vector2(18.0, 16.0)
	_hud_label.add_theme_font_size_override("font_size", 15)
	_hud_label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.96))
	_ui_canvas.add_child(_hud_label)
	_hud_label.text = "WORLDBREAK - initializing"


func adjust_impact_setting(setting: StringName, amount: float) -> void:
	match setting:
		&"blast_radius":
			blast_radius = clampf(blast_radius + amount, 0.5, 12.0)
		&"blast_damage":
			blast_damage = clampf(blast_damage + amount, 0.1, 10.0)
		&"blast_impulse":
			blast_impulse = clampf(blast_impulse + amount, 1.0, 100.0)
		_:
			return
	_refresh_impact_controls()


func reset_impact_settings() -> void:
	blast_radius = DEFAULT_BLAST_RADIUS
	blast_damage = DEFAULT_BLAST_DAMAGE
	blast_impulse = DEFAULT_BLAST_IMPULSE
	_refresh_impact_controls()


func _build_impact_controls() -> void:
	var panel := PanelContainer.new()
	panel.name = "ImpactControls"
	panel.position = Vector2(910.0, 54.0)
	panel.custom_minimum_size = Vector2(350.0, 0.0)
	_ui_canvas.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = "IMPACT SETTINGS"
	heading.add_theme_font_size_override("font_size", 14)
	layout.add_child(heading)

	_add_impact_control_row(layout, "Blast radius", &"blast_radius", 0.25)
	_add_impact_control_row(layout, "Damage", &"blast_damage", 0.25)
	_add_impact_control_row(layout, "Physical impulse", &"blast_impulse", 1.0)

	var reset_button := Button.new()
	reset_button.text = "Reset impact defaults"
	reset_button.tooltip_text = "Restore radius 4.5, damage 4.0, and impulse 22.0"
	reset_button.pressed.connect(reset_impact_settings)
	layout.add_child(reset_button)
	_refresh_impact_controls()


func _add_impact_control_row(parent: VBoxContainer, title: String, setting: StringName, step: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size.x = 142.0
	row.add_child(name_label)

	var decrease_button := Button.new()
	decrease_button.text = "−"
	decrease_button.custom_minimum_size.x = 34.0
	decrease_button.pressed.connect(adjust_impact_setting.bind(setting, -step))
	row.add_child(decrease_button)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 62.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	_impact_value_labels[setting] = value_label

	var increase_button := Button.new()
	increase_button.text = "+"
	increase_button.custom_minimum_size.x = 34.0
	increase_button.pressed.connect(adjust_impact_setting.bind(setting, step))
	row.add_child(increase_button)


func _refresh_impact_controls() -> void:
	if not _impact_value_labels.has(&"blast_radius"):
		return
	(_impact_value_labels[&"blast_radius"] as Label).text = "%.2f" % blast_radius
	(_impact_value_labels[&"blast_damage"] as Label).text = "%.2f" % blast_damage
	(_impact_value_labels[&"blast_impulse"] as Label).text = "%.1f" % blast_impulse
