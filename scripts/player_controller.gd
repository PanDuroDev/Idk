extends CharacterBody3D

signal blast_requested(ray_origin: Vector3, ray_direction: Vector3)

@export_range(1.0, 20.0, 0.5) var move_speed: float = 7.0
@export_range(1.0, 12.0, 0.5) var jump_velocity: float = 5.5
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity: float = 0.0022

var _camera: Camera3D
var _pitch: float = 0.0


func _ready() -> void:
	name = "Player"
	collision_layer = 1
	collision_mask = 1
	floor_max_angle = deg_to_rad(48.0)

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.position = Vector3(0.0, 1.62, 0.0)
	_camera.current = true
	add_child(_camera)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var move_direction: Vector3 = (global_transform.basis * local_direction).normalized()
	velocity.x = move_direction.x * move_speed
	velocity.z = move_direction.z * move_speed

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(
			_pitch - event.relative.y * mouse_sensitivity,
			deg_to_rad(-85.0),
			deg_to_rad(85.0)
		)
		_camera.rotation.x = _pitch

	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("trigger_impact"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_request_blast()
		get_viewport().set_input_as_handled()


func _request_blast() -> void:
	var ray_origin: Vector3 = _camera.global_position
	var ray_direction: Vector3 = -_camera.global_transform.basis.z.normalized()
	blast_requested.emit(ray_origin, ray_direction)


func get_camera() -> Camera3D:
	return _camera
