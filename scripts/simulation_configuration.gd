class_name SimulationConfiguration
extends Resource
## Portable, versioned test configuration. Building and material data stay in
## their native Resources; this file only references their stable IDs.

const SimulationMaterialOverrideScript = preload("res://scripts/simulation_material_override.gd")

const CURRENT_SCHEMA_VERSION: int = 1

@export var schema_version: int = CURRENT_SCHEMA_VERSION
@export var configuration_id: StringName = &""
@export var display_name: String = ""
@export var building_definition_id: StringName = &"classic_70_piece"
@export var building_transform: Transform3D = Transform3D.IDENTITY
@export var material_overrides: Array[SimulationMaterialOverrideScript] = []
@export_range(0.5, 12.0, 0.25) var blast_radius: float = 4.5
@export_range(0.1, 10.0, 0.1) var blast_damage: float = 4.0
@export_range(1.0, 100.0, 1.0) var blast_impulse: float = 22.0
@export_range(0.0, 1.0, 0.05) var blast_upward_bias: float = 0.3
@export_range(0.0, 50.0, 0.1) var gravity: float = 9.8
@export_range(0.05, 10.0, 0.05) var time_scale: float = 1.0
