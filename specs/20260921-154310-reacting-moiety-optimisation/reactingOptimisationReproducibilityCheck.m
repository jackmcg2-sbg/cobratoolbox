% reactingOptimisationReproducibilityCheck.m
%
% Non-CI reproducibility check for feature 20260921-154310-reacting-moiety-optimisation
% (Constitution Principle III's documented-reproducibility-check substitute; spec FR-002,
% FR-011, FR-012, SC-001, SC-004, SC-006; research.md R10; tasks.md T004). Structural
% template: specs/029-vectorize-atm-loops/vectorizationReproducibilityCheck.m.
%
% For every fixture and mode it calls identifyConservedReactingMoieties and either
% CAPTURES a golden snapshot (unmodified src/ only) or COMPARES against one:
%   - arm, moietyFormulae and every field of reacting, on value AND class, sparsity and
%     size, recursively (isequaln alone ignores class and sparsity; FR-008);
%   - or, when the call raises an error, the error identifier and message;
%   - the console text of the call (SC-006), recorded with diary (not evalc). Warning
%     backtrace lines ("> In ...") and "(line N)" references are removed before comparing,
%     because they carry source line numbers that legitimately move when src/ is edited;
%     the raw text is kept in the snapshot;
%   - default mode: median of 3 whole-function runs, before (snapshot) vs after (FR-012);
%   - bileacid, default mode: profiler line-time sums over the stage-09 and stage-14..17
%     blocks, found by searching the source for marker comments (reported, not gated).
%
% USAGE (headless, after initCobraToolbox and changeCobraSolver('gurobi', 'all', 0)):
%   setenv('CBT_RMO_FIXTURES', 'ci,tyr');     % optional subset; default: 7 subsystems + ci
%   setenv('CBT_RMO_SANITY', '1');            % optional: sanityChecks = 1 mode only
%   setenv('CBT_RMO_NO_TIMING_GATE', '1');    % optional: report SLOWER without failing
%   setenv('CBT_RMO_TIMING_ONLY', '1');       % optional: timing only (pufa, re-measures)
%   setenv('CBT_RMO_TIMING_RUNS', '1');       % optional: runs for CBT_RMO_TIMING_ONLY (default 3)
%   setenv('CBT_RMO_MODE', 'synthetic');      % optional: synthetic re-indexing section only
%   run('specs/20260921-154310-reacting-moiety-optimisation/reactingOptimisationReproducibilityCheck.m')
%
% Mode per fixture: CAPTURE if its snapshot is absent, otherwise COMPARE. Snapshots are
% never overwritten.

global CBT_MILP_SOLVER

thisDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(thisDir));
homeDir = getenv('HOME');

corpusDir = '/media/JACK/repos/ctf/rxns/atomMapped_std';
subModelMatPath = fullfile(homeDir, 'repos', 'ReconXKG-cidev', 'ReconXKGtoCobra', 'models', ...
    'subsystemSubModels', 'subsystemSubModels.mat');
ciRxnDir = fullfile(repoRoot, 'test', 'verifiedTests', 'analysis', 'testReactingMoieties', ...
    'data', 'rxnFiles');
externalDir = fullfile(homeDir, 'repos', 'reconXmoieties', 'experiments', 'moietySizing', ...
    'results', 'outputs', 'reactingOptimisation');
snapshotDir = fullfile(thisDir, 'snapshots');
resultsPath = fullfile(thisDir, 'reacting-optimisation-reproducibility-results.md');
icrmFile = fullfile(repoRoot, 'src', 'analysis', 'topology', 'reactingMoieties', ...
    'identifyConservedReactingMoieties.m');
snapshotSizeLimitBytes = 10 * 1024^2;
nTimingRuns = 3;

subsystemFixtures = {'nglycan', 'phe', 'andest', 'chol', 'urea', 'tyr', 'bileacid'};
allFixtures = [subsystemFixtures, {'ci', 'pufa'}];

