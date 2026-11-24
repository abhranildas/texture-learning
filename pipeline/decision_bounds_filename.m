function f = decision_bounds_filename(cfg, ecc)
% DECISION_BOUNDS_FILENAME  Name of the per-eccentricity trained decision-bounds file.
%   f = decision_bounds_filename(cfg, ecc)
%
%   The single source for the decision-bounds filename, used by
%   s5_train_decision_vars (save), load_dv_handles and demo/plot_stage5_intermediate
%   (load), and run_demo (artifact-existence check / quick-mode file pick). Colour and
%   achromatic models cannot share one file -- dbnd.h means something different in
%   each mode (see docs/color-extension-plan.md) -- so each mode ships its own
%   artifact. Likewise for optics: the "_otf" tag (cfg.optics.file_tag) marks
%   bounds trained with the optics on, as in prior_filename, and "_pcagrad"
%   (cfg.features.file_tag) the gradient-PCA model. Under cfg.bill_compat
%   the name gets a "_bill" tag: Bill's imported bounds (tools/import_bill_model),
%   kept apart from this repo's trained ones.
%
%   Inputs
%     cfg - config struct (uses cfg.features.color, cfg.optics.file_tag, cfg.bill_compat).
%     ecc - eccentricity downsample factor (1, 2, 4, 8).
%
%   Output
%     f - filename (no path), e.g. "decision_bounds_ecc_1_color_otf.mat".
%
%   See also PRIOR_FILENAME, S5_TRAIN_DECISION_VARS, LOAD_DV_HANDLES

    if cfg.features.color, color_tag = '_color'; else, color_tag = ''; end
    if cfg.bill_compat, bill_tag = '_bill'; else, bill_tag = ''; end
    f = sprintf('decision_bounds_ecc_%d%s%s%s%s.mat', ecc, color_tag, cfg.optics.file_tag, ...
        cfg.features.file_tag, bill_tag);
end
