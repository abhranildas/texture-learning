function s23_learn_priors_and_pairs(cfg, ecc, autosave)
% S23_LEARN_PRIORS_AND_PAIRS  Learn natural feature priors AND build near/far patch
%   pairs in a single pass over the natural images (merges former stages 2 and 3).
%   s23_learn_priors_and_pairs(cfg, ecc)
%   s23_learn_priors_and_pairs(cfg, ecc, autosave)
%
%   autosave (optional) - true/false to save/skip without asking (used by run_demo,
%   which confirms once up front); omit to be asked interactively.
%
%   For each calibrated natural image -- loaded ONCE (optics, RGB->LMS, downsampled
%   to eccentricity ecc) -- this:
%     * samples isolated patches and accumulates the low-level feature values, then
%       forms the marginal CDFs (the paper's natural priors, Fig. 5), saved to
%       data/models/<prior_filename(cfg,ecc)>; and
%     * samples reference patches and forms near/far training pairs (proximity proxy),
%       saved to data/stimuli/patch_pairs_ecc<ecc>.mat.
%   Priors are eccentricity-dependent (ecc applies blur + downsampling, which changes
%   the feature statistics), so they are stored per ecc, computed from the same ecc
%   image as the pairs -- one image load feeds both.
%
%   Run `setup` first; run stage 1 (LMS->ABR rotation) before. ecc = 1, 2, 4, 8.
%
%   Inputs
%     cfg      - config struct (see config.m).
%     ecc      - eccentricity downsample factor (1, 2, 4, 8).
%     autosave - see above; default asks interactively.
%
%   See also LIST_NATURAL_IMAGES, SAMPLE_PRIOR_FEATURES, SAMPLE_NEARFAR_PAIRS,
%   FINALIZE_PRIORS, PRIOR_FILENAME, S1_LEARN_COLOR_TRANSFORM, S4_OPTIMIZE_BINS

    n_bins = 16000;                      % prior CDF resolution
    maxval = cfg.natural.max_val;
    patch_size = cfg.patch.size / ecc;   % patch size at this eccentricity

    coeff = cfg.color_rotation;          % LMS->ABR rotation from s1, for this optics setting
    if cfg.features.pca_gradient && isempty(cfg.pcgrad.model)
        error('s23:noGradientPCA', 'pca_gradient is on but %s is missing -- run s1b_learn_gradient_pca.', ...
            cfg.paths.gradient_pca);
    end

    files  = list_natural_images(cfg);
    n_prior = ceil(cfg.natural.target_isolated_patches   / numel(files));  % isolated patches/image
    n_pair  = ceil(cfg.natural.target_nearfar_references / numel(files));   % near/far refs / image

    % One independent image per iteration -> parfor (runs serially without the
    % Parallel Computing Toolbox). Each image is loaded ONCE and feeds both the
    % priors (isolated patches) and the near/far pairs.
    Sc      = cell(1, numel(files));
    ptchn_c = cell(1, numel(files));
    ptchf_c = cell(1, numel(files));
    parfor img_idx = 1:numel(files)
        [~, fname, fext] = fileparts(files{img_idx});
        fprintf('sampling %s\n', [fname, fext]);
        img = vislab.nat_stat_bayes.source_to_lms(files{img_idx}, cfg, ...
            struct('prescale', 255/maxval, 'ecc', ecc));
        Sc{img_idx} = sample_prior_features(img, n_prior, patch_size, cfg, coeff);
        [ptchn_c{img_idx}, ptchf_c{img_idx}] = sample_nearfar_pairs(img, n_pair, patch_size, cfg);
    end

    P = finalize_priors([Sc{:}], n_bins, coeff);   % marginal CDFs (the natural priors)
    ptchn = cat(4, ptchn_c{:});
    ptchf = cat(4, ptchf_c{:});
    pcnt  = size(ptchn, 4);

    prior_path = fullfile(cfg.paths.models, prior_filename(cfg, ecc));
    if ~isfolder(cfg.paths.stimuli), mkdir(cfg.paths.stimuli); end
    pairs_path = fullfile(cfg.paths.stimuli, sprintf('patch_pairs_ecc%d.mat', ecc));

    if nargin < 3 || isempty(autosave)
        reply = input(sprintf(['s23: Save feature priors (%s) and near/far pairs ' ...
            '(patch_pairs_ecc%d.mat)? (y/n): '], prior_filename(cfg, ecc), ecc), 's');
        do_save = strcmpi(reply, 'y');
    else
        do_save = autosave;
    end
    if do_save
        save(prior_path, '-struct', 'P');            % edges_*/cdf_* + coeff (see finalize_priors)
        fprintf('s23: saved priors to %s\n', prior_path);
        % The pairs do not depend on the features. With pca_gradient on, keep the
        % existing pairs for this colour/optics mode, so both models train on the
        % same pairs and the pca_gradient-off model's inputs are left untouched.
        keep_pairs = false;
        if cfg.features.pca_gradient, [~, keep_pairs] = load_patch_pairs(cfg, ecc); end
        if keep_pairs
            fprintf('s23: kept the existing near/far pairs in %s\n', pairs_path);
        else
            color  = cfg.features.color;   % saved so s4/s5 can catch a stale-mode reuse
            optics = cfg.optics.apply;     % (see load_patch_pairs)
            save(pairs_path, 'ptchn', 'ptchf', 'pcnt', 'color', 'optics');
            fprintf('s23: saved %d near/far pairs (ecc %d, color=%d) to %s\n', ...
                pcnt, ecc, cfg.features.color, pairs_path);
        end
    else
        fprintf('s23: skipped saving priors and patch pairs.\n');
    end
end
