% HIST_GAP_EXPERIMENT  Difference-vs-divergence illustration for the achromatic (A)
%   channel. Companion to docs/adaptive-histogram-optimization.md.
%
%   Four sections, each runnable on its own (Ctrl+Enter), the last two depending on variables
%   left in the workspace by the ones before them. "collect data" draws a fixed total number of
%   near/far pairs spread over n_images random images, histograms the A channel into n_bins
%   uniform bins, and saves the per-bin JS divergence stats (not the raw patches) to
%   experiments/hist_gap_data.mat, overwriting it each run. The "plot" section loads that .mat
%   and draws the figure below (example pairs re-sampled fresh each run). The "accuracy sweep
%   over number of bins" section sweeps a list of bin counts, recomputing the collect + decision
%   accuracy for each, and plots percent correct and the per-pair total-JSD clouds (near/far) vs
%   bin count. Collect is shared by the first, third and fourth sections via the hist_gap_collect
%   local function (the sweep and the fourth section skip its plot-only extras). The last section
%   takes each swept scheme's best bin count plus the shipped adaptive bins and bar-charts their
%   accuracy on a Brodatz same/different sample.
%
%   Layout (4 x 4):
%     column 1 = a near example pair, column 2 = a far example pair; both columns share
%       the same four panel letters (each stacks its own instance top to bottom):
%       a. the pair image (patch A dark | patch B light, outlined)
%       b. the two patches' A histograms overlaid (see their difference)
%       c. the per-bin JS divergence profile D_i, with its mean across bins
%       d. the two patches' empirical A CDFs (raw pixels, no binning)
%     columns 3-4 = AGGREGATE statistics over many pairs:
%       e (col 3, row 4) = per-pair Cramer-von Mises statistic histograms (near/far), with the
%                          classify_normals boundary and % correct
%       f (col 3, row 1) = mean D_i for near (blue) vs far (red), staircase + SEM band; a thin
%                          DV strip sits just to its right -- two horizontal histograms of the
%                          per-pair mean D_i (near/far) with the optimal log-space boundary and
%                          % correct
%       g (col 4, row 1) = normalized dJSD: near-standardized aggregate (x - near)/pooled SD,
%                          staircase + SEM band, with the A prior (black curve) and the
%                          JSD-profile-equalizing bin placement overlaid (red verticals)
%       h (col 4, row 2) = bin width vs bin location for the model's shipped adaptive A bins
%                          (green, clipped to the plotted A window) and the JSD-profile-equalized
%                          bins (red), same bin count
%       i (col 3, row 2) = pooled bin-bin correlation matrix of D_i (each class mean-subtracted)
%
%   Pair source (`source` in the collect knobs, saved to the .mat so the plot section matches):
%     'natural' - near/far patch pairs from natural images (sample_nearfar_pairs).
%     'brodatz' - same/different-texture patch pairs from the Brodatz sheets
%                 (sample_brodatz_pairs): "near" = same sheet, "far" = different sheets --
%                 cleaner, ground-truth-supervised stand-in for the self-supervised near/far
%                 split, which mixes same- and different-texture pairs at "far".
%
%   Run `setup` first (adds this repo + vislab to the path).
%
%   See also HIST_GAP_COLLECT, SAMPLE_AB_PAIRS, OPTIMAL_CRITERION, CONFIG,
%   docs/adaptive-histogram-optimization.md.

%% 1. collect data
% Constant-volume sampling: draw a fixed TOTAL number of near/far pairs (npairs_total),
% spread evenly across all natural images, histogram the A channel into `n_bins` uniform
% bins between the 1st/99th percentiles of the shipped A-channel prior (loaded, not
% sampled), and keep only the per-pair per-bin JS divergence D_i (raw patches discarded
% per image). Also keep one near and one far example pair for the per-pair panels. Stats
% are saved to experiments/hist_gap_data.mat, overwritten each run.

setup
cfg    = config();
ecc    = 1;                       % fovea
n_bins = 10;                      % uniform bins between the percentile limits
npairs_total = 1e4;               % total near (and total far) pairs, across all images
n_images = 'full';                 % how many random images to sample from ('full' = all
                                   % images); unused for source='brodatz'
source = 'natural';                % 'natural' (near/far image patches) or 'brodatz'
                                   % (same/different texture patches)

rng('shuffle');                   % fresh pairs each run
% all the stats (see local fn below)
D = hist_gap_collect(n_bins, npairs_total, n_images, cfg, ecc, true, source);

% save the stats the plot section needs (overwrite; raw patches never saved). Path is
% relative to the repo root -- run this script from there.
datafile = fullfile('experiments', 'hist_gap_data.mat');
save(datafile, '-struct', 'D');
fprintf('hist_gap: saved stats to %s\n', datafile);

%% 2. plot
% always load the saved aggregate stats so this section runs standalone -- e.g. collect on a
% fast machine, then plot on another -- independent of whatever is in the current workspace
S = load(fullfile('experiments', 'hist_gap_data.mat'));
cfg = config();     % regenerate locally: S.cfg would carry the collect machine's absolute paths
ctr = S.ctr; edges = S.edges; patch_size = S.psz; a_range = S.a_range;   % .mat field is 'psz'
prior_p = S.prior_p; jsd_n = S.jsd_n; jsd_f = S.jsd_f;
cvm_n = S.cvm_n; cvm_f = S.cvm_f;   % per-pair Cramer-von Mises stats (near / far)
source = S.source;   % 'natural' or 'brodatz' -- match whichever hist_gap_collect used

% fresh random example pairs every run, matching the collect's pair source
rng('shuffle');
if strcmpi(source, 'brodatz')
    [texture_pairs, is_same] = sample_texture_pairs(cfg, 1, 50);
    ex_pool = {texture_pairs(:, :, :, is_same), texture_pairs(:, :, :, ~is_same)};
    ex_name = {'same texture', 'different texture'};
else
    files = list_natural_images(cfg);
    img = vislab.nat_stat_bayes.source_to_lms(files{randi(numel(files))}, cfg, ...
        struct('prescale', 255 / cfg.natural.max_val, 'ecc', 1));
    [patches_near, patches_far] = sample_nearfar_pairs(img, 50, patch_size, cfg);
    ex_pool = {patches_near, patches_far}; ex_name = {'near pair', 'far pair'};
end
examples = struct('name', {}, 'img', {}, 'p', {}, 'q', {}, 'jsd', {});
for ex_idx = 1:2
    pimg = ex_pool{ex_idx}(:, :, 1, randi(size(ex_pool{ex_idx}, 4)));
    [p, q, jsd] = pair_hist_jsd(pimg, edges, patch_size);
    examples(ex_idx) = struct('name', ex_name{ex_idx}, 'img', pimg, 'p', p, 'q', q, 'jsd', jsd);
end

% near = blues, far = reds; each pair uses dark (patch A) + light (patch B); aggregate = mid
cNearMid = [0.00 0.45 0.74]; cNearDark = [0.00 0.10 0.45]; cNearLight = [0.45 0.65 1.00];
cFarMid  = [0.85 0.10 0.10]; cFarDark  = [0.55 0.00 0.00]; cFarLight  = [1.00 0.55 0.55];
figure('Name', 'A channel: example pairs and aggregate JS divergence', 'Color', 'w');

