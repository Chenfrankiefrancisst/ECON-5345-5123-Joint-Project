%% Part 2 Clean Version
% Local Projections using ir_jorda.m and lrv_nw.m
% Goal:
% 1. Use standardized AR(1) innovations from GPR, GPR Threat, and GPR Act
% 2. Estimate level LPs for candidate mechanism outcomes
% 3. Avoid embedded helper functions
%
% LP interpretation:
% y_{t+h} - y_{t-1} is the dependent variable
% Therefore, beta_h is already a level-change response.
% Do NOT cumulatively sum the IRF.
%
% required function codes: ir_jorda.m / lrv_nw.m (sourced by Baek and Lee (2022))

clear;
clc;
close all;

%% 1. Load data

DB = readtable('Q_Levels_Database.csv', 'VariableNamingRule', 'preserve');

T = height(DB);

fprintf('\nLoaded Q_Levels_Database.csv\n');
fprintf('Number of observations: %d\n', T);
fprintf('Variables available:\n');
disp(DB.Properties.VariableNames');

% settings
H      = 12;      % maximum horizon
L      = 4;       % maximum lag length
I      = 1:L;     % BIC chooses endogenous y lags
J      = 0;       % z_t only: no lagged GPR innovation
Jflag  = 1;       % align X(:,2:end) with shock date
level  = 1;       % y_{t+h} - y_{t-1}
alpha  = 0.90;    % confidence level
trend  = 0;       % constant only
IC     = 0;       % BIC
L_NW   = -1;      % Newey-West rule of thumb

save_figures = true;

fprintf('\n=== Part 2 Clean LP using ir_jorda.m ===\n');
fprintf('GPR innovations are extracted from AR(1) residuals.\n');
fprintf('LP y-lag candidates I = %s\n', mat2str(I));
fprintf('Shock lag J = %d\n', J);
fprintf('Number of lags for GPR levels and macro controls, L = %d\n', L);
fprintf('Horizon = 0:%d\n', H);
fprintf('Confidence level = %.2f\n', alpha);

%% 2. Load GPR variables
%% =======================================================================

LGPR  = DB.LGPR;
LGPRT = DB.LGPRT;
LGPRA = DB.LGPRA;

LGPR  = LGPR(:);
LGPRT = LGPRT(:);
LGPRA = LGPRA(:);

%% 3. Construct AR(1) innovations
% -----------------------------------------------------------------------
% World GPR innovation
% -----------------------------------------------------------------------

Y_ar = LGPR(2:end);
X_ar = [ones(T-1,1), LGPR(1:end-1)];

good = isfinite(Y_ar) & all(isfinite(X_ar), 2);

b_ar = X_ar(good,:) \ Y_ar(good);
resid_ar = Y_ar(good) - X_ar(good,:) * b_ar;

innov_world = nan(T,1);
temp_index = find(good) + 1;
innov_world(temp_index) = resid_ar;

z_world = (innov_world - mean(innov_world, 'omitnan')) ./ std(innov_world, 'omitnan');

R2_world = 1 - sum(resid_ar.^2) / sum((Y_ar(good) - mean(Y_ar(good))).^2);

% -----------------------------------------------------------------------
% Threat GPR innovation
% -----------------------------------------------------------------------

Y_ar = LGPRT(2:end);
X_ar = [ones(T-1,1), LGPRT(1:end-1)];

good = isfinite(Y_ar) & all(isfinite(X_ar), 2);

b_ar = X_ar(good,:) \ Y_ar(good);
resid_ar = Y_ar(good) - X_ar(good,:) * b_ar;

innov_threat = nan(T,1);
temp_index = find(good) + 1;
innov_threat(temp_index) = resid_ar;

z_threat = (innov_threat - mean(innov_threat, 'omitnan')) ./ std(innov_threat, 'omitnan');

R2_threat = 1 - sum(resid_ar.^2) / sum((Y_ar(good) - mean(Y_ar(good))).^2);

% -----------------------------------------------------------------------
% Act GPR innovation
% -----------------------------------------------------------------------

Y_ar = LGPRA(2:end);
X_ar = [ones(T-1,1), LGPRA(1:end-1)];

good = isfinite(Y_ar) & all(isfinite(X_ar), 2);

b_ar = X_ar(good,:) \ Y_ar(good);
resid_ar = Y_ar(good) - X_ar(good,:) * b_ar;

innov_act = nan(T,1);
temp_index = find(good) + 1;
innov_act(temp_index) = resid_ar;

z_act    = (innov_act    - mean(innov_act,    'omitnan')) ./ std(innov_act,    'omitnan');

R2_act = 1 - sum(resid_ar.^2) / sum((Y_ar(good) - mean(Y_ar(good))).^2);

fprintf('\n--- GPR innovation checks ---\n');
fprintf('World : finite z = %3d / %3d, AR(1) R2 = %.3f\n', sum(isfinite(z_world)), T, R2_world);
fprintf('Threat: finite z = %3d / %3d, AR(1) R2 = %.3f\n', sum(isfinite(z_threat)), T, R2_threat);
fprintf('Act   : finite z = %3d / %3d, AR(1) R2 = %.3f\n', sum(isfinite(z_act)), T, R2_act);

%% 4. Construct controls

% VIX is NOT included as a control.
% VIX is used as an outcome later.

controls = [DB.Unemp, DB.FFR];

controls = double(controls);

control_names = {'Unemp', 'FFR'};

fprintf('\nControls used in LP:\n');
for j = 1:numel(control_names)
    fprintf('  %s: finite = %3d / %3d\n', ...
        control_names{j}, sum(isfinite(controls(:,j))), T);
end

%% 5. Pre-lag GPR and controls manually

% Why manually?
% ir_jorda.m treats X(:,1) as the shock.
% To avoid lagged shocks and to include lagged GPR/control variables
% transparently, we construct the lagged controls ourselves.

LGPR_lags  = lagmatrix(LGPR,  1:L);
LGPRT_lags = lagmatrix(LGPRT, 1:L);
LGPRA_lags = lagmatrix(LGPRA, 1:L);

control_lags = lagmatrix(controls, 1:L);

%% 6. Define outcomes

% VIX outcome
lnVIX = log(max(DB.VOX, 1e-8));

outcome_ids = { ...
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

outcome_labels = { ...
    'Real WTI crude oil price', ...
    'Real gasoline price', ...
    'Michigan expected inflation', ...
    'SPF expected inflation (current)', ...
    'SPF expected inflation (2-step ahead)', ...
    'Real consumption level', ...
    'Real investment level', ...
    'Real GDP level', ...
    'log(VIX)' ...
};

%% 7. Estimate LPs

results = struct();

h = (0:H)';

fprintf('\n--- Estimating LPs using ir_jorda.m ---\n');

for i = 1:numel(outcome_ids)

    yid = outcome_ids{i};
    y_label = outcome_labels{i};

    if strcmp(yid, 'lnVIX')
        y = lnVIX;
    else
        y = DB.(yid);
    end

    y = y(:);

    fprintf('\nOutcome: %s\n', y_label);
    fprintf('  finite y = %3d / %3d\n', sum(isfinite(y)), T);

    % -------------------------------------------------------------------
    % World GPR shock
    % X first column = shock.
    % Other columns = manually pre-lagged GPR level and controls.
    % -------------------------------------------------------------------

    X_world = [z_world, LGPR_lags, control_lags];
    
    start_row = L + 1;
    
    y_w = y(start_row:end);
    X_world_use = X_world(start_row:end, :);
    
    [imp_w, cb_w, shock_w, lag_w, resid_w, sd_w] = ...
        ir_jorda(y_w, X_world_use, I, J, Jflag, level, H, alpha, trend, IC, L_NW);


    % -------------------------------------------------------------------
    % Threat GPR shock
    % -------------------------------------------------------------------

    X_threat = [z_threat, LGPRT_lags, control_lags];

    y_t = y(start_row:end);
    X_threat_use = X_threat(start_row:end, :);
    
    [imp_t, cb_t, shock_t, lag_t, resid_t, sd_t] = ...
        ir_jorda(y_t, X_threat_use, I, J, Jflag, level, H, alpha, trend, IC, L_NW);

    % -------------------------------------------------------------------
    % Act GPR shock
    % -------------------------------------------------------------------


    X_act = [z_act, LGPRA_lags, control_lags];
    
    y_a = y(start_row:end);
    X_act_use = X_act(start_row:end, :);
    
    [imp_a, cb_a, shock_a, lag_a, resid_a, sd_a] = ...
        ir_jorda(y_a, X_act_use, I, J, Jflag, level, H, alpha, trend, IC, L_NW);

% Print BIC-selected I
fprintf('  Selected I by BIC, World  = %s\n', mat2str(lag_w.I'));
fprintf('  Selected I by BIC, Threat = %s\n', mat2str(lag_t.I'));
fprintf('  Selected I by BIC, Act    = %s\n', mat2str(lag_a.I'));

% Store selected I directly
results.(yid).world.selected_I  = lag_w.I(:);
results.(yid).threat.selected_I = lag_t.I(:);
results.(yid).act.selected_I    = lag_a.I(:);

% Optional: also store the full lag_length object
results.(yid).world.lag_length  = lag_w;
results.(yid).threat.lag_length = lag_t;
results.(yid).act.lag_length    = lag_a;

   %%
    % -------------------------------------------------------------------
    % Store results
    % -------------------------------------------------------------------

    results.(yid).label = y_label;

    results.(yid).world.imp = imp_w;
    results.(yid).world.cb  = cb_w;
    results.(yid).world.sd  = sd_w;
    results.(yid).world.shock = shock_w;
    results.(yid).world.lag_length = lag_w;
    results.(yid).world.residual = resid_w;

    results.(yid).threat.imp = imp_t;
    results.(yid).threat.cb  = cb_t;
    results.(yid).threat.sd  = sd_t;
    results.(yid).threat.shock = shock_t;
    results.(yid).threat.lag_length = lag_t;
    results.(yid).threat.residual = resid_t;

    results.(yid).act.imp = imp_a;
    results.(yid).act.cb  = cb_a;
    results.(yid).act.sd  = sd_a;
    results.(yid).act.shock = shock_a;
    results.(yid).act.lag_length = lag_a;
    results.(yid).act.residual = resid_a;

    fprintf('  World : beta h0 = % .4f, beta h4 = % .4f\n', imp_w(1), imp_w(5));
    fprintf('  Threat: beta h0 = % .4f, beta h4 = % .4f\n', imp_t(1), imp_t(5));
    fprintf('  Act   : beta h0 = % .4f, beta h4 = % .4f\n', imp_a(1), imp_a(5));
end


%% Make BIC-selected lag table

lag_table = table();

for i = 1:numel(outcome_ids)

    yid = outcome_ids{i};

    temp = table();
    temp.h = (0:H)';
    temp.outcome = repmat(string(yid), H+1, 1);

    temp.I_world  = results.(yid).world.selected_I;
    temp.I_threat = results.(yid).threat.selected_I;
    temp.I_act    = results.(yid).act.selected_I;

    lag_table = [lag_table; temp];

end

disp(lag_table)

writetable(lag_table, 'Part2_BIC_selected_lags.csv');

%% 8. Make long-format result table

level_lp_results = table();

for i = 1:numel(outcome_ids)

    yid = outcome_ids{i};
    y_label = outcome_labels{i};

    % World
    temp = table();
    temp.outcome = repmat(string(yid), H+1, 1);
    temp.outcome_label = repmat(string(y_label), H+1, 1);
    temp.shock = repmat("world", H+1, 1);
    temp.h = h;
    temp.beta = results.(yid).world.imp;
    temp.lb = results.(yid).world.cb(:,1);
    temp.ub = results.(yid).world.cb(:,2);
    temp.se = results.(yid).world.sd;
    level_lp_results = [level_lp_results; temp];

    % Threat
    temp = table();
    temp.outcome = repmat(string(yid), H+1, 1);
    temp.outcome_label = repmat(string(y_label), H+1, 1);
    temp.shock = repmat("threat", H+1, 1);
    temp.h = h;
    temp.beta = results.(yid).threat.imp;
    temp.lb = results.(yid).threat.cb(:,1);
    temp.ub = results.(yid).threat.cb(:,2);
    temp.se = results.(yid).threat.sd;
    level_lp_results = [level_lp_results; temp];

    % Act
    temp = table();
    temp.outcome = repmat(string(yid), H+1, 1);
    temp.outcome_label = repmat(string(y_label), H+1, 1);
    temp.shock = repmat("act", H+1, 1);
    temp.h = h;
    temp.beta = results.(yid).act.imp;
    temp.lb = results.(yid).act.cb(:,1);
    temp.ub = results.(yid).act.cb(:,2);
    temp.se = results.(yid).act.sd;
    level_lp_results = [level_lp_results; temp];
end

disp(head(level_lp_results));

%% 9. Plot results

rows_per_figure = 5;
n_outcomes = numel(outcome_ids);
n_figs = ceil(n_outcomes / rows_per_figure);

for f = 1:n_figs

    idx_start = (f-1)*rows_per_figure + 1;
    idx_end   = min(f*rows_per_figure, n_outcomes);
    these_idx = idx_start:idx_end;

    rows_this_figure = numel(these_idx);

    fig = figure('Color', 'w', ...
        'Position', [60, 40, 1500, 330*rows_this_figure]);

    tl = tiledlayout(rows_this_figure, 2, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');

    for local_i = 1:rows_this_figure

        i = these_idx(local_i);
        yid = outcome_ids{i};
        y_label = outcome_labels{i};

        % -----------------------------------------------------------
        % Left column: World GPR shock
        % -----------------------------------------------------------

        nexttile;
        hold on;

        imp = results.(yid).world.imp;
        cb  = results.(yid).world.cb;

        p0 = fill([h; flipud(h)], [cb(:,2); flipud(cb(:,1))], ...
            [0.70 0.70 0.70], ...
            'EdgeColor', 'none', ...
            'FaceAlpha', 0.35);

        l0 = plot(h, imp, 'k-', 'LineWidth', 2.0);
        z0_left = yline(0, 'k:', 'LineWidth', 1.0);

        grid on;
        box on;
        xlim([0 H]);

        uistack(p0, 'bottom');
        uistack(l0, 'top');

        title(['World: ', y_label], ...
            'FontWeight', 'bold', ...
            'Interpreter', 'none');

        xlabel('Horizon (quarters)');
        ylabel('Level change: y_{t+h} - y_{t-1}');

        % -----------------------------------------------------------
        % Right column: Threat and Act shocks
        % -----------------------------------------------------------

        nexttile;
        hold on;

        imp_t = results.(yid).threat.imp;
        cb_t  = results.(yid).threat.cb;

        imp_a = results.(yid).act.imp;
        cb_a  = results.(yid).act.cb;

        p1 = fill([h; flipud(h)], [cb_t(:,2); flipud(cb_t(:,1))], ...
            [0.60 0.78 1.00], ...
            'EdgeColor', 'none', ...
            'FaceAlpha', 0.35);

        p2 = fill([h; flipud(h)], [cb_a(:,2); flipud(cb_a(:,1))], ...
            [1.00 0.68 0.68], ...
            'EdgeColor', 'none', ...
            'FaceAlpha', 0.35);

        l1 = plot(h, imp_t, 'b-', 'LineWidth', 2.0);
        l2 = plot(h, imp_a, 'r-', 'LineWidth', 2.0);
        z0_right = yline(0, 'k:', 'LineWidth', 1.0);

        grid on;
        box on;
        xlim([0 H]);

        uistack(p1, 'bottom');
        uistack(p2, 'bottom');
        uistack(l1, 'top');
        uistack(l2, 'top');

        title(['Threat / Act: ', y_label], ...
            'FontWeight', 'bold', ...
            'Interpreter', 'none');

        xlabel('Horizon (quarters)');
        ylabel('Level change: y_{t+h} - y_{t-1}');

    end   % end of local_i loop

    % Shared legend centered below both columns
    lgd = legend([p1 p2 l1 l2 z0_right], ...
        {'Threat CI', 'Act CI', 'Threat', 'Act', 'Zero'}, ...
        'Orientation', 'horizontal');

    lgd.Layout.Tile = 'south';
    lgd.Box = 'off';
    lgd.NumColumns = 5;

    title(tl, sprintf('Part 2 Clean LP using ir\\_jorda.m, Figure %d of %d', f, n_figs), ...
        'FontWeight', 'bold', ...
        'FontSize', 14);

    if save_figures

        ax_all = findall(fig, 'Type', 'axes');
        for aa = 1:numel(ax_all)
            ax_all(aa).Toolbar.Visible = 'off';
        end

        fig_file = sprintf('Part2_Clean_Figure%d.png', f);
        exportgraphics(fig, fig_file, 'Resolution', 250);
        fprintf('Saved figure: %s\n', fig_file);

    end

end
%% 10. Save results in current folder

save('Part2_Clean_irjorda_workspace.mat', ...
    'results', ...
    'level_lp_results', ...
    'lag_table', ...
    'z_world', ...
    'z_threat', ...
    'z_act', ...
    'R2_world', ...
    'R2_threat', ...
    'R2_act', ...
    'outcome_ids', ...
    'outcome_labels', ...
    'L', ...
    'H', ...
    'alpha');

writetable(level_lp_results, 'Part2_Clean_irjorda_results.csv');

fprintf('\nDone. Results are saved in the current folder.\n');