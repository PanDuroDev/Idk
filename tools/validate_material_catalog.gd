@tool
extends EditorScript

const MaterialProfileCatalogScript = preload("res://scripts/material_profile_catalog.gd")
const MATERIAL_CATALOG: MaterialProfileCatalogScript = preload("res://resources/materials/material_profile_catalog.tres")


func _run() -> void:
	var errors: Array[String] = MATERIAL_CATALOG.validate_catalog()
	if not errors.is_empty():
		for error_text: String in errors:
			push_error("Material catalog validation: " + error_text)
		return

	print(
		"WORLDBREAK_MATERIAL_CATALOG_OK: profiles=%d"
		% MATERIAL_CATALOG.profiles.size()
	)
