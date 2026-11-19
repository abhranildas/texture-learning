function out = s6_selfsup_discrimination(cfg, method, itype, ecc, ntrl)
% S6_SELFSUP_DISCRIMINATION  Per-image self-supervised texture discrimination.
%   out = s6_selfsup_discrimination(cfg, method, itype, ecc)
%
%   Pipeline stage 6 (merges self_sup_train_bnd_{bc,bc_shft,c_shft}.m). For each
%   GTR image, computes content/border/mutual DVs for near & far pairs, applies a
%   per-image self-supervised step, and sweeps the grouping criterion (gc) x
%   mutual-similarity weight (wm) to produce near-far and same-different accuracy
%   surfaces. Returns the trial-averaged surfaces.
%
%   method:
%     'bc'      - retrain the border+content bound on this image (classify_normals).
%     'bc_shft' - load the trained bc bound; learn a scalar shift of the bc DV.
%     'c_shft'  - load the trained bc bound; learn a scalar shift of the content DV.
%   itype: texture dataset (default per method: bc/bc_shft -> 3 Brodatz, c_shft -> 1 Pertex).
%   ecc:   eccentricity (default 1).
%
%   Run `setup` first; requires stages 2,4,5 artifacts + IntClassNorm.
%   NOTE: pd differs by method (bc=4, others=8) and eccb=1 for bins — preserved,
%   flagged for Geisler (see QUESTIONS_FOR_GEISLER.md).
%
%   Shared helpers (also used by s7): load_dv_handles, neighbor_far_responses,
%   self_sup_decision, nearfar_score_grid.
%
%   Inputs
%     cfg    - config struct (see config.m).
%     method - 'bc', 'bc_shft' or 'c_shft' (see above; passed through to self_sup_decision).
%     itype  - texture dataset selector (see load_texture_images); default per method.
%     ecc    - eccentricity downsample factor (1, 2, 4, 8); default 1.
%     ntrl   - number of GTR-image trials to average over; default 40.
%
%   Output
%     out - struct: .pcav/.pcsav/.pcdav/.pcnfav (trial-averaged accuracy surfaces,
%           ngc x nms, see nearfar_score_grid), .gc, .wm (the swept grids),
%           .method, .itype, .ecc.
%
%   See also LOAD_DV_HANDLES, NEIGHBOR_FAR_RESPONSES, SELF_SUP_DECISION,
%   NEARFAR_SCORE_GRID, MAKE_GTR_IMAGE, LOAD_TEXTURE_IMAGES, S7_SEGMENT_GTR

    mustBeMember(method, {'bc', 'bc_shft', 'c_shft'});
    switch method
        case 'bc'
            mp = struct('pd',4,'itype',3,'dgc',0.4,'gcmx',4,'dms',0.4,'msmx',4,'load_bc',false);
        case 'bc_shft'
            mp = struct('pd',8,'itype',3,'dgc',0.8,'gcmx',8,'dms',0.8,'msmx',8,'load_bc',true);
        case 'c_shft'
            mp = struct('pd',8,'itype',1,'dgc',0.8,'gcmx',8,'dms',0.8,'msmx',8,'load_bc',true);
    end
    if nargin < 3 || isempty(itype), itype = mp.itype; end
    if nargin < 4 || isempty(ecc),   ecc = 1; end
    if nargin < 5 || isempty(ntrl), ntrl = 40; end   % trials per session
    eccb = 1;                                   % bin-bounds eccentricity (see note)
    cfg.optics.pupil_diameter = mp.pd;          % method-specific pupil for the OTF

    cstat        = zeros(1,20); cstat(cfg.features.dv_dims) = 5;   % spot + edge DV dims

    % artifacts: bin bounds + trained DV handles (LMS->ABR transform auto-loaded)
    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds( ...
        cstat, eccb, bins_filename(cfg));
    dv = load_dv_handles(cfg, ecc, mp.load_bc);

    % trial stimuli, and the patch-index -> grid row/col maps (row-major)
    [imgs, maps] = make_gtr_image(cfg, itype, ntrl, ecc);
    szp = cfg.gtr.szp;
    px = repelem((1:szp)', szp);
    py = repmat((1:szp)', szp, 1);

    % criterion / mutual-similarity-weight grid
    gc_vec = 0:mp.dgc:mp.gcmx;   ngc = numel(gc_vec);
    wm_vec = 0:mp.dms:mp.msmx;   nms = numel(wm_vec);
    [pc, pcs, pcd, pcnf] = deal(zeros(ngc, nms, ntrl));

    for trl = 1:ntrl
        pimg = imgs(:, :, :, trl);
        phiall = segmentation.content_similarity_matrix(pimg, size(pimg,1)/cfg.gtr.szp, ...
            px, py, bin_bounds, n_bins, dv.h, dv.e, dv.c, cfg);
        rho = segmentation.mutual_similarity(phiall, cfg.bill_compat);
        R = neighbor_far_responses(cfg, pimg, rho, maps(:,:,trl), bin_bounds, n_bins, dv);

        % per-image self-supervised step -> combined near/far decision variables qbs/qbd
        [qbs, qbd] = self_sup_decision(method, R, dv);

        % sweep grouping criterion (gc) x mutual-similarity weight (wm)
        [pc(:,:,trl), pcs(:,:,trl), pcd(:,:,trl), pcnf(:,:,trl)] = ...
            nearfar_score_grid(qbs, qbd, R, gc_vec, wm_vec);
    end

    out.pcav   = mean(pc,   3);
    out.pcsav  = mean(pcs,  3);
    out.pcdav  = mean(pcd,  3);
    out.pcnfav = mean(pcnf, 3);
    out.gc = gc_vec;  out.wm = wm_vec;  out.method = method;  out.itype = itype;  out.ecc = ecc;
    fprintf('s6 (%s, itype %d, ecc %d): mean near-far PC max %.3f\n', ...
        method, itype, ecc, max(out.pcav,[],'all'));
end
