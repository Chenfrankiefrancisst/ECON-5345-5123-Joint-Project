clear
clc
close all
warning('off','all')

load("h1_baseline.mat");

% --- Figure output directory ---
out_dir = fullfile(pwd, 'figures');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
fprintf('Figures will be saved to: %s\n', out_dir);

%% 0. data trimming

% ------------------------------------------------------------------------
% ADF unit root tests (pre-transformation, full available sample).
%
% Purpose: verify the integration order of each analysis variable so that
% the LP/ADL transformations are justified:
%   - Level-LP LHS (log(IP), log(CPI)) assumes the series is I(1).
%   - Growth-rate ADL LHS (dlog_ip, infl) assumes the first difference is I(0).
%   - log(VIX) is used as a level control; must be I(0) or borderline.
%
% Implementation: a manual ADF regression in manual_adf.m (no Econometrics
% Toolbox required). Regression: Delta x_t = a + rho * x_{t-1} +
% sum phi_j * Delta x_{t-j} + e_t with n_lags=12 monthly augmentation
% terms and a constant. Reject unit root when t(rho) < 1% critical value
% (-3.44 for T ~ 500; MacKinnon 1996). Integration order is flagged as
%   I(0) if the level test rejects,
%   I(1) if the level test fails to reject but the 1st-difference test rejects,
%   I(2)? otherwise (would invalidate the LP specification).
%
% Runs on full pre-trim master so that series with long histories
% (INDPRO since 1919, CPI since 1947) exploit maximum sample size.
% ------------------------------------------------------------------------
fprintf('\n==============================\n');
fprintf('  ADF UNIT ROOT TESTS\n');
fprintf('==============================\n\n');

adf_series = {
    'log(GPR)',  log(master.GPR)
    'log(GPT)',  log(master.GPT)
    'log(GPA)',  log(master.GPA)
    'log(IP)',   log(master.INDPRO)
    'log(CPI)',  log(master.CPI)
    'log(WTI)',  log(master.WTI)
    'log(VIX)',  log(master.VIX)
    'UNRATE',    master.UNRATE
    'FFR',       master.FFR
};

n_lags_adf = 12;        % monthly data: 12 augmentation lags
cv_1pct    = -3.44;     % approximate 1% critical value, ADF with constant, T ~ 500

fprintf('%-12s  %10s %10s | %10s %10s   %s\n', ...
        'Variable', 'Level t', '1% CV', '1st-diff t', '1% CV', 'Order');
fprintf('%s\n', repmat('-', 1, 72));

for i = 1:size(adf_series, 1)
    name = adf_series{i, 1};
    x    = adf_series{i, 2};
    x    = x(~isnan(x));

    t_lev = manual_adf(x,        n_lags_adf);   % test on level
    t_dif = manual_adf(diff(x),  n_lags_adf);   % test on 1st diff

    if     t_lev < cv_1pct, order = 'I(0)';
    elseif t_dif < cv_1pct, order = 'I(1)';
    else,                   order = 'I(2)?';
    end

    fprintf('%-12s  %10.3f %10.3f | %10.3f %10.3f   %s\n', ...
            name, t_lev, cv_1pct, t_dif, cv_1pct, order);
end
fprintf('\n');

% ------------------------------------------------------------------------
% Sample period: 1990:01 - 2025:12 (unified across ALL specifications).
% Rationale: VIX (VIXCLS, FRED) only starts in 1990:01. Since Robustness 2
% adds log(VIX) as a control, we would lose 1985-1989 for that spec only,
% breaking apples-to-apples comparison across Baseline / R1 / R2. We trim
% the whole sample to 1990:01+ so that all three LP specifications are
% estimated on an identical time window (T ~ 432 months).
% ------------------------------------------------------------------------
sample_start = datetime(1990,1,1);
sample_end   = datetime(2025,12,31);
mask = master.date >= sample_start & master.date <= sample_end;
master = master(mask, :);
fprintf('Sample trimmed to %s - %s (%d months)\n', ...
    datestr(master.date(1)), datestr(master.date(end)), height(master));

% GPR normalized levels
master.gpr_n = 100 * log(100 * master.GPR);
master.gpt_n = 100 * log(100 * master.GPT);
master.gpa_n = 100 * log(100 * master.GPA);

% ------------------------------------------------------------------------
% Macro outcome variables: both log-level and log-difference are stored.
%   log_*  : used as LHS for the LP (ir_jorda with level=0 forms the
%            cumulative difference y(+h) - y(-1) internally, so passing
%            the log-level yields a LEVEL impulse response in log-points,
%            matching Caldara & Iacoviello (2022) and the Overleaf writeup).
%   dlog_* : used as LHS for the ADL (ir_ADL with level=0 expects first
%            differences and cumulates IRF internally) and for descriptive
%            plots / summary stats.
% ------------------------------------------------------------------------
master.log_ip   = 100 * log(master.INDPRO);                 % log-level (x100, log-points)
master.log_cpi  = 100 * log(master.CPI);                    % log-level (x100, log-points)
master.log_wti  = 100 * log(master.WTI);                    % log-level
master.dlog_ip  = [NaN; 100 * diff(log(master.INDPRO))];    % monthly IP growth (%)
master.infl     = [NaN; 100 * diff(log(master.CPI))];       % monthly inflation (%)
master.dlog_wti = [NaN; 100 * diff(log(master.WTI))];       % monthly WTI growth (%)

% Levels
master.ffr_level    = master.FFR;                           % level
master.unrate_level = master.UNRATE;                        % level

% ------------------------------------------------------------------------
% VIX enters as a Robustness-2 CONTROL (confounder, not outcome).
% Use log(VIX) in level, NOT dlog(VIX):
%   - VIX is stationary / borderline I(0) (ADF rejects unit root on log VIX).
%   - As a confounder, we want to absorb the LEVEL of financial uncertainty
%     (persistent high-uncertainty regimes: 2008, 2020). First-differencing
%     discards that level information and removes only month-on-month changes.
%   - Matches Caldara & Iacoviello (2022, AER Table 3) and Baker-Bloom-Davis
%     (2016, QJE), both of which use log(VIX) as a level control.
% dlog_vix is retained only for descriptive plots / summary stats.
% ------------------------------------------------------------------------
master.log_vix  = 100 * log(master.VIX);                    % log-level VIX (preferred control)
master.dlog_vix = [NaN; 100 * diff(log(master.VIX))];       % monthly VIX growth (%) - descriptive only

