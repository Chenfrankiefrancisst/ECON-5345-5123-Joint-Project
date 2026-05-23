%% =======================================================================
% Poisson_shock_test.m
% ------------------------------------------------------------------------
% Builds three Poisson-arrival shocks, runs diagnostics, and plots:
%   - Panel 1--3: raw arrivals N_t^k and Poisson shocks z_t^{N,k}
%   - Panel 4   : separate bottom timeline for named oil-specific episodes
%
% Step 1.  Load pre-computed World GPR shock z_t from AR_GPR_shock.m output
%          Uses "with_oil" variant (GPR_shock_output/workspace_gpr_shock.mat)
%
% Step 2.  Construct Poisson event-arrival shocks z_t^{N,k}
%          N_t^k ~ Poisson(lambda_t^k), Pearson residual standardized
%
% Step 3.  Run diagnostics:
%          Test 1: Conditional Granger exogeneity (manual OLS F-test)
%          Test 2: Ljung-Box Q white-noise test
%          Test 3: Breusch-Godfrey LM white-noise test
%
% Step 4.  Plot arrivals and shocks, save results
%% =======================================================================

clear; clc; close all;

%% Settings
cfg.datafile     = 'Q_Levels_Database.csv';
cfg.dummy_file   = 'oil_relevant_gpr_event_dummies_extended_onset_realized_1986Q1_2025Q4.csv';
cfg.output_dir   = 'Poisson_shock_tests_output';

cfg.save_results = true;
cfg.save_figures = true;
cfg.show_figures = true;
cfg.make_arrival_plots = true;

cfg.use_latex_fonts = true;
cfg.figure_font_size = 13;
cfg.figure_title_font_size = 16;
cfg.episode_label_font_size = 8;
cfg.episode_line_width = 0.8;
cfg.combined_plot_name = 'event_arrivals_and_poisson_shocks_with_bottom_timeline';

%% Poisson model controls (exact variable names from Q_Levels_Database.csv)
cfg.macro_control_vars = {'Unemp', 'FFR', 'WEO_Growth', 'WEO_Revision', 'r_y', 'Indu_Prod'};

%% Event specifications
cfg.event_specs = {
    'ChokepointShippingRisk',  'n_ChokepointShippingRisk_EventOnset',  'Chokepoint shipping onset';
    'StrictSupplyDisruption',  'n_StrictSupplyDisruption_EventOnset',  'Strict supply disruption onset';
    'EnergySanction',          'n_EnergySanction_EventOnset',          'Energy sanction onset'
};

cfg.poisson_min_positive_periods = 4;
cfg.poisson_standardize_predictors = true;
cfg.poisson_ridge_lambda = 1e-6;

cfg.granger_lags = 4;
cfg.wn_lags      = [4, 8, 12];
cfg.test_alpha   = 0.05;

cfg.granger_exog_vars = {'Unemp', 'FFR', 'Real_Brent', 'Real_WTI', 'Real_Gasoline'};

% Named events drawn only in the bottom timeline panel.
% Add / remove rows as needed.
cfg.episode_markers = { ...
    '1987Q3', 'Tanker War'; ...
    '1988Q2', 'Praying Mantis'; ...
    '1990Q3', 'Kuwait invasion'; ...
    '1991Q1', 'Gulf War'; ...
    '2003Q1', 'Iraq War'; ...
    '2011Q1', 'Libya / Arab Spring'; ...
    '2012Q1', 'Iran oil sanctions'; ...
    '2014Q1', 'Crimea sanctions'; ...
    '2018Q2', 'JCPOA exit'; ...
    '2019Q1', 'Venezuela sanctions'; ...
    '2019Q3', 'Abqaiq attack'; ...
    '2022Q1', 'Russia--Ukraine'; ...
    '2022Q4', 'Russia oil price cap'; ...
    '2023Q4', 'Red Sea crisis' ...
};

if cfg.save_results && ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end

apply_latex_graphics_defaults(cfg);

fprintf('\n=== Poisson event-arrival shocks + diagnostics ===\n');
fprintf('Events              : %d\n', size(cfg.event_specs,1));
fprintf('Granger lags        : %d\n', cfg.granger_lags);
fprintf('White-noise lags    : %s\n', mat2str(cfg.wn_lags));
fprintf('Data file           : %s\n', cfg.datafile);
fprintf('Dummy file          : %s\n', cfg.dummy_file);

%% =======================================================================
%  Load data
%% =======================================================================

if ~exist(cfg.datafile, 'file')
    error('Data file not found: %s', cfg.datafile);
end

