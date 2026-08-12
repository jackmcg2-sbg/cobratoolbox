# Implementation Plan: Correctly root-cause and fix atom/bond node-identity defect in `buildAtomAndBondTransitionMultigraph`

**Branch**: `017-fix-atom-bond-node-identity` | **Date**: 2026-08-11 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/017-fix-atom-bond-node-identity/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

`buildAtomAndBondTransitionMultigraph.m` merges atom/bond nodes across reactions that share a
metabolite, because node identity omits the reaction and per-reaction instance. Feature 016's fix
for this (prepend reaction ID + instance number) is confirmed correct in isolation, but applying it
alone — as feature 016 did — regresses a previously-passing test and crashes the bond-transition
loop, because two other parts of the same function implicitly depend on the old merge-by-species
behavior: a bond-loop atom lookup that matches by loose `(mets, AtomNumber, Element)` tuple instead
of the identity string (lines 611-618), and the atom/bond consistency-check formulas (lines 498,
799), whose `diag(M2Ai*M2Ai')`-based residual mathematically requires the per-metabolite atom count
to be a single-instance, reaction-invariant scalar — which only held before the fix because merging
kept it artificially capped. This plan implements all three parts together (node identity, lookup
fix, formula correction), each already cross-checked against actual MATLAB execution in this
repository during planning (see research.md), including a correction to one of the plan's own
initial ideas caught by re-verifying rather than trusting a prior conclusion.

## Technical Context

**Language/Version**: MATLAB (repository baseline R2024b+); MATLAB R2024b confirmed installed and
usable in this environment at `/usr/local/MATLAB/R2024b/bin/matlab` (not on `PATH`)

**Primary Dependencies**: MATLAB `digraph`/`graph`, `spdiags`, and the existing `mapAontoBOld`
helper (`src/analysis/topology/reactingMoieties/mapAontoBOld.m`), already used throughout the
target file for the same kind of edge-to-node value projection this fix reuses; no new dependency

**Storage**: N/A — in-memory `model` struct and RXN files via unmodified
`readABRXNFile.m`/`addBondMappingsRXNFile.m`

**Testing**: MATLAB `assert`-based tests under
`test/verifiedTests/analysis/testReactingMoieties/`, extending `testConservedReactingMoieties.m`
and adding a new fixture for the within-reaction multi-instance case (research.md Decision 4); run
via `test/testAll.m` and CI (`testAllCI_*`); existing `prepareTest('needsMILP', true)` requirement
declaration carries forward unchanged

**Target Platform**: Headless Linux CI (`matlab -batch`), consistent with `initCobraToolbox(false,
'agent')` fast-init used throughout this session's verification

**Project Type**: Single MATLAB toolbox library (existing `src/`/`test/` layout); no new project
structure

**Performance Goals**: No new performance target; the fix adds one `mapAontoBOld` call (linear in
node/edge count, same cost class as the five identical calls already in this file) and a bounded
per-metabolite loop for the corrected `d` — negligible relative to existing RXN-file parsing cost

**Constraints**: Fix confined to
`src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m` (FR-009); no
change to `readABRXNFile.m`, `addBondMappingsRXNFile.m`, `identifyConservedReactingMoieties.m`, or
any existing RXN file; Parts A, B, and C MUST be implemented and tested together, not merged
incrementally in isolation (Part A alone regresses and crashes — proven empirically, not
theoretically, during feature 016)

**Scale/Scope**: One source file, three coordinated internal changes plus one new/located test
fixture; verification via the existing test file extended with new assertions covering all three
parts and both previously-discovered failure modes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Scientific code quality** (Principle I): The boundary touched is node-identity construction,
  one node-lookup mechanism, and two consistency-check formulas inside the atom/bond transition-
  multigraph builder — not `S`, bounds, objective, or status semantics. The corrected `M2Ai`/`d`
  restore the invariant the cited governing theory (Rahou et al., J. Theoretical Biology 621
  (2026) 112348, Eq. 11-12) actually requires (per-species single-instance atom count), verified
  algebraically (research.md Decision 3) against this session's own empirical measurement, not
  assumed. `model.S`, `model.rxns`, `model.mets` remain read-only inputs.
- **Testing and reproducibility** (Principle III): Extend
  `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m` with: (a)
  node-count and no-warning assertions (Part A, US1), (b) an implicit no-crash assertion (Part B,
  US2, satisfied by the call itself completing) plus explicit `numedges(dBTM) > 0`, (c) a corrected
  `res=0` assertion and a cross-reaction equality assertion (Part C, US3), (d) a new/located
  fixture exercising a within-reaction multi-instance metabolite (FR-007, research.md Decision 4),
  and (e) a constructed genuine-inconsistency case asserting the new specific error fires (FR-006).
  All prior assertions in the test (conserved-moiety invariant, bond table counts) must continue
  to pass unchanged. Declares `prepareTest('needsMILP', true)` already, unchanged.
