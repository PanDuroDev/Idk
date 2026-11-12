class_name StructuralSupportGraph
extends RefCounted
## Support rule: a cell stands on the cell below it, or bridges a gap when a
## supported cell is within MAX_BRIDGE_SPAN on both sides at the same height.
## Anything else has lost its load path and falls.

const MAX_BRIDGE_SPAN: int = 2
const BRIDGE_AXES: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]


static func find_supported_cells(
	cells: Array[Vector3i],
	broken_cells: Dictionary,
	grounded_bottom_cells: Dictionary = {},
	use_ground_support: bool = false
) -> Dictionary:
	var occupied: Dictionary = {}
	for cell: Vector3i in cells:
		if not broken_cells.has(cell):
			occupied[cell] = true

	var supported: Dictionary = {}
	for cell: Vector3i in occupied:
		if cell.y != 0:
			continue
		if use_ground_support and not grounded_bottom_cells.has(cell):
			continue
		supported[cell] = true

	var changed := true
	while changed:
		changed = false
		for cell: Vector3i in occupied:
			if supported.has(cell) or not supported.has(cell + Vector3i.DOWN):
				continue
			supported[cell] = true
			changed = true
		if _add_bridged_cells(occupied, supported):
			changed = true

	return supported


static func _add_bridged_cells(occupied: Dictionary, supported: Dictionary) -> bool:
	var added := false
	for cell: Vector3i in occupied:
		if supported.has(cell):
			continue
		for axis: Vector3i in BRIDGE_AXES:
			if not _is_bridged(cell, axis, occupied, supported):
				continue
			supported[cell] = true
			added = true
			break
	return added


static func _is_bridged(cell: Vector3i, axis: Vector3i, occupied: Dictionary, supported: Dictionary) -> bool:
	return _has_anchor(cell, axis, occupied, supported) and _has_anchor(cell, -axis, occupied, supported)


static func _has_anchor(cell: Vector3i, axis: Vector3i, occupied: Dictionary, supported: Dictionary) -> bool:
	for step in range(1, MAX_BRIDGE_SPAN + 1):
		var probe: Vector3i = cell + axis * step
		if not occupied.has(probe):
			return false
		if supported.has(probe):
			return true
	return false
