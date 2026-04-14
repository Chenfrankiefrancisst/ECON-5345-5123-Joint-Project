function t_stat = manual_adf(x, n_lags)
% MANUAL_ADF  Augmented Dickey-Fuller test statistic (no toolbox required).
%
%   t_stat = manual_adf(x, n_lags)
%
%   Runs the ADF regression with a constant and n_lags augmentation terms:
%     Delta x_t = a + rho * x_{t-1} + sum_{j=1..p} phi_j * Delta x_{t-j} + e_t
%   and returns the t-statistic on rho.
%
%   Decision rule: reject unit root if t_stat < critical value.
%   Approximate 1% CV for ADF with constant, T~500: -3.44.
%                5% CV: -2.87,  10% CV: -2.57 (MacKinnon 1996).

    x = x(:);
    dx = diff(x);

    % Dependent: Delta x_t (drop first n_lags observations)
    Y = dx(n_lags+1:end);
    % Lagged level x_{t-1}
    X = x(n_lags+1:end-1);
    % Add constant
    X = [ones(length(Y), 1), X];

    % Augmentation: lagged first differences
    for j = 1:n_lags
        X = [X, dx(n_lags+1-j:end-j)]; %#ok<AGROW>
    end

    % OLS
    b  = X \ Y;
    e  = Y - X * b;
    s2 = (e' * e) / (length(Y) - size(X, 2));
    se = sqrt(diag(s2 * inv(X' * X))); %#ok<MINV>

    t_stat = b(2) / se(2);  % t-stat on the lagged-level coefficient
end
