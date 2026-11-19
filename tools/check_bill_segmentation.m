function report = check_bill_segmentation(segment_fn, golden_file, bill_root)
% CHECK_BILL_SEGMENTATION  Test that this repo segments Bill's GTR images exactly as Bill's code does.
%   report = check_bill_segmentation(segment_fn)
%   report = check_bill_segmentation(segment_fn, golden_file, bill_root)
%
%   Re-segments every image in the golden file (from CAPTURE_BILL_SEGMENTATION)
%   with segment_fn, starting each one from the RNG state Bill's run had for it,
%   and compares the result with Bill's.
%
%   An image passes when the segmentation is the same: the same patches grouped
%   together (region labels may be numbered differently), the same number of
%   groups, and the same number of exactly-correct regions. For a failing image,
%   the report names the first intermediate stage that differs, in pipeline order,
%   to show where the repo first departs from Bill's code.
%
%   Inputs
%     segment_fn   default (empty or omitted): this repo's segmentation. Bill's RGB
%                  image goes through the repo's eye optics, RGB->LMS and
%                  downsampling, then segmentation.segment_lms with Bill's
%                  grouping parameters and the 'bc' rule (Bill's current one).
%                  Otherwise a handle, out = segment_fn(img, map, params):
%                    img     the GTR image as Bill stores it (RGB, gtrimg(:,:,:,k))
%                    map     its ground-truth region map
%                    params  struct with Bill's flgs, gl, gcc, gr
%                  out must have .emap, .ngrps, .nrg, .pcmx. It may also have
%                  .stages with any of the golden stage fields, under the same names
%                  (see CAPTURE_BILL_SEGMENTATION); only those present are compared.
%     golden_file  default tools/golden_bill_segm.mat
%     bill_root    folder holding Bill's code (default: the sibling "Bill's code");
%                  the images are read from there, never written.
%   Output
%     report  struct array, one per image: .segmentation_ok, .ngrps_ok, .nrg_ok,
%             .pass, .first_diff_stage ('' if none), .first_diff_size (max abs diff)
%
% See also CAPTURE_BILL_SEGMENTATION

    repo_root = fileparts(fileparts(mfilename('fullpath')));
    if nargin < 1 || isempty(segment_fn)
        addpath(repo_root);
        setup();
        segment_fn = @repo_segment;
    end
    if nargin < 2 || isempty(golden_file), golden_file = fullfile(repo_root, 'tools', 'golden_bill_segm.mat'); end
    if nargin < 3 || isempty(bill_root),   bill_root   = fullfile(repo_root, '..', "Bill's code"); end

    golden = load(golden_file);
    images = load(fullfile(bill_root, golden.images_file), 'gtrimg');
    stage_order = {'phiall', 'rho', 'rcn', 'rbn', 'rbcn', 'rmn', 'rcf', 'rbf', 'rbcf', 'rmf', ...
                   'same_near', 'same_far', 'pcnf', 'gcopt', 'wmopt', 'phi', 'mu'};

    n_img = numel(golden.images);
    for k = 1:n_img
        ref = golden.images(k);
        rng(ref.rng_state);
        out = segment_fn(images.gtrimg(:,:,:,k), ref.map, golden.params);

        r.segmentation_ok = same_partition(out.emap, ref.emap);
        r.ngrps_ok = out.ngrps == ref.ngrps;
        r.nrg_ok   = out.nrg == ref.nrg;
        r.pass     = r.segmentation_ok && r.ngrps_ok && r.nrg_ok;
        [r.first_diff_stage, r.first_diff_size] = first_difference(out, ref.stages, stage_order);
        report(k) = r; %#ok<AGROW>

        fprintf('image %2d/%d: %s', k, n_img, pass_fail(r.pass));
        if ~isempty(r.first_diff_stage)
            fprintf('   (first differing stage: %s, max |diff| = %.3g)', ...
                r.first_diff_stage, r.first_diff_size);
        end
        fprintf('\n');
    end
    fprintf('%d of %d images segmented exactly as Bill''s code does.\n', sum([report.pass]), n_img);
end

function out = repo_segment(img, map, params)
% This repo's segmentation of one of Bill's stored RGB GTR images. Bill's flags:
% 1 = resolution level, 6 = colour cues, 7 = eye optics.
    cfg = config(params.flgs(6) == 1, params.flgs(7) == 1);
    cfg.bill_compat = true;                % reproduce Bill's quirks (config.m)
    out = segment_bill_image(cfg, img, map, params.flgs(1), struct('method', 'bc', ...
        'group_offset', params.gl, 'confidence', params.gcc, 'merge', params.gr));
end

function ok = same_partition(a, b)
% True if a and b group the same patches together, whatever the label numbers.
    if ~isequal(size(a), size(b)), ok = false; return; end
    pairs = unique([a(:) b(:)], 'rows');
    ok = size(pairs, 1) == numel(unique(a)) && size(pairs, 1) == numel(unique(b));
end

function [stage, gap] = first_difference(out, ref_stages, stage_order)
% First stage (in pipeline order) where out.stages departs from Bill's beyond
% round-off. Stages the repo does not report are skipped.
    stage = '';  gap = 0;
    if ~isfield(out, 'stages'), return; end
    for i = 1:numel(stage_order)
        name = stage_order{i};
        if ~isfield(out.stages, name), continue; end
        mine = full(double(out.stages.(name)));
        bill = full(double(ref_stages.(name)));
        if ~isequal(size(mine), size(bill))
            stage = name;  gap = inf;  return;
        end
        d = abs(mine(:) - bill(:));
        d(isnan(mine(:)) & isnan(bill(:))) = 0;
        tol = 1e-9 * max(1, max(abs(bill(:)), [], 'omitnan'));
        if any(d > tol | isnan(d))
            stage = name;  gap = max(d);  return;
        end
    end
end

function s = pass_fail(ok)
    if ok, s = 'PASS'; else, s = 'FAIL'; end
end
