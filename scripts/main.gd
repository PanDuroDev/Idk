extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player_controller.gd")
const STRUCTURE_SCRIPT = preload("res://scripts/destructible_structure.gd")
const BLAST_SERVICE_SCRIPT = preload("res://scripts/blast_service.gd")
const TERRAIN_SCRIPT = preload("res://terrain/terrain_world.gd")
const BUILDING_DEFINITION_CATALOG = preload("res://resources/buildings/building_definition_catalog.tres")
const MATERIAL_PROFILE_CATALOG = preload("res://resources/materials/material_profile_catalog.tres")
const SIMULATION_CONFIGURATION_CODEC = preload("res://scripts/simulation_configuration_codec.gd")
const SimulationConfigurationScript = preload("res://scripts/simulation_configuration.gd")
const SimulationMaterialOverrideScript = preload("res://scripts/simulation_material_override.gd")
const WORLD_CATALOG = preload("res://resources/worlds/world_catalog.tres")
const WORLD_DEFINITION_VALIDATOR = preload("res://scripts/world_definition_validator.gd")
const WorldDefinitionScript = preload("res://scripts/world_definition.gd")
const SCENARIO_CATALOG = preload("res://resources/scenarios/scenario_catalog.tres")
const SCENARIO_CATALOG_SCRIPT = preload("res://scripts/scenario_catalog.gd")
const EXPERIMENT_HISTORY_SCRIPT = preload("res://scripts/experiment_history.gd")
const ExperimentScenarioScript = preload("res://scripts/experiment_scenario.gd")

const BLAST_DISTANCE: float = 70.0
const MAX_PENDING_BLASTS: int = 4
const MAX_ACTIVE_EFFECTS: int = 8
const EFFECT_LIFETIME: float = 0.55
const DEFAULT_GRAVITY: float = 9.8
const DEFAULT_WORLD_ID: StringName = &"classic_yard"
const MAX_RESIDENT_WORLDS: int = 1
const DEFAULT_BACKGROUND_COLOR: Color = Color(0.035, 0.045, 0.06)
const DEFAULT_AMBIENT_COLOR: Color = Color(0.55, 0.59, 0.68)
const DEFAULT_AMBIENT_ENERGY: float = 0.7
const DEFAULT_SUN_ROTATION: Vector3 = Vector3(-52.0, -28.0, 0.0)
const DEFAULT_SUN_ENERGY: float = 1.25

@export_range(0.5, 12.0, 0.25) var blast_radius: float = 4.5
@export_range(1.0, 100.0, 1.0) var blast_impulse: float = 22.0
@export_range(0.0, 1.0, 0.05) var blast_upward_bias: float = 0.3
@export_range(0.1, 10.0, 0.1) var blast_damage: float = 4.0

var _structure: Node3D
var _terrain: Node3D
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
var _debug_overlay_panel: PanelContainer
var _debug_overlay_label: Label
var _debug_overlay_visible: bool = false
var _active_effects: Array[Node3D] = []
var _headless_effect_burst_count: int = 0
var _active_simulation_configuration: SimulationConfigurationScript
var _simulation_gravity: float = DEFAULT_GRAVITY
var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _active_world_definition: WorldDefinitionScript
var _world_load_count: int = 0
var _world_unload_count: int = 0
var _experiment_history = EXPERIMENT_HISTORY_SCRIPT.new()
var _active_scenario: ExperimentScenarioScript
var _scenario_option: OptionButton
var _world_option: OptionButton
var _simulation_status_label: Label
var _gravity_value_label: Label
var _time_scale_value_label: Label
var _material_option: OptionButton
var _pause_button: Button
var _material_override_id: StringName = &""
var _camera_option: OptionButton
var _orbit_camera: Camera3D
var _overview_camera: Camera3D
var _camera_mode: StringName = &"first_person"
var _orbit_angle: float = 0.0

const CAMERA_MODES: Array[StringName] = [&"first_person", &"orbit", &"overview"]

const DEFAULT_BLAST_RADIUS: float = 4.5
const DEFAULT_BLAST_DAMAGE: float = 4.0
const DEFAULT_BLAST_IMPULSE: float = 22.0


func _ready() -> void:
	_blast_service = BLAST_SERVICE_SCRIPT.new()
	_build_environment()
	_build_ground()

	_spawn_physics_props()

	_player = PLAYER_SCRIPT.new()
	_player.position = Vector3(0.0, 0.1, 6.0)
	add_child(_player)
	_player.blast_requested.connect(request_blast)
	_build_cameras()

	_build_hud()
	_build_simulation_panel()
	_build_debug_overlay()
	var load_errors: Array[String] = load_world(DEFAULT_WORLD_ID)
	if not load_errors.is_empty():
		push_error("Could not load default world: %s" % "\n".join(load_errors))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		toggle_simulation_paused()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		toggle_debug_overlay()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		cycle_camera_mode()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("reset_structure"):
		request_structure_reset()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _reset_requested:
		if is_instance_valid(_structure):
			_structure.call("reset_structure")
		if is_instance_valid(_terrain):
			_terrain.call("reset_terrain")
		_reset_player_to_spawn(_get_active_spawn())
		_reset_requested = false
		_last_broken_count = 0
		_last_affected_count = 0

	while not _pending_blasts.is_empty():
		var request: Dictionary = _pending_blasts.pop_front()
		_process_blast(request["origin"], request["direction"])


func _process(delta: float) -> void:
	_update_orbit_camera(delta)
	_hud_refresh_timer += delta
	if _hud_refresh_timer < 0.25 or not is_instance_valid(_hud_label):
		return
	_hud_refresh_timer = 0.0
	var fragment_total: int = int(_structure.call("get_fragment_count")) if is_instance_valid(_structure) else 0
	var fragment_released: int = int(_structure.call("get_released_fragment_count")) if is_instance_valid(_structure) else 0
	var fragment_broken: int = int(_structure.call("get_broken_fragment_count")) if is_instance_valid(_structure) else 0
	var fragment_unsupported: int = int(_structure.call("get_unsupported_fragment_count")) if is_instance_valid(_structure) else 0
	var terrain_edits: int = int(_terrain.call("get_terrain_edit_count")) if is_instance_valid(_terrain) else 0
	var world_name: String = _active_world_definition.display_name if _active_world_definition != null else "none"
	_hud_label.text = "WORLDBREAK [%s]  |  FPS %d  |  Loose %d/%d  |  Broken %d (+%d)  |  Unsupported %d  |  Targets %d  |  Terrain %d" % [
		world_name,
		Engine.get_frames_per_second(),
		fragment_released,
		fragment_total,
		fragment_broken,
		_last_broken_count,
		fragment_unsupported,
		_last_affected_count,
		terrain_edits
	]
	_refresh_impact_controls()
	_refresh_debug_overlay()


