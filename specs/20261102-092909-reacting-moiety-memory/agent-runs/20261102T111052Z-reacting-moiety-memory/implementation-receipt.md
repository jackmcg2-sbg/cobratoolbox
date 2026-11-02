# Implementation receipt: 20261102-092909-reacting-moiety-memory

## Prompt

The spec, plan and tasks are approved. Run the Spec Kit implementation phase for the active feature.

## Final response

Implementation of the COBRA feature `20261102-092909-reacting-moiety-memory` is complete: tasks T001–T022 are all done, and the hard memory gate passes. Everything is committed locally on that branch in `~/cobratoolbox-rm-memory`. Nothing is pushed and no PR is open.

**Commits** (on the fork's develop, `8a927a4c6`):
- `74e6d04b0`: references captured from the unchanged source, plus the extended base-behaviour tests and their planted-difference controls.
- `ce0bb089f` … `0cc960148`: P1–P6, one commit each, cherry-picked from the prototypes without changes. The P1 and P2 commits carry the `computeGraphs` and `labelOnly` test sections.
- `4fcda054c`: the non-CI check script.
- `ec8fd9b7b`: help-text fixes, comment-only.
- A final commit with the results file, the ticked tasks and this receipt.

**Tests**: all 16 `testReactingMoieties` tests pass:
- on the unchanged source;
- after each of the six changes;
- on the final source.

The two new option sections fail on the unchanged source ("Too many input arguments") and pass with the changes. Every planted difference is detected.

**Equality (SC-002)**: full-mode outputs are `isequaln` to the base on random n=100, 250, 500 and 1,000 and on bfs n=500, with 4 of 4 controls detected on each.

**Memory gate (SC-003, hard)**: **pass**. At random n=1,000, median peak RSS during identification falls from 10.29 to 4.00 GiB, a ratio of 0.389 against the 0.50 gate (2 alternating runs each; siblings within 1%).

**Time (SC-004, reported)**: 251 → 149 s, a ratio of 0.595.

**Deviations from tasks.md** (recorded in its Implementation notes):
- The `labelOnly` and `computeGraphs` test sections landed with P2 and P1, not before them, because they can't run until the options exist.
- The check script was written after the six changes; its self-check uses the archived base copy, so the order doesn't matter.

**Not verified**:
- equality above 1,000 reactions and on full Rhea;
- the `sanityChecks = 1` full path on real subnetworks. On the five bond-key fixtures it raises the existing `identifyIsomorphicClasses.m:34` error, which is pinned as is; it is covered end to end only by the 3-reaction `mainDefaultSanity` case;
- memory after identification.

The plan opens the PR to the fork's develop only with your agreement.

## Diff summary

`git diff --stat 8a927a4c6 HEAD` (feature files only):

- `src/analysis/topology/reactingMoieties/identifyConservedReactingMoieties.m`: P1, the P2 caller, P4, P5.
- `src/analysis/topology/reactingMoieties/extractBondSubgraphs.m`: P2 (`labelOnly`), help text.
- `src/analysis/topology/reactingMoieties/findAndExtractMolecularGraphs.m`: P1 (`computeGraphs`), help text.
- `src/analysis/topology/reactingMoieties/classifySubgraphIsomorphism.m`: P3, P6, help text.
- `test/verifiedTests/analysis/testReactingMoieties/testExtractBondSubgraphs.m`, `testFindAndExtractMolecularGraphs.m`, `testClassifySubgraphIsomorphism.m`, `testConservedReactingMoieties.m`: extended.
- `test/verifiedTests/analysis/testReactingMoieties/data/reactingMoietyMemoryReference.mat` (1.48 MB) and `classifySubgraphIsomorphismGroupsReference.mat` (0.28 MB): new.
- `specs/20261102-092909-reacting-moiety-memory/`: spec, plan, research, contracts, quickstart, checklist and tasks; `captureMemoryReferences.m`, `reactingMoietyMemoryCheck.m`, `reactingMoietyMemoryCheck.sh`, `reactingMoietyMemoryResults.md`; and this receipt.

## Tests

- **`testReactingMoieties/`**: 16 of 16 pass on the unchanged source, after each of P1–P6, and after the help-text commit (runs `tests-base`, `tests-p1` … `tests-p6`, `tests-final`).
- **Red/green**: `testExtractBondSubgraphs` and `testFindAndExtractMolecularGraphs`, with the option sections, fail on the unchanged source and pass on the prototype source.
- **Non-CI equality**: 5 of 5 checkpoints are `isequaln`, with controls detected.
- **Self-check**: base against base is equal.
- **Memory gate**: the ratio is 0.389 (≤ 0.50). PASS.

## Unresolved issues

- The pre-existing `identifyIsomorphicClasses` sanity-check defect (out of scope) makes every `sanityChecks = 1` full-mode bond-key case an error case.
- Equality is untested above 1,000 reactions and on full Rhea.
- The $n^{2.5}$ growth of bond-subgraph edges remains (reconXmoieties exploration Q2).
- Not pushed; no pull request.

## Other information

Each MATLAB run went in its own capped user scope, one at a time, with at least the cap plus 8 GB available. Run outputs and the job log are kept in a work folder outside the repository.
