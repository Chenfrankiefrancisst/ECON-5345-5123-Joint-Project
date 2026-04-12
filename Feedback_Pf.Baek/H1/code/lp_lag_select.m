function results = lp_lag_select(data, p_max, verbose)
% LP_LAG_SELECT  Lag selection via VAR-based AIC/BIC.
%
%   results = lp_lag_select(data, p_max)
%   results = lp_lag_select(data, p_max, verbose)
%
%   Estimates a reduced-form VAR(p) for p = 1, ..., p_max by OLS and
%   computes Akaike (AIC) and Bayesian (BIC) information criteria.
%
%   This serves as a cross-check for the LP lag length. Although LP does
%   not require a VAR specification, using the same lag length as the
%   AIC/BIC-optimal VAR ensures comparability with VAR-based results
%   in the literature (e.g., Caldara & Iacoviello, 2022).
%
%   Inputs:
%     data    — T x K matrix of variables (e.g., [log_GPR, log_IP, log_CPI]).
%               All variables should be in the same form used in the LP.
%     p_max   — maximum lag order to evaluate (e.g., 24).
%     verbose — (optional) logical, print results table (default: true).
%
%   Output:
%     results — struct with fields:
%       .p_aic    — optimal lag by AIC
%       .p_bic    — optimal lag by BIC
%       .aic      — p_max x 1 AIC values
%       .bic      — p_max x 1 BIC values
%       .p_range  — (1:p_max)'
%
%   Information criteria formulas:
%     AIC(p) = log|Sigma_p| + 2 * K^2 * p / T_eff
%     BIC(p) = log|Sigma_p| + K^2 * p * log(T_eff) / T_eff
%
%   where Sigma_p is the MLE covariance of VAR(p) residuals,
%   K = number of variables, T_eff = effective sample size.
%
%   Reference:
%     Luetkepohl, H. (2005). "New Introduction to Multiple Time Series
%     Analysis." Springer. Ch. 4.3 (Model Selection).

    if nargin < 3, verbose = true; end

    [T, K] = size(data);

    aic_vals = nan(p_max, 1);
    bic_vals = nan(p_max, 1);

    for p = 1:p_max
        % Build VAR(p) regression matrices
        % Y = [y_{p+1}, ..., y_T]'  (T_eff x K)
        % X = [1, y_t, y_{t-1}, ..., y_{t-p+1}]  for each t
        T_eff = T - p;
        if T_eff < K * p + 10
            % Too few observations for this lag order
            continue;
        end

        Y = data(p+1:end, :);         % T_eff x K
        X = ones(T_eff, 1);           % constant

        for lag = 1:p
            X = [X, data(p+1-lag:end-lag, :)]; %#ok<AGROW>
        end

        % OLS: B = (X'X)^{-1} X'Y
        B = X \ Y;
        E = Y - X * B;                % T_eff x K residuals

        % MLE covariance (no df correction for IC)
        Sigma = (E' * E) / T_eff;

        % Number of free parameters per equation: K*p + 1 (constant)
        % Total: K * (K*p + 1), but for IC we use K^2*p (lag params only)
        n_params = K * K * p;

        % Information criteria
        log_det = log(det(Sigma));
        aic_vals(p) = log_det + 2 * n_params / T_eff;
        bic_vals(p) = log_det + n_params * log(T_eff) / T_eff;
    end

    % Optimal lags
    [~, p_aic] = min(aic_vals);
    [~, p_bic] = min(bic_vals);

    % Print results
    if verbose
        fprintf('\n========================================\n');
        fprintf('  VAR LAG SELECTION (AIC / BIC)\n');
        fprintf('  Variables: K = %d, T = %d, p_max = %d\n', K, T, p_max);
        fprintf('========================================\n\n');
        fprintf('  %4s  %12s  %12s\n', 'Lag', 'AIC', 'BIC');
        fprintf('  %s\n', repmat('-', 1, 32));

        for p = 1:p_max
            marker = '';
            if p == p_aic && p == p_bic
                marker = ' <- AIC, BIC';
            elseif p == p_aic
                marker = ' <- AIC';
            elseif p == p_bic
                marker = ' <- BIC';
            end
            fprintf('  %4d  %12.4f  %12.4f%s\n', p, aic_vals(p), bic_vals(p), marker);
        end

        fprintf('\n  Optimal: AIC -> p = %d,  BIC -> p = %d\n', p_aic, p_bic);
        fprintf('  Baseline LP uses L = 12.\n');

        if p_aic ~= 12 || p_bic ~= 12
            fprintf('  NOTE: AIC/BIC differ from L=12. Consider reporting both.\n');
        else
            fprintf('  CONFIRMED: AIC/BIC consistent with L=12.\n');
        end
    end

    % Pack output
    results.p_aic   = p_aic;
    results.p_bic   = p_bic;
    results.aic     = aic_vals;
    results.bic     = bic_vals;
    results.p_range = (1:p_max)';
end
