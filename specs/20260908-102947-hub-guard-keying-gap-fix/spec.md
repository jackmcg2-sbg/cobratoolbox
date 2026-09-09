# Feature Specification: Uniform WL-Colour Keying for Guard-Blocked Symmetric Atom Classes

**Feature Branch**: `20260908-hub-guard-keying-gap-fix`

**Created**: 2026-09-08

**Status**: Draft

**Input**: User description: an independent, larger-scale validation of feature
020-canonicalize-symmetric-atom-bonds (`identifyAtomEquivalenceClasses.m`, merged to `develop`
via PR #2693) — `experiments/moietySizing/scripts/validate_symmetric_atom_classes_matlab.m`
(reconXmoieties) run over a stratified sample of 327 metabolites from the full single-resource
RXN corpus (VMH: `/media/JACK/repos/ctf/rxns/atomMapped_standardised`; Rhea:
`/media/JACK/repos/ctf/rxns/rhea_atomMapped/rxnfiles/atomMapped`) — found 93/327 (28%) metabolites
still fail feature 020's own success criterion (`fixedUnionCount == trueBondCount` across every
instance file a metabolite appears in), with 0 falling into feature 020's FR-011 "inconclusive,
falls back and warns" path: every failure is a silent wrong answer. Root-cause investigation
(see `../20260908-102947-hub-guard-keying-gap-fix/PROPOSAL.md`, and this feature's own
`research.md` below) found one mechanism fully explains all 93: `identifyAtomEquivalenceClasses.m`
correctly *detects* every metabolite's true symmetry-equivalence classes (its WL colour
refinement and automorphism cross-check both work), but its "unsafe neighbour" guard — added to
prevent the mirrored-bond collision bug fixed in `72c4c441b` — has only one response when it
fires: leave both atoms' raw, file-specific atom numbers untouched. Since "a hub bonded to two or
more chemically-equivalent branches" (a phosphate's non-bridging oxygens, a carboxylate's two
oxygens, a methyl's three hydrogens, an ammonium's methyls) is the single most common real-world
symmetry shape — not a corner case — this guard fires almost universally, and 100% of the 93
failures have every one of their genuinely-symmetric classes fully guard-blocked. A prototyped
fix — key every atom (not only guard-blocked ones) by its final WL-colour-refinement class plus a
deterministic within-class rank, instead of raw atom number — resolves 21/93 (22.6%); the
remaining 72/93 are a structurally distinct, separate problem (cross-file resonance/protonation-
depiction instability — the RXN files for "the same" metabolite are not actually graph-isomorphic
to begin with) and are explicitly out of scope for this feature (logged separately in project
memory `hub_guard_keying_gap_and_resonance_instability.md` for a future, differently-shaped fix).

## Clarifications

### Session 2026-09-08

- Q: Should this feature also attempt to fix the cross-file resonance/protonation-depiction
  instability (the ~77% majority of the 93 known failures)? → A: No — explicit product decision.
  That problem needs its own upstream-standardisation design (thought through separately, outside
  this feature) rather than a graph-canonicalization patch, and is structurally unrelated to the
  guard-keying gap this feature fixes. Folding it in here would risk an under-designed fix for the
  harder, larger problem while delaying the smaller, already-validated one.
- Q: Is this a reopening of feature 020, or a new feature? → A: A new, dependent feature. 020's
  own tasks.md is fully complete and its own corpus-scale validation (T022, 400 files) passed at
  the time; this gap was only surfaced by a materially larger (327-metabolite), independently-run
  validation afterward. Per this repository's own precedent (`72c4c441b` fixed a similarly-scoped
  guard defect found via 020's own T022 corpus-scale check, within 020's branch, before merge) —
  but since 020 is already merged, the fix belongs in a new feature branch, informed by and
  cross-referencing 020's spec/research/plan rather than duplicating them.
