---

description: "Task list for lowering the memory of full-mode reacting-moiety identification"
---

# Tasks: Lower the memory of full-mode reacting-moiety identification

**Input**: Design documents from `specs/20261102-092909-reacting-moiety-memory/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R7), contracts/new-optional-inputs.md, quickstart.md

**Tests**: Required (Constitution III). The references are captured from the unchanged source (T003–T004), and the extended tests must pass on it (T005–T009) before any source edit.

**Organization**:
- **US2** (regression tests) is foundational and comes first, as the maintainer asked.
- **US1** (the six changes) follows.
- The non-CI check discharges US1 AS2 and AS3.

## Format: `[ID] [P?] [Story] Description`

## Path conventions

- `FEATURE` = `specs/20261102-092909-reacting-moiety-memory`
- `RM` = `src/analysis/topology/reactingMoieties`
- `TESTDIR` = `test/verifiedTests/analysis/testReactingMoieties`
- `BASE` = commit `8a927a4c6` (its `RM` is identical to `6bc522da0`)
- `PROTO` = local branch `perf/reacting-moiety-memory`, with the commits P1 `1f3e33bec`, P2 `c96608d0b`, P3 `d970f3ca5`, P4 `4af4ec788`, P5 `3fdf63f88` and P6 `868308670`
- `SCAN` = `~/repos/reconXmoieties/results/experiments/2026-10-30-reacting-moiety-memory-scan`
- `WORK` = a work folder outside the repository

**Running MATLAB**: every MATLAB run goes in its own capped scope, one at a time: `systemd-run --user --scope -p MemoryMax=<cap> -p MemorySwapMax=0 -p OOMPolicy=continue -- matlab -batch "initCobraToolbox(false); run('<absolute path>')"`. The cap is at most the available memory (`free -g`) minus 8 GB.

---

## Phase 1: Setup

- [X] T001 From the repository root, run:
  - `git merge-base --is-ancestor BASE HEAD`;
  - `git diff --quiet BASE -- RM TESTDIR`;
  - `git diff --quiet 6bc522da0 BASE -- RM`;
  - check that `PROTO` holds the six commits listed above, on `6bc522da0`.

  Stop and report if any check fails.
- [X] T002 [P] Copy the checkpoints to `WORK/ckpt/<order>-n<size>/` and record their sizes:
  - `SCAN/random/n{100,250,500,1000}/*/checkpoint_build.mat`;
  - `SCAN/bfs/n500/*/checkpoint_build.mat`.

  Never resume or write inside `SCAN`. Then create `WORK/base/RM` with `git archive BASE RM | tar -x -C WORK/base`.

---

## Phase 2: Foundational — references and regression tests on the unchanged source (US2)

**Do not edit any file under `RM` until T010 passes.**

- [X] T003 [US2] Create `FEATURE/captureMemoryReferences.m`.
  1. **Guard**: run `git diff --quiet BASE -- RM` through `system`. If it fails, raise `captureMemoryReferences:srcModified`.
  2. **Full-mode golden cases (R7)**: for each bond-key fixture (`coaM`, `coaX`, `coaR`, `crn`, `crnM`):
     1. load `TESTDIR/data/<name>BondKeySubmodel.mat`;
     2. build `BG` and `dATM` with `buildAtomAndBondTransitionMultigraph(subModel, TESTDIR/data/rxnFiles, struct('directed', 0, 'sanityChecks', 1))`, as `testConservedReactingMoieties` does;
     3. run `identifyConservedReactingMoieties` with `struct('directed', 0, 'sanityChecks', s)` for `s` = 0 and 1;
     4. record `name`, `model`, `BG`, `dATM`, `options`, `outcome`, `arm`, `moietyFormulae`, `reacting`, `errorIdentifier`, `errorMessage` and `milpSolver`, the fields of the existing `goldenCases`. An error is recorded as the outcome.
  3. **Classification group cases (US2 AS4)**: with `rng(1)`, build 20 subgraph lists. Each list:
     - uses `graph` and `digraph` alternately;
     - has members of three to five (node, edge) sizes, interleaved in index order;
     - includes identical-edge-list duplicates and `reordernodes` relabellings;
     - carries `mets` node and edge variables.

     Classify each list unlabelled and with `'EdgeVariables', 'mets'`, recording the three outputs and the call count.
  4. **Save**: `TESTDIR/data/reactingMoietyMemoryReference.mat` (`goldenCases`, `provenance`) and `TESTDIR/data/classifySubgraphIsomorphismGroupsReference.mat` (`groupCases`, `provenance`), both with `-v7`. The `provenance` holds the base commit, the MATLAB version, the MILP solver and the date. Print the file sizes and case counts.

  Every `catch` reports `ME.stack(1)` (VII-C).
- [X] T004 [US2] Run T003. Record the file sizes, the number of cases, and any error cases with their messages.
- [X] T005 [P] [US2] Extend `TESTDIR/testExtractBondSubgraphs.m` (US2 AS1, AS2). Add one `%%` section per behaviour.
  - **Label-only on the default path**: for the CI fixture and every `ok` peeling case, check `labelOnly` against the full call: the class, node count and `EndNodes` order of `bondSubgraphs`; for `BMG`, no node table, exactly the kept edge variables, and equal columns; `bmgEdgeIndex` identical.
  - **Fallback paths**: for every fallback case and every error case, `labelOnly = true` gives the reference outputs or the reference error.
  - **Default arguments**: `labelOnly` `[]` and `false` equal the reference.
  - **Classification**: the unlabelled groups (`classifySubgraphIsomorphism` of the label-only and full `bondSubgraphs`) and the `mets`-labelled classes (`identifyIsomorphicClasses` of the label-only and full `BMG`) are identical on the CI fixture.
  - **Controls**: the structural comparison reports a difference for a swapped end node and for an extra variable added to a label-only subgraph.
  - **Header**: update `Purpose:` and `Authors:` (this feature, FR-003, FR-007).
- [X] T006 [P] [US2] Extend `TESTDIR/testFindAndExtractMolecularGraphs.m` (US2 AS3).
  - **`computeGraphs = false`**: the groups equal the reference, and all four graphs are `isequal(..., [])`.
  - **`true`, `[]` and omitted**: all six outputs equal the reference.
  - **Control**: a planted change to a reference group is detected.
  - **Header**: updated.
- [X] T007 [P] [US2] Extend `TESTDIR/testClassifySubgraphIsomorphism.m` (US2 AS4). Load `classifySubgraphIsomorphismGroupsReference.mat`.
  - **Group cases**: for each case, reset the counter, classify, and assert `isequal` on the three outputs and the call count.
  - **Control**: a planted change to one class is detected.
  - **Header**: updated.

  Keep the existing assertions.
- [X] T008 [P] [US2] Extend `TESTDIR/testConservedReactingMoieties.m` (US1 AS1, US2 AS2). Load `reactingMoietyMemoryReference.mat`, and run each of its golden cases through the existing `checkGoldenCase`, after the `prepareTest('needsMILP', true)` gate. `reacting` is compared only when the solver matches the capture's.
  - **Controls**: on one captured `arm`/`reacting`, `isequaln` reports a difference for each planted change:
    - a node added to an `arm.MG` graph;
    - a changed numeric node value in an `arm.MG` graph;
    - `L(1)` + 1;
    - an edge added to a `reacting.ReactMoietyGraphs` graph.
  - **Header**: updated.
- [X] T009 [US2] On the unchanged source, run the four extended tests, then every test in `TESTDIR`. All must pass, and each control must be detected. Record the output.
- [X] T010 Create `FEATURE/reactingMoietyMemoryCheck.m` and `FEATURE/reactingMoietyMemoryCheck.sh` (non-CI; FR-008). Port `run_identify.m`, `compare_outputs.m` and `job.sh` from the reconXmoieties exploration's `exploration/` folder.
  - **`.m`**:
    1. take a reactingMoieties folder, put it first on the path, and assert `which identifyConservedReactingMoieties`;
    2. load a copied checkpoint and run identification in full mode with `sanityChecks = 0`;
    3. save the outputs, and compare two output folders field by field with `isequaln`, including the four controls;
    4. log the identification start and end. Reset the process's peak RSS at the start, by writing `5` to `/proc/self/clear_refs`, and read `VmHWM` from `/proc/self/status` at the end. That value is the identification-window peak RSS that SC-003 gates on.
  - **`.sh`**:
    - runs one capped scope per MATLAB run, sampling `memory.current` every second and recording `memory.peak` and RSS;
    - its modes are `selfcheck`, `equality` and `memory`.
  - **Self-check**: run it on the unchanged source (base against base, random n = 100). The outputs must be equal and all controls detected.

---

## Phase 3: User Story 1 — the six changes (Priority: P1)

**Goal**: identical outputs with less memory and time.

**Independent test**: T017 and T018.

- [X] T011 [US1] Apply P1: `git cherry-pick 1f3e33bec`. Review the diff against plan Design 1, then run every test in `TESTDIR`; all must pass.
- [X] T012 [US1] Apply P2: `git cherry-pick c96608d0b`. Review the diff against Design 2 and the contract, then run every test in `TESTDIR`.
- [X] T013 [US1] Apply P3: `git cherry-pick d970f3ca5`. Review the diff against Design 3, then run every test in `TESTDIR`.
- [X] T014 [US1] Apply P4: `git cherry-pick 4af4ec788`. Review the diff against Design 4, then run every test in `TESTDIR`.
- [X] T015 [US1] Apply P5: `git cherry-pick 3fdf63f88`. Review the diff against Design 5, then run every test in `TESTDIR`.
- [X] T016 [US1] Apply P6: `git cherry-pick 868308670`. Review the diff against Design 6, then run every test in `TESTDIR`.

  In every task T011–T016: if a cherry-pick does not apply cleanly, or review requires a change, stop and report. Do not edit beyond the prototype without approval. Each commit message names the feature and the change (FR-009) and ends with the agent's co-author line.

---

## Phase 4: Verification and close-out

- [X] T017 [US1] Run `reactingMoietyMemoryCheck.sh equality` on the five copied checkpoints, `WORK/base/RM` against `RM` (SC-002). All outputs must be `isequaln`, and all controls detected.
- [X] T018 [US1] Run `reactingMoietyMemoryCheck.sh memory`: 2 alternating runs each of base and new at random n = 1,000 (SC-003, SC-004). Report the ratio of the median identification-window peak RSS, and of the median times. SC-003 is a hard gate: a ratio above 0.50 fails the feature, so stop and report rather than continue to T019. A run that is inconsistent (more than 1.5× its sibling, for example because of other load on the machine) is repeated, and both runs are recorded.
- [X] T019 [P] Static review (FR-001, FR-009, FR-010):
  - `git diff BASE -- RM` touches only the four files;
  - the help text documents both options;
  - no `nargin`, `evalc` or warning suppression;
  - `git log BASE..HEAD` shows six change commits after the test commit(s).
- [X] T020 Write `FEATURE/reactingMoietyMemoryResults.md`: the test results, the equality table, the memory and time table with the job start and end times, and the behaviours not verified (above 1,000 reactions, and full Rhea).
- [X] T021 Report:
  - files changed;
  - checks run;
  - tests passed and failed, with output;
  - SC-002–SC-004;
  - behaviours not verified.
- [X] T022 Create `FEATURE/agent-runs/<UTC-timestamp>-reacting-moiety-memory/implementation-receipt.md`, with the sections Prompt, Final response (T021's response, verbatim), Diff summary, Tests, Unresolved issues and Other information.

## Implementation notes (2026-11-02)

- **T005, T006**: the base-behaviour assertions and their controls landed in commit `74e6d04b0`, before any source edit. The `labelOnly` and `computeGraphs` sections cannot run before those options exist. They were written in full beforehand, and shown to fail on the unchanged source ("Too many input arguments") and to pass on the prototype source. They were then committed together with the change that adds each option: `computeGraphs` with P1 (`ce0bb089f`), `labelOnly` with P2 (`2386c98bd`). This keeps every commit green (FR-009).
- **T004**: all five `sanityChecks = 1` full-mode cases raise the pre-existing `identifyIsomorphicClasses.m:34` sanity-check error ("Inconsistent mapping of atoms to connected components."). They are pinned as error cases. The full `sanityChecks = 1` path stays covered end to end by the existing `mainDefaultSanity` golden case.
- **T010**: written after Phase 3 rather than alongside Phase 2. Its self-check compares the archived base copy against itself, so it does not depend on the order.

---

## Dependencies & Execution Order

- **Phase 1**: T001, then T002.
- **Phase 2**: T003 → T004 → (T005 ∥ T006 ∥ T007 ∥ T008) → T009. T010 can be written alongside T005–T008, but its self-check runs after T009.
- **Phase 3**: T011 → T012 → T013 → T014 → T015 → T016, after T009 and T010. Each depends on the previous one.
- **Phase 4**: T017 → T018 (never two MATLAB jobs at once). T019 can run alongside them. Then T020 → T021 → T022.

## Parallel Example

```text
Stream A: T003 → T004 → (T005 ∥ T006 ∥ T007 ∥ T008) → T009
Stream B: T010 (scripts; self-check after T009)
Then: T011 → … → T016 → T017 → T018 (T019 ∥) → T020 → T021 → T022
```

## Implementation Strategy

- **Regression tests first**, as the maintainer asked: Phase 2 lands as its own commit(s) and passes on the unchanged source.
- **One change per commit**: each of P1–P6 can be ratified or reverted alone.
- **Rollback**: `git revert` of any change commit restores its function's behaviour. The tests stay, and still pass on the reverted source.
- **Pull request**: from this branch to the fork's `develop` (`origin`, `jackmcg2-sbg/cobratoolbox`), only after T022, and only with the maintainer's agreement.
