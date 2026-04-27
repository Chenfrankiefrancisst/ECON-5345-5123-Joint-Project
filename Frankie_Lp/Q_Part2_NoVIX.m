clear; clc; close all;

%% ============================================================
% Part 2: Candidate mechanism LPs using AR-only GPR innovations
% SPLITWISE version
% Controls exclude log(VIX): W_t only includes unemployment and policy rate
%
% World GPR LP stays separate.
% Threat GPR is estimated in its own LP equation.
% Act GPR is estimated in its own LP equation.
%
% Figure format is kept the same:
%   - two figures
%   - each figure has a 6 x 2 layout
%   - left column  = world GPR innovation
%   - right column = threat and act overlaid, estimated from two separate LPs
%
% IMPORTANT:
%   - log(VIX) is removed from the control vector everywhere
%   - log(VIX) is still included as an outcome in Part 2
%% ============================================================

%% -------------------- USER SETTINGS --------------------
cfg.datafile          = 'Q_Baseline_Database.mat';
cfg.p_innov           = 1;
cfg.p_lp              = 4;
cfg.H                 = 12;
cfg.ci                = 0.90;
cfg.shock_size        = 1;
cfg.standardize_innov = true;
cfg.save_results      = false;
cfg.rows_per_figure   = 5;
cfg.horizon_label     = 'Horizon';

cfg.innov_file        = 'gpr_innovations_part2_ARonly_H1.mat';
cfg.results_file      = 'part2_mechanism_lp_results_gpr_innovations_ARonly_splitwise_noVIXcontrol.mat';
cfg.figure_file_1     = 'part2_mechanisms_gpr_innovations_ARonly_splitwise_noVIXcontrol_fig1.png';
cfg.figure_file_2     = 'part2_mechanisms_gpr_innovations_ARonly_splitwise_noVIXcontrol_fig2.png';
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
VIX_raw      = get_required_series(DB, {'VIX','VOX'});
lnVIX        = log(max(VIX_raw, 1e-8));

LGPR  = get_required_series(DB, {'LGPR'});
LGPRT = get_required_series(DB, {'LGPRT'});
LGPRA = get_required_series(DB, {'LGPRA'});

[innov_world,  fs_world]  = extract_innovation_ar(LGPR,  sample, cfg.p_innov, 'LGPR');
[innov_threat, fs_threat] = extract_innovation_ar(LGPRT, sample, cfg.p_innov, 'LGPRT');
[innov_act,    fs_act]    = extract_innovation_ar(LGPRA, sample, cfg.p_innov, 'LGPRA');

if cfg.standardize_innov
    z_world  = zscore_in_sample(innov_world,  sample);
    z_threat = zscore_in_sample(innov_threat, sample);
    z_act    = zscore_in_sample(innov_act,    sample);
else
    z_world  = innov_world;
    z_threat = innov_threat;
    z_act    = innov_act;
end

controls = build_controls(Unemployment, Policy_Rate);
control_names = build_control_names(Policy_Rate);

outcome_ids = {
    'g_Crude', ...
    'g_Gasoline', ...
    'Epi_Umich', ...
    'Epi_SPF', ...
    'Epi_SPF_2Q', ...
    'g_rc', ...
    'g_ri', ...
    'g_ry', ...
    'lnVIX' ...
};

outcome_labels = {
    'WTI crude oil growth', ...
    'Gasoline price growth', ...
    'Michigan expected inflation', ...
    'SPF expected inflation (current)', ...
    'SPF expected inflation (2-step ahead)', ...
    'Real consumption growth', ...
    'Real investment growth', ...
    'Real GDP growth', ...
    'log(VIX)' ...
};

outcome_aliases = {
    {'g_Crude','g_WTI_Cru'}, ...
    {'g_Gasoline','g_Gaso'}, ...
    {'Epi_Umich','Umich'}, ...
    {'Epi_SPF','SPF_inf'}, ...
    {'Epi_SPF_2Q','Two_PH_SPF_Inf'}, ...
    {'g_rc'}, ...
    {'g_ri'}, ...
    {'g_ry'}, ...
    {'lnVIX'} ...
};

results_world  = struct();
results_threat = struct();
results_act    = struct();