DB = readtable(cfg.datafile, 'VariableNamingRule','preserve');
T = height(DB);
sample = true(T,1);
fprintf('Loaded level database: T=%d, K=%d\n', T, numel(DB.Properties.VariableNames));

[quarter_labels, has_quarter] = get_quarter_labels(DB, T);
if has_quarter
    fprintf('Sample: %s to %s\n', quarter_labels{1}, quarter_labels{end});
end

[macro_controls, macro_names] = load_vars_direct(DB, cfg.macro_control_vars, T);
fprintf('Poisson macro ctrls : %s\n', strjoin(macro_names, ', '));

%% =======================================================================
%  Step 1: Load pre-computed World GPR shock from AR_GPR_shock.m output
%% =======================================================================

shock_mat_file = 'GPR_shock_output/workspace_gpr_shock.mat';
if ~exist(shock_mat_file, 'file')
    error('Pre-computed shock file not found: %s\nRun AR_GPR_shock.m first.', shock_mat_file);
end

loaded = load(shock_mat_file, 'Z_all', 'GPR_levels', 'innovation_info');
z_world = loaded.Z_all.with_oil.World;
world_gpr = loaded.GPR_levels.World;

world_info_row = loaded.innovation_info(strcmp(loaded.innovation_info.variant, 'with_oil') & ...
                                         strcmp(loaded.innovation_info.shock, 'World'), :);
fprintf('\n--- Loaded World GPR shock from %s (with_oil) ---\n', shock_mat_file);
if ~isempty(world_info_row)
    fprintf('  World: nobs=%d, R2=%.3f, resid_sd=%.4f\n', ...
        world_info_row.nobs, world_info_row.rsq, world_info_row.resid_sd);
end

%% Event counts and Granger candidates
dummy_aligned = build_aligned_dummy_table(cfg, quarter_labels, has_quarter, T);

[granger_exog_data, granger_exog_names] = load_vars_direct(DB, cfg.granger_exog_vars, T);
granger_X = [z_world, world_gpr, granger_exog_data];
granger_names = [{'z_WorldGPR', 'WorldGPR'}, granger_exog_names];
fprintf('Granger candidates  : %s\n', strjoin(granger_names, ', '));

%% Containers
poisson_diagnostics = table();
granger_exog_results = table();
white_noise_results = table();
bg_results = table();

Z_event = struct();
N_event = struct();
X_cache = struct();

%% =======================================================================
%  Step 2: Construct Poisson event-arrival shocks
%% =======================================================================

fprintf('\n--- Constructing Poisson-arrival shocks ---\n');

for e = 1:size(cfg.event_specs,1)
    sid   = cfg.event_specs{e,1};
    did   = cfg.event_specs{e,2};
    label = cfg.event_specs{e,3};

    [N, source_name] = get_event_count_or_dummy_series(dummy_aligned, did, T);
    if isempty(N) || sum(N > 0) == 0
        warning('Event not found or all zero: %s. Skipping.', did);
        continue;
    end

    out = estimate_poisson_event_residual(N, z_world, world_gpr, macro_controls, sample, cfg, sid);

    Z_event.(sid) = out.z_event_resid;
    N_event.(sid) = N;
    X_cache.(sid).X = out.X_used;
    X_cache.(sid).t_used = out.t_used;

    poisson_diagnostics = [poisson_diagnostics; out.diagnostics]; %#ok<AGROW>

    fprintf('  %-24s | source=%s | pos=%d | total=%g | nobs=%d | method=%s | resid_sd=%.4f\n', ...
        sid, source_name, out.positive_periods, out.total_count, out.nobs, char(out.method), out.resid_sd);
end

%% =======================================================================
%  Step 3: Run diagnostics (Granger exogeneity, Ljung-Box Q, Breusch-Godfrey)
%% =======================================================================

%% Test 1: Conditional Granger exogeneity
fprintf('\n--- Test 1: Conditional Granger exogeneity (manual OLS F-test) ---\n');
fprintf('H0: lagged X_j does NOT predict z_t^{N,k}, conditional on lags of z and other candidates\n');

event_ids = fieldnames(Z_event);

