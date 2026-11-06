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

## After the source change (T018)

Run on 2026-11-06 after T009–T017. The stored golden cases were logged instead of thrown (a
scratch copy of the test whose `checkGoldenCase` prints the failure), so that the run reaches
every other assertion.

- **Passing**: every assertion outside the golden comparisons, including T005 (the shipped
  files' sets), T006 (the transport), T007 (the order change), T016 (the two errors, the
  `'endAtom'` sets of `ad0d11d60`, `'endAtom'` ignoring `dBTM`, conserved outputs independent
  of the rule) and T017 (the new fields, and the planted case without the bond changes of
  `ACONTm` and `r0317`).
- **Failing, as expected until Phase 5**: the 12 full-mode golden cases of
  `conservedReactingMoietiesReference.mat` (`mainDefault`, `mainDefaultSanity`) and
  `reactingMoietyMemoryReference.mat` (`coaM`, `coaX`, `coaR`, `crn`, `crnM`, each `Full`
  and `FullSanity`). They were captured without `dBTM`, so each raises `missingBondTransitions`.
  The six `*Sanity` cases pin the error "Inconsistent mapping of atoms to connected
  components.", which is raised after the options are read. With `dBTM` passed, they are
  expected to raise it again (T019–T020). The conserved-only golden cases pass.

## Golden references (T019–T021)

`capturePaperIncidenceGoldens.m` ran on 2026-11-06 from head `3bbe50978`, with Gurobi. The
per-case, per-field table is [goldenDifferenceReport.md](goldenDifferenceReport.md).

- **Inputs reproduced**: for every case the rebuilt `BG` and `dATM` were `isequaln` to the
  stored ones, so the rebuilt `dBTM` belongs to the same build.
- **FR-007**: in all 18 cases the outcome is unchanged, each pinned error has the same
  identifier and message, and every `arm` and `moietyFormulae` field is unchanged.
- **What changed**: only `reacting`, in the 6 full-mode cases that run (`mainDefault`,
  `coaMFull`, `coaXFull`, `coaRFull`, `crnFull`, `crnMFull`), plus the two new fields.
  `CRB2R` loses most of its entries on the bond-key fixtures. For example, `coaMFull` goes from
  262 nonzeros to 21 and `coaXFull` from 374 to 46. `crnMFull`'s cover shrinks from
  {`PPACOAATREVm`, `HMR_2634`} to {`PPACOAATREVm`}.
- **Unchanged reacting bonds**: on the bond-key fixtures, most condensed reacting bonds belong
  to no reaction under the paper's rule (79 of 98 in `coaMFull`, 85 of 124 in `coaXFull`, 79
  of 95 in `coaRFull`, 24 of 34 in `crnFull`). These bonds carry the reacting label
  (`IsomorphismClass == 0`), but no reaction of the fixture breaks or forms them. They are left
  out of the cover, as rows with no reaction were before.
- **No bond changes off the graph**: `offGraphBondChanges` is 0 in every case.
- **Storage**: both references store `dBTM`, 2.60 MB together (limit 10 MB). Today's files
  are kept unchanged as `*EndAtom.mat`.

**Test folder (SC-006)**: every one of the 17 test files in `testReactingMoieties` passes
under COBRA's own runner (`runScriptFile`, as `runTestSuite` calls it), with this worktree's
source and tests first on the path. Under MATLAB's `runtests`, three sections of two files
this feature does not touch fail: `testBuildAtomAndBondTransitionMultigraph` (`test_i`,
`test_j`) and `testFindConservedBondGroup` (`plantedDifference`). They fail because
`runtests` does not carry a variable from one `%%` section into the next (`molfileOptions`,
`syntheticCases`). Those files and the functions they test are identical to `ad0d11d60`.

## Static review and quickstart (T025, T026)

- **Scope of the change**: `git diff ad0d11d60 -- src` touches only
  `identifyConservedReactingMoieties.m`.
- **`'endAtom'` lines**: STEP 3's earlier code is unchanged apart from indentation. It now sits
  in the `else` branch, and `git diff -w` removes none of its lines.
- **Forbidden constructs**: none of `nargin`, `evalc` or warning suppression appears in the
  added lines.
- **Identifiers**: every new error and warning has one. Besides the contract's two errors
  there is a third, `identifyConservedReactingMoieties:bondOnTwoCondensedEdges`. It is T011's
  check that each bond maps to at most one condensed edge, and it cannot fire while condensed
  edges are keyed by their component pair.
- **Scenarios 1–3**: covered by the T021 runs.
- **Tutorial-derived test**: `test/tutorialDerived/.../tutorial_conservedAndReactingMoieties.m`
  looks for a `data/rxnFiles` folder beside itself, which neither this repository nor
  `~/cobratoolbox` has. It therefore stops before its identification call, at `ad0d11d60` as
  now, and `runTestSuite` does not run it (it runs only `verifiedTests`). A scratch copy with
  `data/rxnFiles` linked to the test's shipped fixture passes under `runScriptFile`, including
  the changed call that passes `dBTM`.
