---

description: "Task list for the pruned conserved bond group"
---

# Tasks: Find the conserved bond group without building every bond subgraph

**Input**: Design documents from `specs/20261103-115636-conserved-bond-group-pruning/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R7), contracts/lazy-extraction-and-pruned-group.md, quickstart.md

**Tests**: Required (Constitution III). The new option's and the new function's tests land with them: they cannot run before them (as in feature `20261102-092909`). Everything else they compare against comes from the unchanged source.

**Organization**:
- **US2** (equality) and **US3** (regression tests) bracket the change.
- **US1** (the full network) is the gate.

## Format: `[ID] [P?] [Story] Description`

## Path conventions

- `FEATURE` = `specs/20261103-115636-conserved-bond-group-pruning`
- `RM` = `src/analysis/topology/reactingMoieties`
- `TESTDIR` = `test/verifiedTests/analysis/testReactingMoieties`
- `BASE` = commit `3c7ee7186`
- `SCAN` = reconXmoieties `results/experiments/2026-10-30-reacting-moiety-memory-scan/`
- `VMH` = reconXmoieties `results/experiments/2026-10-23-collapsed-vmh-037-corpora/` (model `vmhcollapsed037_20261023_103540/model_screened.mat`, RXN files `rxns/`)
- `WORK` = a work folder outside the repository

**Running MATLAB**: every MATLAB run goes in its own memory-capped user scope, one at a time, with a cap of at most the available memory minus 8 GB. Nothing is read from or written to `SCAN`'s or `VMH`'s folders except by copying from them.

---

## Phase 1: Setup and inputs

- [ ] T001 Confirm `git merge-base --is-ancestor BASE HEAD` and `git diff --quiet BASE -- RM TESTDIR`, and archive `BASE`'s `RM` to `WORK/base`. Stop and report if a check fails.
- [ ] T002 Create `FEATURE/rebuildCheckpoint.m`, a function `rebuildCheckpoint(modelOrCheckpoint, rxnDir, outFile)`.
  - **Build**: build `dATM` and `BG` with the fixed builder and the pipeline's options (`directed = 0`, `sanityChecks = 0`).
  - **Check**: run the molfile-equality comparison of feature `20261102-151507`, and print the build time and the counts.
  - **Save**: `runModel`, `dATM`, `BG`, with `-v7.3`.

  Run it for:
  - random n = 2,000, bfs n = 500 and bfs n = 2,000, from copies of `SCAN`'s checkpoints;
  - the full network, from a copy of `VMH`'s `model_screened.mat` (about 70 min, 16 GB cap).

  Copy random n = 100–1,000 from the 2026-11-03 rebuild (exploration E34). Every input must report 0 corrupted metabolites.
- [ ] T003 Record, on `BASE`, what `findAndExtractMolecularGraphs` returns or raises on zero subgraphs and on one subgraph (the contract's empty case), and whether every case in `bondSubgraphReference.mat` and `bondSubgraphPeelingReference.mat` reaches the default peeling path. Note the results in `FEATURE/conservedBondGroupResults.md`. Add a capture script and `.mat` reference only if a case is missing.

---

## Phase 2: Check script and base outputs (US2)

- [ ] T004 [US2] Create `FEATURE/conservedBondGroupCheck.m` and `.sh`, modelled on feature `20261102-092909`'s `reactingMoietyMemoryCheck`. Actions:
  - `identify`: full mode, `sanityChecks = 0`, identification-window VmHWM, optional `outputs.mat`, optional probes;
  - `compare`: every `arm` and `reacting` field and `moietyFormulae`, with the four planted differences;
  - `conserved`: conserved-only identification;
  - `compareConserved`: `L`, `M2M`, `M2R` and `moietyFormulae`.

  `.sh` modes are `selfcheck`, `base`, `equality`, `memory` and `full`. `full` starts only when 32 GB is available, under a 24 GB cap and a 6 h limit.
- [ ] T005 [US2] Run `selfcheck`: base against base on random n = 100, equal, with every control detected.
- [ ] T006 [US2] Run `base`: the base's full-mode outputs for the 7 equality inputs (random n = 100–2,000, bfs n = 500, 2,000). Record any input the base cannot finish under 16 GB; it is then left out of SC-002, and the omission is reported.
- [ ] T007 [US1] Run the conserved-only identification of the full checkpoint, and save its `arm` conserved fields and `moietyFormulae` as the SC-003 reference.
- [ ] T008 Commit T002–T007's scripts and the results file (no source change).

---

## Phase 3: Commit 1 — lazy extraction (US3)

- [ ] T009 [US3] In `RM/extractBondSubgraphs.m`, add `subgraphsToBuild` and `subgraphSizes` (plan, Design 1; contract).
  - **Default**: absent or empty takes today's code unchanged.
  - **`0`**: builds none.
  - **Index vector**: builds only those entries, and errors on out-of-range indices.
  - **Help text**: documents both (VII-E).
- [ ] T010 [US3] Extend `TESTDIR/testExtractBondSubgraphs.m` with `%%` sections:
  - **Subsets**: for every reference case and `labelOnly` false and true, run subsets none, first, last, all, and a fixed random half. Built entries must be `isequaln` to eager, others `[]`; `bmgEdgeIndex` identical; `subgraphSizes` equal to the eager counts.
  - **Fallback**: on the fallback cases, all entries built whatever the subset.
  - **Errors**: the out-of-range error.
  - **Planted controls**: a changed end node, and a wrong size row.
  - **Header**: updated.
- [ ] T011 [US3] Run every test in `TESTDIR`; all must pass. Commit (FR-008, commit 1).

---

## Phase 4: Commit 2 — the pruned search (US3)

- [ ] T012 [US3] Create `RM/findConservedBondGroup.m` (plan, Design 2; contract), with help text that states the exactness argument (VII-E).
- [ ] T013 [US3] Create `TESTDIR/testFindConservedBondGroup.m`.
  - **Reference cases**: for every reference case, sizes and `buildSubgraphs` from `extractBondSubgraphs`, with groups equal to `findAndExtractMolecularGraphs(..., false)`.
  - **Synthetic sets** (spec US3 AS2), small graphs built in the test: equal-population tie, equal-to-best group with smaller leader, a most-populous group that splits, all singletons, one component, and the T003 empty case. Each asserts the groups, and `groupsClassified` and `componentsBuilt`.
  - **Build calls**: a counting handle asserts that `buildSubgraphs` is called only with whole classified groups, each once.
  - **Planted control**: a swapped member is detected.
  - **Header**: Purpose, Authors and tier.
- [ ] T014 [US3] Run every test in `TESTDIR`; all must pass. Commit (FR-008, commit 2).

---

## Phase 5: Commit 3 — the caller (US2)

- [ ] T015 [US2] In `RM/identifyConservedReactingMoieties.m`, take the `sanityChecks = 0` bond stage through the lazy calls (plan, Design 3), with comments on why (FR-007). Leave `sanityChecks = 1` unchanged.
- [ ] T016 [US2] Run every test in `TESTDIR`. All must pass with the stored golden references unchanged (SC-001). Commit (FR-008, commit 3).

---

## Phase 6: Verification

- [ ] T017 [US2] Run `equality` (SC-002): for each of the 7 inputs, new outputs against T006's base outputs, with every control detected. Any difference stops the work, and is reported with the field and input.
- [ ] T018 Run `memory` (SC-004): random n = 1,000 base/new/base/new, then n = 2,000 base and new. Report peak RSS and time, and the `findConservedBondGroup` diagnostics. A pair whose runs differ by more than 1.5× is repeated.
- [ ] T019 [US1] Run `full` (SC-003, SC-005):
  - **Run**: full-mode identification of the full checkpoint, with probes;
  - **Compare**: `compareConserved` against T007;
  - **Report**: peak RSS, time, per-stage time and RSS, diagnostics, and the gate's verdict.

  If the run is disturbed, repeat it once and record both. If the gate fails, stop: report the stage that broke it, and do not tune anything in this feature.
- [ ] T020 [P] Static review:
  - `git diff BASE -- src` touches only the three files;
  - no `nargin`, `evalc` or warning suppression;
  - the `sanityChecks = 1` lines are unchanged.

---

## Phase 7: Close-out

- [ ] T021 Complete `FEATURE/conservedBondGroupResults.md` with the inputs, self-check, tests, equality table, memory and time table, the full-network run and its verdict, and what was not verified (full-size equality of the reacting outputs against a base; Rhea).
- [ ] T022 Report the files changed, the checks run, the tests passed and failed, SC-001–SC-005, and what was not verified.
- [ ] T023 Create `FEATURE/agent-runs/<UTC-timestamp>-conserved-bond-group-pruning/implementation-receipt.md` (Prompt, Final response verbatim, Diff summary, Tests, Unresolved issues, Other information).

---

## Dependencies & Execution Order

- **Phase 1**: T001, then T002 (the full build first, because it is longest), and T003 alongside. Only one MATLAB job runs at a time.
- **Phase 2**: T004 → T005 → T006, with T007 after T002's full build. Then T008.
- **Phases 3–5**: T009 → T010 → T011 → T012 → T013 → T014 → T015 → T016.
- **Phase 6**: T017 → T018 → T019, with T020 alongside.
- **Phase 7**: T021 → T022 → T023.

## Implementation Strategy

- **Base outputs before any source edit** (T006, T007), so the later comparisons are against unchanged code.
- **One reviewable commit per piece** (T011, T014, T016), each with every test passing.
- **The full-network gate last** (T019). Its failure is reported, not worked around here.
- **Rollback**: reverting commit 3 restores the eager path. Commits 1 and 2 are inert without it.