for e = 1:numel(event_ids)
    sid = event_ids{e};
    z = Z_event.(sid);

    for m = 1:numel(granger_names)
        xname = granger_names{m};
        x = granger_X(:,m);

        other_idx = true(1, numel(granger_names));
        other_idx(m) = false;
        X_other = granger_X(:, other_idx);

        try
            gt = manual_conditional_granger_f(z, x, X_other, cfg.granger_lags);
        catch ME
            warning('Manual Granger failed: %s -> z_%s: %s', xname, sid, ME.message);
            continue;
        end

        if gt.nobs <= 0 || ~isfinite(gt.F_stat)
            warning('Manual Granger skipped: %s -> z_%s, too few usable obs or singular test.', xname, sid);
            continue;
        end

        reject = gt.pvalue < cfg.test_alpha;

        granger_exog_results = [granger_exog_results; ...
            table(string(sid), string(xname), string(['z_' sid]), cfg.granger_lags, gt.nobs, ...
            gt.F_stat, gt.pvalue, reject, cfg.test_alpha, gt.df_num, gt.df_den, gt.rank_r, gt.rank_u, ...
            'VariableNames', {'shock','cause','effect','numlags','nobs','stat','pvalue','reject_H0','alpha', ...
            'df_num','df_den','rank_restricted','rank_unrestricted'})]; %#ok<AGROW>

        fprintf('  %-24s | %-14s -> z | nobs=%3d | F=%8.3f | p=%.4f | reject=%d\n', ...
            sid, xname, gt.nobs, gt.F_stat, gt.pvalue, reject);
    end
end

%% Test 2: Ljung-Box Q
fprintf('\n--- Test 2: Ljung-Box Q white-noise test ---\n');
fprintf('H0: z_t^{N,k} is white noise up to lag L\n');

for e = 1:numel(event_ids)
    sid = event_ids{e};
    z_valid = Z_event.(sid);
    z_valid = z_valid(isfinite(z_valid));

    if numel(z_valid) <= max(cfg.wn_lags) + 1
        warning('Too few finite obs for Ljung-Box: z_%s.', sid);
        continue;
    end

    for L = cfg.wn_lags
        try
            [h, pval, stat, cvalue] = lbqtest(z_valid, 'Lags', L, 'Alpha', cfg.test_alpha);
            reject = logical(h);
        catch ME
            warning('lbqtest failed: z_%s, L=%d: %s', sid, L, ME.message);
            continue;
        end

        white_noise_results = [white_noise_results; ...
            table(string(sid), L, numel(z_valid), stat, pval, cvalue, reject, cfg.test_alpha, ...
            'VariableNames', {'shock','lag','nobs','Q_stat','pvalue','cvalue','reject_H0','alpha'})]; %#ok<AGROW>

        fprintf('  z_%-24s | L=%2d | nobs=%3d | Q=%8.3f | p=%.4f | reject=%d\n', ...
            sid, L, numel(z_valid), stat, pval, reject);
    end
end

%% Test 3: Breusch-Godfrey LM
fprintf('\n--- Test 3: Breusch-Godfrey LM white-noise test ---\n');
fprintf('H0: z_t^{N,k} has no serial correlation up to lag L\n');

for e = 1:numel(event_ids)
    sid = event_ids{e};
    z = Z_event.(sid);
    Xg = X_cache.(sid).X;
    t_used = X_cache.(sid).t_used;
    n_orig = numel(t_used);

    if isempty(Xg) || isempty(t_used)
        warning('BG skipped: empty Poisson design for z_%s.', sid);
        continue;
    end

    Lmax = max(cfg.wn_lags);
    Z_lag_full = nan(n_orig, Lmax);
    for k = 1:Lmax
        tlag = t_used - k;
        ok = tlag >= 1;
        Z_lag_full(ok,k) = z(tlag(ok));
    end

    for L = cfg.wn_lags
        Z_lag = Z_lag_full(:, 1:L);
        z_t = z(t_used);
        X_aug = [Xg, Z_lag];

        keep = isfinite(z_t) & all(isfinite(X_aug),2);
        n_use = sum(keep);
        if n_use <= size(X_aug,2) + 1
            warning('BG skipped: z_%s, L=%d, too few obs.', sid, L);
            continue;
        end

        X_full = X_aug(keep,:);
        z_full = z_t(keep);

        r_aux = z_full - X_full * (X_full \ z_full);
        sse_aux = sum(r_aux.^2);
        ss_tot = sum((z_full - mean(z_full)).^2);
        R2_aux = 1 - sse_aux / max(ss_tot, eps);

        X_r = Xg(keep,:);
        r_r = z_full - X_r * (X_r \ z_full);
        sse_r = sum(r_r.^2);

        LM = n_use * R2_aux;
        pval_LM = 1 - chi2cdf(LM, L);
        reject = pval_LM < cfg.test_alpha;

        df_num = L;
        df_den = n_use - size(X_full,2);
        F = ((sse_r - sse_aux) / df_num) / (sse_aux / df_den);
        pval_F = 1 - fcdf(F, df_num, df_den);

        bg_results = [bg_results; ...
            table(string(sid), L, n_use, LM, pval_LM, F, pval_F, reject, cfg.test_alpha, ...
            'VariableNames', {'shock','lag','nobs','LM_stat','LM_pvalue','F_stat','F_pvalue','reject_H0','alpha'})]; %#ok<AGROW>

        fprintf('  z_%-24s | L=%2d | nobs=%3d | LM=%8.3f | p=%.4f | F=%7.3f | Fp=%.4f | reject=%d\n', ...
            sid, L, n_use, LM, pval_LM, F, pval_F, reject);
    end
