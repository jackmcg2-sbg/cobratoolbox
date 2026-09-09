# Phase 0 Research: Uniform WL-Colour Keying for Guard-Blocked Symmetric Atom Classes

**Feature**: `specs/20260908-102947-hub-guard-keying-gap-fix/spec.md`
**Plan**: [plan.md](./plan.md)

No item in plan.md's Technical Context is marked `NEEDS CLARIFICATION`. This document
consolidates the investigation already performed (`PROPOSAL.md`, `prototype/`) into the
Decision / Rationale / Alternatives format Phase 0 requires, so the record of *why* lives beside
the rest of this feature's Spec Kit artifacts rather than only in the incoming proposal.

## R1: What key replaces raw `atomNumber` in the guard-blocked fallback branch

- **Decision**: Key every atom — not only guard-blocked ones — by the pair `(final WL
  colour-refinement class id, within-class rank)`, computed independently per RXN-file instance.
- **Rationale**: The WL colour-refinement class id is a pure graph invariant, identical across
  independently-generated files of the same molecule (unlike raw atom number, which is
  file-specific numbering with no cross-file meaning). Within-class rank is a deterministic
  per-file tie-break that preserves true bond multiplicity — the same job today's raw-number
  fallback does, but reconstructed from a stable invariant instead of inherited from an unstable
  one. Validated directly on `5pmev[x]`: its own phosphorus atom (no symmetry of its own) sits at
  a different raw atom number in each of its two RXN files, confirming raw number is not a stable
  anchor even for atoms outside any equivalence class once a symmetric class exists nearby in the
  same molecule (PROPOSAL.md §3.1).
- **Alternatives considered**:
  - *Rank-within-class for guard-blocked atoms only, raw `atomNumber` unchanged for "safe" atoms*
    (`prototype_fix.py`, v1). Rejected: resolved 0/93 known failures — root-caused to exactly the
    "safe atom's raw number is not stable either" instability above (PROPOSAL.md §3.2, v1).
  - *Drop the unsafe-neighbour guard and always substitute the class canonical representative*.
    Rejected: confirmed directly (reproducing the `gthox[c]` shape `72c4c441b` fixed against the
    current guard logic) that this reintroduces the mirrored-bond collision the guard exists to
    prevent (PROPOSAL.md §3.1). This is why FR-003 requires the guard's own firing decision to be
    untouched — only what key is built from its output changes.

## R2: Where the fix is implemented

- **Decision**: `identifyAtomEquivalenceClasses.m` (expose/reuse the WL-colour class id already
  computed internally by its colour-refinement loop) and `buildAtomAndBondTransitionMultigraph.m`
  (its `safeCanonicalizeOneAtom`/`safeCanonicalizeBondAtoms` fallback branch, immediately before
  its `canonicalBondKey(...)` calls). `canonicalBondKey.m` is read, not modified.
- **Rationale**: Both files are already feature-020 source implementing exactly this
  detection-then-key-construction pipeline; confirmed by direct inspection that
  `safeCanonicalizeOneAtom` (buildAtomAndBondTransitionMultigraph.m:1003) is precisely the
  fallback branch this feature changes — it returns `atomRaw` unchanged whenever the unsafe-map
  check fires, and that is the only branch this feature touches (FR-001, FR-003).
  `canonicalBondKey.m`'s existing atom-number secondary sort already does the right thing once its
  inputs are class-canonicalized upstream (feature 020 research R6); this feature only changes the
  value fed into that sort, not the sort itself.
- **Alternatives considered**: A new detection algorithm or a new source file. Rejected: the
  WL-colour-refinement computation this feature keys off already exists and is confirmed correct
  (Assumptions, spec.md); introducing a second detection path would duplicate feature 020's
  already-validated logic for no benefit and would fail Constitution's spec-driven scope control
  (no new abstraction beyond what the task requires).

## R3: How the singleton (non-symmetric) case reduces to today's behaviour

- **Decision**: For a WL-colour class with exactly one member, `(colourClassId, 1)` must produce a
  `canonicalBondKey.m` sort key identical to today's plain raw `atomNumber` — most likely by
  keeping the singleton's own raw atom number as its class-id component, since a class of one atom
  is already uniquely identified by its sole member's raw number.
- **Rationale**: FR-004 and spec.md US2 Acceptance Scenario 1 require byte-for-byte identical
  output for every non-symmetric atom (the majority case network-wide) — this is a strict
  extension of feature 020's existing key construction, not a replacement for it.
- **Alternatives considered**: A uniform synthetic class-id scheme unrelated to raw atom number
  for singletons. Rejected: would require re-deriving that `canonicalBondKey.m`'s sort treats the
  new synthetic id identically to today's raw number in every ordering case, an unnecessary proof
  burden when reusing the raw number directly is both simpler and already known-correct. To be
  confirmed exactly during implementation (plan.md Design step 4) by reading
  `canonicalBondKey.m`'s current sort-key construction, not merely assumed.

## R4: Corpus-scale validation methodology

- **Decision**: Rerun `experiments/moietySizing/scripts/validate_symmetric_atom_classes_matlab.m`
  (reconXmoieties, external sibling repository, not vendored into this repo) over the same
  327-metabolite stratified sample used during investigation (or a fresh equivalent sample if the
  corpus has drifted), rather than trusting the Python-prototype-measured 21/93 figure or writing
  new in-repo scan tooling.
- **Rationale**: Mirrors feature 020's own research R8 decision to keep corpus-scale scanning
  tooling in the sibling repo (Constitution's artifact-placement gate: no file created under
  `experiments/` in *this* repository). The 21/93 figure is a single Python-prototype snapshot
  (2026-09-08); FR-006/SC-002 require validating "every structurally-consistent failure now
  passes," not reproducing an exact count, because the corpus can drift between investigation and
  implementation (spec.md Assumptions, `vmh_rxn_corpus_drift.md`).
- **Alternatives considered**: Trusting the Python port's 21/93 count as sufficient proof.
  Rejected: spec.md US3 explicitly requires the real MATLAB fix to be measured directly against a
  live corpus rather than assumed to reproduce a prototype's count — the Python port was a design
  aid, not a substitute for MATLAB-native validation (PROPOSAL.md §5: "Python reference
  implementations for review purposes, not the MATLAB implementation itself").

## R5: Regression proof strategy for User Story 2

- **Decision**: Rebuild `dBTM` before/after for every existing fixture referenced by
  `testConservedReactingMoieties.m`, `testCanonicalBondKey.m`, and
  `testIdentifyAtomEquivalenceClasses.m` — feature 019's `r0317`/`ACONTm`/`r0426`/`crn[c]`,
  feature 020's `coa[m]`/`coa[x]`/`coa[r]`/`crn[m]`, the synthetic-chain/fault-injection cases, and
  the `72c4c441b` mirrored-bond collision shape (`gthox[c]`) — confirming node counts, edge counts,
  and keys are unchanged for every case that already passed.
- **Rationale**: Re-keying *every* atom (not only guard-blocked ones, R1) is a broader change than
  a narrowly-scoped patch would be, so its regression surface is correspondingly broader and needs
  explicit verification at the same weight as the fix itself (spec.md US2's stated priority
  rationale, mirroring feature 020's own User Story 2 one level up).
- **Alternatives considered**: Relying only on the new corpus-scale rerun (R4) to catch
  regressions. Rejected: corpus-scale validation only checks crit1 (bond-count union), not
  byte-for-byte key identity for already-passing cases, and existing fixtures are the narrowest,
  fastest proof for FR-004/FR-005/SC-003/SC-005.
