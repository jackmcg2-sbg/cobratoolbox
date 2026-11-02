% captureMemoryReferences.m
%
% One-off capture of the CI references for feature 20261102-092909-reacting-moiety-memory
% (tasks.md T003; research R4, R7). MUST run on UNMODIFIED
% src/analysis/topology/reactingMoieties/ (it refuses otherwise), so every expected output,
% error and call count is the pre-change behaviour.
%
% Writes, under test/verifiedTests/analysis/testReactingMoieties/data/:
%   reactingMoietyMemoryReference.mat
%     goldenCases - full-mode identifyConservedReactingMoieties on the coaM, coaX, coaR, crn
%                   and crnM bond-key fixtures, sanityChecks 0 and 1 (the fields of the
%                   existing goldenCases in conservedReactingMoietiesReference.mat)
%   classifySubgraphIsomorphismGroupsReference.mat
%     groupLists  - 20 deterministic lists of graph/digraph multigraphs whose (node count,
%                   edge count) groups interleave in index order, with identical-edge-list
%                   copies, relabellings and same-size non-isomorphic variants
%     groupCases  - every list classified in three modes (listIndex into groupLists), with
%                   the isisomorphic call count and the fallback count
%   each with a provenance struct (base commit, MATLAB version, MILP solver, date)
%
% USAGE (headless, in its own memory-capped scope):
%   matlab -batch "initCobraToolbox(false); run('<repo>/specs/20261102-092909-reacting-moiety-memory/captureMemoryReferences.m')"

global CBT_MILP_SOLVER

featureDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(featureDir));
rmDir = 'src/analysis/topology/reactingMoieties';
testDir = fullfile(repoRoot, 'test', 'verifiedTests', 'analysis', 'testReactingMoieties');
baseCommit = '8a927a4c6';

srcStatus = system(sprintf('git -C "%s" diff --quiet %s -- %s', repoRoot, baseCommit, rmDir));
if srcStatus ~= 0
    error('captureMemoryReferences:srcModified', ...
        '%s differs from %s: references must be captured from unmodified code.', rmDir, baseCommit);
end
assert(startsWith(which('identifyConservedReactingMoieties'), fullfile(repoRoot, rmDir)), ...
    'identifyConservedReactingMoieties does not resolve to this repository.');

changeCobraSolver('gurobi', 'MILP', 0);
provenance = struct('feature', '20261102-092909-reacting-moiety-memory', ...
    'baseCommit', baseCommit, 'matlab', version, 'milpSolver', CBT_MILP_SOLVER, ...
    'created', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));

%% Full-mode golden cases on the bond-key fixtures (research R7)
rxnFilesDir = fullfile(testDir, 'data', 'rxnFiles');
fixtures = {'coaM', 'coaX', 'coaR', 'crn', 'crnM'};
goldenCases = struct('name', {}, 'model', {}, 'BG', {}, 'dATM', {}, 'options', {}, ...
    'outcome', {}, 'arm', {}, 'moietyFormulae', {}, 'reacting', {}, 'errorIdentifier', {}, ...
    'errorMessage', {}, 'milpSolver', {});
for f = 1:numel(fixtures)
    fixture = load(fullfile(testDir, 'data', [fixtures{f} 'BondKeySubmodel.mat']));
    buildOptions = struct('directed', 0, 'sanityChecks', 1);
    [dATM, ~, ~, ~, ~, ~, BG] = buildAtomAndBondTransitionMultigraph(fixture.subModel, ...
        rxnFilesDir, buildOptions);
    for sanityChecks = [0 1]
        options = struct('directed', 0, 'sanityChecks', sanityChecks);
        goldenCase = struct('name', sprintf('%sFull%s', fixtures{f}, ...
            repmat('Sanity', 1, sanityChecks)), 'model', fixture.subModel, 'BG', BG, ...
            'dATM', dATM, 'options', options, 'outcome', 'ok', 'arm', [], ...
            'moietyFormulae', [], 'reacting', [], 'errorIdentifier', '', 'errorMessage', '', ...
            'milpSolver', CBT_MILP_SOLVER);
        try
            [goldenCase.arm, goldenCase.moietyFormulae, goldenCase.reacting] = ...
                identifyConservedReactingMoieties(fixture.subModel, BG, dATM, options);
        catch ME
            goldenCase.outcome = 'error';
            goldenCase.errorIdentifier = ME.identifier;
            goldenCase.errorMessage = ME.message;
            fprintf('%s: error recorded: %s: %s (%s:%d)\n', goldenCase.name, ME.identifier, ...
                ME.message, ME.stack(1).file, ME.stack(1).line);
        end
        goldenCases(end + 1) = goldenCase; %#ok<SAGROW>
        fprintf('%s: %s\n', goldenCase.name, goldenCase.outcome);
    end
