function content_sim = content_similarity_matrix(region_image, patch_size, patch_x, ...
        patch_y, bin_bounds, n_bins, dv_spot_fun, dv_edge_fun, dv_content_fun, cfg)
% CONTENT_SIMILARITY_MATRIX  All-pairs content similarity between image patches.
%   content_sim = segmentation.content_similarity_matrix(region_image, ...
%       patch_size, patch_x, patch_y, bin_bounds, n_bins, ...
%       dv_spot_fun, dv_edge_fun, dv_content_fun, cfg)
%
%   For every pair of patches, computes the content decision variable (paper:
%   ln L_c) by combining the power, spot/colour-histogram, and edge-histogram
%   DVs via the trained content decision function. Returns the symmetric
%   similarity matrix content_sim (paper phi_ij; Bill's phiall). (Was mk_phi.m;
%   now uses vislab and takes preloaded bin bounds + a cfg struct instead of
%   hardcoded constants.)
%
%   Inputs
%     region_image   - texture-region image, [H x W x 3] (may be rectangular).
%     patch_size     - patch side length in pixels.
%     patch_x,patch_y- patch-index -> grid-coordinate maps (these carry the grid shape).
%     bin_bounds,n_bins - histogram bin bounds/counts (vislab.nat_stat_bayes.load_bin_bounds).
%     dv_spot_fun    - trained spot DV function handle (dv.spot, load_dv_handles).
%     dv_edge_fun    - trained edge DV function handle (dv.edge).
%     dv_content_fun - trained content DV function handle (dv.content).
%     cfg            - config struct (see config.m): uses cfg.norm, cfg.dv, cfg.features.
%
%   Output
%     content_sim - [n x n] symmetric content-similarity matrix (n = number of
%                   patches), a log-likelihood ratio: > 0 favours same texture.
%
%   See also SEGMENTATION.PREP_GRID, SEGMENTATION.CONTENT_FEATURES,
%   SEGMENTATION.CONTENT_DV_PAIR, SEGMENTATION.NEIGHBOR_SIMILARITY_MATRIX

    n = numel(patch_x);
    spot_dims = cfg.features.spot_dims;     % [1 13 14]
    edge_dims = cfg.features.edge_dv_dims;  % [5 9 10 11]
    power_suppress = cfg.dv.power_suppress;

    % prep every patch once (extract + normalize + rotate; raw and contrast-norm gray)
    [patches, achrom, achrom_norm] = segmentation.prep_grid(region_image, patch_size, cfg);
    if cfg.dv.contrast_normalize                            % gray fed to the edge DV
        edge_channel = achrom_norm;
    else
        edge_channel = achrom;
    end

    % featurize every patch once (power spectrum + spot/edge histograms); the pair
    % loop below then only combines them (segmentation.content_dv_pair).
    patch_features = segmentation.content_features(patches, achrom, edge_channel, ...
        patch_size, bin_bounds, n_bins, spot_dims, edge_dims, cfg);

    % All-pairs combine is the O(n^2) cost -> parfor over reference patches (runs
    % serially without the Parallel Computing Toolbox). Each iteration fills the upper
    % part of its row; the matrix is symmetrized afterwards.
    content_sim = zeros(n, n);
    parfor i = 1:n
        fa = patch_features{patch_x(i), patch_y(i)};
        row = zeros(1, n);
        for j = i+1:n
            row(j) = segmentation.content_dv_pair(fa, patch_features{patch_x(j), patch_y(j)}, ...
                patch_size, power_suppress, dv_spot_fun, dv_edge_fun, dv_content_fun, ...
                spot_dims, edge_dims);
        end
        content_sim(i, :) = row;
    end
    content_sim = content_sim + content_sim.';  % symmetric; diagonal stays 0 (unused)
end
