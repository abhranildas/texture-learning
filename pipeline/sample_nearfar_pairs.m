function [ptchn, ptchf] = sample_nearfar_pairs(img, n_samples, patch_size, cfg)
% SAMPLE_NEARFAR_PAIRS  Sample n_samples reference patches from one LMS image and build
%   near/far pairs (Stage 23): per reference, two NEAR pairs (right and lower
%   neighbours) and two FAR pairs (patches beyond a distance criterion). This is
%   the single definition of that per-image sampling, shared by
%   s23_learn_priors_and_pairs and demo/sample_demo_pairs.
%
%   Inputs
%     img        - [H x W x 3] LMS image already at the target eccentricity.
%     n_samples  - number of reference patches to sample (each yields 2 near + 2 far).
%     patch_size - patch size at that eccentricity (cfg.patch.size / ecc), in pixels.
%     cfg        - config struct (see pair_patch_prep).
%
%   Outputs
%     ptchn, ptchf - pair tensors [patch_size x 2*patch_size x nch x (2*n_samples)];
%                    nch = 3 (full ABR) if cfg.features.color, else 1 (achromatic A
%                    channel only, cheaper). ptchn/ptchf are the .mat variable names
%                    saved by s23_learn_priors_and_pairs and must not be renamed.
%
%   Each half is normalized then rotated LMS->ABR by pair_patch_prep (all three
%   channels in colour mode, else only A -- keeps the pairs file and downstream
%   stages cheap when nobody asked for colour).
%
%   See also PAIR_PATCH_PREP, SAMPLE_ISOLATED_PATCHES, S23_LEARN_PRIORS_AND_PAIRS, PAIR_RESPONSES

    patch_size2 = 2 * patch_size;
    [szx, szy, ~] = size(img);
    dcrit = szx / 4;                 % far-pair distance criterion

    [prep, nch] = pair_patch_prep(cfg);

    ptchn = zeros(patch_size, patch_size2, nch, 2*n_samples);
    ptchf = zeros(patch_size, patch_size2, nch, 2*n_samples);
    pcnt = 0;
    for k = 1:n_samples
        x = randi(szx - patch_size2);
        y = randi(szy - patch_size2);
        a_ref = prep(img(x:x+patch_size-1, y:y+patch_size-1, :));

        % near/far RIGHT pairs (reference alongside a right-hand patch)
        pcnt = pcnt + 1;
        a_right = prep(img(x:x+patch_size-1, y+patch_size:y+patch_size2-1, :));
        ptchn(:, :, :, pcnt) = cat(2, a_ref, a_right);
        [xf, yf] = sample_far(szx, szy, patch_size2, x, y, dcrit);
        a_far = prep(img(xf:xf+patch_size-1, yf+patch_size:yf+patch_size2-1, :));
        ptchf(:, :, :, pcnt) = cat(2, a_ref, a_far);

        % near/far DOWN pairs (transposed so a vertical pair reads horizontally).
        % Transpose commutes with normalize+rotate, so transpose the prepared patch
        % directly; permute (not .') so this also works for the 3-channel colour case.
        a_ref_t = permute(a_ref, [2 1 3]);
        pcnt = pcnt + 1;
        a_below = permute(prep(img(x+patch_size:x+patch_size2-1, y:y+patch_size-1, :)), [2 1 3]);
        ptchn(:, :, :, pcnt) = cat(2, a_ref_t, a_below);
        [xf, yf] = sample_far(szx, szy, patch_size2, x, y, dcrit);
        a_far_below = permute( ...
            prep(img(xf:xf+patch_size-1, yf+patch_size:yf+patch_size2-1, :)), [2 1 3]);
        ptchf(:, :, :, pcnt) = cat(2, a_ref_t, a_far_below);
    end
end

% ------------------------------------------------------------------------------
function [xf, yf] = sample_far(szx, szy, patch_size2, x, y, dcrit)
% Sample a location farther than dcrit from (x,y) by rejection sampling.
    while true
        xf = randi(szx - patch_size2);
        yf = randi(szy - patch_size2);
        if sqrt((xf - x)^2 + (yf - y)^2) > dcrit
            return;
        end
    end
end
