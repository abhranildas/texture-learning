function [accuracy, accuracy_same, accuracy_diff, accuracy_nearfar] = nearfar_score_grid( ...
        bc_near, bc_far, R, group_crit_vec, mutual_weight_vec)
% NEARFAR_SCORE_GRID  Discrimination accuracy over a grouping-criterion x weight grid.
%   [accuracy, accuracy_same, accuracy_diff, accuracy_nearfar] = nearfar_score_grid( ...
%       bc_near, bc_far, R, group_crit_vec, mutual_weight_vec)
%
%   For each grouping criterion group_crit (rows; paper gamma_l) and mutual-
%   similarity weight mutual_weight (cols; paper w_m), scores the combined decision
%   variable bc_near/bc_far + mutual_weight * mutual similarity against the near/far
%   and same/different ground truth in R. A pair is called "same" when that DV is
%   >= group_crit. Shared by pipeline stages s6 (averages the surfaces over trials)
%   and s7 (picks the peak-accuracy cell to set the per-image group_crit_best and
%   mutual_weight_best).
%
%   Inputs
%     bc_near, bc_far   - per-pair combined border+content decision variable, near
%                         and far (from self_sup_decision).
%     R                 - struct of per-pair mutual similarity + same/different
%                         ground truth (from neighbor_far_responses): .mutual_near,
%                         .mutual_far, .same_near, .same_far.
%     group_crit_vec    - grouping-criterion values to sweep (DV units).
%     mutual_weight_vec - mutual-similarity weight values to sweep (dimensionless).
%
%   Outputs (each n_crit x n_weight: numel(group_crit_vec) x numel(mutual_weight_vec);
%   Bill's names in brackets)
%     accuracy         - overall same/different proportion correct [pc].
%     accuracy_same    - proportion of "same" pairs called same [pcs].
%     accuracy_diff    - proportion of "different" pairs called different [pcd].
%     accuracy_nearfar - overall near/far proportion correct: near pairs called
%                        same, far pairs called different [pcnf].
%
%   See also SELF_SUP_DECISION, NEIGHBOR_FAR_RESPONSES, S6_SELFSUP_DISCRIMINATION,
%   S7_SEGMENT_GTR

    n_crit = numel(group_crit_vec);  n_weight = numel(mutual_weight_vec);
    [accuracy, accuracy_same, accuracy_diff, accuracy_nearfar] = deal(zeros(n_crit, n_weight));
    for crit_idx = 1:n_crit
        for weight_idx = 1:n_weight
            [accuracy(crit_idx, weight_idx), accuracy_same(crit_idx, weight_idx), ...
                accuracy_diff(crit_idx, weight_idx), accuracy_nearfar(crit_idx, weight_idx)] = ...
                score(bc_near, bc_far, R.mutual_near, R.mutual_far, R.same_near, R.same_far, ...
                group_crit_vec(crit_idx), mutual_weight_vec(weight_idx));
        end
    end
end

function [accuracy, accuracy_same, accuracy_diff, accuracy_nearfar] = score(bc_near, bc_far, ...
        mutual_near, mutual_far, same_near, same_far, group_crit, mutual_weight)
% Near-far and same-different accuracy for one (group_crit, mutual_weight) cell.
% n_same/n_diff count same/different pairs; *_ok count the correct calls.
    n_pairs = numel(bc_near);
    same_ok = 0; diff_ok = 0; n_same = 0; n_diff = 0; near_ok = 0; far_ok = 0;
    for pair_idx = 1:n_pairs
        near_dv = bc_near(pair_idx) + mutual_weight*mutual_near(pair_idx);
        far_dv  = bc_far(pair_idx) + mutual_weight*mutual_far(pair_idx);
        if same_near(pair_idx) == 1
            n_same = n_same + 1;
            if near_dv >= group_crit, same_ok = same_ok + 1; near_ok = near_ok + 1; end
        else
            n_diff = n_diff + 1;
            if near_dv <  group_crit, diff_ok = diff_ok + 1; else, near_ok = near_ok + 1; end
        end
        if same_far(pair_idx) == 1
            n_same = n_same + 1;
            if far_dv >= group_crit, same_ok = same_ok + 1; else, far_ok = far_ok + 1; end
        else
            n_diff = n_diff + 1;
            if far_dv <  group_crit, diff_ok = diff_ok + 1; far_ok = far_ok + 1; end
        end
    end
    accuracy         = (diff_ok + same_ok) / (2*n_pairs);
    accuracy_same    = same_ok / n_same;
    accuracy_diff    = diff_ok / n_diff;
    accuracy_nearfar = (near_ok + far_ok) / (2*n_pairs);
end
