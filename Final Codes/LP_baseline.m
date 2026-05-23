%% =======================================================================
% LP_baseline.m
% ------------------------------------------------------------------------
% Step 1.  Extract standardized GPR shocks z_t under TWO control specs:
%
%          (a) "with_oil"    : GPR_t = a + sum rho_j GPR_{t-j}
%                                       + xi'  [Unemp_t, FFR_t]
%                                       + omega'[Brent, WTI, Gas]_{t-1} + u_t
%          (b) "without_oil" : GPR_t = a + sum rho_j GPR_{t-j}
%                                       + xi'  [Unemp_t, FFR_t]         + u_t
%
%          z_t = (u_t - mean(u))/sd(u) (in-sample).
%
% Step 2.  Baseline local projection (LP) on each variant's shock:
%
%          y_{t+h} - y_{t-1} = alpha_h + beta_h * z_t
%                              + sum_{j=1..p} rho_{h,j}  * y_{t-j}
%                              + sum_{j=1..p} gamma_{h,j}* GPR_{t-j}
%                              + sum_{j=1..p} theta_{h,j}'* controls_{t-j}
%                              + e_{t+h}
%
%          Outcome-dependent LP control set:
%            - If outcome is an oil price (Real_Brent/WTI/Gasoline),
%              drop ALL oil-price controls (high pairwise correlation
%              with y_{t-j} would inflate SEs).
%            - Otherwise, drop only the matching outcome from controls.
%
%          Inference: Newey-West HAC SE, bandwidth = h+1.
%
% Step 3.  Comparison IRF dashboards: w/ oil vs w/o oil overlaid per panel.
%% =======================================================================

clear; clc; close all;

%% User Setting
cfg.datafile     = 'Q_Levels_Database.csv';
cfg.output_dir   = 'LP_baseline_output';
cfg.save_results = true;
cfg.save_figures = true;
cfg.show_figures = true;

%% Step 1 — AR shock extraction
cfg.p_gpr_shock          = 4;
cfg.standardize_shock    = true;
cfg.current_control_vars = {'Unemp', 'FFR'};
cfg.lag1_oil_vars        = {'Real_Brent', 'Real_WTI', 'Real_Gasoline'};

%% Step 2 — LP specification
cfg.p_lp        = 4;     % lag length for y, GPR, controls
cfg.H           = 12;    % horizons 0..H (quarters)
cfg.shock_size  = 1;     % z_t is in s.d. units; 1 -> 1-sd impulse
cfg.alpha_ci    = 0.10;  % CI band  -> 90%

%% Control specifications to compare
spec_variants = {
    'with_oil',    true;    % include lag-1 oil controls in shock equation
    'without_oil', false;   % drop lag-1 oil controls
};

%% Aggregate GPR shocks
cfg.shock_specs = {
    'World',  'LGPR',   'World GPR shock';
    'GPT',    'LGPRT',  'Global geopolitical threats shock';
    'GPA',    'LGPRA',  'Global geopolitical acts shock'
};

%% Outcome variables (exact CSV column names + display label)
%  Matched to the presentation slides (baseline LP figures, p.14-15):
%    Top row    : oil prices    (Brent, WTI, Gasoline)
%    Bottom row : macro outcomes (Headline inflation, Core inflation, IP)
cfg.outcome_vars = {
    'Real_Brent',    'Brent crude oil price';
    'Real_WTI',      'WTI crude oil price';
    'Real_Gasoline', 'Retail gasoline price';
    'Headline_Pi',   'Headline inflation';
    'Core_Pi',       'Core inflation';
    'Indu_Prod',     'Industrial production'
};

%% Controls entered as lags j=1..p in the LP.
%  Includes the three macro outcomes so that cross-outcome dynamics
%  (e.g. headline-vs-core, IP-vs-inflation) are absorbed via lags when one
%  of them is the dependent variable.  The outcome-dependent control logic
%  below removes whichever variable is currently the outcome.
cfg.control_vars = {'Unemp', 'FFR', ...
                    'Real_Brent', 'Real_WTI', 'Real_Gasoline', ...
                    'Headline_Pi', 'Core_Pi', 'Indu_Prod'};

%% Oil-price set used by the outcome-dependent LP control logic.
% When the outcome IS one of these, all of them are dropped from controls
% (y_{t-j} already captures own-price autocorrelation; remaining oil-price
% lags are highly collinear and only inflate the SEs).
cfg.oil_price_vars = {'Real_Brent', 'Real_WTI', 'Real_Gasoline'};