func request_blast(ray_origin: Vector3, ray_direction: Vector3) -> void:
	if _pending_blasts.size() >= MAX_PENDING_BLASTS or ray_direction.is_zero_approx():
		return
	_pending_blasts.append({
		"origin": ray_origin,
		"direction": ray_direction.normalized()
	})


func request_structure_reset() -> void:
	_reset_requested = true


func request_world_reset() -> void:
	_reset_requested = true


func get_building_definition_catalog() -> Resource:
	return BUILDING_DEFINITION_CATALOG


func get_material_profile_catalog() -> Resource:
	return MATERIAL_PROFILE_CATALOG


func get_active_simulation_configuration() -> SimulationConfigurationScript:
	return _active_simulation_configuration


func get_world_catalog() -> Resource:
	return WORLD_CATALOG


func get_world_ids() -> Array[StringName]:
	return WORLD_CATALOG.get_world_ids()


func get_active_world_definition() -> WorldDefinitionScript:
	return _active_world_definition


func get_resident_world_count() -> int:
	return 1 if _active_world_definition != null else 0


func get_max_resident_worlds() -> int:
	return MAX_RESIDENT_WORLDS


func get_world_load_count() -> int:
	return _world_load_count


func get_world_unload_count() -> int:
	return _world_unload_count


