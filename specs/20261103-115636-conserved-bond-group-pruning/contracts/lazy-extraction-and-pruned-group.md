# Contract: lazy bond-subgraph extraction and the pruned conserved group

## `[bondSubgraphs, BMG, bmgEdgeIndex, subgraphSizes] = extractBondSubgraphs(BIG, ATG, labelOnly, subgraphsToBuild)`

- **`subgraphsToBuild`**: trailing, optional.
  - **Absent or empty**: every entry is built, and the first three outputs are identical to the three-input call (Principle II, VII-D).
  - **A vector of component indices** (extraction order, `1..nComponents`, any order, duplicates allowed): those entries of `bondSubgraphs` and `BMG` are built, and every other entry is `[]`.
  - **`0`**: no entry is built.
- **Built entries**: `isequaln` to the same entries of the eager call with the same `labelOnly`.
- **`bmgEdgeIndex`**: always complete, and identical to the eager call.
- **`subgraphSizes`**: an `nComponents × 2` double. `subgraphSizes(k, :) = [numnodes(bondSubgraphs{k}), numedges(bondSubgraphs{k})]` of the eager call, for every k, whether built or not.
- **Fallback paths** (duplicated or non-integer `AtomIndex`, a component label out of range, non-numeric end nodes, a non-`conncomp` `ATG.Nodes.Component`): every entry is built whatever `subgraphsToBuild` says. `subgraphSizes` is read from the built graphs.
- **A BIG without edges**: four empty outputs (`subgraphSizes` is `zeros(0, 2)`).
- **Index out of range**: an error naming the index (identifier `extractBondSubgraphs:subgraphIndexOutOfRange`).
- **Errors**: those raised today keep their identifier and message.

## `[conservedGroup, reactingGroups, diagnostics] = findConservedBondGroup(subgraphSizes, buildSubgraphs)`

- **`subgraphSizes`**: `nComponents × 2`, as above.
- **`buildSubgraphs`**: a function handle. `buildSubgraphs(idx)` returns a cell column of the bond subgraphs of components `idx`, in the order of `idx`.
- **Result**: `conservedGroup` and `reactingGroups` are identical (values, orientation, class) to outputs 5 and 6 of `findAndExtractMolecularGraphs(BIG, BMG, bondSubgraphs, bmgEdgeIndex, false)` on the eager extraction of the same components.
- **`diagnostics`**: a struct with fields:
  - `numSizeGroups`;
  - `groupsClassified`;
  - `componentsBuilt`: the total length of all `idx` passed to `buildSubgraphs`.
- **`buildSubgraphs` calls**: only with the members of a size group it classifies, each group once.

## Unchanged surfaces

- `identifyConservedReactingMoieties`: signature, options, outputs, messages and errors. With `sanityChecks = 1`, its bond stage is unchanged.
- `findAndExtractMolecularGraphs`, `classifySubgraphIsomorphism`, `identifyIsomorphicClasses`: unchanged.
