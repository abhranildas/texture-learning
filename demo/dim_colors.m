function c = dim_colors(n)
% DIM_COLORS  Colours for n feature dimensions in the stage 5 figures, with no
%   red or blue, which mean far and near there.
%   c = dim_colors(n)
%
%   Used for the d'-contribution pie slices and the matching coloured axis labels
%   of the response clouds. Cycles if n exceeds the palette.
%
% Input
%   n  number of dimensions.
% Output
%   c  [n x 3] RGB rows.
%
% See also PLOT_DCON_PIE, PLOT_STAGE5, PLOT_STAGE5_INTERMEDIATE
    palette = [0.93 0.55 0.10;    % orange
               0.40 0.65 0.15;    % green
               0.55 0.25 0.65;    % purple
               0.85 0.70 0.10;    % gold
               0.10 0.60 0.55;    % teal
               0.60 0.40 0.20;    % brown
               0.90 0.45 0.75;    % pink
               0.45 0.45 0.45];   % gray
    c = palette(mod(0:n-1, size(palette, 1)) + 1, :);
end
