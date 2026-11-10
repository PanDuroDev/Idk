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
- Audited Windows job logs instead of relying on the green job badge. Earlier runs `42863598483` and `42863780168` reported success while the log contained unresolved `DestructionMaterialProfile` parse errors and a failed smoke-test marker.
- The workflow was not asserting the Godot log contents or requiring a positive gameplay-test marker, so the runner could report success even though the game scripts failed to compile.
- Scope: wait for project import before launch, fail on script/runtime errors in Godot logs, require the test's success marker, and simulate the debris after collapse.

### During work
- Added a post-collapse physics simulation of 120 physics frames to the smoke test.
- The test records all 70 initial fragment positions, then checks that all 70 fragments remain present, all moved, positions and velocities remain finite, and no fragment center falls below the ground threshold.
- Changed Windows and Linux validation to use Godot's `--import` flow before the launch test and persist per-step logs.
- Added log checks for script/parse/runtime errors and required the gameplay smoke-test success marker.
- Replaced global `DestructionMaterialProfile` type references in the structure script with an explicit preloaded script type alias, avoiding the class-registration dependency that had caused Windows parse errors.
- Added a one-hit lightweight-panel threshold assertion; the existing checks cover the repeated-hit thresholds for masonry and foundation concrete.
- Intermediate attempts at strengthening the Windows gate exposed PowerShell workflow issues; the final workflow was reworked and verified through fresh Actions runs.

