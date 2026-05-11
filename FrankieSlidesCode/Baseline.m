clear; clc; close all;

%% -------------------- GLOBAL FIGURE STYLE --------------------
% Use LaTeX style for all figure texts.
set(groot, 'defaultTextInterpreter', 'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter', 'latex');
set(groot, 'defaultAxesFontSize', 14);
set(groot, 'defaultTextFontSize', 14);
set(groot, 'defaultAxesLineWidth', 1.2);
%% -------------------------------------------------------------

%% ============================================================
% BASELINE NO-VIX LEVEL-CHANGE LOCAL PROJECTIONS
%
% This script modifies the earlier level-change LP code in three ways:
%
%   STEP 1. GPR shocks are extracted from AR + business-cycle controls:
%
%       GPR_t = a + rho(L) GPR_{t-1:t-p} + gamma' C_t + u_t
%
%       where C_t includes Unemp and FFR if available.
%       The standardized residual u_t is the GPR shock z_t.
%
%   STEP 2. The LP still controls for:
%
%       - lags of y
%       - lags of GPR levels
%       - lags of macro controls, e.g. Unemp and FFR
%
%   STEP 3. The LP dependent variable is the level change:
%
%       y_{t+h} - y_{t-1}
%
%       y_{t+h} - y_{t-1}
%       = alpha_h + beta_h z_t
%         + lags(y) + lags(GPR level) + lags(controls) + e_{t+h}
%
% IMPORTANT:
%   beta_h is already a cumulative level-change response.
%   DO NOT cumulate beta_h again.
%% ============================================================

%% -------------------- USER SETTINGS --------------------
cfg.datafile = 'Q_Levels_Database.csv';
cfg.fallback_datafile = 'Q_Levels_Database(1).csv';
cfg.output_dir = 'Q_Baseline_NoVIX_LevelChangeLP_AR_BCShock';

cfg.save_results = false;
cfg.save_figures = false;
cfg.show_figures = true;

% Shock extraction from GPR levels.
% Current default: AR(4) + business-cycle controls.
% If you want old AR(1), set this to 1.
cfg.p_gpr_shock = 4;
cfg.standardize_shock = true;

% In shock extraction, use these lags of macro controls.
% 0 means contemporaneous controls C_t.
% Example: 0:4 would include C_t, C_{t-1}, ..., C_{t-4}.
cfg.gpr_shock_control_lags = 0;

% Level-change LP settings.
cfg.p_lp = 4;
cfg.H = 12;
cfg.ci = 0.90;

% z_t is standardized. Use 1 for a 1-s.d. shock; use 2 for old 2-s.d. plots.
cfg.shock_size = 2;

cfg.horizon_label = 'Horizon (quarters)';

% Figure splitting:
% Each outcome creates 2 panels: left = World, right = Threat/Act.
% max_panels_per_figure = 6 means at most 3 outcomes per figure.
cfg.max_panels_per_figure = 6;

% Baseline no-VIX controls. Missing controls are skipped automatically.
% These controls are used in BOTH:
%   1. GPR shock extraction
%   2. LP controls, through lags
cfg.control_aliases = { ...
    {'Unemp','Unemployment'}, ...
    {'FFR','Policy_Rate','EffPolicyRate','ShadowRate'} ...
};

% Aggregate GPR measures.
cfg.shock_specs = {
    'World',  {'LGPR'},  'World GPR shock';
    'Threat', {'LGPRT'}, 'Geopolitical Threats shock';
    'Act',    {'LGPRA'}, 'Geopolitical Acts shock'
};

