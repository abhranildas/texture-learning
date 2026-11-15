function R = neighbor_far_responses(cfg, pimg, rho, map, bin_bounds, n_bins, dv)
% NEIGHBOR_FAR_RESPONSES  Content/border/mutual DVs for near and far patch pairs.
%   R = neighbor_far_responses(cfg, pimg, rho, map, bin_bounds, n_bins, dv)
%
%   For each reference patch (i,j) in the GTR image, forms two NEAR pairs (its
%   lower and right neighbours) and two FAR pairs (randomly sampled beyond
%   cfg.gtr.dcrit), and returns the content DV, border DV, and mutual similarity
%   for each, plus same/different ground truth. Shared by pipeline stages s6, s7.
%
%   Inputs
%     cfg          - config struct.
%     pimg         - GTR image in ABR-ready LMS space (from make_gtr_image).
%     rho          - mutual-similarity matrix (segmentation.mutual_similarity).
%     map          - [npx x npy] region-label map for this trial (carries the grid shape).
%     bin_bounds,n_bins - histogram bounds (vislab.nat_stat_bayes.load_bin_bounds).
%     dv           - struct of trained DV function handles: dv.h, dv.e, dv.c, dv.b (from quad2fun).
%
%   Output R (struct): rcn,rbn,rmn (near content/border/mutual), rcf,rbf,rmf (far),
%     same_near, same_far (1 = same region), ncnt (number of pairs of each kind).
%
%   Each patch is prepared once (segmentation.prep_grid: extract, normalize, rotate,
%   and contrast-normalize the gray), so every pair reads a clean per-patch copy.
%   (The original re-normalized the reference gray in place across pairs -- a
%   stateful bug; avoided here, flagged for Geisler.)
%
%   See also MAKE_GTR_IMAGE, SEGMENTATION.PREP_GRID, SEGMENTATION.CONTENT_FEATURES,
%   SEGMENTATION.CONTENT_DV_PAIR, SELF_SUP_DECISION, NEARFAR_SCORE_GRID

    [npx, npy] = size(map);              % grid rows x cols (npy = linear-index stride)
    patch_size = size(pimg, 1) / npx;
    dcrit = cfg.gtr.dcrit;
    power_suppress = cfg.gtr.power_suppress;
    spot_dims = cfg.features.spot_dims;
    edge_dims = cfg.features.edge_dv_dims;

    ncnt = 2 * (npx - 1) * (npy - 1);
    [rcn, rbn, rmn] = deal(zeros(1, ncnt));
    [rcf, rbf, rmf] = deal(zeros(1, ncnt));
    same_near = zeros(1, ncnt);
    same_far  = zeros(1, ncnt);
    scnt = 0; dcnt = 0;

    % prep every patch once (extract + normalize + rotate; raw gray for the power DV,
    % contrast-normalized gray for the edge/border DVs)
    [patches, achrom, achrom_norm] = segmentation.prep_grid(pimg, patch_size, cfg);
    windows = segmentation.border_windows(pimg, patch_size, cfg);   % [] unless border_center

    % featurize each patch once (power spectrum + spot/edge histograms); pair_cb below
    % just combines them. Edge features use achrom_norm (contrast-normalized), matching pair_cb.
    content_feats = segmentation.content_features(patches, achrom, achrom_norm, patch_size, ...
        bin_bounds, n_bins, spot_dims, edge_dims, cfg);

    for i = 1:npx-1
        for j = 1:npy-1
            ref_num = (i-1)*npy + j;

            % near — lower neighbour (dir 1)
            scnt = scnt + 1;
            [rcn(scnt), rbn(scnt)] = pair_cb(i, j, i+1, j, 1, windows);
            same_near(scnt) = map(i, j) == map(i+1, j);
            rmn(scnt) = rho(ref_num, i*npy + j);

            % near — right neighbour (dir 2)
            scnt = scnt + 1;
            [rcn(scnt), rbn(scnt)] = pair_cb(i, j, i, j+1, 2, windows);
            same_near(scnt) = map(i, j) == map(i, j+1);
            rmn(scnt) = rho(ref_num, (i-1)*npy + j+1);

            % two far pairs (dir 2, matching the original's leftover dir). Not adjacent,
            % so always the two-patch border cue (no windows), as in Bill's code.
            for f = 1:2
                dcnt = dcnt + 1;
                [x2, y2] = far_patch();
                [rcf(dcnt), rbf(dcnt)] = pair_cb(i, j, x2, y2, 2, []);
                same_far(dcnt) = map(i, j) == map(x2, y2);
                rmf(dcnt) = rho(ref_num, (x2-1)*npy + y2);
            end
        end
    end

    R = struct('rcn', rcn, 'rbn', rbn, 'rmn', rmn, 'rcf', rcf, 'rbf', rbf, 'rmf', rmf, ...
               'same_near', same_near, 'same_far', same_far, 'ncnt', ncnt);

    % ---- nested helper: content + border DV for the pair at grid (ra,ca)-(rb2,cb) ----
    function [rc, rb] = pair_cb(ra, ca, rb2, cb, dir, border_wins)
        rc = segmentation.content_dv_pair(content_feats{ra, ca}, content_feats{rb2, cb}, ...
            patch_size, power_suppress, dv.h, dv.e, dv.c, spot_dims, edge_dims);
        border = segmentation.border_cue(cfg, achrom_norm, border_wins, ra, ca, rb2, cb, dir);
        rb = dv.b(border(1:2)');
    end

    function [x2, y2] = far_patch()
        % Reject-sample a patch farther than dcrit. Bounded so a small/narrow grid
        % (where no patch can exceed dcrit for a central reference) can't loop forever;
        % it then falls back to the farthest patch found. On a normal grid a valid far
        % is found on the first tries, so the fallback never fires (GTR unchanged).
        best_d = -1; bx = 1; by = 1;
        for attempt = 1:1000
            x2 = randi(npx); y2 = randi(npy);
            d = sqrt((i - x2)^2 + (j - y2)^2);
            if d > dcrit, return; end
            if d > best_d, best_d = d; bx = x2; by = y2; end
        end
        x2 = bx; y2 = by;
    end
end
