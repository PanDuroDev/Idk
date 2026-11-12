# Manual Windows Validation

This checklist covers the interactive checks that GitHub Actions cannot perform. It is intended for the target Windows PC with the GTX 1660 SUPER.

## 1. Setup and startup

- Open `project.godot` with the standard Godot **4.7.2 stable** editor.
- Confirm the project uses the Compatibility renderer.
- Press **F5** to run the main scene.
- Confirm the arena, first-person player, 70-piece structure, six physics props, and HUD appear.
- Check the Output and Debugger panels for script errors, parse errors, or repeated physics warnings.

## 2. Controls

- **WASD:** move.
- **Mouse:** look around; check that pitch stops before flipping over.
- **Space:** jump and land on the ground.
- **Left mouse button / F:** trigger an impact while the mouse is captured.
- **Escape:** release or recapture the mouse. When the mouse is visible, the first impact key press recaptures it; press again to fire.
- **R:** reset the destructible structure.

Verify that the HUD counters change after an impact and return to zero after resetting the structure.

## 3. Runtime impact controls

- Use the on-screen Simulation Control panel to adjust blast radius, damage, physical impulse, gravity, and time scale independently.
- Confirm each value changes in the panel and affects subsequent impacts without changing the other settings.
- Load a scenario and confirm its impact/gravity/time-scale values are applied; **Reset world** restores structure/terrain/player state without inventing new impact defaults.
- Verify values cannot move outside radius 0.5-12.0, damage 0.1-10.0, impulse 1.0-100.0, gravity 0.0-50.0, and time scale 0.05-10.0.

## 4. Compare the three material thresholds

For a controlled comparison, change the running scene's exported values through the Remote Inspector:

1. Run the game with F5.
2. In the Scene dock, select **Remote**, then select the root node **Main**.
3. In the Inspector set:
   - `blast_radius = 1.0`
   - `blast_damage = 0.5`
   - `blast_impulse = 1.0`
4. Aim at the center of the front face of one block. Fire once at a time, waiting between shots, and count the hits until that block breaks.
5. Press **R** between material trials so each begins from a clean structure.

Approximate hit counts for a hit at the exact center of the front face are:

| Material | Integrity | Blast resistance | Approximate hits |
|---|---:|---:|---:|
| Lightweight Panel | 0.65 | 0.8 | 3 |
| Masonry | 1.0 | 1.0 | 4 |
| Foundation Concrete | 1.6 | 1.2 | 8 |

These estimates use the current linear distance falloff and a 0.5 m distance from the front face to the block center. Actual counts can be higher if the impact lands away from the face center. This is a tuning comparison, not a claim that the values represent real construction materials.

## 5. Full collapse and reset

In the Remote Inspector for **Main**, set:

- `blast_radius = 4.5`
- `blast_damage = 10.0`
- `blast_impulse = 22.0`

Aim at the center of the front face of a block in the foundation row and trigger an impact. Observe whether the foundation row breaks and the remaining structure loses support.

Check the following:

- Loose fragments rise to 70/70 after full release.
- Fragments fall onto the ground without passing through it.
- No fragment has an obviously invalid transform, launches far outside the arena, or jitters continuously after settling.
- Wait at least 30 seconds to observe long-duration settling.
- Press **R** and confirm that all 70 structure fragments return to their starting positions and the HUD's Broken/Loose/Unsupported counters clear.

Repeat the collapse/reset cycle five times and note any change in behavior.

## 6. Debris lifecycle and budgets

- Trigger a full collapse and confirm all released fragments remain visible and settle naturally.
- Confirm the structure reports active and sleeping loose fragments separately and that active fragments never exceed the configured budget (default 70).
- Leave released debris for at least 30 seconds and confirm only released fragments are retired; supported intact blocks must remain visible and unchanged.
- Trigger another impact against sleeping debris and confirm it wakes and responds.
- Press **R** after some debris has expired. All 70 original blocks, transforms, collision, and support state must return.
- Repeat collapse, expiry, and reset at least five times. Record observations; do not infer a performance improvement without measurements.

## 7. Effects and diagnostics

- Trigger individual and repeated impacts. Confirm a restrained dust/debris burst appears at the impact point and fades within about half a second.
- Trigger more than eight impacts in quick succession. Confirm effect count remains capped and older bursts are discarded without errors.
- Confirm the regular HUD remains unchanged by default.
- Press **F3** to show diagnostics and again to hide them. Check intact/broken/supported/loose/awake/sleeping/retired counts, configured budgets, impact settings, FPS, physics object count, and collision pairs.
- Confirm the overlay remains opt-in after resetting the structure.

## 8. Performance observations

Use the HUD FPS counter and Windows Task Manager while the game is running. Record:

