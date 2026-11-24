function n_correct = plot_stage7(cfg, ecc, itypes)
% PLOT_STAGE7  Segment one GTR image from each texture set at the fixed parameters
%   and show the result.
%   n_correct = plot_stage7(cfg, ecc, itypes)
%
%   For each texture set, builds one GTR image and segments it with segment_image
%   at the fixed parameters cfg.segment. Top row: each GTR image with its
%   ground-truth regions. Bottom row: the model's segmentation of the same image.
%
% Inputs
%   cfg     config struct.
%   ecc     eccentricity divisor (patch geometry is divided by it).
%   itypes  texture sets to show (default 1:6): 1 Pertex, 2 Fabric, 3 Brodatz,
%           4 Brodatz+Fabric, 5 VisTex, 6 McGill.
% Output
%   n_correct  1 x numel(itypes), regions segmented exactly right in each image
%
% See also SEGMENTATION.SEGMENT_LMS, S7_SEGMENT_GTR, TINT_REGIONS,
%   OVERLAY_REGION_BOUNDARIES
    if nargin < 3 || isempty(itypes), itypes = 1:6; end
    set_names = {'Pertex', 'Fabric', 'Brodatz', 'Brodatz + Fabric', 'VisTex', 'McGill'};
    n_sets = numel(itypes);

    figure('Name', 'Stage 7a: GTR Segmentation', 'Position', [100 250 1700 650]);
    n_correct = zeros(1, n_sets);
    n_cols = n_sets + 1;                   % column 1 holds the row labels
    subplot(2, n_cols, 1);           local_row_label('ground truth');
    subplot(2, n_cols, n_cols + 1);  local_row_label('segmented');
    for s = 1:n_sets
        [pimg, map] = make_gtr_image(cfg, itypes(s), 1, ecc);
        seg = segment_image(cfg, pimg, map);
        n_correct(s) = seg.nrg;

        % pimg is LMS (grayscale for Brodatz/Pertex, colour for Fabric etc, as in
        % Bill's self_sup_tex_segm). In achromatic mode patch_to_rgb_display shows
        % the A channel the model segments; in colour mode, the true colour.
        pimg_rgb = patch_to_rgb_display(cfg, pimg, 'lms');
        map_up = imresize(map, [size(pimg,1), size(pimg,2)], 'nearest');
        groups_up = imresize(seg.emap, [size(pimg,1), size(pimg,2)], 'nearest');

        % Achromatic: colour-tint each region; segments take the colour of the
        % true region they overlap most. Colour model: black-and-white region borders.
        subplot(2, n_cols, s + 1);
        local_show(cfg, pimg_rgb, map_up);
        title(set_names{itypes(s)});

        subplot(2, n_cols, n_cols + s + 1);
        local_show(cfg, pimg_rgb, match_region_labels(groups_up, map_up));
        title(sprintf('%d/%d correct\nARI: %.2f', seg.nrg, cfg.gtr.n_regions, ...
            segmentation.adjusted_rand_index(map, seg.emap)));

        drawnow; % update UI
    end

    sgtitle('Stage 7a: GTR Segmentation');
end

% ------------------------------------------------------------------------------
function local_row_label(str)
% Horizontal row label filling the current axes (its own label column).
    axis off;
    text(0.5, 0.5, str, 'Units', 'normalized', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 11);
end

% ------------------------------------------------------------------------------
function local_show(cfg, img_rgb, label_map)
% Image with its regions: tinted (achromatic) or black-and-white borders (colour).
    if cfg.features.color
        image(img_rgb); axis image off; hold on;
        overlay_region_boundaries(label_map, 'k', 3);  overlay_region_boundaries(label_map, 'w', 1);
    else
        image(tint_regions(img_rgb, label_map)); axis image off;
    end
end
