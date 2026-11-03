# Feature Specification: Find the conserved bond group without building every bond subgraph

**Feature Branch**: `20261103-115636-conserved-bond-group-pruning`

**Created**: 2026-11-03

**Status**: Draft (for maintainer review; no source or test file is edited until it is approved and the implementation phase is invoked)

**Input**: Maintainer decision, 2026-11-03: "draft a COBRA Spec Kit feature for P7 (exact size-group pruning with lazy building), with a full collapsed-VMH memory run as a success criterion, for my review before implementation." Context: the reconXmoieties exploration `specs/20261030-121933-reacting-moiety-memory/exploration.md` (branch `explore/reacting-moiety-memory`), question Q2, evidence E22–E29 and E34, checks C8 and C12.

<!--
  Not a characterization-mode feature (Constitution Principle III): a behaviour-preserving
  memory and runtime change. One existing function gains one optional input and one
  optional output; one new function is added.
-->

## Background

Feature `20261102-092909-reacting-moiety-memory` (P1–P6, PR #10) cut the identification-window peak at random n = 1,000 from 10.29 to 4.00 GiB. At n = 2,000, identification completes at 8.65 GB. It does not reach the full collapsed VMH network (9,634 reactions), for one structural reason (exploration E22, E23):
- **Every bond subgraph copies whole atom components.** `extractBondSubgraphs` builds, for every bond-mapping component, the whole atom-transition subgraph of the one or two atom components its bonds join, plus that component's bonds.
- **The giant component dominates.** Every bond pattern touching the giant atom component carries its own copy of it. The giant grows from 1.8 k to 17.4 k atoms between n = 500 and 2,000. The bond-subgraph edge total grows about $n^{2.5}$, to 46.5 M at n = 2,000.
- **Projection**: at about 105 B per edge, full size projects to 240–280 GB.
- **Time**: classifying these subgraphs is also the time sink, 328 of 507 s at n = 2,000.

**Why most of them are never needed** (E26). The bond stage reaches the outputs only through two per-bond labels:
- `BIG.Edges.Component`: the bond-mapping component, numbered in extraction order;
- `BIG.Edges.IsomorphismClass`: the `mets`-labelled class within the conserved group, 0 for a reacting bond.

The unlabelled classification of the bond subgraphs serves one purpose: finding the **conserved group**, the largest isomorphism class, taking the smallest leader index on a tie. Only the conserved group's bond-mapping graphs (`BMG`) are classified further.

**Why the conserved group can be found exactly from far fewer subgraphs** (C8):
- **Classes never cross size groups.** Isomorphic graphs have equal (node, edge) counts, so every class lies inside one size group. `classifySubgraphIsomorphism` restricted to a size group gives the same classes (feature 20261102-092909, P3).
- **Small groups can be skipped.** A size group with fewer members than the best class found so far cannot hold a larger class. So classify size groups from the most populous down, and stop at the first group smaller than the best class.
- **The sizes come free.** A bond subgraph's (node, edge) counts are known during extraction before any graph is built: node count is the component pair's atoms, edge count is the pair's atom-transition edges plus the layer's bonds.

**Measured** (E27, E29; N = 1 each): on random n = 500, 1,000 and 2,000 and bfs n = 2,000, the pruned search returns the same conserved group as the full sweep.
- **How little it touches**: it classifies 1 size group of 275–797, holding 0.15–5.4 % of the bond-subgraph edges. Every classified component has at most 4 nodes, and no component containing the giant is ever classified.
- **Time**: unlabelled classification falls from 345.5 to 0.6 s at n = 2,000.

E34 confirmed that bond graphs from the fixed builder (feature `20261102-151507`) leave identification memory at P1–P6 levels.

**What is left.** At n = 2,000, the two steps this feature removes take 360 of 507 s and add 4.6 of the 5.5 GB that identification adds (E28). The other stages grew about linearly from n = 1,000 to 2,000. Extrapolating, full size is roughly 7–12 GB and 15–30 min. That extrapolation is from n ≤ 2,000, N = 1, so this feature makes a full-network run its gate (SC-003).

## Clarifications

### Session 2026-11-03

- Q: What is the full-network success criterion? → A: a full collapsed-VMH memory run (maintainer, 2026-11-03). Its threshold is a review point below (Assumptions).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Full mode runs on the full collapsed VMH network (Priority: P1)

A researcher runs `identifyConservedReactingMoieties` in full mode (`conservedMoietiesOnly = false`, `computeMoietyGraphs = true`) on the whole 9,634-reaction collapsed VMH network. They need it to finish in the memory of an ordinary workstation, and to give the conserved moieties the conserved-only run gives.

**Why this priority**: this is the goal of the memory work. No reacting-moiety result exists yet for any full network.

**Independent Test**: one full-mode identification on a checkpoint of the full network built with the fixed builder, in a memory-capped scope, measuring the identification-window peak RSS and the time.

**Acceptance Scenarios**:

1. **Given** the full collapsed VMH checkpoint (bond graph from the fixed builder), **When** full-mode identification runs in one memory-capped scope, **Then** it completes, and the identification-window peak RSS and the time are within SC-003.
2. **Given** the same run, **When** its conserved-moiety outputs (`L`, `M2M`, `M2R`, `moietyFormulae`) are compared with the conserved-only run of the same network, **Then** they are identical.

---

### User Story 2 - Same outputs as before, wherever both can run (Priority: P1)

A researcher needs every full-mode output to be exactly what P1–P6 give.

**Why this priority**: the feature claims exactness (C8), so it must be shown on every input the base can finish.

**Independent Test**: full-mode outputs before and after, compared with `isequaln`, on the CI fixtures and on the local subnetworks.

**Acceptance Scenarios**:

1. **Given** every CI golden case, **When** identification runs after the change, **Then** `arm`, `moietyFormulae` and `reacting` are `isequaln` to the stored references, or the same error is raised.
2. **Given** the local subnetworks rebuilt with the fixed builder (random n = 100, 250, 500, 1,000 and 2,000; bfs n = 500 and 2,000), **When** identification runs in full mode with `sanityChecks = 0` on the base and on this feature, **Then** every output is `isequaln`, and the four planted differences are detected.

---

### User Story 3 - The pruning is pinned by regression tests (Priority: P1)

A maintainer later changes the extraction or the classification. They need CI tests that fail if the pruned search ever picks a different conserved group, or if a lazily built subgraph differs from the eagerly built one.

**Why this priority**: the exactness argument rests on two facts: classes never cross size groups, and ties go to the smallest leader. A test must pin each, including the tie and stop rules on inputs built to exercise them.

**Independent Test**: unit tests of the new function, and of the new option of `extractBondSubgraphs`, against references from the unchanged source.

**Acceptance Scenarios**:

1. **Given** the existing bond-subgraph references (`bondSubgraphReference.mat`, `bondSubgraphPeelingReference.mat`), **When** `extractBondSubgraphs` runs with `subgraphsToBuild` set to any subset (none, one, all, and a random half), **Then**:
   - the built entries are `isequaln` to the entries of the eager extraction, for `labelOnly` false and true;
   - the unbuilt entries are empty;
   - `bmgEdgeIndex` is complete and identical;
   - `subgraphSizes(k, :)` equals the node and edge counts of the eager `bondSubgraphs{k}`.
2. **Given** the same references, plus synthetic subgraph sets built to exercise the rules, **When** `findConservedBondGroup` runs, **Then** its conserved and reacting groups equal those of `findAndExtractMolecularGraphs`. The synthetic sets are:
   - two size groups of equal population, whose largest classes tie, with the smaller leader in the group visited second;
   - a size group whose population equals the best class so far, and which holds an equal class with a smaller leader;
   - a most populous size group that splits into many small classes, so a smaller group wins;
   - all classes singletons;
   - one component.
3. **Given** the same inputs, **When** the diagnostics of `findConservedBondGroup` are read, **Then** it built only the members of the size groups it classified. The stop rule is pinned by the number of groups classified on each synthetic set.
4. **Given** a planted difference (a conserved group with one member swapped; a lazily built subgraph with one end node changed; a wrong size row), **When** the test's comparison runs on it, **Then** it reports a difference.

---

### Edge Cases

- **`sanityChecks = 1`**: the caller keeps today's path (eager full extraction, full classification), because the sanity check of `identifyIsomorphicClasses` reads the full subgraphs. That path is unchanged and stays pinned by the `…Sanity` golden cases.
- **Fallback paths of `extractBondSubgraphs`**: duplicated or non-integer `AtomIndex`, a component label out of range, non-numeric end nodes, or an `ATG.Nodes.Component` that is not the `conncomp` labelling. On these paths `subgraphsToBuild` is ignored, every subgraph is built as today, and `subgraphSizes` is read from the built graphs. The pruned search still gives the same group.
- **A BIG without edges**: no components; outputs and errors as today.
- **No dominant size group**: the search classifies more groups, up to all of them, and is never worse than today in what it classifies. It does rebuild each classified group's subgraphs separately (plan, Design 2).
- **Ties**: equal populations are visited in ascending order of their first member. Class ties go to the smallest leader, as `max` over leader-ordered classes does (C8). The order of visiting does not affect the result: the rule compares leaders, not visiting order.
- **Conserved-only mode and `computeMoietyGraphs = false`**: the bond stage does not run; unaffected.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Public signatures stay backward-compatible (Principle II).
  - `extractBondSubgraphs` gains a trailing optional input, `subgraphsToBuild`: the component indices (extraction order) whose `bondSubgraphs` and `BMG` entries are built. Absent or empty means all, as today (VII-D), and `0` means none.
  - It also gains a trailing optional output, `subgraphSizes` (components × 2: node and edge counts of each `bondSubgraphs{k}`).

  No other signature, output, option name or message changes.
- **FR-002**: A new function, `findConservedBondGroup(subgraphSizes, buildSubgraphs)`, returns `conservedGroup` and `reactingGroups` identical to `findAndExtractMolecularGraphs` on the same components, for every input. `buildSubgraphs` is a function handle that returns the bond subgraphs of given component indices.
  - **Method**: it classifies (node, edge) size groups with `classifySubgraphIsomorphism`, in descending population (ties ascending by first member). It keeps the best class (size, then smallest leader), and stops at the first group whose population is smaller than the best size.
  - **Third output**: a diagnostics struct (groups classified, components built).
- **FR-003**: In full mode with `sanityChecks = 0`, `identifyConservedReactingMoieties` takes its bond stage through three calls:
  1. a size-only extraction (`subgraphsToBuild = 0`);
  2. `findConservedBondGroup`, building each classified group lazily;
  3. one extraction of the conserved group's `BMG`, for the labelled classification.

  `BIG.Edges.Component` comes from the complete `bmgEdgeIndex`. With `sanityChecks = 1`, the bond stage is as today.
- **FR-004**: Every output of `identifyConservedReactingMoieties` is `isequaln` to the base for every input, and every error has the same identifier and message.
- **FR-005**: Tests follow III-Naming:
  - `testExtractBondSubgraphs` is extended (US3 AS1);
  - a new `testFindConservedBondGroup` covers US3 AS2–AS4;
  - `testConservedReactingMoieties` keeps its golden comparisons, which must pass unchanged.

  Synthetic sets are built in the test. References of real components come from the existing `.mat` files, plus, where a new reference is needed, a capture script in this feature's directory that refuses to run on modified source. Each test detects its planted differences.
- **FR-006**: The narrowest reproducibility check that proves the feature:
  - all of `test/verifiedTests/analysis/testReactingMoieties/`;
  - a non-CI check script in this feature's directory. It runs the equality comparison (US2 AS2), the memory and time comparison at random n = 1,000 and 2,000 (SC-004), and the full-network run (US1, SC-003).
- **FR-007**: The help text documents the new option and output of `extractBondSubgraphs`, and the method and its exactness argument in `findConservedBondGroup` (VII-E). Comments in `identifyConservedReactingMoieties` say why the bond stage no longer needs every subgraph.
- **FR-008**: The change is three commits, each leaving every `testReactingMoieties` test passing:
  1. the `extractBondSubgraphs` option, with its tests;
  2. the new function, with its test;
  3. the caller change.

### Key Entities *(include if feature involves data)*

- **Size group**: the bond-mapping components with the same (node count, edge count) of their bond subgraph.
- **Conserved group**: the largest unlabelled isomorphism class of bond subgraphs (smallest leader on a tie). Its bonds get a `mets`-labelled class; all other bonds are reacting.
- **Lazily built subgraph**: a bond subgraph or bond-mapping graph built only when requested, `isequaln` to the eagerly built one.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every CI golden case and unit reference gives the same outputs as before. All tests in `testReactingMoieties/` pass after each of the three commits, and each new test detects its planted differences.
- **SC-002**: On the local subnetworks (US2 AS2: random n = 100–2,000, bfs n = 500 and 2,000, bond graphs from the fixed builder), full-mode outputs are `isequaln` to the base (`develop` at `3c7ee7186`), with all four planted differences detected.
- **SC-003** *(hard gate)*: full-mode identification on the full collapsed VMH network (9,634 reactions) must:
  - complete in a single scope capped at 24 GB (`MemorySwapMax = 0`);
  - have an identification-window peak RSS of at most **16 GiB**;
  - take at most **6 h**;
  - give `L`, `M2M`, `M2R` and `moietyFormulae` identical to the conserved-only run of the same checkpoint.

  The run is repeated once if it is disturbed (another job, or a machine-wide out-of-memory event), and both runs are recorded.
- **SC-004** *(reported)*: identification-window peak RSS and time at random n = 1,000 and 2,000, against the base, back to back. The median of 2 alternating runs at n = 1,000, and 1 run each at n = 2,000.
- **SC-005** *(reported)*: on the full-network run, per-stage time and RSS from the existing probe method, so the next bottleneck is named. Candidates: the `mets`-labelled classification (P8 in the exploration), atom components, and the reacting stage.

## Assumptions

- **Base**: the fork's `develop` at `3c7ee7186` (P1–P6 and the whole-molecule bond renumbering, PRs #10 and #11).
- **Review point: the SC-003 threshold.**
  - **16 GiB** is about half of the 32 GB most workstations have, and twice the projection's upper end.
  - **The 24 GB cap** lets an overshoot be measured rather than killed. It needs 32 GB available at the start (cap + 8 GB), so the run waits for that.
  - **Change the threshold** if "applicable" means something else, such as a 16 GB machine.
- **Review point: the gate's failure mode.** If the run exceeds the gate, the feature is not merged as complete. The probes (SC-005) name the stage that broke it, and that becomes the next exploration question. The equality results stand either way.
- **Local data** (non-CI): copies of the memory scan's checkpoints, rebuilt with the fixed builder.
  - Random n = 100–1,000 were rebuilt on 2026-11-03 (E34).
  - Random n = 2,000 and bfs n = 500 and 2,000 are rebuilt by this feature, the same way.
  - The full network: a fresh build of the 2026-10-23 collapsed-VMH model with the fixed builder (about 70 min), and a conserved-only run of it.

  Nothing is read from, or resumed in, the scan's own folders.
- **Environment**: MATLAB R2024b Update 8, Gurobi for the MILP. Each MATLAB job runs alone, in a memory-capped user scope, with a cap of at most the available memory minus 8 GB.

## Out of Scope

- **P8**: grouping the labelled classification by its label multiset. It is a candidate next step if SC-005 names it.
- **Rule changes**: any change to which components are formed, or to the largest-class rule.
- **Full Rhea.**
- **Memory after identification**, such as saves of `arm` by callers.
- **The `sanityChecks = 1` path** and its pre-existing `identifyIsomorphicClasses` error.

## Traceability

| Acceptance criterion | Discharging test | src/analysis/topology/reactingMoieties/ function under test |
|----------------------|------------------|-----------------------------------|
| US3 AS1, AS4 / FR-001, SC-001 | testExtractBondSubgraphs.m (extended) | extractBondSubgraphs |
| US3 AS2–AS4 / FR-002, SC-001 | testFindConservedBondGroup.m (new) | findConservedBondGroup |
| US2 AS1 / FR-003, FR-004, SC-001 | testConservedReactingMoieties.m (golden comparisons, unchanged) | identifyConservedReactingMoieties |
| US2 AS2 / FR-006, SC-002 | non-CI check script in this feature's directory | identifyConservedReactingMoieties |
| US1 AS1–AS2 / FR-006, SC-003, SC-005 | non-CI check script (full network) | identifyConservedReactingMoieties |
| SC-004 | non-CI check script (memory and time) | identifyConservedReactingMoieties |
| FR-007, FR-008 | -- (static `git log`/`git diff` review) | -- (no source function) |
