clear
clc
close all
warning('off','all')

cd 'D:\OneDrive\SKKU PhD\2026 Spring - 거시실증분석\Team Project (with HKUST)\repo\First-Stage\codes'

% Helper function for running ADL/LP analysis across specifications
function results = run_analysis(method, y_ip, y_pi, shock_vars, shock_names, master, specs, params)
    results = struct();
    for spec_idx = 1:length(specs)
        spec_name = specs{spec_idx}.name;
        controls = specs{spec_idx}.controls;

        for s = 1:length(shock_vars)
            shock = master.(shock_vars{s});
            if isempty(controls)
                X = shock;
            else
                X = [shock, cell2mat(cellfun(@(x) master.(x), controls, 'UniformOutput', false))];
            end

            valid = ~isnan(y_ip) & ~isnan(y_pi) & all(~isnan(X),2);
            y_ip_s = y_ip(valid); y_pi_s = y_pi(valid); X_s = X(valid,:);

            if strcmp(method, 'ADL')
                [imp_ip, cb_ip, shock_ip, lag_ip, adlcoef_ip] = ...
                    ir_ADL(y_ip_s, X_s, params.I_candidates, params.J, 0, params.H, params.alpha, params.N_B, params.mindelay, params.IC, params.trend);
                [imp_pi, cb_pi, shock_pi, lag_pi, adlcoef_pi] = ...
                    ir_ADL(y_pi_s, X_s, params.I_candidates, params.J, 0, params.H, params.alpha, params.N_B, params.mindelay, params.IC, params.trend);
                results.(spec_name).(shock_names{s}).ip = struct('imp', imp_ip, 'cb', cb_ip, 'shock', shock_ip, 'lag', lag_ip, 'adlcoef', adlcoef_ip);
                results.(spec_name).(shock_names{s}).pi = struct('imp', imp_pi, 'cb', cb_pi, 'shock', shock_pi, 'lag', lag_pi, 'adlcoef', adlcoef_pi);
            else % LP
                [imp_ip, cb_ip, shock_ip, lag_ip, resid_ip, sd_ip] = ...
                    ir_jorda(y_ip_s, X_s, params.I, params.J, params.Jflag, 0, params.H, params.alpha, params.trend, params.IC, params.L_NW);
                [imp_pi, cb_pi, shock_pi, lag_pi, resid_pi, sd_pi] = ...
                    ir_jorda(y_pi_s, X_s, params.I, params.J, params.Jflag, 0, params.H, params.alpha, params.trend, params.IC, params.L_NW);
                results.(spec_name).(shock_names{s}).ip = struct('imp', imp_ip, 'cb', cb_ip, 'shock', shock_ip, 'lag', lag_ip, 'resid', resid_ip, 'sd', sd_ip);
                results.(spec_name).(shock_names{s}).pi = struct('imp', imp_pi, 'cb', cb_pi, 'shock', shock_pi, 'lag', lag_pi, 'resid', resid_pi, 'sd', sd_pi);
            end

            fprintf('=== %s %s %s complete ===\n', shock_names{s}, spec_name, method);
        end
    end
end

