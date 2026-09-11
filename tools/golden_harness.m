function golden = golden_harness(mode, golden_file)
% GOLDEN_HARNESS  Capture or replay golden outputs for Tier-B readability checks.
%   golden = golden_harness('capture', golden_file)
%   golden = golden_harness('replay', golden_file)
%
%   Calls the five entry points verified in docs/readability-pass.md sec. 1.1
%   directly (never through run_demo, which uses rng('shuffle') on some paths)
%   under an explicit rng(cfg.seed), and either saves their outputs to
%   GOLDEN_FILE ('capture') or reloads GOLDEN_FILE and asserts isequal against
%   a fresh run ('replay').
%
%   Entry points: segmentation.prep_grid, load_dv_handles, sample_demo_pairs,
%   pair_responses, segmentation.content_similarity_matrix.
%
% Inputs
%   mode         'capture' or 'replay'
%   golden_file  path to a .mat file to write to / read from
% Output
%   golden  struct of the five outputs (as captured or as freshly computed,
%           depending on mode)
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
