# Feature Specification: Reaction-scoped atom/bond node identity in `buildAtomAndBondTransitionMultigraph`

**Feature Branch**: `016-atom-bond-node-identity`

**Created**: 2026-08-11

**Status**: Superseded — see `017-fix-atom-bond-node-identity`. This spec's prescribed fix was
empirically disproven by MATLAB execution during `/speckit-implement` (2026-08-11): applying it
regressed a previously-passing case (new `Inconsistent directed atom transition multigraph`
warning) and crashed the bond-transition loop, disproving the "no other code needs to change"
claim below. No code from this feature shipped; the source file was reverted to its pre-feature
state. See `specs/017-fix-atom-bond-node-identity/spec.md`, "Evidence from feature 016" section,
for full details.

**Input**: User description: fix reaction-unscoped atom/bond node identity in
`src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m`. When the same
metabolite (e.g. water, O2, coenzyme A) participates in more than one reaction in a processed
network, atom/bond node identity strings built from `metaboliteID # localAtomNumber # element`
(with no reaction identifier and no per-metabolite instance number) can coincide across
reactions, causing `digraph`'s name-based node deduplication to silently merge atom/bond
instances belonging to physically and causally unrelated reactions into shared nodes. This
inflates each affected species' node population, corrupts the theory-required invariant that
`diag(M2Ai*M2Ai')` equal that species' true reaction-invariant atom count, and produces
false-positive `Inconsistent directed atom/bond transition multigraph` sanity-check warnings.
Bug-fix work, confined to `buildAtomAndBondTransitionMultigraph.m`; additive/corrective only, no
public interface change, no change to `readABRXNFile.m`, `addBondMappingsRXNFile.m`, or
`identifyConservedReactingMoieties.m`.

## Clarifications

