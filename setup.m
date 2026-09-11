function setup()
% SETUP  Put texture-learning and its dependencies on the MATLAB path.
%   Run once per MATLAB session before using the pipeline:
%       >> setup
%
%   Adds to the path:
%     * this repo (its +segmentation and +gtr packages, pipeline/, and twin-net/ --
%       the latter needs the Deep Learning Toolbox)
%     * data/models  (shipped trained artifacts: PCA/CDF/bin/DV .mat files)
%     * vislab (the shared code library) -- the +vislab package inside the
%       sibling vislab-common repo (the lab's local dev layout)
%
%   Also ensures the two required lab add-on toolboxes are available: if either is
%   missing, setup fetches the .mltbx from its latest GitHub release and installs it
%   automatically (matlab.addons.install):
%     * Integrate and Classify Normal Distributions  (classify_normals, quad2fun)
%     * Generalized chi-square distribution  (gx2*, used by the above)
%   Their File Exchange pages, used as the last-resort fallback, are the URLs in the
%   two ensure_addon_on_path calls below -- the single place they are written down.
%   (colorbarpzn, used by a demo plot, now ships inside vislab as vislab.lib.colorbarpzn.)
%
%   Takes no inputs and returns nothing; its whole effect is on the MATLAB path and,
%   if needed, on the installed add-ons. Safe to re-run -- every step is a no-op once
%   the thing it provides already resolves.
%
% See also CONFIG, RUN_DEMO, ADDPATH, MATLAB.ADDONS.INSTALL

    repo_root = fileparts(mfilename('fullpath'));
    addpath(repo_root);                                        % local +segmentation, +gtr
    addpath(fullfile(repo_root, 'pipeline'));                  % s1..s7 pipeline stages
    addpath(fullfile(repo_root, 'demo'));                      % run_demo plotting helpers
    addpath(fullfile(repo_root, 'twin-net'));                  % needs Deep Learning Toolbox
    addpath(genpath(fullfile(repo_root, 'data', 'models')));   % shipped .mat artifacts

    % --- shared lab library (vislab): a sibling folder next to this repo.
    %     If it isn't found, try to clone it automatically (needs git + network);
    %     if that fails too, warn with a manual clone command. ---
    vislab_pkg = locate_folder(repo_root, '+vislab');
    if isempty(vislab_pkg)
        vislab_pkg = fetch_commons(repo_root);
    end
    if isempty(vislab_pkg)
        warning('texture_learning:setup:noCommons', ...
            ['vislab-common not found and could not be fetched automatically. ', ...
            'Clone it next to this repo:  git clone https://github.com/abhranildas/vislab-common']);
    else
        % The package's PARENT goes on the path, which is what exposes vislab.lib.*
        % and vislab.nat_stat_bayes.* as a package namespace.
        addpath(fileparts(vislab_pkg));
    end

    % --- add-on toolboxes -----------------------------------------------------
    % For each: if its probe function already resolves, do nothing. Else try to add
    % an already-installed copy to the path (MATLAB does not always do this in
    % headless `matlab -batch` sessions). Else download the .mltbx from its latest
    % GitHub release and install it automatically. gx2 is handled first because
    % IntClassNorm depends on it. (colorbarpzn now lives in vislab, added above.)
    ensure_addon_on_path('gx2cdf', 'Generalized chi-square distribution*', ...
        'Generalized chi-square distribution (gx2)', ...
        'https://www.mathworks.com/matlabcentral/fileexchange/85028-generalized-chi-square-distribution', ...
        'abhranildas/gx2-matlab');
    ensure_addon_on_path('classify_normals', 'Integrate and Classify Normal Distributions*', ...
        'Integrate and Classify Normal Distributions', ...
        'https://www.mathworks.com/matlabcentral/fileexchange/84973-integrate-and-classify-normal-distributions', ...
        'abhranildas/IntClassNorm');

    % --- shared data store: vislab-common/data (~23 GB, obtained manually) ---
    if ~isfolder(fullfile(repo_root, '..', 'vislab-common', 'data'))
        warning('texture_learning:setup:noData', ...
            ['vislab-common/data not found next to this repo. It is the large (~23 GB) shared data store ', ...
             '(natural images + texture sheets); obtain it separately and place it in vislab-common/data ', ...
             '(see README). Code that reads it will fail until then.']);
    end
end

function folder = fetch_commons(repo_root)
% Auto-fetch the shared library by cloning the vislab-common repo as a sibling
% (../vislab-common); the +vislab package lives inside it. Needs git on the PATH
% and network access.
%
% Inputs
%   repo_root  absolute path to this repo's root folder, char
% Output
%   folder  absolute path to the cloned +vislab package, or '' if the clone
%           failed (the caller then warns)
    folder = '';
    repo_dir = fullfile(repo_root, '..', 'vislab-common');
    url = 'https://github.com/abhranildas/vislab-common.git';
    fprintf('vislab-common not found; trying to clone it to %s ...\n', repo_dir);
    [status, git_output] = system(sprintf('git clone "%s" "%s"', url, repo_dir));
    pkg_dir = fullfile(repo_dir, '+vislab');
    % A zero exit status is not enough on its own: check that the package really
    % landed, by looking for the +lib subpackage inside it.
    if status == 0 && isfolder(fullfile(pkg_dir, '+lib'))
        folder = pkg_dir;
        fprintf('Cloned vislab-common.\n');
    else
        fprintf(2, 'Could not auto-fetch vislab-common (git missing or offline?).\n%s\n', ...
            git_output);
    end
end

function folder = locate_folder(repo_root, name)
% Find an already-present package folder, trying the known dev layouts in order.
%
% Inputs
%   repo_root  absolute path to this repo's root folder, char
%   name       folder to look for, e.g. '+vislab', char
% Output
%   folder  absolute path to the first candidate that exists, or '' if none do.
%           Candidates, in order: inside the sibling vislab-common repo (the
%           canonical layout), inside this repo, then as a sibling of this repo
%           (both older dev layouts).
    candidates = {fullfile(repo_root, '..', 'vislab-common', name), ...
                  fullfile(repo_root, name), ...
                  fullfile(repo_root, '..', name)};
    folder = '';
    for i = 1:numel(candidates)
        if isfolder(candidates{i})
            folder = candidates{i};
            return;
        end
    end
end

function ensure_addon_on_path(probe_function, folder_pattern, toolbox_name, url, gh_repo)
% Ensure an add-on toolbox's functions are available.
%   1. If PROBE_FUNCTION already resolves, do nothing.
%   2. Else add an already-installed copy to the path (MATLAB does not always do
%      this in headless sessions) -- matching FOLDER_PATTERN under the add-ons dir.
%   3. Else, if GH_REPO ("owner/name") is given, download the .mltbx from that repo's
%      latest GitHub release and install it (matlab.addons.install), then re-add.
%   4. Else (still missing): open URL (File Exchange page) in the browser and warn.
%
% Inputs
%   probe_function  name of a function the toolbox provides, used to test whether
%                   it already resolves, char
%   folder_pattern  dir() pattern matching the toolbox's install folder under the
%                   MATLAB add-ons directory, char
%   toolbox_name    display name, used in messages, char
%   url             File Exchange page, opened in a browser as the last resort, char
%   gh_repo         "owner/name" GitHub repo to pull the .mltbx release from;
%                   optional, char. Omit it to skip step 3.
% Output
%   none. The effect is on the MATLAB path and, in step 3, on the installed add-ons.
    if exist(probe_function, 'file') ~= 0
        return;                               % already on the path -- nothing to do
    end
    add_installed_to_path(folder_pattern);
    if exist(probe_function, 'file') ~= 0
        return;
    end
    if nargin >= 5 && ~isempty(gh_repo) && install_from_github_release(gh_repo, toolbox_name)
        add_installed_to_path(folder_pattern);
        if exist(probe_function, 'file') ~= 0
            return;
        end
    end
    if ~batchStartupOptionUsed                % don't pop a browser in headless (-batch) runs
        try, web(url, '-browser'); catch, end
    end
    warning('texture_learning:setup:missingToolbox', ...
        ['Required MATLAB toolbox "%s" not found (cannot find %s) and could not be ', ...
         'auto-installed. Install it (Add-On Explorer / File Exchange), then re-run ', ...
         'setup: %s'], toolbox_name, probe_function, url);
end

function add_installed_to_path(folder_pattern)
% Add an already-installed add-on's folder to the path. MATLAB usually does this
% itself, but not reliably in headless (-batch) sessions.
%
% Inputs
%   folder_pattern  dir() pattern matched against the MATLAB add-ons install
%                   directory, e.g. 'Generalized chi-square distribution*', char
% Output
%   none. Every matching subfolder is added to the path with its own subfolders.
    tb_dir = addons_toolboxes_dir();
    if isempty(tb_dir), return; end
    addon_dirs = dir(fullfile(tb_dir, folder_pattern));
    for i = 1:numel(addon_dirs)
        if addon_dirs(i).isdir
            addpath(genpath(fullfile(tb_dir, addon_dirs(i).name)));
        end
    end
end

function ok = install_from_github_release(gh_repo, toolbox_name)
% Download the .mltbx asset from a repo's latest GitHub release and install it as
% a MATLAB add-on. Needs network access.
%
% Inputs
%   gh_repo       "owner/name" of the GitHub repo, char
%   toolbox_name  display name, used in the progress messages, char
% Output
%   ok  true if the add-on was downloaded and installed; false on any failure
%       (the reason is printed to stderr, and nothing is left installed)
    ok = false;
    try
        opts = weboptions('UserAgent', 'texture-learning-setup', 'Timeout', 60);
        gh_release = webread(sprintf('https://api.github.com/repos/%s/releases/latest', ...
            gh_repo), opts);
        % webread returns the asset list as a struct array or a cell array of
        % structs depending on whether the entries share a field layout.
        assets = gh_release.assets;
        dl_url = '';
        for i = 1:numel(assets)
            if iscell(assets)
                release_asset = assets{i};
            else
                release_asset = assets(i);
            end
            if endsWith(release_asset.name, '.mltbx')
                dl_url = release_asset.browser_download_url;
                break;
            end
        end
        if isempty(dl_url)
            fprintf(2, 'setup: no .mltbx asset in %s''s latest release.\n', gh_repo);
            return;
        end
        fprintf('setup: downloading %s (%s) from GitHub ...\n', ...
            toolbox_name, gh_release.tag_name);
        mltbx_file = [tempname, '.mltbx'];
        websave(mltbx_file, dl_url, opts);
        matlab.addons.install(mltbx_file);
        delete(mltbx_file);
        fprintf('setup: installed %s.\n', toolbox_name);
        ok = true;
    catch err
        fprintf(2, 'setup: could not auto-install %s from GitHub (%s).\n', ...
            toolbox_name, err.message);
    end
end

function addons_dir = addons_toolboxes_dir()
% Best-effort path to the "<...>/MATLAB Add-Ons/Toolboxes" install directory,
% without hardcoding a username.
%
% Inputs
%   none
% Output
%   addons_dir  absolute path to the add-ons Toolboxes folder, or '' if it could
%               not be determined. Tries the add-ons install-folder setting first,
%               then falls back to the parent folder of an add-on function that
%               already resolves.
    addons_dir = '';
    try
        root = settings().matlab.addons.InstallationFolder.ActiveValue; % "<...>/MATLAB Add-Ons"
        candidate = fullfile(root, 'Toolboxes');
        if isfolder(candidate), addons_dir = candidate; return; end
        if isfolder(root),      addons_dir = root;      return; end
    catch
        % settings tree not available in this release -- use the fallback below
    end
    for probe = {'gx2cdf', 'gx2pdf', 'gx2inv'}     % gx2 auto-registers; use it as an anchor
        probe_path = which(probe{1});
        if ~isempty(probe_path)
            % ...\Toolboxes\<addon>\fn.m -> ...\Toolboxes
            addons_dir = fileparts(fileparts(probe_path));
            return;
        end
    end
end
