@tool
extends Node3D

const DestructionMaterialProfileScript = preload("res://scripts/destruction_material_profile.gd")
const BuildingDefinitionValidatorScript = preload("res://scripts/building_definition_validator.gd")

@export var material_profile: DestructionMaterialProfileScript:
	set(value):
		material_profile = value
		_refresh_preview()

@onready var _preview_mesh: MeshInstance3D = $PreviewMesh
@onready var _preview_label: Label3D = $PreviewLabel


func _ready() -> void:
	_refresh_preview()


func _refresh_preview() -> void:
	if not is_node_ready():
		return
	if not is_instance_valid(_preview_mesh) or not is_instance_valid(_preview_label):
		return

	if material_profile == null:
		_preview_mesh.material_override = null
		_preview_label.text = "Assign a DestructionMaterialProfile"
		return

	var errors: Array[String] = BuildingDefinitionValidatorScript.validate_material_profile(material_profile)
	_preview_mesh.material_override = material_profile.create_surface_material()
	if errors.is_empty():
		_preview_label.text = "%s\n%s\nIntegrity %.2f | Resistance %.2f | Density %.2f" % [
			material_profile.display_name,
			String(material_profile.material_id),
			material_profile.integrity,
			material_profile.blast_resistance,
			material_profile.density_multiplier
		]
	else:
		_preview_label.text = "INVALID PROFILE: %s\n%s" % [
			String(material_profile.material_id),
			"\n".join(errors)
		]