None required — the source spec write-up traced the root cause to two specific ID-construction
sites, specified the exact replacement format (reaction ID + metabolite/bond instance number
prepended to the existing local numbering), confirmed the fix's compatibility with the downstream
conserved-moiety consumer by reading its connected-component + isomorphism logic, and gave
concrete before/after invariants to test against (diag(M2Ai*M2Ai') = 3 for water, 2 for O2, 80 for
coenzyme A). No scope, security, or UX ambiguity remains.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sanity check passes on multi-reaction networks sharing hub metabolites (Priority: P1)

A researcher runs `buildAtomAndBondTransitionMultigraph` with `options.sanityChecks = 1` on a
sub-network of several reactions that share a common "hub" metabolite (water, O2, coenzyme A,
etc.) appearing in more than one of those reactions. Today this reliably emits false-positive
`Inconsistent directed atom transition multigraph` and `Inconsistent directed bond transition
multigraph` warnings, because the hub metabolite's atom/bond nodes from different reactions get
silently merged by `digraph`'s name-based deduplication. The researcher should instead get a
clean run with no such warnings, because the underlying atom mapping is in fact internally
consistent per reaction — the warning is a defect in node-identity construction, not a real data
problem.

**Why this priority**: This is the reported symptom and the reason the bug was investigated; it
directly blocks trustworthy use of the sanity check on any multi-reaction network containing
shared metabolites (the common case for real metabolic sub-networks).

**Independent Test**: Run `buildAtomAndBondTransitionMultigraph(subModelSample, atomMappedDir,
options)` with `options.sanityChecks = 1` on a sample of reactions known to share hub metabolites
(e.g. R_17357_e, R_84979_e, R_50844_n, R_70951_e, R_11920_n, R_38891_e, R_31183_i, R_37203_i run
together) and confirm neither warning fires.

**Acceptance Scenarios**:

1. **Given** a sub-network where a metabolite (e.g. water, CHEBI_15377) appears in two or more of
   the processed reactions, **When** `buildAtomAndBondTransitionMultigraph` runs with
   `options.sanityChecks = 1`, **Then** no `Inconsistent directed atom transition multigraph`
   warning is emitted.
2. **Given** the same conditions, **When** the bond-transition sanity check runs, **Then** no
   `Inconsistent directed bond transition multigraph` warning is emitted.

---

### User Story 2 - Per-species atom/bond node counts reflect true chemistry, not merge artifacts (Priority: P1)

A researcher inspects the atom-to-metabolite incidence matrix (`M2Ai`) produced for a
multi-reaction network and needs `diag(M2Ai*M2Ai')` for a given metabolite to equal that
metabolite's true, single-instance atom count — a value fixed by its chemical formula and
independent of how many reactions it participates in. Today, for metabolites that recur across
reactions, this diagonal value is inflated by coincidental node-name collisions (e.g. observed
values of 16 or 32 for water instead of the correct 3). After the fix, this value must be correct
for every recurring metabolite in the network.

**Why this priority**: This is the actual correctness invariant the sanity-check warning is a
proxy for; verifying it directly is what proves the fix addresses root cause rather than just
silencing the warning.

**Independent Test**: After running the fixed function on the same multi-reaction sample, compute
`M2Ai*M2Ai'` and confirm the diagonal entries for water, O2, and coenzyme A (or whichever of these
appear in the sample) equal 3, 2, and 80 respectively.

**Acceptance Scenarios**:

1. **Given** the fixed atom transition multigraph for a network containing water in more than one
   reaction, **When** `diag(M2Ai*M2Ai')` is computed for water's node rows, **Then** the value is
   3 (its true atom count), not an inflated multiple.
2. **Given** the same network also contains O2 and/or coenzyme A recurring across reactions,
   **When** the same diagonal is computed for those species, **Then** the values are 2 and 80
   respectively.

---

### User Story 3 - Downstream conserved/reacting moiety identification is unaffected or improved (Priority: P2)

A researcher who already runs `identifyConservedReactingMoieties.m` on the output of
`buildAtomAndBondTransitionMultigraph` for the affected sample needs its results (`arm`,
`moietyFormulae`, `reacting`) to keep working after the fix — the fix must not sever the
cross-reaction graph-isomorphism matching that identifies conserved moieties, since that matching
already operates on connected components and metabolite labels rather than on shared node
objects.

**Why this priority**: This is the regression-risk check confirming the node-identity fix,
which changes the internal graph structure, does not silently break the feature's actual
downstream deliverable — conserved/reacting moiety identification. It is P2 because it is a
verification of non-regression rather than the primary defect being fixed.

**Independent Test**: Run `identifyConservedReactingMoieties.m` on the fixed `dATM`/`BG` outputs
for the same reaction sample used in User Story 1/2 and confirm it completes without new errors,
producing `arm`, `moietyFormulae`, and `reacting` results, with the previously-observed
bond-change-event resolution count (14/19 sampled reactions) preserved or improved.

**Acceptance Scenarios**:

1. **Given** the fixed `dATM`/`BG` outputs for the sample network, **When**
   `identifyConservedReactingMoieties.m` runs, **Then** it completes without new errors and
   returns non-empty `arm`, `moietyFormulae`, and `reacting` results.
2. **Given** the same run, **When** the bond-change-event resolution count is compared to the
   pre-fix baseline (14/19 sampled reactions), **Then** the post-fix count is greater than or
   equal to the baseline.

### Edge Cases

- A metabolite that appears only once in the entire processed network: its node identity string
  changes (gains a reaction/instance prefix) but its node count and `M2Ai` diagonal must be
  unchanged, since there was never a cross-reaction collision for it.
- A metabolite appearing more than once **within the same reaction** (multiple stoichiometric
  instances, e.g. `2 H2O`): the existing per-reaction `instances` numbering (already correctly
  computed by `readABRXNFile.m`/`addBondMappingsRXNFile.m`) must continue to distinguish these
  instances from each other now that it is embedded in the node ID, not just from other
  reactions'.
- A single-reaction network/model (no cross-reaction sharing possible): sanity checks must
  continue to pass exactly as before the fix (no behavior change expected for this case).
- Any pre-existing genuine (non-merge-artifact) inconsistency in an individual RXN file's atom
  mapping must still surface as a sanity-check warning after the fix — the fix must not mask real
  defects, only remove the false positive caused by name collision.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The atom-transition node identity strings (`substrateID`, `productID`) constructed
  in `buildAtomAndBondTransitionMultigraph.m` MUST be unique per (reaction, metabolite instance,
  local atom number, element) tuple, by prepending the current reaction identifier
  (`model.rxns{i}`) and the metabolite's per-reaction instance number to the existing local atom
  number and element.
- **FR-002**: The bond-transition node identity strings (`bondSubstrateID`, `bondProductID`)
  constructed in `buildAtomAndBondTransitionMultigraph.m` MUST be unique per (reaction,
  metabolite instance, atom number, element) tuple at both head- and tail-atom positions, by
  prepending the current reaction identifier and the bond's per-reaction instance number
  (`bondMappings.instances`).
- **FR-003**: System MUST NOT merge atom or bond nodes belonging to different reactions that
  happen to share a metabolite ID, local atom/bond number, and element, once the fix is applied.
- **FR-004**: System MUST continue to build one shared atom transition multigraph (`dATM`) and
  one shared bond transition multigraph (`dBTM`) spanning all reactions in the processed network
  — the fix scopes node *identity strings*, not the graph's cross-reaction structure required by
  the governing theory (Eq. 11-12 of the cited paper).
- **FR-005**: System MUST preserve the existing documented public interface of
  `buildAtomAndBondTransitionMultigraph.m` (signature, inputs, outputs) and MUST NOT modify
  `readABRXNFile.m`, `addBondMappingsRXNFile.m`, or `identifyConservedReactingMoieties.m`.
- **FR-006**: System MUST preserve documented public interfaces, diagnostic semantics, and
  file-location conventions affected by this feature — in particular, the `sanityChecks` warning
  mechanism itself (still fires on genuine inconsistencies) and the shape/fields of `dATM.Nodes`,
  `dBTM.Nodes`, `M2Ai`, and related outputs consumed downstream.
- **FR-007**: System MUST define the narrowest reproducibility check that proves the fix: running
  `buildAtomAndBondTransitionMultigraph` with `options.sanityChecks = 1` on a fixed multi-reaction
  sample containing a recurring hub metabolite, asserting no false-positive warning and correct
  `diag(M2Ai*M2Ai')` values for that metabolite.
- **FR-008**: System MUST NOT change the numeric atom-mapping content of any RXN file, and MUST
  NOT alter `checkABRXNFiles.m`'s per-file parity check — this feature is confined to node-identity
  string construction in the transition-multigraph builder.

### Key Entities

- **Atom transition node**: A vertex in `dATM` representing one specific atom, in one specific
  instance of one specific metabolite, within one specific reaction. Identity must be unique
  across the whole processed network after this fix (previously unique only within a single RXN
  file's local numbering).
- **Bond transition node reference**: The head/tail atom identity embedded in a bond transition
  edge (`dBTM`), subject to the same reaction/instance-scoping requirement as atom transition
  nodes.
- **Metabolite instance number**: The existing per-reaction occurrence count of a metabolite
  (already computed and exposed by `readABRXNFile.m` as `atoms.instances` /
  `bondMappings.instances`), reused here as part of the node identity key rather than being newly
  computed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Running `buildAtomAndBondTransitionMultigraph` with `options.sanityChecks = 1` on
  the reference multi-reaction sample (R_17357_e, R_84979_e, R_50844_n, R_70951_e, R_11920_n,
  R_38891_e, R_31183_i, R_37203_i run together) produces zero `Inconsistent directed atom
  transition multigraph` and zero `Inconsistent directed bond transition multigraph` warnings.
- **SC-002**: For every metabolite occurring in more than one reaction of that sample (at minimum
  water/CHEBI_15377, and O2/CHEBI_15379 or coenzyme A/CHEBI_57287 if present), `diag(M2Ai*M2Ai')`
  equals the metabolite's true single-instance atom count (3, 2, 80 respectively).
- **SC-003**: `identifyConservedReactingMoieties.m` run on the fixed outputs for the same sample
  completes without new errors and resolves at least as many bond-change events as the pre-fix
  baseline (14/19 sampled reactions).
- **SC-004**: All existing passing tests under the toolbox's `reactingMoieties`/`conservedMoieties`
  test areas remain passing after the change (no new failures introduced).
- **SC-005**: The diff implementing this fix touches only
  `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m`.

## Assumptions

- The `instances` local variable (atom section) and `bondMappings.instances` (bond section) are
  already correctly populated per-reaction by `readABRXNFile.m`/`addBondMappingsRXNFile.m`, as
  confirmed by source inspection; this feature reuses them without modification.
- `model.rxns{i}` is already in scope at both ID-construction sites (it is used elsewhere in the
  same loops, e.g. for `EdgeTable.Trans`), so no new data threading into the function is required.
- The `#` character remains reserved exclusively as the internal field separator in these ID
  strings; no metabolite ID, reaction ID, or instance/atom number in current data contains `#`
  (already enforced downstream by `identifyConservedReactingMoieties.m`'s guard).
- No test fixture or golden-output file currently asserts on the literal pre-fix node-name string
  format; if any such fixture exists, its expected strings must be updated to the new format as
  part of this feature's test discharge, not treated as a separate feature.

## Traceability

| Acceptance criterion | Discharging test | src/<domain>/ function under test |
|----------------------|------------------|-----------------------------------|
| US1 / FR-001, FR-002, FR-003 | testBuildAtomAndBondTransitionMultigraph (sanity-check, no warning) under test/verifiedTests/analysis/ | src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m |
| US2 / FR-001, FR-002 | testBuildAtomAndBondTransitionMultigraph (M2Ai diagonal assertion) under test/verifiedTests/analysis/ | src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m |
| US3 / FR-004, FR-005, FR-006 | testIdentifyConservedReactingMoieties (regression) under test/verifiedTests/analysis/ | src/analysis/topology/reactingMoieties/identifyConservedReactingMoieties.m |
