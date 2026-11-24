function plot_stage6(out, method)
% PLOT_STAGE6  Show the same/different self-supervised discrimination accuracy
%   on GTR patches across the grouping-criterion / mutual-similarity-weight grid.
%   plot_stage6(out, method)
%
% Inputs
%   out    - struct from s6_selfsup_discrimination: out.mutual_weight
%            (mutual-similarity weight grid), out.group_crit (grouping-criterion
%            grid), out.accuracy (same/different accuracy surface over that grid),
%            out.texture_set (texture database id).
%   method - decision method used to build out.accuracy, e.g. 'bc' (border+content).
% Output
%   none (draws the figure)
%
% See also S6_SELFSUP_DISCRIMINATION, PLOT_STAGE7
    figure('Name', 'Stage 6: Same/Different Self-Supervised Performance on GTR Patches', ...
        'Position', [400 400 600 500]);
    imagesc(out.mutual_weight, out.group_crit, out.accuracy); axis xy;
    cb = colorbar; cb.Label.String = 'Same-Different Accuracy';
    xlabel('Mutual Similarity Weight');
    ylabel('Grouping Criterion');

    m_str = method;
    if strcmp(method, 'bc'), m_str = 'Border+Content'; end

    d_str = sprintf('Dataset %d', out.texture_set);
    if out.texture_set == 3, d_str = 'Brodatz'; end

    title(sprintf('Same-Diff Accuracy on GTR Patches (Method: %s, Texture set: %s)', m_str, d_str));
end
