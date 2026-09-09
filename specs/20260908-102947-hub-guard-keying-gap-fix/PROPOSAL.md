# Fix Proposal: Hub-Guard Keying Gap in `identifyAtomEquivalenceClasses.m`

**Status**: Draft, for review — not yet a Spec Kit `spec.md`/`plan.md`. Written by the Cowork
session per Jack's request, for the local session to turn into a proper Spec Kit feature
(`/speckit-specify` or `/speckit-plan`) if accepted.

**Relates to**: `specs/020-canonicalize-symmetric-atom-bonds/` (shipped, merged to `develop` via
PR #2693, commits `e140aa602`/`72c4c441b`). This is a **post-merge follow-up finding**, not a
reopening of 020 — 020's own tasks.md is fully checked off and its corpus-scale validation
(T022, 400 files) passed with 0 mismatches at the time. The gap described here was only surfaced
by a much larger, independent validation pass (327 metabolites, full single-resource corpus)
run afterward.

**Scope**: This proposal covers exactly one root cause ("Diagnosis 1" below, the hub-guard
keying gap) and its validated fix. A second, larger root cause ("Diagnosis 2", cross-file
resonance/protonation-depiction instability) was found during the same investigation and is
**explicitly out of scope here** — logged separately in project memory
(`hub_guard_keying_gap_and_resonance_instability.md`) for Jack to think through independently,
since it likely needs an upstream-standardisation approach rather than a graph-canonicalization
patch. Do not fold Diagnosis 2 into this fix.

---

## 1. How this was found

`experiments/moietySizing/scripts/validate_symmetric_atom_classes_matlab.m` (reconXmoieties,
the authoritative MATLAB harness — calls the real, unmodified `readABRXNFile`,
`identifyAtomEquivalenceClasses`, `canonicalBondKey` directly) was run over a stratified sample
of 327 metabolites drawn from the full single-resource RXN corpus:

- VMH: `/media/JACK/repos/ctf/rxns/atomMapped_standardised`
- Rhea: `/media/JACK/repos/ctf/rxns/rhea_atomMapped/rxnfiles/atomMapped`

Result: **93/327 (28%) fail crit1** (`fixedUnionCount == trueBondCount`, i.e. the union of
canonicalized bond keys across every instance file a metabolite appears in does not equal its
recorded true bond count), **96/327 (29%) fail crit2** (cross-instance canonical-key-set
identity), **0/327 hit the FR-011 fallback path** (the algorithm never reports itself as
inconclusive on this corpus — every failure is a silent wrong answer, not a flagged one).

All 93 crit1 failures were then reproduced independently outside MATLAB, with a faithful Python
port of both `readABRXNFile.m`'s parsing convention and `identifyAtomEquivalenceClasses.m`'s
algorithm (exact brute-force automorphism check, not an approximate/timeout-based one — an
earlier, less careful port had produced false disagreements and was discarded). The Python port
was cross-checked against a real MATLAB run on `5pmev[x]` (5-phosphomevalonate,
`MEVK1x.rxn`/`PMEVKx.rxn`) and matches the phenomenon exactly (small residual count differences
attributable to minor porting details, not the finding itself).

## 2. Diagnosis: the shared-hub guard blocks substitution entirely, for the single most common real-world symmetry pattern

### 2.1 What the guard does today

`identifyAtomEquivalenceClasses.m` (as shipped) does two things: (a) 1-WL colour refinement to
find symmetry-equivalence classes — this part is correct and works fine, confirmed by direct
inspection of its output on every failing case; (b) an "unsafe neighbours" guard, added to
prevent exactly the kind of bug fixed in `72c4c441b` (the `gthox[c]` mirrored-bond collision): if
a neighbour atom is bonded to **two or more members of the same equivalence class
simultaneously**, that neighbour is marked unsafe for that class, and **no substitution happens
at all** for any bond between that class and that neighbour — the raw, file-specific atom number
is used unchanged, exactly as if the class had never been detected.

This guard is doing its job: it is correctly preventing a wrong merge that would undercount bond
multiplicity (two chemically-distinct bonds from a hub to two class members must not collapse
into one bond-node key). But its only tool is "leave the raw number alone," and that reopens the
exact cross-file instability the whole feature exists to close, for every bond it touches.

### 2.2 Why this fires almost universally

"A hub bonded to two or more chemically-equivalent branches" is not a rare pattern — it is the
single most common shape of real-world molecular symmetry: a phosphate's non-bridging oxygens, a
carboxylate's two oxygens, a methyl group's three hydrogens, an ammonium's methyls, a
gem-dimethyl pair. Every one of these has a hub (P, C, C, N, C respectively) bonded to 2+
identical branches — precisely the shape the guard exists to protect. So in practice, whenever a
metabolite has this kind of symmetry, the guard blocks canonicalization for it.

### 2.3 Full-scale confirmation: 93/93 (100%)

`hubguard_diagnostic.py` (built on the 1623-file corpus subset needed for the 93 failures — 
transferred from the device as a single tar since these files live outside reconXmoieties) reran
`identifyAtomEquivalenceClasses` on every instance of every one of the 93 crit1-failing
metabolites and classified each metabolite's non-singleton equivalence classes as fully
guard-blocked / partially blocked / not blocked, plus a structural-consistency cross-check
(same atom count, bond count, charge total, element histogram across every instance file).

**Result: 93/93 (100%) of real crit1 failures have every one of their genuinely-symmetric
classes fully guard-blocked.** There is no case in this corpus where the guard is absent and the
metabolite still fails for an unrelated reason within this mechanism — every failure attributable
to the guard is *fully* attributable to it structurally-consistent instances aside (see Diagnosis
2, out of scope).

### 2.4 Worked example: `5pmev[x]` (5-phosphomevalonate)

Files: `MEVK1x.rxn`, `PMEVKx.rxn` (both already in the repo's existing corpus, no new fixtures
needed for this specific example). `identifyAtomEquivalenceClasses` correctly finds 5
non-singleton classes in each file — all textbook symmetric leaf-pairs/triples (methyl
hydrogens, phosphate oxygens) — and every one of them is fully guard-blocked (the phosphate P is
a hub bonded to 2+ equivalent O's in each case).

- True bond count (ground truth, recorded once): **23**
- Single-instance canonicalized bond-key count (either file alone): **23** — matches; no
  *within-file* problem, because raw numbering is self-consistent within one file.
- **Union across the two instances: 46** (my Python port) / **43** (MATLAB's real run on the
  full 327-metabolite pass) — both roughly double the true count, both driven by the same
  mechanism: guard-blocked bonds keep each file's raw, non-corresponding atom numbers, so the
  union counts each of those bonds twice instead of once. (The 46-vs-43 gap between my port and
  the real MATLAB run reflects small implementation differences in the port, not a disagreement
  about the finding — verified by inspecting the guard-blocked class list directly, which matches
  between the two.)

Verification script: `verify_5pmev.py` (attached, see §5).

## 3. Proposed fix

### 3.1 Design

Replace the "leave raw atomNr untouched when blocked" fallback with a **class-based key that is
itself collision-safe**, so the guard's *detection* of a real hazard no longer forces a fallback
to an unstable identity. Concretely: key every atom — not only guard-blocked ones — by

```
(final WL colour-class id, rank-within-class)
```

instead of by raw `atomNumber`, where:

- **final WL colour-class id** is the 1-WL partition cell the atom converges to (already
  computed by the existing colour-refinement loop — this is a pure graph invariant, identical
  across independently-generated files of the same molecule, unlike raw atom number).
- **rank-within-class** is a deterministic tie-break (e.g. sorted position by raw atom number
  within the class, for that one file) that keeps every real bond distinct — this preserves true
  bond multiplicity exactly the way the guard's raw-number fallback does today, but is
  *reconstructed independently per file from a stable invariant* rather than *inherited
  unchanged from an unstable one*.

This directly completes `research.md` R3's first candidate ("graph-automorphism / canonical
labeling approach... use that canonical rank instead of raw atomNumber as canonicalBondKey's
secondary sort key") — R3 already anticipated this shape of fix, but the shipped implementation
(R6) only used automorphism-based *detection*, and fell back to raw-number-based *construction*
for exactly the cases the guard flags. This proposal is the missing key-*construction* half.

Why not simply drop the guard and always substitute the class canonical number? Confirmed
directly (via the `gthox[c]` case that `72c4c441b` fixed, and reproduced against the current
guard logic) that doing so reintroduces the mirrored-bond collision bug the guard was built to
prevent — this is why v1 of the fix prototype (below) tried "raw atomNr for safe atoms, rank for
blocked atoms" and failed outright. The WL-colour keying must apply **uniformly to every atom**,
not just guard-blocked ones, because a "safe" atom's raw number can itself be destabilized by a
nearby symmetric tie-break cascade (confirmed concretely on `5pmev[x]`'s own phosphorus atom,
which has no symmetry of its own but sits at metNr4 in `MEVK1x.rxn` vs. metNr6 in `PMEVKx.rxn` —
raw numbering is not a stable anchor even for atoms outside any equivalence class, once a class
exists nearby in the same molecule).

### 3.2 Prototyped and validated (Python; reference implementation for the MATLAB port)

Two prototypes were built and run against all 93 real failures before proposing this:

- **v1** (`prototype_fix.py`): rank-within-class for guard-blocked atoms only, raw `atomNumber`
  unchanged for "safe" atoms. **Result: 0/93 resolved (0%).** Root-caused to the "safe" atom
  instability above — rejected.
- **v2** (`prototype_fix2.py`, the validated design in §3.1): WL-final-colour + rank-within-class
  applied uniformly to *every* atom. **Result: 21/93 resolved (22.6%).**

`wl_colors()` in v2 includes the same per-round compact re-hashing step already present in the
shipped `identifyAtomEquivalenceClasses.m` (`unique()`-based re-labeling each refinement round) —
an early version of the prototype carried the raw concatenated signature string forward between
rounds instead and was OOM-killed for the same reason MATLAB's own code comments document (the
17.9GB/25.3GB kills that motivated the original re-hashing fix); this was caught and fixed before
reporting the 21/93 result, using the identical mitigation already proven in the shipped code.

### 3.3 Honest framing of impact

**This fix closes 21 of the 93 known crit1 failures (22.6%), not all of them.** The remaining
72/93 (77.4%) are Diagnosis 2 (cross-file resonance/protonation-depiction instability — different
formal bond orders or charge placement at chemically-equivalent positions across independently-
generated RXN files for "the same" metabolite, so the files are not actually graph-isomorphic to
begin with; no atom-identity canonicalization, however good, can fix a metabolite whose input
graphs genuinely differ). That problem is logged separately per Jack's request and is **not**
addressed by this proposal. See project memory
`hub_guard_keying_gap_and_resonance_instability.md` for the full writeup and a worked example
(`acgam1p[c]`, `ACGAMPM.rxn` vs `UAGDP.rxn`) earmarked for a future presentation figure.

This fix is still worth taking on its own: it fully explains and resolves the guard-blocking
mechanism wherever that mechanism is the *only* problem (confirmed structurally consistent
instances), it requires no change to the RXN-generation toolchain (same constraint as 020), and
it directly completes work R3 already scoped but left undecided.

## 4. Suggested requirements for a formal spec (if accepted)

Drafted in FR-style to slot into a Spec Kit `spec.md`, numbered independently of 020's own
FR-001..FR-011 since this is a new feature building on 020, not an amendment to it:

- **FR-1**: For every atom of a metabolite — not only atoms in a guard-blocked equivalence
  class — the bond-node key construction in `buildAtomAndBondTransitionMultigraph.m` MUST use a
  key derived from that atom's final WL-colour-refinement class plus a deterministic
  within-class rank, in place of raw `atomNumber`, wherever `identifyAtomEquivalenceClasses.m`'s
  existing colour-refinement computation applies.
- **FR-2**: The fix MUST NOT reintroduce the mirrored-bond/shared-hub collision bug fixed in
  `72c4c441b` (`gthox[c]`) — i.e., it must remain collision-free for every existing regression
  fixture from feature 019 and 020, not only fix the 21 newly-resolved cases.
  `test/verifiedTests/analysis/testReactingMoieties/testIdentifyAtomEquivalenceClasses.m` and
  `testConservedReactingMoieties.m` MUST continue to pass unchanged for every fixture that
  currently passes.
- **FR-3**: The fix MUST be validated against the full 93-failure set from the 327-metabolite
  corpus run (not just the 21 it resolves) so the remaining 72 are confirmed to be Diagnosis 2
  (structurally-inconsistent instances), not a residual case of this mechanism the fix missed.
  `validate_symmetric_atom_classes_matlab.m` is the harness to rerun.
- **FR-4**: The fix MUST NOT depend on or modify anything scoped to Diagnosis 2 — no
  resonance/protonation reconciliation logic belongs in this feature.
- **FR-5**: Cost MUST remain amortized per metabolite (consistent with 020's existing
  per-metabolite caching design, R6) — this fix changes what key-construction step 020 already
  performs, not its caching architecture.

### Suggested acceptance test

Rebuild `dBTM` for `5pmev[x]` from `MEVK1x.rxn`/`PMEVKx.rxn` (§2.4): confirm the post-fix union
of canonicalized bond keys across both instances equals the true bond count of 23, with no
FR-008-style mismatch — this is a small, already-diagnosed, already-vendored-adjacent case,
analogous to how 020 itself used `coa[m]`/`crn[m]` as its worked acceptance examples.

## 5. Supporting artifacts (attached alongside this proposal)

All produced and validated this session; ported faithfully from the real MATLAB source read
directly (`identifyAtomEquivalenceClasses.m`, `readABRXNFile.m`), not from assumptions about
their behavior:

- `parse_rxn.py` — faithful port of `readABRXNFile.m`'s parsing convention.
- `port_identify_classes.py` — faithful port of `identifyAtomEquivalenceClasses.m` (exact
  brute-force automorphism check, matches MATLAB's `pairIsGraphAutomorphic`).
- `verify_5pmev.py` — the §2.4 worked example.
- `hubguard_diagnostic.py` — the full 93-failure classification (§2.3), writes
  `hubguard_diagnostic_details.json`.
- `prototype_fix.py` — v1 (rejected, 0/93).
- `prototype_fix2.py` — v2, the validated design (§3.2, 21/93).

These are Python reference implementations for review purposes, not the MATLAB implementation
itself — an actual fix must be written natively in
`src/analysis/topology/reactingMoieties/identifyAtomEquivalenceClasses.m` (and its call site in
`buildAtomAndBondTransitionMultigraph.m`) by the local session's own implementation pass, mirroring
`72c4c441b`'s precedent of fixing this same file for a related guard defect.