end

%% =======================================================================
%  Step 4: Plot and save results
%% =======================================================================

if cfg.make_arrival_plots
    plot_event_arrivals_and_shocks(N_event, Z_event, cfg, quarter_labels, has_quarter, T);
end

if cfg.save_results
    writetable(poisson_diagnostics, fullfile(cfg.output_dir, 'poisson_shock_diagnostics.csv'));
    writetable(granger_exog_results, fullfile(cfg.output_dir, 'poisson_shock_granger_exog.csv'));
    writetable(white_noise_results, fullfile(cfg.output_dir, 'poisson_shock_white_noise_lbq.csv'));
    writetable(bg_results, fullfile(cfg.output_dir, 'poisson_shock_white_noise_bg.csv'));

    event_ids = fieldnames(Z_event);
    Zmat = nan(T, numel(event_ids));
    Nmat = nan(T, numel(event_ids));
    z_names = cell(1, numel(event_ids));
    n_names = cell(1, numel(event_ids));

    for i = 1:numel(event_ids)
        sid = event_ids{i};
        Zmat(:,i) = Z_event.(sid);
        Nmat(:,i) = N_event.(sid);
        z_names{i} = ['zN_' sid];
        n_names{i} = ['N_' sid];
    end

    if has_quarter
        shock_table = [table(string(quarter_labels(:)), 'VariableNames', {'Quarter'}), ...
            array2table(Zmat, 'VariableNames', z_names), ...
            array2table(Nmat, 'VariableNames', n_names)];
    else
        shock_table = [array2table(Zmat, 'VariableNames', z_names), ...
            array2table(Nmat, 'VariableNames', n_names)];
    end

    writetable(shock_table, fullfile(cfg.output_dir, 'poisson_event_shocks.csv'));

    save(fullfile(cfg.output_dir, 'workspace_poisson_event_shock_tests.mat'), ...
        'cfg','Z_event','N_event','z_world','world_gpr', ...
        'poisson_diagnostics','granger_exog_results','white_noise_results','bg_results');

    fprintf('\nSaved results in: %s\n', cfg.output_dir);
end

%% =======================================================================
% Plot functions
%% =======================================================================

function plot_event_arrivals_and_shocks(N_event, Z_event, cfg, quarter_labels, has_quarter, T)
    event_specs = cfg.event_specs;
    x = (1:T)';

    fig = figure( ...
        'Name','Event arrivals and Poisson shocks with timeline', ...
        'NumberTitle','off', ...
        'Visible', visible_flag(cfg), ...
        'Position', [100, 100, 1500, 950]);

    tl = tiledlayout(fig, 4, 1, ...
        'TileSpacing','compact', ...
        'Padding','compact');

    title(tl, 'Raw arrivals $N_t^k$ and Poisson shocks $z_t^{N,k}$', ...
        'Interpreter','latex', ...
        'FontSize', cfg.figure_title_font_size);

    data_axes = gobjects(size(event_specs,1), 1);

    for i = 1:size(event_specs,1)
        sid   = event_specs{i,1};
        label = event_specs{i,3};

        if ~isfield(N_event, sid) || ~isfield(Z_event, sid)
            continue;
        end

        ax = nexttile(tl, i);
        data_axes(i) = ax;

        yyaxis(ax, 'left');
        hN = stem(ax, x, N_event.(sid), ...
            'filled', ...
            'LineWidth', 1.0, ...
            'MarkerSize', 3);
        ylabel(ax, '$N_t^k$', 'Interpreter','latex');

        yyaxis(ax, 'right');
        hZ = plot(ax, x, Z_event.(sid), ...
            'LineWidth', 1.5);
        hold(ax, 'on');
        yline(ax, 0, 'k-', 'LineWidth', 0.8);
        ylabel(ax, '$z_t^{N,k}$', 'Interpreter','latex');

        yyaxis(ax, 'left');
        grid(ax, 'on');
        box(ax, 'on');
        title(ax, latex_escape_text(label), 'Interpreter','latex');

        set(ax, ...
            'XLim', [1 T], ...
            'TickLabelInterpreter','latex', ...
            'FontSize', cfg.figure_font_size, ...
            'LineWidth', 1.1);

        if i < size(event_specs,1)
            set(ax, 'XTickLabel', []);
        end

        if i == 1
            legend(ax, [hN, hZ], {'Raw arrivals $N_t^k$', 'Poisson shock $z_t^{N,k}$'}, ...
                'Interpreter','latex', ...
                'Location','northwest', ...
                'Box','off');
        end
    end

    ax_timeline = nexttile(tl, 4);
    plot_bottom_episode_timeline(ax_timeline, N_event, cfg, quarter_labels, has_quarter, T);

    valid_axes = data_axes(isgraphics(data_axes));
    linkaxes([valid_axes; ax_timeline], 'x');

    if cfg.save_figures
        out_name = cfg.combined_plot_name;
        saveas(fig, fullfile(cfg.output_dir, [out_name '.png']));
        savefig(fig, fullfile(cfg.output_dir, [out_name '.fig']));
    end
