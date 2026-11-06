# Feature Specification: Reacting-bond incidence from bond changes, as in the paper

**Feature Branch**: `20261106-092213-paper-reacting-bond-incidence`

**Created**: 2026-11-06

**Status**: Draft (for maintainer review; no source or test file is edited until it is approved and the implementation phase is invoked)

**Input**: Maintainer request, 2026-11-06: "Start the spec" for implementing the paper's definition of `CRB2R`. Evidence: reconXmoieties exploration `specs/20261030-121933-reacting-moiety-memory/exploration.md` (on `main` since reconXmoieties PR #67), rows E36–E37 and check C14.

<!--
  Not a characterization-mode feature: a method change that alters reacting-moiety outputs on
  purpose, in a function that already has tests.
-->

## Background

`identifyConservedReactingMoieties` finds reacting moieties in three steps. It builds the condensed reacting-bond graph `Condensed_RBG`. It then builds `CRB2R`, a matrix with one row per condensed reacting bond and one column per reaction. Finally it solves a minimum set cover of the rows by the columns. The selected reactions, and the bonds each one covers, are the reacting moieties.

**The paper defines `CRB2R`, and the code does not follow it.** Rahou et al., *J. Theor. Biol.* 621 (2026) 112348:
- §6.3, eq. 32: the set cover runs over the matrix $A \in \{0,1\}^{d \times n}$, with an entry of 1 when a bond "is involved in" a reaction.
- §6.1 says what "involved" means: each edge of the reacting moiety graph is labelled with the reactions where that bond is broken, formed or changes order.
- §4.1, eq. 8 and Fig. 11 agree. For example, Fig. 11 lists reaction 1 as {b, c, d, e}, which are exactly the bonds it breaks or forms.

In symbols, the paper's rule for a condensed reacting bond $b$ and a reaction $R$ is:

$$\text{CRB2R}_{b,R} = 1 \iff b \in \mathcal{S}(R) \,\triangle\, \mathcal{P}(R)$$

**What the code does instead** (`ad0d11d60`, `identifyConservedReactingMoieties.m` L1722–1782): it sets $\text{CRB2R}_{b,R} = 1$ when any atom transition of $R$ has either end atom of $b$ as its head or tail.
- Every reaction that consumes or produces a metabolite moves all of that metabolite's atoms. So the code's rule marks a bond against nearly every reaction that uses either metabolite carrying it, whether or not the bond changes there.
- On the full collapsed VMH network (reconXmoieties E36), one condensed reacting bond is marked by up to 5,195 of 9,634 reactions.
- The set cover still covers every bond, but a selected reaction can "cover" a bond it leaves intact. So the reacting moieties do not mean what the paper means.

**Why the existing tests don't catch it.**
- **Consistent-arm copy**: the two rules give the same `CRB2R` (C10). Every reaction there that moves a reacting bond's atoms also changes that bond, so the Fig. 11 test passes either way.
- **Shipped RXN files**: the rules differ (plan research R3). Today's rule marks `ACONTm` and `r0317` each against one condensed bond they don't change. The test there asserts only the graph's size (6 vertices, 7 bonds), not each reaction's bonds.

**The data the paper's rule needs already exists.** When the builder reads each RXN file (`addBondMappingsRXNFile`), it labels every bond of that reaction as broken (−1), formed (+1) or conserved (0).
- A double bond is split into two bonding interactions, so a change of order is one broken or formed interaction, as §4.1 says.
- These labels reach the bond transition multigraph `dBTM`. `identifyConservedReactingSubgraphs` already reads them out as broken- and formed-bond tables.
- `identifyConservedReactingMoieties` does not receive `dBTM`; it gets only `BG` and `dATM`.

## Clarifications

### Session 2026-11-06

- Q: When several reacting bonds are merged into one condensed edge, which reactions does its `CRB2R` row hold? → A: the union of the reactions that change any of the merged bonds (FR-003).
- Q: Does the current end-atom rule stay available? → A: yes, as a non-default option (FR-006).

## Compatibility

**Approved breaking change** (Principle II), maintainer, 2026-11-06 (Clarifications, FR-006): the default `CRB2R` rule changes to the paper's. A full-mode call that doesn't pass the bond changes now stops with an error, where it used to return end-atom results.

**Migration path**:
- pass the builder's bond transition multigraph (`dBTM`, its eighth output) to get the paper's rule;
- or set `options.reactingBondIncidence = 'endAtom'` to get exactly the earlier results.

Argument positions, option names and existing errors are unchanged. Conserved-only calls are unaffected.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Each reacting bond belongs only to the reactions that change it (Priority: P1)

