extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SCENARIO_CATALOG: Resource = preload("res://resources/scenarios/scenario_catalog.tres")
const SCENARIO_CATALOG_SCRIPT = preload("res://scripts/scenario_catalog.gd")
const ExperimentScenarioScript = preload("res://scripts/experiment_scenario.gd")
const JSON_PATH: String = "user://phase5_runs.json"
const CSV_PATH: String = "user://phase5_runs.csv"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world_catalog: Resource = load("res://resources/worlds/world_catalog.tres")
	var catalog_errors: Array[String] = SCENARIO_CATALOG.validate_catalog(world_catalog)
	if not catalog_errors.is_empty():
		_fail("Scenario catalog is invalid: %s" % "\n".join(catalog_errors))
		return
	if SCENARIO_CATALOG.scenarios.size() != 3 or SCENARIO_CATALOG.get_scenario_ids().size() != 3:
		_fail("Expected three sample scenarios")
		return

	var invalid := ExperimentScenarioScript.new()
	invalid.scenario_id = &""
	invalid.display_name = ""
	invalid.world_id = &"missing_world"
	invalid.target_kind = &"nothing"
	invalid.blast_radius = 99.0
	invalid.gravity = -5.0
	if SCENARIO_CATALOG_SCRIPT.validate_definition(invalid, world_catalog).size() < 5:
		_fail("Malformed scenario was not rejected with all errors")
		return

	var main: Node = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame

	var panel: Node = main.find_child("SimulationPanel", true, false)
	if panel == null:
		_fail("Simulation control panel was not built")
		return
	if main.call("get_scenario_ids").size() != 3:
		_fail("Runtime scenario catalog is not exposed")
		return
	if main.call("get_material_profile_ids").size() != 3:
		_fail("Runtime material catalog is not exposed")
		return
	main.call("set_simulation_paused", true)
	if not bool(main.call("is_simulation_paused")):
		_fail("Simulation pause did not take effect")
		return
	main.call("set_simulation_paused", false)
	if bool(main.call("is_simulation_paused")):
		_fail("Simulation resume did not take effect")
		return

	var modes: Array = main.call("get_camera_modes")
	if modes.size() < 2 or String(main.call("get_camera_mode")) != "first_person":
		_fail("Camera modes were not exposed with a first-person default")
		return
	var cycled: StringName = main.call("cycle_camera_mode")
	if String(cycled) == "first_person" or String(main.call("get_camera_mode")) != String(cycled):
		_fail("Camera cycling did not switch the active mode")
		return
	if not bool(main.call("set_camera_mode", &"first_person")) or String(main.call("get_camera_mode")) != "first_person":
		_fail("Camera mode selection did not restore first person")
		return
	if bool(main.call("set_camera_mode", &"missing_mode")):
		_fail("Camera mode selection accepted an unknown mode")
		return

	main.call("set_camera_mode", &"orbit")
	var crosshair: Label = main.get("_crosshair") as Label
	if crosshair == null or crosshair.visible:
		_fail("Leaving first person did not hide the crosshair")
		return
	main.call("set_camera_mode", &"first_person")
	if not crosshair.visible:
		_fail("First person did not restore the crosshair")
		return

	var ui_canvas: CanvasLayer = main.get("_ui_canvas") as CanvasLayer
	var hud_panel: PanelContainer = ui_canvas.get_node_or_null("HudPanel") as PanelContainer
	var simulation_panel: PanelContainer = ui_canvas.get_node_or_null("SimulationPanel") as PanelContainer
	if hud_panel == null or simulation_panel == null or hud_panel.theme == null or simulation_panel.theme == null:
		_fail("Themed HUD or simulation panel is missing")
		return
	var ui_theme: Theme = main.get("_ui_theme") as Theme
	if ui_theme == null or hud_panel.theme != ui_theme or simulation_panel.theme != ui_theme:
		_fail("HUD and simulation controls must share the central UI theme")
		return
	var panel_style: StyleBoxFlat = ui_theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	if panel_style == null or panel_style.corner_radius_top_left < 12 or panel_style.border_width_left < 1:
		_fail("Monochrome panels must use rounded corners and a visible border")
		return
	if panel_style.bg_color.r > 0.1 or panel_style.bg_color.g > 0.1 or panel_style.bg_color.b > 0.1:
		_fail("Panel surface is not using the near-black monochrome palette")
		return
	var button_normal: StyleBoxFlat = ui_theme.get_stylebox("normal", "Button") as StyleBoxFlat
	var button_hover: StyleBoxFlat = ui_theme.get_stylebox("hover", "Button") as StyleBoxFlat
	var button_pressed: StyleBoxFlat = ui_theme.get_stylebox("pressed", "Button") as StyleBoxFlat
	var button_focus: StyleBoxFlat = ui_theme.get_stylebox("focus", "Button") as StyleBoxFlat
	var button_disabled: StyleBoxFlat = ui_theme.get_stylebox("disabled", "Button") as StyleBoxFlat
	if button_normal == null or button_hover == null or button_pressed == null or button_focus == null or button_disabled == null:
		_fail("Buttons are missing one or more interaction states")
		return
	if button_normal.corner_radius_top_left < 7 or button_hover.border_color.r < 0.8:
		_fail("Button interaction styles do not match the rounded monochrome system")
		return
	var spawn_menu: PanelContainer = main.get("_spawn_menu") as PanelContainer
	if spawn_menu == null or spawn_menu.theme != ui_theme:
		_fail("Spawn menu is not using the shared monochrome theme")
		return
	var debug_panel: PanelContainer = main.get("_debug_overlay_panel") as PanelContainer
	if debug_panel == null or debug_panel.theme != ui_theme:
		_fail("Debug overlay is not using the shared monochrome theme")
		return
	var control_scroll: ScrollContainer = simulation_panel.find_child("ControlScroll", true, false) as ScrollContainer
	if control_scroll == null or control_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO:
		_fail("Simulation controls must remain reachable through vertical scrolling")
		return
	var key_hints: PanelContainer = ui_canvas.get_node_or_null("ControlHints") as PanelContainer
	if key_hints == null or key_hints.theme != ui_theme:
		_fail("HUD control hints are missing their shared bordered panel")
		return
	var primary_button: Button = simulation_panel.find_child("RunScenarioButton", true, false) as Button
	if primary_button == null:
		_fail("Primary scenario action is missing")
		return
	var primary_style: StyleBoxFlat = primary_button.get_theme_stylebox("normal") as StyleBoxFlat
	if primary_style == null or primary_style.bg_color.r < 0.8:
		_fail("Primary scenario action does not have the inverted white-button hierarchy")
		return

	var spawn_items: Array = main.call("get_spawn_items")
	if spawn_items.size() < 4:
		_fail("Sandbox spawn catalog is too small")
		return
	if int(main.call("get_spawned_prop_count")) < 2:
		_fail("Starter rockets were not placed on the ground")
		return
	var spawn_result: Dictionary = main.call("spawn_item", &"barrel")
	if not bool(spawn_result["ok"]) or spawn_result["prop"] == null:
		_fail("Sandbox barrel spawn failed")
		return
	if not bool(main.call("is_spawn_menu_open")) and not bool(main.call("toggle_spawn_menu")):
		_fail("Spawn menu did not open")
		return
	if bool(main.call("toggle_spawn_menu")):
		_fail("Spawn menu did not close")
		return
	if not bool(main.call("try_pickup")):
		_fail("Could not pick up the spawned barrel")
		return
	if main.call("get_held_prop") == null:
		_fail("Held prop was not tracked")
		return
	if not bool(main.call("throw_held_prop")) or main.call("get_held_prop") != null:
		_fail("Throwing the held prop failed")
		return
	var rocket_result: Dictionary = main.call("spawn_item", &"rocket")
	var rocket: RigidBody3D = rocket_result.get("prop") as RigidBody3D
	if rocket == null:
		_fail("Sandbox rocket spawn failed")
		return
	var props_before: int = int(main.call("get_spawned_prop_count"))
	main.call("_hold_prop", rocket)
	if not bool(main.call("throw_held_prop")) or not bool(rocket.get_meta("armed", false)):
		_fail("Throwing a rocket did not arm it")
		return

	# Exercise the real physics signal: the rocket must hit this static wall,
	# emit body_entered, remove itself, and pass through the shared detonation path.
	var collision_target := StaticBody3D.new()
	collision_target.name = "SandboxRocketCollisionTarget"
	collision_target.collision_layer = 1
	collision_target.collision_mask = 1
	collision_target.position = Vector3(24.0, 4.0, 24.0)
	var target_shape := CollisionShape3D.new()
	var target_box := BoxShape3D.new()
	target_box.size = Vector3(4.0, 4.0, 1.0)
	target_shape.shape = target_box
	collision_target.add_child(target_shape)
	main.add_child(collision_target)

	rocket.global_position = Vector3(24.0, 4.0, 29.0)
	rocket.gravity_scale = 0.0
	rocket.linear_velocity = Vector3(0.0, 0.0, -12.0)
	rocket.sleeping = false
	var impacts_before: int = int(main.get("_total_impacts"))
	for _frame in range(120):
		await physics_frame
		if int(main.call("get_spawned_prop_count")) < props_before and int(main.get("_total_impacts")) > impacts_before:
			break
	if int(main.call("get_spawned_prop_count")) >= props_before:
		_fail("Thrown rocket did not detonate through a real physics collision")
		return
	if int(main.get("_total_impacts")) != impacts_before + 1:
		_fail("Rocket collision did not invoke the shared detonation path")
		return
	var spawn_status: Label = main.get("_spawn_status_label") as Label
	if spawn_status == null or not spawn_status.text.contains(collision_target.name):
		_fail("Rocket did not report the actual collision target")
		return
	collision_target.queue_free()
	await physics_frame

	var load_errors: Array = main.call("load_scenario", &"foundation_strike")
	if not load_errors.is_empty():
		_fail("Foundation scenario load failed: %s" % "\n".join(load_errors))
		return
	var active_scenario: ExperimentScenarioScript = main.call("get_active_scenario")
	if active_scenario == null or active_scenario.scenario_id != &"foundation_strike":
		_fail("Scenario load did not select the requested scenario")
		return
	if absf(float(main.get("blast_damage")) - 10.0) > 0.001 or absf(float(main.call("get_simulation_gravity")) - 9.8) > 0.001:
		_fail("Scenario load did not apply its impact and gravity settings")
		return
	main.call("adjust_simulation_setting", &"gravity", 100.0)
	if absf(float(main.call("get_simulation_gravity")) - 50.0) > 0.001:
		_fail("Gravity control is not clamped")
		return
	main.call("adjust_simulation_setting", &"time_scale", 100.0)
	if absf(float(main.call("get_simulation_time_scale")) - 10.0) > 0.001:
		_fail("Time-scale control is not clamped")
		return
	load_errors = main.call("load_scenario", &"foundation_strike")
	if not load_errors.is_empty():
		_fail("Scenario reload after control clamping failed")
		return

	var material_ids: Array = main.call("get_material_profile_ids")
	var test_material: StringName = material_ids[0]
	var material_errors: Array = main.call("select_material_profile", test_material)
	if not material_errors.is_empty():
		_fail("Material selection failed: %s" % "\n".join(material_errors))
		return
	if main.call("get_active_material_override_id") != test_material:
		_fail("Material selection did not record the active override")
		return
	var structure_for_material: Node = main.get_node_or_null("DestructibleStructure")
	if structure_for_material == null:
		_fail("Material selection lost the resident structure")
		return
	var definition_for_material = structure_for_material.call("get_building_definition")
	if definition_for_material == null or definition_for_material.cells.is_empty():
		_fail("Material selection lost the building definition")
		return
	var material_cell: Vector3i = definition_for_material.cells[0].coordinate
	if String(structure_for_material.call("get_cell_material_id", material_cell)) != String(test_material):
		_fail("Material selection did not apply the profile to structure cells")
		return
	material_errors = main.call("select_material_profile", &"")
	if not material_errors.is_empty() or main.call("get_active_material_override_id") != &"":
		_fail("Material selection could not restore definition defaults")
		return

	var first: Dictionary = main.call("run_scenario", &"foundation_strike")
	if not first["ok"]:
		_fail("Foundation run failed: %s" % "\n".join(first["errors"]))
		return
	var first_run: Dictionary = first["run"]
	if int(first_run["broken"]) <= 0 or int(first_run["released"]) <= 0:
		_fail("Foundation run did not break structure fragments")
		return
	if String(first_run["world_id"]) != "classic_yard" or String(first_run["building_definition_id"]) != "classic_70_piece":
		_fail("Run record is missing its world or building metadata")
		return
	if not (first_run.get("material_profile_ids") is Array) or (first_run["material_profile_ids"] as Array).is_empty():
		_fail("Run record is missing material metadata")
		return
	if int(main.call("get_experiment_history").get_run_count()) != 1:
		_fail("Run was not recorded in history")
		return

	var second: Dictionary = main.call("run_scenario", &"foundation_strike")
	if not second["ok"]:
		_fail("Repeated foundation run failed")
		return
	if int(second["run"]["broken"]) != int(first_run["broken"]):
		_fail("Repeated scenario produced a different broken count")
		return
	var comparison: Dictionary = main.call("get_run_comparison")
	if not comparison["has_comparison"] or int(comparison["broken_delta"]) != 0:
		_fail("Run comparison did not report a repeatable broken count")
		return

	var settled: Dictionary = await main.call("run_scenario_settled", &"foundation_strike", 20)
	if not settled["ok"]:
		_fail("Settled foundation run failed: %s" % "\n".join(settled["errors"]))
		return
	var settled_run: Dictionary = settled["run"]
	if not bool(settled_run.get("settled", false)) or int(settled_run.get("settle_frames", 0)) != 20:
		_fail("Settled run did not record its bounded settle window")
		return
	if int(settled_run.get("broken", 0)) <= 0:
		_fail("Settled run did not break structure fragments")
		return
	if int(settled_run.get("active_loose", -1)) < 0 or int(settled_run.get("sleeping_loose", -1)) < 0 or int(settled_run.get("moved_fragments", -1)) < 0:
		_fail("Settled run did not capture post-impact physics state")
		return
	if int(main.call("get_experiment_history").get_run_count()) != 3:
		_fail("Settled run was not recorded in history")
		return

	var terrain_result: Dictionary = main.call("run_scenario", &"terrain_crater")
	if not terrain_result["ok"]:
		_fail("Terrain scenario run failed: %s" % "\n".join(terrain_result["errors"]))
		return
	if int(terrain_result["run"]["terrain_edits"]) <= 0 or int(terrain_result["run"]["broken"]) != 0:
		_fail("Terrain scenario did not carve terrain without structural damage")
		return

	var active_before_invalid: ExperimentScenarioScript = main.call("get_active_scenario")
	load_errors = main.call("load_scenario", &"missing_scenario")
	if load_errors.is_empty() or main.call("get_active_scenario") != active_before_invalid:
		_fail("Invalid scenario load was accepted or changed the active scenario")
		return
	# World switches must discard old props, then place exactly two starter
	# rockets around the new world's configured player spawn.
	var extra_prop: Dictionary = main.call("spawn_item", &"barrel")
	if not bool(extra_prop.get("ok", false)):
		_fail("Could not create a prop before switching worlds")
		return
	load_errors = main.call("load_scenario", &"sparse_beam_shear")
	if not load_errors.is_empty():
		_fail("Sparse scenario load failed: %s" % "\n".join(load_errors))
		return
	if String(main.call("get_active_world_definition").world_id) != "sparse_quarry":
		_fail("Sparse scenario did not switch to its world")
		return
	if int(main.call("get_spawned_prop_count")) != 2:
		_fail("World switch did not replace old props with two starter rockets")
		return
	var sparse_spawn: Vector3 = main.call("_get_active_spawn")
	var sparse_player: Node3D = main.get("_player") as Node3D
	if sparse_player == null or sparse_player.global_position.distance_to(sparse_spawn) > 0.01:
		_fail("World switch did not move the player to the selected world's spawn")
		return
	var starter_props: Array = main.get("_spawned_props")
	for starter_variant in starter_props:
		var starter: RigidBody3D = starter_variant as RigidBody3D
		if starter == null or not starter.name.begins_with("StarterRocket_"):
			_fail("World switch retained a non-starter prop")
			return
		if starter.global_position.distance_to(sparse_spawn) > 8.0:
			_fail("Starter rocket was not placed near the active world's spawn")
			return

	main.call("unload_world")
	if int(main.call("get_spawned_prop_count")) != 0 or int(main.call("get_resident_world_count")) != 0:
		_fail("World unload did not clear props and resident world state")
		return
	load_errors = main.call("load_world", &"classic_yard")
	if not load_errors.is_empty() or int(main.call("get_spawned_prop_count")) != 2:
		_fail("Reloading a world did not recreate its starter rockets")
		return

	main.call("reset_simulation")
	await physics_frame
	await process_frame
	await physics_frame
	var structure: Node = main.get_node_or_null("DestructibleStructure")
	var terrain: Node = main.get_node_or_null("TerrainWorld")
	if structure == null or terrain == null:
		_fail("Reset removed the active world nodes")
		return
	if not bool(structure.call("is_reset_to_initial_state")) or not bool(terrain.call("is_reset_to_initial_state")):
		_fail("Simulation reset did not restore structure and terrain")
		return

	var json_result: Dictionary = main.call("export_experiment_history", JSON_PATH)
	if not json_result["ok"]:
		_fail("JSON export failed: %s" % "\n".join(json_result["errors"]))
		return
	var json_text: String = FileAccess.get_file_as_string(JSON_PATH)
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary) or String(parsed.get("format", "")) != "worldbreak.experiment-history":
		_fail("JSON export did not contain the versioned history schema")
		return
	if (parsed.get("runs", []) as Array).size() != 4:
		_fail("JSON export did not include every recorded run")
		return

	var csv_result: Dictionary = main.call("export_experiment_history", CSV_PATH)
	if not csv_result["ok"]:
		_fail("CSV export failed: %s" % "\n".join(csv_result["errors"]))
		return
	var csv_lines: PackedStringArray = FileAccess.get_file_as_string(CSV_PATH).split("\n", false)
	if csv_lines.size() != 5 or not String(csv_lines[0]).begins_with("run_index,scenario_id,world_id"):
		_fail("CSV export did not contain a header and one row per run")
		return
	if not String(csv_lines[0]).contains("impact") or not String(csv_lines[0]).contains("material_profile_ids") or not String(csv_lines[0]).contains("settle_frames") or not String(csv_lines[4]).contains("terrain_crater"):
		_fail("CSV export is missing impact, material, settle, or scenario fields")
		return

	var bad_export: Dictionary = main.call("export_experiment_history", "user://phase5_runs.txt")
	if bad_export["ok"]:
		_fail("Export accepted an unsupported file extension")
		return

	var history: ExperimentHistory = main.call("get_experiment_history")
	for index in range(55):
		history.add_run({"scenario_id": "bounded_%d" % index})
	if history.get_run_count() != 50:
		_fail("Experiment history is not bounded to 50 runs")
		return
	if int(history.get_last_run()["run_index"]) != 50:
		_fail("Bounded history did not renumber run indexes")
		return

	var escaping_history := ExperimentHistory.new()
	escaping_history.add_run({
		"scenario_id": "comma,\"quote\"\nline",
		"material_profile_ids": ["a;b", "c,d"]
	})
	var escaping_csv: String = escaping_history.to_csv_text()
	if not escaping_csv.contains("\"comma,\"\"quote\"\"\nline\"") or not escaping_csv.contains("\"a;b;c,d\""):
		_fail("CSV export did not escape embedded commas, quotes, or newlines")
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(JSON_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CSV_PATH))
	print("WORLDBREAK_SIMULATION_TOOLS_OK: scenarios=3; run=passed; repeat=passed; settled=passed; comparison=passed; terrain=passed; reset=passed; export=passed; validation=passed")
	quit(0)


func _fail(message: String) -> void:
	push_error("WORLDBREAK_SIMULATION_TOOLS_FAILED: " + message)
	quit(1)