if strcmp(getenv('CBT_RMO_MODE'), 'synthetic')
    runSyntheticReindexingSection(resultsPath, icrmFile, repoRoot);
    return
end

%% Environment
assert(exist('identifyConservedReactingMoieties', 'file') == 2, 'COBRA Toolbox not on path.')
if ~isfolder(snapshotDir)
    mkdir(snapshotDir);
end

timingOnly = strcmp(getenv('CBT_RMO_TIMING_ONLY'), '1');
sanityMode = strcmp(getenv('CBT_RMO_SANITY'), '1');
timingGateOn = ~strcmp(getenv('CBT_RMO_NO_TIMING_GATE'), '1');
fixtureList = [subsystemFixtures, {'ci'}];
if ~isempty(getenv('CBT_RMO_FIXTURES'))
    fixtureList = strtrim(strsplit(getenv('CBT_RMO_FIXTURES'), ','));
    assert(all(ismember(fixtureList, allFixtures)), 'Unknown fixture in CBT_RMO_FIXTURES.')
end
assert(timingOnly || ~any(strcmp(fixtureList, 'pufa')), ...
    'pufa has no golden snapshot; run it only with CBT_RMO_TIMING_ONLY=1.')
if timingOnly
    modeList = {'default'};
    if ~isempty(getenv('CBT_RMO_TIMING_RUNS'))
        nTimingRuns = str2double(getenv('CBT_RMO_TIMING_RUNS'));
    end
elseif sanityMode
    modeList = {'sanity'};
else
    modeList = {'default', 'conservedOnly'};
end

gitCommit = currentGitCommit(repoRoot);
subModels = [];
runTime = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd HH:mm'));
fid = fopen(resultsPath, 'a');
fprintf(fid, ['\n### Run %s UTC — fixtures: %s; modes: %s%s%s\n\n' ...
    '| Fixture | Mode | Run | Status | arm eq | moietyFormulae eq | reacting eq (differing fields) | console eq | median s before -> after (ratio) | targeted stages s before -> after | Solver | Corpus (.rxn) | Snapshot | Commit | Notes |\n' ...
    '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n'], ...
    runTime, strjoin(fixtureList, ','), strjoin(modeList, ','), ...
    ternary(timingOnly, ' (timing only)', ''), ternary(timingGateOn, '', ' (timing gate off)'));
fclose(fid);

