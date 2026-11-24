function migrate_saved_names(models_dir)
% MIGRATE_SAVED_NAMES  One-off rename of the variables and fields stored in data/models.
%   migrate_saved_names()
%   migrate_saved_names(models_dir)
%
%   Rewrites each trained-model file in place with the readable names the code now
%   uses (docs/repo-cleanup.md, item 0.3.12). Values and field order are unchanged;
%   only names change. Idempotent: a file that no longer holds an old name is
%   skipped, so running it twice is harmless. Bill-imported files (*_bill.mat) are
%   migrated the same way.
%
%     decision_bounds_*.mat  variable dbnd -> decision_bounds, fields
%                            h -> spot, ha -> spot_achr, hb -> spot_chrom,
%                            pg -> ms_grad, ms_n -> n_ms_grad, e -> edge,
%                            c -> content, b -> border, bc -> border_content,
%                            spot_achr_n -> n_spot_achr
%     AHE*_bins*.mat         variable btype -> bound_type
%     gradient_pca*.mat      variable pcg -> gradient_pca
%     priors_*.mat           N<tag> -> cdf_<feature>, e<tag> -> edges_<feature>
%                            (see PRIOR_NAMES below; coeff unchanged)
%
%   Input
%     models_dir  folder to migrate (default: this repo's data/models).
%
% See also CONFIG, LOAD_DV_HANDLES, FINALIZE_PRIORS, S4_OPTIMIZE_BINS

    if nargin < 1 || isempty(models_dir)
        models_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data', 'models');
    end

    bound_fields = {'h', 'spot'; 'ha', 'spot_achr'; 'hb', 'spot_chrom'; 'pg', 'ms_grad';
        'ms_n', 'n_ms_grad'; 'e', 'edge'; 'c', 'content'; 'b', 'border';
        'bc', 'border_content'; 'spot_achr_n', 'n_spot_achr'};
    for f = list(models_dir, 'decision_bounds_*.mat')
        S = load(f{1});
        if ~isfield(S, 'dbnd'), skip(f{1}); continue; end
        decision_bounds = rename_fields(S.dbnd, bound_fields);
        save(f{1}, 'decision_bounds');
        done(f{1});
    end

    for f = list(models_dir, 'AHE*_bins*.mat')
        rename_variables(f{1}, {'btype', 'bound_type'});
    end

    for f = list(models_dir, 'gradient_pca*.mat')
        rename_variables(f{1}, {'pcg', 'gradient_pca'});
    end

    names = prior_names();
    prior_vars = [strcat('N', names(:, 1)), strcat('cdf_', names(:, 2));
                  strcat('e', names(:, 1)), strcat('edges_', names(:, 2))];
    for f = list(models_dir, 'priors_*.mat')
        rename_variables(f{1}, prior_vars);
    end
end

function names = prior_names()
% Old priors-file tag -> feature name (feature index in cfg.features.names).
    names = {'a', 'a_pixel';                 % 1
             'b', 'b_pixel';                 % 2
             'r', 'r_pixel';                 % 3
             'm', 'edge_mag';                % 5
             'o', 'edge_ori';                % 6
             'mo', 'edge_mag_ori';           % 7
             'm2', 'bar_mag';                % 9
             'o2', 'bar_ori';                % 10
             'mo2', 'bar_mag_ori';           % 11
             'cs1', 'cs_ratio_small';        % 12
             'cs2', 'cs_linear_small';       % 13
             'cs4', 'cs_linear_large';       % 14
             'pc1', 'pc1';                   % 15, PC large gradient mag
             'pc2', 'pc2';                   % 16, PC mid
             'pc3', 'pc3'};                  % 17, PC small
end

function rename_variables(file, map)
% Rename the file's top-level variables per map {old, new; ...}, keeping the rest.
    S = load(file);
    present = isfield(S, map(:, 1));
    if ~any(present), skip(file); return; end
    S = rename_fields(S, map(present, :));
    save(file, '-struct', 'S');
    done(file);
end

function s = rename_fields(s, map)
% Rename fields per map {old, new; ...} in place, keeping their order.
    names = fieldnames(s);
    [hit, where] = ismember(names, map(:, 1));
    names(hit) = map(where(hit), 2);
    s = cell2struct(struct2cell(s), names, 1);
end

function files = list(folder, pattern)
    d = dir(fullfile(folder, pattern));
    files = fullfile({d.folder}, {d.name});
end

function skip(file)
    [~, name, ext] = fileparts(file);
    fprintf('  already migrated: %s%s\n', name, ext);
end

function done(file)
    [~, name, ext] = fileparts(file);
    fprintf('  migrated:         %s%s\n', name, ext);
end
