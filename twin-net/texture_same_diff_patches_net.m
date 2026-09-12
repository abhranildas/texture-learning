% TEXTURE_SAME_DIFF_PATCHES_NET  Build same/different texture patch-pair TEST sets.
%
%   Builds test sets for the twin network from several texture databases in
%   vislab-common/data/textures. Produces TWO sets:
%
%     same,      diff       -- ALL databases combined (balanced), "different" pairs may
%                              cross databases (two textures from anywhere in the pool)
%     same_brod, diff_brod  -- Brodatz only (both patches from Brodatz textures)
%
%   Each is [patch_size x patch_size x 2 x N] uint8; dim 3 holds the two patches of a
%   pair (1 = reference, 2 = partner), matching the natural-image near/far layout so
%   getTwinBatchPairs can slice it directly. Saved to data/stimuli/textures/patch_pairs.mat.
%
%   Ingestion goes through the shared vislab.nat_stat_bayes.source_to_lms with the
%   per-database flags from cfg.textures -- the SAME function and flags the Bayesian
%   load_texture_images uses -- so the texture test patches are processed identically
%   to the natural-image training patches and cannot diverge from the Bayesian model.
%
%   Balancing: each database contributes the same number of distinct textures (capped) and
%   the same number of pairs, so the large low-variety pertex set cannot swamp the metric.
%
%   Note: same, diff, same_brod, diff_brod are frozen save names (zone-3, see
%   docs/readability-pass.md section 5.3) -- do not rename.
%
%   See also GETTWINBATCHPAIRS, TRAIN_NET

cfg = config;
patch_size = cfg.patch.size;
texdir = cfg.paths.textures;
down_level = 1;              % resolution scale-down; must match the training patches

n_tex_per_db  = 60;          % cap on distinct textures used per DB (subsample larger DBs)
n_same = 10000; n_diff = 10000;          % all-textures pairs of each type
n_same_brod = 5000; n_diff_brod = 5000;  % Brodatz-only pairs of each type

% per-database ingestion flags come from cfg.textures (single source, shared with the
% Bayesian load_texture_images), so gray/gamma/resize can't drift between the models.
db_names = fieldnames(cfg.textures);

% load a capped, random subset of each database as achromatic uint8 images. Sizing pass
% first (dir/min/numel only, no RNG draws) so the loading pass below can preallocate
% instead of growing all_tex/brod_tex one element at a time.
db_files = cell(numel(db_names), 1);
db_n_use = zeros(numel(db_names), 1);
for d = 1:numel(db_names)
    name = db_names{d};
    p = cfg.textures.(name);
    db_files{d} = dir(fullfile(texdir, name, ['*.' p.ext]));
    db_n_use(d) = min(n_tex_per_db, numel(db_files{d}));
end
all_tex  = cell(1, sum(db_n_use));            % every loaded texture (balanced pool)
brod_idx = find(strcmp(db_names, 'brodatz'));
if isempty(brod_idx), n_brod_total = 0; else, n_brod_total = db_n_use(brod_idx); end
brod_tex = cell(1, n_brod_total);             % Brodatz subset (for the Brodatz-only set)
n_all = 0; n_brod = 0;
for d = 1:numel(db_names)
    name = db_names{d};
    p = cfg.textures.(name);
    files = db_files{d};
    n_use = db_n_use(d);
    sel = randperm(numel(files), n_use);
    fprintf('%s: using %d of %d textures\n', name, n_use, numel(files));
    for i = 1:n_use
        [~, A] = vislab.nat_stat_bayes.source_to_lms( ...
            fullfile(files(sel(i)).folder, files(sel(i)).name), cfg, ...
            struct('gray', p.gray, 'gamma', p.gamma, 'resize_pertex', p.resize, 'ecc', down_level));
        A = uint8(A * 255 / max(A(:)));
        n_all = n_all + 1;
        all_tex{n_all} = A;
        if strcmp(name, 'brodatz')
            n_brod = n_brod + 1;
            brod_tex{n_brod} = A;
        end
    end
end

% all-textures set: same = one random texture twice; diff = two different textures from
% anywhere in the pool (cross-database allowed)
[same, diff] = make_pairs(all_tex, n_same, n_diff, patch_size);

% Brodatz-only set (both patches Brodatz)
[same_brod, diff_brod] = make_pairs(brod_tex, n_same_brod, n_diff_brod, patch_size);

% save both sets
outdir = fullfile(cfg.paths.stimuli, 'textures');
if ~exist(outdir, 'dir'); mkdir(outdir); end
if down_level > 1
    outfile = fullfile(outdir, ['patch_pairs_dsmpl_' num2str(down_level) '.mat']);
else
    outfile = fullfile(outdir, 'patch_pairs.mat');
end
save(outfile, 'same', 'diff', 'same_brod', 'diff_brod', '-v7.3')

%% show a few example pairs from the all-textures set (reference | partner)
n_show = 5;
i_same = randi(size(same, 4), 1, n_show);
i_diff = randi(size(diff, 4), 1, n_show);
figure;
tiledlayout(2, n_show, 'TileSpacing', 'compact', 'Padding', 'compact');
for j = 1:n_show
    nexttile; imshow([same(:, :, 1, i_same(j)) same(:, :, 2, i_same(j))], []);
    title(sprintf('same #%d', i_same(j)));
end
for j = 1:n_show
    nexttile; imshow([diff(:, :, 1, i_diff(j)) diff(:, :, 2, i_diff(j))], []);
    title(sprintf('diff #%d', i_diff(j)));
end

%% ------- local functions -------
function [same, diff] = make_pairs(tex, n_same, n_diff, patch_size)
    n = numel(tex);
    same = zeros(patch_size, patch_size, 2, n_same, 'uint8');
    for i = 1:n_same
        k = randi(n);                          % one random texture, two patches
        same(:, :, 1, i) = rand_patch(tex{k}, patch_size);
        same(:, :, 2, i) = rand_patch(tex{k}, patch_size);
    end
    diff = zeros(patch_size, patch_size, 2, n_diff, 'uint8');
    for i = 1:n_diff
        kk = randperm(n, 2);                   % two different textures, one patch each
        diff(:, :, 1, i) = rand_patch(tex{kk(1)}, patch_size);
        diff(:, :, 2, i) = rand_patch(tex{kk(2)}, patch_size);
    end
end

function p = rand_patch(t, patch_size)
    sz = size(t);
    x = randi(sz(1) - patch_size + 1);
    y = randi(sz(2) - patch_size + 1);
    p = t(x:x+patch_size-1, y:y+patch_size-1);
end