% Outcomes.
% All six outcomes are raw level variables, so the LP dependent variable is:
%
%   y_{t+h} - y_{t-1}
%
% Baseline macro outcomes:
%   - Headline CPI
%   - Core CPI
%   - Industrial production
%
% Added oil-price outcomes:
%   - Brent oil price
%   - WTI crude oil price
%   - Gasoline price
%
% transform:
%   'none'     = use the column as-is.
%   'times100' = multiply by 100, useful if a column is in decimal units.
%   '100log'   = take 100*log(raw level), useful if a column is raw positive index.
%
cfg.outcome_specs = {
    'Headline_Pi',   {'Headline_Pi','Pi_Headline','CPI_Headline','Headline_CPI','CPIAUCSL'}, 'Headline CPI level',            'none',     'level_change';
    'Core_Pi',       {'Core_Pi','Pi_Core','CPI_Core','Core_CPI','CPILFESL'},                 'Core CPI level',                'none',     'level_change';
    'Indu_Prod',     {'Indu_Prod','g_Indu_level','INDPRO','IndustrialProduction','IP'},      'Industrial production level',   'times100', 'level_change';
    'Real_Brent',    {'Real_Brent','Brent','Brent_Oil','RealBrent'},                         'Brent oil price',               'none',     'level_change';
    'Real_WTI',      {'Real_WTI','WTI','RealWTI','WTI_Crude'},                               'WTI crude oil price',           'none',     'level_change';
    'Real_Gasoline', {'Real_Gasoline','Gasoline','RealGasoline','Gasoline_Price'},           'Gasoline price',                'none',     'level_change'
};
%% -------------------------------------------------------

if cfg.save_results || cfg.save_figures
    if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
end

fprintf('\n=== Baseline no-VIX LEVEL-CHANGE LP: macro + oil prices, all y_{t+h}-y_{t-1} ===\n');
fprintf('Requested data file: %s\n', cfg.datafile);
fprintf('GPR shock extraction: AR(%d) + business-cycle controls.\n', cfg.p_gpr_shock);
fprintf('Shock-extraction control lags: %s\n', mat2str(cfg.gpr_shock_control_lags));
fprintf('LP lags: %d; horizon: 0:%d; shock size: %.2f s.d.\n', cfg.p_lp, cfg.H, cfg.shock_size);

%% -------------------- LOAD LEVEL DATABASE --------------------
if ~exist(cfg.datafile, 'file')
    if exist(cfg.fallback_datafile, 'file')
        fprintf('Main data file not found. Using fallback: %s\n', cfg.fallback_datafile);
        cfg.datafile = cfg.fallback_datafile;
    else
        error('Data file not found: %s. Put this script in the same folder as Q_Levels_Database.csv or update cfg.datafile.', cfg.datafile);
    end
end

DB = readtable(cfg.datafile, 'VariableNamingRule','preserve');
T = height(DB);
varnames = DB.Properties.VariableNames;
fprintf('Loaded rows T = %d, variables = %d\n', T, numel(varnames));
fprintf('Available variables:\n');
fprintf('  %s\n', strjoin(varnames, ', '));

[quarter_labels, has_quarter] = get_quarter_labels(DB, T);
if has_quarter
    fprintf('Sample starts at %s and ends at %s\n', quarter_labels{1}, quarter_labels{end});
end

% Use the full CSV sample. This avoids accidentally inheriting an old H1_sample mask.
sample = true(T,1);
fprintf('Using full sample: %d / %d rows are active.\n', sum(sample), T);

[controls, control_names] = build_controls(DB, cfg.control_aliases, T);
if isempty(control_names)
    fprintf('Macro controls loaded: none\n');
else
    fprintf('Macro controls loaded: %s\n', strjoin(control_names, ', '));
    for j = 1:numel(control_names)
        fprintf('  Control %-18s finite = %3d / %3d\n', control_names{j}, sum(isfinite(controls(:,j))), T);
    end
end

%% -------------------- CONSTRUCT STANDARDIZED GPR SHOCKS --------------------
Z = struct();
GPR_levels = struct();
innovation_info = table();

