# Implementation Plan: Post-Hoc dBTM Consolidation Pass for Cross-Instance Atom-Numbering Divergence

**Branch**: `20260908-hub-guard-keying-gap-fix` | **Date**: 2026-09-08 (revised after a real
`/speckit-implement` attempt) | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/20260908-102947-hub-guard-keying-gap-fix/spec.md`
(revised), building on `specs/020-canonicalize-symmetric-atom-bonds/` (merged, `develop`), this
directory's `PROPOSAL.md`/`prototype/` (original diagnosis and now-superseded prototype), and
`implementation-blocker-findings.md`/`research-revision.md` (the redesign this plan implements).

**Revision note**: This plan replaces this feature's original design ("replace the guard-blocked
fallback branch with a `(colourClassId, rank)` key, before `canonicalBondKey`/
`resolveAtomNodeIndex` run"), abandoned after a real implementation attempt found it mechanically
unimplementable (`implementation-blocker-findings.md` Findings 1 and 2) and, once diagnosed
further, narrower in scope than the actual problem (`5pmev[x]`'s full row-order divergence, not
just guard-blocked symmetric classes). Jack chose, from four options, a post-hoc `dBTM`
consolidation pass. This plan implements that choice.

## Summary

Two things are true simultaneously about the shipped feature 020 mechanism: (1) `dATM.Nodes` is
built once, globally, across every reaction in the model, so any real atom number observed in
*any* RXN file for a metabolite is a valid substitution target for *every* reaction of that
metabolite (confirmed by reading `buildAtomAndBondTransitionMultigraph.m:372` directly) — this is
why `resolveAtomNodeIndex.m` hard-errors on anything else, including a synthetic key; and (2)
`identifyAtomEquivalenceClasses` runs only once per metabolite, on the first-seen RXN-file
instance, and `safeCanonicalizeOneAtom` silently passes a later instance's raw atom number through
unchanged whenever it isn't a key the reference instance's rank map produced
(`buildAtomAndBondTransitionMultigraph.m:1003-1021`) — with no detection that the assumption
underneath this (cross-instance row-order stability, research R2/R6) has failed. `5pmev[x]`
concretely violates it: 13 of 24 rows differ in element between its two real instances, yet the
molecules are the same (confirmed graph-isomorphic).

The fix adds a new, separate pass that runs *after* `dBTM` is fully built by today's unmodified
code. For every metabolite with more than one RXN-file instance, it attempts to find and verify a
graph-isomorphism correspondence between each non-reference instance's own atoms and the cached
reference instance's atoms — reusing this codebase's own existing tools generalized from
within-graph to between-graph use: `identifyAtomEquivalenceClasses.m`'s WL-colour-refinement loop
(to match colour-class shapes structurally between the two instances) and its
`pairIsGraphAutomorphic`-style direct edge-set verification (to confirm a candidate correspondence
is actually valid before ever using it). Where verified, the pass recomputes the non-reference
instance's affected bonds as if built from the reference instance's own real atom numbers, and
merges the corresponding `dBTM` nodes by correcting `EdgeTable`'s bond-identity columns and
rebuilding `dBTM = digraph(...)` a second time — reusing the exact node-deduplication-by-name
mechanism already used to build `dBTM` the first time. `canonicalBondKey.m`,
`resolveAtomNodeIndex.m`, and the existing within-instance guard logic are never touched, and
`dBTM`'s initial (pre-consolidation) construction is byte-for-byte identical to today's — the new
pass either finds nothing to correct (the overwhelming majority of metabolites, and every existing
regression fixture whose instances already agree) or applies a verified correction, never a
partial or assumed one.

## Technical Context

**Language/Version**: MATLAB, local validation on R2024b+ (COBRA Toolbox baseline, matching
feature 020); headless `matlab -batch` in CI (Linux/Docker, Xvfb).

**Primary Dependencies**: `identifyAtomEquivalenceClasses.m` (feature 020, read and reused —
specifically its WL-colour-refinement loop, generalized to run on a non-reference instance's own
atoms/bonds, and its `pairIsGraphAutomorphic`-style verification pattern, generalized from
self-comparison to cross-instance comparison) and `buildAtomAndBondTransitionMultigraph.m` (the
new pass's call site, appended after the function's existing `dBTM` construction). `canonicalBondKey.m`
and `resolveAtomNodeIndex.m` are read but not modified — this feature's correction never calls
either with anything but real, already-resolved data, since it runs after both have already done
their job. MATLAB's built-in `graph`/`digraph` objects and `isisomorphic` (already used in this
codebase — `identifyAtomEquivalenceClasses.m`'s `pairIsGraphAutomorphic`, and
`identifyIsomorphicClasses.m`/`classifySubgraphIsomorphism.m` from feature 021 for a structurally
analogous subgraph-isomorphism problem) are reused, generalized from within-graph/within-family
comparison to between-two-specific-instances comparison — no new third-party dependency.

**Storage**: N/A — in-memory COBRA model structs, MATLAB `table`/`digraph` structures, and static
RXN-file fixtures under `test/verifiedTests/analysis/testReactingMoieties/data/`. `MEVK1x.rxn`/
`PMEVKx.rxn` (5-phosphomevalonate, `5pmev[x]`) are already vendored (from the original
implementation attempt's T006) and reused as the primary worked example — not present in this
repo's test fixtures before this feature.

**Testing**: A new dedicated test file is required (Constitution III-Naming — this is now genuinely
new, independently-nameable source, unlike the original design). Extend
`testConservedReactingMoieties.m` with the `5pmev[x]` fixture-backed assertion (23 nodes, no
mismatch) as before. Add a new `test<FunctionName>.m` for the new consolidation-pass function,
covering: a verified-correspondence case (`5pmev[x]` itself, or a smaller synthetic pair), a
no-correction-needed case (an existing stable fixture, confirming zero corrections recorded), an
unverifiable-correspondence case (a synthetic pair that is aggregate-consistent but not actually
graph-isomorphic — modeling `acgam1p[c]`'s shape — confirming no merge is applied), and a
bond-type-merge-resolution case (FR-011). Corpus-scale confirmation (spec.md US3, FR-006) reruns
the reconXmoieties sibling repository's existing `validate_symmetric_atom_classes_matlab.m`
harness, as before.

**Target Platform**: Headless MATLAB on Linux, matching feature 020's environment.

**Project Type**: MATLAB scientific library, single project.

**Performance Goals**: The new pass's cost is bounded per metabolite: one WL-colour-refinement
computation and one verification pass per non-reference instance (not a combinatorial search over
possible correspondences — colour-class-shape matching narrows the candidate bijection to a
deterministic, class-preserving choice before verification ever runs, per `research-revision.md`).
Reference-instance data (atoms, bonds, colour partition) is cached once per metabolite (extending
the existing `metAtomCanonicalRankMap`-style caching) and reused across every non-reference
instance's comparison for that metabolite, not recomputed per comparison. The pass runs once, after
`dBTM`'s initial construction — not per-bond, not per-reaction.

**Constraints**: `canonicalBondKey.m`'s and `resolveAtomNodeIndex.m`'s signatures and behavior are
unchanged (not even read differently); `dBTM`'s pre-consolidation construction (today's existing
code path, through its `mapAontoBOld`-based `.Nodes.Bond`/`.BondIndex`/etc. derivation) is
byte-for-byte unchanged; the new pass MUST NOT apply any correction it has not directly verified by
edge-set comparison (spec.md FR-004) — a plausible-looking but unverified correspondence is treated
as no correspondence; MUST NOT alter `dBTM.Edges.HeadMet`/`.TailMet` reaction-direction semantics;
MUST resolve the `metBondTypeFirstSeen` (feature 020 FR-003) interaction explicitly for merged
nodes (spec.md FR-011), not leave it to incidental last-write-wins behavior; no chemPy/RDT
RXN-generation toolchain change; no file created under `experiments/` in this repository; tests
MUST NOT fetch fixtures over the network at run time.

**Scale/Scope**: One new source file (the consolidation-pass function) and one new test file — a
genuine increase from this feature's original, now-superseded "no new file" design, justified in
Complexity Tracking below. `buildAtomAndBondTransitionMultigraph.m` gains one new call (to the new
function) appended after its existing `dBTM` construction — its own internals are otherwise
unchanged. `identifyAtomEquivalenceClasses.m`, `canonicalBondKey.m`, `resolveAtomNodeIndex.m` are
read but not modified.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Scientific code quality**: The new pass operates strictly on bond-graph node identity — merging
  nodes a verified graph isomorphism confirms represent the same physical bond — never on
  `model.S`/`.mets`/`.rxns` or any solver-facing structure. The new mathematical object (a
  cross-instance atom correspondence, verified by direct edge-set comparison) is a natural
  generalization of an object this domain folder already uses correctly
  (`identifyAtomEquivalenceClasses.m`'s within-instance automorphism check,
  `identifyIsomorphicClasses.m`'s subgraph-isomorphism classification) — not a new category of
  computation for this codebase.
- **Testing and reproducibility**: Narrowest proof is the new dedicated test file (verified-merge,
  no-correction, unverifiable-correspondence, and bond-type-merge cases) plus
  `testConservedReactingMoieties.m`'s new `5pmev[x]` assertion. Broader confirmation is the
  corpus-scale rerun of `validate_symmetric_atom_classes_matlab.m` (spec.md US3/FR-006/SC-002-004).
  New RXN fixtures (`MEVK1x.rxn`/`PMEVKx.rxn`, already vendored) are committed, not fetched at test
  time.
- **User experience and diagnostics**: No new user-facing parameter. No new warning path is
  introduced for the *fixed* case; a metabolite the pass cannot verify a correspondence for is left
  exactly as today (still subject to feature 020's existing FR-011 warn-and-fallback if it was
  already triggering that, unaffected by this feature).
- **Performance and numerical integrity**: No solver call added or changed. New caching (reference
  instance's atoms/bonds/colour-partition, per metabolite) follows the existing
  `metBondCountGroundTruth`/`metAtomCanonicalRankMap` pattern. The pass runs once, after `dBTM`
  exists, bounded per metabolite as described above; no debug/diagnostic/verification step is made
  skippable, and the verification step (FR-002/FR-004) is never bypassed for performance.
- **External-solver configuration audit**: N/A — no external solver/library invoked.
- **Spec-driven scope control**: Edits: one new source file (consolidation-pass function) in
  `src/analysis/topology/reactingMoieties/`; one new call site appended to
  `buildAtomAndBondTransitionMultigraph.m` (after its existing `dBTM` construction — no other edit
  to that file); `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m`
  (new `5pmev[x]` assertion); one new test file for the new function; the already-vendored
  `MEVK1x.rxn`/`PMEVKx.rxn` fixtures. `canonicalBondKey.m`, `resolveAtomNodeIndex.m`, and
  `identifyAtomEquivalenceClasses.m`'s existing guard logic are read but not edited. Diagnosis 2 is
  explicitly out-of-scope source-wise: no reconciliation logic for genuinely non-isomorphic
  instances is added anywhere (spec.md FR-008). No `experiments/`, `external/`, `deprecated/`, or
  `binary/` path touched. No migration, no new dependency.
- **MATLAB coding standards**: Implementation must avoid `evalc`, warning suppression, and
  `nargin`-driven optional-argument handling; the new function follows the openCOBRA header
  convention and this domain folder's established idioms (`containers.Map` caching,
  `warning(...)`-gated diagnostics, the `graph`/`isisomorphic` usage pattern already established
  by `identifyAtomEquivalenceClasses.m` and `identifyIsomorphicClasses.m`).
- **Parameter-setting fidelity**: N/A.
- **Artifact placement**: Spec Kit artifacts under
  `specs/20260908-102947-hub-guard-keying-gap-fix/` (this directory — holds `PROPOSAL.md`,
  `prototype/`, `implementation-blocker-findings.md`, `research-revision.md`, and this revised
  `spec.md`/`plan.md`/`tasks.md`). Source changes remain under
  `src/analysis/topology/reactingMoieties/`; test/fixture changes remain under
  `test/verifiedTests/analysis/testReactingMoieties/`. No file created under `experiments/` in
  this repository.

**Result**: PASS (initial, revised), pending the local session's own re-check per this
repository's Spec Kit process.

## Design: post-hoc dBTM consolidation pass

Full design and rationale in `research-revision.md` (this directory) — summarized here for the
plan's own completeness.

### New per-metabolite reference cache (extends the existing first-seen pattern)

Alongside the existing `metAtomCanonicalRankMap`/`metUnsafeNeighborsMap` (unchanged, still used
for their original within-instance purpose), retain, per metabolite, the reference instance's own
`atomNumbers`/`elements`/`headAtoms`/`tailAtoms`/`bTypes` (already read by the existing first-seen
code path, just not currently kept past the `identifyAtomEquivalenceClasses` call) and its
WL-colour-refinement partition (an intermediate value `identifyAtomEquivalenceClasses` already
computes internally — expose it as an additional output rather than recomputing).

### The new function (called once, after `dBTM` exists)

For every metabolite with more than one distinct RXN-file instance contributing to `dBTM`, and for
every non-reference instance of that metabolite:

1. Compute the non-reference instance's own WL-colour partition (same computation as the reference
   instance's, run on this instance's own atoms/bonds).
2. Match colour classes between the two instances by structural signature (the same recursively-
   built, round-compact descriptive-label technique already implemented, OOM-safely, in the
   existing refinement loop — isomorphic graphs converge to the same sorted set of unique class
   signatures at each round). A signature-shape mismatch means the instances are not isomorphic —
   Diagnosis 2 — skip this instance, apply no correction.
3. Pair members within each matched class (sorted-by-raw-atom-number on each side) to build one
   candidate bijection: non-reference atom number -> reference atom number.
4. Verify the candidate directly: relabel the non-reference instance's bonds under the candidate
   mapping and confirm the resulting edge set (endpoints + bond type) matches the reference
   instance's own edge set exactly (the same verification *style* as `pairIsGraphAutomorphic`,
   generalized from self-permutation to cross-instance mapping). If verification fails, apply no
   correction for this instance — never a partial or best-effort merge.
5. Where verified, recompute this instance's bonds' canonical ID strings using the correspondence
   (call `canonicalBondKey` again with each atom substituted for its reference-instance
   counterpart) and record every (current dBTM bond-node name -> corrected name) pair that differs.

After every metabolite is processed: apply the accumulated correction map as a find-and-replace
over `dBTM`'s `EdgeTable`'s bond-identity columns (`EndNodes`, `HeadBond`, `TailBond`), resolve the
`metBondTypeFirstSeen` interaction for any node this collapses two or more prior nodes onto
(spec.md FR-011 — by original reaction-processing order, not last-write-wins), then rebuild
`dBTM = digraph(correctedEdgeTable)` exactly the way it was built the first time, reusing the
existing `mapAontoBOld`-based derivation of `.Nodes.Bond`/`.BondIndex`/`.BondType`/etc. a second
time.

### Why this resolves both original findings without contradiction

Finding 2 (the `resolveAtomNodeIndex` hard-error) cannot occur, by construction: the pass runs
after `dBTM` already exists — no node-index lookup is ever performed against a value this pass
produces. Finding 1 (the `crn[m]` hardcoded-string contradiction) resolves because the reference
instance is never corrected, and research R2 already confirmed `crn[m]`'s row order genuinely is
stable across its two real instances (unlike `5pmev[x]`) — so the pass finds nothing to correct for
that bond, and the existing literal-string test assertion survives untouched.

## Project Structure

### Documentation (this feature)

```
specs/20260908-102947-hub-guard-keying-gap-fix/
├── PROPOSAL.md                        # original diagnosis + now-superseded prototype rationale
├── prototype/                         # original Python reference implementations (superseded
│                                       #   design, kept for the record — see research-revision.md)
├── implementation-blocker-findings.md # Findings 1 and 2 from the halted implementation attempt
├── research-revision.md               # the redesign this plan implements (read first)
├── spec.md                            # this feature's spec, revised for the consolidation pass
├── plan.md                            # this file
└── tasks.md                           # actionable task breakdown, revised for the new mechanism
```

### Source Code (repository root)

```
src/analysis/topology/reactingMoieties/
├── identifyAtomEquivalenceClasses.m         # UNCHANGED (read; WL-colour-refinement step reused)
├── buildAtomAndBondTransitionMultigraph.m   # MODIFIED: one new call after dBTM's existing
│                                             #   construction; no other change
├── canonicalBondKey.m                       # UNCHANGED (read only)
├── resolveAtomNodeIndex.m                   # UNCHANGED (read only)
└── <newConsolidationFunctionName>.m         # NEW — name decided at /speckit-tasks, following
                                              #   this folder's convention (parallel to
                                              #   identifyAtomEquivalenceClasses.m /
                                              #   identifyIsomorphicClasses.m naming style)

