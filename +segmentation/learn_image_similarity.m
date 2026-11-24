function S = learn_image_similarity(cfg, pimg, map, method)
% LEARN_IMAGE_SIMILARITY  One image's patch similarities and self-supervised grouping settings.
%   S = segmentation.learn_image_similarity(cfg, pimg, map, method)
%
%   Computes, once per image, everything the grouping step needs:
%     1. the all-pairs content similarity content_sim (paper phi_ij) and the mutual
%        similarity mutual_sim (paper u_ij);
%     2. near/far patch-pair responses, and from them the grouping criterion
%        group_crit_best (paper gamma_l) and mutual-similarity weight
%        mutual_weight_best (paper w_m) that maximize near/far accuracy on this
%        image (the self-supervised step);
%     3. the neighbour border+content similarity neighbor_sim, combined into
%        combined_sim = neighbor_sim + mutual_weight_best * mutual_sim on
%        neighbouring pairs (paper s_ij).
%   Grouping itself is left to the caller (segmentation.group_patches), so a sweep
%   over grouping parameters reuses one S.
%
%   Inputs
%     cfg     config struct (config.m).
%     pimg    GTR image in LMS space, as from make_gtr_image.
%     map     [rows x cols] ground-truth region map. Sets the patch grid; its labels
%             are used only to score same/different accuracy (S.accuracy,
%             S.accuracy_best), never to choose group_crit_best or mutual_weight_best.
%     method  self-supervised rule (see self_sup_decision):
%               'bc'  pre-trained border+content DV as is ('bc_noshift'); only
%                     group_crit_best and mutual_weight_best are learned. Bill's
%                     current rule (ss_segm.m with contentflg = 0, borderflg = 1).
%               'nc'  older: content-based shift ('c_shft').
%               'ncb' older: border+content bound refit on this image ('bc').
%   Output
%     S  struct (Bill's ss_segm.m names in docs/segmentation-parity.md):
%          content_sim, mutual_sim    [n x n] all-pairs content and mutual similarity
%          content_near, border_near, mutual_near   content DV, border DV and mutual
%          content_far, border_far, mutual_far      similarity of each near / far pair
%          same_near, same_far        ground truth for those pairs (1 = same region)
%          accuracy_nearfar, accuracy near/far and same/different proportion correct,
%                                     [criterion x weight] grid
%          group_crit_best, mutual_weight_best  chosen criterion and weight
%          accuracy_best              same/different accuracy at that choice
%          neighbor_sim, patch_dist, combined_sim  [n x n] neighbour similarity,
%                                     patch-centre distances (pixels), combined
%          patch_x, patch_y, patch_size  patch grid (patch_size in pixels)
%
% See also SEGMENTATION.SEGMENT_LMS, S7_SEGMENT_GTR, NEIGHBOR_FAR_RESPONSES,
%   SELF_SUP_DECISION, NEARFAR_SCORE_GRID

    [n_rows, n_cols] = size(map);
    patch_size = size(pimg, 1) / n_rows;
    ecc = cfg.patch.size / patch_size;
    [cols, rows] = meshgrid(1:n_cols, 1:n_rows);       % patch k is row-major, as make_gtr_image
    patch_x = reshape(rows', [], 1);
    patch_y = reshape(cols', [], 1);

    % artifacts: bin bounds (always the ecc-1 bins, as in the originals) + trained DVs.
    % feature_bound_type(f) > 0 selects feature f (5 = natural-image bins).
    feature_bound_type = zeros(1, 20);  feature_bound_type(cfg.features.dv_dims) = 5;
    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds(feature_bound_type, 1, ...
        bins_filename(cfg));
    dv = load_dv_handles(cfg, ecc, true);

    % --- 1. content similarity + mutual similarity ---
    content_sim = segmentation.content_similarity_matrix(pimg, patch_size, patch_x, patch_y, ...
        bin_bounds, n_bins, dv.spot, dv.edge, dv.content, cfg);
    mutual_sim = segmentation.mutual_similarity(content_sim, cfg.bill_compat);

    % --- 2. learn group_crit_best / mutual_weight_best from the self-supervised
    %        near/far task (grids and tie-breaking as Bill's ss_segm.m:231-234, 594-598) ---
    group_crit_vec = 0 : 0.8 : 16;       % grouping criterion (DV units)
    mutual_weight_vec = 0 : 0.8 : 16;    % mutual-similarity weight (dimensionless)
    R = neighbor_far_responses(cfg, pimg, mutual_sim, map, bin_bounds, n_bins, dv);
    ss_method = struct('bc', 'bc_noshift', 'nc', 'c_shft', 'ncb', 'bc').(method);
    [bc_near, bc_far] = self_sup_decision(ss_method, R, dv);
    [accuracy, ~, ~, accuracy_nearfar] = nearfar_score_grid(bc_near, bc_far, R, ...
        group_crit_vec, mutual_weight_vec);
    [~, best] = max(accuracy_nearfar, [], 'all', 'linear');  % first max in column order:
    [crit_idx, weight_idx] = ind2sub(size(accuracy_nearfar), best);  % lowest weight, then criterion

    % --- 3. neighbour similarity, combined: neighbor_sim + mutual_weight_best * mutual_sim ---
    [neighbor_sim, patch_dist] = segmentation.neighbor_similarity_matrix(pimg, patch_size, ...
        patch_x, patch_y, patch_size, bin_bounds, n_bins, dv, cfg);
    mutual_weight_best = mutual_weight_vec(weight_idx);
    combined_sim = (neighbor_sim + mutual_weight_best * mutual_sim) ...
        .* (neighbor_sim ~= 0);  % neighbours only

    S = struct('content_sim', content_sim, 'mutual_sim', mutual_sim, ...
        'content_near', R.content_near, 'border_near', R.border_near, ...
        'mutual_near', R.mutual_near, 'content_far', R.content_far, ...
        'border_far', R.border_far, 'mutual_far', R.mutual_far, ...
        'same_near', R.same_near, 'same_far', R.same_far, ...
        'accuracy_nearfar', accuracy_nearfar, 'accuracy', accuracy, ...
        'group_crit_best', group_crit_vec(crit_idx), 'mutual_weight_best', mutual_weight_best, ...
        'accuracy_best', accuracy(crit_idx, weight_idx), ...
        'neighbor_sim', neighbor_sim, 'patch_dist', patch_dist, 'combined_sim', combined_sim, ...
        'patch_x', patch_x, 'patch_y', patch_y, 'patch_size', patch_size);
end
