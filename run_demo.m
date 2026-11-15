% RUN_DEMO  End-to-end demonstration of the texture-learning pipeline.
%
%   Run it (from anywhere):   >> run <path-to-repo>/run_demo.m
%   or:   >> cd <repo>; setup; run run_demo.m
%
%   This is a script, not a function: it takes no arguments and returns nothing,
%   but it asks two questions at the prompt (demo mode, then whether to include
%   colour) and leaves its results in the base workspace and in figure windows.
%
% What it does:
%   Demonstrates the entire texture-learning pipeline described in the paper
%   "Proximity as a Ground-Truth Proxy for Training Texture Discrimination and
%   Segmentation".
%
%   Stages 1-5 involve training the model from scratch using calibrated natural images,
%   where spatial proximity serves as a ground-truth proxy for whether two patches are
%   the same or different textures. This training is computationally expensive and
%   requires the full natural image dataset in vislab-common/data.
%
%   For convenience, this demo defaults to `demo_type = 'quick'`, which skips
%   stages 1-5. Instead of loading all patch pairs to train the decision
%   boundaries from scratch, it generates illustrative plots using a fast subset
%   of patch pairs and uses the SHIPPED pre-trained decision bounds (which
%   fully cover all bounds needed for the entire demo pipeline). Quick mode asks
%   whether to include colour, same as full mode: colour and achromatic models
%   ship as separate decision-bounds files, so quick mode runs whichever mode is
%   asked for -- falling back to whichever mode IS shipped, with a clear notice,
%   only if that file is missing.
%
%   If you set `demo_type = 'full'`, the demo will load all patch pairs to
%   actually train the decision bounds from scratch, and run the entire pipeline
%   (this is computationally expensive). Full mode asks whether to train the
%   COLOUR model: the spot decision variable is then built in two steps --
%   achromatic (A pixel, CS-small, CS-large) and chromatic (B, R pixels) -- combined
%   into the full spot DV that feeds the content DV exactly as the achromatic-only
%   spot DV always did (docs/color-extension-plan.md).
%
%   The plotting and response-computation helpers live in demo/ (added to the
%   path by setup): plot_stage1, plot_stage1b_gradients, plot_stage2, plot_stage3,
%   plot_stage5_intermediate, plot_stage5, plot_stage6_pairs, plot_stage7,
%   plot_stage8_natural, compute_demo_responses, sample_texture_pairs, apply_dv,
%   patch_to_rgb_display, overlay_region_boundaries; pipeline/pair_responses.
%
%   Note that stage 7 deliberately calls rng('shuffle') so its grown-texture-region
%   images differ from run to run; this script is therefore not reproducible by
%   design. Call the pipeline functions directly under rng(cfg.seed) if you need
%   repeatable numbers.
%
% See also SETUP, CONFIG, S7_SEGMENT_GTR, PLOT_STAGE6_PAIRS, PLOT_STAGE7,
%   PLOT_STAGE8_NATURAL

% --- locate the repo and set up the path ---
repo_root = fileparts(mfilename('fullpath'));
cd(repo_root);
setup;

