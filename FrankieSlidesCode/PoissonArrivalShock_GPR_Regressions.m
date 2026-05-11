clear; clc; close all;

%% ============================================================
% REGRESS POISSON ARRIVAL SHOCKS ON CURRENT GPR LEVELS / GPR SHOCKS
%
% Goal:
%   Put the standardized Poisson arrival shock on the LHS:
%
%       z_t^{N,k} = a + beta * GPR_t + error_t
%
%   where GPR_t is either:
%       1. current AR(4)+business-cycle-control GPR shock
%       2. current standardized GPR level
%
% Important:
%   The Poisson MLE used to construct z_t^{N,k} EXCLUDES GPR.
%   Therefore z_t^{N,k} is the unexpected arrival component relative to
%   lagged event counts and lagged macro controls only.
%
% Step 1: Non-GPR Poisson baseline intensity
%
%   log(lambda_t^{k,0}) = alpha_k + rho_k N_{t-1}^k + eta_k' W_{t-1}
%
%   z_t^{N,k} = standardize( (N_t^k - lambda_hat_t^{k,0}) / sqrt(lambda_hat_t^{k,0}) )
%
% Step 2: Current GPR residual-arrival regression
%
%   z_t^{N,k} = a_{k,m} + beta_{k,m} GPR_{m,t} + error_t
%
% This directly tests whether unexpected event arrivals are larger when
% current GPR shocks / current GPR levels are high.
%% ============================================================

%% -------------------- USER SETTINGS --------------------

cfg.datafile = 'Q_Levels_Database.csv';
cfg.datafile_fallbacks = {'Q_Levels_Database(2).csv'};

cfg.dummy_file = 'oil_relevant_gprDummies_extended_onset_realized.mat';
cfg.dummy_csv_fallback = 'oil_relevant_gpr_event_dummies_extended_onset_realized_1986Q1_2025Q4.csv';
cfg.dummy_csv_fallbacks = {'oil_relevant_gpr_event_dummies_extended_onset_realized_1986Q1_2025Q4.csv', ...
    'oil_relevant_gpr_event_dummies_extended_onset_realized_1986Q1_2025Q4(5).csv'};

cfg.output_dir = 'PoissonArrivalShock_LHS_GPR_LevelShock_Regressions';
cfg.save_results = true;

% GPR shock extraction:
%   GPR_t = a + sum_{j=1}^4 phi_j GPR_{t-j} + gamma' B_t + u_t
%   z_t^{GPR} = standardized u_t
cfg.p_gpr_shock = 4;
cfg.standardize_shock = true;
cfg.gpr_shock_control_timing = 'contemporaneous';  % 'contemporaneous' or 'lagged'
cfg.gpr_shock_control_aliases = { ...
    {'Unemp','Unemployment'}, ...
    {'FFR','FederalFundsRate','FedFunds','Policy_Rate','PolicyRate','FEDFUNDS'} ...
};

% Event count/dummy variables.
% Prefer n_* event count columns. If missing, fallback to corresponding 0/1 dummy.
cfg.event_vars = { ...
    'n_OilSpecificThreatShock_EventOnset', ...
    'n_OilSpecificRealizedShock_EventOnset', ...
    'n_StrictSupplyDisruption_EventOnset', ...
    'n_ChokepointShippingRisk_EventOnset', ...
    'n_EnergySanction_EventOnset', ...
    'n_ProducerRegionRisk_EventOnset' ...
};

% GPR measures to test on RHS.
cfg.gpr_specs = {
    'World',       {'LGPR'},    'World aggregate GPR';
    'Threat',      {'LGPRT'},   'Global geopolitical threats';
    'Act',         {'LGPRA'},   'Global geopolitical acts';
    'US',          {'LGPRUS'},  'U.S. GPR';
    'Israel',      {'LGPRISR'}, 'Israel GPR';
    'Russia',      {'LGPRRU'},  'Russia GPR';
    'China',       {'LGPRCHN'}, 'China GPR';
    'Venezuela',   {'LGPRVZ'},  'Venezuela GPR';
    'SaudiArabia', {'LGPRSAR'}, 'Saudi Arabia GPR'
};

% RHS predictor types:
%   shock = current AR-residual GPR shock
%   level = current standardized GPR level
cfg.predictor_types = {'shock','level'};

% Non-GPR Poisson baseline controls used to construct z_t^{N,k}.
cfg.include_lagged_count = true;
cfg.include_lagged_macro_controls = true;
cfg.standardize_predictors = true;
cfg.min_positive_periods = 4;
cfg.poisson_ridge_lambda = 1e-6;

% Second-stage regression settings.
% Default: do NOT add controls again, because z_t^{N,k} is already residualized
% against lagged event count and lagged macro controls in the non-GPR Poisson MLE.
cfg.include_controls_in_second_stage = false;
cfg.second_stage_hac_lag = 4;

% Exogeneity / bias diagnostics for the second-stage beta.
% Important: in the fitted OLS regression, the sample moment X'u_hat=0 is
% mechanical. The meaningful check is whether excluded controls still explain
% the residual and whether the beta changes after adding them back.
cfg.run_exogeneity_bias_diagnostics = true;
cfg.bias_beta_change_flag_threshold = 0.25;   % flag if |beta_controlled-beta_simple|/|beta_simple| > 25%

% High-GPR group threshold for descriptive comparison.
% 1 means GPR predictor >= 1 s.d.
cfg.high_gpr_threshold = 1;

% Macro controls entering the non-GPR Poisson baseline as W_{t-1}.
cfg.control_aliases = { ...
    {'Unemp','Unemployment'}, ...
    {'FFR','FederalFundsRate','FedFunds','Policy_Rate','PolicyRate','FEDFUNDS'}, ...
    {'WEO_Growth','gGDP_Forecast'}, ...
    {'WEO_Revision','gGDP_Revise'}, ...
    {'r_y','RealGDP','Real_Output'}, ...
    {'Indu_Prod','IndustrialProduction'} ...
};

%% -------------------- SETUP --------------------

if cfg.save_results
    if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
end

fprintf('\n=== Regressing Poisson arrival shocks on current GPR shocks / levels ===\n');
fprintf('Poisson MLE for arrival shock construction EXCLUDES GPR.\n');
fprintf('Output directory: %s\n', cfg.output_dir);

%% -------------------- LOAD DATA --------------------

if ~exist(cfg.datafile, 'file')
    if isfield(cfg, 'datafile_fallbacks')
        for ff = 1:numel(cfg.datafile_fallbacks)
            if exist(cfg.datafile_fallbacks{ff}, 'file')
                fprintf('Data file not found under default name. Using fallback: %s\n', cfg.datafile_fallbacks{ff});
                cfg.datafile = cfg.datafile_fallbacks{ff};
                break;
            end
        end
    end
end

if ~exist(cfg.datafile, 'file')
    error('Data file not found: %s.', cfg.datafile);
end

DB = readtable(cfg.datafile, 'VariableNamingRule','preserve');
T = height(DB);
fprintf('Loaded level database: T=%d, variables=%d\n', T, numel(DB.Properties.VariableNames));

[quarter_labels, has_quarter] = get_quarter_labels(DB, T);
if has_quarter
    fprintf('Sample starts at %s and ends at %s\n', quarter_labels{1}, quarter_labels{end});
else
    error('No Quarter/date column found in the level database. Cannot align dummy file.');
end

sample = true(T,1);

