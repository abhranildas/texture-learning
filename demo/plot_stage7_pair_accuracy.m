function [acc, frac_exact, ari] = plot_stage7_pair_accuracy(cfg, ecc, n_images, itypes)
% PLOT_STAGE7_PAIR_ACCURACY  Per texture set, GTR discrimination vs segmentation,
%   and segmentation agreement (adjusted Rand index), each mean +/- SD over images.
%   [acc, frac_exact, ari] = plot_stage7_pair_accuracy(cfg, ecc, n_images, itypes)
%
%   Each GTR image is segmented with segment_image at the fixed parameters
%   cfg.segment. Its grouping criterion gc and mutual-similarity weight wm are
%   chosen from the image alone, as those that best separate near pairs (treated
%   as "same") from far pairs (treated as "different") -- the proximity proxy.
%     acc        fraction of those near and far pairs whose true same/different
%                label (from the region map) is called correctly at that gc and wm
%                (seg.pcmx). This is the accuracy (pcmx0) whose per-set histograms
%                Bill plots in test_ss_disc.m.
%     frac_exact fraction of the image's true regions that the segmentation
%                reproduces exactly (seg.nrg / cfg.gtr.n_regions), as in stage 7a.
%     ari        adjusted Rand index of the segmentation against the true map
%                (segmentation.adjusted_rand_index): partial credit, 1 = perfect,
%                0 = chance.
%
%   Left plot: one point per texture set at (mean acc, mean frac_exact), labelled
%   with the set's name, in a shaded box spanning +/- 1 SEM on each axis. Right
%   plot: the same, with mean ARI on the y-axis. (SEM = SD / sqrt(n_images).)
%
% Inputs
%   cfg       config struct (config.m); cfg.segment sets the per-image rule and
%             the fixed grouping parameters.
%   ecc       eccentricity downsample factor (1, 2, 4, 8).
%   n_images  GTR images per texture set (Bill's slides use 20).
%   itypes    texture sets to show (default 1:6): 1 Pertex, 2 Fabric, 3 Brodatz,
%             4 Brodatz+Fabric, 5 VisTex, 6 McGill.
% Outputs
%   acc, frac_exact, ari  [n_images x numel(itypes)], one column per texture set.
%
% See also SEGMENT_IMAGE, SEGMENTATION.ADJUSTED_RAND_INDEX, MAKE_GTR_IMAGE, PLOT_STAGE7
    if nargin < 4 || isempty(itypes), itypes = 1:6; end
    set_names = {'Pertex', 'Fabric', 'Brodatz', 'Brodatz + Fabric', 'VisTex', 'McGill'};
    names = set_names(itypes);
    n_sets = numel(itypes);

    [acc, frac_exact, ari] = deal(zeros(n_images, n_sets));
    for s = 1:n_sets
        fprintf('   %s: %d GTR images...\n', names{s}, n_images);
        [imgs, maps] = make_gtr_image(cfg, itypes(s), n_images, ecc);
        for k = 1:n_images
            seg = segment_image(cfg, imgs(:, :, :, k), maps(:, :, k));
            acc(k, s) = seg.pcmx;
            frac_exact(k, s) = seg.nrg / cfg.gtr.n_regions;
            ari(k, s) = segmentation.adjusted_rand_index(maps(:, :, k), seg.emap);
        end
    end

    n_pairs = 2 * numel(seg.stages.same_near);   % near + far pairs per image
    colors = lines(n_sets);
    figure('Name', 'Stage 7b: GTR discrimination & segmentation performance', ...
        'Position', [150 250 1400 550]);

    % Both plots: x = pair accuracy; y = fraction exactly right (left) or ARI (right).
    % Each axis runs between round values just enclosing the boxes (local_hug),
    % with ticks only at those two limits.
    sem = @(v) std(v, 0, 1) / sqrt(size(v, 1));    % standard error of the mean
    mx = mean(acc, 1);  sx = sem(acc);
    x_ticks = local_hug(mx - sx, mx + sx);

    subplot(1, 2, 1);
    my = mean(frac_exact, 1);  sy = sem(frac_exact);
    local_box_scatter(mx, sx, my, sy, names, colors, x_ticks, local_hug(my - sy, my + sy));
    ylabel('fraction of regions correctly segmented');
    title({'Mean, box = \pm1 SEM', ...
        sprintf('%d images per set', ...
        n_images)});

    subplot(1, 2, 2);
    ma = mean(ari, 1);  sa = sem(ari);
    local_box_scatter(mx, sx, ma, sa, names, colors, x_ticks, local_hug(ma - sa, ma + sa));
    ylabel('adjusted Rand index');
    title({'Mean, box = \pm1 SEM', ...
        sprintf('%d images per set', n_images)});

    sgtitle('Stage 7b: GTR discrimination & segmentation performance');
end

% ------------------------------------------------------------------------------
function lims = local_hug(lo, hi)
% Round axis limits just enclosing [min(lo), max(hi)]: rounded down/up to a step
% of 1, 2 or 5 x 10^k, chosen so the data span about 3-10 steps.
    lo = min(lo);  hi = max(hi);
    if hi - lo < 1e-9                              % all data at one value: pad it
        pad = 0.1 * max(abs(lo), 1);
        lo = lo - pad;  hi = hi + pad;
    end
    span = hi - lo;
    step = 10 ^ floor(log10(span));
    if span / step < 3, step = step / 5; elseif span / step < 6, step = step / 2; end
    lims = [floor(lo / step) * step, ceil(hi / step) * step];
    lims = round(lims / step) * step;              % clear floating-point dust
end

% ------------------------------------------------------------------------------
function local_box_scatter(mx, sx, my, sy, names, colors, x_ticks, y_ticks)
% One labelled point per texture set at (mx, my), in a borderless shaded box
% spanning +/- (sx, sy); axis limits and ticks set to the given ticks' range.
    hold on;
    for s = 1:numel(mx)
        patch(mx(s) + sx(s) * [-1 1 1 -1], my(s) + sy(s) * [-1 -1 1 1], colors(s, :), ...
            'FaceAlpha', 0.25, 'EdgeColor', 'none');
        plot(mx(s), my(s), 'o', 'MarkerSize', 7, ...
            'MarkerFaceColor', colors(s, :), 'MarkerEdgeColor', colors(s, :));
        text(mx(s) + sx(s), my(s), ['  ' names{s}], 'Color', colors(s, :), ...
            'FontWeight', 'bold', 'VerticalAlignment', 'middle');
    end
    xlim(x_ticks([1 end]));  ylim(y_ticks([1 end]));
    set(gca, 'XTick', x_ticks, 'YTick', y_ticks);
    xlabel('same/diff accuracy of patch pairs');
end
