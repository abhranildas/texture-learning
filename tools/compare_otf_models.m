function result = compare_otf_models(texture_sets, n_images, n_score, out_dir, bill_root)
% COMPARE_OTF_MODELS  Segment GTR images with this repo's optics and no-optics models.
%   result = compare_otf_models()
%   result = compare_otf_models(texture_sets, n_images, n_score, out_dir, bill_root)
%
%   For each texture set, makes n_score GTR images with Bill's mk_GTR_images.m and
%   segments each one two ways with this repo's code (segment_bill_image):
%     1. the model trained with the optics (data/models *_otf files), on the GTR
%        image filtered by the optics;
%     2. the model trained without the optics (data/models files without _otf), on
%        the GTR image with no optics filter.
%   Both use Bill's flags (seg_11_8_26_1_1.mat). Each uses its own fixed grouping
%   parameters (cfg.segment, from data/models/segmentation_params[_otf].mat, which
%   s7_segment_gtr chose for that model), and both start from the same RNG state.
%   The per-image criterion and weight are learned from each image as usual.
%
%   Score: each model's % of regions segmented exactly right over all n_score
%   images, per set and over all sets, and the paired difference (no-optics minus
%   optics, same images) with its standard error over images. Figures: the first
%   n_images images of each set, one figure per set: one column per image, rows
%   ground truth and segmentations 1-2, regions as semi-transparent colours matched
%   to the ground truth. Figures are saved as PNGs in out_dir.
%
%   Each model needs its own stage 7 first:
%     s7_segment_gtr(config(color, true, true), [], [], 120, true)
%     s7_segment_gtr(config(color, false, false), [], [], 120, true)
%
%   Bill's code comes from texture-learning-newer/GTRdiscsegm (mk_GTR_images, the
%   fixed parameters), texture-learning-new (other helpers) and
%   texture-learning-newer/GTR images/Texture Images (the texture sheets). His files are only read and called, never modified. An edited
%   copy of mk_GTR_images.m is written to a temp folder for this call only, as a
%   function: texture set, image count and seed as inputs; 64 px patches on a
%   10 x 10 grid (as GTR22.mat, which test_ss_segm.m segments); no display, no file
%   saved. Everything else is his: sheets converted to grayscale, each sheet
%   luminance and contrast normalized.
%
%   Inputs
%     texture_sets  texture sets (1 Pertex, 2 Fabric, 3 Brodatz, 4 Brodatz+Fabric,
%                5 VisTex, 6 McGill); default [3 2 4 5 6 1].
%     n_images   GTR images per texture set shown in the figures; default 4.
%     n_score    GTR images per texture set scored (at least n_images); default 120,
%                as s7_segment_gtr. Images are made in batches of batch_size, batch b
%                with seed b-1, so the figures show the same images as before.
%     out_dir    folder for the PNGs; default data/stimuli/otf_models_comparison.
%     bill_root  folder holding Bill's code (default: the sibling "Bill's code").
%   Output
%     result  struct array, one per texture set: .texture_set, .name, .n_correct
%             (2 x n_score, regions exactly right; rows = segmentations 1-2)
%
% See also COMPARE_OTF_BILL, SEGMENT_BILL_IMAGE

    repo_root = fileparts(fileparts(mfilename('fullpath')));
    if nargin < 1 || isempty(texture_sets), texture_sets = [3 2 4 5 6 1]; end
    if nargin < 2 || isempty(n_images),  n_images = 4; end
    if nargin < 3 || isempty(n_score),   n_score = 120; end
    if nargin < 4 || isempty(out_dir)
        out_dir = fullfile(repo_root, 'data', 'stimuli', 'otf_models_comparison');
    end
    if nargin < 5 || isempty(bill_root), bill_root = fullfile(repo_root, '..', "Bill's code"); end
    if ~isfolder(out_dir), mkdir(out_dir); end
    n_score = max(n_score, n_images);
    batch_size = max(20, n_images);      % images held in memory at once (~10 MB each)
    psz = 64;  szp = 10;
    set_names = {'Pertex', 'Fabric', 'Brodatz', 'Brodatz+Fabric', 'VisTex', 'McGill'};

    % --- this repo; Bill's folders go on the path only while his GTR maker runs ---
    addpath(repo_root);
    setup();
    repo_path = path;
    restore_path = onCleanup(@() path(repo_path));
    segm_dir  = fullfile(bill_root, 'texture-learning-newer', 'GTRdiscsegm');
    sheet_dir = fullfile(bill_root, 'texture-learning-newer', 'GTR images', 'Texture Images');
    temp_dir = tempname;  mkdir(temp_dir);
    remove_temp = onCleanup(@() rmdir(temp_dir, 's'));
    write_gtr_maker(fullfile(segm_dir, 'mk_GTR_images.m'), temp_dir, psz, szp);
    bill_dirs = [{temp_dir, segm_dir, fullfile(bill_root, 'texture-learning-new')}, ...
        fullfile(sheet_dir, {'Brodatz', 'Fabric', 'Pertex', 'Vistex', 'Mcgill'})];
    row_labels = {'Ground truth', ...
        {'Optics model,', 'filtered image'}, ...
        {'No-optics model,', 'unfiltered image'}};

    % --- Bill's flags; each model's own fixed parameters (cfg.segment, from s7) ---
    P = load(fullfile(segm_dir, 'seg_11_8_26_1_1.mat'), 'flgs');
    color = P.flgs(6) == 1;
    repo_cfgs = {config(color, true, true), config(color, false, false)};
    cfg_otf = repo_cfgs{1};

    n_runs = numel(repo_cfgs);
    est_maps = cell(1, n_runs);              % this image's region maps, for display
    result = struct('texture_set', {}, 'name', {}, 'n_correct', {});
    fprintf('%-15s %9s %9s %18s\n', '', 'optics', 'no-optics', 'diff +- SE');
    for t = 1:numel(texture_sets)
        name = set_names{texture_sets(t)};
        counts = zeros(n_runs, n_score);
        shown  = cell(n_runs + 1, n_images); % {display image, region map} per panel
        for b = 1:ceil(n_score / batch_size)
            first = (b - 1) * batch_size;    % images done before this batch
            addpath(bill_dirs{:});
            [gtrimg, maps, texs] = bill_mk_gtr_images(texture_sets(t), ...
                min(batch_size, n_score - first), b - 1);
            path(repo_path);                 % Bill's files off the path, so none
            ntexr = size(texs, 2);           % shadows a repo function
            if b == 1, shown_maps = maps(:, :, 1:n_images); end
            for j = 1:size(gtrimg, 4)
                k = first + j;
                img = gtrimg(:, :, :, j);
                map = maps(:, :, j);
                state = rng;                 % same random draws for every run
                for c = 1:n_runs
                    rng(state);
                    seg_new = segment_bill_image(repo_cfgs{c}, img, map, P.flgs(1));
                    counts(c, k) = seg_new.n_correct;
                    if k <= n_images, est_maps{c} = seg_new.est_map; end
                end
                if k <= n_images             % what each run segments, for display
                    img_otf = vislab.lib.otf_filter(img, cfg_otf.optics.ppd, ...
                        cfg_otf.optics.pupil_diameter, cfg_otf.optics.wavelength);
                    shown(:, k) = {{img, map}; {img_otf, est_maps{1}}; {img, est_maps{2}}};
                end
            end
        end

        plot_comparison(name, row_labels, shown, shown_maps, counts(:, 1:n_images), ntexr, ...
            fullfile(out_dir, sprintf('otf_models_comparison_%s.png', strrep(name, '+', '_'))));
        result(t) = struct('texture_set', texture_sets(t), 'name', name, 'n_correct', counts);
        print_score(name, counts / ntexr);
    end
    all_frac = [result.n_correct] / ntexr;
    print_score(sprintf('All (%d img)', size(all_frac, 2)), all_frac);
    fprintf('%% of regions exactly right; diff = no-optics minus optics, paired over images.\n');
    fprintf('Figures saved in %s\n', out_dir);
