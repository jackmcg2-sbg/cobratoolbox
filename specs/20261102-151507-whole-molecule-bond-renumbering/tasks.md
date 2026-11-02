---

description: "Task list for whole-molecule bond renumbering"
---

# Tasks: Whole-molecule bond renumbering

**Input**: Design documents from `specs/20261102-151507-whole-molecule-bond-renumbering/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R7), contracts/bond-graph-equals-molfiles.md, quickstart.md

**Tests**: Required (Constitution III). The molfile-equality test is written first and must fail on the unchanged source (T004).

**Organization**:
- **US2** (tests and goldens) brackets the fix: red first, recapture after.
- **US1** is the fix.
- **US3** adds the paper's values.

## Format: `[ID] [P?] [Story] Description`

## Path conventions

- `FEATURE` = `specs/20261102-151507-whole-molecule-bond-renumbering`
- `SRC` = `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m`
- `TESTDIR` = `test/verifiedTests/analysis/testReactingMoieties`
- `BASE` = commit `5a4371497`
- `VMH` = reconXmoieties `results/experiments/2026-10-23-collapsed-vmh-037-corpora/` (model `vmhcollapsed037_20261023_103540/model_screened.mat`, RXN files `rxns/`)
- `WORK` = a work folder outside the repository

**Running MATLAB**: every MATLAB run goes in its own memory-capped user scope, one at a time, with a cap of at most the available memory minus 8 GB.

---

## Phase 1: Setup

- [ ] T001 Confirm `git merge-base --is-ancestor BASE HEAD` and `git diff --quiet BASE -- src TESTDIR`. Confirm that the `VMH` model and RXN folder exist, then copy the model to `WORK`. Stop and report if any check fails.

---

## Phase 2: Red (US2), on the unchanged source

**Do not edit `SRC` until T006 is done.**

- [ ] T002 [US2] Create `FEATURE/molfileEqualityCheck.m`, a function `report = molfileEqualityCheck(BG, rxnFileDir, rxns)`.
  - **Input**: for each metabolite with atoms in `BG`, read its first-seen molblock (instance 1 of the first file in `rxns` order, read with `readABRXNFile`).
  - **Check**: compare `BG`'s bonds of that metabolite (atom numbers and `Weight`) with the molblock's.
  - **Output**: corrupted metabolites, misplaced bonds, self-loops and overvalent atoms.

  Port the comparison from the exploration's `bg_vs_molfiles.py`.
- [ ] T003 [US2] Extend `TESTDIR/testBuildAtomAndBondTransitionMultigraph.m` (III-Naming) with a `%%` section per behaviour.
  - **Molfile equality**: for each of the six fixtures (main; coaM, coaX, coaR, crn, crnM submodels), build `BG` and assert molfile equality for every metabolite, with no self-loops. The comparison is inlined as a local function, because tests may not call `specs/` code.
  - **Planted control**: move one bond of a correct `BG` and show the comparison reports it.
  - **Non-isomorphic copy**: a two-reaction hand-built fixture in `TESTDIR/data/` whose second file gives a metabolite a different hydrogen count. Assert the FR-003 warning, and that the raw numbering is kept.
  - **Header**: Purpose, Authors, and tier unchanged.
- [ ] T004 [US2] Run T003 on the unchanged source. Expected: the molfile section fails and names the E33 corrupted cases, and the planted control is detected. Record the output. This is the red half of US2 AS1.
- [ ] T005 [US2] Capture the FR-006 baseline on the unchanged source. Save `arm.L`, `arm.M2M`, `arm.M2R`, `moietyFormulae`, `arm.ATG` and `arm.MTG` to `WORK` for:
  - every case of both golden references (re-running from their stored inputs);
  - the six fixtures built fresh;
  - random n = 500 (a copy of the memory scan's checkpoint, as in feature `20261102-092909`).
- [ ] T006 Commit T002–T005 (test sections that fail are kept out of the commit until T009, so that every commit stays green). The failing output is recorded in `FEATURE/wholeMoleculeRenumberingResults.md`.

---

## Phase 3: User Story 1 — the fix (Priority: P1)

- [ ] T007 [US1] In `SRC`, store each metabolite's reference molblock where `metBondCountGroundTruth` is filled: atom numbers, elements, head, tail and bond types. Remove the `identifyAtomEquivalenceClasses` call and the two caches it fills (plan, Design 1).
- [ ] T008 [US1] In `SRC`, add the per-(file, metabolite, instance) renumbering:
  - identity when the copy equals the reference;
  - otherwise `isomorphism(Gcopy, Gref, 'NodeVariables', 'Element')`;
  - the FR-003 warning when there is none;
  - cached per copy.

  Apply it to both ends of every bond before `canonicalBondKey`, and to the bond-transition atom identities. Remove `safeCanonicalizeBondAtoms` and `safeCanonicalizeOneAtom`. Update the NOTE block (VII-E), and add the "no longer called" line to `identifyAtomEquivalenceClasses`' help (plan, Design 2–5).
- [ ] T009 [US1] Run every test in `TESTDIR`.
  - **Expected**: molfile equality, the planted control and the non-isomorphic case pass, and the feature 019/020 assertions pass (FR-005).
  - **Expected to fail**: the golden comparisons, on bond-level fields only.
  - **Stop condition**: any failure in a conserved field or elsewhere stops the work.

  Commit the fix together with the T003 test sections.

---

## Phase 4: User Story 2 — recapture (Priority: P1)

- [ ] T010 [US2] Create `FEATURE/captureRenumberedGoldens.m`.
  - **Guard**: refuses to run unless `SRC` differs from `BASE` and all tests except the golden comparisons pass.
  - **Inputs**: for every case of `conservedReactingMoietiesReference.mat` and `reactingMoietyMemoryReference.mat`, rebuild `BG`, `dATM` with the fixed builder, the case's model and the fixture RXN folder.
  - **Outputs**: rerun `identifyConservedReactingMoieties` with the case's options, and write both files with the same fields plus a `provenance` struct.
  - **Report**: write a per-case, per-field "unchanged / changed (summary)" table to `FEATURE/wholeMoleculeRenumberingResults.md`, and assert that no conserved field changed (FR-006).
- [ ] T011 [US2] Run T010 and review the difference report. Expected changes: `BG`, `arm.MG` and `reacting` fields in the full-mode cases. Conserved-only cases change only in their stored `BG`. Compare the T005 baseline against the new run for the six fixtures and random n = 500 (FR-006, SC-003). Commit the references and the report.

---

## Phase 5: User Story 3 — the paper's values (Priority: P2)

- [ ] T012 [P] [US3] Add `TESTDIR/data/rxnFilesConsistentArms/` with copies of `ACONTm.rxn`, `r0317.rxn` and `r0426.rxn`. Only the atom-map numbers of the `HC00342[m]` and `h2o[m]` product blocks of `r0317` and `r0426` change, as in the exploration's `remap_consistent.py`. Add a README line stating the change and its source (Rahou et al. 2026, §3.1.1, Fig. 11).
- [ ] T013 [US3] Extend `TESTDIR/testConservedReactingMoieties.m`.
  - **Shipped files**: assert $L$ = [1 1 1 0; 0 1 1 1] over (h2o, cit, icit, cisa), 6 moiety instances, 6 moiety transitions, and formulae H2O and C6H3O6; the condensed reacting graph has 6 vertices and 7 bonds.
  - **Consistent-arm copy**: the condensed reacting graph has 4 vertices and 6 bonds; per reaction, 4 reacting bonds whose component-pair sets equal Fig. 11's 𝒴₁, 𝒴₂, 𝒴₃; the cover has 2 reactions.
  - **Header**: cites the paper sections and figures, and states that these values are taken from the paper, not from a first run.
- [ ] T014 [US3] Run every test in `TESTDIR`; all must pass. Commit.

---

## Phase 6: Verification and close-out

- [ ] T015 Create and run `FEATURE/wholeMoleculeRenumberingCheck.m` (non-CI).
  - **Full collapsed VMH**: build the multigraph from the `WORK` model copy and the `VMH` RXN files, run `molfileEqualityCheck`, and report the count (target 0, SC-002).
  - **Wall time**: the builder's time against `BASE` (`git archive`) on the same input (SC-006). Base and new runs are sequential and each capped; a run whose time differs by more than 1.5× from a repeat is repeated.
- [ ] T016 [P] Static review:
  - `git diff BASE -- src` touches only `SRC` and `identifyAtomEquivalenceClasses.m` (help only);
  - no `nargin`, `evalc` or warning suppression;
  - the warning text names the metabolite and the reaction.
- [ ] T017 Complete `FEATURE/wholeMoleculeRenumberingResults.md`: red output, test results, difference report, VMH count, wall time, and behaviours not verified (Rhea; non-isomorphic copies in real corpora).
- [ ] T018 Report the files changed, checks run, tests passed and failed, SC-001–SC-006 and what was not verified. Add the migration note: outputs built on `BG` since 2026-08-18 should be re-run.
- [ ] T019 Create `FEATURE/agent-runs/<UTC-timestamp>-whole-molecule-bond-renumbering/implementation-receipt.md` (Prompt, Final response verbatim, Diff summary, Tests, Unresolved issues, Other information).

---

## Dependencies & Execution Order

- **Phase 1**: T001.
- **Phase 2**: T002 → T003 → T004. T005 can run in parallel with T002–T004, but only one MATLAB job at a time. Then T006.
- **Phase 3**: T007 → T008 → T009.
- **Phase 4**: T010 → T011.
- **Phase 5**: T012 can be prepared at any time. T013 and T014 come after T011.
- **Phase 6**: T015, with T016 alongside, then T017 → T018 → T019.

## Implementation Strategy

- **Red before green**: the molfile-equality test must fail on the unchanged source (T004), so its later pass is evidence.
- **Recapture only after independent checks pass**: molfile equality (T009), with the difference report reviewed (T011). The paper's values (T013) then anchor the recaptured outputs from outside the code.
- **Rollback**: reverting the fix commit restores the old builder. The recaptured references would then fail, which is intended.
