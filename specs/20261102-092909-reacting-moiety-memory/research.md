# Research: Lower the memory of full-mode reacting-moiety identification

The primary record is the reconXmoieties exploration `specs/20261030-121933-reacting-moiety-memory/exploration.md` (branch `explore/reacting-moiety-memory`, commits up to `138cd5a`). Its scripts are in `exploration/` beside it. Evidence IDs (E*n*) and checks (C*n*) below refer to that file. Every number is N = 1 per size unless stated.

## R1 — Where the memory and time go

**Decision**: target the bond-mapping stage and the intermediates it leaves alive. Do not target the reacting stage.

**Evidence** (6bc522da0, random n = 500, probes at every `%%` section):
- identification starts at 2.4 GB RSS and adds 2.1 GB;
- `extractBondSubgraphs` adds 0.86 GB;
- `findAndExtractMolecularGraphs` adds 0.64 GB that it keeps, plus 0.29 GB transient;
- the atom-component subgraphs add 0.33 GB;
- the moiety graphs add 0.09 GB;
- the reacting stage (RBG, `CRB2R`, MILP, `RM_graph`) adds about 0 GB and takes under 1 s (E4, E7).

Time is 137 s in total: extraction 41 s, atom-component isomorphism 35 s, unlabelled bond classification 21 s, labelled classification 19 s, moiety transition graph 14 s.

`whos` overstates resident memory, because copy-on-write data is counted once per holder (E5, D1). So every saving was measured as a scope or RSS peak.

**Alternatives rejected**: `profile -memory`, which did not finish even at n = 100 (D2).

## R2 — Which intermediates are dead (P1)

**Decision**: clear `bondSubgraphs`, `BMG`, `CBSubgrahs`, `bmgEdgeIndex` and `subgraphs` at their last read, and skip `CMTG`/`RMTG`/`CMG`/`RMG` (E1, E3). None of them is read after its point of clearing, and none is returned.

`computeGraphs` is a trailing optional input of `findAndExtractMolecularGraphs`, so other callers keep all six outputs.

## R3 — What classification reads (P2)

**Decision**: label-only bond subgraphs, used only when `sanityChecks` is off. The sanity check reads `Nodes.AtomIndex`.

Classification reads two things:
- the unlabelled classification reads only the structure of `bondSubgraphs{k}`;
- `identifyIsomorphicClasses` reads `BMG{m}` with `EdgeVariables 'mets'`, plus `EdgeIndex` and `BondIndex`.

**Evidence**: on all 29,761 bond-mapping components at n = 500, label-only and full extraction give the same class, node count and end nodes, the same `mets`, the same `EdgeIndex`, the same `bmgEdgeIndex`, and the same unlabelled and labelled classes. A swap of two `mets` values was detected (E9, C5). Extraction time drops from 53.8 s to 16.1 s.

## R4 — Sweep within (node, edge) groups (P3) and lazy caches (P6)

**Decision**: these keep the same comparisons in the same order. The first invariant check already rejects any pair whose node or edge counts differ, so restricting the sweep to the group removes only pairs that were rejected without an `isisomorphic` call. The diagnostic call count is therefore unchanged (FR-005, SC-006).

P6 builds a label-only copy only for a pair that is not decided by identical edge lists. It frees caches only for subgraphs that are never compared again.

**Evidence**: the existing `testClassifySubgraphIsomorphism` reference, call counts included, passes with P3 and P6 (E16, E21). P6 lowers peak RSS by 4.32 → 4.00 GB at n = 1,000 and 7.28 → 6.18 GB at n = 1,500 (E21). P3 has no measurable effect at n ≤ 500 (E13); it guards the $O(k^2)$ sweep at larger $k$.

## R5 — Moiety indices without rebuilt subgraphs (P5) and vectorised loops (P4)

**Decision**: P5 applies only when `~sanityChecks` and `AtomIndex` is unique; otherwise the existing path runs. P4 vectorises two per-element loops, with no change in result.

**Evidence**: the moiety transition graph takes 14 s → 2 s at n = 500, and identification 98/93 s → 84 s (E15). P4 shows no measurable effect at n = 500 (E13).

## R6 — Equality and effect of P1–P6 together

**Evidence**:
- **Outputs**: `isequaln` to `6bc522da0` on every `arm` and `reacting` field, `moietyFormulae`, validated `L`, and the bundle. Export files are byte-identical apart from `provenance.json`. This holds on random n = 100, 250, 500 and 1,000 and on bfs n = 500.
- **Negative controls**: four controls (MG node added, MG numeric node value, `L` entry, reacting-graph edge) were all detected (E10, E15, E21, E24; C2, C7).
- **A control that could not fail**: one early bfs control was a no-op and was replaced (E24). The extended tests therefore assert that each planted difference is detected.
- **COBRA tests**: 13 of 13 COBRA tests pass on every stage. A deliberately broken copy fails (E16, C4).
- **Memory and time**:
  - at random n = 1,000, the identification-window peak drops from 11.23 to 3.93 GB and time from 215 to 131 s;
  - at bfs n = 500, the peak drops from 3.90 to 2.41 GB (E24);
  - the project driver's whole post-build run at n = 500 drops from 5.42 to 3.23 GB (E17);
  - at n = 2,000, identification finishes at 8.65 GB RSS, where 6bc522da0 was killed at 32 GiB (E23).

**Limits**: equality is untested above 1,000 reactions and on full Rhea. The remaining growth (bond-subgraph edges about $n^{2.5}$, E22, E23) is out of scope.

## R7 — Coverage gap in the existing golden comparison

**Finding** (read from `testConservedReactingMoieties.m` and its `conservedReactingMoietiesReference.mat`): full mode is pinned only on the 3-reaction main fixture (`mainDefault`, `mainDefaultSanity`). The coaX and crnM bond-key fixtures are pinned only in conserved-only mode, and coaM, coaR and crn not at all.

**Decision**: capture full-mode golden cases with `sanityChecks` 0 and 1 for coaM, coaX, coaR, crn and crnM from the unchanged source. Store the inputs (model, BG, dATM) with them, as the existing golden cases do, so the test does not rebuild them. A fixture that errors in full mode is stored as an error case.
