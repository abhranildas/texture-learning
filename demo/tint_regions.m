function out = tint_regions(img_rgb, label_map, alpha)
% TINT_REGIONS  Blend a distinct colour into each labelled region of an image.
%   out = tint_regions(img_rgb, label_map, alpha)
%
%   Used by the stage 7a and 8 plots on achromatic (grayscale) images, where a
%   colour tint shows the regions without hiding the texture. Label k always gets
%   colour k, so two maps labelled consistently (see match_region_labels) show the
%   same region in the same colour.
%
% Inputs
%   img_rgb    [h x w x 3] display image, values 0-1 (patch_to_rgb_display).
%   label_map  [h x w] integer region labels at image resolution (0 = untinted).
%   alpha      tint strength, 0-1 (default 0.45).
% Output
%   out  [h x w x 3] tinted image, values 0-1.
%
% See also MATCH_REGION_LABELS, PLOT_STAGE7, PLOT_STAGE8_NATURAL
    if nargin < 3 || isempty(alpha), alpha = 0.45; end
    n = max([label_map(:); 1]);
    palette = lines(min(n, 7));                         % MATLAB's distinct line colours
    if n > 7, palette = [palette; hsv(n - 7)]; end      % extra colours past the first 7

    out = img_rgb;
    labelled = label_map > 0;
    for c = 1:3
        tint = zeros(size(label_map));
        tint(labelled) = palette(label_map(labelled), c);
        channel = img_rgb(:, :, c);
        channel(labelled) = (1 - alpha) * channel(labelled) + alpha * tint(labelled);
        out(:, :, c) = channel;
    end
end