- Q: What is the success bar — must this feature resolve all 93 known failures? → A: No. Success
  is resolving every failure attributable to genuine cross-instance atom-numbering divergence
  (both the originally-diagnosed guard-blocked shared-hub case and the more general case
  discovered during implementation, R-CONSOL below), with the remaining resonance/protonation-
  instability failures explicitly confirmed as out of scope, not silently left unaddressed or
  miscounted as "fixed."

### Session 2026-09-08, implementation-attempt revision

A real `/speckit-implement` attempt against this spec's original mechanism (substitute a
`(colourClassId, rank)` key in place of the guard-blocked fallback branch, before
`canonicalBondKey`/`resolveAtomNodeIndex` run) halted twice on grounded, MATLAB-verified
contradictions — recorded in full in `implementation-blocker-findings.md` and
`research-revision.md` in this directory. In summary:

- **Finding 1**: the original mechanism's FR-004/FR-005 ("singleton atoms keep byte-for-byte raw
  atom-number keys") directly contradicts SC-001 (`5pmev[x]` must fully resolve to 23 bonds),
  because `5pmev[x]`'s two real instance files do not agree on atom row order at all (confirmed:
  13 of 24 rows differ in element between them) — a case broader than "guard-blocked symmetric
  atoms," and one that also breaks an existing hardcoded-string regression assertion in
  `testConservedReactingMoieties.m` for `crn[m]` if applied uniformly.
