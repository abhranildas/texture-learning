function [loss, gradients_subnet, gradients_params] = modelLoss(net, fcParams, X1, X2, pair_labels)
% MODELLOSS  Twin-network loss and gradients for one training batch.
%   [loss, gradients_subnet, gradients_params] = modelLoss(net, fcParams, X1, X2, pair_labels)
%
%   Called via dlfeval so dlgradient can trace through forwardTwin. Binary
%   cross-entropy between the predicted similarity and the pair label.
%
%   Inputs
%     net         - dlnetwork, the shared twin subnetwork.
%     fcParams    - struct with fields FcWeights, FcBias for the final fullyconnect
%                   (frozen name, also the save field name in data/models/net_on_nat.mat).
%     X1, X2      - "SSCB" dlarray image batches, one patch per pair per array.
%     pair_labels - "CB" (or plain) label vector, 1 = similar (near/same),
%                   0 = dissimilar (far/different).
%
%   Outputs
%     loss             - scalar, binary cross-entropy loss.
%     gradients_subnet - gradients of loss w.r.t. net.Learnables.
%     gradients_params - gradients of loss w.r.t. fcParams.
%
%   See also FORWARDTWIN, TRAIN_NET

% Pass the image pair through the network.
Y = forwardTwin(net, fcParams, X1, X2);

% Calculate binary cross-entropy loss.
loss = crossentropy(Y, pair_labels, ClassificationMode="multilabel");

% Calculate gradients of the loss with respect to the network learnable
% parameters.
[gradients_subnet, gradients_params] = dlgradient(loss, net.Learnables, fcParams);

end