func load_world(world_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	var world: WorldDefinitionScript = WORLD_CATALOG.get_world_by_id(world_id)
	if world == null:
		errors.append("Unknown world ID '%s'." % String(world_id))
		return errors
	var validation: Dictionary = WORLD_DEFINITION_VALIDATOR.validate_definition(
		world,
		BUILDING_DEFINITION_CATALOG,
		MATERIAL_PROFILE_CATALOG
	)
	if not validation["ok"]:
		errors.assign(validation["errors"])
		return errors

	var apply_errors: Array[String] = apply_simulation_configuration(validation["configuration"])
	if not apply_errors.is_empty():
		errors.assign(apply_errors)
		return errors

	_apply_world_environment(world)
	_build_terrain(world)
	_active_world_definition = world
	_reset_player_to_spawn(world.player_spawn)
	_world_load_count += 1
	_refresh_simulation_controls()
	return errors


func unload_world() -> void:
	_clear_structure()
	_remove_terrain()
	_apply_environment_defaults()
	_active_world_definition = null
	_active_simulation_configuration = null
	_material_override_id = &""
	Engine.time_scale = 1.0
	set_simulation_gravity(DEFAULT_GRAVITY)
	_reset_player_to_spawn(Vector3(0.0, 0.1, 6.0))
	_reset_requested = false
	_pending_blasts.clear()
	_last_broken_count = 0
	_last_affected_count = 0
	_world_unload_count += 1
	_refresh_simulation_controls()


func get_scenario_catalog() -> ScenarioCatalog:
	return SCENARIO_CATALOG


func get_scenario_ids() -> Array[StringName]:
	return SCENARIO_CATALOG.get_scenario_ids()


func get_active_scenario() -> ExperimentScenarioScript:
	return _active_scenario


func get_experiment_history() -> ExperimentHistory:
	return _experiment_history


func get_last_run() -> Dictionary:
	return _experiment_history.get_last_run()


func get_run_comparison() -> Dictionary:
	return _experiment_history.get_comparison()


func get_simulation_time_scale() -> float:
	return Engine.time_scale


func get_camera_modes() -> Array[StringName]:
	return CAMERA_MODES.duplicate()


func get_camera_mode() -> StringName:
	return _camera_mode


func set_camera_mode(mode: StringName) -> bool:
	if not CAMERA_MODES.has(mode):
		return false
	_camera_mode = mode
	_apply_camera_mode()
	_refresh_simulation_controls()
	return true


func cycle_camera_mode() -> StringName:
	set_camera_mode(CAMERA_MODES[(CAMERA_MODES.find(_camera_mode) + 1) % CAMERA_MODES.size()])
	return _camera_mode


func _apply_camera_mode() -> void:
	if is_instance_valid(_player):
		var player_camera: Camera3D = _player.call("get_camera")
		if is_instance_valid(player_camera):
			player_camera.current = _camera_mode == &"first_person"
	var anchor: Vector3 = _get_camera_anchor()
	if is_instance_valid(_orbit_camera):
		_orbit_camera.position = anchor + Vector3(cos(_orbit_angle) * 22.0, 12.0, sin(_orbit_angle) * 22.0)
		_orbit_camera.look_at(anchor + Vector3(0.0, 2.0, 0.0))
		_orbit_camera.current = _camera_mode == &"orbit"
	if is_instance_valid(_overview_camera):
		_overview_camera.position = anchor + Vector3(0.0, 42.0, 0.1)
		_overview_camera.look_at(anchor)
		_overview_camera.current = _camera_mode == &"overview"


func _build_cameras() -> void:
	_orbit_camera = Camera3D.new()
	_orbit_camera.name = "OrbitCamera"
	_orbit_camera.fov = 62.0
	add_child(_orbit_camera)
	_overview_camera = Camera3D.new()
	_overview_camera.name = "OverviewCamera"
	_overview_camera.fov = 55.0
	add_child(_overview_camera)
	_apply_camera_mode()


func _update_orbit_camera(delta: float) -> void:
	if _camera_mode != &"orbit" or not is_instance_valid(_orbit_camera):
		return
	_orbit_angle += delta * 0.25
	var anchor: Vector3 = _get_camera_anchor()
	_orbit_camera.position = anchor + Vector3(cos(_orbit_angle) * 22.0, 12.0, sin(_orbit_angle) * 22.0)
	_orbit_camera.look_at(anchor + Vector3(0.0, 2.0, 0.0))


func _get_camera_anchor() -> Vector3:
	if is_instance_valid(_structure):
		return _structure.global_position
	return Vector3(0.0, 1.0, -12.0)


func load_scenario(scenario_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	var scenario: ExperimentScenarioScript = SCENARIO_CATALOG.get_scenario_by_id(scenario_id)
	if scenario == null:
		errors.append("Unknown scenario ID '%s'." % String(scenario_id))
		return errors
	errors.assign(SCENARIO_CATALOG_SCRIPT.validate_definition(scenario, WORLD_CATALOG))
	if not errors.is_empty():
		return errors

	var world_errors: Array[String] = load_world(scenario.world_id)
	if not world_errors.is_empty():
		errors.assign(world_errors)
		return errors

	blast_radius = scenario.blast_radius
	blast_damage = scenario.blast_damage
	blast_impulse = scenario.blast_impulse
	blast_upward_bias = scenario.blast_upward_bias
	set_simulation_gravity(scenario.gravity)
	Engine.time_scale = clampf(scenario.time_scale, 0.05, 10.0)
	_active_scenario = scenario
	_refresh_impact_controls()
	_refresh_simulation_controls()
	return errors


func run_scenario(scenario_id: StringName) -> Dictionary:
	var prepared: Dictionary = _prepare_scenario_run(scenario_id)
	if not prepared["ok"]:
		return {"ok": false, "errors": prepared["errors"], "run": {}}
	var metrics: Dictionary = _apply_scenario_impact(prepared["scenario"], prepared["impact"])
	metrics["active_loose"] = _get_active_loose_count()
	metrics["sleeping_loose"] = _get_sleeping_loose_count()
	metrics["moved_fragments"] = 0
	var run: Dictionary = _record_run(prepared["scenario"], prepared["impact"], metrics, {})
	return {"ok": true, "errors": prepared["errors"], "run": run}


func run_scenario_settled(scenario_id: StringName, settle_frames: int = 120) -> Dictionary:
	var prepared: Dictionary = _prepare_scenario_run(scenario_id)
	if not prepared["ok"]:
		await get_tree().process_frame
		return {"ok": false, "errors": prepared["errors"], "run": {}}
	var scenario: ExperimentScenarioScript = prepared["scenario"]
	var impact: Vector3 = prepared["impact"]
	var snapshot: Dictionary = _capture_fragment_positions()
	await _launch_rocket(impact, scenario.blast_radius)
	var started_usec: int = Time.get_ticks_usec()
	var metrics: Dictionary = _apply_scenario_impact(scenario, impact)
	var frames: int = clampi(settle_frames, 1, 600)
	for _frame in range(frames):
		await get_tree().physics_frame
		if not is_inside_tree():
			return {"ok": false, "errors": ["Scene left the tree during settle."], "run": {}}
	metrics["elapsed_usec"] = Time.get_ticks_usec() - started_usec
	metrics["active_loose"] = _get_active_loose_count()
	metrics["sleeping_loose"] = _get_sleeping_loose_count()
	metrics["moved_fragments"] = _count_moved_fragments(snapshot)
	var run: Dictionary = _record_run(
		scenario,
		impact,
		metrics,
		{"settled": true, "settle_frames": frames}
	)
	return {"ok": true, "errors": prepared["errors"], "run": run}


func _prepare_scenario_run(scenario_id: StringName) -> Dictionary:
	var errors: Array[String] = load_scenario(scenario_id)
	if not errors.is_empty():
		_set_status("SCENARIO FAILED\n" + "\n".join(errors))
		return {"ok": false, "errors": errors, "scenario": null, "impact": Vector3.ZERO}
	set_simulation_paused(false)
	var scenario: ExperimentScenarioScript = _active_scenario
	var target: Node3D = _structure if scenario.target_kind == &"structure" else _terrain
	if not is_instance_valid(target):
		var missing: Array[String] = ["Scenario target '%s' is not resident." % String(scenario.target_kind)]
		_set_status("SCENARIO FAILED\n" + "\n".join(missing))
		return {"ok": false, "errors": missing, "scenario": null, "impact": Vector3.ZERO}

	# Reset through the existing sync paths so the run starts from the same state.
	if is_instance_valid(_structure):
		_structure.call("reset_structure")
	if is_instance_valid(_terrain):
		_terrain.call("reset_terrain")
	_reset_player_to_spawn(_get_active_spawn())
	_reset_requested = false
	_pending_blasts.clear()
	_last_broken_count = 0
	_last_affected_count = 0
	return {
		"ok": true,
		"errors": errors,
		"scenario": scenario,
		"impact": target.global_position + scenario.impact_offset
	}


func _apply_scenario_impact(scenario: ExperimentScenarioScript, impact: Vector3) -> Dictionary:
	var started_usec: int = Time.get_ticks_usec()
	var broken: int = 0
	var released: int = 0
	var terrain_edits: int = 0
	if scenario.target_kind == &"structure":
		broken = int(_structure.call("apply_blast_damage", impact, scenario.blast_radius, scenario.blast_damage))
		released = int(_structure.call("get_released_fragment_count"))
	else:
		_terrain.call("carve_sphere", impact, scenario.blast_radius, scenario.blast_damage)
		terrain_edits = int(_terrain.call("get_terrain_edit_count"))
	var elapsed_usec: int = Time.get_ticks_usec() - started_usec

	_blast_service.call(
		"apply_radial_impulse",
		get_world_3d().direct_space_state,
		impact,
		scenario.blast_radius,
		scenario.blast_impulse,
		scenario.blast_upward_bias
	)
	_total_impacts += 1
	_spawn_blast_flash(impact)
	return {
		"broken": broken,
		"released": released,
		"terrain_edits": terrain_edits,
		"elapsed_usec": elapsed_usec
	}


func _record_run(
	scenario: ExperimentScenarioScript,
	impact: Vector3,
	metrics: Dictionary,
	extra: Dictionary
) -> Dictionary:
	var building_id: StringName = &""
	var material_ids: Array[String] = []
	if is_instance_valid(_structure):
		building_id = _structure.call("get_building_definition_id")
		var definition = _structure.call("get_building_definition")
		if definition != null:
			for cell in definition.cells:
				var material_id: String = String(_structure.call("get_cell_material_id", cell.coordinate))
				if not material_id.is_empty() and not material_ids.has(material_id):
					material_ids.append(material_id)
	var run: Dictionary = _experiment_history.add_run({
		"scenario_id": String(scenario.scenario_id),
		"world_id": String(scenario.world_id),
		"target_kind": String(scenario.target_kind),
		"building_definition_id": String(building_id),
		"material_override_id": String(_material_override_id),
		"material_profile_ids": material_ids,
		"impact": {
			"position": [impact.x, impact.y, impact.z],
			"radius": scenario.blast_radius,
			"damage": scenario.blast_damage,
			"impulse": scenario.blast_impulse,
			"upward_bias": scenario.blast_upward_bias
		},
		"gravity": _simulation_gravity,
		"time_scale": Engine.time_scale,
		"broken": int(metrics.get("broken", 0)),
		"released": int(metrics.get("released", 0)),
		"active_loose": int(metrics.get("active_loose", 0)),
		"sleeping_loose": int(metrics.get("sleeping_loose", 0)),
		"moved_fragments": int(metrics.get("moved_fragments", 0)),
		"settled": bool(extra.get("settled", false)),
		"settle_frames": int(extra.get("settle_frames", 0)),
		"terrain_edits": int(metrics.get("terrain_edits", 0)),
		"elapsed_usec": int(metrics.get("elapsed_usec", 0)),
		"fps_sample": Engine.get_frames_per_second()
	})
	_last_broken_count = int(metrics.get("broken", 0))
	_last_affected_count = int(metrics.get("released", 0))
	_set_status(_format_run_summary(run))
	_refresh_simulation_controls()
	return run


func _get_active_loose_count() -> int:
	if not is_instance_valid(_structure):
		return 0
	return int(_structure.call("get_active_loose_fragment_count"))


func _get_sleeping_loose_count() -> int:
	if not is_instance_valid(_structure):
		return 0
	return int(_structure.call("get_sleeping_loose_fragment_count"))


func _capture_fragment_positions() -> Dictionary:
	var positions: Dictionary = {}
	if not is_instance_valid(_structure):
		return positions
	for child in _structure.get_children():
		var body := child as RigidBody3D
		if body != null:
			positions[body.get_instance_id()] = body.global_position
	return positions


func _count_moved_fragments(snapshot: Dictionary) -> int:
	if snapshot.is_empty() or not is_instance_valid(_structure):
		return 0
	var moved: int = 0
	for child in _structure.get_children():
		var body := child as RigidBody3D
		if body == null:
			continue
		var previous: Variant = snapshot.get(body.get_instance_id())
		if previous == null:
			continue
		if body.global_position.distance_to(previous) > 0.05:
			moved += 1
	return moved


func reset_simulation() -> void:
	set_simulation_paused(false)
	request_world_reset()


func export_experiment_history(path: String) -> Dictionary:
	var lower_path: String = path.to_lower()
	if lower_path.ends_with(".json"):
		return _experiment_history.save_json(path)
	if lower_path.ends_with(".csv"):
		return _experiment_history.save_csv(path)
	return {"ok": false, "errors": ["Experiment exports must use the .json or .csv extension."]}


func adjust_simulation_setting(setting: StringName, amount: float) -> void:
	match setting:
		&"gravity":
			set_simulation_gravity(_simulation_gravity + amount)
		&"time_scale":
			Engine.time_scale = clampf(Engine.time_scale + amount, 0.05, 10.0)
		_:
			return
	_refresh_simulation_controls()


func _format_run_summary(run: Dictionary) -> String:
	var comparison: Dictionary = _experiment_history.get_comparison()
	var summary: String = "RUN %d  %s\nbroken %d | loose %d | terrain %d | %.2f ms" % [
		int(run.get("run_index", 0)),
		String(run.get("scenario_id", "")),
		int(run.get("broken", 0)),
		int(run.get("released", 0)),
		int(run.get("terrain_edits", 0)),
		float(run.get("elapsed_usec", 0)) / 1000.0
	]
	if comparison["has_comparison"]:
		summary += "\nvs run %d: broken %+d | moved %+d | time %+d us" % [
			int(comparison["previous_run_index"]),
			int(comparison["broken_delta"]),
			int(comparison.get("moved_fragments_delta", 0)),
			int(comparison["elapsed_usec_delta"])
		]
	if bool(run.get("settled", false)):
		summary += "\nsettled %d frames | awake %d | asleep %d | moved %d" % [
			int(run.get("settle_frames", 0)),
			int(run.get("active_loose", 0)),
			int(run.get("sleeping_loose", 0)),
			int(run.get("moved_fragments", 0))
		]
	return summary


func _set_status(text: String) -> void:
	if is_instance_valid(_simulation_status_label):
		_simulation_status_label.text = text


func apply_simulation_configuration(configuration: SimulationConfigurationScript) -> Array[String]:
	var errors: Array[String] = []
	if configuration == null:
		errors.append("Simulation configuration is null.")
		return errors
	var validation: Dictionary = SIMULATION_CONFIGURATION_CODEC.validate_configuration(
		configuration,
		BUILDING_DEFINITION_CATALOG,
		MATERIAL_PROFILE_CATALOG
	)
	if not validation["ok"]:
		errors.assign(validation["errors"])
		return errors
	if not is_instance_valid(_structure):
		_create_structure()

	var definition = BUILDING_DEFINITION_CATALOG.get_definition_by_id(configuration.building_definition_id)
	if definition == null:
		errors.append("Unknown building definition ID '%s'." % String(configuration.building_definition_id))
		return errors
	var material_overrides: Dictionary = {}
	for override in configuration.material_overrides:
		var profile = MATERIAL_PROFILE_CATALOG.get_profile_by_id(override.material_id)
		if profile == null:
			errors.append("Unknown material profile ID '%s'." % String(override.material_id))
			return errors
		material_overrides[override.cell] = profile
	if not errors.is_empty():
		return errors

	var rebuild_errors: Array = _structure.call("configure_definition", definition, material_overrides)
	if not rebuild_errors.is_empty():
		errors.assign(rebuild_errors)
		return errors

	_structure.transform = configuration.building_transform
	blast_radius = configuration.blast_radius
	blast_damage = configuration.blast_damage
	blast_impulse = configuration.blast_impulse
	blast_upward_bias = configuration.blast_upward_bias
	set_simulation_gravity(configuration.gravity)
	Engine.time_scale = configuration.time_scale
	_active_simulation_configuration = configuration
	_material_override_id = &""
	_reset_requested = false
	_last_broken_count = 0
	_last_affected_count = 0
	_refresh_impact_controls()
	_refresh_simulation_controls()
	return errors


func set_simulation_gravity(value: float) -> void:
	_simulation_gravity = clampf(value, 0.0, 50.0)
	var gravity_scale: float = _simulation_gravity / DEFAULT_GRAVITY
	for node in get_tree().get_nodes_in_group("blastable"):
		var body := node as RigidBody3D
		if body != null:
			body.gravity_scale = gravity_scale


func get_simulation_gravity() -> float:
	return _simulation_gravity


func set_simulation_paused(paused: bool) -> void:
	get_tree().paused = paused
	_refresh_simulation_controls()


func is_simulation_paused() -> bool:
	return get_tree().paused


func toggle_simulation_paused() -> void:
	set_simulation_paused(not is_simulation_paused())


func get_material_profile_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for profile in MATERIAL_PROFILE_CATALOG.profiles:
		if profile != null:
			ids.append(profile.material_id)
	return ids


func get_active_material_override_id() -> StringName:
	return _material_override_id


func select_material_profile(material_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	if not is_instance_valid(_structure):
		errors.append("No resident structure to apply a material profile.")
		return errors
	var definition = _structure.call("get_building_definition")
	if definition == null:
		errors.append("Active structure has no building definition.")
		return errors
	var overrides: Dictionary = {}
	var configuration_overrides: Array[SimulationMaterialOverrideScript] = []
	if material_id != &"":
		var profile = MATERIAL_PROFILE_CATALOG.get_profile_by_id(material_id)
		if profile == null:
			errors.append("Unknown material profile ID '%s'." % String(material_id))
			return errors
		for cell in definition.cells:
			overrides[cell.coordinate] = profile
			var configuration_override := SimulationMaterialOverrideScript.new()
			configuration_override.cell = cell.coordinate
			configuration_override.material_id = material_id
			configuration_overrides.append(configuration_override)
	var rebuild_errors: Array = _structure.call("configure_definition", definition, overrides)
	if not rebuild_errors.is_empty():
		errors.assign(rebuild_errors)
		return errors
	_material_override_id = material_id
	if _active_simulation_configuration != null:
		var updated: SimulationConfigurationScript = _active_simulation_configuration.duplicate(true) as SimulationConfigurationScript
		updated.material_overrides = configuration_overrides
		_active_simulation_configuration = updated
	_refresh_simulation_controls()
	return errors


func save_simulation_configuration(path: String) -> Dictionary:
	if _active_simulation_configuration == null:
		var missing: Array[String] = ["No active simulation configuration to save."]
		var no_warnings: Array[String] = []
		return {"ok": false, "errors": missing, "warnings": no_warnings}
	return SIMULATION_CONFIGURATION_CODEC.save_to_file(
		_active_simulation_configuration,
		path,
		BUILDING_DEFINITION_CATALOG,
		MATERIAL_PROFILE_CATALOG
	)


func load_simulation_configuration(path: String) -> Dictionary:
	var result: Dictionary = SIMULATION_CONFIGURATION_CODEC.load_from_file(
		path,
		BUILDING_DEFINITION_CATALOG,
		MATERIAL_PROFILE_CATALOG
	)
	result["applied"] = false
	var apply_errors: Array[String] = []
	result["apply_errors"] = apply_errors
	if not result["ok"]:
		return result
	apply_errors = apply_simulation_configuration(result["configuration"])
	result["apply_errors"] = apply_errors
	result["applied"] = apply_errors.is_empty()
	return result


func _process_blast(ray_origin: Vector3, ray_direction: Vector3) -> void:
	var ray_end: Vector3 = ray_origin + ray_direction * BLAST_DISTANCE
	var ray_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1)
	if is_instance_valid(_player):
		ray_query.exclude = [_player.get_rid()]

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ray_hit: Dictionary = space_state.intersect_ray(ray_query)
	var impact_position: Vector3 = ray_hit.get("position", ray_end)

	if is_instance_valid(_terrain):
		_terrain.call("carve_sphere", impact_position, blast_radius, blast_damage)

	_last_broken_count = int(_structure.call("apply_blast_damage", impact_position, blast_radius, blast_damage)) if is_instance_valid(_structure) else 0
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
	_world_environment = WorldEnvironment.new()
	_world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = DEFAULT_BACKGROUND_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = DEFAULT_AMBIENT_COLOR
	environment.ambient_light_energy = DEFAULT_AMBIENT_ENERGY
	_world_environment.environment = environment
	add_child(_world_environment)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.rotation_degrees = DEFAULT_SUN_ROTATION
	_sun.light_energy = DEFAULT_SUN_ENERGY
	_sun.shadow_enabled = true
	add_child(_sun)


func _build_ground() -> void:
	# Low safety floor under the carveable terrain so debris that leaves the
	# resident patch still lands instead of falling forever.
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 1
	add_child(ground)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100.0, 1.0, 100.0)
	collision.shape = shape
	collision.position.y = -6.5
	ground.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -6.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.07, 0.08, 0.1)
	material.roughness = 0.95
	mesh.material = material
	ground.add_child(mesh_instance)


