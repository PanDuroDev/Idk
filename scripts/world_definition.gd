class_name WorldDefinition
extends Resource
## Versioned world preset. Building, material, impact, gravity, and time
## settings stay in the referenced SimulationConfiguration JSON; this resource
## only adds environment, spawn, and terrain presentation.

const CURRENT_SCHEMA_VERSION: int = 1

@export var schema_version: int = CURRENT_SCHEMA_VERSION
@export var world_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_file("*.json") var simulation_configuration_path: String = ""
@export var player_spawn: Vector3 = Vector3(0.0, 0.1, 6.0)
@export var background_color: Color = Color(0.035, 0.045, 0.06)
@export var ambient_color: Color = Color(0.55, 0.59, 0.68)
@export_range(0.0, 4.0, 0.05) var ambient_energy: float = 0.7
@export var sun_rotation_degrees: Vector3 = Vector3(-52.0, -28.0, 0.0)
@export_range(0.0, 8.0, 0.05) var sun_energy: float = 1.25
@export var sun_shadows_enabled: bool = true
@export var terrain_enabled: bool = true
@export var terrain_position: Vector3 = Vector3(0.0, -1.05, 0.0)
@export_range(1, 8, 1) var terrain_chunk_radius: int = 2
@export var terrain_surface_color: Color = Color(0.26, 0.31, 0.25)
@export var terrain_low_end_fallback: bool = false