end

%% Classification cases with interleaved (node, edge) groups (research R4)
modes = {{}, {'EdgeVariables', 'mets'}, {'NodeVariables', 'mets'}};
rng(1);
numLists = 20;
groupLists = cell(numLists, 1);
groupCases = struct('listIndex', {}, 'options', {}, 'isomorphismClasses', {}, ...
    'firstSubgraphIndices', {}, 'subsequentSubgraphIndices', {}, 'callCount', {}, ...
    'fallbackCount', {});
for listIndex = 1:numLists
    isDirected = mod(listIndex, 2) == 0;
    numSizes = randi([3, 5]);
    bases = cell(numSizes, 1);
    for b = 1:numSizes
        bases{b} = labelledRandomGraph(isDirected, 3 + 2 * b, 4 + 3 * b);
    end
    subgraphs = cell(16, 1);
    for k = 1:16
        base = bases{randi(numSizes)};
        kind = randi(3);
        if kind == 1
            subgraphs{k} = base;                                            % identical edge list
        elseif kind == 2
            subgraphs{k} = reordernodes(base, randperm(numnodes(base)));    % relabelling
        else
            subgraphs{k} = movedEdgeCopy(base);                             % same counts
        end
    end
    groupLists{listIndex} = subgraphs;
    for m = 1:numel(modes)
        classifySubgraphIsomorphism('resetCallCount');
        [isomorphismClasses, firstSubgraphIndices, subsequentSubgraphIndices] = ...
            classifySubgraphIsomorphism(subgraphs, modes{m}{:});
        groupCases(end + 1) = struct('listIndex', listIndex, 'options', {modes{m}}, ...
            'isomorphismClasses', {isomorphismClasses}, ...
            'firstSubgraphIndices', firstSubgraphIndices, ...
            'subsequentSubgraphIndices', subsequentSubgraphIndices, ...
            'callCount', classifySubgraphIsomorphism('getCallCount'), ...
            'fallbackCount', classifySubgraphIsomorphism('getFallbackCount')); %#ok<SAGROW>
    end
end

%% Save
memoryFile = fullfile(testDir, 'data', 'reactingMoietyMemoryReference.mat');
groupsFile = fullfile(testDir, 'data', 'classifySubgraphIsomorphismGroupsReference.mat');
save(memoryFile, 'goldenCases', 'provenance', '-v7');
save(groupsFile, 'groupLists', 'groupCases', 'provenance', '-v7');
memoryInfo = dir(memoryFile);
groupsInfo = dir(groupsFile);
fprintf('%s: %d golden cases (%d errors), %d bytes\n', memoryFile, numel(goldenCases), ...
    nnz(strcmp({goldenCases.outcome}, 'error')), memoryInfo.bytes);
fprintf('%s: %d lists, %d cases, %d classes in total, %d bytes\n', groupsFile, numLists, ...
    numel(groupCases), sum(cellfun(@numel, {groupCases.isomorphismClasses})), groupsInfo.bytes);

function G = labelledRandomGraph(isDirected, numNodes, numEdges)
% random multigraph (parallel edges and self-loops allowed) with mets node and edge labels
sourceNodes = randi(numNodes, numEdges, 1);
targetNodes = randi(numNodes, numEdges, 1);
labels = {'a'; 'b'; 'c'};
nodeTable = table(labels(randi(3, numNodes, 1)), 'VariableNames', {'mets'});
edgeTable = table([sourceNodes targetNodes], labels(randi(3, numEdges, 1)), ...
    'VariableNames', {'EndNodes', 'mets'});
if isDirected
    G = digraph(edgeTable, nodeTable);
else
    G = graph(edgeTable, nodeTable);
end
end

function H = movedEdgeCopy(G)
% copy of G with one edge endpoint moved: same node and edge counts, usually not isomorphic
edgeTable = G.Edges;
edgeRow = randi(height(edgeTable));
edgeTable.EndNodes(edgeRow, 2) = randi(numnodes(G));
if isa(G, 'digraph')
    H = digraph(edgeTable, G.Nodes);
else
    H = graph(edgeTable, G.Nodes);
end
end
