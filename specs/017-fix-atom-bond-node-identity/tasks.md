---

description: "Task list template for feature implementation"
---

# Tasks: Correctly root-cause and fix atom/bond node-identity defect in `buildAtomAndBondTransitionMultigraph`

**STATUS (2026-08-11, post-`/speckit-implement` attempt)**: T001-T010 were executed and Parts A/B/C
+ two of three `identifyConservedReactingMoieties.m` duplicate-check fixes were verified correct
in isolation (`res=0` exactly, no crash) — but the **entire change was reverted** (source tree
confirmed clean, matches `develop`) because it regresses `testConservedReactingMoieties.m` from
passing to failing at a third, newly-discovered moiety-level duplicate check that does not follow
the same fix pattern (see spec.md FR-013, research.md Decision 6). **No task below is marked
complete** because nothing shipped, but the verified code for T005-T010 (and the two
`identifyConservedReactingMoieties.m` fixes not originally in this task list) is preserved
verbatim in research.md for re-application once FR-013 is resolved. A new task, T022, is required
before T011 can pass. Re-running this task list from T005 onward should be fast: the code is
already known-correct, just needs to be re-typed alongside T022's resolution.

**Input**: Design documents from `/specs/017-fix-atom-bond-node-identity/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md,
data-model.md, quickstart.md

**Tests**: This is a bug-fix/correctness change; Principle III requires the narrowest practical
test integrated into the existing harness. All test tasks below extend the existing
`test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m` and, where
research.md Decision 4 requires it, add one new fixture under that test's existing fixture
directory. No new test file is created.

**Critical constraint (plan.md Technical Context)**: Parts A, B, and C MUST be implemented and
tested together, not merged incrementally in isolation — Part A alone (node identity) regresses a
previously-passing case and crashes the bond-transition loop, proven empirically during feature
016. This is reflected below: all three parts' source edits live in the User Story 1 phase, since
US1's own acceptance criteria (no warning, correct node count) cannot be observed with Part A alone
in place. User Stories 2 and 3 add verification-specific assertions on top of the same already-
applied fix, not further source edits — the same pattern used successfully in feature 016's task
breakdown.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing
of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Single MATLAB toolbox library (existing `src/`, `test/` layout; see plan.md "Project Structure").
All source edits are confined to one file; all test edits are confined to one existing test file
plus at most one new fixture addition.

---

## Phase 1: Setup

**Purpose**: Confirm preconditions before any edit

- [ ] T001 Confirm the working tree is on branch `017-fix-atom-bond-node-identity`, MATLAB R2024b
  is reachable at `/usr/local/MATLAB/R2024b/bin/matlab` (not on `PATH`), and
  `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m` still has its
  documented line numbers for: atom-loop identity construction (~303-308), bond-loop identity
  construction (~592-603), the bond-loop atom lookup (611-618), the atom-level consistency check
  (line 498), and the bond-level consistency check (line 799) — re-confirm with `grep -n` rather
  than trusting these numbers from the plan, since they may have shifted

**Checkpoint**: Preconditions confirmed; safe to proceed

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish the pre-fix baseline, locate or determine the need to construct a
within-reaction multi-instance fixture, and confirm MATLAB coding-standards compliance — MUST
complete before user story work begins

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T002 [P] Capture pre-fix baseline via actual MATLAB execution (`initCobraToolbox(false,
  'agent')` then run
  `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m` unmodified):
  record (a) `lastwarn` state (expected: empty, no warning), (b) the count of `h2o[m]` atom nodes
  in `dATM.Nodes` (expected: 3, merged across `r0317`/`r0426`), (c) `diag(M2Ai*M2Ai')` for
  `h2o[m]` (expected: 3) — this is the "before" measurement quickstart.md and later regression
  tasks (T011, T023) compare against
- [ ] T003 [P] Scan for an existing in-repo case of a metabolite with `instances > 1` within a
  single reaction (research.md Decision 4): via MATLAB, call `readABRXNFile` across the RXN files
  under `test/verifiedTests/analysis/testReactingMoieties/data/rxnFiles/`,
  `tutorials/analysis/conservedMoieties/data/mini-ctf/rxns/atomMapped/`,
  `tutorials/analysis/conservedMoieties/data/mini-ctf2/rxns/atomMapped/`, and
  `tutorials/analysis/atomicallyResolveReconstruction/data/atomMapped/`, checking
  `max(atoms.instances) > 1` per file. Document the result: if found, record the file/reaction; if
  not found in any corpus, document that a minimal synthetic RXN file pair must be constructed
  under `test/verifiedTests/analysis/testReactingMoieties/data/rxnFiles/` (or a
  feature-specific subdirectory there) for T012
- [ ] T004 [P] Confirm MATLAB coding-standards compliance for the planned edits (constitution
  Principle VII, per plan.md's Constitution Check): no `evalc` will be used; the new specific error
  for cross-reaction/lookup mismatches (T008, T009, T010) will use `error(...)` directly, not a
  suppressed `try/catch`; confirm (again) no registered MATLAB linting/conventions skill exists
  under `.claude/skills/`/`.agents/skills/`

**Checkpoint**: Baseline recorded, fixture path decided, compliance confirmed — user story
implementation can now begin

---

## Phase 3: User Story 1 - Node identity is disambiguated per reaction and instance, without regressing the sanity check (Priority: P1) 🎯 MVP

**Goal**: Eliminate cross-reaction atom/bond node merging (Part A), while keeping the sanity check
passing on the currently-clean `r0317`/`ACONTm`/`r0426` fixture — which requires Parts B and C
(below) to be implemented in the same pass, since Part A alone crashes/regresses before this
story's own acceptance criteria can even be observed.

**Independent Test**: Run `testConservedReactingMoieties.m`'s fixture; confirm no warning fires and
`dATM.Nodes` shows 6 distinct `h2o[m]` atom nodes (not 3 merged).

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation (red), per T002 baseline**

- [ ] T005 [US1] Add to
  `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m`, immediately
  after the `buildAtomAndBondTransitionMultigraph` call: a `lastwarn`-based assertion that no
  `Inconsistent directed atom/bond transition multigraph` warning fires, and an assertion that
  `numel(find(strcmp(dATM.Nodes.mets, 'h2o[m]')))` equals 6. Confirm the node-count assertion FAILS
  on the current unfixed code (it will read 3), consistent with T002 (red state for that
  assertion; the warning assertion will already pass pre-fix per T002 and is a regression guard)

### Implementation for User Story 1

- [ ] T006 [US1] Apply Part A atom-loop identity fix in
  `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m`
  (`substrateID`/`productID`, ~lines 303-308): prepend `model.rxns{i}` and
  `num2str(instances(...))`, per research.md Decision 1 / data-model.md "Atom transition node"
- [ ] T007 [US1] Apply Part A bond-loop identity fix in the same file
  (`bondSubstrateID`/`bondProductID`, ~lines 592-603): prepend `model.rxns{i}` and
  `num2str(bondMappings.instances(...))` at both head/tail positions, per Decision 1 /
  data-model.md "Bond transition node reference"
- [ ] T008 [US1] Apply Part B bond-loop lookup fix in the same file (~lines 611-618): for each of
  the four atom references (substrate-bond head/tail, product-bond head/tail), reconstruct the
  target key using the exact same format as T006/T007, match against `dATME.Nodes.Atom` (confirmed
  by execution to hold this qualified string — research.md Decision 2, NOT `dATME.Nodes.Name`,
  which does not exist at this point in the function), and raise a specific, named error (e.g.
  `buildAtomAndBondTransitionMultigraph:ambiguousBondAtomLookup`) if `numel(matchIdx) ~= 1`,
  identifying the reaction and target key. Reuse `matchIdx` for the corresponding `...Index`
  assignment rather than recomputing
- [ ] T009 [US1] Apply Part C atom-side consistency-check fix in the same file (line 498 and its
  diagnostic block): add a `NodeRxn` vector via `mapAontoBOld` keyed on `dATM.Nodes.AtomIndex`
  (per research.md Decision 3, step 1); compute the corrected per-metabolite `d` sourced from one
  reaction's occurrence normalized by that reaction's stoichiometric coefficient (step 2); under
  `options.sanityChecks`, cross-validate `d` against a second reaction occurrence where one exists
  and raise a specific, named error (e.g.
  `buildAtomAndBondTransitionMultigraph:inconsistentAtomCount`) on mismatch; replace
  `res=(M2Ai*M2Ai')*N - M2Ai*Ti*Ti2R` with `res = D*N - M2Ai*Ti*Ti2R` using the corrected `D`
  (step 3), and update the `N2` diagnostic-display block to use the same corrected `d`/`D`
- [ ] T010 [US1] Apply the analogous Part C bond-side consistency-check fix in the same file (line
  799 and its diagnostic block), substituting `M2BiE`/`M2BiW`/`BTiE`/`BTi2R` for the atom-side
  equivalents, per research.md Decision 3, step 4
- [ ] T011 [US1] Re-run `testConservedReactingMoieties.m` via actual MATLAB execution; confirm the
  T005 assertions now PASS (green — no warning, 6 distinct `h2o[m]` nodes) and no pre-existing
  assertion in the file regresses (SC-001)
- [ ] T012 [US1] Using the fixture/reaction identified or constructed in T003, add a test to
  `testConservedReactingMoieties.m` (or a new test file beside it if a wholly separate fixture was
  constructed) asserting the within-reaction multi-instance metabolite's atom nodes are correctly
  disambiguated by `instances` value; run it via actual MATLAB execution and confirm it passes
  (US1 Acceptance Scenario 3, FR-007, SC-002)

**Checkpoint**: User Story 1 fully functional and independently testable — node identity correctly
disambiguated, no false-positive warning, within-reaction multi-instance case covered

---

## Phase 4: User Story 2 - Every non-ID-based node-lookup site is identified and kept consistent with the new identity format (Priority: P1)

**Goal**: Confirm the bond-loop lookup fix (T008) is both correct and complete — no other
tuple-based, non-ID-string lookup site was missed.

**Independent Test**: Re-run the full-file search for tuple-based node lookups; confirm lines
611-618 is still the only such site and that it now resolves correctly; confirm the full test
category runs with no crash.

### Implementation for User Story 2

- [ ] T013 [US2] Re-run the full-file grep for tuple-based (non-ID-string) node lookups against
  `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m` as edited (T006-
  T010 applied): search for `ismember(...Nodes.mets...)` combined with `Nodes.AtomNumber==` or
  similar patterns; confirm lines 611-618 (now fixed per T008) remain the only site expecting
  exactly one match, and that the M2Ai/M2BiE-construction sites (which deliberately match many
  rows) are unaffected (US2 Acceptance Scenario 1, FR-008)
- [ ] T014 [US2] Run the full existing `test/verifiedTests/analysis/` reactingMoieties/
  conservedMoieties test category via actual MATLAB execution; confirm no crash occurs anywhere in
  `buildAtomAndBondTransitionMultigraph.m` (US2 Acceptance Scenario 2)

**Checkpoint**: Lookup-site fix confirmed correct and exhaustive

---

## Phase 5: User Story 3 - The consistency-check formulas correctly express the single-instance invariant (Priority: P1)

**Goal**: Prove the corrected `res` formula (T009, T010) is mathematically sound — zero residual on
a genuinely consistent network, cross-reaction agreement holds, and a genuinely inconsistent case
is caught with a distinct, diagnosable error rather than silently tolerated or conflated with the
ordinary false positive this feature eliminates.

**Independent Test**: Compute the corrected per-instance count for `h2o[m]` from both `r0317` and
`r0426` independently and confirm they agree; confirm `res = 0` for the fixture; construct a
genuinely-inconsistent case and confirm the new specific error fires.

### Implementation for User Story 3

- [ ] T015 [US3] Add an assertion to `testConservedReactingMoieties.m` (or a diagnostic accessible
  from the test) confirming `res` is zero (within a justified floating-point tolerance) for every
  metabolite on the `r0317`/`ACONTm`/`r0426` fixture post-fix (US3 Acceptance Scenario 1, SC-003)
- [ ] T016 [US3] Add an assertion confirming the T009 cross-reaction equality check: for `h2o[m]`
  (appearing in both `r0317` and `r0426`), the corrected per-instance count computed independently
  from each reaction's occurrence agrees (both equal 3) (US3 Acceptance Scenario 2, FR-006)
- [ ] T017 [US3] Construct a minimal case where a metabolite's local atom numbering genuinely
  differs between two RXN files that both use it (e.g. a copied/modified pair of the `r0317`/
  `r0426`-style fixture with one file's `h2o[m]` MOL block atom order deliberately reordered), add
  a test calling `buildAtomAndBondTransitionMultigraph` with `options.sanityChecks = 1` on it, and
  assert the specific, named error from T009 fires — not the generic
  `Inconsistent directed atom transition multigraph` warning, and not silent success (US3
  Acceptance Scenario 3, FR-006, SC-004)

**Checkpoint**: All three user stories independently verified — node identity fixed, lookup sites
consistent, consistency-check formulas mathematically correct and diagnostically sound

---

## Phase 5b: BLOCKING — identifyConservedReactingMoieties.m duplicate checks (discovered during implementation, FR-009/FR-013)

**Goal**: `identifyConservedReactingMoieties.m` independently recomputes the same defective
formula three times (confirmed by full-file grep: lines ~254, ~547, ~1273 in the unmodified file).
This phase MUST complete before Phase 6, because Parts A/B/C + Phase 3-5 alone regress
`testConservedReactingMoieties.m` from passing to failing (confirmed: unmodified `develop` passes
this test end-to-end; verified via `git stash` + full test run).

- [ ] T018b Apply the identical RHS-read fix pattern (research.md Decision 3, as revised) to
  `identifyConservedReactingMoieties.m` line ~254 (`res=M2Ai*M2Ai'*N - M2Ai*Ti*Ti2R`) — add local
  `mets`/`rxns`/`RHSatom`/`d`/`D` (this function computes these independently, does not reuse
  `buildAtomAndBondTransitionMultigraph`'s outputs) and replace with `res=D*N - RHSatom`. Verified
  working code preserved in research.md ("identifyConservedReactingMoieties.m duplicate checks #1
  and #2" section) — re-apply verbatim, do not re-derive.
- [ ] T018c Apply the fix to line ~547 (`res=M2A*M2A'*N - M2A*A*A2R`) by reusing T018b's `D`
  directly (`res=D*N - M2A*A*A2R`) — no new derivation needed, since the file's own sanity check
  at line ~465 already asserts `M2A` is identical to `M2Ai`. Verified working code preserved in
  research.md.
- [ ] T019b **[NEW — requires investigation, not a mechanical port]** Resolve the moiety-level
  check at line ~1273 (`res = M2M*M2M'*N - M2M*M*M2R`). Per research.md Decision 6: the T018b/c
  pattern does NOT apply — moiety instance counts are not reaction-invariant (empirically
  demonstrated: `cit[m]` implies inconsistent moiety counts across its two reactions). Requires
  understanding the correct moiety-level invariant before implementing (see research.md Decision 6
  for three candidate investigation directions). Do not attempt to force-fit the atom/bond pattern
  again without first resolving why it breaks here — that was tried and produced a mathematically
  wrong (if superficially plausible) result.
- [ ] T020b Re-run `testConservedReactingMoieties.m` end-to-end via actual MATLAB execution (not
  just `buildAtomAndBondTransitionMultigraph` in isolation) and confirm it passes completely,
  including the `identifyConservedReactingMoieties` call and everything downstream of it
  (`identifyConservedReactingSubgraphs`, `buildReactingMoietyTables`, `createMoietyGraph`,
  `getMetMoietySubgraphs`) — this is the true SC-008/FR-013 gate, not just the absence of a crash
  in the first `buildAtomAndBondTransitionMultigraph` call.

**Checkpoint**: `testConservedReactingMoieties.m` passes end-to-end on the fixed code — this is the
actual point at which Parts A/B/C become shippable, not the end of Phase 5.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Confinement check, full-category regression pass, and mandatory reporting

- [ ] T018 [P] Run quickstart.md Scenario G:
  `git diff --stat develop...017-fix-atom-bond-node-identity -- src/` and confirm the only file
  listed is `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m`
  (FR-009, SC-007)
- [ ] T019 Run the full `test/verifiedTests/analysis/` reactingMoieties/conservedMoieties test
  category via actual MATLAB execution and diff pass/fail results against the T002 pre-fix
  baseline; confirm no new failures are introduced (FR-012)
- [ ] T020 Report files edited, checks run, tests passed, tests failed, and any behaviors not yet
  verified, per constitution Principle III's post-implementation reporting requirement
- [ ] T021 Create the implementation receipt in
  `specs/017-fix-atom-bond-node-identity/agent-runs/<UTC-timestamp>-<short-task-or-run-name>/implementation-receipt.md`,
  with the actual final user-facing agent completion response copied verbatim into the
  `Final response` section (constitution Implementation Receipt Ledger)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories (T002's
  baseline is what T005/T011/T019 compare against; T003's fixture decision is what T012 depends on)
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - US2 (T013-T014) and US3 (T015-T017) both depend on US1's source edits (T006-T010) already
    being applied — their assertions verify properties of that same fix, not separate code changes
- **Polish (Phase 6)**: Depends on all three user stories AND Phase 5b (the
  `identifyConservedReactingMoieties.m` blocker) being complete — Phase 5b is not optional cleanup,
  it is the difference between a net regression and a shippable fix

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — no dependency on other stories,
  but internally requires T006-T010 (all three parts) applied together before T011 can pass, per
  the critical constraint stated at the top of this file
- **User Story 2 (P1)**: Depends on User Story 1's Part B (T008) being applied — verifies that fix
  is both correct and exhaustive; adds no further source edits
- **User Story 3 (P1)**: Depends on User Story 1's Part C (T009, T010) being applied — verifies
  that fix is mathematically sound and diagnostically complete; adds no further source edits

### Within Each User Story

- US1: tests first (T005, expected red) → implementation (T006-T010, all three parts together) →
  confirm green (T011) → additional within-reaction-instance coverage (T012)
- US2 and US3: verification-only tasks on top of US1's already-applied fix (no further source
  edits in either phase)

### Parallel Opportunities

- T002, T003, T004 (Foundational) can run in parallel — independent concerns, no shared file
- T006 and T007 (Part A, atom loop vs. bond loop) touch the same file in different regions but are
  logically independent edits; T008 depends on T006/T007's identity format already being decided
  (though not necessarily merged first, since it reuses the same format, not their literal output);
  T009/T010 (Part C) are independent of T008 (Part B) but all four (T006-T010) touch the same file,
  so treat as sequential in practice to avoid merge conflicts, per the "same file" caution in
  feature 016's task notes
- T013 and T014 (US2) can run in parallel with T015-T017 (US3) once T006-T011 are complete —
  different verification concerns, no shared file edits
- T018 (git diff check) can run in parallel with T019 (full test category run)

---

## Parallel Example: Foundational Phase

```bash
# Launch all three foundational tasks together (independent concerns, no shared file):
Task: "Capture pre-fix baseline by running testConservedReactingMoieties.m unmodified"
Task: "Scan atom-mapped RXN corpora for a within-reaction multi-instance metabolite case"
Task: "Confirm MATLAB coding-standards compliance for the planned error-handling approach"
```

## Parallel Example: User Story 2 and User Story 3 verification

```bash
# Once US1 (T006-T011) is complete, launch US2 and US3 verification together:
Task: "Re-confirm lines 611-618 is the only tuple-based lookup site; run full test category for crashes"
Task: "Add res=0, cross-reaction agreement, and genuine-inconsistency-error assertions"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — baseline, fixture decision, compliance check)
3. Complete Phase 3: User Story 1 (T005-T012) — this alone is the complete fix; Parts A+B+C are
   inseparable, so this phase already delivers the shippable result
4. **STOP and VALIDATE**: Confirm T011's green assertions and T012's within-reaction case
   independently
5. User Stories 2 and 3 add verification depth (lookup-site exhaustiveness, formula soundness), not
   additional source changes

### Incremental Delivery

1. Complete Setup + Foundational → baseline recorded, fixture path decided
2. Add User Story 1 (T005-T012) → the fix, complete and self-consistent (all three parts)
3. Add User Story 2 (T013-T014) → proves the lookup fix is exhaustive, not just locally correct
4. Add User Story 3 (T015-T017) → proves the check-formula fix is mathematically sound and
   diagnostically distinguishes real defects from the eliminated false positive
5. Polish (T018-T021) → confinement check, full regression pass, mandatory reporting and receipt

---

## Notes

- [P] tasks = different files or independent concerns, no dependencies
- [Story] label maps task to specific user story for traceability
- T006-T010 are the only source-code edits in this entire feature, all within
  `buildAtomAndBondTransitionMultigraph.m`, and MUST be applied together (not incrementally tested
  in isolation) per the critical constraint at the top of this file
- Every verification task (T002, T005, T011-T017, T019) MUST use actual MATLAB execution — this
  feature exists specifically because a prior round of static-reading-based assumptions (feature
  016) was disproven by execution, twice, during this feature's own planning (research.md
  Decision 2 documents one such self-correction)
- Avoid: editing `readABRXNFile.m`, `addBondMappingsRXNFile.m`, `identifyConservedReactingMoieties.m`,
  `checkABRXNFiles.m`, or any existing RXN file — all are out of scope per spec.md FR-009
