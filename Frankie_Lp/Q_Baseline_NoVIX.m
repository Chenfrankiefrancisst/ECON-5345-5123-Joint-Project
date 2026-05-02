clear; clc; close all;

%% ============================================================
% Part 2: Candidate mechanism LEVEL LPs using AR-only GPR innovations
% SPLITWISE version, no VIX control
%
% Level specification:
%
%   y_{t+h} - y_{t-1} = alpha_h + beta_h z_t
%                       + lagged y levels
%                       + lagged GPR levels
%                       + lagged macro controls
%                       + e_{t+h}
%
% where:
%   - y is a level variable from Q_Levels_Database.csv.
%   - z_t is a standardized AR residual from the corresponding GPR level.
%   - beta_h is already the level-change response, so DO NOT cumulate beta_h.
%   - lagged GPR LEVELS are included as controls, not lagged z-values.
%
% Figure format is kept the same as the original Part 2:
%   - two figures
%   - each figure has rows_per_figure x 2 layout
%   - left column  = World GPR innovation
%   - right column = Threat and Act overlaid, estimated from separate LPs
%
% IMPORTANT:
%   - log(VIX) is removed from the control vector everywhere.
%   - log(VIX) is still included as an outcome, constructed from VOX/VIX.
%% ============================================================

%% -------------------- USER SETTINGS --------------------
cfg.datafile          = 'Q_Levels_Database.csv';
cfg.fallback_datafile = 'Q_Levels_Database(1).csv';

cfg.p_innov           = 1;
cfg.p_lp              = 4;
cfg.H                 = 12;
cfg.ci                = 0.90;
cfg.shock_size        = 1;
cfg.standardize_innov = true;

cfg.save_results      = false;
cfg.save_figures      = false;
cfg.show_figures      = true;
cfg.rows_per_figure   = 5;
cfg.horizon_label     = 'Horizon (quarters)';

cfg.output_dir        = 'Part2_Mechanism_LevelLP_NoVIX';
cfg.innov_file        = fullfile(cfg.output_dir, 'gpr_innovations_part2_level_ARonly.csv');
cfg.results_file      = fullfile(cfg.output_dir, 'part2_mechanism_level_lp_results_splitwise_noVIXcontrol.csv');
cfg.figure_file_1     = fullfile(cfg.output_dir, 'part2_mechanisms_level_splitwise_noVIXcontrol_fig1.png');
cfg.figure_file_2     = fullfile(cfg.output_dir, 'part2_mechanisms_level_splitwise_noVIXcontrol_fig2.png');
%% -------------------------------------------------------

if cfg.save_results || cfg.save_figures
    if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
end

fprintf('\n=== Part 2 mechanism LEVEL LP, splitwise, no VIX control ===\n');
fprintf('Specification: y_{t+h} - y_{t-1} on standardized z_t, lagged y levels, lagged GPR levels, and lagged controls.\n');
fprintf('GPR innovation AR lag p_innov = %d; LP lags p_lp = %d; horizon = 0:%d; shock size = %.2f s.d.\n', ...
    cfg.p_innov, cfg.p_lp, cfg.H, cfg.shock_size);

%% -------------------- LOAD LEVEL DATABASE --------------------
datafile_used = cfg.datafile;
if ~exist(datafile_used, 'file')
    if exist(cfg.fallback_datafile, 'file')
        datafile_used = cfg.fallback_datafile;
    else
        error('Data file not found: %s or %s. Put this script in the same folder as Q_Levels_Database.csv or update cfg.datafile.', ...
            cfg.datafile, cfg.fallback_datafile);
    end
end

DB = readtable(datafile_used, 'VariableNamingRule','preserve');
T = height(DB);
varnames = DB.Properties.VariableNames;
fprintf('Data file used: %s\n', datafile_used);
fprintf('Loaded rows T = %d, variables = %d\n', T, numel(varnames));
fprintf('Variables available:\n');
fprintf('  %s\n', strjoin(varnames, ', '));

[quarter_labels, has_quarter] = get_quarter_labels(DB, T);
if has_quarter
    fprintf('Sample starts at %s and ends at %s\n', quarter_labels{1}, quarter_labels{end});
end

% Use the full CSV sample. Do not reuse old H1_sample masks from the .mat baseline.
sample = true(T,1);
fprintf('Using full sample: %d / %d rows are active.\n', sum(sample), T);

%% -------------------- CONTROLS: NO VIX CONTROL --------------------
Unemployment = get_required_series(DB, {'Unemp','Unemployment'}, T);
Policy_Rate  = get_series_if_exists(DB, {'FFR','Policy_Rate','EffPolicyRate','ShadowRate'}, T);

