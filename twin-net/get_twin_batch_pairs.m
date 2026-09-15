function [X1, X2, pair_labels] = get_twin_batch_pairs(pos, neg, mini_batch_size)
% GET_TWIN_BATCH_PAIRS  Draw a balanced batch from two arrays of pre-stored patch pairs.
%   [X1, X2, pair_labels] = get_twin_batch_pairs(pos, neg, mini_batch_size)
%
%   Used for both natural-image pairs (pos = near, neg = far) and Brodatz/texture
%   test pairs (pos = same texture, neg = different textures). Splits the batch
%   50/50 in expectation between pos and neg.
%
%   Inputs
%     pos, neg        - [patch_size x patch_size x 2 x N] uint8 patch pairs; dim 3
%                        holds the two patches of a pair.
%     mini_batch_size - number of pairs to draw.
%
%   Output
%     X1, X2      - [patch_size x patch_size x 2 x mini_batch_size] uint8, patch 1
%                   and patch 2 of each drawn pair.
%     pair_labels - [1 x mini_batch_size], 1 for pos pairs, 0 for neg pairs.
%
%   See also GET_TWIN_BATCH_NAT_LIVE, TEXTURE_SAME_DIFF_PATCHES_NET

n_pos = size(pos, 4);
n_neg = size(neg, 4);

% split the batch into pos (label 1) and neg (label 0) at 50/50 in expectation
choice = rand(1, mini_batch_size) < 0.5;
num_pos = sum(choice);
num_neg = mini_batch_size - num_pos;

k_pos = randi(n_pos, 1, num_pos);
k_neg = randi(n_neg, 1, num_neg);

X1 = cat(4, pos(:, :, 1, k_pos), neg(:, :, 1, k_neg));
X2 = cat(4, pos(:, :, 2, k_pos), neg(:, :, 2, k_neg));

pair_labels = [ones(1, num_pos), zeros(1, num_neg)];

end
