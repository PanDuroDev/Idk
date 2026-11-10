extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SUPPORT_GRAPH_SCRIPT = preload("res://scripts/structural_support_graph.gd")
const BLAST_SERVICE_SCRIPT = preload("res://scripts/blast_service.gd")
const STRUCTURE_SCRIPT = preload("res://scripts/destructible_structure.gd")
const BUILDING_DEFINITION_VALIDATOR = preload("res://scripts/building_definition_validator.gd")
const BuildingDefinitionScript = preload("res://scripts/building_definition.gd")
const BuildingCellDefinitionScript = preload("res://scripts/building_cell_definition.gd")
const DestructionMaterialProfileScript = preload("res://scripts/destruction_material_profile.gd")
const MaterialProfileCatalogScript = preload("res://scripts/material_profile_catalog.gd")
const MATERIAL_PROFILE_CATALOG: MaterialProfileCatalogScript = preload("res://resources/materials/material_profile_catalog.tres")
const CLASSIC_BUILDING: BuildingDefinitionScript = preload("res://resources/buildings/classic_70_piece.tres")
const SPARSE_BUILDING: BuildingDefinitionScript = preload("res://resources/buildings/sparse_pillar_beam_11.tres")

const REQUIRED_INPUT_ACTIONS: Array[StringName] = [
	&"move_forward",
	&"move_backward",
	&"move_left",
	&"move_right",
	&"jump",
	&"trigger_impact",
	&"reset_structure",
	&"release_mouse"
]


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	if not _test_material_authoring():
		return
	if not _test_building_definition_assets():
		return

	for action: StringName in REQUIRED_INPUT_ACTIONS:
		if not InputMap.has_action(action):
			_fail("Missing InputMap action: %s" % action)
			return

	if not _test_support_graph():
		return

	var main: Node = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame

	var structure: Node = main.get_node_or_null("DestructibleStructure")
	if structure == null:
		_fail("DestructibleStructure was not created")
		return

	if main.get_node_or_null("Player/Camera3D") == null:
		_fail("Player camera was not created")
		return

	var fragment_count: int = int(structure.call("get_fragment_count"))
	if fragment_count != 70:
		_fail("Expected 70 fragments, got %d" % fragment_count)
		return

	if absf(float(main.get("blast_radius")) - 4.5) > 0.001 or absf(float(main.get("blast_damage")) - 4.0) > 0.001 or absf(float(main.get("blast_impulse")) - 22.0) > 0.001:
		_fail("Impact controls did not preserve the prototype defaults")
		return
	main.call("adjust_impact_setting", &"blast_radius", 100.0)
	main.call("adjust_impact_setting", &"blast_damage", -100.0)
	main.call("adjust_impact_setting", &"blast_impulse", 1000.0)
	if absf(float(main.get("blast_radius")) - 12.0) > 0.001 or absf(float(main.get("blast_damage")) - 0.1) > 0.001 or absf(float(main.get("blast_impulse")) - 100.0) > 0.001:
		_fail("Impact controls did not clamp values to their safe ranges")
		return
	main.call("reset_impact_settings")
	if absf(float(main.get("blast_radius")) - 4.5) > 0.001 or absf(float(main.get("blast_damage")) - 4.0) > 0.001 or absf(float(main.get("blast_impulse")) - 22.0) > 0.001:
		_fail("Impact controls did not restore their defaults")
		return
	print("WORLDBREAK_IMPACT_CONTROLS_OK: defaults, bounds, and reset")

	# Build the sparse sample through the same runtime structure component used by the main scene.
	var alternate_structure: Node3D = STRUCTURE_SCRIPT.new()
	alternate_structure.set("building_definition", SPARSE_BUILDING)
	alternate_structure.position = Vector3(25.0, 0.0, -12.0)
	root.add_child(alternate_structure)
	await process_frame
	await physics_frame
	if int(alternate_structure.call("get_fragment_count")) != 11:
		_fail("Sparse building should generate exactly 11 fragments")
		return
	if int(alternate_structure.call("get_supported_fragment_count")) != 11:
		_fail("All 11 sparse building fragments should start supported")
		return
	var custom_fragment: RigidBody3D = alternate_structure.call("get_fragment_for_cell", Vector3i(2, 3, 1))
	if custom_fragment == null or absf(custom_fragment.position.y - 3.74) > 0.001:
		_fail("Sparse per-cell custom transform was not applied by the builder")
		return
	if StringName(alternate_structure.call("get_cell_material_id", Vector3i(2, 3, 1))) != &"lightweight_panel":
		_fail("Sparse per-cell material override was not applied by the builder")
		return

	var sparse_profile: DestructionMaterialProfileScript = null
	for sparse_cell: BuildingCellDefinitionScript in SPARSE_BUILDING.cells:
		if sparse_cell.coordinate == Vector3i(2, 3, 1):
			sparse_profile = SPARSE_BUILDING.get_cell_material_profile(sparse_cell)
			break
	if sparse_profile == null:
		_fail("Sparse per-cell material override could not be resolved")
		return
	if not is_equal_approx(custom_fragment.mass, sparse_profile.density_multiplier):
		_fail("Sparse per-cell material density was not applied to fragment mass")
		return
	var custom_mesh: MeshInstance3D = null
	for fragment_child: Node in custom_fragment.get_children():
		if fragment_child is MeshInstance3D:
			custom_mesh = fragment_child as MeshInstance3D
			break
	if custom_mesh == null:
		_fail("Sparse fragment is missing its MeshInstance3D visual child")
		return
	var custom_visual: StandardMaterial3D = custom_mesh.material_override as StandardMaterial3D
	if custom_visual == null:
		_fail("Sparse fragment visual has no StandardMaterial3D override")
		return
	if not custom_visual.albedo_color.is_equal_approx(sparse_profile.surface_color):
		_fail("Sparse fragment color mismatch: actual=%s expected=%s" % [custom_visual.albedo_color, sparse_profile.surface_color])
		return
	if not is_equal_approx(float(alternate_structure.call("get_cell_integrity", Vector3i(2, 3, 1))), sparse_profile.integrity):
		_fail("Sparse per-cell material integrity was not applied to damage thresholds")
		return
	var override_breaks: int = int(alternate_structure.call(
		"apply_blast_damage",
		custom_fragment.global_position,
		0.1,
		sparse_profile.integrity * sparse_profile.blast_resistance * 1.01
	))
	if override_breaks != 1 or float(alternate_structure.call("get_cell_damage_ratio", Vector3i(2, 3, 1))) < 0.999:
		_fail("Sparse per-cell material resistance/integrity did not control its damage threshold")
		return
	alternate_structure.call("reset_structure")
	if not bool(alternate_structure.call("is_reset_to_initial_state")):
		_fail("Sparse structure reset after material override damage failed")
		return
	var sparse_left_anchor: RigidBody3D = alternate_structure.call("get_fragment_for_cell", Vector3i(0, 0, 1))
	var sparse_right_anchor: RigidBody3D = alternate_structure.call("get_fragment_for_cell", Vector3i(4, 0, 1))
	alternate_structure.call("apply_blast_damage", sparse_left_anchor.global_position, 0.1, 10.0)
	alternate_structure.call("apply_blast_damage", sparse_right_anchor.global_position, 0.1, 10.0)
	if int(alternate_structure.call("get_released_fragment_count")) != 11:
		_fail("Sparse structure collapse did not release all definition cells")
		return
	alternate_structure.call("reset_structure")
	if not bool(alternate_structure.call("is_reset_to_initial_state")):
		_fail("Sparse structure reset did not restore all definition cells")
		return
	alternate_structure.queue_free()
	await process_frame
	print("WORLDBREAK_BUILDING_DEFINITIONS_OK: 70-piece compatibility, sparse generation, transforms, materials, validation, collapse and reset")

	if int(structure.call("get_supported_fragment_count")) != 70:
		_fail("All intact fragments should initially be supported")
		return

	if int(structure.call("get_released_fragment_count")) != 0:
		_fail("Structure should start with every fragment frozen")
		return

	var foundation_cell := Vector3i(3, 0, 1)
	var masonry_cell := Vector3i(3, 1, 1)
	var lightweight_cell := Vector3i(3, 4, 1)

	if StringName(structure.call("get_cell_material_id", foundation_cell)) != &"foundation_concrete":
		_fail("Bottom layer should use the foundation concrete profile")
		return
	if StringName(structure.call("get_cell_material_id", masonry_cell)) != &"masonry":
		_fail("Main wall layers should use the masonry profile")
		return
	if StringName(structure.call("get_cell_material_id", lightweight_cell)) != &"lightweight_panel":
		_fail("Top layer should use the lightweight profile")
		return

	var foundation_integrity: float = float(structure.call("get_cell_integrity", foundation_cell))
	var masonry_integrity: float = float(structure.call("get_cell_integrity", masonry_cell))
	var foundation_resistance: float = float(structure.call("get_cell_blast_resistance", foundation_cell))
	var masonry_resistance: float = float(structure.call("get_cell_blast_resistance", masonry_cell))
	if foundation_integrity <= masonry_integrity or foundation_resistance <= masonry_resistance:
		_fail("Foundation profile must be tougher and more blast resistant than masonry")
		return
	if float(structure.call("get_cell_density_multiplier", foundation_cell)) <= float(structure.call("get_cell_density_multiplier", masonry_cell)):
		_fail("Foundation density multiplier should exceed masonry")
		return

	var initial_fragment_positions: Dictionary = {}
	for fragment_node in structure.get_children():
		var fragment := fragment_node as RigidBody3D
		if fragment != null:
			initial_fragment_positions[fragment.get_instance_id()] = fragment.global_position
	if initial_fragment_positions.size() != 70:
		_fail("Could not capture the initial transform of all 70 fragments")
		return

	main.set("blast_radius", 4.5)
	main.set("blast_damage", 10.0)
	main.call("request_blast", Vector3(0.0, 0.5, 6.0), Vector3(0.0, 0.0, -1.0))
	await physics_frame
	await physics_frame

	var broken_after_blast: int = int(structure.call("get_broken_fragment_count"))
	var unsupported_after_blast: int = int(structure.call("get_unsupported_fragment_count"))
	var released_after_blast: int = int(structure.call("get_released_fragment_count"))
	var supported_after_blast: int = int(structure.call("get_supported_fragment_count"))

	if broken_after_blast < 14:
		_fail("Expected the complete 14-block base row to break, got %d" % broken_after_blast)
		return
	if supported_after_blast != 0:
		_fail("Expected no supported fragments after the full base row was removed, got %d" % supported_after_blast)
		return
	if unsupported_after_blast <= 0:
		_fail("The upper structure should be classified as unsupported")
		return
	if released_after_blast != 70:
		_fail("Expected all 70 fragments to be released after support loss, got %d" % released_after_blast)
		return

	# Let the real physics server simulate the collapse before resetting the scene.
	const COLLAPSE_SIMULATION_FRAMES: int = 120
	for frame_index in range(COLLAPSE_SIMULATION_FRAMES):
		await physics_frame

	var simulated_fragment_count: int = 0
	var moved_fragment_count: int = 0
	for fragment_node in structure.get_children():
		var fragment := fragment_node as RigidBody3D
		if fragment == null:
			continue

		simulated_fragment_count += 1
		var start_position: Vector3 = initial_fragment_positions[fragment.get_instance_id()]
		if not fragment.global_position.is_finite():
			_fail("Fragment position became non-finite after collapse: %s" % fragment.name)
			return
		if not fragment.linear_velocity.is_finite() or not fragment.angular_velocity.is_finite():
			_fail("Fragment velocity became non-finite after collapse: %s" % fragment.name)
			return
		if fragment.global_position.y < -0.1:
			_fail("Fragment passed through the ground during collapse: %s" % fragment.name)
			return
		if fragment.global_position.distance_to(start_position) > 0.05:
			moved_fragment_count += 1

	if simulated_fragment_count != 70:
		_fail("Expected 70 fragments to remain in the physics simulation, got %d" % simulated_fragment_count)
		return
	if moved_fragment_count == 0:
		_fail("The collapse simulation did not move any fragments")
		return

	print(
		"WORLDBREAK_PHYSICS_COLLAPSE_OK: frames=%d; fragments=%d; moved=%d; ground_containment=passed"
		% [COLLAPSE_SIMULATION_FRAMES, simulated_fragment_count, moved_fragment_count]
	)

	main.call("request_structure_reset")
	await physics_frame
	await physics_frame

	if not bool(structure.call("is_reset_to_initial_state")):
		_fail("Reset did not restore graph state, transforms, velocities, and frozen state")
		return

	if int(structure.call("get_supported_fragment_count")) != 70:
		_fail("Reset did not restore all 70 support links")
		return

	var masonry_cell_center := Vector3(0.0, 1.54, -11.48)
	var foundation_cell_center := Vector3(0.0, 0.5, -11.48)

	var first_masonry_hit: int = int(structure.call("apply_blast_damage", masonry_cell_center, 0.25, 0.5))
	if first_masonry_hit != 0:
		_fail("A single weak hit should not break a masonry fragment")
		return
	if absf(float(structure.call("get_cell_damage", masonry_cell)) - 0.5) > 0.001:
		_fail("The first weak hit did not accumulate the expected masonry damage")
		return

	var second_masonry_hit: int = int(structure.call("apply_blast_damage", masonry_cell_center, 0.25, 0.5))
	if second_masonry_hit != 1:
		_fail("A second weak hit should cross the masonry integrity threshold")
		return
	if int(structure.call("get_broken_fragment_count")) != 1:
		_fail("Repeated weak hits should break exactly one masonry fragment")
		return
	if int(structure.call("get_supported_fragment_count")) != 69:
		_fail("A single broken masonry block should retain alternate support paths")
		return

	for hit_index in range(3):
		var foundation_breaks: int = int(structure.call("apply_blast_damage", foundation_cell_center, 0.25, 0.5))
		if foundation_breaks != 0:
			_fail("Foundation concrete should resist three weak masonry-sized hits")
			return
	if float(structure.call("get_cell_damage", foundation_cell)) >= foundation_integrity:
		_fail("Foundation damage should remain below its higher integrity threshold")
		return

	var fourth_foundation_hit: int = int(structure.call("apply_blast_damage", foundation_cell_center, 0.25, 0.5))
	if fourth_foundation_hit != 1:
		_fail("The fourth weak hit should cross the foundation integrity threshold")
		return

	structure.call("reset_structure")
	if not bool(structure.call("is_reset_to_initial_state")):
		_fail("Reset did not clear material damage and restore all structure state")
		return

	var lightweight_cell_center := Vector3(0.0, 4.66, -11.48)
	var lightweight_hit: int = int(structure.call(
		"apply_blast_damage",
		lightweight_cell_center,
		0.25,
		0.55
	))
	if lightweight_hit != 1:
		_fail("A centered weak hit should break the lower-integrity lightweight panel")
		return
	if float(structure.call("get_cell_damage_ratio", lightweight_cell)) < 0.999:
		_fail("The lightweight panel did not reach its material-specific integrity threshold")
		return
	if int(structure.call("get_broken_fragment_count")) != 1:
		_fail("The lightweight panel test should break exactly one fragment")
		return

	structure.call("reset_structure")
	if not bool(structure.call("is_reset_to_initial_state")):
		_fail("Reset did not restore the lightweight panel after its one-hit break test")
		return

	const REPEATED_COLLAPSE_CYCLES: int = 5
	const REPEATED_COLLAPSE_PHYSICS_FRAMES: int = 120
	
	for cycle_index in range(REPEATED_COLLAPSE_CYCLES):
		main.set("blast_radius", 4.5)
		main.set("blast_damage", 10.0)
		main.set("blast_impulse", 22.0)
		main.call("request_blast", Vector3(0.0, 0.5, 6.0), Vector3(0.0, 0.0, -1.0))
		await physics_frame
		await physics_frame
	
		var cycle_broken_count: int = int(structure.call("get_broken_fragment_count"))
		var cycle_released_count: int = int(structure.call("get_released_fragment_count"))
		var cycle_supported_count: int = int(structure.call("get_supported_fragment_count"))
		if cycle_broken_count < 14:
			_fail("Collapse cycle %d did not break the full foundation row" % (cycle_index + 1))
			return
		if cycle_released_count != 70 or cycle_supported_count != 0:
			_fail("Collapse cycle %d did not release all 70 fragments" % (cycle_index + 1))
			return
	
		for frame_index in range(REPEATED_COLLAPSE_PHYSICS_FRAMES):
			await physics_frame
	
		var cycle_fragment_count: int = 0
		var cycle_moved_count: int = 0
		for fragment_node in structure.get_children():
			var fragment := fragment_node as RigidBody3D
			if fragment == null:
				continue
	
			cycle_fragment_count += 1
			if not fragment.global_position.is_finite():
				_fail("Collapse cycle %d produced a non-finite position for %s" % [cycle_index + 1, fragment.name])
				return
			if not fragment.linear_velocity.is_finite() or not fragment.angular_velocity.is_finite():
				_fail("Collapse cycle %d produced a non-finite velocity for %s" % [cycle_index + 1, fragment.name])
				return
			if fragment.global_position.y < -0.1:
				_fail("Collapse cycle %d let %s pass through the ground" % [cycle_index + 1, fragment.name])
				return
			var initial_position: Vector3 = initial_fragment_positions[fragment.get_instance_id()]
			if fragment.global_position.distance_to(initial_position) > 0.05:
				cycle_moved_count += 1
	
		if cycle_fragment_count != 70 or cycle_moved_count != 70:
			_fail("Collapse cycle %d did not move all 70 fragments" % (cycle_index + 1))
			return
	
		main.call("request_structure_reset")
		await physics_frame
		await physics_frame
		if not bool(structure.call("is_reset_to_initial_state")):
			_fail("Reset failed after collapse cycle %d" % (cycle_index + 1))
			return
	
	print(
		"WORLDBREAK_REPEAT_CYCLES_OK: cycles=%d; frames_per_cycle=%d; fragments=70; reset_checks=%d"
		% [REPEATED_COLLAPSE_CYCLES, REPEATED_COLLAPSE_PHYSICS_FRAMES, REPEATED_COLLAPSE_CYCLES]
	)

	# Verify sleeping loose debris can be reactivated by a legitimate radial impact.
	structure.set("loose_debris_lifetime_seconds", 30.0)
	var wake_cell := Vector3i(3, 0, 1)
	structure.call("apply_blast_damage", Vector3(0.0, 0.5, -11.48), 0.25, 2.0)
	await physics_frame
	var wake_fragment: RigidBody3D = structure.call("get_fragment_for_cell", wake_cell)
	if wake_fragment == null or wake_fragment.freeze:
		_fail("The test fragment was not released for the wake-up test")
		return
	wake_fragment.sleeping = true
	var blast_service: RefCounted = BLAST_SERVICE_SCRIPT.new()
	blast_service.call("apply_radial_impulse", main.get_world_3d().direct_space_state, wake_fragment.global_position, 2.0, 2.0, 0.0)
	await physics_frame
	if wake_fragment.sleeping:
		_fail("A radial impact did not wake sleeping loose debris")
		return

	# Recomputing support state alone must not spuriously wake settled debris.
	wake_fragment.sleeping = true
	structure.call("_refresh_support_state")
	await physics_frame
	if not wake_fragment.sleeping:
		_fail("A support refresh incorrectly woke sleeping loose debris")
		return

	# Shorten lifetime only for this isolated cleanup assertion, then prove reset restores every node.
	structure.set("loose_debris_lifetime_seconds", 0.05)
	for frame_index in range(8):
		await physics_frame
	if int(structure.call("get_retired_fragment_count")) <= 0:
		_fail("Expired loose debris was not retired")
		return
	structure.call("reset_structure")
	if not bool(structure.call("is_reset_to_initial_state")) or int(structure.call("get_retired_fragment_count")) != 0:
		_fail("Reset did not restore retired debris to the original structure")
		return
	if int(structure.call("get_fragment_count")) != 70 or int(structure.call("get_supported_fragment_count")) != 70:
		_fail("Debris cleanup/reset did not restore all original structural fragments")
		return
	print("WORLDBREAK_DEBRIS_LIFECYCLE_OK: wake, expiry, and full reset")

	# Exercise the configured awake-body cap with a deliberately small test budget.
	structure.set("loose_debris_lifetime_seconds", 30.0)
	structure.set("max_active_loose_fragments", 1)
	structure.call("apply_blast_damage", Vector3(0.0, 0.5, -11.48), 4.5, 10.0)
	for frame_index in range(2):
		await physics_frame
	if int(structure.call("get_released_fragment_count")) <= 1:
		_fail("The active-fragment budget test did not release multiple fragments")
		return
	var active_after_budget: int = int(structure.call("get_active_loose_fragment_count"))
	var sleeping_after_budget: int = int(structure.call("get_sleeping_loose_fragment_count"))
	var parked_after_budget: int = int(structure.call("get_budget_parked_fragment_count"))
	if active_after_budget > 1 or sleeping_after_budget + parked_after_budget <= 0 or parked_after_budget <= 0:
		_fail("The configured active-fragment cap was not enforced or parked/sleeping counts overlap")
		return
	structure.call("reset_structure")
	structure.set("max_active_loose_fragments", 70)
	if not bool(structure.call("is_reset_to_initial_state")):
		_fail("Reset after active-budget enforcement did not restore the structure")
		return
	print("WORLDBREAK_ACTIVE_FRAGMENT_BUDGET_OK: awake_cap=1")


	# Debug diagnostics are opt-in, and effect bursts remain explicitly bounded.
	var debug_panel: PanelContainer = main.get("_debug_overlay_panel") as PanelContainer
	var debug_label: Label = main.get("_debug_overlay_label") as Label
	if debug_panel == null or debug_label == null or debug_panel.visible or bool(main.get("_debug_overlay_visible")):
		_fail("Debug overlay should exist and be hidden by default")
		return
	# Keep the UI state test independent of renderer-specific Performance monitors in headless mode.
	main.set("_debug_overlay_label", null)
	main.call("toggle_debug_overlay")
	if not bool(main.get("_debug_overlay_visible")) or not debug_panel.visible:
		_fail("F3 debug overlay toggle did not enable diagnostics")
		return
	main.call("toggle_debug_overlay")
	if debug_panel.visible:
		_fail("Debug overlay toggle did not hide diagnostics")
		return
	main.set("_debug_overlay_label", debug_label)
	for effect_index in range(12):
		main.call("_spawn_blast_flash", Vector3.ZERO)
	if int(main.call("get_active_effect_count")) > 8:
		_fail("Blast dust effects exceeded the active effect budget")
		return
	print("WORLDBREAK_DIAGNOSTICS_EFFECTS_OK: opt-in overlay and bounded dust bursts")
	print("WORLDBREAK_SMOKE_TEST_OK: all material profiles, support graph, collapse, cumulative damage, repeated reset, and reset")
	quit(0)


