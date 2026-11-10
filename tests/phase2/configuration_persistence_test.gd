extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const CODEC = preload("res://scripts/simulation_configuration_codec.gd")
const CONFIGURATION = preload("res://scripts/simulation_configuration.gd")
const MATERIAL_OVERRIDE = preload("res://scripts/simulation_material_override.gd")
const BUILDING_CATALOG = preload("res://resources/buildings/building_definition_catalog.tres")
const MATERIAL_CATALOG = preload("res://resources/materials/material_profile_catalog.tres")

const TEST_DIRECTORY: String = "user://worldbreak_configuration_tests"
const SAMPLE_CLASSIC: String = "res://resources/configurations/classic_default.json"
const SAMPLE_SPARSE: String = "res://resources/configurations/sparse_pillar_beam_test.json"


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY))

	if not _test_catalogs():
		return
	if not _test_sample_configurations():
		return
	if not _test_defaults_and_warnings():
		return
	if not _test_invalid_inputs():
		return
	if not _test_file_round_trip():
		return
	if not _test_building_definition_round_trip():
		return
	if not await _test_live_application():
		return

	Engine.time_scale = 1.0
	print("WORLDBREAK_CONFIGURATION_PERSISTENCE_OK: catalogs, defaults, rejection, save/load, building round-trip, and live apply")
	quit(0)


func _test_catalogs() -> bool:
	var building_errors: Array[String] = BUILDING_CATALOG.validate_catalog()
	if not building_errors.is_empty():
		return _fail("Building catalog is invalid: %s" % [building_errors])
	if BUILDING_CATALOG.get_definition_by_id(&"classic_70_piece") == null:
		return _fail("Classic building definition is missing from the catalog")
	if BUILDING_CATALOG.get_definition_by_id(&"sparse_pillar_beam_11") == null:
		return _fail("Sparse building definition is missing from the catalog")
	var material_errors: Array[String] = MATERIAL_CATALOG.validate_catalog()
	if not material_errors.is_empty():
		return _fail("Material catalog is invalid: %s" % [material_errors])
	print("WORLDBREAK_CONFIG_CATALOG_OK")
	return true


func _test_sample_configurations() -> bool:
	var classic_result: Dictionary = CODEC.load_from_file(SAMPLE_CLASSIC, BUILDING_CATALOG, MATERIAL_CATALOG)
	if not classic_result["ok"]:
		return _fail("Classic sample did not load: %s" % [classic_result["errors"]])
	var classic: CONFIGURATION = classic_result["configuration"]
	if String(classic.configuration_id) != "classic_default":
		return _fail("Classic sample has the wrong configuration ID")
	if int(classic.material_overrides.size()) != 0:
		return _fail("Classic sample should not override materials")
	if not is_equal_approx(classic.blast_radius, 4.5) or not is_equal_approx(classic.gravity, 9.8):
		return _fail("Classic sample defaults are wrong")

	var sparse_result: Dictionary = CODEC.load_from_file(SAMPLE_SPARSE, BUILDING_CATALOG, MATERIAL_CATALOG)
	if not sparse_result["ok"]:
		return _fail("Sparse sample did not load: %s" % [sparse_result["errors"]])
	var sparse: CONFIGURATION = sparse_result["configuration"]
	if String(sparse.building_definition_id) != "sparse_pillar_beam_11":
		return _fail("Sparse sample references the wrong building")
	if int(sparse.material_overrides.size()) != 2:
		return _fail("Sparse sample should contain two material overrides")
	if String(sparse.material_overrides[0].material_id) != "lightweight_panel":
		return _fail("Sparse sample override material ID is wrong")
	if not is_equal_approx(sparse.blast_radius, 6.0) or not is_equal_approx(sparse.gravity, 12.5) or not is_equal_approx(sparse.time_scale, 0.85):
		return _fail("Sparse sample impact/environment values are wrong")
	print("WORLDBREAK_CONFIG_SAMPLES_OK")
	return true


