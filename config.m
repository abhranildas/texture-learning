function cfg = config(color)
% CONFIG  Central configuration for the texture-learning pipeline.
%   cfg = config()
%   cfg = config(color)
%
%   Returns a struct of data paths, optical/physical constants, patch geometry,
%   normalization defaults, and the task-feature definitions. Pipeline stage
%   functions take cfg and may override stage-specific fields. Call config(false)
%   or config(true) again (e.g. in run_demo, after the user picks a mode) to get a
%   cfg with the other setting -- cheaper and less error-prone than mutating
%   cfg.features.color and re-deriving by hand.
%
%   EDIT cfg.paths.data_root below if the shared data store (vislab-common/data)
%   is not next to this repo.
%
% Inputs
%   color  logical, optional (default true). True selects the colour model
%          (chromatic B/R spot features included); false the achromatic-only
%          model. Everything downstream of it (spot_dims, dv_dims) is derived
%          at the bottom of this file, so this is the only switch to set.
% Output
%   cfg  struct of configuration fields, grouped as
%          .paths     folder locations (char)
%          .optics    eye-optics constants for the Watson OTF
%          .natural   calibrated natural-image dataset settings
%          .patch     patch/image geometry, in pixels at eccentricity 1
%          .textures  per-database texture-sheet ingestion flags
%          .norm      luminance/contrast normalization targets
%          .dv        decision-variable computation parameters
%          .gtr       grown-texture-region image settings (stages s6, s7)
%          .seed      RNG seed for reproducible runs
%          .demo      demo-plot settings
%          .features  feature-index vocabulary and the colour switch
%
% See also RUN_DEMO, SETUP, S1_LEARN_COLOR_TRANSFORM, S7_SEGMENT_GTR

    if nargin < 1 || isempty(color), color = true; end
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
    cfg.optics.apply          = true;    % apply optics (the "_otf" / filter == 1 path)

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
    %   patch geometry is divided by it to move into the periphery. At ppd = 60, the
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
    cfg.norm.target_mean     = 128;
    cfg.norm.target_contrast = 0.25;

    % --- decision-variable computation params (content-similarity / mk_phi context) ---
    %   power_suppress is the weak Fourier-power suppression exponent (beta). Geisler
    %   unified the content-similarity value (was 10) with DV training in 2026-07, so
    %   this and cfg.gtr.power_suppress below are both 16 and expected to stay equal.
    cfg.dv.power_suppress     = 16;
    cfg.dv.edge_thresh        = 50;    % gradient threshold, image units (edge-count feature)
    cfg.dv.sd1  = 1;  cfg.dv.nsd1 = 3; % 1st-derivative steerable kernel (edges)
    cfg.dv.sd2  = 1;  cfg.dv.nsd2 = 3; % 2nd-derivative steerable kernel (bars)
    cfg.dv.contrast_normalize = true;  % contrast-normalize before edge features

    % --- GTR images / segmentation experiments (stages s6, s7) ---
    cfg.gtr.szp          = 10;    % image size in patches (10x10 = 100 patches)
    cfg.gtr.n_regions    = 5;     % texture regions per GTR image (ntexr)
    cfg.gtr.seed_radius  = 1.0;   % region-seed radius as fraction of max
    cfg.gtr.coverage     = 1.0;   % fraction of the grid filled by regions
    cfg.gtr.dcrit        = 7.0;   % min separation (patches) for a "far" pair
    cfg.gtr.power_suppress = 16;  % weak-power beta for the per-pair DVs
                                  % (kept equal to cfg.dv.power_suppress)

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
    cfg.features.names = { 'A pixel','B pixel','R pixel', ...
        'edge count','edge mag','edge ori','edge mag x ori', ...
        'bar count','bar mag','bar ori','bar mag x ori', ...
        'cs ratio small','cs linear small','cs linear large' };
    cfg.features.edge_dims    = [5 7 9 10]; % edge/bar features computed by dv_edge_hist
    cfg.features.edge_dv_dims = [5 9 10];   % subset fed to the content edge DV (skips feature 7)

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
