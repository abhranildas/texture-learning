function [near, far, col] = s5_train_decision_vars(cfg, ecc, eccb, autosave)
% S5_TRAIN_DECISION_VARS  Train the near/far decision-variable bounds from patch pairs.
%   s5_train_decision_vars(cfg, ecc)
%   s5_train_decision_vars(cfg, ecc, eccb)
%   s5_train_decision_vars(cfg, ecc, eccb, autosave)
%   [near, far, col] = s5_train_decision_vars(...)
%
%   autosave (optional) - true/false to save/skip without asking (used by
%   run_demo, which confirms once up front); omit to be asked interactively.
%
%   Optional outputs near, far are the full per-pair response matrices the bounds
%   were trained on; COL (struct, see pair_responses) gives the column layout, which
%   depends on cfg.features.color (3 spot columns achromatic-only, 5 with colour).
%   run_demo reuses near/far/col so the Stage 5 plots show exactly the points
%   training used.
%
%   Pipeline stage 5 (was nat_near_far_dv_2.m). Using the proximity proxy
%   (near = "same", far = "different"), computes the power, spot, edge and border
%   feature responses for all patch pairs, then trains quadratic decision bounds
%   (via classify_normals) for, in order: spot (h) -- in two steps (achromatic,
%   chromatic) then combined when cfg.features.color is true, see D3 in
%   docs/color-extension-plan.md -- edge (e), content (c = power+spot+edge),
%   border (b), and border+content (bc). Saves the struct of all bounds to
%   data/models/decision_bounds_ecc_<ecc>.mat (achromatic) or
%   decision_bounds_ecc_<ecc>_color.mat (colour) -- see decision_bounds_filename.
%
%   Run `setup` first; run stages 2-4 before. Requires IntClassNorm
%   (classify_normals, quad2fun).
%
%   Inputs
%     cfg  - config struct (see config.m).
%     ecc  - eccentricity downsample factor of the patch pairs (1,2,4,8).
%     eccb - eccentricity of the histogram bin bounds to use (default 1, matching the
%            original; set to ecc to use same-eccentricity bins -- flagged for Geisler).
%     autosave - see above; default asks interactively.
%
%   Outputs
%     near, far - full per-pair response matrices (rows = kept pairs; see pair_responses).
%     col       - struct of column-index ranges into near/far (see pair_responses).
%     dbnd (saved, not returned) - struct of trained quad2fun coefficient sets:
%       .h/.e/.c/.b/.bc (and .ha/.hb when colour is on), plus .spot_dims/.spot_achr_n.
%
%   NOTE: power suppression power_suppress = 16 here (training) and now also in the
%   content-similarity computation (cfg.dv.power_suppress=16) -- Geisler unified them
%   (2026-07; content-sim was 10). Outliers (|log DV| >= 25) are dropped, as in the
%   original.
%
%   See also PAIR_RESPONSES, DECISION_BOUNDS_FILENAME, LOAD_DV_HANDLES,
%   S23_LEARN_PRIORS_AND_PAIRS, S4_OPTIMIZE_BINS

    if nargin < 3 || isempty(eccb), eccb = 1; end
    patch_size  = cfg.patch.size / ecc;
    btype  = 5;                            % natural-image bound type
    power_suppress = 16;                   % weak-power suppression for training
    edge_thresh = cfg.dv.edge_thresh;
    spot_dims = cfg.features.spot_dims;    % [1 13 14] achromatic-only, +[2 3] with colour
    edge_dims = cfg.features.edge_dv_dims; % [5 9 10]

    feature_list = zeros(1, 20);  feature_list(cfg.features.dv_dims) = 1;
    cstat        = zeros(1, 20);  cstat(cfg.features.dv_dims) = btype;

    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds( ...
        cstat, eccb, double(cfg.optics.apply));
    % (LMS->ABR rotation is auto-loaded by apply_color_rotation from the shared store)

    pp = load(fullfile(cfg.paths.stimuli, sprintf('patch_pairs_ecc%d.mat', ecc)), ...
        'ptchn', 'ptchf', 'color');
    if ~isfield(pp, 'color') || pp.color ~= cfg.features.color
        error('s5_train_decision_vars:pairsModeMismatch', ...
        'patch_pairs_ecc%d.mat does not match cfg.features.color=%d -- rerun s23_learn_priors_and_pairs.', ...
            ecc, cfg.features.color);
    end

    % response matrices (columns given by COL: spot/edge/power/border), rows = kept pairs
    [near, ~, col] = pair_responses(pp.ptchn, bin_bounds, n_bins, feature_list, ...
        spot_dims, edge_dims, power_suppress, edge_thresh, patch_size, cfg);
    far = pair_responses(pp.ptchf, bin_bounds, n_bins, feature_list, ...
        spot_dims, edge_dims, power_suppress, edge_thresh, patch_size, cfg);
    fprintf('s5: %d near / %d far pairs kept after outlier rejection (of %d each)\n', ...
        size(near,1), size(far,1), size(pp.ptchn,4));

    % spot (h): achromatic-only trains one bound; with colour, train achromatic (ha) and
    % chromatic (hb) sub-bounds first, then a bound over the two resulting DVs (D3).
    if isempty(cfg.features.spot_chrom_dims)
        dbnd.h = train_bound(near(:, col.spot), far(:, col.spot));
        dvh = quad2fun(dbnd.h, 0);
    else
        dbnd.ha = train_bound(near(:, col.spot_achr),  far(:, col.spot_achr));
        dbnd.hb = train_bound(near(:, col.spot_chrom), far(:, col.spot_chrom));
        dvha = quad2fun(dbnd.ha, 0);
        dvhb = quad2fun(dbnd.hb, 0);
        spot_near = [apply_dv(dvha, near(:, col.spot_achr)), ...
            apply_dv(dvhb, near(:, col.spot_chrom))];
        spot_far  = [apply_dv(dvha, far(:,  col.spot_achr)), ...
            apply_dv(dvhb, far(:,  col.spot_chrom))];
        dbnd.h = train_bound(spot_near, spot_far);
        dvh_2d = quad2fun(dbnd.h, 0);
        n_achr = numel(cfg.features.spot_achr_dims);
        dvh = @(x) dvh_2d([dvha(x(1:n_achr)); dvhb(x(n_achr+1:end))]);
    end

    % edge (e): features cfg.features.edge_dv_dims
    dbnd.e = train_bound(near(:, col.edge), far(:, col.edge));
    dve = quad2fun(dbnd.e, 0);

    % content (c): [power, spot DV, edge DV]
    content_near = [near(:, col.power), apply_dv(dvh, near(:, col.spot)), ...
        apply_dv(dve, near(:, col.edge))];
    content_far  = [far(:, col.power),  apply_dv(dvh, far(:, col.spot)), ...
        apply_dv(dve, far(:, col.edge))];
    dbnd.c = train_bound(content_near, content_far);
    dvc = quad2fun(dbnd.c, 0);

    % border (b): the two border-response columns
    dbnd.b = train_bound(near(:, col.border), far(:, col.border));
    dvb = quad2fun(dbnd.b, 0);

    % border+content (bc): [content DV, border DV]
    bc_near = [apply_dv(dvc, content_near), ...
        apply_dv(dvb, near(:, col.border))];
    bc_far  = [apply_dv(dvc, content_far), ...
        apply_dv(dvb, far(:, col.border))];
    dbnd.bc = train_bound(bc_near, bc_far);

    % record the spot layout so load_dv_handles / the demo plots can tell how dbnd.h
    % must be applied, and catch a config/artifact mismatch loudly instead of silently
    dbnd.spot_dims   = cfg.features.spot_dims;
    dbnd.spot_achr_n = numel(cfg.features.spot_achr_dims);

    file = decision_bounds_filename(cfg, ecc);
    if nargin < 4 || isempty(autosave)
        reply = input(sprintf( ...
            's5: Save decision variables to disk and overwrite %s? (y/n): ', file), 's');
        do_save = strcmpi(reply, 'y');
    else
        do_save = autosave;
    end
    if do_save
        save(fullfile(cfg.paths.models, file), 'dbnd');
        fprintf('s5: trained + saved %s (%d near, %d far pairs)\n', ...
            file, size(near,1), size(far,1));
    else
        fprintf('s5: skipped saving decision variables.\n');
    end
end

% ------------------------------------------------------------------------------
function bd = train_bound(same, different)
% Sample-optimized quadratic bound between two response clouds. samp_balance=true so
% the SVM weights each class equally: outlier rejection leaves slightly unequal near/
% far counts, but the proximity proxy is a symmetric same/different task (50/50), so
% the bound must not tilt with that artifact.
    result = classify_normals(same, different, ...
        'input_type', 'samp', 'plotmode', 0, 'samp_balance', true);
    bd = result.samp_opt_bd;
end

% ------------------------------------------------------------------------------
function y = apply_dv(dv_fun, X)
% Apply a quad2fun decision-variable handle to each row of X.
    y = zeros(size(X, 1), 1);
    for i = 1:size(X, 1)
        y(i) = dv_fun(X(i, :)');
    end
end