fprintf('\n--- Constructing standardized shocks from GPR AR + business-cycle residuals ---\n');
for s = 1:size(cfg.shock_specs,1)
    sid = cfg.shock_specs{s,1};
    aliases = cfg.shock_specs{s,2};
    label = cfg.shock_specs{s,3};

    gpr = get_required_series(DB, aliases, T);
    GPR_levels.(sid) = gpr;

    innov = extract_ar_level_innovation_with_controls( ...
        gpr, controls, sample, cfg.p_gpr_shock, cfg.gpr_shock_control_lags, sid, control_names);

    if cfg.standardize_shock
        z = zscore_in_sample(innov.resid, sample);
    else
        z = innov.resid;
    end
    Z.(sid) = z;

    innovation_info = [innovation_info; table(string(sid), string(label), innov.nobs, innov.rsq, innov.std_resid, ...
        sum(isfinite(z)), string(strjoin(innov.regressor_names, ', ')), ...
        'VariableNames', {'shock','label','nobs','rsq','resid_sd','finite_z','shock_extraction_regressors'})]; %#ok<AGROW>

    fprintf('  %-7s: nobs=%3d, AR+controls R2=% .3f, resid sd=% .4f, finite z=%3d\n', ...
        sid, innov.nobs, innov.rsq, innov.std_resid, sum(isfinite(z)));
    fprintf('           regressors: %s\n', strjoin(innov.regressor_names, ', '));
end

%% -------------------- ESTIMATE DIRECT-LEVEL LOCAL PROJECTIONS --------------------
results_world  = struct();
results_threat = struct();
results_act    = struct();
level_change_lp_results = table();

outcome_ids = cfg.outcome_specs(:,1)';
outcome_labels = cfg.outcome_specs(:,3)';

fprintf('\n--- Estimating level-change local projections ---\n');
for i = 1:size(cfg.outcome_specs,1)
    yid = cfg.outcome_specs{i,1};
    aliases = cfg.outcome_specs{i,2};
    ylabel = cfg.outcome_specs{i,3};
    transform = cfg.outcome_specs{i,4};
    depvar_mode = cfg.outcome_specs{i,5};

    y_raw = get_required_series(DB, aliases, T);
    y = apply_y_transform(y_raw, transform, yid);

    fprintf('\nOutcome: %s\n', ylabel);
    fprintf('  finite y = %3d / %3d, transform = %s, depvar = %s\n', ...
        sum(isfinite(y)), T, transform, depvar_mode);

    rw = estimate_lp_level_change(y, Z.World,  GPR_levels.World,  controls, sample, cfg, 'World');
    rt = estimate_lp_level_change(y, Z.Threat, GPR_levels.Threat, controls, sample, cfg, 'Threat');
    ra = estimate_lp_level_change(y, Z.Act,    GPR_levels.Act,    controls, sample, cfg, 'Act');

    results_world.(yid)  = rw;
    results_threat.(yid) = rt;
    results_act.(yid)    = ra;

    print_lp_check('World',  rw, cfg);
    print_lp_check('Threat', rt, cfg);
    print_lp_check('Act',    ra, cfg);

    tmpw = rw.table; tmpw.shock = repmat("World",  height(tmpw), 1);
    tmpt = rt.table; tmpt.shock = repmat("Threat", height(tmpt), 1);
    tmpa = ra.table; tmpa.shock = repmat("Act",    height(tmpa), 1);

    tmp = [tmpw; tmpt; tmpa];
    tmp.outcome = repmat(string(yid), height(tmp), 1);
    tmp.outcome_label = repmat(string(ylabel), height(tmp), 1);
    tmp.specification = repmat("level_change_y_tph_minus_y_tm1_AR_BCShock", height(tmp), 1);
    level_change_lp_results = [level_change_lp_results; tmp]; %#ok<AGROW>
end

assert_any_finite_results(results_world, results_threat, results_act, outcome_ids);

