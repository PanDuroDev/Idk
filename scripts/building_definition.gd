class_name BuildingDefinition
extends Resource

const BuildingCellDefinitionScript = preload("res://scripts/building_cell_definition.gd")
const DestructionMaterialProfileScript = preload("res://scripts/destruction_material_profile.gd")

const CURRENT_SCHEMA_VERSION: int = 1

@export var schema_version: int = CURRENT_SCHEMA_VERSION
@export var definition_id: StringName = &""
@export var display_name: String = ""
@export var dimensions: Vector3i = Vector3i.ONE
@export var cell_size: Vector3 = Vector3.ONE
@export var cell_spacing: Vector3 = Vector3.ONE
@export var origin_offset: Vector3 = Vector3.ZERO
@export var default_material_profile: DestructionMaterialProfile
@export var cells: Array[BuildingCellDefinition] = []


func get_cell_material_profile(cell: BuildingCellDefinition) -> DestructionMaterialProfile:
	if cell == null:
		return null
	return cell.material_profile if cell.material_profile != null else default_material_profile


func get_cell_local_transform(cell: BuildingCellDefinition) -> Transform3D:
	if cell == null:
		return Transform3D.IDENTITY
	if cell.use_custom_transform:
		return cell.local_transform

	var coordinate: Vector3 = Vector3(
		float(cell.coordinate.x) * cell_spacing.x,
		float(cell.coordinate.y) * cell_spacing.y,
		float(cell.coordinate.z) * cell_spacing.z
	)
	return Transform3D(Basis.IDENTITY, origin_offset + coordinate)


func get_occupied_cell_count() -> int:
	return cells.size()
