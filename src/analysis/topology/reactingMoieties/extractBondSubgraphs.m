function [bondSubgraphs, BMG, bmgEdgeIndex, subgraphSizes] = extractBondSubgraphs(BIG, ATG, labelOnly, subgraphsToBuild)
% Extract subgraphs of bonds and their mappings from a bond instance graph
%
% USAGE:
%
%    [bondSubgraphs, BMG] = extractBondSubgraphs(BIG, ATG)
%    [bondSubgraphs, BMG, bmgEdgeIndex] = extractBondSubgraphs(BIG, ATG)
%    [bondSubgraphs, BMG, bmgEdgeIndex] = extractBondSubgraphs(BIG, ATG, labelOnly)
%    [bondSubgraphs, BMG, bmgEdgeIndex, subgraphSizes] = extractBondSubgraphs(BIG, ATG, labelOnly, subgraphsToBuild)
%
% INPUTS:
%    BIG:    bond instance graph, the full weighted bond graph containing all bonds and weights
%    ATG:    atom transition graph, representing atoms as nodes and their bonds as edges, with field:
%
%              * .Nodes - node table with `AtomIndex` and `Component` columns
%
% OPTIONAL INPUTS:
%    labelOnly:  logical, default false. If true, each subgraph keeps only what the
%                isomorphism classification of identifyConservedReactingMoieties reads:
%                `bondSubgraphs{k}` has no node or edge variables (same nodes, and the
%                same end nodes in the same order, as the full subgraph), and `BMG{m}`
%                has no node table and keeps only the edge variables `EndNodes`,
%                `BondIndex`, `EdgeIndex` and `mets` (same nodes and edge order). This
%                holds far less memory per subgraph. It applies to the default peeling
%                path; the fallback paths described below always return full subgraphs.
%    subgraphsToBuild:  indices of the subgraphs (in extraction order) whose `bondSubgraphs`
%                and `BMG` entries are built; every other entry is `[]`. Default (absent or
%                empty): all are built, as without this input. `0` builds none (indices start
%                at 1, so `0` names no subgraph and is otherwise ignored). `bmgEdgeIndex` and
%                `subgraphSizes` are always complete, and a built entry is identical to the
%                entry built when all are built. It applies to the default peeling path; the
%                fallback paths build every entry.
%
% OUTPUTS:
%    bondSubgraphs:    cell array where each entry represents a subgraph of connected bonds
%    BMG:              cell array of bond mapping graphs, representing isolated sets of mapped bonds
%
% OPTIONAL OUTPUT:
%    bmgEdgeIndex:     cell array, the same size as `BMG`; `bmgEdgeIndex{m}` holds the
%                      `EdgeIndex` values of the edges of `BMG{m}` (the same set as
%                      `BMG{m}.Edges.EdgeIndex`, in the order the edges were extracted)
%    subgraphSizes:    `numel(BMG) x 2` matrix; row k is the node count and the edge count of
%                      `bondSubgraphs{k}` as built when all are built, whether or not it is
%                      built in this call
%
% NOTE:
%    The bond instance graph is peeled component pair by component pair, then layer by
%    layer of repeated bond instances. The bond instance edges and the atom transition
%    edges are grouped once by the pair of components of their end atoms, and a per-edge
%    flag marks the bond instance edges already peeled, so each component pair costs time
%    in proportion to its own size, instead of rebuilding or scanning the whole graphs at
%    every step. The subgraphs of a component pair are assembled in the node and edge
%    order `subgraph` gives them, and the outputs are identical to those of the original
%    implementation. When the atom and edge indices do not allow the lookup arrays
%    (non-integer, non-positive or duplicated `AtomIndex`, component labels outside
%    `1..max(conncomp(ATG))`, non-numeric end nodes), the original algorithm is used
%    instead; when `ATG.Nodes.Component` is not the `conncomp(ATG)` labelling, the
%    previous peeling loop is used.
%
% .. Author: - COBRA Toolbox, features 20260921-154310-reacting-moiety-optimisation,
%              20260928-100409-extract-bond-subgraphs-local-peeling and
%              20261102-092909-reacting-moiety-memory (labelOnly) and
%              20261103-115636-conserved-bond-group-pruning (subgraphsToBuild, subgraphSizes)

% Find connected components of underlying undirected graph.
% Each component corresponds to an "atom conservation relation".
if verLessThan('matlab','8.6')
    error('Requires matlab R2015b+')
else
    %assign the atoms of the atom transition graph into different
    %connected components
    atoms2component = conncomp(ATG)'; % Use built-in matlab algorithm. Introduced in R2015b.
    nComps = max(atoms2component);
end

if ~exist('labelOnly', 'var') || isempty(labelOnly)
    labelOnly = false;
