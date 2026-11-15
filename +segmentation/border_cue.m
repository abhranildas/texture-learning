function border = border_cue(cfg, patches, windows, ra, ca, rb, cb, dir)
% BORDER_CUE  Border features for the patch pair (ra,ca)-(rb,cb).
%   border = segmentation.border_cue(cfg, patches, windows, ra, ca, rb, cb, dir)
%
%   Two ways to measure the border cue, chosen by `windows`:
%     windows = []  two-patch cue (Bill's Rb): the two patches are joined along
%                   their shared edge (vislab.nat_stat_bayes.dv_border).
%     windows = segmentation.border_windows(...)  border-centred cue (Bill's
%                   centerflg = 1, Rb12): one patch-sized window centred on the
%                   shared border. The window is split into its two halves and
%                   passed to dv_border, which then computes exactly Rb12's
%                   border(1:2). Only for adjacent pairs, with (rb,cb) below
%                   (dir 1) or right of (dir 2) (ra,ca).
%
%   Inputs
%     cfg      config struct (uses cfg.dv.sd1, cfg.dv.nsd1).
%     patches  grid of gray patches for the two-patch cue (from prep_grid).
%     windows  [] or {down, right} from segmentation.border_windows.
%     ra, ca, rb, cb  grid positions of the two patches.
%     dir      1 = (rb,cb) below (ra,ca), 2 = right of it.
%   Output
%     border   1x3 vector from dv_border; callers use border(1:2).
%
% See also SEGMENTATION.BORDER_WINDOWS, VISLAB.NAT_STAT_BAYES.DV_BORDER

    if isempty(windows)
        a = patches{ra, ca};
        b = patches{rb, cb};
    else
        w = windows{dir}{ra, ca};
        h = size(w, 1) / 2;
        if dir == 1
            a = w(1:h, :);  b = w(h+1:end, :);
        else
            a = w(:, 1:h);  b = w(:, h+1:end);
        end
    end
    % dv_border's patch_size = extent of `a` across the border (rows for dir 1,
    % columns for dir 2): the border then sits at that row of the joined image
    border = vislab.nat_stat_bayes.dv_border(a, b, size(a, dir), dir, ...
        cfg.dv.sd1, cfg.dv.nsd1, false);
end
