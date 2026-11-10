# Research: Reacting-bond incidence from bond changes, as in the paper

Sources:
- Rahou et al., *J. Theor. Biol.* 621 (2026) 112348: §4.1, §6.1–6.3, Fig. 11.
- reconXmoieties exploration `specs/20261030-121933-reacting-moiety-memory/exploration.md` (on `main`): E31, E36, E37, C10, C14.
- A read-only design check run on 2026-11-06 for this plan: `crb2rDesignCheck.m`, kept in the planning session's scratch folder, not in the repository. It ran COBRA `ad0d11d60` with Gurobi, on the paper's example network, on both the shipped and the consistent-arm RXN fixtures. N = 1.

## R1 — Where the per-reaction bond changes are

**Decision**: read them from the bond transition multigraph `dBTM`, which is the builder's eighth output.

**Rationale**:
- `addBondMappingsRXNFile` labels every bonding interaction of each reaction as broken (−1), formed (+1) or conserved (0). It does this from the difference of the product and substrate weighted adjacency matrices of that reaction's RXN file, so a double bond counts as two interactions.
- Each broken interaction is paired with a per-reaction energy pseudo-bond, whose `mets` is the reaction identifier, and each formed interaction is paired the other way round.
- In `dBTM` a broken bond is therefore an edge whose `TailMet` is a reaction identifier; the changed bond is `HeadBondIndex`. A formed bond is an edge whose `HeadMet` is a reaction identifier; the changed bond is `TailBondIndex`. The reaction is `Edges.rxns`.
- `identifyConservedReactingSubgraphs` already reads broken and formed bonds this way. Its tables have 7 rows each on the shipped fixture (asserted in `testConservedReactingMoieties.m`).
- **Design check**: on the consistent-arm fixture, `dBTM` gives 6 broken and 6 formed interactions. Mapped to condensed edges (R3), they give **exactly the paper's Fig. 11 bond sets**: `ACONTm` {1, 2, 5, 6}, `r0317` {1, 3, 4, 6}, `r0426` {2, 3, 4, 5}. These are identical to today's `CRB2R` on that fixture.

**Alternatives considered**:
- **Recompute the changes inside the function from `BG` and `dATM`**: map each substrate bond through the reaction's atom transitions and test whether the image is a product bond. Rejected: `dATM` edges carry no molecule-instance number. For a metabolite with stoichiometric coefficient > 1, its atoms' transitions can't be paired molecule by molecule, so the image of a bond is ambiguous.
- **Re-read the RXN files inside the function**: duplicates the builder and its renumbering (feature `20261102-151507`). Rejected.

## R2 — Bond identifiers agree across `dBTM`, `BG` and the reacting-bond graph

**Decision**: use `BondIndex` as the shared key, with no remapping.

**Rationale**:
- `BG` is built from `dBTM.Nodes` (`buildAtomAndBondTransitionMultigraph.m` L849), so `BG.Edges.BondIndex` is `dBTM.Nodes.BondIndex`.
- The atom-bond graph `ABG`, the reacting-bond graph `RBG` and `Condensed_RBG` carry the same `BondIndex`. STEP 2 of `identifyConservedReactingMoieties` already looks `Condensed_RBG.Edges.BondIndex` up in `BG.Edges.BondIndex`.
- A double bond is one `BondIndex` with two parallel edges in `BIG`/`ABG`. When its order changes, one interaction is broken or formed, so its `BondIndex` appears once among the changes. That is the §4.1 convention.
- **Design check**: every changed bond on both fixtures was found in `BG` (0 missing).

## R3 — Merged condensed edges: union over all their bonds

**Decision** (maintainer, FR-003): a condensed edge's row is the union of the reactions that change any reacting bond merged into it.

**Implementation note**: STEP 1 de-duplicates condensed edges with `unique(E_sorted, 'rows', 'stable')` and discards the third output. Keep it: it maps every `RBG` edge to its condensed edge. A changed bond's row is then found through its `RBG` edges. A bond with two parallel edges maps to one row, because both have the same end components.

**Design check, shipped fixture** (6 vertices, 7 condensed edges):

| Reaction | Today (`endAtom`) | Paper rule with union |
|---|---|---|
| `ACONTm` | {1, 2, 4, 6, 7} | {1, 2, 4, 6} |
| `r0317` | {1, 3, 5, 6, 7} | {1, 3, 5, 7} |
| `r0426` | {2, 3, 4, 5} | {2, 3, 4, 5, 6, 7} |

Both rules differ here:
- **Today's rule over-marks**: `ACONTm` on edge 7 and `r0317` on edge 6, neither of which they change.
- **Union adds entries**: `r0426` changes bonds merged into edges 6 and 7, but those aren't the first bond that today's rule keeps.

**Consequence for the spec**: its Background said the two rules agree on the paper's example. That holds for the consistent-arm copy only. On the shipped files the current tests assert only the graph's size (6 vertices, 7 bonds), not each reaction's bonds, so they don't see the difference. This gives a second red-before-green assertion without a new fixture (plan, Design 4).

## R4 — How the function receives the bond changes

**Decision**: a fifth, trailing, optional input `dBTM`:

```matlab
identifyConservedReactingMoieties(model, BG, dATM, options, dBTM)
```

**Rationale**:
- It is the builder's own output. `identifyConservedReactingSubgraphs(model, dATM, dBTM)` already takes it the same way.
- It keeps `options` a struct of scalars and flags.
- A trailing input leaves every existing argument position unchanged (Principle II).

**Alternatives considered**:
- **`options.dBTM`**: a multigraph inside an options struct is unusual in this toolbox. Golden cases also store `options`, which would grow with it.
- **A precomputed bond-to-reaction matrix as the input**: smaller, but every caller would have to build it. That moves the method's definition out of the function. Rejected, though the function builds exactly this matrix internally.

