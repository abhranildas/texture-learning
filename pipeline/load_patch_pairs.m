function [pairs, matches] = load_patch_pairs(cfg, ecc)
% LOAD_PATCH_PAIRS  Load the near/far training pairs saved by s23_learn_priors_and_pairs.
%   pairs = load_patch_pairs(cfg, ecc)
%   [pairs, matches] = load_patch_pairs(cfg, ecc)
%
%   The pairs are built for one colour mode and one optics setting, which s23
%   saves with them. With one output, an error is raised if they do not match
%   cfg (so s4/s5 cannot train on stale pairs). With two, nothing is raised:
%   matches says whether they can be used (false also when the file is missing).
%
%   Inputs
%     cfg - config struct (uses cfg.paths.stimuli, cfg.features.color, cfg.optics.apply).
%     ecc - eccentricity downsample factor (1, 2, 4, 8).
%   Outputs
%     pairs   - struct as saved, [] if the file is missing:
%                 .ptchn  near pairs, [patch_size x 2*patch_size x channels x pcnt]:
%                         the pair's two patches side by side, normalized and
%                         LMS->ABR rotated (1 channel achromatic, 3 with colour)
%                 .ptchf  far pairs, same layout
%                 .pcnt   number of pairs of each kind
%                 .color, .optics  the settings they were built with
%               (Terse names kept on purpose: the ~1 GB file is not rewritten.)
%     matches - true if the pairs were built with cfg's colour and optics settings.
%
%   See also S23_LEARN_PRIORS_AND_PAIRS, S4_OPTIMIZE_BINS, S5_TRAIN_DECISION_VARS

    file = fullfile(cfg.paths.stimuli, sprintf('patch_pairs_ecc%d.mat', ecc));
    pairs = [];
    matches = isfile(file);
    if matches
        pairs = load(file);
        matches = isfield(pairs, 'color') && isequal(pairs.color, cfg.features.color) ...
               && isfield(pairs, 'optics') && isequal(pairs.optics, cfg.optics.apply);
    end
    if nargout < 2 && ~matches
        error('load_patch_pairs:modeMismatch', ...
            ['%s is missing or was not built with colour = %d, optics = %d ' ...
             '-- rerun s23_learn_priors_and_pairs.'], file, cfg.features.color, cfg.optics.apply);
    end
end