%% 1. Summary statistics
vars   = {'gpr_n','gpt_n','gpa_n','dlog_ip','infl','ffr_level','dlog_wti','dlog_vix','unrate_level'};
labels = {'GPR','GPT','GPA','IP growth','Inflation','FFR','WTI growth','VIX growth','Unrate'};

fprintf('\n==============================\n');
fprintf('SUMMARY STATISTICS\n');
fprintf('==============================\n\n');

fprintf('%-12s %10s %10s %10s %10s %10s %10s %10s\n', ...
    'Variable','Mean','Std','Min','Max','Skew','Kurt','N');
fprintf('%s\n', repmat('-',1,95));

for i = 1:length(vars)
    x = master.(vars{i});
    x = x(~isnan(x));

    fprintf('%-12s %10.3f %10.3f %10.3f %10.3f %10.3f %10.3f %10d\n', ...
        labels{i}, mean(x), std(x), min(x), max(x), skewness(x), kurtosis(x), length(x));
end

% table
stats = nan(length(vars), 7);

for i = 1:length(vars)
    x = master.(vars{i});
    x = x(~isnan(x));

    stats(i,1) = mean(x);
    stats(i,2) = std(x);
    stats(i,3) = min(x);
    stats(i,4) = max(x);
    stats(i,5) = skewness(x);
    stats(i,6) = kurtosis(x);
    stats(i,7) = length(x);
end

summary_table = array2table(stats, ...
    'VariableNames', {'Mean','Std','Min','Max','Skewness','Kurtosis','N'}, ...
    'RowNames', labels);

disp(summary_table)

%% 2-1. Basic time-series plots (GPR, GPT, GPA): I use raw index data for narrations

% Event windows
event_starts = [datetime(1990,8,1), datetime(2001,9,1), datetime(2003,3,1), datetime(2022,2,1)];
event_ends   = [datetime(1991,2,28), datetime(2001,9,30), datetime(2003,5,31), datetime(2022,12,31)];

figure;

series_list = {'GPR','GPT','GPA'};
series_titles = {'GPR', 'GPT', 'GPA'};
series_colors = {
    [0.85 0.33 0.10]
    [0.00 0.45 0.74]
    [0.47 0.67 0.19]
};

for s = 1:3
    subplot(3,1,s)

    x = master.(series_list{s});

    y_min = 0;
    y_max = max(x, [], 'omitnan') * 1.10;

    hold on
    for i = 1:length(event_starts)
        patch([event_starts(i) event_ends(i) event_ends(i) event_starts(i)], ...
              [y_min y_min y_max y_max], ...
              [0.70 0.70 0.70], ...
              'EdgeColor', 'none', ...
              'FaceAlpha', 0.55);
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

    if s == 3
        xlabel('Year')
    end
end

saveas(gcf, fullfile(out_dir, 'fig01_gpr_gpt_gpa_timeseries.png'));

%% 2-2. Macro variables (do not need to show)

figure;

% 1. Industrial Production Growth
subplot(3,2,1)
plot(master.date, master.dlog_ip, 'LineWidth', 1.2, 'Color', [0.00 0.45 0.74]);
title('Industrial Production Growth');
xlabel('Year');
ylabel('Percent');
xticks(datetime(1990,1,1):calyears(5):datetime(2025,1,1));
xtickformat('yyyy');
grid on;

% 2. Inflation
subplot(3,2,2)
plot(master.date, master.infl, 'LineWidth', 1.2, 'Color', [0.85 0.33 0.10]);
title('Inflation');
xlabel('Year');
ylabel('Percent');
xticks(datetime(1990,1,1):calyears(5):datetime(2025,1,1));
xtickformat('yyyy');
grid on;

% 3. Federal Funds Rate
subplot(3,2,3)
plot(master.date, master.ffr_level, 'LineWidth', 1.2, 'Color', [0.47 0.67 0.19]);
title('Federal Funds Rate');
xlabel('Year');
ylabel('Percent');
xticks(datetime(1990,1,1):calyears(5):datetime(2025,1,1));
xtickformat('yyyy');
grid on;

% 4. WTI Oil Price Growth
subplot(3,2,4)
plot(master.date, master.dlog_wti, 'LineWidth', 1.2, 'Color', [0.49 0.18 0.56]);
title('WTI Oil Price Growth');
xlabel('Year');
ylabel('Percent');
xticks(datetime(1990,1,1):calyears(5):datetime(2025,1,1));
xtickformat('yyyy');
grid on;

% 5. VIX Growth
subplot(3,2,5)
plot(master.date, master.dlog_vix, 'LineWidth', 1.2, 'Color', [0.64 0.08 0.18]);
title('VIX Growth');
xlabel('Year');
ylabel('Percent');
xticks(datetime(1990,1,1):calyears(5):datetime(2025,1,1));
xtickformat('yyyy');
grid on;

saveas(gcf, fullfile(out_dir, 'fig02_macro_variables.png'));

%% 3. Correlation matrix

corr_vars   = {'gpr_n','gpt_n','gpa_n','dlog_ip','infl','ffr_level','dlog_wti','dlog_vix','unrate_level'};
corr_labels = {'GPR','GPT','GPA','IP growth','Inflation','FFR','WTI growth','VIX growth','Unrate'};

X = [];
for i = 1:length(corr_vars)
    X = [X master.(corr_vars{i})];
end

valid = all(~isnan(X),2);
C = corrcoef(X(valid,:));

disp('Correlation matrix:')
disp(array2table(C, 'VariableNames', corr_labels, 'RowNames', corr_labels))

% make colours
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

set(gca, 'XTick', 1:length(corr_labels));
set(gca, 'YTick', 1:length(corr_labels));
set(gca, 'XTickLabel', corr_labels);
set(gca, 'YTickLabel', corr_labels);

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
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 9, ...
            'Color', txt_color);
    end
