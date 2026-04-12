%% S02_EXPLORE_DATA  Descriptive analysis of H1 baseline data.
%
%  Loads h1_baseline.mat (from s01_load_data) and produces:
%    1. Summary statistics table
%    2. Time series plots of all variables
%    3. ADF unit root tests (levels and first differences)
%    4. Correlation matrix
%    5. Autocorrelation of GPR/GPT/GPA
%
%  Output figures are saved to ../output/.
%
%  Usage:
%    >> run('scripts/s02_explore_data.m')
% -----------------------------------------------------------------------

if ~exist('H1_ROOT','var'), clear; clc; close all; end

%% === Paths ===
proj_root = fileparts(fileparts(mfilename('fullpath')));
data_dir  = fullfile(proj_root, 'data');
out_dir   = fullfile(proj_root, 'output');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

%% === Load data ===
load(fullfile(data_dir, 'h1_baseline.mat'));
fprintf('Loaded h1_baseline.mat: %d obs, %s to %s\n', ...
        height(master), datestr(master.date(1)), datestr(master.date(end)));

%% ========================================================================
%  1. SUMMARY STATISTICS
%  ========================================================================
fprintf('\n==============================\n');
fprintf('  SUMMARY STATISTICS\n');
fprintf('==============================\n\n');

% Variables to summarise (levels and logs)
vars_level = {'GPR','GPT','GPA','INDPRO','CPI','FFR','WTI'};
vars_log   = {'log_GPR','log_GPT','log_GPA','log_IP','log_CPI','log_WTI'};

% Level variables
fprintf('%-12s %8s %8s %8s %8s %8s %8s\n', ...
        'Variable', 'Mean', 'Std', 'Min', 'Max', 'Skew', 'Kurt');
fprintf('%s\n', repmat('-', 1, 72));

for i = 1:length(vars_level)
    v = vars_level{i};
    x = master.(v);
    x = x(~isnan(x));
    fprintf('%-12s %8.2f %8.2f %8.2f %8.2f %8.2f %8.2f\n', ...
            v, mean(x), std(x), min(x), max(x), skewness(x), kurtosis(x));
end

fprintf('\n');

% Log variables
fprintf('%-12s %8s %8s %8s %8s %8s %8s\n', ...
        'Variable', 'Mean', 'Std', 'Min', 'Max', 'Skew', 'Kurt');
fprintf('%s\n', repmat('-', 1, 72));

for i = 1:length(vars_log)
    v = vars_log{i};
    x = master.(v);
    x = x(~isnan(x));
    fprintf('%-12s %8.4f %8.4f %8.4f %8.4f %8.2f %8.2f\n', ...
            v, mean(x), std(x), min(x), max(x), skewness(x), kurtosis(x));
end

%% ========================================================================
%  2. TIME SERIES PLOTS
%  ========================================================================
fprintf('\n--- Generating time series plots ---\n');

% --- Panel A: GPR indices ---
fig1 = figure('Position', [100 100 1200 800], 'Name', 'GPR Indices');

subplot(3,1,1);
plot(master.date, master.GPR, 'b-', 'LineWidth', 1.2);
title('GPR — Headline Geopolitical Risk Index');
ylabel('Index'); grid on;

subplot(3,1,2);
plot(master.date, master.GPT, 'r-', 'LineWidth', 1.2);
title('GPT — Geopolitical Threats');
ylabel('Index'); grid on;

subplot(3,1,3);
plot(master.date, master.GPA, 'Color', [0.6 0.2 0.8], 'LineWidth', 1.2);
title('GPA — Geopolitical Acts');
ylabel('Index'); xlabel('Date'); grid on;

saveas(fig1, fullfile(out_dir, 'fig_gpr_indices.png'));
fprintf('  Saved: fig_gpr_indices.png\n');

% --- Panel B: Macro variables ---
fig2 = figure('Position', [100 100 1200 900], 'Name', 'Macro Variables');

subplot(2,2,1);
plot(master.date, master.INDPRO, 'b-', 'LineWidth', 1.2);
title('Industrial Production (INDPRO)');
ylabel('Index (2017=100)'); grid on;

subplot(2,2,2);
plot(master.date, master.CPI, 'r-', 'LineWidth', 1.2);
title('CPI — All Urban Consumers');
ylabel('Index (1982-84=100)'); grid on;

subplot(2,2,3);
plot(master.date, master.FFR, 'k-', 'LineWidth', 1.2);
title('Federal Funds Rate');
ylabel('Percent'); grid on;

subplot(2,2,4);
plot(master.date, master.WTI, 'Color', [0.1 0.5 0.1], 'LineWidth', 1.2);
title('WTI Crude Oil Price');
ylabel('USD / barrel'); xlabel('Date'); grid on;

saveas(fig2, fullfile(out_dir, 'fig_macro_variables.png'));
fprintf('  Saved: fig_macro_variables.png\n');

