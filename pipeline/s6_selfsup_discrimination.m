function out = s6_selfsup_discrimination(cfg, method, texture_set, ecc, n_trials)
% S6_SELFSUP_DISCRIMINATION  Per-image self-supervised texture discrimination.
%   out = s6_selfsup_discrimination(cfg, method, texture_set, ecc)
%
%   Pipeline stage 6 (merges self_sup_train_bnd_{bc,bc_shft,c_shft}.m). For each
%   GTR image, computes content/border/mutual DVs for near & far pairs, applies a
%   per-image self-supervised step, and sweeps the grouping criterion group_crit
%   (paper gamma_l) x mutual-similarity weight mutual_weight (paper w_m) to produce
%   near-far and same-different accuracy surfaces. Returns the trial-averaged
%   surfaces.
%
%   method:
%     'bc'      - retrain the border+content bound on this image (classify_normals).
%     'bc_shft' - load the trained bc bound; learn a scalar shift of the bc DV.
%     'c_shft'  - load the trained bc bound; learn a scalar shift of the content DV.
%   texture_set: texture dataset (default per method: bc/bc_shft -> 3 Brodatz,
%   c_shft -> 1 Pertex).
%   ecc:   eccentricity (default 1).
%
%   Run `setup` first; requires stages 2,4,5 artifacts + IntClassNorm.
%   NOTE: the pupil diameter differs by method (bc = 4 mm, others = 8 mm) and the
%   bins are always the ecc-1 ones (bin_ecc = 1) -- preserved, flagged for Geisler
%   (see QUESTIONS_FOR_GEISLER.md).
%
%   Shared helpers (also used by s7): load_dv_handles, neighbor_far_responses,
%   self_sup_decision, nearfar_score_grid.
%
%   Inputs
%     cfg         - config struct (see config.m).
%     method      - 'bc', 'bc_shft' or 'c_shft' (see above; passed through to
%                   self_sup_decision).
%     texture_set - texture dataset selector (see load_texture_images); default per
%                   method.
%     ecc         - eccentricity downsample factor (1, 2, 4, 8); default 1.
%     n_trials    - number of GTR-image trials to average over; default 40.
%
%   Output
%     out - struct: .accuracy/.accuracy_same/.accuracy_diff/.accuracy_nearfar
%           (trial-averaged accuracy surfaces, n_crit x n_weight, see
%           nearfar_score_grid; Bill's pcav/pcsav/pcdav/pcnfav), .group_crit,
%           .mutual_weight (the swept grids), .method, .texture_set, .ecc.
%
%   See also LOAD_DV_HANDLES, NEIGHBOR_FAR_RESPONSES, SELF_SUP_DECISION,
%   NEARFAR_SCORE_GRID, MAKE_GTR_IMAGE, LOAD_TEXTURE_IMAGES, S7_SEGMENT_GTR

    mustBeMember(method, {'bc', 'bc_shft', 'c_shft'});
    % per-method settings: pupil diameter (mm), default texture set, and the
    % criterion / weight grids (step and max)
    switch method
        case 'bc'
            method_params = struct('pupil_diameter', 4, 'texture_set', 3, ...
                'group_crit_step', 0.4, 'group_crit_max', 4, ...
                'mutual_weight_step', 0.4, 'mutual_weight_max', 4, 'load_bc', false);
        case 'bc_shft'
            method_params = struct('pupil_diameter', 8, 'texture_set', 3, ...
                'group_crit_step', 0.8, 'group_crit_max', 8, ...
                'mutual_weight_step', 0.8, 'mutual_weight_max', 8, 'load_bc', true);
        case 'c_shft'
            method_params = struct('pupil_diameter', 8, 'texture_set', 1, ...
                'group_crit_step', 0.8, 'group_crit_max', 8, ...
                'mutual_weight_step', 0.8, 'mutual_weight_max', 8, 'load_bc', true);
    end
    if nargin < 3 || isempty(texture_set), texture_set = method_params.texture_set; end
    if nargin < 4 || isempty(ecc),   ecc = 1; end
    if nargin < 5 || isempty(n_trials), n_trials = 40; end   % trials per session
    bin_ecc = 1;                         % bin-bounds eccentricity (see note)
    cfg.optics.pupil_diameter = method_params.pupil_diameter;  % method-specific pupil for the OTF

    % feature_bound_type(f) > 0 selects feature f (5 = natural-image bins): spot + edge DV dims
    feature_bound_type = zeros(1,20); feature_bound_type(cfg.features.dv_dims) = 5;

    % artifacts: bin bounds + trained DV handles (LMS->ABR transform auto-loaded)
    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds( ...
        feature_bound_type, bin_ecc, bins_filename(cfg));
    dv = load_dv_handles(cfg, ecc, method_params.load_bc);

    % trial stimuli, and the patch-index -> grid row/col maps (row-major)
    [imgs, maps] = make_gtr_image(cfg, texture_set, n_trials, ecc);
    szp = cfg.gtr.szp;
    patch_x = repelem((1:szp)', szp);
    patch_y = repmat((1:szp)', szp, 1);

    % criterion / mutual-similarity-weight grid
    group_crit_vec = 0:method_params.group_crit_step:method_params.group_crit_max;
    n_crit = numel(group_crit_vec);
    mutual_weight_vec = 0:method_params.mutual_weight_step:method_params.mutual_weight_max;
    n_weight = numel(mutual_weight_vec);
    [accuracy, accuracy_same, accuracy_diff, accuracy_nearfar] = ...
        deal(zeros(n_crit, n_weight, n_trials));

    for trial = 1:n_trials
        pimg = imgs(:, :, :, trial);
        content_sim = segmentation.content_similarity_matrix(pimg, size(pimg,1)/cfg.gtr.szp, ...
            patch_x, patch_y, bin_bounds, n_bins, dv.spot, dv.edge, dv.content, cfg);
        mutual_sim = segmentation.mutual_similarity(content_sim, cfg.bill_compat);
        R = neighbor_far_responses(cfg, pimg, mutual_sim, maps(:,:,trial), bin_bounds, ...
            n_bins, dv);

        % per-image self-supervised step -> combined near/far decision variables
        [bc_near, bc_far] = self_sup_decision(method, R, dv);

        % sweep grouping criterion x mutual-similarity weight
        [accuracy(:,:,trial), accuracy_same(:,:,trial), accuracy_diff(:,:,trial), ...
            accuracy_nearfar(:,:,trial)] = ...
            nearfar_score_grid(bc_near, bc_far, R, group_crit_vec, mutual_weight_vec);
    end

    out.accuracy         = mean(accuracy,         3);
    out.accuracy_same    = mean(accuracy_same,    3);
    out.accuracy_diff    = mean(accuracy_diff,    3);
    out.accuracy_nearfar = mean(accuracy_nearfar, 3);
    out.group_crit = group_crit_vec;  out.mutual_weight = mutual_weight_vec;
    out.method = method;  out.texture_set = texture_set;  out.ecc = ecc;
    fprintf('s6 (%s, texture_set %d, ecc %d): best mean same/different accuracy %.3f\n', ...
        method, texture_set, ecc, max(out.accuracy,[],'all'));
end
