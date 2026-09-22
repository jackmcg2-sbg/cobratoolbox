# Reacting-moiety optimisation reproducibility results

Append-only record for feature `20260921-154310-reacting-moiety-optimisation`.

## Baseline (T001, 2026-09-22)

| Check | Result |
|---|---|
| `git diff --quiet develop -- src/ test/` | clean (exit 0) |
| `git rev-parse HEAD` | `2e3f1bcc983ad37a5f23befd2a5eb322dd89b5fc` (spec commit on top of `develop` @ `64efe1dc8`) |
| Corpus `/media/JACK/repos/ctf/rxns/atomMapped_std` | present (17075 entries) |
| `~/repos/ReconXKG-cidev/ReconXKGtoCobra/models/subsystemSubModels/subsystemSubModels.mat` | present |
| `test/models/mat/Recon3D_301.mat` | present |
| `changeCobraSolver('gurobi','MILP',0)` | true; `CBT_MILP_SOLVER = gurobi` |
| MATLAB | 24.2.0.3157250 (R2024b) Update 8 |

### Unit-test reference capture (T005)

`captureBondSubgraphReferences.m` on unmodified `src/` wrote
`test/verifiedTests/analysis/testReactingMoieties/data/bondSubgraphReference.mat` (203.8 kB). The capture
breakpoint fired at `identifyConservedReactingMoieties.m` line 847. `BIG` has 54 nodes and 60 edges;
`ATG` has 54 nodes and 54 edges. CI case: 26 bond subgraphs (16 conserved, 10 reacting).

Outcomes of the unmodified `extractBondSubgraphs` on the fallback cases. These are what the rewrite must
reproduce:

| Case | Outcome |
|---|---|
| `duplicateAtomIndex` | error `MATLAB:sizeDimensionsMustMatch`: Arrays have incompatible sizes for this operation. (`extractBondSubgraphs.m:56`) |
| `nonIntegerAtomIndex` | error `MATLAB:sizeDimensionsMustMatch`: Arrays have incompatible sizes for this operation. (`extractBondSubgraphs.m:56`) |
| `componentLabelOutOfRange` | ok (26 subgraphs) |
| `namedBIGNodes` | error `MATLAB:UndefinedFunction`: Undefined function 'eq' for input arguments of type 'cell'. (`extractBondSubgraphs.m:52`) |
| `zeroBIGEdges` | ok (0 subgraphs) |


### Run 2026-09-22 08:59 UTC — fixtures: nglycan,phe,andest,chol,urea,tyr,bileacid,ci; modes: default,conservedOnly

