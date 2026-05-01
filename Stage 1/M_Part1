clear
clc
close all
warning('off','all')

script_dir = fileparts(mfilename('fullpath'));

% =======================================================================
% M_PART1: MONTHLY-FREQUENCY ANALYSIS OF GPR SHOCKS
% =======================================================================
% This script is a reorganized version of run_h1_simple_v3.m with one
% substantive change: the LP analysis now uses AR(1)-innovations of
% GPR/GPT/GPA as the shock variable, while the ADL analysis keeps the
% raw level (100*log) GPR series.
%
% RATIONALE FOR THE ASYMMETRIC SHOCK CONSTRUCTION:
%   - ADL (Baek & Lee 2022) embeds the shock's own dynamics inside the
%     model: lagged shocks x_{t-j} appear directly in the regression and
%     the IRF is recovered from the implied MA representation. Feeding a
%     pre-whitened innovation would double-count the AR step and break
%     the structural interpretation of the IRF.
%   - LP (Jorda 2005) estimates one regression per horizon. The
%     treatment x_t still mixes anticipated and unanticipated components.
%     Pre-extracting an AR(1) residual isolates the unforecastable part
%     and makes the impulse response interpretable as a response to a
%     standardized 1-s.d. innovation, comparable across studies and
%     consistent with the Frankie_Lp scripts used by the HKUST team.
%
% Helper functions required (in same folder):
%   ir_ADL.m, adltoma.m, ir_jorda.m, lrv_nw.m, simple_acf.m, simple_pacf.m
% =======================================================================

% Helper: run ADL or LP across (specification x shock) combinations.
% Note we accept a `shock_field_map` so that ADL and LP can read different
% master fields for the same shock label (level for ADL, innovation for LP).
function results = run_analysis(method, y_ip, y_pi, shock_field_map, shock_names, master, specs, params)
    results = struct();
    for spec_idx = 1:length(specs)
        spec_name = specs{spec_idx}.name;
        controls = specs{spec_idx}.controls;

        for s = 1:length(shock_names)
            shock = master.(shock_field_map{s});
            if isempty(controls)
                X = shock;
            else
                X = [shock, cell2mat(cellfun(@(x) master.(x), controls, 'UniformOutput', false))];
            end

            % Drop rows with any missing in y or X. Innovation series have
            % their first p_innov observations missing by construction.
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

% Helper: AR(p)-residual extraction with in-sample z-scoring.
% Returns a series with NaN in the first p positions and standardized
% residuals afterwards. Mirrors Frankie_Lp's extract_ar_innovation
% function so the two pipelines produce comparable shocks.
function z = extract_ar_innovation_zscore(x, p)
    x = x(:);
    T = length(x);
    Y = x(p+1:T);
    X = ones(T-p, 1);
    for j = 1:p
        X = [X, x(p+1-j:T-j)]; %#ok<AGROW>
    end
    good = isfinite(Y) & all(isfinite(X), 2);
    b = X(good,:) \ Y(good);
    resid = nan(T,1);
    fitted_part = X * b;
    resid(p+1:T) = Y - fitted_part;
    % In-sample z-score so the IRF is interpreted per 1 s.d. of innovation.
    use = isfinite(resid);
    mu = mean(resid(use));
    sd = std(resid(use));
    z = (resid - mu) ./ sd;
end

