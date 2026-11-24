function plot_stage5_intermediate(cfg, ecc, R_near, R_far, col)
% PLOT_STAGE5_INTERMEDIATE  Show construction of the spot, gradient and border
%   decision variables.
%   plot_stage5_intermediate(cfg, ecc, R_near, R_far, col)
%
%   One figure, one column per DV, in the order they are built:
%     row 1  response cloud with the trained quadratic boundary (grid, no ticks)
%     row 2  each feature's proportional contribution to classification d'
%            (classify_normals d_con; see plot_dcon_pie)
%     row 3  resulting 1D DV distributions for near vs. far pairs
%   The response-cloud axis labels are coloured to match the contribution-pie
%   sections, tying each feature to its share of d'.
%
%   The columns follow the artifact, not cfg, so the figure always matches what
%   it is plotting: colour (dbnd.ha/hb present) splits the spot DV into
%   achromatic, chromatic and full spot columns; the gradient-PCA model
%   (dbnd.pg present) adds a multi-scale gradient DV column, which merges the PC
%   large / small gradient LLRs before the gradient DV.
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
% See also PLOT_STAGE5, PLOT_DCON_PIE, APPLY_DV, DECISION_BOUNDS_FILENAME
    if isempty(R_near), return; end

    try
        S = load(fullfile(cfg.paths.models, decision_bounds_filename(cfg, ecc)), 'dbnd');
        dbnd = S.dbnd;
    catch
        return;
    end
    names = cfg.features.names;

    % --- one entry per DV column: title, DV handle, its near/far inputs, labels ---
    C = struct('title', {}, 'dv', {}, 'near', {}, 'far', {}, 'labels', {}, 'pie', {});
    function add_col(ttl, dv, near, far, labels, pie)
        C(end+1) = struct('title', ttl, 'dv', dv, 'near', near, 'far', far, ...
            'labels', {labels}, 'pie', {pie});
    end

    spot_lab = {'Achromatic', 'CS-Small', 'CS-Large'};  spot_pie = {'A', 'CS-small', 'CS-large'};
    if isfield(dbnd, 'ha')
        dvha = quad2fun(dbnd.ha, 0);  dvhb = quad2fun(dbnd.hb, 0);
        nha = R_near(:, col.spot_achr);   fha = R_far(:, col.spot_achr);
        nhb = R_near(:, col.spot_chrom);  fhb = R_far(:, col.spot_chrom);
        add_col('Achromatic Spot DV', dvha, nha, fha, spot_lab, spot_pie);
        add_col('Chromatic Spot DV', dvhb, nhb, fhb, {'B (blue-yellow)', 'R (red-green)'}, {'B', 'R'});
        % combiner over [achromatic spot DV, chromatic spot DV]
        add_col('Full Spot DV', quad2fun(dbnd.h, 0), ...
            [apply_dv(dvha, nha), apply_dv(dvhb, nhb)], [apply_dv(dvha, fha), apply_dv(dvhb, fhb)], ...
            {'Achromatic Spot DV', 'Chromatic Spot DV'}, {'achromatic', 'chromatic'});
    else
        add_col('Spot DV', quad2fun(dbnd.h, 0), R_near(:, col.spot), R_far(:, col.spot), ...
            spot_lab, spot_pie);
    end

    % gradient DV: with the gradient-PCA model, its inputs are the multi-scale
    % gradient DV (the 1 px edge mag and PC gradient mag LLRs merged by dbnd.pg)
    % and the bar LLRs
    near_e = R_near(:, col.edge);  far_e = R_far(:, col.edge);
    edge_names = names(cfg.features.edge_dv_dims);
    if isfield(dbnd, 'pg')
        dvpg = quad2fun(dbnd.pg, 0);
        pg_names = names(cfg.features.ms_grad_dims);
        add_col('Multi-scale Gradient DV', dvpg, R_near(:, col.ms_grad), R_far(:, col.ms_grad), ...
            pg_names, pg_names);
        rest = setdiff(col.edge, col.ms_grad, 'stable');
        near_e = [apply_dv(dvpg, R_near(:, col.ms_grad)), R_near(:, rest)];
        far_e  = [apply_dv(dvpg, R_far(:,  col.ms_grad)), R_far(:,  rest)];
        edge_names = [{'multi-scale gradient DV'}, ...
            names(setdiff(cfg.features.edge_dv_dims, cfg.features.ms_grad_dims, 'stable'))];
    end
    % The gradient DV can use more than 3 features; the cloud shows the first 3,
    % with the boundary sliced at the others' means.
    add_col('Gradient DV', quad2fun(dbnd.e, 0), near_e, far_e, edge_names, edge_names);

    add_col('Border DV', quad2fun(dbnd.b, 0), R_near(:, col.border), R_far(:, col.border), ...
        {'Border Edge Mag', 'Border Bar Mag'}, {'border edge', 'border bar'});

    % --- draw: one column per DV ---
    nc = numel(C);
    figure('Name', 'Stage 5A: Spot, Gradient & Border DV Construction', ...
        'Position', [60 80 330 * nc 950]);
    tiledlayout(3, nc, 'TileSpacing', 'loose', 'Padding', 'loose');   % room between DVs
    for c = 1:nc
        nexttile(c);
        if size(C(c).near, 2) >= 3
            local_scatter3_bd(C(c).dv, C(c).near, C(c).far, C(c).labels);
        else
            local_scatter2_bd(C(c).dv, C(c).near, C(c).far, C(c).labels);
        end
        title(['Constructing ' C(c).title]);
        nexttile(nc + c);
        plot_dcon_pie(C(c).near, C(c).far, C(c).pie);
        nexttile(2 * nc + c);
        local_dv_hist(C(c).dv, C(c).near, C(c).far, C(c).title);
        if c == 1, dv_legend(); end
    end
end

% ------------------------------------------------------------------------------
function local_scatter3_bd(dv, near_pts, far_pts, labels)
% 3D response cloud (near = blue, far = red) with the quadratic decision
% boundary as a grey, grey-meshed dv = 0 isosurface. Ticks off, grid on, and
% axis labels coloured to match the d'-contribution pie slices (dim_colors).
% With more than 3 features, the cloud shows the first 3 and the boundary is
% the slice with features 4..end held at their mean over all plotted pairs.
    dcol = dim_colors(numel(labels));
    fixed = mean([near_pts(:, 4:end); far_pts(:, 4:end)], 1);
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
    V = reshape(apply_dv(dv, [Xg(:), Yg(:), Zg(:), repmat(fixed, numel(Xg), 1)]), size(Xg));
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
% Ticks off, grid on, axis labels coloured to match the contribution pie.
    dcol = dim_colors(numel(labels));
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
