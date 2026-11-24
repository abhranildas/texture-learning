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
%                 sample_prior_features: .lms, .g1m/.g1o/.g1mo, .g2m/.g2o/.g2mo,
%                 .cs1/.cs2/.cs4 (and .pc1/.pc2/.pc3 with cfg.features.pca_gradient).
%     n_bins    - number of CDF bins (histcounts bin count).
%     coeff     - 3x3 LMS->ABR rotation matrix (from s1_learn_color_transform).
%
%   Output
%     P - struct whose fields are exactly the variables saved to the priors file
%         (see prior_filename): edges e*, cumulative N*, plus coeff. Fields are the
%         saved variable names and must not be renamed. Callers do
%         save(path, '-struct', 'P').
%
%   See also PRIOR_FILENAME, SAMPLE_PRIOR_FEATURES, S23_LEARN_PRIORS_AND_PAIRS

    abr_all = cat(1, img_feats.lms) * coeff;
    [P.Na, P.ea]    = histcounts(abr_all(:, 1),  n_bins, 'Normalization', 'cdf');
    [P.Nb, P.eb]    = histcounts(abr_all(:, 2),  n_bins, 'Normalization', 'cdf');
    [P.Nr, P.er]    = histcounts(abr_all(:, 3),  n_bins, 'Normalization', 'cdf');
    [P.Nm, P.em]    = histcounts(cat(1, img_feats.g1m),  n_bins, 'Normalization', 'cdf');
    [P.No, P.eo]    = histcounts(cat(1, img_feats.g1o),  n_bins, 'Normalization', 'cdf');
    [P.Nmo, P.emo]  = histcounts(cat(1, img_feats.g1mo), n_bins, 'Normalization', 'cdf');
    [P.Nm2, P.em2]  = histcounts(cat(1, img_feats.g2m),  n_bins, 'Normalization', 'cdf');
    [P.No2, P.eo2]  = histcounts(cat(1, img_feats.g2o),  n_bins, 'Normalization', 'cdf');
    [P.Nmo2, P.emo2]= histcounts(cat(1, img_feats.g2mo), n_bins, 'Normalization', 'cdf');
    [P.Ncs1, P.ecs1]= histcounts(cat(1, img_feats.cs1),  n_bins, 'Normalization', 'cdf');
    [P.Ncs2, P.ecs2]= histcounts(cat(1, img_feats.cs2),  n_bins, 'Normalization', 'cdf');
    [P.Ncs4, P.ecs4]= histcounts(cat(1, img_feats.cs4),  n_bins, 'Normalization', 'cdf');
    % gradient-PCA features (pca_gradient only): fields pc1.. -> Npc1/epc1, ...
    for j = 1:3
        f = sprintf('pc%d', j);
        if isfield(img_feats, f)
            [P.(['N' f]), P.(['e' f])] = histcounts(cat(1, img_feats.(f)), n_bins, ...
                'Normalization', 'cdf');
        end
    end
    P.coeff = coeff;
end
