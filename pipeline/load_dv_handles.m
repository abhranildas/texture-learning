function dv = load_dv_handles(cfg, ecc, load_bc)
% LOAD_DV_HANDLES  Load trained decision-variable function handles for an eccentricity.
%   dv = load_dv_handles(cfg, ecc, load_bc)
%
%   Builds function handles for the trained decision variables from the shipped
%   decision-bounds artifact for cfg.features.color/ecc (see
%   decision_bounds_filename; via quad2fun): dv.h (spot), dv.e (edge), dv.c
%   (content), dv.b (border). If load_bc is true, also dv.bc (border+content).
%   Shared by pipeline stages s6 and s7.
%
%   dv.h has the SAME signature (a function of the full spot-LLR column, in
%   cfg.features.spot_dims order) whether or not colour is on: if the artifact has
%   dbnd.ha/hb (trained with colour, see s5_train_decision_vars), dv.h composes the
%   achromatic and chromatic sub-DVs before applying the combining bound dbnd.h;
%   otherwise dbnd.h is applied directly. So no caller downstream of dv.h needs to
%   know which mode trained it.
%
%   Requires the IntClassNorm add-on (quad2fun) and the stage-5 artifacts in
%   cfg.paths.models. Run `setup` first.
%
%   Inputs
%     cfg     - config struct (uses cfg.paths.models, cfg.features.spot_dims).
%     ecc     - eccentricity downsample factor (1, 2, 4, 8).
%     load_bc - true to also build dv.bc (border+content); default false.
%
%   Output
%     dv - struct of function handles: dv.h, dv.e, dv.c, dv.b (and dv.bc if
%          load_bc), each a decision variable mapping a feature-response row
%          vector to a scalar log-likelihood-ratio DV.
%
%   See also DECISION_BOUNDS_FILENAME, S5_TRAIN_DECISION_VARS

    if nargin < 3 || isempty(load_bc), load_bc = false; end
    S = load(fullfile(cfg.paths.models, decision_bounds_filename(cfg, ecc)), 'dbnd');
    dbnd = S.dbnd;

    if isfield(dbnd, 'spot_dims')
        trained_spot_dims = dbnd.spot_dims;
    else
        trained_spot_dims = cfg.features.spot_achr_dims;   % legacy artifact predates this field
    end
    if ~isequal(trained_spot_dims, cfg.features.spot_dims)
        error('load_dv_handles:spotDimMismatch', ...
            'Trained bounds use spot dims %s but config asks for %s -- retrain stage 5.', ...
            mat2str(trained_spot_dims), mat2str(cfg.features.spot_dims));
    end

    if isfield(dbnd, 'ha')
        dvha = quad2fun(dbnd.ha, 0);
        dvhb = quad2fun(dbnd.hb, 0);
        dvh2 = quad2fun(dbnd.h,  0);
        n_achr = dbnd.spot_achr_n;
        dv.h = @(x) dvh2([dvha(x(1:n_achr)); dvhb(x(n_achr+1:end))]);
    else
        dv.h = quad2fun(dbnd.h, 0);
    end
    if isfield(dbnd, 'edge_dims')
        trained_edge_dims = dbnd.edge_dims;
    else
        trained_edge_dims = [5 9 10 11];      % artifact predates this field
    end
    if ~isequal(trained_edge_dims, cfg.features.edge_dv_dims)
        error('load_dv_handles:edgeDimMismatch', ...
            'Trained bounds use edge dims %s but config asks for %s -- retrain stage 5.', ...
            mat2str(trained_edge_dims), mat2str(cfg.features.edge_dv_dims));
    end
    dv.e = edge_dv_handle(dbnd);             % composite with the multi-scale gradient bound if trained
    dv.c = quad2fun(dbnd.c, 0);
    dv.b = quad2fun(dbnd.b, 0);

    if load_bc
        dv.bc = quad2fun(dbnd.bc, 0);
    end
end
