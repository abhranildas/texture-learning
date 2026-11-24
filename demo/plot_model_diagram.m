function plot_model_diagram(cfg)
% PLOT_MODEL_DIAGRAM  Flowchart of how the features and decision variables (DVs)
%   are combined into the final same/different DV.
%   plot_model_diagram(cfg)
%
%   Left column: the individual features of a patch pair. Spot and edge features
%   enter as histogram log-likelihood ratios (LLRs); the two border responses
%   enter directly (vislab.nat_stat_bayes.dv_border). Each later box is a
%   quadratic decision bound trained in stage 5 (s5_train_decision_vars) on the
%   outputs of the boxes that point into it; power (Fourier power similarity)
%   joins at the content DV. The final DV (border + content,
%   decision_bounds.border_content) is the pairwise similarity the segmentation
%   uses. With cfg.features.color on, the
%   spot DV is built in two steps: achromatic and chromatic sub-DVs, then a bound
%   over the two. With cfg.features.pca_gradient on, the separate H/V steerable
%   filters at each scale feed the learned PCs; their large / mid / small gradient
%   magnitudes and the 1 px edge mag merge into the multi-scale gradient DV, which
%   joins the bar features in the gradient DV.
%
% Inputs
%   cfg  config struct (uses cfg.features).
% Output
%   none (draws the figure)
%
% See also S5_TRAIN_DECISION_VARS, PAIR_RESPONSES, LOAD_DV_HANDLES

    names = cfg.features.names;
    color = ~isempty(cfg.features.spot_chrom_dims);

    % --- column layout: features, then one column per combining step ---
    has_pc = ~isempty(cfg.features.pc_grad_dims);   % gradient-PCA edge features
    fw = 2.6 + 1.0 * has_pc; dw = 2.2;          % feature / DV box widths
    c_h = 2 + color;  c_e = 2 + 2 * has_pc;         % columns of the spot and gradient DVs
    c_c = max(c_h, c_e) + 1;  c_bc = c_c + 1;        % columns of c, bc
    n_dv_cols = c_bc - 1;
    col_x = [fw/2 + 0.2, fw + 0.2 + 1.2 + dw/2 + (0:n_dv_cols-1) * (dw + 1.0)];

    nodes = struct('key', {}, 'x', {}, 'y', {}, 'w', {}, 'h', {}, 'lab', {});
    bh = 0.55;  lh = 0.32;                      % one-line box height, extra per line
    edges = cell(0, 2);
    y = 0;                                      % feature rows, top to bottom
    dy = 0.7; gap = 0.5;

    % feature group -> DV in column 2
    function [ys, keys] = add_group(prefix, labs)
        n = numel(labs); ys = zeros(1, n); keys = cell(1, n);
        for k = 1:n
            y = y - dy; ys(k) = y; keys{k} = sprintf('%s%d', prefix, k);
            nodes(end+1) = struct('key', keys{k}, 'x', col_x(1), 'y', y, 'w', fw, ...
                'h', bh, 'lab', {labs(k)}); %#ok<AGROW>
        end
        y = y - gap;
    end
    function add_dv(key, col, yy, lab, from)
        nodes(end+1) = struct('key', key, 'x', col_x(col), 'y', yy, 'w', dw, ...
            'h', bh + lh * (numel(lab) - 1), 'lab', {lab});
        for k = 1:numel(from), edges(end+1, :) = {from{k}, key}; end
    end

    [ys, ks] = add_group('sa', names(cfg.features.spot_achr_dims));
    if color
        add_dv('ha', 2, mean(ys), {'achromatic spot DV'}, ks);
        [ys2, ks2] = add_group('sc', names(cfg.features.spot_chrom_dims));
        add_dv('hb', 2, mean(ys2), {'chromatic spot DV'}, ks2);
        add_dv('h', c_h, mean([ys ys2]), {'spot DV'}, {'ha', 'hb'});
    else
        add_dv('h', c_h, mean(ys), {'spot DV'}, ks);
    end
    if has_pc
        % the separate H/V steerable filters at every scale feed the learned PCs,
        % and the sigma = cfg.dv.sd1 filters also feed the 1 px edge mag; those four
        % magnitudes merge into the multi-scale gradient DV, which joins the bar
        % features in the gradient DV
        sd = cfg.pcgrad.sd_list;
        % one box per scale, holding its H and V steerable filters
        f_lab = arrayfun(@(s) sprintf('H & V gradient filters (%dpx)', s), sd, ...
            'UniformOutput', false);
        [ys1, ks1] = add_group('sf', f_lab);
        y_pg = mean(ys1);
        ms_dims = cfg.features.ms_grad_dims;        % [edge mag, PC large, mid, small]
        ms_keys = cell(1, numel(ms_dims));
        i1 = sd == cfg.dv.sd1;                      % the filters the edge mag uses
        % the 1 px edge mag sits level with its filters' box; the PCs stack below it
        y_ms = ys1(i1);
        for m = 1:numel(ms_dims)
            ms_keys{m} = sprintf('ms%d', m);
            if ismember(ms_dims(m), cfg.features.pc_grad_dims)
                from = ks1;                         % every filter feeds every PC
                ms_lab = names(ms_dims(m));
                y_ms = y_ms - dy;  y_box = y_ms;
            else
                from = ks1(i1);
                ms_lab = {sprintf('%dpx gradient mag', cfg.dv.sd1)};
                y_box = ys1(i1);
            end
            add_dv(ms_keys{m}, 2, y_box, ms_lab, from);
        end
        add_dv('pg', 3, y_pg + dy, {'multi-scale gradient DV'}, ms_keys);
        % the bar features sit below the multi-scale gradient DV, in its column
        bar_names = names(setdiff(cfg.features.edge_dv_dims, ms_dims, 'stable'));
        ks = cell(1, numel(bar_names));
        for kb = 1:numel(bar_names)
            ks{kb} = sprintf('ed%d', kb);
            nodes(end+1) = struct('key', ks{kb}, 'x', col_x(3), 'y', y_pg + dy - kb * dy - 0.3, ...
                'w', dw, 'h', bh, 'lab', {bar_names(kb)}); %#ok<AGROW>
        end
        add_dv('e', c_e, y_pg + dy - (numel(bar_names) + 1) * dy / 2, {'gradient DV'}, ...
            [{'pg'}, ks]);
    else
        [ys, ks] = add_group('ed', names(cfg.features.edge_dv_dims));
        add_dv('e', c_e, mean(ys), {'gradient DV'}, ks);
    end

    function yy = yv(key)       % nested, so it sees nodes added after this point
        yy = nodes(strcmp({nodes.key}, key)).y;
    end
    add_dv('p', c_e, yv('e') - 2 * dy, {'power'}, {});     % power sits under the gradient DV
    add_dv('c', c_c, yv('e'), {'content DV'}, {'h', 'e', 'p'});
    % border DV above the content DV; its two feeders just to its left, above
    % anything already in that column
    x_l = col_x(c_c - 1);
    y_col = [nodes(abs([nodes.x] - x_l) < 1e-9).y, -Inf];
    y_b = max(yv('c') + 3 * dy, max(y_col) + 2 * dy);
    b_lab = {'border edge energy', 'off-border edge energy'};
    for kb = 1:2
        nodes(end+1) = struct('key', sprintf('bd%d', kb), 'x', x_l, ...
            'y', y_b + (1.5 - kb) * dy, 'w', dw, 'h', bh, 'lab', {b_lab(kb)}); %#ok<AGROW>
    end
    add_dv('b', c_c, y_b, {'border DV'}, {'bd1', 'bd2'});
    add_dv('bc', c_bc, mean([yv('c'), yv('b')]), {'border + content DV'}, {'c', 'b'});

    % --- draw ---
    y_lo = min([nodes.y]) - 0.8;  y_hi = max(max([nodes.y]) + 0.8, 0);
    x_hi = col_x(c_bc) + dw/2 + 1.9;
    figure('Name', 'Model: how features and DVs combine', 'Color', 'w', ...
        'Position', [100 80 1300 max(450, 55 * (y_hi - y_lo))]);
    axes('Position', [0.01 0.01 0.98 0.9]); hold on; axis off;
    xlim([0 x_hi]); ylim([y_lo y_hi]);

    for i = 1:numel(nodes)
        nd = nodes(i);
        fc = [0.93 0.95 1];
        rectangle('Position', [nd.x - nd.w/2, nd.y - nd.h/2, nd.w, nd.h], 'Curvature', 0.2, ...
            'FaceColor', fc, 'EdgeColor', [0.3 0.3 0.3]);
        text(nd.x, nd.y, nd.lab, 'HorizontalAlignment', 'center', 'FontSize', 9, ...
            'FontWeight', 'bold');
    end
    pos = @(key) nodes(strcmp({nodes.key}, key));
    for i = 1:size(edges, 1)
        a = pos(edges{i, 1}); b = pos(edges{i, 2});
        plot([a.x + a.w/2, b.x - b.w/2], [a.y, b.y], 'k-', 'LineWidth', 0.8);
    end
    bc = pos('bc');
    local_arrow([bc.x + bc.w/2, bc.y], [bc.x + bc.w/2 + 0.6, bc.y]);
    text(bc.x + bc.w/2 + 0.7, bc.y, {'same /', 'different'}, 'FontSize', 9, 'FontWeight', 'bold');

    sgtitle('Model: how features and decision variables combine');
end

% ------------------------------------------------------------------------------
function local_arrow(p0, p1)
% Line from P0 to P1 with a filled arrowhead at P1 (data units).
    plot([p0(1) p1(1)], [p0(2) p1(2)], 'k-', 'LineWidth', 0.8);
    d = (p1 - p0) / norm(p1 - p0);  n = [-d(2) d(1)];
    L = 0.15; W = 0.05;
    tip = [p1; p1 - L*d + W*n; p1 - L*d - W*n];
    patch(tip(:, 1), tip(:, 2), 'k', 'EdgeColor', 'none');
end
