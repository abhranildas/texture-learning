function y = apply_dv(dv_fun, X)
% APPLY_DV  Apply a quad2fun decision-variable handle to each row of X.
%   y = apply_dv(dv_fun, X)
%
% Inputs
%   dv_fun  quad2fun-style decision-variable handle; takes one row of X (as a
%           column vector) and returns a scalar
%   X       [N x d] rows to evaluate, one row per observation
% Output
%   y  [N x 1] dv_fun evaluated on each row of X
%
% See also QUAD2FUN, PLOT_STAGE5, PLOT_STAGE5_INTERMEDIATE
    y = zeros(size(X, 1), 1);
    for row = 1:size(X, 1)
        y(row) = dv_fun(X(row, :)');
    end
end
