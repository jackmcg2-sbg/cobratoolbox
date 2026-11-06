% capturePaperIncidenceGoldens.m
%
% Recapture of the golden references under the paper's reacting-bond incidence (feature
% 20261106-092213-paper-reacting-bond-incidence, tasks.md T019; spec FR-006, FR-007, FR-008;
% research R7). MUST run on the committed source (it refuses otherwise).
%
% It:
%   1. writes today's references, as at ad0d11d60, to data/*EndAtom.mat, for the 'endAtom'
%      comparison (FR-006);
%   2. for every case of data/conservedReactingMoietiesReference.mat and
%      data/reactingMoietyMemoryReference.mat, rebuilds BG, dATM and dBTM from the case's model
%      and the fixture RXN files (directed = 0, sanityChecks = 1, as at their capture), and
%      stops if the rebuilt BG or dATM differs from the stored one;
%   3. reruns identifyConservedReactingMoieties with the case's options and dBTM (the default
%      rule, 'bondChange'), recording the outputs or the error;
%   4. stops without saving if the outcome, the error message, or any arm or moietyFormulae
%      field changed (FR-007);
%   5. saves both references with goldenCase.dBTM (empty for conserved-only cases). If the two
%      files together exceed 10 MB, it saves them without dBTM instead, and the test rebuilds
%      dBTM per case;
%   6. writes goldenDifferenceReport.md: per case, each changed reacting field, before and
%      after.
%
% USAGE (headless, in its own memory-capped scope):
%   matlab -batch "initCobraToolbox(false); run('<repo>/specs/20261106-092213-paper-reacting-bond-incidence/capturePaperIncidenceGoldens.m')"

global CBT_MILP_SOLVER

featureDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(featureDir));
rmDir = 'src/analysis/topology/reactingMoieties';
testDir = fullfile(repoRoot, 'test', 'verifiedTests', 'analysis', 'testReactingMoieties');
testDataRelative = 'test/verifiedTests/analysis/testReactingMoieties/data';
rxnFilesDir = fullfile(testDir, 'data', 'rxnFiles');
baseCommit = 'ad0d11d60';
sizeLimitBytes = 10e6;

if system(sprintf('git -C "%s" diff --quiet HEAD -- %s', repoRoot, rmDir)) ~= 0
    error('capturePaperIncidenceGoldens:uncommittedSource', ...
        '%s has uncommitted changes: the references must be captured from committed source.', rmDir);
end
addpath(fullfile(repoRoot, rmDir), '-begin');
assert(startsWith(which('identifyConservedReactingMoieties'), repoRoot), ...
    'identifyConservedReactingMoieties does not resolve to this repository.');
changeCobraSolver('gurobi', 'MILP', 0);
[~, headCommit] = system(sprintf('git -C "%s" rev-parse --short HEAD', repoRoot));
provenance = struct('feature', '20261106-092213-paper-reacting-bond-incidence', ...
    'baseCommit', baseCommit, 'headCommit', strtrim(headCommit), 'matlab', version, ...
    'milpSolver', CBT_MILP_SOLVER, 'reactingBondIncidence', 'bondChange', ...
    'created', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));

referenceNames = {'conservedReactingMoietiesReference', 'reactingMoietyMemoryReference'};
reportLines = {'# Golden difference report', '', ...
    sprintf(['Feature `20261106-092213-paper-reacting-bond-incidence`, tasks.md T019. Run %s, ' ...
    'head `%s`, MILP solver %s. The references as at `%s` are kept as `*EndAtom.mat`. For ' ...
    'each case: the outcome, whether every `arm` and `moietyFormulae` field is unchanged ' ...
    '(required), and each `reacting` field that changed, before and after. Fields new in this ' ...
    'feature are listed as added.'], provenance.created, provenance.headCommit, ...
    CBT_MILP_SOLVER, baseCommit), ''};