end
% isRequested(k): whether the k-th subgraph is built (all of them by default)
if ~exist('subgraphsToBuild', 'var') || isempty(subgraphsToBuild)
    buildAll = true;
    subgraphsToBuild = [];
    isRequested = true(0, 1);
else
    if ~isnumeric(subgraphsToBuild) || any(subgraphsToBuild(:) < 0) || ...
            any(subgraphsToBuild(:) ~= fix(subgraphsToBuild(:)))
        error('extractBondSubgraphs:invalidSubgraphIndex', ...
            'subgraphsToBuild must hold non-negative whole numbers.');
    end
    buildAll = false;
    subgraphsToBuild = subgraphsToBuild(subgraphsToBuild > 0);
    isRequested = false(max([0; subgraphsToBuild(:)]), 1);
    isRequested(subgraphsToBuild) = true;
end

% A bond instance graph without edges yields no subgraphs
if numedges(BIG) == 0
    bondSubgraphs = {};
    BMG = {};
    bmgEdgeIndex = {};
    subgraphSizes = zeros(0, 2);
    checkSubgraphIndices(subgraphsToBuild, 0);
    return
end

% Lookup arrays: component of every atom index, and the edge arrays of BIG
atomIndexATG = full(ATG.Nodes.AtomIndex);
componentATG = full(ATG.Nodes.Component);
endNodes = BIG.Edges.EndNodes;
edgeIdx = BIG.Edges.EdgeIndex;

isPositiveWholeNumeric = @(v) isnumeric(v) && all(v(:) >= 1) && all(v(:) == fix(v(:)));
lookupOK = isPositiveWholeNumeric(atomIndexATG) && isPositiveWholeNumeric(componentATG) ...
    && isPositiveWholeNumeric(endNodes) ...
    && numel(unique(atomIndexATG)) == numel(atomIndexATG) ...
    && all(componentATG <= nComps) && all(endNodes(:) <= max(atomIndexATG));
if lookupOK
    compOfAtom = zeros(max(atomIndexATG), 1);
    compOfAtom(atomIndexATG) = componentATG;
    lookupOK = all(compOfAtom(endNodes(:)) > 0);
end
if ~lookupOK
    [bondSubgraphs, BMG] = extractBondSubgraphsByComponentScan(BIG, ATG, atoms2component);
    bmgEdgeIndex = cellfun(@(g) g.Edges.EdgeIndex, BMG, 'UniformOutput', false);
    subgraphSizes = sizesOfSubgraphs(bondSubgraphs);
    checkSubgraphIndices(subgraphsToBuild, numel(BMG));
    return
end

% Positions of the atoms of every component, ascending, as find(atoms2component == c)
nodesByComp = accumarray(atoms2component(:), (1:numel(atoms2component))', [nComps, 1], ...
    @(v) {sort(v(:))});

% The peeling below always processes the first remaining edge, which relies on every atom
% lying in the component its Component label names, i.e. on ATG.Nodes.Component being the
% conncomp(ATG) labelling, as identifyConservedReactingMoieties sets it. Otherwise the
% previous peeling loop is used.
if ~isequal(componentATG(:), atoms2component(:))
    [bondSubgraphs, BMG, bmgEdgeIndex] = extractBondSubgraphsByEdgeScan(BIG, ATG, compOfAtom, ...
        nodesByComp, endNodes, edgeIdx);
    subgraphSizes = sizesOfSubgraphs(bondSubgraphs);
    checkSubgraphIndices(subgraphsToBuild, numel(BMG));
    return
end

% Edge and node tables of BIG, read once (every read of BIG.Edges builds a full table)
BIGEdges = BIG.Edges;
BIGNodes = BIG.Nodes;
nBIGNodes = numnodes(BIG);
% edge variables kept by labelOnly (those of them BIG has)
labelOnlyEdgeVars = intersect({'EndNodes', 'BondIndex', 'EdgeIndex', 'mets'}, ...
    BIGEdges.Properties.VariableNames, 'stable');
nEdges = size(endNodes, 1);

% Group the bond instance edges by the unordered pair of components of their end atoms.
% The edges with both end atoms in components A and B are then exactly the buckets
% (A,A), (B,B) and (A,B), so each component pair only touches its own edges.
edgeComp = reshape(compOfAtom(endNodes), [], 2);
[edgesByBucket, bucketId] = buildPairEdgeIndex(min(edgeComp, [], 2), max(edgeComp, [], 2), nComps);