func _test_defaults_and_warnings() -> bool:
	var data: Dictionary = {
		"format": CODEC.FORMAT,
		"schema_version": 1,
		"configuration_id": "minimal",
		"building_definition_id": "classic_70_piece"
	}
	var result: Dictionary = CODEC.from_dictionary(data, BUILDING_CATALOG, MATERIAL_CATALOG)
	if not result["ok"]:
		return _fail("Minimal configuration should use documented defaults: %s" % [result["errors"]])
	var configuration: CONFIGURATION = result["configuration"]
	if not is_equal_approx(configuration.blast_radius, 4.5) or not is_equal_approx(configuration.time_scale, 1.0):
		return _fail("Minimal configuration did not use documented defaults")
	if configuration.display_name != "minimal":
		return _fail("Missing display name should default to the configuration ID")
	if not configuration.building_transform.is_equal_approx(Transform3D.IDENTITY):
		return _fail("Missing building transform should default to identity")

	var extended: Dictionary = data.duplicate(true)
	extended["future_field"] = {"ignored": true}
	extended["impact"] = {"radius": 5.0, "future_impact_field": 1}
	var extended_result: Dictionary = CODEC.from_dictionary(extended, BUILDING_CATALOG, MATERIAL_CATALOG)
	if not extended_result["ok"]:
		return _fail("Additive unknown fields should not reject a configuration: %s" % [extended_result["errors"]])
	if not (extended_result["warnings"] as Array).any(func(warning): return String(warning).contains("future_field")):
		return _fail("Unknown top-level fields should produce a warning")
	if not (extended_result["warnings"] as Array).any(func(warning): return String(warning).contains("future_impact_field")):
		return _fail("Unknown nested fields should produce a warning")
	print("WORLDBREAK_CONFIG_DEFAULTS_OK")
	return true


func _test_invalid_inputs() -> bool:
	var base: Dictionary = CODEC.to_dictionary(_sample_configuration())
	if not _expect_rejection(base, "schema_version", 999, "unsupported schema version"):
		return false
	if not _expect_rejection(base, "format", "worldbreak.other", "unsupported format"):
		return false
	if not _expect_rejection(base, "building_definition_id", "missing_building", "unknown building ID"):
		return false
	if not _expect_mutation_rejection(base, func(data): data.erase("configuration_id"), "missing configuration ID"):
		return false
	if not _expect_mutation_rejection(base, func(data): data["impact"]["radius"] = 99.0, "out-of-range blast radius"):
		return false
	if not _expect_mutation_rejection(base, func(data): data["environment"]["time_scale"] = 0.0, "out-of-range time scale"):
		return false
	if not _expect_mutation_rejection(base, func(data): data["material_overrides"] = [{"cell": [3, 0, 1], "material_id": "missing_material"}], "unknown material ID"):
		return false
	if not _expect_mutation_rejection(base, func(data): data["material_overrides"] = [{"cell": [99, 0, 0], "material_id": "masonry"}], "out-of-range override cell"):
		return false
	if not _expect_mutation_rejection(base, func(data): data["material_overrides"] = [{"cell": [3, 0, 1], "material_id": "masonry"}, {"cell": [3, 0, 1], "material_id": "masonry"}], "duplicate override cell"):
		return false
	if not _expect_mutation_rejection(base, func(data): data["building_transform"]["scale"] = [0.0, 1.0, 1.0], "degenerate transform"):
		return false
	if not _expect_mutation_rejection(base, func(data): data["impact"]["damage"] = NAN, "non-finite number"):
		return false

	var malformed_path: String = TEST_DIRECTORY + "/malformed.json"
	var malformed: FileAccess = FileAccess.open(malformed_path, FileAccess.WRITE)
	malformed.store_string("{ this is not json")
	malformed.close()
	var malformed_result: Dictionary = CODEC.load_from_file(malformed_path, BUILDING_CATALOG, MATERIAL_CATALOG)
	if malformed_result["ok"] or (malformed_result["errors"] as Array).is_empty():
		return _fail("Malformed JSON should be rejected with an error")
	var missing_result: Dictionary = CODEC.load_from_file(TEST_DIRECTORY + "/missing.json", BUILDING_CATALOG, MATERIAL_CATALOG)
	if missing_result["ok"]:
		return _fail("Missing configuration file should be rejected")
	print("WORLDBREAK_CONFIG_REJECTION_OK")
	return true


