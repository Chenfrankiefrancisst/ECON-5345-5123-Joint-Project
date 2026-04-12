function se = lp_newey_west(X, resid, bandwidth)
% LP_NEWEY_WEST  Newey-West HAC standard errors for OLS coefficients.
%
%   se = lp_newey_west(X, resid, bandwidth)
%
%   Inputs:
%     X         — T x K regressor matrix (including constant)
%     resid     — T x 1 OLS residual vector
%     bandwidth — integer, number of lags for the Bartlett kernel
%                 Recommended for LP at horizon h: max(h, floor(4*(T/100)^(2/9)))
%
%   Output:
%     se — K x 1 vector of HAC standard errors
%
%   Reference: Newey & West (1987), Econometrica.
%   LP residuals are MA(h) by construction, so HAC correction is essential.

    [T, K] = size(X);

    % --- Meat of the sandwich: S = Gamma_0 + sum of weighted Gamma_j ---
    % Gamma_j = (1/T) * sum_{t=j+1}^{T} e_t * e_{t-j} * x_t * x_{t-j}'
    Xe = X .* resid;          % T x K,  each row = x_t * e_t
    S  = (Xe' * Xe) / T;     % Gamma_0

    for j = 1:bandwidth
        w = 1 - j / (bandwidth + 1);                   % Bartlett weight
        Gamma_j = (Xe(j+1:end, :)' * Xe(1:end-j, :)) / T;
        S = S + w * (Gamma_j + Gamma_j');               % symmetrise
    end

    % --- Sandwich: V = (X'X)^{-1} S (X'X)^{-1} * T ---
    XtX_inv = (X' * X) \ eye(K);
    V = XtX_inv * S * XtX_inv * T;

    se = sqrt(diag(V));
end
