function plot_dcon_bar(near, far, dim_labels)
% PLOT_DCON_BAR  Stacked bar of each dimension's proportional contribution to
%   classification accuracy (d'), drawn into the current axes.
%   plot_dcon_bar(near, far, dim_labels)
%
% Inputs
%   near, far   - sample matrices (rows = observations, cols = dimensions) for
%                 the two classes.
%   dim_labels  - 1 x d cellstr naming the dimensions (same column order).
% Output
%   none (draws a stacked bar into the current axes)
%
%   The contributions are the classify_normals 'd_con' vector: the amount by
%   which the Bayes discriminability d' drops when each dimension is removed
%   (see the IntClassNorm paper). classify_normals is called with plotting off
%   and samp_opt=0 (we want only d_con, not the sample-optimized boundary), and
%   the bar is drawn here -- classify_normals' own colorbar is not used.
%   Dimensions run bottom-to-top, matching classify_normals' convention.
%
% See also PLOT_STAGE5, PLOT_STAGE5_INTERMEDIATE

    n_dims    = size(near, 2);
    dim_colors = lines(n_dims);
    hold on;

    try
        res = classify_normals(near, far, 'input_type', 'samp', 'd_con', true, ...
                               'plotmode', 0, 'samp_opt', 0);
        d_con = max(real(res.d_con(:)), 0);       % guard against tiny imaginary/negative values
    catch
        text(0.5, 0.5, 'd'' contribution unavailable', 'Units', 'normalized', ...
             'HorizontalAlignment', 'center'); axis off; return;
    end
    if ~any(d_con > 0)
        text(0.5, 0.5, 'd'' contribution ~ 0', 'Units', 'normalized', ...
             'HorizontalAlignment', 'center'); axis off; return;
    end

    pct_contrib = 100 * d_con / sum(d_con);       % percent of total contribution
    cum_pct     = [0; cumsum(pct_contrib)];
    for k = 1:n_dims
        rectangle('Position', [0.4, cum_pct(k), 0.8, pct_contrib(k)], ...
                  'FaceColor', dim_colors(k, :), 'EdgeColor', 'w', 'LineWidth', 1);
        text(1.35, (cum_pct(k) + cum_pct(k+1)) / 2, ...
             sprintf('%s  %.0f%%', dim_labels{k}, pct_contrib(k)), ...
             'VerticalAlignment', 'middle', 'FontSize', 8, 'Color', dim_colors(k, :));
    end
    xlim([0 3]); ylim([0 100]);
    % simple bar only: no surrounding box, no vertical axis, no axis label
    set(gca, 'XTick', [], 'YTick', [], 'XColor', 'none', 'YColor', 'none', 'Color', 'none');
    box off;
    title('d'' contributions');
end