% Helper: plot IRF panels for a given (method, set of specs).
function plot_impulse_responses(results, shock_names, shock_colors, spec_names, method, x, out_dir, fig_prefix, shock_kind_label)
    spec_display = {'Baseline', '+UNRATE', '+UNRATE+VIX'};
    for spec_idx = 1:length(spec_names)
        figure('Position',[100 100 1200 900]);
        panel = 0;
        for s = 1:length(shock_names)
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
            yline(0, 'k-'); title([shock_names{s} ' -> IP (' spec_display{spec_idx} ')']); xlabel('h (months)'); ylabel('response'); grid on; box on;

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
            yline(0, 'k-'); title([shock_names{s} ' -> Inflation (' spec_display{spec_idx} ')']); xlabel('h (months)'); ylabel('response'); grid on; box on;
        end
        sgtitle([method ': ' spec_display{spec_idx} ' (' shock_kind_label ', 1-s.d. shock)']);
        saveas(gcf, fullfile(out_dir, [fig_prefix char('a' + spec_idx - 1) '_' method '_' spec_names{spec_idx} '.png']));
    end

    % Comparison plot across the three specifications.
    figure('Position',[100 100 1200 900]);
    spec_colors = {[0 0 0], [0.4 0.4 0.4], [0.7 0.7 0.7]};
    panel = 0;
    for s = 1:length(shock_names)
        panel = panel + 1;
        subplot(3,2,panel); hold on;
        for spec_idx = 1:length(spec_names)
            scale = results.(spec_names{spec_idx}).(shock_names{s}).ip.shock.std;
            imp = results.(spec_names{spec_idx}).(shock_names{s}).ip.imp * scale;
            line_style = {'-', '--', '-.'};
            h(spec_idx) = plot(x, imp, line_style{spec_idx}, 'Color', spec_colors{spec_idx}, 'LineWidth', 2.2);
        end
        yline(0, 'k-'); title([shock_names{s} ' -> IP']); xlabel('h (months)'); ylabel('response'); grid on; box on;

        panel = panel + 1;
        subplot(3,2,panel); hold on;
        for spec_idx = 1:length(spec_names)
            scale = results.(spec_names{spec_idx}).(shock_names{s}).pi.shock.std;
            imp = results.(spec_names{spec_idx}).(shock_names{s}).pi.imp * scale;
            line_style = {'-', '--', '-.'};
            plot(x, imp, line_style{spec_idx}, 'Color', spec_colors{spec_idx}, 'LineWidth', 2.2);
        end
        yline(0, 'k-'); title([shock_names{s} ' -> Inflation']); xlabel('h (months)'); ylabel('response'); grid on; box on;
    end
    lgd = legend(h, spec_display, 'Orientation', 'horizontal');
    lgd.Position = [0.35 0.02 0.3 0.03];
    sgtitle([method ' Comparison (' shock_kind_label '): ' strjoin(spec_display, ' vs ')]);
    saveas(gcf, fullfile(out_dir, [fig_prefix 'd_' method '_comparison.png']));
end

% =======================================================================
% LOAD DATA AND SETUP
% =======================================================================

load("M_Baseline_h1_Dataset.mat");

out_dir = fullfile(pwd, 'figures_M_Part1');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
fprintf('Figures will be saved to: %s\n', out_dir);

% =======================================================================
% SAMPLE TRIMMING TO 1990:01-2025:12
% =======================================================================
% VIX is only available from 1990:01. To keep an identical sample across
% the three specifications (Baseline, +UNRATE, +UNRATE+VIX) we trim the
% entire dataset to a common window. This ensures spec-comparison plots
% are not confounded by sample changes.
sample_start = datetime(1990,1,1);
sample_end   = datetime(2025,12,31);
mask = T.Date >= sample_start & T.Date <= sample_end;
T = T(mask, :);
fprintf('Sample: %s to %s (%d months)\n', datestr(T.Date(1)), datestr(T.Date(end)), height(T));

% =======================================================================
% MASTER DATA STRUCTURE (LEVEL VARIABLES)
% =======================================================================
% These are the variables used throughout the script. We keep them in a
% single struct so descriptive analysis, ADL, and LP can all read from a
% common source without name clashes.

master.date = T.Date;
master.VIX = T.VIX;
master.UNRATE = T.Unemployment;
master.FFR = T.Policy_Rate;
master.WTI = T.Raw_WTI_Crude;

% GPR variables. The dataset stores them as 100*log(GPR) for numerical
% convenience. We keep both forms because:
%   - levels (master.GPR) are needed for the time-series figure with
%     event windows (more readable visually);
%   - 100*log forms (master.gpr_n) are the actual analysis variables,
%     since log-GPR is closer to stationarity and standard in the
%     Caldara-Iacoviello literature.
master.GPR = exp(T.LGPR / 100);
master.GPT = exp(T.LGPRT / 100);
master.GPA = exp(T.LGPRA / 100);
master.gpr_n = T.LGPR * 100;
master.gpt_n = T.LGPRT * 100;
master.gpa_n = T.LGPRA * 100;

% Construct log-levels from monthly growth rates.
% IP and CPI are reported as percent monthly growth. We rebuild a
% log-level series so LP can output IRFs in log-points (cumulative
% percent response), which is the standard reporting unit.
growth_log_ip = 100 * log(1 + T.g_Indu/100);
growth_log_ip(isnan(growth_log_ip)) = 0;
master.log_ip = 100 * log(100) + cumsum([0; growth_log_ip(2:end)]);

