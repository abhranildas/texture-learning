function seg_out = match_region_labels(seg_map, truth_map)
% MATCH_REGION_LABELS  Relabel segments so each takes the label of the true region
%   it overlaps most, for colour-consistent display beside the ground truth.
%   seg_out = match_region_labels(seg_map, truth_map)
%
%   Greedy: segment/region pairs are taken in order of overlap size, each true
%   label used at most once. Segments left unmatched get new labels after the
%   largest true label. 0 (unlabelled) stays 0. Display only; it changes no result.
%
% Inputs
%   seg_map    integer segment labels (0 = unlabelled).
%   truth_map  integer true region labels, same size (0 = background).
% Output
%   seg_out  seg_map relabelled as described.
%
% See also TINT_REGIONS, PLOT_STAGE7
    seg_ids = setdiff(unique(seg_map(:)), 0);
    tru_ids = setdiff(unique(truth_map(:)), 0);
    overlap = zeros(numel(seg_ids), numel(tru_ids));
    for i = 1:numel(seg_ids)
        for j = 1:numel(tru_ids)
            overlap(i, j) = nnz(seg_map == seg_ids(i) & truth_map == tru_ids(j));
        end
    end

    new_label = zeros(numel(seg_ids), 1);
    while any(overlap(:) > 0)
        [~, best] = max(overlap(:));
        [i, j] = ind2sub(size(overlap), best);
        new_label(i) = tru_ids(j);
        overlap(i, :) = 0;  overlap(:, j) = 0;
    end
    next = max([tru_ids; 0]);
    for i = find(new_label == 0)'
        next = next + 1;  new_label(i) = next;
    end

    seg_out = zeros(size(seg_map));
    for i = 1:numel(seg_ids)
        seg_out(seg_map == seg_ids(i)) = new_label(i);
    end
end