% Helper function for plotting impulse responses
function plot_impulse_responses(results, shock_names, shock_colors, spec_names, method, x, out_dir, fig_prefix)
    % Single specification plots
    for spec_idx = 1:length(spec_names)
        figure('Position',[100 100 1200 900]);
        panel = 0;
        for s = 1:length(shock_names)
            % IP response
            panel = panel + 1;
            subplot(3,2,panel); hold on;
            scale = results.(spec_names{spec_idx}).(shock_names{s}).ip.shock.std;
            imp = results.(spec_names{spec_idx}).(shock_names{s}).ip.imp * scale;
            if strcmp(method, 'ADL')
                cb = results.(spec_names{spec_idx}).(shock_names{s}).ip.cb' * scale;
                fill([x fliplr(x)], [cb(1,:) fliplr(cb(2,:))], shock_colors{s}, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
            else
                cb = results.(spec_names{spec_idx}).(shock_names{s}).ip.cb * scale;
                fill([x fliplr(x)], [cb(:,1).' fliplr(cb(:,2).')], shock_colors{s}, 'EdgeColor','none', 'FaceAlpha',0.25);
            end
            plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2);
            spec_display = {'Baseline', '+UNRATE', '+UNRATE+VIX'};
            yline(0, 'k-'); title([shock_names{s} ' -> IP (' spec_display{spec_idx} ')']); xlabel('h'); ylabel('response'); grid on; box on;

            % Inflation response
            panel = panel + 1;
            subplot(3,2,panel); hold on;
            scale = results.(spec_names{spec_idx}).(shock_names{s}).pi.shock.std;
            imp = results.(spec_names{spec_idx}).(shock_names{s}).pi.imp * scale;
            if strcmp(method, 'ADL')
                cb = results.(spec_names{spec_idx}).(shock_names{s}).pi.cb' * scale;
                fill([x fliplr(x)], [cb(1,:) fliplr(cb(2,:))], shock_colors{s}, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
            else
                cb = results.(spec_names{spec_idx}).(shock_names{s}).pi.cb * scale;
                fill([x fliplr(x)], [cb(:,1).' fliplr(cb(:,2).')], shock_colors{s}, 'EdgeColor','none', 'FaceAlpha',0.25);
            end
            plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2);
            yline(0, 'k-'); title([shock_names{s} ' -> Inflation (' spec_display{spec_idx} ')']); xlabel('h'); ylabel('response'); grid on; box on;
        end
        sgtitle([method ': ' spec_display{spec_idx} ' (1-s.d. shock)']);
        saveas(gcf, fullfile(out_dir, [fig_prefix char('a' + spec_idx - 1) '_' method '_' spec_names{spec_idx} '.png']));
    end

    % Comparison plot
    figure('Position',[100 100 1200 900]);
    spec_colors = {[0 0 0], [0.4 0.4 0.4], [0.7 0.7 0.7]};
    panel = 0;
    for s = 1:length(shock_names)
        % IP comparison
        panel = panel + 1;
        subplot(3,2,panel); hold on;
        for spec_idx = 1:length(spec_names)
            scale = results.(spec_names{spec_idx}).(shock_names{s}).ip.shock.std;
            imp = results.(spec_names{spec_idx}).(shock_names{s}).ip.imp * scale;
            line_style = {'-', '--', '-.'};
            h(spec_idx) = plot(x, imp, line_style{spec_idx}, 'Color', spec_colors{spec_idx}, 'LineWidth', 2.2);
        end
        yline(0, 'k-'); title([shock_names{s} ' -> IP']); xlabel('h'); ylabel('response'); grid on; box on;

        % Inflation comparison
        panel = panel + 1;
        subplot(3,2,panel); hold on;
        for spec_idx = 1:length(spec_names)
            scale = results.(spec_names{spec_idx}).(shock_names{s}).pi.shock.std;
            imp = results.(spec_names{spec_idx}).(shock_names{s}).pi.imp * scale;
            line_style = {'-', '--', '-.'};
            plot(x, imp, line_style{spec_idx}, 'Color', spec_colors{spec_idx}, 'LineWidth', 2.2);
        end
        yline(0, 'k-'); title([shock_names{s} ' -> Inflation']); xlabel('h'); ylabel('response'); grid on; box on;
    end
    spec_display = {'Baseline', '+UNRATE', '+UNRATE+VIX'};
    lgd = legend(h, spec_display, 'Orientation', 'horizontal');
    lgd.Position = [0.35 0.02 0.3 0.03];
    sgtitle([method ' Comparison: ' strjoin(spec_display, ' vs ')]);
    saveas(gcf, fullfile(out_dir, [fig_prefix 'd_' method '_comparison.png']));
end

% =======================================================================
% LOAD DATA AND SETUP
% =======================================================================

load("M_Baseline_h1_Dataset.mat");