growth_log_cpi = 100 * log(1 + T.Pi_Headline/100);
growth_log_cpi(isnan(growth_log_cpi)) = 0;
master.log_cpi = 100 * log(100) + cumsum([0; growth_log_cpi(2:end)]);

master.log_wti = 100 * log(master.WTI);
master.log_vix = 100 * log(master.VIX);

% Growth-rate variables for ADL (which models growth rates rather than
% log-levels by design in this implementation).
master.dlog_ip = T.g_Indu;
master.infl = T.Pi_Headline;
master.dlog_wti = [NaN; 100 * diff(log(master.WTI))];
master.dlog_vix = [NaN; 100 * diff(log(master.VIX))];

master.ffr_level = master.FFR;
master.unrate_level = master.UNRATE;

% =======================================================================
% AR(1)-INNOVATION SHOCKS FOR LP
% =======================================================================
% We extract AR(1) residuals of (100*log) GPR series and z-score them in
% sample. These innovations are used as LP shocks; ADL keeps the level
% series. See the header for the full rationale.
%
% AR order p_innov = 1 follows the Frankie_Lp convention so that monthly
% and quarterly Q_Part1 results can be compared on the same shock basis.
% The first observation of each innovation series is NaN (unavailable
% by construction); LP discards it via the `valid` mask.
p_innov = 1;

master.gpr_innov = extract_ar_innovation_zscore(master.gpr_n, p_innov);
master.gpt_innov = extract_ar_innovation_zscore(master.gpt_n, p_innov);
master.gpa_innov = extract_ar_innovation_zscore(master.gpa_n, p_innov);

fprintf('\nAR(1) innovations extracted for GPR/GPT/GPA (p_innov=%d, z-scored in sample).\n', p_innov);
fprintf('  gpr_innov: mean=%.4f, std=%.4f, n=%d\n', ...
    mean(master.gpr_innov,'omitnan'), std(master.gpr_innov,'omitnan'), sum(~isnan(master.gpr_innov)));
fprintf('  gpt_innov: mean=%.4f, std=%.4f, n=%d\n', ...
    mean(master.gpt_innov,'omitnan'), std(master.gpt_innov,'omitnan'), sum(~isnan(master.gpt_innov)));
fprintf('  gpa_innov: mean=%.4f, std=%.4f, n=%d\n', ...
    mean(master.gpa_innov,'omitnan'), std(master.gpa_innov,'omitnan'), sum(~isnan(master.gpa_innov)));

% =======================================================================
% ADF UNIT ROOT TESTS
% =======================================================================
% Tests are run on the LEVEL GPR series (not the innovation), because
% the innovation is white-noise by construction and the test would be
% uninformative. The motivation is to document the integration order
% used to justify the log-level vs growth-rate choice in LP and ADL.

fprintf('\n==============================\n');
fprintf('  ADF UNIT ROOT TESTS\n');
fprintf('==============================\n\n');

adf_series = {
    'log(GPR)',  master.gpr_n
    'log(GPT)',  master.gpt_n
    'log(GPA)',  master.gpa_n
    'log(IP)',   master.log_ip
    'log(CPI)',  master.log_cpi
    'log(WTI)',  master.log_wti
    'log(VIX)',  master.log_vix
    'UNRATE',    master.UNRATE
    'FFR',       master.FFR
};

n_lags_adf = 12;    % monthly data: 12 augmentation lags to absorb annual seasonality
cv_1pct = -3.44;    % approximate 1% CV for ADF with constant, T~432

fprintf('%-12s  %10s %10s | %10s %10s   %s\n', ...
    'Variable', 'Level t', '1% CV', '1st-diff t', '1% CV', 'Order');
fprintf('%s\n', repmat('-', 1, 72));

for i = 1:size(adf_series, 1)
    name = adf_series{i, 1};
    x = adf_series{i, 2};
    x = x(~isnan(x));

    [~, ~, t_lev] = adftest(x, 'lags', n_lags_adf);
    [~, ~, t_dif] = adftest(diff(x), 'lags', n_lags_adf);

    if t_lev < cv_1pct
        order = 'I(0)';
    elseif t_dif < cv_1pct
        order = 'I(1)';
    else
        order = 'I(2)?';
    end

    fprintf('%-12s  %10.3f %10.3f | %10.3f %10.3f   %s\n', ...
        name, t_lev, cv_1pct, t_dif, cv_1pct, order);
