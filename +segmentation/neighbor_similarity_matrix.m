function [phi, dst] = neighbor_similarity_matrix(region_image, patch_size, patch_x, patch_y, ...
        neighbor_distance, bin_bounds, n_bins, dv, cfg)
% NEIGHBOR_SIMILARITY_MATRIX  Border+content similarity for neighbouring patch pairs.
%   [phi, dst] = segmentation.neighbor_similarity_matrix(region_image, ...
%       patch_size, patch_x, patch_y, neighbor_distance, ...
%       bin_bounds, n_bins, dv, cfg)
%
%   For each NEIGHBOURING patch pair (Euclidean patch-centre distance equal to
%   neighbor_distance), computes the power/spot/edge content DV and the border DV
%   and combines them with the trained border+content bound (dv.bc), giving the
%   self-supervised similarity phi_ij used for grouping. Non-neighbour entries are
%   zero. Also returns the full pairwise distance matrix dst. Used by stage s7.
%   (Was the neighbour "phi" loop in tex_grp_s_p_ms_SS_{ncm,ncbm}.m.)
%
%   Inputs mirror segmentation.content_similarity_matrix, plus:
%     neighbor_distance - distance (pixels) identifying a neighbouring pair (= patch_size).
%     dv                - struct of trained DV handles: dv.h, dv.e, dv.c, dv.b, dv.bc.
%
%   Note: per-pair DVs use cfg.gtr.power_suppress (b0=16), matching
%   neighbor_far_responses and content_similarity_matrix (cfg.dv.power_suppress,
%   also 16 since Geisler unified b0 -- 2026-07).
%
%   See also SEGMENTATION.PREP_GRID, SEGMENTATION.CONTENT_FEATURES,
%   SEGMENTATION.CONTENT_DV_PAIR, SEGMENTATION.CONTENT_SIMILARITY_MATRIX

    n = numel(patch_x);
    power_suppress = cfg.gtr.power_suppress;
    spot_dims = cfg.features.spot_dims;     % [1 13 14]
    edge_dims = cfg.features.edge_dv_dims;  % [5 9 10]

    % prep every patch once (extract + normalize + rotate; raw and contrast-norm gray)
    [patches, achrom, achrom_norm] = segmentation.prep_grid(region_image, patch_size, cfg);
    if cfg.dv.contrast_normalize                            % gray fed to edge/border DVs
        edge_channel = achrom_norm;
    else
        edge_channel = achrom;
    end

    % featurize every patch once (power spectrum + spot/edge histograms); the loop
    % combines them per neighbour pair (border DV stays pairwise -- it needs both patches).
    patch_features = segmentation.content_features(patches, achrom, edge_channel, ...
        patch_size, bin_bounds, n_bins, spot_dims, edge_dims, cfg);

    phi = zeros(n, n);
    dst = zeros(n, n);
    for i = 1:n
        x1 = (patch_x(i) - 1) * patch_size + 1;
        y1 = (patch_y(i) - 1) * patch_size + 1;
        for j = i+1:n
            x2 = (patch_x(j) - 1) * patch_size + 1;
            y2 = (patch_y(j) - 1) * patch_size + 1;
            dij = sqrt((x1 - x2)^2 + (y1 - y2)^2);
            dst(i, j) = dij;
            dst(j, i) = dij;
            if dij ~= neighbor_distance
                continue;
            end
            if y1 == y2 && x2 > x1          % vertical neighbour -> dir 1; else horizontal -> dir 2
                dir = 1;
            else
                dir = 2;
            end
            rc = segmentation.content_dv_pair(patch_features{patch_x(i), patch_y(i)}, ...
                patch_features{patch_x(j), patch_y(j)}, ...
                patch_size, power_suppress, dv.h, dv.e, dv.c, spot_dims, edge_dims);
            border = vislab.nat_stat_bayes.dv_border(edge_channel{patch_x(i), patch_y(i)}, ...
                edge_channel{patch_x(j), patch_y(j)}, ...
                patch_size, dir, cfg.dv.sd1, cfg.dv.nsd1, false);
            rb = dv.b(border(1:2)');

            % [content, border] ordering (Geisler-confirmed; matches s5 dbndbc training)
            phi(i, j) = dv.bc([rc, rb]');
            phi(j, i) = phi(i, j);
        end
    end
end
