%clear; clc; close all;

%% ============================================================
% Baseline LPs using AR-only GPR innovations (SPLITWISE version)
% Controls exclude log(VIX): W_t only includes unemployment and policy rate
%
% World GPR is estimated in its own LP equation.
% Threat GPR is estimated in its own LP equation.
% Act GPR is estimated in its own LP equation.
%
% Figure format:
%   - 3 rows x 2 columns
%   - left column: world GPR innovation
%   - right column: threat and act overlaid, estimated from separate LPs
%% ============================================================

%% -------------------- USER SETTINGS --------------------
cfg.datafile = 'Q_Baseline_Database.mat';

cfg.p_innov = 1;
cfg.standardize_innov = true;

cfg.p_lp       = 4;
cfg.H          = 12;
cfg.ci         = 0.90;
cfg.shock_size = 2;
cfg.horizon_label = 'Horizon';

cfg.save_results     = false;
%% -------------------------------------------------------

raw = load(cfg.datafile);
DB  = unpack_database(raw);
T   = infer_sample_length(DB);

sample = get_series_if_exists(DB, {'H1_sample'});
if isempty(sample)
    sample = true(T,1);
else
    sample = isfinite(sample) & (sample ~= 0);
end

Unemployment = get_required_series(DB, {'Unemployment','Unemp'});
Policy_Rate  = get_series_if_exists(DB, {'Policy_Rate','FFR','EffPolicyRate','ShadowRate'});

controls = Unemployment;
control_names = {'Unemployment'};
if ~isempty(Policy_Rate)
    controls = [controls, Policy_Rate]; %#ok<AGROW>
    control_names{end+1} = 'Policy_Rate'; %#ok<AGROW>
end

LGPR  = get_required_series(DB, {'LGPR'});
LGPRT = get_required_series(DB, {'LGPRT'});
LGPRA = get_required_series(DB, {'LGPRA'});

innov_world  = extract_ar_innovation(LGPR,  sample, cfg.p_innov, 'LGPR');
innov_threat = extract_ar_innovation(LGPRT, sample, cfg.p_innov, 'LGPRT');
innov_act    = extract_ar_innovation(LGPRA, sample, cfg.p_innov, 'LGPRA');

if cfg.standardize_innov
    z_world  = zscore_in_sample(innov_world.resid,  sample);
    z_threat = zscore_in_sample(innov_threat.resid, sample);
    z_act    = zscore_in_sample(innov_act.resid,    sample);
else
    z_world  = innov_world.resid;
    z_threat = innov_threat.resid;
    z_act    = innov_act.resid;
end

if cfg.save_results
    innovations = struct();
    innovations.cfg = cfg;
    innovations.sample = sample;
    innovations.innov_world = innov_world;
    innovations.innov_threat = innov_threat;
    innovations.innov_act = innov_act;
    innovations.z_world = z_world;
    innovations.z_threat = z_threat;
    innovations.z_act = z_act;
    save(cfg.innovations_file, 'innovations');
    fprintf('Saved innovations to %s\n', cfg.innovations_file);
end

outcome_ids = {'Pi_Headline', 'Pi_Core', 'g_Indu'};
outcome_labels = {'Headline inflation', 'Core inflation', 'Industrial production growth'};
outcome_aliases = {
    {'Pi_Headline','Headline_Pi'}, ...
    {'Pi_Core','Core_Pi'}, ...
    {'g_Indu'} ...
};

results_world  = struct();
results_threat = struct();
results_act    = struct();

for i = 1:numel(outcome_ids)
    y = get_required_series(DB, outcome_aliases{i});

    results_world.(outcome_ids{i}) = estimate_lp_single_shock( ...
        y, z_world, controls, sample, cfg, outcome_labels{i}, 'world');

    results_threat.(outcome_ids{i}) = estimate_lp_single_shock( ...
        y, z_threat, controls, sample, cfg, outcome_labels{i}, 'threat');

    results_act.(outcome_ids{i}) = estimate_lp_single_shock( ...
        y, z_act, controls, sample, cfg, outcome_labels{i}, 'act');
end

fig = plot_side_by_side_splitwise(results_world, results_threat, results_act, ...
    outcome_ids, outcome_labels, cfg);

if cfg.save_results
    results = struct();
    results.cfg = cfg;
    results.control_names = control_names;
    results.outcome_ids = outcome_ids;
    results.outcome_labels = outcome_labels;
    results.results_world = results_world;
    results.results_threat = results_threat;
    results.results_act = results_act;
    results.z_world = z_world;
    results.z_threat = z_threat;
    results.z_act = z_act;
    results.innov_world = innov_world;
    results.innov_threat = innov_threat;
    results.innov_act = innov_act;
    save(cfg.results_file, 'results');
    fprintf('\nSaved results to %s\n', cfg.results_file);
