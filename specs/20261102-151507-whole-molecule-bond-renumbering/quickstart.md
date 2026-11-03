# Quickstart: validating whole-molecule bond renumbering

**Prerequisites**:
- MATLAB R2024b with Gurobi, and `initCobraToolbox(false)`.
- Each MATLAB run in its own memory-capped user scope, one at a time.

`FEATURE` below stands for `specs/20261102-151507-whole-molecule-bond-renumbering`, and `TESTDIR` for `test/verifiedTests/analysis/testReactingMoieties`.

## Step 1: Red on the unchanged source

Run `testBuildAtomAndBondTransitionMultigraph`.

**Expected**: the molfile-equality section fails and names the corrupted metabolites:
- citrate in `main`;
- the CoA and carnitine species;
- `o2[x]` and `h2o2[x]`.

The planted control is detected.

## Step 2: Fix, then all tests

Run every test in `TESTDIR`.

**Expected**:
- molfile equality passes on every fixture;
- the golden comparisons fail on bond-level fields only (`arm.MG`, `reacting`), never on conserved-moiety fields.

## Step 3: Recapture and review

Run `FEATURE/captureRenumberedGoldens.m`.

**Expected**:
- both references are rewritten;
- `FEATURE/wholeMoleculeRenumberingResults.md` lists every changed field per case;
- no conserved field (`L`, `M2M`, `M2R`, `ATG`, `MTG`, `moietyFormulae`) changed.

Then run all tests.

**Expected**: all pass.

## Step 4: Paper values

Run `testConservedReactingMoieties`.

**Expected**:
- the shipped files give the paper's $L$, 6 instances, 6 transitions, and a condensed reacting graph of 6 vertices and 7 bonds;
- the consistent-arm copy gives Fig. 11: 4 vertices, 6 bonds and the three bond sets.

## Step 5: Non-CI

Run `FEATURE/wholeMoleculeRenumberingCheck.m`.

**Expected**:
- full collapsed VMH: 0 corrupted metabolites;
- builder wall time reported against the base;
- random n = 500: conserved outputs identical.