% Dock all demo figures into one window. Works in the classic MATLAB desktop.
% (In R2025a's new desktop this docks to the desktop rather than a figure
% container, and programmatic docking is limited -- use the figure window's dock
% button if it doesn't take.)
set(0, 'defaultfigurewindowstyle', 'docked');

% --- Eye-optics filter, for training and testing alike (config's `optics` input).
%     false uses (or, in full mode, trains) the model without the optics filter;
%     its files sit beside the optics-on ones in data/models. ---
optics = true;

% --- 0. Choose the demo mode ('quick' or 'full') ---
%   'quick': fast -- skips training (stages 1-5), uses the shipped pre-trained bounds
%            for whichever colour/achromatic mode is asked for (see below).
%   'full':  re-trains the model from scratch over all patch pairs (slow); asks
%            whether to train the colour model.
demo_type = '';
while ~ismember(demo_type, {'quick', 'full'})
    demo_type = lower(strtrim(input( ...
        'Run demo in ''quick'' or ''full'' mode? [quick/full, default quick]: ', 's')));
    if isempty(demo_type), demo_type = 'quick'; end
end

if strcmp(demo_type, 'full')
    reply = input([ ...
        '\nThis will train the model from scratch, which takes a while,\nand will replace the ' ...
        'model parameter files that came pre-installed with this package. Continue? (y/n): '], 's');
    if ~strcmpi(reply, 'y')
        fprintf('Aborting: run_demo stopped before training.\n');
        return;
    end

    color_reply = '';
    while ~ismember(color_reply, {'y', 'n'})
        color_reply = lower(strtrim(input( ...
            ['Include colour in the model (chromatic B/R spot features)? ' ...
             '[y/n, default y]: '], 's')));
        if isempty(color_reply), color_reply = 'y'; end
    end
    cfg = config(strcmp(color_reply, 'y'), optics);

    fprintf('\n--- Running Pipeline Stages 1-5: Training the Model ---\n');

    % Stage 1: Learn Color Transform (Decorrelation)
    % First, the raw RGB camera sensor responses are converted into LMS cone responses.
    % This initial RGB-to-LMS transform uses a fixed matrix calibrated to the specific
    % camera used to capture the natural image dataset.
    % Next, consistent with early visual processing (and optimal encoding), we transform
    % the LMS axes to an ABR (Achromatic, Blue-yellow, Red-green) space so the joint
    % distribution of features has minimal correlation.
    fprintf('-> Running Stage 1: s1_learn_color_transform...\n');
    % Capture the learned LMS->ABR rotation to plot in Stage 1 (over all images).
    coeff_s1 = s1_learn_color_transform(cfg, true);

    % Stage 2+3: Learn Feature Priors AND Make Near/Far Training Pairs (single pass)
    % In one pass over the natural images, compute the natural prior distributions
    % (CDFs) of the low-level image features, and form the proximity-proxy training
    % pairs: "near" pairs (likely same texture) and "far" pairs (likely different).
    % Priors are eccentricity-dependent (ecc blurs + downsamples), so they are learned
    % from the same ecc image as the pairs.
    ecc = 1; % Eccentricity of 1 = fovea
    fprintf('-> Running Stage 2+3: s23_learn_priors_and_pairs...\n');
    s23_learn_priors_and_pairs(cfg, ecc, true);

    % Stage 4: Optimize Adaptive Histogram Bins
    % For each feature dimension, we discretize the feature space into adaptive bins.
    % This prepares the data to estimate the task-specific feature likelihoods (i.e.
    % probability distributions of features for near vs. far pairs).
    fprintf('-> Running Stage 4: s4_optimize_bins...\n');
    % dv_dims = spot (achromatic [+ chromatic]) + edge DV dimensions.
    s4_optimize_bins(cfg, cfg.features.dv_dims, ecc, true);

    % Stage 5: Train Decision Variables and Bounds
    % Using the near/far pairs as ground truth, we train the Bayesian decision variables
    % (spot -- achromatic and, if colour is on, chromatic, then combined -- content,
    % border, and combined) and the optimal decision bounds (e.g., QSVM boundary). This
    % maximizes near-far categorization accuracy, which the paper shows mathematically
    % also optimizes same-different categorization.
    fprintf('-> Running Stage 5: s5_train_decision_vars...\n');
    % Capture the exact points (and their column layout) the bounds trained on, to plot in Stage 5.
    [R_near, R_far, col] = s5_train_decision_vars(cfg, ecc, 1, true);

    fprintf('Training complete.');
else
    % Quick mode uses the shipped data/models artifacts as-is (no training). Colour
    % and achromatic models ship as separate decision-bounds files
    % (decision_bounds_filename), so quick mode can run whichever mode the user
    % asks for -- falling back to whichever mode IS shipped, with a clear notice,
    % only if the requested one's file is missing.
    color_reply = '';
    while ~ismember(color_reply, {'y', 'n'})
        color_reply = lower(strtrim(input( ...
            ['Include colour in the model (chromatic B/R spot features)? ' ...
             '[y/n, default y]: '], 's')));
        if isempty(color_reply), color_reply = 'y'; end
    end
    quick_color = strcmp(color_reply, 'y');
    cfg = config(quick_color, optics);

    fprintf('\nSkipping Stages 1-5 (Training). Using the pre-built shipped models.\n');
    if ~exist(fullfile(cfg.paths.models, decision_bounds_filename(cfg, 1)), 'file')
        cfg_other = config(~quick_color, optics);
        if exist(fullfile(cfg_other.paths.models, decision_bounds_filename(cfg_other, 1)), 'file')
            if quick_color
                fprintf([ ...
                    'No shipped colour-trained bounds found; quick mode will run\n' ...
                    'ACHROMATIC instead. Choose ''full'' mode to train the colour model.\n']);
            else
                fprintf([ ...
                    'No shipped achromatic-only bounds found; quick mode will run\n' ...
                    'COLOUR instead. Choose ''full'' mode to train an achromatic-only model.\n']);
            end
            cfg = cfg_other;
        end
    end
    R_near = []; R_far = []; col = [];
    coeff_s1 = [];   % quick mode: plot_stage1 uses the shipped transform + a single image
end

%% --- PLOTTING STAGES 1-5 ---
ecc = 1;
% plot_stage1 and plot_stage1b_gradients split the same two ways: in full mode they
% use the transform just learned plus pixels from all images, in quick mode the
% shipped transform plus a single image. (The 1b gradient structure is illustrative
% -- it is not itself a pipeline stage.)
fprintf('-> Plotting Stage 1 (colour transforms)...\n');
plot_stage1(cfg, coeff_s1);
fprintf('-> Plotting Stage 1b (multi-scale gradient structure)...\n');
plot_stage1b_gradients(cfg, coeff_s1);
fprintf('-> Plotting Stage 2 (feature priors)...\n');
plot_stage2(cfg, ecc);
fprintf('-> Plotting Stage 3 (near/far pairs)...\n');
plot_stage3(cfg, ecc);

% Points for the Stage 5 plots. Full mode reuses the exact pairs the bounds
% trained on (all images, captured above). Quick mode used the shipped bounds
% without training, so it samples a representative set from a single image.
if isempty(R_near)
    fprintf('\n--- Sampling patch responses for Stage 5 plots ---\n');
    [R_near, R_far, col] = compute_demo_responses(cfg, ecc);
else
    fprintf('\n--- Stage 5 plots use the %d near / %d far training pairs ---\n', ...
        size(R_near, 1), size(R_far, 1));
end

fprintf('-> Plotting Stage 5 (intermediate spot/edge/border DVs)...\n');
plot_stage5_intermediate(cfg, ecc, R_near, R_far, col);
fprintf('-> Plotting Stage 5 (trained decision bounds)...\n');
plot_stage5(cfg, ecc, R_near, R_far, col);
drawnow;

% --- 1. check the shipped (or newly trained) artifacts are present ---
% The bin file's name records whether the optics were applied when it was built.
if cfg.optics.apply, bins_file = 'AHEO_bins.mat'; else, bins_file = 'AHE_bins.mat'; end
needed_files = {prior_filename(cfg, 1), ...
                decision_bounds_filename(cfg, 1), bins_file};
is_present = cellfun(@(f) exist(fullfile(cfg.paths.models, f), 'file') > 0, needed_files);
if ~all(is_present)
    error('demo:missingArtifacts', ...
        ['Missing trained artifacts in data/models: %s\n' ...
         'Run pipeline stages s1-s5 first by setting run_training_stages=true, or restore data/models.'], ...
        strjoin(needed_files(~is_present), ', '));
end
fprintf('Trained model artifacts found in %s\n', cfg.paths.models);

% --- 2. same/different discrimination on random texture pairs ---
fprintf('\n--- Stage 6: Same/Different Discrimination on Texture Pairs ---\n');
plot_stage6_pairs(cfg, ecc);
drawnow;

% --- 3. run the segmentation stage (s7) on GTR images ---
% Randomize the GTR image draws so stage 7 builds different textures each run.
% (MATLAB starts every session from the same default RNG state, so a shuffle -- not
% just the absence of a fixed seed -- is what makes the images vary.)
rng('shuffle');
% Brodatz is grayscale (R=G=B): every ABR channel is then a fixed scalar multiple of
% the same gray image, so the chromatic spot DV would add only noise. Use Fabric
% (colour) when the colour model is on, so it has real chromatic signal to work with.
if cfg.features.color
    itype = 2;  db_name = 'Fabric';
else
    itype = 3;  db_name = 'Brodatz';
end
n_gtr_images = 3;   % GTR images to segment and show (small, for a quick demo)

fprintf('\n--- Stage 7: GTR Segmentation (%s) ---\n', db_name);
fprintf('Builds GTR (grown-texture-region) images from %s source textures. For each, learns\n', db_name);
fprintf('a grouping criterion and mutual-similarity weight from that image alone (proximity\n');
fprintf('as ground truth), then groups its patches into regions at the fixed parameters\n');
fprintf('chosen by stage 7 over many GTR images (offset %.2f, confidence %.2f, merge %.2f).\n', ...
    cfg.segment.group_offset, cfg.segment.confidence, cfg.segment.merge);
n_correct = plot_stage7(cfg, itype, ecc, n_gtr_images);
fprintf('\nStage 7 Result: %.0f%% of regions segmented exactly right (%d images)\n', ...
    100 * mean(n_correct) / cfg.gtr.n_regions, n_gtr_images);
drawnow;

% --- 4. apply the same segmentation to a natural image (self-supervised, no ground truth) ---
fprintf('\n--- Stage 8: Natural-Image Segmentation ---\n');
fprintf('Running the same self-supervised segmentation (64x64 patches) on a natural image.\n');
fprintf('It has no ground-truth regions, so gcopt/wmopt are still learned from proximity,\n');
fprintf('and the fixed grouping parameters are the same as in Stage 7.\n');
plot_stage8_natural(cfg, ecc);

fprintf('\nDemo Complete! Check the generated figure windows.\n');
