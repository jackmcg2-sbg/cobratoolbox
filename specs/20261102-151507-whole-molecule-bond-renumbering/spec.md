# Feature Specification: Whole-molecule bond renumbering

**Feature Branch**: `20261102-151507-whole-molecule-bond-renumbering`

**Created**: 2026-11-02

**Status**: Draft (for maintainer review; no source or test file is edited until it is approved and the implementation phase is invoked)

**Input**: Maintainer request, 2026-11-02: "draft a COBRA Spec Kit feature replacing the per-atom substitution with whole-molecule renumbering, with a molfile-equality test and recaptured goldens, for my review before implementation." Evidence: reconXmoieties exploration `specs/20261030-121933-reacting-moiety-memory/exploration.md` (branch `explore/reacting-moiety-memory`), rows E30–E33 and checks C9–C11.

<!--
  Not a characterization-mode feature: a defect fix that changes outputs on purpose, in a
  function that already has tests.
-->

## Background

Feature 020 (`020-canonicalize-symmetric-atom-bonds`, 2026-08-18) addressed a real problem. When a metabolite appears in several RXN files, chemically equivalent atoms can carry different raw atom numbers in different files. Examples are coenzyme A's gem-dimethyl hydrogens and carnitine's N-methyl hydrogens, and a carboxylate's double bond can be recorded on either oxygen. Because bond-node keys were built from raw atom numbers, these metabolites got more bond nodes than they have bonds: `coa[m]` 86 instead of 82, `crn[m]` 29 instead of 25.

The fix, `safeCanonicalizeOneAtom` in `buildAtomAndBondTransitionMultigraph.m`, replaces **each end of a bond independently** with its symmetry class's representative. That is not an isomorphism: when only one end of a bond is replaced, the bond moves to another atom. For citrate's C13–H14, C13 is replaced by its equivalent C7, while H14 is kept because C13 is also bonded to H15. The bond becomes C7–H14, which does not exist.

Measured with the build of `6bc522da0`, which this branch's base still has (exploration E33):
- **Collapsed VMH network**: **3,533 of 9,489 metabolites (37 %)** have a bond graph `BG` that equals none of their molfiles.
  - 14,804 of 561,955 bonds (2.6 %) are attached to the wrong atom, 96 % of them C–H.
  - 374 metabolites have a bond from an atom to itself (e.g. `12ethd[c]` C8–C8).
  - Every VMH metabolite has a single molfile, so feature 020 had nothing to reconcile there; every one of these changes is damage.
- **COBRA test fixtures**: 38 of 58 metabolite–fixture cases are corrupted, including citrate in the main fixture and O₂/H₂O₂ with an O1–O1 self-loop.
- **Why the tests pass**: bond counts stay correct in every case, and features 019/020 test only counts.
- **Attribution**: the same builder with only `safeCanonicalizeOneAtom` disabled misplaces no bond on any fixture (E33, C11). The authors' original code (`ab6c4840f`) builds citrate correctly.
- **Effect on the paper's example** (Rahou et al., *J. Theor. Biol.* 621 (2026) 112348, §3.1.1; the main CI fixture): the condensed reacting-bond graph has 7 vertices and 10 bonds.
  - The authors' code gives 6 and 7 on the shipped RXN files.
  - With an RXN mapping that treats citrate's two symmetric arms consistently, the authors' code gives exactly the paper's Fig. 11: 4 vertices, 6 bonds, the three reactions' bond sets letter for letter (E32, C10).
  - The conserved moieties ($L$) are unaffected (E30).
- **The golden references pin the corrupted output**: they were all captured after 2026-08-18 (`conservedReactingMoietiesReference.mat`, `reactingMoietyMemoryReference.mat`).

Whole-molecule renumbering keeps what feature 020 fixed and removes the damage:
- each RXN file's copy of a metabolite is mapped onto **one reference copy** of that metabolite by a **single** isomorphism of the molecular graph;
- the **same** renumbering is applied to **both** ends of every bond.

An isomorphism maps bonds onto bonds, so the bond graph becomes the reference molfile exactly. A copy identical to the reference keeps its own numbering.

## Clarifications

None yet. The reviewer may resolve the open points listed under Assumptions here.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every metabolite's bond graph is its molfile (Priority: P1)

A researcher builds the atom and bond transition multigraph for any network. Each metabolite's bonds in `BG` must be exactly the bonds of its molfile: the same atom pairs, the same orders and the same count. This must hold whether the metabolite appears in one RXN file or in several with different atom numbering.

