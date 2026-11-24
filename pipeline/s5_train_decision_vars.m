function [near, far, col] = s5_train_decision_vars(cfg, ecc, bin_ecc, autosave)
% S5_TRAIN_DECISION_VARS  Train the near/far decision-variable bounds from patch pairs.
%   s5_train_decision_vars(cfg, ecc)
%   s5_train_decision_vars(cfg, ecc, bin_ecc)
%   s5_train_decision_vars(cfg, ecc, bin_ecc, autosave)
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
%   (via classify_normals) for, in order: spot -- in two steps (achromatic,
%   chromatic) then combined when cfg.features.color is true, see D3 in
%   docs/color-extension-plan.md -- edge, content (power + spot + edge), border,
%   and border+content. Saves the struct of all bounds to
%   data/models/decision_bounds_ecc_<ecc>.mat (achromatic) or
%   decision_bounds_ecc_<ecc>_color.mat (colour) -- see decision_bounds_filename.
%
%   Run `setup` first; run stages 2-4 before. Requires IntClassNorm
%   (classify_normals, quad2fun).
%
%   Inputs
%     cfg  - config struct (see config.m).
%     ecc  - eccentricity downsample factor of the patch pairs (1,2,4,8).
%     bin_ecc - eccentricity of the histogram bin bounds to use (default 1, matching
%            the original; set to ecc to use same-eccentricity bins -- flagged for
%            Geisler). Was eccb.
%     autosave - see above; default asks interactively.
%
%   Outputs
%     near, far - full per-pair response matrices (rows = kept pairs; see pair_responses).
%     col       - struct of column-index ranges into near/far (see pair_responses).
%     decision_bounds (saved, not returned) - struct of trained quad2fun coefficient
%       sets, one per decision variable (load_dv_handles turns each into dv.<name>):
%         .spot             spot DV bound (with colour: combines the two below)
%         .spot_achr, .spot_chrom  achromatic / chromatic spot sub-bounds (colour only)
%         .ms_grad          multi-scale gradient bound (pca_gradient only), over the
%                           first .n_ms_grad edge LLRs (see edge_dv_handle)
%         .edge, .content, .border, .border_content
%       plus the layout it was trained for: .spot_dims, .n_spot_achr (number of
%       achromatic spot dims), .edge_dims. Before item 0.3.12 this was dbnd with
%       fields h, ha, hb, pg, ms_n, e, c, b, bc, spot_achr_n (Bill's names).
%
%   NOTE: the power DV's weak-power suppression is cfg.dv.power_suppress, the same
%   constant segmentation uses (Bill's load_b0_nat, 5e-5). Outliers (|log DV| >= 25)
%   are dropped, as in the original.
%
%   See also PAIR_RESPONSES, DECISION_BOUNDS_FILENAME, LOAD_DV_HANDLES,
%   S23_LEARN_PRIORS_AND_PAIRS, S4_OPTIMIZE_BINS

    if nargin < 3 || isempty(bin_ecc), bin_ecc = 1; end
    patch_size  = cfg.patch.size / ecc;
    bound_type = 5;                        % histogram-bound type: natural images = 5
    power_suppress = cfg.dv.power_suppress;  % weak-power suppression, as at test
    edge_thresh = cfg.dv.edge_thresh;
    spot_dims = cfg.features.spot_dims;    % [1 13 14] achromatic-only, +[2 3] with colour
    edge_dims = cfg.features.edge_dv_dims; % [5 9 10 11]

    feature_list = zeros(1, 20);  feature_list(cfg.features.dv_dims) = 1;
    feature_bound_type = zeros(1, 20);     % per feature: > 0 selects it (load_bin_bounds)
    feature_bound_type(cfg.features.dv_dims) = bound_type;

    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds( ...
        feature_bound_type, bin_ecc, bins_filename(cfg));

    pp = load_patch_pairs(cfg, ecc);      % errors if built for another colour/optics mode

    % response matrices (columns given by COL: spot/edge/power/border), rows = kept pairs
    [near, ~, col] = pair_responses(pp.ptchn, bin_bounds, n_bins, feature_list, ...
        spot_dims, edge_dims, power_suppress, edge_thresh, patch_size, cfg);
    far = pair_responses(pp.ptchf, bin_bounds, n_bins, feature_list, ...
        spot_dims, edge_dims, power_suppress, edge_thresh, patch_size, cfg);
    fprintf('s5: %d near / %d far pairs kept after outlier rejection (of %d each)\n', ...
        size(near,1), size(far,1), size(pp.ptchn,4));

    % spot: achromatic-only trains one bound; with colour, train achromatic and
    % chromatic sub-bounds first, then a bound over the two resulting DVs (D3).
    if isempty(cfg.features.spot_chrom_dims)
        decision_bounds.spot = train_bound(near(:, col.spot), far(:, col.spot));
        spot_dv = quad2fun(decision_bounds.spot, 0);
    else
        decision_bounds.spot_achr  = train_bound(near(:, col.spot_achr),  far(:, col.spot_achr));
        decision_bounds.spot_chrom = train_bound(near(:, col.spot_chrom), far(:, col.spot_chrom));
        spot_achr_dv = quad2fun(decision_bounds.spot_achr, 0);
        spot_chrom_dv = quad2fun(decision_bounds.spot_chrom, 0);
        spot_near = [apply_dv(spot_achr_dv, near(:, col.spot_achr)), ...
            apply_dv(spot_chrom_dv, near(:, col.spot_chrom))];
        spot_far  = [apply_dv(spot_achr_dv, far(:,  col.spot_achr)), ...
            apply_dv(spot_chrom_dv, far(:,  col.spot_chrom))];
        decision_bounds.spot = train_bound(spot_near, spot_far);
        spot_combine_dv = quad2fun(decision_bounds.spot, 0);
        n_achr = numel(cfg.features.spot_achr_dims);
        spot_dv = @(x) spot_combine_dv([spot_achr_dv(x(1:n_achr)); ...
            spot_chrom_dv(x(n_achr+1:end))]);
    end

    % edge: features cfg.features.edge_dv_dims. With pca_gradient, the 1 px edge mag
    % and the three PC gradient mag LLRs (col.ms_grad, first in col.edge) are first
    % merged by their own bound, the multi-scale gradient DV (ms_grad),
    % which then joins the bar LLRs as the edge DV's inputs.
    if isempty(cfg.features.ms_grad_dims)
        decision_bounds.edge = train_bound(near(:, col.edge), far(:, col.edge));
        edge_dv = quad2fun(decision_bounds.edge, 0);
    else
        decision_bounds.ms_grad = train_bound(near(:, col.ms_grad), far(:, col.ms_grad));
        decision_bounds.n_ms_grad = numel(col.ms_grad);  % inputs to ms_grad (edge_dv_handle)
        ms_grad_dv = quad2fun(decision_bounds.ms_grad, 0);
        rest = setdiff(col.edge, col.ms_grad, 'stable');
        decision_bounds.edge = train_bound( ...
            [apply_dv(ms_grad_dv, near(:, col.ms_grad)), near(:, rest)], ...
            [apply_dv(ms_grad_dv, far(:,  col.ms_grad)), far(:,  rest)]);
        edge_dv = edge_dv_handle(decision_bounds);
    end

    % content: [power, spot DV, edge DV]
    content_near = [near(:, col.power), apply_dv(spot_dv, near(:, col.spot)), ...
        apply_dv(edge_dv, near(:, col.edge))];
    content_far  = [far(:, col.power),  apply_dv(spot_dv, far(:, col.spot)), ...
        apply_dv(edge_dv, far(:, col.edge))];
    decision_bounds.content = train_bound(content_near, content_far);
    content_dv = quad2fun(decision_bounds.content, 0);

    % border: the two border-response columns
    decision_bounds.border = train_bound(near(:, col.border), far(:, col.border));
    border_dv = quad2fun(decision_bounds.border, 0);

    % border+content: [content DV, border DV]
    bc_near = [apply_dv(content_dv, content_near), ...
        apply_dv(border_dv, near(:, col.border))];
    bc_far  = [apply_dv(content_dv, content_far), ...
        apply_dv(border_dv, far(:, col.border))];
    decision_bounds.border_content = train_bound(bc_near, bc_far);

    % record the spot layout so load_dv_handles / the demo plots can tell how
    % decision_bounds.spot must be applied, and catch a config/artifact mismatch
    % loudly instead of silently
    decision_bounds.spot_dims   = cfg.features.spot_dims;
    decision_bounds.n_spot_achr = numel(cfg.features.spot_achr_dims);
    decision_bounds.edge_dims   = cfg.features.edge_dv_dims;

    file = decision_bounds_filename(cfg, ecc);
    if nargin < 4 || isempty(autosave)
        reply = input(sprintf( ...
            's5: Save decision variables to disk and overwrite %s? (y/n): ', file), 's');
        do_save = strcmpi(reply, 'y');
    else
        do_save = autosave;
    end
    if do_save
        save(fullfile(cfg.paths.models, file), 'decision_bounds');
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