% --- Panel C: Log-level variables (used in LP) ---
fig3 = figure('Position', [100 100 1200 600], 'Name', 'Log Variables for LP');

subplot(2,3,1);
plot(master.date, master.log_GPR, 'b-'); title('log(GPR)'); grid on;
subplot(2,3,2);
plot(master.date, master.log_GPT, 'r-'); title('log(GPT)'); grid on;
subplot(2,3,3);
plot(master.date, master.log_GPA, 'Color', [0.6 0.2 0.8]); title('log(GPA)'); grid on;
subplot(2,3,4);
plot(master.date, master.log_IP, 'b-'); title('log(IP)'); grid on;
subplot(2,3,5);
plot(master.date, master.log_CPI, 'r-'); title('log(CPI)'); grid on;
subplot(2,3,6);
plot(master.date, master.log_WTI, 'Color', [0.1 0.5 0.1]); title('log(WTI)'); grid on;

saveas(fig3, fullfile(out_dir, 'fig_log_variables.png'));
fprintf('  Saved: fig_log_variables.png\n');

%% ========================================================================
%  3. STATIONARITY TESTS (ADF)
%  ========================================================================
% ADF test on levels and first differences of key variables.
% For LP, we use log levels as LHS (cumulative diffs computed internally),
% but we need to know the integration order for interpreting the IRFs.
%
% Requires Econometrics Toolbox for adftest(). If unavailable, a simple
% manual ADF regression is provided as fallback.

fprintf('\n==============================\n');
fprintf('  ADF UNIT ROOT TESTS\n');
fprintf('==============================\n');

test_vars = {'log_GPR','log_GPT','log_GPA','log_IP','log_CPI','FFR','log_WTI'};
test_labels = {'log(GPR)','log(GPT)','log(GPA)','log(IP)','log(CPI)','FFR','log(WTI)'};

has_adftest = exist('adftest', 'file') == 2;

if has_adftest
    fprintf('\n%-12s  %10s %10s | %10s %10s\n', ...
            '', '--- Levels ---', '', '--- 1st Diff ---', '');
    fprintf('%-12s  %10s %10s | %10s %10s\n', ...
            'Variable', 'Stat', 'p-value', 'Stat', 'p-value');
    fprintf('%s\n', repmat('-', 1, 65));

    for i = 1:length(test_vars)
        x = master.(test_vars{i});
        x = x(~isnan(x));
        dx = diff(x);

        % Level test (with constant, 12 lags for monthly data)
        [h_lev, pval_lev, stat_lev] = adftest(x, 'Model', 'ARD', 'Lags', 12);
        % First difference test
        [h_dif, pval_dif, stat_dif] = adftest(dx, 'Model', 'ARD', 'Lags', 12);

        fprintf('%-12s  %10.3f %10.4f | %10.3f %10.4f', ...
                test_labels{i}, stat_lev, pval_lev, stat_dif, pval_dif);

        % Annotate integration order
        if pval_lev < 0.05
            fprintf('   I(0)\n');
        elseif pval_dif < 0.05
            fprintf('   I(1)\n');
        else
            fprintf('   I(2)?\n');
        end
    end
else
    fprintf('\n  adftest() not available (Econometrics Toolbox required).\n');
    fprintf('  Running manual ADF regressions instead.\n\n');

    fprintf('%-12s  %10s %10s | %10s %10s\n', ...
            '', '--- Levels ---', '', '--- 1st Diff ---', '');
    fprintf('%-12s  %10s %10s | %10s %10s\n', ...
            'Variable', 't-stat', '1%% CV', 't-stat', '1%% CV');
    fprintf('%s\n', repmat('-', 1, 65));

    % 1% critical value for ADF with constant, T~500: approx -3.44
    cv_1pct = -3.44;
    n_lags = 12;

    for i = 1:length(test_vars)
        x = master.(test_vars{i});
        x = x(~isnan(x));

        % --- Level ADF ---
        t_lev = manual_adf(x, n_lags);
        % --- First difference ADF ---
        t_dif = manual_adf(diff(x), n_lags);

        fprintf('%-12s  %10.3f %10.3f | %10.3f %10.3f', ...
                test_labels{i}, t_lev, cv_1pct, t_dif, cv_1pct);

        if t_lev < cv_1pct
            fprintf('   I(0)\n');
        elseif t_dif < cv_1pct
            fprintf('   I(1)\n');
        else
            fprintf('   I(2)?\n');
        end
    end
end

%% ========================================================================
%  4. CORRELATION MATRIX
%  ========================================================================
fprintf('\n==============================\n');
fprintf('  CORRELATION MATRIX (log levels)\n');
fprintf('==============================\n\n');