% Edge and node tables of ATG, read once, with its edges grouped by component pair in the
% same way (edges can join two strong components of a digraph ATG)
ATGNodes = ATG.Nodes;
ATGEdges = ATG.Edges;
[atgSource, atgTarget] = findedge(ATG);
atgEnds = [atgSource(:), atgTarget(:)];
isDirectedATG = isa(ATG, 'digraph');
atgEdgeComp = reshape(atoms2component(atgEnds), [], 2);
[atgEdgesByBucket, atgBucketId] = buildPairEdgeIndex(min(atgEdgeComp, [], 2), ...
    max(atgEdgeComp, [], 2), nComps);
% Position of each ATG node in the current component pair (0 outside it)
localPosATG = zeros(numel(atoms2component), 1);

% Processed edges are flagged rather than removed from a copy of BIG; the rows still
% flagged are, in order, the edge table that copy would have
remaining = true(nEdges, 1);
% Position of each atom in the current component pair (0 outside it)
localPos = zeros(max(max(atomIndexATG), nBIGNodes), 1);

% Initialize cell arrays to store all combined subgraphs
bondSubgraphs = {};  % Contains subgraphs of connected bonds
BMG = {};  % Bond Mapping Graphs: Isolated sets of bonds that are mapped to each other
bmgEdgeIndex = {};  % EdgeIndex values of the edges of each Bond Mapping Graph
subgraphSizes = zeros(0, 2);  % node and edge counts of each bond subgraph
bondIndexAll = BIGEdges.BondIndex;

% Initialize counter for the subgraph index
subgraphIndex = 1;