[controls, control_names] = build_controls(DB, cfg.control_aliases, T);
fprintf('\nMacro controls loaded: %s\n', strjoin_or_none(control_names));
for j = 1:numel(control_names)
    fprintf('  Control %-18s finite = %3d / %3d\n', control_names{j}, sum(isfinite(controls(:,j))), T);
end

[shock_controls, shock_control_names] = build_controls(DB, cfg.gpr_shock_control_aliases, T);
fprintf('\nGPR shock-extraction controls loaded: %s\n', strjoin_or_none(shock_control_names));
for j = 1:numel(shock_control_names)
    fprintf('  Shock control %-18s finite = %3d / %3d\n', shock_control_names{j}, sum(isfinite(shock_controls(:,j))), T);
end

dummy_aligned = build_aligned_dummy_table(DB, quarter_labels, has_quarter, T, cfg);
if isempty(dummy_aligned)
    error('No dummy table loaded.');
end

%% -------------------- CONSTRUCT GPR SHOCKS AND LEVELS --------------------

GPR = struct();
gpr_diag = table();

fprintf('\n--- Constructing current GPR shocks and levels ---\n');
for s = 1:size(cfg.gpr_specs,1)
    gid = cfg.gpr_specs{s,1};
    aliases = cfg.gpr_specs{s,2};
    label = cfg.gpr_specs{s,3};

    level = get_required_series(DB, aliases, T);
    innov = extract_ar_level_innovation_with_controls(level, shock_controls, sample, cfg.p_gpr_shock, cfg.gpr_shock_control_timing, gid);

    if cfg.standardize_shock
        shock = zscore_in_sample(innov.resid, sample);
    else
        shock = innov.resid;
    end
    level_std = zscore_in_sample(level, sample);

    gfield = make_field_name(gid);
    GPR.(gfield).id = gid;
    GPR.(gfield).label = label;
    GPR.(gfield).level = level;
    GPR.(gfield).level_std = level_std;
    GPR.(gfield).shock = shock;

    gpr_diag = [gpr_diag; table(string(gid), string(label), string(strjoin_or_none(shock_control_names)), ...
        string(cfg.gpr_shock_control_timing), innov.nobs, innov.rsq, innov.std_resid, ...
        sum(isfinite(level)), sum(isfinite(shock)), ...
        'VariableNames', {'gpr_id','label','shock_controls','shock_control_timing', ...
        'ar_bc_nobs','ar_bc_rsq','ar_bc_resid_sd','finite_level','finite_shock'})]; %#ok<AGROW>

    fprintf('  %-12s AR(%d)+BC shock: nobs=%3d, R2=% .3f, finite shock=%3d\n', ...
        gid, cfg.p_gpr_shock, innov.nobs, innov.rsq, sum(isfinite(shock)));
end

%% -------------------- BUILD POISSON ARRIVAL SHOCKS AND RUN RHS GPR REGRESSIONS --------------------

arrival_shock_results = table();
arrival_shock_diagnostics = table();
arrival_shock_series = table();
exogeneity_bias_diagnostics = table();

fprintf('\n--- Constructing non-GPR Poisson arrival shocks and regressing on GPR ---\n');

for ev = 1:numel(cfg.event_vars)
    event_id = cfg.event_vars{ev};
    [N, source_name] = get_event_count_or_dummy_series(dummy_aligned, event_id, T);

    if isempty(N) || sum(N > 0) == 0
        warning('Event count/dummy not found or all zero: %s. Skipping.', event_id);
        continue;
    end

    pres = estimate_non_gpr_poisson_arrival_shock(N, controls, sample, cfg, event_id);
    if sum(isfinite(pres.z_arrival_shock)) == 0
        warning('No finite Poisson arrival shock for %s. Skipping.', event_id);
        continue;
    end

    arrival_shock_diagnostics = [arrival_shock_diagnostics; pres.diagnostics]; %#ok<AGROW>

    fprintf('\nEvent: %s | source=%s | positives=%d | total=%g | poisson nobs=%d | resid sd=% .4f\n', ...
        event_id, source_name, sum(N > 0), sum(N(isfinite(N))), pres.nobs, pres.resid_sd);

    if cfg.save_results
        tmp_series = table(string(quarter_labels(:)), repmat(string(event_id), T, 1), N(:), ...
            pres.lambda_hat(:), pres.pearson_resid(:), pres.z_arrival_shock(:), ...
            'VariableNames', {'Quarter','event','N','lambda_hat_non_gpr','pearson_resid','z_poisson_arrival_shock'});
        arrival_shock_series = [arrival_shock_series; tmp_series]; %#ok<AGROW>
    end

    for s = 1:size(cfg.gpr_specs,1)
        gid = cfg.gpr_specs{s,1};
        gfield = make_field_name(gid);

        for pt = 1:numel(cfg.predictor_types)
            ptype = cfg.predictor_types{pt};

            switch lower(ptype)
                case 'shock'
                    rhs = GPR.(gfield).shock;
                case 'level'
                    rhs = GPR.(gfield).level_std;
                otherwise
                    error('Unknown predictor type: %s', ptype);
            end

            Xsecond = [];
            if isfield(cfg, 'include_controls_in_second_stage') && cfg.include_controls_in_second_stage
                % Optional: add lagged event count and lagged macro controls again.
                % Default is false because the LHS is already residualized by the non-GPR Poisson model.
                Xsecond = build_second_stage_controls(N, controls, cfg);
            end

            rfit = regress_arrival_shock_on_current_gpr(pres.z_arrival_shock, rhs, Xsecond, sample, cfg);

            % Bias / exogeneity diagnostics.
            % The direct sample moment E[x*u]=0 is automatically satisfied by OLS,
            % so this diagnostic also checks omitted-control residual predictability
            % and beta stability after adding lagged count + lagged macro controls.
            if isfield(cfg, 'run_exogeneity_bias_diagnostics') && cfg.run_exogeneity_bias_diagnostics
                Zbias = build_second_stage_controls(N, controls, cfg);
                bdiag = diagnose_second_stage_beta_bias(pres.z_arrival_shock, rhs, Zbias, sample, cfg);

                brow = table( ...
                    string(event_id), string(source_name), string(gid), string(GPR.(gfield).label), string(ptype), ...
                    bdiag.nobs, bdiag.beta_simple, bdiag.se_simple, bdiag.p_simple, ...
                    bdiag.beta_controlled, bdiag.se_controlled, bdiag.p_controlled, ...
                    bdiag.beta_diff, bdiag.beta_pct_change, bdiag.beta_abs_pct_change, ...
                    bdiag.moment_xu_simple, bdiag.moment_xu_t_simple, bdiag.moment_xu_p_simple, ...
                    bdiag.max_abs_mean_Zu_simple, bdiag.omitted_controls_F, bdiag.omitted_controls_p, ...
                    bdiag.gpr_on_controls_F, bdiag.gpr_on_controls_p, ...
                    bdiag.bias_concern_flag, string(bdiag.bias_concern_reason), ...
                    'VariableNames', {'event','source_event','gpr_id','gpr_label','predictor_type', ...
                    'nobs','beta_simple','se_simple','p_simple', ...
                    'beta_controlled','se_controlled','p_controlled', ...
                    'beta_diff','beta_pct_change','beta_abs_pct_change', ...
                    'moment_xu_simple','moment_xu_t_simple','moment_xu_p_simple', ...
                    'max_abs_mean_Zu_simple','omitted_controls_F','omitted_controls_p', ...
                    'gpr_on_controls_F','gpr_on_controls_p', ...
                    'bias_concern_flag','bias_concern_reason'});
                exogeneity_bias_diagnostics = [exogeneity_bias_diagnostics; brow]; %#ok<AGROW>
            end

            high = isfinite(pres.z_arrival_shock) & isfinite(rhs) & sample & rhs >= cfg.high_gpr_threshold;
            low  = isfinite(pres.z_arrival_shock) & isfinite(rhs) & sample & rhs <  cfg.high_gpr_threshold;

            row = table( ...
                string(event_id), string(source_name), string(gid), string(GPR.(gfield).label), string(ptype), ...
                pres.nobs, pres.positive_periods, pres.total_count, cfg.high_gpr_threshold, ...
                rfit.nobs, rfit.beta, rfit.se, rfit.tstat, rfit.pvalue, rfit.rsq, rfit.corr_y_x, ...
                sum(high), mean(pres.z_arrival_shock(high), 'omitnan'), mean(pres.z_arrival_shock(low), 'omitnan'), ...
                mean(pres.z_arrival_shock(high) > 0, 'omitnan'), mean(pres.z_arrival_shock(low) > 0, 'omitnan'), ...
                'VariableNames', {'event','source_event','gpr_id','gpr_label','predictor_type', ...
                'poisson_nobs','positive_periods','total_count','high_threshold', ...
                'reg_nobs','beta_current','se_current','t_current','p_current','rsq','corr_arrivalShock_gpr', ...
                'n_high_gpr','mean_arrivalShock_high_gpr','mean_arrivalShock_low_gpr', ...
                'share_positive_arrivalShock_high_gpr','share_positive_arrivalShock_low_gpr'});

            arrival_shock_results = [arrival_shock_results; row]; %#ok<AGROW>

            fprintf('  %-12s %-5s: beta=% .4f  se=% .4f  t=% .2f  p=% .4f  corr=% .3f\n', ...
                gid, ptype, rfit.beta, rfit.se, rfit.tstat, rfit.pvalue, rfit.corr_y_x);
        end
    end
