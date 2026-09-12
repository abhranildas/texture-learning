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

    listings = cell(1, numel(cfg.natural.sets));
    n_files = 0;
    for set_idx = 1:numel(cfg.natural.sets)
        listings{set_idx} = dir(fullfile(cfg.paths.natural_images, ...
            [cfg.natural.sets{set_idx} '_*.png']));
        n_files = n_files + numel(listings{set_idx});
    end
    files = cell(1, n_files);
    idx = 0;
    for set_idx = 1:numel(listings)
        listing = listings{set_idx};
        for file_idx = 1:numel(listing)
            idx = idx + 1;
            files{idx} = fullfile(listing(file_idx).folder, listing(file_idx).name);
        end
    end
    if isempty(files)
        error('texture_learning:noNaturalImages', ...
            'No natural images found in %s (looked for %s_*.png).', ...
            cfg.paths.natural_images, strjoin(cfg.natural.sets, ', '));
    end
end
