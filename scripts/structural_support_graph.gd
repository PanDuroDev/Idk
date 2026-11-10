class_name StructuralSupportGraph
extends RefCounted

const NEIGHBOR_OFFSETS: Array[Vector3i] = [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1)
]


static func find_supported_cells(cells: Array[Vector3i], broken_cells: Dictionary) -> Dictionary:
	var occupied: Dictionary = {}
	for cell: Vector3i in cells:
		if not broken_cells.has(cell):
			occupied[cell] = true

	var supported: Dictionary = {}
	var frontier: Array[Vector3i] = []

	for cell: Vector3i in cells:
		if cell.y == 0 and occupied.has(cell):
			supported[cell] = true
			frontier.append(cell)

	var frontier_index: int = 0
	while frontier_index < frontier.size():
		var current: Vector3i = frontier[frontier_index]
		frontier_index += 1

		for offset: Vector3i in NEIGHBOR_OFFSETS:
			var neighbor: Vector3i = current + offset
			if not occupied.has(neighbor) or supported.has(neighbor):
				continue
			supported[neighbor] = true
			frontier.append(neighbor)

	return supported
