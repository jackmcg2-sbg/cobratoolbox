---

description: "Task list template for feature implementation"
---

# Tasks: Reaction-scoped atom/bond node identity in `buildAtomAndBondTransitionMultigraph`

**Input**: Design documents from `/specs/016-atom-bond-node-identity/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: This is a bug-fix/correctness change to node-identity construction; Principle III
requires the narrowest practical test integrated into the existing harness. All test tasks below
extend the existing `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m`,
whose bundled fixture (`r0317.rxn` + `r0426.rxn`, both producing `h2o[m]`) already reproduces the
defect with `options.sanityChecks = 1`. No new test file is created.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Single MATLAB toolbox library (existing `src/`, `test/` layout; see plan.md "Project Structure").
All source edits are confined to one file; all test edits are confined to one existing test file.

---

## Phase 1: Setup

**Purpose**: Confirm preconditions before any edit

- [ ] T001 Confirm the working tree is on branch `016-atom-bond-node-identity`, and that
  `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m` (atom ID
  construction ~lines 303-308, bond ID construction ~lines 592-604) and
  `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m` exist at
  their documented paths (plan.md "Project Structure")

**Checkpoint**: Preconditions confirmed; safe to proceed

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish the pre-fix baseline and confirm the fix approach complies with MATLAB
coding standards before any code changes — MUST complete before user story work begins

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T002 [P] Capture pre-fix baseline: run
  `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m` unmodified
  (current `develop`-derived code) and record (a) whether
  `Inconsistent directed atom transition multigraph` and/or
  `Inconsistent directed bond transition multigraph` warnings fire, and (b) the current
  `diag(M2Ai*M2Ai')` value for `h2o[m]` atom nodes (expected: warnings fire; diagonal inflated,
  not 3) — this is the "before" measurement required by the constitution's Testing and
  reproducibility comparison discipline (quickstart.md Scenario A/B, before-fix baseline)
