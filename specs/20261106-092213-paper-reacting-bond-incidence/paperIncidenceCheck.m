function paperIncidenceCheck(action, varargin)
% Non-CI check of the paper's reacting-bond incidence on the full collapsed VMH network
% (feature 20261106-092213-paper-reacting-bond-incidence, tasks.md T022-T024). Run through
% paperIncidenceCheck.sh, which puts each action in its own memory-capped scope.
%
% USAGE:
%    paperIncidenceCheck('identify', inFile, rule, outDir)
%    paperIncidenceCheck('compare', referenceReactingFile, referenceConservedFile, runDir)
%    paperIncidenceCheck('report', referenceReactingFile, endAtomDir, bondChangeDir, resultsFile)
%
% identify:  full-mode identification from inFile (rebuildWithBondTransitions output) under
%            options.reactingBondIncidence = rule, with the pipeline's options
%            (computeMoietyGraphs = 1, sanityChecks = 0). dBTM is loaded and passed only
%            under 'bondChange'. Saves outDir/reacting.mat (reacting, identifySeconds,
%            peakRssKiB) and outDir/conserved.mat (L, M2M, M2R, moietyFormulae). Under
%            'bondChange' it also saves outDir/bondChangeCheck.mat: the sets recomputed
%            independently of CRB2R from the bond changes' atom-transition component pairs
%            (as the test's expectedCondensedSets), the entries from each condensed edge's
%            first bond alone, and a sample of the bond changes on no condensed edge.
% compare:   every reacting field of runDir against referenceReactingFile (the two fields new
%            in this feature left out), and L and moietyFormulae against
%            referenceConservedFile. Prints 'PI ALL EQUAL 1' or 'PI ALL EQUAL 0'.
% report:    the US3 metrics, appended to resultsFile.
%
% .. Author: - Jack McGoldrick, 2026-11-06, feature 20261106-092213-paper-reacting-bond-incidence

switch action
    case 'identify'
        identify(varargin{:});
    case 'compare'
        compare(varargin{:});
    case 'report'
        report(varargin{:});
    otherwise
        error('paperIncidenceCheck:action', 'Unknown action %s.', action);
end
end

function identify(inFile, rule, outDir)
if ~isfolder(outDir)
    mkdir(outDir);
end
load(inFile, 'runModel', 'dATM', 'BG');
options = struct('conservedMoietiesOnly', false, 'computeMoietyGraphs', true, ...
    'sanityChecks', 0, 'reactingBondIncidence', rule);
if strcmp(rule, 'bondChange')
    load(inFile, 'dBTM');
else
    dBTM = [];
end
fprintf('PI identify %s: %d reactions, %d metabolites; VmHWM %d KiB after loading\n', rule, ...
    numel(runModel.rxns), numel(runModel.mets), vmhwm());
tIdentify = tic;
[arm, moietyFormulae, reacting] = identifyConservedReactingMoieties(runModel, BG, dATM, options, dBTM);
identifySeconds = toc(tIdentify);
peakRssKiB = vmhwm();
fprintf('PI identify %s: %.0f s, VmHWM %d KiB; %d condensed reacting bonds, %d nonzeros, %d selected\n', ...
    rule, identifySeconds, peakRssKiB, size(reacting.CRB2R, 1), nnz(reacting.CRB2R), ...
    numel(reacting.selectedReactions));
save(fullfile(outDir, 'reacting.mat'), 'reacting', 'options', 'identifySeconds', 'peakRssKiB', '-v7.3');
L = arm.L; M2M = arm.M2M; M2R = arm.M2R; %#ok<NASGU>
save(fullfile(outDir, 'conserved.mat'), 'L', 'M2M', 'M2R', 'moietyFormulae', '-v7.3');
if strcmp(rule, 'bondChange')
    bondChangeCheck(runModel, dBTM, arm, reacting, outDir);
end
end

function bondChangeCheck(model, dBTM, arm, reacting, outDir)
% The expected sets from the bond changes' component pairs, without CRB2R; the entries from
% each condensed edge's first bond alone; the bond changes on no condensed edge
broken = ismember(dBTM.Edges.TailMet, model.rxns);
formed = ismember(dBTM.Edges.HeadMet, model.rxns);
changedBond = full([dBTM.Edges.HeadBondIndex(broken); dBTM.Edges.TailBondIndex(formed)]);
[~, changedCol] = ismember([dBTM.Edges.rxns(broken); dBTM.Edges.rxns(formed)], model.rxns);
assert(all(changedBond >= 1 & changedBond <= height(dBTM.Nodes)), 'A bond change has no bond node.');
atomIndex = full(arm.ATG.Nodes.AtomIndex);
component = zeros(max(atomIndex), 1);
component(atomIndex) = full(arm.ATG.Nodes.Component);
headAtom = full(dBTM.Nodes.BondHeadAtomIndex);
tailAtom = full(dBTM.Nodes.BondTailAtomIndex);
pairOf = @(b) sort([component(headAtom(b(:))), component(tailAtom(b(:)))], 2);
edgeBond = full(reacting.Condensed_RBG.Edges.BondIndex);
edgePairs = pairOf(edgeBond);
nCRB = numel(edgeBond);
nRxns = numel(model.rxns);
uniquePairs = size(unique(edgePairs, 'rows'), 1) == nCRB;
[~, changedRow] = ismember(pairOf(changedBond), edgePairs, 'rows');
onGraph = changedRow > 0 & changedCol > 0;
expectedCRB2R = spones(sparse(changedRow(onGraph), changedCol(onGraph), 1, nCRB, nRxns));
isFirstBond = onGraph;
isFirstBond(onGraph) = changedBond(onGraph) == edgeBond(changedRow(onGraph));
firstBondCRB2R = spones(sparse(changedRow(isFirstBond), changedCol(isFirstBond), 1, nCRB, nRxns));
offIdx = find(~onGraph);
offSample = table(changedBond(offIdx(1:min(20, end))), ...
    model.rxns(max(changedCol(offIdx(1:min(20, end))), 1)), 'VariableNames', {'BondIndex', 'rxn'});
offSample.Bond = dBTM.Nodes.Bond(offSample.BondIndex);
expectedOffGraph = numel(offIdx);
equalToExpected = isequal(spones(reacting.CRB2R), expectedCRB2R);
fprintf('PI bondChangeCheck: pairs unique %d; CRB2R equals the component-pair sets %d; off-graph %d (function %d)\n', ...
    uniquePairs, equalToExpected, expectedOffGraph, reacting.offGraphBondChanges);
save(fullfile(outDir, 'bondChangeCheck.mat'), 'expectedCRB2R', 'firstBondCRB2R', 'offSample', ...
    'expectedOffGraph', 'equalToExpected', 'uniquePairs', '-v7.3');
end

function compare(referenceReactingFile, referenceConservedFile, runDir)
reference = load(referenceReactingFile, 'reacting');
new = load(fullfile(runDir, 'reacting.mat'), 'reacting');
% the two fields new in this feature are left out of both sides (the baseline predates them)
newFields = {'unchangedReactingBonds', 'offGraphBondChanges'};
newReacting = rmfield(new.reacting, intersect(newFields, fieldnames(new.reacting)));
referenceReacting = rmfield(reference.reacting, intersect(newFields, fieldnames(reference.reacting)));
allEqual = isequal(sort(fieldnames(newReacting)), sort(fieldnames(referenceReacting)));
fprintf('PI reacting fields equal %d\n', allEqual);
for f = fieldnames(referenceReacting)'
    same = isfield(newReacting, f{1}) && isequaln(newReacting.(f{1}), referenceReacting.(f{1}));
    fprintf('PI reacting.%s equal %d\n', f{1}, same);
    allEqual = allEqual && same;
end
clear reference new newReacting referenceReacting
referenceConserved = load(referenceConservedFile, 'L', 'moietyFormulae');
newConserved = load(fullfile(runDir, 'conserved.mat'), 'L', 'moietyFormulae');
for f = {'L', 'moietyFormulae'}
    same = isequaln(newConserved.(f{1}), referenceConserved.(f{1}));
    fprintf('PI %s equal %d\n', f{1}, same);
    allEqual = allEqual && same;
end
fprintf('PI ALL EQUAL %d\n', allEqual);
end

function report(referenceReactingFile, endAtomDir, bondChangeDir, resultsFile)
old = load(referenceReactingFile, 'reacting');
endAtom = load(fullfile(endAtomDir, 'reacting.mat'));
new = load(fullfile(bondChangeDir, 'reacting.mat'));
check = load(fullfile(bondChangeDir, 'bondChangeCheck.mat'));
endAtomConserved = load(fullfile(endAtomDir, 'conserved.mat'));
newConserved = load(fullfile(bondChangeDir, 'conserved.mat'));
oldCRB2R = spones(old.reacting.CRB2R);
newCRB2R = spones(new.reacting.CRB2R);
assert(isequal(size(oldCRB2R), size(newCRB2R)), 'CRB2R sizes differ.');
perBond = @(M) full(sum(M, 2));
oldPerBond = perBond(oldCRB2R);
newPerBond = perBond(newCRB2R);
outside = newCRB2R & ~oldCRB2R;
unionOnly = outside & ~check.firstBondCRB2R;
others = outside & check.firstBondCRB2R;
conservedSame = isequaln(newConserved.L, endAtomConserved.L) && ...
    isequaln(newConserved.M2M, endAtomConserved.M2M) && isequaln(newConserved.M2R, endAtomConserved.M2R) && ...
    isequaln(newConserved.moietyFormulae, endAtomConserved.moietyFormulae);
lines = {'', '## Full collapsed VMH network (T024)', '', ...
    sprintf('Run %s. Old: `''endAtom''` (equal to the 2026-11-05 baseline, T023). New: `''bondChange''`.', ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'))), '', ...
    '| Metric | Old (`endAtom`) | New (`bondChange`) |', '|---|---|---|', ...
    sprintf('| Condensed reacting bonds | %d | %d |', size(oldCRB2R, 1), size(newCRB2R, 1)), ...
    sprintf('| `CRB2R` nonzeros | %d | %d |', nnz(oldCRB2R), nnz(newCRB2R)), ...
    sprintf('| Reactions per bond, largest | %d | %d |', max(oldPerBond), max(newPerBond)), ...
    sprintf('| Reactions per bond, median over all bonds | %g | %g |', median(oldPerBond), median(newPerBond)), ...
    sprintf('| Reactions per bond, median over bonds with any | %g | %g |', ...
        median(oldPerBond(oldPerBond > 0)), median(newPerBond(newPerBond > 0))), ...
    sprintf('| `unchangedReactingBonds` | %d | %d |', nnz(endAtom.reacting.unchangedReactingBonds), ...
        nnz(new.reacting.unchangedReactingBonds)), ...
    sprintf('| `offGraphBondChanges` | %d | %d |', endAtom.reacting.offGraphBondChanges, ...
        new.reacting.offGraphBondChanges), ...
    sprintf('| Cover size (selected reactions) | %d | %d |', numel(old.reacting.selectedReactions), ...
        numel(new.reacting.selectedReactions)), ...
    sprintf('| Identification time (s) | %.0f | %.0f |', endAtom.identifySeconds, new.identifySeconds), ...
    sprintf('| Peak RSS of identification (GiB) | %.1f | %.1f |', endAtom.peakRssKiB / 2^20, new.peakRssKiB / 2^20), ...
    '', ...
    sprintf(['- **Subset test**: %d new entries are not old entries; %d of them are union-only (the ' ...
    'reaction changes a merged bond other than the condensed edge''s first bond), %d others (must be 0).'], ...
    nnz(outside), nnz(unionOnly), nnz(others)), ...
    sprintf('- **Old entries dropped**: %d.', nnz(oldCRB2R & ~newCRB2R)), ...
    sprintf(['- **Independent check**: `CRB2R` equals the sets recomputed from the bond changes'' ' ...
    'component pairs: %d (pairs unique: %d; off-graph by pairs %d).'], check.equalToExpected, ...
    check.uniquePairs, check.expectedOffGraph), ...
    sprintf('- **Conserved outputs** (`L`, `M2M`, `M2R`, `moietyFormulae`) identical under both rules: %d.', conservedSame)};
if new.reacting.offGraphBondChanges > 0
    lines{end + 1} = '- **Sample of off-graph bond changes** (BondIndex, reaction, bond):';
    for k = 1:height(check.offSample)
        lines{end + 1} = sprintf('  - %d, `%s`, `%s`', check.offSample.BondIndex(k), ...
            check.offSample.rxn{k}, check.offSample.Bond{k}); %#ok<AGROW>
    end
end
fid = fopen(resultsFile, 'a');
fprintf(fid, '%s\n', lines{:});
fclose(fid);
fprintf('PI report: others %d, conserved same %d, independent check %d\n', nnz(others), conservedSame, ...
    check.equalToExpected);
end

function kib = vmhwm()
% Peak resident set size of this process, from /proc/self/status (Linux)
txt = fileread('/proc/self/status');
tok = regexp(txt, 'VmHWM:\s*(\d+)', 'tokens', 'once');
kib = sscanf(tok{1}, '%d');
end