**Why this priority**: every bond-level output depends on it. That includes the bond-mapping components, `arm.MG`, the reacting moieties, and the conserved-bond sets downstream tools read from `BG`. Today 37 % of the collapsed VMH network's metabolites are wrong.

**Independent Test**: the molfile-equality check (FR-004). For every metabolite of every fixture, compare its `BG` bonds with its reference molfile.

**Acceptance Scenarios**:

1. **Given** a metabolite with symmetry-equivalent atoms that appears in one RXN file only, or in several files with identical molblocks (citrate in the main fixture; every VMH metabolite), **When** the multigraph is built, **Then** its `BG` bonds equal its molfile bonds, with no renumbering applied.
2. **Given** a metabolite whose copies in different RXN files number equivalent atoms differently (`coa[m]`, `coa[x]`, `coa[r]`, `crn[c]`, `crn[m]` in the fixtures), **When** the multigraph is built, **Then** its `BG` bonds equal its reference molfile's bonds, and its bond-node count equals its true bond count (82, 25), as feature 020 required.
3. **Given** a metabolite whose carboxylate double bond is recorded on different oxygens in different files, **When** the multigraph is built, **Then** the bond orders are those of the reference copy, which is the first-seen file per feature 020's FR-003.
4. **Given** two copies of a metabolite that are not isomorphic as element-labelled graphs (a genuinely different molecule under one identifier), **When** the multigraph is built, **Then** a visible warning names the metabolite and the file (VII-B). That copy keeps its raw numbering, so its bonds are counted separately and the FR-008 bond-count check reports the mismatch, rather than the bonds being silently merged.

---

### User Story 2 - The regression tests pin correct molecules (Priority: P1)

A maintainer relies on the golden references to catch drift. They must pin outputs built from correct bond graphs, and the suite must contain a check that fails on a corrupted bond graph.

**Why this priority**: the existing count-based tests passed on corrupted graphs for 2.5 months. A golden recaptured without an independent check would just pin whatever the new code does.

**Independent Test**:
- run the molfile-equality check on the unchanged source: it fails, naming the corrupted metabolites;
- run it again after the fix: it passes;
- review the per-field difference between the old and new golden outputs.

**Acceptance Scenarios**:

1. **Given** the unchanged source, **When** the new molfile-equality test runs, **Then** it fails and names citrate in the main fixture and the CoA, carnitine, O₂ and H₂O₂ cases (red before green).
2. **Given** the fixed source, **When** the golden references whose stored `BG`/`dATM` were built by the old builder are recaptured, **Then**:
   - their inputs are rebuilt with the fixed builder;
   - their outputs are recaptured with the unchanged `identifyConservedReactingMoieties`;
   - each changed field is listed and explained in this feature's results file.
3. **Given** the recaptured references, **When** a planted bond is moved in a stored `BG`, **Then** the molfile-equality assertion detects it.

---

### User Story 3 - The paper's published example is tested against the paper (Priority: P2)

A researcher wants evidence that the toolbox reproduces Rahou et al. (2026) on its own example network, not only that it equals earlier versions of itself.

**Why this priority**: today no test compares with the paper's published values. The maintainer called alignment with the paper vital.

**Independent Test**: on the paper's example, with an RXN fixture copy whose `r0317` and `r0426` map citrate's arms as `ACONTm` does, assert the paper's published conserved and reacting results.

**Acceptance Scenarios**:

1. **Given** the paper's example with the shipped RXN files, **When** identification runs, **Then** the conserved moiety matrix equals the paper's $L$ (App. C.1.1): [1 1 1 0; 0 1 1 1] over (h2o, cit, icit, cisa). There are 6 moiety instances and 6 moiety transitions (§5.7.1), and formulae H2O and C6H3O6.
2. **Given** the shipped RXN files and the fixed builder, **When** identification runs, **Then** the condensed reacting-bond graph has 6 vertices and 7 bonds, as the authors' original code gives (E32).
3. **Given** the consistent-arm RXN copy, **When** identification runs, **Then**:
   - the condensed reacting-bond graph is the paper's Fig. 11: 4 vertices, 6 bonds;
   - each reaction has 4 reacting bonds, with sets 𝒴₁ `ACONTm` {b, c, d, e}, 𝒴₂ `r0426` {a, d, e, f}, 𝒴₃ `r0317` {a, b, c, f}, compared as atom-transition component pairs;
   - the minimal cover has 2 reactions. Which two is not asserted: every pair is minimal in Fig. 11.