end

function plot_bottom_episode_timeline(ax, N_event, cfg, quarter_labels, has_quarter, T)
    cla(ax);
    hold(ax, 'on');

    set(ax, ...
        'XLim', [1 T], ...
        'YLim', [-1.45 0.45], ...
        'YTick', [], ...
        'TickLabelInterpreter','latex', ...
        'FontSize', cfg.figure_font_size, ...
        'LineWidth', 1.1);

    yline(ax, 0, 'k-', 'LineWidth', 1.0);
    grid(ax, 'on');
    box(ax, 'on');

    % Small event-type ticks from the actual dummy database.
    event_specs = cfg.event_specs;
    event_y = [0.28, 0.18, 0.08];
    for i = 1:size(event_specs,1)
        sid = event_specs{i,1};
        if ~isfield(N_event, sid), continue; end
        idx = find(N_event.(sid) > 0);
        if isempty(idx), continue; end
        y0 = event_y(min(i, numel(event_y)));
        for jj = 1:numel(idx)
            plot(ax, [idx(jj) idx(jj)], [0 y0], ...
                'LineWidth', 1.1, ...
                'HandleVisibility','off');
        end
        text(ax, T + 1.5, y0, latex_escape_text(event_specs{i,3}), ...
            'Interpreter','latex', ...
            'FontSize', cfg.episode_label_font_size, ...
            'HorizontalAlignment','left', ...
            'VerticalAlignment','middle', ...
            'Clipping','off');
    end

    if has_quarter && isfield(cfg, 'episode_markers') && ~isempty(cfg.episode_markers)
        q = string(quarter_labels(:));
        row_y = [-0.20, -0.58, -0.96, -1.34];

        for i = 1:size(cfg.episode_markers, 1)
            q_str = string(cfg.episode_markers{i,1});
            lab   = char(cfg.episode_markers{i,2});

            idx = find(q == q_str, 1, 'first');
            if isempty(idx), continue; end

            r = mod(i-1, numel(row_y)) + 1;
            y_lab = row_y(r);

            plot(ax, [idx idx], [0 y_lab + 0.08], ...
                'Color', [0.35 0.35 0.35], ...
                'LineStyle', '-', ...
                'LineWidth', cfg.episode_line_width, ...
                'HandleVisibility','off');

            plot(ax, idx, 0, ...
                'ko', ...
                'MarkerFaceColor', 'k', ...
                'MarkerSize', 3, ...
                'HandleVisibility','off');

            txt = sprintf('%s\\\\%s', char(q_str), latex_escape_text(lab));

            text(ax, idx, y_lab, txt, ...
                'Interpreter','latex', ...
                'FontSize', cfg.episode_label_font_size, ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','top', ...
                'Clipping','off');
        end
    end

    if has_quarter
        step = max(1, round(T / 8));
        ticks = unique([1:step:T, T]);
        set(ax, ...
            'XTick', ticks, ...
            'XTickLabel', quarter_labels(ticks));
    else
        set(ax, 'XTick', unique([1:round(T/8):T, T]));
    end

    xlabel(ax, 'Quarter', 'Interpreter','latex');
    title(ax, 'Oil-specific geopolitical episodes', ...
        'Interpreter','latex', ...
        'FontSize', cfg.figure_font_size);
end

%% =======================================================================
% Test and data functions
%% =======================================================================

