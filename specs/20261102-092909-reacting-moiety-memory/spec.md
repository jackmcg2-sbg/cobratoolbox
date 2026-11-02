# Feature Specification: Lower the memory of full-mode reacting-moiety identification

**Feature Branch**: `20261102-092909-reacting-moiety-memory`

**Created**: 2026-11-02

**Status**: Draft (for maintainer review; no source or test file is edited until it is approved and the implementation phase is invoked)

**Input**: Maintainer decision, 2026-11-02: "Route 1: draft a COBRA Spec Kit feature (spec, plan, tasks) for P1–P6 plus the regression tests, for my review before any implementation." Context: the reconXmoieties exploration `specs/20261030-121933-reacting-moiety-memory/exploration.md` (branch `explore/reacting-moiety-memory`, evidence E1–E25), and six prototype commits on the local branch `perf/reacting-moiety-memory` (`1f3e33bec`..`868308670`, on `6bc522da0`).

<!--
  Not a characterization-mode feature (Constitution Principle III, "Characterization:
  Legacy Back-Fill Mode"): a behaviour-preserving memory and runtime change to four
  functions that already have tests. Two of them gain one optional input each.
-->

## Background

In full mode (`conservedMoietiesOnly = false`, `computeMoietyGraphs = true`), `identifyConservedReactingMoieties` runs out of memory on genome-scale networks. reconXmoieties scanned it on subnetworks of the 9,634-reaction collapsed VMH network:
- at 1,000 reactions, identification peaked at 11.1 GB;
- at 1,500 reactions, it peaked at 24.1 GB;
- at 2,000 reactions, it was killed at a 32 GiB cap.

On the full Rhea network, the bond-level stage ran out of memory at 40.9 and 49.6 GiB.

The exploration profiled the 500-reaction subnetwork at `6bc522da0` (E4, E7). Identification starts at 2.4 GB resident and adds 2.1 GB, ranked:

| Rank | Consumer | Added RSS | Avoidable? |
|---|---|---|---|
| 1 | `extractBondSubgraphs`: `bondSubgraphs` and `BMG`, two full-table graph objects for each of 29,761 bond-mapping components | +0.86 GB | Mostly: later steps read only the end nodes and `mets` |
| 2 | `findAndExtractMolecularGraphs`: `CMTG`, `RMTG`, `CMG`, `RMG` (never used by the caller), plus the label-only copies inside `classifySubgraphIsomorphism` | +0.64 GB kept, +0.29 GB transient | Yes |
| 3 | Atom-component `subgraphs`: kept through the bond stage, and rebuilt later | +0.33 GB | Kept, but freed during the bond stage and not rebuilt |
| 4 | Moiety transition graph and `arm.MG` | +0.09 GB | No (outputs) |
| 5 | Reacting stage: RBG, `CRB2R`, the MILP set cover, `RM_graph` | about 0 GB, < 1 s | n/a |

None of the bond-stage intermediates is ever cleared.

Six prototype changes (P1–P6) lower memory and time without changing any output:
- At random n = 1,000 against `6bc522da0`: identification-window peak 11.23 → 3.93 GB, and time 215 → 131 s.
- At bfs n = 500: peak 3.90 → 2.41 GB.
- At n = 2,000: identification completes at 8.65 GB peak RSS.

Their outputs are `isequaln` to `6bc522da0` on random n = 100, 250, 500 and 1,000 and on bfs n = 500. That covers every `arm` and `reacting` field, `moietyFormulae`, validated `L`, and the downstream export files byte for byte, with the negative controls detected. All COBRA reacting-moiety tests pass unmodified. Each measurement is N = 1 per size.

They do not make the full 9,634-reaction network feasible. Each bond-mapping component embeds the whole atom components its bonds join, so bond-subgraph edges grow about $n^{2.5}$. That is a separate question (exploration Q2) and out of scope here.

| Change | Prototype | What |
|---|---|---|
| P1 | `1f3e33bec` | Clear dead bond-stage intermediates in `identifyConservedReactingMoieties`. `findAndExtractMolecularGraphs` gains `computeGraphs`: when false, it returns only the groups and skips `CMTG`, `RMTG`, `CMG` and `RMG`. |
| P2 | `c96608d0b` | `extractBondSubgraphs` gains `labelOnly`: subgraphs without the node and edge tables that classification never reads. It is used only when `sanityChecks` is off. |
| P3 | `d970f3ca5` | `classifySubgraphIsomorphism` sweeps each leader only over the later members of its own (node count, edge count) group: the same comparisons in the same order. |
| P4 | `4af4ec788` | Two per-element loops over `ATG.Nodes` in `identifyConservedReactingMoieties` are vectorised. |
| P5 | `3fdf63f88` | Moiety indices are copied to member components through the atom-to-component map, without rebuilding the component subgraphs. Used only when `sanityChecks` is off and `AtomIndex` is unique. |
| P6 | `868308670` | `classifySubgraphIsomorphism` builds label-only copies on first use, and frees each subgraph's cached copy, adjacency, certificate and hashes once it is classified. |

## Clarifications

### Session 2026-11-02

- Q: Is SC-003 a hard gate or reported only? → A: **A hard gate** (maintainer, 2026-11-02: "yes go with the hard gate"). It is measured on per-process peak RSS inside the identification window, which is steadier than the scope's `memory.current` because it does not count page cache (exploration E20).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Same outputs, less memory (Priority: P1)

A researcher identifies conserved and reacting moieties in full mode on a genome-scale subnetwork. They need identification to fit in far less memory and time, and to return exactly the same outputs as before.

**Why this priority**: full mode is the step that does not fit in memory above about 1,500 reactions. Every output-preserving saving extends the size that can be run.

**Independent Test**: run `identifyConservedReactingMoieties` in full mode on the CI fixtures and on local subnetworks before and after the change. Compare every output with `isequaln`, and compare peak memory.

**Acceptance Scenarios**:

1. **Given** the CI fixtures (the r0317/ACONTm/r0426 main fixture and the coaM, coaX, coaR, crn and crnM bond-key fixtures), **When** `identifyConservedReactingMoieties` runs in full mode with `sanityChecks` 0 and 1, **Then** `arm`, `moietyFormulae` and `reacting` are `isequaln` to the outputs captured before the change, or the same error is raised. `reacting` is compared when the MILP solver matches the one used at capture.
2. **Given** the local checkpoints of the random series (n = 100, 250, 500, 1,000) and the bfs series (n = 500), **When** identification runs in full mode with `sanityChecks = 0`, **Then** every output is `isequaln` to the base. The four negative controls are detected.
3. **Given** the random n = 1,000 checkpoint, **When** identification runs before and after the change, **Then** the identification-window peak drops by at least the gate in SC-003.

---

### User Story 2 - The new options are pinned by regression tests (Priority: P1)

A maintainer changes one of these functions later. They need every new optional path, and the default path it must equal, pinned by CI tests that fail on drift. The tests must also be shown to detect a planted difference.

**Why this priority**: the maintainer asked for the regression tests first. Constitution III requires them.

**Independent Test**: run the four extended tests on the unchanged source, so they pass against references captured from it. Run them again after each change.

**Acceptance Scenarios**:

1. **Given** the bond-subgraph references (the CI fixture, the 23 peeling cases and the fallback cases), **When** `extractBondSubgraphs(BIG, ATG, true)` runs, **Then** on the default peeling path each `bondSubgraphs{k}` has the same class and node count as the full subgraph, the same end nodes in the same order, and no node or edge variables. Each `BMG{m}` has the same node count and edge order, no node table, and exactly the edge variables `EndNodes`, `BondIndex`, `EdgeIndex` and `mets` (those BIG has), equal to the full subgraph's columns. `bmgEdgeIndex` is identical. On the fallback paths the outputs equal the full reference, and error cases raise the same error.
2. **Given** label-only and full bond subgraphs of the same input, **When** both are classified as `findAndExtractMolecularGraphs` and `identifyIsomorphicClasses` classify them, **Then** the conserved group, the reacting groups and the `mets`-labelled classes are identical.
3. **Given** the bond-subgraph reference inputs, **When** `findAndExtractMolecularGraphs` runs with `computeGraphs` false, **Then** `conservedGroup` and `reactingGroups` equal the reference and the four graph outputs are `[]`. With `computeGraphs` true, empty or omitted, all six outputs equal the reference.
4. **Given** the existing classification reference, plus new cases whose (node, edge) groups interleave in index order and mix identical-edge-list pairs with others, **When** `classifySubgraphIsomorphism` runs, **Then** the three outputs and the diagnostic `isisomorphic` call count are identical to the pre-change helper.
5. **Given** a planted difference in each kind of compared output, **When** the test's comparison runs on it, **Then** the comparison reports a difference. Each kind is checked: a node added to an `arm.MG` graph, a numeric node value, an `L` entry, a reacting-moiety graph edge, a bond-subgraph end node, and an extra variable in a label-only subgraph.

---

### Edge Cases

- **`sanityChecks = 1`**: the sanity check reads `Nodes.AtomIndex` of the bond subgraphs, so the caller keeps the full subgraphs (P2), and the subgraph-based moiety-index copy (P5).
- **Non-unique `AtomIndex`**: P5 falls back to the subgraph-based copy.
- **Fallback paths of `extractBondSubgraphs`** (duplicated or non-integer `AtomIndex`, a component label out of range, named BIG nodes, a BIG without edges): `labelOnly` has no effect, and outputs or errors are as before.
- **Bond-mapping components with isolated nodes**: the label-only `BMG{m}` keeps the node count by appending the isolated nodes.
- **Directed ATG**: the label-only combined subgraph is a `digraph`.
- **Conserved-only mode and `computeMoietyGraphs = false`**: these paths are unaffected and stay pinned by the existing golden cases.
- **A fixture that errors in full mode**: the capture records the error, and the test asserts the same identifier and message.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Public signatures stay backward-compatible (Principle II). `extractBondSubgraphs` gains a trailing optional `labelOnly`, and `findAndExtractMolecularGraphs` a trailing optional `computeGraphs`. Each defaults to its historical behaviour (`false` and `true`) when absent or empty, handled per VII-D. No other signature, output, option name or message changes.
- **FR-002**: In full mode, every output of `identifyConservedReactingMoieties` must be `isequaln` to that of the base for every input. When an error is raised, its identifier and message must match.
- **FR-003**: `labelOnly = true` returns subgraphs that keep exactly what the classification reads, as in US2 AS1. The default peeling path is the only one affected.
- **FR-004**: `computeGraphs = false` returns the same `conservedGroup` and `reactingGroups`, and `[]` for `CMTG`, `RMTG`, `CMG` and `RMG`.
- **FR-005**: `classifySubgraphIsomorphism` keeps its outputs, its candidate pairs and their order, and its diagnostic call count, on every input.
- **FR-006**: `identifyConservedReactingMoieties` clears each bond-stage intermediate once it is no longer read. It uses `labelOnly` and the moiety-index copy without rebuilt subgraphs only when `sanityChecks` is off, and it always passes `computeGraphs = false`.
- **FR-007**: The tests extend the existing test files, one per function (III-Naming): `testExtractBondSubgraphs`, `testFindAndExtractMolecularGraphs`, `testClassifySubgraphIsomorphism` and `testConservedReactingMoieties`. Their expected values are captured from the unchanged source before any source edit, by a capture script in this feature's directory that refuses to run on modified source. Each extended test asserts that its comparison detects a planted difference (US2 AS5). The headers list the new behaviours, the tier and the authors (III-Coverage).
- **FR-008**: The narrowest reproducibility check that proves the feature:
  - the four extended tests and all of `test/verifiedTests/analysis/testReactingMoieties/`;
  - a non-CI check script in this feature's directory. It compares full-mode outputs before and after on the local subnetwork checkpoints (US1 AS2), and measures the identification-window peak (SC-003).
- **FR-009**: Each change P1–P6 is a separate commit, so it can be reviewed and reverted on its own. Each commit leaves all `testReactingMoieties` tests passing.
- **FR-010**: The help text of the two functions that gain an option documents it in the existing style (VII-E). Comments in `identifyConservedReactingMoieties` say why each `clear` is safe.

### Key Entities *(include if feature involves data)*

- **Bond-mapping component**: one entry of `bondSubgraphs`/`BMG`. It holds the bonds of one isomorphism layer between one or two atom components, plus the whole atom components they join.
- **Label-only subgraph**: a bond-mapping component that carries only the end nodes, and the `mets`/`BondIndex`/`EdgeIndex` edge variables for `BMG`. It is used only for classification and is never returned by `identifyConservedReactingMoieties`.
- **Golden case**: the inputs (model, BG, dATM, options) and either the captured outputs or the captured error of one `identifyConservedReactingMoieties` call, plus the MILP solver used.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On every CI golden case (the existing six and the new full-mode cases), outputs are identical to those captured before the change, and so is every new unit-level reference.
- **SC-002**: On the local random n = 100, 250, 500 and 1,000 and bfs n = 500 checkpoints, full-mode outputs are identical to the base, and all four negative controls are detected.
- **SC-003** *(hard gate)*: At random n = 1,000, the peak resident memory (RSS) of the MATLAB process inside the identification window is at most 0.50 of the base. Both are measured back to back as the median of 2 alternating runs of each, so the gate is a ratio of the medians. The prototypes measured 0.35 on the scope's `memory.current`, N = 1. A gate run whose results are inconsistent is repeated rather than judged, and both runs are recorded. Inconsistent means either run of a pair is more than 1.5× its sibling, for example because of other load on the machine.
- **SC-004**: Identification time at random n = 1,000 is at most 0.80 of the base. This is reported, not a gate; the prototypes measured 0.61.
- **SC-005**: All tests under `test/verifiedTests/analysis/testReactingMoieties/` pass after each of the six commits. Each extended test also detects its planted differences.
- **SC-006**: The diagnostic `isisomorphic` call count is unchanged on every classification reference case.

## Assumptions

- **Base**: the fork's `develop` at `8a927a4c6`. Its `src/analysis/topology/reactingMoieties/` is identical to `6bc522da0`, the commit the prototypes were built and measured on. References are captured from this unchanged source.
- **Prototypes**: the six commits on the local branch `perf/reacting-moiety-memory` are the reference implementation. Implementation re-applies them, as cherry-picks reviewed one by one, rather than redesigning them.
- **Local data** (non-CI): the memory scan's checkpoints at `~/repos/reconXmoieties/results/experiments/2026-10-30-reacting-moiety-memory-scan/<order>/n<size>/<run>/checkpoint_build.mat`. They are copied to a work folder before use, and never modified or resumed in place.
- **Environment**: MATLAB R2024b Update 8, Gurobi for the MILP. Each MATLAB job runs alone, in a memory-capped user scope.
- **Fixtures**: the CI fixtures reuse the inputs already in `data/` (golden-case inputs, bond-key submodels, RXN files, and the bond-subgraph and classification references). New `.mat` references hold only captured outputs, plus inputs not already stored.

## Out of Scope

- Any change to how bond-mapping components are formed or classified (the $n^{2.5}$ growth; reconXmoieties exploration Q2).
- The largest-isomorphism-group rule for the conserved group.
- The `sanityChecks` defect in `identifyIsomorphicClasses`.
- Memory after identification, such as `-v7.3` saves of `arm` by callers.
- Conserved-only mode, and full Rhea.

## Traceability

| Acceptance criterion | Discharging test | src/analysis/topology/reactingMoieties/ function under test |
|----------------------|------------------|-----------------------------------|
| US2 AS1 / FR-001, FR-003, SC-001 | testExtractBondSubgraphs.m (extended) | extractBondSubgraphs |
| US2 AS3 / FR-001, FR-004, SC-001 | testFindAndExtractMolecularGraphs.m (extended) | findAndExtractMolecularGraphs |
| US2 AS4 / FR-005, SC-006 | testClassifySubgraphIsomorphism.m (extended) | classifySubgraphIsomorphism |
| US1 AS1, US2 AS2 / FR-002, FR-006, SC-001 | testConservedReactingMoieties.m (extended golden comparison) | identifyConservedReactingMoieties |
| US2 AS5 / FR-007, SC-005 | negative-control blocks in the four extended tests | all four |
| US1 AS2 / FR-008, SC-002 | non-CI check script in this feature's directory | identifyConservedReactingMoieties |
| US1 AS3 / SC-003, SC-004 | non-CI check script (memory and time) | identifyConservedReactingMoieties |
| FR-009, FR-010 | -- (static `git log`/`git diff` review) | -- (no source function) |
| SC-005 | all tests in testReactingMoieties/, after each commit | all four and callers |