- [ ] T003 [P] Confirm the fix approach documented in research.md ("Decision: Warning-detection
  mechanism for the test") complies with constitution Principle VII-A (no `evalc` suppression) and
  VII-B (warnings stay visible): the planned `lastwarn`-based assertion pattern must be used in
  T004/T008, not `evalc`-based console capture. Also confirm VII-F: no registered MATLAB
  coding-conventions skill exists in this repo (checked `.claude/skills/`, `.agents/skills/`); the
  openCOBRA style guide is sufficient for this change's size, per plan.md's Constitution Check

**Checkpoint**: Baseline recorded, approach confirmed compliant — user story implementation can now begin

---

## Phase 3: User Story 1 - Sanity check passes on multi-reaction networks sharing hub metabolites (Priority: P1) 🎯 MVP

**Goal**: Eliminate the false-positive `Inconsistent directed atom transition multigraph` and
`Inconsistent directed bond transition multigraph` warnings when a metabolite recurs across
reactions in a processed network, by making atom/bond node identity strings unique per
(reaction, metabolite instance, local number, element) instead of colliding across reactions.

**Independent Test**: Run `testConservedReactingMoieties.m` (which sets
`options.sanityChecks = 1` and samples `r0317`/`ACONTm`/`r0426`, where `r0317` and `r0426` both
produce `h2o[m]`) and confirm neither warning fires.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation (red), per T002 baseline**

- [ ] T004 [US1] Add `lastwarn`-based assertions to
  `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m`, immediately
  after the `buildAtomAndBondTransitionMultigraph` call: clear `lastwarn` before the call, then
  assert afterward that `lastwarn` does not match `Inconsistent directed atom transition
  multigraph` or `Inconsistent directed bond transition multigraph` (per research.md's
  `lastwarn` decision, not `evalc`). Confirm this assertion FAILS on the current unfixed code,
  consistent with the T002 baseline (red state)

### Implementation for User Story 1

- [ ] T005 [US1] Fix atom-transition node identity construction in
  `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m`
  (`substrateID`/`productID`, ~lines 303-308): prepend `model.rxns{i}` and
  `num2str(instances(...))` to the existing `metaboliteID # localAtomNumber # element` format, per
  FR-001 and the exact format in data-model.md ("Entity: Atom transition node")
- [ ] T006 [US1] Fix bond-transition node identity construction in
  `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m`
  (`bondSubstrateID`/`bondProductID`, ~lines 592-604): prepend `model.rxns{i}` and
  `num2str(bondMappings.instances(...))` at both head-atom and tail-atom positions, per FR-002 and
  the exact format in data-model.md ("Entity: Bond transition node reference")
- [ ] T007 [US1] Re-run `testConservedReactingMoieties.m`; confirm the T004 warning assertions now
  PASS (green) and no pre-existing assertion in the file regresses (SC-001)
- [ ] T007b [US1] Add a negative-control assertion proving the fix doesn't mask real defects
  (FR-006 / spec.md Edge Cases #4): construct a minimal case with a genuine atom-count mismatch
  (e.g. temporarily corrupt one `instances`/`atomNumbers` entry in a copied fixture, or use
  `res = (M2Ai*M2Ai')*N - M2Ai*Ti*Ti2R` directly on a deliberately mismatched `M2Ai`), call
  `buildAtomAndBondTransitionMultigraph` with `options.sanityChecks = 1`, and assert the
  `Inconsistent directed atom transition multigraph` warning still fires post-fix

**Checkpoint**: At this point, User Story 1 is fully functional and independently testable — no
false-positive sanity-check warnings on the shared-`h2o[m]` fixture

---

## Phase 4: User Story 2 - Per-species atom/bond node counts reflect true chemistry, not merge artifacts (Priority: P1)

**Goal**: Prove the fix addresses root cause, not just the warning symptom — `diag(M2Ai*M2Ai')`
for a recurring metabolite equals its true, single-instance atom count.

**Independent Test**: After US1's fix, compute `M2Ai*M2Ai'` for the same fixture and confirm the
diagonal entries for `h2o[m]` atom nodes equal 3.

### Implementation for User Story 2

- [ ] T008 [US2] Add a `diag(M2Ai*M2Ai')` assertion for `h2o[m]` atom nodes to
  `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m`, per
  quickstart.md Scenario B and data-model.md's "Downstream invariant" section: every diagonal
  entry belonging to an `h2o[m]` atom node instance equals 3 (not an inflated value); confirm it
  passes given the T005 atom-identity fix (SC-002)

**Checkpoint**: User Stories 1 AND 2 both hold — no false-positive warnings, and the underlying
`M2Ai` invariant is chemically correct

---

## Phase 5: User Story 3 - Downstream conserved/reacting moiety identification is unaffected or improved (Priority: P2)

**Goal**: Confirm the node-identity fix does not sever the cross-reaction graph-isomorphism
matching `identifyConservedReactingMoieties.m` relies on for conserved-moiety detection.

**Independent Test**: Run `identifyConservedReactingMoieties.m` on the fixed `dATM`/`BG` outputs
for the same sample and confirm it completes without new errors, preserving or improving the
bond-change-event resolution count.

### Implementation for User Story 3

- [ ] T009 [US3] Confirm the existing downstream assertions already present in
  `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m`
  (`norm(full(arm.L) * N) < tol`, `size(arm.L) == [2, 4]`, `numel(moietyFormulae) == 2`,
  `numel(reacting.selectedReactionNames) == 2`, `height(brokenBondsTable) == 7`,
  `height(formedBondsTable) == 7`) still pass unchanged after the T005/T006 fix, and record the
  observed bond-change-event resolution count (`height(brokenBondsTable)`, `height(formedBondsTable)`)
  against this fixture's own pre-fix values captured in T002 (preserved or improved, not
  regressed). Note: spec.md's "14/19 sampled reactions" figure refers to the original bug
  report's 8-reaction sample (R_17357_e, R_84979_e, ...), which has no committed fixture in this
  repo (research.md); it is illustrative context for SC-003's intent, not a literal target
  measurable on `r0317`/`ACONTm`/`r0426`

**Checkpoint**: All three user stories independently verified — defect fixed, invariant correct,
no downstream regression

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Confinement check, full-category regression pass, and mandatory reporting

- [ ] T010 [P] Run quickstart.md Scenario D:
  `git diff --stat develop...016-atom-bond-node-identity -- src/` and confirm the only file listed
  is `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m` (FR-005,
  FR-008, SC-005)
- [ ] T011 Run the full `test/verifiedTests/analysis/` reactingMoieties/conservedMoieties test
  category and diff pass/fail results against the T002 pre-fix baseline; confirm no new failures
  are introduced (SC-004)
- [ ] T012 Report files edited, checks run, tests passed, tests failed, and any behaviors not yet
  verified, per constitution Principle III's post-implementation reporting requirement
- [ ] T013 Create the implementation receipt in
  `specs/016-atom-bond-node-identity/agent-runs/<UTC-timestamp>-<short-task-or-run-name>/implementation-receipt.md`,
  with the actual final user-facing agent completion response copied verbatim into the
  `Final response` section (constitution Implementation Receipt Ledger)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories (the baseline
  in T002 is what T004's "confirm it fails pre-fix" and T011's regression diff compare against)
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - US1 (T004-T007) must complete before US2 (T008), because T008's assertion depends on the
    atom-identity fix (T005) already being applied
  - US3 (T009) depends on US1 (T005, T006) being applied, since it verifies the fixed `dATM`/`BG`
    outputs
- **Polish (Phase 6)**: Depends on all three user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — no dependency on other stories
- **User Story 2 (P1)**: Depends on User Story 1's implementation (T005) being applied, since the
  `M2Ai` diagonal is only correct once the atom-identity fix is in place; its assertion (T008) is
  independently *testable* (a standalone check runnable on its own), even though it is not
  independently *implementable* before US1
- **User Story 3 (P2)**: Depends on User Story 1's implementation (T005, T006) for the same reason
  — it verifies the already-fixed graph outputs

### Within Each User Story

- Tests before/alongside implementation: T004 (test, written first) → T005/T006 (implementation) → T007 (confirm green)
- US2 and US3 add verification-only tasks on top of US1's already-applied fix (no further source edits)

### Parallel Opportunities

- T002 and T003 (Foundational) can run in parallel — different concerns, no shared file
- T005 and T006 both edit the same file
  (`buildAtomAndBondTransitionMultigraph.m`) and MUST run sequentially, not in parallel
- T010 (git diff check) can run in parallel with T011 (full test category run) — different
  activities, no shared file state dependency

---

## Parallel Example: Foundational Phase

```bash
# Launch both foundational checks together (different concerns, no shared file):
Task: "Capture pre-fix baseline by running testConservedReactingMoieties.m unmodified"
Task: "Confirm the lastwarn-based fix approach complies with Principle VII-A/VII-B"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — establishes the before-fix baseline)
3. Complete Phase 3: User Story 1 (T004-T007) — this alone eliminates the false-positive warnings
4. **STOP and VALIDATE**: Confirm T007's green assertions independently
5. This is already the shippable fix; User Stories 2 and 3 add depth of verification, not
   additional source changes

### Incremental Delivery

1. Complete Setup + Foundational → baseline recorded
2. Add User Story 1 (T004-T007) → warnings eliminated → this is the MVP fix
3. Add User Story 2 (T008) → proves root-cause correctness via the `M2Ai` diagonal invariant
4. Add User Story 3 (T009) → proves no downstream regression in conserved-moiety identification
5. Polish (T010-T013) → confinement check, full regression pass, mandatory reporting and receipt

---

## Notes

- [P] tasks = different files or independent concerns, no dependencies
- [Story] label maps task to specific user story for traceability
- T005 and T006 are the only source-code edits in this entire feature; every other task is a test
  addition, a verification run, or a reporting step
- Verify T004's warning assertion fails before T005/T006 are applied (red), then passes after
  (green)
- Avoid: editing `readABRXNFile.m`, `addBondMappingsRXNFile.m`, `identifyConservedReactingMoieties.m`,
  `checkABRXNFiles.m`, or any RXN file — all are out of scope per spec.md and FR-005/FR-008
