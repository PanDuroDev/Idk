# WORLDBREAK Work Log

This is an append-only engineering journal. Each substantial session is recorded before editing, during implementation, and after verification.

## 2026-11-10 - Engineering improvement pass 02

### Before work
- Starting implementation commit: `98469de3a1ec2e23b10d6449768348f61f390b37`.
- Closed Unreal PR #1; it was not merged.
- Reviewed the original runtime scene, controller, fragment generator, project settings, and initial CI result.
- Researched Godot physics-space timing and reusable shape-query parameters.
- Planned a physics-tick request queue, reusable blast service, InputMap actions, resource sharing, gameplay smoke test, and living docs.

### During work
- Moved raycasts, radial queries, impulses, and reset into `_physics_process()`.
- Extracted `BlastService` with cached query resources and quadratic falloff.
- Shared geometry and collision resources across the 70 fragments and six props.
- Added remappable InputMap actions, configurable blast values, and runtime counters.
- Added headless tests for scene/player setup, fragment count, blast release, and full reset.
- Updated README, technical direction, roadmap, project status, and work log.

### After work
- Final validation of the consolidated Godot foundation passed: [Actions #42848166049](https://github.com/PanDuroDev/Idk/actions/runs/42848166049).
- Manual Windows visual/input/performance testing remains outstanding.
- PR #2 remains a draft and is not merged.
- Next milestone: structural connections/support propagation.

## 2026-11-10 - Structural support graph pass 03

### Before work
- Starting commit: `e95357630711720311add742a33c7a7ae9e8dc62`.
- Confirmed PR #2 remained open, draft, and unmerged.
- Re-read Project Status, Roadmap, Technical Direction, player, blast, and structure scripts.
- Researched Godot 4.7 RigidBody3D freeze/impulse behavior, Joint3D constraints, and physics performance.
- Chose a deterministic six-neighbor support graph rather than physical joints for every touching block.
- Planned synthetic graph tests and an integration test for removing the full base row and restoring the building.
- Documented the limitation: the graph models topology only, not stress, joint break force, bending, or material fracture.

### During work
- Added `StructuralSupportGraph` with six-axis connectivity and ground-anchor reachability.
- Added cell-to-fragment mapping plus broken, supported, and unsupported state.
- Blast damage now marks nearby cells broken, recomputes support, and releases any intact fragments no longer connected to ground.
- Added graph tests for an intact column, severed column, and alternate support path.
- Added integration test for base-row failure, release of all 70 fragments, and full reset.
- First integration attempt failed correctly: the 3.4 m test radius did not remove every ground anchor, and 33 fragments remained supported. Increased the test radius to 4.5 m while keeping the full-collapse assertions.
- Fixed a scene-tree warning by adding the blast flash node before assigning its global transform.
- Added last-hit count to the HUD and updated README, Technical Direction, Roadmap, Project Status, and Work Log.
- Final consolidated commit [bc32c6922c7d78e42f88d3d34e533a476f383e80](https://github.com/PanDuroDev/Idk/commit/bc32c6922c7d78e42f88d3d34e533a476f383e80) passed: [Actions #42856354352](https://github.com/PanDuroDev/Idk/actions/runs/42856354352).

### After work
- Structural support graph and support-loss collapse are implemented in the Godot branch.
- CI verifies graph connectivity, base failure, release of all 70 rigid bodies, and full reset.
- The graph is explicitly documented as an approximation, not a physical force/stress solver.
- Manual visual/input/performance tests on the target Windows PC remain outstanding.
- PR #2 remains a draft and unmerged. Unreal PR #1 remains closed and unmerged.
- Current milestone: headlessly tested modular support-loss collapse.
- Next: cumulative damage and fragment integrity.

## 2026-11-10 - Cumulative damage pass 04

### Before work
- Starting from the validated support-graph prototype.
- Reviewed damage handling, fragment state, blast settings, smoke test, roadmap, and project status.
- Planned configurable per-fragment integrity, distance-falloff damage accumulation, independent blast-damage tuning, reset cleanup, and repeated-hit tests.
- Explicit limitation: this is a tunable prototype damage model, not calibrated real-material simulation.

### During work
- Added exported `fragment_integrity` to the structure and `blast_damage` to the main scene.
- Added per-cell damage storage, damage getter, and normalized damage-ratio getter.
- Replaced binary radius breakage with accumulated damage using linear distance falloff.
- A cell becomes broken only when its accumulated damage reaches its integrity threshold.
- Reset clears damage history alongside support/broken state and rigid-body transforms/velocities.
- Extended tests: first weak hit records 50% damage without breaking; second hit crosses threshold and breaks one cell; alternate support keeps the rest of the structure supported; reset clears the cell damage.
- First integration run failed because the test blast did not remove every base anchor. Raised only the full-collapse test's blast-damage value; preserved the separate two-hit threshold test.
- CI passed on the consolidated commit: [Actions #42857896663](https://github.com/PanDuroDev/Idk/actions/runs/42857896663).
- Test output: `WORLDBREAK_SMOKE_TEST_OK: support graph, collapse, cumulative damage, and full reset`.

### After work
- Cumulative fragment damage and integrity threshold are implemented.
- Final Godot 4.7.2 CI passed editor import, headless launch, support graph tests, cumulative-damage test, collapse, and reset.
- Integrity was still one configurable structure-level value; per-material profiles were the next task.
- Manual Windows visual/input/performance testing remained outstanding.
- PR #2 remained a draft and unmerged; Unreal PR #1 remained closed and unmerged.
- Current milestone: headlessly tested support-loss collapse with cumulative fragment damage.
- Next: data-driven material integrity/resistance profiles.

## 2026-11-10 - Material profiles pass 05

### Before work
- Starting from the validated cumulative-damage prototype, branch commit `31cdafd28b74269492f1fe129f2f82b3a0e9081a`.
- Planned an editable Resource class for material metadata, integrity, blast resistance, density multiplier, and visual tint.
- Planned three default material resources for the foundation, masonry body, and lightweight upper layer.
- Planned per-cell material assignment at structure generation, material-aware damage calculations, density-aware mass, and a test confirming that material profiles alter break thresholds.
- Guardrail: defaults are prototype tuning, not measured real material constants.

### During work
- Added `DestructionMaterialProfile` Resource and three `.tres` assets.
- Added foundation concrete, masonry, and lightweight panel profiles with editable integrity, blast resistance, density multiplier, and surface tint.
- Assigned profiles by structure layer; stored profile references per cell and shared render materials by profile ID.
- Applied density multiplier to rigid-body mass.
- Changed cell damage to use each profile's blast resistance and integrity threshold.
- Added profile accessors and assertions for correct layer mapping and relative profile properties.
- First CI run successfully imported all resources and launched the project, but the test expected the foundation profile to break after three hits. At 0.5 damage per hit, integrity 1.6 and resistance 1.2 require four centered hits. Updated the test to verify three hits do not break it and the fourth does.
- Updated Technical Direction, Roadmap, and README.
- The combined project/documentation CI run [#42859021645](https://github.com/PanDuroDev/Idk/actions/runs/42859021645) passed all steps. Output: `WORLDBREAK_SMOKE_TEST_OK: material profiles, support graph, collapse, cumulative damage, and reset`.

### After work
- Data-driven material profiles are implemented and loaded by the actual Godot project.
- CI verifies resource import, profile assignment, relative integrity/resistance, density multiplier, repeated-hit thresholds, base-row collapse, and reset.
- The three profile values remain prototype tuning, not measured physical material constants.
- Layer-based assignment is implemented; no in-game material authoring UI exists yet.
- Manual visual/input/performance testing on the target Windows PC remains outstanding.
- PR #2 remains a draft and unmerged; Unreal PR #1 remains closed and unmerged.
- Current milestone: headlessly tested material-aware cumulative damage and support-loss collapse.
- Next: manual Windows verification, then material/building authoring tools and evaluation of optional physical breakable joints.

## 2026-11-10 - Merge follow-up

- PR #2 was marked ready for review after confirming its merge state was clean, GitHub Actions validation passed on head `d8e15c4f9bf820a5157573f270931c34b2424b42`, and there were no unresolved review threads or change-request reviews.
- Merged PR #2 into `main` using squash merge.
- Merge commit: `0911466d40115e835815d4072c2f075843369027`.
- Verified GitHub reports PR #2 as closed and merged, and `main` points to the merge commit.
- Manual visual/input/performance testing on the target Windows PC remains outstanding.

## 2026-11-10 - Windows CI parity pass 01

### Before work
- Starting `main` commit: `6a1fb6dbf49231400598dad0229be9f12494044e`.
- Confirmed PR #2 is merged and there are no open PRs.
- Confirmed the current workflow only runs Linux headless checks and its push trigger targets the retired feature branch, so `main` receives no push validation.
- Confirmed the official Godot 4.7.2 release provides the standard Windows x64 editor executable archive.
- Scope: add Windows headless import/launch/gameplay-smoke validation and run CI on pushes to `main`, preserving the existing Linux checks.
- Risks: Windows runner behavior and process exit-code propagation must be verified by an actual Actions run. This does not test interactive rendering, input feel, or target-PC performance.
### During work
- Replaced the retired feature-branch push trigger with push validation on `main`; pull requests targeting `main` remain validated.
- Preserved the existing Linux headless validation job.
- Added a Windows runner using the official Godot 4.7.2 Windows x64 archive, with editor import, headless launch, and the same gameplay smoke test.
- Added explicit PowerShell exit-code propagation so a failing Godot process fails the corresponding Actions step.
- Windows runner results are pending; no interactive graphics, input-feel, or target-PC performance claim is made.

### After work
- GitHub Actions run [#42863598483](https://github.com/PanDuroDev/Idk/actions/runs/42863598483) passed on both `ubuntu-latest` and `windows-latest`.
- On both platforms, Godot 4.7.2 completed editor import/script parsing, headless project launch, and the gameplay smoke test.
- PR #3 remains open pending final review/merge checks.
- This verifies Windows headless startup and logic only. Interactive visuals, input feel, debris settling, and performance on the target GTX 1660 SUPER PC remain unverified.
- Next: complete PR #3 review checks, then perform manual interactive verification on the target Windows PC before extending destruction features.


## 2026-11-10 - Windows CI false-positive investigation and physics regression pass

### Before work
- Starting PR #3 head: `c40cf6994d5e8882a1e62715a43c5d60a0812989`.
- Audited the Windows job logs rather than relying on the green job badge. Earlier runs `42863598483` and `42863780168` reported success while Godot logs contained unresolved `DestructionMaterialProfile` parse errors and a failed smoke-test marker.
- The cause was that the Windows GUI-subsystem editor executable did not provide a reliable `$LASTEXITCODE` through direct PowerShell invocation.
- Scope: make Windows validation fail on actual Godot errors, ensure the global script class cache is built before launching the project, and simulate the debris after collapse.

### During work
- Added a post-collapse physics simulation of 120 physics frames to the smoke test.
- The test records all 70 initial fragment positions, then checks that all 70 fragments remain present, all moved, positions and velocities remain finite, and no fragment center falls below the ground threshold.
- Changed the Windows workflow to use `--import`, verify `.godot/global_script_class_cache.cfg` contains `DestructionMaterialProfile`, retrieve the process exit code with `Start-Process -Wait -PassThru`, scan Godot log files for script/parse/compile/runtime errors, and require explicit smoke-test markers.
- Intermediate Windows failures exposed two issues in the gate itself (PowerShell string interpolation and the unavailable `$LASTEXITCODE`); both were corrected before accepting a passing result.

### After work
- [Actions #42864594057](https://github.com/PanDuroDev/Idk/actions/runs/42864594057) passed on both Linux and Windows at PR head `c40cf6994d5e8882a1e62715a43c5d60a0812989`.
- Both logs include `WORLDBREAK_PHYSICS_COLLAPSE_OK: frames=120; fragments=70; moved=70; ground_containment=passed` and `WORLDBREAK_SMOKE_TEST_OK`.
- The hardened Windows job completed its import/cache, launch, and smoke-test checks without Godot errors.
- Correction: the earlier runs listed above were false positives for Windows and must not be used as evidence of a successful Windows smoke test. The current checked-log run is the first accepted cross-platform result in this pass.
- Still unverified: interactive graphics, player input feel, target-PC FPS/CPU/GPU usage, and long-duration debris settling on the GTX 1660 SUPER system.
- Next: obtain the manual Windows interactive/performance observations before increasing physics complexity or starting terrain work.
