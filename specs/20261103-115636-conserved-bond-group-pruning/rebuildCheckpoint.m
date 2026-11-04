function rebuildCheckpoint(modelOrCheckpoint, rxnDir, outFile)
% Build a checkpoint with the fixed builder (feature 20261103-115636-conserved-bond-group-pruning,
% tasks.md T002). Non-CI.
%
% USAGE:
%
%    rebuildCheckpoint(modelOrCheckpoint, rxnDir, outFile)
%
% INPUTS:
%    modelOrCheckpoint:  a copy of a .mat file holding `runModel` (a pipeline checkpoint) or
%                        `model` (a pipeline `model_screened.mat`)
%    rxnDir:             folder of the RXN files
%    outFile:            new .mat file; receives `runModel`, `dATM` and `BG` (-v7.3)
%
% NOTE:
%    Builds `dATM` and `BG` with buildAtomAndBondTransitionMultigraph and the pipeline's
%    options (directed = 0, sanityChecks = 0), then compares every metabolite's bonds with its
%    molfile (molfileEqualityCheck of feature 20261102-151507-whole-molecule-bond-renumbering)
%    and stops if any is corrupted. Prints `RB` lines with the build time and the counts.
%
% .. Author: - COBRA Toolbox, feature 20261103-115636-conserved-bond-group-pruning

featureDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(featureDir));
rmDir = fullfile(repoRoot, 'src', 'analysis', 'topology', 'reactingMoieties');
addpath(rmDir, '-begin');
addpath(fullfile(repoRoot, 'specs', '20261102-151507-whole-molecule-bond-renumbering'));
assert(startsWith(which('buildAtomAndBondTransitionMultigraph'), rmDir), ...
    'buildAtomAndBondTransitionMultigraph does not resolve to %s.', rmDir);
assert(~isfile(outFile), '%s already exists.', outFile);

contents = whos('-file', modelOrCheckpoint);
if any(strcmp({contents.name}, 'runModel'))
    runModel = load(modelOrCheckpoint, 'runModel').runModel;
else
    runModel = load(modelOrCheckpoint, 'model').model;
end
fprintf('RB start %s, %d reactions\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    numel(runModel.rxns));
timer = tic;
[dATM, ~, rxnAtomMappedBool, ~, ~, ~, BG] = buildAtomAndBondTransitionMultigraph(runModel, ...
    rxnDir, struct('directed', 0, 'sanityChecks', 0));
fprintf('RB build %.0f s, %d of %d reactions atom-mapped\n', toc(timer), nnz(rxnAtomMappedBool), ...
    numel(runModel.rxns));
report = molfileEqualityCheck(BG, rxnDir, runModel.rxns(rxnAtomMappedBool));
fprintf('RB molfile: metabolites %d, corrupted %d, misplaced %d, self-loops %d\n', report.nMets, ...
    numel(report.corrupted), report.nMisplaced, numel(report.selfLoops));
assert(isempty(report.corrupted) && isempty(report.selfLoops), ...
    'The rebuilt bond graph differs from the molfiles for %d metabolites.', numel(report.corrupted));
outDir = fileparts(outFile);
if ~isfolder(outDir)
    mkdir(outDir);
end
save(outFile, 'runModel', 'dATM', 'BG', '-v7.3');
fprintf('RB saved %s\n', outFile);
end