controls = Unemployment;
control_names = {'Unemp'};
if ~isempty(Policy_Rate)
    controls = [controls, Policy_Rate]; %#ok<AGROW>
    control_names{end+1} = 'FFR'; %#ok<AGROW>
end

fprintf('\nControls loaded, excluding VIX by design:\n');
for j = 1:numel(control_names)
    fprintf('  Control %-12s finite = %3d / %3d\n', control_names{j}, sum(isfinite(controls(:,j))), T);
end

%% -------------------- OUTCOME SERIES --------------------
% VIX/VOX is not a control, but is kept as an outcome in log form.
VIX_raw = get_required_series(DB, {'VOX','VIX'}, T);
lnVIX = log(max(VIX_raw, 1e-8));

outcome_ids = {
    'Real_WTI', ...
    'Real_Gasoline', ...
    'MICH', ...
    'SPF_inf', ...
    'Two_PH_SPF_Inf', ...
    'r_c', ...
    'r_i', ...
    'r_y', ...
    'lnVIX' ...
};

outcome_labels = {
    'Real WTI crude oil price', ...
    'Real gasoline price', ...
    'Michigan expected inflation', ...
    'SPF expected inflation (current)', ...
    'SPF expected inflation (2-step ahead)', ...
    'Real consumption level', ...
    'Real investment level', ...
    'Real GDP level', ...
    'log(VIX/VOX)' ...
};

outcome_aliases = {
    {'Real_WTI','g_Crude','g_WTI_Cru'}, ...
    {'Real_Gasoline','g_Gasoline','g_Gaso'}, ...
    {'MICH','Epi_Umich','Umich'}, ...
    {'SPF_inf','Epi_SPF'}, ...
    {'Two_PH_SPF_Inf','Epi_SPF_2Q'}, ...
    {'r_c','g_rc'}, ...
    {'r_i','g_ri'}, ...
    {'r_y','g_ry'}, ...
    {'lnVIX'} ...
};

%% -------------------- CONSTRUCT STANDARDIZED GPR SHOCKS --------------------
LGPR  = get_required_series(DB, {'LGPR'}, T);
LGPRT = get_required_series(DB, {'LGPRT'}, T);
LGPRA = get_required_series(DB, {'LGPRA'}, T);

[innov_world,  fs_world]  = extract_ar_level_innovation(LGPR,  sample, cfg.p_innov, 'LGPR');
[innov_threat, fs_threat] = extract_ar_level_innovation(LGPRT, sample, cfg.p_innov, 'LGPRT');
[innov_act,    fs_act]    = extract_ar_level_innovation(LGPRA, sample, cfg.p_innov, 'LGPRA');

if cfg.standardize_innov
    z_world  = zscore_in_sample(innov_world,  sample);
    z_threat = zscore_in_sample(innov_threat, sample);
    z_act    = zscore_in_sample(innov_act,    sample);
else
    z_world  = innov_world;
    z_threat = innov_threat;
    z_act    = innov_act;
end

fprintf('\n--- GPR innovation checks ---\n');
fprintf('World : AR nobs=%3d, R2=% .3f, finite z=%3d\n', fs_world.nobs,  fs_world.R2,  sum(isfinite(z_world)));
fprintf('Threat: AR nobs=%3d, R2=% .3f, finite z=%3d\n', fs_threat.nobs, fs_threat.R2, sum(isfinite(z_threat)));
fprintf('Act   : AR nobs=%3d, R2=% .3f, finite z=%3d\n', fs_act.nobs,    fs_act.R2,    sum(isfinite(z_act)));

%% -------------------- ESTIMATE LEVEL LOCAL PROJECTIONS --------------------
results_world  = struct();
results_threat = struct();
results_act    = struct();
level_lp_results = table();

fprintf('\n--- Estimating Part 2 level LPs ---\n');
for i = 1:numel(outcome_ids)
    yid = outcome_ids{i};
    ylabel = outcome_labels{i};

    if strcmp(yid, 'lnVIX')
        y = lnVIX;
    else
        y = get_required_series(DB, outcome_aliases{i}, T);
    end

    fprintf('\nOutcome: %s\n', ylabel);
    fprintf('  finite y = %3d / %3d\n', sum(isfinite(y)), T);

    results_world.(yid) = estimate_lp_level_change_single_shock( ...
        y, z_world, LGPR, controls, sample, cfg, ylabel, 'world');

    results_threat.(yid) = estimate_lp_level_change_single_shock( ...
        y, z_threat, LGPRT, controls, sample, cfg, ylabel, 'threat');

    results_act.(yid) = estimate_lp_level_change_single_shock( ...
        y, z_act, LGPRA, controls, sample, cfg, ylabel, 'act');

    results_world.(yid).controls  = control_names;
    results_threat.(yid).controls = control_names;
    results_act.(yid).controls    = control_names;

    print_lp_check(results_world.(yid), results_threat.(yid), results_act.(yid), cfg);

    tmpW = results_world.(yid).table;  tmpW.shock = repmat("world", height(tmpW), 1);
    tmpT = results_threat.(yid).table; tmpT.shock = repmat("threat", height(tmpT), 1);
    tmpA = results_act.(yid).table;    tmpA.shock = repmat("act", height(tmpA), 1);
    tmp = [tmpW; tmpT; tmpA];
    tmp.outcome = repmat(string(yid), height(tmp), 1);
    tmp.outcome_label = repmat(string(ylabel), height(tmp), 1);
    tmp.specification = repmat("level_change_y_tph_minus_y_tm1", height(tmp), 1);
    level_lp_results = [level_lp_results; tmp]; %#ok<AGROW>
