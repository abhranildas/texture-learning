function plot_stage5(cfg, ecc, R_near, R_far, col)
% PLOT_STAGE5  Show construction of the content DV and the final combined
%   (border + content) decision boundary.
%   plot_stage5(cfg, ecc, R_near, R_far, col)
%
%   One figure, one row per stage:
%     col 1  response cloud / decision map with the trained boundary (grid, no ticks)
%     col 2  proportional contribution to classification d' (plot_dcon_pie)
%     col 3  resulting 1D DV distributions for near vs. far pairs
%   Response-cloud axis labels are coloured to match the contribution-pie slices.
%   (This is the figure formerly titled 5C; the old 5B border panel now lives in
%   plot_stage5_intermediate's bottom row.)
%
% Inputs
%   cfg           - config struct.
%   ecc           - eccentricity divisor (used only to load the DV handles).
%   R_near, R_far - response matrices for near/far pairs (pair_responses format).
%   col           - column-layout struct (from pair_responses /
%                   s5_train_decision_vars / compute_demo_responses) giving the
%                   R_near/R_far column layout, which depends on cfg.features.color.
% Output
%   none (draws the figure)
%
% See also PLOT_STAGE5_INTERMEDIATE, PLOT_DCON_PIE, APPLY_DV, LOAD_DV_HANDLES
    if isempty(R_near), return; end

    % dv.h has the same signature (function of the full spot-LLR column) whether or
    % not colour is on -- load_dv_handles composes the two-step spot DV if needed.
    try
        dv = load_dv_handles(cfg, ecc, true);
    catch
        return;
    end

    % Compute DVs: R columns given by COL (spot/edge/power/border)
    content_near = [R_near(:, col.power), apply_dv(dv.h, R_near(:, col.spot)), ...
        apply_dv(dv.e, R_near(:, col.edge))];
    content_far  = [R_far(:, col.power),  apply_dv(dv.h, R_far(:, col.spot)),  ...
        apply_dv(dv.e, R_far(:, col.edge))];

    same_c = apply_dv(dv.c, content_near);
    diff_c = apply_dv(dv.c, content_far);
    same_b = apply_dv(dv.b, R_near(:, col.border));
    diff_b = apply_dv(dv.b, R_far(:, col.border));

    final_near = [same_c, same_b];   % [content DV, border DV] for near pairs
    final_far  = [diff_c, diff_b];

    figure('Name', 'Stage 5B: Content & Overall DV Boundaries', 'Position', [180 100 1300 800]);

    % ==========================================
    % ROW 1: CONTENT DV  ([power, spot, edge])
    % ==========================================
    ccol = dim_colors(3);
    subplot(2, 3, 1); hold on;
    scatter3(content_far(:,1),  content_far(:,2),  content_far(:,3),  2, 'r', 'filled', ...
        'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.6);
    scatter3(content_near(:,1), content_near(:,2), content_near(:,3), 2, 'b', 'filled', ...
        'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.6);
    x_min_c = min([content_near(:,1); content_far(:,1)]) - 1;
    x_max_c = max([content_near(:,1); content_far(:,1)]) + 1;
    y_min_c = min([content_near(:,2); content_far(:,2)]) - 1;
    y_max_c = max([content_near(:,2); content_far(:,2)]) + 1;
    z_min_c = min([content_near(:,3); content_far(:,3)]) - 1;
    z_max_c = max([content_near(:,3); content_far(:,3)]) + 1;
    [Xgc, Ygc, Zgc] = meshgrid(linspace(x_min_c, x_max_c, 40), linspace(y_min_c, y_max_c, 40), ...
        linspace(z_min_c, z_max_c, 40));
    Vc = reshape(apply_dv(dv.c, [Xgc(:), Ygc(:), Zgc(:)]), size(Xgc));
    fv = isosurface(Xgc, Ygc, Zgc, Vc, 0);
    if ~isempty(fv.vertices)
        fv = reducepatch(fv, 0.15);          % coarser mesh so the grey wireframe reads
        p = patch(fv);
        p.FaceColor = [0.7 0.7 0.7]; p.FaceAlpha = 0.35;
        p.EdgeColor = [0.5 0.5 0.5]; p.EdgeAlpha = 0.6;
        camlight; lighting gouraud;
    end
    view(3); grid on;
    set(gca, 'XTickLabel', [], 'YTickLabel', [], 'ZTickLabel', []);   % no ticks, keep grid
    title('Constructing Content DV');
    xlabel('Power DV', 'Color', ccol(1,:)); ylabel('Spot DV', 'Color', ccol(2,:));
    zlabel('Edge DV', 'Color', ccol(3,:));

    subplot(2, 3, 2);
    plot_dcon_pie(content_near, content_far, {'power', 'spot', 'edge'});

    subplot(2, 3, 3); hold on;
    histogram(diff_c, 'FaceColor', 'r', 'Normalization', 'pdf', 'EdgeColor', 'none', ...
        'FaceAlpha', 0.6);
    histogram(same_c, 'FaceColor', 'b', 'Normalization', 'pdf', 'EdgeColor', 'none', ...
        'FaceAlpha', 0.6);
    set(gca, 'YTick', []);
    xlabel('Content DV');
    dv_legend();

    % ==========================================
    % ROW 2: FINAL OVERALL BOUNDARY  ([content, border])
    % ==========================================
    fcol = dim_colors(2);
    c_min = min([same_c; diff_c]) - 1; c_max = max([same_c; diff_c]) + 1;
    b_min = min([same_b; diff_b]) - 1; b_max = max([same_b; diff_b]) + 1;
    [X, Y] = meshgrid(linspace(c_min, c_max, 200), linspace(b_min, b_max, 200));
    Z = zeros(size(X));
    for i = 1:numel(X)
        Z(i) = dv.bc([X(i); Y(i)]);
    end

    subplot(2, 3, 4);
    colormap(gca, 'jet');
    imagesc(X(1,:), Y(:,1), Z); axis xy; hold on;
    contour(X, Y, Z, [0 0], 'k', 'LineWidth', 2);
    try
        cb = vislab.lib.colorbarpzn(min(Z(:)), max(Z(:)));
        cb.Label.String = 'Decision Variable Value';
    catch
        cb = colorbar;
        cb.Label.String = 'Decision Variable Value';
    end
    scatter(diff_c, diff_b, 2, 'r', 'filled', 'MarkerEdgeColor', 'none', 'LineWidth', 0.5);
    scatter(same_c, same_b, 2, 'b', 'filled', 'MarkerEdgeColor', 'none', 'LineWidth', 0.5);
    set(gca, 'XTickLabel', [], 'YTickLabel', []);                     % no ticks
    title('Constructing Final DV (Border + Content)');
    xlabel('Content DV', 'Color', fcol(1,:)); ylabel('Border DV', 'Color', fcol(2,:));

    subplot(2, 3, 5);
    plot_dcon_pie(final_near, final_far, {'content', 'border'});

    subplot(2, 3, 6); hold on;
    histogram(apply_dv(dv.bc, final_far),  'FaceColor', 'r', 'Normalization', 'pdf', ...
        'EdgeColor', 'none', 'FaceAlpha', 0.6);
    histogram(apply_dv(dv.bc, final_near), 'FaceColor', 'b', 'Normalization', 'pdf', ...
        'EdgeColor', 'none', 'FaceAlpha', 0.6);
    set(gca, 'YTick', []);
    xlabel('Final Overall DV');
    title('Final Separation');
end