end

function DB = unpack_database(raw)
    fns = fieldnames(raw);
    for i = 1:numel(fns)
        if istable(raw.(fns{i}))
            DB = raw.(fns{i});
            return;
        end
    end
    DB = raw;
end

function T = infer_sample_length(DB)
    names = get_varnames(DB);
    if isempty(names)
        error('No variables found in loaded data.');
    end
    if istable(DB)
        T = height(DB);
    else
        x = DB.(names{1});
        T = numel(x);
    end
end

function names = get_varnames(DB)
    if istable(DB)
        names = DB.Properties.VariableNames;
    else
        names = fieldnames(DB);
    end
end

function x = get_series_if_exists(DB, targets)
    if ischar(targets) || isstring(targets)
        targets = cellstr(targets);
    end
    names = get_varnames(DB);
    for ii = 1:numel(targets)
        target = targets{ii};
        idx = find(strcmpi(names, target), 1, 'first');
        if isempty(idx)
            idx = find(startsWith(names, target, 'IgnoreCase', true), 1, 'first');
        end
        if ~isempty(idx)
            name = names{idx};
            if istable(DB)
                x = DB.(name);
            else
                x = DB.(name);
            end
            x = x(:);
            return;
        end
    end
    x = [];
end

function x = get_required_series(DB, targets)
    x = get_series_if_exists(DB, targets);
    if isempty(x)
        if ischar(targets) || isstring(targets)
            msg = char(targets);
        else
            msg = strjoin(cellstr(targets), ', ');
        end
        error('Required variable not found. Tried: %s', msg);
    end
end

function z = zscore_in_sample(x, sample)
    use = sample & isfinite(x);
    mu = mean(x(use));
    sd = std(x(use));
    z = (x - mu) ./ sd;
end

function out = extract_ar_innovation(x, sample, p, label)
    x = x(:);
    T = length(x);
    t_grid = (p+1):T;
    n = numel(t_grid);
    k = 1 + p;

    Y = nan(n,1);
    X = nan(n,k);
    keep = false(n,1);

    for ii = 1:n
        t = t_grid(ii);
        row = nan(1,k);
        c = 1;
        row(c) = 1; c = c + 1;
        for j = 1:p
            row(c) = x(t-j); c = c + 1;
        end
        Y(ii) = x(t);
        X(ii,:) = row;
        keep(ii) = sample(t) && all(sample(t-p:t));
    end

    good = keep & isfinite(Y) & all(isfinite(X),2);
    Yg = Y(good);
    Xg = X(good,:);
    tg = t_grid(good)';

    b = Xg \ Yg;
    fitted = nan(T,1);
    resid  = nan(T,1);
    fitted(tg) = Xg * b;
    resid(tg)  = Yg - Xg * b;

    u = resid(tg);
    sse = sum(u.^2);
    sst = sum((Yg - mean(Yg)).^2);
    rsq = 1 - sse / sst;

    out = struct();
    out.label = label;
    out.t_index = tg;
    out.coeff = b;
    out.fitted = fitted;
    out.resid = resid;
    out.nobs = numel(Yg);
    out.rsq = rsq;
    out.mean_resid = mean(u);
    out.std_resid = std(u);
end

function res = estimate_lp_single_shock(y, z, controls, sample, cfg, y_label, shock_tag)
    H = cfg.H;
    p = cfg.p_lp;
    zcrit = normal_icdf(0.5 + cfg.ci/2);

    beta = nan(H+1,1); se = nan(H+1,1); lb = nan(H+1,1); ub = nan(H+1,1); nobs = nan(H+1,1);

    for h = 0:H
        [Y, X] = build_regression_single_shock(y, z, controls, sample, p, h);
        if isempty(Y), continue; end
        bw = min(h + 1, size(X,1)-1);
        [b, se_all] = ols_hac(Y, X, bw);
        beta(h+1) = cfg.shock_size * b(2);
        se(h+1)   = cfg.shock_size * se_all(2);
        lb(h+1)   = beta(h+1) - zcrit * se(h+1);
        ub(h+1)   = beta(h+1) + zcrit * se(h+1);
        nobs(h+1) = size(X,1);
    end

    res = struct();
    res.label = y_label;
    res.shock_tag = shock_tag;
    res.h = (0:H)';
    res.beta = beta;
    res.se = se;
    res.lb = lb;
    res.ub = ub;
    res.nobs = nobs;
    res.table = table((0:H)', beta, se, lb, ub, nobs, ...
        'VariableNames', {'h',['beta_' shock_tag], 'se', 'lb', 'ub', 'nobs'});
