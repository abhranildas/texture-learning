function plot_dcon_pie(near, far, dim_labels)
% PLOT_DCON_PIE  Pie chart of each dimension's proportional contribution to
%   classification accuracy (d'), drawn into the current axes.
%   plot_dcon_pie(near, far, dim_labels)
%
% Inputs
%   near, far   - sample matrices (rows = observations, cols = dimensions) for
%                 the two classes.
%   dim_labels  - 1 x d cellstr naming the dimensions (same column order).
% Output
%   none (draws a pie chart into the current axes)
%
%   The contributions are the classify_normals 'd_con', 'greedy' vector, measured
%   on the data: d' of a set of dimensions is -2*norminv(error rate) of a
%   quadratic boundary optimized on the samples of just those dimensions. Starting from the dimension with the highest d', dimensions
%   are added one at a time, each time the one that raises d' most, and each is
%   credited with the d' it adds in quadrature, sqrt(d_after^2 - d_before^2).
%   classify_normals is called with plotting off, and the pie is drawn here --
%   classify_normals' own colorbar is not used.
%   Dimension k's slice is coloured dim_colors(d)(k,:) (no red or blue, which
%   mean far and near), matching the coloured axis labels of the response clouds
%   beside it. Dimensions contributing nothing get no slice.
%
% See also PLOT_STAGE5, PLOT_STAGE5_INTERMEDIATE

    n_dims     = size(near, 2);
    slice_colors = dim_colors(n_dims);

    try
        res = classify_normals(near, far, 'input_type', 'samp', 'd_con', 'greedy', ...
                               'plotmode', 0);
        d_con = max(real(res.d_con(:)), 0);       % guard against tiny imaginary/negative values
    catch
        text(0.5, 0.5, 'd'' contribution unavailable', 'Units', 'normalized', ...
             'HorizontalAlignment', 'center'); axis off; return;
    end
    if ~any(d_con > 0)
        text(0.5, 0.5, 'd'' contribution ~ 0', 'Units', 'normalized', ...
             'HorizontalAlignment', 'center'); axis off; return;
    end

    shown = find(d_con > 0);                      % pie cannot draw zero slices
    pct = 100 * d_con(shown) / sum(d_con);
    h = pie(gca, pct, dim_labels(shown));         % names outside, percentages inside
    for i = 1:numel(shown)                        % pie returns [slice, label] pairs in input order
        slice = h(2*i - 1);
        label = h(2*i);
        slice.FaceColor = slice_colors(shown(i), :);
        slice.EdgeColor = 'w';
        label.Color = slice_colors(shown(i), :);
        label.FontSize = 8;
        label.FontWeight = 'bold';
        % percentage at the slice's middle angle, 60% of the way out; a slice too
        % thin to hold it keeps it in its outside label instead
        if pct(i) >= 6
            v = slice.Vertices(2:end, :);         % arc points (row 1 is the centre)
            ang = atan2(mean(v(:, 2)), mean(v(:, 1)));
            text(0.6 * cos(ang), 0.6 * sin(ang), sprintf('%.0f%%', pct(i)), ...
                'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 8, ...
                'FontWeight', 'bold');
        else
            label.String = sprintf('%s %.0f%%', label.String, pct(i));
        end
    end
    axis equal off;
    title('d'' contributions');
end
