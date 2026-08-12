# Phase 1 Data Model: Reaction-scoped atom/bond node identity

**Feature**: 016-atom-bond-node-identity | **Date**: 2026-08-11

This feature changes the *identity key* of two existing graph-node concepts inside
`buildAtomAndBondTransitionMultigraph.m`. It introduces no new persistent data structure, model
field, or file format. The entities below are the in-memory objects whose key format changes, and
the fields that flow into that key.

## Entity: Atom transition node

**Represents**: One specific atom, belonging to one specific instance of one specific metabolite,
within one specific reaction, as it appears as an endpoint (`HeadAtom`/`TailAtom`) of an edge in
the atom transition digraph `dATM`.

**Identity key (current, defective)**:
```
metaboliteID # localAtomNumber # element
```
Fields: `atomMets{n}` (metabolite ID, e.g. `h2o[m]`), `atomNumbers(n)` (local, per-RXN-file atom
number, from `atoms.metNrs`), `atomElements{n}` (element symbol).

**Identity key (fixed, this feature)**:
```
reactionID # metaboliteID # instanceNumber # localAtomNumber # element
```
Additional fields: `model.rxns{i}` (current reaction ID, loop variable already in scope),
`instances(n)` (per-reaction metabolite instance number, from `atoms.instances`, already read at
line 258 but previously unused in ID construction).

**Uniqueness rule**: After the fix, no two atom transition nodes across the entire processed
network may share an identity key unless they represent the same physical atom occurrence — i.e.
the 5-tuple `(reactionID, metaboliteID, instanceNumber, localAtomNumber, element)` MUST be unique
per distinct atom occurrence, and MUST coincide only for atoms that are genuinely the same
occurrence (there is no case in this function where two loop iterations legitimately produce an
identical 5-tuple for different atoms).

**Consumers (unchanged, verified opaque-key usage)**: `EdgeTable.EndNodes`, `EdgeTable.HeadAtom`,
`EdgeTable.TailAtom`, `dATM = digraph(EdgeTable)`, `dATM.Nodes`, `M2Ai` construction (maps nodes to
owning metabolite by string match), and cross-reaction matching in
`identifyConservedReactingMoieties.m` (post-hoc, via `conncomp` + `isisomorphic`, never via
shared node identity).

## Entity: Bond transition node reference

**Represents**: The head or tail atom identity embedded in one endpoint of a bond transition edge
in the bond transition digraph `dBTM`/bond instance graph `BG`.

**Identity key (current, defective)**, per bond-substrate/bond-product side:
```
metaboliteID # headAtomNumber # headElement # metaboliteID # tailAtomNumber # tailElement
```
Fields: `bondMappings.mets{n}`, `bondMappings.headAtoms(n)`, `bondMappings.headAtomElements{n}`,
`bondMappings.tailAtoms(n)`, `bondMappings.tailAtomElements{n}`.

**Identity key (fixed, this feature)**:
```
reactionID # metaboliteID # instanceNumber # headAtomNumber # headElement
  # metaboliteID # instanceNumber # tailAtomNumber # tailElement
```
Additional fields: `model.rxns{i}`, `bondMappings.instances(n)` (per-reaction bond/metabolite
instance number, inherited unmodified from `readABRXNFile.m`'s `bInstances`).

**Uniqueness rule**: Same principle as the atom node — the extended tuple must be unique per
distinct bond occurrence across the whole network, coinciding only for genuinely identical bond
occurrences.

**Consumers (unchanged, verified opaque-key usage)**: `EdgeTable.EndNodes`, `EdgeTable.HeadBond`,
`EdgeTable.TailBond`, `dBTM = digraph(EdgeTable)`, `dBTM.Nodes`, `M2BiE`/`M2BiW` construction.

## Entity: Metabolite instance number (reused, not introduced)

**Represents**: The existing count of which occurrence, within a single reaction, a repeated
metabolite atom/bond belongs to (e.g. the first vs. second water produced if a reaction happened
to produce two). Already computed by `readABRXNFile.m` (`atoms.instances`, `aInstances`) and
`addBondMappingsRXNFile.m` (`bondMappings.instances`, inherited from `bonds.instances`/
`bInstances`). This feature reads this existing field into the node identity key; it does not
change how the field itself is computed.

**Validation rule carried over unchanged**: `readABRXNFile.m` and `addBondMappingsRXNFile.m` are
out of scope for this feature (spec "Repository / target" and FR-005) — their output is trusted
as-is.

## State / Relationships

No state machine is involved. The relationship this feature changes is purely the *grouping
key* used by `digraph`'s implicit node deduplication: before the fix, two atom/bond occurrences
in different reactions could alias to the same graph node; after the fix, aliasing can only occur
for genuinely identical `(reaction, metabolite, instance, local-number, element)` occurrences,
which by construction of the loop are never duplicated (`k` increments once per transition, and
`j` enumerates `atomTransitionNumbers` uniquely within one reaction's RXN file parse).

## Downstream invariant this data model must preserve (Eq. 11-12, Rahou et al. 2026)

`M2Ai` (paper's `V`) maps each atom node to its owning metabolite species. For any metabolite
`m`, the row/column selection `M2Ai(m,:) * M2Ai(m,:)'` (`diag(M2Ai*M2Ai')` restricted to `m`) MUST
equal `m`'s true, single-instance atom count, independent of how many reactions or instances of
`m` appear in the processed network — because each reaction/instance now contributes
*distinctly-keyed* nodes rather than merging into one. This is the concrete, checkable
consequence of the identity-key fix and is what SC-002 verifies.