## R5 — The default changes, and Principle II

**Decision**: `options.reactingBondIncidence` takes `'bondChange'` (default) or `'endAtom'`. A full-mode call with `'bondChange'` and no `dBTM` raises `identifyConservedReactingMoieties:missingBondTransitions`. The message names both ways to proceed: pass `dBTM`, or set `'endAtom'`.

**Rationale**:
- Principle II says new optional arguments must default to the historical behaviour, unless a spec approves a breaking change and documents a migration path.
- The maintainer chose the paper's rule as default and the old rule as the option (spec Clarifications). The spec records this as an approved breaking change under **Compatibility**.
- The migration is one argument (`dBTM`), or one option for exact old behaviour.
- The error is loud and immediate, with no silent fallback (VII-C). A caller can't get end-atom results believing they are the paper's.
- Conserved-only calls (`conservedMoietiesOnly = true`) never reach the reacting stage, so they keep working without `dBTM`.

**Callers in this repository** that run full mode and must pass `dBTM`:
- `testConservedReactingMoieties.m` L239, L273, L535 and the golden helper (L611, L625);
- `test/tutorialDerived/analysis/reactingMoieties/tutorial_conservedAndReactingMoieties.m` L155.

The tutorial source (`tutorials/`, a separate repository) is not checked out here; it is listed as a follow-up in the PR.

**Downstream**: the reconXmoieties driver `runAtomMappedMoietyPipeline` calls full mode without `dBTM`. It will error until it is updated, which is reconXmoieties' work (spec, Assumptions).

## R6 — A fixture with a reaction that moves bonds without changing them

**Decision**:
- **Reaction**: add `CITICITtm` (cit[c] + icit[m] → cit[m] + icit[c], a VMH citrate/isocitrate antiporter) to the paper's example model with `addReaction`.
- **RXN file**: hand-written in a new folder `data/rxnFilesTransport/`, which holds copies of the three consistent-arm files plus `CITICITtm.rxn`.
- **Molblocks**: `cit[m]` and `icit[m]` are copied from the consistent-arm files. The `[c]` copies are identical apart from the compartment.
- **Atom map**: the identity, atom k to atom k.

**Rationale**:
- Every reacting bond of the example has an end atom on citrate or isocitrate. So today's rule marks the transport against every condensed reacting bond, while the paper's rule marks it against none: no bond is broken or formed, and the builder adds no energy edges for it.
- **Why not the corpus file**: the reconXmoieties VMH corpus has `CITICITtm.rxn` (ReactionDecoder rdt-2.5.0), but its atom map is not checked. If it paired citrate's symmetric arms differently from the fixture, it would join atom-transition components and change the condensed graph (KI-001), mixing two effects in one test. The identity map rules that out.
- **Effect on Fig. 11**: the transport joins each `[c]` atom's component to its `[m]` atom's. That changes component numbers but not which reacting bonds share a component pair, so the condensed graph stays Fig. 11's 4 vertices and 6 bonds. The test asserts this first.

**Alternatives considered**:
- **A copy of `r0317` with an extra spectator metabolite**: also distinguishes the rules, but is less natural than a transport, which is the most common case at genome scale.

## R7 — Golden references

**Decision**:
- The capture script rebuilds each golden case's `dBTM` from the fixture RXN folder (`data/rxnFiles`), from which the cases' `BG` and `dATM` were built. It asserts that the rebuilt `BG` and `dATM` are `isequaln` to the stored ones before using the rebuilt `dBTM`.
- It stores `goldenCase.dBTM`.
- Today's files are kept as `conservedReactingMoietiesReferenceEndAtom.mat` and `reactingMoietyMemoryReferenceEndAtom.mat` for the `'endAtom'` test (FR-006).
- The script writes a per-field difference report.

**Rationale**: the case inputs are already reproducible from the fixture (feature `20261102-151507`, `captureRenumberedGoldens.m`). Storing `dBTM` keeps the test from re-running the builder per case.

**Risk**: the reference files grow, from 0.67 and 1.48 MB today. If the two files together exceed 10 MB, the test rebuilds `dBTM` per case instead, and the capture script records which path was taken.

## R8 — The full-network check

**Decision**:
- The non-CI script rebuilds the multigraph from the collapsed VMH model and RXN files, keeping `dBTM`.
- It runs identification twice, `'endAtom'` and `'bondChange'`, and compares:
  - `'endAtom'` with the 2026-11-05 run `vmhcollapsed_20261105_142523`, as an equality control: its reacting outputs should be identical;
  - `'bondChange'` with `'endAtom'`, for the US3 report.
- Each MATLAB run is in its own memory-capped scope (24 GiB, as for that run).

**Rationale**: that run's build checkpoint saved `dATM` and `BG` but not `dBTM`, so it can't be resumed for this rule. The rebuild takes about 1 h 41 min.

**Risk**: `dBTM` must be kept in memory alongside `BG` through identification. Its size at full scale has not been measured (estimated at a few GB). The script logs peak RSS. If the run exceeds the cap, the fallback is to pass only the bond-change list, as the alternative in R4.

## R9 — Bond changes that land on no condensed edge

**Decision**:
- Count them in `reacting.offGraphBondChanges` and emit one summary warning when the count is not zero (VII-B).
- They don't enter `CRB2R`.

**Rationale**: which bonds count as reacting is decided by the bond-isomorphism label, not by the changes (spec, Assumptions). So a changed bond could, in principle, lack that label, or join two atoms of one atom-transition component. The design check found 0 such changes on both fixtures. At genome scale the count is the check that the two definitions agree, so it is reported, not hidden.
