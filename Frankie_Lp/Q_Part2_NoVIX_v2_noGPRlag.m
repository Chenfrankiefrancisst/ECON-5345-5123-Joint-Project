%% =======================================================================
%% [PART 2 v2_noGPRlag] Same as Q_Part2_NoVIX_v2.m EXCEPT the lagged GPR
%%                      level block is removed from the LP RHS.
%% -----------------------------------------------------------------------
% Estimating equation (one specification per outcome y and per shock z):
%
%   y_{t+h} - y_{t-1} = alpha_h + beta_h * z_t
%                       + sum_{j=1..p} rho_{h,j} * y_{t-j}
%                       + sum_{j=1..p} theta_{h,j}' * controls_{t-j}
%                       + e_{t+h}
%
% This is identical to v2 except the
%
%   sum_{j=1..p} kappa_{h,j} * GPR_{t-j}
%
% block has been removed. Motivation: z_t is the AR(1) residual of GPR_t,
% so by OLS first-order conditions z_t is in-sample orthogonal to
% GPR_{t-1}; under the AR(1) assumption higher GPR lags carry no extra
% information either. The Gamma(L) block in v2 was therefore largely
% redundant for identification of beta_h.
%
% Use case: clean cross-check against v3 (which routes the same
% specification through ir_jorda). Any IRF discrepancies between this
% script and v3 isolate the three remaining implementation deviations
% (HAC bandwidth rule, HAC sandwich code path, 4-obs sample gap).
%
% Output folder: Part2_Mechanism_LevelLP_NoVIX_noGPRlag/
%% =======================================================================


clear; clc; close all;

this_dir = fileparts(mfilename('fullpath'));
if isempty(this_dir), this_dir = pwd; end
code_dir = fullfile(this_dir, 'code');
if exist(code_dir, 'dir'), addpath(code_dir); end


%% (1) USER SETTINGS -----------------------------------------------------

cfg.datafile          = 'Q_Levels_Database.mat';
cfg.fallback_datafile = 'Q_Levels_Database.csv';

cfg.p_innov           = 1;
cfg.p_lp              = 4;
cfg.H                 = 12;
cfg.ci                = 0.90;
cfg.shock_size        = 1;
cfg.standardize_innov = true;

cfg.save_results      = false;
cfg.save_figures      = true;
cfg.show_figures      = true;
cfg.rows_per_figure   = 5;
cfg.horizon_label     = 'Horizon (quarters)';
cfg.output_dir        = 'Part2_Mechanism_LevelLP_NoVIX_noGPRlag';

cfg.innov_file        = fullfile(cfg.output_dir, 'gpr_innovations_part2_noGPRlag.csv');
cfg.results_file      = fullfile(cfg.output_dir, 'part2_mechanism_level_lp_results_noGPRlag.csv');
cfg.figure_file_1     = fullfile(cfg.output_dir, 'Part2_noGPRlag_Figure1.png');
cfg.figure_file_2     = fullfile(cfg.output_dir, 'Part2_noGPRlag_Figure2.png');

if cfg.save_results || cfg.save_figures
    if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
end

fprintf('\n=== Part 2 noGPRlag : v2 LP without the lagged GPR level block ===\n');
fprintf('Specification: y_{t+h} - y_{t-1} on z_t, lagged y levels, lagged controls (NO GPR lags).\n');
fprintf('GPR innovation AR lag p_innov = %d; LP lags p_lp = %d; horizon = 0:%d; shock size = %.2f s.d.\n', ...
    cfg.p_innov, cfg.p_lp, cfg.H, cfg.shock_size);


%% (2) LOAD LEVEL DATABASE -----------------------------------------------

if exist(cfg.datafile, 'file')
    datafile_used = cfg.datafile;
    DB = load_table_from_mat(datafile_used);
elseif exist(cfg.fallback_datafile, 'file')
    datafile_used = cfg.fallback_datafile;
    warning(['Primary data file %s not found; falling back to CSV mirror %s. ', ...
             'The CSV may be stale relative to the .mat.'], ...
            cfg.datafile, cfg.fallback_datafile);
    DB = readtable(datafile_used, 'VariableNamingRule','preserve');
