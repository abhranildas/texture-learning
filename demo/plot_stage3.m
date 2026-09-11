function plot_stage3(cfg, ecc)
% PLOT_STAGE3  Show example near ("same") and far ("different") patch pairs.
%   plot_stage3(cfg, ecc)
%
%   Full mode shows the built pairs (patch_pairs_ecc<ecc>.mat) if they match the
%   requested cfg.features.color; otherwise (quick mode, or a stale file left over
%   from a run in the other colour mode) it samples a few fresh via sample_demo_pairs
%   (same optics/domain/distance rules as Stage 3). Both branches yield pair tensors
%   (achromatic-only or ABR colour, depending on cfg.features.color), displayed
%   identically.
%
% Inputs
%   cfg  - config struct.
%   ecc  - eccentricity divisor, used only to name the built-pairs file.
% Output
%   none (draws the figure)
%
% See also SAMPLE_DEMO_PAIRS, PATCH_TO_RGB_DISPLAY, PLOT_STAGE6_PAIRS
    out_path = fullfile(cfg.paths.stimuli, sprintf('patch_pairs_ecc%d.mat', ecc));
    n_show = 5;

    pair_data_ok = false;
    if isfile(out_path)
        pair_data = load(out_path, 'ptchn', 'ptchf', 'color');
        pair_data_ok = isfield(pair_data, 'color') && isequal(pair_data.color, cfg.features.color);
    end
    if pair_data_ok
        ptchn = pair_data.ptchn;  ptchf = pair_data.ptchf;
    else
        [ptchn, ptchf] = sample_demo_pairs(cfg, ecc);
        if isempty(ptchn)
            fprintf('No natural images found; skipping Stage 3.\n');
            return;
        end
    end

    n_show = min(n_show, size(ptchn, 4));
    patch_size = size(ptchn, 1);

    figure('Name', 'Stage 3: Near/Far Pairs', 'Position', [200 200 400 800]);
    for i = 1:n_show
        subplot(n_show, 2, (i-1)*2 + 1);
        local_show_pair(cfg, ptchn(:, 1:patch_size, :, i), ...
            ptchn(:, patch_size+1:2*patch_size, :, i));
        if i == 1, title('Near Pairs'); end

        subplot(n_show, 2, (i-1)*2 + 2);
        local_show_pair(cfg, ptchf(:, 1:patch_size, :, i), ...
            ptchf(:, patch_size+1:2*patch_size, :, i));
        if i == 1, title('Far Pairs'); end
    end
end

% ------------------------------------------------------------------------------
function local_show_pair(cfg, a, b)
% Display a patch pair side by side (2-px gap), normalized/gamma-mapped for
% display JOINTLY (patch_to_rgb_display sees both halves at once) so the two
% halves stay comparable in brightness, not each independently rescaled. Patches
% are ABR-space (or achromatic-only) -- see patch_to_rgb_display.
    patch_size = size(a, 2);
    rgb = patch_to_rgb_display(cfg, cat(2, a, b), 'abr');
    gap = zeros(size(rgb, 1), 2, 3);
    image([rgb(:, 1:patch_size, :), gap, rgb(:, patch_size+1:end, :)]); axis image off;
end