### After work
- [Actions #42865744560](https://github.com/PanDuroDev/Idk/actions/runs/42865744560) passed on both Linux and Windows at PR head `351db972746837ebb4ade2d3ab067239b0dfd64a`.
- Both platform logs include `WORLDBREAK_PHYSICS_COLLAPSE_OK: frames=120; fragments=70; moved=70; ground_containment=passed` and `WORLDBREAK_SMOKE_TEST_OK: all material profiles, support graph, collapse, cumulative damage, and reset`.
- The Windows import, headless launch, and smoke-test steps completed with no Godot script/parse/runtime errors in the saved logs.
- Correction: earlier green Windows runs listed above were false positives and are not accepted as validation evidence. The run linked here is the first accepted final cross-platform run for this PR.
- Still unverified: interactive graphics, player input feel, target-PC FPS/CPU/GPU usage, and long-duration debris settling on the GTX 1660 SUPER system.
- Next: obtain manual Windows interactive/performance observations before increasing physics complexity or starting terrain work.


## 2026-11-10 - PR #3 merge follow-up

- PR #3 was marked ready after its final head `0871c476f4c24a26f283ec1e18ad2f97a709bccd` passed the Linux and Windows validation jobs, including log scanning, the three material threshold checks, and the 120-frame post-collapse physics test.
- Confirmed zero submitted PR reviews and zero review threads, with GitHub reporting `mergeable_state=clean`.
- Squash-merged PR #3 into `main`.
- Merge commit: `328595ede6470700a16574bd1461e1b37d3dbe58`.
- The automatic push-to-`main` workflow [#42866260328](https://github.com/PanDuroDev/Idk/actions/runs/42866260328) passed on both Windows and Linux at the merge commit.
- Manual visual/input testing, long-duration debris settling, and target-PC performance profiling remain outstanding; headless CI does not claim to verify them.
- Next: perform the manual Windows 4.7.2 test on the target PC before extending destruction features or starting terrain deformation.


## 2026-11-10 - Manual target-PC validation preparation

### Before work
- Starting `main` commit: `6e9710c0e04482a1c83e5c580775134c24d398ba`.
- CI now passes on Linux and Windows after PR #3, but interactive rendering, player controls, long-duration debris settling, and target-PC performance have not been observed.
- Scope: prepare a reproducible Windows/Godot 4.7.2 checklist without marking any manual test as completed.

### During work
- Added `docs/MANUAL_WINDOWS_VALIDATION.md` with startup, controls, material comparison, full collapse/reset, repeated-cycle, and performance checks.
- Documented Remote Inspector settings for the root `Main` node so all three material profiles can be compared with the same blast radius, damage, and impulse.
- Included approximate material hit counts derived from the current linear falloff model and a measurement table for FPS, CPU, GPU, and GPU memory.
- Linked the checklist from README and Project Status.

### After work
- Documentation is committed on `main`; no gameplay implementation was changed in this pass.
- Interactive Windows tests have not been run by this session and remain unverified.
- Next: run the checklist on the target Windows PC and report actual observations before adding material authoring tools, physical joints, or terrain deformation.
## 2026-11-10 - Repeated collapse/reset regression pass

### Before work
- Starting `main` commit: `5310224d4a415815c698d65e4c8110ba30fa280a`.
- Confirmed PR #3 is merged; the post-merge Linux and Windows validation on `main` passed.
- Reviewed `PROJECT_STATUS.md`, `MANUAL_WINDOWS_VALIDATION.md`, the current smoke test, structure reset implementation, and CI workflow.
- Interactive controls, visual rendering, 30-second settling, and target-PC performance are still local/manual requirements and will not be claimed as completed here.
- Scope: automate five complete collapse/reset cycles with physics simulation between each cycle, asserting fragment release, finite motion, ground containment, and exact reset state.
- Risk: the existing CI timeout remains 10 minutes; the added frames are bounded and do not attempt to measure target hardware performance.

### During work
- Extended `tests/headless_smoke_test.gd` with five successive full-base-row collapse/reset cycles.
- Each cycle requires at least 14 broken foundation fragments, all 70 fragments released and moved, zero supported fragments, 120 physics frames, finite positions and velocities, no fragment center below the ground threshold, and a successful full reset.
- Added a distinct `WORLDBREAK_REPEAT_CYCLES_OK` marker; both Linux and Windows CI must find it in the saved Godot smoke-test log.
- Kept this as a headless regression only; it does not replace the manual five-cycle and 30-second settling checks on the target PC.

### After work
- Final PR-head run [#42868983866](https://github.com/PanDuroDev/Idk/actions/runs/42868983866) passed on both `ubuntu-latest` and `windows-latest` at head `b411874cdcfcffd2a59b916dc4b6897879316231`.
- Linux printed `WORLDBREAK_REPEAT_CYCLES_OK: cycles=5; frames_per_cycle=120; fragments=70; reset_checks=5` and the final smoke-test success marker.
- The Windows job completed the same smoke test; its PowerShell gate confirmed the repeated-cycle marker and overall success marker were present and found no script/parse/compile/runtime error messages in the Godot log.
- Each of the five cycles broke the foundation row, released all 70 fragments, simulated 120 physics frames, verified that all 70 fragments moved with finite positions/velocities and remained above the ground threshold, then confirmed a full reset.
- This remains headless regression coverage. Interactive controls/rendering, 30-second settling on the GTX 1660 SUPER, and target-PC FPS/CPU/GPU measurements remain unverified.
- Next: perform the manual Windows checklist before adding material authoring, breakable joints, or terrain deformation.

## 2026-11-10 - PR #4 merge follow-up

- PR #4 was marked ready after the final head `38a32db7faac7c2ead0991a6f02104f5fb4da887` passed the Linux and Windows CI jobs, including the five-cycle regression, all-fragment movement checks, saved-log checks, and material profile assertions.
- Confirmed the PR was mergeable, with no submitted reviews or unresolved review threads.
- Squash-merged PR #4 into `main`.
- Merge commit: `9aaf496c74b49a7e8bc8008043731ba08918eaa2`.
- Post-merge push validation [#42869641317](https://github.com/PanDuroDev/Idk/actions/runs/42869641317) passed on both Linux and Windows.
- The repeated regression completed five collapse/reset cycles, 120 physics frames per cycle, with all 70 fragments moving, finite physics state, ground containment, and a full reset after each cycle.
- Manual interactive controls/rendering, 30-second debris settling on the target GTX 1660 SUPER PC, and FPS/CPU/GPU measurements remain outstanding.
- Next: complete `docs/MANUAL_WINDOWS_VALIDATION.md` on the target PC. Do not begin material authoring, physical breakable joints, or terrain deformation until those observations have been reviewed.



## 2026-11-10 - Manual validation and AI phase delegation

### Before work
- Starting `main` commit: `0d7c97a48e03ebd909b2e874f90330002c782680`.
- PRs #2, #3, and #4 were merged; the latest recorded Linux and Windows CI was green.
- The user reported that the manual interactive test on the target Windows PC worked successfully.
- Exact FPS/CPU/GPU telemetry values were not supplied; this session does not claim a measured performance baseline.
- Planned to hand off the remaining roadmap to one dedicated AI issue per phase, with explicit PR slices, dependencies, and a single integration/merge owner.

### During work
- Created [AI Phase 1 issue #5](https://github.com/PanDuroDev/Idk/issues/5): runtime impact controls, debris lifecycle/performance budgets, effects, and diagnostics.
- Created [AI Phase 2 issue #6](https://github.com/PanDuroDev/Idk/issues/6): reusable building definitions, material authoring, and configuration save/load; optional breakable-joint feasibility is evidence-gated.
- Created [AI Phase 3 issue #7](https://github.com/PanDuroDev/Idk/issues/7): chunked terrain design, deformation, localized collision rebuilding, and performance budgets.
- Created [AI Phase 4 issue #8](https://github.com/PanDuroDev/Idk/issues/8): data-driven worlds, selection/transitions, and bounded streaming.
- Created [AI Phase 5 issue #9](https://github.com/PanDuroDev/Idk/issues/9): unified simulation controls, repeatable scenarios, and result capture.
- Each issue contains a ready-to-use agent prompt, acceptance criteria, PR breakdown, branch/CI/documentation rules, and explicit instruction not to merge.
- Documented the dependency and concurrency model in `docs/AI_PHASE_ASSIGNMENTS.md`.
- Updated Project Status and Roadmap to record user-reported manual validation and link each phase to its issue.

### After work
- Phase 1 is the only runtime implementation phase ready to start immediately.
- Phase 2 may plan its schema while Phase 1 runs, but runtime implementation waits for Phase 1 interfaces to merge.
- Phase 3 may research and build an isolated terrain prototype in parallel; runtime integration waits for Phases 1-2.
- Phase 4 runtime work waits for Phase 2 building/material contracts and Phase 3 terrain/world contracts.
- Phase 5 is last because it composes the control, material, and world systems.
- The five phase issues describe 15 core future PRs, plus one optional breakable-joint feasibility PR if evidence supports it. The three already merged foundation PRs make 18 planned core PRs overall.
- No implementation PR was created or merged in this delegation session. The integration maintainer remains responsible for review and ordered merges.
- Next: send the Phase 1 prompt from issue #5 to the first AI.


## 2026-11-10 - Phase 1 PR 1: runtime impact controls

### Before work
- Starting main commit: 70da82274da67faf034afb9d98932f4fe1db03f4.
- Confirmed Phase 0 PRs #2-#4 are merged and no other PRs are open.
- Reviewed README, project status, roadmap, technical direction, work log, manual validation checklist, main scene/controller, blast service, destructible structure, headless smoke test, and Linux/Windows workflow.
- Existing pipeline already routes blast radius/damage through apply_blast_damage and radius/impulse through BlastService; the new UI mutates these existing exported properties rather than introducing parallel impact state.
- Risk: UI geometry/input and GDScript signal binding require interactive Godot validation; headless tests can verify settings bounds and reset only.

### During work
- Added a compact in-game Impact Settings panel with +/- controls for radius, damage, and impulse.
- Preserved existing defaults and blast pipeline. Bounds: radius 0.5-12.0, damage 0.1-10.0, impulse 1.0-100.0.
- Added a single reset-to-default action and headless assertions for defaults, clamping, and reset.
- Updated README and manual validation instructions.
- CI has not yet run for this branch; no interactive or target-PC performance claim is made.

### After work
- Implementation and documentation are committed on ai/phase-1/runtime-impact-controls.
- Pending: Linux/Windows Actions logs, panel visual/input validation, and integration maintainer review.
- Next: open PR 1, inspect both platform logs and repair any errors before proceeding to the debris lifecycle branch.


## 2026-11-10 - Phase 1 PR 2: debris lifecycle and budgets

### Before work
- Started from Phase 1 PR 1 head 46261f8d7f6bb13a3c46d686f8acdd19235b72ca; PR #11 remains open and unmerged.
- Existing 70 rigid bodies are the original structural nodes. Deleting them would make reset lossy, so expiry must retire released nodes without freeing their canonical structure identity.
- Risk: a too-small awake-body budget can leave pieces suspended before they fall. The default budget therefore matches the current 70-piece structure; larger-world tuning needs measured profiling.

### During work
- Tracked only fragments that are broken or lose every support path as loose debris; intact supported fragments never enter the lifecycle.
- Added a configurable 30-second loose-debris lifetime. Expiry hides the released fragment, disables its collision, clears motion, and retains the node for deterministic reset.
- Added sleeping/active/retired counters and an active-fragment cap (70 by default, configurable up to 256). Godot's rigid-body sleeping remains enabled; radial impulses can wake sleeping bodies.
- Reset restores visibility, collision layers/masks, groups, transforms, velocities, support state, and all original fragments.
- Added smoke coverage for wake-up, expiry, and complete reset restoration. CI is pending.

### After work
- Implementation is committed on ai/phase-1/debris-lifecycle, stacked on PR #11.
- No pooling was added; the fixed 70-node scene does not justify pooling.
- Target-PC settling and performance measurements remain manual and unrecorded.
- PR 2 is open as #16. Next: inspect its Linux/Windows logs, then validate PR 3 in dependency order.


### Cross-PR validation and measured count baseline

- Changed the pull-request workflow filter from main-only to all target branches. This preserves the Linux and Windows jobs while allowing the stacked Phase 1 PRs to run CI before their dependencies are merged.
- Recorded the actual fixed-scene baseline: 70 original structure bodies, zero loose at startup, 70 released on full collapse, and six separate physics props. The default awake loose-fragment cap remains 70 to avoid suspending pieces mid-fall; smaller caps are explicitly tested.
- The dust effect budget is eight concurrent bursts of six motes each (48 motes maximum), with a 0.55-second lifetime.
- No FPS/CPU/GPU values were fabricated; target-PC profiling remains a manual measurement.
