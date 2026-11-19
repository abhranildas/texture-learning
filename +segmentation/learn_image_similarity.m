function S = learn_image_similarity(cfg, pimg, map, method)
% LEARN_IMAGE_SIMILARITY  One image's patch similarities and self-supervised grouping settings.
%   S = segmentation.learn_image_similarity(cfg, pimg, map, method)
%
%   Computes, once per image, everything the grouping step needs:
%     1. the all-pairs content similarity phiall and the mutual similarity rho;
%     2. near/far patch-pair responses, and from them the grouping criterion gcopt
%        and mutual-similarity weight wmopt that maximize near/far accuracy on this
%        image (the self-supervised step);
%     3. the neighbour border+content similarity phi, combined into
%        mu = phi + wmopt*rho on neighbouring pairs.
%   Grouping itself is left to the caller (segmentation.group_patches), so a sweep
%   over grouping parameters reuses one S.
%
%   Inputs
%     cfg     config struct (config.m).
%     pimg    GTR image in LMS space, as from make_gtr_image.
%     map     [rows x cols] ground-truth region map. Sets the patch grid; its labels
%             are used only to score same/different accuracy (S.pc, S.pcmx), never
%             to choose gcopt or wmopt.
%     method  self-supervised rule (see self_sup_decision):
%               'bc'  pre-trained border+content DV as is ('bc_noshift'); only
%                     gcopt and wmopt are learned. Bill's current rule (ss_segm.m
%                     with contentflg = 0, borderflg = 1).
%               'nc'  older: content-based shift ('c_shft').
%               'ncb' older: border+content bound refit on this image ('bc').
%   Output
%     S  struct, field names matching Bill's ss_segm.m where they exist:
%          phiall, rho                 all-pairs content and mutual similarity
%          rcn rbn rmn / rcf rbf rmf   near / far content, border, mutual values
%          same_near, same_far         ground truth for those pairs
%          pcnf, pc                    near/far and same/different accuracy, gc x wm
%          gcopt, wmopt, pcmx          chosen criterion and weight; pc there
%          phi, dst, mu                neighbour similarity, patch distances, combined
%          patch_x, patch_y, patch_size  patch grid
%
% See also SEGMENTATION.SEGMENT_LMS, S7_SEGMENT_GTR, NEIGHBOR_FAR_RESPONSES,
%   SELF_SUP_DECISION, NEARFAR_SCORE_GRID

    [n_rows, n_cols] = size(map);
    patch_size = size(pimg, 1) / n_rows;
    ecc = cfg.patch.size / patch_size;
    [cols, rows] = meshgrid(1:n_cols, 1:n_rows);       % patch k is row-major, as make_gtr_image
    patch_x = reshape(rows', [], 1);
    patch_y = reshape(cols', [], 1);

    % artifacts: bin bounds (always the ecc-1 bins, as in the originals) + trained DVs
    cstat = zeros(1, 20);  cstat(cfg.features.dv_dims) = 5;   % spot + edge DV dims
    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds(cstat, 1, bins_filename(cfg));
    dv = load_dv_handles(cfg, ecc, true);

    % --- 1. content similarity + mutual similarity ---
    phiall = segmentation.content_similarity_matrix(pimg, patch_size, patch_x, patch_y, ...
        bin_bounds, n_bins, dv.h, dv.e, dv.c, cfg);
    rho = segmentation.mutual_similarity(phiall, cfg.bill_compat);

    % --- 2. learn gcopt/wmopt from the self-supervised near/far task (grids and
    %        tie-breaking as Bill's ss_segm.m:231-234, 594-598) ---
    gc_vec = 0 : 0.8 : 16;         % grouping criterion
    wm_vec = 0 : 0.8 : 16;         % mutual-similarity weight
    R = neighbor_far_responses(cfg, pimg, rho, map, bin_bounds, n_bins, dv);
    ss_method = struct('bc', 'bc_noshift', 'nc', 'c_shft', 'ncb', 'bc').(method);
    [qbs, qbd] = self_sup_decision(ss_method, R, dv);
    [pc, ~, ~, pcnf] = nearfar_score_grid(qbs, qbd, R, gc_vec, wm_vec);
    [~, best] = max(pcnf, [], 'all', 'linear');   % first max in column order:
    [gc_idx, wm_idx] = ind2sub(size(pcnf), best);  % lowest wm, then lowest gc

    % --- 3. neighbour similarity + combined mu = phi + wmopt*rho ---
    [phi, dst] = segmentation.neighbor_similarity_matrix(pimg, patch_size, patch_x, patch_y, ...
        patch_size, bin_bounds, n_bins, dv, cfg);
    wmopt = wm_vec(wm_idx);
    mu = (phi + wmopt * rho) .* (phi ~= 0);  % combine only on neighbouring pairs

    S = struct('phiall', phiall, 'rho', rho, ...
        'rcn', R.rcn, 'rbn', R.rbn, 'rmn', R.rmn, 'rcf', R.rcf, 'rbf', R.rbf, 'rmf', R.rmf, ...
        'same_near', R.same_near, 'same_far', R.same_far, 'pcnf', pcnf, 'pc', pc, ...
        'gcopt', gc_vec(gc_idx), 'wmopt', wmopt, 'pcmx', pc(gc_idx, wm_idx), ...
        'phi', phi, 'dst', dst, 'mu', mu, ...
        'patch_x', patch_x, 'patch_y', patch_y, 'patch_size', patch_size);
end
