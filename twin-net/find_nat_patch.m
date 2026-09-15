function coords = find_nat_patch(img, patch_size, same_max_dist)
% FIND_NAT_PATCH  Sample a near and a far texture patch pair from one image.
%   coords = find_nat_patch(img, patch_size, same_max_dist)
%
%   Proximity only -- no color criterion. The near pair is a reference patch plus a
%   randomly chosen adjacent (non-overlapping) neighbor within same_max_dist patches.
%   The far pair is two patches separated by more than a quarter of the image height
%   (dcrit = image_height/4), matching nat_near_far_patches.m. The far search loops
%   until a valid pair is found (no retry cap), so every call returns one.
%
%   Inputs
%     img           - image used only for its size, [H x W (x C)].
%     patch_size    - patch side length in pixels.
%     same_max_dist - max neighbor offset, in patches, for the near pair.
%
%   Output
%     coords - [4 x 2] patch corner coordinates (row, col):
%              row 1 = near reference patch, row 2 = near partner patch,
%              row 3 = far reference patch,  row 4 = far partner patch.
%
%   See also GET_TWIN_BATCH_NAT_LIVE

coords = nan(4, 2);
sz = size(img);
dcrit = sz(1) / 4; % min far-pair separation = quarter of image height

% find near pair: reference + a randomly chosen adjacent (non-overlapping) neighbor
x_a = randi(sz(1) - 4*same_max_dist*patch_size) + 2*same_max_dist*patch_size;
y_a = randi(sz(2) - 4*same_max_dist*patch_size) + 2*same_max_dist*patch_size;
coords(1, :) = [x_a y_a];

% enumerate valid neighbor offsets (excluding the reference itself)
offsets = [];
for d_row = -same_max_dist:same_max_dist
    for d_col = -same_max_dist:same_max_dist
        if d_row == 0 && d_col == 0 % not the same as the reference patch
            continue;
        end
        x = d_row * patch_size; y = d_col * patch_size;
        if (x_a+x < 1) || (x_a+x+patch_size-1 > sz(1))
            continue;
        end
        if (y_a+y < 1) || (y_a+y+patch_size-1 > sz(2))
            continue;
        end
        offsets(end+1, :) = [x y]; %#ok<AGROW>
    end
end
sel = offsets(randi(size(offsets, 1)), :);
coords(2, :) = [x_a+sel(1) y_a+sel(2)];

% find far pair: reference + random patch beyond dcrit (image_height/4).
% loop until found (no retry cap) so every call returns a valid pair
found = false;
while ~found

    % randomly select the far reference patch
    x_a = randi(sz(1) - 4*same_max_dist*patch_size) + 2*same_max_dist*patch_size;
    y_a = randi(sz(2) - 4*same_max_dist*patch_size) + 2*same_max_dist*patch_size;
    coords(3, :) = [x_a y_a];

    % randomly select a distant patch
    x_b = randi(sz(1) - 4*same_max_dist*patch_size) + 2*same_max_dist*patch_size;
    y_b = randi(sz(2) - 4*same_max_dist*patch_size) + 2*same_max_dist*patch_size;
    dp = sqrt((x_b-x_a)^2 + (y_b-y_a)^2);
    if dp > dcrit
        coords(4, :) = [x_b y_b];
        found = true;
    end
end