end

function print_score(name, frac)
% One line: each model's % of regions exactly right, and the paired difference
% (row 2 minus row 1) with its standard error over images.
    d = frac(2, :) - frac(1, :);
    se = std(d) / sqrt(numel(d));
    fprintf('%-15s %8.1f%% %8.1f%% %+8.1f%% +- %4.1f%%\n', name, ...
        100 * mean(frac(1, :)), 100 * mean(frac(2, :)), 100 * mean(d), 100 * se);
end

function plot_comparison(name, row_labels, shown, maps, counts, ntexr, png_file)
% One figure: a label column, then one column per image; rows ground truth and the
% segmentations.
    [n_rows, n_images] = size(shown);
    n_cols = n_images + 1;
    fig = figure('Name', sprintf('Optics models: %s', name), ...
        'Position', [50 30 280*n_cols 280*n_rows]);
    for r = 1:n_rows
        subplot(n_rows, n_cols, (r-1)*n_cols + 1); axis off;
        text(0.5, 0.5, row_labels{r}, 'HorizontalAlignment', 'center', ...
            'FontWeight', 'bold', 'FontSize', 12);
        for k = 1:n_images
            subplot(n_rows, n_cols, (r-1)*n_cols + k + 1);
            show_regions(shown{r, k}{1}, shown{r, k}{2}, maps(:, :, k));
            if r > 1, title(sprintf('%d of %d right', counts(r-1, k), ntexr)); end
        end
    end
    sgtitle(name);
    drawnow;
    exportgraphics(fig, png_file, 'Resolution', 150);
