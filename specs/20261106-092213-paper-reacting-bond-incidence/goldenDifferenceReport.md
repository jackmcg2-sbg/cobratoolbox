# Golden difference report

Feature `20261106-092213-paper-reacting-bond-incidence`, tasks.md T019. Run 2026-11-06 13:44:58, head `3bbe50978`, MILP solver gurobi. The references as at `ad0d11d60` are kept as `*EndAtom.mat`. For each case: the outcome, whether every `arm` and `moietyFormulae` field is unchanged (required), and each `reacting` field that changed, before and after. Fields new in this feature are listed as added.

## `conservedReactingMoietiesReference.mat`

| Case | Mode | Outcome | `arm`, `moietyFormulae` | `reacting` fields changed (before → after) |
|---|---|---|---|---|
| mainConservedOnly | conserved-only | ok | unchanged | — |
| mainConservedOnlySanity | conserved-only | error, unchanged ("Inconsistent mapping of atoms to connected components.") | unchanged | — |
| mainDefault | full | ok | unchanged | `CRB2R`: 7 x 3, 14 nonzeros → 7 x 3, 14 nonzeros; `ReactMoietyMatrix`: 7 x 2, 9 nonzeros → 7 x 2, 10 nonzeros; `ReactMoietySets`: 2 cells → 2 cells; `ReactMoietyGraphs`: 2 cells → 2 cells; `unchangedReactingBonds` added: 7 x 1 logical, 0 true; `offGraphBondChanges` added: 0 |
| mainDefaultSanity | full | error, unchanged ("Inconsistent mapping of atoms to connected components.") | unchanged | — |
| coaXConservedOnly | conserved-only | ok | unchanged | — |
| crnMConservedOnly | conserved-only | ok | unchanged | — |

## `reactingMoietyMemoryReference.mat`

| Case | Mode | Outcome | `arm`, `moietyFormulae` | `reacting` fields changed (before → after) |
|---|---|---|---|---|
| coaMFull | full | ok | unchanged | `CRB2R`: 98 x 3, 262 nonzeros → 98 x 3, 21 nonzeros; `ReactMoietyMatrix`: 98 x 3, 262 nonzeros → 98 x 3, 21 nonzeros; `ReactMoietySets`: 3 cells → 3 cells; `ReactMoietyGraphs`: 3 cells → 3 cells; `unchangedReactingBonds` added: 98 x 1 logical, 79 true; `offGraphBondChanges` added: 0 |
| coaMFullSanity | full | error, unchanged ("Inconsistent mapping of atoms to connected components.") | unchanged | — |
| coaXFull | full | ok | unchanged | `CRB2R`: 124 x 4, 374 nonzeros → 124 x 4, 46 nonzeros; `ReactMoietyMatrix`: 124 x 4, 374 nonzeros → 124 x 4, 46 nonzeros; `ReactMoietySets`: 4 cells → 4 cells; `ReactMoietyGraphs`: 4 cells → 4 cells; `unchangedReactingBonds` added: 124 x 1 logical, 85 true; `offGraphBondChanges` added: 0 |
| coaXFullSanity | full | error, unchanged ("Inconsistent mapping of atoms to connected components.") | unchanged | — |
| coaRFull | full | ok | unchanged | `CRB2R`: 95 x 2, 96 nonzeros → 95 x 2, 17 nonzeros; `ReactMoietyMatrix`: 95 x 2, 96 nonzeros → 95 x 2, 17 nonzeros; `ReactMoietySets`: 2 cells → 2 cells; `ReactMoietyGraphs`: 2 cells → 2 cells; `unchangedReactingBonds` added: 95 x 1 logical, 79 true; `offGraphBondChanges` added: 0 |
| coaRFullSanity | full | error, unchanged ("Inconsistent mapping of atoms to connected components.") | unchanged | — |
| crnFull | full | ok | unchanged | `CRB2R`: 34 x 3, 84 nonzeros → 34 x 3, 10 nonzeros; `ReactMoietyMatrix`: 34 x 1, 34 nonzeros → 34 x 1, 10 nonzeros; `ReactMoietySets`: 1 cells → 1 cells; `ReactMoietyGraphs`: 1 cells → 1 cells; `unchangedReactingBonds` added: 34 x 1 logical, 24 true; `offGraphBondChanges` added: 0 |
| crnFullSanity | full | error, unchanged ("Inconsistent mapping of atoms to connected components.") | unchanged | — |
| crnMFull | full | ok | unchanged | `CRB2R`: 38 x 2, 39 nonzeros → 38 x 2, 10 nonzeros; `selectedReactions`: [1 2] → 1; `selectedReactionNames`: {PPACOAATREVm, HMR_2634} → {PPACOAATREVm}; `ReactMoietyMatrix`: 38 x 2, 39 nonzeros → 38 x 1, 10 nonzeros; `ReactMoietySets`: 2 cells → 1 cells; `ReactMoietyGraphs`: 2 cells → 1 cells; `unchangedReactingBonds` added: 38 x 1 logical, 28 true; `offGraphBondChanges` added: 0 |
| crnMFullSanity | full | error, unchanged ("Inconsistent mapping of atoms to connected components.") | unchanged | — |

## Storage

The two references store `dBTM` (2.60 MB together, limit 10 MB).

