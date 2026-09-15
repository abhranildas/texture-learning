function golden = golden_harness(mode, golden_file)
% GOLDEN_HARNESS  Capture or replay golden outputs for Tier-B readability checks.
%   golden = golden_harness('capture', golden_file)
%   golden = golden_harness('replay', golden_file)
%
%   Calls entry points directly (never through run_demo, which uses
%   rng('shuffle') on some paths) under an explicit rng(cfg.seed), and either
%   saves their outputs to GOLDEN_FILE ('capture') or reloads GOLDEN_FILE and
%   asserts isequal against a fresh run ('replay').
%
%   Entry points, by tranche (docs/readability-pass.md sections 1.1 and 10):
%     +segmentation/, pipeline/  segmentation.prep_grid, load_dv_handles,
%                                sample_demo_pairs, pair_responses,
%                                segmentation.content_similarity_matrix
%     +gtr/                     gtr.grow_region_masks, gtr.sample_texture_ids
%     demo/                     sample_texture_pairs, apply_dv
%                                (compute_demo_responses reuses pair_responses,
%                                already covered above)
%     twin-net/                 forward_twin, predict_twin, pool_stats, on a tiny
%                                synthetic dlnetwork (needs the Deep Learning
%                                Toolbox; not a stand-in for train_net.m's real
%                                architecture, just enough to exercise the
%                                three functions deterministically)
%
%   Not covered: experiments/adaptive_hist_exp.m is a script, so its local
%   functions have no callable entry point without a Tier-C restructure --
%   that tranche's Tier-B edits are verified by pattern-check only.
%
% Inputs
%   mode         'capture' or 'replay'
%   golden_file  path to a .mat file to write to / read from
% Output
%   golden  struct of all entry-point outputs (as captured or as freshly
%           computed, depending on mode)
%
% See also CANON, CHECK_TIER_A

setup();
cfg = config(true);
ecc = 1;

rng(cfg.seed);
img = 255 * rand(256, 256, 3);
[P, G, Gn] = segmentation.prep_grid(img, cfg.patch.size / ecc, cfg); %#ok<ASGLU>
grid_sum = @(C) sum(cellfun(@(x) sum(x(:)), C), 'all');
golden.prep_grid_checksum = grid_sum(G) + grid_sum(Gn);

rng(cfg.seed);
dv = load_dv_handles(cfg, ecc, true);
golden.dv_fields = sort(fieldnames(dv));

rng(cfg.seed);
[ptchn, ptchf] = sample_demo_pairs(cfg, ecc);
golden.demo_pairs_size = [size(ptchn) size(ptchf)];

psz = cfg.patch.size / ecc;
btype = 5;
b0 = 16;
thresh = cfg.dv.edge_thresh;
nh = cfg.features.spot_dims;
ne = cfg.features.edge_dv_dims;
feature_list = zeros(1, 20);  feature_list(cfg.features.dv_dims) = 1;
cstat        = zeros(1, 20);  cstat(cfg.features.dv_dims) = btype;
[n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds(cstat, ecc, double(cfg.optics.apply));

rng(cfg.seed);
[R, keep, col] = pair_responses(ptchn, bin_bounds, n_bins, feature_list, nh, ne, b0, thresh, psz, cfg); %#ok<ASGLU>
golden.pair_responses_checksum = sum(R(:));
golden.pair_responses_keep_n = numel(keep);

rng(cfg.seed);
n_side = size(img, 1) / psz;
[patch_x, patch_y] = ndgrid(1:n_side, 1:n_side);
phi = segmentation.content_similarity_matrix(img, psz, patch_x(:), patch_y(:), ...
    bin_bounds, n_bins, dv.h, dv.e, dv.c, cfg);
golden.content_similarity_checksum = sum(phi(:));

% --- +gtr/ ---
rng(cfg.seed);
[masks, maps] = gtr.grow_region_masks(8, 4, 3, 0.3, 0.9);
golden.grow_region_masks_checksum = sum(masks(:)) + sum(maps(:));
golden.grow_region_masks_size = [size(masks) size(maps)];

rng(cfg.seed);
ids = gtr.sample_texture_ids(20, 4, 3);
golden.sample_texture_ids_checksum = sum(ids(:));

% --- demo/ ---
rng(cfg.seed);
[ptch, same_gt] = sample_texture_pairs(cfg, ecc, 6, 3);
golden.sample_texture_pairs_checksum = sum(ptch(:));
golden.sample_texture_pairs_same_gt = same_gt;

rng(cfg.seed);
X_apply_dv = randn(5, 3);
y_apply_dv = apply_dv(@(x) sum(x) - 1, X_apply_dv);
golden.apply_dv_checksum = sum(y_apply_dv);

% --- twin-net/ (needs the Deep Learning Toolbox) ---
if exist('dlnetwork', 'file') == 2
    rng(cfg.seed);
    n_channels = 4;
    layers = [imageInputLayer([8 8 1], 'Normalization', 'none'), ...
              convolution2dLayer(3, n_channels, 'Padding', 'same'), ...
              reluLayer];
    net = dlnetwork(layerGraph(layers));
    fcParams.FcWeights = dlarray(randn(1, 2 * n_channels));
    fcParams.FcBias = dlarray(randn(1, 1));
    X1 = dlarray(randn(8, 8, 1, 3), 'SSCB');
    X2 = dlarray(randn(8, 8, 1, 3), 'SSCB');
    golden.forward_twin_checksum = sum(extractdata(forward_twin(net, fcParams, X1, X2)));
    golden.predict_twin_checksum = sum(extractdata(predict_twin(net, fcParams, X1, X2)));
    F = dlarray(randn(4, 4, n_channels, 2), 'SSCB');
    golden.pool_stats_checksum = sum(extractdata(pool_stats(F)), 'all');
else
    golden.forward_twin_checksum = [];
    golden.predict_twin_checksum = [];
    golden.pool_stats_checksum = [];
    warning('golden_harness:noDeepLearningToolbox', ...
        'Deep Learning Toolbox not found -- twin-net/ entry points skipped.');
end

if strcmp(mode, 'capture')
    save(golden_file, 'golden');
elseif strcmp(mode, 'replay')
    ref = load(golden_file, 'golden');
    assert(isequal(ref.golden, golden), 'golden_harness:mismatch', ...
        'golden output changed -- this edit is not behaviour-preserving');
else
    error('golden_harness:mode', 'mode must be ''capture'' or ''replay''');
end
end