end

%% -------------------- DISPLAY SUMMARY --------------------

fprintf('\n=== Current GPR regressions with Poisson arrival shock on LHS: p < 0.10 ===\n');
sig = arrival_shock_results(arrival_shock_results.p_current < 0.10, :);
if isempty(sig)
    fprintf('None at p < 0.10.\n');
else
    sig = sortrows(sig, 'p_current', 'ascend');
    disp(sig(:, {'event','gpr_id','predictor_type','reg_nobs','positive_periods','beta_current','se_current','t_current','p_current','corr_arrivalShock_gpr'}));
end

fprintf('\n=== Top 30 smallest p-values ===\n');
top = sortrows(arrival_shock_results, 'p_current', 'ascend');
disp(top(1:min(30,height(top)), {'event','gpr_id','predictor_type','reg_nobs','positive_periods','beta_current','se_current','t_current','p_current','corr_arrivalShock_gpr'}));

if exist('exogeneity_bias_diagnostics', 'var') && ~isempty(exogeneity_bias_diagnostics)
    fprintf('\n=== Beta-bias / E[Xu] diagnostics: flagged cases ===\n');
    flagged = exogeneity_bias_diagnostics(exogeneity_bias_diagnostics.bias_concern_flag == true, :);
    if isempty(flagged)
        fprintf('No cases flagged by the omitted-control/beta-stability rule.\n');
    else
        flagged = sortrows(flagged, {'omitted_controls_p','beta_abs_pct_change'}, {'ascend','descend'});
        disp(flagged(:, {'event','gpr_id','predictor_type','nobs', ...
            'beta_simple','p_simple','beta_controlled','p_controlled', ...
            'beta_diff','beta_abs_pct_change','omitted_controls_p','gpr_on_controls_p','bias_concern_reason'}));
    end

    fprintf('\nNote: sample E[x*u_hat]=0 in the fitted OLS is mechanical. Use omitted-controls tests and beta stability to assess bias risk.\n');
end

%% -------------------- SAVE --------------------

if cfg.save_results
    writetable(arrival_shock_results, fullfile(cfg.output_dir, 'poisson_arrival_shock_lhs_gpr_regressions.csv'));
    writetable(arrival_shock_diagnostics, fullfile(cfg.output_dir, 'non_gpr_poisson_arrival_shock_diagnostics.csv'));
    writetable(gpr_diag, fullfile(cfg.output_dir, 'gpr_series_diagnostics.csv'));
    if exist('exogeneity_bias_diagnostics', 'var') && ~isempty(exogeneity_bias_diagnostics)
        writetable(exogeneity_bias_diagnostics, fullfile(cfg.output_dir, 'second_stage_exogeneity_bias_diagnostics.csv'));
    end
    if ~isempty(arrival_shock_series)
        writetable(arrival_shock_series, fullfile(cfg.output_dir, 'poisson_arrival_shock_series.csv'));
    end

    save(fullfile(cfg.output_dir, 'workspace_poisson_arrival_shock_lhs_gpr_regressions.mat'), ...
        'cfg','GPR','arrival_shock_results','arrival_shock_diagnostics','arrival_shock_series', ...
        'exogeneity_bias_diagnostics','gpr_diag','control_names','shock_control_names','shock_controls','dummy_aligned');

    fprintf('\nSaved results to: %s\n', cfg.output_dir);
end

%% ======================= NEW HELPER FUNCTIONS FOR ARRIVAL-SHOCK-LHS TEST =======================