% Each pass peels every remaining edge of the component pair of the first remaining edge,
% that edge included, so the next pass starts at the next remaining edge
first = 1;
while first <= nEdges
    % Define the component IDs for the nodes involved in the bond
    component1 = compOfAtom(endNodes(first, 1));
    component2 = compOfAtom(endNodes(first, 2));
    lowComp = min(component1, component2);
    highComp = max(component1, component2);

    % Combine the nodes from both components. Normally component1 and
    % component2 are distinct, so this is a simple union of two disjoint
    % node sets. However, for bond-cleaving reactions (e.g. peroxidases,
    % hydrolases) where a bond within a reactant connects two atoms that
    % end up in different product molecules, atom-transition tracking can
    % merge both product fragments (and the original reactant) into a
    % single connected component -- so the bond's own two endpoint atoms
    % can already share the same component (component1 == component2).
    % In that case the two node sets are identical, and concatenating
    % them would duplicate every node, which subgraph() rejects. Guard
    % against that case explicitly.
    if component1 == component2
        nodesInBothComponents = nodesByComp{component1};
    else
        nodesInBothComponents = [nodesByComp{component1}; nodesByComp{component2}];
    end
    % When none of this pair's subgraphs is requested, its layers, edge indices and sizes
    % are computed from the edge indices alone, without building any table or graph
    if ~buildAll
        [pairRows, pairAtgEdgeCount] = pairEdgeRows(lowComp, highComp, bucketId, edgesByBucket, ...
            atgBucketId, atgEdgesByBucket, remaining);
        % local end nodes, as below (localPos is marked here, not in a helper, so that it is
        % never copied)
        pairAtoms = atomIndexATG(nodesInBothComponents);
        if any(pairAtoms > nBIGNodes)
            % the error the built path raises for these atoms, as below
            subgraph(BIG, pairAtoms);
        end
        localPos(pairAtoms) = 1:numel(pairAtoms);
        localEnds = reshape(localPos(endNodes(pairRows, :)), [], 2);
        localPos(pairAtoms) = 0;
        [layerRows, nLayers] = peelLayers(pairRows, localEnds, bondIndexAll);
        pairSubgraphs = subgraphIndex:subgraphIndex + nLayers - 1;
        pairSubgraphs = pairSubgraphs(pairSubgraphs <= numel(isRequested));
        if ~any(isRequested(pairSubgraphs))
            for layer = 1:nLayers
                bondSubgraphs{subgraphIndex, 1} = []; %#ok<AGROW>
                BMG{subgraphIndex, 1} = []; %#ok<AGROW>
                bmgEdgeIndex{subgraphIndex, 1} = edgeIdx(layerRows{layer}); %#ok<AGROW>
                subgraphSizes(subgraphIndex, :) = [numel(nodesInBothComponents), ...
                    pairAtgEdgeCount + numel(layerRows{layer})]; %#ok<AGROW>
                subgraphIndex = subgraphIndex + 1;
            end
            % Flag the peeled edges as processed and move to the next remaining edge
            remaining(pairRows) = false;
            while first <= nEdges && ~remaining(first)
                first = first + 1;
            end
            continue
        end
    end

    % Create the subgraph containing nodes from both selected components, from the ATG
    % edges of the component pair only: numbered locally ([min max] for an undirected ATG)
    % and sorted by local end nodes with ties in ATG order, as subgraph(ATG, ...) orders them
    atgBuckets = full([atgBucketId(lowComp, lowComp); atgBucketId(highComp, highComp); ...
        atgBucketId(lowComp, highComp)]);
    atgBuckets = unique(atgBuckets(atgBuckets > 0));
    atgRows = vertcat(zeros(0, 1), atgEdgesByBucket{atgBuckets});
    localPosATG(nodesInBothComponents) = 1:numel(nodesInBothComponents);
    atgLocalEnds = reshape(localPosATG(atgEnds(atgRows, :)), [], 2);
    localPosATG(nodesInBothComponents) = 0;
    if ~isDirectedATG
        atgLocalEnds = [min(atgLocalEnds, [], 2), max(atgLocalEnds, [], 2)];
    end
    [~, atgOrder] = sortrows([atgLocalEnds atgRows]);
    if labelOnly
        % the same nodes and end nodes, without the node and edge tables
        nCombined = numel(nodesInBothComponents);
        if isDirectedATG
            combinedSubgraph = digraph(atgLocalEnds(atgOrder, 1), atgLocalEnds(atgOrder, 2), [], nCombined);
        else
            combinedSubgraph = graph(atgLocalEnds(atgOrder, 1), atgLocalEnds(atgOrder, 2), [], nCombined);
        end
    else
        combinedEdges = ATGEdges(atgRows(atgOrder), :);
        combinedEdges.EndNodes = atgLocalEnds(atgOrder, :);
        if isDirectedATG
            combinedSubgraph = digraph(combinedEdges, ATGNodes(nodesInBothComponents, :));
        else
            combinedSubgraph = graph(combinedEdges, ATGNodes(nodesInBothComponents, :));
        end
    end

    % Atoms of the component pair, in the node order of combinedSubgraph
    pairAtoms = atomIndexATG(nodesInBothComponents);
    if any(pairAtoms > nBIGNodes)
        % Raise the error that selecting these atoms from BIG raised before this change;
        % never reached on valid inputs
        subgraph(BIG, pairAtoms);
    end

    % Remaining edges with both end atoms in the component pair, numbered locally and in
    % the row order subgraph(BIGCopy, pairAtoms) gave them: sorted by local (source,
    % target), ties kept in their order in BIG
    buckets = full([bucketId(lowComp, lowComp); bucketId(highComp, highComp); ...
        bucketId(lowComp, highComp)]);
    buckets = unique(buckets(buckets > 0));
    rows = vertcat(zeros(0, 1), edgesByBucket{buckets});
    rows = rows(remaining(rows));
    localPos(pairAtoms) = 1:numel(pairAtoms);
    localEnds = reshape(localPos(endNodes(rows, :)), [], 2);
    localPos(pairAtoms) = 0;
    [~, order] = sortrows([localEnds rows]);
    rows = rows(order);

    % Edge and node tables of the bond instance subgraph of the component pair
    if labelOnly
        GEdges = BIGEdges(rows, labelOnlyEdgeVars);
        nGNodes = numel(pairAtoms);
    else
        GEdges = BIGEdges(rows, :);
        GNodes = BIGNodes(pairAtoms, :);
    end
    GEdges.EndNodes = localEnds(order, :);

    % Initialize cell arrays to store the combined subgraphs for each iteration
    combinedSubgraphs = {};
    BMgraph = {};  % Temporary storage for Bond Mapping Graphs
    BMedgeIdx = {};  % Temporary storage for their EdgeIndex values
    layerSizes = zeros(0, 2);  % Temporary storage for the sizes of the combined subgraphs

    % Repeat until no edges of GBB are left
    while size(GEdges, 1) > 0
        % Get unique BondIndex values
        [~, firstOccurrenceIndices, groupIndices] = unique(GEdges.BondIndex, 'first');

        % Calculate the number of occurrences of each unique BondIndex
        occurrences = accumarray(groupIndices, 1);
        maxOccurrences = max(occurrences);

        % Peel one layer of first occurrences per repeat
        for layer = 1:maxOccurrences
            % Extract the first occurrence indices
            layerEdgeIdx = GEdges.EdgeIndex(firstOccurrenceIndices);

            % Source and target nodes of those edges
            layerEndNodes = GEdges.EndNodes(firstOccurrenceIndices, :);

            % Subgraphs not requested are not built (their entries stay empty)
            buildThis = buildAll || (subgraphIndex + layer - 1 <= numel(isRequested) && ...
                isRequested(subgraphIndex + layer - 1));
            layerSizes(layer, :) = [numnodes(combinedSubgraph), ...
                numedges(combinedSubgraph) + numel(firstOccurrenceIndices)]; %#ok<AGROW>

            % Create the Bond Mapping Graph for the current set of bonds
            EdgeTable = GEdges(firstOccurrenceIndices, :);
            if ~buildThis
                BMgraph{layer, 1} = []; %#ok<AGROW>
            elseif labelOnly
                % digraph sorts the edge rows exactly as with the node table; the
                % isolated nodes of the pair are then appended
                bmGraph = digraph(EdgeTable);
                if numnodes(bmGraph) < nGNodes
                    bmGraph = addnode(bmGraph, nGNodes - numnodes(bmGraph));
                end
                BMgraph{layer, 1} = bmGraph; %#ok<AGROW>
            else
                BMgraph{layer, 1} = digraph(EdgeTable, GNodes); %#ok<AGROW>
            end
            BMedgeIdx{layer, 1} = layerEdgeIdx; %#ok<AGROW>

            % Add these edges to the combined subgraph
            if buildThis
                combinedSubgraphs{layer, 1} = addedge(combinedSubgraph, ...
                    layerEndNodes(:, 1), layerEndNodes(:, 2)); %#ok<AGROW>
            else
                combinedSubgraphs{layer, 1} = []; %#ok<AGROW>
            end

            % Remove the processed edges (row order of the rest is kept, as rmedge does)
            GEdges(firstOccurrenceIndices, :) = [];

            % Update `firstOccurrenceIndices` after edge removal
            if size(GEdges, 1) > 0
                [~, firstOccurrenceIndices, ~] = unique(GEdges.BondIndex, 'first');
            else
                break; % No more edges left
            end
        end
    end

    % Store the combined subgraphs created in this iteration
    for m = 1:length(combinedSubgraphs)
        bondSubgraphs{subgraphIndex, 1} = combinedSubgraphs{m}; %#ok<AGROW>
        BMG{subgraphIndex, 1} = BMgraph{m}; %#ok<AGROW>
        bmgEdgeIndex{subgraphIndex, 1} = BMedgeIdx{m}; %#ok<AGROW>
        subgraphSizes(subgraphIndex, :) = layerSizes(m, :); %#ok<AGROW>
        subgraphIndex = subgraphIndex + 1; % Increment subgraph index
    end

    % Flag the peeled edges as processed and move to the next remaining edge
    remaining(rows) = false;
    while first <= nEdges && ~remaining(first)
        first = first + 1;
    end