func _test_material_authoring() -> bool:
	var errors: Array[String] = MATERIAL_PROFILE_CATALOG.validate_catalog()
	if not errors.is_empty():
		_fail("Material profile catalog is invalid: %s" % "; ".join(errors))
		return false
	if MATERIAL_PROFILE_CATALOG.profiles.size() != 3:
		_fail("Material profile catalog should contain the three original shared profiles")
		return false

	var expected_ids: Array[StringName] = [
		&"foundation_concrete",
		&"masonry",
		&"lightweight_panel"
	]
	for expected_id: StringName in expected_ids:
		if MATERIAL_PROFILE_CATALOG.get_profile_by_id(expected_id) == null:
			_fail("Material catalog could not resolve profile ID '%s'" % String(expected_id))
			return false

	var original: DestructionMaterialProfileScript = MATERIAL_PROFILE_CATALOG.get_profile_by_id(&"masonry")
	var duplicate: DestructionMaterialProfileScript = MATERIAL_PROFILE_CATALOG.duplicate_profile(
		&"masonry",
		&"reinforced_masonry_test",
		"Reinforced Masonry Test"
	)
	if duplicate == null:
		_fail("Material catalog could not duplicate a valid profile")
		return false
	if duplicate == original or duplicate.material_id != &"reinforced_masonry_test":
		_fail("Duplicated material profile must be an independent Resource with its new ID")
		return false
	if duplicate.integrity != original.integrity or duplicate.blast_resistance != original.blast_resistance or duplicate.density_multiplier != original.density_multiplier or duplicate.surface_color != original.surface_color:
		_fail("Duplicated material profile did not preserve the source tuning values")
		return false

	var add_errors: Array[String] = MATERIAL_PROFILE_CATALOG.add_profile(duplicate)
	if not add_errors.is_empty():
		_fail("Material catalog rejected a valid new profile: %s" % "; ".join(add_errors))
		return false
	if MATERIAL_PROFILE_CATALOG.get_profile_by_id(&"reinforced_masonry_test") != duplicate:
		_fail("Material catalog did not retain the newly added profile")
		return false

	var conflicting_copy: DestructionMaterialProfileScript = original.duplicate(true) as DestructionMaterialProfileScript
	var duplicate_add_errors: Array[String] = MATERIAL_PROFILE_CATALOG.add_profile(conflicting_copy)
	if duplicate_add_errors.is_empty():
		_fail("Material catalog accepted a second Resource with an existing material ID")
		return false

	if MATERIAL_PROFILE_CATALOG.duplicate_profile(&"masonry", &"reinforced_masonry_test", "Duplicate ID") != null:
		_fail("Material duplicate helper accepted an ID already used by the catalog")
		return false
	if MATERIAL_PROFILE_CATALOG.duplicate_profile(&"missing_source", &"new_id", "Missing Source") != null:
		_fail("Material duplicate helper accepted an unknown source ID")
		return false

	print("WORLDBREAK_MATERIAL_AUTHORING_OK: catalog, lookup, validation, duplicate, and duplicate-ID rejection")
	return true


