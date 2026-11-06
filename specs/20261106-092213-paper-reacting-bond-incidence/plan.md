# Implementation Plan: Reacting-bond incidence from bond changes, as in the paper

**Branch**: `20261106-092213-paper-reacting-bond-incidence` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/20261106-092213-paper-reacting-bond-incidence/spec.md`

## Summary

`identifyConservedReactingMoieties` builds `CRB2R` from atom transitions: a condensed reacting bond is marked against every reaction that moves either end atom of one of its bonds. The paper (§6.1, eq. 32) marks it only against the reactions that break, form or change the order of it. This feature makes that the default:
- **Data source**: the per-reaction bond changes are read from `dBTM`, which the builder already returns. Broken and formed interactions are its edges to and from each reaction's energy pseudo-bond (research R1, R2).
- **Merged edges**: a condensed edge's row is the union over all reacting bonds merged into it (R3).
- **New input**: `dBTM` becomes a fifth, trailing, optional input (R4).
- **New option**: `options.reactingBondIncidence = 'bondChange' | 'endAtom'`. `'endAtom'` keeps today's rule exactly (R5).

A read-only design check (R1, R3) shows that the paper's rule reproduces Fig. 11 on the consistent-arm fixture. It also shows that the two rules already differ on the shipped fixture, which no current test looks at.

## Technical Context

**Language/Version**: MATLAB R2024b Update 8.

**Primary Dependencies**:
- base MATLAB `graph`/`digraph` and `sparse`;
- `buildAtomAndBondTransitionMultigraph` (unchanged);
- the MILP goes through `solveCobraMILP` (Gurobi on the reference machine).

**Storage**:
- **CI data**: the paper's example (Recon3D subnetwork `r0317`, `ACONTm`, `r0426`) with `data/rxnFiles` and `data/rxnFilesConsistentArms`.
  - New folder `data/rxnFilesTransport/`: three consistent-arm copies plus a hand-written `CITICITtm.rxn` (R6).
  - The two golden references are recaptured with `dBTM`, and today's files are kept as `*EndAtom.mat` (R7).
- **Local data** (non-CI): the collapsed VMH model and the RXN corpus `/media/JACK/repos/ctf/rxns/atomMapped_vmh`. A work folder outside the repository holds the rebuilt checkpoint (R8).

**Testing**:
- `testConservedReactingMoieties.m` is extended (III-Naming: one test file per function, and this is the function's file).
- All of `test/verifiedTests/analysis/testReactingMoieties/` must pass.
- A non-CI check script lives in this directory.

**Target Platform**: headless Linux.

**Project Type**: scientific MATLAB library.

**Performance Goals**: none gated. The reacting stage takes under 1.2 s at every measured size (reconXmoieties E28). The non-CI check reports time and peak RSS.

**Constraints**:
- **Conserved outputs** are `isequaln` under both rules.
- **`'endAtom'`** reproduces today's `reacting` exactly, apart from the two new fields.
- **No silent fallback** to the old rule (VII-C).

**Scale/Scope**:
- **Source**: one source file changed, an estimated 60–100 lines in the reacting stage and help text.
- **Tests**: one test file extended, one fixture folder added, two references recaptured, one test-derived tutorial updated.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Scientific correctness**: the change implements the paper's published definition (§6.1, eq. 32). The paper's own example is checked against its published bond sets, with an independent test that fails on today's rule (FR-004). **PASS**
- **II. Backward compatibility**: **breaking change, approved in the spec** (Compatibility). The default rule changes, and full-mode calls without `dBTM` now raise an error. Migration path:
  - pass the builder's `dBTM` as the fifth input;
  - or set `options.reactingBondIncidence = 'endAtom'` for exact earlier results.

  Argument positions, option names and existing errors are unchanged. Conserved-only calls are unaffected. **PASS** (with the documented exception, confirmed by the maintainer at plan review, 2026-11-06)
- **III. Testing**:
  - **III-Naming**: the tests go in `testConservedReactingMoieties.m`.
  - **Order**: the new assertions are written first and shown to fail on the unchanged source: the transport column and the shipped-fixture per-reaction sets (Design 4).
  - **Planted controls**: a planted entry in `CRB2R` and a planted bond change in a copied `dBTM` must each be detected.
  - **III-Coverage**: the header lists the tier, behaviours and authors.

  **PASS**
- **IV. Solver abstraction**: no solver change. **PASS**
- **V. Scope control**: the reacting-bond label, KI-001, cover selection, Rhea and the reconXmoieties driver are out of scope (spec). **PASS**
- **VI. Spec-driven gate**: this spec, plan and tasks precede any source edit. Implementation starts only on the maintainer's explicit invocation. **PASS**
- **VII. MATLAB standards**:
  - the optional `dBTM` is detected with `exist`/`isempty`, not `nargin` (VII-D);
  - errors carry identifiers (VII-C);
  - the off-graph count is a visible warning (VII-B);
  - no `evalc`;
  - help text and provenance follow VII-E.

  **PASS**
- **IX. File placement**: source in `src/analysis/topology/reactingMoieties/`, test and fixtures beside the existing ones, and feature scripts and results in this directory. **PASS**

## Design

1. **Inputs and option** (contract). Read `options.reactingBondIncidence`, with default `'bondChange'`. Validate it next to the existing `conservedMoietiesOnly` / `computeMoietyGraphs` checks, before any computation. The `dBTM` check (`missingBondTransitions`) runs at the same place, but only when full mode and `'bondChange'` are both set, so a conserved-only call never sees it.
2. **STEP 1, edge de-duplication**: keep the third output of `unique(E_sorted, 'rows', 'stable')` as `rbgEdgeToCondensed`. It maps each `COndensed_RBG` edge (one per `RBG` edge) to its row of `Condensed_RBG`. Nothing else in STEP 1 changes.
3. **STEP 3, `CRB2R`**:
   - **`'endAtom'`**: today's two code paths, untouched.
   - **`'bondChange'`**:
     1. From `dBTM.Edges`, take broken interactions (`TailMet` in `model.rxns`; bond `HeadBondIndex`) and formed ones (`HeadMet` in `model.rxns`; bond `TailBondIndex`). The reaction column is `ismember(Edges.rxns, model.rxns)`.
     2. Map each changed `BondIndex` to the condensed rows of the `RBG` edges with that `BondIndex`, through `rbgEdgeToCondensed`. Several rows are possible only if one bond lies on several `RBG` edges with different end components, which can't happen; the code asserts it.
     3. Build `CRB2R = spones(sparse(rows, cols, 1, nCRB, nRxns))`.
     4. Changed interactions with no row are counted into `offGraphBondChanges`, with one warning if the count is not zero (R9).
4. **Tests, written before the source change**, in this order:
   - **Shipped fixture, per-reaction sets.** Assert each reaction's condensed bonds as atom-transition component pairs, found independently from `dBTM`'s changes and `arm.ATG` components, as the design check does (R3 table). Run on the unchanged source, this fails for `ACONTm`, `r0317` and `r0426`.
   - **Transport fixture (US1 AS1).** Add `CITICITtm` with `addReaction` and build from `data/rxnFilesTransport`. Assert:
     - the condensed graph is still 4 vertices and 6 bonds;
     - the transport's `CRB2R` column is zero, and it is not selected;
     - the other three columns equal the Fig. 11 sets.

     The zero column fails on the unchanged source.
   - **Order change (US1 AS3).** On the consistent-arm fixture, the condensed edge holding cis-aconitate's C=C (formed in `ACONTm`, and changed by `r0426` as well) lists exactly the reactions that change it.
   - **Rule option and errors (FR-002, FR-006).**
     - A conserved-only call without `dBTM` works.
     - A full-mode call without it raises `missingBondTransitions`.
     - An invalid value raises `invalidReactingBondIncidence`.
     - `'endAtom'` reproduces the `*EndAtom.mat` goldens.
   - **`unchangedReactingBonds` and `offGraphBondChanges` (FR-005).** Both are zero or false on the fixtures. A planted case is built by removing one reaction's energy edges from a copy of `dBTM`: its bonds become unchanged rows and leave the cover's constraints.
   - **Planted controls**: a flipped entry of `CRB2R`, and a copied `dBTM` with one extra energy edge, are each detected by the per-reaction assertion.
5. **Callers**: pass `dBTM` at every full-mode call in `testConservedReactingMoieties.m`, in the golden helper (`goldenCase.dBTM`) and in `test/tutorialDerived/.../tutorial_conservedAndReactingMoieties.m`.
6. **Golden references** (R7): `capturePaperIncidenceGoldens.m` in this directory.
   1. It asserts the source state (`git diff --quiet` on `reactingMoieties` against the implementation commit).
   2. It renames today's files to `*EndAtom.mat`.
   3. It rebuilds each case's `dBTM` from `data/rxnFiles`, asserting that the stored `BG` and `dATM` are reproduced.
   4. It recaptures under `'bondChange'`.
   5. It writes `goldenDifferenceReport.md` (per field, per case).
7. **Help text** (FR-010): the header gets the new input, the option, the two new fields and the paper reference. R5 in the pipeline comment is rewritten for both rules. Author/provenance lines are added per VII-E.

**Non-CI check** (US3, FR-009): `paperIncidenceCheck.m` and `paperIncidenceCheck.sh` in this directory.
- **Setup**: one capped scope (24 GiB) per MATLAB run. It asserts `which` for both functions.
- **Rebuild**: rebuild from the collapsed VMH model and RXN corpus, saving `dATM`, `BG` and `dBTM`.
- **`'endAtom'` identification**: compare its `reacting` with `vmhcollapsed_20261105_142523` as an equality control. That run is on COBRA `ad0d11d60`; if they differ, stop and report.
- **`'bondChange'` identification**, then write `paperIncidenceResults.md` with:
  - the nonzeros of `CRB2R`, old against new;
  - the largest and median reactions per bond;
  - the cover sizes;
  - `unchangedReactingBonds` and `offGraphBondChanges`;
  - the subset test, counting union-only entries separately;
  - conserved-output identity;
  - time and peak RSS.

## Project Structure

### Documentation (this feature)

```text
specs/20261106-092213-paper-reacting-bond-incidence/
├── spec.md, plan.md, research.md, quickstart.md, tasks.md
├── contracts/bond-change-incidence.md
├── checklists/requirements.md
├── capturePaperIncidenceGoldens.m      # NEW: golden recapture + difference report
├── goldenDifferenceReport.md           # NEW (generated)
├── paperIncidenceCheck.m               # NEW: non-CI full collapsed VMH check
├── paperIncidenceCheck.sh              # NEW: one capped scope per MATLAB run
├── paperIncidenceResults.md            # NEW (generated)
└── agent-runs/<UTC>-paper-reacting-bond-incidence/implementation-receipt.md
```

No `data-model.md`: the spec's Key Entities and the contract cover the data, as in this folder's earlier features.

### Source Code (repository root)

```text
src/analysis/topology/reactingMoieties/
└── identifyConservedReactingMoieties.m   # MODIFIED: dBTM input, reactingBondIncidence, STEP 1 map, STEP 3, two fields, help

