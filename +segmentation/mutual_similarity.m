function rho = mutual_similarity(content_sim)
% MUTUAL_SIMILARITY  Cosine similarity between patches' content-similarity vectors.
%   rho = segmentation.mutual_similarity(content_sim)
%
%   The paper's mutual similarity (u_ij): for each patch pair (i,j), the cosine
%   similarity between patch i's vector of content similarities to all other
%   patches and patch j's vector (both excluding i and j). Intuitively, two
%   patches are more likely the same texture if they are similar to the same set
%   of other patches. (Was the inline rho loop in the self_sup_*/tex_grp scripts.)
%
%   Input
%     content_sim - [N x N] symmetric content-similarity matrix
%                   (segmentation.content_similarity_matrix).
%
%   Output
%     rho - [N x N] mutual-similarity matrix.
%
%   See also SEGMENTATION.CONTENT_SIMILARITY_MATRIX, SEGMENTATION.GROUP_PATCHES

    n = size(content_sim, 1);
    rho = zeros(n, n);
    for i = 1:n
        for j = 1:n
            keep = true(n, 1);
            keep(i) = false;
            keep(j) = false;
            vi = content_sim(keep, j);        % similarities to patch j (excluding i,j)
            vj = content_sim(i, keep).';       % similarities to patch i (excluding i,j)
            rho(i, j) = sum(vi .* vj) / sqrt(sum(vi.^2) * sum(vj.^2));
        end
    end
end
