function [groups, n_groups] = merge_similar_regions(groups, n_groups, group_counts, ...
        groups2d, content_sim, merge_criterion)
% MERGE_SIMILAR_REGIONS  Merge the single most-similar pair of touching regions.
%   [groups, n_groups] = segmentation.merge_similar_regions(groups, n_groups, ...
%       group_counts, groups2d, content_sim, merge_criterion)
%
%   Region-similarity grouping step: finds spatially touching region pairs,
%   computes their mean content similarity, and merges the most-similar pair if
%   it exceeds merge_criterion. One merge per call. (Was merge_groups.m.)
%
%   Inputs
%     groups          - group membership (row per group, patch indices).
%     n_groups        - number of groups.
%     group_counts    - per-group patch-count + 1 (as produced by group_patches).
%     groups2d        - 2-D region-label map ([n_grid_rows x n_grid_cols]).
%     content_sim     - all-pairs content-similarity matrix.
%     merge_criterion - merge if mean similarity exceeds this (paper: gamma_r).
%
%   Outputs
%     groups, n_groups - updated membership and group count.
%
%   See also SEGMENTATION.GROUP_PATCHES, SEGMENTATION.ASSIGN_ISOLATED_PATCHES

    [n_grid_rows, n_grid_cols] = size(groups2d);        % grid rows x cols

    % adjacency: which regions touch which (4-neighbour)
    touching = zeros(n_groups, n_groups);
    for k = 1:n_groups
        for i = 1:n_grid_rows
            for j = 1:n_grid_cols
                if groups2d(i, j) == k
                    if j < n_grid_cols && groups2d(i, j+1) ~= k
                        touching(k, groups2d(i, j+1)) = 1;
                    end
                    if j > 1 && groups2d(i, j-1) ~= k
                        touching(k, groups2d(i, j-1)) = 1;
                    end
                    if i < n_grid_rows && groups2d(i+1, j) ~= k
                        touching(k, groups2d(i+1, j)) = 1;
                    end
                    if i > 1 && groups2d(i-1, j) ~= k
                        touching(k, groups2d(i-1, j)) = 1;
                    end
                end
            end
        end
    end

    % mean content similarity between each touching pair
    mean_sim = zeros(n_groups, n_groups);
    for k = 1:n_groups
        for l = k+1:n_groups
            if touching(k, l) == 1
                count = 0;
                for a = 1:group_counts(k)
                    for b = 1:group_counts(l)
                        p1 = groups(k, a);
                        p2 = groups(l, b);
                        if p1 > 0 && p2 > 0
                            count = count + 1;
                            mean_sim(k, l) = mean_sim(k, l) + content_sim(p1, p2);
                        end
                    end
                end
                mean_sim(k, l) = mean_sim(k, l) / count;
            end
        end
    end

    % merge the most-similar pair if above criterion
    max_sim = -inf; km = 0; lm = 0;
    for k = 1:n_groups
        for l = k+1:n_groups
            if mean_sim(k, l) > max_sim
                max_sim = mean_sim(k, l);
                km = k; lm = l;
            end
        end
    end
    if max_sim > merge_criterion
        groups(km, group_counts(km)+1 : group_counts(km)+group_counts(lm)) = ...
            groups(lm, 1:group_counts(lm));
        groups(lm, 1:group_counts(lm)) = 0;
        groups(km, :) = sort(groups(km, :), 'descend');
        for k = lm+1:n_groups
            groups(k-1, :) = groups(k, :);
        end
        groups(n_groups, :) = 0;
        n_groups = n_groups - 1;
    end
end
