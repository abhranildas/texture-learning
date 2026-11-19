function plot_stage6_pairs(cfg, ecc)
% PLOT_STAGE6_PAIRS  Qualitative same/different discrimination on random texture
%   pairs, using the shipped Stage 5 decision variables (dv.h, dv.e, dv.c, dv.b,
%   dv.bc).
%   plot_stage6_pairs(cfg, ecc)
%
%   For each pair, shows the two patches side by side together with the
%   ground truth (same/different sheet) and the model's combined border+content
%   decision (dv.bc thresholded at 0, as in plot_stage5's final panel). Also prints
%   the same-different accuracy over the shown pairs.
%
%   Database: Brodatz (grayscale) when cfg.features.color is false, matching the
%   published achromatic demo; Fabric (colour) when cfg.features.color is true --
%   Brodatz is grayscale (R=G=B), so it carries no chromatic signal to show off the
%   colour spot DV (see docs/color-extension-plan.md).
%
% Inputs
%   cfg  - config struct.
%   ecc  - eccentricity divisor (patch geometry is divided by it).
% Output
%   none (draws the figure; prints the same-different accuracy to stdout)
%
% See also PLOT_STAGE3, LOCAL_SHOW_PAIR, PAIR_RESPONSES, LOAD_DV_HANDLES, SAMPLE_TEXTURE_PAIRS
    n_show         = 10;
    btype          = 5;
    power_suppress = cfg.dv.power_suppress;
    edge_thresh    = cfg.dv.edge_thresh;
    patch_size     = cfg.patch.size / ecc;
    spot_llr_dims  = cfg.features.spot_dims;
    edge_llr_dims  = cfg.features.edge_dv_dims;

    if cfg.features.color
        itype = 2;  db_name = 'Fabric';
    else
        itype = 3;  db_name = 'Brodatz';
    end

    feature_list = zeros(1, 20);  feature_list(cfg.features.dv_dims) = 1;
    cstat        = zeros(1, 20);  cstat(cfg.features.dv_dims) = btype;
    eccb = 1;
    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds(cstat, eccb, ...
        bins_filename(cfg));

    try
        dv = load_dv_handles(cfg, ecc, true);
    catch
        fprintf('No trained decision bounds found; skipping Stage 6 pair demo.\n');
        return;
    end

    fprintf('Drawing %d random %s texture pairs and applying the trained border+content\n', ...
        n_show, db_name);
    fprintf('decision variable (Stages 1-5) to each.\n');

    % oversample candidates: pair_responses drops rare outlier pairs, so draw a few
    % extra and keep the first n_show that survive.
    [ptch, same_gt] = sample_texture_pairs(cfg, ecc, n_show + 5, itype);
    [R, keep, col] = pair_responses(ptch, bin_bounds, n_bins, feature_list, ...
        spot_llr_dims, edge_llr_dims, power_suppress, edge_thresh, patch_size, cfg);
    n_show = min(n_show, size(R, 1));
    R = R(1:n_show, :);
    ptch = ptch(:, :, :, keep(1:n_show));
    same_gt = same_gt(keep(1:n_show));

    content = [R(:, col.power), apply_dv(dv.h, R(:, col.spot)), apply_dv(dv.e, R(:, col.edge))];
    content_dv = apply_dv(dv.c, content);
    border_dv  = apply_dv(dv.b, R(:, col.border));
    model_dv   = apply_dv(dv.bc, [content_dv, border_dv]);
    model_same = model_dv >= 0;

    acc = 100 * mean(same_gt == model_same);
    fprintf('\nStage 6 Result: same-different accuracy on these %d %s pairs = %.1f%%\n', ...
        n_show, db_name, acc);

    figure('Name', sprintf('Stage 6: Same/Different Discrimination on %s Pairs', db_name), ...
        'Position', [200 100 500 950]);
    nrow = ceil(n_show / 2);
    for pair_idx = 1:n_show
        subplot(nrow, 2, pair_idx);
        local_show_pair(cfg, ptch(:, 1:patch_size, :, pair_idx), ...
            ptch(:, patch_size+1:2*patch_size, :, pair_idx));
        gt_str    = ternary(same_gt(pair_idx),    'Same', 'Diff');
        model_str = ternary(model_same(pair_idx), 'Same', 'Diff');
        if same_gt(pair_idx) == model_same(pair_idx), col_ = [0 0.6 0]; else, col_ = [0.8 0 0]; end
        title(sprintf('GT: %s | Model: %s', gt_str, model_str), 'Color', col_, 'FontSize', 9);
    end
    sgtitle(sprintf('Stage 6: Same/Different Discrimination on Random %s Texture Pairs (Accuracy: %.1f%%)', db_name, acc));
end

% ------------------------------------------------------------------------------
function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
