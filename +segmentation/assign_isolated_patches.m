function [groups, groups2d, n_groups] = assign_isolated_patches(groups, groups2d, n_groups, ...
        n_patches, patch_x, patch_y, content_sim)
% ASSIGN_ISOLATED_PATCHES  Attach unlinked patches to their best neighbouring group.
%   [groups, groups2d, n_groups] = segmentation.assign_isolated_patches(groups, ...
%       groups2d, n_groups, n_patches, patch_x, patch_y, content_sim)
%
%   Confidence-grouping step: each patch left unlinked after transitive grouping
%   is assigned to the 4-neighbour group with the highest content similarity (if
%   positive); otherwise it starts a new group. (Was iso_patch.m.)
%
%   NOTE: the inner scan excludes the isolated patch itself via
%   `other_idx ~= patch_idx`. The original iso_patch.m used `i ~= j` (row==col),
%   which neither excluded the patch nor kept diagonal group patches correctly;
%   Geisler confirmed (2026-07) it should compare the scanned patch's linear index
%   to the isolated patch's (his fix: `i1 ~= i0`), corrected here. Behaviour-changing
%   vs the preprint (affects isolated-patch assignment in segmentation).
%
%   Inputs
%     groups, groups2d - current group membership and 2-D label map ([n_grid_rows x
%                        n_grid_cols]).
%     n_groups         - current number of groups.
%     n_patches        - total number of patches.
%     patch_x, patch_y - patch-index -> grid-coordinate maps.
%     content_sim      - all-pairs content-similarity matrix.
%
%   Outputs
%     groups, groups2d, n_groups - updated membership, map, and group count.
%
%   See also SEGMENTATION.GROUP_PATCHES, SEGMENTATION.MERGE_SIMILAR_REGIONS

    % grid rows x cols (n_grid_cols is also the linear-index stride)
    [n_grid_rows, n_grid_cols] = size(groups2d);

    % list isolated patches (label 0) with their 4-neighbour group labels
    isolated = zeros(n_patches, 6);   % [row, col, up, left, down, right]
    n_iso = 0;
    for i = 1:n_grid_rows
        for j = 1:n_grid_cols
            if groups2d(i, j) == 0
                n_iso = n_iso + 1;
                isolated(n_iso, 1) = i;
                isolated(n_iso, 2) = j;
                if i > 1,           isolated(n_iso, 3) = groups2d(i-1, j); end
                if j > 1,           isolated(n_iso, 4) = groups2d(i, j-1); end
                if i < n_grid_rows, isolated(n_iso, 5) = groups2d(i+1, j); end
                if j < n_grid_cols, isolated(n_iso, 6) = groups2d(i, j+1); end
            end
        end
    end

    % assign each isolated patch to its best-matching neighbouring group
    for p = 1:n_iso
        max_sim = -100;
        best_group = 0;
        patch_row = isolated(p, 1);
        patch_col = isolated(p, 2);
        patch_idx = (patch_row - 1) * n_grid_cols + patch_col;
        for side = 3:6
            gnum = isolated(p, side);
            if gnum ~= 0
                for r = 1:n_grid_rows
                    for c = 1:n_grid_cols
                        other_idx = (r - 1) * n_grid_cols + c;
                        % Geisler-confirmed (was 'i~=j'); see NOTE above
                        if groups2d(r, c) == gnum && other_idx ~= patch_idx
                            sim = content_sim(patch_idx, other_idx);
                            if sim > max_sim
                                max_sim = sim;
                                best_group = gnum;
                            end
                        end
                    end
                end
            end
        end
        if max_sim > 0
            groups2d(patch_x(patch_idx), patch_y(patch_idx)) = best_group;
        else
            n_groups = n_groups + 1;
            groups2d(patch_x(patch_idx), patch_y(patch_idx)) = n_groups;
            groups(n_groups, 1) = n_groups;
        end
    end
end
