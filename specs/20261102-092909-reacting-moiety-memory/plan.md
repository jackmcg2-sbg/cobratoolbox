# Implementation Plan: Lower the memory of full-mode reacting-moiety identification

**Branch**: `20261102-092909-reacting-moiety-memory` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/20261102-092909-reacting-moiety-memory/spec.md`

## Summary

Full-mode `identifyConservedReactingMoieties` holds, until it returns, two full-table graph objects for every bond-mapping component, plus four concatenated graphs that it never reads. The atom-component subgraphs are also kept alive through the bond stage and rebuilt later. Six changes fix this without changing any output:

| Change | What it does |
|---|---|
| P1 | Clears the dead intermediates and skips the four unused graphs (`computeGraphs = false`) |
| P2 | Extracts label-only bond subgraphs (`labelOnly`) |
| P3 | Compares only within (node, edge) count groups |
| P4 | Vectorises two loops |
| P5 | Copies moiety indices without rebuilding subgraphs |
| P6 | Builds classification caches lazily and frees them once classified |

Prototypes of all six exist, as one commit each on the local branch `perf/reacting-moiety-memory`. Research ([research.md](research.md)) records their measured effect and equality evidence. This feature first pins the current behaviour of the four functions in CI, then re-applies the six commits one by one, then runs the non-CI equality and memory check.

## Technical Context

**Language/Version**: MATLAB R2024b Update 8.

**Primary Dependencies**: base MATLAB `graph`/`digraph`/`isisomorphic`. The MILP goes through `solveCobraMILP` (Gurobi on the reference machine). No solver change.

**Storage**:
- **CI data**, new, beside the tests in `test/verifiedTests/analysis/testReactingMoieties/data/`:
  - `reactingMoietyMemoryReference.mat`: the full-mode golden cases on the bond-key fixtures, `sanityChecks` 0 and 1;
  - `classifySubgraphIsomorphismGroupsReference.mat`: interleaved-group classification cases with call counts.

  Their file names are fixed at T004. The bond-subgraph references reuse the existing `bondSubgraphReference.mat` and `bondSubgraphPeelingReference.mat`, which `6bc522da0` already reproduces.
- **Local data** (non-CI): the memory scan's checkpoints (spec, Assumptions), copied to a work folder.

**Testing**:
- Four existing test files are extended (III-Naming).
- A non-CI check script lives in this directory.

**Target Platform**: headless Linux.

**Project Type**: scientific MATLAB library.

**Performance Goals**: SC-003, a peak ratio ≤ 0.50 at random n = 1,000 (proposed hard gate). SC-004, a time ratio ≤ 0.80 (reported).

**Constraints**:
- Outputs are identical (`isequaln`).
- Errors are identical.
- No message changes.
- Defaults are historical.

**Scale/Scope**: four source files, about 185 lines added and 80 removed (prototype diff), and four test files.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Scientific correctness**: no algorithm change. The groups, classes, moiety numbering, `L`, `arm` and `reacting` are unchanged, and output equality is the acceptance criterion. **PASS**
- **II. Backward compatibility**: two trailing optional inputs, each defaulting to the historical behaviour (`labelOnly = false`, `computeGraphs = true`). No output, field or message changes. **PASS**
- **III. Testing**:
  - references are captured from the unchanged source before any edit;
  - four existing tests are extended (III-Naming);
  - planted-difference controls are added;
  - all `testReactingMoieties` tests run after every commit;
  - the non-CI check covers real subnetworks;
  - tier: the existing tiers are kept. `testConservedReactingMoieties` stays Tier 3 (MILP), and the other three stay Tier 1.

  **PASS**
- **IV. Solver abstraction and performance**:
  - the MILP path is untouched;
  - `reacting` is compared only when the solver matches the capture's, as the existing golden comparison does;
  - performance stays subordinate to equality.

  **PASS**
- **V/VI. Scope and gate**: the spec, plan and tasks are drafts for review. No source or test file is edited until approval and `/speckit-implement`. Edits are confined to the files listed under Source Code below. **PASS (pending approval)**
- **VII. MATLAB standards**:
  - no `evalc`, warning suppression, `nargin` or new `try/catch` without a stack report (VII-A–D);
  - optional inputs use the `exist`/`isempty` pattern;
  - help text and provenance follow VII-E.

  **PASS**
- **VIII. Polyglot fidelity**: N/A.
- **IX. Placement**:
  - source is edited in place;
  - CI data sits beside its tests;
  - capture and check scripts and results go in this directory;
  - no generated output is committed outside it.

  **PASS**
- **Receipt ledger**: one implementation receipt per run, under `agent-runs/`. **PASS (at implementation)**

**Post-design re-check**: all PASS. There are no new source files, no new dependencies, and two documented optional inputs.

## Design

The design is the prototype diff, unchanged unless review asks otherwise. The research decisions are R1–R6.

1. **P1** (`identifyConservedReactingMoieties`, `findAndExtractMolecularGraphs`):
   - add `computeGraphs`, which returns `[]` for the four graphs right after the groups are computed;
   - the caller passes `false`;
   - after `findAndExtractMolecularGraphs`, the caller clears `bondSubgraphs`;
   - after `identifyIsomorphicClasses`, it clears `BMG`, `CBSubgrahs` and `bmgEdgeIndex`;
   - it clears `subgraphs` before the bond stage;
   - it removes the unused `RBSubgraph` line.
2. **P2** (`extractBondSubgraphs`, caller): add `labelOnly`.
   - The combined subgraph is built as `graph(s, t, [], n)` (or `digraph` for a directed ATG).
   - `BMG` is `digraph(EdgeTable)` over the kept edge variables, padded with `addnode` to the pair's node count.
   - The caller passes `~sanityChecks`.
3. **P3** (`classifySubgraphIsomorphism`): `unique([numNodes, numEdges], 'rows')` groups. Each leader's sweep visits only the later, not-yet-excluded members of its group, in ascending order.
4. **P4** (`identifyConservedReactingMoieties`): vectorise the canonical-atom moiety numbering and the moiety bond index.
5. **P5** (`identifyConservedReactingMoieties`): when `~sanityChecks` and `AtomIndex` is unique, copy moiety indices to member components through `atomsByComp`. Otherwise the existing path runs.
6. **P6** (`classifySubgraphIsomorphism`):
   - the edge end nodes are read with `findedge`;
   - the label-only copy is built on the first comparison that needs it, i.e. any comparison except an identical-edge-list one;
   - `deal([])` frees each subgraph's caches once it joins a class, and each leader's after its sweep.

**Reference capture without editing callers**: the capture script asserts that `git diff --quiet 8a927a4c6 -- src/analysis/topology/reactingMoieties` succeeds, and refuses to run otherwise. The baseline for the non-CI check is a `git archive` of `8a927a4c6`'s `reactingMoieties` folder in a work folder outside the repository. Each run asserts `which('identifyConservedReactingMoieties')` before it starts.

## Project Structure

### Documentation (this feature)

```text
specs/20261102-092909-reacting-moiety-memory/
├── spec.md, plan.md, research.md, quickstart.md, tasks.md
├── contracts/new-optional-inputs.md
├── checklists/requirements.md
├── captureMemoryReferences.m            # NEW (T003) — CI references from unchanged src/
├── reactingMoietyMemoryCheck.m          # NEW (T008) — non-CI equality, controls, memory/time
├── reactingMoietyMemoryCheck.sh         # NEW (T008) — one capped scope per MATLAB run
├── reactingMoietyMemoryResults.md       # NEW (generated, T017)
└── agent-runs/<UTC>-reacting-moiety-memory/implementation-receipt.md
```

### Source Code (repository root)

```text
src/analysis/topology/reactingMoieties/
├── identifyConservedReactingMoieties.m      # MODIFIED — P1, P2 (caller), P4, P5
├── extractBondSubgraphs.m                   # MODIFIED — P2 (labelOnly)
├── findAndExtractMolecularGraphs.m          # MODIFIED — P1 (computeGraphs)
└── classifySubgraphIsomorphism.m            # MODIFIED — P3, P6

