function rebuildWithBondTransitions(checkpointFile, rxnDir, outFile)
% Rebuild the atom and bond transition multigraph of a pipeline checkpoint, keeping dBTM
% (tasks.md T002, research R8). The checkpoint's build saved runModel, dATM and BG but not
% dBTM, which the paper's reacting-bond incidence needs.
%
% USAGE:
%    rebuildWithBondTransitions(checkpointFile, rxnDir, outFile)
%
% INPUTS:
%    checkpointFile:    a checkpoint_build.mat (runModel, dATM, BG), read only
%    rxnDir:            the RXN folder the checkpoint was built from
%    outFile:           -v7.3 .mat written with runModel, dATM, BG, dBTM, buildSeconds,
%                       peakRssKiB and equalToCheckpoint
%
% The build uses the pipeline's options (directed = 0, sanityChecks = 0). The rebuilt dATM
% and BG must be isequaln to the checkpoint's; if not, outFile is renamed to *.UNEQUAL.mat
% and an error is raised. dBTM is cleared before the checkpoint's dATM and BG are loaded,
% to keep the peak memory near that of the original build.
%
% .. Author: - Jack McGoldrick, 2026-11-06, feature 20261106-092213-paper-reacting-bond-incidence

load(checkpointFile, 'runModel');
buildOptions = struct('directed', 0, 'sanityChecks', 0);
tBuild = tic;
[dATM, ~, ~, ~, ~, ~, BG, dBTM] = buildAtomAndBondTransitionMultigraph(runModel, rxnDir, buildOptions);
buildSeconds = toc(tBuild);
peakRssKiB = vmhwm();
fprintf('REBUILD built in %.0f s; dBTM %d nodes, %d edges; VmHWM %d KiB\n', buildSeconds, ...
    numnodes(dBTM), numedges(dBTM), peakRssKiB);
equalToCheckpoint = false;
save(outFile, 'runModel', 'dATM', 'BG', 'dBTM', 'buildSeconds', 'peakRssKiB', 'equalToCheckpoint', '-v7.3');
clear dBTM

stored = load(checkpointFile, 'dATM', 'BG');
equalToCheckpoint = isequaln(stored.dATM, dATM) && isequaln(stored.BG, BG);
fprintf('REBUILD EQUAL %d\n', equalToCheckpoint);
if ~equalToCheckpoint
    movefile(outFile, strrep(outFile, '.mat', '.UNEQUAL.mat'));
    error('rebuildWithBondTransitions:unequal', ...
        'The rebuilt dATM (%d) or BG (%d) differs from %s.', isequaln(stored.dATM, dATM), ...
        isequaln(stored.BG, BG), checkpointFile);
end
peakRssKiB = vmhwm();
save(outFile, 'equalToCheckpoint', 'peakRssKiB', '-append');
fprintf('REBUILD saved %s; VmHWM %d KiB\n', outFile, peakRssKiB);
end

function kib = vmhwm()
% Peak resident set size of this process, from /proc/self/status (Linux)
txt = fileread('/proc/self/status');
tok = regexp(txt, 'VmHWM:\s*(\d+)', 'tokens', 'once');
kib = sscanf(tok{1}, '%d');
end
