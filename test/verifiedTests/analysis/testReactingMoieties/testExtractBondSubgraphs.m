% The COBRAToolbox: testExtractBondSubgraphs.m
%
% Purpose:
%     - Regression test for extractBondSubgraphs (feature
%       20260921-154310-reacting-moiety-optimisation, spec FR-003, FR-007, FR-013).
%       The expected outputs in data/bondSubgraphReference.mat were captured from the
%       function BEFORE its body was rewritten for speed, so this test fails if the
%       rewritten function's outputs drift in any way.
%     - Covers: the stage-09 inputs (BIG, ATG) of the r0317/ACONTm/r0426 Recon3D
%       fixture; five inputs that break the lookup-array preconditions (duplicated and
%       non-integer AtomIndex, a component label out of range, named BIG nodes, a BIG
%       with no edges), which must give the same outputs or raise the same error as
%       before.
%
% Authors:
%     - COBRA Toolbox, feature 20260921-154310-reacting-moiety-optimisation

% only base MATLAB graph functions are used: no solver or toolbox requirement
prepareTest();

% save the current path and initialize the test
currentDir = cd(fileparts(which(mfilename)));

reference = load(['data' filesep 'bondSubgraphReference.mat']);
ciInputs = reference.ciInputs;
ciExpected = reference.ciExpected;
fallbackCases = reference.fallbackCases;

% --- CI fixture: two-output form ---
[bondSubgraphs, BMG] = extractBondSubgraphs(ciInputs.BIG, ciInputs.ATG);
assert(areGraphCellsEqual(bondSubgraphs, ciExpected.bondSubgraphs), ...
    'extractBondSubgraphs bondSubgraphs differ from the pre-change reference (CI fixture).');
assert(areGraphCellsEqual(BMG, ciExpected.BMG), ...
    'extractBondSubgraphs BMG differ from the pre-change reference (CI fixture).');

% --- inputs outside the lookup-array preconditions: same outputs or same error ---
for k = 1:numel(fallbackCases)
    fallbackCase = fallbackCases(k);
    if strcmp(fallbackCase.outcome, 'ok')
        [caseSubgraphs, caseBMG] = extractBondSubgraphs(fallbackCase.BIG, fallbackCase.ATG);
        assert(areGraphCellsEqual(caseSubgraphs, fallbackCase.bondSubgraphs) && ...
            areGraphCellsEqual(caseBMG, fallbackCase.BMG), ...
            sprintf('extractBondSubgraphs output differs from the pre-change reference (%s).', ...
            fallbackCase.name));
    else
        errorRaised = false;
        try
            extractBondSubgraphs(fallbackCase.BIG, fallbackCase.ATG);
        catch ME
            errorRaised = true;
            assert(strcmp(ME.identifier, fallbackCase.errorIdentifier) && ...
                strcmp(ME.message, fallbackCase.errorMessage), ...
                sprintf(['extractBondSubgraphs raised a different error from the pre-change ' ...
                'function (%s): expected %s: %s; got %s: %s (%s:%d).'], fallbackCase.name, ...
                fallbackCase.errorIdentifier, fallbackCase.errorMessage, ME.identifier, ...
                ME.message, ME.stack(1).file, ME.stack(1).line));
        end
        assert(errorRaised, sprintf(['extractBondSubgraphs returned normally, but the ' ...
            'pre-change function raised %s (%s).'], fallbackCase.errorIdentifier, fallbackCase.name));
    end
end

% --- three-output form: same graphs, plus the per-graph EdgeIndex cache ---
[bondSubgraphs3, BMG3, bmgEdgeIndex] = extractBondSubgraphs(ciInputs.BIG, ciInputs.ATG);
assert(areGraphCellsEqual(bondSubgraphs3, bondSubgraphs) && areGraphCellsEqual(BMG3, BMG), ...
    'extractBondSubgraphs graphs differ between the two- and three-output forms (CI fixture).');
assert(isEdgeIndexCacheConsistent(bmgEdgeIndex, BMG3), ...
    'extractBondSubgraphs bmgEdgeIndex is not the EdgeIndex set of each BMG (CI fixture).');
for k = 1:numel(fallbackCases)
    fallbackCase = fallbackCases(k);
    if strcmp(fallbackCase.outcome, 'ok')
        [~, caseBMG, caseEdgeIndex] = extractBondSubgraphs(fallbackCase.BIG, fallbackCase.ATG);
        assert(isEdgeIndexCacheConsistent(caseEdgeIndex, caseBMG), ...
            sprintf('extractBondSubgraphs bmgEdgeIndex is not the EdgeIndex set of each BMG (%s).', ...
            fallbackCase.name));
    end
end

% change the directory
cd(currentDir)

function isConsistent = isEdgeIndexCacheConsistent(bmgEdgeIndex, BMG)
% True when bmgEdgeIndex{m} holds the same EdgeIndex values as BMG{m}, in any order.
isConsistent = iscell(bmgEdgeIndex) && isequal(size(bmgEdgeIndex), size(BMG));
for m = 1:numel(BMG)
    if ~isConsistent
        return
    end
    isConsistent = isequal(sort(bmgEdgeIndex{m}(:)), sort(BMG{m}.Edges.EdgeIndex(:)));
end
end

function isSame = areGraphCellsEqual(A, B)
% True when two cell arrays of graph/digraph objects have the same size and each pair is
% graph-equal.
isSame = iscell(A) && iscell(B) && isequal(size(A), size(B));
for q = 1:numel(A)
    if ~isSame
        return
    end
    isSame = isGraphEqual(A{q}, B{q});
end
end

function isSame = isGraphEqual(A, B)
% True when two graph/digraph objects have the same class and equal Nodes and Edges tables
% (table equality: variable names, types, values and row order all have to match).
isSame = strcmp(class(A), class(B)) && isequal(A.Nodes, B.Nodes) && isequal(A.Edges, B.Edges);
end
