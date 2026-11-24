function dv = load_dv_handles(cfg, ecc, load_bc)
% LOAD_DV_HANDLES  Load trained decision-variable function handles for an eccentricity.
%   dv = load_dv_handles(cfg, ecc, load_bc)
%
%   Builds function handles for the trained decision variables from the shipped
%   decision-bounds artifact for cfg.features.color/ecc (see
%   decision_bounds_filename; via quad2fun): dv.spot, dv.edge, dv.content,
%   dv.border, and, if load_bc is true, dv.border_content (paper ln L_h, ln L_e,
%   ln L_c, E_b, ln L_bc). Each handle carries the name of the bound it applies.
%   Shared by pipeline stages s6 and s7.
%
%   dv.spot has the SAME signature (a function of the full spot-LLR column, in
%   cfg.features.spot_dims order) whether or not colour is on: if the artifact has
%   decision_bounds.spot_achr/.spot_chrom (trained with colour, see
%   s5_train_decision_vars), dv.spot composes the achromatic and chromatic sub-DVs
%   before applying the combining bound decision_bounds.spot; otherwise
%   decision_bounds.spot is applied directly. So no caller downstream of dv.spot
%   needs to know which mode trained it.
%
%   Requires the IntClassNorm add-on (quad2fun) and the stage-5 artifacts in
%   cfg.paths.models. Run `setup` first.
%
%   Inputs
%     cfg     - config struct (uses cfg.paths.models, cfg.features.spot_dims).
%     ecc     - eccentricity downsample factor (1, 2, 4, 8).
%     load_bc - true to also build dv.border_content (border+content); default false.
%
%   Output
%     dv - struct of function handles: .spot, .edge, .content, .border (and
%          .border_content if load_bc), each a decision variable mapping a
%          feature-response column vector to a scalar log-likelihood-ratio DV
%          (> 0 favours "same"). Bill's dbndh, dbnde, dbndc, dbndb, dbndbc.
%
%   See also DECISION_BOUNDS_FILENAME, S5_TRAIN_DECISION_VARS

    if nargin < 3 || isempty(load_bc), load_bc = false; end
    S = load(fullfile(cfg.paths.models, decision_bounds_filename(cfg, ecc)), 'decision_bounds');
    decision_bounds = S.decision_bounds;

    if isfield(decision_bounds, 'spot_dims')
        trained_spot_dims = decision_bounds.spot_dims;
    else
        trained_spot_dims = cfg.features.spot_achr_dims;   % legacy artifact predates this field
    end
    if ~isequal(trained_spot_dims, cfg.features.spot_dims)
        error('load_dv_handles:spotDimMismatch', ...
            'Trained bounds use spot dims %s but config asks for %s -- retrain stage 5.', ...
            mat2str(trained_spot_dims), mat2str(cfg.features.spot_dims));
    end

    if isfield(decision_bounds, 'spot_achr')
        spot_achr_dv = quad2fun(decision_bounds.spot_achr, 0);
        spot_chrom_dv = quad2fun(decision_bounds.spot_chrom, 0);
        spot_combine_dv = quad2fun(decision_bounds.spot,  0);
        n_achr = decision_bounds.n_spot_achr;
        dv.spot = @(x) spot_combine_dv([spot_achr_dv(x(1:n_achr)); ...
            spot_chrom_dv(x(n_achr+1:end))]);
    else
        dv.spot = quad2fun(decision_bounds.spot, 0);
    end
    if isfield(decision_bounds, 'edge_dims')
        trained_edge_dims = decision_bounds.edge_dims;
    else
        trained_edge_dims = [5 9 10 11];      % artifact predates this field
    end
    if ~isequal(trained_edge_dims, cfg.features.edge_dv_dims)
        error('load_dv_handles:edgeDimMismatch', ...
            'Trained bounds use edge dims %s but config asks for %s -- retrain stage 5.', ...
            mat2str(trained_edge_dims), mat2str(cfg.features.edge_dv_dims));
    end
    dv.edge = edge_dv_handle(decision_bounds);  % composite with the multi-scale gradient bound if trained
    dv.content = quad2fun(decision_bounds.content, 0);
    dv.border = quad2fun(decision_bounds.border, 0);

    if load_bc
        dv.border_content = quad2fun(decision_bounds.border_content, 0);
    end
end