- **User experience and diagnostics**: The `options.sanityChecks` warning mechanism is preserved
  (still fires on genuine per-file inconsistencies); a *new*, more specific, named error is added
  for the cross-reaction atom/bond-count mismatch case (FR-006), distinguishing a real data defect
  from the false positive this feature eliminates — this is an additive diagnostic improvement, not
  a removed one. No new default-on verbose output; `printLevel` behavior otherwise untouched.
- **Performance and numerical integrity**: No performance goal beyond "no measurable slowdown."
  One `mapAontoBOld` call (same cost class as five already present) plus a per-metabolite loop
  bounded by the number of reactions each metabolite appears in — small relative to existing
  RXN-file parsing. This function computes no optimization solution itself; it is upstream of
  `identifyConservedReactingMoieties.m`'s MILP, which is unmodified and unaffected in cost.
- **External-solver configuration audit**: N/A — no external solver is invoked by this feature's
  changes (the extended test's existing downstream MILP call via `identifyConservedReactingMoieties.m`
  already declares its requirement and is unmodified).
- **Spec-driven scope control** (Principle V): Edit only
  `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m`. Read-only:
  `readABRXNFile.m`, `addBondMappingsRXNFile.m`, `identifyConservedReactingMoieties.m`,
  `checkABRXNFiles.m`, and all existing RXN files. Test-file edits: extend
  `testConservedReactingMoieties.m` in place; possibly add one new fixture directory/files under
  `test/verifiedTests/analysis/testReactingMoieties/data/` (research.md Decision 4) — an addition,
  not a modification, and confined to the same test's existing fixture location. No new dependency
  or abstraction beyond the already-present `mapAontoBOld` helper.
- **MATLAB coding standards** (Principle VII): No `evalc` anywhere in this change (VII-A/B N/A —
  no console-capture pattern is used; the new specific error (FR-006) is raised via `error(...)`,
  not suppressed). Any new `try/catch` introduced for the specific-error path (if implemented that
  way) MUST propagate `ME.stack` per VII-C. No `nargin`-based optional-argument handling is touched
  (VII-D N/A — signature unchanged). The edited code is internal loop-body logic, not a new/
  substantially-revised function header, so the openCOBRA help header (VII-E) is unaffected; the
  function's existing `OUTPUT` doc section already documents `M2Ai`/`dATM.Nodes` fields this
  feature does not add to, so no header update is required beyond what the edit itself implies.
  Existing `camelCase`, spacing, and no-parenthesis-`if` conventions (VII-G) preserved in new code.
  Per VII-F: no registered MATLAB coding-conventions/linting skill exists in this repo (checked
  `.claude/skills/`, `.agents/skills/`, consistent with feature 016's prior finding); given the
  change reuses an existing helper (`mapAontoBOld`) and existing code patterns rather than
  introducing new MATLAB idioms, the openCOBRA style guide is judged sufficient.
- **Parameter-setting fidelity**: N/A — no code is ported into another language or a literate
  document.
- **Artifact placement** (Principle IX): No new files beyond the one edited source file and (if
  research.md Decision 4 requires it) new RXN fixture files placed beside the existing test's
  fixtures (`test/verifiedTests/analysis/testReactingMoieties/data/rxnFiles/` or a
  feature-specific subdirectory there) — the correct location for test fixtures per Principle IX.
  No generated output, new dependency manifest, or misplaced data file.

**Gate result**: PASS — no violations; Complexity Tracking is not required.

## Project Structure

### Documentation (this feature)

```text
specs/017-fix-atom-bond-node-identity/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

No `contracts/` directory: internal analysis function, unchanged public signature, no CLI/API/
binding (research.md Decision 5).

### Source Code (repository root)

```text
src/analysis/topology/reactingMoieties/
├── buildAtomAndBondTransitionMultigraph.m   # EDITED (Parts A+B+C, the only source file touched)
├── mapAontoBOld.m                            # read-only (existing helper, reused as-is)
├── readABRXNFile.m                           # read-only
├── addBondMappingsRXNFile.m                  # read-only
├── identifyConservedReactingMoieties.m       # read-only (downstream consumer, unaffected)
└── checkABRXNFiles.m                         # read-only

test/verifiedTests/analysis/testReactingMoieties/
├── testConservedReactingMoieties.m          # EDITED (extended with Parts A/B/C assertions)
└── data/rxnFiles/                           # existing fixture, unmodified
    ├── r0317.rxn                            # shares h2o[m] with r0426.rxn
    ├── ACONTm.rxn
    ├── r0426.rxn
    ├── r1109.rxn
    └── [possible new fixture: within-reaction multi-instance metabolite, research.md Decision 4]
```

**Structure Decision**: Single MATLAB toolbox library, existing layout (Principle IX). A targeted,
three-part bug fix confined to one existing `src/analysis/topology/reactingMoieties/` file,
verified by extending the one existing test already covering that domain, with at most one new
fixture addition in that test's existing fixture directory. No new directory, subfolder, or
project structure.

## Complexity Tracking

*No Constitution Check violations — this section is not applicable.*
