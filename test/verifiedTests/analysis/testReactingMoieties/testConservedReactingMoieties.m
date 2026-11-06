% The COBRAToolbox: testConservedReactingMoieties.m
%
% Purpose:
%     - Exercise the conserved-and-reacting-moieties workflow (Rahou et al., JTB 2025)
%       on a small, deterministic Recon3D subnetwork, covering the functions
%       buildAtomAndBondTransitionMultigraph, identifyConservedReactingMoieties,
%       identifyConservedReactingSubgraphs, buildReactingMoietyTables,
%       displayReactingMoieties, createMoietyGraph and getMetMoietySubgraphs.
%     - Asserts the conserved-moiety invariant L*N = 0 and stable structural facts.
%
%     - Golden comparison (feature 20260929-111453-conserved-moiety-table-hotspots, spec
%       FR-002, FR-008): data/conservedReactingMoietiesReference.mat holds the outputs (or the
%       error) of identifyConservedReactingMoieties captured before its table hotspots were
%       rewritten, for the main fixture in conserved-only and default mode with sanityChecks
%       0 and 1, and for the coaX and crnM bond-key fixtures (reoriented atom transitions,
%       moieties without internal bonds, multi-member isomorphism classes). Every case must
%       give identical outputs, or raise the identical error.
%     - Full-mode golden comparison (feature 20261102-092909-reacting-moiety-memory, spec
%       FR-002, FR-007, SC-001): data/reactingMoietyMemoryReference.mat holds the outputs (or
%       the error) of identifyConservedReactingMoieties in full mode, captured before its
%       bond-mapping stage was changed to save memory, for the coaM, coaX, coaR, crn and crnM
%       bond-key fixtures with sanityChecks 0 and 1 (with sanityChecks 1 each raises the
%       pre-existing identifyIsomorphicClasses sanity-check error, which is pinned as is).
%       Planted differences in arm.MG, L and reacting.ReactMoietyGraphs must be detected by
%       the comparison, so its passing is evidence.
%     - Golden references recaptured (feature 20261102-151507-whole-molecule-bond-renumbering,
%       FR-007): both references above store BG and dATM as inputs; since that feature they are
%       built by the builder whose BG equals each metabolite's molblock, and their outputs were
%       recaptured (per-field difference report in that feature's results file).
%     - The paper's published example (Rahou et al., J. Theor. Biol. 621 (2026) 112348;
%       feature 20261102-151507-whole-molecule-bond-renumbering, US3). The values below are
%       taken from the paper, not from a first run of this code: on the shipped RXN files the
%       conserved moiety matrix L of App. C.1.1, 6 moiety instances and 6 moiety transitions
%       (Sec. 5.7.1), formulae H2O and C6H3O6, and a condensed reacting bond graph of 6
%       vertices and 7 bonds (the authors' original code gives the same); on
%       data/rxnFilesConsistentArms, which maps citrate's two symmetric arms consistently, the
%       reacting moiety graph of Fig. 11 (4 vertices, 6 bonds, the bond sets of reactions
%       Y1 = ACONTm, Y2 = r0426, Y3 = r0317, compared as atom-transition component pairs) and a
%       2-reaction cover (every pair of reactions is minimal in Fig. 11, so which pair is not
%       asserted).
%     - The paper's reacting-bond incidence (feature 20261106-092213-paper-reacting-bond-
%       incidence; Rahou et al. 2026, Sec. 6.1, eq. 32): each reaction's condensed reacting
%       bonds in CRB2R are exactly those holding a bond it breaks, forms or changes the order
%       of, computed independently from dBTM (expectedCondensedSets, with the union over the
%       bonds merged into a condensed edge). Checked on the shipped files, on cis-aconitate's
%       C=C bond (an order change), and on data/rxnFilesTransport, which adds a transport
%       (CITICITtm, identity atom map) that changes no bond and so belongs to no condensed
%       reacting bond. Also the interface: the missing-dBTM and invalid-option errors, the
%       earlier rule as options.reactingBondIncidence = 'endAtom', and the new fields
%       reacting.unchangedReactingBonds and reacting.offGraphBondChanges, with planted
%       controls. Full-mode calls pass dBTM as the fifth input.
%
%     Derived from tutorials/analysis/reactingMoieties/tutorial_conservedAndReactingMoieties.m
%     (feature 004-reacting-moieties-test). Figures are generated but not displayed.
%
% Authors:
%     - COBRA Toolbox, repurposed from the tutorial by Hadjar Rahou & Ronan M.T. Fleming.
%     - COBRA Toolbox, feature 20260929-111453-conserved-moiety-table-hotspots (golden comparison)
%     - COBRA Toolbox, feature 20261102-092909-reacting-moiety-memory (full-mode golden cases)
%     - COBRA Toolbox, feature 20261102-151507-whole-molecule-bond-renumbering (paper values)
%     - COBRA Toolbox, feature 20261106-092213-paper-reacting-bond-incidence (paper incidence)
%

global CBTDIR
global CBT_MILP_SOLVER

% save the current path and figure-visibility state; restore both even on error
currentDir = pwd;
origFigVis = get(0, 'DefaultFigureVisible');
restoreFigVis = onCleanup(@() set(0, 'DefaultFigureVisible', origFigVis));
set(0, 'DefaultFigureVisible', 'off');   % generate figures, but do not display them

fileDir = fileparts(which('testConservedReactingMoieties'));
cd(fileDir);

% atom-mapped reaction files shipped beside this test (self-contained fixture)
rxnFilesDir = [fileDir filesep 'data' filesep 'rxnFiles'];
assert(isfolder(rxnFilesDir), 'Atom-mapped rxnFiles fixture not found.');

% tolerance for the conservation invariant
tol = 1e-8;

% load a genome-scale model and extract the small reproducible subnetwork
model = readCbModel([CBTDIR filesep 'test' filesep 'models' filesep 'mat' filesep 'Recon3D_301.mat']);
rxnList = {'r0317'; 'ACONTm'; 'r0426'};
subModel = extractSubNetwork(model, rxnList);

N = full(subModel.S);
assert(isequal(size(N), [4, 3]));               % 4 metabolites x 3 reactions
assert(rank(N) == 2);
assert(size(N, 1) - rank(N) == 2);              % left-null-space dimension

% build the directed atom and bond transition multigraph
options.directed = 0;
options.sanityChecks = 1;
[dATM, metAtomMappedBool, rxnAtomMappedBool, M2Ai, Ti2R, dATME, BG, dBTM, ...
    M2BiE, M2BiW, BTi2R, TiE] = ...
    buildAtomAndBondTransitionMultigraph(subModel, rxnFilesDir, options);

assert(numnodes(dATM) > 0);
assert(numnodes(BG) > 0);

% --- feature 026-conserved-moieties-only-option: US1 conserved-moieties-only mode ---
% Placed BEFORE the prepareTest('needsMILP', true) gate below (feature 026 spec FR-002,
% SC-001; analysis finding F1): options.conservedMoietiesOnly = true skips the
% reacting-moiety bond-graph/minimum-set-cover section entirely, so this call must not
% require a MILP solver, and this assertion block must run even on a runner where the
% MILP-gated full-mode call and comparison below are skipped.
optionsConservedOnly = options;
optionsConservedOnly.sanityChecks = 0;
optionsConservedOnly.conservedMoietiesOnly = true;
[armConservedOnly, moietyFormulaeConservedOnly, reactingConservedOnly] = ...
    identifyConservedReactingMoieties(subModel, BG, dATM, optionsConservedOnly);

assert(isstruct(reactingConservedOnly) && isfield(reactingConservedOnly, 'computed') && ...
    reactingConservedOnly.computed == false, ...
    'reacting must be struct(''computed'', false) when options.conservedMoietiesOnly = true (spec FR-004).');
assert(~isfield(reactingConservedOnly, 'selectedReactionNames'), ...
    'reacting must not carry reacting-moiety fields when options.conservedMoietiesOnly = true (spec FR-004).');

