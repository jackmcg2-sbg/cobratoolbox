# Feature Specification: Correctly root-cause and fix atom/bond node-identity defect in `buildAtomAndBondTransitionMultigraph`

**Feature Branch**: `017-fix-atom-bond-node-identity`

**Created**: 2026-08-11

**Status**: Blocked — implementation attempted 2026-08-11 (`/speckit-implement`) and fully reverted
(source tree confirmed clean, matches `develop`) after discovering that Parts A/B/C, while each
individually correct and empirically verified (`res=0` exactly), cannot ship without also
resolving a newly-discovered moiety-level check defect in `identifyConservedReactingMoieties.m`
(see FR-013/SC-008 and research.md Decision 6) — shipping Parts A/B/C alone would turn the
currently-passing `testConservedReactingMoieties.m` into a newly-failing test, confirmed by direct
execution (`git stash` + full test run on unmodified `develop` = pass). No code shipped this
session; all findings and verified (but unmerged) code are preserved in research.md for the next
implementation attempt.

**Supersedes**: `016-atom-bond-node-identity` (abandoned — its approved spec/plan/tasks prescribed
a fix built on an external, never-independently-reproduced bug report; empirical MATLAB testing in
this session disproved the prescribed fix and its "no other code needs to change" claim. See
"Evidence from feature 016" below. `016`'s source file was left unmodified/reverted; no code from
that feature shipped.)

**Input**: User description: re-investigate and correctly fix the atom/bond node-identity defect
in `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m`, using
in-repository evidence and actual MATLAB execution rather than an unverified external report. This
revision incorporates "Spec v2," a follow-up design that resolves the open fork this spec
originally left for the planning phase (see below); v2's confirmed facts and decisions were
independently checked line-by-line against the current source and against this session's own
empirical MATLAB findings before being adopted (all checks passed — see "Verification of v2"
below).

## Evidence from feature 016 (binding context for this feature)

Empirical testing (MATLAB R2024b, this repository, via `initCobraToolbox(false, 'agent')` +
direct calls to `buildAtomAndBondTransitionMultigraph` with `options.sanityChecks = 1`, using the
toolbox's existing fixture `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m`
sampling `r0317`/`ACONTm`/`r0426`, where `r0317` and `r0426` both produce `h2o[m]`) found:

1. **Pre-fix (current `develop` code, unmodified)**: no warning fires; `h2o[m]` has exactly 3 atom
   nodes in `dATM` total (shared/merged across both reactions, not 6 unmerged); `diag(M2Ai*M2Ai')`
   for `h2o[m]` = 3. This fixture exercises the underlying same-species-different-reactions merge
   mechanism but does not reproduce the originally-reported symptom (no warning, no inflated
   diagonal) — the original report's specific 8-reaction sample (`R_17357_e`, `R_84979_e`,
   `R_50844_n`, `R_70951_e`, `R_11920_n`, `R_38891_e`, `R_31183_i`, `R_37203_i`) is not present
   anywhere in this repository, so the original symptom (warnings, diagonal values of 16/32 for
   water) has never been independently verified in-repo.