end
fprintf('\n');

% =======================================================================
% SUMMARY STATISTICS
% =======================================================================
% Reported on level/growth-rate variables (not innovations) so the table
% matches what is published in standard descriptive sections. The
% innovation series are diagnostics, not summary objects.

vars = {'gpr_n','gpt_n','gpa_n','dlog_ip','infl','ffr_level','dlog_wti','dlog_vix','unrate_level'};
labels = {'GPR','GPT','GPA','IP growth','Inflation','FFR','WTI growth','VIX growth','Unrate'};

fprintf('\n==============================\n');
fprintf('SUMMARY STATISTICS\n');
fprintf('==============================\n\n');

fprintf('%-12s %10s %10s %10s %10s %10s %10s %10s\n', ...
    'Variable','Mean','Std','Min','Max','Skew','Kurt','N');
fprintf('%s\n', repmat('-',1,95));

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

summary_table = array2table(stats, ...
    'VariableNames', {'Mean','Std','Min','Max','Skewness','Kurtosis','N'}, ...
    'RowNames', labels);
disp(summary_table)

% =======================================================================
% FIGURE 1: GPR/GPT/GPA TIME SERIES WITH EVENT WINDOWS
% =======================================================================
% Event windows highlight episodes where geopolitical risk spikes are
% known to have macro-relevant transmission. The shaded periods are
% standard in the Caldara-Iacoviello literature.

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
% Computed on level/growth-rate variables. Innovations are not included
% because they are by construction near-orthogonal to lagged information
% and would crowd out informative correlations.

corr_vars = {'gpr_n','gpt_n','gpa_n','dlog_ip','infl','ffr_level','dlog_wti','dlog_vix','unrate_level'};
corr_labels = {'GPR','GPT','GPA','IP growth','Inflation','FFR','WTI growth','VIX growth','Unrate'};

X = cell2mat(cellfun(@(x) master.(x), corr_vars, 'UniformOutput', false));
valid = all(~isnan(X),2);
C = corrcoef(X(valid,:));

disp('Correlation matrix:')
disp(array2table(C, 'VariableNames', corr_labels, 'RowNames', corr_labels))

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