else
    error('Data file not found: neither %s nor %s.', cfg.datafile, cfg.fallback_datafile);
end
T = height(DB);
varnames = DB.Properties.VariableNames;
fprintf('Data file used: %s\n', datafile_used);
fprintf('Loaded rows T = %d, variables = %d\n', T, numel(varnames));

[quarter_labels, has_quarter] = get_quarter_labels(DB, T);
if has_quarter
    fprintf('Sample starts at %s and ends at %s\n', quarter_labels{1}, quarter_labels{end});
end

sample = true(T,1);
fprintf('Using full sample: %d / %d rows are active.\n', sum(sample), T);


%% (3) CONTROLS: NO VIX CONTROL ------------------------------------------

controls      = [DB.Unemp, DB.FFR];
control_names = {'Unemp', 'FFR'};

fprintf('\nControls loaded, excluding VIX by design:\n');
for j = 1:numel(control_names)
    fprintf('  Control %-12s finite = %3d / %3d\n', control_names{j}, sum(isfinite(controls(:,j))), T);
end


%% (4) OUTCOME SERIES ----------------------------------------------------

lnVIX = log(max(DB.VOX, 1e-8));

outcome_ids = {'Real_WTI','Real_Gasoline','MICH','SPF_inf', ...
               'Two_PH_SPF_Inf','r_c','r_i','r_y','lnVIX'};

