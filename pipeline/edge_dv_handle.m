function dve = edge_dv_handle(dbnd)
% EDGE_DV_HANDLE  Edge (gradient) decision-variable handle from the trained bounds.
%   dve = edge_dv_handle(dbnd)
%
%   Without the gradient-PCA features this is quad2fun(dbnd.e). With them
%   (dbnd.pg present, cfg.features.pca_gradient), the first dbnd.ms_n inputs are
%   the 1 px edge mag and PC gradient mag LLRs: they are merged by the multi-scale
%   gradient bound dbnd.pg, and its DV goes into dbnd.e together with the remaining
%   (bar) LLRs. Either way dve takes the full column of edge LLRs, in
%   cfg.features.edge_dv_dims order. Shared by s5_train_decision_vars and
%   load_dv_handles.
%
% Input
%   dbnd  struct of trained bounds (see s5_train_decision_vars).
% Output
%   dve   function handle: column of edge LLRs -> edge DV.
%
% See also S5_TRAIN_DECISION_VARS, LOAD_DV_HANDLES
    dve_last = quad2fun(dbnd.e, 0);
    if ~isfield(dbnd, 'pg')
        dve = dve_last;
        return;
    end
    dvpg = quad2fun(dbnd.pg, 0);
    n = dbnd.ms_n;
    dve = @(x) dve_last([dvpg(x(1:n)); x(n+1:end)]);
end