function gt = manual_conditional_granger_f(y, x, X_other, L)
    y = double(y(:));
    x = double(x(:));

    if isempty(X_other)
        X_other = zeros(numel(y),0);
    else
        X_other = double(X_other);
    end

    T = numel(y);
    t_grid = ((L+1):T)';

    y_dep = y(t_grid);
    Y_lag = make_lag_block(y, t_grid, L);
    X_lag = make_lag_block(x, t_grid, L);

    O_lag = zeros(numel(t_grid), 0);
    for c = 1:size(X_other,2)
        O_lag = [O_lag, make_lag_block(X_other(:,c), t_grid, L)]; %#ok<AGROW>
    end

    Xr = [ones(numel(t_grid),1), Y_lag, O_lag];
    Xu = [Xr, X_lag];

    keep = isfinite(y_dep) & all(isfinite(Xr),2) & all(isfinite(Xu),2);
    y_dep = y_dep(keep);
    Xr = Xr(keep,:);
    Xu = Xu(keep,:);

    n = numel(y_dep);
    gt = struct('nobs',0,'F_stat',NaN,'pvalue',NaN,'df_num',NaN,'df_den',NaN,'rank_r',NaN,'rank_u',NaN);

    if n <= size(Xu,2) + 1
        return;
    end

    br = pinv(Xr) * y_dep;
    bu = pinv(Xu) * y_dep;
    er = y_dep - Xr * br;
    eu = y_dep - Xu * bu;
    sse_r = sum(er.^2);
    sse_u = sum(eu.^2);

    rank_r = rank(Xr);
    rank_u = rank(Xu);
    q = max(rank_u - rank_r, 1);
    df_den = n - rank_u;

    if df_den <= 0 || sse_u <= 0
        return;
    end

    F = max(((sse_r - sse_u) / q) / (sse_u / df_den), 0);
    pval = 1 - fcdf(F, q, df_den);

    gt.nobs = n;
    gt.F_stat = F;
    gt.pvalue = pval;
    gt.df_num = q;
    gt.df_den = df_den;
    gt.rank_r = rank_r;
    gt.rank_u = rank_u;
end

function Xlag = make_lag_block(x, t_grid, L)
    x = double(x(:));
    Xlag = nan(numel(t_grid), L);
    for ell = 1:L
        Xlag(:,ell) = x(t_grid - ell);
    end
end

function [quarter_labels, has_quarter] = get_quarter_labels(DB, T)
    quarter_labels = repmat({''}, T, 1);
    has_quarter = false;
    names = DB.Properties.VariableNames;

    idx = find(strcmpi(names, 'quarter') | strcmpi(names, 'date'), 1);
    if isempty(idx), return; end

    raw = DB.(names{idx});
    quarter_labels = cellstr(string(raw(:)));
    has_quarter = true;
end

function [data, names] = load_vars_direct(DB, varlist, T)
    data = [];
    names = {};
    for i = 1:numel(varlist)
        v = varlist{i};
        if ismember(v, DB.Properties.VariableNames)
            raw = DB.(v);
            if isnumeric(raw) || islogical(raw)
                data = [data, double(raw(:))]; %#ok<AGROW>
                names{end+1} = v; %#ok<AGROW>
            end
        else
            warning('Variable not found: %s', v);
        end
    end
end

function dummy_aligned = build_aligned_dummy_table(cfg, quarter_labels, has_quarter, T)
    dummy_aligned = table();

    if ~has_quarter
        error('No Quarter/date column found in level database.');
    end

    if ~exist(cfg.dummy_file, 'file')
        error('Dummy file not found: %s', cfg.dummy_file);
    end

    q_db = string(quarter_labels(:));
    dummy_aligned = table(q_db, 'VariableNames', {'Quarter'});

    D = readtable(cfg.dummy_file, 'VariableNamingRule','preserve');
    names = D.Properties.VariableNames;
    q_idx = find(strcmpi(names, 'quarter') | strcmpi(names, 'date'), 1);

    if isempty(q_idx)
        error('Dummy file has no Quarter/date column.');
    end

    qD = string(D.(names{q_idx})(:));
    [tf, loc] = ismember(q_db, qD);

    for j = 1:numel(names)
        v = names{j};
        if j == q_idx, continue; end

        raw = D.(v);
        if ~(isnumeric(raw) || islogical(raw)), continue; end

        aligned = zeros(T,1);
        x = double(raw(:));
        aligned(tf) = x(loc(tf));
        aligned(~isfinite(aligned)) = 0;

        safe_v = matlab.lang.makeValidName(v);
        dummy_aligned.(safe_v) = aligned;
    end

    base_vars = {'ChokepointShippingRisk','StrictSupplyDisruption','EnergySanction'};
    for i = 1:numel(base_vars)
        v = base_vars{i};
        if ismember(v, dummy_aligned.Properties.VariableNames)
            oname = [v '_EventOnset'];
            if ~ismember(oname, dummy_aligned.Properties.VariableNames)
                dummy_aligned.(oname) = construct_onset_dummy(dummy_aligned.(v));
            end

            nname = ['n_' oname];
            if ~ismember(nname, dummy_aligned.Properties.VariableNames)
                dummy_aligned.(nname) = dummy_aligned.(oname);
            end
        end
    end
