class_name BuildingCellDefinition
extends Resource

@export var coordinate: Vector3i = Vector3i.ZERO
@export var material_profile: DestructionMaterialProfile
@export var use_custom_transform: bool = false
@export var local_transform: Transform3D = Transform3D.IDENTITY
