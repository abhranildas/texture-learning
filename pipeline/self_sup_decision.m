function [bc_near, bc_far] = self_sup_decision(method, R, dv)
% SELF_SUP_DECISION  Per-image self-supervised combined decision variable.
%   [bc_near, bc_far] = self_sup_decision(method, R, dv)
%
%   Returns the combined border+content decision variable for the near (bc_near)
%   and far (bc_far) patch pairs in R (from neighbor_far_responses), after the
%   per-image self-supervised step. Shared by pipeline stages s6 and s7.
%
%   method:
%     'bc'         - refit the border+content bound on THIS image (classify_normals),
%                    treating near pairs as "same" and far pairs as "different".
%     'bc_shft'    - load the trained bc bound; learn a scalar shift of the bc DV.
%     'bc_noshift' - load the trained bc bound; apply it with no shift.
%     'c_shft'     - load the trained bc bound; learn a scalar shift of the content DV.
%
%   'bc' requires the IntClassNorm add-on (classify_normals); the others require
%   the trained bc bound handle dv.border_content (see load_dv_handles with
%   load_bc=true).
%
%   Inputs
%     method - one of 'bc', 'bc_shft', 'bc_noshift', 'c_shft' (see above).
%     R      - struct of per-pair content/border responses + same/different ground
%              truth (from neighbor_far_responses).
%     dv     - struct of trained DV function handles (from load_dv_handles);
%              dv.border_content is required unless method is 'bc'.
%
%   Outputs
%     bc_near, bc_far - 1 x n_pairs border+content DV of each near / far pair, a
%                       log-likelihood ratio (> 0 favours same; Bill's qbs, qbd).
%
%   See also NEIGHBOR_FAR_RESPONSES, LOAD_DV_HANDLES, NEARFAR_SCORE_GRID,
%   S6_SELFSUP_DISCRIMINATION, S7_SEGMENT_GTR

    n_pairs = R.n_pairs;
    bc_near = zeros(1, n_pairs);  bc_far = zeros(1, n_pairs);
    switch method
        case 'bc'                                   % refit the bc bound on this image
            bd = classify_normals([R.content_near', R.border_near'], ...
                [R.content_far', R.border_far'], 'input_type', 'samp', 'plotmode', 0);
            bc_dv = quad2fun(bd.samp_opt_bd, 0);
            for pair_idx = 1:n_pairs
                bc_near(pair_idx) = bc_dv([R.content_near(pair_idx), R.border_near(pair_idx)]');
                bc_far(pair_idx) = bc_dv([R.content_far(pair_idx), R.border_far(pair_idx)]');
            end
        case 'bc_shft'                              % shift the pre-trained bc DV
            % shift: the criterion best separating near from far (Bill's copt)
            unshifted_near = apply_bc(dv.border_content, R.border_near, R.content_near);
            unshifted_far = apply_bc(dv.border_content, R.border_far, R.content_far);
            shift = best_criterion(unshifted_near, unshifted_far, 5);
            bc_near = unshifted_near - shift;
            bc_far = unshifted_far - shift;
        case 'bc_noshift'                             % pre-trained bc DV, no shift
            bc_near = apply_bc(dv.border_content, R.border_near, R.content_near);
            bc_far = apply_bc(dv.border_content, R.border_far, R.content_far);
        case 'c_shft'                                 % shift the content DV, then bc bound
            content_near = nan_to_zero(R.content_near);  content_far = nan_to_zero(R.content_far);
            border_near = nan_to_zero(R.border_near);  border_far = nan_to_zero(R.border_far);
            shift = best_criterion(content_near, content_far, 1);
            for pair_idx = 1:n_pairs
                bc_near(pair_idx) = dv.border_content( ...
                    [content_near(pair_idx) - shift, border_near(pair_idx)]');
                bc_far(pair_idx) = dv.border_content( ...
                    [content_far(pair_idx) - shift, border_far(pair_idx)]');
            end
        otherwise
            error('self_sup_decision:badMethod', 'unknown method "%s"', method);
    end
end

function v = apply_bc(bc_dv, border_dv, content_dv)
    v = zeros(1, numel(border_dv));
    for pair_idx = 1:numel(border_dv)
        % [content, border] ordering (Geisler-confirmed; matches s5's border_content training)
        v(pair_idx) = bc_dv([content_dv(pair_idx), border_dv(pair_idx)]');
    end
    v(isnan(v)) = 0;
end

function x = nan_to_zero(x), x(isnan(x)) = 0; end

function shift = best_criterion(near_vals, far_vals, hi_fallback)
% Criterion maximizing same/different accuracy (near = same, far = different).
    lo = mean(far_vals);  hi = mean(near_vals);
    if isnan(hi), hi = lo + hi_fallback; end
    step = (hi - lo) / 100;
    if step <= 0, shift = lo; return; end
    shift = lo;  best = 0;
    for crit = lo:step:hi
        accuracy = (sum(near_vals >= crit) + sum(far_vals < crit)) / ...
            (numel(near_vals) + numel(far_vals));
        if accuracy > best, best = accuracy; shift = crit; end
    end
end
