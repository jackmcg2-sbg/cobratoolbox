# Research Revision: Post-Hoc dBTM Consolidation Pass

**Supersedes**: this feature's original `plan.md` "Design: key construction" section (the
"replace the fallback branch with a `(colourClassId, rank)` key" approach) — abandoned, per
`implementation-blocker-findings.md` Findings 1 and 2, as mechanically unimplementable.

**Written after**: a real `/speckit-implement` attempt halted twice on grounded, MATLAB-verified
contradictions (see `implementation-blocker-findings.md`), and after Jack chose, from four
options, to pursue a post-hoc `dBTM` consolidation pass rather than an upstream key-construction
change, a narrow detect-and-warn patch, or a full pause.

## What deepened beyond the two original findings

Tracing the actual current source (not assumed from `research.md`'s original, pre-implementation
reading) confirms both findings are real, and locates a root cause underneath both of them:

1. **`dATM.Nodes` is global, not per-instance.** Built once, before the per-reaction loop, from
   the edge table spanning *every* reaction in the model
   (`buildAtomAndBondTransitionMultigraph.m:372`, `dATM = digraph(EdgeTable)`, deduplicated by
   the `met#atomNumber#element` node-name string). So any raw `(met, atomNumber, element)` triple
   observed in *any* RXN file for a metabolite is a resolvable target for *every* reaction of that
   metabolite — this is *why* today's "safe substitution" branch works at all, and it's also why
   Finding 2's synthetic-key idea specifically cannot: a synthetic value was never observed in any
   file, so it can never be a `dATM.Nodes` row, regardless of how the node-identity index is
   organized.

2. **Equivalence classes are computed once, from the first-seen instance only, and applied
   unchecked to every later instance.** `buildAtomAndBondTransitionMultigraph.m:637-644`: the
   `if ~isKey(metAtomCanonicalRankMap, bMet)` guard means `identifyAtomEquivalenceClasses` runs
   exactly once per metabolite, on whichever reaction's RXN file is encountered first in
   `model.rxns` iteration order. `safeCanonicalizeOneAtom` (`:1003-1021`) then applies *that one
   file's* rank map to every subsequent instance's raw atom numbers via a **silent, unguarded
   pass-through**: `if ~isKey(rankMap, atomRaw) return; end` — no warning, no error, just leaves
   the raw number alone if it isn't a key the reference file happened to produce. This silently
   assumes what feature 019/020's own research (R2, R6) established only for the metabolites it
   actually checked: that atom row order is stable, element-for-element, across every instance of
   a metabolite. **That assumption does not hold universally** — confirmed directly against
   `5pmev[x]`'s two real fixtures (now vendored): 13 of 24 rows differ in element between
   `MEVK1x.rxn` and `PMEVKx.rxn` (phosphorus is row 4 in one, row 6 in the other; row 2 is O in
   one file, H in the other; etc.) — this is not "guard-blocked symmetric atoms," it is full
   local row-order divergence, a case feature 019's own spec explicitly flagged and left
   unaddressed ("a metabolite's atom numbering itself found to be unstable across
   independently-generated RXN files... a more severe condition... would invalidate
   atom-number-based canonicalization for that metabolite").

3. **Nothing in the shipped pipeline detects case 2.** `identifyAtomEquivalenceClasses`'s FR-011
   fallback only fires on *within-file* detection failure (a malformed molblock, a non-terminating
   computation) on the *reference* file. It has no way to notice that a *later* file disagrees with
   the reference, because it never runs on later files at all, and `safeCanonicalizeOneAtom`'s
   silent pass-through swallows the mismatch instead of surfacing it.

`5pmev[x]`'s pre-fix union count (43-46 vs. a true 23 — close to double) is explained by this: not
only the 11 guard-blocked bonds fail to match across files, but effectively none of the 23 do,
because the reference file's rank map barely applies to the second file's numbering at all.

## Why the chosen direction (post-hoc consolidation) is the right fit

The original approach tried to fix this by changing what atom number gets fed into
`canonicalBondKey`/`resolveAtomNodeIndex` *before* `dBTM` exists — which forces every correction
to be both a real, already-known atom number *and* computed correctly on the first pass, with no
room to recover from a bad guess. A post-hoc pass sidesteps this: `dBTM` gets built exactly as it
is today (both `canonicalBondKey.m` and `resolveAtomNodeIndex.m` untouched, zero regression risk
there), and the correction runs *afterward*, when every relevant node is already real and already
resolved — merging two existing nodes is an ordinary graph operation with no lookup-against-a-set
constraint to satisfy at all.

## Design

### New per-metabolite reference data (extends the existing first-seen cache)

Alongside the existing `metAtomCanonicalRankMap`/`metUnsafeNeighborsMap` (still computed and used
exactly as today, for their original within-instance purpose), cache the reference instance's own
atoms/bonds and WL-colour partition, keyed by metabolite:

- `metReferenceAtoms(bMet)`: the first-seen instance's `atomNumbers`/`elements` (already read by
  the existing code at that point, just not currently retained past the `identifyAtomEquivalenceClasses`
  call).
- `metReferenceBonds(bMet)`: the first-seen instance's `headAtoms`/`tailAtoms`/`bTypes`.
- `metReferenceColours(bMet)`: the first-seen instance's per-atom WL-colour-refinement partition
  (the same intermediate value `identifyAtomEquivalenceClasses` already computes internally to
  build `equivalenceClasses` — expose it as an additional output rather than recomputing).