% Figure output directory
out_dir = fullfile(pwd, 'figures');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
fprintf('Figures will be saved to: %s\n', out_dir);

% =======================================================================
% DATA TRIMMING TO UNIFIED SAMPLE PERIOD
% =======================================================================
% Rationale: VIX only starts 1990:01. To ensure identical sample across
% all specifications (Baseline, +UNRATE, +UNRATE+VIX), we trim entire
% dataset to 1990:01-2025:12 (~432 months)

sample_start = datetime(1990,1,1);
sample_end   = datetime(2025,12,31);
mask = T.Date >= sample_start & T.Date <= sample_end;
T = T(mask, :);  % Overwrite with trimmed data
fprintf('Sample: %s to %s (%d months)\n', datestr(T.Date(1)), datestr(T.Date(end)), height(T));

% =======================================================================
% CREATE MASTER DATA STRUCTURE
% =======================================================================

% Direct variable mapping (no transformation needed)
master.date = T.Date;
master.VIX = T.VIX;
master.UNRATE = T.Unemployment;
master.FFR = T.Policy_Rate;
master.WTI = T.Raw_WTI_Crude;

% GPR variables: Convert from 100*log to levels (needed for ADF tests only)
% Dataset has LGPR = 100*log(GPR), convert back to levels
master.GPR = exp(T.LGPR / 100);
master.GPT = exp(T.LGPRT / 100);
master.GPA = exp(T.LGPRA / 100);

% GPR in normalized log form (main analysis variables)
% These are 100 * log(GPR), used throughout impulse response analysis
master.gpr_n = T.LGPR * 100;
master.gpt_n = T.LGPRT * 100;
master.gpa_n = T.LGPRA * 100;

% Construct log-levels from growth rates (efficient: no exp→log conversion)
% For IP: T.g_Indu is monthly growth rate → cumulative log-level
growth_log_ip = 100 * log(1 + T.g_Indu/100);
growth_log_ip(isnan(growth_log_ip)) = 0;  % Replace NaN with 0 for cumsum
master.log_ip = 100 * log(100) + cumsum([0; growth_log_ip(2:end)]);

% For CPI: T.Pi_Headline is monthly inflation → cumulative log-level
growth_log_cpi = 100 * log(1 + T.Pi_Headline/100);
growth_log_cpi(isnan(growth_log_cpi)) = 0;  % Replace NaN with 0 for cumsum
master.log_cpi = 100 * log(100) + cumsum([0; growth_log_cpi(2:end)]);

% Other log-levels (direct calculation)
master.log_wti = 100 * log(master.WTI);
master.log_vix = 100 * log(master.VIX);

% Growth rates: Use original data directly (most accurate)
% These are monthly percentage changes used in ADL analysis
master.dlog_ip = T.g_Indu;           % Industrial production growth
master.infl = T.Pi_Headline;         % Inflation rate
master.dlog_wti = [NaN; 100 * diff(log(master.WTI))];  % WTI growth
master.dlog_vix = [NaN; 100 * diff(log(master.VIX))];  % VIX growth

% Level variables for robustness checks
master.ffr_level = master.FFR;
master.unrate_level = master.UNRATE;

% =======================================================================
% ADF UNIT ROOT TESTS
% =======================================================================
% Test stationarity of key variables in levels vs first differences
% Uses MATLAB built-in adftest() instead of manual implementation

fprintf('\n==============================\n');
fprintf('  ADF UNIT ROOT TESTS\n');
fprintf('==============================\n\n');

% Variables to test: use log-transformed data where appropriate
adf_series = {
    'log(GPR)',  master.gpr_n     % Already log*100
    'log(GPT)',  master.gpt_n     % Already log*100
    'log(GPA)',  master.gpa_n     % Already log*100
    'log(IP)',   master.log_ip    % Constructed log*100
    'log(CPI)',  master.log_cpi   % Constructed log*100
    'log(WTI)',  master.log_wti   % Direct log*100
    'log(VIX)',  master.log_vix   % Direct log*100
    'UNRATE',    master.UNRATE    % Level
    'FFR',       master.FFR       % Level
};

