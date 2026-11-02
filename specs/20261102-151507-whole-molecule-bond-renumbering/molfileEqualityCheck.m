function report = molfileEqualityCheck(BG, rxnFileDir, rxns)
% Compare each metabolite's bonds in a bond graph with its reference molblock
% (feature 20261102-151507-whole-molecule-bond-renumbering, tasks.md T002; contract
% contracts/bond-graph-equals-molfiles.md). Non-CI: used by
% wholeMoleculeRenumberingCheck.m; the CI test inlines the same comparison.
%
% USAGE:
%
%    report = molfileEqualityCheck(BG, rxnFileDir, rxns)
%
% INPUTS:
%    BG:          bond graph from buildAtomAndBondTransitionMultigraph (nodes are atoms with
%                 `mets`, `AtomNumber`, `Element`; edges are bonds with `Weight` = bond order)
%    rxnFileDir:  folder of the RXN files
%    rxns:        reactions in the order the builder processed them (`model.rxns` of the
%                 atom-mapped reactions)
%
% OUTPUT:
%    report:      structure with fields
%
%                   * .nMets - metabolites with atoms in `BG` and a reference molblock
%                   * .corrupted - metabolites whose bond set differs from the reference
%                   * .nMisplaced - bonds in `BG` that are not in the reference
%                   * .selfLoops - metabolites with a bond from an atom to itself
%
% NOTE:
%    The reference molblock of a metabolite is instance 1 of its first RXN file in `rxns`
%    order, as the builder takes it. Bonds are compared as unordered atom-number pairs
%    with their order (`Weight` against the molblock's bond type).
%
% .. Author: - COBRA Toolbox, feature 20261102-151507-whole-molecule-bond-renumbering

reference = containers.Map('KeyType', 'char', 'ValueType', 'any');
for r = 1:numel(rxns)
    if ~isfile(fullfile(rxnFileDir, [rxns{r} '.rxn']))
        continue
    end
    [~, bonds] = readABRXNFile(rxns{r}, rxnFileDir);
    for met = unique(bonds.mets(bonds.instances == 1))'
        if ~isKey(reference, met{1})
            isMet = strcmp(bonds.mets, met{1}) & bonds.instances == 1;
            reference(met{1}) = sortrows([min(bonds.headAtoms(isMet), bonds.tailAtoms(isMet)), ...
                max(bonds.headAtoms(isMet), bonds.tailAtoms(isMet)), bonds.bTypes(isMet)]);
        end
    end
end

atomMet = cellstr(BG.Nodes.mets);
atomNumber = full(BG.Nodes.AtomNumber);
ends = BG.Edges.EndNodes;
weight = full(BG.Edges.Weight);
bondMet = atomMet(ends(:, 1));
report = struct('nMets', 0, 'corrupted', {{}}, 'nMisplaced', 0, 'selfLoops', {{}});
for met = unique(bondMet)'
    if ~isKey(reference, met{1})
        continue
    end
    report.nMets = report.nMets + 1;
    isMet = strcmp(bondMet, met{1});
    a = atomNumber(ends(isMet, 1));
    b = atomNumber(ends(isMet, 2));
    bgBonds = sortrows([min(a, b), max(a, b), weight(isMet)]);
    refBonds = reference(met{1});
    if any(a == b)
        report.selfLoops{end + 1} = met{1};
    end
    if ~isequal(bgBonds, refBonds)
        report.corrupted{end + 1} = met{1};
        report.nMisplaced = report.nMisplaced + nnz(~ismember(bgBonds(:, 1:2), refBonds(:, 1:2), 'rows'));
    end
end
end