for i = 1:numel(outcome_ids)
    if strcmp(outcome_ids{i}, 'lnVIX')
        y = lnVIX;
    else
        y = get_required_series(DB, outcome_aliases{i});
    end

    results_world.(outcome_ids{i}) = estimate_lp_single_shock( ...
        y, z_world, controls, sample, cfg.p_lp, cfg.H, cfg.ci, cfg.shock_size, outcome_labels{i}, 'world');

    results_threat.(outcome_ids{i}) = estimate_lp_single_shock( ...
        y, z_threat, controls, sample, cfg.p_lp, cfg.H, cfg.ci, cfg.shock_size, outcome_labels{i}, 'threat');

    results_act.(outcome_ids{i}) = estimate_lp_single_shock( ...
        y, z_act, controls, sample, cfg.p_lp, cfg.H, cfg.ci, cfg.shock_size, outcome_labels{i}, 'act');

    results_world.(outcome_ids{i}).controls  = control_names;
    results_threat.(outcome_ids{i}).controls = control_names;
    results_act.(outcome_ids{i}).controls    = control_names;
end

figure_files = plot_part2_two_figures_splitwise( ...
    results_world, results_threat, results_act, outcome_ids, outcome_labels, cfg);

if cfg.save_results
    innovations = struct();
    innovations.cfg = cfg;
    innovations.sample = sample;
    innovations.world = innov_world;
    innovations.threat = innov_threat;
    innovations.act = innov_act;
    innovations.z_world = z_world;
    innovations.z_threat = z_threat;
    innovations.z_act = z_act;
    innovations.first_stage_world = fs_world;
    innovations.first_stage_threat = fs_threat;
    innovations.first_stage_act = fs_act;
    save(cfg.innov_file, 'innovations');
    fprintf('\nSaved innovations to %s\n', cfg.innov_file);

    results = struct();
    results.cfg = cfg;
    results.outcome_ids = outcome_ids;
    results.outcome_labels = outcome_labels;
    results.results_world = results_world;
    results.results_threat = results_threat;
    results.results_act = results_act;
    results.first_stage_world = fs_world;
    results.first_stage_threat = fs_threat;
    results.first_stage_act = fs_act;
    results.figure_files = figure_files;
    save(cfg.results_file, 'results');
    fprintf('Saved results to %s\n', cfg.results_file);
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

function controls = build_controls(Unemployment, Policy_Rate)
    controls = Unemployment;
    if ~isempty(Policy_Rate)
        controls = [controls, Policy_Rate]; %#ok<AGROW>
    end
end

function control_names = build_control_names(Policy_Rate)
    control_names = {'Unemployment'};
    if ~isempty(Policy_Rate)
        control_names{end+1} = 'Policy_Rate'; %#ok<AGROW>
    end
end

function z = zscore_in_sample(x, sample)
    x = x(:);
    use = sample & isfinite(x);
    mu = mean(x(use));
    sd = std(x(use));
    z = (x - mu) ./ sd;
end

function [innov, info] = extract_innovation_ar(x, sample, p, x_name)
    x = x(:);
    T = length(x);
    t_grid = (p+1):T;
    n = numel(t_grid);

    k = 1 + p;
    X = nan(n, k);
    Y = nan(n, 1);
    keep = false(n,1);

    for ii = 1:n
        t = t_grid(ii);
        row = nan(1, k);
        c = 1;
        row(c) = 1; c = c + 1;
        for j = 1:p
            row(c) = x(t-j);
            c = c + 1;
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
    yhat = Xg * b;
    resid = Yg - yhat;

    innov = nan(T,1);
    innov(tg) = resid;

    ssr = sum(resid.^2);
    sst = sum((Yg - mean(Yg)).^2);
    R2  = 1 - ssr/sst;

    info = struct();
    info.name = x_name;
    info.p = p;
    info.nobs = numel(Yg);
    info.beta = b;
    info.fitted = yhat;
    info.resid = resid;
    info.t_index = tg;
    info.R2 = R2;
end