end

% The correlation matrix shows that the three geopolitical risk measures are highly correlated with each other, especially between the headline index and its threat and act components. By contrast, their contemporaneous correlations with macro-financial variables are generally modest, suggesting that the transmission of geopolitical risk is likely to operate through dynamic responses rather than strong contemporaneous comovement. Among macro variables, inflation and oil-price growth display a relatively strong positive correlation, while the federal funds rate is negatively correlated with unemployment.

saveas(gcf, fullfile(out_dir, 'fig03_correlation_matrix.png'));

%% 4-1. ACF / PACF: show persistence difference among GPR / GPT / GPA
% variables for ACF / PACF : I think it's better to put on Appendix if needed
gpr = master.gpr_n;
gpt = master.gpt_n;
gpa = master.gpa_n;

DATA = [gpr, gpt, gpa];

% remove missing rows if any
valid = all(~isnan(DATA),2);
DATA = DATA(valid,:);

disp(DATA(1:5,:))

ACF = [];
PACF = [];

for i = 1:3
    [ACF(:,i), L]  = simple_acf(DATA(:,i), 36);
    [PACF(:,i), L] = simple_pacf(DATA(:,i), 36);
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
    box on
    grid on
end

saveas(gcf, fullfile(out_dir, 'fig04a_acf_pacf.png'));

%% 4-2. Autocorrelation of GPR / GPT / GPA : It is better to show each persistence

gpr = master.gpr_n;
gpt = master.gpt_n;
gpa = master.gpa_n;

DATA = [gpr, gpt, gpa];

% remove missing rows if any
valid = all(~isnan(DATA),2);
DATA = DATA(valid,:);

ACF = [];

series_colors = {
    [0.85 0.33 0.10]   % GPR: orange
    [0.00 0.45 0.74]   % GPT: blue
    [0.47 0.67 0.19]   % GPA: green
};

name_title = {'GPR', 'GPT', 'GPA'};

% compute ACF up to 36 lags
for i = 1:3
    [ACF(:,i), L] = simple_acf(DATA(:,i), 36);
end

% plot
figure('Position',[100 100 1200 350])

for i = 1:3
    subplot(1,3,i)
    plot(L, ACF(:,i), 'LineWidth', 1.5, 'Color', series_colors{i})
    title(name_title{i}, 'FontSize', 11)
    xlabel('Lag')
    ylabel('ACF')
    xlim([0 36])
    set(gca, 'FontSize', 9)
    box on
    grid on
end

saveas(gcf, fullfile(out_dir, 'fig04b_acf_only.png'));

%% 5. ADL: Before using LP, I run ADL using Baek and Lee (2022) codes
% required codes: ir_ADL.m, adltoma.m, lrv_nw.m

%% 5-1. ADL: shock(GPR/GPT/GPA) to industry production and CPI (Baseline)

% setting
H = 36;                     % max horizon
J = H;                     % lagged shocks
alpha = 0.90;               % 90% confidence band
N_B = 1000;                 % Monte Carlo size
mindelay = 0;               % contemporaneous response allowed
trend = 0;                  % constant only
I_candidates = 1:12;        % endogenous lag candidates
IC = 0;                     

y_ip = master.dlog_ip;      % IP growth
y_pi = master.infl;         % inflation

shock_vars   = {'gpr_n','gpt_n','gpa_n'};
shock_names  = {'GPR','GPT','GPA'};

% Storage
adl_results = struct();

for s = 1:3
    
    shock = master.(shock_vars{s});
    X = shock;   % first column = shock, no controls
    
    % common valid sample
    valid = ~isnan(y_ip) & ~isnan(y_pi) & ~isnan(X);
    
    y_ip_s = y_ip(valid);
    y_pi_s = y_pi(valid);
    X_s    = X(valid,:);
    
    % IP response
    [imp_ip, cb_ip, shock_ip, lag_ip, adlcoef_ip] = ...
        ir_ADL(y_ip_s, X_s, I_candidates, J, 0, H, alpha, N_B, mindelay, IC, trend);
    
    % Inflation response
    [imp_pi, cb_pi, shock_pi, lag_pi, adlcoef_pi] = ...
        ir_ADL(y_pi_s, X_s, I_candidates, J, 0, H, alpha, N_B, mindelay, IC, trend);
    
    % (i) select proper A and B
    disp(lag_ip)    
    disp(lag_pi)
    
    % proper A and B for dy: A=36, B=2, IC=BIC
    % proper A and B for pi: A=36, B=3, IC=BIC

    % save
    adl_results.baseline.(shock_names{s}).ip.imp      = imp_ip;
    adl_results.baseline.(shock_names{s}).ip.cb       = cb_ip;
    adl_results.baseline.(shock_names{s}).ip.shock    = shock_ip;
    adl_results.baseline.(shock_names{s}).ip.lag      = lag_ip;
    adl_results.baseline.(shock_names{s}).ip.adlcoef  = adlcoef_ip;
    
    adl_results.baseline.(shock_names{s}).pi.imp      = imp_pi;
    adl_results.baseline.(shock_names{s}).pi.cb       = cb_pi;
    adl_results.baseline.(shock_names{s}).pi.shock    = shock_pi;
    adl_results.baseline.(shock_names{s}).pi.lag      = lag_pi;
    adl_results.baseline.(shock_names{s}).pi.adlcoef  = adlcoef_pi;
    
    fprintf('\n=== %s baseline ADL complete ===\n', shock_names{s});
    fprintf('IP selected I = %d, J = %d\n', lag_ip.I, lag_ip.J);
    fprintf('Inflation selected I = %d, J = %d\n', lag_pi.I, lag_pi.J);
end

% Plot baseline ADL IRFs
figure('Position',[100 100 1200 900]);

x = 0:H;
shock_colors = {
    [0.85 0.33 0.10]   % GPR
    [0.00 0.45 0.74]   % GPT
    [0.47 0.67 0.19]   % GPA
};

