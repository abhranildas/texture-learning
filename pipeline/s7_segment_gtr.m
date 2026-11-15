function out = s7_segment_gtr(cfg, itypes, ecc, n_images, save_params)
% S7_SEGMENT_GTR  Choose the segmentation's fixed grouping parameters on GTR images.
%   out = s7_segment_gtr(cfg)
%   out = s7_segment_gtr(cfg, itypes, ecc, n_images, save_params)
%
%   Pipeline stage 7 (Bill's GTR_segment.m + self_sup_tex_segm.m). The segmentation
%   (segmentation.segment_image) has two kinds of parameters:
%     - per image, learned self-supervised from that image alone: the grouping
%       criterion gcopt and the mutual-similarity weight wmopt;
%     - fixed, shared by all images: the offset added to gcopt, the confidence
%       criterion and the region-merge criterion (cfg.segment).
%   This stage chooses the fixed ones, as in the paper ("learned by maximizing
%   average segmentation accuracy over all six kinds of GTR image"). For n_images
%   GTR images of each texture set in itypes, it segments each image over a grid of
%   offsets x merge criteria (method and confidence criterion stay at cfg.segment),
%   counts the regions segmented exactly right, and picks the cell with the highest
%   mean over all images and sets. Ties go to the first cell in column order, as in
%   Bill's code. With save_params, the choice is written to
%   cfg.paths.segmentation_params (data/models/segmentation_params[_otf].mat, tagged
%   by the optics setting), which config.m loads as cfg.segment.
%
%   Images are drawn under rng(cfg.seed), so a run is reproducible. Slow: hours at
%   the default 6 sets x 120 images.
%
%   Inputs
%     cfg          config struct (config.m).
%     itypes       texture sets (see load_texture_images); default [3 2 4 5 6 1],
%                  Bill's six.
%     ecc          eccentricity downsample factor (1, 2, 4, 8); default 1.
%     n_images     GTR images per texture set; default 120.
%     save_params  true to save the chosen parameters; default false.
%
%   Output
%     out  struct:
%       .n_correct   regions exactly right, merge x offset x image x set
%       .frac_correct  mean fraction of regions exactly right, merge x offset
%       .frac_exact    fraction of images with every region right, merge x offset
%       .merge, .offset  the swept grids
%       .params      chosen fixed parameters (cfg.segment with offset/merge replaced)
%       .itypes, .ecc, .n_images
%
%   See also SEGMENTATION.SEGMENT_IMAGE, SEGMENTATION.LEARN_IMAGE_SIMILARITY,
%   MAKE_GTR_IMAGE, LOAD_TEXTURE_IMAGES, CONFIG

    if nargin < 2 || isempty(itypes),      itypes = [3 2 4 5 6 1]; end
    if nargin < 3 || isempty(ecc),         ecc = 1; end
    if nargin < 4 || isempty(n_images),    n_images = 120; end
    if nargin < 5 || isempty(save_params), save_params = false; end

    merge_vec  = 0 : 0.2 : 1.4;          % region-merge criterion (Bill's gr grid)
    offset_vec = -1.25 : 0.25 : 1.25;    % offset added to gcopt (Bill's gl grid)
    params = cfg.segment;                % method and confidence stay fixed
    ntexr  = cfg.gtr.n_regions;
    n_correct = zeros(numel(merge_vec), numel(offset_vec), n_images, numel(itypes));

    rng(cfg.seed);
    for t = 1:numel(itypes)
        [imgr, imgg, imgb, nimg] = load_texture_images(cfg, itypes(t), ecc);
        for k = 1:n_images
            texs = gtr.sample_texture_ids(nimg, ntexr, 1);
            [~, map3] = gtr.grow_region_masks(cfg.gtr.szp, ntexr, 1, ...
                cfg.gtr.seed_radius, cfg.gtr.coverage);
            map  = map3(:, :, 1);
            pimg = make_gtr_image(cfg, imgr, imgg, imgb, texs(1, :), map);
            S = segmentation.learn_image_similarity(cfg, pimg, map, params.method);
            for o = 1:numel(offset_vec)
                for m = 1:numel(merge_vec)
                    p = params;  p.group_offset = offset_vec(o);  p.merge = merge_vec(m);
                    seg = segmentation.segment_image(cfg, [], map, p, S);
                    n_correct(m, o, k, t) = seg.nrg;
                end
            end
        end
        fprintf('s7: texture set %d done (%d images)\n', itypes(t), n_images);
    end

    frac_correct = mean(n_correct, [3 4]) / ntexr;
    [~, best] = max(frac_correct, [], 'all', 'linear');
    [m, o] = ind2sub(size(frac_correct), best);
    params.group_offset = offset_vec(o);
    params.merge = merge_vec(m);

    out = struct('n_correct', n_correct, 'frac_correct', frac_correct, ...
        'frac_exact', mean(n_correct == ntexr, [3 4]), 'merge', merge_vec, ...
        'offset', offset_vec, 'params', params, 'itypes', itypes, 'ecc', ecc, ...
        'n_images', n_images);
    fprintf(['s7: best offset %.2f, merge %.2f (confidence %.2f): %.1f%% of regions ' ...
             'exactly right\n'], params.group_offset, params.merge, params.confidence, ...
             100 * frac_correct(m, o));

    if save_params
        save(cfg.paths.segmentation_params, 'params');
        fprintf('s7: saved to %s\n', cfg.paths.segmentation_params);
    end
end