%% Plotting grid + comparison colors
cfg.dashboard_nrow = 3;
cfg.dashboard_ncol = 2;
cfg.color_with_oil    = [0.10 0.30 0.75];   % blue
cfg.color_without_oil = [0.85 0.20 0.15];   % red

if cfg.save_results && ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end

fprintf('\n=== LP pipeline: shock extraction (w/ oil vs w/o oil) + LP + comparison ===\n');
fprintf('AR lags p_gpr  : %d\n', cfg.p_gpr_shock);
fprintf('LP lags  p_lp  : %d\n', cfg.p_lp);
fprintf('Horizon  H     : %d\n', cfg.H);
fprintf('Shock size     : %.2f s.d.\n', cfg.shock_size);
fprintf('CI level       : %.0f%%\n', 100*(1-cfg.alpha_ci));
fprintf('Data file      : %s\n', cfg.datafile);

%% Load database
DB      = readtable(cfg.datafile, 'VariableNamingRule', 'preserve');
T       = height(DB);
db_vars = DB.Properties.VariableNames;
fprintf('Loaded T = %d rows, %d variables.\n', T, numel(db_vars));

%% Preload every needed column once (exact-name validation + column-vector cast)
needed = unique([cfg.current_control_vars, cfg.lag1_oil_vars, ...
                 cfg.shock_specs(:,2)',    cfg.outcome_vars(:,1)', ...
                 cfg.control_vars]);
DB_cache = struct();
for i = 1:numel(needed)
    vn = needed{i};
    if ~any(strcmp(db_vars, vn))
        error('Variable "%s" not found in %s.\nAvailable columns:\n  %s', ...
              vn, cfg.datafile, strjoin(db_vars, ', '));
    end
    col = DB.(vn);
    if ~(isnumeric(col) || islogical(col))
        error('Variable "%s" exists but is not numeric.', vn);
    end
    DB_cache.(vn) = double(col(:));
end

%% Build full control matrices (used by the shock equation)
nC = numel(cfg.current_control_vars);
current_controls = zeros(T, nC);
for i = 1:nC
    current_controls(:,i) = DB_cache.(cfg.current_control_vars{i});
end

nL = numel(cfg.lag1_oil_vars);
lag1_controls = zeros(T, nL);
for i = 1:nL
    lag1_controls(:,i) = DB_cache.(cfg.lag1_oil_vars{i});
end

%% Diagnostic: pairwise correlation of oil-price controls 
% High pairwise correlation flags multicollinearity in the LP control set.
% (Multicollinearity is harmless for the AR shock extraction since only
% the residual depends on the column space of X, but it inflates the SE
% of beta_h in the LP regression.)
oil_corr = corr(lag1_controls, 'Rows', 'pairwise');
fprintf('\nPairwise correlation of oil-price controls:\n');
fprintf('               %s\n', sprintf('%-14s ', cfg.lag1_oil_vars{:}));
for i = 1:nL
    fprintf('  %-12s', cfg.lag1_oil_vars{i});
    for j = 1:nL
        fprintf(' %-14.3f', oil_corr(i,j));
    end
    fprintf('\n');
end

fprintf('Shock-eq controls  : %s   (current)\n', strjoin(cfg.current_control_vars, ', '));
fprintf('                     %s   (lag-1)\n',   strjoin(cfg.lag1_oil_vars, ', '));

%% Preload GPR level series (variant-invariant)
GPR_levels = struct();
for s = 1:size(cfg.shock_specs,1)
    GPR_levels.(cfg.shock_specs{s,1}) = DB_cache.(cfg.shock_specs{s,2});
end

%% ========================================================================
%  STEP 1: Extract standardized GPR shocks (both variants)
%% ========================================================================
p_ar  = cfg.p_gpr_shock;
t_ar  = ((p_ar+1):T)';
nT_ar = numel(t_ar);

Z_all           = struct();   % Z_all.(variant).(sid)
innovation_info = table();

