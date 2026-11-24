function lims = plot_range(varargin)
% PLOT_RANGE  Axis limits covering the middle 99% of the data, so a few extreme
%   pairs don't squash a plot.
%   lims = plot_range(x1, x2, ...)
%
%   The 0.5th to 99.5th percentile of all inputs pooled (non-finite values
%   ignored), padded by 5% of that span on each side.
%
% Inputs
%   x1, x2, ...  numeric arrays of any shape.
% Output
%   lims  [lo hi].
%
% See also PLOT_DV_HIST, PLOT_STAGE5, PLOT_STAGE5_INTERMEDIATE
    v = cellfun(@(x) x(:), varargin, 'UniformOutput', false);
    v = vertcat(v{:});
    lims = prctile(v(isfinite(v)), [0.5 99.5]);
    lims = lims + [-1 1] * 0.05 * max(diff(lims), eps);
end
