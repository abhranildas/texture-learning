function plot_stage5_intermediate(cfg, ecc, R_near, R_far, col)
% PLOT_STAGE5_INTERMEDIATE  Show construction of the spot, edge and border
%   decision variables.
%   plot_stage5_intermediate(cfg, ecc, R_near, R_far, col)
%
%   One figure, one row per DV:
%     col 1  response cloud with the trained quadratic boundary (grid, no ticks)
%     col 2  each feature's proportional contribution to classification d'
%            (classify_normals d_con; see plot_dcon_bar)
%     col 3  resulting 1D DV distributions for near vs. far pairs
%   The response-cloud axis labels are coloured to match the contribution-bar
%   sections, tying each feature to its share of d'.
%
%   Whether the artifact was trained with colour (dbnd.ha/hb present) decides
%   the layout: achromatic-only shows 3 rows (spot, edge, border); colour shows
%   5 (achromatic spot, chromatic spot, full spot, edge, border) -- branching on
%   the artifact, not cfg.features.color, so the figure always matches what it
%   is plotting.
%
% Inputs
%   cfg           - config struct.
%   ecc           - eccentricity divisor, used to load the decision-bounds file.
%   R_near, R_far - response matrices for near/far pairs (pair_responses format).
%   col           - column-layout struct (from pair_responses /
%                   s5_train_decision_vars / compute_demo_responses) giving the
%                   R_near/R_far column layout.
% Output
%   none (draws the figure)
%
% See also PLOT_STAGE5, PLOT_DCON_BAR, APPLY_DV, DECISION_BOUNDS_FILENAME
    if isempty(R_near), return; end

    try
        S = load(fullfile(cfg.paths.models, decision_bounds_filename(cfg, ecc)), 'dbnd');
        dbnd = S.dbnd;
    catch
        return;
    end
    dve = quad2fun(dbnd.e, 0);
    dvb = quad2fun(dbnd.b, 0);
    colour_mode = isfield(dbnd, 'ha');

    if colour_mode
        nrows = 5;
        figure('Name', 'Stage 5A: Spot, Edge & Border DV Construction', ...
            'Position', [120 40 1300 1500]);
        dvha = quad2fun(dbnd.ha, 0);
        dvhb = quad2fun(dbnd.hb, 0);
        dvh2 = quad2fun(dbnd.h,  0);   % combiner over [achromatic spot DV, chromatic spot DV]

        % ==========================================
        % ROW 1: ACHROMATIC SPOT DV  (features col.spot_achr)
        % ==========================================
        near_ha = R_near(:, col.spot_achr);  far_ha = R_far(:, col.spot_achr);
        subplot(nrows, 3, 1);
        local_scatter3_bd(dvha, near_ha, far_ha, {'Achromatic', 'CS-Small', 'CS-Large'});
        title('Constructing Achromatic Spot DV');
        subplot(nrows, 3, 2);
        plot_dcon_bar(near_ha, far_ha, {'A', 'CS-small', 'CS-large'});
        subplot(nrows, 3, 3);
        local_dv_hist(dvha, near_ha, far_ha, 'Achromatic Spot DV');
        dv_legend();

        % ==========================================
        % ROW 2: CHROMATIC SPOT DV  (features col.spot_chrom)
        % ==========================================
        near_hb = R_near(:, col.spot_chrom);  far_hb = R_far(:, col.spot_chrom);
        subplot(nrows, 3, 4);
        local_scatter2_bd(dvhb, near_hb, far_hb, {'B (blue-yellow)', 'R (red-green)'});
        title('Constructing Chromatic Spot DV');
        subplot(nrows, 3, 5);
        plot_dcon_bar(near_hb, far_hb, {'B', 'R'});
        subplot(nrows, 3, 6);
        local_dv_hist(dvhb, near_hb, far_hb, 'Chromatic Spot DV');

        % ==========================================
        % ROW 3: FULL SPOT DV  ([achromatic spot DV, chromatic spot DV])
        % ==========================================
        near_h2 = [apply_dv(dvha, near_ha), apply_dv(dvhb, near_hb)];
        far_h2  = [apply_dv(dvha, far_ha),  apply_dv(dvhb, far_hb)];
        subplot(nrows, 3, 7);
        local_scatter2_bd(dvh2, near_h2, far_h2, {'Achromatic Spot DV', 'Chromatic Spot DV'});
        title('Constructing Full Spot DV');
        subplot(nrows, 3, 8);
        plot_dcon_bar(near_h2, far_h2, {'achromatic', 'chromatic'});
        subplot(nrows, 3, 9);
        local_dv_hist(dvh2, near_h2, far_h2, 'Full Spot DV');

        row_edge = 10;  row_border = 13;
    else
        nrows = 3;
        figure('Name', 'Stage 5A: Spot, Edge & Border DV Construction', ...
            'Position', [120 60 1300 950]);
        dvh = quad2fun(dbnd.h, 0);

        % ==========================================
        % ROW 1: SPOT DV  (features col.spot = [1 13 14])
        % ==========================================
        near_h = R_near(:, col.spot);  far_h = R_far(:, col.spot);
        subplot(nrows, 3, 1);
        local_scatter3_bd(dvh, near_h, far_h, {'Achromatic', 'CS-Small', 'CS-Large'});
        title('Constructing Spot DV');
        subplot(nrows, 3, 2);
        plot_dcon_bar(near_h, far_h, {'A', 'CS-small', 'CS-large'});
        subplot(nrows, 3, 3);
        local_dv_hist(dvh, near_h, far_h, 'Spot DV');
        dv_legend();

        row_edge = 4;  row_border = 7;
    end

    % ==========================================
    % ROW: EDGE DV  (features col.edge)
    % ==========================================
    near_e = R_near(:, col.edge);  far_e = R_far(:, col.edge);
    subplot(nrows, 3, row_edge);
    local_scatter3_bd(dve, near_e, far_e, {'Edge Mag', 'Bar Mag', 'Bar Ori'});
    title('Constructing Edge DV');
    subplot(nrows, 3, row_edge + 1);
    plot_dcon_bar(near_e, far_e, {'edge mag', 'bar mag', 'bar ori'});
    subplot(nrows, 3, row_edge + 2);
    local_dv_hist(dve, near_e, far_e, 'Edge DV');

    % ==========================================
    % ROW: BORDER DV  (features col.border)
    % ==========================================
    near_b = R_near(:, col.border);  far_b = R_far(:, col.border);
    subplot(nrows, 3, row_border);
    local_scatter2_bd(dvb, near_b, far_b, {'Border Edge Mag', 'Border Bar Mag'});
    title('Constructing Border DV');
    subplot(nrows, 3, row_border + 1);
    plot_dcon_bar(near_b, far_b, {'border edge', 'border bar'});
    subplot(nrows, 3, row_border + 2);
    local_dv_hist(dvb, near_b, far_b, 'Border DV');
