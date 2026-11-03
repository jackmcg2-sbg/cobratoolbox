# Results: find the conserved bond group without building every bond subgraph

Feature `20261103-115636-conserved-bond-group-pruning`, base `3c7ee7186` (the fork's `develop`), 2026-11-03.

Every MATLAB run went in its own memory-capped user scope (`MemorySwapMax = 0`), one at a time, with the cap at most the available memory minus 8 GB at its start (`conservedBondGroupCheck.sh`). Peak RSS is the identification-window VmHWM (`peakResidentKB`), reported in GiB (kB / 1,048,576).

## Verdict

| Criterion | Result |
|---|---|
| SC-001 (tests) | **pass**: 17 of 17 `testReactingMoieties` tests, golden references unchanged |
| SC-002 (equality, 7 subnetworks) | **pass**: `RM ALL EQUAL 1` on all 7, 4 of 4 controls detected on each |
| SC-003 (full network, hard gate) | **pass**: 10.83 GiB, 926 s; conserved outputs identical to the conserved-only run |
| SC-004 (memory and time, reported) | n = 1,000: 3.98 → 3.13 GiB, 157 → 139 s; n = 2,000: 8.60 → 3.97 GiB, 569 → 228 s |
| SC-005 (per-stage, reported) | the peak is now set by the moiety graph (`extractPartitionSubgraphs`), not the bond stage |

## Inputs (T002)

Every input was rebuilt with the fixed builder (`rebuildCheckpoint.m`, or E34 for random n = 100–1,000), and every one reports 0 corrupted metabolites, 0 self-loops (molfile equality of feature `20261102-151507`).

| Input | Build | Note |
|---|---|---|
| random n = 100, 250, 500, 1,000 | E34 rebuild, copied | |
| random n = 2,000 | 573 s | |
| bfs n = 500 | 68 s | |
| bfs n = 2,000 | 405 s | |
| full collapsed VMH (9,634 reactions, 9,489 metabolites) | 5,186 s | from a copy of `model_screened.mat`; 9,634 of 9,634 reactions atom-mapped; peaked at its 9 GB cap but completed |

## Base behaviour (T003)

Recorded on the base's `findAndExtractMolecularGraphs`:

- **Zero subgraphs**: raises `MATLAB:TooManyOutputsDueToMissingBraces` ("Unable to perform assignment with 0 elements on the right-hand side."). `findConservedBondGroup` delegates the empty case to it, so it raises the same error; `testFindConservedBondGroup` asserts this.
- **One subgraph**: conserved group `1`, reacting groups `zeros(1, 0)`.
- **Reference cases**: `bondSubgraphPeelingReference.mat` has 23 cases, of which 22 extract (`ok`) on the peeling path and `atomBeyondBIG` errors. `bondSubgraphReference.mat` has the CI inputs (peeling path) and 5 fallback cases, of which `componentLabelOutOfRange` and `zeroBIGEdges` extract and the other 3 error. The peeling reference has no `n332Inputs` field, so the test's 332-reaction branch does not run. No capture script or new reference was needed.

## Self-check (T005)

Base against base on random n = 100: `RM ALL EQUAL 1`, all 4 planted differences detected.

## Tests (SC-001)

`testReactingMoieties`: 17 of 17 pass after commits 1–2 and after commit 3, including the two new and extended tests (`testExtractBondSubgraphs`, `testFindConservedBondGroup`) and the unchanged golden comparison (`testConservedReactingMoieties`). The suite was not run with commit 1 alone; commit 1 has no caller, and the run after commit 2 covers it.

## Equality (SC-002, T017)

New against base, full mode, `sanityChecks = 0`: every `arm` and `reacting` field and `moietyFormulae` `isequaln`, with the four planted differences detected.

| Input | Result |
|---|---|
| random n = 100 | `RM ALL EQUAL 1` |
| random n = 250 | `RM ALL EQUAL 1` |
| random n = 500 | `RM ALL EQUAL 1` |
| random n = 1,000 | `RM ALL EQUAL 1` |
| random n = 2,000 | `RM ALL EQUAL 1` |
| bfs n = 500 | `RM ALL EQUAL 1` |
| bfs n = 2,000 | `RM ALL EQUAL 1` |

The base finished every input under its cap, so none is left out.

## Memory and time (SC-004, T018)

Peak RSS (GiB) and identification time (s). The memory runs ran back to back (n = 1,000: base, new, base, new; n = 2,000: base, new); the equality runs are listed too.

| Input | Run | Base | New | New / base |
|---|---|---|---|---|
| random n = 100 | equality | 2.13 GiB, 16.4 s | 2.15 GiB, 19.9 s | 1.01, 1.21 |
| random n = 250 | equality | 2.34 GiB, 36.8 s | 2.36 GiB, 40.1 s | 1.01, 1.09 |
| random n = 500 | equality | 2.80 GiB, 74.6 s | 2.66 GiB, 78.4 s | 0.95, 1.05 |
| bfs n = 500 | equality | 2.59 GiB, 22.7 s | 2.37 GiB, 21.4 s | 0.92, 0.94 |
| random n = 1,000 | equality | 3.95 GiB, 160.1 s | 3.14 GiB, 146.4 s | 0.80, 0.91 |
| random n = 1,000 | memory 1 | 3.98 GiB, 159.7 s | 3.13 GiB, 145.1 s | 0.79, 0.91 |
| random n = 1,000 | memory 2 | 3.99 GiB, 153.4 s | 3.12 GiB, 133.1 s | 0.78, 0.87 |
| bfs n = 2,000 | equality | 6.53 GiB, 110.2 s | 3.35 GiB, 75.4 s | 0.51, 0.68 |
| random n = 2,000 | equality | 8.61 GiB, 569.1 s | 3.98 GiB, 231.5 s | 0.46, 0.41 |
| random n = 2,000 | memory | 8.58 GiB, 569.5 s | 3.96 GiB, 224.1 s | 0.46, 0.39 |

SC-004 (median of the 2 memory runs at n = 1,000; the memory run at n = 2,000): n = 1,000, 3.98 → 3.13 GiB and 157 → 139 s; n = 2,000, 8.58 → 3.96 GiB and 570 → 224 s. Siblings agree within 1 % in memory and 9 % in time, so no pair was repeated. At n ≤ 500 there is no memory gain, as expected: the giant atom component, whose copies P7 avoids, is still small there.

An earlier new run at random n = 250 took 66.3 s (machine load from other work); the equality rerun above took 40.1 s.

## Full network (SC-003, SC-005, T007, T019)

**Conserved-only reference (T007)**: 1,299 conserved moieties, 715.8 s (16 GB cap).

**Full-mode run (T019)**: one run, not disturbed (no other job; `memory.events` oom 0).

| Measure | Value | Gate |
|---|---|---|
| Identification-window peak RSS | 11,351,560 kB = **10.83 GiB** | ≤ 16 GiB |
| Identification time | **925.9 s** (15.4 min) | ≤ 6 h |
| Scope cap | 24 GB, completed, exit 0 | |
| `L`, `M2M`, `M2R`, `moietyFormulae` against the conserved-only run | `CB CONSERVED EQUAL 1`, planted `L` difference detected | identical |
| `findConservedBondGroup` | 1 of 2,100 size groups classified, 13,811 of 59,734 subgraphs built | |

Outside the identification window, saving `outputs.mat` (23.7 GB, -v7.3) took 25 min and raised the process's maximum RSS to 16.5 GB (`time.txt`). The first comparison, under a 16 GB cap, was killed for memory while loading `arm` from that file (kept as `runs/full-compare-oom16G`); it was rerun under a 28 GB cap (37 GB available) and peaked at 27.2 GiB. This is a cost of the check harness, not of identification.

**Per-stage time and RSS (SC-005)**, from the probes (elapsed time since the identification start, RSS at the probe; the checkpoint holds 5.26 GiB before identification):

| Stage | Elapsed | RSS |
|---|---|---|
| atom transition graph built | 96 s | 5.88 GiB |
| connected components, atom isomorphism classes | 657 s | 6.63 GiB |
| bond sizes and edge indices (`extractBondSubgraphs`, build none) | 672 s | 6.70 GiB |
| `findConservedBondGroup` | 691 s | 6.70 GiB |
| conserved group's BMG and its mets-labelled classes | 721 s | 6.70 GiB |
| moiety transition graph, bond information (`ABG`) | 787 s | 6.85 GiB |
| moiety graph (`extractPartitionSubgraphs`) | 920 s | 9.99 GiB |
| reacting-moiety steps 1–6 | 925 s | 10.83 GiB |

The bond stage, which made the full network infeasible on the base, now takes 64 s with flat memory. The next bottlenecks:

- **time**: the atom stage, from the atom transition graph to the atom isomorphism classes (535 s, 58 %);
- **memory**: the moiety graph, `extractPartitionSubgraphs` (+3.1 GiB, 133 s), which now sets the peak.

The `mets`-labelled classification (P8) is not a bottleneck here: it took 12 s on the 13,811-member conserved group.

## Not verified

- **Full-size equality of the reacting outputs against the base**: the base cannot run the full network (projected 240–280 GB). Their exactness at full size rests on the argument in `findConservedBondGroup`'s help (research R3) and on equality at every size the base finishes (up to n = 2,000). The conserved outputs are checked at full size against the conserved-only run.
- **Rhea**: not run.
- **`sanityChecks = 1`**: its path is unchanged and covered only by the existing tests.
- **Repeats**: the full-network run is N = 1.
