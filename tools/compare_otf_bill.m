function result = compare_otf_bill(itypes, n_images, out_dir, bill_root)
% COMPARE_OTF_BILL  Segment GTR images with Bill's code under his and the corrected optics filter.
%   result = compare_otf_bill()
%   result = compare_otf_bill(itypes, n_images, out_dir, bill_root)
%
%   For each texture set, makes n_images GTR images with Bill's mk_GTR_images.m and
%   segments each one five ways:
%     1. Bill's current code: his ss_segm.m with his aply_otf.m (frequency
%        u = k/ppd, the incorrect units);
%     2. Bill's code with a corrected aply_otf.m (u = k*ppd/N cycles/deg);
%     3. as 2, plus a corrected ss_segm.m mutual-similarity loop (no stale entry
%        carried over from the i == j case);
%     4. this repo's code (segment_bill_image) with the corrected filter and without
%        the other Bill-compatibility settings (cfg.bill_compat = false: shared
%        vislab colour rotation, no stale mutual-similarity term);
%     5. as 4, but with no optics filter on the GTR image (config's test_optics =
%        false; the model is still the one trained with the optics).
%   Rows 1-3 use Bill's trained model, rows 4-5 this repo's (data/models). All five
%   use Bill's flags and fixed grouping parameters
%   (seg_11_8_26_1_1.mat, as his test_ss_segm.m does), and start from the same RNG
%   state. One figure per texture set: one column per image, rows ground truth and
%   segmentations 1-5, regions as semi-transparent colours matched to the ground
%   truth. Figures are saved as PNGs in out_dir.
%
%   Bill's code comes from texture-learning-newer/GTRdiscsegm (ss_segm, Rp,
%   mk_GTR_images, mk_masks_w, the fixed parameters), texture-learning-new (all
%   other helpers and the trained model files) and texture-learning-newer/GTR
%   images/Texture Images (the texture sheets). His files are only read and called,
%   never modified. Edited copies are written to a temp folder for this call only:
%     - mk_GTR_images.m (GTRdiscsegm) as a function: texture set, image count and
%       seed as inputs; 64 px patches on a 10 x 10 grid (as GTR22.mat, which
%       test_ss_segm.m segments); no display, no file saved. Everything else is his:
%       sheets converted to grayscale, each sheet luminance and contrast normalized.
%     - aply_otf.m with only the frequency line corrected (segmentations 2, 3);
%     - ss_segm.m with only the mutual-similarity line corrected to use the l
%       entries filled for this (i, j) (segmentation 3).
%
%   Note: Bill's trained model and fixed parameters were not retrained with the
%   corrected filter (docs/segmentation-parity.md, step 5).
%
%   Inputs
%     itypes     texture sets (1 Pertex, 2 Fabric, 3 Brodatz, 4 Brodatz+Fabric,
%                5 VisTex, 6 McGill); default [3 2 4 5 6 1].
%     n_images   GTR images per texture set; default 4.
%     out_dir    folder for the PNGs; default data/stimuli/otf_comparison.
%     bill_root  folder holding Bill's code (default: the sibling "Bill's code").
%   Output
%     result  struct array, one per texture set: .itype, .name, .n_correct
%             (5 x n_images, regions exactly right; rows = segmentations 1-5)
%
% See also CAPTURE_BILL_SEGMENTATION, SEGMENT_BILL_IMAGE, OTF_PPD

    repo_root = fileparts(fileparts(mfilename('fullpath')));
    if nargin < 1 || isempty(itypes),    itypes = [3 2 4 5 6 1]; end
    if nargin < 2 || isempty(n_images),  n_images = 4; end
    if nargin < 3 || isempty(out_dir)
        out_dir = fullfile(repo_root, 'data', 'stimuli', 'otf_comparison');
    end
    if nargin < 4 || isempty(bill_root), bill_root = fullfile(repo_root, '..', "Bill's code"); end
    if ~isfolder(out_dir), mkdir(out_dir); end
    psz = 64;  szp = 10;  seed = 0;
    set_names = {'Pertex', 'Fabric', 'Brodatz', 'Brodatz+Fabric', 'VisTex', 'McGill'};

    % --- this repo, then Bill's code on the path for this call only (addpath
    %     prepends, so Bill's folders win any name clash while he is running) ---
    addpath(repo_root);
    setup();
    bill_info = what(bill_root);
    bill_root = bill_info.path;               % absolute, no '..', for the which() checks
    repo_path = path;                         % the repo's code runs on this path only
    old_path = path;
    restore_path = onCleanup(@() path(old_path));
    segm_dir  = fullfile(bill_root, 'texture-learning-newer', 'GTRdiscsegm');
    sheet_dir = fullfile(bill_root, 'texture-learning-newer', 'GTR images', 'Texture Images');
    addpath(fullfile(bill_root, 'texture-learning-new'));
    addpath(segm_dir);
    for d = {'Brodatz', 'Fabric', 'Pertex', 'Vistex', 'Mcgill'}
        addpath(fullfile(sheet_dir, d{1}));
    end
    temp_dir = tempname;  mkdir(temp_dir);
    remove_temp = onCleanup(@() rmdir(temp_dir, 's'));
    fixed_dir = fullfile(temp_dir, 'otf_fixed');  mkdir(fixed_dir);
    rho_dir   = fullfile(temp_dir, 'rho_fixed');  mkdir(rho_dir);
    write_gtr_maker(fullfile(segm_dir, 'mk_GTR_images.m'), temp_dir, psz, szp);
    write_fixed_otf(fullfile(bill_root, 'texture-learning-new', 'aply_otf.m'), fixed_dir);
    write_fixed_rho(fullfile(segm_dir, 'ss_segm.m'), rho_dir);
    addpath(temp_dir);
    % Bill's runs: folders of corrected copies to put in front of his files, and
    % the copies each run must actually be using
    bill_runs = struct('dirs', {{}, {fixed_dir}, {fixed_dir, rho_dir}}, ...
        'otf_from', {bill_root, fixed_dir, fixed_dir}, ...
        'segm_from', {bill_root, bill_root, rho_dir});
    row_labels = {'Ground truth', 'Bill''s current code', ...
        {'Bill''s code,', 'corrected filter'}, ...
        {'Bill''s code, corrected', 'filter and mutual sim'}, ...
        {'New code,', 'corrected filter'}, ...
        {'New code,', 'no filter'}};

    % --- Bill's flags and fixed parameters; the repo uses the same ones ---
    P = load(fullfile(segm_dir, 'seg_11_8_26_1_1.mat'), 'flgs', 'gl', 'gcc', 'gr');
    % the repo's runs: model trained with the optics, test image with the corrected
    % filter or with none; no stale term, shared colour rotation
    repo_cfgs = {config(P.flgs(6) == 1, P.flgs(7) == 1, true), ...
                 config(P.flgs(6) == 1, P.flgs(7) == 1, false)};
    for c = 1:numel(repo_cfgs), repo_cfgs{c}.bill_compat = false; end
    params_new = struct('method', 'bc', 'group_offset', P.gl, 'confidence', P.gcc, ...
        'merge', P.gr);
    ppd = 60;  pupil = 4;  wavelength = 550;     % ss_segm.m's optics constants

    n_bill = numel(bill_runs);
    n_runs = n_bill + numel(repo_cfgs);      % Bill's runs, then the repo's
    result = struct('itype', {}, 'name', {}, 'n_correct', {});
    for t = 1:numel(itypes)
        name = set_names{itypes(t)};
        [gtrimg, maps, texs] = bill_mk_gtr_images(itypes(t), n_images, seed);
        ntexr = size(texs, 2);
        counts = zeros(n_runs, n_images);
        shown  = cell(n_runs + 1, n_images); % {display image, region map} per panel
        for k = 1:n_images
            img = gtrimg(:, :, :, k);
            map = maps(:, :, k);
            state = rng;                     % same random draws for every run

            for b = 1:numel(bill_runs)
                dirs = bill_runs(b).dirs;
                if ~isempty(dirs), addpath(dirs{:}); end
                assert_resolves('aply_otf', bill_runs(b).otf_from);
                assert_resolves('ss_segm',  bill_runs(b).segm_from);
                rng(state);
                [emap, ~, counts(b, k)] = ss_segm(img, map, ntexr, psz, szp, P.flgs, ...
                    P.gl, P.gcc, P.gr);
                shown{b + 1, k} = {aply_otf(img, ppd, pupil, wavelength), emap};
                if ~isempty(dirs), rmpath(dirs{:}); end
            end
            shown{1, k} = {shown{2, k}{1}, map};

            % display images: Bill's corrected-filter image, or the unfiltered one
            repo_shown = {shown{3, k}{1}, img};
            bill_path = path;                % Bill's files off the path, so none
            path(repo_path);                 % shadows a repo function
            for c = 1:numel(repo_cfgs)
                rng(state);
                seg_new = segment_bill_image(repo_cfgs{c}, img, map, P.flgs(1), params_new);
                counts(n_bill + c, k) = seg_new.nrg;
                shown{n_bill + c + 1, k} = {repo_shown{c}, seg_new.emap};
            end
            path(bill_path);
        end

        plot_comparison(name, row_labels, shown, maps, counts, ntexr, ...
            fullfile(out_dir, sprintf('otf_comparison_%s.png', strrep(name, '+', '_'))));
        result(t) = struct('itype', itypes(t), 'name', name, 'n_correct', counts);
        fprintf('%-15s regions exactly right per row: %s\n', name, ...
            sprintf('%5.1f%% ', 100 * mean(counts, 2) / ntexr));
    end
    fprintf('Figures saved in %s\n', out_dir);
