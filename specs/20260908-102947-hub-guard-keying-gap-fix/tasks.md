# Tasks: Post-Hoc dBTM Consolidation Pass for Cross-Instance Atom-Numbering Divergence

**Input**: Design documents from `specs/20260908-102947-hub-guard-keying-gap-fix/`

**Revision note**: This replaces the original `tasks.md` (which implemented a "replace the
guard-blocked fallback branch" mechanism, halted before any source edit —
`implementation-blocker-findings.md`). **T001-T010 below reflect what was actually already done**
during the halted attempt (fixture vendoring, source inspection, pre-fix baselines) and are marked
accordingly rather than redone. Everything from T011 on implements the new, chosen mechanism (a
post-hoc `dBTM` consolidation pass) from scratch.

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md),
[research-revision.md](./research-revision.md) (the design this file implements — read it first),
[implementation-blocker-findings.md](./implementation-blocker-findings.md) (why the original
mechanism doesn't work — read to avoid re-attempting it), `../020-canonicalize-symmetric-atom-bonds/research.md`
R2, R2.3, R3, R6.

**Tests**: Required. This feature adds a new capability without modifying `canonicalBondKey.m`,
`resolveAtomNodeIndex.m`, or `identifyAtomEquivalenceClasses.m`'s existing guard logic — every
currently-passing assertion in `testIdentifyAtomEquivalenceClasses.m`, `testCanonicalBondKey.m`,
and `testConservedReactingMoieties.m` must keep passing unchanged (spec.md FR-005), by
construction (nothing those tests exercise is touched) as well as by explicit rerun.

**Naming decision**: A new source file IS required this time (plan.md Complexity Tracking —
unlike the original, superseded design). Name it following this domain folder's convention
(parallel to `identifyAtomEquivalenceClasses.m`, `identifyIsomorphicClasses.m`) — e.g.
`consolidateEquivalentBondNodes.m` or similar; finalize the exact name in T011 based on what reads
clearest against the existing folder's names, and use it consistently through the rest of this
file's remaining tasks (replace the placeholder `<NewFn>` below once decided). Its test file is
`test<NewFn>.m` (Constitution III-Naming).

## Phase 0: Already Done (from the halted original attempt)

**Purpose**: Record what real work survives the redesign, so it isn't redone.

- [X] T001 Read `PROPOSAL.md`, original `spec.md`/`plan.md`, and the `prototype/` scripts — superseded
      as *design*, but the diagnostic content (93-failure classification, `5pmev[x]` as worked
      example) remains valid and is reused.
- [X] T002 Inspected `identifyAtomEquivalenceClasses.m` in full — confirmed the WL-colour-refinement
      loop's internal variables, the unsafe-neighbour guard, and the cross-class/cross-bond
      collision guard. This reading is reused directly for T012 (the new pass's colour-partition
      computation reuses this same refinement logic).
- [X] T003 Inspected `buildAtomAndBondTransitionMultigraph.m` in full — confirmed `dATM.Nodes` is
      global (built once across all reactions, `:372`), the first-seen-only equivalence-class
      computation (`:637-644`), `safeCanonicalizeBondAtoms`/`safeCanonicalizeOneAtom`'s silent
      pass-through on a missing key (`:1003-1021`), and the exact `dBTM` construction sequence
      (`EdgeTable` -> `digraph` -> `mapAontoBOld`-derived `.Nodes.*`, `:749-796`+) that the new
      pass must reuse a second time (T015).
- [X] T004 Inspected `testIdentifyAtomEquivalenceClasses.m` and `testConservedReactingMoieties.m` in
      full — confirmed fixture patterns and the `crn[m]` hardcoded-string assertion
      (`testConservedReactingMoieties.m:29`, `'crn[m]#3#O#crn[m]#5#C'`) central to Finding 1.
- [X] T005 Read `canonicalBondKey.m` and `resolveAtomNodeIndex.m` in full — confirmed the exact
      hard-error condition (`resolveAtomNodeIndex:missingNodeIdentity`) that made the original
      design unimplementable (Finding 2), and confirmed neither needs to change under the new
      design (they are called identically to today, on already-real data, before the new pass
      ever runs).
- [X] T006 Vendored `MEVK1x.rxn`/`PMEVKx.rxn` into
      `test/verifiedTests/analysis/testReactingMoieties/data/rxnFiles/` — reused as-is.
- [X] T007-T010 Original pre-fix baseline capture (targeted `5pmev[x]` MATLAB rebuild, full
      existing-test-suite pass, corpus-scale pre-fix numbers) — reusable as the "before" side of
      this feature's diffs; re-confirm currency (nothing should have changed since) rather than
      re-running from scratch, unless material time has passed.

**Checkpoint**: Nothing below duplicates the above. Proceed to the new design's implementation.

---

## Phase 1: Foundational — Reference-Instance Cache Extension

**Purpose**: Retain what the new pass needs per metabolite, without recomputing what's already
read.

- [ ] T011 Decide and record `<NewFn>`'s final name (naming decision, above); create
      `src/analysis/topology/reactingMoieties/<NewFn>.m` with an openCOBRA-style header stub
      (signature TBD, filled in as design solidifies through this phase) and a matching empty
      `test/verifiedTests/analysis/testReactingMoieties/test<NewFn>.m` stub.
- [ ] T012 In `identifyAtomEquivalenceClasses.m`, expose the per-atom final WL-colour-refinement
      partition (the same intermediate value already computed internally to build
      `equivalenceClasses`) as an additional output — needed both for the reference instance
      (today's call site) and for every non-reference instance (T013's new calls). Confirm this
      is additive (existing callers unaffected by an extra output they don't request) — no
      existing call site's behavior changes.
- [ ] T013 In `buildAtomAndBondTransitionMultigraph.m`'s existing first-seen-only block
      (`:637-644`), extend the cache: alongside `metAtomCanonicalRankMap`/`metUnsafeNeighborsMap`,
      retain the reference instance's own `atomNumbers`/`elements`/`headAtoms`/`tailAtoms`/`bTypes`
      (already read locally at that point, just not currently kept) and its WL-colour partition
      (T012's new output) in new per-metabolite caches (e.g. `metReferenceAtoms`,
      `metReferenceBonds`, `metReferenceColours` — `containers.Map`, mirroring the existing
      pattern).

**Checkpoint**: Reference-instance data needed by the consolidation pass is cached once per
metabolite, reusing data already being read, with no behavior change to any existing code path.

---

## Phase 2: `<NewFn>` — Cross-Instance Correspondence and Verification

**Purpose**: Implement the actual matching-and-verification core.

- [ ] T014 Implement `<NewFn>`'s colour-class-signature matching step (research-revision.md
      design step 2): given a non-reference instance's own atoms/bonds and a metabolite's cached
      reference data (T013), compute the non-reference instance's own WL-colour partition (reusing
      T012's exposed computation, run fresh on this instance) and match its classes to the
      reference's by structural signature (the same recursively-built, round-compact-labeled
      descriptive-string technique already implemented in the existing refinement loop — port
      faithfully, do not re-derive independently). Where the multiset of class signatures doesn't
      match (different shapes), return "not isomorphic" for this instance — no exception, no
      partial result.
