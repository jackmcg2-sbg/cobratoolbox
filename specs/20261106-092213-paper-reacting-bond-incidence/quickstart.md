# Quickstart: validate the reacting-bond incidence from bond changes

Interface: [contracts/bond-change-incidence.md](contracts/bond-change-incidence.md). Design: [plan.md](plan.md).

## Prerequisites

- MATLAB R2024b, with COBRA initialised from `~/cobratoolbox`.
- This worktree's `src/analysis/topology/reactingMoieties` first on the path. Check that `which identifyConservedReactingMoieties` resolves here.
- A MILP solver: `changeCobraSolver('gurobi', 'MILP', 0)`.

## Scenario 1: the paper's example (CI)

```matlab
runtests('testConservedReactingMoieties')
```

Expected:
- **Fig. 11** on the consistent-arm copy: 4 vertices, 6 bonds, `ACONTm` {b, c, d, e}, `r0426` {a, d, e, f}, `r0317` {a, b, c, f}, a cover of 2.
- **Shipped files**: each reaction's condensed bonds equal the bonds `dBTM` records as broken or formed (research R3 table).
- **With `CITICITtm` added**: its `CRB2R` column is zero, it is not selected, and the other columns are unchanged.
- **Conserved outputs**: unchanged ($L$ = [1 1 1 0; 0 1 1 1]).

## Scenario 2: the earlier rule and the errors (CI)

These cases are in the same test file:
- **`'endAtom'`** reproduces `*EndAtom.mat` exactly.
- **Full mode without `dBTM`** raises `identifyConservedReactingMoieties:missingBondTransitions`.
- **An invalid value** raises `identifyConservedReactingMoieties:invalidReactingBondIncidence`.
- **Conserved-only without `dBTM`** runs.

## Scenario 3: whole test folder (CI)

```matlab
runtests('test/verifiedTests/analysis/testReactingMoieties')
```

Expected: all pass. `goldenDifferenceReport.md` lists every changed `reacting` field per case, and no `arm` or `moietyFormulae` field.

## Scenario 4: full collapsed VMH network (non-CI)

```bash
specs/20261106-092213-paper-reacting-bond-incidence/paperIncidenceCheck.sh <workDir> <baselineRunDir>
```

Here `<baselineRunDir>` is `vmhcollapsed_20261105_142523`. The script takes about 2 h, most of it rebuilding the multigraph, and runs under a 24 GiB cap. Expected in `paperIncidenceResults.md`:
- **Equality control**: `'endAtom'` equals the baseline's `reacting`. If not, the script stops.
- **Old against new**: the nonzeros of `CRB2R`, the largest and median reactions per bond (old: up to 5,195), and the cover sizes (old: 2,399).
- **Subset test**: every new entry outside union-only entries is an old entry.
- **Counts**: `unchangedReactingBonds` and `offGraphBondChanges`, each reported. A nonzero `offGraphBondChanges` is investigated before the results are used.
- **Conserved outputs**: identical to the baseline.