%% -------------------- PLOT SPLITWISE BASELINE DASHBOARDS --------------------
% Each outcome uses 2 panels. With cfg.max_panels_per_figure = 6,
% the code puts at most 3 outcomes in each figure.
figs = plot_side_by_side_splitwise_by_groups(results_world, results_threat, results_act, ...
    outcome_ids, outcome_labels, cfg);

for ff = 1:numel(figs)
    save_figure_if_needed(figs{ff}, cfg, fullfile(cfg.output_dir, ...
        sprintf('baseline_noVIX_levelChangeLP_AR_BCShock_splitwise_part%d', ff)));
end

%% -------------------- OPTIONAL SAVE --------------------
if cfg.save_results
    writetable(level_change_lp_results, fullfile(cfg.output_dir, 'baseline_noVIX_levelChangeLP_AR_BCShock_results.csv'));
    writetable(innovation_info, fullfile(cfg.output_dir, 'baseline_noVIX_levelChangeLP_AR_BCShock_diagnostics.csv'));
    save(fullfile(cfg.output_dir, 'workspace_baseline_noVIX_levelChangeLP_AR_BCShock.mat'), ...
        'cfg','Z','GPR_levels','innovation_info','level_change_lp_results', ...
        'results_world','results_threat','results_act','control_names');
    fprintf('\nSaved results in: %s\n', cfg.output_dir);
else
    fprintf('\nNo files saved because cfg.save_results=false and cfg.save_figures=false.\n');
    fprintf('Results are available in workspace: level_change_lp_results, results_world, results_threat, results_act, Z.\n');
end

%% ======================= LOCAL HELPER FUNCTIONS =======================

function [quarter_labels, has_quarter] = get_quarter_labels(DB, T)
    quarter_labels = repmat({''}, T, 1);
    has_quarter = false;
    names = DB.Properties.VariableNames;
    idx = find(strcmpi(names, 'quarter') | strcmpi(names, 'Quarter') | strcmpi(names, 'date') | strcmpi(names, 'Date'), 1);
    if isempty(idx), return; end
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
                warning('Variable %s was found but is not numeric, so it is skipped.', names{idx});
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

function y = apply_y_transform(y_raw, transform, yid)
    y_raw = double(y_raw(:));
    switch lower(char(transform))
        case 'none'
            y = y_raw;
        case 'times100'
            y = 100 .* y_raw;
        case '100log'
            y = nan(size(y_raw));
            ok = y_raw > 0 & isfinite(y_raw);
            y(ok) = 100 .* log(y_raw(ok));
            if any(~ok & isfinite(y_raw))
                warning('Outcome %s has non-positive values; 100log transform set them to NaN.', yid);
            end
        otherwise
            error('Unknown y transform for %s: %s', yid, transform);
    end
end

function out = extract_ar_level_innovation_with_controls(x, controls, sample, p, control_lags, label, control_names)
    x = x(:);
    T = length(x);

    if isempty(controls)
        controls = zeros(T,0);
    end
    nC = size(controls,2);

    if nargin < 5 || isempty(control_lags)
        control_lags = 0;
    end
    control_lags = unique(control_lags(:)');
    if any(control_lags < 0)
        error('control_lags must be non-negative.');
    end

    max_lag = max([p, control_lags]);
    t_grid = (max_lag+1):T;
    n = numel(t_grid);

    k = 1 + p + nC * numel(control_lags);
    Y = nan(n,1);
    X = nan(n,k);
    keep = false(n,1);

    regressor_names = {'const'};
    for j = 1:p
        regressor_names{end+1} = sprintf('GPR_L%d', j); %#ok<AGROW>
    end
    for L = control_lags
        for cidx = 1:nC
            regressor_names{end+1} = sprintf('%s_L%d', control_names{cidx}, L); %#ok<AGROW>
        end
    end

    for ii = 1:n
        t = t_grid(ii);
        row = nan(1,k);
        c = 1;

        row(c) = 1; c = c + 1;

        for j = 1:p
            row(c) = x(t-j);
            c = c + 1;
        end

        for L = control_lags
            if nC > 0
                row(c:c+nC-1) = controls(t-L,:);
                c = c + nC;
            end
        end

        Y(ii) = x(t);
        X(ii,:) = row;

        idx_need = t-max_lag:t;
        keep(ii) = sample(t) && all(sample(idx_need));
    end

    good = keep & isfinite(Y) & all(isfinite(X),2);
    Yg = Y(good);
    Xg = X(good,:);
    tg = t_grid(good)';

    if isempty(Yg) || size(Xg,1) <= size(Xg,2)
        error('No usable observations in AR + controls shock extraction for %s.', label);
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
        'regressor_names',{regressor_names});
