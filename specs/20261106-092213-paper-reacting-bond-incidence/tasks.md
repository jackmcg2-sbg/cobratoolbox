---

description: "Task list for the paper's reacting-bond incidence"
---

# Tasks: Reacting-bond incidence from bond changes, as in the paper

**Input**: Design documents from `specs/20261106-092213-paper-reacting-bond-incidence/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R9), contracts/bond-change-incidence.md, quickstart.md

**Tests**: Required (Constitution III). The behaviour assertions are written first and run on the unchanged source, so the expected failures are recorded before the change (red before green). Assertions on the new option, the new input and the new fields can't run before they exist, so they land with the source change (as in features `20261102-092909` and `20261103-115636`).

**Organization**:
- **US1** (each bond belongs only to the reactions that change it) is the change.
- **US2** (the paper's example still reproduces) guards it.
- **US3** (the full network) reviews it at scale.

## Format: `[ID] [P?] [Story] Description`

## Path conventions

- `FEATURE` = `specs/20261106-092213-paper-reacting-bond-incidence`
- `RM` = `src/analysis/topology/reactingMoieties`
- `TESTDIR` = `test/verifiedTests/analysis/testReactingMoieties`
- `TEST` = `TESTDIR/testConservedReactingMoieties.m`
- `TUT` = `test/tutorialDerived/analysis/reactingMoieties/tutorial_conservedAndReactingMoieties.m`
- `BASE` = commit `ad0d11d60`
- `RX` = reconXmoieties `/home/jackmcgoldrick/repos/reconXmoieties`
- `BASELINE` = `RX/results/experiments/2026-11-04-collapsed-vmh-reacting-moieties/vmhcollapsed_20261105_142523` (COBRA `BASE`; `checkpoint_build.mat` holds `runModel`, `dATM` and `BG`; `moieties_Qconserved_graphsOn_reacting/` holds `reacting.mat` and `conserved_moieties.mat`)
- `VMHRXN` = `RX/results/experiments/2026-10-23-collapsed-vmh-037-corpora/rxns` (`BASELINE`'s `provenance.json` `rxnDir`)
- `WORK` = a work folder outside both repositories

**Running MATLAB**:
- Initialise COBRA from `~/cobratoolbox`, then put this worktree's `RM` first on the path.
- Assert that `which identifyConservedReactingMoieties` resolves in this worktree.
- Every MATLAB run goes in its own memory-capped user scope, one at a time.
- Nothing is written to `BASELINE`'s or `VMHRXN`'s folders; they are only read or copied from.

---

## Phase 1: Setup

- [X] T001 Confirm `git merge-base --is-ancestor BASE HEAD` and `git diff --quiet BASE -- RM TESTDIR`, and archive `BASE`'s `RM` to `WORK/base`. Stop and report if a check fails.
- [ ] T002 Start the full-network rebuild early, because it takes about 1 h 41 min (research R8). Create `FEATURE/rebuildWithBondTransitions.m`, a function `rebuildWithBondTransitions(checkpointFile, rxnDir, outFile)`:
  - **Model**: it loads `runModel` from `checkpointFile`.
  - **Build**: it runs the builder with the pipeline's options (`directed = 0`, `sanityChecks = 0`).
  - **Equality check**: it asserts that the rebuilt `dATM` and `BG` are `isequaln` to the checkpoint's, and stops if not.
  - **Save**: `runModel`, `dATM`, `BG` and `dBTM`, with `-v7.3`, and the build time and peak RSS.

  Run it on a copy of `BASELINE/checkpoint_build.mat` with `VMHRXN` (24 GiB cap) into `WORK/vmh_with_dBTM.mat`.
- [X] T003 [P] Create `TESTDIR/data/rxnFilesTransport/` (research R6):
  - **Copies**: the three files of `TESTDIR/data/rxnFilesConsistentArms/`.
  - **`CITICITtm.rxn`**: hand-written. Its reactants are `cit[c]` and `icit[m]`, its products `cit[m]` and `icit[c]`. The molblocks are copied from the consistent-arm `cit[m]` and `icit[m]` blocks, with the identifiers changed for the `[c]` copies. The atom map is the identity (atom k of each reactant maps to atom k of the same metabolite among the products).
  - **Check**: run `checkABRXNFiles` on the folder and confirm it parses, and that the builder reports 0 broken and 0 formed bonds for `CITICITtm`.

---

## Phase 2: Tests first, on the unchanged source (US1, US2)

- [X] T004 [US1] Add a local helper to `TEST`, `expectedCondensedSets(model, dBTM, BG, arm, reacting)`. It returns each reaction's set of condensed reacting bonds, computed independently of `CRB2R`:
  - take the broken and formed interactions from `dBTM` (research R1);
  - map each bond, through `BG` end atoms and `arm.ATG.Nodes.Component`, to a component pair;
  - map the component pairs to `Condensed_RBG` edges by the pairs of all reacting bonds merged into each edge, which is the union rule (R3).

  It also returns the count of interactions that fall on no edge.
- [X] T005 [US1] Add a `%%` section to `TEST` for the shipped files: for each reaction, assert that its `CRB2R` column equals `expectedCondensedSets`. Add a planted control: flipping one entry of a copy of `CRB2R` must be detected.
- [X] T006 [US1] Add a `%%` section to `TEST` for the transport (US1 AS1):
  - **Model**: `addReaction` adds `CITICITtm` to the example model (`cit[c] + icit[m] -> cit[m] + icit[c]`).
  - **Build**: from `TESTDIR/data/rxnFilesTransport`.
  - **Asserts, in order**:
    1. the condensed graph is 4 vertices and 6 bonds;
    2. the conserved $L$ over the original four metabolites is unchanged;
    3. the `CITICITtm` column of `CRB2R` is zero, and `CITICITtm` is not among `selectedReactionNames`;
    4. the other three columns equal the Fig. 11 sets, using the existing letter mapping.
- [X] T007 [US1] Add a `%%` section to `TEST` for the order change (US1 AS3). On the consistent-arm fixture, the condensed edge that holds cis-aconitate's C=C bond lists exactly the reactions `dBTM` records as changing an interaction of that bond. Assert both that edge's row and that the bond's `dBTM` changes are interactions of a multiple bond.
- [X] T008 [US1] Run `TEST` on the unchanged source and record the result per section in `FEATURE/paperIncidenceResults.md` under "Red before green". Expected:
  - **fail**: T005 (`ACONTm`, `r0317`, `r0426`) and T006 assert 3;
  - **pass**: Fig. 11, the conserved outputs and T006 asserts 1–2;
  - **T007**: either outcome, but recorded.

  Stop and report if the failures differ from these. Commit `TEST`, `TESTDIR/data/rxnFilesTransport/`, T002's script and the results file (no source change).

---

## Phase 3: Commit 1, the source change (US1)

- [X] T009 [US1] In `RM/identifyConservedReactingMoieties.m`, read and validate `options.reactingBondIncidence` (default `'bondChange'`), next to the `conservedMoietiesOnly` / `computeMoietyGraphs` checks:
  - **Invalid value**: error `identifyConservedReactingMoieties:invalidReactingBondIncidence`.
  - **Optional input**: accept the trailing `dBTM`, detected with `exist`/`isempty`, not `nargin` (VII-D).
  - **Missing input**: in full mode with `'bondChange'` and no `dBTM`, error `identifyConservedReactingMoieties:missingBondTransitions`, with the message in the contract.
- [X] T010 [US1] In STEP 1, keep the third output of `unique(E_sorted, 'rows', 'stable')` as `rbgEdgeToCondensed` (plan, Design 2). Nothing else in STEP 1 changes.
- [X] T011 [US1] In STEP 3, add the `'bondChange'` branch (plan, Design 3):
  - broken interactions (`TailMet` in `model.rxns`, bond `HeadBondIndex`) and formed ones (`HeadMet` in `model.rxns`, bond `TailBondIndex`);
  - reaction columns from `Edges.rxns`;
  - rows through the `RBG` edges' `BondIndex` and `rbgEdgeToCondensed`, asserting that each bond maps to at most one row;
  - `CRB2R = spones(sparse(...))`.

  Leave both existing `'endAtom'` code paths untouched.
- [X] T012 [US1] Add `reacting.unchangedReactingBonds` (`~any(CRB2R, 2)`, both rules) and `reacting.offGraphBondChanges` (`0` under `'endAtom'`). When the count is not zero, emit one warning, `identifyConservedReactingMoieties:offGraphBondChanges`, with the count (VII-B). Leave the cover's `activeBonds` as it is (FR-005).
- [X] T013 [US1] Help text and provenance (FR-010, VII-E):
  - **Header**: the `dBTM` input, `options.reactingBondIncidence` with both values, the two new fields and the paper reference (§6.1, eq. 32).
  - **Pipeline comment**: R5 rewritten for both rules.
  - **Provenance**: an author/provenance line for this feature.

---

## Phase 4: Commit 2, callers and the new interface's tests (US1, US2)

- [X] T014 [US2] Pass `dBTM` at every full-mode call in `TEST`: L239, L273, L535 and the transport section. The consistent-arm and MACACI builds must now return `dBTM` (eighth output). Leave the conserved-only calls (L101, L142, L165) without it.
- [X] T015 [P] [US2] Pass `dBTM` at the full-mode call in `TUT` (L155), with the builder call returning it.
- [X] T016 [US1] Add a `%%` section to `TEST` for the interface (FR-002, FR-006):
  - a conserved-only call without `dBTM` runs;
  - a full-mode call without `dBTM` raises `missingBondTransitions`;
  - an invalid value raises `invalidReactingBondIncidence`;
  - on the shipped files, `'endAtom'` gives today's `CRB2R` (equal to `BASE`'s, captured in T008's run and stored inline as the expected component-pair sets).
- [X] T017 [US1] Add a `%%` section to `TEST` for FR-005:
  - on the fixtures, `unchangedReactingBonds` is all false and `offGraphBondChanges` is 0;
  - **planted case**: on a copy of the consistent-arm `dBTM` with `ACONTm`'s energy edges removed, the bonds only `ACONTm` changes become `unchangedReactingBonds`, and the cover still succeeds;
  - **planted control**: an extra energy edge in a copied `dBTM` is detected by T005's assertion.
- [X] T018 [US1] Update `TEST`'s header (Purpose, behaviours, tier, Authors). Run `TEST`. All sections pass except the two golden comparisons, which are recaptured in Phase 5; record which fail. Commit commit 1 (T009–T013) and commit 2 (T014–T018) separately.

---

## Phase 5: Commit 3, golden references (US1, US2)

- [X] T019 [US1] Create `FEATURE/capturePaperIncidenceGoldens.m` (plan, Design 6; research R7). It:
  1. asserts `git diff --quiet HEAD -- RM`;
  2. copies today's `conservedReactingMoietiesReference.mat` and `reactingMoietyMemoryReference.mat` to `*EndAtom.mat`;
  3. for each case, rebuilds `dBTM` from `TESTDIR/data/rxnFiles`, asserting that the stored `BG` and `dATM` are reproduced (`isequaln`);
  4. recaptures each case under `'bondChange'` and stores `goldenCase.dBTM`;
  5. writes `FEATURE/goldenDifferenceReport.md`, listing per case each changed field, before and after.

  If the two new files together exceed 10 MB, store no `dBTM`; the helper rebuilds it per case instead. The report records which.
- [X] T020 [US1] Update the golden helper in `TEST`:
  - pass `goldenCase.dBTM`, or the rebuilt one;
  - add the `'endAtom'` comparison against `*EndAtom.mat` (FR-006), passing no `dBTM`.
- [X] T021 [US1] Review `goldenDifferenceReport.md`. Only `reacting` fields may change; any `arm` or `moietyFormulae` difference stops the work (FR-007). Run every test in `TESTDIR`; all must pass (SC-006). Commit (commit 3).

---

## Phase 6: Full collapsed VMH network (US3)

- [X] T022 [US3] Create `FEATURE/paperIncidenceCheck.m` and `FEATURE/paperIncidenceCheck.sh`, modelled on feature `20261103-115636`'s `conservedBondGroupCheck`. Actions:
  - **`identify`**: full mode from `WORK/vmh_with_dBTM.mat`, with the rule as an argument, saving `arm`, `moietyFormulae` and `reacting`, and recording the identification time and VmHWM;
  - **`compare`**: every `reacting` field, and the conserved fields;
  - **`report`**: the US3 metrics into `FEATURE/paperIncidenceResults.md`.

  The `.sh` script runs each action in its own scope under a 24 GiB cap, and starts only when at least 32 GB is free.
- [ ] T023 [US3] Run `identify` with `'endAtom'` and `compare` it against `BASELINE/moieties_Qconserved_graphsOn_reacting/reacting.mat` and `conserved_moieties.mat` (equality control, research R8). Any difference stops the work and is reported with the field.
- [ ] T024 [US3] Run `identify` with `'bondChange'`, then `report` (US3 AS1–AS3, SC-004, SC-005):
  - **`CRB2R`**: the number of condensed reacting bonds, and the nonzeros old against new;
  - **Reactions per bond**: the largest and median, old and new;
  - **Cover size**: old (2,399) against new;
  - **New fields**: `unchangedReactingBonds` and `offGraphBondChanges`;
  - **Subset test**: new entries outside old, split into union-only entries and others. "Others" must be 0; if not, stop and list the bonds;
  - **Conserved outputs**: identical to `BASELINE`;
  - **Cost**: identification time and peak RSS.

  A nonzero `offGraphBondChanges` is reported with a sample of the bonds and not tuned here.

---

## Phase 7: Polish and close-out

- [X] T025 [P] Static review:
  - `git diff BASE -- src` touches only `RM/identifyConservedReactingMoieties.m`;
  - the `'endAtom'` lines of STEP 3 are byte-identical to `BASE`'s;
  - no `nargin`, `evalc` or warning suppression;
  - every new error has an identifier.
- [ ] T026 [P] Run the quickstart's scenarios 1–3, and confirm that scenario 4's output is the T024 report.
- [ ] T027 Write the implementation receipt in `FEATURE/agent-runs/<UTC>-paper-reacting-bond-incidence/implementation-receipt.md`, and finish `FEATURE/paperIncidenceResults.md`. Open the PR into the fork's `develop`. List as follow-ups:
  - the reconXmoieties driver must pass `dBTM` and save it in the build checkpoint;
  - the tutorial source repository (`tutorials/`) needs the same call change;
  - Rhea.

---

## Dependencies & Execution Order

- **Phase 1**: T001 first. T002 then runs in the background through Phases 2–5. T003 runs in parallel with T002.
- **Phase 2** (T004–T008) needs T003. T008 needs T004–T007, and records the red state before any source edit.
- **Phase 3** (T009–T013) needs T008. Within the phase the tasks are sequential (one file).
- **Phase 4**: T014 and T016–T018 need Phase 3; T015 can run alongside T014.
- **Phase 5** needs Phase 4.
- **Phase 6**: T022 can be written any time after T001. T023 and T024 need T002's output and Phase 5.
- **Phase 7** needs everything above.

### Parallel opportunities

- T002 (the long rebuild) runs alongside T003–T021. Only one MATLAB job at a time uses more than a few GB, so the CI-size test runs can share the machine with it if at least 8 GB stay free.
- T003 and T004 touch different files.
- T015 and T014.
- T025 and T026.

## Requirement coverage

| Requirement | Tasks |
|---|---|
| FR-001 (paper's rule) | T004, T005, T011 |
| FR-002 (`dBTM` input, missing-input error) | T009, T014–T016 |
| FR-003 (union over merged edges) | T004, T010, T011 |
| FR-004 (non-changing reaction, order change; red before green) | T003, T006–T008 |
| FR-005 (unchanged rows, off-graph count) | T012, T017, T024 |
| FR-006 (`'endAtom'` option) | T009, T016, T019, T020 |
| FR-007 (conserved outputs unchanged) | T006, T021, T023, T024 |
| FR-008 (golden recapture, difference report) | T019–T021 |
| FR-009 (non-CI full-network check) | T002, T022–T024 |
| FR-010 (help text, provenance) | T013, T025 |
| SC-001 | T006, T008 |
| SC-002 | T005 |
| SC-003 (Fig. 11 unchanged) | T008, T018, T021 |
| SC-004 | T021, T023, T024 |
| SC-005 | T024 |
| SC-006 | T021, T026 |

## Implementation strategy

- **MVP**: Phases 1–5. With these done, the paper's rule is the default, tested on the paper's example and the transport fixture, with recaptured references.
- **Before the results are used at genome scale**: Phase 6 (US3).
- **Each phase ends with a commit**; Phases 3–5 are the three commits of the plan.
