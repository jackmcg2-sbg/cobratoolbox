# Implementation Blocker Findings — Hub-Guard Keying Gap Fix

**Status**: Implementation halted before any source change, by explicit user decision, pending
spec/plan rework. This document records what was verified during the `/speckit-implement` attempt
on 2026-09-08, so the next `/speckit-clarify` or plan revision doesn't have to re-derive it.

**What was done**: `test/verifiedTests/analysis/testReactingMoieties/data/rxnFiles/MEVK1x.rxn` and
`PMEVKx.rxn` were vendored (tasks.md T006) — harmless, additive test fixtures, not referenced by
any test yet. No other file under `src/` or `test/` was touched. No task in `tasks.md` was checked
off, since nothing beyond T006 was actually completed.

## Finding 1 — FR-004/FR-005 vs. FR-001/SC-001 are mutually incompatible as written

Verified directly against the real `MEVK1x.rxn`/`PMEVKx.rxn` fixtures in MATLAB
(`identifyAtomEquivalenceClasses` called on each file's own `5pmev[x]` atoms/bonds):

- The phosphorus atom is a **singleton** WL-colour class in both files (no symmetry of its own),
  but its raw atom number is **4 in `MEVK1x.rxn`, 6 in `PMEVKx.rxn`** — confirmed empirically.
- 11 of `5pmev[x]`'s 23 bonds are guard-blocked (5 non-singleton classes: two geminal-H pairs, a
  methyl H-triple, a CH2 H-pair, and the phosphate O-pair — not just the phosphate oxygens the
  worked example emphasizes). The other 12 are singleton-singleton "safe" bonds, including every
  bond touching phosphorus.
- The observed pre-fix union count (43-46 vs. true 23) is close to double 23, meaning almost none
  of the 23 bonds currently match across the two files — not only the 11 guard-blocked ones.

**Consequence**: for `5pmev[x]` to resolve to exactly 23 (SC-001), the phosphorus's own key — a
singleton adjacent to, but not part of, a symmetric class — must *also* become cross-file-stable.
That requires abandoning raw-atomNumber-based keying for singletons too, which is exactly what the
validated Python prototype (`prototype/prototype_fix2.py`) does: it keys every atom by a structural
WL-colour label uniformly, with no singleton special case.

But `test/verifiedTests/analysis/testReactingMoieties/testConservedReactingMoieties.m:219-229`
hardcodes a literal expected key string for `crn[m]`: `'crn[m]#3#O#crn[m]#5#C'` — atoms 3 and 5,
both non-symmetric singletons, asserted **by their raw atom numbers verbatim**, and required by
FR-005/T019 to stay byte-for-byte unchanged. A uniform, every-atom structural-colour scheme changes
this string too. **FR-001+SC-001 and FR-004+FR-005 (+ this existing test) cannot both hold.**

The narrower "guard-blocked branch only" fix (what plan.md's Design section literally describes,
and what `prototype/prototype_fix.py` — v1 — already tried) does not resolve this either: it
resolved 0/93 in the validated prototype, and the bond-level analysis above explains why — the
phosphorus hub's own key stays unstable regardless of what the guard-blocked oxygen endpoint does.

**User decision on this finding**: proceed with the narrow (guard-blocked-branch-only) fix,
accepting that SC-001/SC-002 will very likely not be met (matching the prototype's own v1 result).

## Finding 2 — `resolveAtomNodeIndex` makes even the narrow fix mechanically unimplementable

This finding is independent of Finding 1 and blocks the narrow fix too. Traced the actual call
chain a canonicalized atom number goes through in `buildAtomAndBondTransitionMultigraph.m`:

```
safeCanonicalizeOneAtom → canonicalBondKey → resolveAtomNodeIndex(dATME.Nodes, dATMNodeIndexMap, met, atomNumber, element)
```

`resolveAtomNodeIndex.m` (lines 50-64, from feature `20260902-150020-eliminate-bond-transition-
ismember-scans`) does an **exact-match lookup against real, pre-existing atom nodes** and
**hard-errors** (`resolveAtomNodeIndex:missingNodeIdentity`) when `(met, atomNumber, element)`
doesn't match a row already in `dATME.Nodes` — built earlier and independently, straight from each
RXN file's raw atom numbers (line 382, via the atom-transition pipeline, untouched by any of this
feature's logic).

**Consequence**: whatever value the guard-blocked fallback branch returns must be one of that
metabolite instance's own real, existing raw atom numbers — never a synthetic construction (not a
fractional encoding, not a large-integer `classId*multiplier+rank` encoding — both were considered
and both would hard-crash the build on the first guard-blocked bond, since neither matches any real
`dATME.Nodes` row). This is *why* the existing "safe substitution" branch works at all: it
redirects to the class's canonical representative, which is itself a real atom in the same
molecule.

Given that constraint, the fallback branch has exactly three possible real values to return for a
guard-blocked atom:
1. itself (today's behaviour — a no-op, not a fix),
2. its class's canonical representative (the exact collision the guard exists to prevent), or
3. some other real atom (arbitrary, unprincipled, and just as collision-prone as #2).

None of these implement "replace the fallback with a new stable key" as FR-001/T012 describe. **The
fix as scoped in spec.md/plan.md/tasks.md cannot be implemented by changing what
`safeCanonicalizeOneAtom` returns.** This mechanism was apparently never validated against
`resolveAtomNodeIndex`'s hard real-node-match constraint, which comes from a separate, later
feature the investigating (Cowork) session's Python-only analysis did not cross-check against.

A real fix would need to decouple dBTM's bond-level deduplication from dATM/dATME's real-atom-
identity resolution — e.g. a separate canonicalization/consolidation pass applied *after* node
resolution, at bond-transition-merge time, rather than by substituting the atom number fed into
node resolution itself. This is a materially bigger architectural change than "two files, fallback
branch only, no new source file," and was not designed or scoped by this feature's plan/tasks.

**User decision on this finding**: stop implementation entirely; send back to plan/spec rather than
attempting to design the bigger fix mid-implementation.

## Recommended next step

Before any further implementation attempt on this feature:

1. Re-open via `/speckit-clarify` or a plan revision that explicitly designs where in the pipeline
   deduplication actually happens for a guard-blocked class (dATM/dATME atom-node resolution, or a
   later dBTM bond-consolidation stage) — Finding 2 needs a concrete target mechanism, not just an
   "expose classId+rank" instruction that assumes it can be threaded through
   `resolveAtomNodeIndex` unchanged.
2. Once a mechanism is chosen, Finding 1 needs to be re-litigated in that new mechanism's context:
   does the new consolidation-stage approach allow uniform (every-atom) keying without breaking
   `testConservedReactingMoieties.m`'s literal-string assertions for `crn[m]`? (Plausibly yes, since
   a separate consolidation pass could leave dATM/dATME node identities — and therefore
   `dBTM.Nodes.Bond` strings built from real atom numbers — untouched, while still deduplicating
   equivalent bond-transitions structurally at consolidation time. This is speculative and needs
   verification, not assumption, exactly as this feature's own ethos requires.)
3. `MEVK1x.rxn`/`PMEVKx.rxn` are already vendored and can be reused as the worked example once a
   viable mechanism is designed.
