function patches = sample_isolated_patches(img_lms, n_samples, patch_size, cfg)
% SAMPLE_ISOLATED_PATCHES  Cut n_samples random mean-normalized isolated patches from one image.
%   patches = sample_isolated_patches(img_lms, n_samples, patch_size, cfg)
%
%   The single definition of isolated-patch sampling, shared by the natural-prior
%   stage (s23_learn_priors_and_pairs, via sample_prior_features) and the multi-scale
%   gradient figure (demo/plot_stage1b_gradients) so both draw the SAME kind of
%   patch with the SAME preprocessing. Patches are mean-normalized (ptch_norm
%   type 3: scale the whole patch to the average channel mean); they are NOT
%   contrast-normalized or colour-rotated -- callers rotate to ABR / take the A
%   channel / contrast-normalize as each needs.
%
%   Inputs
%     img_lms    - [H x W x 3] LMS image (at the target eccentricity).
%     n_samples  - number of isolated patches to sample from this image.
%     patch_size - patch size in pixels (cfg.patch.size / ecc).
%     cfg        - config struct (normalization targets).
%
%   Output
%     patches - [patch_size x patch_size x 3 x n_samples] mean-normalized LMS patches.
%
%   See also SAMPLE_PRIOR_FEATURES, SAMPLE_COLOR_PIXELS

    target_mean     = cfg.norm.target_mean;
    target_contrast = cfg.norm.target_contrast;      % unused by norm_type 3; passed for signature
    [n_rows, n_cols, ~] = size(img_lms);
    patches = zeros(patch_size, patch_size, 3, n_samples);
    for k = 1:n_samples
        x = randi(n_rows - patch_size);
        y = randi(n_cols - patch_size);
        patches(:, :, :, k) = vislab.lib.ptch_norm( ...
            img_lms(x:x+patch_size-1, y:y+patch_size-1, :), target_mean, target_contrast, 3, 3);
    end
end
