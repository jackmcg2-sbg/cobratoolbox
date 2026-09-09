# Phase 1 Contracts: Touched Function Interfaces

**Feature**: `specs/20260908-102947-hub-guard-keying-gap-fix/spec.md`
**Plan**: [plan.md](./plan.md) · **Data model**: [data-model.md](./data-model.md)

This feature exposes no public API, CLI, or network endpoint — it is a MATLAB scientific-library
correctness fix internal to `src/analysis/topology/reactingMoieties/`. Its "contracts" are the
signatures and behavioural guarantees of the two touched functions, both already public MATLAB
functions in this repository and both already covered by existing tests. No signature changes are
permitted (plan.md Constraints); this document is the *invariant* contract the implementation must
satisfy, not a new interface.

## `identifyAtomEquivalenceClasses.m`

```matlab
[canonicalAtomNumberMap, equivalenceClasses, unsafeNeighborsByClass] = ...
    identifyAtomEquivalenceClasses(atomNumbers, elements, headAtoms, tailAtoms, bTypes, metName)
```

**Signature**: UNCHANGED (spec.md Assumptions; plan.md Constraints). No new output argument added
to the public return list.

**Contract additions this feature requires** (internal, not a signature change):
- The function's existing colour-refinement loop already computes a final WL colour-class id per
  atom internally. This feature requires that value be reused (exposed via an additional output,
  or via a small internal helper reused at the call site — plan.md Design step 1) rather than
  recomputed, so the class id `buildAtomAndBondTransitionMultigraph.m` keys on is guaranteed
  identical to the one `equivalenceClasses`/`unsafeNeighborsByClass` were themselves derived from.
- **Precondition** (unchanged): `atomNumbers`, `elements`, `headAtoms`, `tailAtoms`, `bTypes`
  describe one RXN-file instance's atoms and bonds for metabolite `metName`.
- **Postcondition** (unchanged behaviour, FR-003): `unsafeNeighborsByClass` continues to be
  populated by exactly the same unsafe-neighbour and cross-class/cross-bond collision guard logic
  as today — this feature's fix must not change which pairings are marked unsafe, only what key
  `buildAtomAndBondTransitionMultigraph.m` constructs when a pairing *is* unsafe.
- **New internal postcondition**: the per-atom WL colour-class id newly exposed (however it is
  exposed) is a deterministic function of this call's own inputs only — never of any prior call's
  state, matching FR-002's per-file independence requirement.

## `buildAtomAndBondTransitionMultigraph.m`

```matlab
[dATM, metAtomMappedBool, rxnAtomMappedBool, M2Ai, Ti2R, dATME, BG, dBTM, M2BiE, M2BiW, BTi2R, BTiE] = ...
    buildAtomAndBondTransitionMultigraph(model, RXNFileDir, options)
```

**Signature**: UNCHANGED. `options.sanityChecks` semantics UNCHANGED (plan.md Constraints).

**Contract change — internal helper `safeCanonicalizeOneAtom`** (buildAtomAndBondTransitionMultigraph.m:1003):

```matlab
atomOut = safeCanonicalizeOneAtom(atomRaw, otherAtomRaw, rankMap, unsafeMap)
```

- **Today's contract**: returns `canonicalRep` (the class's canonical representative) when safe to
  substitute; returns `atomRaw` UNCHANGED when the unsafe-map check fires (the guard-blocked
  fallback this feature replaces).
- **New contract** (FR-001): in the guard-blocked branch, returns a value keyed by
  `(colourClassId, withinClassRank)` — the **WL-Colour-Class Key** (data-model.md) — instead of
  `atomRaw` unchanged. The safe-substitution branch's existing behaviour (returning `canonicalRep`)
  is unchanged; only the fallback branch's return value changes in kind.
- **Postcondition** (FR-004): when `atomRaw`'s WL-colour class is a singleton, the returned key is
  byte-for-byte identical, downstream at `canonicalBondKey.m`, to today's `atomRaw`-based key.
- **Postcondition** (FR-002): within one call to `buildAtomAndBondTransitionMultigraph` (one
  RXN-file instance), two distinct class members never produce the same returned key.
- **Postcondition** (FR-003): this helper's *decision* of which branch to take (the `isKey`/
  `ismember` guard check) is unchanged — only the guard-blocked branch's return value changes.

## `canonicalBondKey.m`

```matlab
[key, met1, atomNum1, elem1, met2, atomNum2, elem2] = ...
    canonicalBondKey(metA, atomNumA, elemA, metB, atomNumB, elemB)
```

**Signature and internal logic**: UNCHANGED — read only, not modified by this feature (plan.md
Primary Dependencies, research.md R2). Documented here because its behaviour is the consumer this
feature's new key construction must remain compatible with: its existing atom-number secondary
sort must treat a singleton's `(colourClassId, 1)` key identically to today's plain `atomNumA`/
`atomNumB` (R3, data-model.md) — to be confirmed against its actual current sort-key construction
during implementation, not merely assumed.
