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

These are starting guardrails, not validated performance numbers. PR 4 must replace or justify them using repeatable measurements.

## Current limitations

- No gameplay integration or BlastService adapter; Phase 1/2 contracts are not stable.
- No persistent global density/edit ledger yet; duplicated border values are only guaranteed when the same values are supplied to both chunks.
- No deformation queue, collision body, save/reset, material mapping, or profiling harness yet.
- Headless tests cannot establish visual seam quality or target-PC performance.

## References

- Godot 4.7 ConcavePolygonShape3D: https://docs.godotengine.org/en/4.7/classes/class_concavepolygonshape3d.html
- Godot 4.7 Shape3D: https://docs.godotengine.org/en/4.7/classes/class_shape3d.html
- Godot 4.7 CSGShape3D: https://docs.godotengine.org/en/4.7/classes/class_csgshape3d.html
- Voxel Tools performance notes: https://voxel-tools.readthedocs.io/en/latest/performance/
