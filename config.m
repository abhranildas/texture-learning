function cfg = config(color, optics, test_optics, pca_gradient)
% CONFIG  Central configuration for the texture-learning pipeline.
%   cfg = config()
%   cfg = config(color)
%   cfg = config(color, optics)
%   cfg = config(color, optics, test_optics)
%   cfg = config(color, optics, test_optics, pca_gradient)
%
%   Returns a struct of data paths, optical/physical constants, patch geometry,
%   normalization defaults, and the task-feature definitions. Pipeline stage
%   functions take cfg and may override stage-specific fields. To switch colour or
%   optics, call config again with the other setting (e.g. in run_demo, after the
%   user picks a mode) rather than mutating cfg.features.color or cfg.optics.apply:
%   other fields (file names, the colour rotation) are derived from them here.
%
%   EDIT cfg.paths.data_root below if the shared data store (vislab-common/data)
%   is not next to this repo.
%
% Inputs
%   color  logical, optional (default true). True selects the colour model
%          (chromatic B/R spot features included); false the achromatic-only
%          model. Everything downstream of it (spot_dims, dv_dims) is derived
%          at the bottom of this file, so this is the only switch to set.
%   optics logical, optional (default true). True applies the eye-optics filter
%          to every image, in training (natural images, s1-s5) and in testing
%          (texture sheets and GTR images, s6-s7). Each trained file is tagged by
%          it ("_otf" when true; the bins are AHEO_ vs AHE_), so the two models
%          sit side by side in data/models and each run loads its own.
%   test_optics  logical, optional (default = optics). Whether the optics filter
%          is applied to the test images (texture sheets, GTR and natural images
%          being segmented), separately from the model, which `optics` picks. Set
%          it different from `optics` only to test a model on images filtered
%          differently from its training images.
%   pca_gradient  logical, optional (default false). True adds three features from
%          the learned multi-scale gradient PCs (s1b_learn_gradient_pca): PC large,
%          mid and small gradient mag (15-17, the magnitudes of PC pairs 1-2, 3-4,
%          5-6). They and the 1 px edge mag (5) are first merged by their own bound,
%          the multi-scale gradient DV (decision_bounds.ms_grad), which then joins
%          the bar features in the gradient (edge) DV. Its trained files are tagged "_pcagrad".
%          False leaves the model and every file name exactly as before.
% Output
%   cfg  struct of configuration fields, grouped as
%          .paths     folder locations (char)
%          .optics    eye-optics constants for the Watson OTF
%          .natural   calibrated natural-image dataset settings
%          .patch     patch/image geometry, in pixels at eccentricity 1
%          .textures  per-database texture-sheet ingestion flags
%          .norm      luminance/contrast normalization targets
%          .dv        decision-variable computation parameters
%          .pcgrad    multi-scale gradient PCA settings and learned model
%          .gtr       grown-texture-region image settings (stages s6, s7)
%          .seed      RNG seed for reproducible runs
%          .demo      demo-plot settings
%          .features  feature-index vocabulary and the colour switch
%
% See also RUN_DEMO, SETUP, S1_LEARN_COLOR_TRANSFORM, S7_SEGMENT_GTR

    if nargin < 1 || isempty(color),  color  = true; end
    if nargin < 2 || isempty(optics), optics = true; end
    if nargin < 3 || isempty(test_optics), test_optics = optics; end
    if nargin < 4 || isempty(pca_gradient), pca_gradient = false; end
    repo_root = fileparts(mfilename('fullpath'));

    % --- data locations ---
    %   data_root  shared lab data store (vislab-common/data), a sibling of this repo
    %   models     shipped trained artifacts (PCA/CDF/bin/DV .mat files)
    %   stimuli    generated artifacts (patch pairs, results)
    cfg.paths.repo_root      = repo_root;
    cfg.paths.data_root      = fullfile(repo_root, '..', 'vislab-common', 'data');
    cfg.paths.natural_images = fullfile(cfg.paths.data_root, 'CPS natural images');
    cfg.paths.textures       = fullfile(cfg.paths.data_root, 'textures');
    cfg.paths.models         = fullfile(repo_root, 'data', 'models');
    cfg.paths.stimuli        = fullfile(repo_root, 'data', 'stimuli');

    % --- eye optics (Watson OTF) ---
    %   ppd is pixels/deg for ALL images (natural, textures, GTR/display): the human
    %   psychophysics display resolution. (Was 64 for the calibrated natural images;
    %   unified to 60 -- requires regenerating the s1-s5 artifacts. See
    %   twin-net/net_plan.md.)
    cfg.optics.ppd            = 60;      % pixels/deg
    cfg.optics.pupil_diameter = 4;       % mm
    cfg.optics.wavelength     = 550;     % nm
    cfg.optics.apply          = optics;  % training images, and which model files (see Inputs)
    cfg.optics.apply_test     = test_optics;  % test images (see Inputs)
    if optics
        cfg.optics.file_tag = '_otf';     % marks files trained with the optics on
    else
        cfg.optics.file_tag = '';
    end

    % --- multi-scale gradient PCA toggle (see Inputs). Off: the model is unchanged.
    %     The PCA itself (s1b_learn_gradient_pca) depends only on the optics. ---
    cfg.features.pca_gradient = pca_gradient;
    if pca_gradient
        cfg.features.file_tag = '_pcagrad';   % marks files trained with it
    else
        cfg.features.file_tag = '';
    end

    % --- LMS->ABR colour rotation (stage s1 output), learned from natural images
    %     with or without the optics. Shared across the lab in data_root. Missing
    %     only before s1 has been run for this optics setting.
    %     LMS: long/medium/short-wavelength cone responses per pixel (images are held
    %     as [H x W x 3] LMS arrays, named lms or pimg). ABR: the opponent axes from a
    %     PCA of LMS -- Achromatic, Blue-yellow, Red-green. coeff is the 3x3 rotation
    %     (its columns the principal components). ---
    cfg.paths.color_rotation = fullfile(cfg.paths.data_root, ...
        ['cps_lms2abr' cfg.optics.file_tag '.mat']);
    cfg.color_rotation = load_if_present(cfg.paths.color_rotation, 'coeff', ...
        's1_learn_color_transform');

    % --- TEMPORARY Bill-compatibility switch (docs/segmentation-parity.md), for
    %     checking this repo against Bill's code only (check_bill_segmentation turns
    %     it on). Off is the correct model. On reproduces Bill's current code on the
    %     texture/GTR path:
    %       1. his optics-filter frequency units (aply_otf uses u = k/ppd, not
    %          k*ppd/N; reported to him as a likely bug), via otf_ppd;
    %       2. his LMS->ABR colour rotation (data/models/bill_lms2abr.mat, written by
    %          tools/import_bill_model) instead of cfg.color_rotation, in
    %          segmentation.prep_grid;
    %       3. a stale extra term in his mutual-similarity loop
    %          (segmentation.mutual_similarity).
    %     Natural-image training (s1-s5) does not use it. Remove once the repo is
    %     verified against Bill's code. ---
    cfg.bill_compat = false;

    % --- calibrated natural-image dataset (for learning priors: stages s1, s2) ---
    %   sets are file-name stems inside cfg.paths.natural_images.
    cfg.natural.sets      = {'Set9_16', 'Set10_16', 'Set12_16'};
    cfg.natural.max_val   = 2^14 - 1;   % 14-bit pixel max (images scaled by 255/max_val)
    cfg.natural.target_isolated_patches   = 7820;  % isolated patches to sample, all images
    cfg.natural.target_nearfar_references = 3910;  % near/far reference locations to sample

    % --- camera RGB -> human LMS cone matrix: now the shared lab calibration,
    %     loaded automatically by vislab.lib.rgb2lms from vislab-common/data/cps_rgb2lms.mat
    %     (no longer hardcoded here). ---

    % --- patch geometry at eccentricity 1 (fovea) ---
    %   ecc throughout the pipeline is an integer divisor, not a number of degrees:
    %   patch geometry is divided by it to move into the periphery. ecc = 1, 2, 4, 8
    %   stand for roughly the fovea, 1.65, 4.95 and 11.55 deg. At ppd = 60, the
    %   values below are a ~1-deg patch inside a ~10-deg GTR image.
    cfg.patch.image_size = 640;   % GTR image size, pixels (eccentricity 1, fovea)
    cfg.patch.size       = 64;    % patch size, pixels (eccentricity 1, fovea)

    % --- texture-database ingestion flags (single source, used by both the Bayesian
    %     load_texture_images and the twin network's texture test set via source_to_lms):
    %       ext    file extension           gray   grayscale sheet -> replicate to 3 channels
    %       gamma  linearize gamma-compressed sheet   resize  1024px pertex sheet -> image_size ---
    cfg.textures.brodatz = struct('ext','gif','gray',true, 'gamma',false,'resize',false);
    cfg.textures.fabric  = struct('ext','png','gray',false,'gamma',true, 'resize',false);
    cfg.textures.mcgill  = struct('ext','png','gray',false,'gamma',true, 'resize',false);
    cfg.textures.vistex  = struct('ext','png','gray',false,'gamma',true, 'resize',false);
    cfg.textures.pertex  = struct('ext','png','gray',true, 'gamma',false,'resize',true);

    % --- luminance/contrast normalization ---
    cfg.norm.target_mean     = 128;    % mean pixel value, 0-255 scale (was m0)
    cfg.norm.target_contrast = 0.25;   % RMS contrast (was c0)

    % --- decision-variable computation params (content-similarity / mk_phi context) ---
    %   power_suppress is the weak Fourier-power suppression constant (beta, Bill's b0).
    %   Bill's current model uses 5e-5 at every eccentricity (his load_b0_nat.m; was 16,
    %   and 10 for content similarity before that). Training (s5) and segmentation
    %   both read it, so the content DV sees the same power scale in both.
    cfg.dv.power_suppress     = 5e-5;
    cfg.dv.edge_thresh        = 50;    % gradient threshold, image units (edge-count feature)
    cfg.dv.sd1  = 1;  cfg.dv.nsd1 = 3; % 1st-derivative steerable kernel (edges)
    cfg.dv.sd2  = 1;  cfg.dv.nsd2 = 3; % 2nd-derivative steerable kernel (bars)
    cfg.dv.contrast_normalize = true;  % contrast-normalize before edge features
    cfg.dv.border_center      = true;  % neighbour border cue from one patch-sized window
                                       % centred on the shared border (Bill's centerflg = 1,
                                       % Rb12); false = the two joined patches (Rb). The
                                       % border bound itself is trained on Rb either way.

    % multi-scale gradient PCA (s1b_learn_gradient_pca), used by the model only when
    % pca_gradient is true; the bar features and border DV stay at sd1/sd2 = 1.
    cfg.pcgrad.sd_list = [1 2 4];      % scales (px) of the H/V first-derivative kernels
    cfg.pcgrad.nsd     = 3;            % kernel width in SDs (as cfg.dv.nsd1)
    cfg.paths.gradient_pca = fullfile(cfg.paths.models, ...
        ['gradient_pca' cfg.optics.file_tag '.mat']);
    cfg.pcgrad.model = [];             % the learned PCA (saved as gradient_pca), if used
    if pca_gradient
        cfg.pcgrad.model = load_if_present(cfg.paths.gradient_pca, 'gradient_pca', ...
            's1b_learn_gradient_pca');
    end

    % --- GTR images / segmentation experiments (stages s6, s7) ---
    cfg.gtr.szp          = 10;    % image size in patches (10x10 = 100 patches)
    cfg.gtr.n_regions    = 5;     % texture regions per GTR image (ntexr)
    cfg.gtr.seed_radius  = 1.0;   % region-seed radius as fraction of max
    cfg.gtr.coverage     = 1.0;   % fraction of the grid filled by regions
    % normalize every texture sheet to mean cfg.norm.target_mean and contrast
    % cfg.norm.target_contrast before building texture pairs / GTR images, so regions
    % don't differ in overall luminance or contrast (Bill's mk_GTR_images.m, normflg=1;
    % his self_sup_tex_segm.m does not normalize: set false to match that)
    cfg.gtr.normalize_sheets = true;
    cfg.gtr.dcrit        = 7.0;   % min separation (patches) for a "far" pair

    % --- fixed segmentation parameters, shared by all images (segmentation.segment_lms):
    %       method        per-image rule for learning group_crit_best and
    %                     mutual_weight_best ('bc', see segmentation.learn_image_similarity)
    %       group_offset  added to the learned group_crit_best (paper gamma_l offset;
    %                     Bill's gl)
    %       confidence    confidence criterion (gamma_c; Bill's gcc)
    %       merge         region-merge criterion (gamma_r; Bill's gr)
    %     Chosen by s7_segment_gtr. Before s7 has saved them for this optics setting,
    %     Bill's choice (his seg_11_8_26_1_1.mat) is the fallback, so s7 has a method
    %     and confidence to run with. ---
    cfg.paths.segmentation_params = fullfile(cfg.paths.models, ...
        ['segmentation_params' cfg.optics.file_tag cfg.features.file_tag '.mat']);
    cfg.segment = load_if_present(cfg.paths.segmentation_params, 'params', 's7_segment_gtr');
    if isempty(cfg.segment)
        cfg.segment = struct('method', 'bc', 'group_offset', -0.25, 'confidence', 1.2, ...
            'merge', 0.8);
    end
    % Natural images (stage 8) add this to cfg.segment.group_offset: a stricter link
    % threshold. A natural image has many more patches than a GTR image, so at the
    % GTR threshold a few links across region boundaries chain almost every patch
    % into one region. Set by eye on the stage 8 image (Set12_16_143); GTR is unaffected.
    cfg.natural.extra_group_offset = 2;

    % --- reproducibility ---
    cfg.seed = 0;

    % --- demo plots ---
    cfg.demo.scatter_points = 10000;   % max points drawn in the demo's 3D scatter plots

    % --- task-feature definitions (indices used throughout the DV code) ---
    %   1 A pixel (achromatic)     8  bar count
    %   2 B pixel (blue-yellow)    9  bar magnitude
    %   3 R pixel (red-green)     10  bar orientation
    %   4 edge count             11  bar magnitude x orientation
    %   5 edge magnitude         12  center-surround ratio (small)
    %   6 edge orientation       13  center-surround linear (small)
    %   7 edge mag x orientation 14  center-surround linear (large)
    %                            15  PC large gradient mag (pca_gradient only)
    %                            16  PC mid gradient mag   (pca_gradient only)
    %                            17  PC small gradient mag (pca_gradient only)
    cfg.features.names = { 'A pixel','B pixel','R pixel', ...
        'edge count','edge mag','edge ori','edge mag x ori', ...
        'bar count','bar mag','bar ori','bar mag x ori', ...
        'cs ratio small','cs linear small','cs linear large', ...
        'PC large gradient mag','PC mid gradient mag','PC small gradient mag' };
    cfg.features.edge_dims    = [5 7 9 10]; % edge/bar features computed by dv_edge_hist
    % edge DV features (Bill's current ne). With pca_gradient, the 1 px edge mag (5)
    % and the three PC gradient mags (15-17) are first merged by their own bound
    % (ms_grad_dims, first in edge_dv_dims); that DV joins the bar features.
    if cfg.features.pca_gradient
        cfg.features.pc_grad_dims = [15 16 17];
        cfg.features.ms_grad_dims = [5 cfg.features.pc_grad_dims];
        cfg.features.edge_dv_dims = [cfg.features.ms_grad_dims 9 10 11];
    else
        cfg.features.pc_grad_dims = [];
        cfg.features.ms_grad_dims = [];
        cfg.features.edge_dv_dims = [5 9 10 11];
    end

    % --- colour extension (docs/color-extension-plan.md). Achromatic spot = A pixel +
    %     CS-small + CS-large (the published model); chromatic spot = B (blue-yellow) +
    %     R (red-green) pixels, appended only when `color` is true. Everything else
    %     (spot_dims, dv_dims) is derived here so there is one source of truth; callers
    %     that need to switch modes call config(true)/config(false) again rather than
    %     mutating cfg.features.color by hand. ---
    cfg.features.color          = color;
    cfg.features.spot_achr_dims = [1 13 14];
    if cfg.features.color
        cfg.features.spot_chrom_dims = [2 3];  % B (blue-yellow), R (red-green) pixels
    else
        cfg.features.spot_chrom_dims = [];
    end
    cfg.features.spot_dims = [cfg.features.spot_achr_dims, cfg.features.spot_chrom_dims];
    cfg.features.dv_dims   = sort([cfg.features.spot_dims, cfg.features.edge_dv_dims]);
end

function value = load_if_present(file, name, made_by)
% Variable `name` from `file`, or [] with a warning if the file does not exist yet
% (it is made by the stage `made_by`, which itself needs a cfg to run).
    if isfile(file)
        S = load(file, name);
        value = S.(name);
    else
        [~, f, e] = fileparts(file);
        warning('config:missingFile', '%s not found; run %s to make it.', [f e], made_by);
        value = [];
    end
end
