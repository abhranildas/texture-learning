function plot_stage8_natural(cfg, ecc)
% PLOT_STAGE8_NATURAL  Segment a natural image with the GTR segmentation machinery.
%   plot_stage8_natural(cfg, ecc)
%
%   Applies the exact self-supervised segmentation used on GTR images
%   (segment_image at the fixed parameters cfg.segment) to a real
%   natural image, using the same 64x64 (= cfg.patch.size/ecc) patches. The image
%   is clipped to the largest rectangle that is a whole number of patches.
%
%   Unlike a GTR image, a natural image has NO ground-truth region map, so:
%     * the per-image grouping criterion gcopt and mutual-similarity weight wmopt
%       are still learned self-supervised -- they come from the near/far accuracy,
%       which uses proximity only. An all-zero map is passed; it only sets the
%       patch grid and fills the unused same/different labels.
%     * there is nothing to score the segmentation against, so no accuracy is
%       reported; the fixed parameters are the ones chosen on GTR images (s7).
%   Under cfg.bill_compat this image still gets the shared (corrected) optics, not
%   Bill's: his formula is defined for square images only.
%
%   Inputs
%     cfg    - config struct.
%     ecc    - eccentricity (default 1).
%
% See also SEGMENTATION.SEGMENT_LMS, S7_SEGMENT_GTR, PATCH_TO_RGB_DISPLAY

    if nargin < 2 || isempty(ecc), ecc = 1; end
    patch_size = cfg.patch.size / ecc;

    % --- pick the natural image, halve it, clip each dimension to whole patches ---
    files    = list_natural_images(cfg);
    img_name = '12_16_143';                  % filename stem of the image to segment
    idx = find(contains(files, img_name), 1);
    if isempty(idx)
        fprintf('stage 8: image "%s" not found; using the first natural image.\n', img_name);
        idx = 1;
    end
    prescale = 255 / cfg.natural.max_val;
    cfg_test = cfg;                          % a test image: optics per cfg.optics.apply_test
    cfg_test.optics.apply = cfg.optics.apply_test;
    pimg = vislab.nat_stat_bayes.source_to_lms(files{idx}, cfg_test, ...
        struct('prescale', prescale, 'ecc', ecc));
    pimg = imresize(pimg, 0.5);              % halve the image before segmenting

    % segment_image crops it (top-left) to whole patches
    seg = segment_image(cfg, pimg, [], ecc=ecc);
    pimg = seg.lms;
    groups2d = seg.emap;
    fprintf('stage 8: segmented a %dx%d natural image (%dx%d patches of %dpx).\n', ...
            size(pimg, 1), size(pimg, 2), size(groups2d, 1), size(groups2d, 2), patch_size);

    % --- plot: natural image beside its segmentation overlay ---
    % in achromatic mode this shows the A channel the model segments (see
    % patch_to_rgb_display), not the true colour
    pimg_rgb = patch_to_rgb_display(cfg, pimg, 'lms');
    groups_up = imresize(groups2d, [size(pimg, 1), size(pimg, 2)], 'nearest');
    nreg = numel(unique(groups2d(groups2d > 0)));

    figure('Name', 'Stage 8: Natural-image segmentation', 'Position', [400 200 1000 520]);
    subplot(1, 2, 1);
    image(pimg_rgb); axis image off; title('Natural image');
    subplot(1, 2, 2);
    if cfg.features.color                    % colour model: black-and-white borders
        image(pimg_rgb); axis image off; hold on;
        overlay_region_boundaries(groups_up, 'k', 3);  overlay_region_boundaries(groups_up, 'w', 1);
    else                                     % achromatic: colour-tint each region
        image(tint_regions(pimg_rgb, groups_up)); axis image off;
    end
    title(sprintf('Self-supervised segmentation (%d regions)', nreg));
    drawnow;
end