newReferences = struct();
for referenceName = referenceNames
    referenceFile = fullfile(testDir, 'data', [referenceName{1} '.mat']);
    endAtomFile = fullfile(testDir, 'data', [referenceName{1} 'EndAtom.mat']);
    % 1. today's reference, from the base commit, so that a rerun cannot copy a recaptured file
    status = system(sprintf('git -C "%s" show %s:%s/%s.mat > "%s"', repoRoot, baseCommit, ...
        testDataRelative, referenceName{1}, endAtomFile));
    assert(status == 0, 'Could not write %s from %s.', endAtomFile, baseCommit);
    old = load(endAtomFile);
    goldenCases = old.goldenCases;
    goldenCases(1).dBTM = [];
    reportLines(end + 1:end + 4) = {sprintf('## `%s.mat`', referenceName{1}), '', ...
        '| Case | Mode | Outcome | `arm`, `moietyFormulae` | `reacting` fields changed (before → after) |', ...
        '|---|---|---|---|---|'};
    for k = 1:numel(goldenCases)
        oldCase = old.goldenCases(k);
        newCase = goldenCases(k);
        conservedOnly = isfield(oldCase.options, 'conservedMoietiesOnly') && oldCase.options.conservedMoietiesOnly;
        % 2. the stored inputs must be reproduced; dBTM comes from the same build
        [dATM, ~, ~, ~, ~, ~, BG, dBTM] = buildAtomAndBondTransitionMultigraph(oldCase.model, ...
            rxnFilesDir, struct('directed', 0, 'sanityChecks', 1));
        assert(isequaln(BG, oldCase.BG) && isequaln(dATM, oldCase.dATM), ...
            'The rebuilt BG (%d) or dATM (%d) of %s differs from the stored one.', ...
            isequaln(BG, oldCase.BG), isequaln(dATM, oldCase.dATM), oldCase.name);
        if conservedOnly
            newCase.dBTM = [];
        else
            newCase.dBTM = dBTM;
        end
        % 3. rerun under the default rule
        newCase.milpSolver = CBT_MILP_SOLVER;
        newCase.outcome = 'ok';
        newCase.errorIdentifier = '';
        newCase.errorMessage = '';
        newCase.arm = [];
        newCase.moietyFormulae = [];
        newCase.reacting = [];
        try
            [newCase.arm, newCase.moietyFormulae, newCase.reacting] = identifyConservedReactingMoieties( ...
                oldCase.model, oldCase.BG, oldCase.dATM, oldCase.options, newCase.dBTM);
        catch ME
            newCase.outcome = 'error';
            newCase.errorIdentifier = ME.identifier;
            newCase.errorMessage = ME.message;
        end
        % 4. FR-007: only reacting may change
        assert(strcmp(newCase.outcome, oldCase.outcome), 'FR-007: the outcome of %s changed from %s to %s (%s).', ...
            oldCase.name, oldCase.outcome, newCase.outcome, newCase.errorMessage);
        reactingChanged = {};
        if strcmp(newCase.outcome, 'ok')
            assert(isequaln(newCase.arm, oldCase.arm) && isequaln(newCase.moietyFormulae, oldCase.moietyFormulae), ...
                'FR-007: arm or moietyFormulae of %s changed.', oldCase.name);
            if isstruct(newCase.reacting)
                for f = fieldnames(newCase.reacting)'
                    if ~isfield(oldCase.reacting, f{1})
                        reactingChanged{end + 1} = sprintf('`%s` added: %s', f{1}, ...
                            describeValue(newCase.reacting.(f{1}))); %#ok<AGROW>
                    elseif ~isequaln(oldCase.reacting.(f{1}), newCase.reacting.(f{1}))
                        reactingChanged{end + 1} = sprintf('`%s`: %s → %s', f{1}, ...
                            describeValue(oldCase.reacting.(f{1})), describeValue(newCase.reacting.(f{1}))); %#ok<AGROW>
                    end
                end
                assert(isempty(setdiff(fieldnames(oldCase.reacting), fieldnames(newCase.reacting))), ...
                    'A reacting field of %s was removed.', oldCase.name);
            end
            outcomeText = 'ok';
        else
            assert(strcmp(newCase.errorIdentifier, oldCase.errorIdentifier) && ...
                strcmp(newCase.errorMessage, oldCase.errorMessage), ...
                'FR-007: the error of %s changed from "%s" to "%s".', oldCase.name, ...
                oldCase.errorMessage, newCase.errorMessage);
            outcomeText = sprintf('error, unchanged ("%s")', newCase.errorMessage);
        end
        modeText = 'full';
        if conservedOnly
            modeText = 'conserved-only';
        end
        reportLines{end + 1} = sprintf('| %s | %s | %s | unchanged | %s |', oldCase.name, modeText, ...
            outcomeText, joinOrDash(reactingChanged)); %#ok<SAGROW>
        goldenCases(k) = newCase;
        fprintf('GC %s %s: %s; reacting changed {%s}\n', referenceName{1}, oldCase.name, outcomeText, ...
            strjoin(reactingChanged, '; '));
    end
    reportLines{end + 1} = ''; %#ok<SAGROW>
    newReferences.(referenceName{1}) = goldenCases;
end

% 5. every case passed the FR-007 check: save both references, with dBTM if they stay small
storedDBTM = true;
for attempt = 1:2
    totalBytes = 0;
    for referenceName = referenceNames
        goldenCases = newReferences.(referenceName{1});
        if ~storedDBTM
            [goldenCases.dBTM] = deal([]);
        end
        provenance.storedDBTM = storedDBTM;
        referenceFile = fullfile(testDir, 'data', [referenceName{1} '.mat']);
        save(referenceFile, 'goldenCases', 'provenance', '-v7');
        fileInfo = dir(referenceFile);
        totalBytes = totalBytes + fileInfo.bytes;
    end
    if totalBytes <= sizeLimitBytes || ~storedDBTM
        break
    end
    storedDBTM = false;
end
if storedDBTM
    storageText = sprintf('The two references store `dBTM` (%.2f MB together, limit 10 MB).', totalBytes / 1e6);
else
    storageText = sprintf(['With `dBTM` the two references exceeded 10 MB, so they store none ' ...
        '(%.2f MB together); the test rebuilds `dBTM` per case.'], totalBytes / 1e6);
end
fprintf('GC saved; %s\n', storageText);
reportLines(end + 1:end + 2) = {'## Storage', ''};
reportLines{end + 1} = storageText;
reportLines{end + 1} = '';

% 6. the report
fid = fopen(fullfile(featureDir, 'goldenDifferenceReport.md'), 'w');
fprintf(fid, '%s\n', reportLines{:});
fclose(fid);

function text = describeValue(value)
% A short description of a reacting field's value for the report
if isa(value, 'graph') || isa(value, 'digraph')
    text = sprintf('%d vertices, %d edges', numnodes(value), numedges(value));
elseif iscell(value) && all(cellfun(@(c) ischar(c) || isstring(c), value(:)))
    text = ['{' strjoin(cellstr(value(:)'), ', ') '}'];
elseif iscell(value)
    text = sprintf('%d cells', numel(value));
elseif islogical(value)
    text = sprintf('%d x %d logical, %d true', size(value, 1), size(value, 2), nnz(value));
elseif isnumeric(value) && numel(value) <= 12
    text = mat2str(full(value(:)'));
elseif isnumeric(value)
    text = sprintf('%d x %d, %d nonzeros', size(value, 1), size(value, 2), nnz(value));
else
    text = class(value);
end
end

function text = joinOrDash(items)
if isempty(items)
    text = '—';
else
    text = strjoin(items, '; ');
end
end
