function rgb = patch_to_rgb_display(cfg, patch, space)
% PATCH_TO_RGB_DISPLAY  Approximate a stored colour patch/image as a displayable
%   sRGB-like image, for demo figures only -- this is never used in the numeric
%   pipeline, and is not an exact inverse of the camera's clipped, lossy forward
%   transforms, just a visualization.
%
%   Inputs
%     cfg   - config struct (cfg.paths.data_root, cfg.optics.apply).
%     patch - [H x W x nch]: nch=1 achromatic-only (displayed as grayscale,
%             replicated to 3 channels so the output shape is always the same);
%             nch=3 colour, in the space given by SPACE.
%     space - 'abr' -- patch pairs (sample_nearfar_pairs/sample_texture_pairs store
%                       normalized, LMS->ABR-rotated pairs; see pair_responses.m).
%             'lms' -- GTR/natural images (make_gtr_image/source_to_lms store LMS,
%                       not yet rotated; see pipeline/neighbor_far_responses.m).
%             Ignored when nch=1.
%   Output
%     rgb - [H x W x 3] in [0,1], gamma-corrected for on-screen display.
%
% See also PLOT_STAGE3, PLOT_STAGE6_PAIRS, PLOT_STAGE7, PLOT_STAGE8_NATURAL
    if size(patch, 3) == 1
        gray_img = double(patch) - min(patch(:));
        gray_img = gray_img / max(eps, max(gray_img(:)));
        rgb = repmat(gray_img .^ (1/2.2), 1, 1, 3);
        return;
    end

    lms_data = load(fullfile(cfg.paths.data_root, 'cps_rgb2lms.mat'), 'lms');
    [h, w, ~] = size(patch);
    switch space
        case 'abr'
            if cfg.optics.apply, fname = 'cps_lms2abr_otf.mat'; else, fname = 'cps_lms2abr.mat'; end
            coeff_data = load(fullfile(cfg.paths.data_root, fname), 'coeff');
            lms_rows = reshape(patch, h*w, 3) / coeff_data.coeff;   % invert the LMS->ABR rotation
        case 'lms'
            lms_rows = reshape(patch, h*w, 3);
        otherwise
            error('patch_to_rgb_display:badSpace', 'space must be ''abr'' or ''lms''.');
    end
    rgb_rows = max(lms_rows / lms_data.lms, 0);   % invert the RGB->LMS calibration, clip negative
    rgb_lin  = reshape(rgb_rows, h, w, 3);
    rgb = (rgb_lin / max(eps, max(rgb_lin(:)))) .^ (1/2.2);
end
