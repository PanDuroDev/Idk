# Terrain Prototype Architecture

**Status:** Isolated research/prototype. Not connected to the gameplay scene.

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

## Initial target budgets (hypotheses, not measured claims)

- Prototype chunk resolution: 16 cells per axis (4,913 samples).
- Maximum dirty chunks per one spherical edit: 8.
- Mesh rebuilds applied per frame: 1.
- Collision rebuilds applied per physics frame: 1.
- Collision only for chunks in the active interaction radius; distant chunks remain render-only.
- Low-end fallback: 8 cells per axis, larger cell size, and collision only around the active test area.

The default values are implemented in TerrainBudgetConfig and are enforced at edit acceptance, resident-chunk checks, the mesh queue, and the collision queue. The low-end profile reduces resolution to 8 cells per axis, resident chunks to 8, dirty chunks per edit to 4, edit radius to 6 world units, pending collision work to 2, and density memory to 4 MiB. The profile test records elapsed CPU mesh-build time, sample count, density payload bytes, vertex count, and estimated vertex payload bytes at 8³ and 16³ resolutions. Payload estimates exclude allocator, ArrayMesh, physics-cooking, and engine overhead; elapsed times from CI are not target-PC benchmarks.

These values are conservative starting limits, not validated GTX 1660 SUPER performance guarantees. Target-PC profiling and interactive visual checks remain required before gameplay integration.

## Current limitations

- No gameplay integration or BlastService adapter; Phase 1/2 runtime contracts are not stable.
- The world-space sphere edit journal is in-memory only. It has no disk persistence, versioning, or undo history; callers must rebuild every affected chunk from the same deterministic base field and ordered journal.
- There is no end-to-end terrain coordinator yet. The edit journal, mesh rebuild queue, and collision rebuild queue are separate components; callers still own orchestration and chunk lifetime.
- There is no terrain chunk streaming/residency manager, material mapping, or runtime chunk-scene factory. Budget helpers expose and validate limits but do not implement a full world streamer.
- Automated tests verify numeric shared-face vertex agreement, but visual seam inspection, collider/mesh visual comparison, and high-speed rigid-body tunneling checks remain manual.
- CI profiling reports deterministic workload timings and estimated payload sizes only. It does not establish target-PC FPS/CPU/GPU performance.

## References

- Godot 4.7 ConcavePolygonShape3D: https://docs.godotengine.org/en/4.7/classes/class_concavepolygonshape3d.html
- Godot 4.7 Shape3D: https://docs.godotengine.org/en/4.7/classes/class_shape3d.html
- Godot 4.7 CSGShape3D: https://docs.godotengine.org/en/4.7/classes/class_csgshape3d.html
- Godot 4.7 SurfaceTool and clockwise front-face winding: https://docs.godotengine.org/en/4.7/classes/class_surfacetool.html
- Voxel Tools performance notes: https://voxel-tools.readthedocs.io/en/latest/performance/
