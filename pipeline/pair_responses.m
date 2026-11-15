function [R, keep, col] = pair_responses(patches, bin_bounds, n_bins, feature_list, ...
        spot_llr_dims, edge_llr_dims, power_suppress, edge_thresh, patch_size, cfg)
% PAIR_RESPONSES  Per-pair [spot LLRs, edge LLRs, power, border] response matrix.
%   [R, keep, col] = pair_responses(patches, bin_bounds, n_bins, feature_list, ...
%       spot_llr_dims, edge_llr_dims, power_suppress, edge_thresh, patch_size, cfg)
%
%   Shared by s5_train_decision_vars, compute_demo_responses and plot_stage6_pairs.
%   Drops outlier pairs (|.| >= 25 in the spot/edge/power LLRs). `spot_llr_dims` sets
%   3 spot columns (achromatic only) or 5 (with cfg.features.spot_chrom_dims), so
%   callers must index the response matrix by the returned COL struct rather than a
%   fixed layout:
%     col.spot        - all spot LLR columns, in spot_llr_dims order (achromatic dims first)
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
%   / sample_demo_pairs / sample_texture_pairs, via pair_patch_prep) -- read here
%   AS-IS, with no further normalize + rotate step; repeating it on an
%   already-rotated ABR array would silently re-normalize and re-rotate it.
%
%   Inputs
%     patches        - [patch_size x 2*patch_size x nch x n_pairs] pair tensor (see
%                      sample_nearfar_pairs).
%     bin_bounds, n_bins - histogram bin edges / counts (vislab.nat_stat_bayes.load_bin_bounds).
%     feature_list   - 1x20 flag vector selecting which features to histogram.
%     spot_llr_dims  - feature dims whose spot LLRs form col.spot (cfg.features.spot_dims).
%     edge_llr_dims  - feature dims whose edge LLRs form col.edge (cfg.features.edge_dv_dims).
%     power_suppress - weak Fourier-power suppression constant (beta) for the power DV.
%     edge_thresh    - gradient threshold for the edge histogram features (image units).
%     patch_size     - patch side length in pixels.
%     cfg            - config struct (uses cfg.norm.target_contrast, cfg.dv.sd1/nsd1/sd2/nsd2
%                      and cfg.features.spot_achr_dims).
%
%   All ten arguments are required and positional. The arguments block validates
%   class and attributes, plus a size only where the size is load-bearing (the
%   three scalars, and bin_bounds being a matrix); the vector shapes above are
%   documentation, not enforced, since no orientation here affects the result.
%
%   Outputs
%     R    - [n_kept x (numel(spot_llr_dims)+numel(edge_llr_dims)+3)] response matrix.
%     keep - original pair indices that survived outlier rejection.
%     col  - struct of column-index ranges into R (see above).
%
%   See also SAMPLE_NEARFAR_PAIRS, S5_TRAIN_DECISION_VARS

    arguments
        patches              {mustBeNumeric, mustBeReal}
        bin_bounds     (:,:) {mustBeNumeric, mustBeReal}
        n_bins               {mustBeInteger, mustBeNonnegative}
        feature_list         {mustBeMember(feature_list, [0, 1])}
        spot_llr_dims        {mustBeInteger, mustBePositive}
        edge_llr_dims        {mustBeInteger, mustBePositive}
        power_suppress (1,1) {mustBeNumeric, mustBeReal, mustBeNonnegative}
        edge_thresh    (1,1) {mustBeNumeric, mustBeReal, mustBeNonnegative}
        patch_size     (1,1) {mustBeInteger, mustBePositive}
        cfg            (1,1) struct
    end

    target_contrast = cfg.norm.target_contrast;
    lo = -25; hi = 25;
    n_pairs = size(patches, 4);
    n_spot = numel(spot_llr_dims);  n_edge = numel(edge_llr_dims);
    n_achr = numel(cfg.features.spot_achr_dims);
    col = struct('spot',       1:n_spot, ...
                 'spot_achr',  1:n_achr, ...
                 'spot_chrom', n_achr+1:n_spot, ...
                 'edge',       n_spot + (1:n_edge), ...
                 'power',      n_spot + n_edge + 1, ...
                 'border',     n_spot + n_edge + (2:3));
    R = zeros(n_pairs, n_spot + n_edge + 3);
    keep = zeros(n_pairs, 1);
    n = 0;
    for i = 1:n_pairs
        p1 = patches(1:patch_size, 1:patch_size, :, i);
        p2 = patches(1:patch_size, patch_size+1:2*patch_size, :, i);
        a1 = p1(:, :, 1);
        a2 = p2(:, :, 1);

        rp   = log(vislab.nat_stat_bayes.dv_power(a1, a2, power_suppress, patch_size));
        spot = vislab.nat_stat_bayes.dv_spot_hist(p1, p2, patch_size, bin_bounds, n_bins, ...
            feature_list);
        rh = log(spot(spot_llr_dims));

        a1 = vislab.lib.cntrst_norm(a1, target_contrast, patch_size);
        a2 = vislab.lib.cntrst_norm(a2, target_contrast, patch_size);
        border = vislab.nat_stat_bayes.dv_border(a1, a2, patch_size, 2, cfg.dv.sd1, cfg.dv.nsd1, ...
            false);
        edge   = vislab.nat_stat_bayes.dv_edge_hist(a1, a2, edge_thresh, bin_bounds, n_bins, ...
            cfg.dv.sd1, cfg.dv.nsd1, cfg.dv.sd2, cfg.dv.nsd2, feature_list);
        re = log(edge(edge_llr_dims));

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