end

figure_files = plot_part2_two_figures_splitwise_level( ...
    results_world, results_threat, results_act, outcome_ids, outcome_labels, cfg);

%% -------------------- OPTIONAL SAVE --------------------
if cfg.save_results
    innovations = table( ...
        string({'world';'threat';'act'}), ...
        [fs_world.nobs; fs_threat.nobs; fs_act.nobs], ...
        [fs_world.R2; fs_threat.R2; fs_act.R2], ...
        [sum(isfinite(z_world)); sum(isfinite(z_threat)); sum(isfinite(z_act))], ...
        'VariableNames', {'shock','ar_nobs','ar_R2','finite_z'});
    writetable(innovations, cfg.innov_file);
    writetable(level_lp_results, cfg.results_file);
    save(fullfile(cfg.output_dir, 'part2_mechanism_level_lp_workspace.mat'), ...
        'cfg','results_world','results_threat','results_act','level_lp_results', ...
        'z_world','z_threat','z_act','fs_world','fs_threat','fs_act','control_names','figure_files');
    fprintf('\nSaved results to %s\n', cfg.output_dir);
else
    fprintf('\nNo result tables saved because cfg.save_results=false.\n');
    fprintf('Results are available in workspace: level_lp_results, results_world, results_threat, results_act.\n');
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

function [innov, info] = extract_ar_level_innovation(x, sample, p, x_name)
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
        row(1) = 1;
        for j = 1:p
            row(1+j) = x(t-j);
        end
        Y(ii) = x(t);
        X(ii,:) = row;
        keep(ii) = sample(t) && all(sample(t-p:t));
    end

    good = keep & isfinite(Y) & all(isfinite(X),2);
    Yg = Y(good);
    Xg = X(good,:);
    tg = t_grid(good)';

    if isempty(Yg) || size(Xg,1) <= size(Xg,2)
        error('No usable observations in AR level shock extraction for %s.', x_name);
    end

    b = Xg \ Yg;
    yhat = Xg * b;
    resid = Yg - yhat;

    innov = nan(T,1);
    innov(tg) = resid;

    ssr = sum(resid.^2);
    sst = sum((Yg - mean(Yg)).^2);
    if sst > 0
        R2  = 1 - ssr/sst;
    else
        R2 = NaN;
    end

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

function res = estimate_lp_level_change_single_shock(y, z, gpr_level, controls, sample, cfg, y_label, shock_tag)
    H = cfg.H;
    zcrit = normal_icdf(0.5 + cfg.ci/2);

    beta = nan(H+1,1);
    se   = nan(H+1,1);
    lb   = nan(H+1,1);
    ub   = nan(H+1,1);
    nobs = nan(H+1,1);

    dbg_list = cell(H+1,1);

    for h = 0:H
        [Y, X, ~, dbg] = build_lp_level_change_design(y, z, gpr_level, controls, sample, cfg.p_lp, h);
        dbg_list{h+1} = dbg;
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
    res.label = y_label;
    res.shock_tag = shock_tag;
    res.h = (0:H)';
    res.beta = beta;
    res.se = se;
    res.lb = lb;
    res.ub = ub;
    res.nobs = nobs;
    res.debug = dbg_list;
    res.response_ylabel = 'Level change: y_{t+h} - y_{t-1}';
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

        % Dependent variable: y_{t+h} - y_{t-1}.
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

