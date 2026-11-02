# Results: Whole-molecule bond renumbering

**Base**: `5a4371497`. Each MATLAB run went in its own memory-capped user scope, one at a time. Job times are local, 2026-11-02.

## Red: the unchanged source (T004)

`molfileEqualityCheck` on the six fixtures, built from their RXN files with the unchanged builder:

| Fixture | Corrupted | Misplaced bonds | Self-loops | Metabolites |
|---|---|---|---|---|
| main | 1 of 4 | 2 | — | cit[m] |
| coaM | 8 of 10 | 30 | — | accoa[m] coa[m] crn[m] hncsacoaox[m] hypgcoa[m] nndcacoa[m] ppacoa[m] ppacrn[m] |
| coaX | 9 of 18 | 23 | h2o2[x], o2[x] | accoa[x] adrncoa[x] coa[x] ddcdatmtcoa[x] h2o2[x] nsnc621tehcoa[x] o2[x] ptca3Zcoa[x] vitEadencoxcoaE[x] |
| coaR | 3 of 9 | 9 | — | coa[r] dca4Z7Zcoa[r] ocdcacoa[r] |
| crn | 10 of 10 | 54 | — | coa[c] crn[c] crn[m] crn[r] eldccrn[c] hcsa17Zcrn[c] hcsa17Zcrn[r] hdca2Ecrn[c] hdca2Ecrn[m] ocdcacoaE[c] |
| crnM | 7 of 7 | 36 | — | coa[m] crn[c] crn[m] hdca2Ecrn[c] hdca2Ecrn[m] ppacoa[m] ppacrn[m] |
| **Total** | **38 of 58** | | | |

This matches the reconXmoieties exploration E33 case for case.

`testBuildAtomAndBondTransitionMultigraph` with the new sections fails on the unchanged source at its first fixture: "FR-004: in the main fixture the bonds of cit[m] differ from their molblock".

## FR-006 baseline (T005)

Conserved-moiety outputs (`L`, `M2M`, `M2R`, `ATG`, `MTG`, `moietyFormulae`) were saved for 23 cases:
- the 16 golden cases, with inputs rebuilt from RXN files with builder `sanityChecks = 0`;
- the six fixtures;
- random n = 500.

The eight `…Sanity` golden cases raise the pre-existing `identifyIsomorphicClasses` sanity-check error ("Inconsistent mapping of atoms to connected components.") on inputs rebuilt this way. They are compared as errors.

## Recaptured golden references (T010, T011)

Run 2026-11-02 15:42:25, head `95103e100`. For each case: whether the stored inputs and each output changed (`=` unchanged, `changed`).

### `conservedReactingMoietiesReference.mat`

| Case | outcome | BG | dATM | conserved (L, M2M, M2R, ATG, MTG, formulae) | arm fields changed | reacting fields changed |
|---|---|---|---|---|---|---|
| mainConservedOnly | ok | changed | = | = | `MG` | — |
| mainConservedOnlySanity | error | changed | = | = | — | — |
| mainDefault | ok | changed | = | = | `MG` | `Condensed_RBG`, `CRB2R`, `ReactMoietyMatrix`, `ReactMoietySets`, `ReactMoietyGraphs` |
| mainDefaultSanity | error | changed | = | = | — | — |
| coaXConservedOnly | ok | changed | = | = | `MG` | — |
| crnMConservedOnly | ok | changed | = | = | `MG` | — |

### `reactingMoietyMemoryReference.mat`

| Case | outcome | BG | dATM | conserved (L, M2M, M2R, ATG, MTG, formulae) | arm fields changed | reacting fields changed |
|---|---|---|---|---|---|---|
| coaMFull | ok | changed | = | = | `MG` | `Condensed_RBG`, `CRB2R`, `ReactMoietyMatrix`, `ReactMoietySets`, `ReactMoietyGraphs` |
| coaMFullSanity | error | changed | = | = | — | — |
| coaXFull | ok | changed | = | = | `MG` | `Condensed_RBG`, `CRB2R`, `ReactMoietyMatrix`, `ReactMoietySets`, `ReactMoietyGraphs` |
| coaXFullSanity | error | changed | = | = | — | — |
| coaRFull | ok | changed | = | = | `MG` | `Condensed_RBG`, `CRB2R`, `ReactMoietyMatrix`, `ReactMoietySets`, `ReactMoietyGraphs` |
| coaRFullSanity | error | changed | = | = | — | — |
| crnFull | ok | changed | = | = | `MG` | `Condensed_RBG`, `CRB2R`, `ReactMoietyMatrix`, `ReactMoietySets`, `ReactMoietyGraphs` |
| crnFullSanity | error | changed | = | = | — | — |
| crnMFull | ok | changed | = | = | `MG` | `Condensed_RBG`, `CRB2R`, `selectedReactions`, `selectedReactionNames`, `ReactMoietyMatrix`, `ReactMoietySets`, `ReactMoietyGraphs` |
| crnMFullSanity | error | changed | = | = | — | — |