2. **Applying feature 016's prescribed fix exactly as specified** (prepend `model.rxns{i}` and the
   per-reaction `instances` value to both atom-loop and bond-loop node identity strings) and
   re-running the same fixture produced two new, previously-absent failures:
   - The atom-transition sanity check newly fires `Inconsistent directed atom transition
     multigraph` for `h2o[m]` — a regression against a previously-passing case. Root cause: the
     existing consistency-check formula `res = (M2Ai*M2Ai')*N - M2Ai*Ti*Ti2R` (`buildAtomAndBondTransitionMultigraph.m`
     line 498) multiplies `diag(M2Ai*M2Ai')` — a single scalar per metabolite — against `N` (that
     metabolite's stoichiometric coefficient in *each* reaction column), while separately summing
     only that reaction's own atom-transition edges via `Ti*Ti2R`. This is only self-consistent if
     `diag(M2Ai*M2Ai')` equals the metabolite's single-instance atom count, reused identically
     across every reaction it appears in — i.e. the formula *requires* cross-reaction node sharing
     by species. Reaction-scoping the atom nodes breaks this multiplication for every reaction
     after the first, by construction. Empirically confirmed: the diagnostic printout showed
     `res = 3` for `h2o[m]` in both `r0317` and `r0426` after reaction-scoping — exactly the value
     predicted by `d(unmerged)=6` × `N=1` − `Ti*Ti2R(this reaction only)=3` = 3.
   - The bond-transition loop crashes (`Unable to perform assignment because the left and right
     sides have a different number of elements`) at `buildAtomAndBondTransitionMultigraph.m`
     lines 611-618 (`EdgeTable.HeadBondHeadAtom(k) = dATME.Nodes.Atom(...)` and seven analogous
     assignments: `HeadBondTailAtom`, `TailBondHeadAtom`, `TailBondTailAtom`, and their four
     `...Index` counterparts). This lookup matches a bond's head/tail atom by
     `(mets, AtomNumber, Element)` alone against `dATME.Nodes` — it does not use the node-identity
     string at all, and is not reaction-scoped. It implicitly relied on the pre-fix merge behaviour
     to guarantee exactly one match; reaction-scoping atoms makes the same triple match multiple
     rows, and the scalar assignment fails. This disproves feature 016's claim that "all other
     locations... operate generically on the node-name string... require no changes." A full-file
     grep for every other tuple-based (non-ID-string) node lookup found no other such site — the
     only other `mets`-based matches (lines 418, 728, 734) are deliberate many-to-one
     metabolite→atom-node lookups (building `M2Ai`/`M2BiE`), not "expect exactly one match" bugs.
3. **Why local atom numbering happens to coincide for water across these two files**: `atomNumbers`
   (`atoms.metNrs` in `readABRXNFile.m`) is simply the sequential line position of each atom within
   its metabolite's MOL block (`aMetNrs = k - 4`), not a random or reaction-specific index. Both
   fixture RXN files were generated by the same tooling with deterministic, canonical per-species
   atom ordering (confirmed: identical H/O/H line order in both files' `h2o[m]` MOL blocks). Merge
   by `(metaboliteID, localAtomNumber, element)` is, for this common case, consistent with — and
   arguably required by — the check formula's structure, not a coincidental defect.
4. **A narrower alternative tested**: appending only the per-reaction `instances` value (no
   reaction-ID prefix) reproduced the pre-fix baseline exactly (no warning, diagonal = 3, no
   crash) — empirically neutral on this fixture. This fixture has no metabolite occurring more
   than once *within* a single reaction, so this narrower change's actual disambiguating effect is
   untested; its correctness for whatever originally produced diagonal values of 16/32 is unknown.

## Design decision (resolves the fork the initial revision of this spec left open)

The initial revision of this spec deliberately left open, as a to-be-decided question (former
FR-003), whether a correct fix should (a) keep merge-by-species and drop reaction-scoping
(compatible with the existing check formula as-is), or (b) keep reaction-scoping and revise the
check formula to match. **This is now decided: option (b).** Reaction- and instance-scoped node
identity (feature 016's Part-A string format, confirmed correct) is retained, and the consistency-
check formulas are revised so their per-metabolite/per-bond count is sourced from a single
reaction's occurrence rather than summed across the whole network. This decision is adopted from
"Spec v2" (a follow-up design authored after reviewing this session's empirical findings) and was
independently verified before adoption:

- Every line number v2 cites (498, 611-614/615-618, 799, 820) was checked with `grep -n` against
  the current, unmodified source and matches exactly.
- v2's claim that lines 611-618 are the *only* other non-ID-based, tuple-matching node lookup in
  the file was independently re-verified by a fresh full-file grep (see point 2 above) — confirmed.
- v2's algebraic derivation of why the check formula breaks under reaction-scoping was
  cross-checked against this session's actual empirical measurement (`res = 3` for `h2o[m]`) and
  matches exactly.
- v2's proposed same-species cross-reaction consistency assertion (compute the single-instance
  count from two different reaction occurrences and require they agree, raising a distinct,
  specific error on mismatch) directly answers the "metabolite whose local atom numbering
  genuinely differs between two RXN files" edge case this spec's initial revision flagged as an
  open, unresolved question.

The exact MATLAB-level implementation (literal replacement code, the specific mechanism for
restricting `M2Ai`'s columns to one reaction, and the recommended A+B-then-C implementation/test
ordering) is captured in v2's original text and will be carried forward as Phase 0/1 design detail
in `plan.md`/`research.md` when `/speckit-plan` is next run for this feature — consistent with this
repository's convention that `spec.md` states WHAT/WHY (testable requirements) and `plan.md`
states HOW (code-level design). Nothing from v2 is discarded; it is relocated to the artifact layer
where implementation detail belongs.

## Clarifications

None required from the user — the fork this spec previously deferred to `/speckit-clarify` (check-
formula compatibility vs. revision) is now resolved by the "Design decision" above, with its own
evidence trail. No other unresolved business/scope ambiguity remains.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Node identity is disambiguated per reaction and instance, without regressing the sanity check (Priority: P1)

A maintainer running `buildAtomAndBondTransitionMultigraph` with `options.sanityChecks = 1` on a
multi-reaction network needs atom and bond nodes to be genuinely distinct per reaction and
per-reaction instance (no accidental cross-reaction merging), while the sanity check itself
continues to pass on networks that are actually consistent — including the `r0317`/`ACONTm`/`r0426`
fixture, which passes today and must keep passing.

**Why this priority**: This is the core defect (accidental node merging) and the exact way feature
016's fix regressed a previously-passing case. Both properties — correct disambiguation and no
regression — must hold together, or the fix is not done.

**Independent Test**: Run `testConservedReactingMoieties.m`'s existing fixture before and after the
fix via actual MATLAB execution; confirm the sanity check still passes, and directly inspect
`dATM.Nodes` to confirm `h2o[m]` now has 6 distinct atom nodes (3 per reaction × 2 reactions),
not 3 merged ones.

**Acceptance Scenarios**:

1. **Given** the fixed function, **When** run on the `r0317`/`ACONTm`/`r0426` fixture with
   `options.sanityChecks = 1`, **Then** no `Inconsistent directed atom transition multigraph` or
   `Inconsistent directed bond transition multigraph` warning fires.
2. **Given** the fixed function's output, **When** `dATM.Nodes` is inspected for `h2o[m]`, **Then**
   it contains 6 distinct atom nodes (one full set of 3 per reaction), confirming nodes are
   genuinely reaction/instance-scoped rather than merged.
3. **Given** a metabolite occurring more than once within a single reaction (e.g. `2 H2O`), **When**
   the fixed function processes that reaction, **Then** the `instances` field correctly
   disambiguates those occurrences in node identity — verified against a fixture that actually
   exercises this case (constructed if none exists in the current RXN corpus).

---

### User Story 2 - Every non-ID-based node-lookup site is updated in lockstep with the new identity format (Priority: P1)

A maintainer applying the node-identity fix needs every place in
`buildAtomAndBondTransitionMultigraph.m` that independently re-derives node identity — instead of
using the canonical identity string — to be found and kept consistent, so the fix does not crash
elsewhere the way it crashed in the bond-transition loop under feature 016.

**Why this priority**: This is the second concrete way feature 016's fix broke (a hard crash, not
just a warning regression), confirmed to exist at lines 611-618 and confirmed (by full-file grep)
to be the only such site.

**Independent Test**: Re-run the full-file search for tuple-based (non-ID-string) node lookups as
part of the fix's own verification, confirm the lines 611-618 lookup now keys off the same
reaction/instance-scoped identity as the node-construction loop (Part A), and confirm no other such
site was missed.

**Acceptance Scenarios**:

1. **Given** the fixed function, **When** the bond-transition loop populates
   `HeadBondHeadAtom`/`HeadBondTailAtom`/`TailBondHeadAtom`/`TailBondTailAtom` and their `...Index`
   counterparts, **Then** the lookup resolves to exactly one matching node per reaction/instance,
   with an explicit, diagnosable error (not a silent crash or silent wrong-row match) if it ever
   does not.
2. **Given** the fixed function, **When** the full existing `reactingMoieties`/`conservedMoieties`
   test category is run via actual MATLAB execution, **Then** no crash occurs anywhere in the
   function.

---

### User Story 3 - The consistency-check formulas correctly express the single-instance invariant (Priority: P1)

A maintainer inspecting the atom- and bond-level consistency checks needs `res =
(M2Ai*M2Ai')*N - M2Ai*Ti*Ti2R` (and its bond-side analogue) to correctly express that each
metabolite/bond's per-instance count is fixed by chemistry (independent of how many reactions or
instances it appears in across the processed network) — not accidentally computed as a network-wide
sum, which is what made the check reject a genuinely-fixed atom-identity representation once nodes
were correctly disambiguated.

**Why this priority**: This is the root cause of the regression in User Story 1 — the formula, not
the node-identity change itself, was what broke. Fixing node identity without this would either
force keeping the incorrect merge behaviour (User Story 1 fails) or produce constant false-positive
warnings (this story fails).

**Independent Test**: For a metabolite appearing in two or more reactions, compute the corrected
per-instance count from two different reaction occurrences independently and confirm they agree;
confirm the check's `res` is zero for a genuinely consistent network, and confirm it correctly
flags (with a distinct, specific error) a genuinely inconsistent one (e.g. a metabolite whose local
atom numbering actually differs between two files).

**Acceptance Scenarios**:

1. **Given** the corrected check formula, **When** run on the `r0317`/`ACONTm`/`r0426` fixture,
   **Then** `res` is zero (or within a justified floating-point tolerance) for every metabolite,
   using a per-instance count sourced from a single reaction's occurrence rather than a network-wide
   sum.
2. **Given** a metabolite appearing in two reactions, **When** its per-instance count is computed
   independently from each reaction's occurrence, **Then** the two computed counts agree, and this
   agreement is asserted under `options.sanityChecks` (not merely assumed).
3. **Given** a constructed case where a metabolite's local atom numbering genuinely differs between
   two RXN files that both use it, **When** the corrected check runs, **Then** it raises a distinct,
   specific error identifying the mismatch — separately diagnosable from a generic "inconsistent
   multigraph" warning.

### Edge Cases

- A metabolite occurring more than once within a single reaction (e.g. `2 H2O`): covered by User
  Story 1, Acceptance Scenario 3 — untested by the currently-available fixture, so a fixture
  exercising it must be located or constructed.
- A metabolite whose local atom numbering genuinely differs between two RXN files that both
  atom-map it: covered by User Story 3, Acceptance Scenario 3 — the corrected check formula must
  surface this as a distinct, specific, diagnosable error, not silently tolerate or conflate it
  with the ordinary false-positive this feature eliminates.
- A single-reaction network/model: behaviour must remain unchanged from current `develop` (already
  passing; not affected by any of the changes here, since there is no cross-reaction sharing to
  disambiguate).
- Any additional non-ID-based lookup sites beyond lines 611-618: none were found by full-file grep,
  but the fix's own verification (User Story 2) MUST re-confirm this rather than trust this spec's
  finding blindly, since the codebase may change before implementation.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Atom-transition node identity strings (`substrateID`/`productID`) MUST be unique per
  (reaction, metabolite instance, local atom number, element) tuple, retaining feature 016's
  confirmed-correct format: reaction identifier and per-reaction `instances` value prepended to the
  existing metabolite/local-number/element identity.
- **FR-002**: Bond-transition node identity strings (`bondSubstrateID`/`bondProductID`) MUST be
  unique per (reaction, metabolite instance, atom number, element) tuple at both head- and
  tail-atom positions, using the same reaction+instance-scoped format as FR-001.
- **FR-003**: The bond-transition loop's atom lookups at lines 611-618
  (`HeadBondHeadAtom`/`HeadBondTailAtom`/`TailBondHeadAtom`/`TailBondTailAtom` and their `...Index`
  counterparts) MUST resolve each lookup against the same reaction/instance-scoped identity
  established by FR-001/FR-002, rather than the current loose `(mets, AtomNumber, Element)` triple
  match, and MUST raise an explicit, diagnosable error (not a silent crash or silent wrong-row
  match) if a lookup does not resolve to exactly one node.
- **FR-004**: The atom-level consistency-check formula (`res = (M2Ai*M2Ai')*N - M2Ai*Ti*Ti2R`, line
  498) MUST be revised so that its per-metabolite count (`d`) is sourced from a single reaction's
  occurrence of that metabolite (normalized by that reaction's stoichiometric coefficient), not
  from the row-sum of `M2Ai` across the whole processed network.
- **FR-005**: The bond-level consistency-check formula (line 799) MUST receive the analogous
  correction to FR-004, using bond-count-per-single-instance in place of the current network-wide
  sum.
- **FR-006**: Under `options.sanityChecks`, the corrected per-instance count for a metabolite (or
  bond) appearing in two or more reactions MUST be independently recomputed from at least two
  different reaction occurrences and asserted equal; a genuine mismatch MUST raise a distinct,
  specific error (not the generic `Inconsistent directed atom/bond transition multigraph` warning),
  so a true data inconsistency is diagnosable separately from the false positive this feature
  eliminates.
- **FR-007**: The fix MUST correctly disambiguate a metabolite occurring more than once within a
  single reaction (the `instances` field's stated purpose), verified against a fixture that
  actually exercises this case (located in the existing RXN corpus or newly constructed, since the
  currently-available fixture does not exercise it).
- **FR-008**: The full text of `buildAtomAndBondTransitionMultigraph.m` MUST be (re-)searched for
  every site that looks up or matches graph nodes by raw tuple rather than via the canonical
  node-identity string, to confirm FR-003 addresses every such site as of implementation time (this
  spec's own full-file grep found only lines 611-618, but that finding MUST be independently
  re-confirmed at implementation time, not assumed still true).
- **FR-009**: **[REVISED — see Status]** The fix's scope is confined to
  `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m` AND
  `src/analysis/topology/reactingMoieties/identifyConservedReactingMoieties.m`.
  `readABRXNFile.m` and `addBondMappingsRXNFile.m` remain unmodified. The original "Design
  decision" claim that this feature resolves entirely within one file is **disproven**:
  `identifyConservedReactingMoieties.m` independently recomputes the same defective
  consistency-check formula in three places (confirmed by full-file grep and execution — see
  research.md addendum), two of which (directed and undirected atom-level checks) require the
  identical fix pattern as FR-004, and one of which (moiety-level, line ~1273) requires additional,
  not-yet-completed theory work — see FR-013.
- **FR-010**: System MUST preserve documented public interfaces, diagnostic semantics (the
  `sanityChecks` warning still fires on genuine inconsistencies, per FR-006), and file-location
  conventions.
- **FR-011**: All verification MUST use actual MATLAB execution (MATLAB R2024b, available at
  `/usr/local/MATLAB/R2024b/bin/matlab`, not on `PATH`; fast headless init via
  `initCobraToolbox(false, 'agent')`) — static code reading alone is insufficient, since feature
  016's static-reading-based root-cause narrative was disproven by execution, and since this
  feature's own Part C design was itself revised mid-implementation after execution revealed the
  originally-planned bond-side approach was mathematically wrong (research.md Decision 3).
- **FR-012**: After the fix, the full existing `reactingMoieties`/`conservedMoieties` test category
  MUST be re-run via actual MATLAB execution and MUST show no new failures relative to the
  `develop` baseline. **This is a hard gate on shippability, not just a check**: Parts A/B/C
  (buildAtomAndBondTransitionMultigraph.m) and the two atom-level duplicate-check fixes in
  identifyConservedReactingMoieties.m are individually verified correct, but MUST NOT be merged
  until FR-013 is also resolved, because doing so alone regresses
  `testConservedReactingMoieties.m` from passing to failing (confirmed by execution: unmodified
  `develop` passes this test end-to-end today).
- **FR-013 (NEW)**: The moiety-level consistency check in `identifyConservedReactingMoieties.m`
  (line ~1273, `res = M2M*M2M'*N - M2M*M*M2R`) MUST be resolved before this feature ships. The
  atom/bond-level fix pattern (FR-004/FR-005: read `d` from one reaction's occurrence, cross-
  validate against others) does NOT apply here — empirical evidence shows moiety instance counts
  are not reaction-invariant the way atom/bond counts are (a metabolite's moiety decomposition can
  legitimately differ depending on which bonds break/form in a specific reaction). Resolving this
  requires investigating what the correct moiety-level invariant actually is (see research.md
  Decision 6 for candidate directions), not a mechanical port of FR-004's pattern.

### Key Entities

- **Atom transition node**: A vertex in `dATM`, keyed by the reaction+instance-scoped identity
  string (FR-001), one per true atom occurrence — no longer merged across reactions.
- **Bond transition node reference**: The head/tail atom identity embedded in a bond transition
  edge in `dBTM`/`BG`, keyed the same way (FR-002), resolved via the corrected lookup (FR-003).
- **Node-identity consistency-check formula**: `res = (M2Ai*M2Ai')*N - M2Ai*Ti*Ti2R` (atom side,
  FR-004) and its bond-side analogue (FR-005) — revised to use a single-instance count rather than
  a network-wide sum, with a cross-reaction consistency assertion (FR-006).
- **Metabolite instance number**: The existing per-reaction `instances`/`bondMappings.instances`
  field (already correctly computed by `readABRXNFile.m`/`addBondMappingsRXNFile.m`, unmodified
  per FR-009), reused unchanged in node identity (FR-001/FR-002).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `testConservedReactingMoieties.m` (existing fixture) passes via actual MATLAB
  execution, both before and after the fix, with `h2o[m]` shown to have 6 distinct atom nodes
  post-fix (not 3 merged), and no new warning.
- **SC-002**: A fixture (located or newly constructed) demonstrably exercises a metabolite
  occurring more than once within a single reaction, and the fix correctly disambiguates it,
  confirmed by actual MATLAB execution.
- **SC-003**: The corrected consistency-check formulas produce `res = 0` (within a justified
  tolerance) for every metabolite/bond on the `r0317`/`ACONTm`/`r0426` fixture, with the
  per-instance count verified equal when independently computed from two different reaction
  occurrences (FR-006), confirmed by actual MATLAB execution.
- **SC-004**: A constructed case with genuinely inconsistent local atom numbering across two RXN
  files produces the distinct, specific error required by FR-006 — not the generic false-positive
  warning this feature eliminates, and not silent tolerance.
- **SC-005**: The bond-transition loop's lookup at lines 611-618 resolves correctly (exactly one
  match) on both the `r0317`/`ACONTm`/`r0426` fixture and the SC-002 fixture, with no crash,
  confirmed by actual MATLAB execution.
- **SC-006**: The full `reactingMoieties`/`conservedMoieties` test category passes via actual
  MATLAB execution, both before and after the fix, with no new failures. **Not yet met**: verified
  that the atom/bond-level fix alone regresses this (moiety-level check newly fails); blocked on
  SC-008.
- **SC-007**: The fix's diff is confined to
  `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m` and
  `src/analysis/topology/reactingMoieties/identifyConservedReactingMoieties.m` (revised per FR-009).
- **SC-008 (NEW)**: The moiety-level check (FR-013) is resolved such that
  `testConservedReactingMoieties.m` passes end-to-end, including the downstream
  `identifyConservedReactingMoieties` call, with the corrected (disambiguated) `dATM`/`M2Ai` from
  Parts A/B/C — not just the two directly-analogous atom-level duplicate checks.

## Assumptions

- MATLAB R2024b, installed at `/usr/local/MATLAB/R2024b/bin/matlab` (not on `PATH`), is available
  in the environment where this feature is planned and implemented, and `initCobraToolbox(false,
  'agent')` provides a fast (~2s), non-interactive, headless initialization sufficient for running
  the toolbox's existing tests and diagnostic scripts.
- The original external bug report's specific 8-reaction sample remains unobtainable for this
  feature; if it becomes available, it would be additional confirming evidence but is not required
  — the "Design decision" above is independently justified by this repository's own evidence
  (empirical `res=3` measurement, algebraic derivation, and the confirmed single-other-lookup-site
  finding).
- `readABRXNFile.m` and `addBondMappingsRXNFile.m` remain out of scope. `identifyConservedReactingMoieties.m`
  is **confirmed in scope** (FR-009, revised) — the assumption that this feature resolves entirely
  within `buildAtomAndBondTransitionMultigraph.m` was disproven by execution during implementation.
- The mechanism for sourcing the corrected `d` (FR-004/FR-005) is settled and verified, superseding
  the original plan of "restricting `M2Ai`'s columns to a single reaction" — the implemented and
  verified approach reads `d(i)` directly from the existing RHS matrix's own per-reaction value
  (`RHS(i,j0)/N(i,j0)`), which is simpler and was proven necessary because the column-restriction
  approach, while correct for atoms, does not generalize to bonds (research.md Decision 3).
- The moiety-level invariant (FR-013) is NOT assumed to follow the same pattern as the atom/bond
  fix — this assumption was explicitly tested and disproven (research.md Decision 6). No assumption
  is made yet about what the correct invariant is; that is open investigation for the next session.

## Traceability

| Acceptance criterion | Discharging test | src/<domain>/ function under test |
|----------------------|------------------|-----------------------------------|
| US1 / FR-001, FR-002, FR-007 | testConservedReactingMoieties (extended: node-count + within-reaction-instance assertions) under test/verifiedTests/analysis/testReactingMoieties/ | src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m |
| US2 / FR-003, FR-008 | testConservedReactingMoieties (extended, full-category run, no-crash assertion) under test/verifiedTests/analysis/testReactingMoieties/ | src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m |
| US3 / FR-004, FR-005, FR-006 | testConservedReactingMoieties (extended: res=0 + cross-reaction agreement + distinct-error assertions) under test/verifiedTests/analysis/testReactingMoieties/ | src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m |
| SC-002 / FR-007 | New/extended fixture test for within-reaction multi-instance metabolites under test/verifiedTests/analysis/testReactingMoieties/ | src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m |
| SC-008 / FR-013 | testConservedReactingMoieties (full end-to-end pass, including identifyConservedReactingMoieties) under test/verifiedTests/analysis/testReactingMoieties/ | src/analysis/topology/reactingMoieties/identifyConservedReactingMoieties.m |
| SC-004 / FR-006 | New constructed-inconsistency fixture test under test/verifiedTests/analysis/testReactingMoieties/ | src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m |
