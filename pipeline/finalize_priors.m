function P = finalize_priors(img_feats, n_bins, coeff)
% FINALIZE_PRIORS  Turn per-image feature samples into the natural-prior marginal CDFs.
%   P = finalize_priors(img_feats, n_bins, coeff)
%
%   Turns the per-image feature samples (a struct array from sample_prior_features,
%   one element per image) into the marginal CDFs -- the natural priors that Stage 23
%   saves. Used by s23_learn_priors_and_pairs.
%
%   Inputs
%     img_feats - struct array (one element per natural image), fields as returned by
%                 sample_prior_features: .lms, .edge_mag/.edge_ori/.edge_mag_ori,
%                 .bar_mag/.bar_ori/.bar_mag_ori, .cs_ratio_small/.cs_linear_small/
%                 .cs_linear_large (and .pc1/.pc2/.pc3 with cfg.features.pca_gradient).
%     n_bins    - number of CDF bins (histcounts bin count).
%     coeff     - 3x3 LMS->ABR rotation matrix (from s1_learn_color_transform).
%
%   Output
%     P - struct whose fields are exactly the variables saved to the priors file
%         (see prior_filename): for each feature <name>, edges_<name> (the
%         n_bins+1 bin edges, in the feature's own units) and cdf_<name> (the
%         cumulative probability at each upper edge), plus coeff. <name> is a_pixel,
%         b_pixel, r_pixel (the ABR channels), the img_feats field names above, and
%         pc1..pc3. Callers do save(path, '-struct', 'P'); readers (s4_optimize_bins,
%         demo/plot_stage2) use the same names. Before item 0.3.12 these were
%         N<tag>/e<tag> (e.g. Na/ea); tools/migrate_saved_names converts old files.
%
%   See also PRIOR_FILENAME, SAMPLE_PRIOR_FEATURES, S23_LEARN_PRIORS_AND_PAIRS

    abr_all = cat(1, img_feats.lms) * coeff;
    [P.cdf_a_pixel, P.edges_a_pixel] = histcounts(abr_all(:, 1), n_bins, 'Normalization', 'cdf');
    [P.cdf_b_pixel, P.edges_b_pixel] = histcounts(abr_all(:, 2), n_bins, 'Normalization', 'cdf');
    [P.cdf_r_pixel, P.edges_r_pixel] = histcounts(abr_all(:, 3), n_bins, 'Normalization', 'cdf');
    [P.cdf_edge_mag, P.edges_edge_mag] = histcounts(cat(1, img_feats.edge_mag), n_bins, ...
        'Normalization', 'cdf');
    [P.cdf_edge_ori, P.edges_edge_ori] = histcounts(cat(1, img_feats.edge_ori), n_bins, ...
        'Normalization', 'cdf');
    [P.cdf_edge_mag_ori, P.edges_edge_mag_ori] = histcounts(cat(1, img_feats.edge_mag_ori), ...
        n_bins, 'Normalization', 'cdf');
    [P.cdf_bar_mag, P.edges_bar_mag] = histcounts(cat(1, img_feats.bar_mag), n_bins, ...
        'Normalization', 'cdf');
    [P.cdf_bar_ori, P.edges_bar_ori] = histcounts(cat(1, img_feats.bar_ori), n_bins, ...
        'Normalization', 'cdf');
    [P.cdf_bar_mag_ori, P.edges_bar_mag_ori] = histcounts(cat(1, img_feats.bar_mag_ori), ...
        n_bins, 'Normalization', 'cdf');
    [P.cdf_cs_ratio_small, P.edges_cs_ratio_small] = histcounts( ...
        cat(1, img_feats.cs_ratio_small), n_bins, 'Normalization', 'cdf');
    [P.cdf_cs_linear_small, P.edges_cs_linear_small] = histcounts( ...
        cat(1, img_feats.cs_linear_small), n_bins, 'Normalization', 'cdf');
    [P.cdf_cs_linear_large, P.edges_cs_linear_large] = histcounts( ...
        cat(1, img_feats.cs_linear_large), n_bins, 'Normalization', 'cdf');
    % gradient-PCA features (pca_gradient only): fields pc1.. -> cdf_pc1/edges_pc1, ...
    for j = 1:3
        f = sprintf('pc%d', j);
        if isfield(img_feats, f)
            [P.(['cdf_' f]), P.(['edges_' f])] = histcounts(cat(1, img_feats.(f)), n_bins, ...
                'Normalization', 'cdf');
        end
    end
    P.coeff = coeff;
end