| Measurement | Result |
|---|---|
| Idle FPS after 30 seconds | |
| Lowest observed FPS during full collapse | |
| FPS 15 seconds after collapse | |
| Approximate CPU usage during collapse | |
| Approximate GPU 3D usage during collapse | |
| GPU memory usage during collapse | |
| Any freezes, stutters, or abnormal fragment motion | |

Do not treat a single FPS reading as a benchmark. Record the resolution, graphics settings, and whether the measurement was taken during idle, active collapse, or after settling.

## 9. Simulation tools and experiments

- Confirm the Simulation Control panel is visible and readable at the target resolution.
- Select each world preset and confirm the environment, structure, terrain, and spawn change without errors.
- Select each scenario, press **Run scenario (settled)**, and confirm the status label reports settled broken/loose/terrain counts, awake/sleeping/moved bodies, settle frames, and elapsed time.
- Run the same scenario twice and confirm the comparison line appears; repeat after **Reset world** and check the initial state is restored.
- Select a material preset, confirm the structure tint/mass behavior changes, then select `default` and confirm the original materials return.
- Press **P** or the Pause button during debris motion; confirm physics stops while the panel remains usable, then resume.
- Export JSON and CSV after several runs. Open both files and confirm they contain run indexes, scenario/world/building/material IDs, impact settings, settled outcome fields, counts, and timing fields. Treat elapsed time, FPS, and settled physics counts as non-deterministic observations, not reproducibility guarantees.
- Confirm unsupported export extensions are rejected and failed writes do not replace an existing export file.

## 10. Presentation: explosions, ground, rocket, cameras

- Fire at the ground away from the structure and confirm the whole arena floor can be carved; the crater should persist until **Reset world**.
- Fire near the structure and confirm the floor is carveable beneath it; loose debris may settle into the crater but must not fall through the world.
- Confirm each impact shows a bright core flash, an expanding ground ring, dust, and debris chips, and that repeated impacts do not keep stale effects alive.
- Fire at the structure and confirm the floor under it is carved as well, not only the structure itself.
- Confirm the blast tool detonates instantly at the aim point instead of launching a rocket from the camera.
- Confirm the HUD and control panel use the dark theme, the crosshair remains visible as the aim reticle in every camera mode, and the panel stays anchored top-right after resizing the window.
- Confirm the game opens maximized and fills the display; resize the window and switch aspect ratios, then confirm the HUD stays top-left, the Simulation panel stays top-right, and the hint line stays centered at the bottom without overlap.
- Confirm the Simulation panel is compact (about 300 px wide on a 1920-wide window), ends below its status line instead of running to the bottom edge, and shows a thin rounded scrollbar only if the content needs scrolling.
- Run a settled scenario and confirm damage, crater, chips, and shake are applied immediately with no flying rocket.
- Use the panel Camera row and the **C** key to switch between first person, orbit, and overview. Confirm orbit rotates on right-drag and zooms with the wheel, overview pans on right-drag and zooms with the wheel, WASD does not move the player outside first person, and switching back to first person restores movement/aiming.
- In orbit and overview, fire the blast tool and throw a carried rocket. Confirm the impact or throw starts from the camera view rather than the player's position.
- Record any visual artifacts, camera clipping, or frame-rate drops seen with the new effects.

## 11. Sandbox: spawn menu, carrying, and thrown rockets

- Press **Tab** and confirm the spawn menu opens with a prop grid and that the mouse cursor becomes visible; press Tab again to close and recapture the mouse.
- Spawn each prop type and confirm it appears in front of the player on the ground, is stable, and has a sensible size and collision.
- Look at a prop and press **E**; confirm it is carried in front of the camera, cannot be pushed through the player, and that **E** drops it.
- Carry a prop and click; confirm it is thrown in the look direction with the player's momentum and that the blast tool does not also fire.
- Throw a rocket at a solid wall, the structure, or the ground and confirm a real collision triggers crater, structure damage, chips, and shake. Throw one at nothing and confirm it does not explode mid-air; the rocket must not detonate merely because it was thrown.
- Confirm two starter rockets rest on the ground near the active world's player spawn and reappear after **Reset world**.
- Spawn an extra prop, switch between both world presets, and confirm old props are removed and exactly two starter rockets appear near each new spawn point. Unload the world and confirm no spawned props remain; load a world again and confirm its two starter rockets return.
- Confirm the spawned-prop count stops at 24, including the two starter rockets.
- Record any prop clipping, unstable jitter, missing detonation, or frame drops while carrying.

## 12. Report the result

Record the Godot version, Windows version, whether any errors appeared, the three material hit counts, the number of successful collapse/reset cycles, and the performance table above. Keep screenshots or a short recording of any failure. Do not mark interactive validation complete until these observations have been reviewed.
