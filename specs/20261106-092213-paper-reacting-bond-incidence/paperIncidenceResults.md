# Results: reacting-bond incidence from bond changes

Feature `20261106-092213-paper-reacting-bond-incidence`. MATLAB R2024b, Gurobi MILP, COBRA
initialised from `~/cobratoolbox` with this worktree's `src/analysis/topology/reactingMoieties`
first on the path. N = 1 per run.

## Red before green (T008)

Run on 2026-11-06 with the source at `ad0d11d60` (no source change) and the new assertions
of T005–T007 in `testConservedReactingMoieties.m`. The test was run twice: once as is, where
it stops at the first failing assertion, and once with a logging stand-in for `assert` first
on the path, so that every assertion is evaluated and each failure is listed.

| Assertion | Expected | Result |
|---|---|---|
| T005, shipped files, `ACONTm` | fail | **fail**: `CRB2R` {1, 2, 4, 6, 7}, bonds changed on {1, 2, 4, 6} |
| T005, shipped files, `r0317` | fail | **fail**: `CRB2R` {1, 3, 5, 6, 7}, bonds changed on {1, 3, 5, 7} |
| T005, shipped files, `r0426` | fail | **fail**: `CRB2R` {2, 3, 4, 5}, bonds changed on {2, 3, 4, 5, 6, 7} |
| T005, off-graph count 0; planted control | pass | pass |
| Fig. 11 on the consistent-arm copy | pass | pass |
| T007, cis-aconitate's C=C (order change) | either | pass: the bond's condensed edge is {`r0317`, `r0426`} under both rules |
| T006 assert 1, condensed graph 4 × 6 with `CITICITtm` | pass | pass |
| T006 assert 2, $L$ over the original four metabolites | pass | pass |
| T006 assert 3, `CITICITtm` column zero | fail | **fail**: marked on {1, 2, 5, 6} |
| T006, `CITICITtm` not selected | pass | pass |
| T006 assert 4, Fig. 11 sets with `CITICITtm` | pass | pass |
| Conserved outputs and every other assertion | pass | pass |

The failures are exactly the expected ones, with the bond sets of research R3.

## Transport fixture (T003)

`data/rxnFilesTransport` parses (the builder's RXN quality checks pass for all 4 files) and
the builder records 0 broken and 0 formed bonding interactions for `CITICITtm` (2 and 2 for
each of the other reactions).