n_lags_adf = 12;    % Monthly data: use 12 augmentation lags
cv_1pct = -3.44;    % Approximate 1% critical value (ADF with constant, T~500)

% Print header
fprintf('%-12s  %10s %10s | %10s %10s   %s\n', ...
    'Variable', 'Level t', '1% CV', '1st-diff t', '1% CV', 'Order');
fprintf('%s\n', repmat('-', 1, 72));

% Run tests for each variable
for i = 1:size(adf_series, 1)
    name = adf_series{i, 1};
    x = adf_series{i, 2};
    x = x(~isnan(x));  % Remove missing values

    % ADF test on levels and first differences
    [~, ~, t_lev] = adftest(x, 'lags', n_lags_adf);
    [~, ~, t_dif] = adftest(diff(x), 'lags', n_lags_adf);

    % Determine integration order based on critical value
    if t_lev < cv_1pct
        order = 'I(0)';      % Stationary in levels
    elseif t_dif < cv_1pct
        order = 'I(1)';      % Stationary in first differences
    else
        order = 'I(2)?';     % Potentially I(2) or higher
    end

    fprintf('%-12s  %10.3f %10.3f | %10.3f %10.3f   %s\n', ...
        name, t_lev, cv_1pct, t_dif, cv_1pct, order);
end
fprintf('\n');

% =======================================================================
% SUMMARY STATISTICS
% =======================================================================
% Generate descriptive statistics for key analysis variables

vars = {'gpr_n','gpt_n','gpa_n','dlog_ip','infl','ffr_level','dlog_wti','dlog_vix','unrate_level'};
labels = {'GPR','GPT','GPA','IP growth','Inflation','FFR','WTI growth','VIX growth','Unrate'};

fprintf('\n==============================\n');
fprintf('SUMMARY STATISTICS\n');
fprintf('==============================\n\n');

fprintf('%-12s %10s %10s %10s %10s %10s %10s %10s\n', ...
    'Variable','Mean','Std','Min','Max','Skew','Kurt','N');
fprintf('%s\n', repmat('-',1,95));

% Calculate and display statistics
data_matrix = cell2mat(cellfun(@(x) master.(x), vars, 'UniformOutput', false));
skew_vals = nan(size(data_matrix, 2), 1);
kurt_vals = nan(size(data_matrix, 2), 1);
for i = 1:size(data_matrix, 2)
    valid_data = data_matrix(~isnan(data_matrix(:,i)), i);
    if length(valid_data) > 0
        skew_vals(i) = skewness(valid_data);
        kurt_vals(i) = kurtosis(valid_data);
    end
end