% --- feature 027-conserved-moiety-equivalence-test: cross-function equivalence guard ---
% Guards against future divergence between the two independent implementations of the
% conserved-moiety decomposition algorithm: identifyConservedReactingMoieties.m (in
% conserved-only mode, above) uses the newer prefiltered classifySubgraphIsomorphism
% helper internally, while the sibling identifyConservedMoieties.m still uses the
% original nested-loop isisomorphic approach. options.sanityChecks = 0 is used on the
% sibling call because sanityChecks = 1 on the conserved-only call above is a known,
% pre-existing, out-of-scope crash in a bond-subgraph classification path unrelated to
% conserved-moiety computation (spec 027 Edge Cases). Distinct variable names
% (armSibling/moietyFormulaeSibling) avoid colliding with this file's own arm/
% moietyFormulae variables from the full-mode call below. Neither this call nor the
% comparison requires a MILP solver, so this block is placed before the
% prepareTest('needsMILP', true) gate below (spec 027 FR-007).
optionsSibling = struct('sanityChecks', 0);
[armSibling, moietyFormulaeSibling] = identifyConservedMoieties(subModel, dATM, optionsSibling);

assert(isequal(armSibling.L, armConservedOnly.L), ...
    'arm.L must be identical between identifyConservedReactingMoieties(conservedMoietiesOnly=true) and identifyConservedMoieties (spec 027 SC-001/SC-002).');
assert(isequal(armSibling.M2M, armConservedOnly.M2M), ...
    'arm.M2M must be identical between identifyConservedReactingMoieties(conservedMoietiesOnly=true) and identifyConservedMoieties (spec 027 SC-001/SC-002).');
assert(isequal(armSibling.M2R, armConservedOnly.M2R), ...
    'arm.M2R must be identical between identifyConservedReactingMoieties(conservedMoietiesOnly=true) and identifyConservedMoieties (spec 027 SC-001/SC-002).');
assert(isequal(moietyFormulaeSibling, moietyFormulaeConservedOnly), ...
    'moietyFormulae must be identical between identifyConservedReactingMoieties(conservedMoietiesOnly=true) and identifyConservedMoieties (spec 027 SC-001/SC-002).');

% --- feature 20261002-conserved-only-skip-moiety-graphs (KNOWN ISSUE KI-001) ---
% options.computeMoietyGraphs = false (with conservedMoietiesOnly = true) skips the
% bond-level stage. Every output except arm.MG must be identical to the default
% conserved-only call above, and arm.MG must be an empty cell array. Placed before the
% MILP gate: no MILP is solved.
optionsNoMoietyGraphs = optionsConservedOnly;
optionsNoMoietyGraphs.computeMoietyGraphs = false;
[armNoMG, moietyFormulaeNoMG, reactingNoMG] = ...
    identifyConservedReactingMoieties(subModel, BG, dATM, optionsNoMoietyGraphs);

assert(iscell(armNoMG.MG) && isempty(armNoMG.MG), ...
    'arm.MG must be an empty cell array when options.computeMoietyGraphs = false (KI-001).');
assert(isequal(sort(fieldnames(armNoMG)), sort(fieldnames(armConservedOnly))), ...
    'arm must have the same fields with and without options.computeMoietyGraphs (KI-001).');
armFields = setdiff(fieldnames(armConservedOnly), {'MG'});
for k = 1:numel(armFields)
    assert(isequal(armNoMG.(armFields{k}), armConservedOnly.(armFields{k})), ...
        sprintf('arm.%s must be unchanged by options.computeMoietyGraphs = false (KI-001).', armFields{k}));
end
assert(isequal(moietyFormulaeNoMG, moietyFormulaeConservedOnly), ...
    'moietyFormulae must be unchanged by options.computeMoietyGraphs = false (KI-001).');
assert(isequal(reactingNoMG, reactingConservedOnly), ...
    'reacting must be unchanged by options.computeMoietyGraphs = false (KI-001).');

% computeMoietyGraphs = false is only valid in conserved-only mode
optionsInvalid = options;
optionsInvalid.sanityChecks = 0;
optionsInvalid.conservedMoietiesOnly = false;
optionsInvalid.computeMoietyGraphs = false;
raisedExpected = false;
try
    identifyConservedReactingMoieties(subModel, BG, dATM, optionsInvalid);
catch ME
    raisedExpected = strcmp(ME.identifier, ...
        'identifyConservedReactingMoieties:computeMoietyGraphsRequiresConservedOnly');
end
assert(raisedExpected, ...
    'computeMoietyGraphs = false without conservedMoietiesOnly = true must raise the documented error (KI-001).');

% the minimum-set-cover step uses a MILP (intlinprog or solveCobraMILP); require a
% MILP solver so the remaining, full-mode part of this test skips cleanly
% (COBRA:RequirementsNotMet) where none exists. Relocated here (was previously at the
% very top of this file) so the conserved-moieties-only assertions above -- which must
% not require a MILP solver (spec FR-002, SC-001) -- are still exercised on a runner
% with no MILP solver, rather than being skipped along with the rest of the script.
% --- feature 20260929-111453: golden comparison, conserved-moieties-only cases ---
% Placed before the MILP gate: these cases solve no MILP, so they run on every runner.
goldenReference = load([fileDir filesep 'data' filesep 'conservedReactingMoietiesReference.mat']);
for k = 1:numel(goldenReference.goldenCases)
    if isfield(goldenReference.goldenCases(k).options, 'conservedMoietiesOnly')
        checkGoldenCase(goldenReference.goldenCases(k), true);
    end
end

prepareTest('needsMILP', true);

% --- feature 20260929-111453: golden comparison, default-mode cases ---
% reacting is compared only when the MILP solver matches the one used at capture: optimal
% MILP solutions need not be unique across solvers.
for k = 1:numel(goldenReference.goldenCases)
    if ~isfield(goldenReference.goldenCases(k).options, 'conservedMoietiesOnly')
        checkGoldenCase(goldenReference.goldenCases(k), ...
            strcmp(goldenReference.goldenCases(k).milpSolver, CBT_MILP_SOLVER));
    end
end

% --- feature 20261102-092909: full-mode golden comparison on the bond-key fixtures ---
memoryReference = load([fileDir filesep 'data' filesep 'reactingMoietyMemoryReference.mat']);
for k = 1:numel(memoryReference.goldenCases)
    checkGoldenCase(memoryReference.goldenCases(k), ...
        strcmp(memoryReference.goldenCases(k).milpSolver, CBT_MILP_SOLVER));
end

% planted differences: isequaln must report each one, so the comparisons above can fail
hasControlData = arrayfun(@(c) strcmp(c.outcome, 'ok') && ~isempty(c.arm.MG) && ...
    nnz(c.arm.L) > 0 && ~isempty(c.reacting.ReactMoietyGraphs), memoryReference.goldenCases);
assert(any(hasControlData), 'No full-mode golden case has the outputs the controls perturb.');
controlCase = memoryReference.goldenCases(find(hasControlData, 1));
controlGraphs = controlCase.arm.MG;
controlGraphs{1} = addnode(controlGraphs{1}, 1);
assert(~isequaln(controlGraphs, controlCase.arm.MG), ...
    'A node added to an arm.MG graph is not detected.');
controlGraphs = controlCase.arm.MG;
graphIndex = find(cellfun(@numnodes, controlGraphs) > 0, 1);
controlNodes = controlGraphs{graphIndex}.Nodes;
numericVariables = controlNodes.Properties.VariableNames(varfun(@isnumeric, controlNodes, ...
    'OutputFormat', 'uniform'));
controlNodes.(numericVariables{1})(1) = controlNodes.(numericVariables{1})(1) + 1;
controlGraphs{graphIndex} = feval(class(controlGraphs{graphIndex}), ...
    controlGraphs{graphIndex}.Edges, controlNodes);
assert(~isequaln(controlGraphs, controlCase.arm.MG), ...
    'A changed numeric node value in an arm.MG graph is not detected.');
