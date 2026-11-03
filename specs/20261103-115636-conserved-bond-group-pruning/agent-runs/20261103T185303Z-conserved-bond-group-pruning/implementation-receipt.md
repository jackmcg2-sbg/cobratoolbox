# Implementation receipt: 20261103-115636-conserved-bond-group-pruning

## Prompt

The spec, plan and tasks are approved. Run the Spec Kit implementation phase for the active feature.

## Final response

Implementation of `20261103-115636-conserved-bond-group-pruning` (P7) is complete: tasks T001–T023 are done, and the full-network hard gate passes. Everything is committed locally on the feature branch in `~/cobratoolbox-rm-memory`. Nothing is pushed and no PR is open.

**Full collapsed VMH (SC-003, hard gate)**: **pass**. Full-mode identification ran in one 24 GB scope:

| Measure | Result | Gate |
|---|---|---|
| Identification-window peak RSS | 10.83 GiB | ≤ 16 GiB |
| Time | 926 s | ≤ 6 h |
| `L`, `M2M`, `M2R`, `moietyFormulae` | identical to the conserved-only run (1,299 conserved moieties), planted difference detected | identical |

`findConservedBondGroup` classified 1 of 2,100 size groups and built 13,811 of 59,734 bond subgraphs.

**Tests (SC-001)**: 17 of 17 `testReactingMoieties` tests pass after commits 1–2 and after commit 3, golden references unchanged.

**Equality (SC-002)**: full-mode outputs `isequaln` to the base on random n = 100, 250, 500, 1,000 and 2,000 and bfs n = 500 and 2,000, with 4 of 4 controls detected on each.

**Memory and time (SC-004)**:

| Input | Peak RSS, base → new | Time, base → new |
|---|---|---|
| random n = 1,000 (median of 2) | 3.98 → 3.13 GiB | 157 → 139 s |
| random n = 2,000 | 8.58 → 3.96 GiB | 570 → 224 s |
| bfs n = 2,000 | 6.53 → 3.35 GiB | 110 → 75 s |

**Next bottleneck (SC-005)**: memory, the moiety graph (`extractPartitionSubgraphs`, +3.1 GiB); time, the atom stage (535 s of 926). The bond stage now takes 64 s with flat memory.

**Not verified**: full-size equality of the reacting outputs against the base (the base cannot run it); Rhea; the full-network run is N = 1.

The PR to the fork's `develop` opens only with the maintainer's agreement.

## Diff summary

Against `3c7ee7186`, `src` and `test`:

- `src/analysis/topology/reactingMoieties/extractBondSubgraphs.m`: optional `subgraphsToBuild` (empty: unchanged; `0`: build none; indices: build only those) and a fourth output `subgraphSizes`.
- `src/analysis/topology/reactingMoieties/findConservedBondGroup.m` (new): the conserved group from the size groups that can hold it, exactly as `findAndExtractMolecularGraphs` would give it.
- `src/analysis/topology/reactingMoieties/identifyConservedReactingMoieties.m`: with `sanityChecks = 0`, the bond stage uses the two above; with `sanityChecks = 1` it is unchanged.
- `test/.../testExtractBondSubgraphs.m` (extended) and `test/.../testFindConservedBondGroup.m` (new).

Feature folder: spec, plan, research, contract, quickstart, tasks, `rebuildCheckpoint.m`, `conservedBondGroupCheck.m` and `.sh`, `conservedBondGroupResults.md`, this receipt.

## Tests

- `testReactingMoieties`: 17 of 17 pass (after commits 1–2, after commit 3).
- Non-CI: self-check, equality on 7 subnetworks, memory runs, full-network run and conserved comparison (`conservedBondGroupResults.md`).

## Unresolved issues

- The check harness's comparison of the full run needs about 27 GiB, because it loads `arm` from a 23.7 GB `outputs.mat`. It is a test-harness cost; identification itself is unaffected.
- No full-size check of the reacting outputs against an independent reference.

## Other information

- Static review (T020): `git diff 3c7ee7186 -- src` touches only the three files; no `nargin`, `evalc` or warning suppression is added; the `sanityChecks = 1` branch makes the same calls as before.
- Inputs and run folders are in the session scratchpad (`p7/`), outside the repository.
