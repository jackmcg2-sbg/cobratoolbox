% The COBRAToolbox: testBuildAtomAndBondTransitionMultigraph.m
%
% Purpose:
%     - Test that buildAtomAndBondTransitionMultigraph returns M2BiE, M2BiW and
%       BTi2R as sparse double matrices by default and as full double matrices
%       with options.denseBondMatrices = 1, with identical values, sizes and
%       classes of every other output in both modes (feature
%       20260921-125236-sparse-bond-matrices, FR-015).
%     - Test that the atomic and bond decompositions hold with zero residual
%       in both modes, and that the bond mismatch report prints identically in
%       both modes on a deliberately inconsistent model.
%     - Test that options.denseBondMatrices has no effect when
%       options.bondTransitionMultigraph = 0.
%     - Test that a model containing a reaction with no bonds (implicit-hydrogen water
%       transport, data/rxn) builds, with that reaction's atom transition in the atom graph and
%       no bond transition from it (feature 20261012-093525-symmetric-iso-zero-bond, FR-005).
%     - Test that every metabolite's bonds in BG equal its reference molblock (first-seen RXN
%       file, instance 1): the same atom pairs and orders, no self-loop, on the main fixture
%       and the coaM, coaX, coaR, crn and crnM bond-key fixtures; that the comparison detects
%       a planted moved bond; and that a copy of a metabolite that is not isomorphic to its
%       reference (data/rxnFilesNonIsomorphicCopy) raises a warning naming the metabolite and
%       the reaction and keeps its raw atom numbering (feature
%       20261102-151507-whole-molecule-bond-renumbering, FR-003, FR-004).
%
% Authors:
%     - COBRA Toolbox, feature 20260921-125236-sparse-bond-matrices
%     - COBRA Toolbox, feature 20261012-093525-symmetric-iso-zero-bond (zero-bond reaction)
%     - COBRA Toolbox, feature 20261102-151507-whole-molecule-bond-renumbering (molfile equality)

global CBTDIR

% no solver is needed; declared for the harness convention
prepareTest();

% save the current path and initialize the test
currentDir = pwd;
fileDir = fileparts(which('testBuildAtomAndBondTransitionMultigraph'));
cd(fileDir);

% atom-mapped reaction files shipped beside the reacting-moiety tests
rxnFilesDir = [fileDir filesep 'data' filesep 'rxnFiles'];
assert(isfolder(rxnFilesDir), 'Atom-mapped rxnFiles fixture not found.');

% the r0317/ACONTm/r0426 Recon3D subnetwork used by testConservedReactingMoieties.m
model = readCbModel([CBTDIR filesep 'test' filesep 'models' filesep 'mat' filesep 'Recon3D_301.mat']);
subModel = extractSubNetwork(model, {'r0317'; 'ACONTm'; 'r0426'});

bondMatrixIdx = 9:11; % M2BiE, M2BiW, BTi2R
otherIdx = setdiff(1:12, bondMatrixIdx);

options.directed = 0;
options.sanityChecks = 1;
defaultOut = cell(1, 12);
[defaultOut{:}] = buildAtomAndBondTransitionMultigraph(subModel, rxnFilesDir, options);
denseOptions = options;
denseOptions.denseBondMatrices = 1;
denseOut = cell(1, 12);
[denseOut{:}] = buildAtomAndBondTransitionMultigraph(subModel, rxnFilesDir, denseOptions);

% (d) both decompositions hold with zero residual in both modes.
% Exact comparison with zero is valid (Principle III): every entry involved is an
% integer or an exact binary fraction, so the residual is computed exactly
% (specs/20260921-125236-sparse-bond-matrices/research.md R4).
modeOutputs = {defaultOut, denseOut};
modeNames = {'default', 'dense'};
for modeIdx = 1:2
    [atomResidual, bondResidual] = decompositionResiduals(subModel, modeOutputs{modeIdx});
    assert(atomResidual == 0, sprintf('FR-015 (d): atomic decomposition residual is %g in %s mode.', atomResidual, modeNames{modeIdx}));
    assert(bondResidual == 0, sprintf('FR-015 (d): bond decomposition residual is %g in %s mode.', bondResidual, modeNames{modeIdx}));
