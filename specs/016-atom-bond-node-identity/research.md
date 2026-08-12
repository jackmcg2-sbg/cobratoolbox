# Phase 0 Research: Reaction-scoped atom/bond node identity

**Feature**: 016-atom-bond-node-identity | **Date**: 2026-08-11

No `[NEEDS CLARIFICATION]` markers were left in `spec.md` — the source investigation already
traced root cause to two specific ID-construction sites and specified the exact replacement
format. This document records the supporting technical findings needed to plan the fix and its
verification.

## Decision: Fix site and exact string format

**Decision**: Change the atom-loop `substrateID`/`productID` construction (lines ~303-308 of
`buildAtomAndBondTransitionMultigraph.m`) and the bond-loop `bondSubstrateID`/`bondProductID`
construction (lines ~592-604) to prepend `model.rxns{i}` and the per-reaction `instances(...)` /
`bondMappings.instances(...)` value, per the format given in the spec. No other line in the
function changes.

**Rationale**: Confirmed by direct source read
(`src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m`):
- Line 258: `instances=atoms.instances;` — already populated per-reaction, in scope at the
  ID-construction site, currently unused there.
- Line 321: `EdgeTable.Trans{k} = [model.rxns{i} '#' substrateID '#' productID];` — proves
  `model.rxns{i}` is already in scope in the same loop iteration, so no new data threading is
  required.
- The bond loop (around line 592) has the analogous `bondMappings.instances` field, confirmed
  present by `readABRXNFile.m` (`bInstances`, propagated by `addBondMappingsRXNFile.m`).
- `dATM = digraph(EdgeTable)` (downstream of both loops) deduplicates by node name — the sole
  mechanism causing the cross-reaction merge; no other line needs to change because everything
  else treats `HeadAtom`/`TailAtom`/`HeadBond`/`TailBond` as opaque keys copied from these two ID
  strings.

**Alternatives considered**:
- *Scope the whole multigraph per reaction instead of sharing one graph across the network*:
  rejected — the governing theory (Rahou et al. 2026, Eq. 11: `N = (VV^T)^{-1}VTE`) defines `V`
  (the code's `M2Ai`) as spanning the whole processed network; a per-reaction-only graph would be
  an architecture change beyond this bug fix and would not match the paper's notation.
- *Use a numeric/hash node ID instead of a delimited string*: rejected — no other line in the
  function reads or parses the string's internal structure (confirmed by grep for `HeadAtom`,
  `TailAtom`, `HeadBond`, `TailBond`, `dATM.Nodes`, `dBTM.Nodes` — all treat it as an opaque key),
  so a delimited string is sufficient and keeps the change minimal and human-readable for
  debugging, consistent with the existing `#`-delimited convention already used for `Trans`.
- *Fix in `readABRXNFile.m` by making `atoms.metNrs` globally unique instead*: rejected by the
  source spec — `readABRXNFile.m` is confirmed correct and out of scope; changing per-file local
  numbering there would be a larger, unjustified change to a file this feature does not need to
  touch (Principle V — smallest coherent dependency set).

## Decision: Verification target — extend the existing test fixture, not a new one

