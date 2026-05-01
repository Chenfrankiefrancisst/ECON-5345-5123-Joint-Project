clear
clc
close all
warning('off','all')

script_dir = fileparts(mfilename('fullpath'));

% =======================================================================
% Q_PART1: QUARTERLY-FREQUENCY ANALYSIS OF GPR SHOCKS
% =======================================================================
% Quarterly counterpart of M_Part1.m. The same analytic pipeline (ADF,
% summary statistics, descriptive figures, ADL, LP, ADL vs LP) is run
% at quarterly frequency.
%
% AGGREGATION CHOICE:
%   We aggregate the monthly dataset to quarters by taking the simple
%   mean within each calendar quarter (Jan-Mar, Apr-Jun, Jul-Sep, Oct-Dec).
%   This is the most common convention in macro applications:
%   - For stock-like variables (GPR, VIX, FFR, UNRATE, log-levels) the
%     quarterly mean is a smooth representative of the quarter.
%   - For flow-like variables (growth rates, inflation) the mean across
%     three monthly observations equals the average monthly rate during
%     the quarter, which is a defensible quarterly summary.
%
% LOG-LEVEL CONSTRUCTION (METHOD A):
%   We first build monthly log-levels (cumulative sum of log growth) and
%   then aggregate those log-levels to quarters via mean. This is more
%   accurate than rebuilding log-levels from quarterly growth rates,
%   because monthly cumulation preserves all within-quarter information.
%
% ASYMMETRIC SHOCK CONSTRUCTION (same as M_Part1):
%   - ADL keeps level (100*log) GPR. ADL embeds shock dynamics inside
%     the model (lagged x_{t-j} appear in the regression and the IRF is
%     recovered from the implied MA representation), so feeding a
%     pre-whitened innovation would double-count and break the
%     structural interpretation.
%   - LP uses AR(1)-innovation GPR. LP's beta_h is interpretable as a
%     response to a 1-s.d. unforecastable shock, comparable across
%     studies and consistent with Frankie_Lp/Q_Baseline_NoVIX.m.
%
% Helper functions required (in same folder):
%   ir_ADL.m, adltoma.m, ir_jorda.m, lrv_nw.m, simple_acf.m, simple_pacf.m
% =======================================================================

% Helper: monthly -> quarterly aggregation by simple mean.
% Returns a Tq-by-K matrix where Tq = number of complete quarters.
% The first row corresponds to the calendar quarter containing the first
% observation in `dates`. Quarters with fewer than 3 observations (only
% possible at the boundaries) are dropped to keep aggregation honest.
function [Xq, q_dates] = monthly_to_quarterly_mean(X, dates)
    if isvector(X), X = X(:); end
    yr = year(dates);
    qr = ceil(month(dates) / 3);
    keys = yr * 10 + qr;
    [unique_keys, ~, ic] = unique(keys, 'stable');
    Tq = length(unique_keys);
    K  = size(X, 2);
    Xq = nan(Tq, K);
    counts = accumarray(ic, 1);
    for k = 1:K
        s = accumarray(ic, X(:,k), [], @(v) mean(v, 'omitnan'));
        Xq(:,k) = s;
    end
    drop = counts < 3;
    Xq(drop, :) = [];
    unique_keys(drop) = [];
    yr_q = floor(unique_keys / 10);
    qr_q = unique_keys - yr_q * 10;
    q_dates = datetime(yr_q, (qr_q - 1) * 3 + 1, 1);  % first month of each quarter
end

