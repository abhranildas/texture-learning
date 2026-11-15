% +segmentation  (package namespace: segmentation.*)
% HBO texture-segmentation pipeline: per-patch prep and content features, all-pairs
% and neighbour similarity matrices, patch grouping into regions, and scoring.
%
%   Functions:
%     prep_grid                 - prepare every patch of the image grid once (extract,
%                                  normalize, rotate; raw + contrast-norm gray)
%     content_features          - precompute each grid patch's content features once
%                                  (power spectrum, spot/edge histograms)
%     content_dv_pair           - content decision variable between two patches, from
%                                  their precomputed features
%     content_similarity_matrix - all-pairs content similarity between image patches
%     neighbor_similarity_matrix - border+content similarity for neighbouring patch pairs
%     mutual_similarity          - cosine similarity between patches' content-similarity
%                                  vectors (paper: u_ij)
%     learn_image_similarity     - one image's similarities, self-supervised grouping
%                                  criterion/weight, and combined neighbour similarity
%     segment_image              - segment one GTR image at fixed grouping parameters
%     group_patches              - segment patches by local-similarity, transitive,
%                                  isolated, and region grouping
%     merge_similar_regions      - merge the single most-similar pair of touching regions
%     assign_isolated_patches    - attach unlinked patches to their best neighbouring group
%     count_correct_regions      - count estimated regions that exactly match a
%                                  ground-truth region
%
% Call functions as segmentation.<function>. See SEGMENTATION.PREP_GRID's header
% (and its See-also chain) for the intended call order producer-to-consumer.