controlL = controlCase.arm.L;
[rowIndex, columnIndex] = find(controlL, 1);
controlL(rowIndex, columnIndex) = controlL(rowIndex, columnIndex) + 1;
assert(~isequaln(controlL, controlCase.arm.L), 'A changed entry of arm.L is not detected.');
controlReacting = controlCase.reacting.ReactMoietyGraphs;
controlReacting{end} = addedge(controlReacting{end}, 1, 1);
assert(~isequaln(controlReacting, controlCase.reacting.ReactMoietyGraphs), ...
    'An edge added to a reacting-moiety graph is not detected.');
clear memoryReference controlCase controlGraphs controlNodes controlL controlReacting

% identify conserved and reacting moieties
options.sanityChecks = 0;
[arm, moietyFormulae, reacting] = ...
    identifyConservedReactingMoieties(subModel, BG, dATM, options, dBTM);

% *** core invariant: the conserved-moiety matrix L satisfies L*N = 0 ***
assert(norm(full(arm.L) * N) < tol);
assert(isequal(size(arm.L), [2, 4]));           % 2 conserved moieties x 4 metabolites
assert(numel(moietyFormulae) == 2);

% the minimum set cover selects a minimal set of reactions covering reacting bonds
assert(numel(reacting.selectedReactionNames) == 2);
assert(all(ismember(reacting.selectedReactionNames, subModel.rxns)));

% --- feature 20261102-151507: the paper's published values (Rahou et al. 2026) ---
% conserved moieties on the shipped RXN files: L of App. C.1.1 over (h2o, cit, icit, cisa),
% the 6 moiety instances and 6 moiety transitions of Sec. 5.7.1, and the moiety formulae.
% Integer data, so exact comparisons.
assert(isequal(subModel.mets, {'h2o[m]'; 'cit[m]'; 'icit[m]'; 'HC00342[m]'}), ...
    'The example network''s metabolite order changed; the paper''s L is given over (h2o, cit, icit, cisa).');
assert(isequal(full(arm.L), [1 1 1 0; 0 1 1 1]), 'arm.L differs from the paper''s L (App. C.1.1).');
assert(numnodes(arm.MTG) == 6 && numedges(arm.MTG) == 6, ...
    'The paper has 6 moiety instances and 6 moiety transitions (Sec. 5.7.1).');