function out = estimate_non_gpr_poisson_arrival_shock(N, controls, sample, cfg, label)
    % Construct z_t^{N,k} from a Poisson MLE that EXCLUDES GPR:
    %   log(lambda_t^{k,0}) = alpha + rho N_{t-1}^k + eta' W_{t-1}
    %   z_t^{N,k} = standardize((N_t^k - lambda_hat_t^{k,0}) / sqrt(lambda_hat_t^{k,0}))

    N = double(N(:));
    N(~isfinite(N)) = NaN;
    N(N < 0) = NaN;
    T = length(N);

    if isempty(controls)
        controls = zeros(T,0);
    end

    t_grid = 2:T;
    Y0 = N(t_grid);

    X0 = [];
    if isfield(cfg, 'include_lagged_count') && cfg.include_lagged_count
        X0 = [X0, N(t_grid-1)]; %#ok<AGROW>
    end
    if isfield(cfg, 'include_lagged_macro_controls') && cfg.include_lagged_macro_controls && ~isempty(controls)
        X0 = [X0, controls(t_grid-1,:)]; %#ok<AGROW>
    end

    valid = sample(t_grid) & sample(t_grid-1) & isfinite(Y0);
    if ~isempty(X0)
        valid = valid & all(isfinite(X0),2);
    end

    Y = Y0(valid);
    Xraw = X0(valid,:);

    min_positive = 4;
    if isfield(cfg, 'min_positive_periods')
        min_positive = cfg.min_positive_periods;
    end

    nobs = numel(Y);
    n_positive = sum(Y > 0);
    n_zero = sum(Y == 0);
    total_count = sum(Y);

    lambda_hat = nan(T,1);
    pearson_resid = nan(T,1);
    z_arrival_shock = nan(T,1);

    method = "not_estimated";
    converged = false;
    loglik = NaN;
    dev = NaN;
    coeff = NaN;

    if nobs <= size(Xraw,2) + 1 || n_positive < min_positive || total_count <= 0
        warning('Too few observations/positive periods for non-GPR Poisson residualization of %s: n=%d positives=%d total=%g.', ...
            label, nobs, n_positive, total_count);
        resid_sd = NaN;
        diag = table(string(label), string(method), converged, nobs, n_positive, n_zero, total_count, ...
            resid_sd, loglik, dev, ...
            'VariableNames', {'event','method','converged','nobs','positive_periods','zero_periods','total_count', ...
            'pearson_resid_sd','loglik','deviance'});
        out = struct('z_arrival_shock',z_arrival_shock,'pearson_resid',pearson_resid,'lambda_hat',lambda_hat, ...
            'coeff',coeff,'nobs',nobs,'positive_periods',n_positive,'zero_periods',n_zero,'total_count',total_count, ...
            'method',method,'converged',converged,'loglik',loglik,'deviance',dev,'resid_sd',resid_sd,'diagnostics',diag);
        return;
    end

    standardize_predictors = true;
    if isfield(cfg, 'standardize_predictors')
        standardize_predictors = cfg.standardize_predictors;
    end

    [X, muX, sdX] = standardize_design_columns(Xraw, standardize_predictors); %#ok<ASGLU>
    [coeff, method, converged, loglik, dev] = fit_poisson_count(Y, X, cfg);

    eta = [ones(size(X,1),1), X] * coeff;
    lam = clamp_intensity(exp(max(min(eta, 30), -30)));

    pr = (Y - lam) ./ sqrt(lam);
    resid_sd = std(pr, 'omitnan');
    if isfinite(resid_sd) && resid_sd > 0
        zuse = (pr - mean(pr, 'omitnan')) ./ resid_sd;
    else
        zuse = pr;
    end

    idx = t_grid(valid);
    lambda_hat(idx) = lam;
    pearson_resid(idx) = pr;
    z_arrival_shock(idx) = zuse;

    diag = table(string(label), string(method), converged, nobs, n_positive, n_zero, total_count, ...
        resid_sd, loglik, dev, ...
        'VariableNames', {'event','method','converged','nobs','positive_periods','zero_periods','total_count', ...
        'pearson_resid_sd','loglik','deviance'});

    out = struct();
    out.z_arrival_shock = z_arrival_shock;
    out.pearson_resid = pearson_resid;
    out.lambda_hat = lambda_hat;
    out.coeff = coeff;
    out.nobs = nobs;
    out.positive_periods = n_positive;
    out.zero_periods = n_zero;
    out.total_count = total_count;
    out.method = method;
    out.converged = converged;
    out.loglik = loglik;
    out.deviance = dev;
    out.resid_sd = resid_sd;
    out.diagnostics = diag;
end

function Xsecond = build_second_stage_controls(N, controls, cfg)
    N = double(N(:));
    T = length(N);
    if isempty(controls)
        controls = zeros(T,0);
    end
    Xsecond = nan(T,0);
    if isfield(cfg, 'include_lagged_count') && cfg.include_lagged_count
        Xsecond = [Xsecond, [NaN; N(1:end-1)]]; %#ok<AGROW>
    end
    if isfield(cfg, 'include_lagged_macro_controls') && cfg.include_lagged_macro_controls && ~isempty(controls)
        Xsecond = [Xsecond, [nan(1,size(controls,2)); controls(1:end-1,:)]]; %#ok<AGROW>
    end
end

function fit = regress_arrival_shock_on_current_gpr(y, x, Xextra, sample, cfg)
    % OLS regression:
    %   y_t = a + beta x_t + optional controls + e_t
    % with Newey-West/HAC standard error for beta.

    y = double(y(:));
    x = double(x(:));
    T = length(y);
    if nargin < 3 || isempty(Xextra)
        Xextra = zeros(T,0);
    end

    valid = sample(:) & isfinite(y) & isfinite(x);
    if ~isempty(Xextra)
        valid = valid & all(isfinite(Xextra),2);
    end

    yv = y(valid);
    xv = x(valid);
    Xv = [ones(numel(yv),1), xv, Xextra(valid,:)];

    fit = struct('nobs',numel(yv),'beta',NaN,'se',NaN,'tstat',NaN,'pvalue',NaN,'rsq',NaN,'corr_y_x',NaN);
    if numel(yv) <= size(Xv,2)
        return;
    end

    b = Xv \ yv;
    u = yv - Xv*b;

    hac_lag = 0;
    if isfield(cfg, 'second_stage_hac_lag')
        hac_lag = cfg.second_stage_hac_lag;
    end
    V = hac_covariance(Xv, u, hac_lag);
    se = sqrt(max(diag(V), 0));

    beta = b(2);
    se_beta = se(2);
    tstat = beta / se_beta;
    pval = 2 * (1 - normal_cdf(abs(tstat)));

    sst = sum((yv - mean(yv)).^2);
    ssr = sum(u.^2);
    if sst > 0
        rsq = 1 - ssr/sst;
    else
        rsq = NaN;
    end

    if std(yv) > 0 && std(xv) > 0
        c = corr(yv, xv, 'Rows','complete');
    else
        c = NaN;
    end

    fit.nobs = numel(yv);
    fit.beta = beta;
    fit.se = se_beta;
    fit.tstat = tstat;
    fit.pvalue = pval;
    fit.rsq = rsq;
    fit.corr_y_x = c;
end


