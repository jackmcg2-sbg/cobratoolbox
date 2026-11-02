# Implementation Plan: Whole-molecule bond renumbering

**Branch**: `20261102-151507-whole-molecule-bond-renumbering` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/20261102-151507-whole-molecule-bond-renumbering/spec.md`

## Summary

`buildAtomAndBondTransitionMultigraph` replaces each end of a bond independently with a symmetry-class representative. This moves bonds between atoms: 37 % of collapsed-VMH metabolites are corrupted, and so are 38 of 58 metabolite–fixture cases ([research.md](research.md) R1).

The fix replaces this with one renumbering per (RXN file, metabolite, instance):
- **the identity**, when the copy's molblock equals the reference (first-seen) molblock;
- **otherwise one isomorphism** of the element-labelled molecular graph onto the reference;
- **applied to both ends** of every bond.

Order of work:
1. Write the molfile-equality test first, and show it fails on the unchanged source.
2. Apply the fix.
3. Recapture the two golden references whose stored inputs came from the old builder, with a difference report.
4. Add the paper's published values as tests.
5. Check the full collapsed VMH network outside CI.

## Technical Context

**Language/Version**: MATLAB R2024b Update 8.

**Primary Dependencies**: base MATLAB `graph`/`isomorphism`. No solver change; the MILP in the identification tests is unchanged.

**Storage**:
- **CI data, recaptured**: `data/conservedReactingMoietiesReference.mat`, `data/reactingMoietyMemoryReference.mat`.
- **CI data, new**: `data/rxnFilesConsistentArms/` (copies of `ACONTm.rxn`, `r0317.rxn` and `r0426.rxn`, with atom-map numbers changed in two product blocks).
- **Local data** (non-CI): the collapsed VMH network's model and its 9,634 RXN files (reconXmoieties `results/experiments/2026-10-23-collapsed-vmh-037-corpora/`).

**Testing**:
- **Extended**: `testBuildAtomAndBondTransitionMultigraph.m` (molfile equality, non-isomorphic copy) and `testConservedReactingMoieties.m` (recaptured goldens, paper values, conserved outputs unchanged).
- **Non-CI**: a check script in this directory.

**Target Platform**: headless Linux.

**Performance Goals**: SC-006, builder wall time ≤ 1.10 of the base on the full collapsed VMH network (reported).

**Constraints**:
- molfile equality for every metabolite;
- conserved-moiety outputs identical;
- visible warning when no isomorphism exists;
- no silent fallback.

**Scale/Scope**: one source file, `buildAtomAndBondTransitionMultigraph.m`: the bond-key block and its two local functions. Help text only in `identifyAtomEquivalenceClasses.m`. Two test files and three data artefacts.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Scientific correctness**: the fix restores each metabolite's molecular graph to its molfile. Bond-level outputs change on purpose and are listed in a reviewed difference report. The atom-level (conserved-moiety) outputs must not change. **PASS**
- **II. Backward compatibility**: no signature, option or output-field change. `identifyAtomEquivalenceClasses` is kept (deprecation, not deletion). Output values change because the old ones were wrong. That is approved here explicitly, with a migration note: re-run anything built on `BG` since 2026-08-18. **PASS (approved behaviour change)**
- **III. Testing**:
  - the molfile-equality test is written first and must fail on the unchanged source;
  - the recaptured goldens are anchored by independent checks: molfile equality, the paper's published values, and the authors' original code's 6/7 on the shipped files;
  - one test file per function;
  - tiers unchanged.

  **PASS**
- **IV. Solver abstraction**: untouched. The reacting outputs in the goldens are compared under the existing solver rule. **PASS**
- **V/VI. Scope and gate**: drafts for review only, with no source or test edit until approval and `/speckit-implement`. **PASS (pending approval)**
- **VII. MATLAB standards**:
  - VII-B: a warning naming the metabolite and the reaction when no isomorphism exists;
  - VII-C: an error with the metabolite named if the search fails;
  - VII-D: no `nargin`;
  - VII-E: help text.

  **PASS**
- **VIII. Polyglot**: N/A.
- **IX. Placement**:
  - **source**: edited in place;
  - **CI data**: beside its tests;
  - **capture, check and report scripts**: in this directory.

  **PASS**
- **Receipt ledger**: written at implementation. **PASS (at implementation)**

## Design

1. **Reference molblocks.** At the place where `metBondCountGroundTruth` is filled today (first instance of a metabolite in its first file), also store that molblock's atom numbers, elements, bonds (head, tail) and bond types. This stored copy is the reference (FR-002). Remove `metAtomCanonicalRankMap`, `metUnsafeNeighborsMap` and the `identifyAtomEquivalenceClasses` call.
2. **Per-copy renumbering.** For each (file, metabolite, instance) seen in a reaction:
   - if its sorted (head, tail, type) bond list and its element list equal the reference's, the renumbering is the identity;
   - otherwise build two `graph` objects (nodes = atom numbers, `Element` node variable, bond order not used) and call `isomorphism(Gcopy, Gref, 'NodeVariables', 'Element')`;
   - an empty result raises the FR-003 warning and keeps the copy's raw numbering;
   - the result is cached per (file, metabolite, instance).
3. **Use.** Replace `safeCanonicalizeBondAtoms(...)` by a lookup of the copy's renumbering applied to both head and tail. `canonicalBondKey` then orders the renumbered pair. The bond-transition atom identities passed to `resolveAtomNodeIndex` use the same renumbered atoms, so a bond node and its atoms agree.
4. **Bond types.** Keep the first-seen cache (`metBondTypeFirstSeen`). Since keys are now the reference's, the first-seen type equals the reference's order for every bond present in the reference.
5. **Remove** `safeCanonicalizeBondAtoms` and `safeCanonicalizeOneAtom`. Update the NOTE block of the builder, and add a "no longer called by `buildAtomAndBondTransitionMultigraph`" line to `identifyAtomEquivalenceClasses`'s help.

## Project Structure

### Documentation (this feature)

```text
specs/20261102-151507-whole-molecule-bond-renumbering/
├── spec.md, plan.md, research.md, quickstart.md, tasks.md
├── contracts/bond-graph-equals-molfiles.md
├── checklists/requirements.md
├── molfileEqualityCheck.m              # NEW: per-metabolite BG vs reference molblock (used by the test and the non-CI check)
├── captureRenumberedGoldens.m          # NEW: recapture of the two references + per-field difference report
├── wholeMoleculeRenumberingCheck.m     # NEW: non-CI full-VMH molfile equality, conserved-output equality, wall time
├── wholeMoleculeRenumberingResults.md  # NEW (generated)
└── agent-runs/<UTC>-whole-molecule-bond-renumbering/implementation-receipt.md
```

`molfileEqualityCheck.m` is a feature-directory script, and the test inlines its logic as a local function. This is because a test may not depend on a `specs/` path (CI).

### Source Code (repository root)

```text
src/analysis/topology/reactingMoieties/
├── buildAtomAndBondTransitionMultigraph.m   # MODIFIED: renumbering replaces per-atom substitution; NOTE
└── identifyAtomEquivalenceClasses.m         # MODIFIED: help text only

