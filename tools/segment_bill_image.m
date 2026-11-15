function out = segment_bill_image(cfg, img, map, level, params)
% SEGMENT_BILL_IMAGE  This repo's segmentation of one of Bill's stored RGB GTR images.
%   out = segment_bill_image(cfg, img, map, level)
%   out = segment_bill_image(cfg, img, map, level, params)
%
%   Takes a GTR image in the form Bill's ss_segm.m takes it (RGB, before optics)
%   through the repo's front end -- eye optics if cfg.optics.apply_test (units set by
%   otf_ppd, so cfg.bill_compat picks Bill's or the corrected filter), RGB->LMS,
%   downsampling -- then segmentation.segment_image.
%
%   Inputs
%     cfg     config struct.
%     img     [N x N x 3] RGB GTR image, as in Bill's gtrimg(:,:,:,k).
%     map     its ground-truth region map.
%     level   resolution scale-down level (Bill's flgs(1)).
%     params  fixed segmentation parameters (default cfg.segment).
%   Output
%     out  segmentation.segment_image output (.emap, .ngrps, .nrg, .pcmx, .stages)
%
% See also CHECK_BILL_SEGMENTATION, COMPARE_OTF_BILL, SEGMENTATION.SEGMENT_IMAGE

    if nargin < 5, params = []; end
    if cfg.optics.apply_test
        img = vislab.lib.otf_filter(img, otf_ppd(cfg, size(img, 1)), ...
            cfg.optics.pupil_diameter, cfg.optics.wavelength);
    end
    lms = vislab.lib.downsample(vislab.lib.rgb2lms(img), level);
    out = segmentation.segment_image(cfg, lms, map, params);
end