end

function onset = construct_onset_dummy(x)
    x = double(x(:) ~= 0);
    onset = zeros(size(x));

    if isempty(x), return; end

    onset(1) = x(1);
    if numel(x) >= 2
        onset(2:end) = double(x(2:end)==1 & x(1:end-1)==0);
    end
end

function [x, source_name] = get_event_count_or_dummy_series(dummy_aligned, varname, T)
    source_name = varname;
    x = get_dummy_series(dummy_aligned, varname, T);

    if ~isempty(x), return; end

    if startsWith(varname, 'n_')
        alt = regexprep(varname, '^n_', '');
    else
        alt = ['n_' varname];
    end

    x = get_dummy_series(dummy_aligned, alt, T);
    if ~isempty(x)
        source_name = alt;
    end
end

function x = get_dummy_series(dummy_aligned, varname, T)
    x = [];

    if isempty(dummy_aligned), return; end

    names = dummy_aligned.Properties.VariableNames;
    idx = find(strcmpi(names, varname), 1);

    if isempty(idx), return; end

    raw = dummy_aligned.(names{idx});
    if isnumeric(raw) || islogical(raw)
        x = double(raw(:));
        if numel(x) ~= T
            x = [];
        end
    end
end

function out = estimate_poisson_event_residual(N, z_world, world_gpr, controls, sample, cfg, label)
    N = double(N(:));
    z_world = double(z_world(:));
    world_gpr = double(world_gpr(:));
    T = numel(N);

    if isempty(controls), controls = zeros(T,0); end

    t_grid = (2:T)';
    Xraw = [z_world(t_grid), world_gpr(t_grid-1), N(t_grid-1), controls(t_grid-1,:)];
    Y = N(t_grid);

    valid = sample(t_grid) & isfinite(Y) & all(isfinite(Xraw),2);
    Yuse = Y(valid);
    Xuse_raw = Xraw(valid,:);
    t_used = t_grid(valid);

    n_positive = sum(Yuse > 0);
    n_zero = sum(Yuse == 0);
    total_count = sum(Yuse);

    z_event_resid = nan(T,1);
    pearson_resid = nan(T,1);
    lambda_hat = nan(T,1);
    eta_hat = nan(T,1);

    min_positive = cfg.poisson_min_positive_periods;

    if numel(Yuse) <= size(Xuse_raw,2) + 1 || n_positive < min_positive || total_count <= 0
        warning('Too few positives for Poisson residualization: %s.', label);

        diag = table(string(label), string("not_estimated"), false, numel(Yuse), n_positive, n_zero, total_count, ...
            NaN, NaN, NaN, NaN, ...
            'VariableNames', {'shock','method','converged','nobs','positive_periods','zero_periods','total_count', ...
            'mean_lambda_positive','mean_lambda_zero','pearson_resid_sd','deviance'});

        out = struct('z_event_resid',z_event_resid,'pearson_resid',pearson_resid, ...
            'lambda_hat',lambda_hat,'eta_hat',eta_hat,'X_used',zeros(0,0),'t_used',zeros(0,1), ...
            'nobs',numel(Yuse),'positive_periods',n_positive,'zero_periods',n_zero, ...
            'total_count',total_count,'method',"not_estimated",'converged',false, ...
            'resid_sd',NaN,'diagnostics',diag);
        return;
    end

    [Xuse, ~, ~] = standardize_design_columns(Xuse_raw, cfg.poisson_standardize_predictors);
    [b, method, converged] = fit_poisson_count(Yuse, Xuse, cfg);

    X_used = [ones(size(Xuse,1),1), Xuse];
    eta_use = X_used * b;
    lam_use = clamp_intensity(exp(max(min(eta_use, 30), -30)));

    pearson_use = (Yuse - lam_use) ./ sqrt(lam_use);
    resid_sd = std(pearson_use, 'omitnan');
    z_use = (pearson_use - mean(pearson_use, 'omitnan')) ./ resid_sd;

    z_event_resid(t_used) = z_use;
    pearson_resid(t_used) = pearson_use;
    lambda_hat(t_used) = lam_use;
    eta_hat(t_used) = eta_use;

    mean_lambda_positive = mean(lam_use(Yuse > 0), 'omitnan');
    mean_lambda_zero = mean(lam_use(Yuse == 0), 'omitnan');
    dev = poisson_deviance(Yuse, lam_use);

    diag = table(string(label), string(method), converged, numel(Yuse), n_positive, n_zero, total_count, ...
        mean_lambda_positive, mean_lambda_zero, resid_sd, dev, ...
        'VariableNames', {'shock','method','converged','nobs','positive_periods','zero_periods','total_count', ...
        'mean_lambda_positive','mean_lambda_zero','pearson_resid_sd','deviance'});

    out = struct();
    out.z_event_resid = z_event_resid;
    out.pearson_resid = pearson_resid;
    out.lambda_hat = lambda_hat;
    out.eta_hat = eta_hat;
    out.X_used = X_used;
    out.t_used = t_used;
    out.nobs = numel(Yuse);
    out.positive_periods = n_positive;
    out.zero_periods = n_zero;
    out.total_count = total_count;
    out.method = method;
    out.converged = converged;
    out.resid_sd = resid_sd;
    out.diagnostics = diag;
