# Implementation receipt: 20261106-092213-paper-reacting-bond-incidence

## Prompt

Run implementation (`/speckit-implement` for the active feature, tasks T001–T027). For the
full-network rebuild the maintainer chose to start it with a 4 GB memory margin instead of 8 GB.

## Final response

The paper's reacting-bond incidence (Rahou et al., JTB 621, 112348 (2026), §6.1, eq. 32) is the
default in `identifyConservedReactingMoieties`, and tasks T001–T026 are done. Everything is
committed locally on `20261106-092213-paper-reacting-bond-incidence` in
`~/cobratoolbox-rm-memory`. The PR to the fork's `develop` opens only with the maintainer's
agreement.

**Red before green (T008, T018)**: on the unchanged source the new assertions failed exactly
where research R3 said: the three shipped reactions' bond sets, and the transport reaction
`CITICITtm` marked on condensed bonds {1, 2, 5, 6}. After the change, every assertion passes,
and 17 of 17 `testReactingMoieties` files pass under COBRA's runner.

**Golden references (T019–T021)**: recaptured under `'bondChange'`. In every case `arm`,
`moietyFormulae`, the outcome and the pinned errors are unchanged. The old references are kept
as `*EndAtom.mat`, and `'endAtom'` reproduces them exactly.

**Full collapsed VMH (T002, T023, T024)**:

| Measure | `'endAtom'` | `'bondChange'` |
|---|---|---|
| Equal to the 2026-11-05 baseline | `PI ALL EQUAL 1` | — |
| `CRB2R` nonzeros (38963 condensed bonds) | 109877 | 68624 |
| `unchangedReactingBonds` | 0 | 23125 |
| `offGraphBondChanges` | 0 | 0 |
| Cover size | 2399 | 2791 |
| Time; peak RSS | 942 s; 11.4 GiB | 856 s; 14.5 GiB |

New entries not in the old incidence: 42894, all union-only; others 0. `CRB2R` equals the
sets recomputed independently from the bond changes' component pairs. `L`, `M2M`, `M2R` and
`moietyFormulae` are identical under both rules.

**Not verified**: Rhea; the reconXmoieties driver (it does not yet pass `dBTM`); the
tutorial-derived test in place (it lacks `data/rxnFiles`, before and after this change).
Full-network runs are N = 1.

## Diff summary

Against `ad0d11d60`, `src` and `test` (12 files, +927 −62):

- `src/analysis/topology/reactingMoieties/identifyConservedReactingMoieties.m`: fifth input
  `dBTM`; `options.reactingBondIncidence` {(`'bondChange'`), `'endAtom'`}; errors
  `:missingBondTransitions`, `:invalidReactingBondIncidence` and `:bondOnTwoCondensedEdges`;
  warning `:offGraphBondChanges`; new fields `reacting.unchangedReactingBonds` and
  `reacting.offGraphBondChanges`. The `'endAtom'` branch is the earlier STEP 3, re-indented only.
- `test/.../testConservedReactingMoieties.m`: per-reaction bond sets, controls, the interface,
  the new fields, the transport fixture and the `'endAtom'` golden loop.
- `test/.../data/rxnFilesTransport/` (new): the consistent-arm files and `CITICITtm.rxn`.
- `test/.../data/*Reference.mat` recaptured with `dBTM`; `*EndAtom.mat` (new) as at `ad0d11d60`.
- `test/tutorialDerived/.../tutorial_conservedAndReactingMoieties.m`: passes `dBTM`.

Feature folder: spec, plan, research, contract, quickstart, tasks, `rebuildWithBondTransitions.m`,
`paperIncidenceCheck.m` and `.sh`, `capturePaperIncidenceGoldens.m`, `goldenDifferenceReport.md`,
`paperIncidenceResults.md`, this receipt.

## Tests

- `testReactingMoieties`: 17 of 17 pass under `runScriptFile`, as `runTestSuite` calls it.
- Non-CI: the red record, the golden recapture, the full-network rebuild, equality control and
  report (`paperIncidenceResults.md`).

## Unresolved issues

- Under MATLAB's `runtests`, three sections of two untouched test files fail, because
  `runtests` does not carry variables between `%%` sections. COBRA's runner passes them.
- The tutorial-derived test looks for a missing `data/rxnFiles` folder, before and after this
  change; a scratch copy with the folder linked passes.
- The largest rows grow (5195 → 8301 reactions): by the union rule (FR-003), an edge between
  large atom-transition components collects every reaction that changes any of its merged bonds.

## Deviations from tasks.md

- A third error, `:bondOnTwoCondensedEdges`, checks that each bond maps to one condensed edge;
  it cannot fire while condensed edges are keyed by their component pair.
- The test helper is `expectedCondensedSets(model, dBTM, arm, reacting)`, without `BG`.
- The new test blocks use `% ---` markers, not `%%` sections, which would stop variables being
  shared between blocks under `runtests`.
- The planted unchanged-row case removes the bond changes of both `ACONTm` and `r0317`, so that
  one condensed bond is changed by no reaction.
- The full-network runs used a 4 GB memory margin (`MARGIN_GB=4`) instead of 8 GB, at the
  maintainer's request.

## Follow-ups

- The reconXmoieties driver must pass `dBTM` and save it in the build checkpoint.
- The tutorial source repository (`tutorials/`) needs the same call change.
- Rhea.
- The tutorial-derived test's missing `data/rxnFiles` folder.

## Other information

- Inputs and run folders are in the session scratchpad (`work/`), outside the repository.