- **Finding 2**: `resolveAtomNodeIndex.m` (feature `20260902-150020-eliminate-bond-transition-
  ismember-scans`, not cross-checked during this feature's original research) hard-errors unless
  the atom number fed to it matches a real, already-existing node — so no synthetic
  `(colourClassId, rank)`-style key can ever work, regardless of how it is encoded.

Root cause, confirmed by reading the current source directly (`research-revision.md`): the
shipped feature 020 mechanism computes equivalence classes from only the first-seen instance file
of each metabolite and applies that file's rank map to every other instance via a **silent,
unguarded pass-through** — no detection, no warning — when a later instance's raw numbering
doesn't match. This assumes universal cross-instance row-order stability, which research R2/R6
established only for the specific metabolites checked at the time, and which does not hold for
`5pmev[x]`.

- Q: Given both findings, how should the fix be re-scoped? → A: **Post-hoc `dBTM` consolidation
  pass** (Jack's choice, from four options including an upstream isomorphism-remap alternative, a
  narrow detect-and-warn-only patch, and pausing entirely). `canonicalBondKey.m`,
  `resolveAtomNodeIndex.m`, and `identifyAtomEquivalenceClasses.m`'s existing within-instance
  guard logic are **not modified** — `dBTM` is built exactly as it is today, and a new, separate
  pass runs afterward, merging bond-nodes that a verified cross-instance graph-isomorphism
  correspondence confirms are the same physical bond. Full design in `research-revision.md`. This
  supersedes this spec's and `plan.md`'s original "replace the fallback branch" mechanism
  throughout the remainder of this document.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cross-Instance Atom-Numbering Divergence Canonicalizes Consistently Across Files (Priority: P1)

A COBRA Toolbox developer runs the moiety-identification pipeline over a model containing
reactions that share a metabolite whose independently-generated RXN-file instances disagree on
raw atom numbering — whether because a symmetry-equivalence class has a shared hub (feature 020's
unsafe-neighbour guard blocks substitution for these, e.g. a phosphate's non-bridging oxygens or a
methyl's three hydrogens) or because two instances' atom row order diverges more broadly for a
metabolite that is nonetheless the same physical molecule in both files (confirmed for `5pmev[x]`:
13 of 24 rows differ in element between its two instances, yet the graphs are isomorphic). Today,
both cases leave the affected bonds' cross-file keys unreconciled — the guard-blocked case because
`safeCanonicalizeOneAtom` has no fallback but the raw, file-specific number; the broader case
because the shipped mechanism never checks whether a later instance's numbering matches the
first-seen instance it cached a rank map from, and silently no-ops when it doesn't. After the fix,
a new post-hoc `dBTM` consolidation pass (see `research-revision.md`) verifies a graph-isomorphism
correspondence between each non-reference instance and its metabolite's cached reference instance,
and merges bond-nodes the correspondence confirms are the same physical bond — closing both cases
for every metabolite whose instances are genuinely graph-isomorphic (structurally consistent),
without changing `canonicalBondKey.m`, `resolveAtomNodeIndex.m`, or the existing guard logic at
all.

**Why this priority**: This is the actual, now fully-diagnosed defect. It is also the only
functional requirement in this feature — everything else (US2, US3) exists to keep the fix from
introducing a worse regression than the bug it fixes, exactly as feature 020's own priority
structure did for its fix.

**Independent Test**: Rebuild `dBTM` for a model containing exactly `MEVK1x` and `PMEVKx` (both
sharing `5pmev[x]`, 5-phosphomevalonate — a small, already-diagnosed worked example, confirmed
graph-isomorphic despite full row-order divergence between its two instances, see
`research-revision.md`), confirming `5pmev[x]` resolves to exactly 23 bond nodes (its true bond
count) rather than 43-46 (the pre-fix inflation observed on this exact pair).

**Acceptance Scenarios**:

1. **Given** a metabolite whose independently-generated RXN-file instances are graph-isomorphic
   but disagree on raw atom numbering (whether via a guard-blocked symmetric class or broader
   row-order divergence), **When** the consolidation pass verifies a correspondence between a
   non-reference instance and the metabolite's cached reference instance, **Then**
   `buildAtomAndBondTransitionMultigraph.m` resolves bonds to/from the corrected atoms to the same
   canonical bond-node identity across all such instances.
2. **Given** the `5pmev[x]` worked example (`MEVK1x.rxn`/`PMEVKx.rxn`), **When** the multigraph is
   rebuilt after this fix, **Then** it resolves to exactly 23 bond nodes with no bond-count
   mismatch.
3. **Given** the 93-metabolite failure set already catalogued by
   `validate_symmetric_atom_classes_matlab.m` (reconXmoieties), **When** the harness is rerun
   after this fix, **Then** every metabolite whose instances are genuinely graph-isomorphic
   (verified by the consolidation pass, not merely aggregate-consistent — see FR-006) newly
   passes crit1.

---

### User Story 2 - No Regression For Feature 019/020's Fixes Or Any Currently-Passing Metabolite (Priority: P2)

A COBRA Toolbox developer relies on `dBTM` output for metabolites already handled correctly —
whether because they have no symmetry at all (feature 019's domain), or because their instances
already canonicalize correctly today (a subset of feature 020's domain, including cases feature
020 fixed like `coa[m]`/`coa[x]`/`coa[r]`/`crn[m]`, and the mirrored-bond collision-guard fixture
from `72c4c441b`, `gthox[c]`-shaped). After this fix, none of these regress: `canonicalBondKey.m`,
`resolveAtomNodeIndex.m`, and `identifyAtomEquivalenceClasses.m`'s existing guard logic are
unmodified, and the new post-hoc consolidation pass only ever renames a bond-node identity when it
has *verified* (by direct edge-set comparison, not assumed) that a correction is correct — a
metabolite whose reference and non-reference instances already agree produces zero corrections,
by construction.

**Why this priority**: The new pass runs over every multi-instance metabolite in the model, not
only the ones known to be broken today — an unverified or incorrectly-verified correspondence
could merge two bond-nodes that are not actually the same physical bond, which would be a more
severe regression than the bug being fixed (mirrors feature 020's own User Story 2 concern one
level up).

**Independent Test**: Rebuild `dBTM` before and after the fix for every existing regression
fixture referenced by `testConservedReactingMoieties.m`, `testCanonicalBondKey.m`, and
`testIdentifyAtomEquivalenceClasses.m` (feature 019's `r0317`/`ACONTm`/`r0426`/`crn[c]` cases,
feature 020's `coa[m]`/`coa[x]`/`coa[r]`/`crn[m]` cases, and the synthetic 20-atom-chain and
fault-injection cases already covered by `testIdentifyAtomEquivalenceClasses.m`), and confirm
node counts, edge counts, and keys are unchanged for every metabolite/case that already passed.

**Acceptance Scenarios**:

1. **Given** a metabolite whose instances already agree on atom numbering wherever
   `canonicalBondKey.m`'s existing sort already resolves them correctly (e.g. `crn[m]`'s atoms 3
   and 5, confirmed row-stable across its two real instances by research R2), **When** the
   consolidation pass runs, **Then** it records zero corrections for that bond and the existing
   literal-string test assertion (`testConservedReactingMoieties.m:29`) is unaffected.
2. **Given** `coa[m]`/`coa[x]`/`coa[r]`/`crn[m]` (020's fixed cases), **When** rebuilt after this
   fix, **Then** they continue to resolve to their true bond counts (82, 82, 82, 25 respectively)
   with no new mismatch.
3. **Given** `crn[c]` (019's fixed case) and 019/020's other existing regression fixtures, **When**
   rebuilt after this fix, **Then** node counts, edge counts, and keys are byte-for-byte unchanged.
4. **Given** the two-fold mirrored-bond collision scenario `72c4c441b` fixed, **When** the fix is
   applied, **Then** the cross-class/cross-bond collision guard already present in
   `identifyAtomEquivalenceClasses.m` continues to prevent the collision, since this fix does not
   modify that guard, its call site, or `dBTM`'s initial (pre-consolidation) construction at all.
5. **Given** a candidate cross-instance correspondence the consolidation pass cannot verify by
   direct edge-set comparison (step 4 of the design in `research-revision.md`), **When** the pass
   runs, **Then** it does NOT apply that correction — the affected instance's bonds are left
   exactly as today's baseline produces them, never merged on an unverified guess.

---

### User Story 3 - Confirm The Fix's Real-World Impact At Corpus Scale, Honestly (Priority: P3)

A COBRA Toolbox developer needs to know, after implementing the fix, exactly how much of the
known 93-failure gap it closes — not assume it closes all of it, and not undercount what it does
close due to a stale baseline.

**Why this priority**: The 21/93 (22.6%) figure originally cited was measured via an independent
Python prototype using a *synthetic*-key scheme now known to be unimplementable (Findings 1/2);
the actual mechanism shipped here (verified cross-instance isomorphism + real-node merge) is
expected to close at least that many cases and, per the `5pmev[x]` re-check during the redesign
(confirmed resolvable by the same underlying WL-colour matching, `research-revision.md`), plausibly
more — but this must be *measured*, not assumed, against a live MATLAB run.

**Independent Test**: Rerun `experiments/moietySizing/scripts/validate_symmetric_atom_classes_matlab.m`
(reconXmoieties) over the same 327-metabolite stratified sample (or a fresh equivalent sample, if
the corpus has changed) after implementation, and catalogue: (a) how many of the previously-93
failing metabolites now pass crit1, (b) for each metabolite that still fails, confirm the
consolidation pass genuinely found no verifiable isomorphism between its instances (not that it
was never attempted, and not that verification was skipped for an implementation reason) — i.e.
confirm the failure is Diagnosis 2, out of scope — and (c) confirm no metabolite that passed crit1
before the fix newly fails after it.

**Acceptance Scenarios**:

1. **Given** the 327-metabolite corpus-validation harness, **When** rerun post-fix, **Then** every
   metabolite whose instances are genuinely graph-isomorphic (this feature's entire target set,
   verified by the consolidation pass itself, not by a coarser aggregate check) now passes crit1.
2. **Given** any metabolite that still fails crit1 post-fix, **When** inspected, **Then** the
   consolidation pass's own verification step is confirmed to have failed for it (no isomorphism
   found between its instances), and this is recorded, not silently absorbed into "expected
   residual failures."
3. **Given** the 327-metabolite corpus-validation harness, **When** rerun post-fix, **Then** the
   pass count for crit1 is >= its pre-fix count (no new failures introduced among the 234
   previously-passing metabolites).

### Edge Cases

- A metabolite has more than one non-reference instance, and different non-reference instances
  require *different* corrections to converge on the reference's numbering — each instance's
  correspondence must be computed and verified independently against the reference (never against
  another non-reference instance), so a correction never depends on processing order among
  non-reference instances.
- Two RXN-file instances of the same metabolite are not actually graph-isomorphic (Diagnosis 2 —
  different bond order/charge placement at chemically-equivalent atoms, e.g. `acgam1p[c]`'s mono-
  vs. di-anionic phosphate) — per the Clarifications above, this feature explicitly does not
  attempt to fix these; the consolidation pass's own colour-class-signature mismatch (or, failing
  that, its direct edge-set verification step) must detect and skip these, and the acceptance
  criteria (US3) require them to be *identified and reported as out of scope*, not silently
  swallowed into a "still fails" bucket indistinguishable from a genuine regression.
- A metabolite has only one instance in a given model build — the consolidation pass has nothing to
  consolidate against and must be a no-op for it (not attempt a self-comparison, not error).
- A metabolite's instances are graph-isomorphic but the colour-class-based correspondence search
  (step 3 of the design) yields a candidate bijection that does NOT survive direct edge-set
  verification (step 4) — per US2 Acceptance Scenario 5, this must fail safe (no merge applied),
  not apply a best-effort/partial correction.
- The reference instance itself is never corrected (nothing to correct it against) — for a
  metabolite whose reference instance happens to be processed multiple times (e.g. it appears in
  more than one reaction), its own bond keys are already self-consistent by construction (feature
  020, unchanged) and the consolidation pass must recognize this and skip it, not attempt a
  self-to-self isomorphism check.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: After `dBTM` is fully constructed (its existing `.Nodes`/`.Edges` derivation via
  `mapAontoBOld`, unchanged), a new consolidation pass MUST, for every metabolite with more than
  one distinct RXN-file instance, attempt to verify a graph-isomorphism correspondence between
  each non-reference instance's own atoms and the metabolite's cached reference instance's atoms
  (the first-seen instance `identifyAtomEquivalenceClasses` already runs on today).
- **FR-002**: Where a correspondence is found and verified (by direct edge-set comparison under
  the candidate mapping — not assumed from colour-class-shape agreement alone), the pass MUST
  recompute that instance's affected bonds' canonical identity as if built from the reference
  instance's own atom numbers, and merge the corresponding `dBTM` bond-nodes accordingly (by
  correcting the affected `EdgeTable` identity columns and reconstructing `dBTM` via `digraph(...)`
  a second time — the same node-deduplication-by-name mechanism already used to build `dBTM` the
  first time, not new merge machinery).
- **FR-003**: `canonicalBondKey.m`, `resolveAtomNodeIndex.m`, and
  `identifyAtomEquivalenceClasses.m`'s existing within-instance unsafe-neighbour guard and
  cross-class/cross-bond collision guard (the mechanisms that prevent the `72c4c441b` mirrored-
  bond collision) MUST NOT be modified by this feature. `dBTM`'s initial construction (before the
  new consolidation pass runs) MUST be byte-for-byte identical to today's.
