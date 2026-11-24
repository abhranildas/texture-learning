function [raw_filt, pc_filt, K] = pc_filter_images(pcg)
% PC_FILTER_IMAGES  Exact images of the multi-scale steerable filters and of the
%   learned gradient PC filters, for display.
%   [raw_filt, pc_filt, K] = pc_filter_images(pcg)
%
%   Each filter is the response of the model's own filtering
%   (vislab.lib.multiscale_grad_responses) to a single bright pixel, so it is
%   exactly what the model applies. Each PC filter is the weighted sum of the raw
%   filters by its PCA coefficients (signs fixed by s1b_learn_gradient_pca).
%
% Input
%   pcg  learned PCA struct (s1b_learn_gradient_pca): .sd_list, .nsd, .coeff.
% Outputs
%   raw_filt  1 x 2n cell of K x K filters, [H at sd_list, V at sd_list].
%   pc_filt   1 x 2n cell of K x K PC filters, PC1 first.
%   K         filter image size (odd, centred).
%
% See also PLOT_STAGE1B_GRADIENTS, PLOT_STAGE2, S1B_LEARN_GRADIENT_PCA
    nf = size(pcg.coeff, 2);
    K = pcg.nsd * max(pcg.sd_list) + 1;
    L = 2 * K - 1;
    delta = zeros(L);  delta(K, K) = 1;
    imp = vislab.lib.multiscale_grad_responses(delta, pcg.sd_list, pcg.nsd);
    imp = imp(ceil(K/2):ceil(K/2)+K-1, ceil(K/2):ceil(K/2)+K-1, :);   % K x K x nf
    raw_filt = squeeze(num2cell(imp, [1 2]))';
    pc_filt = cell(1, nf);
    for c = 1:nf
        pc_filt{c} = sum(imp .* reshape(pcg.coeff(:, c), [1 1 nf]), 3);
    end
end
