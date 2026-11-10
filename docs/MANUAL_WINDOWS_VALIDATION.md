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

- Use the on-screen Impact Settings panel to adjust blast radius, damage, and physical impulse independently.
- Confirm each value changes in the panel and affects subsequent impacts without changing the other settings.
- Press **Reset impact defaults** and confirm the values return to radius 4.5, damage 4.0, and impulse 22.0.
- Verify values cannot move outside radius 0.5-12.0, damage 0.1-10.0, and impulse 1.0-100.0.

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

## 6. Performance observations

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

## 7. Report the result

Record the Godot version, Windows version, whether any errors appeared, the three material hit counts, the number of successful collapse/reset cycles, and the performance table above. Keep screenshots or a short recording of any failure. Do not mark interactive validation complete until these observations have been reviewed.