% Helper: run ADL or LP across (specification x shock) combinations.
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

            valid = ~isnan(y_ip) & ~isnan(y_pi) & all(~isnan(X),2);
            y_ip_s = y_ip(valid); y_pi_s = y_pi(valid); X_s = X(valid,:);

            if strcmp(method, 'ADL')
                [imp_ip, cb_ip, shock_ip, lag_ip, adlcoef_ip] = ...
                    ir_ADL(y_ip_s, X_s, params.I_candidates, params.J, 0, params.H, params.alpha, params.N_B, params.mindelay, params.IC, params.trend);
                [imp_pi, cb_pi, shock_pi, lag_pi, adlcoef_pi] = ...
                    ir_ADL(y_pi_s, X_s, params.I_candidates, params.J, 0, params.H, params.alpha, params.N_B, params.mindelay, params.IC, params.trend);
                results.(spec_name).(shock_names{s}).ip = struct('imp', imp_ip, 'cb', cb_ip, 'shock', shock_ip, 'lag', lag_ip, 'adlcoef', adlcoef_ip);
                results.(spec_name).(shock_names{s}).pi = struct('imp', imp_pi, 'cb', cb_pi, 'shock', shock_pi, 'lag', lag_pi, 'adlcoef', adlcoef_pi);
            else
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
            yline(0, 'k-'); title([shock_names{s} ' -> IP (' spec_display{spec_idx} ')']); xlabel('h (quarters)'); ylabel('response'); grid on; box on;

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
            yline(0, 'k-'); title([shock_names{s} ' -> Inflation (' spec_display{spec_idx} ')']); xlabel('h (quarters)'); ylabel('response'); grid on; box on;
        end
        sgtitle([method ': ' spec_display{spec_idx} ' (' shock_kind_label ', 1-s.d. shock)']);
        saveas(gcf, fullfile(out_dir, [fig_prefix char('a' + spec_idx - 1) '_' method '_' spec_names{spec_idx} '.png']));
    end

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
        yline(0, 'k-'); title([shock_names{s} ' -> IP']); xlabel('h (quarters)'); ylabel('response'); grid on; box on;

        panel = panel + 1;
        subplot(3,2,panel); hold on;
        for spec_idx = 1:length(spec_names)
            scale = results.(spec_names{spec_idx}).(shock_names{s}).pi.shock.std;
            imp = results.(spec_names{spec_idx}).(shock_names{s}).pi.imp * scale;
            line_style = {'-', '--', '-.'};
            plot(x, imp, line_style{spec_idx}, 'Color', spec_colors{spec_idx}, 'LineWidth', 2.2);
        end
        yline(0, 'k-'); title([shock_names{s} ' -> Inflation']); xlabel('h (quarters)'); ylabel('response'); grid on; box on;
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

out_dir = fullfile(pwd, 'figures_Q_Part1');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
fprintf('Figures will be saved to: %s\n', out_dir);

% =======================================================================
% TRIM MONTHLY SAMPLE BEFORE AGGREGATION
% =======================================================================
% Trim to 1990:01-2025:12 first so the resulting quarters are 1990Q1-2025Q4.
% This guarantees the quarterly sample is exactly aligned with the
% monthly sample used in M_Part1, which is essential for any
% monthly-vs-quarterly cross-frequency comparison in the paper.
sample_start = datetime(1990,1,1);
sample_end   = datetime(2025,12,31);
mask = T.Date >= sample_start & T.Date <= sample_end;
T = T(mask, :);
fprintf('Monthly sample after trim: %s to %s (%d months)\n', ...
    datestr(T.Date(1)), datestr(T.Date(end)), height(T));

% =======================================================================
% STEP 1: BUILD MONTHLY MASTER (PRE-AGGREGATION)
% =======================================================================
% We first construct all the monthly variables exactly as in M_Part1,
% INCLUDING the constructed monthly log-levels. This is essential for
% method (a): we aggregate the monthly log-level to quarters rather
% than rebuilding it from quarterly growth rates. The latter would
% truncate within-quarter information and produce a slightly different
% level path.
m = struct();
m.date = T.Date;
m.VIX = T.VIX;
m.UNRATE = T.Unemployment;
m.FFR = T.Policy_Rate;
m.WTI = T.Raw_WTI_Crude;
m.GPR = exp(T.LGPR / 100);
m.GPT = exp(T.LGPRT / 100);
m.GPA = exp(T.LGPRA / 100);
m.gpr_n = T.LGPR * 100;
m.gpt_n = T.LGPRT * 100;
m.gpa_n = T.LGPRA * 100;

growth_log_ip = 100 * log(1 + T.g_Indu/100);
growth_log_ip(isnan(growth_log_ip)) = 0;
m.log_ip = 100 * log(100) + cumsum([0; growth_log_ip(2:end)]);

growth_log_cpi = 100 * log(1 + T.Pi_Headline/100);
growth_log_cpi(isnan(growth_log_cpi)) = 0;
m.log_cpi = 100 * log(100) + cumsum([0; growth_log_cpi(2:end)]);

m.log_wti = 100 * log(m.WTI);
m.log_vix = 100 * log(m.VIX);

m.dlog_ip = T.g_Indu;
m.infl = T.Pi_Headline;
m.dlog_wti = [NaN; 100 * diff(log(m.WTI))];
m.dlog_vix = [NaN; 100 * diff(log(m.VIX))];

m.ffr_level = m.FFR;
m.unrate_level = m.UNRATE;

