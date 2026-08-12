# Quickstart: Verifying the atom/bond node identity fix

**Feature**: 016-atom-bond-node-identity | **Date**: 2026-08-11

This guide documents runnable steps that prove the fix works end-to-end. It does not contain
implementation code — see `data-model.md` for the exact identity-key format and `tasks.md` (Phase
2) for the concrete edit and test steps.

## Prerequisites

- MATLAB R2024b+ (repo baseline), with COBRA Toolbox initialized (`initCobraToolbox`).
- A MILP solver available (the existing test declares `prepareTest('needsMILP', true)`) so the
  test skips cleanly rather than failing spuriously on installations without one.
- Working tree on branch `016-atom-bond-node-identity`, with the fix applied to
  `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m` only.

## Scenario A — No false-positive sanity-check warnings (US1 / SC-001)

Run the existing fixture, which already samples reactions `r0317`, `ACONTm`, `r0426` (both
`r0317` and `r0426` produce the shared metabolite `h2o[m]`, reproducing the defect) with
`options.sanityChecks = 1` already set:

```matlab
cd(fileparts(which('testConservedReactingMoieties')))
run testConservedReactingMoieties
```

**Expected outcome (after fix)**: The run completes without printing `Warning: Inconsistent
directed atom transition multigraph` or `Warning: Inconsistent directed bond transition
multigraph` to console. Before the fix, on this same fixture, at least one of these warnings is
expected to fire (baseline to confirm before editing, per Principle III's "before/after"
comparison discipline).

## Scenario B — Per-species atom node count is chemically correct (US2 / SC-002)

Immediately after the `buildAtomAndBondTransitionMultigraph` call inside the same test/session:

```matlab
h2oRows = find(startsWith(dATM.Nodes.mets, 'h2o'));   % or the field M2Ai's rows are indexed by
d = diag(M2Ai * M2Ai');
% inspect d for the rows corresponding to h2o[m] instances across r0317 and r0426
```

**Expected outcome (after fix)**: Every diagonal entry corresponding to an `h2o[m]` atom node
equals 3 (water's true atom count), for every instance in every reaction it appears in — not an
inflated multiple such as the previously observed 16 or 32.

## Scenario C — Downstream conserved/reacting moiety identification still works (US3 / SC-003)

The same test file continues past graph construction into
`identifyConservedReactingMoieties`, `identifyConservedReactingSubgraphs`, and
`buildReactingMoietyTables`. Confirm these existing assertions still hold after the fix (no
change to their expected values, since the fix does not alter true atom-transition semantics,
only node-identity string collisions):

```matlab
assert(norm(full(arm.L) * N) < tol);            % conserved-moiety invariant L*N = 0
assert(isequal(size(arm.L), [2, 4]));
assert(numel(moietyFormulae) == 2);
assert(numel(reacting.selectedReactionNames) == 2);
assert(height(brokenBondsTable) == 7);
assert(height(formedBondsTable) == 7);
```

**Expected outcome**: All existing assertions pass unchanged.

## Scenario D — Fix is confined to the target file (SC-005)

```bash
git diff --stat develop...016-atom-bond-node-identity -- src/
```

**Expected outcome**: The only file listed under `src/` is
`src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m`.

## Scenario E — No other CI regressions (SC-004)

Run the full test category before and after the change and diff pass/fail results:

```matlab
cd(fullfile(CBTDIR, 'test', 'verifiedTests', 'analysis', 'testReactingMoieties'))
result = run(testConservedReactingMoieties); % or invoke via test/testAll.m's analysis category
```

**Expected outcome**: Identical or improved pass/fail status compared to the pre-fix baseline run
of the same test category.
