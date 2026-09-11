function [pimg, patch_x, patch_y] = make_gtr_image(cfg, imgr, imgg, imgb, texs_row, map)
% MAKE_GTR_IMAGE  Assemble one grown-texture-region image from region masks + textures.
%   [pimg, patch_x, patch_y] = make_gtr_image(cfg, imgr, imgg, imgb, texs_row, map)
%
%   Fills each labelled region of `map` with its assigned texture sheet, sets the
%   background to the target mean, and returns the LMS image plus the patch-index
%   -> grid-coordinate maps. Shared by pipeline stages s6 and s7.
%
%   Inputs
%     cfg       - config struct.
%     imgr/g/b  - LMS channel stacks (sz x sz x nimg) from load_texture_images.
%     texs_row  - 1 x n_regions texture-sheet index per region (from gtr.sample_texture_ids).
%     map       - szp x szp integer region-label map (from gtr.grow_region_masks).
%
%   Outputs
%     pimg             - sz x sz x 3 LMS grown-texture-region image.
%     patch_x, patch_y - sz2 x 1 maps from patch index to grid row/col.
%
%   See also LOAD_TEXTURE_IMAGES, GTR.SAMPLE_TEXTURE_IDS, GTR.GROW_REGION_MASKS,
%   S6_SELFSUP_DISCRIMINATION, S7_SEGMENT_GTR

    szp = size(map, 1);
    sz  = size(imgr, 1);
    patch_size = sz / szp;
    n_regions = numel(texs_row);
    target_mean = cfg.norm.target_mean;
    illum_offset = 0;         % illumination offset (0 = uniform; set >0 for Fig-13-style tests)

    % region masks (each region's patches expanded to pixels)
    pimg = zeros(sz, sz, 3);
    for region_idx = 1:n_regions
        mask = kron(double(map == region_idx), ones(patch_size));      % szp x szp -> sz x sz
        k = texs_row(region_idx);
        pimg(:, :, 1) = pimg(:, :, 1) + imgr(:, :, k) .* mask;
        pimg(:, :, 2) = pimg(:, :, 2) + imgg(:, :, k) .* mask;
        pimg(:, :, 3) = pimg(:, :, 3) + imgb(:, :, k) .* mask;
    end

    % background (outside all regions) -> target mean
    covered = kron(double(map > 0), ones(patch_size)) > 0;
    outside = repmat(~covered, 1, 1, 3);
    pimg(outside) = target_mean;

    % optional per-half illumination scaling
    if illum_offset ~= 0
        scl = (1 + illum_offset) * ones(sz, 1);
        scl((1:sz) < sz/2) = 1 - illum_offset;
        pimg = pimg .* scl;
    end

    % patch index -> (row, col), row-major
    sz2 = szp^2;
    patch_x = zeros(sz2, 1);
    patch_y = zeros(sz2, 1);
    patch_idx = 0;
    for row = 1:szp
        for col = 1:szp
            patch_idx = patch_idx + 1;
            patch_x(patch_idx) = row;
            patch_y(patch_idx) = col;
        end
    end
end
