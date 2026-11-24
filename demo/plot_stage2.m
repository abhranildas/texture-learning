function plot_stage2(cfg, ecc)
% PLOT_STAGE2  Show the natural feature priors (PDFs) and the
%   task-optimized adaptive bins for the spot, edge and bar features.
%   plot_stage2(cfg, ecc)
%
%   In colour mode, adds the B (blue-yellow) and R (red-green) pixel priors
%   alongside the achromatic spot features.
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

    if cfg.features.color, nrows = 5; else, nrows = 4; end
    has_pc = isfield(priors, 'epc1');     % gradient-PCA priors (pca_gradient only)
    nrows = nrows + 2 * has_pc;             % three PC panels: two more rows
    figure('Name', 'Stage 2: Natural Priors, and task-optimized bins', ...
        'Position', [100 100 800 nrows*250]);
    t = tiledlayout(nrows, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, 'Stage 2: Natural Priors, and task-optimized bins');

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

    % --- SPOT FEATURES (Rows 1 & 2; +B/R rows if colour) ---
    % 1. Achromatic (Dim 1)
    plot_feature(1, priors.ea, priors.Na, 1, 'Achromatic');

    if cfg.features.color
        % 1b. Blue-Yellow pixel (Dim 2)
        plot_feature(2, priors.eb, priors.Nb, 2, 'Blue-Yellow (B) Pixel');
    end

    % 2. Center-Surround Small (Dim 13)
    plot_feature(3, priors.ecs2, priors.Ncs2, 13, 'Center-Surround (Small)');
    add_inset(local_cs_kernel(3, 2));

    if cfg.features.color
        % 2b. Red-Green pixel (Dim 3)
        plot_feature(4, priors.er, priors.Nr, 3, 'Red-Green (R) Pixel');
        cs_large_idx = 5;
    else
        cs_large_idx = 4;
    end

    % 3. Center-Surround Large (Dim 14)
    plot_feature(cs_large_idx, priors.ecs4, priors.Ncs4, 14, 'Center-Surround (Large)');
    add_inset(local_cs_kernel(5, 4));

    % --- EDGE FEATURES ---
    % skip the empty slot beside CS-Large's row
    if cfg.features.color, edge_row = 7; else, edge_row = 5; end

    % 4. 1st Deriv Magnitude / Edge (Dim 5)
    plot_feature(edge_row, priors.em, priors.Nm, 5, '1st Deriv (Edge) Magnitude');
    add_inset(k_edge);

    % 5. 1st Deriv Orientation / Edge (Dim 6)
    plot_feature(edge_row+1, priors.eo, priors.No, 6, '1st Deriv (Edge) Orientation (degrees)');
    xlim([-180 180]); xticks([-180 0 180]);
    add_inset(k_edge);

    % --- BAR FEATURES ---
    bar_row = edge_row + 2;

    % 6. 2nd Deriv Magnitude / Bar (Dim 9)
    plot_feature(bar_row, priors.em2, priors.Nm2, 9, '2nd Deriv (Bar) Magnitude');
    add_inset(k_bar);

    % 7. 2nd Deriv Orientation / Bar (Dim 10)
    plot_feature(bar_row+1, priors.eo2, priors.No2, 10, '2nd Deriv (Bar) Orientation (degrees)');
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
            plot_feature(bar_row+1+j, priors.(sprintf('epc%d', j)), ...
                priors.(sprintf('Npc%d', j)), 14+j, pc_titles{j});
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