test/verifiedTests/analysis/testReactingMoieties/
├── testConservedReactingMoieties.m          # MODIFIED: add 5pmev[x] fixture-backed assertion
├── test<NewConsolidationFunctionName>.m     # NEW — Constitution III-Naming
└── data/
    └── rxnFiles/
        ├── MEVK1x.rxn                       # already vendored (original attempt's T006)
        └── PMEVKx.rxn                       # already vendored (original attempt's T006)
```

## Complexity Tracking

*(Now genuinely needed — the original plan's "no new file" claim no longer holds.)*

**New source file, justified**: The original design avoided a new file because it planned to
modify existing key-construction logic in place. That design is mechanically unimplementable
(Findings 1/2). The chosen alternative — a post-hoc consolidation pass — is a distinct operation
(cross-instance graph matching + node merging) from anything `identifyAtomEquivalenceClasses.m`
or `buildAtomAndBondTransitionMultigraph.m` currently does, and giving it its own file/test file
follows this domain folder's own established convention for a new, independently-nameable
capability (`identifyAtomEquivalenceClasses.m` itself, feature 020; `identifyIsomorphicClasses.m`,
pre-existing) rather than growing `buildAtomAndBondTransitionMultigraph.m`'s already-1000+-line
body in place. This is the same reasoning research R9 (feature 020) already established for its
own new-function decision, applied to a second, later new capability in the same domain.

**Broader-than-originally-scoped fix, justified**: The redesign fixes a strictly larger set of
cases (any verifiably-graph-isomorphic instance pair, not only guard-blocked symmetric classes)
than the original design targeted, discovered only because `5pmev[x]` — chosen as this feature's
own worked example — turned out to violate an assumption (row-order stability) the original
research never tested directly. Narrowing the fix back to "guard-blocked only" was considered
(one of the four options presented) and rejected: it was already shown, in the original
prototype's v1, to resolve 0/93 real failures, for the same underlying reason (a guard-blocked
class's own hub atom can be just as numbering-unstable as the class itself). The broader,
correctly-scoped fix is not optional padding — it is the smallest change that is actually correct.
