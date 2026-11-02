# Results: Lower the memory of full-mode reacting-moiety identification

**Date**: 2026-11-02. **Base**: `8a927a4c6` (its `reactingMoieties` source is identical to `6bc522da0`). **Head**: `ec8fd9b7b`.

**Environment**:
- MATLAB R2024b Update 8, with Gurobi for the MILP;
- every MATLAB run in its own memory-capped user scope (`MemoryMax` 8 GB, or 16 GB at n = 1,000; `MemorySwapMax=0`), one at a time;
- available memory at least the cap plus 8 GB at every start.

## Tests (SC-001, SC-005, SC-006)

All 16 tests in `test/verifiedTests/analysis/testReactingMoieties/` pass at every stage:
- on the unchanged source, with the references and the extended base-behaviour tests (`74e6d04b0`);
- after each of P1 (`ce0bb089f`), P2 (`2386c98bd`), P3 (`d86bd34db`), P4 (`98fd90b6d`), P5 (`5229c7997`) and P6 (`0cc960148`);
- after the help-text commit (`ec8fd9b7b`).

New CI coverage:
- 10 full-mode golden cases on the coaM, coaX, coaR, crn and crnM bond-key fixtures, 5 with `sanityChecks` 0 and 5 with `sanityChecks` 1. The latter raise the pre-existing `identifyIsomorphicClasses.m:34` sanity-check error, which is pinned as is;
- 60 interleaved-group classification cases, with call and fallback counts;
- `labelOnly` on the CI fixture, the 22 main-path and fallback peeling cases, and the 5 fallback cases (including error cases);
- `computeGraphs` false, true and empty;
- planted-difference controls in each of the four extended tests, all detected.

The `labelOnly` and `computeGraphs` sections fail on the unchanged source ("Too many input arguments") and pass with the changes.

## Equality on real subnetworks (SC-002), T017

`reactingMoietyMemoryCheck.sh equality`: full mode, `sanityChecks = 0`, from copies of the memory scan's checkpoints. The base is a `git archive` of `8a927a4c6`, and the new code is this branch at `4fcda054c`, whose source differs from the head only in comments. Each comparison covers every `arm` and `reacting` field, and `moietyFormulae`, with four planted differences.

| Checkpoint | Outputs `isequaln` | Controls detected | Base peak RSS / time | New peak RSS / time |
|---|---|---|---|---|
| random n = 100 | yes | 4 of 4 | 2.33 GiB / 22.6 s | 2.17 GiB / 24.3 s |
| random n = 250 | yes | 4 of 4 | 2.89 GiB / 56.8 s | 2.36 GiB / 41.8 s |
| random n = 500 | yes | 4 of 4 | 4.49 GiB / 112.3 s | 2.82 GiB / 81.6 s |
| random n = 1,000 | yes | 4 of 4 | 10.29 GiB / 308.0 s | 3.97 GiB / 161.7 s |
| bfs n = 500 | yes | 4 of 4 | 4.24 GiB / 37.7 s | 2.61 GiB / 25.3 s |

Peak RSS is that of the MATLAB process inside the identification window: VmHWM is reset just before `identifyConservedReactingMoieties` and read just after it. Each row is one run of each, N = 1.

## Memory gate (SC-003, hard) and time (SC-004, reported), T018

`reactingMoietyMemoryCheck.sh memory`: random n = 1,000, alternating base, new, base, new; outputs not saved.

| Run | Peak RSS | Time |
|---|---|---|
| base 1 | 10.29 GiB | 245.7 s |
| new 1 | 4.01 GiB | 146.5 s |
| base 2 | 10.29 GiB | 256.4 s |
| new 2 | 3.99 GiB | 152.1 s |

The siblings of each pair are within 1.00× (peak) and 1.04× (time) of each other, so no repeat was needed.

- **SC-003**: the ratio of the median peaks is **0.389**, against a gate of ≤ 0.50. **PASS.**
- **SC-004**: the ratio of the median times is **0.595**, against ≤ 0.80 (reported only).

## Job times (local, 2026-11-02)

- Capture: 09:55–09:56.
- Tests on the unchanged source: 09:58.
- Red/green check of the option sections, and the tests after P1–P6: 10:00–10:10.
- Self-check: 10:11–10:13.
- Equality: 10:13–10:51.
- Memory gate: 10:52–11:08.
- Final tests: 11:10.

The full log is the `jobs.txt` of the work folder.

## Not verified

- Equality above 1,000 reactions, and on full Rhea.
- The `sanityChecks = 1` full path on real subnetworks. In CI it is covered only by the 3-reaction `mainDefaultSanity` case; on the bond-key fixtures it raises the pre-existing sanity-check error.
- Peaks after identification, for example a caller's `-v7.3` save of `arm`.
- The remaining $n^{2.5}$ growth of bond-subgraph edges, which is out of scope.