func _test_file_round_trip() -> bool:
	var original: CONFIGURATION = _sample_configuration()
	var path: String = TEST_DIRECTORY + "/round_trip.json"
	var save_result: Dictionary = CODEC.save_to_file(original, path, BUILDING_CATALOG, MATERIAL_CATALOG)
	if not save_result["ok"]:
		return _fail("Saving a valid configuration failed: %s" % [save_result["errors"]])
	var load_result: Dictionary = CODEC.load_from_file(path, BUILDING_CATALOG, MATERIAL_CATALOG)
	if not load_result["ok"]:
		return _fail("Loading the saved configuration failed: %s" % [load_result["errors"]])
	var loaded: CONFIGURATION = load_result["configuration"]
	if CODEC.to_dictionary(original) != CODEC.to_dictionary(loaded):
		return _fail("Save/load round-trip did not preserve normalized configuration data")
	var second_path: String = TEST_DIRECTORY + "/round_trip_second.json"
	if not CODEC.save_to_file(loaded, second_path, BUILDING_CATALOG, MATERIAL_CATALOG)["ok"]:
		return _fail("Second save after load failed")
	if CODEC.to_dictionary(original) != CODEC.to_dictionary(loaded):
		return _fail("Round-trip changed configuration data")
	var invalid_save: Dictionary = CODEC.save_to_file(null, TEST_DIRECTORY + "/invalid.json", BUILDING_CATALOG, MATERIAL_CATALOG)
	if invalid_save["ok"]:
		return _fail("Saving a null configuration should fail")
	var wrong_extension: Dictionary = CODEC.save_to_file(original, TEST_DIRECTORY + "/wrong.txt", BUILDING_CATALOG, MATERIAL_CATALOG)
	if wrong_extension["ok"]:
		return _fail("Saving a configuration with a non-JSON extension should fail")
	print("WORLDBREAK_CONFIG_ROUND_TRIP_OK")
	return true


func _test_building_definition_round_trip() -> bool:
	var source = BUILDING_CATALOG.get_definition_by_id(&"classic_70_piece")
	var path: String = TEST_DIRECTORY + "/classic_copy.tres"
	var save_result: Dictionary = CODEC.save_building_definition(source, path)
	if not save_result["ok"]:
		return _fail("Saving a building definition failed: %s" % [save_result["errors"]])
	var load_result: Dictionary = CODEC.load_building_definition(path)
	if not load_result["ok"]:
		return _fail("Loading a saved building definition failed: %s" % [load_result["errors"]])
	var loaded = load_result["definition"]
	if int(loaded.cells.size()) != 70:
		return _fail("Saved building definition lost occupied cells")
	if String(loaded.definition_id) != "classic_70_piece":
		return _fail("Saved building definition changed its stable ID")
	print("WORLDBREAK_CONFIG_BUILDING_ROUND_TRIP_OK")
	return true