end

% (e) the bond mismatch report prints identically in both modes. Doubling one
% stoichiometric coefficient of a bond-bearing metabolite of r0317 makes both
% decompositions inconsistent while the RXN-file atom and bond mappings, and
% hence the graphs, are unchanged. The atom-side report and warning also fire
% and stay visible; that is expected.
dBTM = defaultOut{8};
r0317Idx = find(strcmp(subModel.rxns, 'r0317'));
candidateMets = find(subModel.S(:, r0317Idx) ~= 0);
perturbedMetIdx = candidateMets(find(ismember(subModel.mets(candidateMets), dBTM.Nodes.mets), 1));
assert(~isempty(perturbedMetIdx), 'FR-015 (e): no bond-bearing metabolite of r0317 found to perturb.');
badModel = subModel;
badModel.S(perturbedMetIdx, r0317Idx) = 2 * badModel.S(perturbedMetIdx, r0317Idx);
% Both modes are called from the same line, so the warning backtraces in the
% captured text are identical too.
modeOptions = {options, denseOptions};
reportTexts = cell(1, 2);
for modeIdx = 1:2
    reportTexts{modeIdx} = runWithDiary(badModel, rxnFilesDir, modeOptions{modeIdx});
end
[defaultText, denseText] = reportTexts{:};
for modeIdx = 1:2
    assert(contains(reportTexts{modeIdx}, 'Inconsistency between reaction stoichiometry and bond mapped reactions'), ...
        sprintf('FR-015 (e): bond mismatch report not printed in %s mode.', modeNames{modeIdx}));
    assert(contains(reportTexts{modeIdx}, 'Inconsistent directed bond transition multigraph'), ...
        sprintf('FR-015 (e): bond inconsistency warning not raised in %s mode.', modeNames{modeIdx}));
end
% Exact text comparison is valid: both modes perform the same arithmetic on the
% same values (research R4), and the printed report is discrete text.
assert(strcmp(defaultText, denseText), ...
    'FR-015 (e): the console output, including the bond mismatch report, differs between default and dense modes.');

% (b) with options.denseBondMatrices = 1 the three matrices are full double, as before
for k = bondMatrixIdx
    assert(~issparse(denseOut{k}) && isa(denseOut{k}, 'double'), ...
        sprintf('FR-015 (b): output %d must be a full double matrix when options.denseBondMatrices = 1.', k));
end

% (c) every other output is identical across modes, including class and sparsity,
% and the three matrices hold identical values. Exact comparison is valid: the
% outputs are discrete (graphs, index maps, 0/1 incidence, integer bond types).
for k = otherIdx
    assert(isequaln(defaultOut{k}, denseOut{k}), ...
        sprintf('FR-015 (c): output %d differs between default and dense modes.', k));
    assert(strcmp(class(defaultOut{k}), class(denseOut{k})) && issparse(defaultOut{k}) == issparse(denseOut{k}), ...
        sprintf('FR-015 (c): output %d changes class or sparsity between default and dense modes.', k));
end
for k = bondMatrixIdx
    assert(isequal(size(defaultOut{k}), size(denseOut{k})) && isequaln(full(defaultOut{k}), denseOut{k}), ...
        sprintf('FR-015 (c): output %d holds different values in default and dense modes.', k));
end

% (a) by default the three matrices are sparse double (FR-003)
for k = bondMatrixIdx
    assert(issparse(defaultOut{k}) && isa(defaultOut{k}, 'double'), ...
        sprintf('FR-015 (a), FR-003: output %d must be a sparse double matrix by default.', k));
end

% (f) with options.bondTransitionMultigraph = 0, options.denseBondMatrices has no
% effect (US1 acceptance scenario 4); only the first five outputs are assigned.
noBondOptions = options;
noBondOptions.bondTransitionMultigraph = 0;
noBondDenseOptions = noBondOptions;
noBondDenseOptions.denseBondMatrices = 1;
noBondOut = cell(1, 5);
[noBondOut{:}] = buildAtomAndBondTransitionMultigraph(subModel, rxnFilesDir, noBondOptions);
noBondDenseOut = cell(1, 5);
[noBondDenseOut{:}] = buildAtomAndBondTransitionMultigraph(subModel, rxnFilesDir, noBondDenseOptions);
for k = 1:5
    assert(isequaln(noBondOut{k}, noBondDenseOut{k}) && strcmp(class(noBondOut{k}), class(noBondDenseOut{k})) && ...
        issparse(noBondOut{k}) == issparse(noBondDenseOut{k}), ...
        sprintf('FR-015 (f): output %d depends on options.denseBondMatrices when options.bondTransitionMultigraph = 0.', k));
