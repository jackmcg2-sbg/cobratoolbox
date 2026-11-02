# Contract: the two new optional inputs

Both inputs are trailing and optional. When absent or empty, each gives the historical behaviour (Principle II), handled with `exist`/`isempty` (VII-D).

## `extractBondSubgraphs(BIG, ATG, labelOnly)`

- **`labelOnly`**: logical. The default is `false`, which gives outputs identical to the two-input call.
- **`true`, default peeling path**:
  - `bondSubgraphs{k}` has the same class (`graph`, or `digraph` for a directed ATG) and node count as with `false`. It has the same `EndNodes` in the same order, and no node or edge variables.
  - `BMG{m}` is a `digraph` with the same node count and edge order as with `false`. It has no node table, and edge variables exactly `intersect({'EndNodes','BondIndex','EdgeIndex','mets'}, BIG.Edges.Properties.VariableNames, 'stable')`, equal column by column to the full `BMG{m}`.
  - `bmgEdgeIndex` is identical.
- **`true`, fallback paths** (duplicated or non-integer `AtomIndex`, a component label out of range, named BIG nodes, a BIG without edges, the non-peeling branches): the outputs are identical to `false`, and errors keep their identifier and message.

## `findAndExtractMolecularGraphs(BIG, BMG, bondSubgraphs, bmgEdgeIndex, computeGraphs)`

- **`computeGraphs`**: logical. The default is `true`, which gives all six outputs identical to the four-input call.
- **`false`**: `conservedGroup` and `reactingGroups` are identical to `true`, and `CMTG`, `RMTG`, `CMG` and `RMG` are `[]`.

## Unchanged surfaces

- `classifySubgraphIsomorphism`: signature, outputs, diagnostic actions (`'resetCallCount'`, `'getCallCount'`) and call counts.
- `identifyConservedReactingMoieties`: signature, options, outputs, messages and errors.