end

function z = zscore_in_sample(x, sample)
    x = x(:);
    use = sample & isfinite(x);
    mu = mean(x(use));
    sd = std(x(use));
    if ~isfinite(sd) || sd == 0
        warning('Shock standard deviation is zero or invalid. Returning unstandardized residual.');
        z = x;
    else
        z = (x - mu) ./ sd;
    end
end

function res = estimate_lp_level_change(y, z, gpr_level, controls, sample, cfg, shock_tag)
    H = cfg.H;
    zcrit = normal_icdf(0.5 + cfg.ci/2);

    beta = nan(H+1,1);
    se   = nan(H+1,1);
    lb   = nan(H+1,1);
    ub   = nan(H+1,1);
    nobs = nan(H+1,1);

    dbg_by_h = repmat(struct('n_candidate',NaN,'sample_ok',NaN,'y_ok',NaN,'z_ok',NaN, ...
        'ylags_ok',NaN,'gprlags_ok',NaN,'controls_ok',NaN,'final_good',NaN), H+1, 1);

    for h = 0:H
        [Y, X, ~, dbg] = build_lp_level_change_design(y, z, gpr_level, controls, sample, cfg.p_lp, h);
        dbg_by_h(h+1) = dbg;

        if isempty(Y) || size(X,1) <= size(X,2)
            continue;
        end

        bw = min(h + 1, size(X,1)-1);
        [b, se_all] = ols_hac(Y, X, bw);

        beta(h+1) = cfg.shock_size * b(2);
        se(h+1)   = cfg.shock_size * se_all(2);
        lb(h+1)   = beta(h+1) - zcrit * se(h+1);
        ub(h+1)   = beta(h+1) + zcrit * se(h+1);
        nobs(h+1) = size(X,1);
    end

    res = struct();
    res.shock_tag = shock_tag;
    res.h = (0:H)';
    res.beta = beta;
    res.se = se;
    res.lb = lb;
    res.ub = ub;
    res.nobs = nobs;
    res.debug = dbg_by_h;
    res.response_ylabel = '\textbf{Level change: }$y_{t+h}-y_{t-1}$';

    res.table = table((0:H)', beta, se, lb, ub, nobs, ...
        'VariableNames', {'h','beta','se','lb','ub','nobs'});
end