end
checkSubgraphIndices(subgraphsToBuild, numel(BMG));

end

function [bondSubgraphs, BMG, bmgEdgeIndex] = extractBondSubgraphsByEdgeScan(BIG, ATG, compOfAtom, ...
    nodesByComp, endNodes, edgeIdx)
% The previous peeling loop of extractBondSubgraphs, which removes the processed edges from
% a copy of the bond instance graph after every component pair. It is kept for inputs
% whose ATG.Nodes.Component is not the conncomp(ATG) labelling, where the processed edge is
% not always the first remaining one, so that such inputs give exactly the results, or
% raise exactly the errors, they always did.

% Initialize cell arrays to store all combined subgraphs
bondSubgraphs = {};  % Contains subgraphs of connected bonds
BMG = {};  % Bond Mapping Graphs: Isolated sets of bonds that are mapped to each other
bmgEdgeIndex = {};  % EdgeIndex values of the edges of each Bond Mapping Graph

% Initialize counter for the subgraph index
subgraphIndex = 1;

% Make a copy of BIG for processing; endNodes and edgeIdx mirror its edge table
BIGCopy = BIG;

% Iterate until all edges are processed from BIGCopy
while size(endNodes, 1) > 0
    % Update the number of bonds after each iteration, since BIGCopy changes
    numBonds = size(endNodes, 1);
    bondIdProcessed = [];  % Reinitialize to store processed bond IDs in each iteration

    % Iterate over each bond in BIGCopy
    k = 1; % Initialize iteration counter for edges
    while k <= numBonds
        % Define the component IDs for the nodes involved in the bond
        component1 = compOfAtom(endNodes(k, 1));
        component2 = compOfAtom(endNodes(k, 2));

        % Combine the nodes from both components. Normally component1 and
        % component2 are distinct, so this is a simple union of two disjoint
        % node sets. However, for bond-cleaving reactions (e.g. peroxidases,
        % hydrolases) where a bond within a reactant connects two atoms that
        % end up in different product molecules, atom-transition tracking can
        % merge both product fragments (and the original reactant) into a
        % single connected component -- so the bond's own two endpoint atoms
        % can already share the same component (component1 == component2).
        % In that case the two node sets are identical, and concatenating
        % them would duplicate every node, which subgraph() rejects. Guard
        % against that case explicitly.
        if component1 == component2
            nodesInBothComponents = nodesByComp{component1};
        else
            nodesInBothComponents = [nodesByComp{component1}; nodesByComp{component2}];
        end
        % Create the subgraph containing nodes from both selected components
        combinedSubgraph = subgraph(ATG, nodesInBothComponents);

        % Find the subgraph in BIGCopy that corresponds to the combined subgraph
        % by selecting edges whose nodes match the AtomIndex in the combinedSubgraph.
        % Only its edge and node tables are used from here on.
        GBB = subgraph(BIGCopy, combinedSubgraph.Nodes.AtomIndex);
        GEdges = GBB.Edges;
        GNodes = GBB.Nodes;

        % Initialize cell arrays to store the combined subgraphs for each iteration
        combinedSubgraphs = {};
        BMgraph = {};  % Temporary storage for Bond Mapping Graphs
        BMedgeIdx = {};  % Temporary storage for their EdgeIndex values

        % Repeat until no edges of GBB are left
        while size(GEdges, 1) > 0
            % Get unique BondIndex values
            [~, firstOccurrenceIndices, groupIndices] = unique(GEdges.BondIndex, 'first');

            % Calculate the number of occurrences of each unique BondIndex
            occurrences = accumarray(groupIndices, 1);
            maxOccurrences = max(occurrences);

            % Peel one layer of first occurrences per repeat
            for layer = 1:maxOccurrences
                % Extract the first occurrence indices
                layerEdgeIdx = GEdges.EdgeIndex(firstOccurrenceIndices);
                bondIdProcessed = [bondIdProcessed; layerEdgeIdx]; %#ok<AGROW>

                % Source and target nodes of those edges
                layerEndNodes = GEdges.EndNodes(firstOccurrenceIndices, :);

                % Create the Bond Mapping Graph for the current set of bonds
                EdgeTable = GEdges(firstOccurrenceIndices, :);
                BMgraph{layer, 1} = digraph(EdgeTable, GNodes); %#ok<AGROW>
                BMedgeIdx{layer, 1} = layerEdgeIdx; %#ok<AGROW>

                % Add these edges to the combined subgraph
                combinedSubgraphs{layer, 1} = addedge(combinedSubgraph, ...
                    layerEndNodes(:, 1), layerEndNodes(:, 2)); %#ok<AGROW>

                % Remove the processed edges (row order of the rest is kept, as rmedge does)
                GEdges(firstOccurrenceIndices, :) = [];

                % Update `firstOccurrenceIndices` after edge removal
                if size(GEdges, 1) > 0
                    [~, firstOccurrenceIndices, ~] = unique(GEdges.BondIndex, 'first');
                else
                    break; % No more edges left
                end
            end
        end

        % Store the combined subgraphs created in this iteration
        for m = 1:length(combinedSubgraphs)
            bondSubgraphs{subgraphIndex, 1} = combinedSubgraphs{m}; %#ok<AGROW>
            BMG{subgraphIndex, 1} = BMgraph{m}; %#ok<AGROW>
            bmgEdgeIndex{subgraphIndex, 1} = BMedgeIdx{m}; %#ok<AGROW>
            subgraphIndex = subgraphIndex + 1; % Increment subgraph index
        end

        % Find IDs of the edges that have been processed in BIGCopy
        idsToRemove = find(ismember(edgeIdx, bondIdProcessed));

        % Remove the processed edges from BIGCopy and from its mirrored edge arrays
        BIGCopy = rmedge(BIGCopy, idsToRemove);
        endNodes(idsToRemove, :) = [];
        edgeIdx(idsToRemove) = [];

        % Update the number of bonds after removing edges
        numBonds = size(endNodes, 1);

        % If we have removed edges, do not increment `k` as it needs to check the new first edge
        % Else increment to the next edge
        if numBonds == 0
            break; % No more edges left
        elseif ismember(k, idsToRemove)
            k = 1; % Reset to first edge after removal
        else
            k = k + 1; % Increment to next edge
        end
    end
