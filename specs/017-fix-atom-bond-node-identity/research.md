# Phase 0 Research: Correctly root-cause and fix atom/bond node-identity defect

**Feature**: 017-fix-atom-bond-node-identity | **Date**: 2026-08-11

No `[NEEDS CLARIFICATION]` markers were left in `spec.md` — the "Design decision" section already
resolved the one open fork (retain reaction+instance scoping, revise the check formulas). This
document carries forward "Spec v2"'s literal implementation-level design as Phase 0 decisions,
each cross-checked against actual MATLAB execution in this repository before being finalized here
— including one correction to a claim made during the spec's own review (see Decision 2 below),
caught only by re-verifying rather than trusting the earlier conclusion.

## Addendum: implementation-attempt findings (2026-08-11, `/speckit-implement`)

A full implementation attempt was carried out and then **fully reverted** (source tree confirmed
clean, matching `develop`) because it caused a net regression, discovered only by testing the
complete downstream pipeline, not just the directly-edited function. This addendum records what
was learned so the next attempt does not have to re-derive it. Decisions 2 and 3 below are updated
in place to reflect the version that was actually empirically verified (simpler and more robust
than the version planned before implementation began); Decision 6 (new) records the blocking
finding.

**Confirmed correct in isolation, exact code preserved in Decisions 2/3 below**: Parts A, B, and C
in `buildAtomAndBondTransitionMultigraph.m` were implemented, and the fixture
(`r0317`/`ACONTm`/`r0426`) ran with zero warnings, `h2o[m]` showing exactly 6 distinct atom nodes,
`max(max(abs(res)))==0` for both the atom- and bond-level checks, and no crash anywhere in the
function.

**New finding — `identifyConservedReactingMoieties.m` has three duplicate copies of the same
defective formula, not an unknown number as `spec.md` FR-009 left open**: a full-file grep
(`grep -n "res\s*=.*\*N\s*-\|diag(M2"`) found:
1. Line ~254 (directed atom transition multigraph): `res=M2Ai*M2Ai'*N - M2Ai*Ti*Ti2R`. Fixed by
   reusing the corrected `D` pattern from Decision 3 — confirmed `res=0` exactly.
2. Line ~547 (undirected, simplified atom transition graph `ATG`/`M2A`): `res=M2A*M2A'*N -
   M2A*A*A2R`. The file's own sanity check at line ~465 (`res = M2Ai-M2A`) asserts `M2A` is
   identical to `M2Ai`, so the *same* corrected `D` from fix #1 applies directly — no new
   derivation needed. Confirmed passes once #1 is fixed.
3. Line ~1273 (moiety-level): `res = M2M*M2M'*N - M2M*M*M2R`. **This one is not analogous** — see
   Decision 6.

**Blocking discovery (Decision 6)**: the moiety-level check is not reaction-invariant the way atom
and bond counts are, so the same fix pattern does not apply, and — critically — **the currently
unmodified `develop` branch passes `testConservedReactingMoieties.m` end-to-end today** (verified
directly: stashed all changes, ran the full test, `T011_FULL_TEST_PASSED`). This means fixes #1 and
#2 above, while individually correct, cannot be merged without also resolving #3 — doing so would
turn a currently-passing test into a newly-failing one. **The moiety-level check must be part of
this feature's scope, not a separate follow-up**, or Parts A/B/C cannot ship at all without
regressing existing coverage.

## Decision 1: Atom/bond node identity format (Part A) — unchanged from spec, re-confirmed

**Decision**: Prepend `model.rxns{i}` and the per-reaction `instances(...)` value to the existing
`substrateID`/`productID` construction (`buildAtomAndBondTransitionMultigraph.m` lines 303-308),
and `model.rxns{i}` + `bondMappings.instances(...)` to `bondSubstrateID`/`bondProductID`
construction (lines 592-603 in the current file). Exact format, unchanged from the original bug
report and feature 016:
```
reactionID # metaboliteID # instanceNumber # localAtomNumber # element        (atoms)
reactionID # metaboliteID # instanceNumber # atomNumber # element             (per atom-in-bond reference)
```

