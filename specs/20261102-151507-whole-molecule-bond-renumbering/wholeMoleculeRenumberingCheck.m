function wholeMoleculeRenumberingCheck(modelFile, rxnFileDir, outDir)
% Non-CI check of feature 20261102-151507-whole-molecule-bond-renumbering (tasks.md T015;
% spec FR-009, SC-002, SC-006): build the atom and bond transition multigraph of a whole
% network with the builder on the path, time the build, and count the metabolites whose
% bond-graph bonds differ from their reference molblock (molfileEqualityCheck).
%
% USAGE:
%
%    wholeMoleculeRenumberingCheck(modelFile, rxnFileDir, outDir)
%
% INPUTS:
%    modelFile:   .mat file holding one model structure (a copy, e.g. the collapsed VMH
%                 network's model_screened.mat)
%    rxnFileDir:  folder of the network's RXN files
%    outDir:      folder for summary.txt and the report
%
% .. Author: - COBRA Toolbox, feature 20261102-151507-whole-molecule-bond-renumbering
featureDir = fileparts(mfilename('fullpath'));
addpath(featureDir);
fprintf('WM which %s\n', which('buildAtomAndBondTransitionMultigraph'));
loaded = load(modelFile);
names = fieldnames(loaded);
model = loaded.(names{1});
if ~isfolder(outDir)
    mkdir(outDir);
end
fprintf('WM build start %s, %d reactions\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), numel(model.rxns));
timer = tic;
[~, ~, ~, ~, ~, ~, BG] = buildAtomAndBondTransitionMultigraph(model, rxnFileDir, ...
    struct('directed', 0, 'sanityChecks', 0));
buildSeconds = toc(timer);
fprintf('WM build end %s (%.0f s)\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), buildSeconds);
report = molfileEqualityCheck(BG, rxnFileDir, model.rxns);
fprintf('WM metabolites %d, corrupted %d, misplaced bonds %d, self-loops %d\n', report.nMets, ...
    numel(report.corrupted), report.nMisplaced, numel(report.selfLoops));
if ~isempty(report.corrupted)
    fprintf('WM corrupted, first 20: %s\n', strjoin(report.corrupted(1:min(20, end)), ' '));
end
fid = fopen(fullfile(outDir, 'summary.txt'), 'w');
fprintf(fid, 'buildSeconds %.0f\nnMets %d\ncorrupted %d\nmisplaced %d\nselfLoops %d\n', buildSeconds, ...
    report.nMets, numel(report.corrupted), report.nMisplaced, numel(report.selfLoops));
fclose(fid);
save(fullfile(outDir, 'report.mat'), 'report', 'buildSeconds');
end
