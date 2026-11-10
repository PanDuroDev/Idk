class_name ScenarioCatalog
extends Resource

const ExperimentScenarioScript = preload("res://scripts/experiment_scenario.gd")

@export var scenarios: Array[ExperimentScenarioScript] = []


func validate_catalog(world_catalog: WorldCatalog) -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	for index in range(scenarios.size()):
		var scenario: ExperimentScenarioScript = scenarios[index]
		if scenario == null:
			errors.append("Scenario catalog entry %d is null." % index)
			continue
		for scenario_error: String in validate_definition(scenario, world_catalog):
			errors.append("Scenario catalog entry %d: %s" % [index, scenario_error])
		var scenario_id: StringName = scenario.scenario_id
		if seen_ids.has(scenario_id):
			errors.append("Scenario catalog contains duplicate scenario ID '%s'." % String(scenario_id))
		else:
			seen_ids[scenario_id] = true
	return errors


func get_scenario_by_id(scenario_id: StringName) -> ExperimentScenarioScript:
	for scenario: ExperimentScenarioScript in scenarios:
		if scenario != null and scenario.scenario_id == scenario_id:
			return scenario
	return null


func get_scenario_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for scenario: ExperimentScenarioScript in scenarios:
		if scenario != null:
			ids.append(scenario.scenario_id)
	return ids


static func validate_definition(scenario: ExperimentScenarioScript, world_catalog: WorldCatalog) -> Array[String]:
	var errors: Array[String] = []
	if scenario == null:
		errors.append("Scenario is null.")
		return errors
	if scenario.schema_version != ExperimentScenarioScript.CURRENT_SCHEMA_VERSION:
		errors.append("Unsupported scenario schema version: %d." % scenario.schema_version)
	if String(scenario.scenario_id).strip_edges().is_empty():
		errors.append("Scenario ID must not be empty.")
	if scenario.display_name.strip_edges().is_empty():
		errors.append("Scenario display name must not be empty.")
	if world_catalog == null or world_catalog.get_world_by_id(scenario.world_id) == null:
		errors.append("Scenario references unknown world ID '%s'." % String(scenario.world_id))
	if not ExperimentScenarioScript.TARGET_KINDS.has(scenario.target_kind):
		errors.append("Scenario target kind must be 'structure' or 'terrain'.")
	if not scenario.impact_offset.is_finite():
		errors.append("Scenario impact offset must contain finite values.")
	if not is_finite(scenario.blast_radius) or scenario.blast_radius < 0.5 or scenario.blast_radius > 12.0:
		errors.append("Scenario blast radius must be within 0.5..12.0.")
	if not is_finite(scenario.blast_damage) or scenario.blast_damage < 0.1 or scenario.blast_damage > 10.0:
		errors.append("Scenario blast damage must be within 0.1..10.0.")
	if not is_finite(scenario.blast_impulse) or scenario.blast_impulse < 1.0 or scenario.blast_impulse > 100.0:
		errors.append("Scenario blast impulse must be within 1.0..100.0.")
	if not is_finite(scenario.blast_upward_bias) or scenario.blast_upward_bias < 0.0 or scenario.blast_upward_bias > 1.0:
		errors.append("Scenario upward bias must be within 0.0..1.0.")
	if not is_finite(scenario.gravity) or scenario.gravity < 0.0 or scenario.gravity > 50.0:
		errors.append("Scenario gravity must be within 0.0..50.0.")
	if not is_finite(scenario.time_scale) or scenario.time_scale < 0.05 or scenario.time_scale > 10.0:
		errors.append("Scenario time scale must be within 0.05..10.0.")
	return errors
