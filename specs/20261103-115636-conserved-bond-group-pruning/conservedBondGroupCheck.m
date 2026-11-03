function conservedBondGroupCheck(action, varargin)
% Non-CI check of feature 20261103-115636-conserved-bond-group-pruning (tasks.md T004-T007,
% T017-T019; spec FR-006, SC-002-SC-005), adapted from reactingMoietyMemoryCheck.m of feature
% 20261102-092909-reacting-moiety-memory. Called by conservedBondGroupCheck.sh, which runs
% each call in its own memory-capped MATLAB scope.
%
% USAGE:
%
%    conservedBondGroupCheck('identify', rmDir, checkpointFile, outDir, saveOutputs)
%    conservedBondGroupCheck('identify', rmDir, checkpointFile, outDir, saveOutputs, probeDir)
%    conservedBondGroupCheck('compare', referenceDir, newDir)
%    conservedBondGroupCheck('conserved', rmDir, checkpointFile, outDir)
%    conservedBondGroupCheck('compareConserved', conservedDir, fullDir)
%
% INPUTS:
%    action:          'identify' runs identifyConservedReactingMoieties in full mode
%                     (conservedMoietiesOnly = false, computeMoietyGraphs = true,
%                     sanityChecks = 0) from a copied checkpoint, with rmDir first on the
%                     path, and writes `metrics.txt` (identification seconds and peak
%                     resident memory of this MATLAB process inside the identification
%                     window, in kB) and, if saveOutputs, `outputs.mat` (arm,
%                     moietyFormulae, reacting) to outDir.
%                     'compare' compares the outputs.mat of two identify runs field by field
%                     with isequaln, applies four planted differences that must be detected,
%                     and prints `RM ALL EQUAL 1` only if every field is equal and every
%                     planted difference is detected.
%                     'conserved' runs identifyConservedReactingMoieties in conserved-only
%                     mode (conservedMoietiesOnly = true, computeMoietyGraphs = false) and saves
%                     `conserved.mat` (arm.L, arm.M2M, arm.M2R, moietyFormulae).
%                     'compareConserved' compares those four with the same fields of a full-mode
%                     run's outputs.mat, and prints `CB CONSERVED EQUAL 1` only if all are
%                     equal and a planted difference is detected.
%    rmDir:           reactingMoieties folder under test (base copy or this repository's)
%    probeDir:        optional; a folder holding an instrumented copy of
%                     identifyConservedReactingMoieties.m (rmProbe calls), put before rmDir
%    checkpointFile:  a copy of a checkpoint_build.mat holding runModel, BG and dATM (never
%                     the memory scan's own file)
%    outDir:          new folder for the run's outputs
%    saveOutputs:     logical; false for the memory runs, whose peak is then not raised by
%                     the save (the peak is read before the save in either case)

switch action
    case 'identify'
        [rmDir, checkpointFile, outDir, saveOutputs] = varargin{1:4};
        probeDir = '';
        if numel(varargin) >= 5
            probeDir = varargin{5};
        end
        identifyFromCheckpoint(rmDir, checkpointFile, outDir, saveOutputs, probeDir);
    case 'compare'
        [referenceDir, newDir] = varargin{:};
        compareOutputs(referenceDir, newDir);
    case 'conserved'
        [rmDir, checkpointFile, outDir] = varargin{:};
        conservedFromCheckpoint(rmDir, checkpointFile, outDir);
    case 'compareConserved'
        [conservedDir, fullDir] = varargin{:};
        compareConserved(conservedDir, fullDir);
    otherwise
        error('conservedBondGroupCheck:unknownAction', 'Unknown action %s.', action);
end
end

function identifyFromCheckpoint(rmDir, checkpointFile, outDir, saveOutputs, probeDir)
initCobraToolbox(false);
addpath(rmDir, '-begin');
expectedDir = rmDir;
if ~isempty(probeDir)
    addpath(probeDir, '-begin');
    expectedDir = probeDir;
end
functionFile = which('identifyConservedReactingMoieties');
fprintf('RM which identifyConservedReactingMoieties = %s\n', functionFile);
assert(startsWith(functionFile, expectedDir), ...
    'identifyConservedReactingMoieties does not resolve to %s.', expectedDir);
assert(startsWith(which('extractBondSubgraphs'), rmDir), ...
    'extractBondSubgraphs does not resolve to %s.', rmDir);
assert(changeCobraSolver('gurobi', 'MILP', 0) == 1, 'The gurobi MILP solver is not available.');
if ~isfolder(outDir)
    mkdir(outDir);
end
checkpoint = load(checkpointFile, 'runModel', 'dATM', 'BG');
options = struct('conservedMoietiesOnly', false, 'computeMoietyGraphs', true, 'sanityChecks', 0);

% the peak resident memory of this process is reset just before identification and read
% just after it, so it covers the identification window only
processId = feature('getpid');
resetPeakResidentMemory(processId);
fprintf('RM identify start %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
timer = tic;
[arm, moietyFormulae, reacting] = identifyConservedReactingMoieties(checkpoint.runModel, ...
    checkpoint.BG, checkpoint.dATM, options);
identifySeconds = toc(timer);
peakResidentKB = readPeakResidentMemory(processId);
fprintf('RM identify end %s (%.1f s, peak RSS %d kB)\n', ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), identifySeconds, peakResidentKB);
metricsFile = fopen(fullfile(outDir, 'metrics.txt'), 'w');
fprintf(metricsFile, 'identifySeconds %.3f\npeakResidentKB %d\nfunctionFile %s\n', ...
    identifySeconds, peakResidentKB, functionFile);
fclose(metricsFile);
if saveOutputs
    save(fullfile(outDir, 'outputs.mat'), 'arm', 'moietyFormulae', 'reacting', '-v7.3');
end
end

function resetPeakResidentMemory(processId)
% write 5 to clear_refs: the kernel resets VmHWM to the current resident size
fileId = fopen(sprintf('/proc/%d/clear_refs', processId), 'w');
assert(fileId > 0, 'Cannot reset the peak resident memory of process %d.', processId);
fprintf(fileId, '5');
fclose(fileId);
end

function peakResidentKB = readPeakResidentMemory(processId)
status = fileread(sprintf('/proc/%d/status', processId));
peakResidentKB = str2double(regexp(status, 'VmHWM:\s*(\d+)', 'tokens', 'once'));
end

function compareOutputs(referenceDir, newDir)
reference = load(fullfile(referenceDir, 'outputs.mat'), 'arm', 'moietyFormulae', 'reacting');
candidate = load(fullfile(newDir, 'outputs.mat'), 'arm', 'moietyFormulae', 'reacting');
allEqual = true;
names = {'arm', 'reacting'};
for n = 1:numel(names)
    referenceFields = fieldnames(reference.(names{n}));
    isEqual = isequal(referenceFields, fieldnames(candidate.(names{n})));
    fprintf('RM %-40s %d\n', [names{n} ' field names'], isEqual);
    allEqual = allEqual && isEqual;
    for k = 1:numel(referenceFields)
        isEqual = isfield(candidate.(names{n}), referenceFields{k}) && ...
            isequaln(reference.(names{n}).(referenceFields{k}), ...
            candidate.(names{n}).(referenceFields{k}));
        fprintf('RM %-40s %d\n', [names{n} '.' referenceFields{k}], isEqual);
        allEqual = allEqual && isEqual;
    end
end
isEqual = isequaln(reference.moietyFormulae, candidate.moietyFormulae);
fprintf('RM %-40s %d\n', 'moietyFormulae', isEqual);
allEqual = allEqual && isEqual;

% planted differences: each must be detected, or the comparison above proves nothing
arm = reference.arm;
detected = true(4, 1);
graphs = arm.MG;
graphs{1} = addnode(graphs{1}, 1);
detected(1) = ~isequaln(graphs, arm.MG);
graphs = arm.MG;
graphIndex = find(cellfun(@numnodes, graphs) > 0, 1);
nodes = graphs{graphIndex}.Nodes;
numericVariables = nodes.Properties.VariableNames(varfun(@isnumeric, nodes, 'OutputFormat', 'uniform'));
nodes.(numericVariables{1})(1) = nodes.(numericVariables{1})(1) + 1;
graphs{graphIndex} = feval(class(graphs{graphIndex}), graphs{graphIndex}.Edges, nodes);
detected(2) = ~isequaln(graphs, arm.MG);
L = arm.L;
[rowIndex, columnIndex] = find(L, 1);
L(rowIndex, columnIndex) = L(rowIndex, columnIndex) + 1;
detected(3) = ~isequaln(L, arm.L);
reactingGraphs = reference.reacting.ReactMoietyGraphs;
reactingGraphs{end} = addedge(reactingGraphs{end}, 1, 1);
detected(4) = ~isequaln(reactingGraphs, reference.reacting.ReactMoietyGraphs);
controlNames = {'MG node added', 'MG numeric node value', 'L entry', 'reacting graph edge'};
for k = 1:4
    fprintf('RM planted difference (%s) detected: %d\n', controlNames{k}, detected(k));
end
fprintf('RM ALL EQUAL %d\n', allEqual && all(detected));
end

function conservedFromCheckpoint(rmDir, checkpointFile, outDir)
initCobraToolbox(false);
addpath(rmDir, '-begin');
assert(startsWith(which('identifyConservedReactingMoieties'), rmDir), ...
    'identifyConservedReactingMoieties does not resolve to %s.', rmDir);
if ~isfolder(outDir)
    mkdir(outDir);
end
checkpoint = load(checkpointFile, 'runModel', 'dATM', 'BG');
options = struct('conservedMoietiesOnly', true, 'computeMoietyGraphs', false, 'sanityChecks', 0);
timer = tic;
[arm, moietyFormulae] = identifyConservedReactingMoieties(checkpoint.runModel, checkpoint.BG, ...
    checkpoint.dATM, options);
fprintf('CB conserved-only identification %.1f s, %d conserved moieties\n', toc(timer), size(arm.L, 1));
L = arm.L; M2M = arm.M2M; M2R = arm.M2R; %#ok<NASGU>
save(fullfile(outDir, 'conserved.mat'), 'L', 'M2M', 'M2R', 'moietyFormulae', '-v7.3');
end

function compareConserved(conservedDir, fullDir)
reference = load(fullfile(conservedDir, 'conserved.mat'));
candidate = load(fullfile(fullDir, 'outputs.mat'), 'arm', 'moietyFormulae');
allEqual = true;
for name = {'L', 'M2M', 'M2R'}
    isEqual = isequaln(reference.(name{1}), candidate.arm.(name{1}));
    fprintf('CB %-20s %d\n', name{1}, isEqual);
    allEqual = allEqual && isEqual;
end
isEqual = isequaln(reference.moietyFormulae, candidate.moietyFormulae);
fprintf('CB %-20s %d\n', 'moietyFormulae', isEqual);
allEqual = allEqual && isEqual;
planted = reference.L;
[rowIndex, columnIndex] = find(planted, 1);
planted(rowIndex, columnIndex) = planted(rowIndex, columnIndex) + 1;
detected = ~isequaln(planted, candidate.arm.L);
fprintf('CB planted difference (L entry) detected: %d\n', detected);
fprintf('CB CONSERVED EQUAL %d\n', allEqual && detected);
end
