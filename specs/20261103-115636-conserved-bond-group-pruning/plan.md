# Implementation Plan: Find the conserved bond group without building every bond subgraph

**Branch**: `20261103-115636-conserved-bond-group-pruning` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/20261103-115636-conserved-bond-group-pruning/spec.md`

## Summary

Full-mode `identifyConservedReactingMoieties` builds, and classifies without labels, a graph for every bond-mapping component. Those graphs serve only to find the conserved group, and their total size grows about $n^{2.5}$ (research R1, R2). This feature:
- **builds lazily**: `extractBondSubgraphs` returns every component's sizes and edge indices, but builds only the components asked for;
- **prunes exactly**: a new function, `findConservedBondGroup`, classifies size groups from the most populous down, stops when no remaining group can hold a larger class (R3), and builds each classified group on demand;
- **builds the conserved `BMG` only**: the caller builds just the conserved group's bond-mapping graphs, for the labelled classification.

Every output stays identical. The `sanityChecks = 1` path is unchanged. The gate is one full-mode run on the full collapsed VMH network (SC-003).

## Technical Context

**Language/Version**: MATLAB R2024b Update 8.

**Primary Dependencies**: base MATLAB `graph`/`digraph`, and `classifySubgraphIsomorphism` (unchanged). The MILP goes through `solveCobraMILP` (Gurobi on the reference machine).

**Storage**:
- **CI data**: the existing `bondSubgraphReference.mat`, `bondSubgraphPeelingReference.mat` and golden references in `test/verifiedTests/analysis/testReactingMoieties/data/`. Synthetic tie and stop cases are built inside the new test. A new `.mat` reference is added only if T003 finds a real-component case the existing files do not cover.
- **Local data** (non-CI): checkpoints rebuilt with the fixed builder in a work folder outside the repository (spec, Assumptions).

**Testing**:
- `testExtractBondSubgraphs.m` is extended.
- `testFindConservedBondGroup.m` is new.
- All of `testReactingMoieties/` must pass.
- A non-CI check script lives in this directory.

**Target Platform**: headless Linux.

**Project Type**: scientific MATLAB library.

**Performance Goals**:
- **SC-003 (hard gate)**: the full collapsed VMH network in at most 16 GiB identification-window peak RSS and 6 h, under a 24 GB cap.
- **SC-004 (reported)**: random n = 1,000 and 2,000 against the base.

**Constraints**:
- Outputs are identical (`isequaln`).
- Errors are identical.
- No message changes.
- Defaults are historical.

**Scale/Scope**:
- **Source**: two source files changed and one new, an estimated 120–180 lines.
- **Tests**: one test file extended and one new.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Scientific correctness**: no algorithm change. The conserved group is the same class by the argument of R3, and output equality on every input the base can finish is the acceptance criterion (SC-001, SC-002). **PASS**
- **II. Backward compatibility**: one trailing optional input and one trailing optional output on `extractBondSubgraphs`. Absent or empty means all components are built, as today. A new function adds surface without changing any existing one. **PASS**
- **III. Testing**:
  - **III-Naming**: the new function gets `testFindConservedBondGroup.m`, and `testExtractBondSubgraphs.m` is extended.
  - **Order**: tests come before the change they cover, on unchanged source where they can run there. The new option's tests can't run before the option exists, so they land with it, as in feature `20261102-092909`.
  - **Planted controls**: every test has them.
  - **III-Coverage**: headers list the tier, behaviours and authors.

  **PASS**
- **IV. Solver abstraction**: no solver change. **PASS**
- **V. Scope control**: P8, rule changes, Rhea and the sanity path are out of scope (spec). **PASS**
- **VI. Spec-driven gate**: this spec, plan and tasks precede any source edit. Implementation starts only on the maintainer's approval. **PASS**
- **VII. MATLAB standards**:
  - optional arguments use `exist`/`isempty`, not `nargin` (VII-D);
  - no `evalc` or warning suppression;
  - help text in the existing style (VII-E).

  **PASS**
- **IX. File placement**: source in `src/analysis/topology/reactingMoieties/`, tests beside the existing ones, and feature scripts and results in this directory. **PASS**

## Design

1. **`extractBondSubgraphs(BIG, ATG, labelOnly, subgraphsToBuild)`, with fourth output `subgraphSizes`** (R4).
   - **Default peeling path**: for each component pair, compute its layers from the existing row bookkeeping on index vectors. For each layer, record:
     - `bmgEdgeIndex{k}`;
     - `subgraphSizes(k, :) = [numel(nodesInBothComponents), numel(atgRows) + numel(layerRows)]`.
   - **Building**: the combined subgraph, the edge tables and the `BMG` digraph are built only when the pair has a layer in `subgraphsToBuild`, and kept only for requested layers. Unrequested entries are `[]`.
   - **Default**: `subgraphsToBuild` absent or empty builds all, through today's code path unchanged.
   - **Fallback paths**: they build all, and `subgraphSizes` is read from the built graphs.
   - **Help text**: documents both, with the identity "a built entry is `isequaln` to the eager one".
2. **New `findConservedBondGroup(subgraphSizes, buildSubgraphs)` → `[conservedGroup, reactingGroups, diagnostics]`** (R3).
   - **Order**: `[~, ~, sizeGroup] = unique(subgraphSizes, 'rows')`. Groups are ordered by population descending, ties by first member ascending.
   - **Loop**: for each group in that order:
     - stop if its population is below `bestSize`;
     - otherwise `members = find(sizeGroup == g)` and `classes = classifySubgraphIsomorphism(buildSubgraphs(members))`;
     - update the best class on (larger size) or (equal size and smaller leader `members(classes{c}(1))`).
   - **Outputs**: `conservedGroup = bestClass` as a row vector of ascending indices, as `findAndExtractMolecularGraphs` returns it; `reactingGroups = setdiff(1:nComponents, conservedGroup)`.
   - **`diagnostics`**: `groupsClassified`, `componentsBuilt`, `numSizeGroups`.
   - **Empty input**: as `findAndExtractMolecularGraphs` on zero subgraphs. T003 records what that does, so the new function matches it.
   - **Help text**: states the exactness argument.
3. **`identifyConservedReactingMoieties`, bond stage, `sanityChecks = 0` only** (FR-003). With `sanityChecks = 1`, the current lines run unchanged.

   ```matlab
   [~, ~, bmgEdgeIndex, subgraphSizes] = extractBondSubgraphs(BIG, ATG, true, 0);
   buildGroup = @(idx) selectBuilt(extractBondSubgraphs(BIG, ATG, true, idx), idx);
   [conservedGroups, reactingGroups] = findConservedBondGroup(subgraphSizes, buildGroup);
   [~, BMGc] = extractBondSubgraphs(BIG, ATG, true, conservedGroups);
   CBSubgrahs = BMGc(conservedGroups);
   ```

   - `bonds2component` is filled from the complete `bmgEdgeIndex`, as today.
   - `selectBuilt` is a local helper that returns the requested entries of the first output.
   - "Build none" is passed as `0`. Component indices start at 1, so `0` names no component, and empty must keep meaning all (VII-D, the historical default). The help text states this.

**Reference capture**: the capture script asserts `git diff --quiet 3c7ee7186 -- src/analysis/topology/reactingMoieties`. The non-CI baseline is a `git archive` of `3c7ee7186`'s `reactingMoieties` folder in the work folder. Each run asserts `which('identifyConservedReactingMoieties')` and `which('extractBondSubgraphs')`.

## Project Structure

### Documentation (this feature)

```text
specs/20261103-115636-conserved-bond-group-pruning/
├── spec.md, plan.md, research.md, quickstart.md, tasks.md
├── contracts/lazy-extraction-and-pruned-group.md
├── checklists/requirements.md
├── conservedBondGroupCheck.m             # NEW — non-CI identify/compare/sizes, probes
├── conservedBondGroupCheck.sh            # NEW — one capped scope per MATLAB run
├── rebuildCheckpoint.m                   # NEW — fixed-builder checkpoint from a model and RXN folder
├── conservedBondGroupResults.md          # NEW (generated)
└── agent-runs/<UTC>-conserved-bond-group-pruning/implementation-receipt.md
```

### Source Code (repository root)

```text
src/analysis/topology/reactingMoieties/
├── extractBondSubgraphs.m               # MODIFIED — subgraphsToBuild, subgraphSizes
├── findConservedBondGroup.m             # NEW
└── identifyConservedReactingMoieties.m  # MODIFIED — bond stage when sanityChecks = 0

test/verifiedTests/analysis/testReactingMoieties/
├── testExtractBondSubgraphs.m           # MODIFIED — lazy subsets, sizes, fallback, controls
└── testFindConservedBondGroup.m         # NEW — references, synthetic tie/stop sets, diagnostics, controls
```

**Structure Decision**: the single toolbox layout.

## Implementation order (for `/speckit-tasks`)

1. **Setup**: confirm the base, and rebuild the local inputs with the fixed builder. That covers random n = 2,000, bfs n = 500 and 2,000, and the full network, plus its conserved-only run. The full-network build runs early, because it takes about 70 min.
2. **Write the check script** and self-check it, base against base.
3. **Run the base's** equality outputs, plus memory and time.
4. **Commit 1**: the `extractBondSubgraphs` option, with its tests.
5. **Commit 2**: `findConservedBondGroup`, with its test.
6. **Commit 3**: the caller change. Run all tests.
7. **Non-CI equality** (SC-002), **memory and time** (SC-004), then the **full-network gate** (SC-003, SC-005).
8. **Close out**: static review, results file, report and receipt.

## Complexity Tracking

No constitution violations; no entries.
