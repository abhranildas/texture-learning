function plot_dv_hist(near_vals, far_vals, xlab)
% PLOT_DV_HIST  Overlaid near (blue) / far (red) histograms of a scalar decision
%   variable in the current axes, over the middle 99% of the values (plot_range).
%   plot_dv_hist(near_vals, far_vals, xlab)
%
%   Values outside that range are left out of the bins.
%
% Inputs
%   near_vals, far_vals  DV values of the near and far pairs.
%   xlab                 x-axis label.
% Output
%   none (draws into the current axes)
%
% See also PLOT_RANGE, PLOT_STAGE5, PLOT_STAGE5_INTERMEDIATE
    lims = plot_range(near_vals, far_vals);
    hold on;
    histogram(far_vals,  'BinLimits', lims, 'FaceColor', 'r', 'Normalization', 'pdf', ...
        'EdgeColor', 'none', 'FaceAlpha', 0.6);
    histogram(near_vals, 'BinLimits', lims, 'FaceColor', 'b', 'Normalization', 'pdf', ...
        'EdgeColor', 'none', 'FaceAlpha', 0.6);
    xlim(lims);  set(gca, 'YTick', []);  xlabel(xlab);
end
