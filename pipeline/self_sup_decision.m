function [qbs, qbd] = self_sup_decision(method, R, dv)
% SELF_SUP_DECISION  Per-image self-supervised combined decision variable.
%   [qbs, qbd] = self_sup_decision(method, R, dv)
%
%   Returns the combined border+content decision variable for the near (qbs) and
%   far (qbd) patch pairs in R (from neighbor_far_responses), after the per-image
%   self-supervised step. Shared by pipeline stages s6 and s7.
%
%   method:
%     'bc'         - refit the border+content bound on THIS image (classify_normals),
%                    treating near pairs as "same" and far pairs as "different".
%     'bc_shft'    - load the trained bc bound; learn a scalar shift of the bc DV.
%     'bc_noshift' - load the trained bc bound; apply it with no shift.
%     'c_shft'     - load the trained bc bound; learn a scalar shift of the content DV.
%
%   'bc' requires the IntClassNorm add-on (classify_normals); the others require
%   the trained bc bound handle dv.bc (see load_dv_handles with load_bc=true).
%
%   Inputs
%     method - one of 'bc', 'bc_shft', 'bc_noshift', 'c_shft' (see above).
%     R      - struct of per-pair content/border responses + same/different ground
%              truth (from neighbor_far_responses).
%     dv     - struct of trained DV function handles (from load_dv_handles); dv.bc
%              is required unless method is 'bc'.
%
%   Outputs
%     qbs, qbd - combined decision variable per pair, near (qbs) and far (qbd).
%
%   See also NEIGHBOR_FAR_RESPONSES, LOAD_DV_HANDLES, NEARFAR_SCORE_GRID,
%   S6_SELFSUP_DISCRIMINATION, S7_SEGMENT_GTR

    n_pairs = R.ncnt;
    qbs = zeros(1, n_pairs);  qbd = zeros(1, n_pairs);
    switch method
        case 'bc'                                   % refit the bc bound on this image
            bd = classify_normals([R.rcn', R.rbn'], [R.rcf', R.rbf'], ...
                'input_type', 'samp', 'plotmode', 0);
            dvbc = quad2fun(bd.samp_opt_bd, 0);
            for pair_idx = 1:n_pairs
                qbs(pair_idx) = dvbc([R.rcn(pair_idx), R.rbn(pair_idx)]');
                qbd(pair_idx) = dvbc([R.rcf(pair_idx), R.rbf(pair_idx)]');
            end
        case 'bc_shft'                              % shift the pre-trained bc DV
            rbcn = apply_bc(dv.bc, R.rbn, R.rcn);
            rbcf = apply_bc(dv.bc, R.rbf, R.rcf);
            copt = best_criterion(rbcn, rbcf, 5);
            qbs = rbcn - copt;
            qbd = rbcf - copt;
        case 'bc_noshift'                             % pre-trained bc DV, no shift
            qbs = apply_bc(dv.bc, R.rbn, R.rcn);
            qbd = apply_bc(dv.bc, R.rbf, R.rcf);
        case 'c_shft'                                 % shift the content DV, then bc bound
            rcn = nan_to_zero(R.rcn);  rcf = nan_to_zero(R.rcf);
            rbn = nan_to_zero(R.rbn);  rbf = nan_to_zero(R.rbf);
            copt = best_criterion(rcn, rcf, 1);
            for pair_idx = 1:n_pairs
                qbs(pair_idx) = dv.bc([rcn(pair_idx) - copt, rbn(pair_idx)]');
                qbd(pair_idx) = dv.bc([rcf(pair_idx) - copt, rbf(pair_idx)]');
            end
        otherwise
            error('self_sup_decision:badMethod', 'unknown method "%s"', method);
    end
end

function v = apply_bc(dvbc, rb, rc)
    v = zeros(1, numel(rb));
    for pair_idx = 1:numel(rb)
        % [content, border] ordering (Geisler-confirmed; matches s5 dbndbc training)
        v(pair_idx) = dvbc([rc(pair_idx), rb(pair_idx)]');
    end
    v(isnan(v)) = 0;
end

function x = nan_to_zero(x), x(isnan(x)) = 0; end

function copt = best_criterion(near_vals, far_vals, hi_fallback)
% Criterion maximizing same/different accuracy (near = same, far = different).
    lo = mean(far_vals);  hi = mean(near_vals);
    if isnan(hi), hi = lo + hi_fallback; end
    step = (hi - lo) / 100;
    if step <= 0, copt = lo; return; end
    copt = lo;  best = 0;
    for crit = lo:step:hi
        pc = (sum(near_vals >= crit) + sum(far_vals < crit)) / (numel(near_vals) + numel(far_vals));
        if pc > best, best = pc; copt = crit; end
    end
end