agg_top = @(X) mean(X, 1) + std(X, 0, 1) ./ sqrt(size(X, 1));
% shared y-scale for the two per-pair JSD profiles (eps floor: coarse bins can give
% all-zero example JSD)
jmax = max([examples.jsd, eps]);
xr = round([edges(1), edges(end)]);   % x-axis limits/ticks = bin edges (so bins align
                                       % with the matrix columns)

% per-pair mean over bins (the decision variable / B), and a shared y-scale for the
% aggregate profile and this mean plot (their own, much smaller than the per-pair jmax)
mn = mean(jsd_n, 2); mf = mean(jsd_f, 2);
pmax = max([agg_top(jsd_n), agg_top(jsd_f), mean(mn) + std(mn), mean(mf) + std(mf), eps]);

% column 1 = near pair, column 2 = far pair; each column stacks the pair's 4 plots, both
% columns sharing the same letters a-d (the rest, col 3-4, continue from e)
img_lab = 'a'; hist_lab = 'b'; jsd_lab = 'c'; cdf_lab = 'd';
for ex_idx = 1:2
    ex = examples(ex_idx);
    if ex_idx == 1, cDark = cNearDark; cLight = cNearLight; tcol = cNearMid;
    else,           cDark = cFarDark;  cLight = cFarLight;  tcol = cFarMid;  end

    % (row 1) the pair image, each patch outlined in its plotting colour, with a
    % transparent gap between them so both outlines are visible in the middle
    axImg = subplot(4, 4, ex_idx);
    gap = 2;                          % just wide enough to show both outlines in the middle
    dispimg = [ex.img(:, 1:patch_size), nan(patch_size, gap), ex.img(:, patch_size+1:end)];
    him = imagesc(dispimg); set(him, 'AlphaData', ~isnan(dispimg));
    colormap(gca, gray); axis image off; set(gca, 'Color', 'w'); hold on;
    % patch A
    rectangle('Position', [0.5, 0.5, patch_size, patch_size], 'EdgeColor', cDark, 'LineWidth', 2);
    % patch B
    rectangle('Position', [patch_size + gap + 0.5, 0.5, patch_size, patch_size], ...
        'EdgeColor', cLight, 'LineWidth', 2);
    title(ex.name, 'Color', tcol);
    if ex_idx == 1, panel_label(axImg, img_lab); end   % letter once on the left; the right
                                                        % column is the same panel

    % (row 2) A histograms: light patch as a solid filled histogram, dark patch as a staircase
    % outline on top (neither shows vertical bin edges)
    axH = subplot(4, 4, 4 + ex_idx); hold on; box on;
    xs = repelem(edges, 2); ys = [0, repelem(ex.q, 2), 0];                  % staircase polygon
    fill(xs, ys, cLight, 'EdgeColor', 'none');                             % light: solid fill
    stairs(edges, [ex.p, ex.p(end)], 'Color', cDark, 'LineWidth', 1);   % dark: outline on top
    set(gca, 'YTick', []); xlim(xr); set(gca, 'XTick', xr);
    if ex_idx == 1, ylabel('A histograms'); end     % row label on the first column only
    xlabel(axH, 'A');
    bare_y(axH);
    if ex_idx == 1, panel_label(axH, hist_lab); end

    % (row 3) the per-bin JS divergence profile as a filled histogram (no edges)
    axJ = subplot(4, 4, 8 + ex_idx); hold on; box on;
    bar(ctr, ex.jsd, 1, 'FaceColor', tcol, 'EdgeColor', 'none');
    yline(mean(ex.jsd), '-', 'Color', tcol, 'LineWidth', 0.75);    % mean across bins
    ylim([0, jmax]); xlim(xr); set(gca, 'YTick', [], 'XTick', xr);
    if ex_idx == 1, ylabel('JSD'); end              % row label on the first column only
    xlabel(axJ, 'A');
    bare_y(axJ);
    if ex_idx == 1, panel_label(axJ, jsd_lab); end

    % (row 4) the two patches' empirical A CDFs -- raw A pixels, no binning
    axC = subplot(4, 4, 12 + ex_idx); hold on; box on;
    aL = sort(reshape(ex.img(:, 1:patch_size),               [], 1));   % patch A pixels (dark)
    aR = sort(reshape(ex.img(:, patch_size+1:2*patch_size),  [], 1));   % patch B pixels (light)
    yv = (1:numel(aL)).' / numel(aL);   % same y-grid for both (equal pixel counts)
    % flat tails: 0 at left edge, 1 at right
    xL = [xr(1); aL; xr(2)]; xR = [xr(1); aR; xr(2)]; yy = [0; yv; 1];
    plot(xL, yy, '-', 'Color', cDark,  'LineWidth', 1.5);
    plot(xR, yy, '-', 'Color', cLight, 'LineWidth', 1.5);
    ylim([0, 1.05]); xlim(xr); set(gca, 'YTick', [0 1], 'XTick', xr);   % headroom above 1 so
                                                                         % the flat top shows
    if ex_idx == 1, ylabel('empirical CDF'); end    % row label on the first column only
    xlabel(axC, 'A');
    bare_y(axC);
    if ex_idx == 1, panel_label(axC, cdf_lab); end
end

% column 3: aggregate JS-divergence profile (near/far) and its standardization
% panel f: aggregate profile. Its x-extent is set to the correlation matrix below (i) so
% the two align horizontally.
axA = subplot(4, 4, 3); hold on; box on;
plot_band(edges, jsd_n, 0, 1, cNearMid, 'near');   % raw mean (mu_ref=0, sd_unit=1) + SEM band
plot_band(edges, jsd_f, 0, 1, cFarMid, 'far');
ylim([0, pmax]); xlim(xr); set(gca, 'YTick', [], 'XTick', xr);
cm_left = 0.10; cm_right = 0.16;                 % matrix margins (row A-strip, colorbar)
pg = get(axA, 'Position');
mx = pg(1) + cm_left * pg(3); mwid = (1 - cm_left - cm_right) * pg(3);
set(axA, 'Position', [mx, pg(2), mwid, pg(4)]);
title('mean JSD');
xlabel(axA, 'A');
bare_y(axA);
panel_label(axA, 'f');

% the model's shipped adaptive A bin edges, and the prior- and JSD-profile-equalizing bins at
% the same bin count (bins packed where the prior/profile is steep) -- shared by panels h and g.
lo = a_range(1); hi = a_range(2);
Bm = load(fullfile(cfg.paths.models, 'AHEO_bins.mat'), 'bin_bounds', 'eccs');
a_edges_adapt = Bm.bin_bounds{1, find(Bm.eccs == 1, 1)};      % model's shipped adaptive bin edges
nb = numel(a_edges_adapt) - 1;                                % match the model's adaptive bin count
ie_edges = equalize_cdf(nb, S.edges, S.jsd_cdf, lo, hi);      % equal JSD-profile mass per bin
a_priors = load(fullfile(cfg.paths.models, prior_filename(cfg, 1)), 'edges_a_pixel', 'cdf_a_pixel');
pe_edges = prior_equalized_edges(nb, lo, hi, a_priors);       % equal prior mass per bin