function diag = diagnose_second_stage_beta_bias(y, x, Zextra, sample, cfg)
    % Diagnose whether the simple beta in
    %   y_t = a + beta x_t + u_t
    % may be sensitive to omitted controls.
    %
    % Important: E[x*u_hat]=0 is mechanically true in-sample for OLS because
    % x is included in the regression. Therefore the meaningful diagnostics are:
    %   1. beta stability after adding Zextra = [N_{t-1}, W_{t-1}],
    %   2. whether Zextra jointly predicts the simple-regression residual,
    %   3. whether x is correlated with Zextra.

    y = double(y(:));
    x = double(x(:));
    T = length(y);
    if nargin < 3 || isempty(Zextra)
        Zextra = zeros(T,0);
    end

    valid = sample(:) & isfinite(y) & isfinite(x);
    if ~isempty(Zextra)
        valid = valid & all(isfinite(Zextra),2);
    end

    yv = y(valid);
    xv = x(valid);
    Zv = Zextra(valid,:);
    n = numel(yv);

    diag = struct();
    diag.nobs = n;
    diag.beta_simple = NaN;
    diag.se_simple = NaN;
    diag.p_simple = NaN;
    diag.beta_controlled = NaN;
    diag.se_controlled = NaN;
    diag.p_controlled = NaN;
    diag.beta_diff = NaN;
    diag.beta_pct_change = NaN;
    diag.beta_abs_pct_change = NaN;
    diag.moment_xu_simple = NaN;
    diag.moment_xu_t_simple = NaN;
    diag.moment_xu_p_simple = NaN;
    diag.max_abs_mean_Zu_simple = NaN;
    diag.omitted_controls_F = NaN;
    diag.omitted_controls_p = NaN;
    diag.gpr_on_controls_F = NaN;
    diag.gpr_on_controls_p = NaN;
    diag.bias_concern_flag = false;
    diag.bias_concern_reason = "";

    if n <= 3
        return;
    end

    L = 0;
    if isfield(cfg, 'second_stage_hac_lag')
        L = cfg.second_stage_hac_lag;
    end

    % Simple regression: y on constant + x.
    Xs = [ones(n,1), xv];
    bs = Xs \ yv;
    us = yv - Xs * bs;
    Vs = hac_covariance(Xs, us, L);
    ses = sqrt(max(diag_vec(Vs), 0));
    diag.beta_simple = bs(2);
    diag.se_simple = ses(2);
    diag.p_simple = 2 * (1 - normal_cdf(abs(bs(2) / ses(2))));

    % Mechanical sample moment. This should be numerically zero because x is in Xs.
    xu = xv .* us;
    diag.moment_xu_simple = mean(xu, 'omitnan');
    se_m = hac_se_mean(xu, L);
    if isfinite(se_m) && se_m > 0
        diag.moment_xu_t_simple = diag.moment_xu_simple / se_m;
        diag.moment_xu_p_simple = 2 * (1 - normal_cdf(abs(diag.moment_xu_t_simple)));
    end

    % Controlled regression: y on constant + x + excluded controls.
    if ~isempty(Zv)
        Xc = [ones(n,1), xv, Zv];
        if n > size(Xc,2)
            bc = Xc \ yv;
            uc = yv - Xc * bc;
            Vc = hac_covariance(Xc, uc, L);
            sec = sqrt(max(diag_vec(Vc), 0));
            diag.beta_controlled = bc(2);
            diag.se_controlled = sec(2);
            diag.p_controlled = 2 * (1 - normal_cdf(abs(bc(2) / sec(2))));

            diag.beta_diff = diag.beta_controlled - diag.beta_simple;
            if abs(diag.beta_simple) > 1e-12
                diag.beta_pct_change = diag.beta_diff / abs(diag.beta_simple);
                diag.beta_abs_pct_change = abs(diag.beta_pct_change);
            end

            % Omitted-control test: do lagged count/macros explain the simple residual?
            % This is equivalent to asking whether residuals still contain structure
            % that could be correlated with x.
            [Fz, pz] = nested_ols_f_test(yv, Xs, Xc);
            diag.omitted_controls_F = Fz;
            diag.omitted_controls_p = pz;

            zu = Zv .* us;
            mean_Zu = mean(zu, 1, 'omitnan');
            mean_Zu = mean_Zu(isfinite(mean_Zu));
            if ~isempty(mean_Zu)
                diag.max_abs_mean_Zu_simple = max(abs(mean_Zu));
            end
        end

        % Test whether x is predictable from the excluded controls.
        Xr = ones(n,1);
        Xu = [ones(n,1), Zv];
        if n > size(Xu,2)
            [Fx, px] = nested_ols_f_test(xv, Xr, Xu);
            diag.gpr_on_controls_F = Fx;
            diag.gpr_on_controls_p = px;
        end
    else
        diag.beta_controlled = diag.beta_simple;
        diag.se_controlled = diag.se_simple;
        diag.p_controlled = diag.p_simple;
        diag.beta_diff = 0;
        diag.beta_pct_change = 0;
        diag.beta_abs_pct_change = 0;
    end

    thresh = 0.25;
    if isfield(cfg, 'bias_beta_change_flag_threshold')
        thresh = cfg.bias_beta_change_flag_threshold;
    end

    reasons = strings(0,1);
    if isfinite(diag.omitted_controls_p) && diag.omitted_controls_p < 0.10
        reasons(end+1) = "excluded controls predict residual"; %#ok<AGROW>
    end
    if isfinite(diag.gpr_on_controls_p) && diag.gpr_on_controls_p < 0.10
        reasons(end+1) = "GPR correlated with excluded controls"; %#ok<AGROW>
    end
    if isfinite(diag.beta_abs_pct_change) && diag.beta_abs_pct_change > thresh
        reasons(end+1) = "beta changes after controls"; %#ok<AGROW>
    end

    % Flag only if there is both residual structure and either GPR-control
    % correlation or substantial beta movement.
    flag_resid = isfinite(diag.omitted_controls_p) && diag.omitted_controls_p < 0.10;
    flag_xz = isfinite(diag.gpr_on_controls_p) && diag.gpr_on_controls_p < 0.10;
    flag_move = isfinite(diag.beta_abs_pct_change) && diag.beta_abs_pct_change > thresh;
    diag.bias_concern_flag = flag_resid && (flag_xz || flag_move);
    diag.bias_concern_reason = strjoin(reasons, '; ');
end

function [F, pval] = nested_ols_f_test(y, XR, XU)
    y = double(y(:));
    XR = double(XR);
    XU = double(XU);
    n = length(y);
    kR = size(XR,2);
    kU = size(XU,2);
    q = kU - kR;

    F = NaN;
    pval = NaN;
    if q <= 0 || n <= kU
        return;
    end

    bR = XR \ y;
    uR = y - XR * bR;
    ssrR = sum(uR.^2);

    bU = XU \ y;
    uU = y - XU * bU;
    ssrU = sum(uU.^2);

    if ssrU > 0
        F = ((ssrR - ssrU) / q) / (ssrU / (n - kU));
        if F < 0 && abs(F) < 1e-10
            F = 0;
        end
        pval = ftest_pvalue(F, q, n - kU);
    end
end

function se = hac_se_mean(v, L)
    v = double(v(:));
    v = v(isfinite(v));
    n = numel(v);
    se = NaN;
    if n <= 1
        return;
    end
    v = v - mean(v);
    L = min(max(round(L),0), n-1);
    lrvar = mean(v.^2);
    for ell = 1:L
        w = 1 - ell/(L+1);
        gamma = mean(v((ell+1):n) .* v(1:(n-ell)));
        lrvar = lrvar + 2*w*gamma;
    end
    se = sqrt(max(lrvar,0) / n);
end

function d = diag_vec(A)
    d = diag(A);
end

