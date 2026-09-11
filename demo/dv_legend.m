function dv_legend()
% DV_LEGEND  Far/Near legend for the DV histograms (stage 5A/5B, top-right panels).
%   dv_legend()
%
%   Adds solid red/blue proxy swatches and legends them. The histograms are drawn
%   semi-transparent (FaceAlpha < 1, no edge); such icons can fail to render in the
%   on-screen OpenGL legend, so we legend opaque proxy patches instead -- the bars
%   themselves are left unchanged. Call with the target axes current.
%
% Inputs
%   none (operates on the current axes)
% Output
%   none (adds a legend to the current axes)
%
% See also PLOT_STAGE5, PLOT_STAGE5_INTERMEDIATE
    hf = patch(NaN, NaN, 'r', 'EdgeColor', 'none');   % Far  = red
    hn = patch(NaN, NaN, 'b', 'EdgeColor', 'none');   % Near = blue
    legend([hf hn], {'Far Pairs', 'Near Pairs'}, 'Location', 'best');
end
