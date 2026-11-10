# Terrain Prototype Architecture

**Status:** Resident prototype integrated into the gameplay scene. This is a bounded encounter patch, not a terrain streamer or a claim of production terrain performance.

## Decision

Use a chunked scalar density field with a deterministic tetrahedral isosurface mesher for the first vertical slice.

| Representation | Overhangs / caves | Local edit cost | Boundary handling | Decision |
|---|---|---|---|---|
| Heightfield | No | Low | Simple | Rejected: cannot represent caves or overhangs |
| Block voxels | Yes | Very low data edit | Exact grid alignment | Rejected for this slice: stair-step geometry conflicts with smooth crater intent |
| Density voxels + Marching Cubes | Yes | Bounded to affected cells/chunks | Shared samples and consistent edge interpolation | Strong long-term candidate; lookup table adds implementation/test surface |
| Density voxels + Marching Tetrahedra | Yes | Bounded to affected cells/chunks | Shared samples and fixed tetrahedral decomposition | Selected for a compact spike; higher triangle count is an explicit trade-off |

The data API is independent of the mesher so a later switch to Marching Cubes or Surface Nets does not invalidate chunk coordinates or edit history.

## Chunk contract

- Chunk coordinates are integer coordinates in a global chunk grid.
- Each chunk stores (cells + 1) scalar samples on every axis. The positive border sample is duplicated by neighboring chunks.
- Global sample coordinates map local samples to one global integer lattice. Adjacent chunks therefore address their shared border with identical global coordinates.
- Cell size maps the global sample lattice to world units.
- Density >= 0 is solid; density < 0 is empty.
- The prototype uses a fixed six-tetrahedra decomposition around the cube's 0-to-6 diagonal and deterministic edge interpolation.

## Collision constraints

The intended collision representation is one static concave trimesh per active chunk, not one world-sized trimesh and not concave shapes on moving rigid bodies. Godot 4.7 documents ConcavePolygonShape3D as the slowest 3D collision shape and warns that it is intended for static geometry; fast small bodies can tunnel through its hollow surface. Collision therefore needs a lower-resolution/near-player budget and bounded rebuild queue. If profiling shows trimesh cooking is too expensive, use a coarse collision field or static convex decomposition only where required.

## Threading and application

Density edits and mesh-array generation are CPU-side operations. Do not create or mutate scene nodes, physics shapes, or rendering resources from worker threads. Build results can be queued; apply mesh and collider replacements on the main thread. Collision replacement is routed through a bounded queue. Requests are coalesced by CollisionShape3D, so repeated edits before processing install only the latest mesh. The queue drains at most one request per physics frame by default, cooks a static trimesh on the main thread, and defers disabling/replacing/re-enabling the CollisionShape3D until after the active physics step.

## Runtime coordinator

`terrain/terrain_world.gd` (`class_name TerrainWorld`) owns a small resident patch: four chunks in a 2x2 XZ footprint with one vertical layer, built at chunk coordinate Y=0. The default profile uses 16-cell chunks with a 1.0 world-unit cell size; the low-end profile uses 8-cell chunks with a 2.0 cell size, keeping the same 32 x 32 world-unit footprint. The base field is a flat 1-unit-thick slab (`1.0 - local_y`) with its top surface at local Y=1.

- Each resident chunk has a `TerrainChunkData`, `MeshInstance3D`, `StaticBody3D`, and `CollisionShape3D`. Terrain bodies use collision layer 1 and the `terrain` group.
- Initial chunk meshes and colliders are built synchronously when the patch loads so gameplay does not start above missing collision.
- `carve_sphere(world_center, radius, strength)` converts the impact to local space, rejects edits outside the resident patch or beyond `max_edit_radius`/`max_dirty_chunks_per_edit`, appends one negative sphere edit, rebuilds only the intersected resident chunks' samples, and queues their meshes. A completed mesh rebuild queues the corresponding static trimesh collider.
- The main scene calls `carve_sphere` from its existing blast path. Terrain remains static; `BlastService` continues to apply impulses only to `blastable` rigid bodies. There is no second blast subsystem.
- `reset_terrain()` clears the edit journal and any pending rebuild requests, then synchronously rebuilds all resident chunk samples, meshes, and colliders. The gameplay reset input resets both the structure and the terrain.
- Edits, meshes, and collision replacement are bounded per frame, but the initial load build and reset build are synchronous. There is no background streaming or chunk eviction yet.

## Initial target budgets (hypotheses, not measured claims)

- Prototype chunk resolution: 16 cells per axis (4,913 samples).
- Maximum dirty chunks per one spherical edit: 8.
- Mesh rebuilds applied per frame: 1.
- Collision rebuilds applied per physics frame: 1.
- Collision only for chunks in the active interaction radius; distant chunks remain render-only.
- Low-end fallback: 8 cells per axis, larger cell size, and collision only around the active test area.

The default values are implemented in TerrainBudgetConfig and are enforced at edit acceptance, resident-chunk checks, the mesh queue, and the collision queue. The integrated patch uses four resident chunks by default (about 79 KiB of density payload at 16³) and four low-end chunks (about 12 KiB at 8³). The low-end profile reduces resolution to 8 cells per axis, resident chunks to 8, dirty chunks per edit to 4, edit radius to 6 world units, pending collision work to 2, and density memory to 4 MiB. The profile test records elapsed CPU mesh-build time, sample count, density payload bytes, vertex count, and estimated vertex payload bytes at 8³ and 16³ resolutions. Payload estimates exclude allocator, ArrayMesh, physics-cooking, and engine overhead; elapsed times from CI are not target-PC benchmarks.

These values are conservative starting limits, not validated GTX 1660 SUPER performance guarantees. Target-PC profiling and interactive visual checks remain required before treating them as performance claims.

## Current limitations

- The integrated patch is fixed and resident. There is no chunk streaming, eviction, LOD, or terrain larger than the 32 x 32 prototype footprint.
- The base field is a flat slab. There are no authored heightmaps, caves, overhangs, terrain materials, or biome blending in the scene yet.
- The edit journal is in-memory only. It has no disk persistence, versioning, undo history, or scenario serialization; callers must rebuild every affected chunk from the same deterministic base field and ordered journal.
- Initial load and reset rebuild all four resident chunks synchronously. Only per-edit mesh and collision work is frame-budgeted.
- Runtime collision uses one static concave trimesh per chunk. Automated tests check collider presence and rebuild agreement, but visual seam inspection, collider/mesh visual comparison, and high-speed rigid-body tunneling checks remain manual.
- CI profiling reports deterministic workload timings and estimated payload sizes only. It does not establish target-PC FPS/CPU/GPU performance.

## References

- Godot 4.7 ConcavePolygonShape3D: https://docs.godotengine.org/en/4.7/classes/class_concavepolygonshape3d.html
- Godot 4.7 Shape3D: https://docs.godotengine.org/en/4.7/classes/class_shape3d.html
- Godot 4.7 CSGShape3D: https://docs.godotengine.org/en/4.7/classes/class_csgshape3d.html
- Godot 4.7 SurfaceTool and clockwise front-face winding: https://docs.godotengine.org/en/4.7/classes/class_surfacetool.html
- Voxel Tools performance notes: https://voxel-tools.readthedocs.io/en/latest/performance/