for i = 1:size(C,1)
    for j = 1:size(C,2)
        if abs(C(i,j)) >= 0.5
            txt_color = [1 1 1];
        else
            txt_color = [0 0 0];
        end
        text(j, i, sprintf('%.2f', C(i,j)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 9, 'Color', txt_color);
    end
end
saveas(gcf, fullfile(out_dir, 'fig03_correlation_matrix.png'));

% =======================================================================
% FIGURE 4: ACF/PACF OF GPR/GPT/GPA (LEVELS)
% =======================================================================
% Computed on the LEVEL series. The point of this figure is to document
% the persistence that motivates the AR(1)-pre-whitening for LP shocks.
% A near-flat ACF on the innovation series would confirm that the AR(1)
% step removed the predictable component (we report this separately).

gpr_data = [master.gpr_n, master.gpt_n, master.gpa_n];
valid = all(~isnan(gpr_data),2);
gpr_data = gpr_data(valid,:);

ACF = []; PACF = [];
for i = 1:3
    [ACF(:,i), L] = simple_acf(gpr_data(:,i), 36);
    [PACF(:,i), L] = simple_pacf(gpr_data(:,i), 36);
end

name_title = {'GPR', 'GPT', 'GPA'};

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

% Diagnostic: ACF of the innovation series. If the AR(1) pre-whitening
% worked, these ACFs should hover around zero for all lags > 0, which is
% the necessary condition for the LP shock to be interpretable as
% unforecastable.
innov_data = [master.gpr_innov, master.gpt_innov, master.gpa_innov];
valid_innov = all(~isnan(innov_data),2);
innov_data = innov_data(valid_innov,:);

ACF_innov = [];
for i = 1:3
    [ACF_innov(:,i), L] = simple_acf(innov_data(:,i), 36);
end

figure('Position',[100 100 1200 350])
for i = 1:3
    subplot(1,3,i)
    plot(L, ACF_innov(:,i), 'LineWidth', 1.5, 'Color', series_colors{i})
    yline(0, 'k--');
    title([name_title{i} ' innovation'], 'FontSize', 11)
    xlabel('Lag'); ylabel('ACF')
    xlim([0 36])
    ylim([-0.3 0.3])
    set(gca, 'FontSize', 9)
    box on; grid on
end
sgtitle('AR(1) innovation ACFs — diagnostic for LP shock')
saveas(gcf, fullfile(out_dir, 'fig04c_acf_innovation.png'));

% =======================================================================
% ADL ANALYSIS — uses LEVEL GPR as the shock
% =======================================================================
% ADL embeds shock dynamics inside the model via lagged x_{t-j}. Feeding
% an AR-prewhitened innovation here would double-count and break the
% structural interpretation of the IRF, so we keep the level.

fprintf('\n==============================\n');
fprintf('  STARTING ADL ANALYSIS (level GPR shocks)\n');
fprintf('==============================\n\n');

H = 36;                  % horizon: 36 months = 3 years
J = H;                   % match lagged-shock window to horizon
alpha = 0.90;            % 90% bands, conventional in LP literature
N_B = 1000;              % bootstrap reps for ADL CIs
mindelay = 0;            % allow contemporaneous response
trend = 0;               % constant only (no time trend)
I_candidates = 1:12;     % endogenous lag candidates for IC selection
IC = 0;                  % default IC

y_ip = master.dlog_ip;   % ADL is specified on growth rates here
y_pi = master.infl;

% Use level GPR for ADL.
shock_field_map_adl = {'gpr_n', 'gpt_n', 'gpa_n'};
shock_names = {'GPR','GPT','GPA'};

adl_specs = {struct('name', 'baseline', 'controls', []), ...
             struct('name', 'robust1', 'controls', {{'unrate_level'}}), ...
             struct('name', 'robust2', 'controls', {{'unrate_level', 'log_vix'}})};

adl_params = struct('I_candidates', I_candidates, 'J', J, 'H', H, 'alpha', alpha, ...
                    'N_B', N_B, 'mindelay', mindelay, 'IC', IC, 'trend', trend);

adl_results = run_analysis('ADL', y_ip, y_pi, shock_field_map_adl, shock_names, master, adl_specs, adl_params);

x = 0:H;
shock_colors = {[0.85 0.33 0.10], [0.00 0.45 0.74], [0.47 0.67 0.19]};
spec_names = {'baseline', 'robust1', 'robust2'};

plot_impulse_responses(adl_results, shock_names, shock_colors, spec_names, 'ADL', x, out_dir, 'fig05', 'level GPR shock');

% =======================================================================
% LP ANALYSIS — uses AR(1)-INNOVATION GPR as the shock
% =======================================================================
% LP estimates one regression per horizon. Pre-whitening x_t separates
% anticipated vs unanticipated components, so beta_h is interpretable as
% a response to a true 1-s.d. unforecastable innovation. This matches
% the convention in Frankie_Lp/Q_Baseline_NoVIX.m.

fprintf('\n==============================\n');
fprintf('  STARTING LP ANALYSIS (AR(1) innovation shocks)\n');
fprintf('==============================\n\n');

H = 36;          % horizon: same 36-month window for direct comparability with ADL
I = 12;          % endogenous lags (1 year)
J = 0;           % only contemporaneous shock; lagged shocks unnecessary
                 % because innovation is already orthogonal to its own past
Jflag = 0;       % J applies only to shock, not controls
alpha = 0.90;
trend = 1;       % linear trend allowed (LP can absorb low-frequency drift)
IC = 0;
L_NW = -1;       % Stock-Watson bandwidth rule for HAC SE

% LP outcomes are log-levels so the IRF reads in cumulative log-points.
y_ip = master.log_ip;
y_pi = master.log_cpi;

% Use AR(1)-innovation GPR for LP.
shock_field_map_lp = {'gpr_innov', 'gpt_innov', 'gpa_innov'};

lp_specs = {struct('name', 'baseline', 'controls', []), ...
            struct('name', 'robust1', 'controls', {{'unrate_level'}}), ...
            struct('name', 'robust2', 'controls', {{'unrate_level', 'log_vix'}})};

lp_params = struct('I', I, 'J', J, 'Jflag', Jflag, 'H', H, 'alpha', alpha, ...
                   'trend', trend, 'IC', IC, 'L_NW', L_NW);

lp_results = run_analysis('LP', y_ip, y_pi, shock_field_map_lp, shock_names, master, lp_specs, lp_params);

plot_impulse_responses(lp_results, shock_names, shock_colors, spec_names, 'LP', x, out_dir, 'fig06', 'AR(1) innovation shock');

% =======================================================================
% ADL vs LP COMPARISON
% =======================================================================
% Note: the two methods now use DIFFERENT shock variables (level vs
% innovation). The IRFs are still comparable because both are scaled to
% a 1-s.d. shock of their respective shock series, and the qualitative
% shape (sign, persistence, hump-shape) should be preserved if the AR
% pre-whitening did not throw away the macro signal.

figure('Position',[100 100 1200 900]);
panel = 0;
for s = 1:3
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    scale_adl = adl_results.baseline.(shock_names{s}).ip.shock.std;
    scale_lp = lp_results.baseline.(shock_names{s}).ip.shock.std;
    imp_adl = adl_results.baseline.(shock_names{s}).ip.imp * scale_adl;
    imp_lp = lp_results.baseline.(shock_names{s}).ip.imp * scale_lp;
    h1 = plot(x, imp_adl, '-', 'Color', shock_colors{s}, 'LineWidth', 2.4);
    h2 = plot(x, imp_lp, '--', 'Color', [0 0 0], 'LineWidth', 2.0);
    yline(0, 'k-'); title([shock_names{s} ' -> IP']); xlabel('h (months)'); ylabel('response'); grid on; box on;

    panel = panel + 1;
    subplot(3,2,panel); hold on;
    scale_adl = adl_results.baseline.(shock_names{s}).pi.shock.std;
    scale_lp = lp_results.baseline.(shock_names{s}).pi.shock.std;
    imp_adl = adl_results.baseline.(shock_names{s}).pi.imp * scale_adl;
    imp_lp = lp_results.baseline.(shock_names{s}).pi.imp * scale_lp;
    h1 = plot(x, imp_adl, '-', 'Color', shock_colors{s}, 'LineWidth', 2.4);
    h2 = plot(x, imp_lp, '--', 'Color', [0 0 0], 'LineWidth', 2.0);
    yline(0, 'k-'); title([shock_names{s} ' -> Inflation']); xlabel('h (months)'); ylabel('response'); grid on; box on;
end
lgd = legend([h1 h2], {'ADL (level shock)','LP (innovation shock)'}, 'Orientation', 'horizontal');
lgd.Position = [0.35 0.02 0.3 0.03];
sgtitle('ADL vs LP Comparison (Baseline, 1-s.d. shock)');
saveas(gcf, fullfile(out_dir, 'fig07a_adl_vs_lp.png'));

figure('Position',[100 100 1200 900]);
panel = 0;
for s = 1:3
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
    yline(0, 'k-'); title([shock_names{s} ' -> IP']); xlabel('h (months)'); ylabel('response'); grid on; box on;

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
    yline(0, 'k-'); title([shock_names{s} ' -> Inflation']); xlabel('h (months)'); ylabel('response'); grid on; box on;
end
lgd = legend([h1 h2], {'ADL (level shock)','LP (innovation shock)'}, 'Orientation', 'horizontal');
lgd.Position = [0.35 0.02 0.3 0.03];
sgtitle('ADL vs LP Comparison with LP Confidence Bands (Baseline, 1-s.d. shock)');
saveas(gcf, fullfile(out_dir, 'fig07b_adl_vs_lp_with_ci.png'));

% =======================================================================
% COMPLETION SUMMARY
% =======================================================================

fprintf('\n==============================\n');
fprintf('  M_PART1 ANALYSIS COMPLETE\n');
fprintf('==============================\n\n');
fprintf('Generated figures in: %s\n', out_dir);
fprintf('  Fig 1: GPR/GPT/GPA time series with event windows (levels)\n');
fprintf('  Fig 2: Macro variables time series\n');
fprintf('  Fig 3: Correlation matrix (level/growth variables)\n');
fprintf('  Fig 4a/4b: ACF/PACF of GPR levels (motivates AR pre-whitening)\n');
fprintf('  Fig 4c: ACF of AR(1) innovations (diagnostic for LP shock)\n');
fprintf('  Fig 5a-5d: ADL impulse responses, level GPR shock\n');
fprintf('  Fig 6a-6d: LP impulse responses, AR(1) innovation shock\n');
fprintf('  Fig 7a-7b: ADL (level) vs LP (innovation) comparisons\n');
fprintf('\nResults stored in adl_results and lp_results.\n');
