function windows = border_windows(image, patch_size, cfg)
% BORDER_WINDOWS  Patch-sized windows centred on every shared border of the patch grid.
%   windows = segmentation.border_windows(image, patch_size, cfg)
%
%   For the border-centred border cue (cfg.dv.border_center; Bill's centerflg = 1).
%   These windows are exactly the patch grid of the image shifted by half a patch,
%   so prep_grid prepares them the same way as ordinary patches (mean-normalized,
%   rotated to ABR) and returns their achromatic channel. As in Bill's code
%   (ss_segm.m:265-268), they are NOT contrast-normalized.
%
%   Inputs
%     image       GTR image in LMS space.
%     patch_size  patch side in pixels (even).
%     cfg         config struct.
%   Output
%     windows  [] if cfg.dv.border_center is false; otherwise {down, right}:
%                down{r,c}   straddles the border between grid rows r and r+1, column c
%                right{r,c}  straddles the border between grid columns c and c+1, row r
%
% See also SEGMENTATION.BORDER_CUE, SEGMENTATION.PREP_GRID

    if ~cfg.dv.border_center
        windows = [];
        return;
    end
    h = patch_size / 2;
    [~, down]  = segmentation.prep_grid(image(h+1:end-h, :, :), patch_size, cfg);
    [~, right] = segmentation.prep_grid(image(:, h+1:end-h, :), patch_size, cfg);
    windows = {down, right};
end