anyFailure = false;
failureKinds = {};
for f = 1:numel(fixtureList)
    name = fixtureList{f};
    fprintf('\n=== fixture %s ===\n', name);
    try
        if strcmp(name, 'ci')
            model = buildCiFixtureModel();
            rxnDir = ciRxnDir;
            buildSanity = 1;
            provenance = rxnDirProvenance(ciRxnDir, 'Recon3D_301 r0317/ACONTm/r0426');
        else
            if isempty(subModels)
                assert(isfolder(corpusDir), 'Atom-mapped corpus not found: %s', corpusDir)
                assert(isfile(subModelMatPath), 'Subsystem submodels not found: %s', subModelMatPath)
                loaded = load(subModelMatPath, 'subModels');
                subModels = loaded.subModels;
            end
            model = subModels.(name);
            rxnDir = corpusDir;
            buildSanity = double(sanityMode);
            provenance = rxnDirProvenance(corpusDir, subModelMatPath);
        end
        [dATM, ~, ~, ~, ~, ~, BG] = buildAtomAndBondTransitionMultigraph(model, rxnDir, ...
            struct('directed', 0, 'sanityChecks', buildSanity));
    catch ME
        anyFailure = true;
        failureKinds{end + 1} = 'ERROR'; %#ok<SAGROW>
        appendRow(resultsPath, struct('fixture', name, 'mode', '-', 'run', 'build', ...
            'status', 'ERROR', 'notes', describeError(ME)), gitCommit);
        fprintf(2, '  build failed: %s\n', describeError(ME));
        continue
    end

    for m = 1:numel(modeList)
        mode = modeList{m};
        row = emptyRow(name, mode);
        row.corpus = sprintf('%d', provenance.nRxnFiles);
        row.solver = CBT_MILP_SOLVER;
        snapFile = fullfile(snapshotDir, sprintf('%s-%s-golden-snapshot.mat', name, mode));
        pointerFile = strrep(snapFile, '.mat', '.external.txt');
        haveSnapshot = isfile(snapFile) || isfile(pointerFile);
        options = modeOptions(mode);
        isGatedFixture = any(strcmp(name, subsystemFixtures));
        fprintf('--- %s / %s (%s) ---\n', name, mode, ...
            ternary(timingOnly, 'TIMING', ternary(haveSnapshot, 'COMPARE', 'CAPTURE')));
        try
            if timingOnly
                row.run = 'TIMING';
                rec = timeIdentification(model, BG, dATM, options, nTimingRuns);
                beforeMedian = NaN;
                if haveSnapshot
                    baseline = loadSnapshot(snapFile, pointerFile);
                    beforeMedian = baseline.wholeFunctionMedianSeconds;
                end
                row.timing = timingText(beforeMedian, rec.medianSeconds);
                row.status = timingStatus(beforeMedian, rec.medianSeconds, isGatedFixture, timingGateOn);
                row.notes = sprintf('runs: %s s', strjoin(compose('%.2f', rec.seconds), ', '));
            elseif ~haveSnapshot
                row.run = 'CAPTURE';
                srcStatus = system(sprintf('git -C "%s" diff --quiet develop -- src/', repoRoot));
                assert(srcStatus == 0, 'reactingOptimisationCheck:srcModified', ...
                    'Refusing to CAPTURE: src/ differs from develop.');
                rec = runIdentification(model, BG, dATM, options, mode, name, icrmFile, nTimingRuns);
                snapshot = rec;
                snapshot.fixtureName = name;
                snapshot.mode = mode;
                snapshot.options = options;
                snapshot.milpSolver = CBT_MILP_SOLVER;
                snapshot.corpusProvenance = provenance;
                snapshot.gitCommit = gitCommit;
                snapshot.capturedAt = char(datetime('now', 'TimeZone', 'UTC', ...
                    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
                snapshot.nReactions = numel(model.rxns);
                snapshot.nMetabolites = numel(model.mets);
                save(snapFile, '-struct', 'snapshot', '-v7');
                row.snapshot = placeSnapshot(snapFile, pointerFile, externalDir, snapshotSizeLimitBytes);
                row.status = ternary(strcmp(rec.outcome, 'ok'), 'CAPTURED', 'CAPTURED (error outcome)');
                row.timing = timingText(rec.wholeFunctionMedianSeconds, NaN);
                row.stages = stageText(rec.targetedStageSeconds, []);
                if strcmp(rec.outcome, 'error')
                    row.notes = sprintf('%s: %s (%s)', rec.errorIdentifier, rec.errorMessage, rec.errorTopFrame);
                end
            else
                row.run = 'COMPARE';
                [baseline, row.snapshot] = loadSnapshot(snapFile, pointerFile);
                rec = runIdentification(model, BG, dATM, options, mode, name, icrmFile, nTimingRuns);
                row = compareToSnapshot(row, baseline, rec, provenance, CBT_MILP_SOLVER, ...
                    isGatedFixture, timingGateOn);
            end
        catch ME
            row.status = 'ERROR';
            row.notes = describeError(ME);
            fprintf(2, '  %s\n', row.notes);
        end
        if ismember(row.status, {'DIFF', 'CLASS DIFF', 'CONSOLE DIFF', 'ERROR', 'SLOWER', ...
                'SOLVER MISMATCH', 'CORPUS CHANGED SINCE CAPTURE'})
            anyFailure = true;
            failureKinds{end + 1} = row.status; %#ok<SAGROW>
        end
        appendRow(resultsPath, row, gitCommit);
        fprintf('  status: %s\n', row.status);
    end
end

if anyFailure
    kinds = unique(failureKinds);
    if isequal(kinds, {'SOLVER MISMATCH'})
        error('reactingOptimisationCheck:solverMismatch', ...
            'The MILP solver differs from the one used at capture; re-run with it. See %s', resultsPath);
    end
    error('reactingOptimisationCheck:failure', ...
        'At least one fixture reported %s; see %s', strjoin(kinds, ', '), resultsPath);
end

%% ---------------------------------------------------------------------------
%% Local functions
%% ---------------------------------------------------------------------------

function model = buildCiFixtureModel()
% The CI fixture of testConservedReactingMoieties.m (self-contained, in-repo data).
global CBTDIR
fullModel = readCbModel(fullfile(CBTDIR, 'test', 'models', 'mat', 'Recon3D_301.mat'));
model = extractSubNetwork(fullModel, {'r0317'; 'ACONTm'; 'r0426'});
end

function options = modeOptions(mode)
switch mode
    case 'default'
        options = struct('directed', 0, 'sanityChecks', 0);
    case 'conservedOnly'
        options = struct('directed', 0, 'sanityChecks', 0, 'conservedMoietiesOnly', 1);
    case 'sanity'
        options = struct('directed', 0, 'sanityChecks', 1);
    otherwise
        error('reactingOptimisationCheck:unknownMode', 'Unknown mode %s.', mode);
end
end

function rec = runIdentification(model, BG, dATM, options, mode, name, icrmFile, nTimingRuns)
% Outcome + console text in one diary-recorded call, then timing and profiling.
rec = struct('outcome', '', 'arm', [], 'moietyFormulae', [], 'reacting', [], ...
    'errorIdentifier', '', 'errorMessage', '', 'errorTopFrame', '', 'consoleText', '', ...
    'wholeFunctionSeconds', [], 'wholeFunctionMedianSeconds', NaN, 'targetedStageSeconds', []);
diaryFile = [tempname '.txt'];
diary(diaryFile);
try
    [arm, moietyFormulae, reacting] = identifyConservedReactingMoieties(model, BG, dATM, options);
    diary off
    rec.outcome = 'ok';
    rec.arm = arm;
    rec.moietyFormulae = moietyFormulae;
    rec.reacting = reacting;
catch ME
    diary off
    rec.outcome = 'error';
    rec.errorIdentifier = ME.identifier;
    rec.errorMessage = ME.message;
    if isempty(ME.stack)
        rec.errorTopFrame = '';
    else
        rec.errorTopFrame = sprintf('%s:%d', ME.stack(1).name, ME.stack(1).line);
    end
    fprintf('  outcome: error %s\n', describeError(ME));
end
rec.consoleText = fileread(diaryFile);
delete(diaryFile);

if strcmp(rec.outcome, 'ok') && strcmp(mode, 'default')
    timing = timeIdentification(model, BG, dATM, options, nTimingRuns);
    rec.wholeFunctionSeconds = timing.seconds;
    rec.wholeFunctionMedianSeconds = timing.medianSeconds;
    fprintf('  median of %d runs: %.2f s\n', nTimingRuns, timing.medianSeconds);
    if strcmp(name, 'bileacid')
        rec.targetedStageSeconds = profileTargetedStages(model, BG, dATM, options, icrmFile);
    end
end
end

function timing = timeIdentification(model, BG, dATM, options, nRuns)
timing.seconds = zeros(1, nRuns);
for r = 1:nRuns
    tRun = tic;
    identifyConservedReactingMoieties(model, BG, dATM, options);
    timing.seconds(r) = toc(tRun);
end
timing.medianSeconds = median(timing.seconds);
end

function stageSeconds = profileTargetedStages(model, BG, dATM, options, icrmFile)
% Profiler line times (which include time spent in called functions) summed over the
% stage-09 and stage-14..17 blocks of identifyConservedReactingMoieties.m.
icrmLines = strtrim(splitlines(fileread(icrmFile)));
stage09Start = findMarker(icrmLines, '% STEP B1', 1);
stage09End = findMarker(icrmLines, '%map BIG to connected component', stage09Start) - 1;
stage14Start = findMarker(icrmLines, '%Reacting bond graph', stage09End);
stage14End = findMarker(icrmLines, '%% STEP 4', stage14Start) - 1;

profile clear
profile on
identifyConservedReactingMoieties(model, BG, dATM, options);
profile off
profileInfo = profile('info');
functionTable = profileInfo.FunctionTable;
isIcrm = strcmp({functionTable.FunctionName}, 'identifyConservedReactingMoieties');
assert(nnz(isIcrm) == 1, 'Expected one profiler entry for identifyConservedReactingMoieties.');
executedLines = functionTable(isIcrm).ExecutedLines;
lineNumbers = executedLines(:, 1);
lineSeconds = executedLines(:, 3);
stageSeconds = struct();
stageSeconds.stage09 = sum(lineSeconds(lineNumbers >= stage09Start & lineNumbers <= stage09End));
stageSeconds.stage14to17 = sum(lineSeconds(lineNumbers >= stage14Start & lineNumbers <= stage14End));
stageSeconds.wholeFunctionProfiled = functionTable(isIcrm).TotalTime;
stageSeconds.blockLines = [stage09Start stage09End; stage14Start stage14End];
fprintf('  profiled: stage09 %.2f s, stage14to17 %.2f s (lines %d-%d, %d-%d)\n', ...
    stageSeconds.stage09, stageSeconds.stage14to17, stage09Start, stage09End, stage14Start, stage14End);
profile clear
end

function lineNumber = findMarker(lines, prefix, fromLine)
hits = find(startsWith(lines, prefix));
hits = hits(hits >= fromLine);
assert(~isempty(hits), 'Marker "%s" not found after line %d.', prefix, fromLine);
lineNumber = hits(1);
end

function row = compareToSnapshot(row, baseline, rec, provenance, solverNow, isGatedFixture, timingGateOn)
row.timing = timingText(baseline.wholeFunctionMedianSeconds, rec.wholeFunctionMedianSeconds);
row.stages = stageText(baseline.targetedStageSeconds, rec.targetedStageSeconds);
notes = {};
if ~strcmp(baseline.milpSolver, solverNow)
    row.status = 'SOLVER MISMATCH';
    row.notes = sprintf('captured with %s, now %s: not a code comparison', baseline.milpSolver, solverNow);
    return
end
if baseline.corpusProvenance.nRxnFiles ~= provenance.nRxnFiles
    row.status = 'CORPUS CHANGED SINCE CAPTURE';
    row.notes = 'Not a code comparison: the reaction-file corpus changed.';
    return
end

status = 'EQUAL';
if ~strcmp(baseline.outcome, rec.outcome)
    status = 'DIFF';
    notes{end + 1} = sprintf('outcome %s -> %s', baseline.outcome, rec.outcome);
elseif strcmp(rec.outcome, 'error')
    sameError = strcmp(baseline.errorIdentifier, rec.errorIdentifier) && ...
        strcmp(baseline.errorMessage, rec.errorMessage);
    row.armEq = '-';
    row.formulaeEq = '-';
    row.reactingEq = ternary(sameError, 'same error', 'DIFFERENT ERROR');
    notes{end + 1} = sprintf('error outcome: %s', rec.errorIdentifier);
    if ~sameError
        status = 'DIFF';
        notes{end + 1} = sprintf('was %s: %s; now %s: %s', baseline.errorIdentifier, ...
            baseline.errorMessage, rec.errorIdentifier, rec.errorMessage);
    end
else
    [armSame, armPaths, armClass] = compareStrictly(baseline.arm, rec.arm, 'arm');
    [formulaeSame, formulaePaths, formulaeClass] = compareStrictly(baseline.moietyFormulae, ...
        rec.moietyFormulae, 'moietyFormulae');
    [reactingSame, reactingPaths, reactingClass] = compareStrictly(baseline.reacting, ...
        rec.reacting, 'reacting');
    row.armEq = yesNo(armSame);
    row.formulaeEq = yesNo(formulaeSame);
    row.reactingEq = ternary(reactingSame, 'yes', strjoin(reactingPaths(1:min(8, end)), '; '));
    allPaths = [armPaths, formulaePaths, reactingPaths];
    if ~(armSame && formulaeSame && reactingSame)
        if ~isempty(allPaths) && all([armClass, formulaeClass, reactingClass] | ...
                [armSame, formulaeSame, reactingSame])
            status = 'CLASS DIFF';
        else
            status = 'DIFF';
        end
        notes{end + 1} = ['differs: ' strjoin(allPaths(1:min(12, end)), '; ')];
    end
    % FR-008: CRB2R must stay a sparse double (default and sanity modes)
    if isfield(rec.reacting, 'CRB2R')
        crb2rOK = issparse(rec.reacting.CRB2R) && strcmp(class(rec.reacting.CRB2R), 'double');
        if ~crb2rOK
            status = 'CLASS DIFF';
            notes{end + 1} = 'reacting.CRB2R is not a sparse double';
        end
    end
end

consoleSame = strcmp(normaliseConsole(baseline.consoleText), normaliseConsole(rec.consoleText));
row.consoleEq = yesNo(consoleSame);
if ~consoleSame && strcmp(status, 'EQUAL')
    status = 'CONSOLE DIFF';
end

if strcmp(status, 'EQUAL') && ~isnan(rec.wholeFunctionMedianSeconds)
    timeStatus = timingStatus(baseline.wholeFunctionMedianSeconds, ...
        rec.wholeFunctionMedianSeconds, isGatedFixture, timingGateOn);
    if ~strcmp(timeStatus, 'EQUAL')
        status = timeStatus;
    end
end
if strcmp(status, 'SLOWER')
    notes{end + 1} = 're-measure before treating as failure (timing noise)';
end
row.status = status;
row.notes = strjoin(notes, ' / ');
end

function status = timingStatus(beforeSeconds, afterSeconds, isGatedFixture, timingGateOn)
if isnan(beforeSeconds) || isnan(afterSeconds)
    status = 'EQUAL';
elseif ~isGatedFixture
    status = 'TIMING (not gated)';
elseif afterSeconds <= beforeSeconds
    status = 'EQUAL';
elseif timingGateOn
    status = 'SLOWER';
else
    status = 'SLOWER (not gated)';
end
end

function text = normaliseConsole(text)
% Drop warning backtrace lines and "(line N)" references: they carry source line numbers.
lines = splitlines(text);
lines = lines(~startsWith(strtrim(lines), '> In ') & ~startsWith(strtrim(lines), '[> In '));
lines = regexprep(lines, '\(line \d+\)', '(line N)');
text = strjoin(lines, newline);
end

function [isSame, diffPaths, isClassOnly] = compareStrictly(a, b, path)
% Recursive comparison on class, sparsity, size and value (isequaln ignores the first two).
% isClassOnly is true when every difference found is a class/sparsity/size difference.
diffPaths = {};
classDiffs = 0;
[diffPaths, classDiffs] = compareNode(a, b, path, diffPaths, classDiffs);
isSame = isempty(diffPaths);
isClassOnly = ~isSame && classDiffs == numel(diffPaths);
end

function [diffPaths, classDiffs] = compareNode(a, b, path, diffPaths, classDiffs)
if ~strcmp(class(a), class(b)) || issparse(a) ~= issparse(b) || ~isequal(size(a), size(b))
    diffPaths{end + 1} = sprintf('%s [class/sparsity/size: %s%s %s vs %s%s %s]', path, ...
        class(a), ternary(issparse(a), ' sparse', ''), mat2str(size(a)), ...
        class(b), ternary(issparse(b), ' sparse', ''), mat2str(size(b)));
    classDiffs = classDiffs + 1;
    return
end
if isa(a, 'graph') || isa(a, 'digraph')
    [diffPaths, classDiffs] = compareNode(a.Nodes, b.Nodes, [path '.Nodes'], diffPaths, classDiffs);
    [diffPaths, classDiffs] = compareNode(a.Edges, b.Edges, [path '.Edges'], diffPaths, classDiffs);
elseif istable(a)
    if ~isequal(a.Properties.VariableNames, b.Properties.VariableNames)
        diffPaths{end + 1} = [path ' [variable names]'];
        return
    end
    for v = 1:width(a)
        name = a.Properties.VariableNames{v};
        [diffPaths, classDiffs] = compareNode(a.(name), b.(name), [path '.' name], diffPaths, classDiffs);
    end
elseif isstruct(a)
    if ~isequal(sort(fieldnames(a)), sort(fieldnames(b)))
        diffPaths{end + 1} = [path ' [field names]'];
        return
    end
    names = fieldnames(a);
    for k = 1:numel(a)
        for n = 1:numel(names)
            if numel(a) == 1
                childPath = [path '.' names{n}];
            else
                childPath = sprintf('%s(%d).%s', path, k, names{n});
            end
            [diffPaths, classDiffs] = compareNode(a(k).(names{n}), b(k).(names{n}), childPath, ...
                diffPaths, classDiffs);
        end
    end
elseif iscell(a)
    for k = 1:numel(a)
        [diffPaths, classDiffs] = compareNode(a{k}, b{k}, sprintf('%s{%d}', path, k), ...
            diffPaths, classDiffs);
    end
elseif ~isequaln(a, b)
    diffPaths{end + 1} = [path ' [values]'];
end
end

function prov = rxnDirProvenance(rxnDir, modelSource)
listing = dir(fullfile(rxnDir, '*.rxn'));
prov = struct('rxnDir', rxnDir, 'nRxnFiles', numel(listing), 'modelSource', modelSource);
if isfile(modelSource)
    info = dir(modelSource);
    prov.modelSourceDate = info.date;
end
end

function commit = currentGitCommit(repoRoot)
[status, out] = system(sprintf('git -C "%s" rev-parse HEAD', repoRoot));
if status ~= 0
    commit = 'UNKNOWN';
    return
end
commit = strtrim(out);
[~, dirty] = system(sprintf('git -C "%s" status --porcelain -- src', repoRoot));
if ~isempty(strtrim(dirty))
    commit = [commit '+src-uncommitted'];
end
end

function location = placeSnapshot(snapFile, pointerFile, externalDir, sizeLimitBytes)
% Keep small snapshots in the repo; move large ones out, leaving a pointer (029 R7).
info = dir(snapFile);
if info.bytes <= sizeLimitBytes
    location = sprintf('in repo (%.1f MB)', info.bytes / 1024^2);
    return
end
if ~isfolder(externalDir)
    mkdir(externalDir);
end
[~, base, ext] = fileparts(snapFile);
externalFile = fullfile(externalDir, [base ext]);
movefile(snapFile, externalFile);
hash = sha256OfFile(externalFile);
fid = fopen(pointerFile, 'w');
fprintf(fid, 'path: %s\nsha256: %s\nbytes: %d\n', externalFile, hash, info.bytes);
fclose(fid);
location = sprintf('external (%.1f MB, sha256 %s)', info.bytes / 1024^2, hash(1:12));
end

function [baseline, location] = loadSnapshot(snapFile, pointerFile)
if isfile(snapFile)
    baseline = load(snapFile);
    location = 'in repo';
    return
end
pointer = fileread(pointerFile);
externalFile = strtrim(regexp(pointer, '(?<=path: )[^\n]+', 'match', 'once'));
expectedHash = strtrim(regexp(pointer, '(?<=sha256: )[0-9a-f]+', 'match', 'once'));
assert(isfile(externalFile), 'External snapshot missing: %s', externalFile);
actualHash = sha256OfFile(externalFile);
assert(strcmp(actualHash, expectedHash), ...
    'External snapshot hash mismatch for %s (expected %s, got %s).', externalFile, expectedHash, actualHash);
baseline = load(externalFile);
location = sprintf('external (sha256 verified %s)', expectedHash(1:12));
end

function hash = sha256OfFile(filePath)
[status, out] = system(sprintf('sha256sum "%s"', filePath));
assert(status == 0, 'sha256sum failed for %s', filePath);
hash = strtok(strtrim(out));
end

function row = emptyRow(name, mode)
row = struct('fixture', name, 'mode', mode, 'run', '-', 'status', 'ERROR', 'armEq', '-', ...
    'formulaeEq', '-', 'reactingEq', '-', 'consoleEq', '-', 'timing', '-', 'stages', '-', ...
    'solver', '-', 'corpus', '-', 'snapshot', '-', 'notes', '');
end

function appendRow(resultsPath, row, gitCommit)
full = emptyRow(row.fixture, row.mode);
names = fieldnames(row);
for n = 1:numel(names)
    full.(names{n}) = row.(names{n});
end
fid = fopen(resultsPath, 'a');
fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n', ...
    full.fixture, full.mode, full.run, full.status, full.armEq, full.formulaeEq, ...
    strrep(full.reactingEq, '|', '/'), full.consoleEq, full.timing, full.stages, full.solver, ...
    full.corpus, full.snapshot, shortCommit(gitCommit), strrep(full.notes, '|', '/'));
fclose(fid);
end

function text = timingText(beforeSeconds, afterSeconds)
if isnan(afterSeconds)
    text = ternary(isnan(beforeSeconds), '-', sprintf('%.2f -> -', beforeSeconds));
elseif isnan(beforeSeconds)
    text = sprintf('- -> %.2f', afterSeconds);
else
    text = sprintf('%.2f -> %.2f (%.2fx)', beforeSeconds, afterSeconds, beforeSeconds / afterSeconds);
end
end

function text = stageText(before, after)
if isempty(before) && isempty(after)
    text = '-';
elseif isempty(after)
    text = sprintf('09: %.2f; 14-17: %.2f (profiled, relative)', before.stage09, before.stage14to17);
else
    text = sprintf('09: %.2f -> %.2f; 14-17: %.2f -> %.2f (profiled, relative)', before.stage09, ...
        after.stage09, before.stage14to17, after.stage14to17);
end
end

function text = shortCommit(gitCommit)
[hash, marker] = strtok(gitCommit, '+');
text = [hash(1:min(12, end)) marker];
end

function text = describeError(ME)
% Full ME information, including the failing frame (Constitution VII-C).
if isempty(ME.stack)
    text = sprintf('%s: %s', ME.identifier, ME.message);
else
    text = sprintf('%s: %s (%s:%d)', ME.identifier, ME.message, ME.stack(1).file, ME.stack(1).line);
end
end

function text = yesNo(flag)
text = ternary(flag, 'yes', 'NO');
end

function out = ternary(condition, a, b)
if condition
    out = a;
else
    out = b;
end
end

%% ---------------------------------------------------------------------------
%% Synthetic re-indexing section (tasks.md T022; research.md R4-R6, R8)
%% ---------------------------------------------------------------------------

function runSyntheticReindexingSection(resultsPath, icrmFile, repoRoot) %#ok<INUSD>
error('reactingOptimisationCheck:notImplemented', 'not yet implemented: T022');
end
