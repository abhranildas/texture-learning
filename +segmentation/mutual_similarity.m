function rho = mutual_similarity(content_sim, bill_compat)
% MUTUAL_SIMILARITY  Cosine similarity between patches' content-similarity vectors.
%   rho = segmentation.mutual_similarity(content_sim)
%   rho = segmentation.mutual_similarity(content_sim, bill_compat)
%
%   The paper's mutual similarity (u_ij): for each patch pair (i,j), the cosine
%   similarity between patch i's vector of content similarities to all other
%   patches and patch j's vector (both excluding i and j). Intuitively, two
%   patches are more likely the same texture if they are similar to the same set
%   of other patches. (Was the inline rho loop in the self_sup_*/tex_grp scripts.)
%
%   bill_compat (TEMPORARY, cfg.bill_compat) reproduces a side effect of Bill's loop
%   (ss_segm.m:208-228): his vectors vi, vj are allocated with N-2 entries, grow to
%   N-1 on the first i == j pass, and never shrink. So every later i ~= j pair also
%   sums one stale extra term, the last entries written by the most recent i == j
%   pass. Verified against Bill's own rho to 1e-15.
%
%   Inputs
%     content_sim - [N x N] symmetric content-similarity matrix
%                   (segmentation.content_similarity_matrix).
%     bill_compat - logical, default false (see above).
%
%   Output
%     rho - [N x N] mutual-similarity matrix.
%
%   See also SEGMENTATION.CONTENT_SIMILARITY_MATRIX, SEGMENTATION.GROUP_PATCHES

    if nargin < 2 || isempty(bill_compat), bill_compat = false; end
    n = size(content_sim, 1);
    rho = zeros(n, n);
    stale = [0 0];                         % bill_compat: extra [vi vj] term
    for i = 1:n
        for j = 1:n
            keep = true(n, 1);
            keep(i) = false;
            keep(j) = false;
            vi = content_sim(keep, j);        % similarities to patch j (excluding i,j)
            vj = content_sim(i, keep).';       % similarities to patch i (excluding i,j)
            if bill_compat
                if i == j
                    stale = [vi(end), vj(end)];
                else
                    vi(end+1) = stale(1);  %#ok<AGROW>
                    vj(end+1) = stale(2);  %#ok<AGROW>
                end
            end
            rho(i, j) = sum(vi .* vj) / sqrt(sum(vi.^2) * sum(vj.^2));
        end
    end
end