panel = 0;
for s = 1:3
    
    % ---------- IP ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = adl_results.baseline.(shock_names{s}).ip.shock.std;   % 1-s.d. shock
    imp = adl_results.baseline.(shock_names{s}).ip.imp * scale;
    cb  = adl_results.baseline.(shock_names{s}).ip.cb' * scale;
    
    fill([x fliplr(x)], [cb(1,:) fliplr(cb(2,:))], ...
        shock_colors{s}, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2);
    yline(0, 'k-');
    title([shock_names{s} ' -> IP (1-s.d. shock)']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
    
    % ---------- Inflation ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = adl_results.baseline.(shock_names{s}).pi.shock.std;   % same shock std
    imp = adl_results.baseline.(shock_names{s}).pi.imp * scale;
    cb  = adl_results.baseline.(shock_names{s}).pi.cb' * scale;
    
    fill([x fliplr(x)], [cb(1,:) fliplr(cb(2,:))], ...
        shock_colors{s}, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2);
    yline(0, 'k-');
    title([shock_names{s} ' -> Inflation (1-s.d. shock)']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
end

sgtitle('Baseline ADL: GPR / GPT / GPA shocks (1-s.d. shock)');
saveas(gcf, fullfile(out_dir, 'fig05a_adl_baseline.png'));

%% 5-2. Robustness Check 1 (+UNRATE)

for s = 1:3
    
    shock = master.(shock_vars{s});
    X = [shock, master.unrate_level];   % shock + UNRATE
    
    valid = ~isnan(y_ip) & ~isnan(y_pi) & all(~isnan(X),2);
    
    y_ip_s = y_ip(valid);
    y_pi_s = y_pi(valid);
    X_s    = X(valid,:);
    
    % IP response
    [imp_ip, cb_ip, shock_ip, lag_ip, adlcoef_ip] = ...
        ir_ADL(y_ip_s, X_s, I_candidates, J, 0, H, alpha, N_B, mindelay, IC, trend);
    
    % Inflation response
    [imp_pi, cb_pi, shock_pi, lag_pi, adlcoef_pi] = ...
        ir_ADL(y_pi_s, X_s, I_candidates, J, 0, H, alpha, N_B, mindelay, IC, trend);
    
    % save
    adl_results.robust1.(shock_names{s}).ip.imp      = imp_ip;
    adl_results.robust1.(shock_names{s}).ip.cb       = cb_ip;
    adl_results.robust1.(shock_names{s}).ip.shock    = shock_ip;
    adl_results.robust1.(shock_names{s}).ip.lag      = lag_ip;
    adl_results.robust1.(shock_names{s}).ip.adlcoef  = adlcoef_ip;
    
    adl_results.robust1.(shock_names{s}).pi.imp      = imp_pi;
    adl_results.robust1.(shock_names{s}).pi.cb       = cb_pi;
    adl_results.robust1.(shock_names{s}).pi.shock    = shock_pi;
    adl_results.robust1.(shock_names{s}).pi.lag      = lag_pi;
    adl_results.robust1.(shock_names{s}).pi.adlcoef  = adlcoef_pi;
    
    fprintf('\n=== %s robustness 1 complete ===\n', shock_names{s});
    fprintf('IP selected I = %d, J = %d\n', lag_ip.I, lag_ip.J);
    fprintf('Inflation selected I = %d, J = %d\n', lag_pi.I, lag_pi.J);
end

% Plot (1-s.d. shock)

figure('Position',[100 100 1200 900]);

x = 0:H;
panel = 0;

for s = 1:3
    
    % ---------- IP ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = adl_results.robust1.(shock_names{s}).ip.shock.std;
    imp = adl_results.robust1.(shock_names{s}).ip.imp * scale;
    cb  = adl_results.robust1.(shock_names{s}).ip.cb' * scale;
    
    fill([x fliplr(x)], [cb(1,:) fliplr(cb(2,:))], ...
        shock_colors{s}, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2);
    yline(0, 'k-');
    title([shock_names{s} ' -> IP (+UNRATE)']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
    
    % ---------- Inflation ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = adl_results.robust1.(shock_names{s}).pi.shock.std;
    imp = adl_results.robust1.(shock_names{s}).pi.imp * scale;
    cb  = adl_results.robust1.(shock_names{s}).pi.cb' * scale;
    
    fill([x fliplr(x)], [cb(1,:) fliplr(cb(2,:))], ...
        shock_colors{s}, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2);
    yline(0, 'k-');
    title([shock_names{s} ' -> Inflation (+UNRATE)']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
end

sgtitle('ADL Robustness 1: + UNRATE (1-s.d. shock)');
saveas(gcf, fullfile(out_dir, 'fig05b_adl_robust1_unrate.png'));

%% 5-3. Robustness 2 (+ UNRATE + log(VIX))
% VIX enters in LOG-LEVEL (stationary, captures persistent uncertainty regimes).
% See the transformation block at the top for the rationale.

for s = 1:3

    shock = master.(shock_vars{s});
    X = [shock, master.unrate_level, master.log_vix];   % shock + UNRATE + log(VIX)
    
    valid = ~isnan(y_ip) & ~isnan(y_pi) & all(~isnan(X),2);
    
    y_ip_s = y_ip(valid);
    y_pi_s = y_pi(valid);
    X_s    = X(valid,:);
    
    % IP response
    [imp_ip, cb_ip, shock_ip, lag_ip, adlcoef_ip] = ...
        ir_ADL(y_ip_s, X_s, I_candidates, J, 0, H, alpha, N_B, mindelay, IC, trend);
    
    % Inflation response
    [imp_pi, cb_pi, shock_pi, lag_pi, adlcoef_pi] = ...
        ir_ADL(y_pi_s, X_s, I_candidates, J, 0, H, alpha, N_B, mindelay, IC, trend);
    
    % save
    adl_results.robust2.(shock_names{s}).ip.imp      = imp_ip;
    adl_results.robust2.(shock_names{s}).ip.cb       = cb_ip;
    adl_results.robust2.(shock_names{s}).ip.shock    = shock_ip;
    adl_results.robust2.(shock_names{s}).ip.lag      = lag_ip;
    adl_results.robust2.(shock_names{s}).ip.adlcoef  = adlcoef_ip;
    
    adl_results.robust2.(shock_names{s}).pi.imp      = imp_pi;
    adl_results.robust2.(shock_names{s}).pi.cb       = cb_pi;
    adl_results.robust2.(shock_names{s}).pi.shock    = shock_pi;
    adl_results.robust2.(shock_names{s}).pi.lag      = lag_pi;
    adl_results.robust2.(shock_names{s}).pi.adlcoef  = adlcoef_pi;
    
    fprintf('\n=== %s robustness 2 complete ===\n', shock_names{s});
    fprintf('IP selected I = %d, J = %d\n', lag_ip.I, lag_ip.J);
    fprintf('Inflation selected I = %d, J = %d\n', lag_pi.I, lag_pi.J);
end

% Plot (1-s.d. shock)

figure('Position',[100 100 1200 900]);

x = 0:H;
panel = 0;

for s = 1:3
    
    % ---------- IP ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = adl_results.robust2.(shock_names{s}).ip.shock.std;
    imp = adl_results.robust2.(shock_names{s}).ip.imp * scale;
    cb  = adl_results.robust2.(shock_names{s}).ip.cb' * scale;
    
    fill([x fliplr(x)], [cb(1,:) fliplr(cb(2,:))], ...
        shock_colors{s}, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2);
    yline(0, 'k-');
    title([shock_names{s} ' -> IP (+UNRATE, +VIX)']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
    
    % ---------- Inflation ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = adl_results.robust2.(shock_names{s}).pi.shock.std;
    imp = adl_results.robust2.(shock_names{s}).pi.imp * scale;
    cb  = adl_results.robust2.(shock_names{s}).pi.cb' * scale;
    
    fill([x fliplr(x)], [cb(1,:) fliplr(cb(2,:))], ...
        shock_colors{s}, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2);
    yline(0, 'k-');
    title([shock_names{s} ' -> Inflation (+UNRATE, +VIX)']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
end

sgtitle('ADL Robustness 2: + UNRATE + log(VIX) (1-s.d. shock)');
saveas(gcf, fullfile(out_dir, 'fig05c_adl_robust2_unrate_vix.png'));

%% 5-4. Comparison overlay

figure('Position',[100 100 1200 900]);

x = 0:H;
spec_colors = {
    [0 0 0]          % baseline
    [0.4 0.4 0.4]    % robust1
    [0.7 0.7 0.7]    % robust2
};

panel = 0;
for s = 1:3
    
    % ---------- IP ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = adl_results.baseline.(shock_names{s}).ip.shock.std;
    
    imp0 = adl_results.baseline.(shock_names{s}).ip.imp * scale;
    imp1 = adl_results.robust1.(shock_names{s}).ip.imp * scale;
    imp2 = adl_results.robust2.(shock_names{s}).ip.imp * scale;
    
    plot(x, imp0, 'Color', spec_colors{1}, 'LineWidth', 2);
    plot(x, imp1, 'Color', spec_colors{2}, 'LineWidth', 2);
    plot(x, imp2, 'Color', spec_colors{3}, 'LineWidth', 2);
    yline(0, 'k-');
    title([shock_names{s} ' -> IP']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
    
    % ---------- Inflation ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = adl_results.baseline.(shock_names{s}).pi.shock.std;
    
    imp0 = adl_results.baseline.(shock_names{s}).pi.imp * scale;
    imp1 = adl_results.robust1.(shock_names{s}).pi.imp * scale;
    imp2 = adl_results.robust2.(shock_names{s}).pi.imp * scale;
    
    h1 = plot(x, imp0, '-',  'Color', [0 0 0],       'LineWidth', 2.2);   % baseline
    h2 = plot(x, imp1, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 2.0); % +UNRATE
    h3 = plot(x, imp2, '-.', 'Color', [0.65 0.65 0.65], 'LineWidth', 2.0); % +UNRATE+VIX
    yline(0, 'k-');
    title([shock_names{s} ' -> Inflation']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
end

lgd = legend([h1 h2 h3], {'Baseline','+UNRATE','+UNRATE+VIX'});
lgd.Orientation = 'horizontal';
lgd.Position = [0.35 0.02 0.3 0.03];

sgtitle('ADL Comparison: Baseline vs Robustness 1 vs Robustness 2');
saveas(gcf, fullfile(out_dir, 'fig05d_adl_comparison.png'));

%% 6. Local Projections: This is the main methodology for our proposal. It is also from Baek and Lee (2022).
% required codes: ir_jorda.m, lrv_nw.m

% settings
H      = 36;      % horizon
I      = 12;      % endogenous lags
J      = 0;       % only contemporaneous shock
Jflag  = 0;       % J applies only to shock, not controls
alpha  = 0.90;    % 90% confidence level
trend  = 1;       % linear trend
IC     = 0;       % BIC
L_NW   = -1;      % Stock-Watson rule

% ------------------------------------------------------------------------
% LP LHS: log-LEVEL (NOT first-difference). Rationale:
%   ir_jorda with level=0 constructs the regression internally as
%       y(t+h) - y(t-1) = trend + beta(L) * Delta y + gamma(L) * x + e
%   so passing y = log(IP) (or log(CPI)) makes the LHS the cumulative
%   log change log(y)_{t+h} - log(y)_{t-1}, which gives a LEVEL impulse
%   response in log-points. This is the Jorda (2005) convention for I(1)
%   outcomes and matches Caldara & Iacoviello (2022, AER) and the Overleaf
%   writeup. Passing dlog_ip here would double-difference (wrong).
%   Units: y is scaled x100, so IRF is in log-points x 100 (~ percent).
% ------------------------------------------------------------------------
y_ip = master.log_ip;     % log(IP) * 100 -> level IRF via internal y(+h)-y(-1)
y_pi = master.log_cpi;    % log(CPI) * 100 -> level IRF via internal y(+h)-y(-1)

shock_vars  = {'gpr_n','gpt_n','gpa_n'};
shock_names = {'GPR','GPT','GPA'};

lp_results = struct();

%% 6-1. Baseline LP: no controls
for s = 1:3
    
    shock = master.(shock_vars{s});
    X = shock;   % only shock
    
    valid = ~isnan(y_ip) & ~isnan(y_pi) & ~isnan(X);
    
    y_ip_s = y_ip(valid);
    y_pi_s = y_pi(valid);
    X_s    = X(valid,:);
    
    % IP response
    [imp_ip, cb_ip, shock_ip, lag_ip, resid_ip, sd_ip] = ...
        ir_jorda(y_ip_s, X_s, I, J, Jflag, 0, H, alpha, trend, IC, L_NW);
    
    % Inflation response
    [imp_pi, cb_pi, shock_pi, lag_pi, resid_pi, sd_pi] = ...
        ir_jorda(y_pi_s, X_s, I, J, Jflag, 0, H, alpha, trend, IC, L_NW);
    
    % save
    lp_results.baseline.(shock_names{s}).ip.imp    = imp_ip;
    lp_results.baseline.(shock_names{s}).ip.cb     = cb_ip;
    lp_results.baseline.(shock_names{s}).ip.shock  = shock_ip;
    lp_results.baseline.(shock_names{s}).ip.lag    = lag_ip;
    lp_results.baseline.(shock_names{s}).ip.resid  = resid_ip;
    lp_results.baseline.(shock_names{s}).ip.sd     = sd_ip;
    
    lp_results.baseline.(shock_names{s}).pi.imp    = imp_pi;
    lp_results.baseline.(shock_names{s}).pi.cb     = cb_pi;
    lp_results.baseline.(shock_names{s}).pi.shock  = shock_pi;
    lp_results.baseline.(shock_names{s}).pi.lag    = lag_pi;
    lp_results.baseline.(shock_names{s}).pi.resid  = resid_pi;
    lp_results.baseline.(shock_names{s}).pi.sd     = sd_pi;
    
    fprintf('\n=== %s baseline LP complete ===\n', shock_names{s});
end

% Plot baseline LP IRFs (1-s.d. shock)

figure('Position',[100 100 1200 900]);
x = 0:H;

shock_colors = {
    [0.85 0.33 0.10]   % GPR
    [0.00 0.45 0.74]   % GPT
    [0.47 0.67 0.19]   % GPA
};

panel = 0;
for s = 1:3
    
    % ---------- IP ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = lp_results.baseline.(shock_names{s}).ip.shock.std;
    imp = lp_results.baseline.(shock_names{s}).ip.imp * scale;
    cb  = lp_results.baseline.(shock_names{s}).ip.cb * scale;
    
    fill([x fliplr(x)], [cb(:,1).' fliplr(cb(:,2).')], ...
         shock_colors{s}, 'EdgeColor','none', 'FaceAlpha',0.25);
    plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2.2);
    yline(0,'k-');
    grid on; box on;
    title([shock_names{s} ' -> IP (1-s.d. shock)']);
    xlabel('h (months)');
    ylabel('response');
    set(gca,'FontSize',11,'LineWidth',1.0);
    
    % ---------- Inflation ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = lp_results.baseline.(shock_names{s}).pi.shock.std;
    imp = lp_results.baseline.(shock_names{s}).pi.imp * scale;
    cb  = lp_results.baseline.(shock_names{s}).pi.cb * scale;
    
    fill([x fliplr(x)], [cb(:,1).' fliplr(cb(:,2).')], ...
         shock_colors{s}, 'EdgeColor','none', 'FaceAlpha',0.25);
    plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2.2);
    yline(0,'k-');
    grid on; box on;
    title([shock_names{s} ' -> Inflation (1-s.d. shock)']);
    xlabel('h (months)');
    ylabel('response');
    set(gca,'FontSize',11,'LineWidth',1.0);
end

sgtitle('Baseline LP: GPR / GPT / GPA shocks (1-s.d. shock)');
saveas(gcf, fullfile(out_dir, 'fig06a_lp_baseline.png'));

%% 6-2. Robustness 1 (+ UNRATE)

for s = 1:3
    
    shock = master.(shock_vars{s});
    X = [shock, master.unrate_level];   % shock + UNRATE
    
    valid = ~isnan(y_ip) & ~isnan(y_pi) & all(~isnan(X),2);
    
    y_ip_s = y_ip(valid);
    y_pi_s = y_pi(valid);
    X_s    = X(valid,:);
    
    % IP response
    [imp_ip, cb_ip, shock_ip, lag_ip, resid_ip, sd_ip] = ...
        ir_jorda(y_ip_s, X_s, I, J, Jflag, 0, H, alpha, trend, IC, L_NW);
    
    % Inflation response
    [imp_pi, cb_pi, shock_pi, lag_pi, resid_pi, sd_pi] = ...
        ir_jorda(y_pi_s, X_s, I, J, Jflag, 0, H, alpha, trend, IC, L_NW);
    
    % save
    lp_results.robust1.(shock_names{s}).ip.imp    = imp_ip;
    lp_results.robust1.(shock_names{s}).ip.cb     = cb_ip;
    lp_results.robust1.(shock_names{s}).ip.shock  = shock_ip;
    lp_results.robust1.(shock_names{s}).ip.lag    = lag_ip;
    lp_results.robust1.(shock_names{s}).ip.resid  = resid_ip;
    lp_results.robust1.(shock_names{s}).ip.sd     = sd_ip;
    
    lp_results.robust1.(shock_names{s}).pi.imp    = imp_pi;
    lp_results.robust1.(shock_names{s}).pi.cb     = cb_pi;
    lp_results.robust1.(shock_names{s}).pi.shock  = shock_pi;
    lp_results.robust1.(shock_names{s}).pi.lag    = lag_pi;
    lp_results.robust1.(shock_names{s}).pi.resid  = resid_pi;
    lp_results.robust1.(shock_names{s}).pi.sd     = sd_pi;
    
    fprintf('\n=== %s robustness 1 LP complete ===\n', shock_names{s});
end

% Plot robustness 1 LP IRFs (1-s.d. shock)

figure('Position',[100 100 1200 900]);
x = 0:H;
panel = 0;

for s = 1:3
    
    % ---------- IP ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = lp_results.robust1.(shock_names{s}).ip.shock.std;
    imp = lp_results.robust1.(shock_names{s}).ip.imp * scale;
    cb  = lp_results.robust1.(shock_names{s}).ip.cb * scale;
    
    fill([x fliplr(x)], [cb(:,1).' fliplr(cb(:,2).')], ...
         shock_colors{s}, 'EdgeColor','none', 'FaceAlpha',0.25);
    plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2.2);
    yline(0,'k-');
    grid on; box on;
    title([shock_names{s} ' -> IP (+UNRATE)']);
    xlabel('h (months)');
    ylabel('response');
    set(gca,'FontSize',11,'LineWidth',1.0);
    
    % ---------- Inflation ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = lp_results.robust1.(shock_names{s}).pi.shock.std;
    imp = lp_results.robust1.(shock_names{s}).pi.imp * scale;
    cb  = lp_results.robust1.(shock_names{s}).pi.cb * scale;
    
    fill([x fliplr(x)], [cb(:,1).' fliplr(cb(:,2).')], ...
         shock_colors{s}, 'EdgeColor','none', 'FaceAlpha',0.25);
    plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2.2);
    yline(0,'k-');
    grid on; box on;
    title([shock_names{s} ' -> Inflation (+UNRATE)']);
    xlabel('h (months)');
    ylabel('response');
    set(gca,'FontSize',11,'LineWidth',1.0);
