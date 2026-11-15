function out = segment_image(cfg, pimg, map, params, S)
% SEGMENT_IMAGE  Segment one GTR image into texture regions at fixed grouping parameters.
%   out = segmentation.segment_image(cfg, pimg, map)
%   out = segmentation.segment_image(cfg, pimg, map, params)
%   out = segmentation.segment_image(cfg, pimg, map, params, S)
%
%   Learns this image's similarities and self-supervised grouping criterion
%   (segmentation.learn_image_similarity), then groups its patches into regions
%   (segmentation.group_patches) at the fixed parameters in params. The
%   counterpart of Bill's ss_segm.m.
%
%   Inputs
%     cfg     config struct (config.m).
%     pimg    GTR image in LMS space, as from make_gtr_image.
%     map     [rows x cols] ground-truth region map. Sets the patch grid and scores
%             the result; pass zeros(rows, cols) when there is no ground truth.
%     params  struct (default cfg.segment):
%               .method        self-supervised rule ('bc', 'nc' or 'ncb')
%               .group_offset  added to the learned criterion gcopt (Bill's gl)
%               .confidence    confidence criterion (Bill's gcc)
%               .merge         region-merge criterion (Bill's gr)
%     S       optional learn_image_similarity output for this image and
%             params.method, so a sweep over the other parameters learns it once
%             (pimg is then unused).
%   Output
%     out  struct: .emap (estimated region map), .ngrps (number of regions),
%          .nrg (regions exactly matching a ground-truth region), .pcmx
%          (same/different accuracy at the learned settings), .stages (S)
%
% See also SEGMENTATION.LEARN_IMAGE_SIMILARITY, SEGMENTATION.GROUP_PATCHES,
%   SEGMENTATION.COUNT_CORRECT_REGIONS, S7_SEGMENT_GTR

    if nargin < 4 || isempty(params), params = cfg.segment; end
    if nargin < 5 || isempty(S)
        S = segmentation.learn_image_similarity(cfg, pimg, map, params.method);
    end
    [~, out.ngrps, out.emap] = segmentation.group_patches(S.mu, S.dst, ...
        S.gcopt + params.group_offset, params.confidence, S.patch_size, ...
        S.patch_x, S.patch_y, S.phiall, params.merge);
    out.nrg = segmentation.count_correct_regions(map, max(map(:)), out.emap, out.ngrps);
    out.pcmx = S.pcmx;
    out.stages = S;
end
