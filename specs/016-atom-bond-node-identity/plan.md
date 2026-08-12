# Implementation Plan: Reaction-scoped atom/bond node identity in `buildAtomAndBondTransitionMultigraph`

**Branch**: `016-atom-bond-node-identity` | **Date**: 2026-08-11 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/016-atom-bond-node-identity/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

`buildAtomAndBondTransitionMultigraph.m` builds atom/bond transition node identity strings without
a reaction identifier or per-reaction instance number, so `digraph`'s name-based node
deduplication silently merges atom/bond occurrences from different reactions whenever they share
a metabolite ID, local atom/bond number, and element — most visibly for hub metabolites (water,
O2, coenzyme A) that recur across reactions in a processed network. This corrupts the
theory-required invariant that `diag(M2Ai*M2Ai')` equal each species' true, reaction-invariant
atom count, producing false-positive `Inconsistent directed atom/bond transition multigraph`
sanity-check warnings. The fix (confined to two ID-construction sites in this one file) prepends
the current reaction identifier (`model.rxns{i}`, already in scope) and the already-computed
per-reaction instance number (`instances`/`bondMappings.instances`, already read but currently
unused in ID construction) to the existing local numbering, making every node's identity unique
per true atom/bond occurrence across the whole network while preserving the single shared
multigraph the governing theory (Rahou et al. 2026, Eq. 11-12) requires.

## Technical Context

**Language/Version**: MATLAB (repository baseline R2024b+)

**Primary Dependencies**: MATLAB `digraph`/`graph` (Graph and Network Algorithms), already used
throughout the target file; no new dependency

**Storage**: N/A (in-memory `model` struct and RXN files, read via existing unmodified
`readABRXNFile.m`/`addBondMappingsRXNFile.m`)

**Testing**: MATLAB `assert`-based test under `test/verifiedTests/analysis/testReactingMoieties/`
(extends the existing `testConservedReactingMoieties.m`, which already reproduces the defect via
its `r0317`/`r0426` shared-`h2o[m]` fixture with `options.sanityChecks = 1`), run via
`test/testAll.m` and CI (`testAllCI_*`)

**Target Platform**: Headless Linux CI (`matlab -batch`), consistent with the existing test

**Project Type**: Single MATLAB toolbox library (existing `src/`/`test/` layout; no new project
structure)

**Performance Goals**: No new performance target; the fix only changes string-key content built
inside the existing per-transition loops (same iteration count, same asymptotic cost) — must not
measurably slow `buildAtomAndBondTransitionMultigraph` on the existing test fixture

**Constraints**: Fix confined to
`src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m` only; no change to
`readABRXNFile.m`, `addBondMappingsRXNFile.m`, `identifyConservedReactingMoieties.m`, or any RXN
file (FR-005, FR-008, SC-005)

