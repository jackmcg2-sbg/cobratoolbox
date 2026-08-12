# Phase 1 Data Model: Correctly root-cause and fix atom/bond node-identity defect

**Feature**: 017-fix-atom-bond-node-identity | **Date**: 2026-08-11

This feature changes (a) the identity key of two existing graph-node concepts, (b) one node-lookup
mechanism that depends on that key, and (c) the per-species/per-bond count used by two consistency-
check formulas. No new persistent data structure, model field, or file format is introduced.

## Entity: Atom transition node

**Represents**: One specific atom, belonging to one specific instance of one specific metabolite,
within one specific reaction, as an endpoint of an edge in the atom transition digraph `dATM`.

**Identity key (current, defective)**: `metaboliteID # localAtomNumber # element`
(e.g. `"h2o[m]#2#O"`, confirmed by direct execution against the current, unfixed code).

**Identity key (fixed, Part A)**: `reactionID # metaboliteID # instanceNumber # localAtomNumber #
element`. Built from `model.rxns{i}` (loop variable, already in scope), `atomMets{n}`,
`instances(n)` (from `atoms.instances`), `atomNumbers(n)` (from `atoms.metNrs`), `atomElements{n}`.

**Storage of this key within the function**: Set as `EdgeTable.EndNodes`/`HeadAtom`/`TailAtom` at
construction time (lines 303-328); becomes `dATM.Nodes.Name` transiently after `digraph(EdgeTable)`
(line 356); copied into the persistent `dATM.Nodes.Atom` column (line 360) *before* `Name` is
stripped and the graph is rebuilt with numeric `AtomIndex` keys (lines 376-380, confirmed by
execution — see research.md Decision 2). **`dATM.Nodes.Atom` is therefore the durable form of this
identity key for the remainder of the function**, including in `dATME` (the energy-node-augmented
copy consumed by the bond loop).

**Uniqueness rule**: After the fix, the 5-tuple `(reactionID, metaboliteID, instanceNumber,
localAtomNumber, element)` is unique per distinct atom occurrence across the whole processed
network.

## Entity: Bond transition node reference

**Represents**: The head or tail atom identity embedded in one endpoint of a bond transition edge.

**Identity key (current, defective)**, per bond-substrate/bond-product side:
`metaboliteID # headAtomNumber # headElement # metaboliteID # tailAtomNumber # tailElement`.

**Identity key (fixed, Part A)**: `reactionID # metaboliteID # instanceNumber # headAtomNumber #
headElement # metaboliteID # instanceNumber # tailAtomNumber # tailElement`, built from
`bondMappings.instances(...)` in place of/alongside `bondMappings.headAtoms`/`tailAtoms`.

## Entity: Bond-loop atom lookup (Part B — corrected mechanism)

**Represents**: The mechanism by which the bond-transition loop resolves a bond's head/tail atom
back to its `dATME.Nodes` row, to populate `EdgeTable.HeadBondHeadAtom`/`HeadBondTailAtom`/
`TailBondHeadAtom`/`TailBondTailAtom` and their four `...Index` counterparts (lines 611-618).

**Current (defective) mechanism**: Boolean AND match on `(dATME.Nodes.mets, dATME.Nodes.AtomNumber,
dATME.Nodes.Element)` — three loose fields, not the identity key. Correct only because, pre-Part-A,
this triple happened to be unique across the network (a side effect of the merge defect Part A
removes).

**Fixed mechanism**: Reconstruct the target atom's fully-qualified key using the *same* format as
Part A (reaction ID from the current loop's `model.rxns{i}`, the relevant `mets`/`instances`/
`headAtoms-or-tailAtoms`/`*Element` fields from `bondMappings`), then match against
`dATME.Nodes.Atom` (the durable identity-key column, confirmed to hold this exact string — see
"Atom transition node" entity above). `numel(matchIdx) ~= 1` MUST raise a specific, named error
(FR-003) rather than silently crash (the current failure mode once Part A is applied without this
fix) or silently pick a wrong row.

**Applies to**: all four atom references per bond transition (substrate-bond head/tail,
product-bond head/tail) × 2 fields each (`Atom` value, `AtomIndex` value) = 8 assignments, sharing
4 distinct reconstructed keys (the `...Index` variant of each reference reuses the same
`matchIdx`).