end

% (g) a reaction with no bonds (feature 20261012-093525-symmetric-iso-zero-bond, FR-005, SC-004):
% implicit-hydrogen ethanol transport plus water transport, whose single-atom molecules have no
% bonds. The build completes, the water atom transition is in the atom graph, the water
% reaction contributes no bond transition, and both decompositions hold.
implicitHDir = [fileDir filesep 'data' filesep 'rxn'];
zeroBondModel = struct();
zeroBondModel.mets = {'etoh[e]'; 'etoh[c]'; 'h2o[c]'; 'h2o[e]'};
zeroBondModel.rxns = {'ETOHt_implicitH'; 'H2Ot_implicitH'};
zeroBondModel.S = sparse([-1, 0; 1, 0; 0, -1; 0, 1]);
zeroBondModel.lb = [-1000; -1000];
zeroBondModel.ub = [1000; 1000];
zeroBondModel.c = [0; 0];
zeroBondModel.b = [0; 0; 0; 0];
zeroBondOut = cell(1, 12);
[zeroBondOut{:}] = buildAtomAndBondTransitionMultigraph(zeroBondModel, implicitHDir, options);
zeroBondATM = zeroBondOut{1};
zeroBondBTM = zeroBondOut{8};
assert(all(zeroBondOut{3}), 'FR-005: both reactions must be atom mapped.');
waterTransitions = strcmp(zeroBondATM.Edges.rxns, 'H2Ot_implicitH');
assert(nnz(waterTransitions) == 1, 'FR-005: the water reaction must contribute one atom transition.');
waterEnds = zeroBondATM.Edges.EndNodes(waterTransitions, :);
waterEndMets = zeroBondATM.Nodes.mets(findnode(zeroBondATM, waterEnds));
assert(isequal(sort(waterEndMets(:)), {'h2o[c]'; 'h2o[e]'}), ...
    'FR-005: the water atom transition must join the two water oxygens.');
assert(nnz(strcmp(zeroBondATM.Edges.rxns, 'ETOHt_implicitH')) == 3, ...
    'FR-005: the ethanol reaction must contribute three atom transitions.');
assert(~any(strcmp(zeroBondBTM.Edges.rxns, 'H2Ot_implicitH')), ...
    'FR-005: the water reaction must contribute no bond transition.');
assert(any(strcmp(zeroBondBTM.Edges.rxns, 'ETOHt_implicitH')), ...
    'FR-005: the ethanol reaction must contribute bond transitions.');
[atomResidual, bondResidual] = decompositionResiduals(zeroBondModel, zeroBondOut);
assert(atomResidual == 0 && bondResidual == 0, ...
    sprintf('FR-005: decomposition residuals %g (atoms) and %g (bonds) must be zero.', atomResidual, bondResidual));

% return to the original directory
%% (h) every metabolite's bonds in BG equal its reference molblock (feature
% 20261102-151507-whole-molecule-bond-renumbering, FR-004, SC-001). Bond orders are integers,
% so the comparison is exact.
molfileOptions = struct('directed', 0, 'sanityChecks', 0);
fixtureModels = {'main', subModel};
for fixtureName = {'coaM', 'coaX', 'coaR', 'crn', 'crnM'}
    fixture = load([fileDir filesep 'data' filesep fixtureName{1} 'BondKeySubmodel.mat']);
    fixtureModels(end + 1, :) = {fixtureName{1}, fixture.subModel}; %#ok<AGROW>