---

### Edge Cases

- **Several copies of a metabolite in one file** (stoichiometric coefficient > 1): each instance is mapped separately onto the reference.
- **An isomorphism that is not unique** (the molecule has automorphisms): any isomorphism gives the same bond graph. The choice must be deterministic and must be the identity whenever the copy equals the reference, so atom transitions keep their raw atoms wherever no renumbering is needed.
- **Resonance variants**: the isomorphism ignores bond order and matches on element and connectivity, so carboxylate copies with the double bond on different oxygens are still matched. Orders then come from the reference (US1 AS3).
- **Explicit and implicit hydrogens**: copies that differ in hydrogen count are not isomorphic and fall under US1 AS4.
- **Energy pseudo-nodes** (one per reaction): not metabolites; passed through as today.
- **Atom transitions use raw numbers** (`dATM`, atom level): renumbering applies to bond keys and bond-transition atom identities only. The atom-level pairing of interchangeable atoms is known issue KI-001 and is out of scope. The conserved moieties ($L$, `M2M`, formulae) must not change (FR-006).
- **`identifyAtomEquivalenceClasses`**: no longer called by the builder. It is kept unchanged with its test (Principle II: deprecation, not deletion), and its help text says so.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `buildAtomAndBondTransitionMultigraph` must build bond-node keys and bond-transition atom identities from a per-(RXN file, metabolite, instance) renumbering. That renumbering is the identity when the copy's molblock equals the metabolite's reference molblock. Otherwise it is one isomorphism of the element-labelled, bond-order-ignoring molecular graph onto the reference. It must be applied to both ends of every bond. The per-atom substitution (`safeCanonicalizeBondAtoms`, `safeCanonicalizeOneAtom`) is removed from the builder.
- **FR-002**: The reference molblock of a metabolite is its first-seen instance, in the existing processing order. That is the same instance whose bond count is today's FR-008 ground truth and whose bond types are canonical (feature 020 FR-003).
- **FR-003**: When no isomorphism exists, a warning naming the metabolite, the reaction and the reason is emitted, not suppressed (VII-B), and that copy keeps its raw numbering. When the isomorphism search does not finish, it raises an error with the metabolite named (VII-C). There is no silent fallback.
- **FR-004**: A new test (molfile equality) asserts, for every metabolite of every fixture, that its `BG` bonds equal its reference molblock's bonds (atom pairs and orders), and that no bond joins an atom to itself. It is added to `testBuildAtomAndBondTransitionMultigraph.m` (III-Naming). It is written and shown to fail on the unchanged source before the fix.
- **FR-005**: Feature 019/020 assertions stay as they are and must pass: bond-node counts 82 and 25, no inconsistency warning for `crn[c]`, and first-seen carboxylate bond types for `crn[m]`.
- **FR-006**: The conserved-moiety outputs (`arm.L`, `arm.M2M`, `arm.M2R`, `moietyFormulae`, `arm.ATG`, `arm.MTG`) must be identical (`isequaln`) before and after on every fixture and on the non-CI networks. The bond-level outputs may change: `BG`, `dBTM`, the bond-mapping components, `arm.MG`, and every `reacting` field.
- **FR-007**: Golden references whose stored inputs came from the old builder are recaptured by a capture script in this feature's directory, run on the fixed source:
  - `conservedReactingMoietiesReference.mat`: its 6 cases;
  - `reactingMoietyMemoryReference.mat`: its 10 cases, from feature `20261102-092909`.

  The script writes a per-field old-against-new difference report, which is part of the review. References that only feed a pure function its inputs are not recaptured, because the function's behaviour on those inputs is what they pin: `bondSubgraphReference.mat`, `bondSubgraphPeelingReference.mat` and the classification references.
- **FR-008**: Tests for US3 are added to `testConservedReactingMoieties.m`. A consistent-arm copy of the example's RXN files is added as test data beside the existing fixture (`data/rxnFilesConsistentArms/`), with only the atom-map numbers of the `r0317` and `r0426` product blocks changed. The shipped fixture is not modified.
- **FR-009**: Non-CI check: rebuild the multigraph for the full collapsed VMH network and report the molfile-equality count (target: 0 corrupted metabolites) and the builder's wall time against the base. Also report that the conserved-moiety outputs of a subnetwork (random n = 500) are unchanged (FR-006).
- **FR-010**: Help text and provenance follow VII-E: the builder's NOTE describes the renumbering, and `identifyAtomEquivalenceClasses` notes that the builder no longer calls it.