end

% ------------------------------------------------------------------------------
function local_scatter3_bd(dv, near_pts, far_pts, labels)
% 3D response cloud (near = blue, far = red) with the quadratic decision
% boundary as a grey, grey-meshed dv = 0 isosurface. Ticks off, grid on, and
% axis labels coloured to match the d'-contribution bar sections (lines(dim)).
    dcol = lines(numel(labels));
    hold on;
    scatter3(far_pts(:,1),  far_pts(:,2),  far_pts(:,3),  2, 'r', 'filled', ...
        'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.6);
    scatter3(near_pts(:,1), near_pts(:,2), near_pts(:,3), 2, 'b', 'filled', ...
        'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.6);

    x_min = min([near_pts(:,1); far_pts(:,1)]) - 1;
    x_max = max([near_pts(:,1); far_pts(:,1)]) + 1;
    y_min = min([near_pts(:,2); far_pts(:,2)]) - 1;
    y_max = max([near_pts(:,2); far_pts(:,2)]) + 1;
    z_min = min([near_pts(:,3); far_pts(:,3)]) - 1;
    z_max = max([near_pts(:,3); far_pts(:,3)]) + 1;

    [Xg, Yg, Zg] = meshgrid(linspace(x_min, x_max, 40), linspace(y_min, y_max, 40), ...
        linspace(z_min, z_max, 40));
    V = reshape(apply_dv(dv, [Xg(:), Yg(:), Zg(:)]), size(Xg));
    fv = isosurface(Xg, Yg, Zg, V, 0);
    if ~isempty(fv.vertices)
        local_draw_surface(fv);
    end
    view(3); grid on;
    set(gca, 'XTickLabel', [], 'YTickLabel', [], 'ZTickLabel', []);   % no ticks, keep grid
    xlabel(labels{1}, 'Color', dcol(1,:));
    ylabel(labels{2}, 'Color', dcol(2,:));
    zlabel(labels{3}, 'Color', dcol(3,:));
end

% ------------------------------------------------------------------------------
function local_scatter2_bd(dv, near_pts, far_pts, labels)
% 2D response cloud with the quadratic decision boundary as the dv = 0 contour.
% Ticks off, grid on, axis labels coloured to match the contribution bar.
    dcol = lines(numel(labels));
    hold on;
    scatter(far_pts(:,1),  far_pts(:,2),  2, 'r', 'filled', 'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', 0.6);
    scatter(near_pts(:,1), near_pts(:,2), 2, 'b', 'filled', 'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', 0.6);

    x_min = min([near_pts(:,1); far_pts(:,1)]) - 1; x_max = max([near_pts(:,1); far_pts(:,1)]) + 1;
    y_min = min([near_pts(:,2); far_pts(:,2)]) - 1; y_max = max([near_pts(:,2); far_pts(:,2)]) + 1;
    [Xg, Yg] = meshgrid(linspace(x_min, x_max, 200), linspace(y_min, y_max, 200));
    Zg = reshape(apply_dv(dv, [Xg(:), Yg(:)]), size(Xg));
    contour(Xg, Yg, Zg, [0 0], 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
    grid on;
    set(gca, 'XTickLabel', [], 'YTickLabel', []);                     % no ticks, keep grid
    xlabel(labels{1}, 'Color', dcol(1,:));
    ylabel(labels{2}, 'Color', dcol(2,:));
end

% ------------------------------------------------------------------------------
function local_draw_surface(fv)
% Draw a decision-boundary isosurface as a grey face with a grey mesh.
    fv = reducepatch(fv, 0.15);        % coarser mesh so the grey wireframe reads
    p = patch(fv);
    p.FaceColor = [0.7 0.7 0.7]; p.FaceAlpha = 0.35;
    p.EdgeColor = [0.5 0.5 0.5]; p.EdgeAlpha = 0.6;
    camlight; lighting gouraud;
end

% ------------------------------------------------------------------------------
function local_dv_hist(dv, near_pts, far_pts, xlab)
% Overlaid near/far histograms of the scalar decision variable, current axes.
    hold on;
    histogram(apply_dv(dv, far_pts),  'FaceColor', 'r', 'Normalization', 'pdf', ...
        'EdgeColor', 'none', 'FaceAlpha', 0.6);
    histogram(apply_dv(dv, near_pts), 'FaceColor', 'b', 'Normalization', 'pdf', ...
        'EdgeColor', 'none', 'FaceAlpha', 0.6);
    set(gca, 'YTick', []);
    xlabel(xlab);
end
