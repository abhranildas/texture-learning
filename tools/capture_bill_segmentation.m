function golden = capture_bill_segmentation(bill_root, out_file)
% CAPTURE_BILL_SEGMENTATION  Record Bill's own segmentation of his GTR images as a golden reference.
%   golden = capture_bill_segmentation()
%   golden = capture_bill_segmentation(bill_root, out_file)
%
%   Runs Bill's ss_segm.m on the 20 Fabric GTR images in his GTR22.mat, exactly as
%   his test_ss_segm.m does: the flags and grouping parameters from
%   seg_11_8_26_1_1.mat, rng(1) set once, images in order. Saves the segmentations
%   (and the intermediate quantities behind them) to out_file. CHECK_BILL_SEGMENTATION
%   then compares this repo's segmentation of the same images against it.
%
%   Bill's files are only read and called, never modified. Everything comes from
%   Bill's code/texture-learning-newer/GTRdiscsegm (ss_segm, newest Rp, the images
%   and parameters) and Bill's code/texture-learning-new (all other helpers, the
%   trained dbnd*NO bounds, CDFs and AHEO bins), which this function puts on the
%   path for the duration of the call and then removes.
%
%   Each image is segmented twice from the same RNG state:
%     1. by Bill's ss_segm.m itself -- this gives the golden segmentation;
%     2. by a copy of it written to a temp folder, identical except that it also
%        returns its intermediate values (stages, below), for locating where this
%        repo first departs from Bill's code. The two runs must agree exactly, or
%        the function errors.
%   Bill's own saved output for these images (ss_segm_11_8_26_22.mat) is the anchor:
%   a mismatch with it means this machine's setup (bounds files, toolbox versions)
%   differs from Bill's, and is reported with a warning.
%
%   Inputs
%     bill_root  folder holding Bill's code (default: the sibling "Bill's code").
%     out_file   .mat file to write (default: tools/golden_bill_segm.mat).
%   Output
%     golden  struct, also saved to out_file:
%       .images_file  GTR image file, relative to bill_root
%       .params       flgs, gl, gcc, gr passed to ss_segm
%       .images(k)    per image: .rng_state (RNG state just before segmenting it),
%                     .map, .emap, .ngrps, .nrg, .pcmx, .matches_bill_saved, .stages
%       .stages       phiall, rho (all-pairs content and mutual similarity),
%                     rcn/rbn/rbcn/rmn and rcf/rbf/rbcf/rmf (near/far content, border,
%                     border+content and mutual-similarity values), same_near,
%                     same_far, pcnf (near/far accuracy over gc x wm), gcopt, wmopt,
%                     phi, mu (neighbour similarity before/after adding wmopt*rho;
%                     sparse)
%
%   Runtime: two ss_segm calls per image, 20 images (not yet timed).
%
% See also CHECK_BILL_SEGMENTATION

    repo_root = fileparts(fileparts(mfilename('fullpath')));
    if nargin < 1 || isempty(bill_root), bill_root = fullfile(repo_root, '..', "Bill's code"); end
    if nargin < 2 || isempty(out_file),  out_file  = fullfile(repo_root, 'tools', 'golden_bill_segm.mat'); end

    segm_rel   = fullfile('texture-learning-newer', 'GTRdiscsegm');
    segm_dir   = fullfile(bill_root, segm_rel);
    helper_dir = fullfile(bill_root, 'texture-learning-new');

    % --- Bill's code on the path for this call only. addpath prepends, so segm_dir
    %     (added last) wins where both folders hold a file (e.g. Rp.m). ---
    old_path = path;
    restore_path = onCleanup(@() path(old_path));
    addpath(helper_dir);
    addpath(segm_dir);
    temp_dir = tempname;  mkdir(temp_dir);
    remove_temp = onCleanup(@() rmdir(temp_dir, 's'));
    write_instrumented_copy(fullfile(segm_dir, 'ss_segm.m'), temp_dir);
    addpath(temp_dir);
    assert_from_bill({'ss_segm', 'Rp', 'Rh', 'Re', 'Rb', 'Rb12', 'mk_phi', 'mk_groups', ...
        'reg_count', 'mk_bb', 'ptch_norm', 'cntrst_norm', 'rot', 'dsmp', 'aply_otf', ...
        'rgb2lms', 'load_b0_nat'}, bill_root);

    images_file = fullfile(segm_rel, 'GTR22.mat');
    images   = load(fullfile(bill_root, images_file), 'gtrimg', 'maps', 'texs', 'ngtr', 'psz', 'szp');
    params   = load(fullfile(segm_dir, 'seg_11_8_26_1_1.mat'), 'flgs', 'gl', 'gcc', 'gr');
    bill_out = load(fullfile(segm_dir, 'ss_segm_11_8_26_22.mat'), 'emaps', 'ngrps', 'nrg', 'pcmx');
    ntexr = size(images.texs, 2);

    rng(1);                                            % as test_ss_segm.m:22-23
    for k = 1:images.ngtr
        args = {images.gtrimg(:,:,:,k), images.maps(:,:,k), ntexr, images.psz, images.szp, ...
                params.flgs, params.gl, params.gcc, params.gr};
        state = rng;
        [emap, ngrps, nrg, pcmx] = ss_segm(args{:});
        rng(state);
        [emap2, ngrps2, nrg2, pcmx2, stages] = ss_segm_instrumented(args{:});
        if ~isequaln({emap, ngrps, nrg, pcmx}, {emap2, ngrps2, nrg2, pcmx2})
            error('capture_bill_segmentation:instrumentedDiffers', ...
                'Image %d: the instrumented copy of ss_segm disagrees with ss_segm itself.', k);
        end
        matches = isequal(emap, bill_out.emaps(:,:,k)) && ngrps == bill_out.ngrps(k) ...
            && nrg == bill_out.nrg(k) && abs(pcmx - bill_out.pcmx(k)) < 1e-12;
        golden.images(k) = struct('rng_state', state, 'map', images.maps(:,:,k), ...
            'emap', emap, 'ngrps', ngrps, 'nrg', nrg, 'pcmx', pcmx, ...
            'matches_bill_saved', matches, 'stages', stages);
        fprintf('image %2d/%d: %d of %d regions exact, matches Bill''s saved run: %d\n', ...
            k, images.ngtr, nrg, ntexr, matches);
    end

    golden.images_file = images_file;
    golden.params = params;
    save(out_file, '-struct', 'golden');
    fprintf('Saved %s\n', out_file);

    n_match = sum([golden.images.matches_bill_saved]);
    if n_match < images.ngtr
        warning('capture_bill_segmentation:anchorMismatch', ...
            ['%d of %d images differ from Bill''s saved ss_segm_11_8_26_22.mat. This setup ' ...
             'does not reproduce Bill''s run; fix that before trusting the golden file.'], ...
            images.ngtr - n_match, images.ngtr);
    end