stats = [mean(data_matrix, 'omitnan')', std(data_matrix, 'omitnan')', ...
         min(data_matrix, [], 'omitnan')', max(data_matrix, [], 'omitnan')', ...
         skew_vals, kurt_vals, sum(~isnan(data_matrix))'];

for i = 1:length(vars)
    fprintf('%-12s %10.3f %10.3f %10.3f %10.3f %10.3f %10.3f %10d\n', ...
        labels{i}, stats(i,:));
end

% Create summary table
summary_table = array2table(stats, ...
    'VariableNames', {'Mean','Std','Min','Max','Skewness','Kurtosis','N'}, ...
    'RowNames', labels);
disp(summary_table)

% =======================================================================
% FIGURE 1: GPR TIME SERIES WITH EVENT WINDOWS
% =======================================================================
% Plot GPR/GPT/GPA indices with shaded event periods

% Define major geopolitical events for shading
events = [1990 8 1 1991 2 28; 2001 9 1 2001 9 30; 2003 3 1 2003 5 31; 2022 2 1 2022 12 31];
event_starts = datetime(events(:,1:3));
event_ends = datetime(events(:,4:6));

figure;
series_list = {'GPR','GPT','GPA'};
series_titles = {'GPR', 'GPT', 'GPA'};
series_colors = {[0.85 0.33 0.10], [0.00 0.45 0.74], [0.47 0.67 0.19]};

for s = 1:3
    subplot(3,1,s)
    x = master.(series_list{s});
    y_min = 0;
    y_max = max(x, [], 'omitnan') * 1.10;

    hold on
    % Shade event periods
    for i = 1:length(event_starts)
        patch([event_starts(i) event_ends(i) event_ends(i) event_starts(i)], ...
              [y_min y_min y_max y_max], [0.70 0.70 0.70], ...
              'EdgeColor', 'none', 'FaceAlpha', 0.55);
    end

    plot(master.date, x, 'LineWidth', 1.2, 'Color', series_colors{s});
    hold off

    xlim([datetime(1990,1,1) datetime(2025,12,31)])
    ylim([y_min y_max])
    title(series_titles{s})
    ylabel('Index')
    xticks(datetime(1990,1,1):calyears(5):datetime(2025,1,1))
    xtickformat('yyyy')
    grid on

    if s == 3, xlabel('Year'); end
end
saveas(gcf, fullfile(out_dir, 'fig01_gpr_gpt_gpa_timeseries.png'));

% =======================================================================
% FIGURE 2: MACRO VARIABLES TIME SERIES
% =======================================================================

figure;
macro_var_names = {'dlog_ip', 'infl', 'ffr_level', 'dlog_wti', 'dlog_vix'};
macro_vars = cellfun(@(x) master.(x), macro_var_names, 'UniformOutput', false);
macro_titles = {'Industrial Production Growth', 'Inflation', 'Federal Funds Rate', 'WTI Oil Price Growth', 'VIX Growth'};
macro_colors = {[0.00 0.45 0.74], [0.85 0.33 0.10], [0.47 0.67 0.19], [0.49 0.18 0.56], [0.64 0.08 0.18]};

for i = 1:5
    subplot(3,2,i)
    plot(master.date, macro_vars{i}, 'LineWidth', 1.2, 'Color', macro_colors{i});
    title(macro_titles{i})
    xlabel('Year')
    ylabel('Percent')
    xticks(datetime(1990,1,1):calyears(5):datetime(2025,1,1))
    xtickformat('yyyy')
    grid on
end
saveas(gcf, fullfile(out_dir, 'fig02_macro_variables.png'));

% =======================================================================
% FIGURE 3: CORRELATION MATRIX
% =======================================================================

% Select variables for correlation analysis
corr_vars = {'gpr_n','gpt_n','gpa_n','dlog_ip','infl','ffr_level','dlog_wti','dlog_vix','unrate_level'};
corr_labels = {'GPR','GPT','GPA','IP growth','Inflation','FFR','WTI growth','VIX growth','Unrate'};

% Build data matrix and compute correlations
X = cell2mat(cellfun(@(x) master.(x), corr_vars, 'UniformOutput', false));
valid = all(~isnan(X),2);
C = corrcoef(X(valid,:));

disp('Correlation matrix:')
disp(array2table(C, 'VariableNames', corr_labels, 'RowNames', corr_labels))

% Create correlation heatmap with custom colormap
n = 256;
r = [linspace(0,1,n/2), ones(1,n/2)]';
g = [linspace(0,1,n/2), linspace(1,0,n/2)]';
b = [ones(1,n/2), linspace(1,0,n/2)]';
cmap = [r g b];

figure;
imagesc(C);
colorbar;
caxis([-1 1]);
colormap(cmap);

set(gca, 'XTick', 1:length(corr_labels), 'YTick', 1:length(corr_labels));
set(gca, 'XTickLabel', corr_labels, 'YTickLabel', corr_labels);

title('Correlation Matrix (analysis variables, 1990–2025)');
axis square;
set(gca, 'FontSize', 10);

% Add correlation values as text
for i = 1:size(C,1)
    for j = 1:size(C,2)
        if abs(C(i,j)) >= 0.5
            txt_color = [1 1 1];  % White text for strong correlations
        else
            txt_color = [0 0 0];  % Black text for weak correlations
        end
        text(j, i, sprintf('%.2f', C(i,j)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 9, 'Color', txt_color);
    end
end
saveas(gcf, fullfile(out_dir, 'fig03_correlation_matrix.png'));

% =======================================================================
% FIGURE 4: AUTOCORRELATION ANALYSIS
% =======================================================================
% Show persistence differences among GPR components

gpr_data = [master.gpr_n, master.gpt_n, master.gpa_n];
valid = all(~isnan(gpr_data),2);
gpr_data = gpr_data(valid,:);

% Compute ACF and PACF up to 36 lags
ACF = []; PACF = [];
for i = 1:3
    [ACF(:,i), L] = simple_acf(gpr_data(:,i), 36);
    [PACF(:,i), L] = simple_pacf(gpr_data(:,i), 36);
end

name_title = {'GPR', 'GPT', 'GPA'};

% Plot ACF and PACF together
figure('Position',[100 100 1200 350])
for i = 1:3
    subplot(1,3,i)
    plot(L, ACF(:,i), 'b-', 'LineWidth', 1.5)
    hold on
    plot(L, PACF(:,i), 'r--', 'LineWidth', 1.5)
    title(name_title{i}, 'FontSize', 11)
    legend({'ACF','PACF'}, 'FontSize', 9, 'Location', 'northeast')
    set(gca, 'FontSize', 9)
    box on; grid on
end
saveas(gcf, fullfile(out_dir, 'fig04a_acf_pacf.png'));

% Plot ACF only with series colors
figure('Position',[100 100 1200 350])
for i = 1:3
    subplot(1,3,i)
    plot(L, ACF(:,i), 'LineWidth', 1.5, 'Color', series_colors{i})
    title(name_title{i}, 'FontSize', 11)
    xlabel('Lag'); ylabel('ACF')
    xlim([0 36])
    set(gca, 'FontSize', 9)
    box on; grid on
end
saveas(gcf, fullfile(out_dir, 'fig04b_acf_only.png'));

% =======================================================================
% ADL ANALYSIS (Autoregressive Distributed Lag)
% =======================================================================
% Estimate impulse responses using ADL methodology from Baek & Lee (2022)
% Required functions: ir_ADL.m, adltoma.m, lrv_nw.m

fprintf('\n==============================\n');
fprintf('  STARTING ADL ANALYSIS\n');
fprintf('==============================\n\n');

% ADL estimation settings
H = 36;                  % Maximum horizon (months)
J = H;                   % Lagged shocks
alpha = 0.90;            % 90% confidence bands
N_B = 1000;              % Bootstrap replications
mindelay = 0;            % Contemporaneous response allowed
trend = 0;               % Constant only (no trend)
I_candidates = 1:12;     % Endogenous lag candidates
IC = 0;                  % Information criterion

% Outcome variables (growth rates for ADL)
y_ip = master.dlog_ip;   % Industrial production growth
y_pi = master.infl;      % Inflation

% Shock variables
shock_vars = {'gpr_n','gpt_n','gpa_n'};
shock_names = {'GPR','GPT','GPA'};

% Define specifications and run ADL analysis
adl_specs = {struct('name', 'baseline', 'controls', []), ...
             struct('name', 'robust1', 'controls', {{'unrate_level'}}), ...
             struct('name', 'robust2', 'controls', {{'unrate_level', 'log_vix'}})};

adl_params = struct('I_candidates', I_candidates, 'J', J, 'H', H, 'alpha', alpha, ...
                    'N_B', N_B, 'mindelay', mindelay, 'IC', IC, 'trend', trend);

adl_results = run_analysis('ADL', y_ip, y_pi, shock_vars, shock_names, master, adl_specs, adl_params);

% =======================================================================
% GENERATE ADL FIGURES (5a-5d)
% =======================================================================

x = 0:H;  % Horizon axis
shock_colors = {[0.85 0.33 0.10], [0.00 0.45 0.74], [0.47 0.67 0.19]};
spec_names = {'baseline', 'robust1', 'robust2'};

% Generate all ADL figures using helper function
plot_impulse_responses(adl_results, shock_names, shock_colors, spec_names, 'ADL', x, out_dir, 'fig05');

% =======================================================================
% LOCAL PROJECTIONS ANALYSIS
% =======================================================================
% Main methodology: estimate impulse responses using Jordà (2005) approach
% Required functions: ir_jorda.m, lrv_nw.m

fprintf('\n==============================\n');
fprintf('  STARTING LP ANALYSIS\n');
fprintf('==============================\n\n');

% LP estimation settings
H = 36;          % Horizon
I = 12;          % Endogenous lags
J = 0;           % Only contemporaneous shock
Jflag = 0;       % J applies only to shock, not controls
alpha = 0.90;    % 90% confidence level
trend = 1;       % Linear trend
IC = 0;          % BIC
L_NW = -1;       % Stock-Watson bandwidth rule

% Outcome variables (log-levels for LP)
% ir_jorda with level=0 constructs y(t+h) - y(t-1) internally
% Passing log-levels gives level impulse responses in log-points
y_ip = master.log_ip;    % log(IP) * 100
y_pi = master.log_cpi;   % log(CPI) * 100

% Define specifications and run LP analysis
lp_specs = {struct('name', 'baseline', 'controls', []), ...
            struct('name', 'robust1', 'controls', {{'unrate_level'}}), ...
            struct('name', 'robust2', 'controls', {{'unrate_level', 'log_vix'}})};

lp_params = struct('I', I, 'J', J, 'Jflag', Jflag, 'H', H, 'alpha', alpha, ...
                   'trend', trend, 'IC', IC, 'L_NW', L_NW);

lp_results = run_analysis('LP', y_ip, y_pi, shock_vars, shock_names, master, lp_specs, lp_params);

% =======================================================================
% GENERATE LP FIGURES (6a-6d)
% =======================================================================

% Generate all LP figures using helper function
plot_impulse_responses(lp_results, shock_names, shock_colors, spec_names, 'LP', x, out_dir, 'fig06');

% =======================================================================
% ADL vs LP COMPARISON FIGURES (7a-7b)
% =======================================================================

% ADL vs LP comparison (point estimates only)
figure('Position',[100 100 1200 900]);
panel = 0;
for s = 1:3
    % IP comparison
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    scale_adl = adl_results.baseline.(shock_names{s}).ip.shock.std;
    scale_lp = lp_results.baseline.(shock_names{s}).ip.shock.std;
    imp_adl = adl_results.baseline.(shock_names{s}).ip.imp * scale_adl;
    imp_lp = lp_results.baseline.(shock_names{s}).ip.imp * scale_lp;
    h1 = plot(x, imp_adl, '-', 'Color', shock_colors{s}, 'LineWidth', 2.4);
    h2 = plot(x, imp_lp, '--', 'Color', [0 0 0], 'LineWidth', 2.0);
    yline(0, 'k-'); title([shock_names{s} ' -> IP']); xlabel('h'); ylabel('response'); grid on; box on;

    % Inflation comparison
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    scale_adl = adl_results.baseline.(shock_names{s}).pi.shock.std;
    scale_lp = lp_results.baseline.(shock_names{s}).pi.shock.std;
    imp_adl = adl_results.baseline.(shock_names{s}).pi.imp * scale_adl;
    imp_lp = lp_results.baseline.(shock_names{s}).pi.imp * scale_lp;
    h1 = plot(x, imp_adl, '-', 'Color', shock_colors{s}, 'LineWidth', 2.4);
    h2 = plot(x, imp_lp, '--', 'Color', [0 0 0], 'LineWidth', 2.0);
    yline(0, 'k-'); title([shock_names{s} ' -> Inflation']); xlabel('h'); ylabel('response'); grid on; box on;
end
lgd = legend([h1 h2], {'ADL','LP'}, 'Orientation', 'horizontal');
lgd.Position = [0.42 0.02 0.16 0.03];
sgtitle('ADL vs LP Comparison (Baseline, 1-s.d. shock)');
saveas(gcf, fullfile(out_dir, 'fig07a_adl_vs_lp.png'));

% ADL vs LP with LP confidence bands
figure('Position',[100 100 1200 900]);
panel = 0;
for s = 1:3
    % IP comparison with bands
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    scale_adl = adl_results.baseline.(shock_names{s}).ip.shock.std;
    scale_lp = lp_results.baseline.(shock_names{s}).ip.shock.std;
    imp_adl = adl_results.baseline.(shock_names{s}).ip.imp * scale_adl;
    imp_lp = lp_results.baseline.(shock_names{s}).ip.imp * scale_lp;
    cb_lp = lp_results.baseline.(shock_names{s}).ip.cb * scale_lp;
    fill([x fliplr(x)], [cb_lp(:,1).' fliplr(cb_lp(:,2).')], [0.8 0.8 0.8], 'EdgeColor','none', 'FaceAlpha',0.35);
    h1 = plot(x, imp_adl, '-', 'Color', shock_colors{s}, 'LineWidth', 2.4);
    h2 = plot(x, imp_lp, '--', 'Color', [0 0 0], 'LineWidth', 2.0);
    yline(0, 'k-'); title([shock_names{s} ' -> IP']); xlabel('h'); ylabel('response'); grid on; box on;

    % Inflation comparison with bands
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    scale_adl = adl_results.baseline.(shock_names{s}).pi.shock.std;
    scale_lp = lp_results.baseline.(shock_names{s}).pi.shock.std;
    imp_adl = adl_results.baseline.(shock_names{s}).pi.imp * scale_adl;
    imp_lp = lp_results.baseline.(shock_names{s}).pi.imp * scale_lp;
    cb_lp = lp_results.baseline.(shock_names{s}).pi.cb * scale_lp;
    fill([x fliplr(x)], [cb_lp(:,1).' fliplr(cb_lp(:,2).')], [0.8 0.8 0.8], 'EdgeColor','none', 'FaceAlpha',0.35);
    h1 = plot(x, imp_adl, '-', 'Color', shock_colors{s}, 'LineWidth', 2.4);
    h2 = plot(x, imp_lp, '--', 'Color', [0 0 0], 'LineWidth', 2.0);
    yline(0, 'k-'); title([shock_names{s} ' -> Inflation']); xlabel('h'); ylabel('response'); grid on; box on;