function [Y, X, good, dbg] = build_lp_level_change_design(y, z, gpr_level, controls, sample, p, h)
    y = y(:);
    z = z(:);
    gpr_level = gpr_level(:);
    T = length(y);

    if isempty(controls)
        controls = zeros(T,0);
    end
    nC = size(controls,2);

    % t must have y(t-1), p lags, z(t), and y(t+h).
    % Because p>=1, y(t-1) is available.
    t_grid = (p+1):(T-h);
    n = numel(t_grid);

    % Columns: const, z_t, y-level lags, GPR-level lags, macro-control lags.
    % No lagged z-values are included.
    k = 1 + 1 + p + p + p*nC;
    X0 = nan(n,k);
    Y0 = nan(n,1);

    sample_ok = false(n,1);
    y_ok = false(n,1);
    z_ok = false(n,1);
    ylags_ok = false(n,1);
    gprlags_ok = false(n,1);
    controls_ok = true(n,1);

    for ii = 1:n
        t = t_grid(ii);
        c = 1;
        row = nan(1,k);

        % THIS IS THE ONLY LP DEPENDENT VARIABLE:
        % y_{t+h} - y_{t-1}
        Y0(ii) = y(t+h) - y(t-1);

        row(c) = 1; c = c + 1;
        row(c) = z(t); c = c + 1;

        ylag = nan(1,p);
        for j = 1:p
            ylag(j) = y(t-j);
            row(c) = ylag(j); c = c + 1;
        end

        gprlag = nan(1,p);
        for j = 1:p
            gprlag(j) = gpr_level(t-j);
            row(c) = gprlag(j); c = c + 1;
        end

        ctrl_block = [];
        if nC > 0
            for j = 1:p
                valsC = controls(t-j,:);
                row(c:c+nC-1) = valsC;
                ctrl_block = [ctrl_block, valsC]; %#ok<AGROW>
                c = c + nC;
            end
        end

        X0(ii,:) = row;

        sample_ok(ii) = sample(t) && sample(t+h) && all(sample(t-p:t));
        y_ok(ii) = isfinite(Y0(ii));
        z_ok(ii) = isfinite(z(t));
        ylags_ok(ii) = all(isfinite(ylag));
        gprlags_ok(ii) = all(isfinite(gprlag));
        if nC > 0
            controls_ok(ii) = all(isfinite(ctrl_block));
        end
    end

    good = sample_ok & y_ok & z_ok & ylags_ok & gprlags_ok & controls_ok & all(isfinite(X0),2);
    Y = Y0(good);
    X = X0(good,:);

    dbg = struct();
    dbg.n_candidate = n;
    dbg.sample_ok = sum(sample_ok);
    dbg.y_ok = sum(y_ok);
    dbg.z_ok = sum(z_ok);
    dbg.ylags_ok = sum(ylags_ok);
    dbg.gprlags_ok = sum(gprlags_ok);
    dbg.controls_ok = sum(controls_ok);
    dbg.final_good = sum(good);
end