func _build_terrain(world: WorldDefinitionScript = null) -> void:
	_remove_terrain()
	if world != null and not world.terrain_enabled:
		return
	_terrain = TERRAIN_SCRIPT.new()
	_terrain.name = "TerrainWorld"
	if world != null:
		_terrain.position = world.terrain_position
		_terrain.set("chunk_radius", world.terrain_chunk_radius)
		_terrain.set("surface_color", world.terrain_surface_color)
		_terrain.set("use_low_end_fallback", world.terrain_low_end_fallback)
	else:
		_terrain.position = Vector3(0.0, -1.0, 0.0)
	add_child(_terrain)


func _remove_terrain() -> void:
	if is_instance_valid(_terrain):
		remove_child(_terrain)
		_terrain.queue_free()
	_terrain = null


func _create_structure() -> void:
	if is_instance_valid(_structure):
		return
	_structure = STRUCTURE_SCRIPT.new()
	_structure.position = Vector3(0.0, 0.0, -12.0)
	add_child(_structure)


func _clear_structure() -> void:
	if is_instance_valid(_structure):
		remove_child(_structure)
		_structure.queue_free()
	_structure = null


func _apply_world_environment(world: WorldDefinitionScript) -> void:
	if is_instance_valid(_world_environment) and _world_environment.environment != null:
		_world_environment.environment.background_color = world.background_color
		_world_environment.environment.ambient_light_color = world.ambient_color
		_world_environment.environment.ambient_light_energy = world.ambient_energy
	if is_instance_valid(_sun):
		_sun.rotation_degrees = world.sun_rotation_degrees
		_sun.light_energy = world.sun_energy
		_sun.shadow_enabled = world.sun_shadows_enabled


