function make_readme_figure(texture_sets, seed)
% MAKE_README_FIGURE  Regenerate sample_segment.png, the README's example figure.
%   make_readme_figure()
%   make_readme_figure(texture_sets, seed)
%
%   One column per texture set; rows: the GTR image, its true regions, and the
%   model's segmentation (scored above it), drawn as in the stage 7a demo figure
%   (plot_stage7). Row names appear once, left of the first column. Uses the
%   current config, so the texture sheets are luminance/contrast normalized when
%   cfg.gtr.normalize_sheets is on.
%
% Inputs
%   texture_sets  texture sets, one per column (default [3 2 6]: Brodatz, Fabric, McGill).
%   seed    random seed for the GTR layouts (default 1).
% Output
%   none (writes sample_segment.png in the repo root)
%
% See also PLOT_STAGE7, MAKE_GTR_IMAGE, SEGMENT_IMAGE
    if nargin < 1 || isempty(texture_sets), texture_sets = [3 2 6]; end
    if nargin < 2 || isempty(seed),   seed = 1; end
    cfg = config(false, false);       % the demo default: achromatic, no optics
    set_names = {'Pertex', 'Fabric', 'Brodatz', 'Brodatz + Fabric', 'VisTex', 'McGill'};
    row_names = {'GTR image', 'true regions', 'segmented'};
    n = numel(texture_sets);

    fig = figure('Color', 'w', 'WindowStyle', 'normal', 'Position', [100 100 300 * n + 60 900]);
    t = tiledlayout(3, n, 'TileSpacing', 'compact', 'Padding', 'compact');
    rng(seed);
    for c = 1:n
        [img, map] = make_gtr_image(cfg, texture_sets(c), 1, 1);
        seg = segment_image(cfg, img, map);
        rgb = patch_to_rgb_display(cfg, img, 'lms');
        map_up = imresize(map, [size(img, 1), size(img, 2)], 'nearest');
        seg_up = imresize(seg.est_map, [size(img, 1), size(img, 2)], 'nearest');
        panels = {rgb, tint_regions(rgb, map_up), ...
                  tint_regions(rgb, match_region_labels(seg_up, map_up))};
        for r = 1:3
            nexttile(t, (r - 1) * n + c);
            image(panels{r}); axis image;
            set(gca, 'XTick', [], 'YTick', [], 'XColor', 'none', 'YColor', 'none');
            if c == 1                 % row name, once per row
                ylabel(row_names{r}, 'Color', 'k', 'FontWeight', 'bold', 'FontSize', 12);
            end
            if r == 1
                title(set_names{texture_sets(c)}, 'FontSize', 12);
            elseif r == 3
                title(sprintf('%d/%d correct, ARI %.2f', seg.n_correct, cfg.gtr.n_regions, ...
                    segmentation.adjusted_rand_index(map, seg.est_map)), 'FontWeight', 'normal');
            end
        end
    end
    exportgraphics(fig, fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
        'sample_segment.png'), 'Resolution', 110);
end