**Rationale**: This part of feature 016's fix was never disproven — only its "no other changes
needed" claim was. `model.rxns{i}` and `instances`/`bondMappings.instances` are already in scope
at both sites (confirmed by source read: `instances=atoms.instances;` at line 258;
`bondMappings.instances` inherited unmodified from `readABRXNFile.m`'s `bonds.instances`).

**Alternatives considered**: See spec.md's "Evidence from feature 016," point 4 — an
`instances`-only variant (no reaction prefix) was empirically tested and found neutral on the
`r0317`/`ACONTm`/`r0426` fixture, but does not solve the actual defect (cross-reaction merging)
this feature exists to fix; rejected once Part C makes full reaction-scoping viable.

## Decision 2: Bond-loop atom lookup fix (Part B) — corrected during this research pass

**Decision**: Replace the six-per-reference `(mets, AtomNumber, Element)` triple-match lookups at
lines 611-618 with a lookup keyed on `dATME.Nodes.Atom` (a column that already holds the
node's fully-qualified identity string, confirmed below) matched against a reconstructed target
key built with the exact same format as Part A, with an explicit `numel(matchIdx) ~= 1` guard
raising a specific, named error on failure — per spec.md FR-003.

**Rationale, and a correction caught during this research pass**: While comparing "Spec v2" against
this repo earlier, it was speculated that MATLAB's `digraph` auto-generates a `Name` column from
`EdgeTable.EndNodes`, and that `dATME.Nodes.Name` could be reused directly instead of building a
new key column — implying v2's proposed separate `QualifiedKey` column was redundant. **This
speculation was wrong, and re-verifying it before writing it into a design decision caught the
error**: direct execution (`buildAtomAndBondTransitionMultigraph.m` line 377,
`Nodes = removevars(Nodes,'Name');`, followed by rebuilding `dATM = digraph(Edges,Nodes)` at line
380 with purely numeric `AtomIndex`-based `EndNodes`) shows `Name` is deliberately stripped before
the bond-transition loop even starts, specifically so the final graph is keyed by numeric
`AtomIndex`, not by string. Confirmed empirically: `dATM.Nodes.Properties.VariableNames` (and
`dATME.Nodes.Properties.VariableNames`, since `dATME = addnode(dATM, EnergyNode)` inherits the same
schema) is `Atom, AtomIndex, mets, AtomNumber, Element` — no `Name`.

However, a *different* pre-existing column serves the same purpose: `dATM.Nodes.Atom` (built at
line 360, `Atom = mapAontoBOld([dATM.Edges.HeadAtom; dATM.Edges.TailAtom], dATM.Nodes.Name,
[dATM.Edges.HeadAtom; dATM.Edges.TailAtom])`, i.e. projecting each edge's `HeadAtom`/`TailAtom`
value — which is set to `substrateID`/`productID` at line 327-328 — back onto its own node row via
the (still-present-at-that-point) `Name` key) is populated with exactly the same qualified-ID
string as the node's `Name`, *before* `Name` is removed. Confirmed empirically on the current
(pre-fix) code: for `h2o[m]`'s three atom nodes, `dATM.Nodes.Atom` held `"h2o[m]#1#H"`,
`"h2o[m]#2#O"`, `"h2o[m]#3#H"` — exactly the current (pre-Part-A) identity-string format. After
Part A's fix, this column will hold the full reaction+instance-scoped string instead. So: no new
column needs to be built (v2's proposed `QualifiedKey` construction step is unnecessary) — matching
against the already-existing `Atom` column is sufficient and is a smaller diff.

**Alternatives considered**:
- *Reuse `Name` directly* (this research pass's own initial, wrong idea): rejected — `Name` does
  not exist on `dATME.Nodes` by the time the bond loop runs; empirically disproven, not merely
  theorized against.
- *Build a new `QualifiedKey` node column* (v2's original proposal): unnecessary — `Atom` already
  holds this value; rejected as redundant, not as incorrect. Building it explicitly would still
  work and is a safe fallback if `Atom`'s content is found to diverge from `Name` in some case not
  yet tested (e.g. the energy node itself, which is not looked up by this fix regardless).
- *Match by `AtomIndex` instead of a string key*: would require first resolving the target atom's
  `AtomIndex` via the same string reconstruction anyway (there is no shortcut from
  `bondMappings`'s raw fields to `AtomIndex` without going through `Atom`/`Name`-equivalent
  matching first), so it does not simplify anything; the string-keyed lookup against `Atom` is the
  most direct available path.

**Verified at implementation time (2026-08-11)**: `dATME.Nodes.Atom` for the *energy* node does
not collide with any real atom's qualified key, confirmed by full end-to-end execution with no
lookup errors on the energy-node path. One case the original decision missed and had to be
special-cased during implementation: `bondMappings.mets{X}` can equal `model.rxns{i}` itself (the
energy-node reference) — for that case, `dATME.Nodes.Atom` is literally `'E'`, not a qualified
5-part string, so the lookup must branch: `if strcmp(bondMappings.mets{X}, model.rxns{i})`, match
by `strcmp(dATME.Nodes.Atom,'E') & strcmp(dATME.Nodes.mets, model.rxns{i})` (unique within the
current reaction's `dATME` by construction); otherwise build and match the qualified key as
originally planned. Confirmed via execution: with this branch in place, all four per-bond-reference
lookups (substrate/product × head/tail) resolved to exactly one match, including energy-node
references, on the `r0317`/`ACONTm`/`r0426` fixture — zero crashes.

## Decision 3: Consistency-check formula correction (Part C) — revised after implementation, simpler than originally planned

**Decision (as actually implemented and verified, superseding the original plan below)**: The
originally-planned `NodeRxn`/node-counting approach (see "Original plan" below) turned out to work
for the atom side but **not** the bond side (see "Why the original plan was replaced"). The
approach that was implemented and empirically verified to give `res=0` exactly, for **both** the
atom- and bond-level checks, is simpler and does not need `NodeRxn`/`mapAontoBOld` at all: read
`d(i)` directly from the existing RHS matrix's own per-reaction value, rather than independently
recomputing an equivalent count.

For the atom-level check (line 498):
```matlab
RHSatom = M2Ai*Ti*Ti2R;                      % already needed for res; compute once, reuse
d = zeros(nMappedMets,1);
for i=1:nMappedMets
    rxnCols = find(N(i,:) ~= 0);
    if isempty(rxnCols), continue; end
    d(i) = full(RHSatom(i,rxnCols(1))) / full(N(i,rxnCols(1)));
    if options.sanityChecks && numel(rxnCols) > 1
        for j2 = 2:numel(rxnCols)
            dCheck = full(RHSatom(i,rxnCols(j2))) / full(N(i,rxnCols(j2)));
            if dCheck ~= d(i)
                error('buildAtomAndBondTransitionMultigraph:inconsistentAtomCount', ...
                    'Metabolite %s: inconsistent atom count between reaction %s (%g) and %s (%g).', ...
                    mets{i}, rxns{rxnCols(1)}, d(i), rxns{rxnCols(j2)}, dCheck);
            end
        end
    end
end
D = spdiags(d,0,nMappedMets,nMappedMets);
res = D*N - RHSatom;                          % replaces (M2Ai*M2Ai')*N - M2Ai*Ti*Ti2R
```
The bond-level check (line 799) is the identical pattern, substituting the bond-side matrices, and
preserving the pre-existing `~hBool` (proton-exclusion) masking exactly as the original code
structured it (see "Fragile pre-existing structure" note below):
```matlab
RHSbond = M2BiE(~hBool,:)*BTiE*BTi2R;
dFull = zeros(length(model.mets),1);          % full model.mets length, matching M2BiE's rows
for k=1:numel(mets)                            % mets = model.mets(metBondMappedBool)
    rxnCols = find(N(k,:) ~= 0);
    if isempty(rxnCols), continue; end
    fullIdx = find(strcmp(model.mets, mets{k}), 1);
    dFull(fullIdx) = full(RHSbond(k,rxnCols(1))) / full(N(k,rxnCols(1)));
    % ... same cross-validation loop as atom side, using dFull(fullIdx) and inconsistentBondCount
end
d = dFull(~hBool);
D = spdiags(d,0,length(d),length(d));
res = D*N - RHSbond;                           % replaces (M2BiW(~hBool,:)*M2BiE(~hBool,:)')*N - ...
```

**This is mathematically guaranteed correct by construction for the defining reaction `j0`**:
`d(i) := RHS(i,j0)/N(i,j0)` makes `D*N(i,j0) = d(i)*N(i,j0) = RHS(i,j0)` exactly, so
`res(i,j0)=0` always. It is correct for *every* reaction the metabolite appears in only if the
cross-reaction consistency genuinely holds chemically — exactly what the FR-006 assertion checks.

**Why the original plan (below) was replaced**: The atom-side `NodeRxn`-based node-counting
approach was implemented first and verified: `res=0` exactly on the fixture. The *same pattern*,
translated to the bond side (`BondRxn` via `mapAontoBOld` on `dBTM`, `nnz(M2BiE(fullIdx,:) &
rxnBondBool')`), was implemented next and **produced a nonzero residual** (`res=3` for `cit[m]`,
`res=-4` for `HC00342[m]` on the fixture) — debugged directly: independently-computed
`bondCountInRxn` values (17, 17) were internally consistent per metabolite, but did not match what
`M2BiE*BTiE*BTi2R` actually computes for that reaction. Root cause: **bond nodes are not 1:1 with
bond-transition edges the way atom nodes are with atom-transition edges** — the `bTypes~=1`
double/triple-bond expansion (`bondTypeInstance` in `addBondMappingsRXNFile.m`) means a single
conceptual bond node can participate in a different number of bond-transition edges depending on
context, so "count of bond nodes matching a reaction" is not the same quantity as "signed
incidence-weighted sum of bond-transition edges for that reaction." Reading `d` directly from the
RHS matrix's own value sidesteps this entirely, since it never claims node-count and edge-count are
equivalent — it just reads back what the formula already, unambiguously computes for one reaction.
Both atom and bond sides were switched to this simpler pattern for consistency, and re-verified:
`res=0` exactly for both, on the same fixture.

**Fragile pre-existing structure preserved, not fixed (out of scope)**: the bond-level check mixes
two different row-index spaces that happen to coincide only on this specific fixture — `res`'s LHS
uses `~hBool` (proton-exclusion mask over the *full* `model.mets`), while the diagnostic loop's
`mets{i}` indexing uses `metBondMappedBool` (a *different* subset). On the test fixture (0 protons,
all 4 metabolites bond-mapped) `nnz(~hBool) == nnz(metBondMappedBool) == 4` and both preserve
`model.mets`'s original order, so they coincide row-for-row — but this is not a general guarantee.
This is a **pre-existing characteristic of the original code**, not introduced by this fix; per
Principle V (smallest coherent dependency set), it was deliberately preserved as-is rather than
"improved," since fixing it would be a separate, unauthorized change. Flagged here so a future
session investigating a larger/different model doesn't mistake it for a new regression.

**Original plan (superseded, kept for reference)**:
1. Derive `NodeRxn` via `mapAontoBOld` keyed on `dATM.Nodes.AtomIndex`, mapping each atom node to
   its owning reaction.
2. Count atom nodes per metabolite per reaction via `nnz(M2Ai(i,:) & strcmp(NodeRxn, rxns{j})')`.
3. This works for atoms (verified) but not bonds (see above) — superseded by the RHS-read approach.

**Alternatives considered** (unchanged from original decision): keeping `d` as the row-sum and
reverting Part A was rejected (doesn't fix the actual defect); computing `d` with no cross-reaction
assertion was rejected (would silently tolerate genuine RXN-file inconsistencies, FR-006).

**Verified at implementation time**: both the atom- and bond-level corrected checks produce
`max(max(abs(res)))==0` exactly on the `r0317`/`ACONTm`/`r0426` fixture, confirmed by direct
execution, not inferred.

## identifyConservedReactingMoieties.m duplicate checks #1 and #2 (verified fixes)

Confirmed by execution: fix #1 (line ~254, directed atom transition multigraph — identical
structure to `buildAtomAndBondTransitionMultigraph.m`'s atom-level check) uses the *exact same*
RHS-read pattern as Decision 3's atom-side fix, with its own local `mets`/`rxns`/`RHSatom`/`d`/`D`
(this function computes `M2Ai`, `Ti`, `Ti2R`, `N` independently, mirroring
`buildAtomAndBondTransitionMultigraph.m` rather than reusing its outputs). Verified: `res=0`
after this fix, confirmed by reaching the next check without error.

Fix #2 (line ~547, undirected atom transition graph `ATG`) needs **no new derivation at all** —
the function's own pre-existing sanity check at line ~465 (`res = M2Ai-M2A; if
max(max(abs(res)))~=0 error(...)`) already asserts `M2A` is identical to `M2Ai` (same node set,
same metabolite mapping — `ATG` is `simplify(ATM)`, an undirected multi-edge-collapsed view of the
*same* `dATM`, not a different node set). Since `M2A*M2A' == M2Ai*M2Ai'` follows directly, the
`D` computed for fix #1 is *already* the correct diagonal correction for fix #2: replace
`res=M2A*M2A'*N - M2A*A*A2R` with `res=D*N - M2A*A*A2R`, reusing `D` verbatim. Confirmed by
execution: `res=0` after this fix, confirmed by reaching the (previously unreached) moiety-level
check — which is where Decision 6's blocker was found.

## Decision 6: Moiety-level duplicate check (line ~1273) — BLOCKING, unresolved

**Finding**: `identifyConservedReactingMoieties.m` line ~1273,
`res = M2M*M2M'*N - M2M*M*M2R`, is a *third* duplicate of the same structural pattern
(`M2M` = metabolite-to-moiety-instance mapping, analogous to `M2Ai`/`M2A`). It is **also** broken
by the corrected (disambiguated) `dATM`, but the same fix pattern (Decision 3's "read `d` from
`RHS(i,j0)/N(i,j0)`, cross-validate against other reactions") does **not** apply here, and applying
it anyway produces a mathematically wrong result that happens to not always trigger the
cross-validation guard (see below) — this must not be "fixed" the same way without further theory
work.

**Empirical evidence this is fundamentally different from the atom/bond case**: with
`options.sanityChecks` *enabled*, the naively-ported fix's own cross-validation would have caught
this (that's exactly what it's for), but the test that reaches this code path
(`testConservedReactingMoieties.m`) calls `identifyConservedReactingMoieties` with
`options.sanityChecks = 0` (a pre-existing, deliberate choice in that test, unrelated to this
feature). With the cross-validation bypassed, the naive fix silently used `d(cit[m])=1` (from
reaction `ACONTm`, where `RHSmoiety(cit,ACONTm)=-1`, `N(cit,ACONTm)=-1`) while reaction `r0317`
independently implies `d(cit[m])=2` (`RHSmoiety(cit,r0317)=-2`, `N(cit,r0317)=-1`) — a genuine
disagreement, not a computation bug (verified by direct inspection of `full(N)` and
`full(RHSmoiety)` via temporary debug output, then reverted). **Unlike atom or bond count, which
are fixed chemical properties of a species (water always has 3 atoms, everywhere it appears),
moiety decomposition is inherently tied to which bonds break/form in a *specific* reaction — the
same metabolite can legitimately decompose into a different number of moiety instances depending
on reaction context.** Forcing a single reaction-invariant `d(i)` here is not a correction, it is
imposing a false invariant, and would either (a) silently produce a wrong `res` check that
sometimes passes only by coincidence, or (b) if the cross-validation guard *were* active, spuriously
error on legitimate, chemically-correct differences.

**Why this blocks shipping Parts A/B/C at all, not just this one check**: the *currently
unmodified* `develop` branch passes `testConservedReactingMoieties.m` end-to-end today (verified:
`git stash` all changes, ran the full test, `T011_FULL_TEST_PASSED`). The moiety-level check
currently "passes" only because pre-fix node merging masks the same underlying issue the atom/bond
checks were also masking. Fixing *only* the atom/bond level (even correctly) surfaces the
moiety-level check's failure, which was previously hidden — turning a currently-green test red.
**This feature cannot ship Parts A/B/C in isolation without a corresponding resolution at the
moiety level**, or an explicit, deliberate decision to accept and document a known regression
(not attempted this session — reverted instead).

**What resolving this actually requires** (not done — flagged for the next session): understanding
what the *correct* moiety-level invariant is when a metabolite's moiety decomposition legitimately
differs across reactions. Candidates to investigate, none evaluated yet: (a) the check should
compare per-reaction, not assert a single global `d(i)` — i.e. `res` should be reformulated to not
require `M2M*M2M'` (or its replacement) to be a metabolite-level diagonal scalar at all; (b) the
apparent inconsistency might indicate `M2M`/`nMoieties` construction (line ~1222,
`moieties2mets = atoms2mets(isCanonical)`) needs to also change now that atoms are reaction-scoped
— i.e. the defect might be upstream of the check itself, in how canonical moiety instances are
selected, not in the check formula; (c) consult the governing theory paper's moiety-splitting
treatment (Ghaderi et al. 2020, cited in this file's header) for the intended invariant, since this
check was not covered by the Rahou et al. 2026 paper this feature's atom/bond fixes are grounded
in. This is genuine domain/theory work, not a mechanical port, and should not be attempted by
pattern-matching the atom/bond fix again without first understanding why the pattern breaks here.

## Decision 4: Fixture for within-reaction multi-instance metabolites (FR-007/SC-002)

**Decision**: First scan the toolbox's existing atom-mapped RXN file corpus (beyond the 4-file
`test/verifiedTests/analysis/testReactingMoieties/data/rxnFiles/` fixture) for a reaction where a
metabolite has `instances > 1` (i.e. `atoms.instances` or `bondMappings.instances` takes a value
greater than 1 for some row) via a short MATLAB scan calling `readABRXNFile` across the corpus and
checking `max(atoms.instances) > 1`. If found, use it (or extract a minimal reaction subset
containing it) as the fixture for this scenario. If no such case exists in the corpus, construct a
minimal synthetic RXN file pair (e.g. a toy reaction consuming `2 H2O`) as a new fixture under
`test/verifiedTests/analysis/testReactingMoieties/data/rxnFiles/` (or a feature-specific
subdirectory), documenting which path was taken.

**Rationale**: Required by spec.md FR-007/SC-002 — this case is untested by the currently-available
fixture and is the one part of the original bug report's hypothesis not yet disproven or confirmed
by this session's evidence.

**Alternatives considered**: Skip this verification and rely on the `r0317`/`ACONTm`/`r0426`
fixture alone — rejected, since spec.md explicitly requires covering this case (it is the
`instances` field's stated purpose, and leaving it unverified would repeat feature 016's pattern of
shipping an untested assumption).

## Decision 5: No `/contracts/` artifact (unchanged from feature 016's precedent)

**Decision**: Skip the `/contracts/` directory.

**Rationale**: `buildAtomAndBondTransitionMultigraph.m` is an internal analysis-pipeline function;
FR-009/FR-010 require its public signature and interface to remain unchanged. No external API, CLI,
service endpoint, or cross-language binding is touched.

## Technical Context resolution

- **Language/Version**: MATLAB (repository baseline R2024b+). MATLAB R2024b is confirmed installed
  and usable in this environment at `/usr/local/MATLAB/R2024b/bin/matlab` (not on `PATH`); fast
  headless init via `initCobraToolbox(false, 'agent')` confirmed to complete in ~1.5-2s.
- **Primary Dependencies**: MATLAB `digraph`/`graph`, `mapAontoBOld` (existing helper in the same
  directory), `spdiags`. No new dependency.
- **Storage**: N/A — in-memory `model` struct and RXN files via unmodified
  `readABRXNFile.m`/`addBondMappingsRXNFile.m`.
- **Testing**: MATLAB `assert`-based tests under
  `test/verifiedTests/analysis/testReactingMoieties/`, extending `testConservedReactingMoieties.m`
  and adding new fixture(s) per Decision 4; run via `test/testAll.m` and CI. Existing
  `prepareTest('needsMILP', true)` requirement declaration carries forward unchanged.
- **Target Platform**: Headless Linux CI (`matlab -batch`), consistent with the existing test and
  with how this session validated every decision above.
- **Project Type**: Single MATLAB toolbox library; no new project structure.
- **Performance Goals**: No new performance target; the fix adds one `mapAontoBOld` call and a
  per-metabolite loop bounded by `nMappedMets × (reactions containing that metabolite)` — small
  relative to existing per-reaction RXN-file parsing cost.
- **Constraints**: Fix confined to
  `src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m` (FR-009); no
  change to `readABRXNFile.m`, `addBondMappingsRXNFile.m`, `identifyConservedReactingMoieties.m`,
  or any existing RXN file (new fixture files, if constructed per Decision 4, are additions, not
  modifications, to the test fixture directory).
- **Scale/Scope**: One source file, three coordinated changes (Parts A/B/C) plus one possibly-new
  test fixture; verification via the existing test file extended with new assertions.