func _apply_environment_defaults() -> void:
	if is_instance_valid(_world_environment) and _world_environment.environment != null:
		_world_environment.environment.background_color = DEFAULT_BACKGROUND_COLOR
		_world_environment.environment.ambient_light_color = DEFAULT_AMBIENT_COLOR
		_world_environment.environment.ambient_light_energy = DEFAULT_AMBIENT_ENERGY
	if is_instance_valid(_sun):
		_sun.rotation_degrees = DEFAULT_SUN_ROTATION
		_sun.light_energy = DEFAULT_SUN_ENERGY
		_sun.shadow_enabled = true


func _get_active_spawn() -> Vector3:
	return _active_world_definition.player_spawn if _active_world_definition != null else Vector3(0.0, 0.1, 6.0)


func _reset_player_to_spawn(spawn: Vector3) -> void:
	if not is_instance_valid(_player):
		return
	_player.global_position = spawn
	_player.velocity = Vector3.ZERO


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
		prop.gravity_scale = _simulation_gravity / DEFAULT_GRAVITY
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


func _launch_rocket(impact: Vector3, radius: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var rocket := _build_rocket(radius)
	add_child(rocket)
	rocket.global_position = impact + Vector3(0.0, 12.0, 20.0)
	rocket.look_at(impact)
	var flight: Tween = create_tween()
	flight.tween_property(rocket, "global_position", impact, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await flight.finished
	if is_instance_valid(rocket):
		rocket.queue_free()


func _build_rocket(radius: float) -> Node3D:
	var rocket := Node3D.new()
	rocket.name = "Rocket"
	rocket.scale = Vector3.ONE * clampf(radius / 4.5, 0.7, 1.6)
	var pivot := Node3D.new()
	pivot.rotation_degrees.x = -90.0
	rocket.add_child(pivot)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.62, 0.66, 0.7)
	metal.roughness = 0.35
	metal.metallic = 0.6
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.75, 0.2, 0.12)
	accent.roughness = 0.55

	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.16
	body_mesh.bottom_radius = 0.18
	body_mesh.height = 1.5
	body.mesh = body_mesh
	body.material_override = metal
	pivot.add_child(body)

	var nose := MeshInstance3D.new()
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 0.16
	nose_mesh.height = 0.5
	nose.mesh = nose_mesh
	nose.material_override = accent
	nose.position.y = 1.0
	pivot.add_child(nose)

	for index in range(3):
		var fin := MeshInstance3D.new()
		var fin_mesh := BoxMesh.new()
		fin_mesh.size = Vector3(0.05, 0.42, 0.3)
		fin.mesh = fin_mesh
		fin.material_override = accent
		fin.rotation.y = TAU * float(index) / 3.0
		fin.position = Vector3(cos(TAU * float(index) / 3.0) * 0.2, -0.62, sin(TAU * float(index) / 3.0) * 0.2)
		pivot.add_child(fin)

	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.16
	flame_mesh.height = 0.32
	flame.mesh = flame_mesh
	var flame_material := StandardMaterial3D.new()
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.albedo_color = Color(1.0, 0.7, 0.25, 0.85)
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0, 0.55, 0.15)
	flame_material.emission_energy_multiplier = 3.0
	flame.material_override = flame_material
	flame.position.y = -0.82
	pivot.add_child(flame)
	return rocket


