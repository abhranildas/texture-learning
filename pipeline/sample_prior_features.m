function s = sample_prior_features(img_lms, n_samples, patch_size, cfg, coeff)
% SAMPLE_PRIOR_FEATURES  Sample n_samples isolated patches from one LMS image and return
%   the raw feature values used to build the natural priors (Stage 23). This is the
%   single definition of that per-image sampling, used by s23_learn_priors_and_pairs.
%
%   Inputs
%     img_lms    - [H x W x 3] LMS image (at the target eccentricity).
%     n_samples  - number of isolated patches to sample from this image.
%     patch_size - patch size in pixels (cfg.patch.size / ecc).
%     cfg        - config struct (normalization).
%     coeff      - LMS->ABR rotation (from Stage 1).
%
%   Output s (columns of sampled values for this image; field names match
%   finalize_priors' inputs and the priors-file names):
%     .lms  [n x 3]      normalized LMS pixels (for the ABR colour-channel CDFs)
%     .edge_mag .edge_ori .edge_mag_ori
%                        1st-derivative (edge) steerable magnitude / orientation /
%                        (mag x ori); features 5-7. Locals g1m/g1o/g1mo below.
%     .bar_mag .bar_ori .bar_mag_ori
%                        2nd-derivative (bar) steerable magnitude / orientation /
%                        (mag x ori); features 9-11. Locals g2m/g2o/g2mo below.
%     .cs_ratio_small .cs_linear_small .cs_linear_large
%                        center-surround ratio / small-linear / large-linear;
%                        features 12-14 (vislab.lib.center_surround types 1, 2, 4)
%     .pc1 .pc2 .pc3     PC large / mid / small gradient magnitude, features 15-17
%                        (only with cfg.features.pca_gradient;
%                        vislab.lib.pc_grad_response)
%
%   See also SAMPLE_ISOLATED_PATCHES, FINALIZE_PRIORS, S23_LEARN_PRIORS_AND_PAIRS

    target_contrast = cfg.norm.target_contrast;
    thresh    = 0;                       % keep gradient pixels above this (exclude exact zeros)
    sd1 = cfg.dv.sd1; nsd1 = cfg.dv.nsd1; sd2 = cfg.dv.sd2; nsd2 = cfg.dv.nsd2;
    swid = 3;                            % center-surround window (cs_type 4 uses a fixed 5x5)

    % isolated patches (mean-normalized), via the shared sampler used by stage 1b too
    patches = sample_isolated_patches(img_lms, n_samples, patch_size, cfg);
    cap = n_samples * patch_size^2;      % generous per-image upper bound

    lms   = zeros(cap, 3);   n_lms = 0;
    g1m   = zeros(cap, 1);   g1o = zeros(cap, 1);  g1mo = zeros(cap, 1);  n_g1 = 0;
    g2m   = zeros(cap, 1);   g2o = zeros(cap, 1);  g2mo = zeros(cap, 1);  n_g2 = 0;
    cs1v  = zeros(cap, 1);   n_cs1 = 0;
    cs2v  = zeros(cap, 1);   n_cs2 = 0;
    cs4v  = zeros(cap, 1);   n_cs4 = 0;
    use_pc = cfg.features.pca_gradient;
    n_pairs = numel(cfg.features.pc_grad_dims);   % PC gradient pairs (features 15-17)
    pcv = zeros(cap, n_pairs);  n_pc = zeros(1, n_pairs);   % allocated only when used

    for k = 1:n_samples
        patch = patches(:, :, :, k);

        % accumulate LMS pixel values (for the colour-channel CDFs after rotation)
        lms(n_lms+1 : n_lms+patch_size^2, :) = reshape(patch, [], 3);
        n_lms = n_lms + patch_size^2;

        % achromatic (A) channel in ABR space, contrast-normalized
        abr = vislab.nat_stat_bayes.apply_color_rotation(patch, coeff);
        a = vislab.lib.cntrst_norm(abr(:, :, 1), target_contrast, patch_size);

        % 1st-derivative steerable responses (keep above-threshold)
        [gm, go] = vislab.lib.steerable_grad_response(a, sd1, nsd1);
        keep = gm > thresh;
        vals = gm(keep); ori = go(keep); m = numel(vals);
        g1m(n_g1+1:n_g1+m)  = vals;
        g1o(n_g1+1:n_g1+m)  = ori;
        g1mo(n_g1+1:n_g1+m) = vals .* ori;
        n_g1 = n_g1 + m;

        % 2nd-derivative steerable responses (all pixels)
        [gm2, go2] = vislab.lib.grad2_response(a, sd2, nsd2);
        m2 = numel(gm2);
        g2m(n_g2+1:n_g2+m2)  = gm2(:);
        g2o(n_g2+1:n_g2+m2)  = go2(:);
        g2mo(n_g2+1:n_g2+m2) = gm2(:) .* go2(:);
        n_g2 = n_g2 + m2;

        % center-surround responses (ratio, small linear, large linear)
        cs = vislab.lib.center_surround(a, swid, 1);
        nc = numel(cs); cs1v(n_cs1+1:n_cs1+nc) = cs(:); n_cs1 = n_cs1 + nc;
        cs = vislab.lib.center_surround(a, swid, 2);
        nc = numel(cs); cs2v(n_cs2+1:n_cs2+nc) = cs(:); n_cs2 = n_cs2 + nc;
        cs = vislab.lib.center_surround(a, swid, 4);
        nc = numel(cs); cs4v(n_cs4+1:n_cs4+nc) = cs(:); n_cs4 = n_cs4 + nc;

        % learned multi-scale gradient PC magnitudes (keep above-threshold, as g1m)
        if use_pc
            mags = vislab.lib.pc_grad_response(a, cfg.pcgrad.model, n_pairs);
            for j = 1:n_pairs
                v = mags(:, :, j);  v = v(v > thresh);
                pcv(n_pc(j)+1:n_pc(j)+numel(v), j) = v;  n_pc(j) = n_pc(j) + numel(v);
            end
        end
    end

    s.lms  = lms(1:n_lms, :);
    s.edge_mag = g1m(1:n_g1);  s.edge_ori = g1o(1:n_g1);  s.edge_mag_ori = g1mo(1:n_g1);
    s.bar_mag  = g2m(1:n_g2);  s.bar_ori  = g2o(1:n_g2);  s.bar_mag_ori  = g2mo(1:n_g2);
    s.cs_ratio_small  = cs1v(1:n_cs1);
    s.cs_linear_small = cs2v(1:n_cs2);
    s.cs_linear_large = cs4v(1:n_cs4);
    if use_pc
        for j = 1:n_pairs, s.(sprintf('pc%d', j)) = pcv(1:n_pc(j), j); end
    end
end
