% The COBRAToolbox: testFindConservedBondGroup.m
%
% Purpose:
%     - Regression test for findConservedBondGroup (feature
%       20261103-115636-conserved-bond-group-pruning, spec FR-002, US3 AS2-AS4; contract
%       contracts/lazy-extraction-and-pruned-group.md). Tier: unit, base MATLAB graph
%       functions only.
%     - Reference inputs: every input of data/bondSubgraphReference.mat and
%       data/bondSubgraphPeelingReference.mat that extracts without error. The conserved and
%       reacting groups must equal those of findAndExtractMolecularGraphs on the eager
%       extraction, with the subgraphs given by the eager cell and by lazy extraction
%       (extractBondSubgraphs with subgraphsToBuild).
%     - Synthetic sets built here to exercise the search rules: equal-population size groups
%       whose largest classes tie (the smaller leader is in the group visited second); a size
%       group whose population equals the best class so far and holds an equal class with a
%       smaller leader; a most populous size group that splits into small classes; all
%       singletons, in one size group and in separate ones; one subgraph; no subgraphs. Each
%       asserts the groups, the expected groups, and the number of size groups classified and
%       subgraphs built.
%     - Build calls: buildSubgraphs is called only with whole size groups, each once.
%     - Planted difference: a conserved group with one member swapped must be detected.
%
% Authors:
%     - COBRA Toolbox, feature 20261103-115636-conserved-bond-group-pruning

% only base MATLAB graph functions are used: no solver or toolbox requirement
prepareTest();

% save the current path and initialize the test
currentDir = cd(fileparts(which(mfilename)));

%% reference inputs: the same groups as findAndExtractMolecularGraphs
reference = load(['data' filesep 'bondSubgraphReference.mat']);
peeling = load(['data' filesep 'bondSubgraphPeelingReference.mat']);
referenceInputs = [{'CI fixture'}, {peeling.peelingCases.name}, {reference.fallbackCases.name}; ...
    {reference.ciInputs.BIG}, {peeling.peelingCases.BIG}, {reference.fallbackCases.BIG}; ...
    {reference.ciInputs.ATG}, {peeling.peelingCases.ATG}, {reference.fallbackCases.ATG}]';
referenceOutcomes = [{'ok'}; {peeling.peelingCases.outcome}'; {reference.fallbackCases.outcome}'];
if isfield(peeling, 'n332Inputs')
    referenceInputs(end + 1, :) = {'332-reaction subset', peeling.n332Inputs.BIG, ...
        peeling.n332Inputs.ATG};
    referenceOutcomes{end + 1} = 'ok';
end
numCompared = 0;
for k = 1:size(referenceInputs, 1)
    if ~strcmp(referenceOutcomes{k}, 'ok')
        continue
    end
    [caseName, caseBIG, caseATG] = referenceInputs{k, :};
    [bondSubgraphs, BMG, bmgEdgeIndex, subgraphSizes] = extractBondSubgraphs(caseBIG, caseATG, true);
    if isempty(BMG)
        continue
    end
    [~, ~, ~, ~, expectedConserved, expectedReacting] = findAndExtractMolecularGraphs(caseBIG, ...
        BMG, bondSubgraphs, bmgEdgeIndex, false);
    [conservedGroup, reactingGroups] = findConservedBondGroup(subgraphSizes, @(idx) bondSubgraphs(idx));
    assert(isequal(conservedGroup, expectedConserved) && isequal(reactingGroups, expectedReacting), ...
        sprintf('findConservedBondGroup differs from findAndExtractMolecularGraphs (%s).', caseName));
    lazyBuild = @(idx) selectEntries(extractBondSubgraphs(caseBIG, caseATG, true, idx), idx);
    [conservedGroup, reactingGroups] = findConservedBondGroup(subgraphSizes, lazyBuild);
    assert(isequal(conservedGroup, expectedConserved) && isequal(reactingGroups, expectedReacting), ...
        sprintf(['findConservedBondGroup with lazily built subgraphs differs from ' ...
        'findAndExtractMolecularGraphs (%s).'], caseName));
    numCompared = numCompared + 1;