A researcher identifies reacting moieties on a network. For every condensed reacting bond, the reactions recorded against it must be exactly the reactions that break, form or change the order of that bond. A reaction that only moves the bond's atoms, such as a transport reaction or a reaction elsewhere on the same metabolite, must not be recorded.

**Why this priority**: this is the definition in the paper. Every reacting-moiety output (the set cover, `ReactMoietyMatrix`, `ReactMoietySets`, `ReactMoietyGraphs`) is built on it.

**Independent Test**: use a small network where at least one reaction moves a reacting bond's atoms without changing that bond. Check that this reaction's column of `CRB2R` is zero for that bond, and that each row equals the reactions the RXN files label as breaking or forming the bond.

**Acceptance Scenarios**:

1. **Given** the paper's example plus a reaction that moves citrate without changing any of its bonds (for example citrate transport between two compartments, mapped atom to atom), **When** reacting moieties are identified, **Then**:
   - the added reaction's column of `CRB2R` is all zero;
   - the added reaction is not in the minimal cover;
   - the other three reactions' columns are the same as without the added reaction.

   Under the current rule, the added reaction's column marks every condensed reacting bond with an end atom on citrate. So this scenario fails on the unchanged source (red before green).
2. **Given** any network, **When** reacting moieties are identified, **Then** for every condensed reacting bond $b$ and reaction $R$, $\text{CRB2R}_{b,R} = 1$ exactly when the builder's bond labels record $b$ (or, for a merged edge, any of the bonds merged into $b$; FR-003) as broken or formed in $R$.
3. **Given** a reaction that changes a bond's order without breaking it (a double bond becoming single), **When** reacting moieties are identified, **Then** that reaction is recorded against the condensed bond for the changed bonding interaction.

---

### User Story 2 - The paper's published example still reproduces (Priority: P1)

A maintainer relies on the Fig. 11 test, which compares the toolbox with the paper's published values.

**Why this priority**: the change brings the code closer to the paper, so the paper's own example must not move.

**Independent Test**: the existing Fig. 11 test in `testConservedReactingMoieties.m`, unchanged.

**Acceptance Scenarios**:

1. **Given** the consistent-arm RXN copy of the paper's example (`data/rxnFilesConsistentArms/`), **When** reacting moieties are identified, **Then**:
   - the condensed reacting-bond graph is still Fig. 11: 4 vertices and 6 bonds;
   - each reaction's bonds are still 𝒴₁ `ACONTm` {b, c, d, e}, 𝒴₂ `r0426` {a, d, e, f} and 𝒴₃ `r0317` {a, b, c, f};
   - the minimal cover still has 2 reactions.
2. **Given** the shipped RXN fixture, **When** identification runs, **Then** the conserved moieties ($L$, 6 instances, 6 transitions, formulae H2O and C6H3O6) are unchanged.

---

### User Story 3 - The change is reviewed on real networks before it is trusted (Priority: P2)

A maintainer wants to see what the change does at genome scale before reacting-moiety results built on it are used.

**Why this priority**: the toy networks can't show the size of the change. On the full collapsed VMH network the old rule's rows are dense (up to 5,195 reactions per bond).

**Independent Test**: a non-CI check script in this feature's directory. It runs on the full collapsed VMH network and reports the old and new outputs side by side.

**Acceptance Scenarios**:

1. **Given** the full collapsed VMH network, **When** reacting moieties are identified with the new rule, **Then** the check reports:
   - the number of condensed reacting bonds and of non-zero entries of `CRB2R`, old against new;
   - the largest and median number of reactions per bond;
   - the cover size, old (2,399 reactions) against new;
   - the number of condensed reacting bonds no reaction changes (FR-005).
2. **Given** the same run, **When** the new `CRB2R` is compared with the old one, **Then** every new non-zero entry is a non-zero entry of the old rule for the same condensed edge. Changing a bond moves its end atoms, so the new rule can only remove entries. The one exception is entries that come from other bonds merged into the edge (FR-003); the check counts these separately.
3. **Given** the same run, **When** the conserved-moiety outputs are compared with the 2026-11-05 run (`vmhcollapsed_20261105_142523`), **Then** they are identical.

---

### Edge Cases

