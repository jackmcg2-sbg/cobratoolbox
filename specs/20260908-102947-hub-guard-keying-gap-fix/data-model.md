# Phase 1 Data Model: Uniform WL-Colour Keying for Guard-Blocked Symmetric Atom Classes

**Feature**: `specs/20260908-102947-hub-guard-keying-gap-fix/spec.md`
**Plan**: [plan.md](./plan.md) · **Research**: [research.md](./research.md)

This feature introduces no new persisted or model-facing entity (`model.S`/`.mets`/`.rxns` are
never read or written by this layer — plan.md Constitution Check). The entities below are
in-memory constructs threaded between `identifyAtomEquivalenceClasses.m` and
`buildAtomAndBondTransitionMultigraph.m` during one `dBTM` build; none outlive that call except via
the same per-metabolite cache feature 020 already maintains (FR-009).

## Entities

### WL-Colour-Class Key

The replacement for raw `atomNumber` as the atom-identity input to `canonicalBondKey.m`'s (or its
upstream remap's) sort.

| Field | Type | Description |
|---|---|---|
| `colourClassId` | scalar (int-like) | The 1-WL colour-refinement partition cell the atom converges to, per `identifyAtomEquivalenceClasses.m`'s existing colour-refinement loop. A pure graph invariant — identical across independently-generated RXN-file instances of the same molecule. |
| `withinClassRank` | positive integer | See **Within-Class Rank** below. |

**Validation rules**:
- FR-004: for a singleton class (no symmetry), `(colourClassId, 1)` MUST produce a
  `canonicalBondKey.m` sort key identical to today's plain raw `atomNumber` (R3, research.md) —
  the singleton's own raw atom number is the natural choice of `colourClassId` for this case.
- FR-002: two atoms occupying different physical positions within the same class, within one
  file, MUST NOT collapse onto the same `(colourClassId, withinClassRank)` pair.

**Relationships**: Computed from `identifyAtomEquivalenceClasses.m`'s existing outputs
(`equivalenceClasses`, and the internal colour-refinement state feature 020 already computes but
does not currently expose past the function boundary — plan.md Design step 1). Consumed by
`buildAtomAndBondTransitionMultigraph.m`'s `safeCanonicalizeOneAtom` fallback branch in place of
returning `atomRaw` unchanged.

### Within-Class Rank

A deterministic, per-file, per-class tie-break.

| Field | Type | Description |
|---|---|---|
| `member` | raw atom number | One atom belonging to a given WL-colour class, within one RXN-file instance. |
| `rank` | positive integer, 1-indexed | Sorted position of `member` by raw atom number among that class's members, computed independently per file. |

**Validation rules**:
- Pure function of one file's own class membership — never carried over from, or compared
  against, another file's numbering (FR-002).
- Every class member receives a rank, even when only some members participate in guard-blocked
  bonds (Edge Cases, spec.md) — ranks must stay reproducible if the fix is invoked again on the
  same file.
- Singleton classes always rank `1` (R3).

**Relationships**: One `withinClassRank` value is computed per `(class, file)` pair, feeding
directly into that class's members' **WL-Colour-Class Key**.

### Structurally-Consistent Instance Set

The precondition US1/FR-006's cross-file guarantee is conditioned on — not a new field on any
existing struct, but a classification this feature's *validation* step (not its source-code fix)
applies to a metabolite's set of RXN-file instances.

| Field | Type | Description |
|---|---|---|
| `metName` | string | Metabolite identifier (e.g. `5pmev[x]`), matching `identifyAtomEquivalenceClasses.m`'s `metName` parameter. |
| `atomCount`, `bondCount`, `elementHistogram`, `totalCharge` | per-instance scalars/maps | Structural fingerprint compared across every instance file the metabolite appears in. |
| `isConsistent` | boolean | `true` iff every instance file agrees on all four fingerprint fields. |

**Validation rules**:
- FR-008: this feature MUST NOT attempt to reconcile an inconsistent set — a metabolite classified
  `isConsistent = false` is Diagnosis 2 (out of scope) and must continue to fail crit1 exactly as
  it does pre-fix.
- FR-006/SC-004: every metabolite still failing crit1 post-fix MUST be classified and the
  classification recorded (US3), not silently absorbed into an undifferentiated "still fails"
  bucket.

**Relationships**: Computed by the corpus-scale validation harness
(`validate_symmetric_atom_classes_matlab.m`, reconXmoieties — research.md R4) and by
`hubguard_diagnostic.py`'s method (or its MATLAB equivalent) referenced in spec.md US3's
Independent Test. Not computed or stored by the source-code fix itself.

## State transitions

None of the three entities above are stateful across calls beyond feature 020's existing
per-metabolite cache (`metBondCountGroundTruth`-style, FR-009): each is recomputed fresh per
`identifyAtomEquivalenceClasses` call for a given metabolite instance and discarded once that
metabolite's `dBTM` contribution is built, exactly matching today's caching architecture.