test/verifiedTests/analysis/testReactingMoieties/
├── testConservedReactingMoieties.m       # MODIFIED: new assertions, dBTM at full-mode calls
└── data/
    ├── rxnFilesTransport/                # NEW: 3 consistent-arm copies + CITICITtm.rxn (identity map)
    ├── conservedReactingMoietiesReference.mat        # RECAPTURED (bondChange, with dBTM)
    ├── reactingMoietyMemoryReference.mat             # RECAPTURED (bondChange, with dBTM)
    ├── conservedReactingMoietiesReferenceEndAtom.mat # RENAMED from today's file
    └── reactingMoietyMemoryReferenceEndAtom.mat      # RENAMED from today's file

test/tutorialDerived/analysis/reactingMoieties/
└── tutorial_conservedAndReactingMoieties.m          # MODIFIED: pass dBTM
```

**Structure Decision**: the single toolbox layout.

## Implementation order (for `/speckit-tasks`)

1. **Setup**:
   - confirm the base (`ad0d11d60`);
   - write `CITICITtm.rxn` and check that it parses (`checkABRXNFiles`);
   - start the full-network rebuild early, since it takes about 1 h 41 min.
2. **Tests first**: add the Design 4 assertions and run them on the unchanged source. Record which fail (the expected red: shipped-fixture sets, the transport column, the option and errors) and which pass (Fig. 11, conserved outputs).
3. **Commit 1, source**: option and `dBTM` input, STEP 1 map, STEP 3 `'bondChange'`, the two fields, help text.
4. **Commit 2, callers**: pass `dBTM` in the test and the test-derived tutorial.
5. **Commit 3, goldens**: rename and recapture, with the difference report. Run the whole `testReactingMoieties/` folder.
6. **Non-CI check**: the `'endAtom'` equality control first, then `'bondChange'` and the US3 report.
7. **Close out**: static review, results files, receipt, PR into the fork's `develop`. List as follow-ups: the reconXmoieties driver and checkpoint change, and the tutorial source repository.

## Complexity Tracking

| Item | Why needed | Simpler alternative rejected because |
|---|---|---|
| Default changes (Principle II exception) | The maintainer chose the paper's rule as the default (spec Clarifications) | Defaulting to `'endAtom'` would keep the published method opt-in, and genome-scale results would silently stay on the old rule |
