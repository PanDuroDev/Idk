class_name BuildingCellDefinition
extends Resource

const DestructionMaterialProfileScript = preload("res://scripts/destruction_material_profile.gd")

@export var coordinate: Vector3i = Vector3i.ZERO
@export var material_profile: DestructionMaterialProfileScript
@export var use_custom_transform: bool = false
@export var local_transform: Transform3D = Transform3D.IDENTITY