end

function plot_comparison(name, row_labels, shown, maps, counts, ntexr, png_file)
% One figure: a label column, then one column per image; rows ground truth and the
% segmentations.
    [n_rows, n_images] = size(shown);
    n_cols = n_images + 1;
    fig = figure('Name', sprintf('Optics comparison: %s', name), ...
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

function write_fixed_otf(src, dest_dir)
% Bill's aply_otf.m with the radial frequency in cycles/deg: bin k of an N-pixel
% image is k*ppd/N cycles/deg, not k/ppd.
    txt = replace_n(fileread(src), ...
        'u = sqrt\(\(i-i0\)\^2 \+ \(j-j0\)\^2\)/ppd;', ...
        'u = sqrt(((i-i0)/sz1)^2 + ((j-j0)/sz2)^2)*ppd;', 1);
    write_text(fullfile(dest_dir, 'aply_otf.m'), txt);
end

function write_fixed_rho(src, dest_dir)
% Bill's ss_segm.m with the mutual similarity computed from the l entries filled for
% this (i, j) only. His vi, vj are allocated once outside the loop, so after the
% i == j case (one extra entry) every later pair carries that stale last entry.
    txt = replace_n(fileread(src), ...
        'rho\(i,j\) = sum\(vi\.\*vj\)/sqrt\(sum\(vi\.\^2\)\*sum\(vj\.\^2\)\);', ...
        'rho(i,j) = sum(vi(1:l).*vj(1:l))/sqrt(sum(vi(1:l).^2)*sum(vj(1:l).^2));', 1);
    write_text(fullfile(dest_dir, 'ss_segm.m'), txt);
end

function assert_resolves(fname, folder)
% Fail unless fname resolves to a file under folder.
    file = which(fname);
    assert(startsWith(file, folder), '%s resolves to %s, expected under %s.', ...
        fname, file, folder);
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
