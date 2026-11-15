function [prep, n_channels] = pair_patch_prep(cfg)
% PAIR_PATCH_PREP  How each half of a training/demo patch pair is prepared.
%   [prep, n_channels] = pair_patch_prep(cfg)
%
%   prep(patch) mean-normalizes an LMS patch (ptch_norm type 3) and rotates it
%   LMS->ABR with cfg.color_rotation, the rotation learned under the same optics
%   setting. In colour mode it keeps all three ABR channels; otherwise only the
%   achromatic A channel, which keeps the pair files and later stages cheap.
%   Shared by sample_nearfar_pairs and demo/sample_texture_pairs.
%
%   Inputs
%     cfg - config struct (uses cfg.norm, cfg.color_rotation, cfg.features.color).
%   Outputs
%     prep       - function handle, [H x W x 3] LMS patch -> [H x W x n_channels] ABR.
%     n_channels - 3 in colour mode, else 1.
%
%   See also SAMPLE_NEARFAR_PAIRS, SAMPLE_TEXTURE_PAIRS, S1_LEARN_COLOR_TRANSFORM

    if isempty(cfg.color_rotation)
        error('pair_patch_prep:noRotation', ...
            'No LMS->ABR rotation for this optics setting -- run s1_learn_color_transform first.');
    end
    if cfg.features.color, n_channels = 3; else, n_channels = 1; end
    rotation = cfg.color_rotation;
    target_mean = cfg.norm.target_mean;
    target_contrast = cfg.norm.target_contrast;
    prep = @(p) keep_channels(vislab.nat_stat_bayes.apply_color_rotation( ...
        vislab.lib.ptch_norm(p, target_mean, target_contrast, 3, 3), rotation), n_channels);
end

function abr = keep_channels(abr, n_channels)
    abr = abr(:, :, 1:n_channels);
end