| Fixture | Mode | Run | Status | arm eq | moietyFormulae eq | reacting eq (differing fields) | console eq | median s before -> after (ratio) | targeted stages s before -> after | Solver | Corpus (.rxn) | Snapshot | Commit | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| nglycan | default | CAPTURE | CAPTURED | - | - | - | - | 1.43 -> - | - | gurobi | 17072 | in repo (0.1 MB) | 2e3f1bcc983a |  |
| nglycan | conservedOnly | CAPTURE | CAPTURED | - | - | - | - | - | - | gurobi | 17072 | in repo (0.1 MB) | 2e3f1bcc983a |  |
| phe | default | CAPTURE | CAPTURED | - | - | - | - | 2.75 -> - | - | gurobi | 17072 | in repo (0.3 MB) | 2e3f1bcc983a |  |
| phe | conservedOnly | CAPTURE | CAPTURED | - | - | - | - | - | - | gurobi | 17072 | in repo (0.3 MB) | 2e3f1bcc983a |  |
| andest | default | CAPTURE | CAPTURED | - | - | - | - | 6.84 -> - | - | gurobi | 17072 | in repo (0.6 MB) | 2e3f1bcc983a |  |
| andest | conservedOnly | CAPTURE | CAPTURED | - | - | - | - | - | - | gurobi | 17072 | in repo (0.6 MB) | 2e3f1bcc983a |  |
| chol | default | CAPTURE | CAPTURED | - | - | - | - | 19.56 -> - | - | gurobi | 17072 | in repo (2.1 MB) | 2e3f1bcc983a |  |
| chol | conservedOnly | CAPTURE | CAPTURED | - | - | - | - | - | - | gurobi | 17072 | in repo (2.1 MB) | 2e3f1bcc983a |  |
| urea | default | CAPTURE | CAPTURED | - | - | - | - | 9.85 -> - | - | gurobi | 17072 | in repo (1.4 MB) | 2e3f1bcc983a |  |
| urea | conservedOnly | CAPTURE | CAPTURED | - | - | - | - | - | - | gurobi | 17072 | in repo (1.4 MB) | 2e3f1bcc983a |  |
| tyr | default | CAPTURE | CAPTURED | - | - | - | - | 15.66 -> - | - | gurobi | 17072 | in repo (2.4 MB) | 2e3f1bcc983a |  |
| tyr | conservedOnly | CAPTURE | CAPTURED | - | - | - | - | - | - | gurobi | 17072 | in repo (2.3 MB) | 2e3f1bcc983a |  |
| bileacid | default | CAPTURE | CAPTURED | - | - | - | - | 45.96 -> - | 09: 42.32; 14-17: 4.14 (profiled, relative) | gurobi | 17072 | in repo (4.2 MB) | 2e3f1bcc983a |  |
| bileacid | conservedOnly | CAPTURE | CAPTURED | - | - | - | - | - | - | gurobi | 17072 | in repo (4.1 MB) | 2e3f1bcc983a |  |
| ci | default | CAPTURE | CAPTURED | - | - | - | - | 0.17 -> - | - | gurobi | 18 | in repo (0.0 MB) | 2e3f1bcc983a |  |
| ci | conservedOnly | CAPTURE | CAPTURED | - | - | - | - | - | - | gurobi | 18 | in repo (0.0 MB) | 2e3f1bcc983a |  |

### Run 2026-09-22 09:13 UTC — fixtures: ci,tyr; modes: sanity

| Fixture | Mode | Run | Status | arm eq | moietyFormulae eq | reacting eq (differing fields) | console eq | median s before -> after (ratio) | targeted stages s before -> after | Solver | Corpus (.rxn) | Snapshot | Commit | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ci | sanity | CAPTURE | CAPTURED (error outcome) | - | - | - | - | - | - | gurobi | 18 | in repo (0.0 MB) | 2e3f1bcc983a | : Inconsistent mapping of atoms to connected components. (identifyIsomorphicClasses:34) |
| tyr | sanity | CAPTURE | CAPTURED (error outcome) | - | - | - | - | - | - | gurobi | 17072 | in repo (0.0 MB) | 2e3f1bcc983a | : Inconsistent mapping of atom transition instances to each atom transition in A2Ti (identifyConservedReactingMoieties:499) |

### Notes on the sanity-mode capture (T007) and the CI baseline (T008)

- Both `sanity` captures (`sanityChecks = 1`) raise an error on unmodified `src/`. This is the crash that
  predates this feature, and the snapshot records it as the expected outcome.
  - `ci` fails in `identifyIsomorphicClasses:34` ("Inconsistent mapping of atoms to connected
    components."). That is the STEP B3 call, after `extractBondSubgraphs` and
    `findAndExtractMolecularGraphs` have run, so the `ci`/`sanity` comparison does exercise the rewritten
    stage-09 functions up to that point.
  - `tyr` fails at `identifyConservedReactingMoieties:499` ("Inconsistent mapping of atom transition
    instances to each atom transition in A2Ti"), which comes before any changed block. Its `sanity`
    comparison therefore only confirms that the early failure is unchanged; it does not exercise the
    rewrite.
- T008: `testConservedReactingMoieties.m` **passes** on unmodified `src/` (gurobi, R2024b), which is the
  SC-002 baseline.
