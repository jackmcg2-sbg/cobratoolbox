# Quickstart: validating the pruned conserved bond group

Every MATLAB run goes in its own memory-capped user scope, one at a time, with a cap of at most the available memory minus 8 GB. `WORK` is a folder outside the repository.

## Step 1: Inputs

Rebuild the local checkpoints with the fixed builder (`rebuildCheckpoint.m`):
- random n = 2,000, bfs n = 500 and bfs n = 2,000, from copies of the memory scan's checkpoints;
- the full network, from a copy of the 2026-10-23 `model_screened.mat` and its RXN folder (about 70 min, 16 GB cap).

Copy random n = 100–1,000 from the 2026-11-03 rebuild (E34). Then run conserved-only identification of the full checkpoint.

## Step 2: Self-check and base

```bash
WORK=<work folder> specs/20261103-115636-conserved-bond-group-pruning/conservedBondGroupCheck.sh selfcheck
```

```bash
WORK=<work folder> specs/20261103-115636-conserved-bond-group-pruning/conservedBondGroupCheck.sh base
```

`selfcheck` runs base against base on random n = 100: equal, with the controls detected. `base` saves the base outputs for the equality cases.

## Step 3: After each commit

Run every test in `test/verifiedTests/analysis/testReactingMoieties/`. All must pass.

## Step 4: Equality, memory, full network

```bash
WORK=<work folder> specs/20261103-115636-conserved-bond-group-pruning/conservedBondGroupCheck.sh equality
```

```bash
WORK=<work folder> specs/20261103-115636-conserved-bond-group-pruning/conservedBondGroupCheck.sh memory
```

```bash
WORK=<work folder> specs/20261103-115636-conserved-bond-group-pruning/conservedBondGroupCheck.sh full
```

- `equality`: SC-002, on 7 subnetworks.
- `memory`: SC-004. Random n = 1,000, base/new alternating twice, then n = 2,000 once each.
- `full`: SC-003 and SC-005. One run under a 24 GB cap, started only when 32 GB is available; probes on.

Results go to `conservedBondGroupResults.md`.
