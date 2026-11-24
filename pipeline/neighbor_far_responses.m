function R = neighbor_far_responses(cfg, pimg, mutual_sim, map, bin_bounds, n_bins, dv)
% NEIGHBOR_FAR_RESPONSES  Content/border/mutual DVs for near and far patch pairs.
%   R = neighbor_far_responses(cfg, pimg, mutual_sim, map, bin_bounds, n_bins, dv)
%
%   For each reference patch (i,j) in the GTR image, forms two NEAR pairs (its
%   lower and right neighbours) and two FAR pairs (randomly sampled beyond
%   cfg.gtr.dcrit), and returns the content DV, border DV, and mutual similarity
%   for each, plus same/different ground truth. Shared by pipeline stages s6, s7.
%
%   Inputs
%     cfg          - config struct.
%     pimg         - GTR image in ABR-ready LMS space (from make_gtr_image).
%     mutual_sim   - [n x n] mutual-similarity matrix (segmentation.mutual_similarity).
%     map          - [n_rows x n_cols] region-label map for this trial (carries the
%                    grid shape).
%     bin_bounds,n_bins - histogram bounds (vislab.nat_stat_bayes.load_bin_bounds).
%     dv           - struct of trained DV function handles (load_dv_handles): .spot,
%                    .edge, .content, .border.
%
%   Output R (struct, each field 1 x n_pairs; Bill's names in brackets):
%     content_near, border_near, mutual_near  near pairs' content DV, border DV and
%                                             mutual similarity [rcn, rbn, rmn]
%     content_far, border_far, mutual_far     the same for far pairs [rcf, rbf, rmf]
%     same_near, same_far   ground truth, 1 = both patches in the same region
%     n_pairs               number of pairs of each kind (a scalar) [ncnt]
%
%   Each patch is prepared once (segmentation.prep_grid: extract, normalize, rotate,
%   and contrast-normalize the gray), so every pair reads a clean per-patch copy.
%   (The original re-normalized the reference gray in place across pairs -- a
%   stateful bug; avoided here, flagged for Geisler.)
%
%   See also MAKE_GTR_IMAGE, SEGMENTATION.PREP_GRID, SEGMENTATION.CONTENT_FEATURES,
%   SEGMENTATION.CONTENT_DV_PAIR, SELF_SUP_DECISION, NEARFAR_SCORE_GRID

    [n_rows, n_cols] = size(map);        % grid rows x cols (n_cols = linear-index stride)
    patch_size = size(pimg, 1) / n_rows;
    dcrit = cfg.gtr.dcrit;
    power_suppress = cfg.dv.power_suppress;
    spot_dims = cfg.features.spot_dims;
    edge_dims = cfg.features.edge_dv_dims;

    n_pairs = 2 * (n_rows - 1) * (n_cols - 1);
    [content_near, border_near, mutual_near] = deal(zeros(1, n_pairs));
    [content_far, border_far, mutual_far] = deal(zeros(1, n_pairs));
    same_near = zeros(1, n_pairs);
    same_far  = zeros(1, n_pairs);
    n_near = 0; n_far = 0;

    % prep every patch once (extract + normalize + rotate; raw gray for the power DV,
    % contrast-normalized gray for the edge/border DVs)
    [patches, achrom, achrom_norm] = segmentation.prep_grid(pimg, patch_size, cfg);
    windows = segmentation.border_windows(pimg, patch_size, cfg);   % [] unless border_center

    % featurize each patch once (power spectrum + spot/edge histograms); pair_cb below
    % just combines them. Edge features use achrom_norm (contrast-normalized), matching pair_cb.
    content_feats = segmentation.content_features(patches, achrom, achrom_norm, patch_size, ...
        bin_bounds, n_bins, spot_dims, edge_dims, cfg);

    for i = 1:n_rows-1
        for j = 1:n_cols-1
            ref_num = (i-1)*n_cols + j;

            % near — lower neighbour (dir 1)
            n_near = n_near + 1;
            [content_near(n_near), border_near(n_near)] = pair_cb(i, j, i+1, j, 1, windows);
            same_near(n_near) = map(i, j) == map(i+1, j);
            mutual_near(n_near) = mutual_sim(ref_num, i*n_cols + j);

            % near — right neighbour (dir 2)
            n_near = n_near + 1;
            [content_near(n_near), border_near(n_near)] = pair_cb(i, j, i, j+1, 2, windows);
            same_near(n_near) = map(i, j) == map(i, j+1);
            mutual_near(n_near) = mutual_sim(ref_num, (i-1)*n_cols + j+1);

            % two far pairs (dir 2, matching the original's leftover dir). Not adjacent,
            % so always the two-patch border cue (no windows), as in Bill's code.
            for f = 1:2
                n_far = n_far + 1;
                [x2, y2] = far_patch();
                [content_far(n_far), border_far(n_far)] = pair_cb(i, j, x2, y2, 2, []);
                same_far(n_far) = map(i, j) == map(x2, y2);
                mutual_far(n_far) = mutual_sim(ref_num, (x2-1)*n_cols + y2);
            end
        end
    end

    R = struct('content_near', content_near, 'border_near', border_near, ...
        'mutual_near', mutual_near, 'content_far', content_far, 'border_far', border_far, ...
        'mutual_far', mutual_far, 'same_near', same_near, 'same_far', same_far, ...
        'n_pairs', n_pairs);

    % ---- nested helper: content + border DV for the pair at grid (ra,ca)-(rb2,cb) ----
    function [content_dv, border_dv] = pair_cb(ra, ca, rb2, cb, dir, border_wins)
        content_dv = segmentation.content_dv_pair(content_feats{ra, ca}, ...
            content_feats{rb2, cb}, patch_size, power_suppress, dv.spot, dv.edge, ...
            dv.content, spot_dims, edge_dims);
        border = segmentation.border_cue(cfg, achrom_norm, border_wins, ra, ca, rb2, cb, dir);
        border_dv = dv.border(border(1:2)');
    end

    function [x2, y2] = far_patch()
        % Reject-sample a patch farther than dcrit. Bounded so a small/narrow grid
        % (where no patch can exceed dcrit for a central reference) can't loop forever;
        % it then falls back to the farthest patch found. On a normal grid a valid far
        % is found on the first tries, so the fallback never fires (GTR unchanged).
        best_d = -1; bx = 1; by = 1;
        for attempt = 1:1000
            x2 = randi(n_rows); y2 = randi(n_cols);
            d = sqrt((i - x2)^2 + (j - y2)^2);
            if d > dcrit, return; end
            if d > best_d, best_d = d; bx = x2; by = y2; end
        end
        x2 = bx; y2 = by;
    end
end
