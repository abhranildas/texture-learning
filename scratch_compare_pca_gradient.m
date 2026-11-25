% SCRATCH_COMPARE_PCA_GRADIENT  One-off: does adding the PCA gradient features
%   improve GTR performance? Segments the same GTR images with the model
%   without and with the PCA gradients (colour off, optics off -- the trained
%   pair), and plots pair accuracy vs ARI for each texture set.
%   Run from the repo root after `setup`. Delete when done.
%   Set n_images = 1 for a quick check.

n_images = 20;  texture_sets = 1:6;  ecc = 1;  seed = 1;
set_names = {'Pertex', 'Fabric', 'Brodatz', 'Brodatz + Fabric', 'VisTex', 'McGill'};
cfgs = {config(false, false, [], false), config(false, false, [], true)};
n_sets = numel(texture_sets);
[acc, ari] = deal(zeros(n_images, n_sets, 2));    % image x set x (without, with)

for s = 1:n_sets
    fprintf('%s: %d GTR images\n', set_names{texture_sets(s)}, n_images);
    % images depend on optics only, so one stack serves both models
    [imgs, maps] = make_gtr_image(cfgs{1}, texture_sets(s), n_images, ecc, seed + s);
    for k = 1:n_images
        for m = 1:2
            seg = segment_image(cfgs{m}, imgs(:, :, :, k), maps(:, :, k));
            acc(k, s, m) = seg.accuracy_best;
            ari(k, s, m) = segmentation.adjusted_rand_index(maps(:, :, k), seg.est_map);
        end
    end
end
save('scratch_compare_pca_gradient_results.mat', 'acc', 'ari', 'texture_sets', ...
    'n_images', 'seed');

% ---- plot ----
sem = @(v) std(v, 0, 1) / sqrt(size(v, 1));
colors = lines(n_sets);
figure('Name', 'PCA gradient: without vs with', 'Position', [150 250 1300 550]);

% left: mean (acc, ARI) without -> with, boxes = +/- 1 SEM
subplot(1, 2, 1); hold on;
for s = 1:n_sets
    for m = 1:2
        mx = mean(acc(:, s, m));  sx = sem(acc(:, s, m));
        my = mean(ari(:, s, m));  sy = sem(ari(:, s, m));
        patch(mx + sx * [-1 1 1 -1], my + sy * [-1 -1 1 1], colors(s, :), ...
            'FaceAlpha', 0.12 + 0.13 * (m == 2), 'EdgeColor', 'none');
    end
    x = squeeze(mean(acc(:, s, :), 1));  y = squeeze(mean(ari(:, s, :), 1));
    quiver(x(1), y(1), x(2) - x(1), y(2) - y(1), 0, 'Color', colors(s, :), ...
        'LineWidth', 1.5, 'MaxHeadSize', 0.5);
    plot(x(1), y(1), 'o', 'Color', colors(s, :));
    plot(x(2), y(2), 'o', 'MarkerFaceColor', colors(s, :), 'MarkerEdgeColor', colors(s, :));
    text(x(2), y(2), ['  ' set_names{texture_sets(s)}], 'Color', colors(s, :), ...
        'FontWeight', 'bold');
end
xlabel('same/diff accuracy of patch pairs');  ylabel('adjusted Rand index');
title({'without (open) \rightarrow with (filled) PCA gradients', ...
    sprintf('mean, box = \\pm1 SEM, %d images per set', n_images)});

% right: paired change per set, mean +/- 1 SEM of the per-image differences
subplot(1, 2, 2); hold on;
d_acc = acc(:, :, 2) - acc(:, :, 1);  d_ari = ari(:, :, 2) - ari(:, :, 1);
for s = 1:n_sets
    mx = mean(d_acc(:, s));  sx = sem(d_acc(:, s));
    my = mean(d_ari(:, s));  sy = sem(d_ari(:, s));
    patch(mx + sx * [-1 1 1 -1], my + sy * [-1 -1 1 1], colors(s, :), ...
        'FaceAlpha', 0.25, 'EdgeColor', 'none');
    plot(mx, my, 'o', 'MarkerFaceColor', colors(s, :), 'MarkerEdgeColor', colors(s, :));
    text(mx + sx, my, ['  ' set_names{texture_sets(s)}], 'Color', colors(s, :), ...
        'FontWeight', 'bold');
end
xline(0, 'k:');  yline(0, 'k:');
xlabel('\Delta pair accuracy (with - without)');  ylabel('\Delta ARI (with - without)');
title({'paired change on the same images', 'mean, box = \pm1 SEM of differences'});
sgtitle('Effect of adding the PCA gradient features');