% panel h: bin width vs bin location for the three irregular-bin schemes above, drawn in the free
% cell to the right of f (where the A-corr matrix used to sit), aligned in x with panel g above it.
% The shipped adaptive edges span the FULL prior support (0th-100th percentile), well past the
% 1st-99th percentile window plotted here, so their outer tail bins are much wider than anything
% else on the axis; clip them to [lo, hi] for display, or that outlier drags the whole plot
% off-scale.
posCA = get(subplot(4, 4, 8), 'Position'); delete(gca);
mxA = posCA(1) + cm_left * posCA(3); mwidA = (1 - cm_left - cm_right) * posCA(3);
axK = axes('Position', [mxA, posCA(2), mwidA, posCA(4)]); hold on; box on;
cA = [0.20 0.60 0.20]; cIE = [0.85 0.10 0.10]; cPE = [0 0 0];
a_edges_disp = unique(min(max(a_edges_adapt, lo), hi));
plot((a_edges_disp(1:end-1) + a_edges_disp(2:end)) / 2, diff(a_edges_disp), ...
    '-o', 'Color', cA, 'MarkerFaceColor', cA, 'MarkerSize', 3);
plot((ie_edges(1:end-1) + ie_edges(2:end)) / 2, diff(ie_edges), ...
    '-o', 'Color', cIE, 'MarkerFaceColor', cIE, 'MarkerSize', 3);
plot((pe_edges(1:end-1) + pe_edges(2:end)) / 2, diff(pe_edges), ...
    '-o', 'Color', cPE, 'MarkerFaceColor', cPE, 'MarkerSize', 3);
xlim(xr); set(gca, 'XTick', xr);
xlabel(axK, 'A'); ylabel(axK, 'bin width');
title(axK, 'bin width vs location');
text(axK, 0.05, 0.95, 'adaptive',    'Units', 'normalized', 'Color', cA,  ...
    'VerticalAlignment', 'top');
text(axK, 0.05, 0.85, 'profile-eq.', 'Units', 'normalized', 'Color', cIE, ...
    'VerticalAlignment', 'top');
text(axK, 0.05, 0.75, 'prior-eq.',   'Units', 'normalized', 'Color', cPE, ...
    'VerticalAlignment', 'top');
panel_label(axK, 'h');

% panel i: pooled bin-bin correlation of the per-bin JSD (each class mean-subtracted, then
% pooled), drawn at the SAME x-extent as f, with A-level strips on top/left and a colorbar
posC = get(subplot(4, 4, 7), 'Position'); delete(gca);
Rpool = corrcoef([jsd_n - mean(jsd_n, 1); jsd_f - mean(jsd_f, 1)]);
add_corr_panel(posC, mx, mwid, Rpool, ctr, a_range, 'i', 'JSD corr.');

% top-right (right of the mean JSD, past the DV strip): the near-standardized aggregate, as
% staircases with SEM bands (same style as f), with the A prior (thin black curve) and the
% JSD-profile-equalizing bin placement overlaid as red verticals. Aligned in x with panel h
% below it.
axStd = axes('Position', [mxA, pg(2), mwidA, pg(4)]); hold on; box on;
mu_near   = mean(jsd_n, 1);
sd_pooled = sqrt((var(jsd_n, 0, 1) + var(jsd_f, 0, 1)) / 2);   % per-bin pooled near+far SD
plot_band(edges, jsd_n, mu_near, sd_pooled, cNearMid, 'near');
plot_band(edges, jsd_f, mu_near, sd_pooled, cFarMid, 'far');
speak = max((mean(jsd_f, 1) - mu_near) ./ sd_pooled);   % far-separation peak, to scale the prior
plot(ctr, prior_p / max(prior_p) * speak, 'k-', 'LineWidth', 1);   % A prior (moved here from g)
for xb = ie_edges
    xline(xb, 'Color', [0.85 0.10 0.10], 'LineWidth', 0.5, 'HandleVisibility', 'off');
end
xlim(xr); set(gca, 'XTick', xr);
title('normalized \Delta JSD');
xlabel(axStd, 'A');
bare_y(axStd);
panel_label(axStd, 'g');

