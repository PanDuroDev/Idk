# WORLDBREAK Project Status

**Last updated:** 2026-11-10  
**Current branch:** `main`  
**PR #2:** [Merged](https://github.com/PanDuroDev/Idk/pull/2) into `main`  
**Merge commit (PR #2):** `0911466d40115e835815d4072c2f075843369027`  
**PR #3:** [Merged](https://github.com/PanDuroDev/Idk/pull/3) into `main`  
**Merge commit (PR #3):** `328595ede6470700a16574bd1461e1b37d3dbe58`  
**PR #4:** [Merged](https://github.com/PanDuroDev/Idk/pull/4) into `main`  
**Merge commit (PR #4):** `9aaf496c74b49a7e8bc8008043731ba08918eaa2`

## Project idea

WORLDBREAK is a 3D physics and destruction sandbox. The long-term goal is to let users create or choose simulation worlds, apply impacts and forces, and observe props, buildings, and eventually terrain breaking under configurable conditions. Multiple fictional environments and reusable simulation tools are planned. These are goals, not completed features.

## Technical baseline

- Godot 4.7.2 stable.
- GDScript and standard Godot editor; no .NET SDK required.
- Compatibility renderer and Godot Physics 3D.
- Target includes desktop GPUs such as GTX 1660 SUPER 6 GB.

## Current implementation

- Generated arena and first-person controller.
- 70 modular rigid-body fragments and six physics props.
- Reusable blast service and physics-tick request processing.
- Shared mesh, material, and collision resources.
- Six-axis support graph; fragments with no path to a surviving ground anchor are released.
- Per-cell accumulated damage with distance falloff.
- Three data-driven `DestructionMaterialProfile` resources:
  - Foundation Concrete: integrity 1.6, blast resistance 1.2, density multiplier 1.3.
  - Masonry: integrity 1.0, blast resistance 1.0, density multiplier 1.0.
  - Lightweight Panel: integrity 0.65, blast resistance 0.8, density multiplier 0.75.
- Material profiles determine per-cell integrity, blast resistance, rigid-body mass multiplier, and shared visual tint.
- Blast damage remains separate from physical impulse strength.
- Reset restores damage history, support state, transforms, velocities, and frozen states.
- Runtime HUD and headless smoke tests.

## Validation

Godot 4.7.2 CI passed on the merged implementation. The final pre-merge validation was [Actions #42859271503](https://github.com/PanDuroDev/Idk/actions/runs/42859271503).

Verified:
- Godot imported the custom Resource script and all three `.tres` material profiles.
- The final PR #3 workflow passed on both `ubuntu-latest` and `windows-latest` at head `351db972746837ebb4ade2d3ab067239b0dfd64a` ([Actions #42865744560](https://github.com/PanDuroDev/Idk/actions/runs/42865744560)). It imports the project before launch, scans Godot logs for script/runtime errors, and requires the gameplay smoke-test success marker.
- CI now runs on pull requests targeting `main` and pushes to `main`; this closes the previous gap where the push trigger only watched the retired feature branch.
- PR #4 was squash-merged as `9aaf496c74b49a7e8bc8008043731ba08918eaa2`; the post-merge push run [Actions #42869641317](https://github.com/PanDuroDev/Idk/actions/runs/42869641317) passed on Linux and Windows.
- The post-merge push run [Actions #42866260328](https://github.com/PanDuroDev/Idk/actions/runs/42866260328) passed on both Linux and Windows at merge commit `328595ede6470700a16574bd1461e1b37d3dbe58`.
- Project launched headlessly.
- Material profile assignment for foundation, middle, and top layers.
- Foundation has higher integrity, blast resistance, and density than masonry.
- Masonry breaks after two centered weak hits.
- Foundation resists three weak hits and breaks on the fourth.
- A centered weak hit breaks the lightweight panel at its own integrity/resistance threshold; the follow-up reset restores the fragment.
- Full base-row collapse, support graph behavior, and reset pass.
- The headless integration test then simulates 120 additional physics frames: all 70 fragments moved, position/velocity values remained finite, and no fragment center crossed below the ground threshold.
- A further headless regression passes five consecutive collapse/reset cycles: all 70 fragments move in every cycle, complete 120 physics frames with finite state and ground containment, and return to the initial state after each reset ([post-merge Actions #42869641317](https://github.com/PanDuroDev/Idk/actions/runs/42869641317)).

## Current limitations

- Material profile values are editable prototype values, not measured real-world material constants.
- Profiles are assigned by layer in the test structure; there is no in-game material editor yet.
- Damage uses fragment-center distance and simple falloff.
- Support graph remains a topological approximation, not a stress solver or physical joint network.
- No arbitrary mesh fracture, bending, crack propagation, terrain deformation, world streaming, or debris pooling.
- The user reported that the manual Windows gameplay/visual/control validation passed on 2026-11-10. Exact FPS/CPU/GPU telemetry values were not supplied, so no numerical performance baseline is claimed.

## Phase 1 progress

All three implementation PRs are open and deliberately stacked. Nothing has been merged by the phase agents.

- PR 1: [#11 - Runtime impact controls](https://github.com/PanDuroDev/Idk/pull/11), branch `ai/phase-1/runtime-impact-controls`. Adds bounded radius, damage, and impulse controls plus reset-to-default behavior. Latest recorded Linux and Windows CI run passed.
- PR 2: [#16 - Debris lifecycle and budgets](https://github.com/PanDuroDev/Idk/pull/16), branch `ai/phase-1/debris-lifecycle`, based on PR #11. Adds released-fragment lifetime/retirement, sleeping and impact wake-up, a hard awake-fragment cap, and lossless reset. Latest recorded Linux and Windows CI run passed.
- PR 3: [#17 - Lightweight effects and diagnostics](https://github.com/PanDuroDev/Idk/pull/17), branch `ai/phase-1/effects-and-diagnostics`, based on PR #16. Adds capped dust bursts and an F3 diagnostics panel. A final CI run is validating the latest disjoint sleeping/parked metrics and overlay assertions.

The default awake-fragment cap is 70 because the current structure contains 70 fragments. This is a conservative guardrail for the fixed prototype, not a measured optimum. Eight simultaneous effect bursts with six motes each cap the visual effect at 48 motes. No FPS/CPU/GPU improvement is claimed without target-PC profiling.

### Remaining manual validation

- Verify impact-control panel layout and mouse interaction in a normal window.
- Trigger repeated impacts and confirm dust visibility, fade, and oldest-burst eviction at the eight-burst cap.
- Toggle the diagnostics panel with F3 and verify the values remain readable during collapse and after settling.
- Profile idle, active collapse, and settled scenes on the target Windows PC. Headless CI cannot establish visual quality or performance.

### Current integration order

Merge only after review, in dependency order: PR #11, then PR #16, then PR #17. Re-run CI on each updated target branch after integration.

## AI phase delegation

Five dedicated implementation issues are open:
- Phase 1: [#5 - Destruction vertical slice](https://github.com/PanDuroDev/Idk/issues/5) - ready now.
- Phase 2: [#6 - Reusable structures and material authoring](https://github.com/PanDuroDev/Idk/issues/6) - runtime work after Phase 1.
- Phase 3: [#7 - Chunked terrain deformation](https://github.com/PanDuroDev/Idk/issues/7) - design and isolated prototype may begin early; integration waits for Phases 1-2.
- Phase 4: [#8 - Multiple worlds](https://github.com/PanDuroDev/Idk/issues/8) - runtime work after Phase 2-3 contracts stabilize.
- Phase 5: [#9 - Simulation tools](https://github.com/PanDuroDev/Idk/issues/9) - runtime work after Phases 1, 2, and 4.

Each issue contains its own AI prompt, PR breakdown, acceptance criteria, and common engineering rules. Agents may implement and open PRs proactively without asking between ordinary subtasks, but they must not merge. One integration maintainer reviews and merges PRs in dependency order. See [AI_PHASE_ASSIGNMENTS.md](AI_PHASE_ASSIGNMENTS.md).

## Required update protocol

Every substantial session updates this file and `WORK_LOG.md` at three points:
1. **Before:** starting commit, current state, intended scope, references, and risks.
2. **During:** completed units, changed architecture, blockers, and tests already run.
3. **After:** exact changes, CI/manual test results, unverified limitations, current milestone, and one concrete next step.

Never mark a feature complete just because code was committed. State whether it passed CI, manual testing, or remains unverified.
