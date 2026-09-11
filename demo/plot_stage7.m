function plot_stage7(cfg, out, method, itype, ecc)
% PLOT_STAGE7  Generate sample GTR images and show the ground-truth regions
%   next to the model's segmentation output.
%   plot_stage7(cfg, out, method, itype, ecc)
%
% Inputs
%   cfg    - config struct.
%   out    - struct from s7_segment_gtr, giving the (mc, dgc) merge-parameter
%            sweep (out.nregs5_ave, out.mc, out.dgc) to pick the optimum from.
%   method - self-supervised decision method, 'nc' or 'bc' (see self_sup_decision).
%   itype  - texture database id (load_texture_images itype).
%   ecc    - eccentricity divisor (patch geometry is divided by it).
% Output
%   none (draws the figure)
%
% See also S7_SEGMENT_GTR, SEGMENTATION.GROUP_PATCHES, OVERLAY_REGION_BOUNDARIES
    fprintf('Generating a sample GTR image and segmenting it for visual output...\n');

    [best, idx] = max(out.nregs5_ave, [], 'all', 'linear');
    [ki, li] = ind2sub(size(out.nregs5_ave), idx);
    mc_opt = out.mc(ki);
    dgc_opt = out.dgc(li);

    szp = cfg.gtr.szp;
    patch_size = cfg.patch.size / ecc;
    ntexr = cfg.gtr.n_regions;

    cstat = zeros(1,20); cstat(cfg.features.dv_dims) = 5;   % spot + edge DV dims
    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds(cstat, 1, ...
        double(cfg.optics.apply));
    dv = load_dv_handles(cfg, ecc, true);
    [imgr, imgg, imgb, nimg] = load_texture_images(cfg, itype, ecc);

    figure('Name', 'Stage 7: GTR Segmentation', 'Position', [400 200 1200 800]);

    ss_method = struct('nc', 'c_shft', 'ncb', 'bc').(method);

    n_examples = 3;
    for ex = 1:n_examples
        texs = gtr.sample_texture_ids(nimg, ntexr, 1);
        [~, map3] = gtr.grow_region_masks(szp, ntexr, 1, cfg.gtr.seed_radius, cfg.gtr.coverage);
        map = map3(:, :, 1);
        [pimg, px, py] = make_gtr_image(cfg, imgr, imgg, imgb, texs(1,:), map);

        phiall = segmentation.content_similarity_matrix(pimg, patch_size, px, py, bin_bounds, ...
            n_bins, dv.h, dv.e, dv.c, cfg);
        rho = segmentation.mutual_similarity(phiall);

        R = neighbor_far_responses(cfg, pimg, rho, map, bin_bounds, n_bins, dv);
        [qbs, qbd] = self_sup_decision(ss_method, R, dv);
        gc_vec = 0:0.8:8; wm_vec = 0:0.8:9.6;
        [~, ~, ~, pcnf] = nearfar_score_grid(qbs, qbd, R, gc_vec, wm_vec);
        [row_best, col_at] = max(pcnf, [], 2);
        [~, J] = max(row_best);
        gcopt = gc_vec(J); wmopt = wm_vec(col_at(J));

        [phi, dst] = segmentation.neighbor_similarity_matrix(pimg, patch_size, px, py, ...
            patch_size, bin_bounds, n_bins, dv, cfg);
        mu = (phi + wmopt * rho) .* (phi ~= 0);

        cc_opt = 1.1;
        [~, ~, groups2d] = segmentation.group_patches(mu, dst, gcopt + dgc_opt, cc_opt, ...
            patch_size, px, py, phiall, mc_opt);

        % pimg is LMS (true source colour: grayscale for Brodatz, colour for Fabric
        % etc -- see make_gtr_image); patch_to_rgb_display shows it as it really is.
        pimg_rgb = patch_to_rgb_display(cfg, pimg, 'lms');

        % Upsample maps to image resolution
        map_up = imresize(map, [size(pimg,1), size(pimg,2)], 'nearest');
        groups_up = imresize(groups2d, [size(pimg,1), size(pimg,2)], 'nearest');

        subplot(n_examples, 2, (ex-1)*2 + 1);
        image(pimg_rgb); axis image off; hold on;
        overlay_region_boundaries(map_up);
        if ex == 1, title('GTR Image (Ground Truth Regions)'); end

        subplot(n_examples, 2, (ex-1)*2 + 2);
        image(pimg_rgb); axis image off; hold on;
        overlay_region_boundaries(groups_up);
        if ex == 1, title('Segmented Output'); end

        drawnow; % update UI
    end

    sgtitle(sprintf('Stage 7: GTR Segmentation (Accuracy: %.1f%% fully-correct regions)', ...
        100 * best));
end
