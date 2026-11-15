function local_show_pair(cfg, a, b)
% LOCAL_SHOW_PAIR  Display a patch pair side by side (2-px gap).
%   local_show_pair(cfg, a, b)
%
%   Normalized/gamma-mapped for display JOINTLY (patch_to_rgb_display sees both
%   halves at once) so the two halves stay comparable in brightness, not each
%   independently rescaled. Patches are ABR-space (or achromatic-only) -- see
%   patch_to_rgb_display.
%
% Inputs
%   cfg  - config struct.
%   a, b - the two patches to show side by side, each [patch_size x patch_size x 3].
% Output
%   none (draws into the current axes)
%
% See also PATCH_TO_RGB_DISPLAY, PLOT_STAGE3, PLOT_STAGE6_PAIRS
    patch_size = size(a, 2);
    rgb = patch_to_rgb_display(cfg, cat(2, a, b), 'abr');
    gap = zeros(size(rgb, 1), 2, 3);
    image([rgb(:, 1:patch_size, :), gap, rgb(:, patch_size+1:end, :)]); axis image off;
end
