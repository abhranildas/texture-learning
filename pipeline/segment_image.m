function seg = segment_image(cfg, img, map, opts)
% SEGMENT_IMAGE  Segment one image into texture regions.
%   seg = segment_image(cfg, img)              % photo: image file, or LMS array
%   seg = segment_image(cfg, img, map)         % GTR image, scored against its true map
%   seg = segment_image(cfg, rgb, [], rgb=true)
%   segment_image(...)                         % no output: show image and segmentation
%
%   Learns this image's similarities and grouping criterion self-supervised (from
%   proximity alone), then groups its patches into regions at the fixed parameters
%   cfg.segment (chosen by s7_segment_gtr).
%
%   Inputs
%     cfg   config struct (config.m).
%     img   one of:
%             - an LMS array, as from make_gtr_image (used as is);
%             - an image file path: read as RGB, then eye optics (if
%               cfg.optics.apply_test), RGB->LMS and downsampling to opts.ecc.
%               8-bit files are taken as gamma-compressed and linearized; 16-bit
%               files as the lab's linear 14-bit camera images (scaled by
%               255/cfg.natural.max_val);
%             - an RGB array with rgb=true: linear RGB (0-255), processed as a file.
%     map   true region-label map, patches x patches (as from make_gtr_image);
%           default [] (none). It is used only to score the result, never to learn,
%           and sets the patch grid. Without it the image is cropped (top-left) to
%           whole patches of cfg.patch.size/ecc pixels.
%   Name-value options
%     rgb     img is an RGB array (default false: an array is taken as LMS).
%     ecc     eccentricity downsample factor (default 1). Sets the patch size when
%             there is no map, and the downsampling of an RGB input.
%     params  fixed grouping parameters (default cfg.segment).
%
%   Output
%     seg  struct:
%            .emap   estimated region map (patches x patches)
%            .ngrps  number of regions found
%            .nrg    regions exactly matching a true region (NaN without map)
%            .pcmx   same/different accuracy on patch pairs at the learned
%                    criterion (NaN without map)
%            .lms    the LMS image that was segmented (after any cropping)
%            .stages intermediate results (segmentation.learn_image_similarity)
%
%   Example
%     [img, map] = make_gtr_image(config(), 3);
%     segment_image(config(), img, map)
%
%   See also MAKE_GTR_IMAGE, SEGMENTATION.SEGMENT_LMS, S7_SEGMENT_GTR

    arguments
        cfg struct
        img
        map = []
        opts.rgb (1,1) logical = false
        opts.ecc (1,1) double {mustBePositive} = 1
        opts.params = []
    end

    % --- to LMS ---
    if ischar(img) || isstring(img)
        raw = imread(img);
        if isa(raw, 'uint16')
            cimg = double(raw) * 255 / cfg.natural.max_val;     % lab's linear camera images
        else
            cimg = vislab.lib.gamma_expand(double(raw));         % gamma-compressed 8-bit
        end
        if size(cimg, 3) == 1, cimg = repmat(cimg, 1, 1, 3); end
        lms = rgb_to_lms(cfg, cimg, opts.ecc);
    elseif opts.rgb
        lms = rgb_to_lms(cfg, double(img), opts.ecc);
    else
        lms = img;
    end

    % --- patch grid ---
    scored = ~isempty(map);
    if scored
        patch_size = size(lms, 1) / size(map, 1);
        if patch_size ~= round(patch_size) || size(lms, 2) ~= patch_size * size(map, 2)
            error('segment_image:gridMismatch', ...
                'Image (%dx%d px) is not a whole number of patches of the %dx%d map.', ...
                size(lms, 1), size(lms, 2), size(map, 1), size(map, 2));
        end
    else
        patch_size = cfg.patch.size / opts.ecc;
        n_rows = floor(size(lms, 1) / patch_size);
        n_cols = floor(size(lms, 2) / patch_size);
        if n_rows < 2 || n_cols < 2
            error('segment_image:tooSmall', ...
                'Image (%dx%d px) is smaller than 2x2 patches of %d px.', ...
                size(lms, 1), size(lms, 2), patch_size);
        end
        lms = lms(1:n_rows*patch_size, 1:n_cols*patch_size, :);
        map = zeros(n_rows, n_cols);
    end

    % --- segment ---
    seg = segmentation.segment_lms(cfg, lms, map, opts.params);
    if ~scored
        seg.nrg = NaN;
        seg.pcmx = NaN;
    end
    seg.lms = lms;

    if nargout == 0
        show(cfg, seg, map, scored);
        clear seg
    end
end

function lms = rgb_to_lms(cfg, cimg, ecc)
% Linear RGB -> eye optics (if cfg.optics.apply_test) -> LMS -> downsample to ecc.
    if cfg.optics.apply_test
        cimg = vislab.lib.otf_filter(cimg, cfg.optics.ppd, ...
            cfg.optics.pupil_diameter, cfg.optics.wavelength);
    end
    lms = vislab.lib.downsample(vislab.lib.rgb2lms(cimg), ecc);
end

function show(cfg, seg, map, scored)
% Image with its true regions (if known) beside the model's segmentation.
    rgb = patch_to_rgb_display(cfg, seg.lms, 'lms');
    sz = [size(seg.lms, 1), size(seg.lms, 2)];
    figure('Name', 'Segmentation', 'Position', [400 200 1000 520]);
    subplot(1, 2, 1);
    image(rgb); axis image off; hold on;
    if scored
        overlay_region_boundaries(imresize(map, sz, 'nearest'));
        title(sprintf('True regions (%d)', max(map(:))));
    else
        title('Image');
    end
    subplot(1, 2, 2);
    image(rgb); axis image off; hold on;
    overlay_region_boundaries(imresize(seg.emap, sz, 'nearest'));
    if scored
        title(sprintf('Segmentation: %d of %d regions exactly right', seg.nrg, max(map(:))));
    else
        title(sprintf('Segmentation (%d regions)', seg.ngrps));
    end
    drawnow;
end
