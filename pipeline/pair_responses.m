function [R, keep, col] = pair_responses(patches, bin_bounds, n_bins, feature_list, nh, ne, b0, thresh, psz, cfg)
% PAIR_RESPONSES  Per-pair [spot LLRs, edge LLRs, power, border] response matrix.
%   [R, keep, col] = pair_responses(patches, bin_bounds, n_bins, feature_list, nh, ne, b0, thresh, psz, cfg)
%
%   Shared by s5_train_decision_vars, compute_demo_responses and plot_stage6_pairs.
%   Drops outlier pairs (|.| >= 25 in the spot/edge/power LLRs). `nh` sets 3 spot
%   columns (achromatic only) or 5 (with cfg.features.spot_chrom_dims), so callers
%   must index the response matrix by the returned COL struct rather than a fixed
%   layout:
%     col.spot        - all spot LLR columns, in nh order (achromatic dims first)
%     col.spot_achr   - the achromatic subset of col.spot
%     col.spot_chrom  - the chromatic subset of col.spot (empty if colour is off)
%     col.edge        - edge LLR columns
%     col.power       - power LLR column
%     col.border      - the two border-response columns
%
%   Optional second output KEEP holds the original pair indices that survived, so
%   callers can re-align per-pair ground truth or images (e.g. plot_stage6_pairs).
%
%   `patches` are pairs already normalized + LMS->ABR-rotated (by sample_nearfar_pairs
%   / sample_demo_pairs / sample_texture_pairs) -- read here AS-IS, with no further
%   patch_to_a/patch_to_abr call. Those functions' contract is "3-channel input is
%   raw LMS, normalize + rotate it"; calling them again on an already-rotated ABR
%   array would silently re-normalize and re-rotate it.
    c0 = cfg.norm.target_contrast;
    lo = -25; hi = 25;
    n_pairs = size(patches, 4);
    n_h = numel(nh);  n_e = numel(ne);
    n_achr = numel(cfg.features.spot_achr_dims);
    col = struct('spot',       1:n_h, ...
                 'spot_achr',  1:n_achr, ...
                 'spot_chrom', n_achr+1:n_h, ...
                 'edge',       n_h + (1:n_e), ...
                 'power',      n_h + n_e + 1, ...
                 'border',     n_h + n_e + (2:3));
    R = zeros(n_pairs, n_h + n_e + 3);
    keep = zeros(n_pairs, 1);
    n = 0;
    for i = 1:n_pairs
        p1 = patches(1:psz, 1:psz, :, i);
        p2 = patches(1:psz, psz+1:2*psz, :, i);
        a1 = p1(:, :, 1);
        a2 = p2(:, :, 1);

        rp   = log(vislab.nat_stat_bayes.dv_power(a1, a2, b0, psz));
        spot = vislab.nat_stat_bayes.dv_spot_hist(p1, p2, psz, bin_bounds, n_bins, feature_list);
        rh = log(spot(nh));

        a1 = vislab.lib.cntrst_norm(a1, c0, psz);
        a2 = vislab.lib.cntrst_norm(a2, c0, psz);
        border = vislab.nat_stat_bayes.dv_border(a1, a2, psz, 2, cfg.dv.sd1, cfg.dv.nsd1, false);
        edge   = vislab.nat_stat_bayes.dv_edge_hist(a1, a2, thresh, bin_bounds, n_bins, cfg.dv.sd1, cfg.dv.nsd1, cfg.dv.sd2, cfg.dv.nsd2, feature_list);
        re = log(edge(ne));

        check = [rh, re, rp];
        if all(check > lo) && all(check < hi)
            n = n + 1;
            R(n, :) = [rh, re, rp, border(1), border(2)];
            keep(n) = i;
        end
    end
    R = R(1:n, :);
    keep = keep(1:n);
end
