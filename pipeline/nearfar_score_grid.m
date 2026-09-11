function [pc, pcs, pcd, pcnf] = nearfar_score_grid(qbs, qbd, R, gc_vec, wm_vec)
% NEARFAR_SCORE_GRID  Discrimination accuracy over a grouping-criterion x weight grid.
%   [pc, pcs, pcd, pcnf] = nearfar_score_grid(qbs, qbd, R, gc_vec, wm_vec)
%
%   For each grouping criterion gc (rows) and mutual-similarity weight wm (cols),
%   scores the combined decision variable (qbs/qbd + wm*mutual) against the
%   near/far and same/different ground truth in R. Shared by pipeline stages
%   s6 (averages the surfaces over trials) and s7 (picks the peak-accuracy cell
%   to set the per-image gcopt/wmopt).
%
%   Inputs
%     qbs, qbd     - per-pair combined border+content decision variable, near (qbs)
%                    and far (qbd) (from self_sup_decision).
%     R            - struct of per-pair mutual similarity + same/different ground
%                    truth (from neighbor_far_responses): .rmn, .rmf, .same_near, .same_far.
%     gc_vec       - grouping-criterion values to sweep (dimensionless DV units).
%     wm_vec       - mutual-similarity weight values to sweep (dimensionless).
%
%   Outputs (each ngc x nms, ngc = numel(gc_vec), nms = numel(wm_vec))
%     pc   - overall same/different proportion correct.
%     pcs  - proportion of "same" pairs called same.
%     pcd  - proportion of "different" pairs called different.
%     pcnf - overall near/far proportion correct.
%
%   See also SELF_SUP_DECISION, NEIGHBOR_FAR_RESPONSES, S6_SELFSUP_DISCRIMINATION,
%   S7_SEGMENT_GTR

    ngc = numel(gc_vec);  nms = numel(wm_vec);
    [pc, pcs, pcd, pcnf] = deal(zeros(ngc, nms));
    for gc_idx = 1:ngc
        for wm_idx = 1:nms
            [pc(gc_idx,wm_idx), pcs(gc_idx,wm_idx), pcd(gc_idx,wm_idx), pcnf(gc_idx,wm_idx)] = ...
                score(qbs, qbd, R.rmn, R.rmf, R.same_near, R.same_far, ...
                gc_vec(gc_idx), wm_vec(wm_idx));
        end
    end
end

function [pc, pcs, pcd, pcnf] = score(qbs, qbd, rmn, rmf, same_near, same_far, gc, wm)
% Near-far and same-different accuracy for one (gc, wm) cell.
    ncnt = numel(qbs);
    ncs = 0; ncd = 0; sc = 0; dc = 0; ncn = 0; ncf = 0;
    for pair_idx = 1:ncnt
        near_dv = qbs(pair_idx) + wm*rmn(pair_idx);
        far_dv  = qbd(pair_idx) + wm*rmf(pair_idx);
        if same_near(pair_idx) == 1
            sc = sc + 1;
            if near_dv >= gc, ncs = ncs + 1; ncn = ncn + 1; end
        else
            dc = dc + 1;
            if near_dv <  gc, ncd = ncd + 1; else, ncn = ncn + 1; end
        end
        if same_far(pair_idx) == 1
            sc = sc + 1;
            if far_dv >= gc, ncs = ncs + 1; else, ncf = ncf + 1; end
        else
            dc = dc + 1;
            if far_dv <  gc, ncd = ncd + 1; ncf = ncf + 1; end
        end
    end
    pc   = (ncd + ncs) / (2*ncnt);
    pcs  = ncs / sc;
    pcd  = ncd / dc;
    pcnf = (ncn + ncf) / (2*ncnt);
end
