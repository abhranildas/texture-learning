function make_readme_figure(itypes, seed)
% MAKE_README_FIGURE  Regenerate sample_segment.png, the README's example figure.
%   make_readme_figure()
%   make_readme_figure(itypes, seed)
%
%   One row per texture set: the GTR image, its true regions, and the model's
%   segmentation, drawn as in the stage 7a demo figure (plot_stage7). Uses the
%   current config, so the texture sheets are luminance/contrast normalized when
%   cfg.gtr.normalize_sheets is on.
%
% Inputs
%   itypes  texture sets, one per row (default [3 2 6]: Brodatz, Fabric, McGill).
%   seed    random seed for the GTR layouts (default 1).
% Output
%   none (writes sample_segment.png in the repo root)
%
% See also PLOT_STAGE7, MAKE_GTR_IMAGE, SEGMENT_IMAGE
    if nargin < 1 || isempty(itypes), itypes = [3 2 6]; end
    if nargin < 2 || isempty(seed),   seed = 1; end
    cfg = config(false, false);       % the demo default: achromatic, no optics
    set_names = {'Pertex', 'Fabric', 'Brodatz', 'Brodatz + Fabric', 'VisTex', 'McGill'};
    n = numel(itypes);

    fig = figure('Color', 'w', 'WindowStyle', 'normal', 'Position', [100 100 900 300 * n]);
    tiledlayout(n, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    rng(seed);
    for r = 1:n
        [img, map] = make_gtr_image(cfg, itypes(r), 1, 1);
        seg = segment_image(cfg, img, map);
        rgb = patch_to_rgb_display(cfg, img, 'lms');
        map_up = imresize(map, [size(img, 1), size(img, 2)], 'nearest');
        seg_up = imresize(seg.emap, [size(img, 1), size(img, 2)], 'nearest');

        nexttile; image(rgb); axis image off;
        title(sprintf('GTR image (%s)', set_names{itypes(r)}));
        nexttile; image(tint_regions(rgb, map_up)); axis image off;
        title('true regions');
        nexttile; image(tint_regions(rgb, match_region_labels(seg_up, map_up))); axis image off;
        title(sprintf('segmented: %d/%d correct, ARI %.2f', seg.nrg, cfg.gtr.n_regions, ...
            segmentation.adjusted_rand_index(map, seg.emap)));
    end
    exportgraphics(fig, fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
        'sample_segment.png'), 'Resolution', 110);
end
