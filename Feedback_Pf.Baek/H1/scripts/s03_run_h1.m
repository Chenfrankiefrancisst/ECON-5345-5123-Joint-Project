%% S03_RUN_H1  H1 baseline LP + robustness checks.
%
%  Estimates Local Projection impulse responses of log(IP) and log(CPI)
%  to GPR / GPT / GPA shocks. Three specifications:
%
%    Baseline:     own lags only (shock + outcome)
%    Robustness 1: + UNRATE lags
%    Robustness 2: + UNRATE lags + log(VIX) lags
%
%  Also runs VAR-based AIC/BIC lag selection as a cross-check for L=12.
%
%  Prerequisite: run s01_load_data.m first.
%
%  Output:
%    ../output/fig_h1_baseline.png
%    ../output/fig_h1_robust1_unrate.png
%    ../output/fig_h1_robust2_unrate_vix.png
%    ../output/fig_h1_lag_selection.png
%    ../output/h1_results.mat
% -----------------------------------------------------------------------

if ~exist('H1_ROOT','var'), clear; clc; close all; end

%% === Paths ===
proj_root = fileparts(fileparts(mfilename('fullpath')));
data_dir  = fullfile(proj_root, 'data');
code_dir  = fullfile(proj_root, 'code');
out_dir   = fullfile(proj_root, 'output');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

addpath(code_dir);

%% === Load data ===
load(fullfile(data_dir, 'h1_baseline.mat'), 'master');
T = height(master);
fprintf('Loaded: %d obs, %s to %s\n', T, ...
        datestr(master.date(1)), datestr(master.date(end)));

%% === Parameters ===
H     = 36;     % max horizon (months)
L     = 12;     % baseline lag length
alpha = 0.10;   % significance level -> 90% CI

%% ====================================================================
%  PART 0: LAG SELECTION (VAR-based AIC/BIC cross-check)
%  ====================================================================
% We check whether AIC/BIC from a reduced-form VAR support L=12.
% Three VAR systems are tested (one per shock variant).

fprintf('\n============================================================\n');
fprintf('  PART 0: VAR-BASED LAG SELECTION\n');
fprintf('============================================================\n');

shock_names  = {'GPR', 'GPT', 'GPA'};
shock_vars   = {'log_GPR', 'log_GPT', 'log_GPA'};
outcome_vars = {'log_IP', 'log_CPI'};
p_max = 24;

lag_results = struct();
for s = 1:3
    fprintf('\n--- VAR system: [%s, log_IP, log_CPI] ---\n', shock_names{s});

    % Build data matrix for VAR (drop NaN rows)
    var_data = [master.(shock_vars{s}), master.log_IP, master.log_CPI];
    valid = all(~isnan(var_data), 2);
    var_data = var_data(valid, :);

    lag_results.(shock_names{s}) = lp_lag_select(var_data, p_max, true);
end

% Plot AIC/BIC curves
fig_lag = figure('Position', [100 100 1400 400], 'Name', 'Lag Selection');
for s = 1:3
    subplot(1, 3, s);
    res = lag_results.(shock_names{s});
    plot(res.p_range, res.aic, 'b-o', 'LineWidth', 1.2, 'MarkerSize', 4); hold on;
    plot(res.p_range, res.bic, 'r-s', 'LineWidth', 1.2, 'MarkerSize', 4);
    xline(12, 'k--', 'L=12', 'LineWidth', 1, 'LabelOrientation', 'horizontal');
    xline(res.p_aic, 'b:', sprintf('AIC=%d', res.p_aic), 'LineWidth', 0.8);
    xline(res.p_bic, 'r:', sprintf('BIC=%d', res.p_bic), 'LineWidth', 0.8);
    hold off;
    title(sprintf('VAR(%s, IP, CPI)', shock_names{s}));
    xlabel('Lag order p'); ylabel('Information criterion');
    legend('AIC', 'BIC', 'Location', 'best');
    grid on; xlim([1 p_max]);
end
saveas(fig_lag, fullfile(out_dir, 'fig_h1_lag_selection.png'));
fprintf('\nSaved: fig_h1_lag_selection.png\n');

%% ====================================================================
%  PART 1: BASELINE LP (own lags only)
%  ====================================================================
fprintf('\n============================================================\n');
fprintf('  PART 1: BASELINE LP (own lags only)\n');
fprintf('============================================================\n');