% =======================================================================
% STEP 2: AGGREGATE TO QUARTERLY VIA MEAN
% =======================================================================
% Field-by-field aggregation. We pack the monthly fields into a matrix,
% aggregate jointly so all variables share an identical date axis, and
% unpack into the quarterly master struct.
agg_fields = {'VIX','UNRATE','FFR','WTI','GPR','GPT','GPA', ...
              'gpr_n','gpt_n','gpa_n','log_ip','log_cpi', ...
              'log_wti','log_vix','dlog_ip','infl','dlog_wti','dlog_vix', ...
              'ffr_level','unrate_level'};
% Note: 'dlog_wti' appears twice in the list above so we deduplicate.
agg_fields = unique(agg_fields, 'stable');

M_matrix = nan(length(m.date), length(agg_fields));
for k = 1:length(agg_fields)
    M_matrix(:, k) = m.(agg_fields{k});
end

[Q_matrix, q_dates] = monthly_to_quarterly_mean(M_matrix, m.date);

master = struct();
master.date = q_dates;
for k = 1:length(agg_fields)
    master.(agg_fields{k}) = Q_matrix(:, k);
end

fprintf('Quarterly sample: %s to %s (%d quarters)\n', ...
    datestr(master.date(1)), datestr(master.date(end)), length(master.date));

% =======================================================================
% STEP 3: AR(1)-INNOVATION SHOCKS FOR LP (QUARTERLY)
% =======================================================================
% Same construction as M_Part1, applied to the quarterly aggregated
% level GPR series. AR order p_innov = 1 matches Frankie_Lp's quarterly
% pipeline so our LP results are directly comparable to theirs.

p_innov = 1;
master.gpr_innov = extract_ar_innovation_zscore(master.gpr_n, p_innov);
master.gpt_innov = extract_ar_innovation_zscore(master.gpt_n, p_innov);
master.gpa_innov = extract_ar_innovation_zscore(master.gpa_n, p_innov);

fprintf('\nQuarterly AR(1) innovations extracted (p_innov=%d, z-scored).\n', p_innov);
fprintf('  gpr_innov: mean=%.4f, std=%.4f, n=%d\n', ...
    mean(master.gpr_innov,'omitnan'), std(master.gpr_innov,'omitnan'), sum(~isnan(master.gpr_innov)));
fprintf('  gpt_innov: mean=%.4f, std=%.4f, n=%d\n', ...
    mean(master.gpt_innov,'omitnan'), std(master.gpt_innov,'omitnan'), sum(~isnan(master.gpt_innov)));
fprintf('  gpa_innov: mean=%.4f, std=%.4f, n=%d\n', ...
    mean(master.gpa_innov,'omitnan'), std(master.gpa_innov,'omitnan'), sum(~isnan(master.gpa_innov)));

