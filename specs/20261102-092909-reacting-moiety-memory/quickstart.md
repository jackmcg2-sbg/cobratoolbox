# Quickstart: validating the full-mode memory changes

**Prerequisites**:
- MATLAB R2024b with Gurobi, and `initCobraToolbox(false)`.
- The memory scan's checkpoints (spec, Assumptions), copied to a work folder.
- Every MATLAB run goes in its own memory-capped user scope, one at a time: `systemd-run --user --scope -p MemoryMax=<cap> -p MemorySwapMax=0 -p OOMPolicy=continue -- matlab -batch "..."`, with `<cap>` at most the available memory minus 8 GB.

`FEATURE` below stands for `specs/20261102-092909-reacting-moiety-memory`, and `TESTDIR` for `test/verifiedTests/analysis/testReactingMoieties`.

## Step 1: Capture on unchanged source

Run `FEATURE/captureMemoryReferences.m`.

**Expected**:
- It refuses to run if `src/analysis/topology/reactingMoieties` differs from `8a927a4c6`.
- It writes the two new `.mat` files under `TESTDIR/data/`, and prints the case counts and any recorded error cases.

## Step 2: Extended tests on unchanged source

Run the four extended tests.

**Expected**: all pass, and each prints that its planted differences were detected.

## Step 3: Check-script self-check

Run `FEATURE/reactingMoietyMemoryCheck.sh selfcheck`.

**Expected**: base against base gives equal outputs on random n = 100, and all four controls are detected.

## Step 4: After each of P1–P6

Run every test in `TESTDIR`.

**Expected**: all pass, after each commit.

## Step 5: Equality and memory

Run `FEATURE/reactingMoietyMemoryCheck.sh equality`. This covers random n = 100, 250, 500 and 1,000, and bfs n = 500, base against new.

**Expected**: every output is `isequaln`, and all controls are detected.

Then run `FEATURE/reactingMoietyMemoryCheck.sh memory`. This alternates 2 runs each of base and new at random n = 1,000.

**Expected**:
- peak ratio ≤ 0.50 (SC-003);
- the time ratio is reported (SC-004).

The results are written to `FEATURE/reactingMoietyMemoryResults.md`.