end

function [Y, X] = build_regression_single_shock(y, z, controls, sample, p, h)
    y = y(:);
    z = z(:);
    T = length(y);
    nC = size(controls,2);
    t_grid = (p+1):(T-h);
    n = numel(t_grid);
    k = 1 + 1 + p + p + p*nC;

    X = nan(n,k);
    Y = nan(n,1);
    keep = false(n,1);

    for ii = 1:n
        t = t_grid(ii);
        row = nan(1,k);
        c = 1;
        row(c) = 1; c = c + 1;
        row(c) = z(t); c = c + 1;
        for j = 1:p
            row(c) = y(t-j); c = c + 1;
        end
        for j = 1:p
            row(c) = z(t-j); c = c + 1;
        end
        for j = 1:p
            row(c:c+nC-1) = controls(t-j,:);
            c = c + nC;
        end

        Y(ii) = y(t+h);
        X(ii,:) = row;
        keep(ii) = sample(t) && sample(t+h);
    end

    good = keep & isfinite(Y) & all(isfinite(X),2);
    Y = Y(good);
    X = X(good,:);
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
    se = sqrt(diag(V));
end

function q = normal_icdf(p)
    q = -sqrt(2) * erfcinv(2 * p);
end

function fig = plot_side_by_side_splitwise(results_world, results_threat, results_act, ...
    outcome_ids, outcome_labels, cfg)

    h = 0:cfg.H;
    fig = figure('Color', 'w', 'Position', [80, 60, 1400, 900]);
    tlo = tiledlayout(3,2, 'TileSpacing', 'compact', 'Padding', 'compact');

    world_fill  = [0.75 0.75 0.75];
    threat_fill = [0.78 0.86 1.00];
    act_fill    = [1.00 0.82 0.82];

    for i = 1:numel(outcome_ids)
        nexttile((i-1)*2 + 1); hold on;
        rw = results_world.(outcome_ids{i});
        fill([h, fliplr(h)], [rw.ub', fliplr(rw.lb')], ...
            world_fill, 'EdgeColor', 'none', 'FaceAlpha', 0.55);
        plot(h, rw.beta, 'k-', 'LineWidth', 2.0);
        plot(h, zeros(size(h)), 'k--', 'LineWidth', 1.0);
        grid on; box on; xlim([0 cfg.H]);
        xlabel(cfg.horizon_label); ylabel('Response');
        title(['World innovation: ', outcome_labels{i}]);

        nexttile((i-1)*2 + 2); hold on;
        rt = results_threat.(outcome_ids{i});
        ra = results_act.(outcome_ids{i});

        fill([h, fliplr(h)], [rt.ub', fliplr(rt.lb')], ...
            threat_fill, 'EdgeColor', 'none', 'FaceAlpha', 0.50);
        fill([h, fliplr(h)], [ra.ub', fliplr(ra.lb')], ...
            act_fill, 'EdgeColor', 'none', 'FaceAlpha', 0.40);

        plot(h, rt.beta, 'b-', 'LineWidth', 2.0);
        plot(h, ra.beta, 'r-', 'LineWidth', 2.0);
        plot(h, zeros(size(h)), 'k--', 'LineWidth', 1.0);

        grid on; box on; xlim([0 cfg.H]);
        xlabel(cfg.horizon_label); ylabel('Response');
        title(['Threat and act innovations (separate LPs): ', outcome_labels{i}]);

        if i == 1
            legend({'Threat CI','Act CI','Threat','Act'}, 'Location', 'best');
        end
    end

    title(tlo, sprintf(['Baseline LPs using AR-only GPR innovations ', ...
        '(splitwise threat/act; no VIX control; p_{innov} = %d, p_{LP} = %d, shock size = %.1f s.d.)'], ...
        cfg.p_innov, cfg.p_lp, cfg.shock_size), ...
        'FontSize', 15, 'FontWeight', 'bold');
end


%%
%% ============================================================
% Quick exogeneity diagnostics for z_t
% Idea:
%   If z_t is a good innovation, it should not be predictable from:
%   (1) its own lags
%   (2) lagged macro variables / controls
%   (3) both together
%% ============================================================

% --- choose an information set known at t-1 ---
Pi_Headline = get_required_series(DB, {'Pi_Headline','Headline_Pi'});
Pi_Core     = get_required_series(DB, {'Pi_Core','Core_Pi'});
g_Indu      = get_required_series(DB, {'g_Indu'});