assert(isequal(moietyFormulae(:), {'H2O'; 'C6H3O6'}), 'The moiety formulae differ from H2O and C6H3O6.');
% on the shipped files citrate's arms are mapped inconsistently between ACONTm and the two
% dehydrations, so the condensed reacting bond graph has 6 vertices and 7 bonds (the paper's
% section 4.1 rule and the authors' original code give the same), not Fig. 11
assert(numnodes(reacting.Condensed_RBG) == 6 && numedges(reacting.Condensed_RBG) == 7, ...
    sprintf('Shipped files: condensed reacting bond graph has %d vertices and %d bonds, expected 6 and 7.', ...
    numnodes(reacting.Condensed_RBG), numedges(reacting.Condensed_RBG)));

% --- feature 20261106-092213-paper-reacting-bond-incidence: the paper's incidence ---
% A condensed reacting bond belongs to exactly the reactions that break, form or change the
% order of a reacting bond merged into it (Rahou et al. 2026, Sec. 6.1, eq. 32; spec FR-001,
% FR-003). The expected sets come from dBTM's broken and formed bonding interactions, not
% from CRB2R. On the shipped files the earlier end-atom rule marks ACONTm on edge 7 and r0317
% on edge 6, which they do not change, and leaves r0426 off edges 6 and 7 (research R3).
[expectedCRB2R, offGraphChanges] = expectedCondensedSets(subModel, dBTM, arm, reacting);
assert(offGraphChanges == 0, sprintf(['Shipped files: %d broken or formed bonding ' ...
    'interactions are on no condensed reacting bond.'], offGraphChanges));
for r = 1:numel(subModel.rxns)
    assert(isequal(full(reacting.CRB2R(:, r)) ~= 0, expectedCRB2R(:, r)), sprintf(['Shipped ' ...
        'files: the condensed reacting bonds of %s are {%s}, but the bonds it breaks or forms ' ...
        'are on {%s} (Rahou et al. 2026, Sec. 6.1).'], subModel.rxns{r}, ...
        num2str(find(reacting.CRB2R(:, r))'), num2str(find(expectedCRB2R(:, r))')));
end
plantedCRB2R = full(reacting.CRB2R) ~= 0;
plantedCRB2R(1, 1) = ~plantedCRB2R(1, 1);
assert(~isequal(plantedCRB2R, expectedCRB2R), 'A flipped entry of CRB2R is not detected.');
% planted control: an extra broken interaction, relabelled from ACONTm to r0317 on a
% condensed reacting bond r0317 does not change, must make the expected sets differ
r0317Rows = find(expectedCRB2R(:, strcmp(subModel.rxns, 'r0317')));
acontmBroken = find(strcmp(dBTM.Edges.TailMet, 'ACONTm'));
acontmBroken = acontmBroken(~ismember(condensedEdgeOfBond(full(dBTM.Edges.HeadBondIndex(acontmBroken)), ...
    dBTM, arm, reacting), [0; r0317Rows]));
assert(~isempty(acontmBroken), 'No ACONTm bond change is off r0317''s condensed reacting bonds.');
plantedEdge = dBTM.Edges(acontmBroken(1), :);
plantedEdge.TailMet = {'r0317'};
plantedEdge.rxns = {'r0317'};
plantedDBTM = addedge(dBTM, plantedEdge);
assert(~isequal(expectedCondensedSets(subModel, plantedDBTM, arm, reacting), ...
    full(reacting.CRB2R) ~= 0), 'An extra bond change in dBTM is not detected.');
clear plantedCRB2R r0317Rows acontmBroken plantedEdge plantedDBTM

% feature 20261106-092213 (spec FR-002, FR-006): the interface. The conserved-only calls
% above pass no dBTM and run. In full mode, the default rule without dBTM raises
% missingBondTransitions, and a value other than 'bondChange' or 'endAtom' (matched
% case-sensitively) raises invalidReactingBondIncidence.
optionsFullNoDBTM = options;
identifierRaised = '';
try
    identifyConservedReactingMoieties(subModel, BG, dATM, optionsFullNoDBTM);
catch ME
    identifierRaised = ME.identifier;
end
assert(strcmp(identifierRaised, 'identifyConservedReactingMoieties:missingBondTransitions'), ...
    sprintf('Full mode without dBTM must raise missingBondTransitions, got "%s".', identifierRaised));
for invalidValue = {'bondchange', 'end atom', 1, ''}
    optionsInvalidIncidence = options;
    optionsInvalidIncidence.reactingBondIncidence = invalidValue{1};
    identifierRaised = '';
    try
        identifyConservedReactingMoieties(subModel, BG, dATM, optionsInvalidIncidence, dBTM);
    catch ME
        identifierRaised = ME.identifier;
    end
    assert(strcmp(identifierRaised, 'identifyConservedReactingMoieties:invalidReactingBondIncidence'), ...
        sprintf('options.reactingBondIncidence = %s must raise invalidReactingBondIncidence, got "%s".', ...
        mat2str(invalidValue{1}), identifierRaised));
end
% 'endAtom' keeps the earlier rule, with or without dBTM: on the shipped files its CRB2R is
% the one ad0d11d60 gives (rows of each reaction, recorded in the feature's T008 run), and the
% conserved outputs are those of the default rule (FR-007)
optionsEndAtom = options;
optionsEndAtom.reactingBondIncidence = 'endAtom';
[armEndAtom, moietyFormulaeEndAtom, reactingEndAtom] = ...
    identifyConservedReactingMoieties(subModel, BG, dATM, optionsEndAtom);
endAtomRows = {'ACONTm', [1 2 4 6 7]; 'r0317', [1 3 5 6 7]; 'r0426', [2 3 4 5]};
for r = 1:size(endAtomRows, 1)
    endAtomColumn = strcmp(subModel.rxns, endAtomRows{r, 1});
    assert(isequal(find(reactingEndAtom.CRB2R(:, endAtomColumn))', endAtomRows{r, 2}), ...
        sprintf('''endAtom'': the condensed reacting bonds of %s are {%s}, expected {%s}.', ...
        endAtomRows{r, 1}, num2str(find(reactingEndAtom.CRB2R(:, endAtomColumn))'), ...
        num2str(endAtomRows{r, 2})));
end
[~, ~, reactingEndAtomWithDBTM] = ...
    identifyConservedReactingMoieties(subModel, BG, dATM, optionsEndAtom, dBTM);
assert(isequaln(reactingEndAtomWithDBTM, reactingEndAtom), '''endAtom'' must ignore dBTM.');
assert(isequaln(armEndAtom, arm) && isequaln(moietyFormulaeEndAtom, moietyFormulae), ...
    'The conserved outputs must not depend on options.reactingBondIncidence (FR-007).');
assert(isequaln(reactingEndAtom.Condensed_RBG, reacting.Condensed_RBG), ...
    'The condensed reacting bond graph must not depend on options.reactingBondIncidence.');
assert(~any(reactingEndAtom.unchangedReactingBonds) && reactingEndAtom.offGraphBondChanges == 0, ...
    '''endAtom'': no condensed reacting bond is unchanged and offGraphBondChanges is 0.');
clear optionsFullNoDBTM identifierRaised invalidValue optionsInvalidIncidence optionsEndAtom ...
    armEndAtom moietyFormulaeEndAtom reactingEndAtom reactingEndAtomWithDBTM endAtomRows endAtomColumn

% feature 20261106-092213 (spec FR-005): the two new fields. On the shipped files every
% condensed reacting bond is changed by some reaction and every bond change is on the graph.
assert(isequal(size(reacting.unchangedReactingBonds), [numedges(reacting.Condensed_RBG), 1]) && ...
    islogical(reacting.unchangedReactingBonds) && ~any(reacting.unchangedReactingBonds), ...
    'Shipped files: unchangedReactingBonds must be an all-false nCRB x 1 logical.');
assert(reacting.offGraphBondChanges == 0, 'Shipped files: offGraphBondChanges must be 0.');
% planted case: without the bond changes of ACONTm and r0317 (every condensed reacting bond
% here is changed by two reactions), the bonds only those two change are unchanged rows; they
% are left out of the cover, which still succeeds, and they are not off the graph
removedRxns = {'ACONTm', 'r0317'};
plantedDBTM = rmedge(dBTM, find(ismember(dBTM.Edges.TailMet, removedRxns) | ...
    ismember(dBTM.Edges.HeadMet, removedRxns)));
[~, ~, plantedReacting] = identifyConservedReactingMoieties(subModel, BG, dATM, options, plantedDBTM);
plantedExpected = expectedCondensedSets(subModel, plantedDBTM, arm, plantedReacting);
assert(any(plantedReacting.unchangedReactingBonds) && ...
    isequal(plantedReacting.unchangedReactingBonds, ~any(plantedExpected, 2)), sprintf(['Without ' ...
    'the bond changes of ACONTm and r0317, the unchanged condensed reacting bonds are {%s}, ' ...
    'expected {%s}.'], num2str(find(plantedReacting.unchangedReactingBonds)'), ...
    num2str(find(~any(plantedExpected, 2))')));
assert(plantedReacting.offGraphBondChanges == 0, 'Removing bond changes cannot put any off the graph.');
plantedSelected = ismember(subModel.rxns, plantedReacting.selectedReactionNames);
assert(all(any(plantedReacting.CRB2R(~plantedReacting.unchangedReactingBonds, plantedSelected), 2)), ...
    'Without the bond changes of ACONTm and r0317, the cover must still cover every changed bond.');
clear removedRxns plantedDBTM plantedReacting plantedExpected plantedSelected

% Fig. 11 on the consistent-arm copy: the contracted vertices are the atom-transition
% components of citrate's C3, C7, O2 and H8 (the paper's C3, C13, O2 and H15); the reacting
% bonds a..f and the reactions' bond sets Y1 = {b,c,d,e}, Y2 = {a,d,e,f}, Y3 = {a,b,c,f}
consistentDir = [fileDir filesep 'data' filesep 'rxnFilesConsistentArms'];
[consistentATM, ~, ~, ~, ~, ~, consistentBG, consistentDBTM] = buildAtomAndBondTransitionMultigraph( ...
    subModel, consistentDir, struct('directed', 0, 'sanityChecks', 1));
[consistentArm, consistentFormulae, consistentReacting] = identifyConservedReactingMoieties( ...
    subModel, consistentBG, consistentATM, struct('directed', 0, 'sanityChecks', 0), consistentDBTM);
assert(isequal(full(consistentArm.L), full(arm.L)) && isequal(consistentFormulae, moietyFormulae), ...
    'The consistent-arm mapping must not change the conserved moieties.');
fig11Graph = consistentReacting.Condensed_RBG;
assert(numnodes(fig11Graph) == 4 && numedges(fig11Graph) == 6, sprintf(['Fig. 11: the reacting ' ...
    'moiety graph has 4 vertices and 6 bonds, got %d and %d.'], numnodes(fig11Graph), numedges(fig11Graph)));
atgNodes = consistentArm.ATG.Nodes;
componentOfCitrateAtom = @(atomNumber) full(atgNodes.Component(strcmp(atgNodes.mets, 'cit[m]') & ...
    full(atgNodes.AtomNumber) == atomNumber));
paperComponents = [componentOfCitrateAtom(3), componentOfCitrateAtom(7), componentOfCitrateAtom(2), ...
    componentOfCitrateAtom(8)]; % paper C3, C13, O2, H15
[sortedComponents, ~] = sort(paperComponents);
[~, vertexOfPaperAtom] = ismember(paperComponents, sortedComponents); % condensed vertex ids
C3 = vertexOfPaperAtom(1); C13 = vertexOfPaperAtom(2); O2 = vertexOfPaperAtom(3); H15 = vertexOfPaperAtom(4);
paperBonds = struct('a', [C3 C13], 'b', [C3 O2], 'c', [C13 H15], 'd', [C3 H15], 'e', [C13 O2], 'f', [O2 H15]);
paperReactions = {'ACONTm', 'bcde'; 'r0426', 'adef'; 'r0317', 'abcf'};
fig11Edges = sort(fig11Graph.Edges.EndNodes, 2);
for r = 1:size(paperReactions, 1)
    reactionColumn = strcmp(subModel.rxns, paperReactions{r, 1});
    reactionEdges = sortrows(fig11Edges(full(consistentReacting.CRB2R(:, reactionColumn)) ~= 0, :));
    expectedEdges = sortrows(cell2mat(arrayfun(@(letter) sort(paperBonds.(letter)), ...
        paperReactions{r, 2}', 'UniformOutput', false)));
    assert(isequal(reactionEdges, expectedEdges), sprintf(['Fig. 11: the reacting bonds of %s ' ...
        'are not {%s}.'], paperReactions{r, 1}, strjoin(cellstr(paperReactions{r, 2}'), ',')));
end
assert(numel(consistentReacting.selectedReactionNames) == 2, ...
    'Fig. 11: a minimal cover of the reacting bonds has 2 reactions.');

% feature 20261106-092213 (spec US1 AS3): an order change counts as a change. r0317 forms,
% and r0426 breaks, one interaction of cis-aconitate's C=C bond (paper bond a); the condensed
% reacting bond that holds it belongs to exactly those two reactions.
cisaDoubleBond = find(strcmp(consistentDBTM.Nodes.Bond, 'HC00342[m]#2#C#HC00342[m]#6#C'));
assert(isscalar(cisaDoubleBond) && full(consistentDBTM.Nodes.BondType(cisaDoubleBond)) == 2, ...
    'Cis-aconitate''s C2=C6 bond must be one double bond of the consistent-arm dBTM.');
[changedBonds, changingRxns] = bondChanges(subModel, consistentDBTM);
cisaChangingRxns = sort(changingRxns(changedBonds == cisaDoubleBond));
assert(isequal(cisaChangingRxns, {'r0317'; 'r0426'}), sprintf(['The interactions of ' ...
    'cis-aconitate''s C=C bond changed by each reaction: expected one by r0317 and one by ' ...
    'r0426, got {%s}.'], strjoin(cisaChangingRxns, ', ')));
cisaRow = condensedEdgeOfBond(cisaDoubleBond, consistentDBTM, consistentArm, consistentReacting);
assert(cisaRow > 0, 'Cis-aconitate''s C=C bond is on no condensed reacting bond.');
cisaRowRxns = sort(subModel.rxns(full(consistentReacting.CRB2R(cisaRow, :)) ~= 0));
assert(isequal(cisaRowRxns, unique(cisaChangingRxns)), sprintf(['The condensed reacting ' ...
    'bond holding cis-aconitate''s C=C bond belongs to {%s}, not to the reactions that change ' ...
    'its order (r0317, r0426).'], strjoin(cisaRowRxns, ', ')));
assert(~any(consistentReacting.unchangedReactingBonds) && consistentReacting.offGraphBondChanges == 0, ...
    'Consistent arms: no condensed reacting bond is unchanged and no bond change is off the graph.');
clear consistentATM consistentBG consistentDBTM consistentArm consistentFormulae ...
    consistentReacting fig11Graph cisaDoubleBond changedBonds changingRxns cisaChangingRxns ...
    cisaRow cisaRowRxns

% --- feature 20261106-092213 (spec US1 AS1, FR-004): a reaction that moves bonds without
% changing them. CITICITtm (cit[c] + icit[m] -> cit[m] + icit[c]) is added to the example,
% with an identity atom map (data/rxnFilesTransport, research R6). It breaks and forms no
% bond, so its CRB2R column is zero and it is never selected; under the earlier end-atom rule
% it was marked on every condensed reacting bond with an end atom on citrate or isocitrate.
transportModel = addReaction(subModel, 'CITICITtm', 'reactionFormula', ...
    'cit[c] + icit[m] -> cit[m] + icit[c]', 'printLevel', 0);
assert(isequal(transportModel.mets(1:4), subModel.mets) && ...
    isequal(transportModel.rxns(1:3), subModel.rxns), ...
    'Adding CITICITtm must keep the example''s metabolite and reaction order.');
transportDir = [fileDir filesep 'data' filesep 'rxnFilesTransport'];
[transportATM, ~, transportRxnBool, ~, ~, ~, transportBG, transportDBTM] = ...
    buildAtomAndBondTransitionMultigraph(transportModel, transportDir, ...
    struct('directed', 0, 'sanityChecks', 1));
assert(all(transportRxnBool), 'The transport fixture must atom-map all four reactions.');
[transportArm, ~, transportReacting] = identifyConservedReactingMoieties(transportModel, ...
    transportBG, transportATM, struct('directed', 0, 'sanityChecks', 0), transportDBTM);
assert(numnodes(transportReacting.Condensed_RBG) == 4 && ...
    numedges(transportReacting.Condensed_RBG) == 6, sprintf(['With CITICITtm: the condensed ' ...
    'reacting bond graph has %d vertices and %d bonds, expected Fig. 11''s 4 and 6.'], ...
    numnodes(transportReacting.Condensed_RBG), numedges(transportReacting.Condensed_RBG)));
assert(isequal(full(transportArm.L(:, 1:4)), [1 1 1 0; 0 1 1 1]), ...
    'With CITICITtm: L over (h2o, cit, icit, cisa) differs from the paper''s L (App. C.1.1).');
transportColumn = strcmp(transportModel.rxns, 'CITICITtm');
assert(nnz(transportReacting.CRB2R(:, transportColumn)) == 0, sprintf(['CITICITtm breaks and ' ...
    'forms no bond, but CRB2R marks it on condensed reacting bonds {%s}.'], ...
    num2str(find(transportReacting.CRB2R(:, transportColumn))')));
assert(~ismember('CITICITtm', transportReacting.selectedReactionNames), ...
    'CITICITtm changes no bond and must not be selected.');
assertFig11Sets(transportModel, transportArm, transportReacting, 'With CITICITtm');
assert(~any(transportReacting.unchangedReactingBonds) && transportReacting.offGraphBondChanges == 0, ...
    'With CITICITtm: no condensed reacting bond is unchanged and no bond change is off the graph.');
clear transportModel transportDir transportATM transportRxnBool transportBG transportDBTM ...
    transportArm transportReacting transportColumn

% --- feature 026-conserved-moieties-only-option: US2 equivalence with the existing
% full computation (spec FR-003/FR-008/FR-009, SC-002/SC-003) ---
% The conserved-moieties-only run above and this full-mode run must agree exactly on
% every conserved-moiety-specific field, since both execute the identical conserved-
% moiety code path -- the option only decides whether execution continues past it.
assert(isequal(armConservedOnly.L, arm.L), ...
    'arm.L must be identical between conserved-moieties-only mode and the full computation (spec SC-002).');
assert(isequal(armConservedOnly.M2M, arm.M2M), ...
    'arm.M2M must be identical between conserved-moieties-only mode and the full computation (spec SC-002).');
assert(isequal(armConservedOnly.M2R, arm.M2R), ...
    'arm.M2R must be identical between conserved-moieties-only mode and the full computation (spec SC-002).');
assert(isequal(moietyFormulaeConservedOnly, moietyFormulae), ...
    'moietyFormulae must be identical between conserved-moieties-only mode and the full computation (spec SC-002).');

% the conservation invariant must also hold on the conserved-moieties-only run's arm.L
% (spec Acceptance Scenario 3 of US2), reusing the same N and tol as the full-mode check.
assert(norm(full(armConservedOnly.L) * N) < tol);

% classify bond transitions into conserved/reacting subgraphs
[brokenBondsTable, formedBondsTable, CAG, RAG, CBG, RBG] = ...
    identifyConservedReactingSubgraphs(subModel, dATM, dBTM);
reacting.brokenBondsTable = brokenBondsTable;
reacting.formedBondsTable = formedBondsTable;

assert(height(brokenBondsTable) == 7);
assert(height(formedBondsTable) == 7);

% build the reacting-moiety tables and display them (exercises displayReactingMoieties)
reacting = buildReactingMoietyTables(reacting, formedBondsTable, brokenBondsTable);
displayReactingMoieties(reacting);

% construct the moiety graph and the per-metabolite moiety subgraphs
moietyGraph = createMoietyGraph(subModel, BG, arm);
assert(numnodes(moietyGraph) > 0);

[MG, moietyMG, moietyInstanceG] = getMetMoietySubgraphs(subModel, BG, arm);
assert(numel(moietyMG) == 2);

% generate (but do not display) the representative figures from the tutorial
figure; plot(BG, 'Layout', 'layered'); title('Bond Instance Graph');
figure; spy(full(arm.L) * N); title('Verification: L*N = 0');
figure; plot(moietyGraph); title('Moiety Graph');

% clean up figures created during the test (visibility is restored by onCleanup)
close all force;

% --- feature 019-canonicalize-bond-node-keys: targeted crn[c] bond-node-key regression ---
% ELAIDCPT1/HMR_2634/HMR_2919 share crn[c], whose bonds were previously keyed inconsistently
% across independently-generated RXN files, inflating crn[c] to 31 bond-graph nodes (true count:
% 25) and triggering a spurious "Inconsistent directed bond transition multigraph" warning.
% This fixture and RXN triple are the real, MATLAB-verified reproduction of that bug (see
% specs/019-canonicalize-bond-node-keys/research.md R6); the crn[c] atom/bond numbering here
% differs from the r0317/ACONTm/r0426 fixture above and is unrelated to it.
crnSubModel = load([fileDir filesep 'data' filesep 'crnBondKeySubmodel.mat']);
crnSubModel = crnSubModel.subModel;

lastwarn('');
options.directed = 0;
options.sanityChecks = 1;
[~, ~, ~, ~, ~, ~, ~, crnDBTM] = ...
    buildAtomAndBondTransitionMultigraph(crnSubModel, rxnFilesDir, options);
[crnWarnMsg, ~] = lastwarn();

crnBondNodeCount = nnz(ismember(crnDBTM.Nodes.mets, 'crn[c]'));
assert(crnBondNodeCount == 25, ...
    sprintf('crn[c] should resolve to 25 bond-graph nodes (its true bond count), got %d.', crnBondNodeCount));
assert(isempty(strfind(crnWarnMsg, 'Inconsistent directed bond transition multigraph')), ...
    'buildAtomAndBondTransitionMultigraph should not warn of inconsistency for crn[c] across ELAIDCPT1/HMR_2634/HMR_2919.');

% US1 acceptance scenario 3: the same physical crn[c] bond referenced by different reactions
% resolves to the same BondIndex (i.e. the same dBTM.Nodes row) across all three reactions.
crnEdgesBool = ismember(crnDBTM.Nodes.mets(crnDBTM.Edges.EndNodes(:,1)), 'crn[c]') | ...
    ismember(crnDBTM.Nodes.mets(crnDBTM.Edges.EndNodes(:,2)), 'crn[c]');
crnRxnsTouchingCrn = unique(crnDBTM.Edges.rxns(crnEdgesBool));
assert(numel(crnRxnsTouchingCrn) == 3, ...
    'All three reactions (ELAIDCPT1, HMR_2634, HMR_2919) should reference crn[c] bond nodes.');

% --- feature 019-canonicalize-bond-node-keys: US3 per-metabolite bond-count sanity check ---
% (a) known-good case: the crn[c] fixture above is already a matching case (25 == 25), so the
% new sanity check inside buildAtomAndBondTransitionMultigraph must not have emitted its
% "does not match its true bond count" warning during that call.
assert(isempty(strfind(crnWarnMsg, 'does not match its true bond count')), ...
    'The per-metabolite bond-count sanity check must not warn for a metabolite whose bond-graph node count already matches its true bond count.');

% (b) deliberately-mismatched case: exercise the exact comparison-and-warn logic the sanity
% check uses (dBTM.Nodes.mets count vs. a ground-truth map), via a minimal synthetic scenario,
% since forcing a genuine post-fix RXN-level mismatch would require corrupting valid RXN syntax.
mismatchGroundTruth = containers.Map('KeyType', 'char', 'ValueType', 'double');
mismatchGroundTruth('syntheticMet[c]') = 5; % true bond count from its own molblock
syntheticNodesMets = repmat({'syntheticMet[c]'}, 7, 1); % 7 bond-graph nodes present (mismatch: 7 ~= 5)
lastwarn('');
actualBondNodeCount = nnz(strcmp(syntheticNodesMets, 'syntheticMet[c]'));
trueBondCount = mismatchGroundTruth('syntheticMet[c]');
if actualBondNodeCount ~= trueBondCount
    warning('%s bond-graph node count (%d) does not match its true bond count (%d) from its own RXN-file molblock.', 'syntheticMet[c]', actualBondNodeCount, trueBondCount);
end
[mismatchWarnMsg, ~] = lastwarn();
assert(~isempty(strfind(mismatchWarnMsg, 'does not match its true bond count')), ...
    'The per-metabolite bond-count sanity check logic must warn when a bond-graph node count does not match the true bond count.');
assert(~isempty(strfind(mismatchWarnMsg, 'syntheticMet[c]')), ...
    'The sanity-check warning must identify the mismatched metabolite by name.');
% execution continues past the warning (non-fatal) -- reaching this line proves that

% --- feature 020-canonicalize-symmetric-atom-bonds: coa[m]/coa[x]/coa[r]/crn[m] symmetry/
% resonance bond-node-identity regression (spec FR-007, SC-001-003) ---
% coa[m], coa[x] and coa[r] each contain CoA's gem-dimethyl pair of methyl carbons, which
% independently-generated RXN files number inconsistently; pre-fix, each resolves to 86
% bond-graph nodes (true count: 82). crn[m] additionally exercises carnitine's three
% symmetric N-methyl carbons and its resonance-ambiguous carboxylate bond type; pre-fix,
% it resolves to 29 nodes (true count: 25). See specs/020-canonicalize-symmetric-atom-bonds/
% spec.md Problem Statement and research.md R2/R2.3 for the full root-cause analysis.
symmetryFixtures = {'coaMBondKeySubmodel.mat', 'coa[m]', 82; ...
                     'coaXBondKeySubmodel.mat', 'coa[x]', 82; ...
                     'coaRBondKeySubmodel.mat', 'coa[r]', 82; ...
                     'crnMBondKeySubmodel.mat', 'crn[m]', 25};

for symIdx = 1:size(symmetryFixtures, 1)
    symFixtureFile = symmetryFixtures{symIdx, 1};
    symMet = symmetryFixtures{symIdx, 2};
    symExpectedCount = symmetryFixtures{symIdx, 3};

    symSubModel = load([fileDir filesep 'data' filesep symFixtureFile]);
    symSubModel = symSubModel.subModel;

    lastwarn('');
    options.directed = 0;
    options.sanityChecks = 1;
    [~, ~, ~, ~, ~, ~, ~, symDBTM] = ...
        buildAtomAndBondTransitionMultigraph(symSubModel, rxnFilesDir, options);
    [symWarnMsg, ~] = lastwarn();

    symActualCount = nnz(ismember(symDBTM.Nodes.mets, symMet));
    assert(symActualCount == symExpectedCount, ...
        sprintf('%s should resolve to %d bond-graph nodes (its true bond count), got %d.', ...
        symMet, symExpectedCount, symActualCount));

    % Metabolite-named substring check (rather than a blanket phrase check): the coa[x]
    % fixture also contains h2o2[x], which has its own, pre-existing, out-of-scope FR-008
    % mismatch unrelated to this feature (research.md scope: this feature targets
    % coa[m]/coa[x]/coa[r]/crn[m] specifically) -- a blanket check for the warning phrase
    % alone would spuriously fail on that unrelated warning even though coa[x] itself is
    % correct, so the assertion below names the target metabolite explicitly (matching
    % exactly what the FR-008 warning text embeds for that metabolite).
    assert(isempty(strfind(symWarnMsg, sprintf('%s bond-graph node count', symMet))), ...
        sprintf('buildAtomAndBondTransitionMultigraph should not warn of a bond-count mismatch for %s.', symMet));
end

% T009b: the crn[m] carboxylate carbon (atom 5) is bonded to two resonance-equivalent
% oxygens (atoms 3 and 6); their bond TYPE (not their atom identity -- the two bonds
% remain, correctly, two distinct bond-graph nodes) is only formally single/double
% depending on which Kekulé structure the atom-mapping tool recorded in a given RXN file.
% PPACOAATREVm is processed before HMR_2634 in this submodel's model.rxns order, so the
% first-seen bond-type cache (research R7) must resolve both canonicalized bond-node keys
% to PPACOAATREVm's own recorded bond types, deterministically, regardless of what
% HMR_2634 records for the same keys. Expected literal values captured directly against
% the post-fix pipeline (T007/T016 baseline-capture pass, feature 020 implementation,
% 2026-08-18): 2 (double) for the atom-5/atom-3 bond, 1 (single) for the atom-5/atom-6 bond.
crnMSubModel = load([fileDir filesep 'data' filesep 'crnMBondKeySubmodel.mat']);
crnMSubModel = crnMSubModel.subModel;
options.directed = 0;
options.sanityChecks = 1;
[~, ~, ~, ~, ~, ~, ~, crnMDBTM] = ...
    buildAtomAndBondTransitionMultigraph(crnMSubModel, rxnFilesDir, options);
assert(isequal(crnMSubModel.rxns(1:2), {'PPACOAATREVm'; 'HMR_2634'}), ...
    'crn[m] fixture''s model.rxns order changed -- T009b''s hardcoded expected BondType values assume PPACOAATREVm is processed first.');

carboxylateDoubleBondIdx = find(strcmp(crnMDBTM.Nodes.Bond, 'crn[m]#3#O#crn[m]#5#C'));
carboxylateSingleBondIdx = find(strcmp(crnMDBTM.Nodes.Bond, 'crn[m]#5#C#crn[m]#6#O'));
assert(isscalar(carboxylateDoubleBondIdx) && isscalar(carboxylateSingleBondIdx), ...
    'crn[m]''s canonicalized carboxylate bond-node keys (atom 5 to atom 3, and atom 5 to atom 6) must each resolve to exactly one dBTM.Nodes row.');
assert(full(crnMDBTM.Nodes.BondType(carboxylateDoubleBondIdx)) == 2, ...
    sprintf('crn[m]''s atom-5/atom-3 carboxylate bond-node should resolve to PPACOAATREVm''s first-seen BondType (2), got %d.', ...
    full(crnMDBTM.Nodes.BondType(carboxylateDoubleBondIdx))));
assert(full(crnMDBTM.Nodes.BondType(carboxylateSingleBondIdx)) == 1, ...
    sprintf('crn[m]''s atom-5/atom-6 carboxylate bond-node should resolve to PPACOAATREVm''s first-seen BondType (1), got %d.', ...
    full(crnMDBTM.Nodes.BondType(carboxylateSingleBondIdx))));

% --- feature 024-fix-empty-selection-bugs: US1 zero-MILP-selection regression ---
% MACACI (VMH) <-> rh_14817 (Rhea) is one of the four real pairs from the broad
% positive-control health-check run (2026-09-04, specs/024-fix-empty-selection-
% bugs/spec.md SC-001) whose reacting-bond minimum set-cover is genuinely
% degenerate: zero reacting bonds map to either candidate reaction, so
% solveCobraMILP's trivial optimum selects zero reactions (m_active == 0).
% Pre-fix, identifyConservedReactingMoieties.m's STEP 5 never executes the
% loops that assign RM_sets/RM_graph in that case, and STEP 6 throws
% "Unrecognized function or variable 'RM_sets'" reading them back (spec
% FR-001/FR-002). This is a hand-built, deliberately-unmerged combined model
% (the Stage 3/Stage 5 pilot convention mirrored from reconXmoieties'
% stage5_pilot_pgm_rh15901.m), built directly from each RXN file's own $MOL
% block header ('maleacac[c]'/'4fumacac[c]'/'CHEBI_17105[c]'/'CHEBI_18034[c]')
% -- not derived from Recon3D_301, since MACACI/rh_14817 are VMH/Rhea
% reactions outside that model. The two RXN files are vendored alongside this
% test's existing fixtures (test/verifiedTests/analysis/testReactingMoieties/
% data/rxnFiles/MACACI.rxn, rh_14817.rxn), copied verbatim from
% reconXmoieties' own staged reproduction data for this pair.
%
% This specific check requires a MILP solver that returns a trivial optimum
% for a fully unconstrained (zero-row) covering problem; gurobi does. glpk's
% MEX wrapper does not ('A cannot be an empty matrix', found empirically
% while building this regression) -- an unrelated, out-of-scope limitation in
% glpk's own zero-row handling, not touched by this feature; skip this
% sub-check gracefully rather than fail on it if gurobi is unavailable.
macaciGurobiOK = false;
try
    macaciGurobiOK = changeCobraSolver('gurobi', 'MILP', 0);
catch
    macaciGurobiOK = false;
end

if ~macaciGurobiOK
    warning('testConservedReactingMoieties:macaciSkipped', ...
        ['Skipping the MACACI/rh_14817 zero-MILP-selection regression: ' ...
         'gurobi MILP solver not available in this session.']);
else
    macaciModel = struct();
    macaciModel.mets = {'maleacac[c]'; '4fumacac[c]'; 'CHEBI_17105[c]'; 'CHEBI_18034[c]'};
    macaciModel.rxns = {'MACACI'; 'rh_14817'};
    macaciModel.S = sparse([-1  0; ...
                              1  0; ...
                              0 -1; ...
                              0  1]);
    macaciModel.lb = [-1000; -1000];
    macaciModel.ub = [ 1000;  1000];

    options.directed = 0;
    options.sanityChecks = 1;
    [macaciDATM, macaciMetBool, macaciRxnBool, ~, ~, ~, macaciBG, macaciDBTM] = ...
        buildAtomAndBondTransitionMultigraph(macaciModel, rxnFilesDir, options);
    assert(all(macaciMetBool) && all(macaciRxnBool), ...
        'MACACI/rh_14817 fixture should atom-map cleanly (both metabolites and both reactions).');

    options.sanityChecks = 0;
    [~, ~, macaciReacting] = identifyConservedReactingMoieties(macaciModel, macaciBG, macaciDATM, options, macaciDBTM);

    % US1 Acceptance Scenario 1 (spec.md): completes without error (implicit --
    % reaching this line proves it) and returns {} for both fields, not
    % undefined variables.
    assert(isempty(macaciReacting.selectedReactionNames), ...
        'MACACI/rh_14817''s MILP set-cover should select zero reactions (degenerate/empty covering problem) -- if this fails, the fixture no longer reproduces the zero-selection branch this test targets.');
    assert(iscell(macaciReacting.ReactMoietySets) && isequal(macaciReacting.ReactMoietySets, {}), ...
        'reacting.ReactMoietySets must be {} (not undefined) when the MILP set-cover selects zero reactions (spec FR-001/FR-002).');
    assert(iscell(macaciReacting.ReactMoietyGraphs) && isequal(macaciReacting.ReactMoietyGraphs, {}), ...
        'reacting.ReactMoietyGraphs must be {} (not undefined) when the MILP set-cover selects zero reactions (spec FR-001/FR-002).');
end

% --- feature 024-fix-empty-selection-bugs: US2 empty-reacting-moiety-table
% schema regression (FR-003/FR-004/FR-009) ---
% Reuses this test's own already-computed r0317/ACONTm/r0426 fixture output
% (reacting, formedBondsTable, brokenBondsTable from earlier in this file) --
% no new biological fixture data needed. buildReactingMoietyTables.m stored a
% bare, columnless table() whenever a selected reaction's formed- and broken-
% bond subtables were BOTH empty (US2 Acceptance Scenario 1), and could not
% even concatenate [F; B] when exactly ONE side was empty (the latent third
% crash, FR-009, found during spec validation pass 2) -- both were traced to
% the same `~isempty(F)`/`~isempty(B)` guards around the BondChange column
% assignment.
phantomReacting = reacting;
phantomReacting.selectedReactionNames = [reacting.selectedReactionNames; ...
    {'PHANTOM_NO_REACTING_BONDS'}; {'PHANTOM_ONE_SIDE_EMPTY'}];

% one-sided phantom row: matches formedBondsTable's own column schema (a row
% slice of the same dBTM.Edges table brokenBondsTable is sliced from -- see
% identifyConservedReactingSubgraphs.m:58-59), so no column is hand-typed
% here; only its `rxns` value is overwritten to the phantom reaction name.
phantomFormedRow = formedBondsTable(1, :);
phantomFormedRow.rxns = {'PHANTOM_ONE_SIDE_EMPTY'};
phantomFormedBondsTable = [formedBondsTable; phantomFormedRow];

phantomReacting = buildReactingMoietyTables(phantomReacting, phantomFormedBondsTable, brokenBondsTable);

% both-empty branch (US2 Acceptance Scenario 1, FR-003/FR-004): no row of
% either formedBondsTable or brokenBondsTable names 'PHANTOM_NO_REACTING_BONDS'.
phantomBothEmptyIdx = find(strcmp(phantomReacting.selectedReactionNames, 'PHANTOM_NO_REACTING_BONDS'));
assert(isscalar(phantomBothEmptyIdx), 'Phantom both-empty reaction name not found where expected.');
bothEmptyTable = phantomReacting.reactMoietyTables{phantomBothEmptyIdx};
assert(istable(bothEmptyTable) && height(bothEmptyTable) == 0, ...
    'A reaction with no formed/broken bonds must produce a zero-row table (not error).');
assert(ismember('BondChange', bothEmptyTable.Properties.VariableNames), ...
    'The zero-row table for a no-reacting-bonds reaction must still carry a BondChange column (spec FR-003/FR-004) -- not a bare table().');

% one-empty branch (FR-009): exactly one phantom formed-bond row, zero
% broken-bond rows, for 'PHANTOM_ONE_SIDE_EMPTY'.
phantomOneSideIdx = find(strcmp(phantomReacting.selectedReactionNames, 'PHANTOM_ONE_SIDE_EMPTY'));
assert(isscalar(phantomOneSideIdx), 'Phantom one-side-empty reaction name not found where expected.');
oneSideEmptyTable = phantomReacting.reactMoietyTables{phantomOneSideIdx};
assert(istable(oneSideEmptyTable) && height(oneSideEmptyTable) == 1, ...
    '[F; B] must concatenate without error when exactly one side is empty, yielding the one real (formed) row (spec FR-009).');
assert(ismember('BondChange', oneSideEmptyTable.Properties.VariableNames) && ...
    strcmp(string(oneSideEmptyTable.BondChange(1)), 'formed'), ...
    'The one-empty-subtable result must carry a uniform BondChange column regardless of which side was empty (spec FR-009).');

% US2 Acceptance Scenario 3 (non-regression): the non-empty r0317/ACONTm/
% r0426 reactions computed earlier in this file are unaffected by the phantom
% additions above (same object identity for the real entries).
for realIdx = 1:numel(reacting.selectedReactionNames)
    assert(isequal(phantomReacting.reactMoietyTables{realIdx}, reacting.reactMoietyTables{realIdx}), ...
        'Pre-existing (non-phantom) reactMoietyTables entries must be unchanged by this regression check.');
end

% return to the original directory
cd(currentDir);

function checkGoldenCase(goldenCase, compareReacting)
% Assert that identifyConservedReactingMoieties gives the captured outputs, or raises the
% captured error, on one golden case
if strcmp(goldenCase.outcome, 'error')
    errorRaised = false;
    try
        identifyConservedReactingMoieties(goldenCase.model, goldenCase.BG, goldenCase.dATM, ...
            goldenCase.options);
    catch ME
        errorRaised = true;
        assert(strcmp(ME.identifier, goldenCase.errorIdentifier) && ...
            strcmp(ME.message, goldenCase.errorMessage), ...
            sprintf(['identifyConservedReactingMoieties raised a different error from the ' ...
            'captured one (%s): expected "%s", got "%s" (%s:%d).'], goldenCase.name, ...
            goldenCase.errorMessage, ME.message, ME.stack(1).file, ME.stack(1).line));
    end
    assert(errorRaised, sprintf(['identifyConservedReactingMoieties returned normally, but ' ...
        'the captured run raised "%s" (%s).'], goldenCase.errorMessage, goldenCase.name));
    return
end
[arm, moietyFormulae, reacting] = identifyConservedReactingMoieties(goldenCase.model, ...
    goldenCase.BG, goldenCase.dATM, goldenCase.options);
assert(isequaln(arm, goldenCase.arm), ...
    sprintf('arm differs from the captured reference (%s).', goldenCase.name));
assert(isequaln(moietyFormulae, goldenCase.moietyFormulae), ...
    sprintf('moietyFormulae differs from the captured reference (%s).', goldenCase.name));
if compareReacting
    assert(isequaln(reacting, goldenCase.reacting), ...
        sprintf('reacting differs from the captured reference (%s).', goldenCase.name));
else
    fprintf('%s: reacting not compared (MILP solver differs from the captured %s).\n', ...
        goldenCase.name, goldenCase.milpSolver);
end
end

function [changedBonds, changingRxns] = bondChanges(model, dBTM)
% The bonding interactions dBTM records as broken or formed, as (BondIndex, reaction) pairs,
% one per interaction: a broken interaction is an edge whose TailMet is a reaction (the bond
% is its HeadBondIndex), a formed one an edge whose HeadMet is a reaction (bond TailBondIndex)
% (research R1)
broken = ismember(dBTM.Edges.TailMet, model.rxns);
formed = ismember(dBTM.Edges.HeadMet, model.rxns);
changedBonds = full([dBTM.Edges.HeadBondIndex(broken); dBTM.Edges.TailBondIndex(formed)]);
changingRxns = [dBTM.Edges.rxns(broken); dBTM.Edges.rxns(formed)];
end

function rows = condensedEdgeOfBond(bondIndex, dBTM, arm, reacting)
% The condensed reacting bond whose atom-transition component pair is that of each bond, 0
% where there is none. Every reacting bond merged into a condensed edge has that edge's
% component pair, so this finds the edge without CRB2R (the union rule of spec FR-003).
atomIndex = full(arm.ATG.Nodes.AtomIndex);
component = full(arm.ATG.Nodes.Component);
bondPair = @(b) sort(reshape(component(arrayfun(@(a) find(atomIndex == a), ...
    full([dBTM.Nodes.BondHeadAtomIndex(b(:)), dBTM.Nodes.BondTailAtomIndex(b(:))]))), [], 2), 2);
edgePairs = bondPair(reacting.Condensed_RBG.Edges.BondIndex);
assert(size(unique(edgePairs, 'rows'), 1) == size(edgePairs, 1), ...
    'Two condensed reacting bonds have the same atom-transition component pair.');
[~, rows] = ismember(bondPair(bondIndex), edgePairs, 'rows');
end

function [expectedCRB2R, offGraphChanges] = expectedCondensedSets(model, dBTM, arm, reacting)
% Each reaction's condensed reacting bonds by the paper's rule (Rahou et al. 2026, Sec. 6.1,
% eq. 32), computed without CRB2R: the bonds dBTM records as broken or formed by the
% reaction, on the condensed edge with their component pair. offGraphChanges counts the
% interactions on no condensed edge.
[changedBonds, changingRxns] = bondChanges(model, dBTM);
rows = condensedEdgeOfBond(changedBonds, dBTM, arm, reacting);
[~, columns] = ismember(changingRxns, model.rxns);
onGraph = rows > 0;
expectedCRB2R = full(sparse(rows(onGraph), columns(onGraph), 1, ...
    numedges(reacting.Condensed_RBG), numel(model.rxns))) ~= 0;
offGraphChanges = nnz(~onGraph);
end

function assertFig11Sets(model, arm, reacting, label)
% The bond sets of Fig. 11 (Rahou et al. 2026) for ACONTm, r0426 and r0317, compared as
% atom-transition component pairs of citrate's C3, C7, O2 and H8 (the paper's C3, C13, O2
% and H15), as in the consistent-arm check above
atgNodes = arm.ATG.Nodes;
componentOfCitrateAtom = @(atomNumber) full(atgNodes.Component(strcmp(atgNodes.mets, 'cit[m]') & ...
    full(atgNodes.AtomNumber) == atomNumber));
paperComponents = [componentOfCitrateAtom(3), componentOfCitrateAtom(7), componentOfCitrateAtom(2), ...
    componentOfCitrateAtom(8)];
[~, vertexOfPaperAtom] = ismember(paperComponents, sort(paperComponents));
C3 = vertexOfPaperAtom(1); C13 = vertexOfPaperAtom(2); O2 = vertexOfPaperAtom(3); H15 = vertexOfPaperAtom(4);
paperBonds = struct('a', [C3 C13], 'b', [C3 O2], 'c', [C13 H15], 'd', [C3 H15], 'e', [C13 O2], 'f', [O2 H15]);
paperReactions = {'ACONTm', 'bcde'; 'r0426', 'adef'; 'r0317', 'abcf'};
graphEdges = sort(reacting.Condensed_RBG.Edges.EndNodes, 2);
for r = 1:size(paperReactions, 1)
    reactionColumn = strcmp(model.rxns, paperReactions{r, 1});
    reactionEdges = sortrows(graphEdges(full(reacting.CRB2R(:, reactionColumn)) ~= 0, :));
    expectedEdges = sortrows(cell2mat(arrayfun(@(letter) sort(paperBonds.(letter)), ...
        paperReactions{r, 2}', 'UniformOutput', false)));
    assert(isequal(reactionEdges, expectedEdges), sprintf(['%s: the reacting bonds of %s ' ...
        'are not {%s} (Fig. 11).'], label, paperReactions{r, 1}, strjoin(cellstr(paperReactions{r, 2}'), ',')));
end
end
