# Quickstart: Validating the Hub-Guard Keying Fix

**Feature**: `specs/20260908-102947-hub-guard-keying-gap-fix/spec.md`
**Plan**: [plan.md](./plan.md) · **Tasks**: [tasks.md](./tasks.md)

This is a validation/run guide — it documents how to prove the fix works end-to-end, not how to
implement it (see [plan.md](./plan.md) Design section and `tasks.md` for that). Every command
below is MATLAB, run headless, consistent with plan.md's Target Platform.

## Prerequisites

- `initCobraToolbox` already run in the MATLAB session.
- Fixture pair vendored: `MEVK1x.rxn`/`PMEVKx.rxn` under
  `test/verifiedTests/analysis/testReactingMoieties/data/rxnFiles/` (tasks.md T006 — sourced from
  `~/repos/reconXmoieties/chempy_results/old/vmh2_reconx_for_atom_mapping/rxnfiles/atomMapped/`,
  same vendoring pattern as feature 020's research R10). Confirm presence before running Scenario 1:
  ```bash
  ls test/verifiedTests/analysis/testReactingMoieties/data/rxnFiles/MEVK1x.rxn \
     test/verifiedTests/analysis/testReactingMoieties/data/rxnFiles/PMEVKx.rxn
  ```
- For Scenario 3 (corpus-scale) only: access to the reconXmoieties sibling repository
  (`~/repos/reconXmoieties` or `/media/JACK/repos/...`, per this feature's own checkout) and the
  RXN corpus paths named in spec.md's Input section (VMH: `atomMapped_standardised`; Rhea:
  `rhea_atomMapped/rxnfiles/atomMapped`). No network fetch is required or permitted at test time
  (plan.md Constraints).

## Scenario 1 — Worked example: `5pmev[x]` resolves to its true bond count (SC-001)

Proves US1's Independent Test and FR-001/FR-002/FR-004 for the smallest concrete case.

```matlab
% From the repository root, MATLAB already initialized (initCobraToolbox)
model = <submodel containing exactly the MEVK1x and PMEVKx reactions>; % tasks.md T007
options = struct();  % defaults; no options.sanityChecks change needed
[~, ~, ~, ~, ~, ~, ~, dBTM] = buildAtomAndBondTransitionMultigraph(model, ...
    'test/verifiedTests/analysis/testReactingMoieties/data/rxnFiles', options);

met5pmevNodes = numel(findnode(dBTM, ... % nodes belonging to 5pmev[x]
    dBTM.Nodes.Properties.RowNames(contains(dBTM.Nodes.Properties.RowNames, '5pmev'))));
assert(met5pmevNodes == 23, ...
    'Expected 23 bond nodes for 5pmev[x] post-fix, got %d', met5pmevNodes);
```

**Expected outcome**: exactly 23 bond-graph nodes, no bond-count mismatch (pre-fix: 43-46 per
PROPOSAL.md §2.4). Equivalent, permanent form of this check: the new assertion added to
`testConservedReactingMoieties.m` (tasks.md T016).

## Scenario 2 — Full existing regression suite is unchanged (FR-004, FR-005, SC-003, SC-005)

Proves US2: re-keying every atom must not change output for any already-passing case.

```matlab
run('test/verifiedTests/analysis/testReactingMoieties/testIdentifyAtomEquivalenceClasses.m')
run('test/verifiedTests/analysis/testReactingMoieties/testCanonicalBondKey.m')
run('test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m')
```

**Expected outcome**: all three pass with no new failures. Per tasks.md T017-T019, comparison must
be against the pre-fix baseline's underlying values (node counts, edge counts, keys — not just
pass/fail), for `coa[m]`/`coa[x]`/`coa[r]`/`crn[m]`/`crn[c]` and the synthetic-chain/fault-injection
cases in `testIdentifyAtomEquivalenceClasses.m`.

## Scenario 3 — Corpus-scale confirmation (FR-006, SC-002, SC-003, SC-004)

Proves US3: measures the fix's real impact against the live corpus rather than trusting the
Python-prototype-measured 21/93 figure.

```matlab
% Run from the reconXmoieties sibling repository, not this repository (research.md R4;
% no new in-repo scan tooling, no file created under experiments/ in *this* repo)
cd(fullfile('~', 'repos', 'reconXmoieties'));
run('experiments/moietySizing/scripts/validate_symmetric_atom_classes_matlab.m')
```

**Expected outcome** (tasks.md T023-T025):
- Every metabolite among the original 93 crit1 failures whose instances are structurally
  consistent (same atom count, bond count, element histogram, total charge across files) now
  passes crit1.
- Every metabolite that still fails crit1 is confirmed structurally inconsistent (Diagnosis 2,
  out of scope, FR-008) — not silently left unexplained.
- crit1 pass count `>=` the pre-fix baseline (234/327) — zero regressions among previously-passing
  metabolites.

Record the actual post-fix numbers in the implementation receipt (tasks.md T027) — do not report
the Python prototype's 21/93 figure as the delivered result.

## Troubleshooting

- **Fixture missing**: re-vendor `MEVK1x.rxn`/`PMEVKx.rxn` per Prerequisites; do not fetch over
  the network in a test run (plan.md Constraints).
- **Corpus paths unavailable**: Scenario 3 requires local access to the sibling reconXmoieties
  repository and the RXN corpus; if unavailable, Scenarios 1-2 alone still discharge FR-001
  through FR-005 — record Scenario 3 as deferred, not skipped silently (tasks.md T023 note on
  recording corpus drift if the sample must change).
- **A previously-passing fixture now fails**: stop — this is a regression (US2). Do not proceed to
  Scenario 3 or write the implementation receipt until the regression is root-caused and fixed;
  compare against `git log` for the exact pre-fix commit if the baseline is unclear.