info_block = [Pi_Headline, Pi_Core, g_Indu, controls];
info_names = {'Pi_Headline','Pi_Core','g_Indu', control_names{:}};

fprintf('\n============================================\n');
fprintf(' QUICK EXOGENEITY / PREDICTABILITY CHECKS\n');
fprintf('============================================\n');
fprintf('Information set at t-1: %s\n\n', strjoin(info_names, ', '));

check_world  = quick_exogeneity_report(z_world,  info_block, sample, cfg.p_lp, 'world');
check_threat = quick_exogeneity_report(z_threat, info_block, sample, cfg.p_lp, 'threat');
check_act    = quick_exogeneity_report(z_act,    info_block, sample, cfg.p_lp, 'act');

disp('--- Summary table: world ---');
disp(check_world.summary);

disp('--- Summary table: threat ---');
disp(check_threat.summary);

disp('--- Summary table: act ---');
disp(check_act.summary);

%% ======================= FUNCTIONS =======================

function out = quick_exogeneity_report(z, info, sample, p, label)

    z = z(:);
    T = length(z);

    % Require t, t-1, ..., t-p all inside sample
    hist_ok = valid_history(sample, p);

    % Test 1: z_t on its own lags only
    X1 = [ones(T,1), make_lags(z, p)];
    t1 = joint_f_test_intercept_only(z, X1, hist_ok, sprintf('%s: own lags', label));

    % Test 2: z_t on lagged macro info only
    X2 = [ones(T,1), make_lags(info, p)];
    t2 = joint_f_test_intercept_only(z, X2, hist_ok, sprintf('%s: lagged macro info', label));

    % Test 3: z_t on both own lags + lagged macro info
    X3 = [ones(T,1), make_lags(z, p), make_lags(info, p)];
    t3 = joint_f_test_intercept_only(z, X3, hist_ok, sprintf('%s: own lags + macro info', label));

    out = struct();
    out.own_lags   = t1;
    out.macro_lags = t2;
    out.all_lags   = t3;

    out.summary = table( ...
        string({t1.label; t2.label; t3.label}), ...
        [t1.nobs; t2.nobs; t3.nobs], ...
        [t1.F; t2.F; t3.F], ...
        [t1.pval; t2.pval; t3.pval], ...
        [t1.R2; t2.R2; t3.R2], ...
        'VariableNames', {'Test','N','Fstat','pvalue','R2'});
end

function out = joint_f_test_intercept_only(y, X, keep, label)
    % H0: all slope coefficients = 0
    % Restricted model: y = a + u
    % Unrestricted:      y = a + B w_t + u

    good = keep & isfinite(y) & all(isfinite(X),2);
    y = y(good);
    X = X(good,:);

    [n, k] = size(X);
    if n <= k
        error('Not enough observations for %s: n=%d, k=%d', label, n, k);
    end

    % unrestricted
    b_u = X \ y;
    u_u = y - X*b_u;
    SSR_u = u_u' * u_u;

    % restricted: intercept only
    X_r = ones(n,1);
    b_r = X_r \ y;
    u_r = y - X_r*b_r;
    SSR_r = u_r' * u_r;

    q = k - 1; % number of restrictions
    F = ((SSR_r - SSR_u) / q) / (SSR_u / (n - k));
    pval = 1 - fcdf(F, q, n - k);

    TSS = sum((y - mean(y)).^2);
    R2  = 1 - SSR_u / TSS;

    fprintf('%s\n', label);
    fprintf('  n = %d, F = %.4f, p = %.4f, R2 = %.4f\n', n, F, pval, R2);

    if pval < 0.10
        fprintf('  -> REJECT at 10%%: z_t is still predictable here.\n\n');
    else
        fprintf('  -> DO NOT REJECT at 10%%: good for innovation-style exogeneity.\n\n');
    end

    out = struct('label', label, 'nobs', n, 'F', F, 'pval', pval, 'R2', R2);
end

function L = make_lags(X, p)
    if isvector(X)
        X = X(:);
    end
    [T, K] = size(X);
    L = nan(T, p*K);
    for j = 1:p
        cols = (j-1)*K + (1:K);
        L((j+1):end, cols) = X(1:(end-j), :);
    end
end

function ok = valid_history(sample, p)
    sample = logical(sample(:));
    T = length(sample);
    ok = sample;
    for j = 1:p
        tmp = false(T,1);
        tmp((j+1):end) = sample(1:(end-j));
        ok = ok & tmp;
    end
end