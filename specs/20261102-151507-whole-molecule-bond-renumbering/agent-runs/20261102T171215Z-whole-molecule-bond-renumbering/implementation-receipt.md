# Implementation receipt: 20261102-151507-whole-molecule-bond-renumbering

## Prompt

The spec, plan and tasks are approved. Run the Spec Kit implementation phase for the active feature.

## Final response

Implementation of `20261102-151507-whole-molecule-bond-renumbering` is complete. All of T001–T019 are done and committed locally in `~/cobratoolbox-rm-memory`. Nothing is pushed and no PR is open.

**The fix**: `buildAtomAndBondTransitionMultigraph` no longer substitutes symmetric atoms one bond end at a time. Each metabolite keeps one reference molblock (its first-seen copy). Every later copy is either identical to it or renumbered onto it by a single whole-molecule isomorphism, applied to both ends of every bond. A copy with no isomorphism raises `buildAtomAndBondTransitionMultigraph:nonIsomorphicMolblock`, naming the metabolite and reaction, and keeps its raw numbering.

**Success criteria**:
- **SC-001**: met. Molfile equality holds on all six fixtures. On the unchanged source, 38 of 58 metabolite–fixture cases were corrupted.
- **SC-002**: met. 0 of 9,489 collapsed-VMH metabolites corrupted (3,533 before), with 0 misplaced bonds, 0 self-loops and 0 non-isomorphic warnings.
- **SC-003**: met. Conserved-moiety outputs (`L`, `M2M`, `M2R`, `ATG`, `MTG`, formulae) are identical before and after on 23 cases, including random n = 500.
- **SC-004**: met. The paper's $L$, 6 instances and 6 transitions hold on the shipped files, and Fig. 11 (4 vertices, 6 bonds, the three bond sets, a 2-reaction cover) holds on the consistent-arm copy. The test fails on the unchanged builder.
- **SC-005**: met. All 16 `testReactingMoieties` tests pass. Both golden references were recaptured with a per-field difference report: `BG`, `arm.MG` and the reacting fields changed, while `dATM` and the conserved fields did not.
- **SC-006** (reported): 4,219 s against the base's 7,646 s (ratio 0.55). The base time is from a 2026-10-23 run on another day, so this is not a controlled comparison.

**Not verified**:
- Rhea;
- the isomorphism path on any real corpus (no VMH copy needed it);
- re-running downstream outputs.

**Migration note**: reacting-moiety outputs built on `BG` since 2026-08-18 (feature 019/020) were built on corrupted bond graphs and should be re-run. Conserved-moiety outputs are unaffected.

Opening a PR to the fork's develop needs your approval.

## Diff summary

Against `5a4371497`, 25 files changed (+1,766 / −56):
- **Source**: `buildAtomAndBondTransitionMultigraph.m`. The reference-molblock map, `renumberCopiesOntoReference`, `moleculeIsomorphism` and `renumberBondAtoms` were added; `safeCanonicalizeBondAtoms`, `safeCanonicalizeOneAtom` and the `identifyAtomEquivalenceClasses` caches were removed. `identifyAtomEquivalenceClasses.m` got a help-only note.
- **Tests**:
  - `testBuildAtomAndBondTransitionMultigraph.m`: molfile equality on six fixtures, a planted moved bond, and a non-isomorphic copy;
  - `testConservedReactingMoieties.m`: the paper's values.
- **Test data**:
  - `rxnFilesNonIsomorphicCopy/` and `rxnFilesConsistentArms/`, each with a README;
  - both golden `.mat` references, recaptured with provenance.
- **Feature directory**: spec, plan, research, quickstart, contract, checklist and tasks; `molfileEqualityCheck.m`, `captureRenumberedGoldens.m`, `wholeMoleculeRenumberingCheck.m`; and the results file.

## Tests

- **Red** (T004): the molfile section fails on the unchanged source at `cit[m]`, the main fixture's corrupted metabolite.
- **Green**: all 16 tests in `test/verifiedTests/analysis/testReactingMoieties/` pass after the fix (T009), after the recapture (T011) and after the paper tests (T014).
- **Discrimination**: the paper test fails on `git archive 5a4371497` (7 vertices and 10 bonds, against the paper's 6 and 7).
- **Non-CI**: `wholeMoleculeRenumberingCheck` on the full collapsed VMH network gives 0 corrupted.

## Unresolved issues

- Rhea was not checked.
- No real-corpus copy has exercised the isomorphism path or the FR-003 warning.
- SC-006 base timing comes from another day.
- The eight `…Sanity` golden cases still raise the pre-existing `identifyIsomorphicClasses` sanity-check error, unchanged by this feature.
- Downstream reacting-moiety outputs since 2026-08-18 need re-running.

## Other information

- Every MATLAB job ran in its own memory-capped user scope, one at a time. The VMH job peaked at 6,558 MiB under a 16 GB cap.
- The origin of this feature is the reconXmoieties exploration `20261030-121933-reacting-moiety-memory`, E30–E33 (C9–C11).