end

function [Xstd, muX, sdX] = standardize_design_columns(X, do_standardize)
    Xstd = X;
    muX = zeros(1,size(X,2));
    sdX = ones(1,size(X,2));

    if ~do_standardize || isempty(X), return; end

    for j = 1:size(X,2)
        xj = X(:,j);
        mu = mean(xj, 'omitnan');
        sd = std(xj, 'omitnan');

        if isfinite(sd) && sd > 0
            Xstd(:,j) = (xj - mu) ./ sd;
            muX(j) = mu;
            sdX(j) = sd;
        end
    end
end

function [b, method, converged] = fit_poisson_count(Y, X, cfg)
    Y = double(Y(:));
    X = double(X);
    k = size(X,2);

    if exist('glmfit', 'file') == 2
        try
            [b, ~, stats] = glmfit(X, Y, 'poisson', 'link', 'log');
            method = "glmfit_poisson";
            converged = true;

            if isfield(stats, 'se') && any(~isfinite(stats.se))
                converged = false;
            end
            return;
        catch ME
            warning('glmfit Poisson failed: %s. Falling back to fminsearch.', ME.message);
        end
    end

    b0 = zeros(k+1,1);
    b0(1) = log(max(mean(Y,'omitnan'), 1e-6));
    lambda = cfg.poisson_ridge_lambda;

    obj = @(theta) poisson_negloglik(theta, Y, X, lambda);
    opts = optimset('Display','off', 'MaxIter', 20000, 'MaxFunEvals', 50000, ...
        'TolX', 1e-8, 'TolFun', 1e-8);

    [b, ~, exitflag] = fminsearch(obj, b0, opts);
    method = "fminsearch_poisson";
    converged = exitflag > 0;
end

function nll = poisson_negloglik(theta, Y, X, lambda)
    eta = [ones(size(X,1),1), X] * theta(:);
    mu = clamp_intensity(exp(max(min(eta, 30), -30)));

    nll = -sum(Y .* log(mu) - mu - gammaln(Y + 1));

    if isfinite(lambda) && lambda > 0
        nll = nll + lambda * sum(theta(2:end).^2);
    end
end

function mu = clamp_intensity(mu)
    mu = min(max(mu, 1e-8), 1e8);
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

function v = visible_flag(cfg)
    if isfield(cfg, 'show_figures') && cfg.show_figures
        v = 'on';
    else
        v = 'off';
    end
end

function apply_latex_graphics_defaults(cfg)
    if isfield(cfg, 'use_latex_fonts') && cfg.use_latex_fonts
        set(groot, 'defaultTextInterpreter','latex');
        set(groot, 'defaultAxesTickLabelInterpreter','latex');
        set(groot, 'defaultLegendInterpreter','latex');

        if isfield(cfg, 'figure_font_size')
            set(groot, 'defaultAxesFontSize', cfg.figure_font_size);
            set(groot, 'defaultTextFontSize', cfg.figure_font_size);
        end
    end
end

function s = latex_escape_text(s)
    s = char(s);
    s = strrep(s, '\', '\textbackslash{}');
    s = strrep(s, '_', '\_');
    s = strrep(s, '%', '\%');
    s = strrep(s, '&', '\&');
    s = strrep(s, '#', '\#');
    s = strrep(s, '{', '\{');
    s = strrep(s, '}', '\}');
end