- **FR-004**: Where no verified correspondence exists for a non-reference instance (colour-class
  shapes don't match between it and the reference, or a candidate bijection fails direct edge-set
  verification), the consolidation pass MUST leave that instance's bonds exactly as today's
  baseline (pre-consolidation `dBTM`) produces them — no partial, best-effort, or unverified
  correction is ever applied.
- **FR-005**: For every existing regression fixture from feature 019 (`r0317`/`ACONTm`/`r0426`,
  the `crn[c]` 3-reaction case) and feature 020 (`coa[m]`/`coa[x]`/`coa[r]`/`crn[m]`, and
  `testIdentifyAtomEquivalenceClasses.m`'s existing synthetic-chain and fault-injection cases),
  node counts, edge counts, keys, and derived diagnostic outputs MUST be unchanged by this fix —
  including any fixture where the consolidation pass runs but finds nothing to correct (US2
  Acceptance Scenario 1).
- **FR-006**: After the fix, rerunning `validate_symmetric_atom_classes_matlab.m`
  (reconXmoieties) over the 327-metabolite stratified sample used during investigation MUST show:
  every metabolite whose instances are genuinely graph-isomorphic (verified, not merely
  aggregate-consistent — see the `5pmev[x]` counter-example in `research-revision.md`, which
  passes an aggregate atom/bond/charge/element-histogram check yet has 13 of 24 rows diverge) now
  passes crit1; every metabolite that still fails is confirmed to have failed the consolidation
  pass's own isomorphism verification (Diagnosis 2, out of scope); and the total crit1 pass count
  does not decrease relative to the pre-fix baseline (234/327).
- **FR-007**: The fix MUST be implemented entirely within the existing MATLAB pipeline (a new
  function alongside `identifyAtomEquivalenceClasses.m` and `buildAtomAndBondTransitionMultigraph.m`
  in `src/analysis/topology/reactingMoieties/`), consistent with feature 020's own FR-008 scoping
  decision — no change to the chemPy/RDT RXN-generation toolchain.
- **FR-008**: This feature MUST NOT attempt to detect or reconcile cross-instance structural
  inconsistency (Diagnosis 2 — differing formal bond order or charge placement between RXN-file
  instances of the same metabolite at chemically-equivalent positions, or any other case the
  consolidation pass's own verification step correctly rejects). A metabolite failing for that
  reason MUST continue to fail exactly as it does pre-fix (no new, half-designed reconciliation
  logic), and MUST be distinguishable in US3's validation output from a metabolite this feature
  failed to fix.
- **FR-009**: The consolidation pass's cost MUST be bounded per metabolite (one colour-class
  computation and one verification pass per non-reference instance, not a combinatorial search),
  consistent with feature 020's existing per-metabolite caching philosophy (`metBondCountGroundTruth`-
  style) — reference-instance data (atoms, bonds, colour partition) is cached once per metabolite
  and reused for every non-reference instance's comparison, not recomputed per comparison.