function res = estimate_lp_single_shock(y, z, controls, sample, p, H, ci, shock_size, y_label, shock_tag)
    zcrit = normal_icdf(0.5 + ci/2);

    beta = nan(H+1,1); se = nan(H+1,1); lb = nan(H+1,1); ub = nan(H+1,1); nobs = nan(H+1,1);

    for h = 0:H
        [Y, X] = build_regression_single_shock(y, z, controls, sample, p, h);
        if isempty(Y)
            warning('No usable observations for h=%d in %s LP (%s).', h, shock_tag, y_label);
            continue;
        end
        bw = min(h + 1, size(X,1)-1);
        [b, se_all] = ols_hac(Y, X, bw);
        beta(h+1) = shock_size * b(2);
        se(h+1)   = shock_size * se_all(2);
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
    y = y(:); z = z(:); T = length(y); nC = size(controls,2);
    t_grid = (p+1):(T-h);
    n = numel(t_grid);
    k = 1 + 1 + p + p + p*nC;

    X = nan(n, k); Y = nan(n,1); keep = false(n,1);
    for ii = 1:n
        t = t_grid(ii);
        row = nan(1, k); c = 1;
        row(c) = 1; c = c + 1;
        row(c) = z(t); c = c + 1;
        for j = 1:p
            row(c) = y(t-j); c = c + 1;
        end
        for j = 1:p
            row(c) = z(t-j); c = c + 1;
        end
        for j = 1:p
            row(c:c+nC-1) = controls(t-j,:); c = c + nC;
        end
        Y(ii) = y(t+h);
        X(ii,:) = row;
        keep(ii) = sample(t) && sample(t+h);
    end
    good = keep & isfinite(Y) & all(isfinite(X),2);
    Y = Y(good); X = X(good,:);
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
        xt = X(t,:)';
        S = S + (u(t)^2) * (xt * xt');
    end
    for L = 1:bw
        wL = 1 - L / (bw + 1);
        Gamma = zeros(k, k);
        for t = (L+1):n
            xt  = X(t,:)';
            xtL = X(t-L,:)';
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

function figure_files = plot_part2_two_figures_splitwise(results_world, results_threat, results_act, outcome_ids, outcome_labels, cfg)
    n_outcomes = numel(outcome_ids);
    n_per_fig  = cfg.rows_per_figure;
    n_figs     = ceil(n_outcomes / n_per_fig);
    h          = 0:cfg.H;

    world_fill_color  = [0.65 0.65 0.65];
    threat_fill_color = [0.76 0.86 1.00];
    act_fill_color    = [1.00 0.82 0.82];

    figure_files = cell(n_figs,1);

    for f = 1:n_figs
        idx_start = (f-1)*n_per_fig + 1;
        idx_end   = min(f*n_per_fig, n_outcomes);
        these_idx = idx_start:idx_end;

        fig = figure('Color', 'w', 'Position', [60, 40, 1500, 1600]);
        tl = tiledlayout(n_per_fig, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

        for local_i = 1:n_per_fig
            if local_i <= numel(these_idx)
                i = these_idx(local_i);

                nexttile; hold on;
                rw = results_world.(outcome_ids{i});
                fill([h, fliplr(h)], [rw.ub', fliplr(rw.lb')], world_fill_color, ...
                    'EdgeColor', 'none', 'FaceAlpha', 0.55);
                plot(h, rw.beta, 'k-', 'LineWidth', 2.0);
                plot(h, zeros(size(h)), 'k:', 'LineWidth', 1.0);
                xlim([0 cfg.H]);
                grid on; box on;
                title(outcome_labels{i}, 'FontWeight', 'bold');
                xlabel(cfg.horizon_label);
                ylabel('Response');

                nexttile; hold on;
                rt = results_threat.(outcome_ids{i});
                ra = results_act.(outcome_ids{i});

                fill([h, fliplr(h)], [rt.ub', fliplr(rt.lb')], threat_fill_color, ...
                    'EdgeColor', 'none', 'FaceAlpha', 0.50);
                fill([h, fliplr(h)], [ra.ub', fliplr(ra.lb')], act_fill_color, ...
                    'EdgeColor', 'none', 'FaceAlpha', 0.45);
                plot(h, rt.beta, 'b-', 'LineWidth', 2.0);
                plot(h, ra.beta, 'r-', 'LineWidth', 2.0);
                plot(h, zeros(size(h)), 'k:', 'LineWidth', 1.0);
                xlim([0 cfg.H]);
                grid on; box on;
                title(outcome_labels{i}, 'FontWeight', 'bold');
                xlabel(cfg.horizon_label);
                ylabel('Response');
                if i == 1
                    legend({'Threat CI', 'Act CI', 'Threat', 'Act', 'Zero'}, 'Location', 'best');
                end
            else
                ax1 = nexttile; axis(ax1, 'off');
                ax2 = nexttile; axis(ax2, 'off');
            end
        end

        title(tl, sprintf(['Part 2: Candidate Mechanism LPs using AR-only GPR Innovations ', ...
            '(splitwise threat/act; no VIX control; Figure %d of %d; shock size = %.1f s.d., p_{innov} = %d, p_{LP} = %d)'], ...
            f, n_figs, cfg.shock_size, cfg.p_innov, cfg.p_lp), ...
            'FontWeight', 'bold', 'FontSize', 14);

        if f == 1
            file_out = cfg.figure_file_1;
        elseif f == 2
            file_out = cfg.figure_file_2;
        else
            file_out = sprintf('part2_mechanisms_gpr_innovations_ARonly_splitwise_noVIXcontrol_fig%d.png', f);
        end
        exportgraphics(fig, file_out, 'Resolution', 250);
        fprintf('Saved figure to %s\n', file_out);
        figure_files{f} = file_out;
    end
end
