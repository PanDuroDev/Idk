# WORLDBREAK

A real-time 3D planetary destruction sandbox built with Unreal Engine 5.8, C++, and Blueprints.

**Status:** early foundation, not yet a playable game.

## Vision
Explore multiple fictional worlds, trigger configurable impact events, and observe physical interactions, structural failure, terrain changes, and environmental aftermath. The project prioritizes repeatable experiments and believable effects over claiming scientifically exact weapon simulation.

## Stack
- Unreal Engine 5.8 stable baseline
- C++ for runtime systems and performance-sensitive logic
- Blueprints for rapid iteration and level composition
- Chaos Physics / Chaos Destruction for rigid bodies and authored fracture
- Niagara for dust, smoke, fire, debris visuals, and atmosphere
- World Partition / Data Layers for large environments
- PCG for procedural placement
- Landscape for the first terrain prototype; custom chunked terrain for runtime cratering
- Fab / Quixel and Poly Haven for licensed assets

## Hardware target
The first target is a mid-range PC with a 6 GB GPU. Conventional raster rendering is the baseline. Lumen, ray tracing, high-end volumetrics, and expensive simulation settings must remain optional.

## Getting started
1. Install Unreal Engine 5.8.
2. Clone the repository.
3. Generate project files from Worldbreak.uproject or open it directly.
4. Build WorldbreakEditor using Visual Studio 2022 with the Game development with C++ workload.

## Current foundation
AWorldbreakBlastActor is a generic Blueprint-callable physics test actor. It applies a configurable radial impulse to nearby simulating physics bodies and can optionally dispatch Unreal radial damage. It is not a complete weapon system.

## Asset policy
Record the source and license of every external asset. Fab / Quixel assets require per-asset license checks. Poly Haven assets are CC0. Do not commit marketplace packs or assets with unclear redistribution rights.

## Documentation
- docs/TECHNICAL_DIRECTION.md
- docs/ROADMAP.md
- docs/ASSET_CREDITS.md

This is a fictional entertainment simulation project, not real-world weapon engineering or operational modeling.