% =======================================================================
% ADF UNIT ROOT TESTS (QUARTERLY)
% =======================================================================
% Critical value adjusted for the smaller quarterly sample (T~144 vs
% monthly T~432). The 1% MacKinnon CV with constant only at T=150 is
% approximately -3.49 (slightly more conservative than monthly's -3.44).
% Augmentation lags are reduced to 4 (one year of quarterly lags), since
% the higher-frequency seasonal lags from monthly are not relevant here.

fprintf('\n==============================\n');
fprintf('  ADF UNIT ROOT TESTS (quarterly)\n');
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

n_lags_adf = 4;
cv_1pct = -3.49;

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
% SUMMARY STATISTICS (QUARTERLY)
% =======================================================================

vars = {'gpr_n','gpt_n','gpa_n','dlog_ip','infl','ffr_level','dlog_wti','dlog_vix','unrate_level'};
labels = {'GPR','GPT','GPA','IP growth','Inflation','FFR','WTI growth','VIX growth','Unrate'};

fprintf('\n==============================\n');
fprintf('SUMMARY STATISTICS (quarterly)\n');
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
% FIGURE 1: GPR/GPT/GPA TIME SERIES WITH EVENT WINDOWS (QUARTERLY)
% =======================================================================

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
    title([series_titles{s} ' (quarterly mean)'])
    ylabel('Index')
    xticks(datetime(1990,1,1):calyears(5):datetime(2025,1,1))
    xtickformat('yyyy')
    grid on
    if s == 3, xlabel('Year'); end
end
saveas(gcf, fullfile(out_dir, 'fig01_gpr_gpt_gpa_timeseries.png'));

% =======================================================================
% FIGURE 2: MACRO VARIABLES TIME SERIES (QUARTERLY)
% =======================================================================

figure;
macro_var_names = {'dlog_ip', 'infl', 'ffr_level', 'dlog_wti', 'dlog_vix'};
macro_vars = cellfun(@(x) master.(x), macro_var_names, 'UniformOutput', false);
macro_titles = {'IP Growth (avg monthly within Q)', 'Inflation (avg monthly within Q)', 'Federal Funds Rate', 'WTI Growth (avg monthly within Q)', 'VIX Growth (avg monthly within Q)'};
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
% FIGURE 3: CORRELATION MATRIX (QUARTERLY)
% =======================================================================

corr_vars = {'gpr_n','gpt_n','gpa_n','dlog_ip','infl','ffr_level','dlog_wti','dlog_vix','unrate_level'};
corr_labels = {'GPR','GPT','GPA','IP growth','Inflation','FFR','WTI growth','VIX growth','Unrate'};

X = cell2mat(cellfun(@(x) master.(x), corr_vars, 'UniformOutput', false));
valid = all(~isnan(X),2);
C = corrcoef(X(valid,:));

disp('Correlation matrix (quarterly):')
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
title('Correlation Matrix — quarterly (1990Q1–2025Q4)');
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
% FIGURE 4: ACF/PACF OF GPR/GPT/GPA (QUARTERLY LEVELS)
% =======================================================================
% Maximum lag reduced from 36 to 16 to keep the same time span (~4
% years) as the monthly version, where 36 monthly lags = 36 months.

gpr_data = [master.gpr_n, master.gpt_n, master.gpa_n];
valid = all(~isnan(gpr_data),2);
gpr_data = gpr_data(valid,:);

max_lag = 16;
ACF = []; PACF = [];
for i = 1:3
    [ACF(:,i), L] = simple_acf(gpr_data(:,i), max_lag);
    [PACF(:,i), L] = simple_pacf(gpr_data(:,i), max_lag);
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
    xlabel('Lag (quarters)')
    box on; grid on
end
saveas(gcf, fullfile(out_dir, 'fig04a_acf_pacf.png'));

figure('Position',[100 100 1200 350])
for i = 1:3
    subplot(1,3,i)
    plot(L, ACF(:,i), 'LineWidth', 1.5, 'Color', series_colors{i})
    title(name_title{i}, 'FontSize', 11)
    xlabel('Lag (quarters)'); ylabel('ACF')
    xlim([0 max_lag])
    set(gca, 'FontSize', 9)
    box on; grid on
end
saveas(gcf, fullfile(out_dir, 'fig04b_acf_only.png'));

innov_data = [master.gpr_innov, master.gpt_innov, master.gpa_innov];
valid_innov = all(~isnan(innov_data),2);
innov_data = innov_data(valid_innov,:);

ACF_innov = [];
for i = 1:3
    [ACF_innov(:,i), L] = simple_acf(innov_data(:,i), max_lag);
end

figure('Position',[100 100 1200 350])
for i = 1:3
    subplot(1,3,i)
    plot(L, ACF_innov(:,i), 'LineWidth', 1.5, 'Color', series_colors{i})
    yline(0, 'k--');
    title([name_title{i} ' innovation'], 'FontSize', 11)
    xlabel('Lag (quarters)'); ylabel('ACF')
    xlim([0 max_lag])
    ylim([-0.4 0.4])
    set(gca, 'FontSize', 9)
    box on; grid on
end
sgtitle('AR(1) innovation ACFs — diagnostic for LP shock (quarterly)')
saveas(gcf, fullfile(out_dir, 'fig04c_acf_innovation.png'));

% =======================================================================
% ADL ANALYSIS — uses LEVEL GPR as the shock (QUARTERLY)
% =======================================================================
% Horizon set to 12 quarters (= 3 years) to match the monthly analysis
% in time-span units. Endogenous lag candidates capped at 8 quarters
% (= 2 years), which is standard for quarterly macro VAR/ADL.

fprintf('\n==============================\n');
fprintf('  STARTING ADL ANALYSIS (level GPR shocks, quarterly)\n');
fprintf('==============================\n\n');

H = 12;                  % quarters: 3-year horizon, matches monthly (36 months)
J = H;
alpha = 0.90;
N_B = 1000;
mindelay = 0;
trend = 0;
I_candidates = 1:8;      % up to 2 years of endogenous lags
IC = 0;

y_ip = master.dlog_ip;
y_pi = master.infl;

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
% LP ANALYSIS — uses AR(1)-INNOVATION GPR as the shock (QUARTERLY)
% =======================================================================
% Lag length I=4 (one year) is the standard quarterly choice. Innovation
% is already orthogonal to its own past so J=0 (no lagged shock terms
% in the right-hand side beyond what the controls absorb).

fprintf('\n==============================\n');
fprintf('  STARTING LP ANALYSIS (AR(1) innovation shocks, quarterly)\n');
fprintf('==============================\n\n');

H = 12;
I = 4;
J = 0;
Jflag = 0;
alpha = 0.90;
trend = 1;
IC = 0;
L_NW = -1;

y_ip = master.log_ip;
y_pi = master.log_cpi;

shock_field_map_lp = {'gpr_innov', 'gpt_innov', 'gpa_innov'};

lp_specs = {struct('name', 'baseline', 'controls', []), ...
            struct('name', 'robust1', 'controls', {{'unrate_level'}}), ...
            struct('name', 'robust2', 'controls', {{'unrate_level', 'log_vix'}})};

lp_params = struct('I', I, 'J', J, 'Jflag', Jflag, 'H', H, 'alpha', alpha, ...
                   'trend', trend, 'IC', IC, 'L_NW', L_NW);

lp_results = run_analysis('LP', y_ip, y_pi, shock_field_map_lp, shock_names, master, lp_specs, lp_params);

plot_impulse_responses(lp_results, shock_names, shock_colors, spec_names, 'LP', x, out_dir, 'fig06', 'AR(1) innovation shock');

% =======================================================================
% ADL vs LP COMPARISON (QUARTERLY)
% =======================================================================

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
    yline(0, 'k-'); title([shock_names{s} ' -> IP']); xlabel('h (quarters)'); ylabel('response'); grid on; box on;

    panel = panel + 1;
    subplot(3,2,panel); hold on;
    scale_adl = adl_results.baseline.(shock_names{s}).pi.shock.std;
    scale_lp = lp_results.baseline.(shock_names{s}).pi.shock.std;
    imp_adl = adl_results.baseline.(shock_names{s}).pi.imp * scale_adl;
    imp_lp = lp_results.baseline.(shock_names{s}).pi.imp * scale_lp;
    h1 = plot(x, imp_adl, '-', 'Color', shock_colors{s}, 'LineWidth', 2.4);
    h2 = plot(x, imp_lp, '--', 'Color', [0 0 0], 'LineWidth', 2.0);
    yline(0, 'k-'); title([shock_names{s} ' -> Inflation']); xlabel('h (quarters)'); ylabel('response'); grid on; box on;
end
lgd = legend([h1 h2], {'ADL (level shock)','LP (innovation shock)'}, 'Orientation', 'horizontal');
lgd.Position = [0.35 0.02 0.3 0.03];
sgtitle('ADL vs LP Comparison — Quarterly (Baseline, 1-s.d. shock)');
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
    yline(0, 'k-'); title([shock_names{s} ' -> IP']); xlabel('h (quarters)'); ylabel('response'); grid on; box on;

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
    yline(0, 'k-'); title([shock_names{s} ' -> Inflation']); xlabel('h (quarters)'); ylabel('response'); grid on; box on;
end
lgd = legend([h1 h2], {'ADL (level shock)','LP (innovation shock)'}, 'Orientation', 'horizontal');
lgd.Position = [0.35 0.02 0.3 0.03];
sgtitle('ADL vs LP Comparison with LP CI — Quarterly (Baseline, 1-s.d. shock)');
saveas(gcf, fullfile(out_dir, 'fig07b_adl_vs_lp_with_ci.png'));

% =======================================================================
% COMPLETION SUMMARY
% =======================================================================

fprintf('\n==============================\n');
fprintf('  Q_PART1 ANALYSIS COMPLETE\n');
fprintf('==============================\n\n');
fprintf('Generated figures in: %s\n', out_dir);
fprintf('  Fig 1: GPR/GPT/GPA quarterly time series with event windows\n');
fprintf('  Fig 2: Macro variables (quarterly)\n');
fprintf('  Fig 3: Correlation matrix (quarterly)\n');
fprintf('  Fig 4a/4b: ACF/PACF of quarterly GPR levels\n');
fprintf('  Fig 4c: ACF of quarterly AR(1) innovations (diagnostic)\n');
fprintf('  Fig 5a-5d: ADL impulse responses (quarterly, level GPR shock)\n');
fprintf('  Fig 6a-6d: LP impulse responses (quarterly, AR(1) innovation shock)\n');
fprintf('  Fig 7a-7b: ADL (level) vs LP (innovation) comparisons\n');
fprintf('\nQuarterly sample: %d quarters | results stored in adl_results, lp_results.\n', length(master.date));