function print_lp_check(rw, rt, ra, cfg)
    fprintf('  World: finite beta=%2d/%2d, nobs h0=%3.0f, beta h0=% .4f, beta h4=% .4f\n', ...
        sum(isfinite(rw.beta)), cfg.H+1, rw.nobs(1), get_beta_at_h(rw,0), get_beta_at_h(rw,4));
    fprintf('  Threat: finite beta=%2d/%2d, nobs h0=%3.0f, beta h0=% .4f, beta h4=% .4f\n', ...
        sum(isfinite(rt.beta)), cfg.H+1, rt.nobs(1), get_beta_at_h(rt,0), get_beta_at_h(rt,4));
    fprintf('  Act:    finite beta=%2d/%2d, nobs h0=%3.0f, beta h0=% .4f, beta h4=% .4f\n', ...
        sum(isfinite(ra.beta)), cfg.H+1, ra.nobs(1), get_beta_at_h(ra,0), get_beta_at_h(ra,4));
end

function b = get_beta_at_h(res, hval)
    idx = find(res.h == hval, 1);
    if isempty(idx)
        b = NaN;
    else
        b = res.beta(idx);
    end
end

function figure_files = plot_part2_two_figures_splitwise_level(results_world, results_threat, results_act, outcome_ids, outcome_labels, cfg)
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

        if cfg.show_figures
            fig = figure('Color', 'w', 'Position', [60, 40, 1500, 1600]);
        else
            fig = figure('Color', 'w', 'Position', [60, 40, 1500, 1600], 'Visible','off');
        end
        tl = tiledlayout(n_per_fig, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

        for local_i = 1:n_per_fig
            if local_i <= numel(these_idx)
                i = these_idx(local_i);

                nexttile; hold on;
                rw = results_world.(outcome_ids{i});
                plot_one_irf_with_ci(gca, h, rw, world_fill_color, 'k');
                plot(h, zeros(size(h)), 'k:', 'LineWidth', 1.0);
                xlim([0 cfg.H]); grid on; box on;
                title(['World: ', outcome_labels{i}], 'FontWeight', 'bold', 'Interpreter','none');
                xlabel(cfg.horizon_label);
                ylabel('Level change: y_{t+h}-y_{t-1}');

                nexttile; hold on;
                rt = results_threat.(outcome_ids{i});
                ra = results_act.(outcome_ids{i});
                plot_one_irf_with_ci(gca, h, rt, threat_fill_color, 'b');
                plot_one_irf_with_ci(gca, h, ra, act_fill_color, 'r');
                plot(h, zeros(size(h)), 'k:', 'LineWidth', 1.0);
                xlim([0 cfg.H]); grid on; box on;
                title(['Threat / Act: ', outcome_labels{i}], 'FontWeight', 'bold', 'Interpreter','none');
                xlabel(cfg.horizon_label);
                ylabel('Level change: y_{t+h}-y_{t-1}');
                if i == 1
                    legend({'Threat CI', 'Threat', 'Act CI', 'Act', 'Zero'}, 'Location', 'best');
                end
            else
                ax1 = nexttile; axis(ax1, 'off');
                ax2 = nexttile; axis(ax2, 'off');
            end
        end

        title(tl, sprintf(['Part 2: Candidate Mechanism LEVEL LPs ', ...
            '(Figure %d of %d; shock size = %.1f s.d., p_{innov} = %d, p_{LP} = %d)'], ...
            f, n_figs, cfg.shock_size, cfg.p_innov, cfg.p_lp), ...
            'FontWeight', 'bold', 'FontSize', 14);

        drawnow;

        if f == 1
            file_out = cfg.figure_file_1;
        elseif f == 2
            file_out = cfg.figure_file_2;
        else
            file_out = fullfile(cfg.output_dir, sprintf('part2_mechanisms_level_splitwise_noVIXcontrol_fig%d.png', f));
        end

        if cfg.save_figures
            try
                exportgraphics(fig, file_out, 'Resolution', 250);
            catch
                print(fig, file_out, '-dpng', '-r250');
            end
            fprintf('Saved figure to %s\n', file_out);
        end
        figure_files{f} = file_out;
    end
end

function plot_one_irf_with_ci(ax, h, r, fill_color, line_color)
    finite_beta = isfinite(r.beta(:));
    finite_ci = isfinite(r.lb(:)) & isfinite(r.ub(:));

    if sum(finite_beta) == 0
        text(ax, 0.5, 0.5, 'All beta = NaN', 'HorizontalAlignment','center', ...
            'Units','normalized', 'FontWeight','bold');
        axis(ax, 'off');
        return;
    end

    if sum(finite_ci) >= 2
        hci = h(finite_ci);
        ub = r.ub(finite_ci)';
        lb = r.lb(finite_ci)';
        fill(ax, [hci, fliplr(hci)], [ub, fliplr(lb)], fill_color, ...
            'EdgeColor','none','FaceAlpha',0.50);
    end

    plot(ax, h(finite_beta), r.beta(finite_beta), '-', 'Color', line_color, 'LineWidth', 2.0);
end