func _test_live_application() -> bool:
	var main: Node = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame
	var structure: Node = main.get_node_or_null("DestructibleStructure")
	if structure == null:
		return _fail("Live test could not find the destructible structure")
	if int(structure.call("get_fragment_count")) != 70:
		return _fail("Live test did not start from the default 70-piece building")

	var sparse_result: Dictionary = CODEC.load_from_file(SAMPLE_SPARSE, BUILDING_CATALOG, MATERIAL_CATALOG)
	if not sparse_result["ok"]:
		return _fail("Sparse sample failed to load for live application")
	var apply_errors: Array = main.call("apply_simulation_configuration", sparse_result["configuration"])
	if not apply_errors.is_empty():
		return _fail("Live application of the sparse sample failed: %s" % [apply_errors])
	if int(structure.call("get_fragment_count")) != 11:
		return _fail("Live application did not rebuild the sparse 11-cell building")
	if StringName(structure.call("get_cell_material_id", Vector3i(0, 0, 1))) != &"lightweight_panel":
		return _fail("Live application did not apply the per-cell material override")
	if not is_equal_approx(float(main.get("blast_radius")), 6.0) or not is_equal_approx(float(main.get("blast_damage")), 6.5):
		return _fail("Live application did not apply impact settings")
	if not is_equal_approx(float(main.call("get_simulation_gravity")), 12.5):
		return _fail("Live application did not apply the gravity setting")
	if not is_equal_approx(Engine.time_scale, 0.85):
		return _fail("Live application did not apply the time scale")
	if (structure as Node3D).position.distance_to(Vector3(0.0, 0.0, -12.0)) > 0.001:
		return _fail("Live application did not apply the building transform")
	structure.call("reset_structure")
	if not bool(structure.call("is_reset_to_initial_state")):
		return _fail("Rebuilt building did not reset to its new initial state")

	var broken_config: CONFIGURATION = _sample_configuration()
	broken_config.material_overrides[0].material_id = &"missing_material"
	var before_count: int = int(structure.call("get_fragment_count"))
	var error_before: int = int(main.call("apply_simulation_configuration", broken_config).size())
	if error_before == 0:
		return _fail("Invalid live configuration should report errors")
	if int(structure.call("get_fragment_count")) != before_count:
		return _fail("Invalid live configuration should leave the active building untouched")

	var live_path: String = TEST_DIRECTORY + "/live_saved.json"
	var save_result: Dictionary = main.call("save_simulation_configuration", live_path)
	if not save_result["ok"]:
		return _fail("Active configuration could not be saved: %s" % [save_result["errors"]])
	var load_result: Dictionary = main.call("load_simulation_configuration", live_path)
	if not load_result["ok"] or not load_result["applied"]:
		return _fail("Saved active configuration could not be loaded and applied: %s" % [load_result])
	print("WORLDBREAK_CONFIG_LIVE_APPLY_OK")
	main.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	return true


func _sample_configuration() -> CONFIGURATION:
	var configuration: CONFIGURATION = CONFIGURATION.new()
	configuration.configuration_id = &"masonry_impact_test"
	configuration.display_name = "Masonry impact test"
	configuration.building_definition_id = &"classic_70_piece"
	configuration.building_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -12.0))
	configuration.blast_radius = 4.5
	configuration.blast_damage = 4.0
	configuration.blast_impulse = 22.0
	configuration.blast_upward_bias = 0.3
	configuration.gravity = 9.8
	configuration.time_scale = 1.0
	var override = MATERIAL_OVERRIDE.new()
	override.cell = Vector3i(3, 2, 0)
	override.material_id = &"masonry"
	configuration.material_overrides.append(override)
	return configuration


func _expect_rejection(base: Dictionary, key: String, value: Variant, label: String) -> bool:
	var data: Dictionary = base.duplicate(true)
	data[key] = value
	var result: Dictionary = CODEC.from_dictionary(data, BUILDING_CATALOG, MATERIAL_CATALOG)
	if result["ok"] or (result["errors"] as Array).is_empty():
		return _fail("Configuration with %s should be rejected" % label)
	return true


func _expect_mutation_rejection(base: Dictionary, mutate: Callable, label: String) -> bool:
	var data: Dictionary = base.duplicate(true)
	mutate.call(data)
	var result: Dictionary = CODEC.from_dictionary(data, BUILDING_CATALOG, MATERIAL_CATALOG)
	if result["ok"] or (result["errors"] as Array).is_empty():
		return _fail("Configuration with %s should be rejected" % label)
	return true


func _fail(message: String) -> bool:
	push_error(message)
	print("WORLDBREAK_CONFIGURATION_PERSISTENCE_FAILED: " + message)
	quit(1)
	return false