### Key Entities

- **Reference molblock**: the first-seen copy of a metabolite. It defines atom numbering, bonds and bond orders.
- **Renumbering**: one map from a copy's raw atom numbers to the reference's numbers. It is the identity when the copy equals the reference, and otherwise an isomorphism of element-labelled molecular graphs.
- **Molfile-equality check**: the per-metabolite equality of `BG` bonds with the reference molblock's bonds.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Molfile equality holds for every metabolite of every CI fixture (0 corrupted, 0 self-loops). On the unchanged source the same check reports the 38 corrupted metabolite–fixture cases of E33.
- **SC-002**: On the full collapsed VMH network, 0 of 9,489 metabolites are corrupted, down from 3,533 (non-CI).
- **SC-003**: The conserved-moiety outputs are identical before and after (FR-006) on every fixture and on random n = 500.
- **SC-004**: The paper's example gives the paper's $L$, 6 instances and 6 transitions on the shipped files, and Fig. 11 (4 vertices, 6 bonds, the three bond sets) on the consistent-arm copy.
- **SC-005**: All tests in `test/verifiedTests/analysis/testReactingMoieties/` pass. The recaptured references come with a reviewed per-field difference report.
- **SC-006**: The builder's wall time on the full collapsed VMH network is at most 1.10 of the base. This is reported, not a gate: VMH needs no isomorphism search, because all its copies equal their reference.

## Assumptions

- **Base**: the fork's `develop` at `5a4371497`, which includes feature `20261102-092909-reacting-moiety-memory`.
- **Order of features**: this feature lands before the reacting-moiety scalability work (exploration option P7), so that P7's equality criterion pins correct molecules.
- **Isomorphism**: MATLAB's `isomorphism` on `graph` objects with `'NodeVariables', 'Element'`, bond order not compared. Copies that equal the reference skip it.
- **Open point for review: choice among several isomorphisms.** The proposal is MATLAB's deterministic result, except the identity whenever the copy equals the reference. A minimal-change choice (fewest renumbered atoms) is possible, but it changes no bond graph, so it is not proposed.
- **Open point for review: downstream reconXmoieties outputs built on `BG` since 2026-08-18** (moiety-bundle conserved bonds, `arm.MG`, reacting moieties). Re-running them is reconXmoieties' work, not this feature's.

## Out of Scope

- **Atom-level pairing of interchangeable atoms** in `dATM` (KI-001).
- **The largest-isomorphism-group rule** for conserved bonds (reconXmoieties `docs/known-defects.md`, 2026-10-16). It does not change the paper's example (E31).
- **Correcting the shipped RXN fixture's citrate-arm mapping.** A consistent copy is added for US3 instead.
- **Reacting-moiety scalability (P7).**

## Traceability

| Acceptance criterion | Discharging test | src/analysis/topology/reactingMoieties/ function under test |
|----------------------|------------------|-----------------------------------|
| US1 AS1–AS2, US2 AS1, AS3 / FR-001, FR-002, FR-004, SC-001 | testBuildAtomAndBondTransitionMultigraph.m (molfile equality, extended) | buildAtomAndBondTransitionMultigraph |
| US1 AS3 / FR-005 | testConservedReactingMoieties.m (existing feature 020 assertions) | buildAtomAndBondTransitionMultigraph |
| US1 AS4 / FR-003 | testBuildAtomAndBondTransitionMultigraph.m (non-isomorphic copy: warning, raw numbering) | buildAtomAndBondTransitionMultigraph |
| US2 AS2 / FR-007, SC-005 | testConservedReactingMoieties.m (recaptured golden comparison) + difference report | identifyConservedReactingMoieties |
| US3 / FR-008, SC-004 | testConservedReactingMoieties.m (paper values, extended) | buildAtomAndBondTransitionMultigraph, identifyConservedReactingMoieties |
| FR-006, SC-003 | testConservedReactingMoieties.m (conserved outputs unchanged) + non-CI check | identifyConservedReactingMoieties |
| FR-009, SC-002, SC-006 | non-CI check script in this feature's directory | buildAtomAndBondTransitionMultigraph |
| FR-010 | -- (static review) | -- (no source function) |
