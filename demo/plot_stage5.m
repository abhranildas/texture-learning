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

    % dv.spot has the same signature (function of the full spot-LLR column) whether or
    % not colour is on -- load_dv_handles composes the two-step spot DV if needed.
    try
        dv = load_dv_handles(cfg, ecc, true);
    catch
        return;
    end

    % Compute DVs: R columns given by COL (spot/edge/power/border)
    content_near = [R_near(:, col.power), apply_dv(dv.spot, R_near(:, col.spot)), ...
        apply_dv(dv.edge, R_near(:, col.edge))];
    content_far  = [R_far(:, col.power),  apply_dv(dv.spot, R_far(:, col.spot)),  ...
        apply_dv(dv.edge, R_far(:, col.edge))];

    same_c = apply_dv(dv.content, content_near);
    diff_c = apply_dv(dv.content, content_far);
    same_b = apply_dv(dv.border, R_near(:, col.border));
    diff_b = apply_dv(dv.border, R_far(:, col.border));

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
    xl = plot_range(content_near(:,1), content_far(:,1));    % middle 99% of each axis
    yl = plot_range(content_near(:,2), content_far(:,2));
    zl = plot_range(content_near(:,3), content_far(:,3));
    [Xgc, Ygc, Zgc] = meshgrid(linspace(xl(1), xl(2), 40), linspace(yl(1), yl(2), 40), ...
        linspace(zl(1), zl(2), 40));
    Vc = reshape(apply_dv(dv.content, [Xgc(:), Ygc(:), Zgc(:)]), size(Xgc));
    fv = isosurface(Xgc, Ygc, Zgc, Vc, 0);
    if ~isempty(fv.vertices)
        fv = reducepatch(fv, 0.15);          % coarser mesh so the grey wireframe reads
        p = patch(fv);
        p.FaceColor = [0.7 0.7 0.7]; p.FaceAlpha = 0.35;
        p.EdgeColor = [0.5 0.5 0.5]; p.EdgeAlpha = 0.6;
        camlight; lighting gouraud;
    end
    view(3); grid on;  xlim(xl); ylim(yl); zlim(zl);
    set(gca, 'XTickLabel', [], 'YTickLabel', [], 'ZTickLabel', []);   % no ticks, keep grid
    title('Constructing Content DV');
    xlabel('Power DV', 'Color', ccol(1,:)); ylabel('Spot DV', 'Color', ccol(2,:));
    zlabel('Edge DV', 'Color', ccol(3,:));

    subplot(2, 3, 2);
    plot_dcon_pie(content_near, content_far, {'power', 'spot', 'edge'});

    subplot(2, 3, 3);
    plot_dv_hist(same_c, diff_c, 'Content DV');
    dv_legend();

    % ==========================================
    % ROW 2: FINAL OVERALL BOUNDARY  ([content, border])
    % ==========================================
    fcol = dim_colors(2);
    cl = plot_range(same_c, diff_c);  bl = plot_range(same_b, diff_b);
    [X, Y] = meshgrid(linspace(cl(1), cl(2), 200), linspace(bl(1), bl(2), 200));
    Z = zeros(size(X));
    for i = 1:numel(X)
        Z(i) = dv.border_content([X(i); Y(i)]);
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
    xlim(cl); ylim(bl);
    set(gca, 'XTickLabel', [], 'YTickLabel', []);                     % no ticks
    title('Constructing Final DV (Border + Content)');
    xlabel('Content DV', 'Color', fcol(1,:)); ylabel('Border DV', 'Color', fcol(2,:));

    subplot(2, 3, 5);
    plot_dcon_pie(final_near, final_far, {'content', 'border'});

    subplot(2, 3, 6);
    plot_dv_hist(apply_dv(dv.border_content, final_near), ...
        apply_dv(dv.border_content, final_far), 'Final Overall DV');
    title('Final Separation');
end
