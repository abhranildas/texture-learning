function ppd = otf_ppd(cfg, n_pixels)
% OTF_PPD  Pixels per degree to pass to vislab.lib.otf_filter for an image n_pixels wide.
%   ppd = otf_ppd(cfg, n_pixels)
%
%   Normally cfg.optics.ppd. Under the TEMPORARY cfg.bill_compat switch it is
%   n_pixels / cfg.optics.ppd. otf_filter computes the frequency of the k-th FFT
%   bin as k*ppd/N cycles/deg, so this substitution makes it compute k/cfg.optics.ppd,
%   which is exactly what Bill's aply_otf.m does (for a square image).
%
%   Inputs
%     cfg       config struct (uses cfg.optics.ppd, cfg.bill_compat).
%     n_pixels  width (= height) in pixels of the image about to be filtered.
%   Output
%     ppd  value for otf_filter's ppd argument.
%
% See also CONFIG, LOAD_TEXTURE_IMAGES

    if cfg.bill_compat
        ppd = n_pixels / cfg.optics.ppd;
    else
        ppd = cfg.optics.ppd;
    end
end
