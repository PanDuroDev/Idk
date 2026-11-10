class_name DestructionMaterialProfile
extends Resource

@export var material_id: StringName = &"masonry"
@export var display_name: String = "Masonry"
@export_range(0.1, 100.0, 0.1) var integrity: float = 1.0
@export_range(0.1, 10.0, 0.05) var blast_resistance: float = 1.0
@export_range(0.1, 10.0, 0.05) var density_multiplier: float = 1.0
@export var surface_color: Color = Color(0.42, 0.44, 0.48, 1.0)


func create_surface_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = surface_color
	material.roughness = 0.84
	return material