end

sgtitle('LP Robustness 1: + UNRATE (1-s.d. shock)');
saveas(gcf, fullfile(out_dir, 'fig06b_lp_robust1_unrate.png'));

%% 6-3. Robustness 2 (+ UNRATE + log(VIX))
% VIX enters in LOG-LEVEL (stationary, captures persistent uncertainty regimes).
% See the transformation block at the top for the rationale.

for s = 1:3

    shock = master.(shock_vars{s});
    X = [shock, master.unrate_level, master.log_vix];   % shock + UNRATE + log(VIX)
    
    valid = ~isnan(y_ip) & ~isnan(y_pi) & all(~isnan(X),2);
    
    y_ip_s = y_ip(valid);
    y_pi_s = y_pi(valid);
    X_s    = X(valid,:);
    
    % IP response
    [imp_ip, cb_ip, shock_ip, lag_ip, resid_ip, sd_ip] = ...
        ir_jorda(y_ip_s, X_s, I, J, Jflag, 0, H, alpha, trend, IC, L_NW);
    
    % Inflation response
    [imp_pi, cb_pi, shock_pi, lag_pi, resid_pi, sd_pi] = ...
        ir_jorda(y_pi_s, X_s, I, J, Jflag, 0, H, alpha, trend, IC, L_NW);
    
    % save
    lp_results.robust2.(shock_names{s}).ip.imp    = imp_ip;
    lp_results.robust2.(shock_names{s}).ip.cb     = cb_ip;
    lp_results.robust2.(shock_names{s}).ip.shock  = shock_ip;
    lp_results.robust2.(shock_names{s}).ip.lag    = lag_ip;
    lp_results.robust2.(shock_names{s}).ip.resid  = resid_ip;
    lp_results.robust2.(shock_names{s}).ip.sd     = sd_ip;
    
    lp_results.robust2.(shock_names{s}).pi.imp    = imp_pi;
    lp_results.robust2.(shock_names{s}).pi.cb     = cb_pi;
    lp_results.robust2.(shock_names{s}).pi.shock  = shock_pi;
    lp_results.robust2.(shock_names{s}).pi.lag    = lag_pi;
    lp_results.robust2.(shock_names{s}).pi.resid  = resid_pi;
    lp_results.robust2.(shock_names{s}).pi.sd     = sd_pi;
    
    fprintf('\n=== %s robustness 2 LP complete ===\n', shock_names{s});
