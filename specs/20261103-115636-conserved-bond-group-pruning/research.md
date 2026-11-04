# Research: Find the conserved bond group without building every bond subgraph

Sources: the reconXmoieties exploration `specs/20261030-121933-reacting-moiety-memory/exploration.md` (branch `explore/reacting-moiety-memory`), evidence E22–E29 and E34, checks C8 and C12. N = 1 per measurement unless stated.

## R1 — What grows faster than the network

**Decision**: target the eager construction of every bond subgraph, and the unlabelled classification of all of them.

**Rationale** (E22, E23): each bond subgraph is the atom-transition subgraph of its component pair, plus one peeling layer of bonds. Every bond pattern touching the giant atom component therefore embeds a copy of the giant.

| Random n | Atoms in giant | Bond-subgraph edges | Share of edges in giant-sized components |
|---|---|---|---|
| 500 | 1,769 | 1.64 M | 58 % |
| 1,000 | 5,148 | 8.05 M | 63 % |
| 1,500 | 11,409 | 24.7 M | 67 % |
| 2,000 | 17,401 | 46.5 M | 68 % |

- **Memory**: at n = 2,000 with P1–P6, the bond stage holds about 105 B per bond-subgraph edge, so full size projects to 240–280 GB.
- **Time**: unlabelled classification takes 328 of 507 s at n = 2,000.

**Alternatives considered**:
- **Shrinking each subgraph further**: P2 already keeps only end nodes; the growth is in the number of edges, not their size.
- **Running reacting moieties on parts of the network**: a method change, so outputs would differ by design (exploration option D).

## R2 — What the bond stage feeds

**Decision**: compute only what the outputs read, which is:
- the complete per-bond component number;
- the conserved group;
- the conserved group's `BMG`.

**Rationale** (E26; `identifyConservedReactingMoieties.m` bond stage, `findAndExtractMolecularGraphs.m`):
- **`BIG.Edges.Component`** is filled from `bmgEdgeIndex{k}` for every component k. It reaches `ABG`, the edges of `arm.MG` and the reacting graph.
- **`BIG.Edges.IsomorphismClass`** is the `mets`-labelled class of `identifyIsomorphicClasses(BMG(conservedGroups))`, and 0 elsewhere.
- **`bondSubgraphs`** is read only by `findAndExtractMolecularGraphs`. That function takes the first class of maximal size, in leader order, and the caller then clears it.
- **Nothing else** reads `bondSubgraphs` or the `BMG` of reacting components.

## R3 — Why size-group pruning is exact

**Decision**: classify (node, edge) size groups in descending population, keep the best class (size, then smallest leader), and stop at the first group smaller than the best size.

**Rationale** (C8):
1. **Classes never cross size groups.** Isomorphic graphs have equal node and edge counts.
2. **Restriction preserves the classes.** Within a size group, `classifySubgraphIsomorphism` already compares each leader only with the later members of its own size group, in ascending order (P3). So classifying a size group alone gives the same classes, with the same leaders.
3. **The tie rule carries over.** `findAndExtractMolecularGraphs` uses `max` over classes ordered by leader, which picks the smallest leader among the largest classes. The pruned search compares (size, leader) explicitly, so the order in which groups are visited does not matter.
4. **Skipped groups cannot win.** A group with fewer members than the best size cannot hold a class that large. A group whose population equals the best size is still classified, because it can hold an equal class with a smaller leader.

**Evidence** (E27, E29): `isequal` of the pruned and the full conserved group at random n = 500, 1,000, 2,000 and bfs n = 2,000.

| Case | Size groups classified | Components classified | Edge share | Unlabelled classification |
|---|---|---|---|---|
| random n = 500 | 1 of 275 | 22,024 | 5.36 % | 3.7 → 0.3 s |
| random n = 1,000 | 1 of 493 | 35,872 | 1.78 % | 26.4 → 0.5 s |
| random n = 2,000 | 1 of 797 | 46,662 | 0.40 % | 345.5 → 0.6 s |
| bfs n = 2,000 | 1 of 600 | 13,150 | 0.15 % | 31.0 → 0.2 s |

Every classified component has 4 nodes.

**Margin**: the next-largest group holds 2,599 / 4,493 / 11,702 / 2,118 components against a conserved class of 22,016 / 35,852 / 46,645 / 13,148. So the stop rule fires at the second group by a factor of 4–8.

