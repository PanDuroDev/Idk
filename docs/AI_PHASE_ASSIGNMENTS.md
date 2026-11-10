# AI Phase Assignments

This document is the coordination map for the remaining WORLDBREAK roadmap. Each linked GitHub issue contains the full ready-to-use prompt for its dedicated AI owner.

## Current state

- Phase 0 is complete: PRs #2, #3, and #4 are merged.
- The user reported successful manual gameplay/visual/control validation on the target Windows PC on 2026-11-10.
- No exact FPS/CPU/GPU telemetry values were provided. Performance profiling remains a task, not a completed benchmark.
- `main` at the start of delegation: `0d7c97a48e03ebd909b2e874f90330002c782680`.

## Assignments

| Phase | AI issue | Planned PRs | Start condition |
|---|---|---:|---|
| 1 - Destruction vertical slice | [#5](https://github.com/PanDuroDev/Idk/issues/5) | 3 | Ready now |
| 2 - Structures/material authoring/config persistence | [#6](https://github.com/PanDuroDev/Idk/issues/6) | 3 (+ optional joint feasibility PR) | Schema planning can begin during Phase 1; runtime code after Phase 1 merge |
| 3 - Chunked terrain | [#7](https://github.com/PanDuroDev/Idk/issues/7) | 4 | Research/design and isolated prototype may run during Phases 1-2; runtime integration after Phases 1-2 |
| 4 - Multiple worlds | [#8](https://github.com/PanDuroDev/Idk/issues/8) | 3 | Schema proposal may be drafted early; runtime implementation after Phase 2 and Phase 3 contracts stabilize |
| 5 - Simulation tools | [#9](https://github.com/PanDuroDev/Idk/issues/9) | 2 | UI/API review may begin early; runtime implementation after Phases 1, 2, and 4 |

The core plan is 15 future PRs across Phases 1-5. The three foundation PRs already merged bring the planned core total to 18. Breakable physical joints are an optional evidence-gated experiment, not a mandatory feature.

## Dependency map

```text
Phase 0 (complete)
      |
      v
Phase 1 ----------------------+
      |                       |
      v                       v
Phase 2                 Phase 3 design/research
      |                       |
      +----------+------------+
                 v
          Phase 3 integration
                 |
                 v
           Phase 4 worlds
                 |
                 v
       Phase 5 simulation tools
```

Phase 3 is the highest-risk engineering task. It may investigate terrain representation and build an isolated prototype while earlier phases proceed, but it must not integrate with gameplay until the existing blast, material, and configuration interfaces are stable. Phase 4 and Phase 5 must not invent duplicate resource/control systems.

## Parallel-work rules

1. One AI owns one phase issue. The agent should make progress through its entire phase without asking the user for permission between ordinary PR-sized tasks.
2. Agents may work in parallel only on isolated designs/prototypes with separate files and stable interfaces. Do not allow concurrent edits to the same root scene, shared gameplay scripts, tests, or common documentation.
3. Phase 1 is the only runtime implementation authorized to start immediately.
4. Phase 2 may plan data schemas during Phase 1, but must defer code that depends on Phase 1's runtime controls/debris lifecycle.
5. Phase 3 may create design notes and an isolated terrain prototype, but must defer main-scene integration until Phases 1-2 are merged.
6. Phase 4 may prepare a proposal, but final WorldDefinition implementation waits for the building/material and terrain contracts.
7. Phase 5 may review APIs and propose a UI layout, but implementation waits for the control/resource/world APIs it composes.

## Integration and merge policy

- Each agent uses a dedicated branch: `ai/phase-N/<short-scope>`.
- No agent commits to `main`, merges its own PR, enables auto-merge, or rewrites another agent's branch.
- PRs target `main`, are narrowly scoped, and include test evidence, risks, and manual test notes.
- A dependent PR must declare its dependency and use a stacked branch if its base is not yet merged.
- The integration maintainer reviews architecture, diffs, tests/logs, dependency order, and regressions, then merges in order. The maintainer may request changes or reject an implementation that adds complexity without evidence.
- A phase is not complete merely because all PRs are open or code was committed. It is complete only after the relevant PRs are merged, CI passes, docs are accurate, and required manual checks are reviewed.

## Recommended launch order

1. Send [Issue #5](https://github.com/PanDuroDev/Idk/issues/5) to AI 1 now.
2. Send [Issue #6](https://github.com/PanDuroDev/Idk/issues/6) to AI 2 for schema/design planning only while AI 1 implements; authorize runtime implementation after Phase 1 is merged.
3. Send [Issue #7](https://github.com/PanDuroDev/Idk/issues/7) to AI 3 for research and isolated terrain prototyping in parallel; integration stays blocked on Phases 1-2.
4. Prepare AI 4 and AI 5 with their issues, but keep them in design-only mode until their dependencies stabilize.

All issue prompts are written in English to match the repository's engineering documentation and can be copied directly to the assigned AI.
