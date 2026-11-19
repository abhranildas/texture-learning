function n_correct = plot_stage7(cfg, itype, ecc, n_images)
% PLOT_STAGE7  Segment sample GTR images at the fixed parameters and show the result.
%   n_correct = plot_stage7(cfg, itype, ecc, n_images)
%
%   Builds n_images GTR images from texture set itype, segments each with
%   segment_image at the fixed parameters cfg.segment, and shows each
%   image's ground-truth regions beside the model's segmentation.
%
% Inputs
%   cfg       config struct.
%   itype     texture database id (load_texture_images itype).
%   ecc       eccentricity divisor (patch geometry is divided by it).
%   n_images  number of GTR images to segment and show.
% Output
%   n_correct  1 x n_images, regions segmented exactly right in each image
%
% See also SEGMENTATION.SEGMENT_LMS, S7_SEGMENT_GTR, OVERLAY_REGION_BOUNDARIES

    figure('Name', 'Stage 7: GTR Segmentation', 'Position', [400 200 1200 800]);

    textures = itype;                      % loaded on the first image, then reused
    n_correct = zeros(1, n_images);
    for ex = 1:n_images
        [pimg, map, ~, textures] = make_gtr_image(cfg, textures, 1, ecc);
        seg = segment_image(cfg, pimg, map);
        n_correct(ex) = seg.nrg;

        % pimg is LMS (grayscale for Brodatz/Pertex, colour for Fabric etc, as in
        % Bill's self_sup_tex_segm). In achromatic mode patch_to_rgb_display shows
        % the A channel the model segments; in colour mode, the true colour.
        pimg_rgb = patch_to_rgb_display(cfg, pimg, 'lms');
        map_up = imresize(map, [size(pimg,1), size(pimg,2)], 'nearest');
        groups_up = imresize(seg.emap, [size(pimg,1), size(pimg,2)], 'nearest');

        subplot(n_images, 2, (ex-1)*2 + 1);
        image(pimg_rgb); axis image off; hold on;
        overlay_region_boundaries(map_up);
        if ex == 1, title('GTR Image (Ground Truth Regions)'); end

        subplot(n_images, 2, (ex-1)*2 + 2);
        image(pimg_rgb); axis image off; hold on;
        overlay_region_boundaries(groups_up);
        title(sprintf('Segmented: %d of %d regions exactly right', seg.nrg, cfg.gtr.n_regions));

        drawnow; % update UI
    end

    sgtitle(sprintf('Stage 7: GTR Segmentation (%.0f%% of regions exactly right)', ...
        100 * mean(n_correct) / cfg.gtr.n_regions));
end
