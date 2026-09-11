function patch_features = content_features(patches, achrom, edge_channel, patch_size, ...
        bin_bounds, n_bins, spot_dims, edge_dims, cfg)
% CONTENT_FEATURES  Precompute each grid patch's content features ONCE.
%   patch_features = segmentation.content_features(patches, achrom, edge_channel, ...
%       patch_size, bin_bounds, n_bins, spot_dims, edge_dims, cfg)
%
%   The featurize half of the content decision variable. The all-pairs / neighbour
%   loops otherwise recompute every patch's power spectrum and feature histograms for
%   each of its pairings -- O(n^2) featurizations of only n distinct patches. This
%   computes them once per patch (O(n)); segmentation.content_dv_pair then just
%   combines two patches' features. Shared by content_similarity_matrix,
%   neighbor_similarity_matrix and neighbor_far_responses.
%
%   Inputs (patches, achrom, edge_channel are grid cells from segmentation.prep_grid,
%   indexed {grid_row, grid_col})
%     patches      - ABR patch (for the spot / colour histograms).
%     achrom       - raw achromatic channel (for the power spectrum).
%     edge_channel - achromatic channel fed to the edge histograms (contrast-normalized
%                    or raw, chosen by the caller to match its dv_edge_hist call).
%     patch_size   - patch size in pixels.
%     bin_bounds, n_bins - histogram bin edges / counts (load_bin_bounds).
%     spot_dims    - spot feature dims to histogram (cfg.features.spot_dims, e.g. [1 13 14]).
%     edge_dims    - edge feature dims to histogram (cfg.features.edge_dv_dims, e.g. [5 9 10]).
%     cfg          - config struct (edge threshold + steerable kernel widths).
%
%   Output
%     patch_features - [grid_row x grid_col] cell; patch_features{r,c} is a struct with fields
%            .pspec       normalized power spectrum of achrom{r,c}
%            .hspot{k}    histcounts of spot feature k (k in spot_dims)
%            .hedge{k}    histcounts of edge feature k (k in edge_dims)
%
%   See also SEGMENTATION.PREP_GRID, SEGMENTATION.CONTENT_DV_PAIR,
%   SEGMENTATION.CONTENT_SIMILARITY_MATRIX, SEGMENTATION.NEIGHBOR_SIMILARITY_MATRIX

    thr = cfg.dv.edge_thresh;                 % only affects unused count features here
    sd1 = cfg.dv.sd1; nsd1 = cfg.dv.nsd1; sd2 = cfg.dv.sd2; nsd2 = cfg.dv.nsd2;
    spot_flags = zeros(1, 20); spot_flags(spot_dims) = 1;
    edge_flags = zeros(1, 20); edge_flags(edge_dims) = 1;
    [n_grid_rows, n_grid_cols] = size(patches);

    % Featurize each patch independently -> parfor (runs serially without the Parallel
    % Computing Toolbox). This is the per-patch (FFT + steerable) cost shared by
    % content_similarity_matrix, neighbor_similarity_matrix and neighbor_far_responses.
    % linear order so parfor can slice
    patches_v = patches(:);  achrom_v = achrom(:);  edge_channel_v = edge_channel(:);
    patch_features_v = cell(n_grid_rows * n_grid_cols, 1);
    parfor k = 1:n_grid_rows * n_grid_cols
        s = struct('pspec', vislab.nat_stat_bayes.power_spectrum(achrom_v{k}), ...
            'hspot', [], 'hedge', []);

        sv = vislab.nat_stat_bayes.spot_features(patches_v{k}, patch_size, spot_flags);
        hs = cell(1, 20);
        for t = 1:numel(spot_dims)
            d = spot_dims(t);  hs{d} = histcounts(sv{d}, bin_bounds(d, 1:n_bins(d)));
        end
        s.hspot = hs;

        ev = vislab.nat_stat_bayes.edge_features( ...
            edge_channel_v{k}, thr, sd1, nsd1, sd2, nsd2, edge_flags);
        he = cell(1, 20);
        for t = 1:numel(edge_dims)
            d = edge_dims(t);  he{d} = histcounts(ev{d}, bin_bounds(d, 1:n_bins(d)));
        end
        s.hedge = he;

        patch_features_v{k} = s;
    end
    patch_features = reshape(patch_features_v, n_grid_rows, n_grid_cols);
end
