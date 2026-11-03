% captureRenumberedGoldens.m
%
% Recapture of the golden references whose stored inputs were built by the builder before
% feature 20261102-151507-whole-molecule-bond-renumbering (tasks.md T010; spec FR-007).
% MUST run on the FIXED builder (it refuses otherwise).
%
% For every case of data/conservedReactingMoietiesReference.mat and
% data/reactingMoietyMemoryReference.mat it:
%   1. rebuilds the stored inputs BG and dATM with the fixed builder, from the case's model
%      and the fixture RXN files (directed = 0, sanityChecks = 1, as at their capture);
%   2. reruns identifyConservedReactingMoieties with the case's options, recording the
%      outputs or the error;
%   3. compares old and new, field by field, and stops without saving if a conserved-moiety
%      output (L, M2M, M2R, ATG, MTG, moietyFormulae) or the outcome changed (FR-006);
%   4. saves both references with the same fields, plus a provenance struct, and appends the
%      per-case, per-field difference table to wholeMoleculeRenumberingResults.md.
%
% USAGE (headless, in its own memory-capped scope):
%   matlab -batch "initCobraToolbox(false); run('<repo>/specs/20261102-151507-whole-molecule-bond-renumbering/captureRenumberedGoldens.m')"

global CBT_MILP_SOLVER

featureDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(featureDir));
builderFile = 'src/analysis/topology/reactingMoieties/buildAtomAndBondTransitionMultigraph.m';
testDir = fullfile(repoRoot, 'test', 'verifiedTests', 'analysis', 'testReactingMoieties');
rxnFilesDir = fullfile(testDir, 'data', 'rxnFiles');
baseCommit = '5a4371497';

builderStatus = system(sprintf('git -C "%s" diff --quiet %s -- %s', repoRoot, baseCommit, builderFile));
if builderStatus == 0
    error('captureRenumberedGoldens:builderUnchanged', ...
        '%s equals %s: the references must be recaptured with the fixed builder.', builderFile, baseCommit);
end
addpath(fullfile(repoRoot, 'src', 'analysis', 'topology', 'reactingMoieties'), '-begin');
assert(startsWith(which('buildAtomAndBondTransitionMultigraph'), repoRoot), ...
    'buildAtomAndBondTransitionMultigraph does not resolve to this repository.');
changeCobraSolver('gurobi', 'MILP', 0);
[~, headCommit] = system(sprintf('git -C "%s" rev-parse --short HEAD', repoRoot));
provenance = struct('feature', '20261102-151507-whole-molecule-bond-renumbering', ...
    'baseCommit', baseCommit, 'headCommit', strtrim(headCommit), 'matlab', version, ...
    'milpSolver', CBT_MILP_SOLVER, 'created', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));

conservedFields = {'L', 'M2M', 'M2R', 'ATG', 'MTG'};
reportLines = {'', '## Recaptured golden references (T010, T011)', '', ...
    sprintf('Run %s, head `%s`. For each case: whether the stored inputs and each output changed (`=` unchanged, `changed`).', ...
    provenance.created, provenance.headCommit), ''};