func _spawn_blast_flash(position: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		_headless_effect_burst_count = mini(_headless_effect_burst_count + 1, MAX_ACTIVE_EFFECTS)
		return
	for index in range(_active_effects.size() - 1, -1, -1):
		if not is_instance_valid(_active_effects[index]):
			_active_effects.remove_at(index)
	if _active_effects.size() >= MAX_ACTIVE_EFFECTS:
		var oldest: Node3D = _active_effects.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var effect := Node3D.new()
	effect.name = "BlastEffect"
	add_child(effect)
	effect.global_position = position
	_active_effects.append(effect)

	# Hot core flash.
	var flash_material := StandardMaterial3D.new()
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.62, 0.2, 0.9)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.5, 0.12)
	flash_material.emission_energy_multiplier = 4.0
	var flash := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 2.0
	flash.mesh = sphere_mesh
	flash.material_override = flash_material
	flash.scale = Vector3.ONE * 0.25
	effect.add_child(flash)

	# Expanding ground shockwave ring.
	var shock_material := StandardMaterial3D.new()
	shock_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shock_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shock_material.albedo_color = Color(0.95, 0.86, 0.7, 0.75)
	shock_material.emission_enabled = true
	shock_material.emission = Color(1.0, 0.72, 0.35)
	shock_material.emission_energy_multiplier = 2.0
	var shock := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	shock.mesh = torus
	shock.material_override = shock_material
	shock.rotation_degrees.x = 90.0
	shock.position.y = 0.05
	shock.scale = Vector3.ONE * 0.4
	effect.add_child(shock)

	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.07
	dust_mesh.height = 0.14
	var dust_material := StandardMaterial3D.new()
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_material.albedo_color = Color(0.72, 0.62, 0.46, 0.78)
	dust_material.roughness = 1.0

	var directions: Array[Vector3] = [
		Vector3(1.0, 0.45, 0.0), Vector3(-1.0, 0.35, 0.2),
		Vector3(0.1, 0.8, 1.0), Vector3(-0.2, 0.55, -1.0),
		Vector3(0.7, 0.2, -0.8), Vector3(-0.8, 0.25, -0.5)
	]
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * blast_radius * 0.6, EFFECT_LIFETIME * 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_material, "albedo_color", Color(1.0, 0.62, 0.2, 0.0), EFFECT_LIFETIME)
	tween.tween_property(shock, "scale", Vector3.ONE * blast_radius * 1.6, EFFECT_LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(shock_material, "albedo_color", Color(0.95, 0.86, 0.7, 0.0), EFFECT_LIFETIME)
	for index in range(directions.size()):
		var dust := MeshInstance3D.new()
		dust.mesh = dust_mesh
		dust.material_override = dust_material
		dust.scale = Vector3.ONE * (0.65 + float(index % 3) * 0.2)
		effect.add_child(dust)
		var direction: Vector3 = directions[index].normalized()
		var travel: float = 0.45 + float(index % 3) * 0.18
		tween.tween_property(dust, "position", direction * travel, EFFECT_LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(dust, "scale", Vector3.ZERO, EFFECT_LIFETIME)
	tween.tween_property(dust_material, "albedo_color", Color(0.72, 0.62, 0.46, 0.0), EFFECT_LIFETIME)
	tween.finished.connect(_remove_effect.bind(effect))


func _remove_effect(effect: Node3D) -> void:
	_active_effects.erase(effect)
	if is_instance_valid(effect):
		effect.queue_free()


func get_active_effect_count() -> int:
	return _headless_effect_burst_count if DisplayServer.get_name() == "headless" else _active_effects.size()


func set_debug_overlay_enabled(enabled: bool) -> void:
	_debug_overlay_visible = enabled
	if is_instance_valid(_debug_overlay_panel):
		_debug_overlay_panel.visible = enabled
	_refresh_debug_overlay()


func toggle_debug_overlay() -> void:
	set_debug_overlay_enabled(not _debug_overlay_visible)


func _build_debug_overlay() -> void:
	_debug_overlay_panel = PanelContainer.new()
	_debug_overlay_panel.name = "DebugOverlay"
	_debug_overlay_panel.position = Vector2(18.0, 575.0)
	_debug_overlay_panel.custom_minimum_size = Vector2(390.0, 0.0)
	_debug_overlay_panel.visible = false
	_ui_canvas.add_child(_debug_overlay_panel)

	_debug_overlay_label = Label.new()
	_debug_overlay_label.add_theme_font_size_override("font_size", 13)
	_debug_overlay_label.add_theme_color_override("font_color", Color(0.82, 0.9, 0.98))
	_debug_overlay_panel.add_child(_debug_overlay_label)
	_refresh_debug_overlay()


func _refresh_debug_overlay() -> void:
	if not _debug_overlay_visible or not is_instance_valid(_debug_overlay_label) or DisplayServer.get_name() == "headless":
		return
	var total: int = int(_structure.call("get_fragment_count")) if is_instance_valid(_structure) else 0
	var broken: int = int(_structure.call("get_broken_fragment_count")) if is_instance_valid(_structure) else 0
	var supported: int = int(_structure.call("get_supported_fragment_count")) if is_instance_valid(_structure) else 0
	var loose: int = int(_structure.call("get_released_fragment_count")) if is_instance_valid(_structure) else 0
	var active: int = int(_structure.call("get_active_loose_fragment_count")) if is_instance_valid(_structure) else 0
	var sleeping: int = int(_structure.call("get_sleeping_loose_fragment_count")) if is_instance_valid(_structure) else 0
	var retired: int = int(_structure.call("get_retired_fragment_count")) if is_instance_valid(_structure) else 0
	var parked: int = int(_structure.call("get_budget_parked_fragment_count")) if is_instance_valid(_structure) else 0
	var active_budget: int = int(_structure.get("max_active_loose_fragments")) if is_instance_valid(_structure) else 0
	var lifetime: float = float(_structure.get("loose_debris_lifetime_seconds")) if is_instance_valid(_structure) else 0.0
	_debug_overlay_label.text = "DESTRUCTION / PHYSICS DEBUG (F3)\nFPS %d | Physics ticks %d\nIntact %d | Broken %d | Supported %d\nLoose %d | Awake %d/%d | Sleeping %d | Parked %d | Retired %d\nDebris lifetime %.0fs | Effect bursts %d/%d\nBlast radius %.2f | Damage %.2f | Impulse %.1f\nPhysics objects %d | Collision pairs %d" % [
		Engine.get_frames_per_second(),
		Engine.get_physics_ticks_per_second(),
		total - broken,
		broken,
		supported,
		loose,
		active,
		active_budget,
		sleeping,
		parked,
		retired,
		lifetime,
		_active_effects.size(),
		MAX_ACTIVE_EFFECTS,
		blast_radius,
		blast_damage,
		blast_impulse,
		int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
	]


func _build_hud() -> void:
	_ui_canvas = CanvasLayer.new()
	_ui_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
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


func _build_simulation_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "SimulationPanel"
	panel.position = Vector2(910.0, 54.0)
	panel.custom_minimum_size = Vector2(350.0, 0.0)
	_ui_canvas.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = "SIMULATION CONTROL"
	heading.add_theme_font_size_override("font_size", 14)
	layout.add_child(heading)

	_world_option = _add_option_row(layout, "World", WORLD_CATALOG.get_world_ids(), _on_world_selected)
	_scenario_option = _add_option_row(layout, "Scenario", SCENARIO_CATALOG.get_scenario_ids(), _on_scenario_selected)
	var material_ids: Array[StringName] = [&"default"]
	material_ids.append_array(get_material_profile_ids())
	_material_option = _add_option_row(layout, "Material", material_ids, _on_material_selected)
	_camera_option = _add_option_row(layout, "Camera", CAMERA_MODES, _on_camera_selected)

	_add_impact_control_row(layout, "Blast radius", &"blast_radius", 0.25)
	_add_impact_control_row(layout, "Damage", &"blast_damage", 0.25)
	_add_impact_control_row(layout, "Physical impulse", &"blast_impulse", 1.0)
	_gravity_value_label = _add_setting_control_row(layout, "Gravity", &"gravity", 0.5)
	_time_scale_value_label = _add_setting_control_row(layout, "Time scale", &"time_scale", 0.05)

	var action_row := HBoxContainer.new()
	layout.add_child(action_row)

	var run_button := Button.new()
	run_button.text = "Run scenario (settled)"
	run_button.tooltip_text = "Reset the world, apply the selected scenario, and record the outcome after 120 physics frames"
	run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_button.pressed.connect(_run_selected_scenario)
	action_row.add_child(run_button)

	_pause_button = Button.new()
	_pause_button.text = "Pause"
	_pause_button.tooltip_text = "Pause or resume physics without changing the experiment time scale (P)"
	_pause_button.pressed.connect(toggle_simulation_paused)
	action_row.add_child(_pause_button)

	var reset_button := Button.new()
	reset_button.text = "Reset world"
	reset_button.pressed.connect(reset_simulation)
	action_row.add_child(reset_button)

	var export_row := HBoxContainer.new()
	layout.add_child(export_row)

	var json_button := Button.new()
	json_button.text = "Export JSON"
	json_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	json_button.pressed.connect(_export_history.bind("user://experiment_runs.json"))
	export_row.add_child(json_button)

	var csv_button := Button.new()
	csv_button.text = "Export CSV"
	csv_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	csv_button.pressed.connect(_export_history.bind("user://experiment_runs.csv"))
	export_row.add_child(csv_button)

	_simulation_status_label = Label.new()
	_simulation_status_label.custom_minimum_size = Vector2(0.0, 52.0)
	_simulation_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_simulation_status_label.add_theme_font_size_override("font_size", 12)
	_simulation_status_label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.78))
	_simulation_status_label.text = "Select a world and scenario."
	layout.add_child(_simulation_status_label)

	_refresh_impact_controls()
	_refresh_simulation_controls()