for v = 1:size(spec_variants, 1)
    variant = spec_variants{v,1};
    use_oil = spec_variants{v,2};

    if use_oil
        L1   = lag1_controls;
        nL_v = nL;
        oil_lbl = 'YES';
    else
        L1   = zeros(T, 0);
        nL_v = 0;
        oil_lbl = 'NO';
    end

    fprintf('\n--- Constructing shocks [variant=%s, oil controls=%s] ---\n', variant, oil_lbl);

    Z_v = struct();
    for s = 1:size(cfg.shock_specs,1)
        sid   = cfg.shock_specs{s,1};
        label = cfg.shock_specs{s,3};
        gpr   = GPR_levels.(sid);

        % Vectorised design: [1, AR lags, B_t, O_{t-1}]
        X_ar = zeros(nT_ar, p_ar);
        for j = 1:p_ar
            X_ar(:,j) = gpr(t_ar - j);
        end
        X_curr = current_controls(t_ar, :);
        if nL_v > 0
            X_lag1 = L1(t_ar - 1, :);
        else
            X_lag1 = zeros(nT_ar, 0);
        end
        X = [ones(nT_ar,1), X_ar, X_curr, X_lag1];
        Y = gpr(t_ar);

        good   = isfinite(Y) & all(isfinite(X), 2);
        Yg     = Y(good);
        Xg     = X(good, :);
        t_used = t_ar(good);

        if size(Xg,1) <= size(Xg,2)
            error('Not enough usable observations for AR(%d) extraction of %s [%s].', ...
                  p_ar, sid, variant);
        end

        % Numerical-stability check: condition number of X'X.
        % > 1e8 hints at problematic multicollinearity (rare for our regressor count).
        cond_XtX = cond(Xg' * Xg);

        b    = Xg \ Yg;
        Yhat = Xg * b;
        u    = Yg - Yhat;
        rsq  = 1 - sum(u.^2) / sum((Yg - mean(Yg)).^2);

        resid_full         = nan(T,1);
        resid_full(t_used) = u;
        if cfg.standardize_shock
            z_shock = (resid_full - mean(u)) / std(u);
        else
            z_shock = resid_full;
        end
        Z_v.(sid) = z_shock;

        innovation_info = [innovation_info; ...
            table(string(variant), string(sid), string(label), numel(Yg), rsq, std(u), sum(isfinite(z_shock)), ...
                  'VariableNames', {'variant','shock','label','nobs','rsq','resid_sd','finite_z'})]; %#ok<AGROW>

        fprintf('  %-12s: nobs=%3d, AR R2=% .3f, resid sd=% .4f, finite z=%3d, cond(X''X)=%6.2e\n', ...
                sid, numel(Yg), rsq, std(u), sum(isfinite(z_shock)), cond_XtX);
    end
    Z_all.(variant) = Z_v;
end

%% ========================================================================
%  STEP 2: Baseline LP estimation (run for BOTH variants)
%% ========================================================================
p      = cfg.p_lp;
H      = cfg.H;
nO     = size(cfg.outcome_vars, 1);

% X_full layout (assembled below): [const, z_t, Y_lag(p), GPR_lag(p), Ctrl_lag(p*nCu)]
% Column index of z_t is therefore always 2; we assert this once per horizon
% loop entry rather than trusting a magic constant silently.
idx_const = 1;
idx_z     = 2;

h4_idx = min(5, H + 1);                % console-summary horizon (h=4 if available)

z_crit = norminv(1 - cfg.alpha_ci/2);  % ~1.645 for 90%

% Maximal contiguous sample for LP: t in [p+1, T].  Each horizon h merely
% slices off the last h rows so that t+h <= T; lag values themselves do
% not depend on h.  Pre-building the lag matrices once per (shock, outcome)
% therefore eliminates ~ horizon-many redundant rebuilds.
t_max  = ((p+1):T)';
n_max  = numel(t_max);

lp_results = table();
irf_struct = struct();                 % irf_struct.(variant).(sid).(yname)

for v = 1:size(spec_variants, 1)
    variant = spec_variants{v,1};
    fprintf('\n--- LP estimation [variant=%s] ---\n', variant);

    for ii = 1:size(cfg.shock_specs,1)
        sid       = cfg.shock_specs{ii,1};
        z         = Z_all.(variant).(sid);
        gpr_level = GPR_levels.(sid);

        % GPR lag block depends on the current shock only -> build once.
        GPR_lag_full = zeros(n_max, p);
        for j = 1:p
            GPR_lag_full(:,j) = gpr_level(t_max - j);
        end

        fprintf('\nShock: %s\n', sid);

        for oi = 1:nO
            yname  = cfg.outcome_vars{oi,1};
            y      = DB_cache.(yname);

            % Outcome-dependent LP control set:
            %   - oil-price outcome  : drop ALL oil-price controls
            %                          (y_{t-j} captures own lags; the others
            %                           are highly collinear and inflate SEs).
            %   - non-oil outcome    : drop only the matching outcome.
            if ismember(yname, cfg.oil_price_vars)
                ctrl_used = setdiff(cfg.control_vars, cfg.oil_price_vars, 'stable');
            else
                ctrl_used = setdiff(cfg.control_vars, {yname}, 'stable');
            end
            nCu = numel(ctrl_used);

            % Pre-stack control series as a T x nCu matrix (done once per outcome).
            ctrl_mat = zeros(T, nCu);
            for c = 1:nCu
                ctrl_mat(:,c) = DB_cache.(ctrl_used{c});
            end

            % Build h-invariant lag blocks for this (shock, outcome) combination.
            Y_lag_full = zeros(n_max, p);
            for j = 1:p
                Y_lag_full(:,j) = y(t_max - j);
            end
            Ctrl_lag_full = zeros(n_max, p * nCu);
            for c = 1:nCu
                for j = 1:p
                    Ctrl_lag_full(:, (c-1)*p + j) = ctrl_mat(t_max - j, c);
                end
            end

            beta   = nan(H+1, 1);
            se     = nan(H+1, 1);
            nobs_h = nan(H+1, 1);

            for h = 0:H
                % Valid t window: t-p>=1, t-1>=1, t+h<=T -> t in [p+1, T-h].
                % This is the first (n_max - h) rows of the pre-built blocks.
                rows = 1:(n_max - h);
                if isempty(rows), continue; end
                t_grid = t_max(rows);
                n_t    = numel(t_grid);

                Y     = y(t_grid + h) - y(t_grid - 1);
                Z_imp = z(t_grid);

                Y_lag    = Y_lag_full(rows, :);
                GPR_lag  = GPR_lag_full(rows, :);
                Ctrl_lag = Ctrl_lag_full(rows, :);

                X_full = [ones(n_t,1), Z_imp, Y_lag, GPR_lag, Ctrl_lag];

                % Safety check: the z column must still be at idx_z.  This
                % catches accidental layout changes when the assembly above
                % is edited.  isequaln treats NaN as equal so the check
                % passes even though Z_imp's first p entries are NaN.
                if h == 0
                    assert(isequaln(X_full(:,idx_z), Z_imp), ...
                        'LP_baseline:idx_z layout assumption violated.');
                end

                good = isfinite(Y) & all(isfinite(X_full), 2);
                Yg   = Y(good);
                Xg   = X_full(good, :);
                n    = sum(good);
                k    = size(Xg, 2);

                if n <= k + 1
                    warning('h=%d, %s/%s [%s]: insufficient obs (n=%d, k=%d). Skipping.', ...
                            h, sid, yname, variant, n, k);
                    continue;
                end

                bhat  = Xg \ Yg;
                resid = Yg - Xg * bhat;

                % Newey-West HAC, Bartlett kernel, bandwidth = h+1.
                bw    = h + 1;
                score = Xg .* resid;
                Omega = score' * score;
                for j = 1:bw
                    w  = 1 - j/(bw+1);
                    Sj = score((j+1):n, :)' * score(1:(n-j), :);
                    Omega = Omega + w * (Sj + Sj');
                end
                A      = Xg' * Xg;
                V_beta = A \ Omega / A;          % numerically safer than explicit inverse

                beta(h+1)   = bhat(idx_z) * cfg.shock_size;
                se(h+1)     = sqrt(max(V_beta(idx_z, idx_z), 0)) * cfg.shock_size;
                nobs_h(h+1) = n;
            end

            lb = beta - z_crit * se;
            ub = beta + z_crit * se;

            horizons = (0:H)';
            tmp = table(repmat(string(variant), H+1, 1), ...
                        repmat(string(sid),     H+1, 1), ...
                        repmat(string(yname),   H+1, 1), ...
                        horizons, beta, se, lb, ub, nobs_h, ...
                        'VariableNames', {'variant','shock','outcome','horizon','beta','se','lb','ub','nobs'});
            lp_results = [lp_results; tmp]; %#ok<AGROW>
            irf_struct.(variant).(sid).(yname) = struct('beta', beta, 'se', se, ...
                'lb', lb, 'ub', ub, 'nobs', nobs_h);

            % Console summary (guarded for arbitrary H).
            if any(isfinite(beta))
                [~, peak_h] = max(abs(beta));
            else
                peak_h = 1;
            end
            fprintf('  %-14s | beta(h=0)=% .3f (se=% .3f) | beta(h=%d)=% .3f (se=% .3f) | peak=% .3f at h=%d\n', ...
                    yname, beta(1), se(1), h4_idx-1, beta(h4_idx), se(h4_idx), beta(peak_h), peak_h-1);
        end
    end
end

%% ========================================================================
%  STEP 3: Comparison IRF dashboards (w/ oil vs w/o oil overlaid)
%% ========================================================================
if cfg.save_figures || cfg.show_figures
    visible_flag = 'off';
    if cfg.show_figures, visible_flag = 'on'; end

    h_idx = 0:H;

    for ii = 1:size(cfg.shock_specs,1)
        sid = cfg.shock_specs{ii,1};

        % Suppress figure-level toolbar/menu so they do not appear in
        % exported PNGs (and pair with the per-axes Toolbar.Visible='off'
        % set before exportgraphics below).
        fig = figure('Position', [80 80 1000 1200], 'Visible', visible_flag, ...
                     'ToolBar', 'none', 'MenuBar', 'none');
        sgtitle(sprintf('LP IRF comparison: %s GPR shock  (%.0f%% bands, NW HAC bw=h+1)', ...
                        sid, 100*(1-cfg.alpha_ci)), ...
                'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');

        for oi = 1:nO
            yname      = cfg.outcome_vars{oi,1};
            ylabel_str = cfg.outcome_vars{oi,2};
            r_with     = irf_struct.with_oil.(sid).(yname);
            r_wo     = irf_struct.without_oil.(sid).(yname);

            % Column-major placement: col 1 = oil prices (oi=1..3),
            % col 2 = macro outcomes (oi=4..6). Preserves the 2x3 layout's
            % "oil vs macro" semantic grouping when rotated to 3x2.
            if oi <= 3
                subplot_pos = 2*oi - 1;     % 1, 3, 5  (col 1)
            else
                subplot_pos = 2*(oi - 3);   % 2, 4, 6  (col 2)
            end
            subplot(cfg.dashboard_nrow, cfg.dashboard_ncol, subplot_pos);
            hold on; box on; grid on;

            % CI bands (translucent)
            patch([h_idx, fliplr(h_idx)], [r_with.lb', fliplr(r_with.ub')], ...
                  cfg.color_with_oil, 'FaceAlpha', 0.18, 'EdgeColor', 'none');
            patch([h_idx, fliplr(h_idx)], [r_wo.lb', fliplr(r_wo.ub')], ...
                  cfg.color_without_oil, 'FaceAlpha', 0.18, 'EdgeColor', 'none');

            % Zero line
            plot(h_idx, zeros(size(h_idx)), 'k--', 'LineWidth', 1);

            % Point estimates
            h1 = plot(h_idx, r_with.beta, '-',  'Color', cfg.color_with_oil,    'LineWidth', 2.4);
            h2 = plot(h_idx, r_wo.beta, '--', 'Color', cfg.color_without_oil, 'LineWidth', 2.2);

            title(ylabel_str, 'Interpreter', 'none', 'FontSize', 11);
            xlabel('Horizon (quarters)');
            ylabel('Response');
            xlim([0 H]);

            if oi == 1
                legend([h1, h2], {'w/ oil', 'w/o oil'}, ...
                       'Location', 'best', 'FontSize', 9);
            end
        end

        if cfg.save_figures
            drawnow;  % Ensure figure is fully rendered
            if isempty(fig) || ~isgraphics(fig, 'figure')
                warning('Invalid figure handle for %s. Skipping save.', sid);
            else
                % Hide axes toolbar (R2018b+) so it does not appear in exported PNG.
                for ax = findall(fig, 'Type', 'axes')'
                    if isprop(ax, 'Toolbar')
                        ax.Toolbar.Visible = 'off';
                    end
                end
                exportgraphics(fig, fullfile(cfg.output_dir, sprintf('IRF_compare_%s.png', sid)), 'Resolution', 200);
                savefig(fig,        fullfile(cfg.output_dir, sprintf('IRF_compare_%s.fig', sid)));
            end
        end
        if ~cfg.show_figures
            close(fig);
        end
    end
    if cfg.save_figures
        fprintf('\nSaved comparison IRF figures to %s\n', cfg.output_dir);
    end
end

%% Save results
if cfg.save_results
    writetable(innovation_info, fullfile(cfg.output_dir, 'gpr_shock_diagnostics.csv'));
    writetable(lp_results,      fullfile(cfg.output_dir, 'lp_results.csv'));
    save(fullfile(cfg.output_dir, 'workspace_lp.mat'), ...
         'cfg','Z_all','GPR_levels','innovation_info','lp_results','irf_struct');
    fprintf('Saved CSVs + workspace to %s\n', cfg.output_dir);
else
    fprintf('\nNo files saved (cfg.save_results = false).\n');
end
