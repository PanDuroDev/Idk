# Technical Direction

## Product
Worldbreak is a first-person 3D sandbox for exploring impact, structural failure, environmental response, and aftermath across fictional worlds. It is not a scientifically exact nuclear-effects simulator. The focus is convincing physical and visual feedback, player control, repeatable scenarios, and performance.

## Engine and code
Unreal Engine 5.8 is the stable baseline. C++ owns reusable runtime systems and performance-sensitive logic. Blueprints handle level scripting, rapid prototyping, and presentation wiring. Data Assets and Data Tables will define worlds, impact presets, material responses, and scenarios. Python is not a runtime dependency.

## Simulation boundaries
A blast is a gameplay event with a location, radius, intensity, and response profile. It dispatches to independent systems:
- rigid-body impulse and gameplay damage;
- structural fracture and collapse;
- terrain deformation requests;
- dust, debris, heat-haze, flash, and audio presentation;
- telemetry and replay markers.

The initial code uses Chaos rigid-body physics and a generic radial impulse actor. It does not claim to model real blast-wave propagation.

## Structural destruction
Use Chaos Geometry Collections for authored destructible props and buildings. Fracture patterns, cluster hierarchy, connection constraints, and damage thresholds are authored per asset. Detailed simulation activates near relevant events; distant structures use simplified representations.

## Terrain deformation
Landscape is suitable for the first static terrain prototype, but not arbitrary runtime cratering. The planned direction is chunked, locally deformable terrain with bounded editable regions, chunk-level collision rebuilds, level of detail, and deformation data stored separately from render meshes.

A planetary surface needs spherical coordinates or a cube-sphere/tiled representation. It must not be one enormous high-resolution mesh.

## Multiple worlds
Each world is a profile and content set defining identity, gravity, atmosphere, terrain seed, biome rules, streaming bounds, quality budget, and scenarios. World Partition and Data Layers are candidates for large terrestrial environments. A spherical world needs a dedicated streaming strategy.

## Visuals
Niagara handles event-driven dust, smoke, sparks, debris trails, fire, and atmospheric effects. Visual scale is separate from physical scale: a large cloud does not require millions of simulated particles.

## Performance
The first target is a 6 GB GPU. Conventional raster rendering is the baseline; Lumen, hardware ray tracing, and Nanite are not mandatory.
- Use instancing and hierarchical LODs.
- Activate physics based on distance and relevance.
- Bound debris counts and lifetimes.
- Run terrain work asynchronously where possible.
- Pool transient actors.
- Profile before adding complexity.

## Assets
Use Fab / Quixel Megascans for scanned environment assets after checking each asset's Fab license. Poly Haven provides CC0 HDRIs, textures, and models. Custom destructible structures and terrain materials should be authored where controlled topology is needed. Record all external content in docs/ASSET_CREDITS.md.

## First vertical slice
One compact test range: player movement, a small authored destructible structure, physics props, one configurable impact event, dust/debris feedback, repeatable reset, and basic performance counters. Expand to deformable terrain and multiple worlds only after this slice is stable.