## Entity: Node-identity consistency-check formula (Part C — corrected)

**Represents**: The atom-level invariant `res = (M2Ai*M2Ai')*N - M2Ai*Ti*Ti2R` (line 498) and its
bond-level analogue (line 799), which validate that the atom/bond transition graph is consistent
with `model.S`.

**Current (defective) `d`**: `diag(M2Ai*M2Ai')`, mathematically the row-sum of `M2Ai` — the total
count of atom-node columns mapped to a metabolite *across the whole processed network*. Correct
only when nodes are merged by species (masking the row-sum into the single-instance count by
construction); breaks once Part A correctly disambiguates nodes (empirically confirmed: `res=3`
per reaction for `h2o[m]`, exactly matching the predicted `d(row-sum)=6` vs. true single-instance
`d=3` discrepancy).

**Corrected `d`**: sourced from exactly one reaction's occurrence of the metabolite, normalized by
that reaction's stoichiometric coefficient (`N(i,j0)`), per research.md Decision 3's algorithm
(steps 1-3). Reaction membership per atom node is derived via a new `NodeRxn` vector (built with
the existing `mapAontoBOld` helper, keyed on the now-numeric `AtomIndex` since `Name` no longer
exists at this point in the function).

**New invariant assertion** (`options.sanityChecks`, FR-006): for a metabolite/bond appearing in
`>= 2` reactions, the corrected `d` computed independently from two different reaction occurrences
MUST agree; a specific, named error (not the generic multigraph-inconsistency warning) is raised on
disagreement, distinguishing a genuine RXN-file numbering inconsistency from the false positive
this feature eliminates.

**Applies symmetrically to**: the atom-side check (`M2Ai`, `Ti`, `Ti2R`, line 498) and the
bond-side check (`M2BiE`, `M2BiW`, `BTiE`, `BTi2R`, line 799), including each check's diagnostic-
printing block (`N2` display), which must use the same corrected `d`/`D`.

## Entity: Metabolite/bond instance number (reused, not introduced)

**Represents**: The existing per-reaction occurrence count (`atoms.instances`,
`bondMappings.instances`), already correctly computed by `readABRXNFile.m`/
`addBondMappingsRXNFile.m` (both out of scope, FR-009), reused unchanged in the Part A identity key
and in the Part C corrected `d` computation's implicit per-occurrence bookkeeping.

## Relationships / data flow (updated)

```
readABRXNFile / addBondMappingsRXNFile  (unchanged, out of scope)
        |  atoms.instances, bondMappings.instances
        v
Part A: substrateID/productID/bondSubstrateID/bondProductID
        (reaction + instance scoped identity strings)
        |
        v
dATM = digraph(EdgeTable)  -->  dATM.Nodes.Atom holds the identity string (durable)
        |                       dATM.Nodes.Name is transient, removed at line 377
        v
dATM rebuilt with numeric AtomIndex keys (line 380)
        |
        +--> Part C: NodeRxn (via mapAontoBOld, keyed on AtomIndex)
        |    --> corrected d, D --> res = D*N - M2Ai*Ti*Ti2R  (atom check)
        |
        v
dATME = addnode(dATM, EnergyNode)  (bond loop, per reaction i)
        |
        v
Part B: bond-loop atom lookup, keyed on dATME.Nodes.Atom (reconstructed target key)
        |
        v
dBTM = digraph(EdgeTable)  --> Part C (bond-side): analogous corrected d, D, res  (line 799)
```

## Downstream invariant this data model must preserve

The governing theory (Rahou, Haraldsdóttir, Martinelli, Thiele, Fleming, J. Theoretical Biology 621
(2026) 112348, Eq. 11-12) requires `M2Ai` (`V`) to span the whole processed network by column
count, with `VVᵀ` diagonal equal to each species' true, single-instance atom count. The corrected
`d` (Decision 3) is precisely this quantity — reaction-invariant, sourced from one occurrence,
cross-validated against a second occurrence when available — which is what makes
`res = D*N - M2Ai*Ti*Ti2R` hold as a true identity for a correctly-disambiguated (Part A),
multi-reaction network, consistent with both the paper's algebra and this session's own empirical
measurement of where the uncorrected formula fails.