test/verifiedTests/analysis/testReactingMoieties/
├── testBuildAtomAndBondTransitionMultigraph.m   # MODIFIED: molfile equality on every fixture, non-isomorphic copy, planted control
├── testConservedReactingMoieties.m              # MODIFIED: paper values (shipped + consistent arms), conserved outputs unchanged
├── data/conservedReactingMoietiesReference.mat  # RECAPTURED
├── data/reactingMoietyMemoryReference.mat       # RECAPTURED
└── data/rxnFilesConsistentArms/{ACONTm,r0317,r0426}.rxn   # NEW
```

**Structure Decision**: the single toolbox layout. One source file changes behaviour, and the test data sits beside the tests.

## Implementation order (for `/speckit-tasks`)

1. **Setup**: confirm the base and the local data.
2. **Red**:
   - write the molfile-equality test and the planted control;
   - show the test fails on the unchanged source, naming the E33 cases;
   - record conserved-moiety outputs of every fixture and of random n = 500 from the unchanged source, for FR-006.
3. **Fix** (Design 1–5). Run all `testReactingMoieties` tests. Molfile equality must pass. The golden comparisons are expected to fail on bond-level fields only, and on no conserved field.
4. **Recapture** the two references with `captureRenumberedGoldens.m`, write the difference report, and review it. A difference in a conserved field stops the work.
5. **Paper tests**: add the consistent-arm RXN copy and the US3 assertions.
6. **Non-CI**: full collapsed VMH molfile equality and wall time, plus conserved-output equality at random n = 500.
7. **Close-out**: static review, results file, report and receipt.

## Complexity Tracking

| Item | Why needed | Simpler alternative rejected because |
|---|---|---|
| Recapturing golden references | Their stored inputs encode the corrupted bond graphs | Keeping them would pin the defect. They are anchored instead by independent checks (molfile equality, paper values, the authors' code) and a reviewed difference report |