- **FR-010**: For every downstream consumer of the changed node/edge fields
  (`identifyConservedReactingMoieties.m`, `identifyConservedReactingSubgraphs.m`,
  `extractBondSubgraphs.m`), this fix MUST NOT change that consumer's output for any metabolite
  the consolidation pass leaves uncorrected, and any change to previously-affected metabolites'
  output MUST be attributable to a verified correction alone (mirrors feature 020 FR-010).
- **FR-011**: Where the consolidation pass corrects two or more bond-nodes with different
  first-seen bond types (feature 020 FR-003's `metBondTypeFirstSeen` cache, keyed by bond-ID
  string) into one merged node, the merged node's bond type MUST be resolved deterministically —
  whichever bond type was recorded first by original reaction-processing order among every node
  that now collapses onto the corrected identity, not an arbitrary or last-write-wins choice. This
  interaction MUST be designed explicitly during implementation (`research-revision.md`), not left
  implicit.

### Key Entities

- **Reference Instance**: The first-seen RXN-file instance of a metabolite (already the instance
  `identifyAtomEquivalenceClasses` runs on today) — its own bond-node keys are never corrected by
  this feature; every other instance's keys are corrected, when verifiably possible, to match it.
- **Cross-Instance Atom Correspondence**: A verified bijection from a non-reference instance's own
  raw atom numbers to the reference instance's raw atom numbers, established by matching
  WL-colour-refinement class signatures between the two instances' own graphs and confirmed by
  direct edge-set comparison under the candidate mapping (not assumed from colour-class-shape
  agreement alone, and never a synthetic value — always a real, reference-instance atom number,
  satisfying `resolveAtomNodeIndex`'s constraint by construction, since correction happens after
  node resolution, not before).
