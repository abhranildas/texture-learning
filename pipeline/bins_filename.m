function f = bins_filename(cfg)
% BINS_FILENAME  Name of the consolidated adaptive-histogram bin-bounds file.
%   f = bins_filename(cfg)
%
%   The single source for the bins filename, used by s4_optimize_bins (save), every
%   vislab.nat_stat_bayes.load_bin_bounds caller (load) and run_demo (existence
%   check). "AHEO" marks bins trained with the optics on, "AHE" without; a
%   "_pcagrad" tag (cfg.features.file_tag) marks the gradient-PCA model. Under
%   cfg.bill_compat the name gets a "_bill" tag: Bill's imported bins
%   (tools/import_bill_model), kept apart from this repo's trained ones.
%
%   Input
%     cfg - config struct (uses cfg.optics.apply, cfg.bill_compat).
%   Output
%     f - filename (no path), e.g. "AHEO_bins.mat".
%
%   See also DECISION_BOUNDS_FILENAME, S4_OPTIMIZE_BINS

    if cfg.optics.apply, f = 'AHEO_bins'; else, f = 'AHE_bins'; end
    f = [f cfg.features.file_tag];
    if cfg.bill_compat, f = [f '_bill']; end
    f = [f '.mat'];
end