end

function show_regions(img, regions, truth)
% Bill's (grayscale, linear) image with a patch-level region map on top as
% semi-transparent colours, matched to the ground-truth regions.
    alpha = 0.4;
    labels = match_labels(regions, truth);
    labels = imresize(labels, [size(img, 1), size(img, 2)], 'nearest');
    n = max(labels(:));
    palette = [lines(min(n, 7)); turbo(max(n - 7, 0))];   % 7 distinct, then more
    tint = zeros([size(labels), 3]);
    for c = 1:3
        channel = zeros(size(labels));
        channel(labels > 0) = palette(labels(labels > 0), c);
        tint(:, :, c) = channel;
    end
    image(lin2rgb(min(max(img, 0), 1))); axis image off; hold on;
    image(tint, 'AlphaData', alpha * (labels > 0));
end

function out = match_labels(est, truth)
% Relabel est so each region takes the label of the truth region it overlaps most,
% pairing greedily by overlap; unpaired regions get labels after max(truth).
    ids = setdiff(unique(est(:)), 0);
    overlap = zeros(numel(ids), max(truth(:)));
    for a = 1:numel(ids)
        for g = 1:size(overlap, 2)
            overlap(a, g) = nnz(est == ids(a) & truth == g);
        end
    end
    new = zeros(numel(ids), 1);
    while any(overlap(:) > 0)
        [~, best] = max(overlap(:));
        [a, g] = ind2sub(size(overlap), best);
        new(a) = g;
        overlap(a, :) = 0;
        overlap(:, g) = 0;
    end
    new(new == 0) = max(truth(:)) + (1:nnz(new == 0));
    out = zeros(size(est));
    for a = 1:numel(ids)
        out(est == ids(a)) = new(a);
    end
end

function write_gtr_maker(src, dest_dir, psz, szp)
% Bill's mk_GTR_images.m script as the function bill_mk_gtr_images(itype, ngtr, seed).
    txt = fileread(src);
    txt = replace_n(txt, 'close all; clearvars;', ...
        'function [gtrimg, maps, texs] = bill_mk_gtr_images(itype, ngtr, seed)', 1);
    txt = replace_n(txt, '^addpath\(''C:\\Users\\Bill Geisler[^\n]*\n', '', 5);
    txt = replace_n(txt, 'rng\(''shuffle''\);\s*\n\s*s = rng; seed = s\.Seed;', 'rng(seed);', 1);
    txt = replace_n(txt, '^ngtr = 20;[^\n]*', '', 1);
    txt = replace_n(txt, '^itype = 1;[^\n]*', '', 1);
    txt = replace_n(txt, '^psz = 32;', sprintf('psz = %d;', psz), 1);
    txt = replace_n(txt, '^szp = 20;', sprintf('szp = %d;', szp), 1);
    txt = replace_n(txt, '^showgtr = 1;', 'showgtr = 0;', 1);
    txt = replace_n(txt, 'if saveflg == 1\s*\n\s*gtrimg\(:,:,:,n\) = pimg;\s*\n\s*end', ...
        'gtrimg(:,:,:,n) = pimg;', 1);
    write_text(fullfile(dest_dir, 'bill_mk_gtr_images.m'), [txt newline 'end' newline]);
end

function txt = replace_n(txt, pattern, replacement, n_expected)
% regexprep that insists on exactly n_expected matches, so a change in Bill's file
% fails loudly instead of silently running unedited code.
    n = numel(regexp(txt, pattern, 'lineanchors'));
    assert(n == n_expected, 'Expected %d match(es) of "%s", found %d.', n_expected, pattern, n);
    txt = regexprep(txt, pattern, replacement, 'lineanchors');   % no $ or \ in replacements
end

function write_text(file, txt)
    fid = fopen(file, 'w');
    fwrite(fid, txt);
    fclose(fid);
end