end


% Plot robustness 2 LP IRFs (1-s.d. shock)

figure('Position',[100 100 1200 900]);
x = 0:H;
panel = 0;

for s = 1:3
    
    % ---------- IP ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = lp_results.robust2.(shock_names{s}).ip.shock.std;
    imp = lp_results.robust2.(shock_names{s}).ip.imp * scale;
    cb  = lp_results.robust2.(shock_names{s}).ip.cb * scale;
    
    fill([x fliplr(x)], [cb(:,1).' fliplr(cb(:,2).')], ...
         shock_colors{s}, 'EdgeColor','none', 'FaceAlpha',0.25);
    plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2.2);
    yline(0,'k-');
    grid on; box on;
    title([shock_names{s} ' -> IP (+UNRATE,+VIX)']);
    xlabel('h (months)');
    ylabel('response');
    set(gca,'FontSize',11,'LineWidth',1.0);
    
    % ---------- Inflation ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = lp_results.robust2.(shock_names{s}).pi.shock.std;
    imp = lp_results.robust2.(shock_names{s}).pi.imp * scale;
    cb  = lp_results.robust2.(shock_names{s}).pi.cb * scale;
    
    fill([x fliplr(x)], [cb(:,1).' fliplr(cb(:,2).')], ...
         shock_colors{s}, 'EdgeColor','none', 'FaceAlpha',0.25);
    plot(x, imp, 'Color', shock_colors{s}, 'LineWidth', 2.2);
    yline(0,'k-');
    grid on; box on;
    title([shock_names{s} ' -> Inflation (+UNRATE,+VIX)']);
    xlabel('h (months)');
    ylabel('response');
    set(gca,'FontSize',11,'LineWidth',1.0);