% column 4: the decision variable = mean JS over bins, near vs far (each pair a jittered
% dot, mean +/- SD). Optimal criterion from classify_normals, found in log space (the model's
% actual DV, matching eval_r's log-LLR) and transformed back with exp. The boundary is
% quadratic, so it can have TWO real roots (near = between them, far = outside): both are
% drawn, but the axis is linked to the aggregate profile's scale [0, pmax], so a far root may clip.
lmn = log(mn); lmf = log(mf);
[roots_log, pcorrect_log] = optimal_criterion(lmn, lmf, cfg);

dv_gap = 0.02 * pg(3); dv_wid = 0.20 * pg(3);   % thin vertical strip just right of the aggregate
ax = axes('Position', [mx + mwid + dv_gap, pg(2), dv_wid, pg(4)]);
dv_hist(ax, mn, mf, cNearMid, cFarMid, [0, pmax]);   % two DV histograms (near/far), horizontal
bd = exp(roots_log(:));                              % log criterion, back to linear DV units
% boundary between near/far
bd = bd(bd >= min(median(mn), median(mf)) & bd <= max(median(mn), median(mf)));
for c = bd', yline(c, 'k-', 'LineWidth', 1); end
text(0.5, 0.95, sprintf('%.0f%%', pcorrect_log), 'Units', 'normalized', 'Color', 'k', ...
    'HorizontalAlignment', 'center');
title('mean');

% panel e (col 3, row 4): histograms of the per-pair Cramer-von Mises statistic for
% near (blue) vs far (red) pairs, with the optimal classify_normals boundary + percent correct
axCvM = subplot(4, 4, 15); hold on; box on;
[rC, pcorrect_cvm] = optimal_criterion(cvm_n, cvm_f, cfg);
edC = linspace(min([cvm_n; cvm_f]), max([cvm_n; cvm_f]), 30);
histogram(cvm_n, edC, 'FaceColor', cNearMid, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
histogram(cvm_f, edC, 'FaceColor', cFarMid,  'FaceAlpha', 0.5, 'EdgeColor', 'none');
% boundary between the two classes
rC = rC(rC >= min(median(cvm_n), median(cvm_f)) & rC <= max(median(cvm_n), median(cvm_f)));
for c = rC', xline(c, 'k-', 'LineWidth', 1); end
set(gca, 'XTick', []); xlabel('Cramér-von Mises statistic');
bare_y(axCvM);
text(0.5, 0.95, sprintf('%.0f%%', pcorrect_cvm), 'Units', 'normalized', 'Color', 'k', ...
    'HorizontalAlignment', 'center');
panel_label(axCvM, 'e');

%% 3. accuracy sweep over number of bins
% Sweep a list of bin counts. The (expensive) image loading / patch sampling only happens ONCE,
% via sample_ab_pairs -- every bin count and every scheme below just re-bins that same fixed
% sample of patches_near/patches_far (cheap: a histcounts call per pair), instead of
% re-collecting a fresh sample per candidate as before. This also makes the sweep a fair,
% paired comparison across bin counts and schemes (no sampling-noise confound from one
% candidate to the next), and mirrors how s4_optimize_bins.m's feature_values/eval_r split
% featurization from re-binning.
% Plots (top) the per-pair total-JSD clouds (near blue, far red) with the decision boundary,
% and (bottom) accuracy vs bin count for uniform, prior-equalized, and profile-equalized bins,
% with the shipped adaptive bins as a horizontal anchor. The profile-equalized curve places
% bins to equalize the high-res JSD-profile CDF stored by section 1, so run section 1 (at high
% resolution) first for that curve; the rest is self-contained.
nbins_list = 2:15;   % bin counts to sweep (edit me)
nboot      = 200;    % bootstrap resamples for the accuracy error bands (own knob)

cNear = [0.00 0.45 0.74]; cFar = [0.85 0.10 0.10];  % near = blue, far = red (as in section 2)
cfg = config(); ecc = 1; patch_size = cfg.patch.size / ecc;
rng('shuffle');
sub = @(v) v(round(linspace(1, numel(v), min(200, numel(v)))));   % thin each cloud for plotting
% A prior CDF (for prior-equalized bins)
a_priors = load(fullfile(cfg.paths.models, prior_filename(cfg, ecc)), ...
    'edges_a_pixel', 'cdf_a_pixel');
[plo, phi] = a_prior_quantiles(a_priors);           % 1-99% window, same as the uniform bins
% high-res JSD-profile CDF from section 1
Spr = load(fullfile('experiments', 'hist_gap_data.mat'), 'edges', 'jsd_cdf');
% ONE sample, re-binned below
[patches_near, patches_far] = sample_ab_pairs(cfg, ecc, patch_size, npairs_total, n_images, source);

K = numel(nbins_list);
step = nbins_list(2) - nbins_list(1);   % linear sweep -- equal spacing, used to scale the
                                         % jitter/boundary width below
acc    = zeros(1, K); acc_sd    = zeros(1, K);   % uniform bins (+ bootstrap SD)
acc_pe = zeros(1, K); acc_pe_sd = zeros(1, K);   % prior-equalized bins (equal prior mass per bin)
acc_ie = zeros(1, K); acc_ie_sd = zeros(1, K);   % profile-equalized bins (equal JSD-profile mass
                                                  % per bin)
tnC = cell(1, K); tfC = cell(1, K);   % per-nbins total-JSD clouds (near / far), uniform bins
bnd = cell(1, K);                     % per-nbins decision boundary/boundaries (total-JSD space)
parfor i = 1:K
    nbins_list(i)
    % uniform bins, same window as sample_ab_pairs' patches
    edges_u = linspace(plo, phi, nbins_list(i) + 1);
    % total JSD over bins (per pair) = the decision variable
    tn = sum(pair_jsd(patches_near, edges_u, patch_size), 2);
    tf = sum(pair_jsd(patches_far, edges_u, patch_size), 2);
    [roots_log, acc(i)] = optimal_criterion(log(tn), log(tf), cfg);   % log-space criterion
                                                                       % (as in section 2)
    acc_sd(i) = boot_acc_sd(tn, tf, cfg, nboot);     % bootstrap SD of that accuracy (pair-
                                                      % resampling error)
    b = exp(roots_log(:));                          % boundary/boundaries transformed back
                                                      % to total-JSD space
    bnd{i} = b(b >= min(median(tn), median(tf)) & b <= max(median(tn), median(tf)));   % keep
                                                                  % the one between the clouds
    tnC{i} = sub(tn); tfC{i} = sub(tf);

    % same bin count, edges placed to equalize the prior (equal prior mass per bin)
    edges_pe = prior_equalized_edges(nbins_list(i), plo, phi, a_priors);
    tnp = sum(pair_jsd(patches_near, edges_pe, patch_size), 2);
    tfp = sum(pair_jsd(patches_far, edges_pe, patch_size), 2);
    [~, acc_pe(i)] = optimal_criterion(log(tnp), log(tfp), cfg);
    acc_pe_sd(i) = boot_acc_sd(tnp, tfp, cfg, nboot);

    % same bin count, edges placed to equalize the stored high-res JSD-profile CDF
    edges_ie = equalize_cdf(nbins_list(i), Spr.edges, Spr.jsd_cdf, plo, phi);
    tni = sum(pair_jsd(patches_near, edges_ie, patch_size), 2);
    tfi = sum(pair_jsd(patches_far, edges_ie, patch_size), 2);
    [~, acc_ie(i)] = optimal_criterion(log(tni), log(tfi), cfg);
    acc_ie_sd(i) = boot_acc_sd(tni, tfi, cfg, nboot);
    fprintf('sweep: %5d bins -> uniform %.2f +/- %.2f%%, prior-eq %.2f +/- %.2f%%, profile-eq %.2f +/- %.2f%%\n', ...
        nbins_list(i), acc(i), acc_sd(i), acc_pe(i), acc_pe_sd(i), acc_ie(i), acc_ie_sd(i));
end

% anchor: accuracy with the model's SHIPPED adaptive A bins (feature 1), evaluated on the SAME
% patch-pairs sample as the sweep above -- the benchmark the sweep is compared against.
B = load(fullfile(cfg.paths.models, 'AHEO_bins.mat'), 'bin_bounds', 'eccs');
a_edges = B.bin_bounds{1, find(B.eccs == ecc, 1)};   % model's learned bin edges for A
tna = sum(pair_jsd(patches_near, a_edges(:)', patch_size), 2);
tfa = sum(pair_jsd(patches_far, a_edges(:)', patch_size), 2);
[~, acc_adaptive] = optimal_criterion(log(tna), log(tfa), cfg);
acc_adaptive_sd = boot_acc_sd(tna, tfa, cfg, nboot);
fprintf('sweep: adaptive bins (%d) -> %.2f +/- %.2f%% correct\n', ...
    numel(a_edges) - 1, acc_adaptive, acc_adaptive_sd);

figure('Name', 'A-channel proximity accuracy vs number of bins', 'Color', 'w');
% (top) per-pair total-JSD clouds, near (blue) vs far (red), jittered at each bin count, with
% the optimal decision boundary/boundaries (black, from the log-space criterion) at each count
subplot(2, 1, 1); hold on; box on;
jit = @(n) (rand(n, 1) - 0.5) * 0.25 * step;
for i = 1:K
    x = nbins_list(i);
    yN = tnC{i}(tnC{i} > 0); yF = tfC{i}(tfC{i} > 0);   % >0 only (log y-axis; zero-divergence
                                                         % pairs drop)
    scatter(x - 0.18 * step + jit(numel(yN)), yN, 4, cNear, 'filled');
    scatter(x + 0.18 * step + jit(numel(yF)), yF, 4, cFar,  'filled');
    for b = bnd{i}'
        plot([x - 0.38 * step, x + 0.38 * step], [b, b], 'k-', 'LineWidth', 1);   % decision
                                                                                   % boundary
    end
end
set(gca, 'YScale', 'log'); xlim([nbins_list(1) - step/2, nbins_list(end) + step/2]);
ylabel('total JSD over bins (per pair)'); title('Total JSD (per pair) vs bin count');
% (bottom) accuracy vs bin count: uniform and prior-equalized sweeps (curves) vs the shipped
% adaptive bins (horizontal line)
subplot(2, 1, 2); hold on; box on; grid on;
cU = .5*[1 1 1]; cP = [0 0 0]; cI = [0.90 0.50 0.10]; cA = [0.20 0.60 0.20];
% +/- 1 bootstrap SD bands (see boot_acc_sd), drawn under the lines/anchor
fill([nbins_list, fliplr(nbins_list)], [acc + acc_sd, fliplr(acc - acc_sd)], cU, ...
    'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([nbins_list, fliplr(nbins_list)], [acc_pe + acc_pe_sd, fliplr(acc_pe - acc_pe_sd)], cP, ...
    'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([nbins_list, fliplr(nbins_list)], [acc_ie + acc_ie_sd, fliplr(acc_ie - acc_ie_sd)], cI, ...
    'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([nbins_list(1) - step/2, nbins_list(end) + step/2, ...
      nbins_list(end) + step/2, nbins_list(1) - step/2], ...
    acc_adaptive + acc_adaptive_sd * [-1, -1, 1, 1], cA, ...
    'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
hU = plot(nbins_list, acc,    '-o', 'Color', cU, 'MarkerFaceColor', cU, 'LineWidth', 1);
hP = plot(nbins_list, acc_pe, '-o', 'Color', cP, 'MarkerFaceColor', cP, 'LineWidth', 1);
hI = plot(nbins_list, acc_ie, '-o', 'Color', cI, 'MarkerFaceColor', cI, 'LineWidth', 1);
hA = yline(acc_adaptive, '-', 'Color', cA, 'LineWidth', 1.5);
xline(numel(a_edges) - 1, '-', 'Color', cA, 'LineWidth', 1.5, ...
    'HandleVisibility', 'off');   % adaptive bin count
xlim(nbins_list([1 end]));
yr = [min([acc - acc_sd, acc_pe - acc_pe_sd, acc_ie - acc_ie_sd, ...
           acc_adaptive - acc_adaptive_sd]), ...
      max([acc + acc_sd, acc_pe + acc_pe_sd, acc_ie + acc_ie_sd, ...
           acc_adaptive + acc_adaptive_sd])];
ylim(yr + 0.05 * diff(yr) * [-1, 1]);   % pad 5% of the plotted (incl. SD bands) range on each side
xlabel('number of A bins'); ylabel('percent correct'); title('Proximity accuracy vs bin count');
legend([hU, hP, hI, hA], {'uniform', 'prior-equalized', 'profile-equalized', 'adaptive'}, ...
    'Location', 'best');

%% 4. Brodatz accuracy at each method's best bin count
% Take each swept scheme's best-performing bin count (uniform, prior-eq, profile-eq) from the
% sweep above, plus the shipped adaptive bins (a single fixed bin count, never swept), and
% compare all four on a ground-truth Brodatz same/different sample: the same one already
% collected above if the sweep ran with source='brodatz', or ONE fresh sample (same npairs_total,
% ecc), reused across all four methods' bin edges, if it ran on source='natural'.
[~, iU] = max(acc);     nbU = nbins_list(iU);
[~, iP] = max(acc_pe);  nbP = nbins_list(iP);
[~, iI] = max(acc_ie);  nbI = nbins_list(iI);
fprintf('best bin counts -> uniform %d, prior-eq %d, profile-eq %d, adaptive %d\n', ...
    nbU, nbP, nbI, numel(a_edges) - 1);

names  = {'uniform', 'prior-equalized', 'profile-equalized', 'adaptive'};
colors = {cU, cP, cI, cA};

if strcmpi(source, 'brodatz')
    % the sweep above already scored these exact bin counts on Brodatz pairs -- reuse directly
    bar_acc = [acc(iU), acc_pe(iP), acc_ie(iI), acc_adaptive];
    bar_sd  = [acc_sd(iU), acc_pe_sd(iP), acc_ie_sd(iI), acc_adaptive_sd];
else
    % the sweep ran on natural pairs -- draw ONE fresh Brodatz sample and re-bin it at each
    % method's own best-performing edges (no per-method re-sampling)
    [patches_near_b, patches_far_b] = sample_ab_pairs(cfg, ecc, patch_size, npairs_total, ...
        n_images, 'brodatz');
    edges_best = {linspace(plo, phi, nbU + 1), prior_equalized_edges(nbP, plo, phi, a_priors), ...
        equalize_cdf(nbI, Spr.edges, Spr.jsd_cdf, plo, phi), a_edges(:)'};
    bar_acc = zeros(1, 4); bar_sd = zeros(1, 4);
    for k = 1:4
        tnk = sum(pair_jsd(patches_near_b, edges_best{k}, patch_size), 2);
        tfk = sum(pair_jsd(patches_far_b, edges_best{k}, patch_size), 2);
        [~, bar_acc(k)] = optimal_criterion(log(tnk), log(tfk), cfg);
        bar_sd(k) = boot_acc_sd(tnk, tfk, cfg, nboot);
    end
end
fprintf('Brodatz accuracy -> uniform %.2f +/- %.2f%%, prior-eq %.2f +/- %.2f%%, profile-eq %.2f +/- %.2f%%, adaptive %.2f +/- %.2f%%\n', ...
    bar_acc(1), bar_sd(1), bar_acc(2), bar_sd(2), bar_acc(3), bar_sd(3), bar_acc(4), bar_sd(4));

figure('Name', 'A-channel Brodatz accuracy at each method''s best bin count', 'Color', 'w');
hold on; box on; grid on;
for k = 1:4
    bar(k, bar_acc(k), 'FaceColor', colors{k}, 'EdgeColor', 'none');
end
errorbar(1:4, bar_acc, bar_sd, 'k.', 'LineWidth', 1, 'CapSize', 8, 'HandleVisibility', 'off');
set(gca, 'XTick', 1:4, 'XTickLabel', names);
ylim([min(bar_acc - bar_sd) - 2, max(bar_acc + bar_sd) + 2]);
ylabel('percent correct');
title('Brodatz same/different accuracy, each method at its best bin count');

% ------------------------------------------------------------------------------
function D = hist_gap_collect(n_bins, npairs_total, n_images, cfg, ecc, want_extras, source)
% Collect the per-pair per-bin JS divergence stats for the A channel. Shared by the collect
% section and the accuracy-vs-bins sweep (one source of truth). Draws npairs_total near/far
% pairs, from either natural images (spread over n_images random images, 'full' = all) or
% Brodatz same/different-texture pairs (n_images unused).
%   n_bins - number of UNIFORM bins (scalar), OR an explicit vector of bin edges to use
%            directly (e.g. the model's shipped adaptive bins for the adaptive anchor).
%   want_extras (default true) - also compute the plot-only extras: two example pairs and the
%   per-pair Cramer-von Mises stats. The sweep passes false to skip them, since it only needs
%   jsd_n/jsd_f.
%   source (default 'natural') - 'natural' (sample_nearfar_pairs) or 'brodatz'
%   (sample_brodatz_pairs: "near" = same sheet, "far" = different sheets).
% Returns struct D. Fields jsd_n, jsd_f, ctr, edges, psz (patch size), a_range, prior_p,
% jsd_cdf, source are always set; examples and the per-pair Cramer-von Mises stats cvm_n/cvm_f
% only when want_extras.
    if nargin < 6 || isempty(want_extras), want_extras = true; end
    if nargin < 7 || isempty(source), source = 'natural'; end
    patch_size = cfg.patch.size / ecc;

    % 1st/99th percentiles of the shipped A-channel prior CDF (feature 1) set the uniform-bin
    % window and the level-strip range (always the natural-image prior, so both sources share
    % one binning scheme); explicit edges (adaptive bins) are used as-is.
    priors = load(fullfile(cfg.paths.models, prior_filename(cfg, ecc)), ...
        'edges_a_pixel', 'cdf_a_pixel');
    [lo, hi] = a_prior_quantiles(priors);
    if isscalar(n_bins)
        edges = linspace(lo, hi, n_bins + 1);      % uniform bins
    else
        edges  = sort(n_bins(:))';                 % caller passed explicit bin edges
        n_bins = numel(edges) - 1;
    end
    ctr   = (edges(1:end-1) + edges(2:end)) / 2;
    a_range = [lo, hi];   % map the 1-99% window black..white (full range is ~all black)

    % prior of A over the same bins (from the shipped CDF), for the overlay on panel g
    xq = priors.edges_a_pixel(:); Nq = priors.cdf_a_pixel(:);
    if numel(xq) == numel(Nq) + 1, xq = xq(2:end); end   % CDF Na(k) = P(A <= ea(k+1))
    [xqu, iu] = unique(xq);
    prior_p = diff(interp1(xqu, Nq(iu), edges, 'linear', 'extrap'));   % per-bin prior probability

    switch lower(source)
        case 'natural'
            [jsd_n, jsd_f, cvm_n, cvm_f, examples] = collect_natural(cfg, ecc, patch_size, ...
                edges, npairs_total, n_images, want_extras);
        case 'brodatz'
            [jsd_n, jsd_f, cvm_n, cvm_f, examples] = collect_brodatz(cfg, ecc, patch_size, ...
                edges, npairs_total, want_extras);
        otherwise
            error('hist_gap_collect:badSource', "source must be 'natural' or 'brodatz', got '%s'.", source);
    end
    fprintf('A in [%.3g, %.3g] (1st-99th pct of shipped prior), %d bins; %d near / %d far pairs (source: %s).\n', ...
        lo, hi, n_bins, size(jsd_n, 1), size(jsd_f, 1), source);

    % high-res "information" profile: per-bin far JSD in units of the near distribution
    % (subtract near mean, divide by near SD), floored at 0 (only a positive far>near gap is
    % signal). Stored as a normalized CDF over the bin edges -- the JSD analogue of the prior
    % CDF -- so section 3 can place bins to equalize it. Zero-near-variance bins contribute none.
    prof = (mean(jsd_f, 1) - mean(jsd_n, 1)) ./ std(jsd_n, 0, 1);
    prof(~isfinite(prof)) = 0;
    prof = max(prof, 0);
    c = cumsum([0, prof]);                          % cumulative at the n_bins+1 edges
    if c(end) > 0, jsd_cdf = c / c(end); else, jsd_cdf = linspace(0, 1, numel(edges)); end

    % assemble field-by-field (struct(...) with a struct-array value would size D to it)
    % .mat field is 'psz' (not renamed to patch_size -- see hist_gap_collect's header)
    D.cfg = cfg; D.ctr = ctr; D.edges = edges; D.psz = patch_size; D.a_range = a_range;
    D.prior_p = prior_p; D.jsd_n = jsd_n; D.jsd_f = jsd_f; D.jsd_cdf = jsd_cdf; D.source = source;
    if want_extras
        D.examples = examples; D.cvm_n = cvm_n; D.cvm_f = cvm_f;
    end
end

% ------------------------------------------------------------------------------
function [patches_near, patches_far] = sample_ab_pairs(cfg, ecc, patch_size, npairs_total, ...
    n_images, source)
% Draw npairs_total near/far (or same/different) A-channel patch pairs, with NO binning -- the
% bin-independent half of collect_natural/collect_brodatz, split out so a sweep over many bin
% counts/schemes can draw the (expensive, especially for natural images) sample ONCE and reuse
% it, re-binning only (mirrors s4_optimize_bins.m's feature_values/eval_r split).
%   source - 'natural' (sample_nearfar_pairs, spread over n_images random images, 'full' = all)
%   or 'brodatz' (sample_brodatz_pairs; n_images unused).
    switch lower(source)
        case 'natural'
            maxval = cfg.natural.max_val;
            load_lms = @(file) vislab.nat_stat_bayes.source_to_lms(file, cfg, ...
                struct('prescale', 255 / maxval, 'ecc', ecc));
            files = list_natural_images(cfg);
            if ~strcmpi(string(n_images), 'full')   % keep n random images (else use them all)
                files = files(randperm(numel(files), min(n_images, numel(files))));
            end
            per_img = ceil(npairs_total / numel(files));   % constant volume: same pair count
                                                             % per image

            patches_near_c = cell(1, numel(files)); patches_far_c = cell(1, numel(files));
            parfor f = 1:numel(files)
                [~, fname, fext] = fileparts(files{f});
                fprintf('image %d/%d  %s\n', f, numel(files), [fname, fext]);
                img = load_lms(files{f});
                [patches_near_c{f}, patches_far_c{f}] = sample_nearfar_pairs(img, per_img, ...
                    patch_size, cfg);
            end
            patches_near = cat(4, patches_near_c{:});
            patches_far = cat(4, patches_far_c{:});

            % keep exactly npairs_total, drawn uniformly across the pooled pairs (per_img
            % rounded up)
            keep = randperm(size(patches_near, 4), min(npairs_total, size(patches_near, 4)));
            patches_near = patches_near(:, :, :, keep);
            patches_far = patches_far(:, :, :, keep);
        case 'brodatz'
            % one call draws all npairs_total pairs at once (fast; no per-image loop needed)
            fprintf('sampling %d Brodatz same/different-texture pairs\n', npairs_total);
            [patches, same_gt] = sample_texture_pairs(cfg, ecc, npairs_total);
            patches_near = patches(:, :, :, same_gt);
            patches_far = patches(:, :, :, ~same_gt);
        otherwise
            error('sample_ab_pairs:badSource', "source must be 'natural' or 'brodatz', got '%s'.", source);
    end
end

% ------------------------------------------------------------------------------
function [jsd_n, jsd_f, cvm_n, cvm_f, examples] = ...
    collect_natural(cfg, ecc, patch_size, edges, npairs_total, n_images, want_extras)
% Near/far patch pairs from natural images (sample_ab_pairs), binned into the per-pair per-bin
% JS divergence D_i. Outputs as documented in hist_gap_collect.
    [patches_near, patches_far] = sample_ab_pairs(cfg, ecc, patch_size, npairs_total, ...
        n_images, 'natural');
    jsd_n = pair_jsd(patches_near, edges, patch_size);
    jsd_f = pair_jsd(patches_far, edges, patch_size);
    examples = struct('name', {}, 'img', {}, 'p', {}, 'q', {}, 'jsd', {});
    if want_extras
        % two-sample CvM between the two patches' A pixels (per pair)
        cvm_n = pair_cvm(patches_near, patch_size);
        cvm_f = pair_cvm(patches_far, patch_size);

        % two example pairs (one near, one far) for the illustration panels, drawn from the
        % already-collected sample (no extra image access needed)
        ex_pool = {patches_near, patches_far}; ex_name = {'near pair', 'far pair'};
        for ex_idx = 1:2
            pimg = ex_pool{ex_idx}(:, :, 1, randi(size(ex_pool{ex_idx}, 4)));
            [p, q, jsd] = pair_hist_jsd(pimg, edges, patch_size);
            examples(ex_idx) = struct('name', ex_name{ex_idx}, 'img', pimg, 'p', p, 'q', q, ...
                'jsd', jsd);
        end
    else
        cvm_n = []; cvm_f = [];
    end
end

% ------------------------------------------------------------------------------
function [jsd_n, jsd_f, cvm_n, cvm_f, examples] = ...
    collect_brodatz(cfg, ecc, patch_size, edges, npairs_total, want_extras)
% Same/different-texture patch pairs from the Brodatz sheets (sample_ab_pairs; also used by the
% Stage 6 qualitative demo): "near" = two patches from the same sheet, "far" = one patch each
% from two different sheets. Ground-truth-supervised stand-in for the natural-image near/far
% split, which mixes same- and different-texture patches into "far". Binned into the per-pair
% per-bin JS divergence D_i. Outputs as documented in hist_gap_collect.
    [patches_near, patches_far] = sample_ab_pairs(cfg, ecc, patch_size, npairs_total, [], ...
        'brodatz');
    jsd_n = pair_jsd(patches_near, edges, patch_size);
    jsd_f = pair_jsd(patches_far, edges, patch_size);
    examples = struct('name', {}, 'img', {}, 'p', {}, 'q', {}, 'jsd', {});
    if want_extras
        cvm_n = pair_cvm(patches_near, patch_size);
        cvm_f = pair_cvm(patches_far, patch_size);

        % two example pairs (one near, one far) for the illustration panels, drawn from the
        % already-collected sample (no extra Brodatz-sheet access needed)
        ex_pool = {patches_near, patches_far}; ex_name = {'same texture', 'different texture'};
        for ex_idx = 1:2
            pimg = ex_pool{ex_idx}(:, :, 1, randi(size(ex_pool{ex_idx}, 4)));
            [p, q, jsd] = pair_hist_jsd(pimg, edges, patch_size);
            examples(ex_idx) = struct('name', ex_name{ex_idx}, 'img', pimg, 'p', p, 'q', q, ...
                'jsd', jsd);
        end
    else
        cvm_n = []; cvm_f = [];
    end
end

% ------------------------------------------------------------------------------
function dv_hist(ax, xn, xf, cn, cf, ylims)
% Two decision-variable histograms drawn horizontally in the narrow strip AX: near and far
% distributions of the per-pair DV along y (the shared mean-JSD scale), counts along x.
    axes(ax); hold on;
    ed = linspace(ylims(1), ylims(2), 26);
    yc = (ed(1:end-1) + ed(2:end)) / 2;
    barh(yc, histcounts(xn, ed), 1, 'FaceColor', cn, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    barh(yc, histcounts(xf, ed), 1, 'FaceColor', cf, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    set(gca, 'XTick', [], 'YTick', [], 'XColor', 'none', 'YColor', 'none'); ylim(ylims);   % no box
end

% ------------------------------------------------------------------------------
function C = pair_cvm(patches, patch_size)
% Per-pair two-sample Cramer-von Mises statistic between the two patches' raw A pixels (no
% binning) for every pair -> [npairs x 1].
    n = size(patches, 4);
    C = zeros(n, 1);
    for i = 1:n
        pimg = patches(:, :, 1, i);
        C(i) = cvm2(reshape(pimg(:, 1:patch_size), [], 1), ...
            reshape(pimg(:, patch_size+1:2*patch_size), [], 1));
    end
end

% ------------------------------------------------------------------------------
function t = cvm2(x, y)
% Two-sample Cramer-von Mises statistic (Anderson 1962) between samples x and y, from their
% pooled ranks. Ties broken arbitrarily by sort order (A pixels are effectively continuous).
    x = x(:); y = y(:); n = numel(x); m = numel(y); N = n + m;
    [~, ord] = sort([x; y]);
    pr = zeros(N, 1); pr(ord) = (1:N)';           % pooled ranks
    r = sort(pr(1:n)); s = sort(pr(n+1:end));
    U = n * sum((r - (1:n)').^2) + m * sum((s - (1:m)').^2);
    t = U / (N * n * m) - (4*n*m - 1) / (6*N);
end

% ------------------------------------------------------------------------------
function [crit, pcorrect] = optimal_criterion(near, far, cfg)
% Optimal 1-D criterion separating near/far, from classify_normals's boundary (same
% call as s4_optimize_bins's proximity_error). The boundary is quadratic, so `crit` is
% ALL its real roots (0, 1, or 2), sorted. Also returns class-balanced percent correct.
    near = near(isfinite(near));      % drop -Inf (log of a zero-divergence pair), as eval_r does
    far  = far(isfinite(far));
    rng(cfg.seed);
    res = classify_normals(near, far, 'input_type', 'samp', 'plotmode', 0, ...
        'samp_balance', true, 'samp_opt', 1);
    bd = res.samp_opt_bd;
    r = roots([bd.q2, bd.q1, bd.q0]);
    crit = sort(real(r(abs(imag(r)) < 1e-12)));   % real roots only
    pcorrect = 100 * (1 - res.samp_opt_err);
end

% ------------------------------------------------------------------------------
function sd = boot_acc_sd(tn, tf, cfg, nboot)
% Bootstrap SD of the class-balanced percent-correct accuracy (optimal_criterion's log-space
% criterion), resampling the already-collected per-pair total-JSD values tn/tf (near/far) with
% replacement. Captures pair-sampling variability from the existing pool of pairs, with no
% extra hist_gap_collect calls (so no extra image/Brodatz-sheet sampling).
    n = numel(tn); m = numel(tf);
    accb = zeros(nboot, 1);
    for b = 1:nboot
        idxn = randi(n, n, 1); idxf = randi(m, m, 1);   % draw the resample from the ambient
                                                         % stream
        s = rng;                       % optimal_criterion resets rng(cfg.seed) internally --
        [~, accb(b)] = optimal_criterion(log(tn(idxn)), log(tf(idxf)), cfg);   % save/restore
                                                                                % so that reset
        rng(s);                        % doesn't flatten the next iteration's resample draw
    end
    sd = std(accb);
end

% ------------------------------------------------------------------------------
function J = pair_jsd(patches, edges, patch_size)
% Per-pair per-bin JS divergence D_i for every pair -> J [npairs x n_bins].
    n      = size(patches, 4);
    n_bins = numel(edges) - 1;
    J = zeros(n, n_bins);
    for i = 1:n
        [~, ~, jsd] = pair_hist_jsd(patches(:, :, 1, i), edges, patch_size);
        J(i, :) = jsd;
    end
end

% ------------------------------------------------------------------------------
function [p, q, jsd] = pair_hist_jsd(pairimg, edges, patch_size)
% Probability histograms p, q of the two patch halves and the per-bin JS
% divergence D_i between them. pairimg is [patch_size x 2*patch_size]: left half A, right
% half B.
    left  = pairimg(:, 1:patch_size);
    right = pairimg(:, patch_size+1:2*patch_size);
    p = histcounts(left(:),  edges);  p = p / max(sum(p), eps);
    q = histcounts(right(:), edges);  q = q / max(sum(q), eps);
    m = (p + q) / 2;
    jsd = 0.5 * klterm(p, m) + 0.5 * klterm(q, m);
end

% ------------------------------------------------------------------------------
function t = klterm(p, m)
% Per-bin KL contribution p*log(p/m), with 0*log0 := 0.
    t = zeros(size(p));
    nz = p > 0 & m > 0;
    t(nz) = p(nz) .* log(p(nz) ./ m(nz));
end

% ------------------------------------------------------------------------------
function add_corr_panel(posC, mx, mwid, R, ctr, a_range, ch, ttl)
% Bin-bin correlation matrix R (n_bins x n_bins) drawn in the matrix rectangle [mx, posC(2),
% mwid, .] (x-extent passed in so it aligns with the profile above). The left margin
% [posC(1)..mx] holds a grayscale A-level strip (rows), the top holds one (columns), and
% the right margin holds a colorbar. Diagonal zeroed; colour axis spans min..max off-diag.
    n_bins = numel(ctr);
    figpos = get(gcf, 'Position');
    mw = mx - posC(1);                            % left-strip width (the left margin)
    mh = mw * figpos(3) / figpos(4);              % top-strip height (same px thickness)
    lims = [0.5, n_bins + 0.5];
    mpos = [mx, posC(2), mwid, posC(4) - mh];     % matrix rectangle

    offdiag = R(~eye(n_bins));
    cmin = min(offdiag); cmax = max(offdiag);
    if cmax <= cmin   % single/equal off-diagonal (e.g. n_bins=2): pad to a valid range
        pad = max(abs(cmin), 1) * 1e-3;
        cmin = cmin - pad; cmax = cmax + pad;
    end
    R(1:n_bins+1:end) = 0;                        % zero the diagonal

    axM = axes('Position', mpos);
    imagesc(axM, R); colormap(axM, copper);
    set(axM, 'XTick', [], 'YTick', [], 'CLim', [cmin, cmax]); xlim(axM, lims); ylim(axM, lims);
    cb = colorbar(axM); axM.Position = mpos;      % reset (colorbar shrinks the peer axes)
    cb.Position = [mx + mwid + posC(3)*0.02, posC(2), posC(3)*0.035, mpos(4)];
    cb.Ticks = [cmin, cmax]; cb.TickLabels = {sprintf('%.2f', cmin), sprintf('%.2f', cmax)};

    axT = axes('Position', [mx, posC(2) + posC(4) - mh, mwid, mh]);
    imagesc(axT, 1:n_bins, 1, ctr, a_range); colormap(axT, gray);     % A level of each column
    set(axT, 'XTick', [], 'YTick', []); xlim(axT, lims);
    title(axT, ttl);
    panel_label(axT, ch);

    axL = axes('Position', [posC(1), posC(2), mw, mpos(4)]);
    imagesc(axL, 1, 1:n_bins, ctr(:), a_range); colormap(axL, gray);  % A level of each row
    set(axL, 'XTick', [], 'YTick', []); ylim(axL, lims);
end

% ------------------------------------------------------------------------------
function panel_label(ax, ch)
% Bold panel letter just above the top-left corner of axes ax.
    text(ax, 0, 1.02, ch, 'Units', 'normalized', 'FontWeight', 'bold', ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left', 'Clipping', 'off');
end


% ------------------------------------------------------------------------------
function bare_y(ax)
% Strip the box and the whole y-axis (line, ticks, tick labels) from a panel, keeping only the
% x-axis. Any ylabel is preserved (YColor 'none' hides it, so restore its colour explicitly).
    set(ax, 'Box', 'off', 'YTick', [], 'YColor', 'none');
    set(get(ax, 'YLabel'), 'Color', 'k', 'Visible', 'on');
end

% ------------------------------------------------------------------------------
function plot_band(edges, X, mu_ref, sd_unit, color, name)
% Per-bin mean of X, standardized as (mean_X - mu_ref)./sd_unit, drawn as a staircase (no
% vertical bin edges, no fill) with a +/- SEM staircase band (SEM_X/sd_unit). Pass mu_ref=0,
% sd_unit=1 for the raw mean (panel f); pass the near mean and pooled SD for the standardized
% separation profile (panel g, where near is ~0 and far is the per-bin separation in SD units).
    mu = (mean(X, 1) - mu_ref) ./ sd_unit;
    e  = (std(X, 0, 1) ./ sqrt(size(X, 1))) ./ sd_unit;
    xs = [edges(1), repelem(edges(2:end-1), 2), edges(end)];   % staircase x for the per-bin band
    fill([xs, fliplr(xs)], [repelem(mu + e, 2), fliplr(repelem(mu - e, 2))], color, ...
        'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    stairs(edges, [mu, mu(end)], 'Color', color, 'LineWidth', 1, 'DisplayName', name);
end

% ------------------------------------------------------------------------------
function [lo, hi] = a_prior_quantiles(priors)
% From the shipped A-channel prior CDF (values ea, cumulative prob Na), return the
% 1st/99th percentiles.
    ea = priors.edges_a_pixel(:);
    Na = priors.cdf_a_pixel(:);
    if numel(ea) == numel(Na) + 1
        xq = ea(2:end);              % histcounts 'cdf': Na(k) = P(X <= ea(k+1))
    else
        xq = ea;
    end
    [Nu, iu] = unique(Na);           % strictly increasing support for interpolation
    xu = xq(iu);
    lo = interp1(Nu, xu, 0.01, 'linear', 'extrap');
    hi = interp1(Nu, xu, 0.99, 'linear', 'extrap');
end

% ------------------------------------------------------------------------------
function edges = equalize_cdf(n_bins, xvals, cdfvals, lo, hi)
% n_bins+1 bin edges placing equal CDF increments in each bin between A values lo and hi, from a
% monotone CDF (cdfvals at xvals). Edges sit at evenly spaced CDF levels between CDF(lo) and
% CDF(hi), inverted back to A values. Shared by the prior-equalized and JSD-profile-equalized
% bins (the only difference is which CDF you pass).
    [Cu, iu] = unique(cdfvals(:));               % strictly increasing CDF support
    xu = xvals(:); xu = xu(iu);
    clo = interp1(xu, Cu, lo, 'linear', 'extrap');
    chi = interp1(xu, Cu, hi, 'linear', 'extrap');
    edges = interp1(Cu, xu, linspace(clo, chi, n_bins + 1), 'linear', 'extrap');
end

% ------------------------------------------------------------------------------
function edges = prior_equalized_edges(n_bins, lo, hi, priors)
% Bin edges placing EQUAL PRIOR MASS per bin between lo and hi (histogram equalization), from
% the shipped prior CDF (ea values, Na cumulative).
    ea = priors.edges_a_pixel(:); Na = priors.cdf_a_pixel(:);
    if numel(ea) == numel(Na) + 1, ea = ea(2:end); end   % 'cdf': Na(k)=P(X<=ea(k+1))
    edges = equalize_cdf(n_bins, ea, Na, lo, hi);
end

