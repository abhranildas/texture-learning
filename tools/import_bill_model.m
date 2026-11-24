function import_bill_model(bill_root)
% IMPORT_BILL_MODEL  Replace this repo's trained model files with Bill's.
%   import_bill_model()
%   import_bill_model(bill_root)
%
%   Converts Bill's trained artifacts (Bill's code/texture-learning-new) into this
%   repo's formats and writes them to data/models with a "_bill" tag, beside this
%   repo's trained files (cfg.bill_compat selects them; see bins_filename):
%     decision_bounds_ecc_1_otf_bill.mat        achromatic DVs, from dbnd{h,e,c,b,bc}NO1
%     decision_bounds_ecc_1_color_otf_bill.mat  colour DVs, from dbnd{ah,bh,ch,ce,cc,cb,cbc}NO1
%     AHEO_bins_bill.mat               adaptive bins, from AHEO5<feature><ecc>, ecc 1/2/4/8
%     bill_lms2abr.mat                 LMS->ABR rotation coeff, from his
%                                      cdfs_abr_mo13_mo23_cs33_otf.mat
%   His fixed grouping parameters are not imported: check_bill_segmentation reads
%   them from his seg_11_8_26_1_1.mat.
%   The border bounds are Bill's near-and-far ones (borderflg = 1), which his
%   current segmentation runs use. Bill's model was trained and run with the eye
%   optics on, so the files get the optics-on names (config(..., true)).
%   Bill's files are only read.
%
%   Bill's model also uses power suppression b0 = 5e-5 and edge DV features
%   [5 9 10 11]; config.m must match (cfg.dv.power_suppress,
%   cfg.features.edge_dv_dims) for these files to be used consistently.
%
%   Input
%     bill_root  folder holding Bill's code (default: the sibling "Bill's code").
%
% See also LOAD_DV_HANDLES, DECISION_BOUNDS_FILENAME, CAPTURE_BILL_SEGMENTATION

    repo_root = fileparts(fileparts(mfilename('fullpath')));
    if nargin < 1 || isempty(bill_root), bill_root = fullfile(repo_root, '..', "Bill's code"); end
    src = fullfile(bill_root, 'texture-learning-new');
    addpath(repo_root);
    setup();
    cfg = config(false, true);                 % achromatic, optics on
    cfg_color = config(true, true);            % colour, optics on
    cfg.bill_compat = true;                    % "_bill" file names
    cfg_color.bill_compat = true;
    models = cfg.paths.models;
    bound = @(name, var) getfield(load(fullfile(src, [name '.mat']), var), var);

    % --- achromatic decision bounds (spot dims [1 13 14]) ---
    % Bill's bound names map to ours as dbndh -> spot, dbnde -> edge, dbndc -> content,
    % dbndb -> border, dbndbc -> border_content, dbndha/hb -> spot_achr/spot_chrom
    % (docs/segmentation-parity.md); n_spot_achr = number of achromatic spot dims.
    decision_bounds = struct('spot', bound('dbndhNO1', 'dbndh'), ...
        'edge', bound('dbndeNO1', 'dbnde'), ...
        'content', bound('dbndcNO1', 'dbndc'), 'border', bound('dbndbNO1', 'dbndb'), ...
        'border_content', bound('dbndbcNO1', 'dbndbc'), 'spot_dims', [1 13 14], 'n_spot_achr', 3);
    save(fullfile(models, decision_bounds_filename(cfg, 1)), 'decision_bounds');

    % --- colour decision bounds (spot dims [1 13 14 2 3]): achromatic and chromatic
    %     spot sub-DVs ha, hb, combined by h, as load_dv_handles composes them ---
    decision_bounds = struct('spot_achr', bound('dbndahNO1', 'dbndha'), ...
        'spot_chrom', bound('dbndbhNO1', 'dbndhb'), ...
        'spot', bound('dbndchNO1', 'dbndh'), 'edge', bound('dbndceNO1', 'dbnde'), ...
        'content', bound('dbndccNO1', 'dbndc'), 'border', bound('dbndcbNO1', 'dbndb'), ...
        'border_content', bound('dbndcbcNO1', 'dbndbc'), 'spot_dims', [1 13 14 2 3], ...
        'n_spot_achr', 3);
    save(fullfile(models, decision_bounds_filename(cfg_color, 1)), 'decision_bounds');

    % --- adaptive histogram bins, natural-image type 5, with optics ---
    eccs = [1 2 4 8];
    bound_type = 5;                             % histogram-bound type: natural images
    features = [1 2 3 5 6 7 9 10 11 13 14];     % the features Bill has bins for
    bin_bounds = cell(14, numel(eccs));
    n_bins = zeros(14, numel(eccs));
    for e = 1:numel(eccs)
        for f = features
            B = load(fullfile(src, sprintf('AHEO%d%d%d.mat', bound_type, f, eccs(e))), ...
                'bnds', 'nbnds');
            assert(numel(B.bnds) == B.nbnds, 'import_bill_model:bins', ...
                'AHEO%d%d%d.mat: nbnds disagrees with bnds', bound_type, f, eccs(e));
            bin_bounds{f, e} = B.bnds(:).';
            n_bins(f, e) = B.nbnds;
        end
    end
    save(fullfile(models, bins_filename(cfg)), 'bin_bounds', 'n_bins', 'eccs', 'bound_type');

    % --- Bill's LMS->ABR colour rotation (used when cfg.bill_compat is on) ---
    coeff = bound('cdfs_abr_mo13_mo23_cs33_otf', 'coeff');
    save(fullfile(models, 'bill_lms2abr.mat'), 'coeff');

    fprintf('Wrote Bill''s bounds and bins to %s\n', models);
end
