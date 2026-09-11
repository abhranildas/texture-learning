function Y = predictTwin(net, fcParams, X1, X2)
% PREDICTTWIN  Twin-network similarity prediction, inference mode.
%   Y = predictTwin(net, fcParams, X1, X2)
%
%   Passes each image through the shared twin subnetwork via predict (not forward),
%   so no autodiff trace is kept. Use predictTwin for inference/evaluation; use
%   forwardTwin during training (needs the trace for dlgradient).
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
%   See also FORWARDTWIN, POOLSTATS

% Pass each image through the twin subnetwork, then pool its feature map to
% mean+std texture statistics (L2-normalized) via poolStats.
Y1 = poolStats(predict(net, X1));
Y2 = poolStats(predict(net, X2));

% Subtract the feature vectors.
Y = abs(Y1 - Y2);

% Pass result through a fullyconnect operation.
Y = fullyconnect(Y, fcParams.FcWeights, fcParams.FcBias);

% Convert to probability between 0 and 1.
Y = sigmoid(Y);

end