- [ ] T015 Implement the candidate-bijection construction (design step 3): pair members within
      each matched class by sorted raw-atom-number position on each side.
- [ ] T016 Implement direct edge-set verification (design step 4): relabel the non-reference
      instance's bonds under the candidate bijection and confirm the resulting edge set (endpoints
      + bond type) matches the reference instance's own edge set exactly. Reuse
      `pairIsGraphAutomorphic`'s verification *style* (generalized from a self-permutation check to
      a cross-instance mapping check) rather than writing an unrelated comparison from scratch. On
      verification failure, `<NewFn>` must report "unresolved" for this instance, not raise or
      apply a partial correction (spec.md FR-004).
- [ ] T017 Implement corrected bond-ID recomputation (design step 5): for a verified instance, call
      `canonicalBondKey` again for each of its bonds, substituting each atom for its
      reference-instance counterpart (via T014-T016's verified bijection), and record every
      (current dBTM bond-node name -> corrected name) pair that differs from what today's
      unmodified pipeline already produced.
- [ ] T018 Write `test<NewFn>.m` covering, at minimum: (a) a verified-correspondence case
      (`5pmev[x]`'s two real instances — full row-order divergence, still isomorphic — confirming
      the corrected names collapse both instances onto 23 bonds), (b) a no-correction-needed case
      (an existing stable fixture, e.g. `crn[m]`'s atoms 3/5, confirming zero corrections
      recorded), (c) an unverifiable-correspondence case (a synthetic pair that is
      aggregate-consistent — same atom/bond count, element histogram, charge — but NOT actually
      graph-isomorphic, modeling `acgam1p[c]`'s shape, confirming `<NewFn>` reports "unresolved"
      and applies nothing).

**Checkpoint**: `<NewFn>` correctly identifies and verifies cross-instance correspondences in
isolation, before it is wired into the pipeline's node-merge step.

---

## Phase 3: Wiring — Correction Map Application and dBTM Rebuild

**Purpose**: Apply `<NewFn>`'s output to actually merge `dBTM` nodes.

- [ ] T019 In `buildAtomAndBondTransitionMultigraph.m`, after `dBTM`'s existing construction
      (its current `mapAontoBOld`-derived `.Nodes.Bond`/`.BondIndex`/`.BondType`/etc., unchanged),
      add one new call: for every metabolite with more than one instance contributing to `dBTM`,
      invoke `<NewFn>` for each non-reference instance (using T013's cache) and accumulate the
      resulting correction map (T017's output) across all metabolites.
- [ ] T020 Implement the `metBondTypeFirstSeen` merge-resolution rule (spec.md FR-011): where the
      correction map causes two or more previously-distinct bond-node names (each with its own
      recorded first-seen bond type) to collapse onto one corrected name, resolve the merged node's
      bond type deterministically by original reaction-processing order — the type recorded by
      whichever of the now-merged nodes was processed earliest, not an arbitrary or last-write-wins
      choice. Write a dedicated `test<NewFn>.m` (or `testConservedReactingMoieties.m`) case for
      this specifically (two synthetic instances merging with different recorded bond types,
      confirming deterministic resolution).
- [ ] T021 Apply the accumulated correction map as a find-and-replace over `dBTM`'s `EdgeTable`'s
      bond-identity columns (`EndNodes`, `HeadBond`, `TailBond`) and rebuild
      `dBTM = digraph(correctedEdgeTable)`, reusing the exact same subsequent derivation code
      (`.Nodes.Bond`/`.BondIndex`/`.BondType`/etc. via `mapAontoBOld`) already used for the first
      `dBTM` construction — do not write a second, parallel derivation.
- [ ] T022 Rebuild `dBTM` for the `5pmev[x]` fixture (T006/T007's data) end-to-end through the
      now-wired pipeline; confirm it resolves to exactly 23 bond nodes (spec.md SC-001), matching
      T018(a)'s isolated result now produced by the actual pipeline, not just `<NewFn>` in
      isolation.

**Checkpoint**: User Story 1 fully functional end-to-end — `5pmev[x]` resolves correctly through
the real `buildAtomAndBondTransitionMultigraph.m` call path.

---

## Phase 4: No-Regression Verification (User Story 2)

**Purpose**: Confirm the new pass introduces no regression, given it now runs for every
multi-instance metabolite in the model, not only previously-known failures.

- [ ] T023 [P] Rerun `testIdentifyAtomEquivalenceClasses.m` and `testCanonicalBondKey.m` in full
      post-implementation; confirm byte-for-byte unchanged (neither file nor its call sites were
      modified — this should hold by construction, verify it does).
- [ ] T024 Rerun `testConservedReactingMoieties.m` in full (including the new `5pmev[x]`
      assertion); diff `coa[m]`/`coa[x]`/`coa[r]`/`crn[m]`/`crn[c]` node counts, edge counts, and
      keys against the Phase 0 pre-fix baseline (T009) — confirm byte-for-byte unchanged,
      including the literal `crn[m]` string assertion (`:29`) that Finding 1 originally broke
      under the old design — confirm `<NewFn>` records zero corrections for `crn[m]`'s atoms 3/5
      specifically (spec.md US2 Acceptance Scenario 1).
- [ ] T025 Construct or identify a regression case reproducing the `72c4c441b` mirrored-bond
      collision shape (`gthox[c]`-shaped, or synthetic equivalent) and confirm the existing
      cross-class/cross-bond collision guard (unmodified) still prevents it — this should hold
      trivially since `<NewFn>` runs after `dBTM` already exists and never touches the guard, but
      verify explicitly.
- [ ] T026 Re-review `identifyConservedReactingMoieties.m`, `identifyConservedReactingSubgraphs.m`,
      and `extractBondSubgraphs.m` (spec.md FR-010) for any assumption about `dBTM`'s node/edge
      identity being fixed once returned from `buildAtomAndBondTransitionMultigraph.m` that this
      feature's post-construction correction could break; confirm none exists, or fix and re-test
      if one is found.
- [ ] T027 Full local test-suite run (`testAll`-scoped to this domain, or the full suite if time
      allows) to catch any interaction the narrower diffing above might miss — pay particular
      attention to run time, since `<NewFn>` now runs for every multi-instance metabolite in
      whatever model is built, not only the 93 originally-known failures; confirm it does not
      introduce a material slowdown (spec.md/plan.md's per-metabolite-bounded cost claim).

**Checkpoint**: No regression confirmed, including the specific contradiction (`crn[m]`'s literal
test string) that halted the original implementation attempt.

---

## Phase 5: Corpus-Scale Confirmation, Honestly (User Story 3)

**Purpose**: Measure the fix's actual impact against the live corpus — not assume it reproduces
the original, now-superseded 21/93 Python-prototype figure.

- [ ] T028 Rerun `experiments/moietySizing/scripts/validate_symmetric_atom_classes_matlab.m`
      (reconXmoieties) over the same 327-metabolite stratified sample used for the Phase 0
      baseline (or a fresh equivalent sample if the corpus has materially changed, recording that
      fact); compare crit1 pass/fail against the baseline metabolite-by-metabolite.
- [ ] T029 For every metabolite that still fails crit1 post-fix, confirm `<NewFn>` genuinely
      reported "unresolved" for it (either a colour-class-signature mismatch, T014, or a failed
      edge-set verification, T016) — not that consolidation was skipped for an implementation
      reason (e.g. an uncaught error swallowed silently). Flag, and do NOT silently pass over, any
      metabolite that still fails despite `<NewFn>` reporting a verified correspondence somewhere
      in its instances (spec.md FR-006/SC-004; that would indicate a bug in the wiring, T019-T021,
      not a Diagnosis-2 case).
- [ ] T030 Confirm the crit1 pass count is >= the pre-fix baseline — zero regressions among
      previously-passing metabolites (spec.md SC-003).
- [ ] T031 Write up the actual post-fix numbers (pass count, resolved-failure count, confirmed-
      unresolved count) — do not reuse the original 21/93 figure anywhere in the writeup; report
      what MATLAB actually measured under the new mechanism.

**Checkpoint**: Real-world impact measured and honestly reported.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T032 Write an implementation receipt
      (`specs/20260908-102947-hub-guard-keying-gap-fix/implementation-receipt.md`) recording:
      `<NewFn>`'s final name and signature, the exact pre-/post-fix `5pmev[x]` counts, the full
      regression-suite diff result (Phase 4), the real corpus-scale numbers (Phase 5), and an
      explicit note that this supersedes the original (halted) implementation attempt's design.
- [ ] T033 [P] Confirm no file was created under `experiments/` in this repository and no
      generated logs/diaries/`.mat` probe files were committed.
- [ ] T034 [P] Confirm `canonicalBondKey.m` and `resolveAtomNodeIndex.m` were not modified
      (read-only throughout, per plan.md) — diff against `develop` to verify.
- [ ] T035 Update `.specify/feature.json` (or this repository's equivalent feature-tracking
      metadata) once this feature is ready to merge.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 0 (Already Done)**: No new dependency — recorded for context only.
- **Phase 1 (Foundational)**: Depends on Phase 0's source-reading; blocks Phases 2-3.
- **Phase 2 (`<NewFn>` core)**: Depends on Phase 1's cache extension.
- **Phase 3 (Wiring)**: Depends on Phase 2's verified, independently-tested core.
- **Phase 4 (No-regression)**: Depends on Phase 3 (diffs the wired pipeline's actual output).
- **Phase 5 (Corpus-scale)**: Depends on Phase 3 and, practically, on Phase 4 (run last among the
  verification phases, so a corpus-scale failure can be attributed correctly).
- **Phase 6 (Polish)**: Depends on all prior phases.

### Parallel Opportunities

- T002-T005 (Phase 0, already done) were run in parallel originally.
- T023 can run in parallel with T024 (different test files).
- T033 and T034 can run in parallel (different review targets).

---

## Implementation Strategy

### MVP First (Phases 1-3 Only)

1. Confirm Phase 0's prior work is still current (re-read if material time has passed).
2. Implement Phase 1 (cache extension) and Phase 2 (`<NewFn>`'s matching/verification core, tested
   in isolation).
3. Wire it in (Phase 3) and confirm `5pmev[x]` resolves to 23 nodes end-to-end (T022).
4. Stop and confirm before proceeding to full regression/corpus-scale verification.

### Incremental Delivery

1. Phases 1-3: the actual fix, working end-to-end for the worked example.
2. Phase 4: confirm no regression — including the specific contradiction that halted the original
   attempt.
3. Phase 5: confirm the real corpus-scale impact, honestly — not assumed to match 21/93.
4. Phase 6: implementation receipt with real (not prototype-estimated) numbers.

### Notes

- Every task above uses `- [ ] T### [P?] Description with file path`; check off as completed.
- `[P]` marks tasks that touch different files or only gather evidence.
- Do not attempt the original "replace the fallback branch" mechanism — it is confirmed
  unimplementable (`implementation-blocker-findings.md`), not merely difficult.
- Do not commit generated logs, diaries, saved probe `.mat` files, or temporary MATLAB artifacts;
  do not create anything under `experiments/` in this repository.
- `canonicalBondKey.m` and `resolveAtomNodeIndex.m` are read but not modified — no task edits
  either.
- The `prototype/` directory's Python scripts (from the original design) are historical context
  only at this point — they validate the *detection* half of the problem (WL-colour matching is
  sound), not the now-superseded synthetic-key *construction* approach. `research-revision.md` is
  the authoritative design reference for this phase's implementation.
