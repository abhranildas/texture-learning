function [near, far, col] = compute_demo_responses(cfg, ecc)
% COMPUTE_DEMO_RESPONSES  Per-pair power/spot/edge/border responses for the Stage 5
%   plots in QUICK mode.
%   [near, far, col] = compute_demo_responses(cfg, ecc)
%
%   Since quick mode uses the shipped bounds without training (and so has no
%   training points to reuse), it samples near/far pairs from a single natural
%   image via sample_demo_pairs (same optics/domain/distance rules as Stage 3)
%   and computes their responses. (Full mode instead reuses the exact pairs s5
%   trained on.)
%
% Inputs
%   cfg  - config struct.
%   ecc  - eccentricity divisor (patch geometry is divided by this).
% Output
%   near, far - [nPairs x nFeatures] response matrices (pair_responses format).
%   col       - column-layout struct from pair_responses, giving the
%               response-matrix column layout shared by near and far.
%
% See also PAIR_RESPONSES, SAMPLE_DEMO_PAIRS, PLOT_STAGE5, PLOT_STAGE5_INTERMEDIATE
    btype         = 5;
    power_suppress = cfg.dv.power_suppress;
    edge_thresh    = cfg.dv.edge_thresh;
    patch_size     = cfg.patch.size / ecc;
    spot_llr_dims  = cfg.features.spot_dims;
    edge_llr_dims  = cfg.features.edge_dv_dims;

    feature_list = zeros(1, 20);  feature_list(cfg.features.dv_dims) = 1;
    cstat        = zeros(1, 20);  cstat(cfg.features.dv_dims) = btype;
    eccb = 1;

    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds(cstat, eccb, ...
        double(cfg.optics.apply));

    [ptchn_sub, ptchf_sub] = sample_demo_pairs(cfg, ecc);
    if isempty(ptchn_sub)
        fprintf('No natural images found; skipping Stage 5 response plots.\n');
        near = []; far = []; col = []; return;
    end

    [near, ~, col] = pair_responses(ptchn_sub, bin_bounds, n_bins, feature_list, ...
        spot_llr_dims, edge_llr_dims, power_suppress, edge_thresh, patch_size, cfg);
    far            = pair_responses(ptchf_sub, bin_bounds, n_bins, feature_list, ...
        spot_llr_dims, edge_llr_dims, power_suppress, edge_thresh, patch_size, cfg);
end