end

end

function [edgesByBucket, bucketId] = buildPairEdgeIndex(lowComp, highComp, nComps)
% Group edge rows by the unordered pair of components of their end nodes
%
% INPUTS:
%    lowComp:     n x 1, the smaller component of the two end nodes of every edge
%    highComp:    n x 1, the larger component of the two end nodes of every edge
%    nComps:      number of components
%
% OUTPUTS:
%    edgesByBucket:    cell array, the ascending edge rows of every distinct pair
%    bucketId:         nComps x nComps sparse, bucketId(lowComp, highComp) is the index
%                      of that pair in edgesByBucket, 0 when no edge joins the pair

if isempty(lowComp)
    edgesByBucket = {};
    bucketId = sparse(nComps, nComps);
    return
end
[pairKeys, firstRow, bucketOfEdge] = unique([lowComp(:), highComp(:)], 'rows');
edgesByBucket = accumarray(bucketOfEdge, (1:numel(lowComp))', [], @(v) {sort(v)});
bucketId = sparse(pairKeys(:, 1), pairKeys(:, 2), bucketOfEdge(firstRow), nComps, nComps);
end

function [bondSubgraphs, BMG] = extractBondSubgraphsByComponentScan(BIG, ATG, atoms2component)
% The original extractBondSubgraphs algorithm, which reads the component of every bond's
% end atoms by scanning ATG.Nodes. It is kept as the fallback for inputs whose atom or edge
% indices do not allow the lookup arrays of the main function, so that such inputs give
% exactly the results, or raise exactly the errors, they always did.

% Initialize cell array to store all combined subgraphs
bondSubgraphs = {};  % Contains subgraphs of connected bonds
BMG = {};  % Bond Mapping Graphs: Isolated sets of bonds that are mapped to each other

% Initialize counter for the subgraph index
subgraphIndex = 1;

% Make a copy of BGW for processing
BIGCopy = BIG;

% Iterate until all edges are processed from BGWCopy
while numedges(BIGCopy) > 0
    % Update the number of bonds after each iteration, since BGWCopy changes
    numBonds = numedges(BIGCopy);
    bondIdProcessed = [];  % Reinitialize to store processed bond IDs in each iteration

    % Iterate over each bond in BGWCopy
    k = 1; % Initialize iteration counter for edges
    while k <= numBonds
        % Get the tail and head atom indices for the current bond in BGWCopy
        i = BIGCopy.Edges.EndNodes(k, 1);
        j = BIGCopy.Edges.EndNodes(k, 2);

        % Define the component IDs for the nodes involved in the bond
        component1 = ATG.Nodes.Component(ATG.Nodes.AtomIndex == i);
        component2 = ATG.Nodes.Component(ATG.Nodes.AtomIndex == j);

        % Find nodes belonging to the selected components
        nodesInComponent1 = find(atoms2component == component1);
        nodesInComponent2 = find(atoms2component == component2);
        % Combine the nodes from both components. Normally component1 and
        % component2 are distinct, so this is a simple union of two disjoint
        % node sets. However, for bond-cleaving reactions (e.g. peroxidases,
        % hydrolases) where a bond within a reactant connects two atoms that
        % end up in different product molecules, atom-transition tracking can
        % merge both product fragments (and the original reactant) into a
        % single connected component -- so the bond's own two endpoint atoms
        % can already share the same component (component1 == component2).
        % In that case nodesInComponent1 and nodesInComponent2 are identical,
        % and concatenating them would duplicate every node, which subgraph()
        % rejects. Guard against that case explicitly.
                if component1 == component2
                    nodesInBothComponents = nodesInComponent1;
                else
                    nodesInBothComponents = [nodesInComponent1; nodesInComponent2];
                end
        % Create the subgraph containing nodes from both selected components
                combinedSubgraph = subgraph(ATG, nodesInBothComponents);

        % Find the subgraph in BGWCopy that corresponds to the combined subgraph
        % by selecting edges whose nodes match the AtomIndex in the combinedSubgraph
        GBB = subgraph(BIGCopy, combinedSubgraph.Nodes.AtomIndex);

        % Initialize a cell array to store the combined subgraphs for each iteration
        combinedSubgraphs = {};
        BMgraph = {};  % Temporary storage for Bond Mapping Graphs
        iteration = 1;

        % Repeat until GBB is empty (i.e., no edges left)
        while numedges(GBB) > 0
            % Get unique BondIndex values
            [uniqueBonds, firstOccurrenceIndices, groupIndices] = unique(GBB.Edges.BondIndex, 'first');

            % Calculate the number of occurrences of each unique BondIndex
            occurrences = accumarray(groupIndices, 1);
            maxOccurrences = max(occurrences);

            % Iterate through the maximum occurrences to create subgraphs
            for j = 1:maxOccurrences
                % Extract the first occurrence indices
                bondIds = GBB.Edges.EdgeIndex(firstOccurrenceIndices);
                bondIdProcessed = [bondIdProcessed; bondIds];

                % Extract source and target nodes of those edges
                s = GBB.Edges.EndNodes(firstOccurrenceIndices, 1); % Source nodes
                t = GBB.Edges.EndNodes(firstOccurrenceIndices, 2); % Target nodes

                % Create a subgraph for the current set of bonds
                EdgeTable = GBB.Edges(firstOccurrenceIndices, :); % Edge table for the subgraph
                NodeTable = GBB.Nodes; % Full node table (preserved properties)
                BMgraph{j, 1} = digraph(EdgeTable, NodeTable); % Construct the Bond Mapping Graph

                % Add these edges to the combined subgraph
                currentCombinedGraph = addedge(combinedSubgraph, s, t);

                % Store the current subgraph
                combinedSubgraphs{j, 1} = currentCombinedGraph;

                % Remove the edges that have been processed from GBB
                GBB = rmedge(GBB, firstOccurrenceIndices);

                % Update `firstOccurrenceIndices` after edge removal
                if numedges(GBB) > 0
                    [~, firstOccurrenceIndices, ~] = unique(GBB.Edges.BondIndex, 'first');
                else
                    break; % No more edges left in GBB
                end
            end

            % Update iteration counter
            iteration = iteration + 1;
        end

        % Store the combined subgraphs created in this iteration in bondSubgraphs
        for m = 1:length(combinedSubgraphs)
            bondSubgraphs{subgraphIndex, 1} = combinedSubgraphs{m}; % Subgraphs of connected bonds
            BMG{subgraphIndex, 1} = BMgraph{m}; % Bond Mapping Graphs
            subgraphIndex = subgraphIndex + 1; % Increment subgraph index
        end

        % Find IDs of the edges that have been processed in BGWCopy
        idsToRemove = find(ismember(BIGCopy.Edges.EdgeIndex, bondIdProcessed));

        % Remove the processed edges from BGWCopy
        BIGCopy = rmedge(BIGCopy, idsToRemove);

        % Update the number of bonds after removing edges
        numBonds = numedges(BIGCopy);

        % If we have removed edges, do not increment `k` as it needs to check the new first edge
        % Else increment to the next edge
        if numBonds == 0
            break; % No more edges left
        elseif ismember(k, idsToRemove)
            k = 1; % Reset to first edge after removal
        else
            k = k + 1; % Increment to next edge
        end
    end
end

end

function [pairRows, atgEdgeCount] = pairEdgeRows(lowComp, highComp, bucketId, edgesByBucket, ...
    atgBucketId, atgEdgesByBucket, remaining)
% Remaining bond instance rows of a component pair, collected as the peeling loop collects
% them, and the number of ATG edges of the pair
buckets = full([bucketId(lowComp, lowComp); bucketId(highComp, highComp); ...
    bucketId(lowComp, highComp)]);
buckets = unique(buckets(buckets > 0));
pairRows = vertcat(zeros(0, 1), edgesByBucket{buckets});
pairRows = pairRows(remaining(pairRows));
atgBuckets = full([atgBucketId(lowComp, lowComp); atgBucketId(highComp, highComp); ...
    atgBucketId(lowComp, highComp)]);
atgBuckets = unique(atgBuckets(atgBuckets > 0));
atgEdgeCount = sum(cellfun(@numel, atgEdgesByBucket(atgBuckets)));
end

function [layerRows, nLayers] = peelLayers(pairRows, localEnds, bondIndexAll)
% The rows of each peeling layer of a component pair, as the peeling loop extracts them: the
% rows are ordered by local (source, target), ties in BIG order, and layer L holds the L-th
% occurrence of each BondIndex in that order, sorted by BondIndex (unique(..., 'first'))
[~, order] = sortrows([localEnds pairRows]);
rows = pairRows(order);
if isempty(rows)
    layerRows = cell(0, 1);
    nLayers = 0;
    return
end
[~, ~, groupOfRow] = unique(bondIndexAll(rows));
% occurrence rank of every row within its BondIndex, in row order
[~, byGroup] = sortrows([groupOfRow(:), (1:numel(rows))']);
groupSorted = groupOfRow(byGroup);
isGroupStart = [true; diff(groupSorted(:)) ~= 0];
startPos = find(isGroupStart);
rankSorted = (1:numel(rows))' - startPos(cumsum(isGroupStart)) + 1;
nLayers = max(rankSorted);
layerRows = cell(nLayers, 1);
for layer = 1:nLayers
    % within a layer every BondIndex occurs once, listed by ascending BondIndex
    layerRows{layer} = rows(byGroup(rankSorted == layer));
end
end

function sizes = sizesOfSubgraphs(bondSubgraphs)
% Node and edge counts of built subgraphs
if isempty(bondSubgraphs)
    sizes = zeros(0, 2);
else
    sizes = [cellfun(@numnodes, bondSubgraphs(:)), cellfun(@numedges, bondSubgraphs(:))];
end
end

function checkSubgraphIndices(subgraphsToBuild, numSubgraphs)
% Every requested subgraph index must name an extracted subgraph
if any(subgraphsToBuild > numSubgraphs)
    error('extractBondSubgraphs:subgraphIndexOutOfRange', ...
        'subgraphsToBuild names subgraph %d, but only %d were extracted.', ...
        max(subgraphsToBuild), numSubgraphs);
end
end
