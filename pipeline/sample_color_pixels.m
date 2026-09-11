function pix = sample_color_pixels(img_lms, n_samples, cfg)
% SAMPLE_COLOR_PIXELS  Sample n_samples isolated patches from one LMS image and return
%   their normalized LMS pixel values.
%   pix = sample_color_pixels(img_lms, n_samples, cfg)
%
%   Returns [n_samples*patch_size^2 x 3], for the Stage 1 colour PCA. The single
%   definition of that per-image sampling (used by s1_learn_color_transform).
%
%   Inputs
%     img_lms   - [H x W x 3] LMS image.
%     n_samples - number of isolated patches to sample from this image.
%     cfg       - config struct (uses cfg.patch.size, cfg.norm.target_mean/target_contrast).
%
%   Output
%     pix - [n_samples*patch_size^2 x 3] normalized LMS pixel values (all patches
%           concatenated), pixels x LMS channel.
%
%   See also S1_LEARN_COLOR_TRANSFORM, SAMPLE_ISOLATED_PATCHES

    patch_size = cfg.patch.size;
    target_mean     = cfg.norm.target_mean;
    target_contrast = cfg.norm.target_contrast;
    n_colr    = 3;
    norm_type = 3;                                   % average-mean normalization

    [n_rows, n_cols, ~] = size(img_lms);
    pix = zeros(n_samples * patch_size^2, 3);
    n = 0;
    for k = 1:n_samples
        x = randi(n_rows - patch_size);
        y = randi(n_cols - patch_size);
        patch = vislab.lib.ptch_norm(img_lms(x:x+patch_size-1, y:y+patch_size-1, :), ...
            target_mean, target_contrast, norm_type, n_colr);
        pix(n+1 : n+patch_size^2, :) = reshape(patch, [], 3);
        n = n + patch_size^2;
    end
end
