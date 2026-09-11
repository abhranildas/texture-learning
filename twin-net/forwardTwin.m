function Y = forwardTwin(net, fcParams, X1, X2)
% FORWARDTWIN  Twin-network similarity prediction, training mode (records for autodiff).
%   Y = forwardTwin(net, fcParams, X1, X2)
%
%   Passes each image through the shared twin subnetwork via forward (not predict),
%   so batchnorm/dropout state and the autodiff trace needed by dlgradient are kept.
%   Use forwardTwin during training; use predictTwin for inference.
%
%   Inputs
%     net      - dlnetwork, the shared twin subnetwork.
%     fcParams - struct with fields FcWeights, FcBias for the final fullyconnect
%                (frozen name: also the field name train_net.m saves to
%                data/models/net_on_nat.mat -- do not rename).
%     X1, X2   - "SSCB" dlarray image batches, one patch per pair per array.
%
%   Output
%     Y - "CB" dlarray, predicted probability in (0,1) that each pair is similar
%         (near/same, closer to 1) vs dissimilar (far/different, closer to 0).
%
%   See also PREDICTTWIN, MODELLOSS, POOLSTATS

% Pass each image through the twin subnetwork, then pool its feature map to
% mean+std texture statistics (L2-normalized) via poolStats.
Y1 = poolStats(forward(net, X1));
Y2 = poolStats(forward(net, X2));

% Subtract the feature vectors
Y = abs(Y1 - Y2);

% Pass the result through a fullyconnect operation
Y = fullyconnect(Y, fcParams.FcWeights, fcParams.FcBias);

% Convert to probability between 0 and 1.
Y = sigmoid(Y);

end
