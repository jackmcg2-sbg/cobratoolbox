function [conservedGroup, reactingGroups, diagnostics] = findConservedBondGroup(subgraphSizes, buildSubgraphs)
% Find the conserved group of bond subgraphs, classifying and building only the size groups that can hold it
%
% USAGE:
%
%    [conservedGroup, reactingGroups] = findConservedBondGroup(subgraphSizes, buildSubgraphs)
%    [conservedGroup, reactingGroups, diagnostics] = findConservedBondGroup(subgraphSizes, buildSubgraphs)
%
% INPUTS:
%    subgraphSizes:    `n x 2` matrix of the node count and the edge count of each bond subgraph
%                      (fourth output of `extractBondSubgraphs`)
%    buildSubgraphs:   function handle; `buildSubgraphs(idx)` returns a cell column holding the
%                      bond subgraphs `idx` (indices into the rows of `subgraphSizes`), in the
%                      order of `idx`
%
% OUTPUTS:
%    conservedGroup:   indices of the subgraphs in the largest unlabelled isomorphism class
%                      (the class with the smallest leader index on a tie), ascending
%    reactingGroups:   indices of all other subgraphs, ascending
%
% OPTIONAL OUTPUT:
%    diagnostics:      structure with fields:
%
%                        * .numSizeGroups - number of distinct (node count, edge count) pairs
%                        * .groupsClassified - number of size groups classified
%                        * .componentsBuilt - number of subgraphs requested from `buildSubgraphs`
%
% NOTE:
%    The outputs are identical to the `conservedGroup` and `reactingGroups` outputs of
%    `findAndExtractMolecularGraphs` on all the subgraphs, which classifies every subgraph and
%    takes the first class of maximal size in leader order. The same group is found here
%    exactly, from far fewer subgraphs:
%
%      1. isomorphic graphs have the same node and edge counts, so every isomorphism class lies
%         inside one size group;
%      2. `classifySubgraphIsomorphism` compares each leader only with the later members of
%         its own size group, in ascending order, so classifying one size group on its own
%         gives exactly its classes, with the same leaders;
%      3. the size groups are classified from the most populous down (ties by first member),
%         keeping the best class by size and then by smallest leader, which is the class
%         `max` picks among leader-ordered classes;
%      4. the search stops at the first size group with fewer members than the best class,
%         since it, and every later group, cannot hold a class as large. A group with exactly
%         as many members is still classified, as it may hold an equal class with a smaller
%         leader.
%
%    Only the members of the classified size groups are built, so on genome-scale networks
%    the large bond subgraphs (those that embed the largest atom components) are never built.
%    With no subgraphs, the result (or error) is that of `findAndExtractMolecularGraphs`.
%
% .. Author: - COBRA Toolbox, feature 20261103-115636-conserved-bond-group-pruning

numSubgraphs = size(subgraphSizes, 1);
diagnostics = struct('numSizeGroups', 0, 'groupsClassified', 0, 'componentsBuilt', 0);
if numSubgraphs == 0
    % the same result, or the same error, as the full classification of no subgraphs
    [~, ~, ~, ~, conservedGroup, reactingGroups] = findAndExtractMolecularGraphs([], cell(0, 1), ...
        cell(0, 1), cell(0, 1), false);
    return
end

% size groups, the most populous first, ties by their first member
[~, firstMember, sizeGroup] = unique(subgraphSizes, 'rows', 'first');
population = accumarray(sizeGroup(:), 1);
[~, groupOrder] = sortrows([-population, firstMember]);
diagnostics.numSizeGroups = numel(population);

bestSize = 0;
bestLeader = inf;
conservedGroup = zeros(1, 0);
for g = groupOrder'
    if population(g) < bestSize
        break
    end
    members = find(sizeGroup == g);
    groupSubgraphs = buildSubgraphs(members);
    diagnostics.componentsBuilt = diagnostics.componentsBuilt + numel(members);
    diagnostics.groupsClassified = diagnostics.groupsClassified + 1;
    classes = classifySubgraphIsomorphism(groupSubgraphs);
    clear groupSubgraphs
    for c = 1:numel(classes)
        classMembers = reshape(members(classes{c}), 1, []);
        if numel(classMembers) > bestSize || ...
                (numel(classMembers) == bestSize && classMembers(1) < bestLeader)
            bestSize = numel(classMembers);
            bestLeader = classMembers(1);
            conservedGroup = classMembers;
        end
    end
end
reactingGroups = setdiff(1:numSubgraphs, conservedGroup);
end
