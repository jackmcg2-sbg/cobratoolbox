# Research: Whole-molecule bond renumbering

The primary record is the reconXmoieties exploration `specs/20261030-121933-reacting-moiety-memory/exploration.md` (branch `explore/reacting-moiety-memory`, commits up to `efb3a4f`). Its scripts are in `exploration/`. Every number is N = 1.

## R1 — The defect and its extent (E33, C11)

**Method**: `export_bg_bonds.m` writes every bond of `BG`. `bg_vs_molfiles.py` compares each metabolite's bonds (atom pairs and orders) with its molblock in every RXN file that holds it.

**Results**:
- **Collapsed VMH** (`BG` of the full build with `6bc522da0`; 9,634 RXN files): 3,533 of 9,489 metabolites corrupted, 14,804 of 561,955 bonds misplaced.
  - By element pair: C–H 14,194, C–C 460, O–P 80, H–N 34, S–S 11, others 22.
  - 374 metabolites have a self-loop.
  - No VMH metabolite has more than one molblock variant.
- **Fixtures**:

  | Fixture | Corrupted |
  |---|---|
  | main | 1 of 4 |
  | coaM | 8 of 10 |
  | coaX | 9 of 18 |
  | coaR | 3 of 9 |
  | crn | 10 of 10 |
  | crnM | 7 of 7 |

  Bond counts are unchanged in every case.

**Controls**:
- The authors' code (`ab6c4840f`) on `main`: 0 corrupted.
- This builder with `safeCanonicalizeOneAtom` disabled: 0 misplaced bonds on every fixture. Only `coa[*]` and `crn[m]` keep duplicated bonds (86/82, 29/25), from their two differently numbered molblocks. That duplication is feature 020's original problem.

**Decision**: replace the per-atom substitution, rather than drop it. The duplication it was meant to remove is real.

## R2 — Why per-atom substitution cannot be correct

**Mechanism**: replacing atom $a$ of bond $\{a, b\}$ by an equivalent $a'$ is a graph automorphism only if $b$ is replaced by its image under the same automorphism. Replacing ends independently, or replacing one end only (the "unsafe neighbour" guard), moves the bond. Example: citrate's C13–H14 becomes C7–H14.

**Decision**: map each copy with a single isomorphism onto one reference. An isomorphism maps the bond set onto the bond set, so the bond graph equals the reference molblock by construction.

## R3 — Identity when the copy equals the reference

Copies that equal their reference are by far the most common case: every VMH metabolite, and citrate in the fixture. For them the renumbering must be the identity, not an arbitrary automorphism. A non-trivial automorphism would leave the bond graph correct, but it would re-attach bond-transition atoms to other equivalent atoms than the RXN file says, for no reason.

**Decision**: compare the copy with the reference first (sorted bond list and element list), and search for an isomorphism only when they differ.

## R4 — Resonance and bond order

Feature 020 recorded carnitine's carboxylate C=O on atom 3 in one file and atom 6 in the other.

**Decision**: the isomorphism matches on element and connectivity only (bond order ignored), so such copies still match. Orders come from the reference (first-seen), which is feature 020's FR-003 rule.

## R5 — The paper's example (E30–E32, C9, C10)

- **Conserved moieties**: equal the paper on the shipped files: $L$ = [1 1 1 0; 0 1 1 1], 6 instances, 6 transitions.
- **Condensed reacting-bond graph**, as (vertices, bonds):

  | Code | Shipped RXN files | Consistent-arm copy |
  |---|---|---|
  | Fork (corrupted citrate) | 7, 10 | 7, 10 |
  | Authors' code | 6, 7 | 4, 6 = Fig. 11 |
  | Paper's §4.1 rule from the RXN files | 6, 7 | 4, 6 |

- **The consistent-arm copy** changes only the atom-map numbers of the `r0317` and `r0426` product blocks, so that both dehydrations use citrate's C7 arm and H8, as `ACONTm` does (`remap_consistent.py`).

**Decision**: US3 asserts:
- the paper's conserved values on the shipped files;
- 6 vertices and 7 bonds on the shipped files;
- Fig. 11 on the consistent-arm copy.

## R6 — Golden references and their stored inputs

- **Recaptured.** `conservedReactingMoietiesReference.mat` (6 cases, 2026-09-29) and `reactingMoietyMemoryReference.mat` (10 cases, 2026-11-02) store `BG` and `dATM` built by the old builder, alongside the outputs.
- **Not recaptured.** `bondSubgraphReference.mat`, `bondSubgraphPeelingReference.mat` and the two classification references pin pure functions on stored inputs. Their correctness on those inputs does not depend on the inputs being chemically right.
- **Unaffected references.** `testBuildAtomAndBondTransitionMultigraph` asserts residuals, warnings and sparse/dense identity, not bond identities.
- **Unaffected assertions.** The feature 019/020 assertions in `testConservedReactingMoieties` check counts and first-seen bond types, which the fix keeps.

## R7 — Cost

- **Collapsed VMH**: there is no isomorphism search (R3). The extra cost is one sorted-list comparison per copy, against today's colour refinement per metabolite in `identifyAtomEquivalenceClasses`, so the builder should not get slower. SC-006 reports it.
- **Fixtures**: CoA and carnitine variants need one `isomorphism` call per variant copy, on graphs of at most about 90 atoms.