**Decision**: Use `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m`
and its bundled fixture (`data/rxnFiles/{r0317,ACONTm,r0426,r1109}.rxn`) as the primary
verification vehicle, extending it rather than writing a new bespoke test (Principle III: "the
narrowest practical automated test... integrated into the existing harness rather than a
bespoke one").

**Rationale**: Confirmed by reading the fixture RXN files — `r0317.rxn` and `r0426.rxn` both
produce `h2o[m]` (grep-confirmed: both contain `cit[m]/icit[m] -> h2o[m] + HC00342[m]`), and both
are included in the test's 3-reaction sample (`rxnList = {'r0317'; 'ACONTm'; 'r0426'}`) alongside
`options.sanityChecks = 1` already set (line 52 of the test). This is precisely the
multi-reaction, shared-hub-metabolite scenario the bug report describes — the fixture already
reproduces the defect end-to-end without needing new RXN files or a new model subset. Because the
test already asserts the downstream conserved-moiety invariant (`norm(full(arm.L) * N) < tol`),
bond table row counts, and moiety counts, it also already covers Success Criterion SC-003/US3
(no downstream regression) as a side effect of extending it.

**Alternatives considered**:
- *Write a new, separate test targeting `buildAtomAndBondTransitionMultigraph` in isolation*:
  rejected as the primary vehicle (though the task list may still add narrow assertions) —
  Principle III prefers extending the existing harness test over a bespoke one when the existing
  one already exercises the defect, and `testConservedReactingMoieties.m` already does.
- *Use the full R_17357_e/R_84979_e/... reaction sample named in the source investigation*:
  not available as a committed, CI-runnable fixture (those reaction IDs and their RXN files are
  not present under `test/`); the locally available `r0317`/`r0426` pair is an equivalent,
  already-CI-integrated instance of the same defect class (shared metabolite, `h2o[m]`, across
  two of the three sampled reactions) and requires no new fixture data. The source spec's
  acceptance criteria are about the defect *class*, not those specific reaction IDs.

## Decision: Warning-detection mechanism for the test

**Decision**: Wrap the `buildAtomAndBondTransitionMultigraph` call with MATLAB's
`lastwarn`/warning-capture idiom (clear `lastwarn`, call the function, assert `lastwarn` does not
match `'Inconsistent directed (atom|bond) transition multigraph'`), rather than using `evalc` to
capture console text.

**Rationale**: Principle VII-A (evalc suppression prohibition) forbids using `evalc` to suppress
or capture warning-producing calls whose side effects (warnings) are being observed; `evalc` here
would also violate VII-B (warning visibility) if misused to swallow the warning rather than
inspect it. The standard, non-suppressing MATLAB pattern is to reset `[msg, id] = lastwarn('');`
before the call and inspect `lastwarn` afterward — the warning still prints normally to console
(satisfying VII-B) while the test can assert on its (non-)occurrence.

**Alternatives considered**:
- *`evalc` to capture printed warning text*: rejected — Principle VII-A explicitly forbids this
  suppression pattern for exactly this purpose.
- *A custom warning listener / `warning('query', ...)` state toggle*: unnecessary complexity for
  a single boolean assertion; `lastwarn` is the idiomatic, already-used-elsewhere-in-the-toolbox
  mechanism for this.

## Decision: No `/contracts/` artifact

**Decision**: Skip the `/contracts/` directory for this feature.

**Rationale**: `buildAtomAndBondTransitionMultigraph.m` is an internal analysis-pipeline function
with no exported public API surface change (FR-005 requires the signature to remain identical),
no CLI, no service endpoint, and no cross-language binding touched. Per the Phase 1 instruction
("skip if project is purely internal"), and per Principle VIII (no polyglot surface is touched by
this feature), there is no external interface to contract-document beyond the existing MATLAB
function signature itself, which does not change.

## Technical Context resolution

- **Language/Version**: MATLAB (repo baseline R2024b+, per constitution Scientific Computing
  Constraints) — no other language surface is touched.
- **Primary Dependencies**: MATLAB `digraph`/`graph` (Graph and Network Algorithms toolbox
  functions already used throughout this file); no new dependency introduced.
- **Storage**: N/A — no persistent storage; operates on in-memory `model` struct and RXN files
  already read via `readABRXNFile`/`addBondMappingsRXNFile` (unmodified).
- **Testing**: MATLAB `assert`-based tests under `test/verifiedTests/analysis/testReactingMoieties/`,
  run via `test/testAll.m` and CI (`testAllCI_*`); no MILP/LP solver dependency introduced beyond
  what `testConservedReactingMoieties.m` already declares via `prepareTest('needsMILP', true)`.
- **Target Platform**: Headless Linux CI (MATLAB `-batch`), consistent with existing test.
- **Project Type**: Single MATLAB toolbox library (existing `src/`/`test/` layout); no new
  project structure needed.
- **Performance Goals**: No new performance target; fix only changes string-key content for
  existing node/edge construction (same loop structure, same asymptotic cost) — must not
  measurably slow `buildAtomAndBondTransitionMultigraph` on the existing test fixture.
- **Constraints**: Fix confined to `buildAtomAndBondTransitionMultigraph.m` only (FR-005/SC-005);
  no change to `readABRXNFile.m`, `addBondMappingsRXNFile.m`, `identifyConservedReactingMoieties.m`,
  or any RXN file.
- **Scale/Scope**: One MATLAB file, two ID-construction sites (~10-16 changed lines total across
  the atom and bond loops); verification via one extended existing test file.