% Storage for all results
all_results = struct();

% 3 shocks x 2 outcomes = 6 regressions
outcome_names = {'log IP', 'log CPI'};
outcome_cols  = {'log_IP', 'log_CPI'};

for s = 1:3
    shock = master.(shock_vars{s});
    for o = 1:2
        Y = master.(outcome_cols{o});
        label = sprintf('%s_%s', shock_names{s}, outcome_cols{o});

        % Baseline: no additional controls (W omitted)
        fprintf('  Estimating: %s -> %s ... ', shock_names{s}, outcome_names{o});
        res = lp_estimate(Y, shock, H, L, alpha);
        all_results.baseline.(label) = res;
        fprintf('done (T_eff = %d at h=0)\n', res.T_eff(1));
    end
end

% Plot baseline: 3x2 panel
fig_base = figure('Position', [50 50 1200 900], 'Name', 'H1 Baseline');
panel = 0;
for s = 1:3
    for o = 1:2
        panel = panel + 1;
        label = sprintf('%s_%s', shock_names{s}, outcome_cols{o});
        res = all_results.baseline.(label);

        opts = struct();
        opts.title = sprintf('%s \\rightarrow %s', shock_names{s}, outcome_names{o});
        opts.ylabel = 'Response';
        opts.fig_handle = fig_base;
        opts.subplot_pos = [3, 2, panel];
        opts.color = [0.1 0.1 0.1];  % black
        lp_plot_irf(res, opts);
    end
end
sgtitle('H1 Baseline: GPR/GPT/GPA \rightarrow IP, CPI  (own lags only, L=12)', ...
        'FontSize', 13, 'FontWeight', 'bold');
saveas(fig_base, fullfile(out_dir, 'fig_h1_baseline.png'));
fprintf('Saved: fig_h1_baseline.png\n');

%% ====================================================================
%  PART 2: ROBUSTNESS 1 — add UNRATE
%  ====================================================================
%  Rationale: unemployment proxies the business cycle state. It is a
%  potential CONFOUNDER (recessions may raise GPR through political
%  instability AND affect inflation via the Phillips curve), not a
%  mediator of the GPR -> inflation channel.
%  Reference: Caldara et al. (2026, JIE) include output/unemployment
%  controls in their country-panel specification.

fprintf('\n============================================================\n');
fprintf('  PART 2: ROBUSTNESS 1 (+ UNRATE)\n');
fprintf('============================================================\n');

for s = 1:3
    shock = master.(shock_vars{s});
    for o = 1:2
        Y = master.(outcome_cols{o});
        label = sprintf('%s_%s', shock_names{s}, outcome_cols{o});

        W = master.UNRATE;
        fprintf('  Estimating: %s -> %s + UNRATE ... ', shock_names{s}, outcome_names{o});
        res = lp_estimate(Y, shock, H, L, alpha, W);
        all_results.robust1.(label) = res;
        fprintf('done\n');
    end
end

% Plot robustness 1
fig_r1 = figure('Position', [50 50 1200 900], 'Name', 'H1 Robustness 1');
panel = 0;
for s = 1:3
    for o = 1:2
        panel = panel + 1;
        label = sprintf('%s_%s', shock_names{s}, outcome_cols{o});

        opts = struct();
        opts.title = sprintf('%s \\rightarrow %s', shock_names{s}, outcome_names{o});
        opts.ylabel = 'Response';
        opts.fig_handle = fig_r1;
        opts.subplot_pos = [3, 2, panel];
        opts.color = [0.1 0.1 0.1];
        lp_plot_irf(all_results.robust1.(label), opts);
    end
end
sgtitle('H1 Robustness 1: + UNRATE  (L=12)', 'FontSize', 13, 'FontWeight', 'bold');
saveas(fig_r1, fullfile(out_dir, 'fig_h1_robust1_unrate.png'));
fprintf('Saved: fig_h1_robust1_unrate.png\n');

%% ====================================================================
%  PART 3: ROBUSTNESS 2 — add UNRATE + log(VIX)
%  ====================================================================
%  Rationale: VIX captures financial-market uncertainty that could be a
%  common driver of both GPR (news attention increases when VIX is high)
%  and macro outcomes (uncertainty -> investment/consumption decline).
%  VIX measures a DIFFERENT dimension of uncertainty (financial) than GPR
%  (geopolitical), so it is a confounder, not a mediator.
%  Reference: Baker, Bloom & Davis (2016, QJE); Caldara & Iacoviello
%  (2022) show GPR and VIX are moderately correlated but distinct.
%
%  NOTE: VIX (VIXCLS) starts 1990-01. Effective sample is shorter
%  (~432 months vs ~492 for baseline). This is reported in the output.