- **A condensed edge that merges several atom-level reacting bonds** (several reacting bonds between the same two atom-transition components): see FR-003.
- **A condensed reacting bond that no reaction changes.** Bonds are labelled reacting by the bond-isomorphism rule (`IsomorphismClass == 0`), not from the per-reaction labels. So a bond may be labelled reacting although no reaction breaks or forms it. Its row would be empty, and the set cover could not cover it. Such rows are excluded from the cover's constraints, as rows with no reaction already are today, and counted in the output (FR-005).
- **A reaction with several molecules of the same metabolite** (stoichiometric coefficient > 1): the labels come from each RXN file, which numbers each molecule separately, so no pairing of molecules is needed.
- **Reactions with no RXN file, or whose bond mappings failed to parse**: they have no bond labels and get an all-zero column. The builder already warns when it skips a file.
- **Energy pseudo-nodes** (one per reaction, which broken and formed bonds connect to in `dBTM`): not bonds, so never rows of `CRB2R`.
- **The set cover selects no reactions**: still a valid outcome. The `RM_sets` / `RM_graph` behaviour stays as it is (`{}`).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `identifyConservedReactingMoieties` must set $\text{CRB2R}_{b,R} = 1$ exactly when reaction $R$ breaks, forms or changes the order of condensed reacting bond $b$, and 0 otherwise. Which bonds change in which reaction is taken from the per-reaction bond labels the builder already computes from the RXN files (broken −1, formed +1, conserved 0, with a double bond split into two bonding interactions). The rule "any atom transition of $R$ touches either end atom of $b$" is no longer the default.
- **FR-002**: `identifyConservedReactingMoieties` must receive these per-reaction bond changes. The existing calls `(model, BG, dATM, options)` must keep working for conserved-moiety-only runs (`options.conservedMoietiesOnly = true`), which don't use `CRB2R`. In full mode without the bond changes, the function must stop with an error naming the missing input (VII-C), not fall back silently. The exception is `options.reactingBondIncidence = 'endAtom'` (FR-006).
- **FR-003**: When several atom-level reacting bonds fall on the same pair of atom-transition components, they are merged into one condensed edge, as today. Its row of `CRB2R` must be the union of the reactions that change any of the merged bonds. The paper doesn't say how to label a merged edge (its condensation matrix $Z$, eq. 31, is not defined); the union loses no bond change. The current code keeps only the first merged bond's `BondIndex` and its two atoms; that choice is not kept.
- **FR-004**: A new test fixture adds, to a copy of the paper's example, one reaction that moves a reacting bond's metabolite without changing any of its bonds (US1 AS1). The test is added to `testConservedReactingMoieties.m` (III-Naming), and it is written and shown to fail on the unchanged source before the change. A second assertion checks a bond-order change (US1 AS3) on an existing fixture reaction, or on a small added one if none exists.
- **FR-005**: The `reacting` output must record which condensed reacting bonds no reaction changes (an index or logical vector), so a run can report them. These rows are left out of the cover's constraints. It must also count the broken or formed bonds that land on no condensed reacting bond, with a visible warning when there are any (VII-B). That count is the check that the reacting-bond label and the per-reaction bond changes agree.
- **FR-006**: The current end-atom rule must stay available as a non-default option, so earlier results can be reproduced: `options.reactingBondIncidence`, either `'bondChange'` (default, FR-001) or `'endAtom'` (today's rule, unchanged, including its use of the first merged bond only). With `'endAtom'` the per-reaction bond changes are not needed, and the reacting outputs must equal today's golden references (`isequaln`), so FR-008 keeps those beside the recaptured ones. An unknown value raises an error naming the option.
- **FR-007**: Conserved-moiety outputs (`arm.L`, `arm.M2M`, `arm.M2R`, `moietyFormulae`, `arm.ATG`, `arm.MTG`, `arm.MG`) must be identical (`isequaln`) before and after on every fixture. Only `reacting` fields may change: `CRB2R`, the cover, `ReactMoietyMatrix`, `ReactMoietySets`, `ReactMoietyGraphs`, and the new field of FR-005. `Condensed_RBG` changes only if FR-003 chooses not to merge.
- **FR-008**: Golden references whose `reacting` fields change are recaptured by a capture script in this feature's directory, with a per-field old-against-new difference report that is part of the review: `conservedReactingMoietiesReference.mat` (6 cases) and `reactingMoietyMemoryReference.mat` (10 cases). Their stored `BG` and `dATM` inputs are not rebuilt; the per-reaction bond changes are added to them from the same builder run. Today's references are kept, under new names, for the `'endAtom'` test (FR-006).
- **FR-009**: Non-CI check (US3): a script in this feature's directory runs the full collapsed VMH network and writes the report of US3 AS1–AS3. The project driver's build checkpoint does not save the bond transition multigraph, so the check rebuilds the multigraph (about 1 h 41 min) unless a checkpoint containing the bond changes is supplied.
- **FR-010**: Help text and provenance follow VII-E. The function's header states the rule with its paper reference (§6.1, eq. 32), names the new input and the FR-005 output field, and describes `options.reactingBondIncidence`, with R5 rewritten: `'bondChange'` as the paper's rule, `'endAtom'` as "reactions whose atom transitions touch either endpoint atom".

### Key Entities

- **Condensed reacting bond**: an edge of `Condensed_RBG` joining two atom-transition components; a row of `CRB2R`.
- **Per-reaction bond change**: a bond (one bonding interaction of it, for a multiple bond) that a reaction breaks or forms, as labelled from that reaction's RXN file.
- **Bond-change incidence (`CRB2R`)**: the binary matrix, condensed reacting bonds × reactions, recording which reactions change which condensed bond. It is the paper's set-cover matrix $A$.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the fixture with the added non-changing reaction, that reaction's `CRB2R` column is zero and it is not in the cover. The same assertion fails on the unchanged source.
- **SC-002**: On every CI fixture, each `CRB2R` row equals the set of reactions the RXN files label as changing that bond (or the union over its merged bonds, FR-003).
- **SC-003**: The Fig. 11 test passes unchanged (4 vertices, 6 bonds, the three bond sets, a cover of 2).
- **SC-004**: Conserved-moiety outputs are identical before and after on every fixture (FR-007), and on the full collapsed VMH network (US3 AS3).
- **SC-005**: On the full collapsed VMH network, the report of US3 AS1–AS2 is produced. Every new `CRB2R` entry that doesn't come from a merged bond is also an entry of the old rule. The cover size and per-bond reaction counts are reported, not gated: there is no reference value for them.
- **SC-006**: All tests in `test/verifiedTests/analysis/testReactingMoieties/` pass. The recaptured references come with a reviewed per-field difference report.

## Assumptions

- **Base**: the fork's `develop` at `ad0d11d60`, which includes whole-molecule bond renumbering (PR #11) and conserved-bond-group pruning (PR #12).
- **Which bonds are reacting** stays as it is: the bond-isomorphism label (`IsomorphismClass == 0`). This feature changes only which reactions each reacting bond is recorded against. The paper's §4.1 rule labels three more atom-level bonds on the paper's example, but gives the same condensed graph (reconXmoieties E31). That rule (and the largest-isomorphism-group question in reconXmoieties `docs/known-defects.md`, 2026-10-16) is out of scope.
- **The RXN files' bond labels are correct.** They come from the same atom mappings that build `dATM`, so the two agree on which atoms move. The non-CI check (FR-009) would show any reaction whose bond labels mark a bond its atom transitions don't touch: those are entries outside the old rule (SC-005).
- **Downstream reconXmoieties work** (passing the bond changes from the project driver `runAtomMappedMoietyPipeline`, saving them in the build checkpoint, rerunning reacting-moiety results, and updating the manuscript) is reconXmoieties' work, not this feature's.
- **Rhea** is not checked by this feature: its full network has not yet been rerun on the fixed builder.

## Out of Scope

- **The rule that labels a bond reacting** (`IsomorphismClass == 0` against the paper's §4.1 rule).
- **Atom-level pairing of interchangeable atoms** in `dATM` (KI-001).
- **Choosing among several minimal covers.** The cover is still any minimal one the solver returns.
- **Performance.** The reacting stage takes under 1.2 s at every measured size (reconXmoieties E28), so no time target is set; the non-CI check reports the time.

## Traceability

| Acceptance criterion | Discharging test | src/analysis/topology/reactingMoieties/ function under test |
|----------------------|------------------|-----------------------------------|
| US1 AS1 / FR-001, FR-004, SC-001 | testConservedReactingMoieties.m (added non-changing reaction; red before green) | identifyConservedReactingMoieties |
| US1 AS2 / FR-001, FR-003, SC-002 | testConservedReactingMoieties.m (each row equals the labelled bond changes, every fixture) | identifyConservedReactingMoieties |
| US1 AS3 / FR-004 | testConservedReactingMoieties.m (bond-order change) | identifyConservedReactingMoieties |
| US2 / SC-003 | testConservedReactingMoieties.m (existing Fig. 11 test, unchanged) | buildAtomAndBondTransitionMultigraph, identifyConservedReactingMoieties |
| FR-002 | testConservedReactingMoieties.m (conserved-only call without bond changes works; full mode without them errors) | identifyConservedReactingMoieties |
| FR-005 | testConservedReactingMoieties.m (unchanged bonds recorded and left out of the cover) | identifyConservedReactingMoieties |
| FR-006 | testConservedReactingMoieties.m (`'endAtom'` reproduces today's references; unknown value errors) | identifyConservedReactingMoieties |
| FR-007, SC-004 | testConservedReactingMoieties.m (conserved outputs unchanged) + non-CI check | identifyConservedReactingMoieties |
| FR-008, SC-006 | testConservedReactingMoieties.m (recaptured golden comparison) + difference report | identifyConservedReactingMoieties |
| US3 / FR-009, SC-005 | non-CI check script in this feature's directory | identifyConservedReactingMoieties |
| FR-010 | -- (static review) | -- (no source function) |
