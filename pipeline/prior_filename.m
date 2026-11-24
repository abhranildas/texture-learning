function f = prior_filename(cfg, ecc)
% PRIOR_FILENAME  Name of the per-eccentricity natural-priors file.
%   f = prior_filename(cfg, ecc)
%
%   The single source for the priors filename, used by s23_learn_priors_and_pairs
%   (save), s4_optimize_bins and demo/plot_stage2 (load). Priors are
%   eccentricity-dependent (ecc applies blur + downsampling), so each ecc has its
%   own file. The "_otf" tag marks optics-applied priors, "_pcagrad" priors
%   learned with the multi-scale gradient PCA features (cfg.features.file_tag).
%
%   Inputs
%     cfg - config struct (uses cfg.optics.file_tag).
%     ecc - eccentricity downsample factor (1, 2, 4, 8).
%
%   Output
%     f - filename (no path), e.g. "priors_abr_mo13_mo23_cs33_otf_ecc_1.mat".
%
%   See also DECISION_BOUNDS_FILENAME, S23_LEARN_PRIORS_AND_PAIRS, S4_OPTIMIZE_BINS

    f = sprintf('priors_abr_mo13_mo23_cs33%s%s_ecc_%d.mat', cfg.optics.file_tag, ...
        cfg.features.file_tag, ecc);
end
