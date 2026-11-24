function plot_stage2(cfg, ecc)
% PLOT_STAGE2  Show the natural feature priors (PDFs) and the
%   task-optimized adaptive bins for the spot, edge and bar features.
%   plot_stage2(cfg, ecc)
%
%   Rows of three: the spot features (A pixel, small and large centre-surround);
%   in colour mode, the B (blue-yellow) and R (red-green) pixels; the edge
%   magnitude and bar magnitude and orientation; with pca_gradient, the three PC
%   gradient magnitudes.
%
% Inputs
%   cfg  - config struct.
%   ecc  - eccentricity divisor, used only to name the saved priors file.
% Output
%   none (draws the figure)
%
% See also PRIOR_FILENAME, VISLAB.NAT_STAT_BAYES.LOAD_BIN_BOUNDS, PLOT_STAGE1B_GRADIENTS
    out_path = fullfile(cfg.paths.models, prior_filename(cfg, ecc));
    if ~isfile(out_path), return; end
    priors = load(out_path);

    bin_file = bins_filename(cfg);
    bin_path = fullfile(cfg.paths.models, bin_file);
    has_bins = isfile(bin_path);
    if has_bins
        S = load(bin_path);
        ecc_idx = find(S.eccs == ecc, 1);
    end

    % one row of three per feature family: spot; colour pixels (colour mode only);
    % edge and bar; gradient PCs (pca_gradient only)
    has_pc = isfield(priors, 'edges_pc1');     % gradient-PCA priors (pca_gradient only)
    nrows = 2 + cfg.features.color + has_pc;
    figure('Name', 'Stage 2: Natural Priors, and task-optimized bins', ...
        'Position', [100 100 1100 nrows*230]);
    t = tiledlayout(nrows, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, 'Stage 2: Natural Priors, and task-optimized bins');
    tile = @(row, col) (row - 1) * 3 + col;

    trunc_xlim = @(e, N) xlim([e(max(1, find(N >= 0.01, 1, 'first'))), ...
        e(max(1, find(N >= 0.99, 1, 'first')))]);

    % Kernel insets sit inside each PDF plot's top-right corner, each kernel a
    % fixed s_px-pixel square at any figure size (see local_add_inset).
    s_px = 28;
    [~, k_edge] = vislab.lib.steerable_kernels(cfg.dv.sd1, cfg.dv.nsd1);    % vertical edge
    [~, ~, k_bar] = vislab.lib.gauss_deriv2_kernels(cfg.dv.sd2, cfg.dv.nsd2); % vertical bar
    add_inset = @(varargin) local_add_inset(gca, s_px, varargin{:});

    function plot_feature(ax_idx, e, N, dim, xl_str)
        nexttile(t, ax_idx);
        pdf = diff([0, N]); % PDF from CDF
        plot(e(1:end-1), pdf, 'LineWidth', 2); hold on;
        set(gca, 'YTick', []); % Remove y-axis ticks for PDF plots
        % No y-limit: the per-bin PDF can exceed 1, and its scale differs per feature.
        trunc_xlim(e, N);
        if has_bins && dim <= size(S.bin_bounds, 1) && ~isempty(S.bin_bounds{dim, ecc_idx})
            bnds = S.bin_bounds{dim, ecc_idx};
            for b = bnds', xline(b, 'k-', 'LineWidth', 0.5); end
        end
        xlabel(xl_str);
    end

    % --- row 1: spot features ---
    plot_feature(tile(1, 1), priors.edges_a_pixel, priors.cdf_a_pixel, 1, 'Achromatic');
    plot_feature(tile(1, 2), priors.edges_cs_linear_small, ...
        priors.cdf_cs_linear_small, 13, 'Center-Surround (Small)');
    add_inset(local_cs_kernel(3, 2));
    plot_feature(tile(1, 3), priors.edges_cs_linear_large, ...
        priors.cdf_cs_linear_large, 14, 'Center-Surround (Large)');
    add_inset(local_cs_kernel(5, 4));

    % --- colour pixels (colour mode only) ---
    row = 2;
    if cfg.features.color
        plot_feature(tile(row, 1), priors.edges_b_pixel, priors.cdf_b_pixel, 2, ...
            'Blue-Yellow (B) Pixel');
        plot_feature(tile(row, 2), priors.edges_r_pixel, priors.cdf_r_pixel, 3, ...
            'Red-Green (R) Pixel');
        row = row + 1;
    end

    % --- edge and bar features ---
    plot_feature(tile(row, 1), priors.edges_edge_mag, ...
        priors.cdf_edge_mag, 5, '1st Deriv (Edge) Magnitude');
    add_inset(k_edge);
    plot_feature(tile(row, 2), priors.edges_bar_mag, priors.cdf_bar_mag, 9, ...
        '2nd Deriv (Bar) Magnitude');
    add_inset(k_bar);
    plot_feature(tile(row, 3), priors.edges_bar_ori, ...
        priors.cdf_bar_ori, 10, '2nd Deriv (Bar) Orientation (degrees)');
    xlim([-90 90]); xticks([-90 0 90]);
    add_inset(k_bar);

    % --- MULTI-SCALE GRADIENT PC FEATURES (pca_gradient only) ---
    % Insets: the PC pair each feature is the magnitude of (PC1|PC2, PC3|PC4, PC5|PC6),
    % drawn exactly as the model applies them (pc_filter_images).
    if has_pc
        pc_titles = {'PC Large Gradient Magnitude', 'PC Mid Gradient Magnitude', ...
            'PC Small Gradient Magnitude'};
        if ~isempty(cfg.pcgrad.model), [~, pc_filt] = pc_filter_images(cfg.pcgrad.model); end
        for j = 1:3
            plot_feature(tile(row + 1, j), priors.(sprintf('edges_pc%d', j)), ...
                priors.(sprintf('cdf_pc%d', j)), 14+j, pc_titles{j});
            if isempty(cfg.pcgrad.model), continue; end
            add_inset(pc_filt{2*j-1}, pc_filt{2*j});
        end
    end
