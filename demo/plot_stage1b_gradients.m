function plot_stage1b_gradients(cfg, gradient_pca, X, n_resp_images)
% PLOT_STAGE1B_GRADIENTS  The multi-scale first-derivative (gradient) structure of
%   natural images, and the gradient PCs the model can use (stage 1b).
%   plot_stage1b_gradients(cfg, gradient_pca, X)
%   plot_stage1b_gradients(cfg, gradient_pca, X, n_resp_images)
%
%   Draws the output of s1b_learn_gradient_pca: the H/V first-derivative responses
%   at the scales cfg.pcgrad.sd_list, on isolated 64x64 patches of the achromatic
%   (A) channel, and their joint PCA. It shows
%     1. horizontal and vertical responses are ~uncorrelated (H independent of V);
%     2. responses ARE strongly correlated across scale within each orientation;
%     3. PCA on all of them together gives a decorrelated multi-scale basis whose
%        PCs come out in H/V pairs -- nothing in the PCA imposes that.
%   With cfg.features.pca_gradient on, the model's PC large / mid / small gradient
%   mag features are the magnitudes of PC1-2, PC3-4 and PC5-6
%   (vislab.lib.pc_grad_response).
%
%   The filters drawn are exact: each is the response of the model's own filtering
%   (vislab.lib.multiscale_grad_responses, then the PC weights) to a single bright
%   pixel. At the model's nsd = cfg.pcgrad.nsd = 3 the Gaussian is cut off while
%   still ~32% of peak, so the filters look blocky; that is what the model uses.
%
% Inputs
%   cfg  config struct.
%   gradient_pca  learned PCA struct from s1b_learn_gradient_pca (in full mode,
%        learned from all natural images and saved; in quick mode, from one image).
%   X    gradient responses (second output of s1b_learn_gradient_pca).
%   n_resp_images  number of images X comes from (default gradient_pca.n_images,
%        i.e. X is what the PCA was run on). In quick mode with the gradient-PCA
%        model on, X is one image's responses while gradient_pca is the saved model;
%        the title then says so, and the PC correlations are only near identity (a PCA decorrelates
%        exactly only the data it was fitted to).
% Output
%   none (draws the figure)
%
% See also S1B_LEARN_GRADIENT_PCA, VISLAB.LIB.MULTISCALE_GRAD_RESPONSES,
%   VISLAB.LIB.PC_GRAD_RESPONSE, PLOT_STAGE1, PLOT_STAGE2

    sd_list = gradient_pca.sd_list;
    n_scales = numel(sd_list);
    nf = 2 * n_scales;
    scatter_pts = cfg.demo.scatter_points;   % cap for the SCATTER only (PCA uses every sample)
    H = X(:, 1:n_scales);  V = X(:, n_scales+1:end);

    % --- statistics: column order of X is [H sigma1..N, V sigma1..N] ---
    C_raw = corrcoef(X);                                        % (2*n_scales) square
    pca_coeff = gradient_pca.coeff;  explained = gradient_pca.explained;
    score = (X - gradient_pca.mu) * pca_coeff;                           % PC responses
    C_pc = corrcoef(score);                                     % PC response correlations (~identity)
    score2 = score(:, 1:2);                                     % first 2 PCs, for the scatter
    clear score
    feat_sigma = [sd_list, sd_list];     % sigma per feature column (for the corr-matrix ticks)

    % --- exact filters: impulse responses of the model's filtering. Because H is
    %     uncorrelated with V, each PC is (nearly) pure-H or pure-V. ---
    [raw_filt, pc_filt, K] = pc_filter_images(gradient_pca);
    pc_isH = sum(abs(pca_coeff(1:n_scales, :)), 1) >= sum(abs(pca_coeff(n_scales+1:end, :)), 1);

    cmap_div = local_diverging();                                      % red(-)-white-blue(+)

    % =====================================================================
    figure('Name', 'Stage 1b: Multi-scale gradient structure', ...
           'Position', [40 40 1500 980]);
    t = tiledlayout(3, 12, 'TileSpacing', 'loose', 'Padding', 'compact');
    t.Units = 'normalized'; t.OuterPosition = [0 0 1 0.93];   % leave a top strip for the title
    if nargin < 4 || isempty(n_resp_images), n_resp_images = gradient_pca.n_images; end
    img_txt = @(n) sprintf('%d natural image%s', n, repmat('s', 1, n ~= 1));
    if n_resp_images == gradient_pca.n_images
        src_txt = img_txt(gradient_pca.n_images);
    else
        src_txt = sprintf('PCs from %s; responses from %s', img_txt(gradient_pca.n_images), ...
            img_txt(n_resp_images));
    end
    annotation(gcf, 'textbox', [0.1 0.94 0.8 0.05], ...
        'String', sprintf('Stage 1b: joint dist. of gradients at different scales (%s)', ...
        src_txt), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold', 'FontSize', 12, 'EdgeColor', 'none');

    sc = n_scales:-1:1;   % scale order, largest sigma first
    sig_sc_lab = arrayfun(@(s) sprintf('\\sigma=%d', s), sd_list(sc), 'UniformOutput', false);

    % --- Row 1a: raw steerable filters, single grid (H top row, V bottom row) ---
    nexttile([1 6]);
    imagesc(local_kernel_grid(raw_filt(sc), raw_filt(n_scales + sc), K)); axis image; clim([-1 1]); colormap(gca, gray);
    set(gca, 'XTick', ((1:n_scales) - 0.5) * K, 'XTickLabel', sig_sc_lab, ...
             'YTick', [0.5 1.5] * K, 'YTickLabel', {'H', 'V'}, 'TickLength', [0 0]);
    title('raw steerable filters');

    % --- Row 1b: PCA filters, single grid (H-dominant PCs top, V-dominant bottom) ---
    % each sorted by variance; column j is the j-th H/V pair
    h_pcs = find(pc_isH);  v_pcs = find(~pc_isH);
    nexttile([1 6]);
    imagesc(local_kernel_grid(pc_filt(h_pcs), pc_filt(v_pcs), K));
    axis image; clim([-1 1]); colormap(gca, gray); hold on;
    set(gca, 'XTick', [], 'YTick', [], 'TickLength', [0 0]);
    for j = 1:numel(h_pcs)
        text((j-1)*K + 1, 1, sprintf('PC%d', h_pcs(j)), ...
             'VerticalAlignment', 'top', 'FontSize', 8, 'Color', 'w');
    end
    for j = 1:numel(v_pcs)
        text((j-1)*K + 1, K + 1, sprintf('PC%d', v_pcs(j)), ...
             'VerticalAlignment', 'top', 'FontSize', 8, 'Color', 'w');
    end
    title('PCA filters');

    % --- Row 2: raw H and V responses at the 3 largest scales (correlated clouds),
    %     then the first 2 joint PCs (decorrelated cloud) ---
    nobs = size(H, 1);
    si   = randperm(nobs, min(nobs, scatter_pts));   % random subsample for a readable scatter
    big3 = sc(1:3);                                  % 3 largest scales
    raw_lab = @(o) arrayfun(@(s) sprintf('%s \\sigma=%d', o, s), sd_list(big3), ...
        'UniformOutput', false);
    pc_lab = {'PC1', 'PC2'};
    local_scatter(H(:, big3), si, raw_lab('H'), 'horizontal steerable responses');
    local_scatter(V(:, big3), si, raw_lab('V'), 'vertical steerable responses');
    local_scatter(score2, si, pc_lab, 'first 2 PC''s');

    % --- Row 3a: response correlation matrix (H/V blocks, sigma-labelled) ---
    nexttile([1 3]);
    hv = n_scales + 0.5;
    % tick labels name orientation and scale, e.g. "H1" = horizontal at sigma = 1
    hv_lab = [repmat({'H'}, 1, n_scales), repmat({'V'}, 1, n_scales)];
    sig_lab = cellfun(@(o, s) sprintf('%s%d', o, s), hv_lab, num2cell(feat_sigma), ...
        'UniformOutput', false);
    imagesc(C_raw, [-1 1]); axis image; colormap(gca, cmap_div); colorbar; hold on;
    plot([hv hv], [0.5 nf+0.5], 'k-', 'LineWidth', 1.2);
    plot([0.5 nf+0.5], [hv hv], 'k-', 'LineWidth', 1.2);
    set(gca, 'XTick', 1:nf, 'XTickLabel', sig_lab, 'YTick', 1:nf, 'YTickLabel', sig_lab, ...
             'TickLength', [0 0]);
    xlabel('orientation, \sigma'); ylabel('orientation, \sigma');
    title('steerable response correlations');

    % --- Row 3b: PCA coefficients (rows = H/V x sigma, cols = PCs; shows alternation) ---
    nexttile([1 3]);
    mx = max(abs(pca_coeff(:)));
    imagesc(pca_coeff, [-mx mx]); axis image; colormap(gca, cmap_div); colorbar; hold on;
    plot([0.5 nf+0.5], [hv hv], 'k-', 'LineWidth', 1.2);   % divide H rows from V rows
    set(gca, 'XTick', 1:nf, 'YTick', 1:nf, 'YTickLabel', sig_lab, 'TickLength', [0 0]);
    xlabel('principal component'); ylabel('orientation, \sigma');
    title('PCA coefficients');

    % --- Row 3c: PC response correlation matrix (decorrelated: ~identity) ---
    nexttile([1 3]);
    imagesc(C_pc, [-1 1]); axis image; colormap(gca, cmap_div); colorbar;
    set(gca, 'XTick', 1:nf, 'YTick', 1:nf, 'TickLength', [0 0]);
    xlabel('principal component'); ylabel('principal component');
    title('PCA response correlations');

    % --- Row 3d: variance explained, with each PC's filter under its bar ---
    % A nested layout in this tile: the bars on top, a strip of filters below. The
    % strip keeps a 1:1 data aspect, so the filters stay square at any figure size;
    % its x range matches the bars', so filter j sits under bar j.
    t_var = tiledlayout(t, 4, 1, 'TileSpacing', 'none', 'Padding', 'none');
    t_var.Layout.Tile = 2 * 12 + 10;  t_var.Layout.TileSpan = [1 3];
    nexttile(t_var, [3 1]);
    bar(explained, 'FaceColor', [0.3 0.5 0.8]); hold on;
    plot(cumsum(explained), '-o', 'Color', [0.8 0.3 0.3], 'LineWidth', 1.2);
    ylabel('% variance'); ylim([0 105]); xlim([0.5 nf+0.5]);
    set(gca, 'XTick', 1:nf);
    title(sprintf('variance explained (PC1+2 = %.0f%%)', sum(explained(1:2))));
    nexttile(t_var);
    w = 0.8;                                        % filter width, x units
    for j = 1:nf
        k = pc_filt{j};  k = (k / max(abs(k(:))) + 1) / 2;   % [-1,1] -> [0,1] gray
        image('XData', [j - w/2, j + w/2], 'YData', [0 w], 'CData', repmat(k, 1, 1, 3));
    end
    set(gca, 'YDir', 'reverse', 'DataAspectRatio', [1 1 1], 'XLim', [0.5 nf+0.5], ...
        'YLim', [-0.05 w + 0.05], 'XTick', [], 'YTick', [], 'XColor', 'none', 'YColor', 'none');
    xlabel('principal component', 'Color', 'k');
end

function local_scatter(X, si, labs, ttl)
% 2D or 3D scatter of the 2 or 3 columns of X (subsampled at rows SI) in a 1x4
% tile, with the axes zoomed past outliers to the bulk and tick labels dropped.
    nexttile([1 4]);
    if size(X, 2) == 3
        scatter3(X(si, 1), X(si, 2), X(si, 3), 1, 'k', '.'); view(3);
        zlabel(labs{3}); set(gca, 'ZTickLabel', []);
    else
        scatter(X(si, 1), X(si, 2), 1, 'k', '.'); axis square;
    end
    grid on;
    local_bulk_lims(X);
    set(gca, 'XTickLabel', [], 'YTickLabel', []); % drop tick labels, keep grid
    xlabel(labs{1}); ylabel(labs{2});
    title(ttl);
end

function M = local_kernel_grid(top_kernels, bot_kernels, K)
% Two-row montage: TOP_KERNELS on the top row, BOT_KERNELS on the bottom row.
% Each kernel is padded to K x K and per-kernel normalized to [-1,1], then laid
% out left-to-right. Returns a (2K) x (ncol*K) image.
    rows = {top_kernels, bot_kernels};
    ncol = max(numel(top_kernels), numel(bot_kernels));
    M = zeros(2 * K, ncol * K);
    for r = 1:2
        ks = rows{r};
        for i = 1:numel(ks)
            k = ks{i};
            k = k / max(abs(k(:)));             % per-kernel normalize to [-1,1]
            [kh, kw] = size(k);
            r0 = (r-1)*K + floor((K - kh) / 2) + 1;
            c0 = (i-1)*K + floor((K - kw) / 2) + 1;
            M(r0:r0+kh-1, c0:c0+kw-1) = k;
        end
    end
end

function local_bulk_lims(X)
% Set the current axes' limits to each column of X's 0.5-99.5 percentile, so a
% few extreme outliers don't stretch the axes and flatten the bulk cloud.
    lims = {@xlim, @ylim, @zlim};
    for d = 1:size(X, 2)
        l = prctile(X(:, d), [0.5 99.5]);
        if diff(l) > 0, lims{d}(l); end
    end
end

function cmap = local_diverging()
% Red (negative) - white (zero) - blue (positive) diverging colormap.
    n   = 128;
    top = [ones(n, 1), linspace(0, 1, n)', linspace(0, 1, n)'];   % red -> white
    bot = [linspace(1, 0, n)', linspace(1, 0, n)', ones(n, 1)];   % white -> blue
    cmap = [top; bot];
end