func _test_building_definition_assets() -> bool:
	var classic_errors: Array[String] = BUILDING_DEFINITION_VALIDATOR.validate_definition(CLASSIC_BUILDING)
	if not classic_errors.is_empty():
		_fail("Classic building definition is invalid: %s" % "; ".join(classic_errors))
		return false
	if CLASSIC_BUILDING.get_occupied_cell_count() != 70:
		_fail("Classic building definition must contain exactly 70 occupied cells")
		return false

	var classic_coordinates: Dictionary = {}
	for cell: BuildingCellDefinitionScript in CLASSIC_BUILDING.cells:
		if classic_coordinates.has(cell.coordinate):
			_fail("Classic building definition contains duplicate coordinate %s" % cell.coordinate)
			return false
		classic_coordinates[cell.coordinate] = true

		var expected_center := Vector3(
			(float(cell.coordinate.x) - 3.0) * 1.04,
			0.5 + float(cell.coordinate.y) * 1.04,
			(float(cell.coordinate.z) - 0.5) * 1.04
		)
		var actual_center: Vector3 = CLASSIC_BUILDING.get_cell_local_transform(cell).origin
		if actual_center.distance_to(expected_center) > 0.001:
			_fail("Classic cell %s changed its legacy center" % cell.coordinate)
			return false

		var expected_material_id: StringName = &"masonry"
		if cell.coordinate.y == 0:
			expected_material_id = &"foundation_concrete"
		elif cell.coordinate.y == 4:
			expected_material_id = &"lightweight_panel"
		if CLASSIC_BUILDING.get_cell_material_profile(cell).material_id != expected_material_id:
			_fail("Classic cell %s changed its legacy material layer" % cell.coordinate)
			return false
	if classic_coordinates.size() != 70:
		_fail("Classic building coordinates are not unique")
		return false

	var classic_origin_cell: BuildingCellDefinitionScript = null
	var foundation_cell: BuildingCellDefinitionScript = null
	var masonry_cell: BuildingCellDefinitionScript = null
	var lightweight_cell: BuildingCellDefinitionScript = null
	for cell: BuildingCellDefinitionScript in CLASSIC_BUILDING.cells:
		if cell.coordinate == Vector3i(0, 0, 0):
			classic_origin_cell = cell
		elif cell.coordinate == Vector3i(3, 1, 1):
			masonry_cell = cell
		elif cell.coordinate == Vector3i(3, 4, 1):
			lightweight_cell = cell
		elif cell.coordinate == Vector3i(3, 0, 1):
			foundation_cell = cell

	if classic_origin_cell == null or foundation_cell == null or masonry_cell == null or lightweight_cell == null:
		_fail("Classic preset is missing one of its material/position regression cells")
		return false
	var classic_origin: Vector3 = CLASSIC_BUILDING.get_cell_local_transform(classic_origin_cell).origin
	if classic_origin.distance_to(Vector3(-3.12, 0.5, -0.52)) > 0.001:
		_fail("Classic preset changed the legacy first-cell center")
		return false
	if CLASSIC_BUILDING.get_cell_material_profile(foundation_cell).material_id != &"foundation_concrete":
		_fail("Classic preset bottom layer must retain foundation concrete")
		return false
	if CLASSIC_BUILDING.get_cell_material_profile(masonry_cell).material_id != &"masonry":
		_fail("Classic preset middle layers must retain masonry")
		return false
	if CLASSIC_BUILDING.get_cell_material_profile(lightweight_cell).material_id != &"lightweight_panel":
		_fail("Classic preset top layer must retain lightweight panel material")
		return false

	var sparse_errors: Array[String] = BUILDING_DEFINITION_VALIDATOR.validate_definition(SPARSE_BUILDING)
	if not sparse_errors.is_empty():
		_fail("Sparse building definition is invalid: %s" % "; ".join(sparse_errors))
		return false
	if SPARSE_BUILDING.dimensions == CLASSIC_BUILDING.dimensions or SPARSE_BUILDING.get_occupied_cell_count() != 11:
		_fail("Sparse sample must prove a different 11-cell layout")
		return false

	var custom_transform_count: int = 0
	var lightweight_override_count: int = 0
	for cell: BuildingCellDefinitionScript in SPARSE_BUILDING.cells:
		if cell.use_custom_transform:
			custom_transform_count += 1
		if SPARSE_BUILDING.get_cell_material_profile(cell).material_id == &"lightweight_panel":
			lightweight_override_count += 1
	if custom_transform_count != 1 or lightweight_override_count != 1:
		_fail("Sparse sample must exercise one custom transform and one per-cell material override")
		return false

	var malformed := BuildingDefinitionScript.new()
	malformed.schema_version = BuildingDefinitionScript.CURRENT_SCHEMA_VERSION
	malformed.definition_id = &"malformed_duplicate_test"
	malformed.display_name = "Malformed duplicate test"
	malformed.dimensions = Vector3i(2, 2, 2)
	malformed.default_material_profile = CLASSIC_BUILDING.default_material_profile
	var duplicate_a := BuildingCellDefinitionScript.new()
	duplicate_a.coordinate = Vector3i.ZERO
	var duplicate_b := BuildingCellDefinitionScript.new()
	duplicate_b.coordinate = Vector3i.ZERO
	malformed.cells.append(duplicate_a)
	malformed.cells.append(duplicate_b)
	var malformed_errors: Array[String] = BUILDING_DEFINITION_VALIDATOR.validate_definition(malformed)
	var found_duplicate_error: bool = false
	for error_text: String in malformed_errors:
		if error_text.contains("duplicates coordinate"):
			found_duplicate_error = true
	if not found_duplicate_error:
		_fail("Building validator did not reject duplicate cell coordinates")
		return false

	malformed.cells[1].coordinate = Vector3i(2, 0, 0)
	var out_of_bounds_errors: Array[String] = BUILDING_DEFINITION_VALIDATOR.validate_definition(malformed)
	var found_bounds_error: bool = false
	for error_text: String in out_of_bounds_errors:
		if error_text.contains("outside the definition dimensions"):
			found_bounds_error = true
	if not found_bounds_error:
		_fail("Building validator did not reject an out-of-bounds cell")
		return false

	malformed.cells[1].coordinate = Vector3i.ZERO
	malformed.default_material_profile = null
	var missing_material_errors: Array[String] = BUILDING_DEFINITION_VALIDATOR.validate_definition(malformed)
	var found_missing_material_error: bool = false
	for error_text: String in missing_material_errors:
		if error_text.contains("no material profile"):
			found_missing_material_error = true
	if not found_missing_material_error:
		_fail("Building validator did not reject cells without material assignment")
		return false

	var duplicate_profile: DestructionMaterialProfileScript = CLASSIC_BUILDING.default_material_profile.duplicate() as DestructionMaterialProfileScript
	var duplicate_catalog: Array[DestructionMaterialProfileScript] = []
	duplicate_catalog.append(CLASSIC_BUILDING.default_material_profile)
	duplicate_catalog.append(duplicate_profile)
	var duplicate_catalog_errors: Array[String] = BUILDING_DEFINITION_VALIDATOR.validate_material_catalog(duplicate_catalog)
	if duplicate_catalog_errors.is_empty():
		_fail("Material catalog validator accepted duplicate profile IDs")
		return false

	malformed.default_material_profile = CLASSIC_BUILDING.default_material_profile
	malformed.dimensions = Vector3i(2, 0, 2)
	var invalid_dimensions_errors: Array[String] = BUILDING_DEFINITION_VALIDATOR.validate_definition(malformed)
	var found_dimensions_error: bool = false
	for error_text: String in invalid_dimensions_errors:
		if error_text.contains("dimensions must be positive"):
			found_dimensions_error = true
	if not found_dimensions_error:
		_fail("Building validator did not reject non-positive dimensions")
		return false

	malformed.dimensions = Vector3i(2, 2, 2)
	malformed.schema_version = BuildingDefinitionScript.CURRENT_SCHEMA_VERSION + 1
	var unsupported_schema_errors: Array[String] = BUILDING_DEFINITION_VALIDATOR.validate_definition(malformed)
	var found_schema_error: bool = false
	for error_text: String in unsupported_schema_errors:
		if error_text.contains("Unsupported building schema version"):
			found_schema_error = true
	if not found_schema_error:
		_fail("Building validator did not reject an unsupported schema version")
		return false

	malformed.schema_version = BuildingDefinitionScript.CURRENT_SCHEMA_VERSION
	malformed.cells.clear()
	malformed.cells.append(null)
	var null_cell_errors: Array[String] = BUILDING_DEFINITION_VALIDATOR.validate_definition(malformed)
	var found_null_cell_error: bool = false
	for error_text: String in null_cell_errors:
		if error_text.contains("Cell entry 0 is null"):
			found_null_cell_error = true
	if not found_null_cell_error:
		_fail("Building validator did not reject a null cell entry")
		return false

	var invalid_transform_cell := BuildingCellDefinitionScript.new()
	invalid_transform_cell.coordinate = Vector3i.ZERO
	invalid_transform_cell.use_custom_transform = true
	invalid_transform_cell.local_transform = Transform3D(Basis.IDENTITY, Vector3(INF, 0.0, 0.0))
	malformed.cells.clear()
	malformed.cells.append(invalid_transform_cell)
	var invalid_transform_errors: Array[String] = BUILDING_DEFINITION_VALIDATOR.validate_definition(malformed)
	var found_transform_error: bool = false
	for error_text: String in invalid_transform_errors:
		if error_text.contains("non-finite or degenerate custom transform"):
			found_transform_error = true
	if not found_transform_error:
		_fail("Building validator did not reject a non-finite custom transform")
		return false

	var invalid_profile := DestructionMaterialProfileScript.new()
	invalid_profile.material_id = &"invalid_profile"
	invalid_profile.display_name = "Invalid profile"
	invalid_profile.integrity = 0.0
	var profile_errors: Array[String] = BUILDING_DEFINITION_VALIDATOR.validate_material_profile(invalid_profile)
	if profile_errors.is_empty():
		_fail("Material profile validator accepted an out-of-range integrity value")
		return false

	return true


func _test_support_graph() -> bool:
	var column: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(0, 1, 0),
		Vector3i(0, 2, 0)
	]
	var intact_support: Dictionary = SUPPORT_GRAPH_SCRIPT.find_supported_cells(column, {})
	if intact_support.size() != 3:
		_fail("An intact column should be fully supported")
		return false

	var removed_base: Dictionary = {Vector3i(0, 0, 0): true}
	var collapsed_support: Dictionary = SUPPORT_GRAPH_SCRIPT.find_supported_cells(column, removed_base)
	if not collapsed_support.is_empty():
		_fail("A column without its base anchor should have no supported cells")
		return false

	var bridge: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(0, 1, 0),
		Vector3i(1, 0, 0),
		Vector3i(1, 1, 0)
	]
	var one_base_removed: Dictionary = {Vector3i(0, 0, 0): true}
	var alternate_path: Dictionary = SUPPORT_GRAPH_SCRIPT.find_supported_cells(bridge, one_base_removed)
	if alternate_path.size() != 3:
		_fail("The alternate support path should keep the connected bridge supported")
		return false

	return true


func _fail(message: String) -> void:
	push_error("WORLDBREAK_SMOKE_TEST_FAILED: " + message)
	quit(1)