outcome_labels = { ...
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


%% (5) CONSTRUCT STANDARDIZED GPR SHOCKS ---------------------------------
% GPR levels are still loaded -- we need them for the AR(1) shock
% extraction. They simply do not enter the LP RHS as controls.

LGPR  = DB.LGPR;
LGPRT = DB.LGPRT;
LGPRA = DB.LGPRA;

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


%% (6) ESTIMATE LEVEL LOCAL PROJECTIONS ----------------------------------

results_world  = struct();
results_threat = struct();
results_act    = struct();
level_lp_results = table();

fprintf('\n--- Estimating Part 2 noGPRlag level LPs ---\n');
for i = 1:numel(outcome_ids)
    yid = outcome_ids{i};
    ylabel = outcome_labels{i};

    if strcmp(yid, 'lnVIX')
        y = lnVIX;
    else
        y = DB.(yid);
    end

    fprintf('\nOutcome: %s\n', ylabel);
    fprintf('  finite y = %3d / %3d\n', sum(isfinite(y)), T);

    % Three independent LPs — splitwise specification. Note: gpr_level
    % is no longer passed because the GPR(L) block is gone.
    results_world.(yid) = estimate_lp_level_change_single_shock( ...
        y, z_world,  controls, sample, cfg, ylabel, 'world');

    results_threat.(yid) = estimate_lp_level_change_single_shock( ...
        y, z_threat, controls, sample, cfg, ylabel, 'threat');

    results_act.(yid) = estimate_lp_level_change_single_shock( ...
        y, z_act,    controls, sample, cfg, ylabel, 'act');

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
    tmp.specification = repmat("level_change_y_tph_minus_y_tm1_noGPRlag", height(tmp), 1);
    level_lp_results = [level_lp_results; tmp]; %#ok<AGROW>
end

figure_files = plot_part2_two_figures_splitwise_level( ...
    results_world, results_threat, results_act, outcome_ids, outcome_labels, cfg);

%% OPTIONAL SAVE ---------------------------------------------------------
if cfg.save_results
    innovations = table( ...
        string({'world';'threat';'act'}), ...
        [fs_world.nobs; fs_threat.nobs; fs_act.nobs], ...
        [fs_world.R2; fs_threat.R2; fs_act.R2], ...
        [sum(isfinite(z_world)); sum(isfinite(z_threat)); sum(isfinite(z_act))], ...
        'VariableNames', {'shock','ar_nobs','ar_R2','finite_z'});
    writetable(innovations, cfg.innov_file);
    writetable(level_lp_results, cfg.results_file);
    save(fullfile(cfg.output_dir, 'part2_mechanism_level_lp_workspace_noGPRlag.mat'), ...
        'cfg','results_world','results_threat','results_act','level_lp_results', ...
        'z_world','z_threat','z_act','fs_world','fs_threat','fs_act','control_names','figure_files');
    fprintf('\nSaved results to %s\n', cfg.output_dir);
else
    fprintf('\nNo result tables saved because cfg.save_results=false.\n');
end


%% =======================================================================
%% Helper Functions
%% =======================================================================

function DB = load_table_from_mat(matfile)
    S = load(matfile);
    fnames = fieldnames(S);
    DB = [];
    for k = 1:numel(fnames)
        if istable(S.(fnames{k}))
            DB = S.(fnames{k});
            return;
        end
    end
    if numel(fnames) == 1 && isstruct(S.(fnames{1}))
        DB = struct2table(S.(fnames{1}));
        return;
    end
    error('No table found inside %s. Top-level variables present: %s', ...
        matfile, strjoin(fnames, ', '));
end


function [quarter_labels, has_quarter] = get_quarter_labels(DB, T)
    quarter_labels = repmat({''}, T, 1);
    has_quarter = false;
    names = DB.Properties.VariableNames;
    idx = find(strcmpi(names, 'quarter') | strcmpi(names, 'Quarter') | ...
               strcmpi(names, 'date') | strcmpi(names, 'Date'), 1);
    if isempty(idx), return; end
    q = DB.(names{idx});
    has_quarter = true;
    if iscell(q)
        quarter_labels = q(:);
    else
        quarter_labels = cellstr(string(q(:)));
    end
end


function [innov, info] = extract_ar_level_innovation(x, sample, p, x_name)
    x = x(:);
    sample = sample(:);
    T = length(x);

    Xlags = lagmatrix(x, 1:p);
    X = [ones(T,1), Xlags];
    Y = x;

    sample_window = sample;
    for j = 1:p
        sample_window = sample_window & [false(j,1); sample(1:end-j)];
    end

    good = sample_window & isfinite(Y) & all(isfinite(X), 2);
    Yg = Y(good);
    Xg = X(good, :);

    if isempty(Yg) || size(Xg,1) <= size(Xg,2)
        error('No usable observations in AR level shock extraction for %s.', x_name);
    end

    b = Xg \ Yg;
    yhat = Xg * b;
    resid = Yg - yhat;

    innov = nan(T, 1);
    innov(good) = resid;

    ssr = sum(resid.^2);
    sst = sum((Yg - mean(Yg)).^2);
    if sst > 0
        R2 = 1 - ssr/sst;
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
    info.t_index = find(good);
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


%% Estimate level-change LP for ONE outcome x ONE shock ------------------
% Identical to v2's estimate_lp_level_change_single_shock EXCEPT no
% gpr_level argument; the GPR(L) block has been removed from the design.

function res = estimate_lp_level_change_single_shock(y, z, controls, sample, cfg, y_label, shock_tag)

    H = cfg.H;
    zcrit = norminv(0.5 + cfg.ci/2);

    beta = nan(H+1,1);
    se   = nan(H+1,1);
    lb   = nan(H+1,1);
    ub   = nan(H+1,1);
    nobs = nan(H+1,1);

    dbg_list = cell(H+1,1);

    for h = 0:H
        [Y, X, ~, dbg] = build_lp_level_change_design(y, z, controls, sample, cfg.p_lp, h);
        dbg_list{h+1} = dbg;

        if isempty(Y) || size(X,1) <= size(X,2)
            continue;
        end

        % LLSW (2018) fixed-b bandwidth, per horizon (same as v2).
        n_lp = size(X,1);
        bw = min(max(round(0.18 * n_lp), 1), n_lp - 1);

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


%% Build (Y, X) for one horizon — NO GPR(L) block -----------------------
% Differs from v2's build_lp_level_change_design only in the absence of
% the GPR-level lag block (Glag) from X0, the gprlags_ok finiteness
% check, and the dbg.gprlags_ok counter.

function [Y, X, good, dbg] = build_lp_level_change_design(y, z, controls, sample, p, h)

    y = y(:);
    z = z(:);
    sample = sample(:);
    T = length(y);

    if isempty(controls)
        controls = zeros(T,0);
    end
    nC = size(controls,2);

    % Lag blocks for y own-lags and controls. NO GPR-level block.
    Ylag = lagmatrix(y, 1:p);              % T x p
    if nC > 0
        Clag = lagmatrix(controls, 1:p);   % T x (p*nC)
    else
        Clag = zeros(T, 0);
    end

    % Forward outcome y_{t+h} aligned to row t. y(t-1) via lagmatrix(y,1).
    Yfwd = nan(T, 1);
    Yfwd(1:T-h) = y(1+h:end);
    Y0 = Yfwd - lagmatrix(y, 1);

    % Regressor block ordering: const, z_t, y-lags, control lags.
    X0 = [ones(T,1), z, Ylag, Clag];

    % Sample-window mask: sample(t) AND sample(t-1..t-p) AND sample(t+h).
    sample_window = sample;
    for j = 1:p
        sample_window = sample_window & [false(j,1); sample(1:end-j)];
    end
    if h == 0
        sample_fwd = sample;
    else
        sample_fwd = [sample(1+h:end); false(h,1)];
    end
    sample_ok = sample_window & sample_fwd;

    % Time-index validity: t must have p preceding rows AND h trailing rows.
    t_valid = false(T, 1);
    t_valid(p+1 : T-h) = true;

    % Componentwise finiteness checks.
    y_ok       = isfinite(Y0);
    z_ok       = isfinite(z);
    ylags_ok   = all(isfinite(Ylag), 2);
    if nC > 0
        controls_ok = all(isfinite(Clag), 2);
    else
        controls_ok = true(T, 1);
    end

    good = t_valid & sample_ok & y_ok & z_ok & ylags_ok ...
        & controls_ok & all(isfinite(X0), 2);
    Y = Y0(good);
    X = X0(good, :);

    dbg = struct();
    dbg.n_candidate = sum(t_valid);
    dbg.sample_ok   = sum(t_valid & sample_ok);
    dbg.y_ok        = sum(t_valid & y_ok);
    dbg.z_ok        = sum(t_valid & z_ok);
    dbg.ylags_ok    = sum(t_valid & ylags_ok);
    dbg.controls_ok = sum(t_valid & controls_ok);
    dbg.final_good  = sum(good);
end


%% OLS with Newey-West (Bartlett) HAC standard errors -------------------
% Identical to v2's ols_hac.

function [b, se, V] = ols_hac(y, X, bw)

    [n, k] = size(X);
    if n <= k
        error('Not enough observations: n=%d, k=%d', n, k);
    end

    bw = min(max(bw, 0), n - 1);

    [V, se, b] = hac(X, y, ...
        'type',      'HAC',  ...
        'weights',   'BT',   ...
        'bandwidth', bw,     ...
        'intercept', false,  ...
        'smallT',    true,   ...
        'display',   'off');
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


%% Render two-column IRF figures (left=World, right=Threat/Act) -------
% Identical to v2's plotting helper; only the figure-title prefix is
% updated to flag the noGPRlag spec.

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

        title(tl, sprintf(['Part 2 noGPRlag: Mechanism LEVEL LPs ', ...
            '(Figure %d of %d; shock size = %.1f s.d., p_{innov} = %d, p_{LP} = %d)'], ...
            f, n_figs, cfg.shock_size, cfg.p_innov, cfg.p_lp), ...
            'FontWeight', 'bold', 'FontSize', 14);

        drawnow;

        if f == 1
            file_out = cfg.figure_file_1;
        elseif f == 2
            file_out = cfg.figure_file_2;
        else
            file_out = fullfile(cfg.output_dir, sprintf('part2_noGPRlag_fig%d.png', f));
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