test/verifiedTests/analysis/testReactingMoieties/
├── testExtractBondSubgraphs.m               # MODIFIED — labelOnly structure, fallback, errors, classification, controls
├── testFindAndExtractMolecularGraphs.m      # MODIFIED — computeGraphs false/true/empty/omitted, controls
├── testClassifySubgraphIsomorphism.m        # MODIFIED — interleaved groups, call count, controls
├── testConservedReactingMoieties.m          # MODIFIED — full-mode golden cases on bond-key fixtures, controls
└── data/reactingMoietyMemoryReference.mat, data/classifySubgraphIsomorphismGroupsReference.mat   # NEW
```

**Structure Decision**: the single toolbox layout. The four edited source files are edited in place, and the test data sits beside the tests.

## Implementation order (for `/speckit-tasks`)

1. **Setup**: confirm the base and the local data.
2. **Capture the references on unchanged `src/`**.
3. **Extend the four tests**. They must pass on unchanged `src/`, with their controls detected.
4. **Write the check script and self-check it on unchanged `src/`**: base against base gives equal outputs, and the controls are detected.
5. **Apply P1–P6 as six commits**, cherry-picked from the prototypes. Run all `testReactingMoieties` tests after each.
6. **Non-CI equality** on 5 checkpoints, then the **memory and time measurement** (SC-003, SC-004).
7. **Static review**, results file, report and receipt.

## Complexity Tracking

No constitution violations; no entries.