end
lgd = legend([h1 h2], {'ADL','LP'}, 'Orientation', 'horizontal');
lgd.Position = [0.42 0.02 0.16 0.03];
sgtitle('ADL vs LP Comparison with LP Confidence Bands (Baseline, 1-s.d. shock)');
saveas(gcf, fullfile(out_dir, 'fig07b_adl_vs_lp_with_ci.png'));

% =======================================================================
% COMPLETION SUMMARY
% =======================================================================

fprintf('\n==============================\n');
fprintf('  ANALYSIS COMPLETE\n');
fprintf('==============================\n\n');
fprintf('Generated 15 figures in: %s\n', out_dir);
fprintf('- Fig 1: GPR/GPT/GPA time series with event windows\n');
fprintf('- Fig 2: Macro variables time series\n');
fprintf('- Fig 3: Correlation matrix\n');
fprintf('- Fig 4a/4b: Autocorrelation analysis\n');
fprintf('- Fig 5a-5d: ADL impulse responses (baseline, robust1, robust2, comparison)\n');
fprintf('- Fig 6a-6d: LP impulse responses (baseline, robust1, robust2, comparison)\n');
fprintf('- Fig 7a-7b: ADL vs LP comparisons\n');
fprintf('\nAll results stored in adl_results and lp_results structures.\n');