fprintf('\n============================================================\n');
fprintf('  PART 3: ROBUSTNESS 2 (+ UNRATE + log VIX)\n');
fprintf('============================================================\n');

for s = 1:3
    shock = master.(shock_vars{s});
    for o = 1:2
        Y = master.(outcome_cols{o});
        label = sprintf('%s_%s', shock_names{s}, outcome_cols{o});

        W = [master.UNRATE, master.log_VIX];
        fprintf('  Estimating: %s -> %s + UNRATE + VIX ... ', shock_names{s}, outcome_names{o});
        res = lp_estimate(Y, shock, H, L, alpha, W);
        all_results.robust2.(label) = res;
        fprintf('done (T_eff = %d at h=0)\n', res.T_eff(1));
    end
end

% Plot robustness 2
fig_r2 = figure('Position', [50 50 1200 900], 'Name', 'H1 Robustness 2');
panel = 0;
for s = 1:3
    for o = 1:2
        panel = panel + 1;
        label = sprintf('%s_%s', shock_names{s}, outcome_cols{o});

        opts = struct();
        opts.title = sprintf('%s \\rightarrow %s', shock_names{s}, outcome_names{o});
        opts.ylabel = 'Response';
        opts.fig_handle = fig_r2;
        opts.subplot_pos = [3, 2, panel];
        opts.color = [0.1 0.1 0.1];
        lp_plot_irf(all_results.robust2.(label), opts);
    end
end
sgtitle('H1 Robustness 2: + UNRATE + log(VIX)  (L=12)', ...
        'FontSize', 13, 'FontWeight', 'bold');
saveas(fig_r2, fullfile(out_dir, 'fig_h1_robust2_unrate_vix.png'));
fprintf('Saved: fig_h1_robust2_unrate_vix.png\n');

%% ====================================================================
%  PART 4: COMPARISON OVERLAY
%  ====================================================================
%  Plot baseline vs robustness 1 vs robustness 2 side by side for each
%  shock-outcome pair, to visualise how much beta_h changes.

fprintf('\n--- Generating comparison plots ---\n');

fig_cmp = figure('Position', [50 50 1400 900], 'Name', 'H1 Comparison');
colors = {[0 0 0], [0.4 0.4 0.4], [0.7 0.7 0.7]};  % black, dark gray, light gray
spec_labels = {'Baseline', '+ UNRATE', '+ UNRATE + VIX'};

panel = 0;
for s = 1:3
    for o = 1:2
        panel = panel + 1;
        subplot(3, 2, panel);
        label = sprintf('%s_%s', shock_names{s}, outcome_cols{o});

        specs = {all_results.baseline.(label), ...
                 all_results.robust1.(label), ...
                 all_results.robust2.(label)};

        hold on;
        for k = 1:3
            res = specs{k};
            valid = ~isnan(res.beta);
            h = res.h(valid);
            plot(h, res.beta(valid), '-', 'Color', colors{k}, ...
                 'LineWidth', 2 - 0.5*(k-1));
        end
        yline(0, 'k--', 'LineWidth', 0.5);
        hold off;

        title(sprintf('%s \\rightarrow %s', shock_names{s}, outcome_names{o}));
        xlabel('Horizon (months)');
        ylabel('\\beta_h');
        if panel == 2
            legend(spec_labels, 'Location', 'best', 'FontSize', 8);
        end
        grid on; xlim([0 H]);
    end
end
sgtitle('H1 Specification Comparison', 'FontSize', 13, 'FontWeight', 'bold');
saveas(fig_cmp, fullfile(out_dir, 'fig_h1_comparison.png'));
fprintf('Saved: fig_h1_comparison.png\n');

%% === Save all results ===
save(fullfile(out_dir, 'h1_results.mat'), 'all_results', 'lag_results', ...
     'H', 'L', 'alpha', 'shock_names', 'outcome_names');
fprintf('\nSaved: h1_results.mat\n');
fprintf('\n=== s03_run_h1 complete ===\n');