corr_vars = {'log_GPR','log_GPT','log_GPA','log_IP','log_CPI','FFR','log_WTI'};
corr_labels = {'GPR','GPT','GPA','IP','CPI','FFR','WTI'};
corr_data = [];
for i = 1:length(corr_vars)
    corr_data = [corr_data, master.(corr_vars{i})]; %#ok<AGROW>
end

% Remove rows with NaN
valid = all(~isnan(corr_data), 2);
C = corrcoef(corr_data(valid, :));

% Print
fprintf('%-6s', '');
for i = 1:length(corr_labels)
    fprintf('%8s', corr_labels{i});
end
fprintf('\n');

for i = 1:length(corr_labels)
    fprintf('%-6s', corr_labels{i});
    for j = 1:length(corr_labels)
        fprintf('%8.3f', C(i,j));
    end
    fprintf('\n');
end

% Heatmap figure
fig4 = figure('Position', [100 100 700 600], 'Name', 'Correlation Matrix');
imagesc(C);
colorbar;
caxis([-1 1]);
colormap(redblue_cmap());
set(gca, 'XTick', 1:length(corr_labels), 'XTickLabel', corr_labels, ...
         'YTick', 1:length(corr_labels), 'YTickLabel', corr_labels);
title('Correlation Matrix (log levels, 1985–2025)');

% Add correlation values as text
for i = 1:size(C,1)
    for j = 1:size(C,2)
        text(j, i, sprintf('%.2f', C(i,j)), ...
             'HorizontalAlignment', 'center', 'FontSize', 9);
    end
end

saveas(fig4, fullfile(out_dir, 'fig_correlation_matrix.png'));
fprintf('\n  Saved: fig_correlation_matrix.png\n');

%% ========================================================================
%  5. AUTOCORRELATION OF GPR / GPT / GPA
%  ========================================================================
fprintf('\n--- GPR autocorrelation analysis ---\n');

fig5 = figure('Position', [100 100 1200 400], 'Name', 'GPR Autocorrelation');
max_lag = 24;

shock_vars  = {'log_GPR', 'log_GPT', 'log_GPA'};
shock_names = {'log(GPR)', 'log(GPT)', 'log(GPA)'};

for i = 1:3
    subplot(1, 3, i);
    x = master.(shock_vars{i});
    x = x(~isnan(x));

    acf_vals = nan(max_lag+1, 1);
    for k = 0:max_lag
        temp = corrcoef(x(1:end-k), x(1+k:end));
        acf_vals(k+1) = temp(1,2);
    end

    bar(0:max_lag, acf_vals, 0.5, 'FaceColor', [0.3 0.5 0.8]);
    hold on;
    % 95% confidence band (approximate: 1.96/sqrt(T))
    yline( 1.96/sqrt(length(x)), 'r--', 'LineWidth', 0.8);
    yline(-1.96/sqrt(length(x)), 'r--', 'LineWidth', 0.8);
    hold off;
    title(shock_names{i});
    xlabel('Lag (months)');
    ylabel('ACF');
    ylim([-0.2 1.1]);
    grid on;
end

saveas(fig5, fullfile(out_dir, 'fig_gpr_acf.png'));
fprintf('  Saved: fig_gpr_acf.png\n');

%% === Done ===
fprintf('\n=== s02_explore_data complete ===\n');
fprintf('All figures saved to: %s\n', out_dir);

%% ========================================================================
%  LOCAL FUNCTIONS
%  ========================================================================

function t_stat = manual_adf(x, n_lags)
% MANUAL_ADF  Simple ADF test statistic (t-stat on the lagged level).
%   ADF regression: dx_t = a + rho * x_{t-1} + sum(phi_j * dx_{t-j}) + e_t
%   Returns t-stat on rho. Reject unit root if t_stat < critical value.

    x = x(:);
    T = length(x);
    dx = diff(x);

    % Build lagged differences
    Y = dx(n_lags+1:end);           % dependent: dx_t  (length T-1-n_lags)
    X = x(n_lags+1:end-1);          % lagged level: x_{t-1}  (same length)
    X = [ones(length(Y),1), X];     % add constant

    % Add lagged differences
    for j = 1:n_lags
        X = [X, dx(n_lags+1-j:end-j)]; %#ok<AGROW>
    end

    % OLS
    b = X \ Y;
    e = Y - X * b;
    se = sqrt(diag((e'*e / (length(Y) - size(X,2))) * inv(X'*X))); %#ok<INV>

    t_stat = b(2) / se(2);  % t-stat on the lagged level coefficient
end

function cmap = redblue_cmap()
% REDBLUE_CMAP  Diverging red-white-blue colormap for correlation matrices.
    n = 128;
    r = [linspace(0.2, 1, n), ones(1, n)];
    g = [linspace(0.2, 1, n), linspace(1, 0.2, n)];
    b = [ones(1, n), linspace(1, 0.2, n)];
    cmap = [r', g', b'];
end