**Alternatives considered**: keeping the full sweep but making each comparison cheaper does not remove the edges that must be built (R1).

## R4 — Lazy building: where the sizes come from

**Decision**: `extractBondSubgraphs` gains `subgraphsToBuild` and a `subgraphSizes` output. It always peels every component pair and records each component's edge indices and sizes, but builds graph objects only for the requested components.

**Rationale** (E26; `extractBondSubgraphs.m` peeling loop):
- **Node count** of `bondSubgraphs{k}` is the number of atoms of its component pair (`numel(nodesInBothComponents)`).
- **Edge count** is the pair's atom-transition edges (`numel(atgRows)`) plus the bonds of its layer. `graph`, `digraph` and `addedge` keep parallel edges and self-loops, so nothing merges.
- **Peeling needs only index arithmetic.** A layer is the first remaining occurrence of each `BondIndex` within the pair, in ascending `BondIndex` order. So `bmgEdgeIndex` and the layer sizes come from the existing row bookkeeping, without building tables or graphs.

The test pins all three (US3 AS1).

**Alternatives considered**:
- **A separate plan/build pair of new functions**: two more public functions and test files, and a refactor of the peeling loop that today's references pin. The option keeps one function and its existing tests.
- **Storing every layer's rows for one later build**: holds the same information as `bmgEdgeIndex`, and the per-group build calls would still peel. Rejected for simplicity; R5 bounds the repeated peeling.
- **Classifying inside `findAndExtractMolecularGraphs`**: its inputs are the built subgraphs, so it cannot be lazy without changing its contract.

## R5 — Cost of repeated peeling

**Decision**: accept one extraction call per classified size group, plus one for the sizes and one for the conserved `BMG`. That is 3 calls on every case measured.

**Rationale**:
- **Extraction is cheap without building.** At n = 2,000 the whole label-only extraction, building every subgraph, took about 32 s (E28). The size-only call skips the dominant cost, constructing graphs.
- **Worst case.** A network with no dominant size group would classify many groups. Each call would then re-peel, at up to (groups classified + 2) times the cost of peeling once. That is no worse in memory than today, and slower in time only in that case.
- **The diagnostics** (FR-002) report the number of groups classified, so the check script shows it.

**Alternatives considered**: building a group-to-component index during the first call and handing it to later calls. Deferred unless the full-network probes (SC-005) show peeling time matters.

## R6 — What remains, and the full-size projection

**Finding** (E28; P1–P6 probes at random n = 1,000 → 2,000):

| Stage | Time |
|---|---|
| Atom components and their classification | 45 → 76 s |
| `mets`-labelled bond classification of the conserved group | 31 → 45 s |
| Moiety transition and moiety graphs | 7 → 18 s |
| Reacting stage | < 1.2 s at every size |

RSS at the start of identification grew from 2.67 to 3.14 GB over the same range.

**Projection**: if these stages stay about linear, full size needs roughly 7–12 GB and 15–30 min. That is an extrapolation from n ≤ 2,000, N = 1.

**Risks the full-network gate checks**:
- **Labelled classification**: the `mets`-labelled classification grows with members × classes inside one size group (P8 candidate).
- **Atom-component stage**: at the full giant size.
- **Reacting stage**: the MILP set cover at the full number of reacting bonds.

## R7 — Inputs and measurement

**Decision**:
- **Bond graphs**: every local input is built with the fixed builder (`20261102-151507`).
- **Memory metric**: the per-process VmHWM, reset through `/proc/<pid>/clear_refs` at the start of identification and read at its end, as in `reactingMoietyMemoryCheck.m`.

**Rationale**:
- **Memory carries over to fixed bond graphs** (E34, C12). Bond graphs from the fixed builder leave identification memory at P1–P6 levels, within −2 % to +7 % at n = 100–1,000. Their reacting graph is 13–21 % smaller.
- **Time didn't on a loaded machine.** Timing comparisons under load (average about 9) varied 1.4× between repeats, so the time criteria are reported, and measured back to back.
- **Why VmHWM**: it does not count page cache, unlike the scope's `memory.current` (E20).
- **Conserved reference at full size**: the conserved-only run of the 2026-10-23 network (1,299 conserved moieties in 1,535 s) used the old builder. Its `dATM`, and so its conserved outputs, are unchanged by the builder fix (feature `20261102-151507`, FR-006). The full-network check still reruns conserved-only on the same new checkpoint, so the comparison does not depend on that argument.