**Scale/Scope**: One MATLAB file, two ID-construction sites (~10-16 changed lines total across the
atom-transition and bond-transition loops); verification via one extended existing test file plus
targeted `M2Ai`-diagonal assertions

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Scientific code quality** (Principle I): The boundary touched is node-identity string
  construction inside the atom/bond transition-multigraph builder — not `S`, bounds, objective,
  or status semantics. The change corrects `M2Ai` (paper's `V`) so `diag(M2Ai*M2Ai')` matches each
  species' true atom count, per the cited governing theory (Rahou, Haraldsdóttir, Martinelli,
  Thiele, Fleming, J. Theoretical Biology 621 (2026) 112348, Eq. 11-12). No model field semantics
  change; `model.S`, `model.rxns`, `model.mets` are read-only inputs, unmodified.
- **Testing and reproducibility** (Principle III): Extend
  `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m` (its bundled
  `r0317`/`r0426` fixture already shares `h2o[m]` across two of the three sampled reactions with
  `options.sanityChecks = 1` already set — it already reproduces the defect) rather than adding a
  bespoke test. Add: (a) a `lastwarn`-based assertion that neither
  `Inconsistent directed atom transition multigraph` nor
  `Inconsistent directed bond transition multigraph` fires; (b) an assertion that
  `diag(M2Ai*M2Ai')` for `h2o[m]` atom nodes equals 3. Runs via `test/testAll.m` and CI
  (`testAllCI_*`); already declares `prepareTest('needsMILP', true)` so it skips gracefully where
  no MILP solver is installed.
- **User experience and diagnostics**: The `options.sanityChecks` warning mechanism itself is
  preserved unchanged (still fires on genuine per-file inconsistencies, per FR-006/edge cases) —
  only the false-positive trigger (name collision) is removed. No new print/verbose output is
  added; `printLevel`/console behavior is otherwise untouched.
- **Performance and numerical integrity**: No performance goal beyond "no measurable slowdown" —
  the fix changes string concatenation inside existing loops with unchanged iteration counts and
  control flow; no new solver call, no algorithmic complexity change. Solution quality is
  unaffected because this function computes no optimization solution; it is a graph-construction
  step upstream of `identifyConservedReactingMoieties.m`'s minimum-set-cover MILP, which is
  unmodified.
- **External-solver configuration audit**: N/A — this feature invokes no external solver directly.
  (The extended test's downstream call to `identifyConservedReactingMoieties.m` already declares
  its MILP requirement via the pre-existing `prepareTest('needsMILP', true)`; this feature adds no
  new solver configuration surface.)
- **Spec-driven scope control** (Principle V): Edit only
  `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m`. Read-only for
  this feature: `readABRXNFile.m`, `addBondMappingsRXNFile.m`, `identifyConservedReactingMoieties.m`,
  `checkABRXNFiles.m`, and all RXN files (confirmed correct and out of scope by the source
  investigation). Test-file edit: extend
  `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m` in place. No
  new dependency, helper file, or abstraction is introduced.
- **MATLAB coding standards** (Principle VII): No `evalc` used anywhere in this change — warning
  detection in the extended test uses `lastwarn`, not console-capture suppression (VII-A/VII-B).
  No new `try/catch` block is introduced (VII-C N/A). No `nargin`-based optional-argument handling
  is touched (VII-D N/A — the function signature does not change). The two edited code blocks are
  internal loop bodies, not new/substantially-revised function headers, so the openCOBRA help
  header (VII-E) is unaffected; existing `camelCase`, spacing, and no-parenthesis-`if` conventions
  (VII-G) are preserved in the edited lines. Per VII-F, searched for a registered MATLAB
  coding-conventions/linting skill (`.claude/skills/`, `.agents/skills/`) — none exists in this
  repo. Given the change is two ~4-line string-concatenation edits inside existing loops (no new
  function, no new vectorisation/allocation/handle-class pattern), the existing openCOBRA style
  guide (VII-G) is judged sufficient; no new project skill is proposed for a change this narrow.
- **Parameter-setting fidelity**: N/A — this feature ports no code into another language or a
  literate document.
- **Artifact placement** (Principle IX): No new files are created; the sole edited source file
  already lives at its correct location
  (`src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m`), and the sole
  edited test file already lives at its correct location
  (`test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m`). No
  generated output, new dependency manifest, or data file is introduced.

**Gate result**: PASS — no violations; Complexity Tracking is not required.

## Project Structure

### Documentation (this feature)

```text
specs/016-atom-bond-node-identity/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

No `contracts/` directory: this feature touches no external interface (see research.md, "No
`/contracts/` artifact" — internal analysis function, unchanged signature, no CLI/API/binding).

### Source Code (repository root)

```text
src/analysis/topology/reactingMoieties/
├── buildAtomAndBondTransitionMultigraph.m   # EDITED (the only source file this feature touches)
├── readABRXNFile.m                          # read-only (out of scope, confirmed correct)
├── addBondMappingsRXNFile.m                 # read-only (out of scope, confirmed correct)
├── identifyConservedReactingMoieties.m      # read-only (downstream consumer, verified compatible)
└── checkABRXNFiles.m                        # read-only (out of scope)

test/verifiedTests/analysis/testReactingMoieties/
├── testConservedReactingMoieties.m          # EDITED (extended with warning + M2Ai-diagonal asserts)
└── data/rxnFiles/                           # existing fixture, unmodified
    ├── r0317.rxn                            # shares h2o[m] with r0426.rxn (reproduces the defect)
    ├── ACONTm.rxn
    ├── r0426.rxn
    └── r1109.rxn
```

**Structure Decision**: Single MATLAB toolbox library, existing layout (Principle IX). This is a
targeted bug fix confined to one existing `src/analysis/topology/reactingMoieties/` file, verified
by extending the one existing test file already covering that domain
(`test/verifiedTests/analysis/testReactingMoieties/`). No new directory, subfolder, or project
structure is introduced.

## Complexity Tracking

*No Constitution Check violations — this section is not applicable.*
