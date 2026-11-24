function ari = adjusted_rand_index(true_map, est_map)
% ADJUSTED_RAND_INDEX  Chance-corrected agreement between two segmentations.
%   ari = segmentation.adjusted_rand_index(true_map, est_map)
%
%   Over all pairs of patches, the Rand index is the fraction of pairs on which
%   the two maps agree (both "same region" or both "different region"). The
%   adjusted index rescales it so a perfect match scores 1 and a segmentation no
%   better than chance scores 0 (it can go slightly negative). Partial errors
%   cost partial credit: one wrong patch lowers it a little, merging two regions
%   lowers it more. Every label, including 0, counts as a region.
%
%   Inputs
%     true_map  integer region labels (e.g. the GTR map, patches x patches).
%     est_map   integer segment labels, same size (e.g. seg.est_map).
%   Output
%     ari  adjusted Rand index (Hubert & Arabie, 1985).
%
% See also SEGMENTATION.COUNT_CORRECT_REGIONS, SEGMENT_IMAGE
    [~, ~, t] = unique(true_map(:));
    [~, ~, e] = unique(est_map(:));
    n = numel(t);
    counts = accumarray([t, e], 1);                 % contingency table
    pairs = @(x) sum(x(:) .* (x(:) - 1) / 2);      % number of same-label pairs

    agree_same = pairs(counts);
    true_same = pairs(sum(counts, 2));
    est_same = pairs(sum(counts, 1));
    expected = true_same * est_same / (n * (n - 1) / 2);
    best = (true_same + est_same) / 2;

    if best == expected            % both maps one region, or both all singletons
        ari = double(isequal(true_same, est_same));
    else
        ari = (agree_same - expected) / (best - expected);
    end
end
