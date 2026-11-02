function reactingMoietyMemoryCheck(action, varargin)
% Non-CI check of feature 20261102-092909-reacting-moiety-memory (tasks.md T010, T017, T018;
% spec FR-008, SC-002, SC-003, SC-004). Called by reactingMoietyMemoryCheck.sh, which runs
% each call in its own memory-capped MATLAB scope.
%
% USAGE:
%
%    reactingMoietyMemoryCheck('identify', rmDir, checkpointFile, outDir, saveOutputs)
%    reactingMoietyMemoryCheck('compare', referenceDir, newDir)
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
%    rmDir:           reactingMoieties folder under test (base copy or this repository's)
%    checkpointFile:  a copy of a checkpoint_build.mat holding runModel, BG and dATM (never
%                     the memory scan's own file)
%    outDir:          new folder for the run's outputs
%    saveOutputs:     logical; false for the memory runs, whose peak is then not raised by
%                     the save (the peak is read before the save in either case)

switch action
    case 'identify'
        [rmDir, checkpointFile, outDir, saveOutputs] = varargin{:};
        identifyFromCheckpoint(rmDir, checkpointFile, outDir, saveOutputs);
    case 'compare'
        [referenceDir, newDir] = varargin{:};
        compareOutputs(referenceDir, newDir);
    otherwise
        error('reactingMoietyMemoryCheck:unknownAction', 'Unknown action %s.', action);
end
end

function identifyFromCheckpoint(rmDir, checkpointFile, outDir, saveOutputs)
initCobraToolbox(false);
addpath(rmDir, '-begin');
functionFile = which('identifyConservedReactingMoieties');
fprintf('RM which identifyConservedReactingMoieties = %s\n', functionFile);
assert(startsWith(functionFile, rmDir), ...
    'identifyConservedReactingMoieties does not resolve to %s.', rmDir);
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