func _add_option_row(
	parent: VBoxContainer,
	title: String,
	ids: Array[StringName],
	callback: Callable
) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size.x = 142.0
	row.add_child(name_label)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in range(ids.size()):
		option.add_item(String(ids[index]))
		option.set_item_metadata(index, ids[index])
	option.item_selected.connect(callback)
	row.add_child(option)
	return option


func _add_setting_control_row(
	parent: VBoxContainer,
	title: String,
	setting: StringName,
	step: float
) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size.x = 142.0
	row.add_child(name_label)

	var decrease_button := Button.new()
	decrease_button.text = "−"
	decrease_button.custom_minimum_size.x = 34.0
	decrease_button.pressed.connect(adjust_simulation_setting.bind(setting, -step))
	row.add_child(decrease_button)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 62.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)

	var increase_button := Button.new()
	increase_button.text = "+"
	increase_button.custom_minimum_size.x = 34.0
	increase_button.pressed.connect(adjust_simulation_setting.bind(setting, step))
	row.add_child(increase_button)
	return value_label


func _on_world_selected(index: int) -> void:
	var world_id: StringName = _world_option.get_item_metadata(index)
	var errors: Array[String] = load_world(world_id)
	if errors.is_empty():
		_set_status("World loaded: %s" % String(world_id))
	else:
		_set_status("WORLD FAILED\n" + "\n".join(errors))
	_refresh_simulation_controls()