### New pass: `consolidateCrossInstanceBondNodes` (new function, new test file)

Runs once, after `dBTM`'s initial construction (i.e., after the existing
`buildAtomAndBondTransitionMultigraph.m` code that derives `dBTM.Nodes.Bond`/`.BondIndex`/etc. via
`mapAontoBOld`, exactly as it does today), before the function returns. For every metabolite with
more than one distinct RXN-file instance contributing to `dBTM`:

1. **Build the target instance's own WL-colour partition** the same way the reference instance's
   was built (reuse `identifyAtomEquivalenceClasses`'s refinement step, run on this instance's own
   atoms/bonds — not cached, since every non-reference instance needs its own).
2. **Match colour classes structurally between target and reference**, using the same
   recursively-built, round-compact descriptive-signature trick already implemented (and OOM-safe)
   in the existing colour-refinement loop: two isomorphic graphs converge to the *same* sorted set
   of unique class signatures at each round, so classes can be paired by signature rather than by
   position. If the multiset of class signatures (sizes and structural labels) does not match
   between the two instances, they are **not isomorphic — this is Diagnosis 2** (cross-instance
   structural inconsistency, e.g. `acgam1p[c]`'s mono- vs. di-anionic phosphate). Skip this
   instance: leave its bonds exactly as today's baseline produces them. This feature does not
   attempt Diagnosis 2 (unchanged from the original spec's FR-008 scope decision).
3. **Pair members within each matched class** (sorted-by-raw-atom-number on each side, k-th to
   k-th) to build one full candidate bijection: target atom number -> reference atom number.
4. **Verify the candidate bijection directly**: relabel the target instance's bonds under the
   candidate mapping and confirm the resulting edge set (endpoints + bond type) matches the
   reference instance's own edge set exactly. This reuses the same verification *style* already
   used by `pairIsGraphAutomorphic` (there: confirming a candidate self-permutation preserves one
   graph's edges; here: confirming a candidate cross-graph mapping equates two different graphs'
   edges) — a cheap, direct check, not a new search. If verification fails, treat this instance as
   unresolved for this metabolite (skip, matching FR-011's warn-and-fall-back spirit) rather than
   ever applying an unverified merge.
5. **Recompute this instance's bonds' canonical ID strings** using the verified correspondence
   (i.e., call `canonicalBondKey` again, this time with each atom substituted for its
   reference-instance counterpart) to get each bond's *corrected* dBTM node name.
6. **Record every (current dBTM bond-node name -> corrected name) pair** where they differ, across
   every metabolite/instance processed this way, in one `containers.Map`.

After all metabolites are processed: apply the correction map as a find-and-replace over
`dBTM`'s `EdgeTable`'s bond-identity columns (`EndNodes`, `HeadBond`, `TailBond`), then rebuild
`dBTM = digraph(correctedEdgeTable)` **exactly the same way it was built the first time** — MATLAB's
own node-name deduplication does the actual merging, reusing the existing
`mapAontoBOld`-based derivation of `.Nodes.Bond`/`.BondIndex`/`.BondType`/etc. a second time
rather than inventing new node-merge machinery.

**`BondType` first-seen-wins interaction (FR-003, feature 020)**: `metBondTypeFirstSeen` is keyed
by bond-ID string; after consolidation renames some strings, entries recorded under a
*non-reference* instance's now-corrected name need to be resolved against whichever bond type was
recorded **first, by original reaction-processing order**, among every node that now collapses
onto the corrected name — not silently dropped or arbitrarily overwritten. Implementation must
either re-derive this from the (already-tracked) processing order after the correction map is
built, or track it alongside the correction map as it's constructed. Needs an explicit design
decision at implementation time, not left implicit.

### Why this resolves Finding 1 without contradiction

Finding 1's crn[m] concern (`testConservedReactingMoieties.m:29`'s hardcoded
`'crn[m]#3#O#crn[m]#5#C'`) is resolved *by construction*, not by exception: the reference instance
of any metabolite is never corrected (nothing to correct it against), and research R2 already
established that `crn[m]`'s row order genuinely *is* stable, element-for-element, across its two
real instances (unlike `5pmev[x]`) — so atoms 3 and 5's positions already agree between
`HMR_2634` and `PPACOAATREVm` with no correction needed, and the consolidation pass produces no
rename for that bond at all. The existing test's literal string survives untouched. The feature's
FR-004/FR-005 no longer need to assert "every singleton keeps its raw number" as a blanket rule
(which is what created the contradiction) — instead: **a bond's key changes only when this pass
verifies a correction is actually needed and safe**, which is a strictly narrower, correct
guarantee.

### What stays completely untouched

`canonicalBondKey.m`, `resolveAtomNodeIndex.m`, and `identifyAtomEquivalenceClasses.m`'s existing
within-instance guard/collision-check logic are not modified at all — the new pass runs after
`dBTM` already exists, using only already-resolved node data and ordinary graph/string operations.
This keeps the regression surface for `testCanonicalBondKey.m` and the existing
`testIdentifyAtomEquivalenceClasses.m` assertions at zero by construction, not by careful
diffing after the fact.
