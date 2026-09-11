function [X1, X2, pair_labels] = getTwinBatch_nat_live( ...
    A_pool, mini_batch_size, patch_size, same_max_dist)
% GETTWINBATCH_NAT_LIVE  Cut a fresh batch of near/far patch pairs on the fly.
%   [X1, X2, pair_labels] = ...
%       getTwinBatch_nat_live(A_pool, mini_batch_size, patch_size, same_max_dist)
%
%   Cuts a balanced batch of FRESH near/far patch pairs from the pool of achromatic
%   (A) source images. Each pair is cut at random coordinates from a randomly chosen
%   image, so pairs effectively never repeat across training -- there is nothing for
%   the network to memorize. This is the on-the-fly replacement for slicing a fixed,
%   pre-stored pair array (as getTwinBatchPairs does for the Brodatz test set).
%
%   Note: this must NOT reseed the RNG. The offline generator (nat_near_far_patches_net)
%   reseeds per image with rng(k) for reproducibility, but here we want every batch to
%   be genuinely new, so we let the global RNG run freely.
%
%   Inputs
%     A_pool          - 1xN cell array of uint8 A images (from load_nat_A_pool).
%     mini_batch_size - number of pairs in the batch.
%     patch_size      - patch side length in pixels (e.g. 64; matches the [64 64 1]
%                       network input).
%     same_max_dist   - max neighbor offset, in patches, for the near pair.
%
%   Output
%     X1, X2      - [patch_size x patch_size x 1 x mini_batch_size] uint8, patch 1
%                   and patch 2 of each pair. Patches are cut on the CPU; train_net
%                   moves the finished batch to the GPU.
%     pair_labels - [1 x mini_batch_size], 1 = near/positive, 0 = far/negative.
%
%   See also FIND_NAT_PATCH, GETTWINBATCHPAIRS, LOAD_NAT_A_POOL

n_img = numel(A_pool);

% decide near vs far per slot -- 50/50 in expectation
choice = rand(1, mini_batch_size) < 0.5;   % true -> near
num_near = sum(choice);
num_far  = mini_batch_size - num_near;

X1 = zeros(patch_size, patch_size, 1, mini_batch_size, 'uint8');
X2 = zeros(patch_size, patch_size, 1, mini_batch_size, 'uint8');

% near pairs first, then far pairs. A single
% find_nat_patch call returns both a near pair (rows 1-2) and a far pair
% (rows 3-4); we keep only the one we need for this slot. find_nat_patch is cheap
% (random coordinates + a small offset enumeration), so discarding the other half
% is not a meaningful cost next to the GPU forward/backward pass.
for i = 1:num_near
    A = A_pool{randi(n_img)};
    coords = find_nat_patch(A, patch_size, same_max_dist);
    x_a = coords(1, 1); y_a = coords(1, 2);
    x_b = coords(2, 1); y_b = coords(2, 2);
    X1(:, :, 1, i) = A(x_a:x_a+patch_size-1, y_a:y_a+patch_size-1);
    X2(:, :, 1, i) = A(x_b:x_b+patch_size-1, y_b:y_b+patch_size-1);
end
for j = 1:num_far
    A = A_pool{randi(n_img)};
    coords = find_nat_patch(A, patch_size, same_max_dist);
    x_a = coords(3, 1); y_a = coords(3, 2);
    x_b = coords(4, 1); y_b = coords(4, 2);
    X1(:, :, 1, num_near+j) = A(x_a:x_a+patch_size-1, y_a:y_a+patch_size-1);
    X2(:, :, 1, num_near+j) = A(x_b:x_b+patch_size-1, y_b:y_b+patch_size-1);
end

pair_labels = [ones(1, num_near) zeros(1, num_far)];
end