function [b, se, V] = ols_hac(y, X, bw)
    [n, k] = size(X);
    if n <= k
        error('Not enough observations: n=%d, k=%d', n, k);
    end

    b = X \ y;
    u = y - X*b;

    bw = min(max(bw,0), n-1);
    XtX_inv = pinv(X' * X);

    S = zeros(k, k);
    for t = 1:n
        xt = X(t, :)';
        S = S + (u(t)^2) * (xt * xt');
    end

    for L = 1:bw
        wL = 1 - L / (bw + 1);
        Gamma = zeros(k, k);
        for t = (L+1):n
            xt = X(t, :)';
            xtL = X(t-L, :)';
            Gamma = Gamma + u(t) * u(t-L) * (xt * xtL');
        end
        S = S + wL * (Gamma + Gamma');
    end

    V = (n / (n - k)) * XtX_inv * S * XtX_inv;
    se = sqrt(max(diag(V),0));
end

function q = normal_icdf(p)
    q = -sqrt(2) * erfcinv(2 * p);
end

function print_lp_check(name, res, cfg)
    finite_beta = sum(isfinite(res.beta));
    h4 = min(4, cfg.H);
    fprintf('  %-7s: finite beta=%2d/%2d, nobs h0=%3.0f, nobs hH=%3.0f, beta h0=% .4f, beta h%d=% .4f\n', ...
        name, finite_beta, cfg.H+1, res.nobs(1), res.nobs(end), res.beta(1), h4, res.beta(h4+1));

    if finite_beta == 0
        d = res.debug(1);
        fprintf('    Debug h=0: candidate=%d, sample_ok=%d, y_ok=%d, z_ok=%d, ylags_ok=%d, gprlags_ok=%d, controls_ok=%d, final_good=%d\n', ...
            d.n_candidate, d.sample_ok, d.y_ok, d.z_ok, d.ylags_ok, d.gprlags_ok, d.controls_ok, d.final_good);
    end
end

function assert_any_finite_results(results_world, results_threat, results_act, outcome_ids)
    any_ok = false;
    for i = 1:numel(outcome_ids)
        yid = outcome_ids{i};
        any_ok = any_ok || any(isfinite(results_world.(yid).beta)) || ...
            any(isfinite(results_threat.(yid).beta)) || any(isfinite(results_act.(yid).beta));
    end
    if ~any_ok
        error(['All LP betas are NaN. The regression sample is empty. ', ...
            'Check the h=0 debug lines: the column with a small count is the filter causing the problem.']);
    end
end

function figs = plot_side_by_side_splitwise_by_groups(results_world, results_threat, results_act, ...
    outcome_ids, outcome_labels, cfg)

    panels_per_outcome = 2;

    if ~isfield(cfg, 'max_panels_per_figure') || isempty(cfg.max_panels_per_figure)
        max_panels = 6;
    else
        max_panels = cfg.max_panels_per_figure;
    end

    max_outcomes_per_fig = max(1, floor(max_panels / panels_per_outcome));

    n_outcomes = numel(outcome_ids);
    n_figs = ceil(n_outcomes / max_outcomes_per_fig);
    figs = cell(n_figs, 1);

    for ff = 1:n_figs
        idx_start = (ff-1) * max_outcomes_per_fig + 1;
        idx_end   = min(ff * max_outcomes_per_fig, n_outcomes);
        idx = idx_start:idx_end;

        subtitle = sprintf('Part %d/%d: outcomes %d--%d', ff, n_figs, idx_start, idx_end);

        figs{ff} = plot_side_by_side_splitwise_one_figure( ...
            results_world, results_threat, results_act, ...
            outcome_ids(idx), outcome_labels(idx), cfg, subtitle);
    end
end

function fig = plot_side_by_side_splitwise_one_figure(results_world, results_threat, results_act, ...
    outcome_ids, outcome_labels, cfg, figure_subtitle)

    nrows_this_fig = numel(outcome_ids);
    fig_height = max(520, 280 * nrows_this_fig);
    fig = figure('Color', 'w', 'Position', [120, 80, 1080, fig_height]);
    tlo = tiledlayout(numel(outcome_ids), 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    % Darker and more visible confidence bands.
    % The band visibility is mainly controlled by:
    %   1. fill color below
    %   2. FaceAlpha in plot_single_irf
    world_fill  = [0.45 0.45 0.45];
    threat_fill = [0.35 0.55 0.95];
    act_fill    = [0.95 0.45 0.45];

    for i = 1:numel(outcome_ids)
        yid = outcome_ids{i};
        lab = latex_escape_label(outcome_labels{i});

        % -------------------- Left column: World --------------------
        nexttile((i-1)*2 + 1); hold on;
        rw = results_world.(yid);
        plot_single_irf(gca, rw, cfg, world_fill, 'k-', 'World');

        title(['\textbf{World innovation: ', lab, '}'], 'Interpreter','latex', 'FontSize', 16, 'FontWeight', 'bold');
        xlabel(['\textbf{', cfg.horizon_label, '}'], 'Interpreter','latex', 'FontSize', 15, 'FontWeight', 'bold');
        ylabel(rw.response_ylabel, 'Interpreter','latex', 'FontSize', 15, 'FontWeight', 'bold');

        % -------------------- Right column: Threat and Act --------------------
        nexttile((i-1)*2 + 2); hold on;
        rt = results_threat.(yid);
        ra = results_act.(yid);
        plot_single_irf(gca, rt, cfg, threat_fill, 'b-', 'Threat');
        plot_single_irf(gca, ra, cfg, act_fill,    'r-', 'Act');

        title(['\textbf{Threat and act innovations: ', lab, '}'], 'Interpreter','latex', 'FontSize', 16, 'FontWeight', 'bold');
        xlabel(['\textbf{', cfg.horizon_label, '}'], 'Interpreter','latex', 'FontSize', 15, 'FontWeight', 'bold');
        ylabel(rt.response_ylabel, 'Interpreter','latex', 'FontSize', 15, 'FontWeight', 'bold');

        if i == 1
            legend({'\textbf{Threat CI}','\textbf{Threat}','\textbf{Act CI}','\textbf{Act}'}, ...
                'Location', 'best', 'Interpreter','latex', 'Box','off', ...
                'FontSize', 13, 'FontWeight', 'bold');
        end
    end

    title(tlo, sprintf(['\\textbf{Baseline LP: ', ...
        'AR(%d)+BC GPR shocks, $p_{LP}=%d$, shock size=%.1f s.d.}\\\\', ...
        '\\textbf{%s}'], ...
        cfg.p_gpr_shock, cfg.p_lp, cfg.shock_size, latex_escape_label(figure_subtitle)), ...
        'FontSize', 18, 'FontWeight', 'bold', 'Interpreter','latex');

    drawnow;
end

function plot_single_irf(ax, r, cfg, fill_color, line_style, line_label)
    h = r.h(:)';
    finite_beta = isfinite(r.beta);
    finite_ci = isfinite(r.lb) & isfinite(r.ub);

    if sum(finite_beta) == 0
        text(ax, 0.5, 0.5, 'All beta = NaN', ...
            'HorizontalAlignment','center', ...
            'Units','normalized', ...
            'FontWeight','bold', ...
            'Interpreter','latex');
        axis(ax, 'off');
        return;
    end

    % Confidence band: darker and more prominent.
    if sum(finite_ci) >= 2
        hci = h(finite_ci);
        ub = r.ub(finite_ci)';
        lb = r.lb(finite_ci)';

        fill(ax, [hci, fliplr(hci)], [ub, fliplr(lb)], fill_color, ...
            'EdgeColor', 'none', ...
            'FaceAlpha', 0.5, ...
            'DisplayName', [line_label ' CI']);
    end

    % IRF line.
    plot(ax, h(finite_beta), r.beta(finite_beta), line_style, ...
        'LineWidth', 2.4, ...
        'DisplayName', line_label);

    % Zero line.
    plot(ax, h, zeros(size(h)), 'k--', ...
        'LineWidth', 1.1, ...
        'HandleVisibility','off');

    grid(ax, 'on');
    box(ax, 'on');
    xlim(ax, [0 cfg.H]);

    set(ax, ...
        'TickLabelInterpreter','latex', ...
        'FontSize', 14, ...
        'FontWeight', 'bold', ...
        'LineWidth', 1.2);
end

function out = latex_escape_label(in)
    % Escape underscores and other common special characters for LaTeX labels.
    out = char(string(in));
    out = strrep(out, '\', '\textbackslash{}');
    out = strrep(out, '_', '\_');
    out = strrep(out, '%', '\%');
    out = strrep(out, '&', '\&');
    out = strrep(out, '#', '\#');
end

function save_figure_if_needed(fig, cfg, base_path)
    if ~cfg.save_figures
        return;
    end
    if isempty(fig) || ~isgraphics(fig, 'figure')
        warning('Invalid figure handle. Skipping save: %s', base_path);
        return;
    end

    drawnow;
    try
        savefig(fig, [base_path '.fig']);
    catch ME
        warning('Could not save .fig file. Reason: %s', ME.message);
    end

    try
        exportgraphics(fig, [base_path '.png'], 'Resolution', 300);
    catch
        try
            print(fig, [base_path '.png'], '-dpng', '-r300');
        catch ME2
            warning('Could not save png. Reason: %s', ME2.message);
        end
    end
end