end

function write_instrumented_copy(src, out_dir)
% Copy Bill's ss_segm.m as ss_segm_instrumented.m, changed only so it also returns
% its intermediate values. Each edit must match exactly once, so a change to Bill's
% file fails loudly here instead of silently capturing the wrong thing.
    txt = strrep(fileread(src), sprintf('\r\n'), newline);
    txt = replace_once(txt, 'function [emap,ngrps,nrg,pcmx] =...', ...
                            'function [emap,ngrps,nrg,pcmx,stages] =...');
    txt = replace_once(txt, '    ss_segm(img,map,', '    ss_segm_instrumented(img,map,');
    % rho is zeroed off-neighbour while mu is built, so keep the full matrix first
    txt = replace_once(txt, '% combine similarity and mutual similarity', ...
                            ['rho_all = rho;' newline '% combine similarity and mutual similarity']);
    capture = ['stages = struct(''phiall'', phiall, ''rho'', rho_all, ' ...
        '''rcn'', rcn, ''rbn'', rbn, ''rbcn'', rbcn, ''rmn'', rmn, ' ...
        '''rcf'', rcf, ''rbf'', rbf, ''rbcf'', rbcf, ''rmf'', rmf, ' ...
        '''same_near'', same_near, ''same_far'', same_far, ''pcnf'', pcnf, ' ...
        '''gcopt'', gcopt, ''wmopt'', wmopt, ''phi'', sparse(phi), ''mu'', sparse(mu));'];
    last_end = regexp(txt, '\nend\s*$', 'once');
    assert(~isempty(last_end), 'capture_bill_segmentation:edit', 'ss_segm.m: final "end" not found');
    txt = [txt(1:last_end) capture newline 'end' newline];
    fid = fopen(fullfile(out_dir, 'ss_segm_instrumented.m'), 'w');
    fwrite(fid, txt);
    fclose(fid);
end

function txt = replace_once(txt, old, new)
    n = count(txt, old);
    assert(n == 1, 'capture_bill_segmentation:edit', ...
        'ss_segm.m: expected "%s" once, found it %d times', old, n);
    txt = strrep(txt, old, new);
end

function assert_from_bill(names, bill_root)
% Every helper must resolve to Bill's folders, not to a same-named file elsewhere.
    root = char(java.io.File(bill_root).getCanonicalPath());
    for i = 1:numel(names)
        where = which(names{i});
        if isempty(where) || ~startsWith(char(java.io.File(where).getCanonicalPath()), root)
            error('capture_bill_segmentation:shadowed', ...
                '%s resolves to "%s", not to Bill''s code under %s', names{i}, where, root);
        end
    end
end
