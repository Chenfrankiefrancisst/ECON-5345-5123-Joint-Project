%% =======================================================================
% AR_GPR_shock.m
% ------------------------------------------------------------------------
% Extracts standardized GPR shocks and runs three diagnostic tests:
%   Test 1 — Granger exogeneity         (gctest)
%   Test 2 — White noise: Ljung-Box Q   (lbqtest)
%   Test 3 — White noise: Breusch-Godfrey LM (manual OLS aux regression)
%
% Shock extraction model (OLS):
%   GPR_t = a + sum_{j=1}^p rho_j GPR_{t-j}
%           + xi' B_t + omega' O_{t-1} + u_t,
%   where B_t  = [Unemp_t, FFR_t]                        (contemporaneous)
%         O_{t-1} = [Brent_{t-1}, WTI_{t-1}, Gas_{t-1}]  (lag-1)
% The standardized shock is z_t = (u_t - mean(u))/sd(u).
%
% Two control specifications are run side-by-side:
%   "with_oil"    : cur Unemp/FFR + lag-1 Brent/WTI/Gasoline   (w/ oil)
%   "without_oil" : cur Unemp/FFR only (oil controls removed)  (w/o oil)
%% =======================================================================

clear; clc; close all;

%% User Setting
cfg.datafile     = 'Q_Levels_Database.csv';
cfg.output_dir   = 'GPR_shock_output';
cfg.save_results = true;

%% AR shock-extraction settings.
cfg.p_gpr_shock       = 4;
cfg.standardize_shock = true;

%% Exact column names used as controls in the AR shock equation.
cfg.current_control_vars = {'Unemp', 'FFR'};
cfg.lag1_oil_vars        = {'Real_Brent', 'Real_WTI', 'Real_Gasoline'};

%% Test settings.
cfg.granger_lags      = 4;                       % Test 1 (gctest NumLags)
cfg.wn_lags           = [4, 8, 12];              % Test 2 / 3 lag horizons
cfg.test_alpha        = 0.05;                    % shared significance level
cfg.granger_exog_vars = {'Unemp', 'FFR', 'Real_Brent', 'Real_WTI', 'Real_Gasoline'};

%% Shock specifications: {short_id, exact_CSV_column, label}.
cfg.shock_specs = {
    'World',  'LGPR',   'World GPR shock';
    'GPT',    'LGPRT',  'Global geopolitical threats shock';
    'GPA',    'LGPRA',  'Global geopolitical acts shock'
};

if cfg.save_results && ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end

fprintf('\n=== GPR shock extraction + Granger / white-noise diagnostics ===\n');
fprintf('Number of shocks       : %d\n', size(cfg.shock_specs,1));
fprintf('AR lags                : %d\n', cfg.p_gpr_shock);
fprintf('Granger-test lag length: %d\n', cfg.granger_lags);
fprintf('White-noise lag grid   : %s\n', mat2str(cfg.wn_lags));
fprintf('Significance level     : %.2f\n', cfg.test_alpha);
fprintf('Data file              : %s\n', cfg.datafile);

%% Load database
DB      = readtable(cfg.datafile, 'VariableNamingRule', 'preserve');
T       = height(DB);
db_vars = DB.Properties.VariableNames;
fprintf('Loaded T = %d rows, %d variables.\n', T, numel(db_vars));

