class_name ExperimentScenario
extends Resource
## Versioned, reusable experiment preset. A scenario selects a world and an
## impact anchor relative to the world's structure or terrain patch, then
## applies fixed blast, gravity, and time-scale settings.

const FORMAT: String = "worldbreak.experiment-scenario"
const CURRENT_SCHEMA_VERSION: int = 1
const TARGET_KINDS: Array[StringName] = [&"structure", &"terrain"]

@export var schema_version: int = CURRENT_SCHEMA_VERSION
@export var scenario_id: StringName = &""
@export var display_name: String = ""
@export var world_id: StringName = &"classic_yard"
@export var target_kind: StringName = &"structure"
@export var impact_offset: Vector3 = Vector3(0.0, 0.5, 0.52)
@export_range(0.5, 12.0, 0.25) var blast_radius: float = 4.5
@export_range(0.1, 10.0, 0.1) var blast_damage: float = 10.0
@export_range(1.0, 100.0, 1.0) var blast_impulse: float = 22.0
@export_range(0.0, 1.0, 0.05) var blast_upward_bias: float = 0.3
@export_range(0.0, 50.0, 0.5) var gravity: float = 9.8
@export_range(0.05, 10.0, 0.05) var time_scale: float = 1.0
