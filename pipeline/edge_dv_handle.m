function edge_dv = edge_dv_handle(decision_bounds)
% EDGE_DV_HANDLE  Edge (gradient) decision-variable handle from the trained bounds.
%   edge_dv = edge_dv_handle(decision_bounds)
%
%   Without the gradient-PCA features this is quad2fun(decision_bounds.edge). With
%   them (decision_bounds.ms_grad present, cfg.features.pca_gradient), the first
%   decision_bounds.n_ms_grad inputs are the 1 px edge mag and PC gradient mag LLRs:
%   they are merged by the multi-scale gradient bound decision_bounds.ms_grad, and
%   its DV goes into decision_bounds.edge (final_dv below) together with the
%   remaining (bar) LLRs. Either way edge_dv takes the full column of edge LLRs, in
%   cfg.features.edge_dv_dims order. Shared by s5_train_decision_vars and
%   load_dv_handles.
%
% Input
%   decision_bounds  struct of trained bounds (see s5_train_decision_vars).
% Output
%   edge_dv   function handle: column of edge LLRs -> edge DV.
%
% See also S5_TRAIN_DECISION_VARS, LOAD_DV_HANDLES
    final_dv = quad2fun(decision_bounds.edge, 0);
    if ~isfield(decision_bounds, 'ms_grad')
        edge_dv = final_dv;
        return;
    end
    ms_grad_dv = quad2fun(decision_bounds.ms_grad, 0);
    n = decision_bounds.n_ms_grad;
    edge_dv = @(x) final_dv([ms_grad_dv(x(1:n)); x(n+1:end)]);
end