- **Structurally-Consistent (Aggregate) vs. Graph-Isomorphic (Verified)**: Two distinct notions
  that earlier investigation conflated. Aggregate consistency (same atom count, bond count,
  element histogram, total charge) is necessary but *not sufficient* — `5pmev[x]` satisfies it
  while still having 13 of 24 rows diverge between instances. This feature's actual precondition
  is graph isomorphism, verified directly by the consolidation pass (FR-001/FR-002), not the
  coarser aggregate check used in earlier diagnostic scripts (`hubguard_diagnostic.py`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `5pmev[x]` (from `MEVK1x.rxn`/`PMEVKx.rxn`) resolves to exactly 23 bond-graph nodes
  (its true bond count) after the fix, down from 43-46 pre-fix, with no bond-count mismatch —
  re-confirmed feasible under the consolidation-pass design (`research-revision.md`) despite its
  full row-order divergence between instances.
- **SC-002**: Rerunning `validate_symmetric_atom_classes_matlab.m` over the 327-metabolite sample
  shows the crit1 pass count increase from the pre-fix baseline (234/327, 71.6%) by at least the
  count of metabolites whose instances are genuinely graph-isomorphic among the original 93
  failures — a live MATLAB measurement, not assumed to reproduce the original (now-superseded)
  21/93 Python-prototype figure (see FR-006, US3).
- **SC-003**: Every metabolite in the 327-metabolite sample that passed crit1 pre-fix (234/327)
  still passes post-fix — zero regressions.
- **SC-004**: Every metabolite that still fails crit1 post-fix is confirmed, and recorded, as
  having failed the consolidation pass's own isomorphism verification (Diagnosis 2) — none are
  unexplained.
- **SC-005**: Feature 019's and 020's existing regression fixtures (`r0317`/`ACONTm`/`r0426`/
  `crn[c]`/`coa[m]`/`coa[x]`/`coa[r]`/`crn[m]`) and `testIdentifyAtomEquivalenceClasses.m`'s
  existing synthetic-chain and fault-injection assertions continue to hold, unchanged, after this
  fix.
- **SC-006**: Every downstream consumer identified during investigation
  (`identifyConservedReactingMoieties.m`, `identifyConservedReactingSubgraphs.m`,
  `extractBondSubgraphs.m`) produces output changes, before vs. after the fix, limited to the
  intended correction for previously-uncorrected metabolites, with no other behavioral difference.

## Assumptions

- The 93-failure/327-metabolite baseline is a 2026-09-08 snapshot
  (`validate_symmetric_atom_classes_matlab.m` run against the corpus paths in the Input section
  above). The corpus can drift (research.md `vmh_rxn_corpus_drift.md`, project memory);
  implementation MUST re-run the validation harness against the live corpus at implementation time.
  The original 21/93 figure is superseded (it was measured against a mechanism now known to be
  unimplementable) — FR-006/SC-002 state the real requirement as "every graph-isomorphic failure
  now passes," not a fixed count.
- `identifyAtomEquivalenceClasses.m`'s existing colour-refinement computation (WL colour classes)
  is itself correct and reused, unmodified, by the new consolidation pass (both for the reference
  instance, as today, and for each non-reference instance's own partition, newly computed) —
  confirmed by direct inspection and by an independent Python port validated against real MATLAB
  behaviour during investigation.
- Diagnosis 2 (cross-instance structural inconsistency / resonance-protonation-depiction
  instability) is a separate, larger problem (~77% of the originally-known 93 failures, on the
  now-superseded diagnosis) requiring its own, differently-shaped design (likely upstream
  standardisation at RXN-generation time, not a downstream graph-canonicalization patch) —
  explicitly out of scope here, per product decision (Clarifications). See project memory
  `hub_guard_keying_gap_and_resonance_instability.md` for the deferred design discussion and a
  worked example (`acgam1p[c]`) reserved for that future work.
- MATLAB's `isisomorphic`/graph-matching machinery (already used in this codebase by
  `identifyAtomEquivalenceClasses.m`'s `pairIsGraphAutomorphic` for within-instance automorphism
  verification, and by `identifyIsomorphicClasses.m`/`classifySubgraphIsomorphism.m` for
  subgraph-isomorphism classification, feature 021) is assumed sufficient, generalized from
  within-graph to between-graph comparison, for this feature's direct edge-set verification step
  (FR-002) — no new third-party dependency. The colour-class-signature matching step (FR-001) is a
  cross-instance generalization of the WL-colour-refinement loop `identifyAtomEquivalenceClasses.m`
  already implements, reusing its per-round compact re-hashing (OOM-safety) design.
- A new source file and a new dedicated test file are required (unlike this feature's original,
  now-superseded design, which needed neither) — see `plan.md`'s Project Structure.

## Traceability

| Acceptance criterion | Discharging test | src/<domain>/ function under test |
|----------------------|------------------|-----------------------------------|
| US1 / FR-001, FR-002, SC-001 | New regression test: rebuild `dBTM` for `MEVK1x`/`PMEVKx` (`5pmev[x]`), confirm 23 nodes, no mismatch | src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m, new consolidation-pass function |
| US1 / FR-006, SC-002, SC-004 | Corpus-scale rerun of `validate_symmetric_atom_classes_matlab.m` (reconXmoieties, 327-metabolite sample), before/after comparison | new consolidation-pass function |
| US2 / FR-003, FR-005, SC-003, SC-005 | Existing `testIdentifyAtomEquivalenceClasses.m`, `testCanonicalBondKey.m`, `testConservedReactingMoieties.m` rerun unchanged; explicit before/after diff on 019/020 fixtures | src/analysis/topology/reactingMoieties/identifyAtomEquivalenceClasses.m, src/analysis/topology/reactingMoieties/canonicalBondKey.m, src/analysis/topology/reactingMoieties/resolveAtomNodeIndex.m (all unmodified, diffed to confirm) |
| US2 / FR-003 (collision guard) | New/extended regression case reproducing the `72c4c441b` mirrored-bond collision shape, confirmed still prevented | src/analysis/topology/reactingMoieties/identifyAtomEquivalenceClasses.m |
| US2 / FR-004 (fail-safe on unverified correspondence) | New regression case: a candidate correspondence that fails edge-set verification, confirmed no merge applied | new consolidation-pass function |
| US2 / FR-010, SC-006 | Downstream-consumer regression on `identifyConservedReactingMoieties.m`, `identifyConservedReactingSubgraphs.m`, `extractBondSubgraphs.m` | src/analysis/topology/reactingMoieties/identifyConservedReactingMoieties.m, src/analysis/topology/reactingMoieties/identifyConservedReactingSubgraphs.m, src/analysis/topology/reactingMoieties/extractBondSubgraphs.m |
| US3 / FR-006, FR-008, SC-002, SC-003, SC-004 | Full corpus-scale scan, pre- and post-fix, with explicit isomorphism-verification-failure classification for residual failures | new consolidation-pass function |
| US1 / FR-007 | Implementation location review (MATLAB-only, no chemPy/RDT change) | new consolidation-pass function, src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m |
| US1 / FR-009 | Performance/caching review against `metBondCountGroundTruth` pattern | new consolidation-pass function |
| US1 / FR-011 (bond-type merge resolution) | New regression case: two merging nodes with different first-seen bond types, confirmed deterministic resolution | new consolidation-pass function, src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m |