Every case's `dATM` and conserved-moiety outputs are unchanged, and the outcome of every error case (the pre-existing `identifyIsomorphicClasses` sanity-check error) is unchanged. Changes are confined to the bond graph and what is built from it:
- `BG` changed in every case;
- `arm.MG` changed in every successful case;
- the reacting-moiety fields changed in the full-mode cases;
- in `crnMFull` the minimal cover now selects different reactions.

## FR-006: conserved outputs before and after (T011)

All 23 T005 cases (16 golden cases, the six fixtures and random n = 500, each rebuilt from RXN files) give identical `L`, `M2M`, `M2R`, `ATG`, `MTG`, `moietyFormulae` and outcome with the fixed builder as with the unchanged one (`compare_conserved`, all identical). All 16 tests in `testReactingMoieties/` pass with the recaptured references.

## The paper's published values (T012–T014)

`testConservedReactingMoieties` now asserts values taken from Rahou et al. (2026):
- **Shipped RXN files**: `arm.L` = [1 1 1 0; 0 1 1 1] over (h2o, cit, icit, cisa) (App. C.1.1), 6 moiety instances and 6 moiety transitions (§5.7.1), formulae H2O and C6H3O6, and a condensed reacting bond graph of 6 vertices and 7 bonds.
- **`data/rxnFilesConsistentArms`**: Fig. 11, with 4 vertices (the atom-transition components of citrate's C3, C7, O2 and H8 = the paper's C3, C13, O2, H15) and 6 bonds. The reacting-bond sets are 𝒴₁ `ACONTm` {b, c, d, e}, 𝒴₂ `r0426` {a, d, e, f} and 𝒴₃ `r0317` {a, b, c, f}, with a 2-reaction cover.

With the fixed builder the test passes. With the unchanged builder (`git archive 5a4371497`) it fails: "Shipped files: condensed reacting bond graph has 7 vertices and 10 bonds, expected 6 and 7". All 16 tests pass.

## Full collapsed VMH network (T015, non-CI)

`wholeMoleculeRenumberingCheck` ran the fixed builder on a copy of the 2026-10-23 collapsed-VMH model (`model_screened.mat`) with its RXN folder (`rxns/`, 9,634 reactions), then ran `molfileEqualityCheck`. The job ran 2026-11-02 15:54–17:11 under a 16 GB cap, with peak memory 6,558 MiB.

| Measure | Result |
|---|---|
| Metabolites with bonds compared | 9,489 |
| Corrupted | **0** (E33 on the unchanged builder: 3,533) |
| Misplaced bonds | 0 |
| Self-loops | 0 |
| `nonIsomorphicMolblock` warnings | 0 |
| Builder wall time | 4,219 s |

- **SC-002**: met.
- **SC-006** (reported): 4,219 s against 7,646 s for the base builder, a ratio of 0.55, within the 1.10 bound. The base time comes from the 2026-10-23 pipeline run (`6bc522da0`, whose builder files equal `5a4371497`'s), measured on another day under unknown load. Base and new were not run back to back in this session, so the 1.5× repeat rule was not applied. The ratio shows no slowdown, but it is not a controlled speed-up measurement.
- The builder's existing message "9495 metabolites should be bond mapped, but only 9489 in the dBTM" lists six single-atom metabolites with no bonds (`h[c]`, `cl[c]`, `f[c]`, `br[c]`, `i[c]`, `s[c]`). It is printed by unchanged code and is unrelated to this feature.

## Not verified

- **Rhea**: the fixed builder was not run on the collapsed Rhea corpus, so its molfile-equality count is unmeasured.
- **Non-isomorphic copies in real corpora**: no VMH copy needed the isomorphism search or raised the FR-003 warning, because every copy equals its reference. The isomorphism path and the warning are covered only by the CI fixtures (`rxnFilesNonIsomorphicCopy`; the planted control).
- **Downstream outputs**: reacting-moiety outputs built on `BG` since feature 019/020 (2026-08-18) were built on corrupted bond graphs and have not been re-run.