end
for fixtureIdx = 1:size(fixtureModels, 1)
    [~, ~, ~, ~, ~, ~, fixtureBG] = buildAtomAndBondTransitionMultigraph( ...
        fixtureModels{fixtureIdx, 2}, rxnFilesDir, molfileOptions);
    [mismatchedMets, selfLoopMets] = molfileBondMismatches(fixtureBG, rxnFilesDir, ...
        fixtureModels{fixtureIdx, 2}.rxns);
    assert(isempty(mismatchedMets) && isempty(selfLoopMets), sprintf(['FR-004: in the %s ' ...
        'fixture the bonds of %s differ from their molblock (self-loops in %s).'], ...
        fixtureModels{fixtureIdx, 1}, strjoin(mismatchedMets, ', '), strjoin(selfLoopMets, ', ')));
end

%% (i) the comparison detects a planted moved bond: move citrate's first C-H bond of the main
% fixture to another carbon of citrate
[~, ~, ~, ~, ~, ~, plantedBG] = buildAtomAndBondTransitionMultigraph(subModel, rxnFilesDir, ...
    molfileOptions);
plantedEnds = plantedBG.Edges.EndNodes;
plantedMets = cellstr(plantedBG.Nodes.mets);
plantedElements = cellstr(plantedBG.Nodes.Element);
endElements = [plantedElements(plantedEnds(:, 1)), plantedElements(plantedEnds(:, 2))];
isCitrateCH = strcmp(plantedMets(plantedEnds(:, 1)), 'cit[m]') & ...
    sum(strcmp(endElements, 'C'), 2) == 1 & sum(strcmp(endElements, 'H'), 2) == 1;
movedBond = find(isCitrateCH, 1);
carbonEnd = plantedEnds(movedBond, strcmp(endElements(movedBond, :), 'C'));
citrateCarbons = find(strcmp(plantedMets, 'cit[m]') & strcmp(plantedElements, 'C'));
otherCarbon = citrateCarbons(find(citrateCarbons ~= carbonEnd, 1));
plantedEdges = plantedBG.Edges;
plantedEdges.EndNodes(movedBond, plantedEnds(movedBond, :) == carbonEnd) = otherCarbon;
plantedBG = graph(plantedEdges, plantedBG.Nodes);
plantedMismatches = molfileBondMismatches(plantedBG, rxnFilesDir, subModel.rxns);
assert(isequal(plantedMismatches, {'cit[m]'}), ...
    'FR-004: a C-H bond of citrate moved to another carbon is not detected.');

%% (j) a copy that is not isomorphic to its reference warns, naming the metabolite and the
% reaction, and keeps its raw atom numbering (FR-003): data/rxnFilesNonIsomorphicCopy/r0317.rxn
% bonds citrate's H14 to C7 instead of C13
nonIsomorphicDir = [fileDir filesep 'data' filesep 'rxnFilesNonIsomorphicCopy'];
nonIsomorphicModel = extractSubNetwork(model, {'ACONTm'; 'r0317'});
assert(strcmp(nonIsomorphicModel.rxns{1}, 'ACONTm'), ...
    'FR-003 fixture: ACONTm must be processed first, so that its citrate is the reference.');
nonIsomorphicText = runWithDiary(nonIsomorphicModel, nonIsomorphicDir, molfileOptions);
assert(contains(nonIsomorphicText, 'cit[m]') && contains(nonIsomorphicText, 'r0317') && ...
    contains(nonIsomorphicText, 'not isomorphic'), ...
    'FR-003: no warning names cit[m] and r0317 for a copy not isomorphic to its reference.');
[~, ~, ~, ~, ~, ~, nonIsomorphicBG] = buildAtomAndBondTransitionMultigraph(nonIsomorphicModel, ...
    nonIsomorphicDir, molfileOptions);
citAtom = @(number) find(strcmp(cellstr(nonIsomorphicBG.Nodes.mets), 'cit[m]') & ...
    full(nonIsomorphicBG.Nodes.AtomNumber) == number);
assert(findedge(nonIsomorphicBG, citAtom(7), citAtom(14)) > 0 && ...
    findedge(nonIsomorphicBG, citAtom(13), citAtom(14)) > 0, ['FR-003: the non-isomorphic ' ...
    'copy''s raw bond C7-H14 and the reference''s C13-H14 must both be kept.']);

cd(currentDir);

