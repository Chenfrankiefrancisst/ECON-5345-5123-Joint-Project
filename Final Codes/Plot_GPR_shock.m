%% =======================================================================
% plot_z_shocks.m
% ------------------------------------------------------------------------
% Plot z_t (standardized GPR shocks) for face-validity inspection.
% Reads GPR_shock_output/gpr_shocks.csv and overlays known geopolitical
% events as vertical reference lines.
%
% Output:
%   GPR_shock_output/z_shocks_timeseries.png
%   GPR_shock_output/z_shocks_timeseries.fig
%% =======================================================================

clear; clc; close all;

shocks_csv = 'GPR_shock_output/gpr_shocks.csv';
shock_ids  = {'World', 'GPT', 'GPA'};
shock_lbls = {'World GPR shock', 'GP Threats shock', 'GP Acts shock'};

%% Load shocks + parse Quarter to datetime
T = readtable(shocks_csv, 'VariableNamingRule', 'preserve');
q   = string(T.Quarter);
yr  = double(extractBefore(q, 'Q'));
qtr = double(extractAfter(q, 'Q'));
dt  = datetime(yr, (qtr-1)*3 + 2, 15);   % mid-quarter date

%% Known geopolitical events (face-validity check)
events = { ...
    datetime(1990, 8, 2),  'Iraq-Kuwait';
    datetime(2001, 9,11),  '9/11';
    datetime(2003, 3,20),  'Iraq War';
    datetime(2014, 3, 1),  'Crimea';
    datetime(2022, 2,24),  'Ukraine';
    datetime(2023,10, 7),  'Israel-Hamas'};

%% Plot: one panel per shock, w/ oil vs w/o oil overlaid
fig = figure('Position', [80 80 1300 800]);

for s = 1:3
    subplot(3,1,s); hold on; box on; grid on;

    % Event vertical lines + labels (hidden from legend)
    for e = 1:size(events,1)
        xline(events{e,1}, ':', events{e,2}, ...
              'Color', [0.55 0.55 0.55], 'LineWidth', 0.7, ...
              'FontSize', 8, 'LabelVerticalAlignment', 'top', ...
              'HandleVisibility', 'off');
    end

    % Zero + +/-2 s.d. reference lines (hidden from legend)
    yline(0,  'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
    yline( 2, 'k:', 'LineWidth', 0.4, 'HandleVisibility', 'off');
    yline(-2, 'k:', 'LineWidth', 0.4, 'HandleVisibility', 'off');

    % Shock series (w/ oil vs w/o oil)
    plot(dt, T.([shock_ids{s} '_with_oil']),    '-',  ...
         'Color', [0.10 0.30 0.75], 'LineWidth', 1.4, 'DisplayName', 'w/ oil');
    plot(dt, T.([shock_ids{s} '_without_oil']), '--', ...
         'Color', [0.85 0.20 0.15], 'LineWidth', 1.2, 'DisplayName', 'w/o oil');

    title(shock_lbls{s}, 'FontSize', 11);
    ylabel('z_t (s.d.)');
    if s == 3, xlabel('Quarter'); end
    if s == 1, legend('Location', 'northwest', 'FontSize', 9); end
end

sgtitle('Standardized GPR shocks z_t : w/ oil vs w/o oil with key events', ...
        'FontSize', 13, 'FontWeight', 'bold');

%% Save
out = 'GPR_shock_output';
if ~exist(out, 'dir'), mkdir(out); end
exportgraphics(fig, fullfile(out, 'z_shocks_timeseries.png'), 'Resolution', 200);
savefig(fig,        fullfile(out, 'z_shocks_timeseries.fig'));
fprintf('Saved: %s/z_shocks_timeseries.{png,fig}\n', out);
