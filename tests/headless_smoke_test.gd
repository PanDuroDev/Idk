extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SUPPORT_GRAPH_SCRIPT = preload("res://scripts/structural_support_graph.gd")

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

	print("WORLDBREAK_SMOKE_TEST_OK: material profiles, support graph, collapse, cumulative damage, and reset")
	quit(0)


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
