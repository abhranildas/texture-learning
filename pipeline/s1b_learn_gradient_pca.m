function [gradient_pca, X] = s1b_learn_gradient_pca(cfg, autosave, one_image)
% S1B_LEARN_GRADIENT_PCA  Learn the multi-scale gradient PCs from natural images.
%   gradient_pca = s1b_learn_gradient_pca(cfg)
%   gradient_pca = s1b_learn_gradient_pca(cfg, autosave)
%   [gradient_pca, X] = s1b_learn_gradient_pca(cfg, autosave, one_image)
%
%   Pipeline stage 1b. Samples isolated patches from the natural images exactly as
%   the stage 2 priors do (source_to_lms, then sample_isolated_patches, rotated to
%   ABR, A channel, contrast-normalized), takes the horizontal and vertical
%   first-derivative responses at the scales cfg.pcgrad.sd_list on each isolated
%   patch (vislab.lib.multiscale_grad_responses, cropping the border the largest
%   kernel overlaps), and runs PCA jointly on all of them.
%   No H/V pairing is imposed: if the PCs come out in H/V pairs, the data did it.
%   With cfg.features.pca_gradient on, the model uses all three PC pairs
%   (vislab.lib.pc_grad_response): the magnitudes of PC1-2, PC3-4 and PC5-6 are the
%   PC large, mid and small gradient mag features. Saves struct gradient_pca (was
%   pcg) to cfg.paths.gradient_pca.
%
%   Inputs
%     cfg        config struct (uses cfg.pcgrad, cfg.color_rotation, cfg.natural).
%     autosave   true/false to save/skip without asking; omit to be asked.
%     one_image  true to sample only the first natural image (demo quick mode; the
%                result is then for display only and never saved). Default false.
%   Outputs
%     gradient_pca  struct: .coeff [2n x 2n] PCs as columns (each sign fixed so
%          its largest entry is positive), .mu [1 x 2n] response means, .explained (% variance),
%          .sd_list, .nsd, .n_images. Rows/channels are [H at sd_list, V at sd_list].
%     X    the sampled responses PCA was run on (rows = pixels), for the stage 1b
%          figure.
%
% See also PLOT_STAGE1B_GRADIENTS, VISLAB.LIB.PC_GRAD_RESPONSE, CONFIG

    if nargin < 3 || isempty(one_image), one_image = false; end
    sd_list = cfg.pcgrad.sd_list;  nsd = cfg.pcgrad.nsd;
    patch_size = cfg.patch.size;
    stride = 4;     % keep every 4th pixel in each direction: neighbouring responses are
                    % nearly redundant, and all of them would not fit in memory
    coeff_abr = cfg.color_rotation;
    target_contrast = cfg.norm.target_contrast;

    files = list_natural_images(cfg);
    if one_image, files = files(1); end
    n_samples = ceil(cfg.natural.target_isolated_patches / numel(files));
    fprintf('s1b: sampling %d patches from %d image(s)...\n', numel(files) * n_samples, ...
        numel(files));
    prescale = 255 / cfg.natural.max_val;
    Xc = cell(1, numel(files));
    if numel(files) > 1, nw = Inf; else, nw = 0; end   % one image: serial, no pool
    parfor (f = 1:numel(files), nw)
        img_lms = vislab.nat_stat_bayes.source_to_lms(files{f}, cfg, struct('prescale', prescale));
        patches = sample_isolated_patches(img_lms, n_samples, patch_size, cfg);
        Xf = cell(n_samples, 1);
        for k = 1:n_samples
            abr = vislab.nat_stat_bayes.apply_color_rotation(patches(:, :, :, k), coeff_abr);
            a = vislab.lib.cntrst_norm(abr(:, :, 1), target_contrast, patch_size);
            [R, crop] = vislab.lib.multiscale_grad_responses(a, sd_list, nsd);
            R = R(crop:stride:end-crop+1, crop:stride:end-crop+1, :);
            Xf{k} = reshape(R, [], size(R, 3));
        end
        Xc{f} = cat(1, Xf{:});
    end
    X = cat(1, Xc{:});

    [coeff, ~, ~, ~, explained, mu] = pca(X);
    [~, imax] = max(abs(coeff), [], 1);              % fix each PC's arbitrary sign
    sgn = sign(coeff(sub2ind(size(coeff), imax, 1:size(coeff, 2))));
    coeff = coeff .* sgn;
    gradient_pca = struct('coeff', coeff, 'mu', mu, 'explained', explained, ...
        'sd_list', sd_list, 'nsd', nsd, 'n_images', numel(files));

    % report each used PC's mean scale, to check which pair is the larger-scale one
    w = abs(coeff);
    scale = ([sd_list, sd_list] * w) ./ sum(w, 1);
    fprintf('s1b: PC mean scales (px) %s; variance explained %s %%\n', ...
        mat2str(round(scale, 2)), mat2str(round(explained', 1)));

    if one_image, return; end
    if nargin < 2 || isempty(autosave)
        do_save = strcmpi(input(sprintf('s1b: Save gradient PCA to %s? (y/n): ', ...
            cfg.paths.gradient_pca), 's'), 'y');
    else
        do_save = autosave;
    end
    if do_save
        save(cfg.paths.gradient_pca, 'gradient_pca');
        fprintf('s1b: saved %s\n', cfg.paths.gradient_pca);
    else
        fprintf('s1b: skipped saving the gradient PCA.\n');
    end
end
