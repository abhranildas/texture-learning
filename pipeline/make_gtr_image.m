function [imgs, maps, texs, textures] = make_gtr_image(cfg, textures, n_images, ecc, seed)
% MAKE_GTR_IMAGE  Make grown-texture-region (GTR) images and their region maps.
%   [imgs, maps] = make_gtr_image(cfg, texture_set)
%   [imgs, maps, texs, textures] = make_gtr_image(cfg, texture_set, n_images, ecc, seed)
%   [imgs, maps] = make_gtr_image(cfg, textures, n_images)
%
%   A GTR image is a cfg.gtr.szp x cfg.gtr.szp grid of patches divided into
%   cfg.gtr.n_regions randomly grown regions, each filled with a different texture
%   from one texture set. Any patch outside every region is set to the mean
%   luminance (cfg.norm.target_mean). Because the true regions are known, GTR
%   images are used to score discrimination and segmentation.
%
%   Inputs
%     cfg       config struct (config.m).
%     textures  texture set id: 1 Pertex, 2 Fabric, 3 Brodatz, 4 Brodatz+Fabric,
%               5 VisTex, 6 McGill. Loading a set is the slow step, so to make
%               more images from the same set later, pass instead the `textures`
%               output of an earlier call (then ecc is ignored).
%     n_images  number of images; default 1.
%     ecc       eccentricity downsample factor (1, 2, 4, 8); default 1.
%     seed      random seed; default [] (continue the current random stream).
%
%   Outputs
%     imgs      [sz x sz x 3 x n_images] LMS images (sz = cfg.patch.image_size/ecc);
%               eye optics applied if cfg.optics.apply_test (load_texture_images).
%     maps      [szp x szp x n_images] integer region-label maps (0 = background).
%     texs      [n_images x n_regions] texture-sheet index used for each region.
%     textures  the loaded texture set (fields r, g, b: LMS sheet stacks), for reuse.
%
%   Example
%     [img, map] = make_gtr_image(config(), 3);   % one Brodatz GTR image
%
%   See also LOAD_TEXTURE_IMAGES, GTR.GROW_REGION_MASKS, GTR.SAMPLE_TEXTURE_IDS,
%   SEGMENTATION.SEGMENT_LMS

    if nargin < 3 || isempty(n_images), n_images = 1; end
    if nargin < 4 || isempty(ecc),      ecc = 1; end
    if nargin >= 5 && ~isempty(seed),   rng(seed); end

    if isnumeric(textures)
        [r, g, b] = load_texture_images(cfg, textures, ecc);
        textures = struct('r', r, 'g', g, 'b', b);
    end

    % random draws: all texture choices, then all region layouts
    n_regions = cfg.gtr.n_regions;
    texs = gtr.sample_texture_ids(size(textures.r, 3), n_regions, n_images);
    [~, maps] = gtr.grow_region_masks(cfg.gtr.szp, n_regions, n_images, ...
        cfg.gtr.seed_radius, cfg.gtr.coverage);

    sz = size(textures.r, 1);
    imgs = zeros(sz, sz, 3, n_images);
    for k = 1:n_images
        imgs(:, :, :, k) = fill_regions(cfg, textures, texs(k, :), maps(:, :, k));
    end
end

function img = fill_regions(cfg, textures, texs_row, map)
% Fill each labelled region of map with its texture sheet; background -> target mean.
    sz = size(textures.r, 1);
    patch_size = sz / size(map, 1);
    illum_offset = 0;         % illumination offset (0 = uniform; set >0 for Fig-13-style tests)

    img = zeros(sz, sz, 3);
    for region_idx = 1:numel(texs_row)
        mask = kron(double(map == region_idx), ones(patch_size));      % szp x szp -> sz x sz
        k = texs_row(region_idx);
        img(:, :, 1) = img(:, :, 1) + textures.r(:, :, k) .* mask;
        img(:, :, 2) = img(:, :, 2) + textures.g(:, :, k) .* mask;
        img(:, :, 3) = img(:, :, 3) + textures.b(:, :, k) .* mask;
    end

    covered = kron(double(map > 0), ones(patch_size)) > 0;
    img(repmat(~covered, 1, 1, 3)) = cfg.norm.target_mean;

    % optional per-half illumination scaling
    if illum_offset ~= 0
        scl = (1 + illum_offset) * ones(sz, 1);
        scl((1:sz) < sz/2) = 1 - illum_offset;
        img = img .* scl;
    end
end
