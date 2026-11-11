class_name ExperimentHistory
extends RefCounted
## Bounded run history for repeatable experiments, with JSON and CSV export.
## Export writes a temporary file, re-reads it, then replaces the destination.

const FORMAT: String = "worldbreak.experiment-history"
const CURRENT_SCHEMA_VERSION: int = 1
const MAX_RUNS: int = 50
const CSV_COLUMNS: Array[String] = [
	"run_index", "scenario_id", "world_id", "target_kind", "building_definition_id",
	"material_override_id", "material_profile_ids",
	"impact_x", "impact_y", "impact_z", "blast_radius", "blast_damage",
	"blast_impulse", "blast_upward_bias", "gravity", "time_scale",
	"broken", "released", "active_loose", "sleeping_loose", "moved_fragments",
	"settle_frames", "settled", "terrain_edits", "elapsed_usec", "fps_sample"
]

var _runs: Array[Dictionary] = []


func add_run(record: Dictionary) -> Dictionary:
	var stored: Dictionary = record.duplicate(true)
	stored["run_index"] = _runs.size() + 1
	_runs.append(stored)
	if _runs.size() > MAX_RUNS:
		_runs.pop_front()
		for index in range(_runs.size()):
			_runs[index]["run_index"] = index + 1
	return stored


func get_runs() -> Array[Dictionary]:
	return _runs.duplicate(true)


func get_run_count() -> int:
	return _runs.size()


func get_last_run() -> Dictionary:
	return {} if _runs.is_empty() else _runs[_runs.size() - 1].duplicate(true)


func clear() -> void:
	_runs.clear()


func get_comparison() -> Dictionary:
	if _runs.size() < 2:
		return {"has_comparison": false}
	var previous: Dictionary = _runs[_runs.size() - 2]
	var latest: Dictionary = _runs[_runs.size() - 1]
	return {
		"has_comparison": true,
		"previous_run_index": int(previous.get("run_index", 0)),
		"latest_run_index": int(latest.get("run_index", 0)),
		"broken_delta": int(latest.get("broken", 0)) - int(previous.get("broken", 0)),
		"released_delta": int(latest.get("released", 0)) - int(previous.get("released", 0)),
		"moved_fragments_delta": int(latest.get("moved_fragments", 0)) - int(previous.get("moved_fragments", 0)),
		"terrain_edit_delta": int(latest.get("terrain_edits", 0)) - int(previous.get("terrain_edits", 0)),
		"elapsed_usec_delta": int(latest.get("elapsed_usec", 0)) - int(previous.get("elapsed_usec", 0))
	}


func to_dictionary() -> Dictionary:
	return {
		"format": FORMAT,
		"schema_version": CURRENT_SCHEMA_VERSION,
		"runs": get_runs()
	}


func to_json_text() -> String:
	return JSON.stringify(to_dictionary(), "\t", true)


func to_csv_text() -> String:
	var header := ""
	for index in range(CSV_COLUMNS.size()):
		if index > 0:
			header += ","
		header += CSV_COLUMNS[index]
	var lines: Array[String] = [header]
	for run: Dictionary in _runs:
		var impact: Dictionary = run.get("impact", {})
		var position: Variant = impact.get("position", [0.0, 0.0, 0.0])
		var cells: Array[String] = [
			str(run.get("run_index", 0)),
			_csv(run.get("scenario_id", "")),
			_csv(run.get("world_id", "")),
			_csv(run.get("target_kind", "")),
			_csv(run.get("building_definition_id", "")),
			_csv(run.get("material_override_id", "")),
			_csv(_material_ids(run.get("material_profile_ids", []))),
			str(position[0]), str(position[1]), str(position[2]),
			str(impact.get("radius", 0.0)),
			str(impact.get("damage", 0.0)),
			str(impact.get("impulse", 0.0)),
			str(impact.get("upward_bias", 0.0)),
			str(run.get("gravity", 0.0)),
			str(run.get("time_scale", 1.0)),
			str(run.get("broken", 0)),
			str(run.get("released", 0)),
			str(run.get("active_loose", 0)),
			str(run.get("sleeping_loose", 0)),
			str(run.get("moved_fragments", 0)),
			str(run.get("settle_frames", 0)),
			str(run.get("settled", false)),
			str(run.get("terrain_edits", 0)),
			str(run.get("elapsed_usec", 0)),
			str(run.get("fps_sample", 0.0))
		]
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"


func save_json(path: String) -> Dictionary:
	if not path.to_lower().ends_with(".json"):
		return {"ok": false, "errors": ["Experiment history JSON files must use the .json extension."]}
	return _write_text(path, to_json_text())


func save_csv(path: String) -> Dictionary:
	if not path.to_lower().ends_with(".csv"):
		return {"ok": false, "errors": ["Experiment history CSV files must use the .csv extension."]}
	return _write_text(path, to_csv_text())


static func _write_text(path: String, payload: String) -> Dictionary:
	var errors: Array[String] = []
	var temp_path: String = path + ".tmp"
	var directory: String = path.get_base_dir()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if directory_error != OK:
		errors.append("Could not create export directory '%s' (error %d)." % [directory, directory_error])
		return {"ok": false, "errors": errors}

	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		errors.append("Could not open export file for writing: %s" % temp_path)
		return {"ok": false, "errors": errors}
	file.store_string(payload)
	file.flush()
	file.close()

	var verify_file: FileAccess = FileAccess.open(temp_path, FileAccess.READ)
	if verify_file == null or verify_file.get_as_text() != payload:
		if verify_file != null:
			verify_file.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		errors.append("Export file could not be verified after writing.")
		return {"ok": false, "errors": errors}
	verify_file.close()

	var rename_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path),
		ProjectSettings.globalize_path(path)
	)
	if rename_error != OK:
		errors.append("Could not replace export destination '%s' (error %d)." % [path, rename_error])
		return {"ok": false, "errors": errors}
	return {"ok": true, "errors": errors}


static func _material_ids(value: Variant) -> String:
	if not value is Array:
		return ""
	var parts: PackedStringArray = []
	for item in value:
		parts.append(str(item))
	return ";".join(parts)


static func _csv(value: Variant) -> String:
	var text: String = str(value)
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"" + text.replace("\"", "\"\"") + "\""
	return text