end

% ------------------------------------------------------------------------------
function local_add_inset(host, s_px, varargin)
% Draw the kernel(s) in VARARGIN side by side, each scaled to its own max |value|
% and shown as an s_px x s_px pixel square, in the top-right corner of axes HOST.
% The inset is a separate pixel-unit axes, re-pinned to HOST after every redraw
% (its MarkedClean event), so it keeps its place, size and squareness when the
% figure is resized or docked.
    n = numel(varargin);
    ax = axes(ancestor(host, 'figure'), 'Units', 'pixels', 'Position', [1 1 n*s_px s_px]);
    for i = 1:n
        k = varargin{i};
        image(ax, 'XData', [i-1, i] + [1 -1]/(2*size(k, 2)), ...
            'YData', [0, 1] + [1 -1]/(2*size(k, 1)), ...
            'CData', k / max(abs(k(:))), 'CDataMapping', 'scaled');
    end
    set(ax, 'CLim', [-1 1], 'YDir', 'reverse', 'XLim', [0 n], 'YLim', [0 1], ...
        'DataAspectRatio', [1 1 1], 'Visible', 'off');
    colormap(ax, gray);
    addlistener(host, 'MarkedClean', @(~, ~) local_pin_inset(ax, host));
    local_pin_inset(ax, host);
end

function local_pin_inset(ax, host)
% Move inset axes AX to the top-right corner of HOST's plot box (4 px margin).
    if ~isvalid(ax) || ~isvalid(host), return; end
    p = getpixelposition(host, true);
    sz = ax.Position(3:4);
    pos = [p(1) + p(3) - sz(1) - 4, p(2) + p(4) - sz(2) - 4, sz];
    if any(abs(ax.Position - pos) > 0.5), ax.Position = pos; end
end

function k = local_cs_kernel(width, cs_type)
% The centre-surround kernel the model uses: vislab.lib.center_surround's response
% to a single bright pixel, trimmed to its support (the kernels are symmetric, so
% convolution's flip doesn't matter).
    d = zeros(11);  d(6, 6) = 1;
    k = vislab.lib.center_surround(d, width, cs_type);
    k = k(any(k, 2), any(k, 1));
end

