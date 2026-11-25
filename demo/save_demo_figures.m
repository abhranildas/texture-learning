function save_demo_figures(cfg)
% SAVE_DEMO_FIGURES  Save every open demo figure as a PNG in docs/demo_figures,
%   for the README.
%   save_demo_figures(cfg)
%
%   Each figure is named by the part of its 'Name' before the colon, lower-cased
%   with spaces as underscores: 'Stage 5A: ...' -> stage_5a.png, 'Model: ...' ->
%   model.png. If two open figures share a name, the newest one is saved.
%   Saved at 96 dpi: the Stage 2 kernel insets are pixel-sized axes and do not
%   render at other export resolutions.
%
% Inputs
%   cfg  config struct (the repo root is two levels above cfg.paths.models).
% Output
%   none (writes docs/demo_figures/*.png)
%
% See also RUN_DEMO
    repo_root = fileparts(fileparts(cfg.paths.models));    % <repo>/data/models
    out_dir = fullfile(repo_root, 'docs', 'demo_figures');
    if ~isfolder(out_dir), mkdir(out_dir); end
    figs = findall(groot, 'Type', 'figure');      % newest first
    saved = {};
    for f = figs'
        name = strtok(f.Name, ':');
        if isempty(name), continue; end
        slug = lower(strrep(strtrim(name), ' ', '_'));
        if ismember(slug, saved), continue; end   % an older figure of the same name
        exportgraphics(f, fullfile(out_dir, [slug '.png']), 'Resolution', 96);
        saved{end+1} = slug; %#ok<AGROW>
    end
    fprintf('Saved %d figures to %s\n', numel(saved), out_dir);
end
