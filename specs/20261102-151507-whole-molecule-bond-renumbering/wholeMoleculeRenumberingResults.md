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
