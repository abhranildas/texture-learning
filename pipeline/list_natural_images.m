function files = list_natural_images(cfg)
% LIST_NATURAL_IMAGES  Full paths of all calibrated natural images across all sets.
%   files = list_natural_images(cfg)
%
%   Collects every <set>_*.png in cfg.paths.natural_images for each stem in
%   cfg.natural.sets. Shared by the natural-image pipeline stages (s1, s23, s4).
%
%   Inputs
%     cfg - config struct (uses cfg.paths.natural_images, cfg.natural.sets).
%
%   Output
%     files - cell array of full file paths.
%
%   See also S1_LEARN_COLOR_TRANSFORM, S23_LEARN_PRIORS_AND_PAIRS, S4_OPTIMIZE_BINS

    files = {};
    for set_idx = 1:numel(cfg.natural.sets)
        listing = dir(fullfile(cfg.paths.natural_images, [cfg.natural.sets{set_idx} '_*.png']));
        for file_idx = 1:numel(listing)
            files{end+1} = fullfile(listing(file_idx).folder, listing(file_idx).name); %#ok<AGROW>
        end
    end
    if isempty(files)
        error('texture_learning:noNaturalImages', ...
            'No natural images found in %s (looked for %s_*.png).', ...
            cfg.paths.natural_images, strjoin(cfg.natural.sets, ', '));
    end
end