%% Preload all referenced columns ONCE (case-sensitive exact match).
% Each column is forced to a numeric column vector to avoid orientation
% surprises downstream (avoids the row-vs-column-vector pitfall when
% indexing later by t).
needed_vars = unique([cfg.current_control_vars, cfg.lag1_oil_vars, ...
                      cfg.granger_exog_vars,    cfg.shock_specs(:,2)']);
DB_cache = struct();
for i = 1:numel(needed_vars)
    vn = needed_vars{i};
    if ~any(strcmp(db_vars, vn))
        error('Variable "%s" not found in %s. Available columns:\n  %s', ...
              vn, cfg.datafile, strjoin(db_vars, ', '));
    end
    col = DB.(vn);
    if ~(isnumeric(col) || islogical(col))
        error('Variable "%s" exists but is not numeric.', vn);
    end
    DB_cache.(vn) = double(col(:));   % (:) guarantees column vector
end

%% Extract Quarter labels once (used only for the shocks-CSV).
q_idx = find(strcmpi(db_vars, 'quarter') | strcmpi(db_vars, 'date'), 1);
if ~isempty(q_idx)
    has_quarter = true;
    quarter_col = string(DB{:, q_idx});   % string() handles char/cell/datetime
else
    has_quarter = false;
    quarter_col = strings(T, 0);
end

%% Build control matrices from the cache (no extra DB lookups).
nC = numel(cfg.current_control_vars);
current_controls = zeros(T, nC);
for i = 1:nC
    current_controls(:,i) = DB_cache.(cfg.current_control_vars{i});
end
fprintf('Current controls (B_t)    : %s\n', strjoin(cfg.current_control_vars, ', '));

nL = numel(cfg.lag1_oil_vars);
lag1_controls = zeros(T, nL);
for i = 1:nL
    lag1_controls(:,i) = DB_cache.(cfg.lag1_oil_vars{i});
end
fprintf('Lag-1 oil controls (O_t-1): %s\n', strjoin(cfg.lag1_oil_vars, ', '));

%% Preload GPR level series (variant-invariant).
GPR_levels = struct();
for s = 1:size(cfg.shock_specs,1)
    GPR_levels.(cfg.shock_specs{s,1}) = DB_cache.(cfg.shock_specs{s,2});
end

%% Control-specification variants
spec_variants = {
    'with_oil',    true;
    'without_oil', false;
};

% Stacked-result containers (one row per (variant, shock, ...) combination).
innovation_info      = table();
granger_exog_results = table();
white_noise_results  = table();
bg_results           = table();
Z_all                = struct();

p      = cfg.p_gpr_shock;
t_grid = ((p+1):T)';
nT     = numel(t_grid);

for v = 1:size(spec_variants, 1)
    variant = spec_variants{v,1};
    use_oil = spec_variants{v,2};

    if use_oil
        L1   = lag1_controls;
        nL_v = nL;
    else
        L1   = zeros(T, 0);
        nL_v = 0;
    end

    if use_oil, oil_lbl = 'YES'; else, oil_lbl = 'NO'; end
    fprintf('\n##### Variant: %-7s (lag-1 oil controls: %s) #####\n', variant, oil_lbl);

    Z_v      = struct();
    Xg_cache = struct();   % cached design matrices (used in BG aux regression)

    %% Extract standardized GPR shocks 
    fprintf('\n--- Constructing standardized GPR shocks [%s] ---\n', variant);
    for s = 1:size(cfg.shock_specs,1)
        sid   = cfg.shock_specs{s,1};
        label = cfg.shock_specs{s,3};
        gpr   = GPR_levels.(sid);

        % Vectorised design matrix: [1, AR lags, B_t, O_{t-1}].
        X_ar = zeros(nT, p);
        for j = 1:p
            X_ar(:,j) = gpr(t_grid - j);
        end
        X_curr = current_controls(t_grid,  :);
        if nL_v > 0
            X_lag1 = L1(t_grid - 1, :);
        else
            X_lag1 = zeros(nT, 0);
        end
        X = [ones(nT,1), X_ar, X_curr, X_lag1];
        Y = gpr(t_grid);

        good   = isfinite(Y) & all(isfinite(X), 2);
        Yg     = Y(good);
        Xg     = X(good, :);
        t_used = t_grid(good);

        if size(Xg,1) <= size(Xg,2)
            error('Not enough usable observations for AR(%d) extraction of %s [%s].', ...
                  p, sid, variant);
        end

        b    = Xg \ Yg;
        Yhat = Xg * b;                                       % computed once, reused
        u    = Yg - Yhat;
        rsq  = 1 - sum(u.^2) / sum((Yg - mean(Yg)).^2);

        resid_full         = nan(T,1);
        resid_full(t_used) = u;

        if cfg.standardize_shock
            z = (resid_full - mean(u)) / std(u);
        else
            z = resid_full;
        end
        Z_v.(sid)             = z;
        Xg_cache.(sid).X      = Xg;
        Xg_cache.(sid).t_used = t_used;

        innovation_info = [innovation_info; ...
            table(string(variant), string(sid), string(label), numel(Yg), rsq, std(u), sum(isfinite(z)), ...
                  'VariableNames', {'variant','shock','label','nobs','rsq','resid_sd','finite_z'})]; %#ok<AGROW>

        fprintf('  %-12s: nobs=%3d, AR R2=% .3f, resid sd=% .4f, finite z=%3d\n', ...
                sid, numel(Yg), rsq, std(u), sum(isfinite(z)));
    end
    Z_all.(variant) = Z_v;

    %% Test 1: Conditional Granger exogeneity (lagged X  ==>  z_t)
    % For each candidate predictor X_j, test
    %     H0: X_j does NOT Granger-cause z_t,
    %     conditional on (a) z_t's own lags (handled by gctest) and
    %                    (b) lags of the OTHER predictors in granger_exog_vars.
    fprintf('\n--- Test 1: Conditional Granger exogeneity [%s] ---\n', variant);
    fprintf('H0: X_j does NOT Granger-cause z_t conditional on other predictors\n');

    for s = 1:size(cfg.shock_specs,1)
        sid = cfg.shock_specs{s,1};
        z   = Z_v.(sid);

        for m = 1:numel(cfg.granger_exog_vars)
            xname = cfg.granger_exog_vars{m};
            x     = DB_cache.(xname);                       % candidate cause

            % Conditioning set = the OTHER granger_exog_vars columns.
            other_names = cfg.granger_exog_vars;
            other_names(m) = [];
            X_other = zeros(T, numel(other_names));
            for c = 1:numel(other_names)
                X_other(:,c) = DB_cache.(other_names{c});
            end

            use = isfinite(x) & isfinite(z) & all(isfinite(X_other), 2);
            % Heuristic: need at least (2 + nCond) * (lags+1) usable rows.
            min_n = (2 + numel(other_names)) * (cfg.granger_lags + 1);
            if sum(use) <= min_n
                warning('Test 1 skipped (too few obs): %s -> z_%s [%s].', xname, sid, variant);
                continue;
            end

            try
                % gctest(Y1=effect, Y2=cause, X=conditioning).
                [h, pval, stat, ~] = gctest(z(use), x(use), X_other(use,:), ...
                                            'NumLags', cfg.granger_lags, ...
                                            'Test',    'f', ...
                                            'Alpha',   cfg.test_alpha);
                reject = logical(h);
            catch ME
                warning('gctest failed (%s -> z_%s [%s]): %s', xname, sid, variant, ME.message);
                continue;
            end

            granger_exog_results = [granger_exog_results; ...
                table(string(variant), string(sid), string(xname), string(['z_' sid]), ...
                      cfg.granger_lags, sum(use), stat, pval, reject, cfg.test_alpha, ...
                      'VariableNames', {'variant','shock','cause','effect','numlags','nobs','stat','pvalue','reject_H0','alpha'})]; %#ok<AGROW>

            fprintf('  %-12s | %-14s -> z_%-12s | nobs=%3d | F=% .3f | pval=% .4f | reject=%d\n', ...
                    sid, xname, sid, sum(use), stat, pval, reject);
        end
    end

    %% Test 2: Ljung-Box Q (white noise)
    fprintf('\n--- Test 2: Ljung-Box Q [%s] ---\n', variant);
    fprintf('H0: z_t is white noise up to lag L (fail-to-reject supports white noise)\n');

    for s = 1:size(cfg.shock_specs,1)
        sid     = cfg.shock_specs{s,1};
        z_valid = Z_v.(sid);
        z_valid = z_valid(isfinite(z_valid));
        if numel(z_valid) <= max(cfg.wn_lags) + 1
            warning('Too few finite obs for Ljung-Box on z_%s [%s].', sid, variant);
            continue;
        end

        for L = cfg.wn_lags
            try
                [h, pval, stat, cvalue] = lbqtest(z_valid, ...
                                                  'Lags',  L, ...
                                                  'Alpha', cfg.test_alpha);
                reject = logical(h);
            catch ME
                warning('lbqtest failed for z_%s (L=%d) [%s]: %s', sid, L, variant, ME.message);
                continue;
            end

            white_noise_results = [white_noise_results; ...
                table(string(variant), string(sid), L, numel(z_valid), stat, pval, cvalue, reject, cfg.test_alpha, ...
                      'VariableNames', {'variant','shock','lag','nobs','Q_stat','pvalue','cvalue','reject_H0','alpha'})]; %#ok<AGROW>

            fprintf('  z_%-10s | L=%2d | nobs=%3d | Q=% 8.3f | pval=% .4f | reject=%d\n', ...
                    sid, L, numel(z_valid), stat, pval, reject);
        end
    end

    %% --- Test 3: Breusch-Godfrey LM (robustness for white-noise test) ---
    % Aux regression: z_t = X_t' alpha + sum_{k=1..L} gamma_k z_{t-k} + v_t
    % where X_t contains the SAME regressors as the AR(p) extraction.
    % H0: gamma_1 = ... = gamma_L = 0.   LM = n * R^2_aux ~ Chi^2(L).
    fprintf('\n--- Test 3: Breusch-Godfrey LM [%s] ---\n', variant);
    fprintf('H0: z_t has no serial correlation up to lag L (fail-to-reject supports white noise)\n');

    for s = 1:size(cfg.shock_specs,1)
        sid    = cfg.shock_specs{s,1};
        z      = Z_v.(sid);
        Xg     = Xg_cache.(sid).X;
        t_used = Xg_cache.(sid).t_used;
        n_orig = numel(t_used);

        % Build the lagged-residual matrix once at the maximum L, then slice
        % the first L columns for each test horizon (avoids rebuilding the
        % same lag columns three times per shock).
        Lmax = max(cfg.wn_lags);
        Z_lag_full = nan(n_orig, Lmax);
        for k = 1:Lmax
            tlag = t_used - k;
            ok   = tlag >= 1;
            Z_lag_full(ok, k) = z(tlag(ok));
        end

        for L = cfg.wn_lags
            Z_lag = Z_lag_full(:, 1:L);

            z_t   = z(t_used);
            X_aug = [Xg, Z_lag];
            keep  = isfinite(z_t) & all(isfinite(X_aug), 2);
            n_use = sum(keep);

            if n_use <= size(X_aug, 2) + 1
                warning('BG: too few obs (n=%d) for L=%d on z_%s [%s].', n_use, L, sid, variant);
                continue;
            end

            X_full  = X_aug(keep, :);
            z_full  = z_t(keep);

            % Unrestricted aux regression (with lagged residuals).
            r_aux   = z_full - X_full * (X_full \ z_full);
            sse_aux = sum(r_aux.^2);
            ss_tot  = sum((z_full - mean(z_full)).^2);
            R2_aux  = 1 - sse_aux / max(ss_tot, eps);

            % Restricted (without lagged residuals) — only needed for the F form.
            X_r   = Xg(keep, :);
            r_r   = z_full - X_r * (X_r \ z_full);
            sse_r = sum(r_r.^2);

            % LM (Chi^2 form, canonical BG).
            LM      = n_use * R2_aux;
            pval_LM = 1 - chi2cdf(LM, L);
            reject  = pval_LM < cfg.test_alpha;

            % F form on the L lagged-residual coefficients.
            df_num = L;
            df_den = n_use - size(X_full, 2);
            F      = ((sse_r - sse_aux) / df_num) / (sse_aux / df_den);
            pval_F = 1 - fcdf(F, df_num, df_den);

            bg_results = [bg_results; ...
                table(string(variant), string(sid), L, n_use, LM, pval_LM, F, pval_F, reject, cfg.test_alpha, ...
                      'VariableNames', {'variant','shock','lag','nobs','LM_stat','LM_pvalue','F_stat','F_pvalue','reject_H0','alpha'})]; %#ok<AGROW>

            fprintf('  z_%-10s | L=%2d | nobs=%3d | LM=% 8.3f | LM pval=% .4f | F=% 7.3f | F pval=% .4f | reject=%d\n', ...
                    sid, L, n_use, LM, pval_LM, F, pval_F, reject);
        end
    end
end

%% Convenience alias for downstream scripts (default = with-oil variant).
Z = Z_all.with_oil;

%% Save results
if cfg.save_results
    writetable(innovation_info, fullfile(cfg.output_dir, 'gpr_shock_diagnostics.csv'));
    if ~isempty(granger_exog_results)
        writetable(granger_exog_results, fullfile(cfg.output_dir, 'granger_exog_test.csv'));
    end
    if ~isempty(white_noise_results)
        writetable(white_noise_results, fullfile(cfg.output_dir, 'white_noise_lbq.csv'));
    end
    if ~isempty(bg_results)
        writetable(bg_results, fullfile(cfg.output_dir, 'white_noise_bg.csv'));
    end

    % Export the standardized shocks (both variants) as one wide CSV.
    variants = fieldnames(Z_all);
    sids     = fieldnames(Z_all.(variants{1}));
    nCols    = numel(variants) * numel(sids);
    Zmat     = nan(T, nCols);
    col_names = cell(1, nCols);
    c = 0;
    for vv = 1:numel(variants)
        for ss = 1:numel(sids)
            c = c + 1;
            col_names{c} = [sids{ss} '_' variants{vv}];
            Zmat(:,c)    = Z_all.(variants{vv}).(sids{ss});
        end
    end
    if has_quarter
        shock_table = [table(quarter_col, 'VariableNames', {'Quarter'}), ...
                       array2table(Zmat,  'VariableNames', col_names)];
    else
        shock_table = array2table(Zmat, 'VariableNames', col_names);
    end
    writetable(shock_table, fullfile(cfg.output_dir, 'gpr_shocks.csv'));

    save(fullfile(cfg.output_dir, 'workspace_gpr_shock.mat'), ...
         'cfg','Z_all','Z','GPR_levels','innovation_info', ...
         'granger_exog_results','white_noise_results','bg_results');
    fprintf('\nSaved results in: %s\n', cfg.output_dir);
else
    fprintf('\nNo files saved (cfg.save_results = false).\n');
    fprintf('Workspace: Z_all, Z, GPR_levels, innovation_info, granger_exog_results, white_noise_results, bg_results.\n');
end