function [atomResidual, bondResidual] = decompositionResiduals(model, out)
% Recompute both decompositions from the outputs, deriving N and the
% bond-mapped subsets as buildAtomAndBondTransitionMultigraph does.
[dATM, metAtomMappedBool, rxnAtomMappedBool, M2Ai, Ti2R] = out{1:5};
[dBTM, M2BiE, M2BiW, BTi2R, BTiE] = out{8:12};
atomN = sparse(model.S(metAtomMappedBool, rxnAtomMappedBool));
atomRes = (M2Ai * M2Ai') * atomN - M2Ai * incidence(dATM) * Ti2R;
atomResidual = full(max([0; abs(atomRes(:))]));
rxnBondMappedBool = ismember(model.rxns, dBTM.Edges.rxns);
metBondMappedBool = ismember(model.mets, dBTM.Nodes.mets(~ismember(dBTM.Nodes.Bond, {'E'})));
bondN = sparse(model.S(metBondMappedBool, rxnBondMappedBool));
bondRes = (M2BiW(metBondMappedBool, :) * M2BiE(metBondMappedBool, :)') * bondN - ...
    M2BiE(metBondMappedBool, :) * BTiE * BTi2R;
bondResidual = full(max([0; abs(bondRes(:))]));
end

function [mismatchedMets, selfLoopMets] = molfileBondMismatches(BG, rxnFileDir, rxns)
% Metabolites whose bonds in BG (atom-number pairs and Weight) differ from their reference
% molblock, instance 1 of their first RXN file in rxns order, and metabolites with a bond
% from an atom to itself (feature 20261102-151507-whole-molecule-bond-renumbering, FR-004)
reference = containers.Map('KeyType', 'char', 'ValueType', 'any');
for r = 1:numel(rxns)
    if ~isfile(fullfile(rxnFileDir, [rxns{r} '.rxn']))
        continue
    end
    [~, bonds] = readABRXNFile(rxns{r}, rxnFileDir);
    for met = unique(bonds.mets(bonds.instances == 1))'
        if ~isKey(reference, met{1})
            isMet = strcmp(bonds.mets, met{1}) & bonds.instances == 1;
            reference(met{1}) = sortrows([min(bonds.headAtoms(isMet), bonds.tailAtoms(isMet)), ...
                max(bonds.headAtoms(isMet), bonds.tailAtoms(isMet)), bonds.bTypes(isMet)]);
        end
    end
end
atomMet = cellstr(BG.Nodes.mets);
atomNumber = full(BG.Nodes.AtomNumber);
ends = BG.Edges.EndNodes;
weight = full(BG.Edges.Weight);
bondMet = atomMet(ends(:, 1));
mismatchedMets = {};
selfLoopMets = {};
for met = unique(bondMet)'
    if ~isKey(reference, met{1})
        continue % a reaction's energy pseudo-node
    end
    isMet = strcmp(bondMet, met{1});
    a = atomNumber(ends(isMet, 1));
    b = atomNumber(ends(isMet, 2));
    if any(a == b)
        selfLoopMets{end + 1} = met{1}; %#ok<AGROW>
    end
    if ~isequal(sortrows([min(a, b), max(a, b), weight(isMet)]), reference(met{1}))
        mismatchedMets{end + 1} = met{1}; %#ok<AGROW>
    end
end
end

function consoleText = runWithDiary(model, rxnFilesDir, options)
% Run the function with its console output recorded by diary rather than
% evalc, so every warning still reaches the console (Principle VII-B); the
% caller's diary state is restored afterwards.
diaryFile = [tempname '.txt'];
previousDiaryState = get(0, 'Diary');
previousDiaryFile = get(0, 'DiaryFile');
restoreDiary = onCleanup(@() restoreDiaryState(previousDiaryState, previousDiaryFile, diaryFile)); %#ok<NASGU>
diary(diaryFile);
buildAtomAndBondTransitionMultigraph(model, rxnFilesDir, options);
diary('off');
consoleText = fileread(diaryFile);
end

function restoreDiaryState(previousDiaryState, previousDiaryFile, diaryFile)
diary('off');
set(0, 'DiaryFile', previousDiaryFile);
if strcmp(previousDiaryState, 'on')
    diary('on');
end
if isfile(diaryFile)
    delete(diaryFile);
end
end