end

sgtitle('LP Robustness 2: + UNRATE + log(VIX) (1-s.d. shock)');
saveas(gcf, fullfile(out_dir, 'fig06c_lp_robust2_unrate_vix.png'));

%% 6-4. LP Comparison overlay

figure('Position',[100 100 1200 900]);

x = 0:H;
panel = 0;

for s = 1:3
    
    % ---------- IP ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = lp_results.baseline.(shock_names{s}).ip.shock.std;
    
    imp0 = lp_results.baseline.(shock_names{s}).ip.imp * scale;
    imp1 = lp_results.robust1.(shock_names{s}).ip.imp * scale;
    imp2 = lp_results.robust2.(shock_names{s}).ip.imp * scale;
    
    h1 = plot(x, imp0, '-',  'Color', [0 0 0],          'LineWidth', 2.2);
    h2 = plot(x, imp1, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 2.0);
    h3 = plot(x, imp2, '-.', 'Color', [0.65 0.65 0.65], 'LineWidth', 2.0);
    yline(0, 'k-');
    title([shock_names{s} ' -> IP']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
    
    % ---------- Inflation ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale = lp_results.baseline.(shock_names{s}).pi.shock.std;
    
    imp0 = lp_results.baseline.(shock_names{s}).pi.imp * scale;
    imp1 = lp_results.robust1.(shock_names{s}).pi.imp * scale;
    imp2 = lp_results.robust2.(shock_names{s}).pi.imp * scale;
    
    h1 = plot(x, imp0, '-',  'Color', [0 0 0],          'LineWidth', 2.2);
    h2 = plot(x, imp1, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 2.0);
    h3 = plot(x, imp2, '-.', 'Color', [0.65 0.65 0.65], 'LineWidth', 2.0);
    yline(0, 'k-');
    title([shock_names{s} ' -> Inflation']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
end

lgd = legend([h1 h2 h3], {'Baseline','+UNRATE','+UNRATE+VIX'});
lgd.Orientation = 'horizontal';
lgd.Position = [0.35 0.02 0.3 0.03];

sgtitle('LP Comparison: Baseline vs Robustness 1 vs Robustness 2');
saveas(gcf, fullfile(out_dir, 'fig06d_lp_comparison.png'));


%% 7-1. ADL vs LP comparison overlay

figure('Position',[100 100 1200 900]);

x = 0:H;
panel = 0;

for s = 1:3
    
    % ---------- IP ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    % 1-s.d. scaling
    scale_adl = adl_results.baseline.(shock_names{s}).ip.shock.std;
    scale_lp  = lp_results.baseline.(shock_names{s}).ip.shock.std;
    
    imp_adl = adl_results.baseline.(shock_names{s}).ip.imp * scale_adl;
    imp_lp  = lp_results.baseline.(shock_names{s}).ip.imp * scale_lp;
    
    h1 = plot(x, imp_adl, '-',  'Color', shock_colors{s}, 'LineWidth', 2.4);
    h2 = plot(x, imp_lp,  '--', 'Color', [0 0 0],         'LineWidth', 2.0);
    
    yline(0, 'k-');
    title([shock_names{s} ' -> IP']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
    
    % ---------- Inflation ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale_adl = adl_results.baseline.(shock_names{s}).pi.shock.std;
    scale_lp  = lp_results.baseline.(shock_names{s}).pi.shock.std;
    
    imp_adl = adl_results.baseline.(shock_names{s}).pi.imp * scale_adl;
    imp_lp  = lp_results.baseline.(shock_names{s}).pi.imp * scale_lp;
    
    h1 = plot(x, imp_adl, '-',  'Color', shock_colors{s}, 'LineWidth', 2.4);
    h2 = plot(x, imp_lp,  '--', 'Color', [0 0 0],         'LineWidth', 2.0);
    
    yline(0, 'k-');
    title([shock_names{s} ' -> Inflation']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
end

lgd = legend([h1 h2], {'ADL','LP'});
lgd.Orientation = 'horizontal';
lgd.Position = [0.42 0.02 0.16 0.03];

sgtitle('ADL vs LP Comparison (Baseline, 1-s.d. shock)');
saveas(gcf, fullfile(out_dir, 'fig07a_adl_vs_lp.png'));


%% 7-2. ADL vs LP comparison with LP confidence band

figure('Position',[100 100 1200 900]);

x = 0:H;
panel = 0;

for s = 1:3
    
    % ---------- IP ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale_adl = adl_results.baseline.(shock_names{s}).ip.shock.std;
    scale_lp  = lp_results.baseline.(shock_names{s}).ip.shock.std;
    
    imp_adl = adl_results.baseline.(shock_names{s}).ip.imp * scale_adl;
    imp_lp  = lp_results.baseline.(shock_names{s}).ip.imp * scale_lp;
    cb_lp   = lp_results.baseline.(shock_names{s}).ip.cb  * scale_lp;
    
    fill([x fliplr(x)], [cb_lp(:,1).' fliplr(cb_lp(:,2).')], ...
         [0.8 0.8 0.8], 'EdgeColor','none', 'FaceAlpha',0.35);
    
    h1 = plot(x, imp_adl, '-',  'Color', shock_colors{s}, 'LineWidth', 2.4);
    h2 = plot(x, imp_lp,  '--', 'Color', [0 0 0],         'LineWidth', 2.0);
    
    yline(0, 'k-');
    title([shock_names{s} ' -> IP']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
    
    % ---------- Inflation ----------
    panel = panel + 1;
    subplot(3,2,panel); hold on;
    
    scale_adl = adl_results.baseline.(shock_names{s}).pi.shock.std;
    scale_lp  = lp_results.baseline.(shock_names{s}).pi.shock.std;
    
    imp_adl = adl_results.baseline.(shock_names{s}).pi.imp * scale_adl;
    imp_lp  = lp_results.baseline.(shock_names{s}).pi.imp * scale_lp;
    cb_lp   = lp_results.baseline.(shock_names{s}).pi.cb  * scale_lp;
    
    fill([x fliplr(x)], [cb_lp(:,1).' fliplr(cb_lp(:,2).')], ...
         [0.8 0.8 0.8], 'EdgeColor','none', 'FaceAlpha',0.35);
    
    h1 = plot(x, imp_adl, '-',  'Color', shock_colors{s}, 'LineWidth', 2.4);
    h2 = plot(x, imp_lp,  '--', 'Color', [0 0 0],         'LineWidth', 2.0);
    
    yline(0, 'k-');
    title([shock_names{s} ' -> Inflation']);
    xlabel('h');
    ylabel('response');
    grid on;
    box on;
end

lgd = legend([h1 h2], {'ADL','LP'});
lgd.Orientation = 'horizontal';
lgd.Position = [0.42 0.02 0.16 0.03];

sgtitle('ADL vs LP Comparison with LP Confidence Band (Baseline, 1-s.d. shock)');
saveas(gcf, fullfile(out_dir, 'fig07b_adl_vs_lp_with_ci.png'));

fprintf('\nAll %d figures saved to: %s\n', 15, out_dir);