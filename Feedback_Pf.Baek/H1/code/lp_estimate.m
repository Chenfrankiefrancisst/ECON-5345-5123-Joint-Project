function results = lp_estimate(Y, shock, H, L, alpha, W)
% LP_ESTIMATE  Local Projection impulse responses (Jorda 2005).
%
%   results = lp_estimate(Y, shock, H, L, alpha)
%   results = lp_estimate(Y, shock, H, L, alpha, W)
%
%   Estimates horizon-by-horizon regressions:
%       y_{t+h} - y_{t-1} = a_h + beta_h * shock_t + gamma_h' * controls_t + e_{t+h}
%
%   for h = 0, 1, ..., H.
%
%   The function ALWAYS includes L lags of Y (own lags) and L lags of the
%   shock as controls. This is the minimal specification for H1, which
%   tests the total reduced-form effect of GPR on inflation / output
%   without conditioning on mediating channels.
%
%   Inputs:
%     Y     — T x 1 outcome variable in LOG LEVELS (e.g., log(CPI)).
%             The function internally constructs cumulative differences.
%     shock — T x 1 shock variable (e.g., log GPR).
%     H     — max horizon (e.g., 36 for 3 years of monthly data).
%     L     — number of lags for controls (e.g., 12 for monthly).
%     alpha — significance level for confidence bands (e.g., 0.10 for 90% CI).
%     W     — (optional) T x M matrix of ADDITIONAL control variables.
%             Use this for channel analysis (Stage 4+) where mediators like
%             oil, FFR, or credit spreads are added to measure attenuation.
%             For H1 baseline, omit this argument or pass [].
%
%   Output:
%     results — struct with fields:
%       .beta   — (H+1) x 1 impulse response coefficients
%       .se     — (H+1) x 1 Newey-West HAC standard errors
%       .ci_lo  — (H+1) x 1 lower confidence band
%       .ci_hi  — (H+1) x 1 upper confidence band
%       .h      — (H+1) x 1 horizon vector [0; 1; ...; H]
%       .T_eff  — (H+1) x 1 effective sample size at each horizon
%       .R2     — (H+1) x 1 R-squared at each horizon
%
%   Design rationale (H1):
%     H1 tests whether GPR acts as a cost-push shock (CPI up, IP down).
%     FFR and oil are MEDIATORS (GPR -> oil -> CPI), not confounders.
%     Including them as controls would partial out the causal channels
%     we want to measure, attenuating the total effect estimate.
%     Channel decomposition belongs in Stage 4-5, where W is populated.
%
%   Reference: Jorda, O. (2005). "Estimation and Inference of Impulse
%   Responses by Local Projections." AER, 95(1), 161-182.

    T = length(Y);
    z_crit = norminv(1 - alpha/2);  % critical value (e.g., 1.645 for 90%)

    % Handle optional W
    if nargin < 6 || isempty(W)
        W = zeros(T, 0);  % no additional controls
    end

    % --- Build lagged control matrix ---
    % Always include: L lags of Y, L lags of shock
    % Optionally include: L lags of each column in W (for channel analysis)
    all_vars = [Y, shock, W];  % T x (2+M)
    n_vars = size(all_vars, 2);

    % Lagged controls: lags 1 to L of all variables
    Z_lags = nan(T, n_vars * L);
    for lag = 1:L
        cols = (lag-1)*n_vars + (1:n_vars);
        Z_lags(lag+1:end, cols) = all_vars(1:end-lag, :);
    end

    % Effective start index: need L lags available
    t_start = L + 1;

    % --- Preallocate output ---
    beta   = nan(H+1, 1);
    se_out = nan(H+1, 1);
    ci_lo  = nan(H+1, 1);
    ci_hi  = nan(H+1, 1);
    T_eff  = nan(H+1, 1);
    R2     = nan(H+1, 1);

    % --- Horizon-by-horizon OLS ---
    for h = 0:H
        % LHS: cumulative change y_{t+h} - y_{t-1}
        t_end = T - h;
        if t_end < t_start + 1
            warning('Horizon h=%d: insufficient observations. Stopping.', h);
            break;
        end

        idx = t_start:t_end;
        lhs = Y(idx + h) - Y(idx - 1);

        % RHS: constant + shock_t (contemporaneous) + lagged controls
        rhs = [ones(length(idx), 1), shock(idx), Z_lags(idx, :)];

        % Drop columns that are all-NaN
        valid_cols = ~any(isnan(rhs), 1);
        rhs = rhs(:, valid_cols);

        % Drop rows with any NaN
        valid_rows = ~any(isnan([lhs, rhs]), 2);
        lhs = lhs(valid_rows);
        rhs = rhs(valid_rows, :);

        Th = length(lhs);
        T_eff(h+1) = Th;

        % OLS
        bhat = rhs \ lhs;
        resid = lhs - rhs * bhat;

        % R-squared
        SS_res = sum(resid.^2);
        SS_tot = sum((lhs - mean(lhs)).^2);
        R2(h+1) = 1 - SS_res / SS_tot;

        % beta_h is the coefficient on shock (column 2 in original rhs)
        orig_col2 = 2;  % shock is always column 2
        if valid_cols(orig_col2)
            col_map = cumsum(valid_cols);
            shock_col = col_map(orig_col2);
            beta(h+1) = bhat(shock_col);

            % Newey-West SE
            nw_bw = max(h, floor(4*(Th/100)^(2/9)));
            se_vec = lp_newey_west(rhs, resid, nw_bw);
            se_out(h+1) = se_vec(shock_col);

            % Confidence interval
            ci_lo(h+1) = beta(h+1) - z_crit * se_out(h+1);
            ci_hi(h+1) = beta(h+1) + z_crit * se_out(h+1);
        end
    end

    % --- Pack output ---
    results.beta  = beta;
    results.se    = se_out;
    results.ci_lo = ci_lo;
    results.ci_hi = ci_hi;
    results.h     = (0:H)';
    results.T_eff = T_eff;
    results.R2    = R2;
end
