function [ptch, same_gt] = sample_texture_pairs(cfg, ecc, npairs, itype)
% SAMPLE_TEXTURE_PAIRS  Random same/different texture-sheet patch pairs, for the
%   Stage 6 qualitative same/different demo. For each of npairs draws, either takes
%   two patches from two different locations of ONE randomly chosen sheet ("same"
%   texture) or one patch each from two distinct randomly chosen sheets
%   ("different" texture), with roughly half of the draws same and half different.
%   (Was sample_brodatz_pairs.m; generalized to any load_texture_images itype so
%   Stage 6 can run on a colour database -- Brodatz is grayscale, so it carries no
%   chromatic signal; see run_demo.m.)
%
%   Inputs
%     cfg, ecc, npairs - as elsewhere; ecc is the eccentricity divisor (patch
%                        geometry is divided by it).
%     itype            - texture database (load_texture_images itype); default 3
%                         (Brodatz).
%
%   Output
%     ptch    - pair tensor [patch_size x 2*patch_size x nch x npairs]
%               (pair_responses format); nch = 3 if cfg.features.color else 1.
%     same_gt - [npairs x 1] logical ground truth, true = same texture.
%
% See also LOAD_TEXTURE_IMAGES, PLOT_STAGE6_PAIRS
    if nargin < 4 || isempty(itype), itype = 3; end
    patch_size = cfg.patch.size / ecc;
    target_mean = cfg.norm.target_mean;
    target_contrast = cfg.norm.target_contrast;

    if cfg.features.color
        nch = 3;  prep = @(p) vislab.nat_stat_bayes.patch_to_abr(p, target_mean, target_contrast);
    else
        nch = 1;  prep = @(p) vislab.nat_stat_bayes.patch_to_a(p, target_mean, target_contrast);
    end

    [imgr, imgg, imgb, nimg] = load_texture_images(cfg, itype, ecc);
    sheet_size = size(imgr, 1);

    ptch = zeros(patch_size, 2*patch_size, nch, npairs);
    same_gt = false(npairs, 1);
    for pair_idx = 1:npairs
        same_gt(pair_idx) = rand < 0.5;
        k1 = randi(nimg);
        if same_gt(pair_idx)
            k2 = k1;
        else
            k2 = mod(k1 - 1 + randi(nimg - 1), nimg) + 1;   % any sheet other than k1
        end
        x1 = randi(sheet_size - patch_size + 1); y1 = randi(sheet_size - patch_size + 1);
        x2 = randi(sheet_size - patch_size + 1); y2 = randi(sheet_size - patch_size + 1);

        p1 = prep(cat(3, imgr(x1:x1+patch_size-1, y1:y1+patch_size-1, k1), ...
                          imgg(x1:x1+patch_size-1, y1:y1+patch_size-1, k1), ...
                          imgb(x1:x1+patch_size-1, y1:y1+patch_size-1, k1)));
        p2 = prep(cat(3, imgr(x2:x2+patch_size-1, y2:y2+patch_size-1, k2), ...
                          imgg(x2:x2+patch_size-1, y2:y2+patch_size-1, k2), ...
                          imgb(x2:x2+patch_size-1, y2:y2+patch_size-1, k2)));
        ptch(:, :, :, pair_idx) = cat(2, p1, p2);
    end
end
