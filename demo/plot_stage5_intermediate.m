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
%   it is plotting: colour (decision_bounds.spot_achr/.spot_chrom present) splits
%   the spot DV into achromatic, chromatic and full spot columns; the gradient-PCA
%   model (decision_bounds.ms_grad present) adds a multi-scale gradient DV column,
%   which merges the PC large / small gradient LLRs before the gradient DV.
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
        S = load(fullfile(cfg.paths.models, decision_bounds_filename(cfg, ecc)), 'decision_bounds');
        decision_bounds = S.decision_bounds;
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
    if isfield(decision_bounds, 'spot_achr')
        spot_achr_dv = quad2fun(decision_bounds.spot_achr, 0);
        spot_chrom_dv = quad2fun(decision_bounds.spot_chrom, 0);
        nha = R_near(:, col.spot_achr);   fha = R_far(:, col.spot_achr);
        nhb = R_near(:, col.spot_chrom);  fhb = R_far(:, col.spot_chrom);
        add_col('Achromatic Spot DV', spot_achr_dv, nha, fha, spot_lab, spot_pie);
        add_col('Chromatic Spot DV', spot_chrom_dv, nhb, fhb, ...
            {'B (blue-yellow)', 'R (red-green)'}, {'B', 'R'});
        % combiner over [achromatic spot DV, chromatic spot DV]
        add_col('Full Spot DV', quad2fun(decision_bounds.spot, 0), ...
            [apply_dv(spot_achr_dv, nha), apply_dv(spot_chrom_dv, nhb)], ...
            [apply_dv(spot_achr_dv, fha), apply_dv(spot_chrom_dv, fhb)], ...
            {'Achromatic Spot DV', 'Chromatic Spot DV'}, {'achromatic', 'chromatic'});
    else
        add_col('Spot DV', quad2fun(decision_bounds.spot, 0), R_near(:, col.spot), ...
            R_far(:, col.spot), ...
            spot_lab, spot_pie);
    end

    % gradient DV: with the gradient-PCA model, its inputs are the multi-scale
    % gradient DV (the 1 px edge mag and PC gradient mag LLRs merged by decision_bounds.ms_grad)
    % and the bar LLRs
    near_e = R_near(:, col.edge);  far_e = R_far(:, col.edge);
    edge_names = names(cfg.features.edge_dv_dims);
    if isfield(decision_bounds, 'ms_grad')
        ms_grad_dv = quad2fun(decision_bounds.ms_grad, 0);
        pg_names = names(cfg.features.ms_grad_dims);
        add_col('Multi-scale Gradient DV', ms_grad_dv, R_near(:, col.ms_grad), ...
            R_far(:, col.ms_grad), ...
            pg_names, pg_names);
        rest = setdiff(col.edge, col.ms_grad, 'stable');
        near_e = [apply_dv(ms_grad_dv, R_near(:, col.ms_grad)), R_near(:, rest)];
        far_e  = [apply_dv(ms_grad_dv, R_far(:,  col.ms_grad)), R_far(:,  rest)];
        edge_names = [{'multi-scale gradient DV'}, ...
            names(setdiff(cfg.features.edge_dv_dims, cfg.features.ms_grad_dims, 'stable'))];
    end
    % The gradient DV can use more than 3 features; the cloud shows the first 3,
    % with the boundary sliced at the others' means.
    add_col('Gradient DV', quad2fun(decision_bounds.edge, 0), near_e, far_e, ...
        edge_names, edge_names);

    add_col('Border DV', quad2fun(decision_bounds.border, 0), R_near(:, col.border), ...
        R_far(:, col.border), ...
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
        plot_dv_hist(apply_dv(C(c).dv, C(c).near), apply_dv(C(c).dv, C(c).far), C(c).title);
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

    xl = plot_range(near_pts(:,1), far_pts(:,1));    % middle 99% of each axis
    yl = plot_range(near_pts(:,2), far_pts(:,2));
    zl = plot_range(near_pts(:,3), far_pts(:,3));
    [Xg, Yg, Zg] = meshgrid(linspace(xl(1), xl(2), 40), linspace(yl(1), yl(2), 40), ...
        linspace(zl(1), zl(2), 40));
    V = reshape(apply_dv(dv, [Xg(:), Yg(:), Zg(:), repmat(fixed, numel(Xg), 1)]), size(Xg));
    fv = isosurface(Xg, Yg, Zg, V, 0);
    if ~isempty(fv.vertices)
        local_draw_surface(fv);
    end
    view(3); grid on;  xlim(xl); ylim(yl); zlim(zl);
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

    xl = plot_range(near_pts(:,1), far_pts(:,1));  yl = plot_range(near_pts(:,2), far_pts(:,2));
    [Xg, Yg] = meshgrid(linspace(xl(1), xl(2), 200), linspace(yl(1), yl(2), 200));
    Zg = reshape(apply_dv(dv, [Xg(:), Yg(:)]), size(Xg));
    contour(Xg, Yg, Zg, [0 0], 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
    grid on;  xlim(xl); ylim(yl);
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