func _on_scenario_selected(index: int) -> void:
	var scenario_id: StringName = _scenario_option.get_item_metadata(index)
	var errors: Array[String] = load_scenario(scenario_id)
	if errors.is_empty():
		_set_status("Scenario ready: %s\nPress Run scenario." % String(scenario_id))
	else:
		_set_status("SCENARIO FAILED\n" + "\n".join(errors))


func _on_material_selected(index: int) -> void:
	var material_id: StringName = _material_option.get_item_metadata(index)
	var errors: Array[String] = select_material_profile(&"" if material_id == &"default" else material_id)
	if errors.is_empty():
		_set_status("Material applied: %s" % String(material_id))
	else:
		_set_status("MATERIAL FAILED\n" + "\n".join(errors))
	_refresh_simulation_controls()


func _on_camera_selected(index: int) -> void:
	if set_camera_mode(_camera_option.get_item_metadata(index)):
		_set_status("Camera: %s (C cycles)" % String(_camera_mode))


func _run_selected_scenario() -> void:
	if not is_instance_valid(_scenario_option) or _scenario_option.selected < 0:
		return
	_set_status("Running scenario...")
	await run_scenario_settled(_scenario_option.get_item_metadata(_scenario_option.selected))


func _export_history(path: String) -> void:
	var result: Dictionary = export_experiment_history(path)
	if result["ok"]:
		_set_status("Exported %d runs to %s" % [_experiment_history.get_run_count(), path])
	else:
		_set_status("EXPORT FAILED\n" + "\n".join(result["errors"]))


func _refresh_simulation_controls() -> void:
	if is_instance_valid(_gravity_value_label):
		_gravity_value_label.text = "%.1f" % _simulation_gravity
	if is_instance_valid(_time_scale_value_label):
		_time_scale_value_label.text = "%.2f" % Engine.time_scale
	if is_instance_valid(_pause_button):
		_pause_button.text = "Resume" if is_simulation_paused() else "Pause"
	_select_option(
		_world_option,
		_active_world_definition.world_id if _active_world_definition != null else &""
	)
	_select_option(
		_scenario_option,
		_active_scenario.scenario_id if _active_scenario != null else &""
	)
	_select_option(
		_material_option,
		_material_override_id if _material_override_id != &"" else &"default"
	)
	_select_option(_camera_option, _camera_mode)


func _select_option(option: OptionButton, option_id: StringName) -> void:
	if not is_instance_valid(option):
		return
	for index in range(option.item_count):
		if option.get_item_metadata(index) == option_id:
			option.select(index)
			return


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