end
assert(numCompared >= 10, 'Too few reference inputs were compared (%d).', numCompared);

%% synthetic sets: the search rules
% building blocks: (3 nodes, 2 edges) path, parallel pair, self-loop plus edge; (2, 1) edge and
% self-loop; (4, 3) path
path3 = graph([1 2], [2 3], [], 3);
double3 = graph([1 1], [2 2], [], 3);
loop3 = graph([1 2], [1 3], [], 3);
edge2 = graph(1, 2, [], 2);
loop2 = graph(1, 1, [], 2);
path4 = graph([1 2 3], [2 3 4], [], 4);

syntheticCases = struct('name', {}, 'graphs', {}, 'conserved', {}, 'groupsClassified', {}, ...
    'componentsBuilt', {});
% two size groups of 3; their largest classes (size 2) tie, and the smaller leader (2) lies in
% the group visited second (its first member, 2, is larger than the first group's, 1)
syntheticCases(end + 1) = struct('name', 'equal-population tie', ...
    'graphs', {{double3; edge2; path3; edge2; path3; loop2}}, 'conserved', [2 4], ...
    'groupsClassified', 2, 'componentsBuilt', 6);
% the first group (4 members) gives a class of 3 with leader 2; the second group has exactly
% 3 members, all isomorphic, with leader 1, so it must still be classified, and it wins
syntheticCases(end + 1) = struct('name', 'equal-to-best group with smaller leader', ...
    'graphs', {{edge2; path3; path3; path3; double3; edge2; edge2}}, 'conserved', [1 6 7], ...
    'groupsClassified', 2, 'componentsBuilt', 7);
% the most populous group (4) splits into classes of 2, 1 and 1; the next group (3) is one
% class and wins; the last group (1) is not classified
syntheticCases(end + 1) = struct('name', 'populous group splits', ...
    'graphs', {{path3; double3; loop3; path3; edge2; edge2; edge2; path4}}, 'conserved', [5 6 7], ...
    'groupsClassified', 2, 'componentsBuilt', 7);
% singletons in separate size groups: every group has as many members as the best class (1),
% so all are classified, and the first subgraph wins
syntheticCases(end + 1) = struct('name', 'singleton groups', ...
    'graphs', {{path4; edge2; path3}}, 'conserved', 1, 'groupsClassified', 3, 'componentsBuilt', 3);
% singletons in one size group
syntheticCases(end + 1) = struct('name', 'singletons in one group', ...
    'graphs', {{loop3; path3; double3}}, 'conserved', 1, 'groupsClassified', 1, 'componentsBuilt', 3);
% one subgraph
syntheticCases(end + 1) = struct('name', 'one subgraph', 'graphs', {{path3}}, 'conserved', 1, ...
    'groupsClassified', 1, 'componentsBuilt', 1);

for k = 1:numel(syntheticCases)
    syntheticCase = syntheticCases(k);
    graphs = syntheticCase.graphs;
    sizes = [cellfun(@numnodes, graphs), cellfun(@numedges, graphs)];
    [~, ~, ~, ~, expectedConserved, expectedReacting] = findAndExtractMolecularGraphs([], {}, ...
        graphs, {}, false);
    assert(isequal(expectedConserved, syntheticCase.conserved), ...
        'The synthetic case "%s" does not exercise the intended rule: findAndExtractMolecularGraphs gives %s.', ...
        syntheticCase.name, mat2str(expectedConserved));
    calls = containers.Map('KeyType', 'double', 'ValueType', 'any');
    [conservedGroup, reactingGroups, diagnostics] = findConservedBondGroup(sizes, ...
        @(idx) recordCall(calls, graphs, idx));
    assert(isequal(conservedGroup, expectedConserved) && isequal(reactingGroups, expectedReacting), ...
        'findConservedBondGroup differs from findAndExtractMolecularGraphs (%s).', syntheticCase.name);
    assert(diagnostics.groupsClassified == syntheticCase.groupsClassified && ...
        diagnostics.componentsBuilt == syntheticCase.componentsBuilt, ...
        'findConservedBondGroup classified %d groups and built %d subgraphs, expected %d and %d (%s).', ...
        diagnostics.groupsClassified, diagnostics.componentsBuilt, syntheticCase.groupsClassified, ...
        syntheticCase.componentsBuilt, syntheticCase.name);
    % each call builds one whole size group, and no group is built twice
    [~, ~, sizeGroup] = unique(sizes, 'rows');
    builtGroups = zeros(calls.Count, 1);
    for c = 1:calls.Count
        idx = calls(c);
        builtGroups(c) = sizeGroup(idx(1));
        assert(isequal(sort(idx(:)), find(sizeGroup == builtGroups(c))), ...
            'findConservedBondGroup built part of a size group (%s).', syntheticCase.name);
    end
    assert(numel(unique(builtGroups)) == numel(builtGroups) && ...
        calls.Count == diagnostics.groupsClassified, ...
        'findConservedBondGroup built a size group twice (%s).', syntheticCase.name);
end

%% no subgraphs: the same result or error as findAndExtractMolecularGraphs
[expectedResult, expectedError] = groupsOrError(@() findAndExtractMolecularGraphs([], {}, ...
    cell(0, 1), {}, false));
[result, caught] = prunedGroupsOrError(zeros(0, 2));
if isempty(expectedError)
    assert(isempty(caught) && isequal(result, expectedResult), ...
        'findConservedBondGroup differs from findAndExtractMolecularGraphs on no subgraphs.');
else
    assert(~isempty(caught) && strcmp(caught.identifier, expectedError.identifier) && ...
        strcmp(caught.message, expectedError.message), ...
        'findConservedBondGroup raises a different error from findAndExtractMolecularGraphs on no subgraphs.');
end

%% planted difference: a swapped member is detected
plantedCase = syntheticCases(1);
sizes = [cellfun(@numnodes, plantedCase.graphs), cellfun(@numedges, plantedCase.graphs)];
conservedGroup = findConservedBondGroup(sizes, @(idx) plantedCase.graphs(idx));
plantedGroup = conservedGroup;
outsideGroup = setdiff(1:numel(plantedCase.graphs), conservedGroup);
plantedGroup(1) = outsideGroup(1);
assert(isequal(conservedGroup, plantedCase.conserved) && ~isequal(plantedGroup, plantedCase.conserved), ...
    'A conserved group with a swapped member is not detected.');

% change the directory
cd(currentDir)

function entries = selectEntries(cells, idx)
% The entries idx of a cell array, as a column
entries = reshape(cells(idx), [], 1);
end

function graphs = recordCall(calls, allGraphs, idx)
% Record the indices of one buildSubgraphs call and return those graphs
calls(calls.Count + 1) = idx;
graphs = reshape(allGraphs(idx), [], 1);
end

function [result, caught] = groupsOrError(fun)
% The conserved and reacting groups returned by fun, or the error it raised
result = {};
caught = [];
try
    [~, ~, ~, ~, conservedGroup, reactingGroups] = fun();
    result = {conservedGroup, reactingGroups};
catch caught
end
end

function [result, caught] = prunedGroupsOrError(subgraphSizes)
% The groups findConservedBondGroup returns for subgraphSizes (with no subgraphs to build), or
% the error it raised
result = {};
caught = [];
try
    [conservedGroup, reactingGroups] = findConservedBondGroup(subgraphSizes, @(idx) cell(0, 1));
    result = {conservedGroup, reactingGroups};
catch caught
end
end
