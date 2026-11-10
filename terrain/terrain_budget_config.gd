class_name TerrainBudgetConfig
extends Resource
## Conservative, inspectable limits for the isolated terrain prototype.

@export_range(4, 32, 1) var chunk_resolution: int = 16
@export_range(1, 128, 1) var max_resident_chunks: int = 32
@export_range(1, 32, 1) var max_dirty_chunks_per_edit: int = 8
@export var max_edit_radius: float = 12.0
@export_range(1, 8, 1) var max_mesh_rebuilds_per_frame: int = 1
@export_range(1, 8, 1) var max_collision_rebuilds_per_physics_frame: int = 1
@export_range(1, 32, 1) var max_pending_collision_rebuilds: int = 8
@export_range(1, 256, 1) var max_density_memory_mib: int = 16

func validate_limits() -> PackedStringArray:
	var errors := PackedStringArray()
	if chunk_resolution < 4 or chunk_resolution > 32:
		errors.append("chunk_resolution must be between 4 and 32")
	if max_resident_chunks < 1:
		errors.append("max_resident_chunks must be positive")
	if max_dirty_chunks_per_edit < 1 or max_dirty_chunks_per_edit > max_resident_chunks:
		errors.append("max_dirty_chunks_per_edit must be positive and no greater than max_resident_chunks")
	if max_edit_radius <= 0.0:
		errors.append("max_edit_radius must be positive")
	if max_mesh_rebuilds_per_frame < 1:
		errors.append("max_mesh_rebuilds_per_frame must be positive")
	if max_collision_rebuilds_per_physics_frame < 1:
		errors.append("max_collision_rebuilds_per_physics_frame must be positive")
	if max_pending_collision_rebuilds < 1:
		errors.append("max_pending_collision_rebuilds must be positive")
	if max_density_memory_mib < 1:
		errors.append("max_density_memory_mib must be positive")
	return errors

func accepts_edit(radius: float, affected_chunk_count: int) -> bool:
	return validate_limits().is_empty() and radius > 0.0 and radius <= max_edit_radius and affected_chunk_count > 0 and affected_chunk_count <= max_dirty_chunks_per_edit

func can_reside(current_chunks: int, additional_chunks: int = 1) -> bool:
	return validate_limits().is_empty() and current_chunks >= 0 and additional_chunks >= 0 and current_chunks + additional_chunks <= max_resident_chunks

func estimated_density_bytes(chunk_count: int) -> int:
	if chunk_count <= 0 or chunk_resolution <= 0:
		return 0
	var samples_per_axis := chunk_resolution + 1
	return samples_per_axis * samples_per_axis * samples_per_axis * 4 * chunk_count

func within_density_memory_budget(chunk_count: int) -> bool:
	return estimated_density_bytes(chunk_count) <= max_density_memory_mib * 1024 * 1024

func configure_collision_queue(queue: TerrainCollisionQueue) -> void:
	queue.max_rebuilds_per_physics_frame = maxi(1, max_collision_rebuilds_per_physics_frame)
	queue.max_pending_collision_rebuilds = maxi(1, max_pending_collision_rebuilds)

static func low_end_fallback() -> TerrainBudgetConfig:
	var profile := TerrainBudgetConfig.new()
	profile.chunk_resolution = 8
	profile.max_resident_chunks = 8
	profile.max_dirty_chunks_per_edit = 4
	profile.max_edit_radius = 6.0
	profile.max_mesh_rebuilds_per_frame = 1
	profile.max_collision_rebuilds_per_physics_frame = 1
	profile.max_pending_collision_rebuilds = 2
	profile.max_density_memory_mib = 4
	return profile
