function [patches, achrom, achrom_norm] = prep_grid(region_image, patch_size, cfg)
% PREP_GRID  Prepare every patch of the image grid ONCE.
%   [patches, achrom, achrom_norm] = segmentation.prep_grid(region_image, patch_size, cfg)
%
%   The single source of per-patch preparation shared by
%   segmentation.content_similarity_matrix, segmentation.neighbor_similarity_matrix
%   and neighbor_far_responses (which previously each had their own copy and
%   re-prepared patches per pair). For every grid cell it extracts the patch,
%   mean-normalizes it (ptch_norm type 3), rotates LMS->ABR, and also returns the
%   raw and contrast-normalized achromatic channels -- so the all-pairs / neighbour
%   loops just index these instead of recomputing.
%
%   The grid size follows the image: size(region_image)/patch_size patches in each
%   dimension, so the image may be rectangular (any whole number of patches per side).
%
%   Inputs
%     region_image - texture-region image, [H x W x 3] (H, W each a multiple of
%                    patch_size).
%     patch_size    - patch side length in pixels.
%     cfg           - config struct (uses cfg.norm.target_mean / target_contrast).
%
%   Outputs (each a [H/patch_size x W/patch_size] cell, indexed by grid coordinate
%   {grid_row, grid_col})
%     patches     - [patch_size x patch_size x 3] ABR patch.
%     achrom      - [patch_size x patch_size] raw achromatic channel (patches(:,:,1)),
%                   for the power DV.
%     achrom_norm - [patch_size x patch_size] contrast-normalized achromatic channel,
%                   for the edge/border DVs.
%
%   See also SEGMENTATION.CONTENT_SIMILARITY_MATRIX, SEGMENTATION.NEIGHBOR_SIMILARITY_MATRIX

    target_mean = cfg.norm.target_mean;
    target_contrast = cfg.norm.target_contrast;
    n_grid_rows = size(region_image, 1) / patch_size;      % patch rows
    n_grid_cols = size(region_image, 2) / patch_size;      % patch cols
    patches     = cell(n_grid_rows, n_grid_cols);
    achrom      = cell(n_grid_rows, n_grid_cols);
    achrom_norm = cell(n_grid_rows, n_grid_cols);
    for grid_row = 1:n_grid_rows
        for grid_col = 1:n_grid_cols
            rows = (grid_row - 1) * patch_size + (1:patch_size);
            cols = (grid_col - 1) * patch_size + (1:patch_size);
            patch = vislab.lib.ptch_norm( ...
                region_image(rows, cols, :), target_mean, target_contrast, 3, 3);
            patch = vislab.nat_stat_bayes.apply_color_rotation(patch);   % shared LMS->ABR transform
            patches{grid_row, grid_col} = patch;
            achrom{grid_row, grid_col}  = patch(:, :, 1);
            achrom_norm{grid_row, grid_col} = ...
                vislab.lib.cntrst_norm(patch(:, :, 1), target_contrast, patch_size);
        end
    end
end