newReferences = struct();
for referenceName = {'conservedReactingMoietiesReference', 'reactingMoietyMemoryReference'}
    referenceFile = fullfile(testDir, 'data', [referenceName{1} '.mat']);
    old = load(referenceFile);
    goldenCases = old.goldenCases;
    reportLines(end + 1:end + 3) = {sprintf('### `%s.mat`', referenceName{1}), '', ...
        '| Case | outcome | BG | dATM | conserved (L, M2M, M2R, ATG, MTG, formulae) | arm fields changed | reacting fields changed |'};
    reportLines{end + 1} = '|---|---|---|---|---|---|---|';
    for k = 1:numel(goldenCases)
        oldCase = goldenCases(k);
        newCase = oldCase;
        [dATM, ~, ~, ~, ~, ~, BG] = buildAtomAndBondTransitionMultigraph(oldCase.model, rxnFilesDir, ...
            struct('directed', 0, 'sanityChecks', 1));
        newCase.BG = BG;
        newCase.dATM = dATM;
        newCase.milpSolver = CBT_MILP_SOLVER;
        newCase.outcome = 'ok';
        newCase.errorIdentifier = '';
        newCase.errorMessage = '';
        newCase.arm = [];
        newCase.moietyFormulae = [];
        newCase.reacting = [];
        try
            [newCase.arm, newCase.moietyFormulae, newCase.reacting] = ...
                identifyConservedReactingMoieties(oldCase.model, BG, dATM, oldCase.options);
        catch ME
            newCase.outcome = 'error';
            newCase.errorIdentifier = ME.identifier;
            newCase.errorMessage = ME.message;
        end
        assert(strcmp(newCase.outcome, oldCase.outcome), ...
            'FR-006: the outcome of %s changed from %s to %s (%s).', oldCase.name, oldCase.outcome, ...
            newCase.outcome, newCase.errorMessage);
        mark = @(a, b) ternary(isequaln(a, b), '=', 'changed');
        armChanged = {};
        reactingChanged = {};
        conservedSame = true;
        if strcmp(newCase.outcome, 'ok')
            for f = fieldnames(oldCase.arm)'
                if ~isfield(newCase.arm, f{1}) || ~isequaln(oldCase.arm.(f{1}), newCase.arm.(f{1}))
                    armChanged{end + 1} = f{1}; %#ok<AGROW>
                end
            end
            conservedSame = ~any(ismember(conservedFields, armChanged)) && ...
                isequaln(oldCase.moietyFormulae, newCase.moietyFormulae);
            if isstruct(oldCase.reacting)
                for f = fieldnames(oldCase.reacting)'
                    if ~isfield(newCase.reacting, f{1}) || ~isequaln(oldCase.reacting.(f{1}), newCase.reacting.(f{1}))
                        reactingChanged{end + 1} = f{1}; %#ok<AGROW>
                    end
                end
            end
        else
            conservedSame = strcmp(oldCase.errorMessage, newCase.errorMessage);
        end
        assert(conservedSame, 'FR-006: a conserved-moiety output of %s changed (%s).', oldCase.name, ...
            strjoin(armChanged, ', '));
        reportLines{end + 1} = sprintf('| %s | %s | %s | %s | = | %s | %s |', oldCase.name, oldCase.outcome, ...
            mark(oldCase.BG, newCase.BG), mark(oldCase.dATM, newCase.dATM), ...
            joinOrDash(armChanged), joinOrDash(reactingChanged));
        goldenCases(k) = newCase;
        fprintf('RC %s %s: BG %s, arm changed {%s}, reacting changed {%s}\n', referenceName{1}, ...
            oldCase.name, mark(oldCase.BG, newCase.BG), strjoin(armChanged, ' '), strjoin(reactingChanged, ' '));
    end
    reportLines{end + 1} = '';
    newReferences.(referenceName{1}) = goldenCases;
end

% every case passed the FR-006 check: save both references and the report
for referenceName = fieldnames(newReferences)'
    goldenCases = newReferences.(referenceName{1}); %#ok<NASGU>
    save(fullfile(testDir, 'data', [referenceName{1} '.mat']), 'goldenCases', 'provenance', '-v7');
    fprintf('RC saved %s.mat\n', referenceName{1});
end
fid = fopen(fullfile(featureDir, 'wholeMoleculeRenumberingResults.md'), 'a');
fprintf(fid, '%s\n', reportLines{:});
fclose(fid);

function out = ternary(condition, a, b)
if condition
    out = a;
else
    out = b;
end
end

function text = joinOrDash(names)
if isempty(names)
    text = '—';
else
    text = strjoin(strcat('`', names, '`'), ', ');
end
end
