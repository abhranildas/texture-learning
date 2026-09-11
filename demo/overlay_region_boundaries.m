function overlay_region_boundaries(label_map, color, line_width)
% OVERLAY_REGION_BOUNDARIES  Outline each labeled region's boundary on the current
%   axes (hold on already in effect). Used instead of a colour-tint alpha overlay so
%   region structure reads clearly on both grayscale and colour base images (stages
%   7 and 8), in both monochrome and colour model modes.
%   overlay_region_boundaries(label_map, color, line_width)
%
% Inputs
%   label_map  - integer region-label image (0 = unlabeled/background).
%   color      - boundary line colorspec (default 'y').
%   line_width - boundary line width, points (default 1.5).
% Output
%   none (draws boundary outlines into the current axes)
%
%   Requires the Image Processing Toolbox (bwboundaries); imresize (already used to
%   upsample label_map to image resolution) is from the same toolbox.
%
% See also PLOT_STAGE7, PLOT_STAGE8_NATURAL
    if nargin < 2 || isempty(color), color = 'y'; end
    if nargin < 3 || isempty(line_width), line_width = 1.5; end

    ids = setdiff(unique(label_map(:)), 0);
    for k = 1:numel(ids)
        boundaries = bwboundaries(label_map == ids(k));
        for bi = 1:numel(boundaries)
            boundary = boundaries{bi};
            plot(boundary(:,2), boundary(:,1), 'Color', color, 'LineWidth', line_width);
        end
    end
end
