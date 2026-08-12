# Quickstart: Verifying the corrected atom/bond node-identity fix

**Feature**: 017-fix-atom-bond-node-identity | **Date**: 2026-08-11

Runnable steps that prove Parts A+B+C work together end-to-end. All commands assume MATLAB R2024b
at `/usr/local/MATLAB/R2024b/bin/matlab` (not on `PATH`) and fast headless init via
`initCobraToolbox(false, 'agent')`, exactly as used to derive every decision in `research.md`.

## Prerequisites

- MATLAB R2024b+ available; a MILP solver installed (existing test declares
  `prepareTest('needsMILP', true)`).
- Working tree on branch `017-fix-atom-bond-node-identity`, with Parts A+B+C applied together (per
  research.md's "Implementation order" — they are not independently mergeable; Part A alone
  regresses and crashes, as proven empirically for feature 016).

## Scenario A — Node identity is genuinely disambiguated, sanity check still passes (US1)

```matlab
initCobraToolbox(false, 'agent');
global CBTDIR
fileDir = [CBTDIR filesep 'test' filesep 'verifiedTests' filesep 'analysis' filesep 'testReactingMoieties'];
rxnFilesDir = [fileDir filesep 'data' filesep 'rxnFiles'];
model = readCbModel([CBTDIR filesep 'test' filesep 'models' filesep 'mat' filesep 'Recon3D_301.mat']);
subModel = extractSubNetwork(model, {'r0317'; 'ACONTm'; 'r0426'});
options.directed = 0; options.sanityChecks = 1;
lastwarn('');
[dATM, metAtomMappedBool, ~, M2Ai, ~, dATME, BG, dBTM] = ...
    buildAtomAndBondTransitionMultigraph(subModel, rxnFilesDir, options);
[msg, ~] = lastwarn();
assert(isempty(msg), 'Unexpected warning: %s', msg);
h2oRows = find(strcmp(dATM.Nodes.mets, 'h2o[m]'));
assert(numel(h2oRows) == 6, 'Expected 6 distinct h2o[m] atom nodes (2 reactions x 3 atoms), got %d', numel(h2oRows));
```

**Expected outcome**: No warning; 6 distinct `h2o[m]` atom nodes (not 3 merged).

## Scenario B — Bond-loop lookup resolves correctly, no crash (US2)

Continue the same session — reaching this point without a `MATLAB:table:VertDimMismatch`/size-
mismatch error on `EdgeTable.HeadBondHeadAtom`/etc. already demonstrates Part B works, since that
assignment executes inside the same `buildAtomAndBondTransitionMultigraph` call above. As an
explicit check:

```matlab
assert(numedges(dBTM) > 0, 'Bond transition multigraph unexpectedly empty');
```

**Expected outcome**: The call above completes without error, and `dBTM` is non-empty.

## Scenario C — Consistency-check formulas hold (US3)

The absence of a warning in Scenario A already confirms `res` is zero for this fixture. To inspect
directly (requires either exposing the corrected `d`/`res` as additional outputs during
implementation, or reproducing the corrected computation externally using `M2Ai`, `Ti2R`, and
`model.S` as in research.md Decision 3):

```matlab
N = full(subModel.S(metAtomMappedBool, :));
% d, D, res computed per research.md Decision 3 steps 1-3 (or read directly from the
% function's internal diagnostic output printed under options.sanityChecks = 1, if no numerical
% residual/warning is printed, res is zero)
```

**Expected outcome**: No `Inconsistency between reaction stoichiometry and atom mapped reactions`
diagnostic block is printed for `h2o[m]` (or any other metabolite in this fixture).

## Scenario D — Within-reaction multi-instance metabolite is disambiguated (US1 / FR-007)

Using the fixture identified or constructed per research.md Decision 4:

```matlab
% substitute the located/constructed fixture's directory and reaction list
[dATM2, ~, ~, M2Ai2] = buildAtomAndBondTransitionMultigraph(multiInstanceSubModel, multiInstanceRxnFilesDir, options);
% assert the multi-instance metabolite's atom nodes are correctly disambiguated by instance number
% (exact assertion depends on which fixture Decision 4 resolves to; see tasks.md for the concrete form)
```

**Expected outcome**: Documented once Decision 4's fixture choice is finalized during
implementation (FR-011 requires this to be executed and observed, not assumed).

## Scenario E — Genuine inconsistency still raises a distinct, specific error (US3 / FR-006)

Using a constructed case where a metabolite's local atom numbering genuinely differs between two
RXN files that both use it:

```matlab
% construct or locate such a case; call buildAtomAndBondTransitionMultigraph with
% options.sanityChecks = 1 and confirm a specific, named error is raised (not the generic
% "Inconsistent directed atom transition multigraph" warning, and not silent success)
```

**Expected outcome**: A distinct, named error identifying the metabolite and the two conflicting
reactions/counts (per research.md Decision 3, step 2).

## Scenario F — No regression in the existing test suite (FR-012)

```matlab
cd(fullfile(CBTDIR, 'test', 'verifiedTests', 'analysis', 'testReactingMoieties'))
run testConservedReactingMoieties
```

**Expected outcome**: Completes with all existing assertions passing (conserved-moiety invariant
`norm(full(arm.L) * N) < tol`, bond table row counts, etc.), plus the new assertions from
Scenarios A-E.

## Scenario G — Fix confined to the target file (SC-007)

```bash
git diff --stat develop...017-fix-atom-bond-node-identity -- src/
```

**Expected outcome**: Only
`src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m` is listed.
