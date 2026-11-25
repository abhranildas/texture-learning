function [acc, frac_exact, ari] = plot_stage7_pair_accuracy(cfg, ecc, n_images, texture_sets)
% PLOT_STAGE7_PAIR_ACCURACY  Per texture set, GTR discrimination vs segmentation,
%   and segmentation agreement (adjusted Rand index), one point per image.
%   [acc, frac_exact, ari] = plot_stage7_pair_accuracy(cfg, ecc, n_images, texture_sets)
%
%   Each GTR image is segmented with segment_image at the fixed parameters
%   cfg.segment. Its grouping criterion and mutual-similarity weight
%   (seg.stages.group_crit_best, .mutual_weight_best) are chosen from the image
%   alone, as those that best separate near pairs (treated as "same") from far
%   pairs (treated as "different") -- the proximity proxy.
%     acc        fraction of those near and far pairs whose true same/different
%                label (from the region map) is called correctly at that criterion
%                and weight (seg.accuracy_best). This is the accuracy (Bill's
%                pcmx0) whose per-set histograms Bill plots in test_ss_disc.m.
%     frac_exact fraction of the image's true regions that the segmentation
%                reproduces exactly (seg.n_correct / cfg.gtr.n_regions), as in stage 7a.
%     ari        adjusted Rand index of the segmentation against the true map
%                (segmentation.adjusted_rand_index): partial credit, 1 = perfect,
%                0 = chance.
%
%   Plot: one point per GTR image at (acc, ari), coloured by texture set, with a
%   shaded box per set spanning its mean +/- 1 SD on each axis. frac_exact is
%   returned but not plotted.
%
% Inputs
%   cfg       config struct (config.m); cfg.segment sets the per-image rule and
%             the fixed grouping parameters.
%   ecc       eccentricity downsample factor (1, 2, 4, 8).
%   n_images  GTR images per texture set (Bill's slides use 20).
%   texture_sets  texture sets to show (default 1:6): 1 Pertex, 2 Fabric, 3 Brodatz,
%             4 Brodatz+Fabric, 5 VisTex, 6 McGill.
% Outputs
%   acc, frac_exact, ari  [n_images x numel(texture_sets)], one column per texture set.
%
% See also SEGMENT_IMAGE, SEGMENTATION.ADJUSTED_RAND_INDEX, MAKE_GTR_IMAGE, PLOT_STAGE7
    if nargin < 4 || isempty(texture_sets), texture_sets = 1:6; end
    set_names = {'Pertex', 'Fabric', 'Brodatz', 'Brodatz + Fabric', 'VisTex', 'McGill'};
    names = set_names(texture_sets);
    n_sets = numel(texture_sets);

    [acc, frac_exact, ari] = deal(zeros(n_images, n_sets));
    for s = 1:n_sets
        fprintf('   %s: %d GTR images...\n', names{s}, n_images);
        [imgs, maps] = make_gtr_image(cfg, texture_sets(s), n_images, ecc);
        for k = 1:n_images
            seg = segment_image(cfg, imgs(:, :, :, k), maps(:, :, k));
            acc(k, s) = seg.accuracy_best;
            frac_exact(k, s) = seg.n_correct / cfg.gtr.n_regions;
            ari(k, s) = segmentation.adjusted_rand_index(maps(:, :, k), seg.est_map);
        end
    end

    colors = lines(n_sets);
    figure('Name', 'Stage 7b: GTR discrimination & segmentation performance', ...
        'Position', [150 250 750 600]);
    local_cloud(acc, ari, names, colors);
    ylabel('adjusted Rand index');
    title({'Stage 7b: GTR discrimination & segmentation performance', ...
        sprintf('one point per image (%d per set), box = mean \\pm 1 SD', n_images)});
end

% ------------------------------------------------------------------------------
function local_cloud(x, y, names, colors)
% Scatter one point per image (rows of x, y), one colour per texture set
% (columns), each set with a shaded box spanning its mean +/- 1 SD on each axis,
% and a legend naming the sets.
    hold on;
    h = gobjects(1, size(x, 2));
    for s = 1:size(x, 2)
        mx = mean(x(:, s));  sx = std(x(:, s));
        my = mean(y(:, s));  sy = std(y(:, s));
        patch(mx + sx * [-1 1 1 -1], my + sy * [-1 -1 1 1], colors(s, :), ...
            'FaceAlpha', 0.15, 'EdgeColor', colors(s, :), 'HandleVisibility', 'off');
        h(s) = scatter(x(:, s), y(:, s), 25, colors(s, :), 'filled', ...
            'MarkerFaceAlpha', 0.6, 'MarkerEdgeColor', 'none', 'DisplayName', names{s});
    end
    grid on;  axis padded;                     % keep points at 1.0 off the axis edge
    xlabel('same/diff accuracy of patch pairs');
    legend(h, 'Location', 'best');
end