function V = hac_covariance(X, u, L)
    % Newey-West HAC covariance: (X'X)^(-1) S (X'X)^(-1)
    X = double(X);
    u = double(u(:));
    [n,k] = size(X);
    L = min(max(round(L),0), n-1);

    Xu = X .* u;
    S = Xu' * Xu;
    for ell = 1:L
        w = 1 - ell/(L+1);
        Gamma = Xu((ell+1):n,:)' * Xu(1:(n-ell),:);
        S = S + w * (Gamma + Gamma');
    end

    XXinv = pinv(X' * X);
    V = XXinv * S * XXinv;
end

function p = normal_cdf(x)
    p = 0.5 .* erfc(-x ./ sqrt(2));
end

%% ======================= HELPER FUNCTIONS =======================

function fit = fit_poisson_intensity_test(N, gpr_series, controls, sample, cfg, gpr_lags, label)
    N = double(N(:));
    N(~isfinite(N)) = NaN;
    N(N < 0) = NaN;

    gpr_series = double(gpr_series(:));
    T = length(N);

    if isempty(controls)
        controls = zeros(T,0);
    end

    nC = size(controls,2);

    maxLag = max([gpr_lags(:); 1]);
    t_grid = (maxLag+1):T;

    Y0 = N(t_grid);

    % Build GPR terms.
    G0 = nan(numel(t_grid), numel(gpr_lags));
    for jj = 1:numel(gpr_lags)
        L = gpr_lags(jj);
        if L == 0
            G0(:,jj) = gpr_series(t_grid);
        else
            G0(:,jj) = gpr_series(t_grid - L);
        end
    end

    % Restricted controls: const handled inside fit function; here only non-constant predictors.
    Xbase0 = [];

    if isfield(cfg, 'include_lagged_count') && cfg.include_lagged_count
        Xbase0 = [Xbase0, N(t_grid-1)]; %#ok<AGROW>
    end

    if isfield(cfg, 'include_lagged_macro_controls') && cfg.include_lagged_macro_controls && nC > 0
        Xbase0 = [Xbase0, controls(t_grid-1,:)]; %#ok<AGROW>
    end

    valid = sample(t_grid) & sample(t_grid-1) & isfinite(Y0) & all(isfinite(G0),2);
    if ~isempty(Xbase0)
        valid = valid & all(isfinite(Xbase0),2);
    end

    Y = Y0(valid);
    G = G0(valid,:);
    Xbase = Xbase0(valid,:);

    min_positive = 4;
    if isfield(cfg, 'min_positive_periods')
        min_positive = cfg.min_positive_periods;
    end

    nobs = numel(Y);
    n_positive = sum(Y > 0);
    n_zero = sum(Y == 0);
    total_count = sum(Y);

    lambda_full = nan(T,1);
    lambda_restricted = nan(T,1);

    fit = empty_fit_struct();
    fit.label = string(label);
    fit.nobs = nobs;
    fit.positive_periods = n_positive;
    fit.zero_periods = n_zero;
    fit.total_count = total_count;
    fit.num_gpr_terms = size(G,2);

    if nobs <= (size(Xbase,2) + size(G,2) + 1) || n_positive < min_positive || total_count <= 0
        warning('Too few observations/positive periods for %s: n=%d positives=%d total=%g.', label, nobs, n_positive, total_count);
        fit.lambda_full = lambda_full;
        fit.lambda_restricted = lambda_restricted;
        return;
    end

    standardize_predictors = true;
    if isfield(cfg, 'standardize_predictors')
        standardize_predictors = cfg.standardize_predictors;
    end

    Xfull_raw = [G, Xbase];
    Xrestr_raw = Xbase;

    [Xfull, muFull, sdFull] = standardize_design_columns(Xfull_raw, standardize_predictors);
    [Xrestr, muRestr, sdRestr] = standardize_design_columns(Xrestr_raw, standardize_predictors);

    [bFull, methodFull, convFull, llFull, devFull] = fit_poisson_count(Y, Xfull, cfg);
    [bRestr, methodRestr, convRestr, llRestr, devRestr] = fit_poisson_count(Y, Xrestr, cfg);

    kFull = numel(bFull);
    kRestr = numel(bRestr);
    df = kFull - kRestr;

    LR = 2 * (llFull - llRestr);
    if LR < 0 && abs(LR) < 1e-8
        LR = 0;
    end
    pLR = chi2_pvalue(LR, df);

    etaFull = [ones(size(Xfull,1),1), Xfull] * bFull;
    lambdaUseFull = clamp_intensity(exp(max(min(etaFull, 30), -30)));

    etaRestr = [ones(size(Xrestr,1),1), Xrestr] * bRestr;
    lambdaUseRestr = clamp_intensity(exp(max(min(etaRestr, 30), -30)));

    idx = t_grid(valid);
    lambda_full(idx) = lambdaUseFull;
    lambda_restricted(idx) = lambdaUseRestr;

    aicFull = 2*kFull - 2*llFull;
    aicRestr = 2*kRestr - 2*llRestr;

    bG = bFull(2:(1+size(G,2)));

    mean_lambda_positive = mean(lambdaUseFull(Y > 0), 'omitnan');
    mean_lambda_zero = mean(lambdaUseFull(Y == 0), 'omitnan');

    if std(Y) > 0 && std(lambdaUseFull) > 0
        corr_N_lambda = corr(Y, lambdaUseFull, 'Rows','complete');
    else
        corr_N_lambda = NaN;
    end

    [olsF, olsp] = deal(NaN);
    if isfield(cfg, 'run_ols_lambda_diagnostic') && cfg.run_ols_lambda_diagnostic
        [olsF, olsp] = ols_test_lambda_on_gpr(lambdaUseFull, G, Xbase);
    end

    fit.coeff_full = bFull;
    fit.coeff_restricted = bRestr;
    fit.method_full = methodFull;
    fit.method_restricted = methodRestr;
    fit.converged_full = convFull;
    fit.converged_restricted = convRestr;
    fit.loglik_full = llFull;
    fit.loglik_restricted = llRestr;
    fit.lr_stat = LR;
    fit.lr_df = df;
    fit.lr_p_value = pLR;
    fit.deviance_full = devFull;
    fit.deviance_restricted = devRestr;
    fit.aic_full = aicFull;
    fit.aic_restricted = aicRestr;
    fit.first_gpr_coeff = bG(1);
    fit.sum_gpr_coeff = sum(bG);
    fit.mean_lambda_full = mean(lambdaUseFull, 'omitnan');
    fit.mean_lambda_restricted = mean(lambdaUseRestr, 'omitnan');
    fit.mean_lambda_positive_full = mean_lambda_positive;
    fit.mean_lambda_zero_full = mean_lambda_zero;
    fit.corr_N_lambda_full = corr_N_lambda;
    fit.ols_lambda_F = olsF;
    fit.ols_lambda_p_value = olsp;
    fit.lambda_full = lambda_full;
    fit.lambda_restricted = lambda_restricted;
    fit.predictor_mean_full = muFull;
    fit.predictor_sd_full = sdFull;
    fit.predictor_mean_restricted = muRestr;
    fit.predictor_sd_restricted = sdRestr;
end

function fit = empty_fit_struct()
    fit = struct();
    fit.label = "";
    fit.nobs = NaN;
    fit.positive_periods = NaN;
    fit.zero_periods = NaN;
    fit.total_count = NaN;
    fit.num_gpr_terms = NaN;
    fit.coeff_full = NaN;
    fit.coeff_restricted = NaN;
    fit.method_full = "";
    fit.method_restricted = "";
    fit.converged_full = false;
    fit.converged_restricted = false;
    fit.loglik_full = NaN;
    fit.loglik_restricted = NaN;
    fit.lr_stat = NaN;
    fit.lr_df = NaN;
    fit.lr_p_value = NaN;
    fit.deviance_full = NaN;
    fit.deviance_restricted = NaN;
    fit.aic_full = NaN;
    fit.aic_restricted = NaN;
    fit.first_gpr_coeff = NaN;
    fit.sum_gpr_coeff = NaN;
    fit.mean_lambda_full = NaN;
    fit.mean_lambda_restricted = NaN;
    fit.mean_lambda_positive_full = NaN;
    fit.mean_lambda_zero_full = NaN;
    fit.corr_N_lambda_full = NaN;
    fit.ols_lambda_F = NaN;
    fit.ols_lambda_p_value = NaN;
    fit.lambda_full = NaN;
    fit.lambda_restricted = NaN;
end

function [F, pval] = ols_test_lambda_on_gpr(lambda, G, Xbase)
    y = lambda(:);
    valid = isfinite(y) & all(isfinite(G),2);
    if ~isempty(Xbase)
        valid = valid & all(isfinite(Xbase),2);
    end

    y = y(valid);
    G = G(valid,:);
    Xbase = Xbase(valid,:);

    XR = [ones(numel(y),1), Xbase];
    XU = [ones(numel(y),1), G, Xbase];

    n = numel(y);
    q = size(G,2);
    kU = size(XU,2);

    F = NaN;
    pval = NaN;

    if n <= kU
        return;
    end

    bR = XR \ y;
    uR = y - XR*bR;
    ssrR = sum(uR.^2);

    bU = XU \ y;
    uU = y - XU*bU;
    ssrU = sum(uU.^2);

    if ssrU > 0
        F = ((ssrR - ssrU)/q) / (ssrU/(n-kU));
        if F < 0 && abs(F) < 1e-10
            F = 0;
        end
        pval = ftest_pvalue(F, q, n-kU);
    end
end

function [b, method, converged, loglik, dev] = fit_poisson_count(Y, X, cfg)
    Y = double(Y(:));
    X = double(X);

    % Try glmfit if Statistics Toolbox exists.
    if exist('glmfit', 'file') == 2
        try
            [b, ~, stats] = glmfit(X, Y, 'poisson', 'link', 'log');
            method = "glmfit_poisson";
            converged = true;
            if isfield(stats, 'se') && any(~isfinite(stats.se))
                converged = false;
            end

            mu = clamp_intensity(exp([ones(size(X,1),1), X] * b));
            loglik = poisson_loglik(Y, mu);
            dev = poisson_deviance(Y, mu);
            return;
        catch ME
            warning('glmfit Poisson failed: %s. Falling back to fminsearch.', ME.message);
        end
    end

    % Fallback: base MATLAB fminsearch.
    k = size(X,2);
    ybar = max(mean(Y, 'omitnan'), 1e-6);

    b0 = zeros(k+1,1);
    b0(1) = log(ybar);

    lambda = 0;
    if isfield(cfg, 'poisson_ridge_lambda')
        lambda = cfg.poisson_ridge_lambda;
    end

    obj = @(theta) poisson_negloglik(theta, Y, X, lambda);
    opts = optimset('Display','off','MaxIter',20000,'MaxFunEvals',50000,'TolX',1e-8,'TolFun',1e-8);

    [b, ~, exitflag] = fminsearch(obj, b0, opts);

    method = "fminsearch_poisson";
    converged = exitflag > 0;

    mu = clamp_intensity(exp(max(min([ones(size(X,1),1), X] * b, 30), -30)));
    loglik = poisson_loglik(Y, mu);
    dev = poisson_deviance(Y, mu);
end

function nll = poisson_negloglik(theta, Y, X, lambda)
    eta = [ones(size(X,1),1), X] * theta(:);
    mu = clamp_intensity(exp(max(min(eta, 30), -30)));
    nll = -poisson_loglik(Y, mu);

    if nargin >= 4 && isfinite(lambda) && lambda > 0
        nll = nll + lambda * sum(theta(2:end).^2);
    end
end

function ll = poisson_loglik(Y, mu)
    mu = clamp_intensity(mu(:));
    Y = Y(:);
    ll = sum(Y .* log(mu) - mu - gammaln(Y + 1));
end

function dev = poisson_deviance(Y, mu)
    Y = double(Y(:));
    mu = clamp_intensity(mu(:));
    term = zeros(size(Y));

    pos = Y > 0;
    term(pos) = Y(pos) .* log(Y(pos) ./ mu(pos)) - (Y(pos) - mu(pos));
    term(~pos) = mu(~pos);

    dev = 2 * sum(term, 'omitnan');
end

function mu = clamp_intensity(mu)
    mu = min(max(mu, 1e-8), 1e8);
end

function p = chi2_pvalue(x, df)
    if ~isfinite(x) || x < 0 || df <= 0
        p = NaN;
        return;
    end

    if exist('chi2cdf', 'file') == 2
        p = 1 - chi2cdf(x, df);
    else
        p = 1 - gammainc(x/2, df/2);
    end
end

function p = ftest_pvalue(F, d1, d2)
    if ~isfinite(F) || F < 0 || d1 <= 0 || d2 <= 0
        p = NaN;
        return;
    end

    if exist('fcdf', 'file') == 2
        p = 1 - fcdf(F, d1, d2);
    else
        x = (d1 * F) / (d1 * F + d2);
        p = 1 - betainc(x, d1/2, d2/2);
    end
end

function [Xstd, muX, sdX] = standardize_design_columns(X, do_standardize)
    Xstd = X;
    muX = zeros(1,size(X,2));
    sdX = ones(1,size(X,2));

    if ~do_standardize || isempty(X)
        return;
    end

    for j = 1:size(X,2)
        xj = X(:,j);
        mu = mean(xj, 'omitnan');
        sd = std(xj, 'omitnan');

        if isfinite(sd) && sd > 0
            Xstd(:,j) = (xj - mu) ./ sd;
            muX(j) = mu;
            sdX(j) = sd;
        else
            Xstd(:,j) = xj;
            muX(j) = 0;
            sdX(j) = 1;
        end
    end
end

function dummy_aligned = build_aligned_dummy_table(DB, quarter_labels, has_quarter, T, cfg)
    dummy_aligned = table();

    if ~has_quarter
        warning('No Quarter/Date column found in level database. Dummy controls cannot be aligned.');
        return;
    end

    q_db = string(quarter_labels(:));
    dummy_aligned = table(q_db, 'VariableNames', {'Quarter'});

    D = load_dummy_table_from_file(cfg);
    if isempty(D), return; end

    qD = get_quarter_from_dummy_table(D);
    if isempty(qD)
        warning('Dummy file loaded, but no Quarter/date column was found.');
        return;
    end

    qD = string(qD(:));
    dnames = D.Properties.VariableNames;
    [tf, loc] = ismember(q_db, qD);

    for j = 1:numel(dnames)
        v = dnames{j};

        if any(strcmpi(v, {'Quarter','quarter','Date','date','Time','time'}))
            continue;
        end

        raw = D.(v);
        if isnumeric(raw) || islogical(raw)
            x = double(raw(:));
        else
            continue;
        end

        if numel(x) ~= numel(qD)
            continue;
        end

        aligned = zeros(T,1);
        aligned(tf) = x(loc(tf));
        aligned(~isfinite(aligned)) = 0;

        safe_v = matlab.lang.makeValidName(v);
        dummy_aligned.(safe_v) = aligned;
    end
end

function D = load_dummy_table_from_file(cfg)
    D = table();

    candidate_files = {};
    if isfield(cfg, 'dummy_file') && ~isempty(cfg.dummy_file)
        candidate_files{end+1} = cfg.dummy_file; %#ok<AGROW>
    end
    if isfield(cfg, 'dummy_csv_fallback') && ~isempty(cfg.dummy_csv_fallback)
        candidate_files{end+1} = cfg.dummy_csv_fallback; %#ok<AGROW>
    end
    if isfield(cfg, 'dummy_csv_fallbacks') && ~isempty(cfg.dummy_csv_fallbacks)
        for ii = 1:numel(cfg.dummy_csv_fallbacks)
            candidate_files{end+1} = cfg.dummy_csv_fallbacks{ii}; %#ok<AGROW>
        end
    end

    candidate_files = unique(candidate_files, 'stable');

    chosen = '';
    for ii = 1:numel(candidate_files)
        if exist(candidate_files{ii}, 'file')
            chosen = candidate_files{ii};
            break;
        end
    end

    if isempty(chosen)
        warning('No dummy MAT/CSV file found.');
        return;
    end

    [~,~,ext] = fileparts(chosen);
    if strcmpi(ext, '.mat')
        raw = load(chosen);
        D = unpack_dummy_database(raw);
        fprintf('\nLoaded dummy MAT file: %s\n', chosen);
    else
        D = readtable(chosen, 'VariableNamingRule','preserve');
        fprintf('\nLoaded dummy CSV file: %s\n', chosen);
    end

    if ~istable(D)
        warning('Loaded dummy object is not a table.');
        D = table();
    end
end

function D = unpack_dummy_database(raw)
    fns = fieldnames(raw);

    for i = 1:numel(fns)
        obj = raw.(fns{i});
        if istable(obj)
            D = obj;
            return;
        end
    end

    if numel(fns) > 0
        S = struct();
        n = [];
        for i = 1:numel(fns)
            obj = raw.(fns{i});
            if isvector(obj) && (isnumeric(obj) || islogical(obj) || iscell(obj) || isstring(obj) || isdatetime(obj))
                obj = obj(:);
                if isempty(n), n = numel(obj); end
                if numel(obj) == n
                    S.(fns{i}) = obj;
                end
            end
        end

        if ~isempty(fieldnames(S))
            D = struct2table(S);
            return;
        end
    end

    D = table();
end

function q = get_quarter_from_dummy_table(D)
    q = [];
    if isempty(D), return; end

    names = D.Properties.VariableNames;
    candidates = {'Quarter','quarter','Date','date','time','Time'};

    for i = 1:numel(candidates)
        idx = find(strcmpi(names, candidates{i}), 1);
        if ~isempty(idx)
            raw = D.(names{idx});
            q = cellstr(string(raw(:)));
            return;
        end
    end
end

function [x, source_name] = get_event_count_or_dummy_series(dummy_aligned, varname, T)
    source_name = varname;
    x = get_dummy_series(dummy_aligned, varname, T);

    if ~isempty(x)
        return;
    end

    if startsWith(varname, 'n_')
        alt = regexprep(varname, '^n_', '');
        x = get_dummy_series(dummy_aligned, alt, T);
        if ~isempty(x)
            source_name = alt;
            return;
        end
    else
        alt = ['n_' varname];
        x = get_dummy_series(dummy_aligned, alt, T);
        if ~isempty(x)
            source_name = alt;
            return;
        end
    end
end

function x = get_dummy_series(dummy_aligned, varname, T)
    x = [];
    if isempty(dummy_aligned), return; end

    if ismember(varname, dummy_aligned.Properties.VariableNames)
        x = double(dummy_aligned.(varname)(:));
        if numel(x) ~= T
            x = [];
        end
    end
end

function [quarter_labels, has_quarter] = get_quarter_labels(DB, T)
    quarter_labels = repmat({''}, T, 1);
    has_quarter = false;

    names = DB.Properties.VariableNames;

    idx = find(strcmpi(names, 'quarter') | strcmpi(names, 'Quarter') | strcmpi(names, 'date') | strcmpi(names, 'Date'), 1);

    if isempty(idx)
        return;
    end

    q = DB.(names{idx});
    has_quarter = true;

    if iscell(q)
        quarter_labels = q(:);
    else
        quarter_labels = cellstr(string(q(:)));
    end
end

function x = get_series_if_exists(DB, targets, T)
    if ischar(targets) || isstring(targets)
        targets = cellstr(targets);
    end

    names = DB.Properties.VariableNames;
    x = [];

    for ii = 1:numel(targets)
        target = char(targets{ii});

        idx = find(strcmpi(names, target), 1, 'first');

        if isempty(idx)
            idx = find(startsWith(names, target, 'IgnoreCase', true), 1, 'first');
        end

        if ~isempty(idx)
            raw = DB.(names{idx});

            if isnumeric(raw) || islogical(raw)
                x = double(raw(:));

                if numel(x) ~= T
                    warning('Variable %s has incompatible length and is skipped.', names{idx});
                    x = [];
                end

                return;
            else
                x = [];
                return;
            end
        end
    end
end

function x = get_required_series(DB, targets, T)
    x = get_series_if_exists(DB, targets, T);

    if isempty(x)
        if ischar(targets) || isstring(targets)
            msg = char(targets);
        else
            msg = strjoin(cellstr(targets), ', ');
        end

        error('Required numeric variable not found. Tried: %s', msg);
    end
end

function [controls, control_names] = build_controls(DB, control_aliases, T)
    controls = [];
    control_names = {};

    for i = 1:numel(control_aliases)
        x = get_series_if_exists(DB, control_aliases{i}, T);

        if ~isempty(x)
            controls = [controls, x]; %#ok<AGROW>
            control_names{end+1} = char(control_aliases{i}{1}); %#ok<AGROW>
        else
            warning('Control not found and skipped: %s', strjoin(control_aliases{i}, ', '));
        end
    end
end

function out = extract_ar_level_innovation_with_controls(x, shock_controls, sample, p, timing, label)
    % Extract GPR innovation from an AR(p) model augmented with business-cycle controls.
    %
    % timing = 'contemporaneous':
    %   GPR_t = a + sum_j phi_j GPR_{t-j} + gamma' B_t + u_t
    %
    % timing = 'lagged':
    %   GPR_t = a + sum_j phi_j GPR_{t-j} + gamma' B_{t-1} + u_t
    %
    % Here B_t is typically [Unemployment_t, FFR_t].

    x = x(:);
    T = length(x);

    if nargin < 2 || isempty(shock_controls)
        shock_controls = zeros(T,0);
    end
    shock_controls = double(shock_controls);
    if size(shock_controls,1) ~= T
        error('shock_controls has incompatible number of rows for %s.', label);
    end

    if nargin < 5 || isempty(timing)
        timing = 'contemporaneous';
    end
    timing = lower(string(timing));

    nC = size(shock_controls,2);
    t_grid = (p+1):T;
    n = numel(t_grid);
    k = 1 + p + nC;

    Y = nan(n,1);
    X = nan(n,k);
    keep = false(n,1);

    for ii = 1:n
        t = t_grid(ii);
        row = nan(1,k);
        row(1) = 1;

        % AR(p) lags of the GPR level.
        for j = 1:p
            row(1+j) = x(t-j);
        end

        % Business-cycle controls used in shock extraction.
        if nC > 0
            switch timing
                case "contemporaneous"
                    bc_row = shock_controls(t,:);
                    keep_bc = sample(t);
                case "lagged"
                    bc_row = shock_controls(t-1,:);
                    keep_bc = sample(t-1);
                otherwise
                    error('Unknown cfg.gpr_shock_control_timing = %s. Use contemporaneous or lagged.', timing);
            end
            row((1+p+1):end) = bc_row;
        else
            keep_bc = true;
        end

        Y(ii) = x(t);
        X(ii,:) = row;

        keep(ii) = sample(t) && all(sample(t-p:t)) && keep_bc;
    end

    good = keep & isfinite(Y) & all(isfinite(X),2);

    Yg = Y(good);
    Xg = X(good,:);
    tg = t_grid(good)';

    if isempty(Yg) || size(Xg,1) <= size(Xg,2)
        error('No usable observations in AR+business-cycle shock extraction for %s.', label);
    end

    b = Xg \ Yg;

    fitted = nan(T,1);
    resid  = nan(T,1);

    fitted(tg) = Xg * b;
    resid(tg)  = Yg - Xg * b;

    u = resid(tg);

    sse = sum(u.^2);
    sst = sum((Yg - mean(Yg)).^2);

    if sst > 0
        rsq = 1 - sse / sst;
    else
        rsq = NaN;
    end

    out = struct('label',label,'t_index',tg,'coeff',b,'fitted',fitted,'resid',resid, ...
        'nobs',numel(Yg),'rsq',rsq,'mean_resid',mean(u),'std_resid',std(u), ...
        'num_ar_lags',p,'num_bc_controls',nC,'bc_timing',timing);
end

function z = zscore_in_sample(x, sample)
    x = x(:);

    use = sample & isfinite(x);

    mu = mean(x(use));
    sd = std(x(use));

    if ~isfinite(sd) || sd == 0
        warning('Standard deviation is zero or invalid. Returning unstandardized series.');
        z = x;
    else
        z = (x - mu) ./ sd;
    end
end

function s = strjoin_or_none(names)
    if isempty(names)
        s = 'none';
    else
        s = strjoin(names, ', ');
    end
end

function fname = make_field_name(s)
    fname = matlab.lang.makeValidName(char(s));
end
