%% =======================================================================
%% [PART 2] Candidate mechanism LEVEL LPs using AR-only GPR innovations
%%          SPLITWISE version, no VIX control.
%% -----------------------------------------------------------------------
% Estimating equation (one specification per outcome y and per shock z):
%
%   y_{t+h} - y_{t-1} = alpha_h + beta_h * z_t
%                       + sum_{j=1..p} rho_{h,j} * y_{t-j}
%                       + sum_{j=1..p} gamma_{h,j} * GPR_{t-j}
%                       + sum_{j=1..p} theta_{h,j}' * controls_{t-j}
%                       + e_{t+h}
%
% Notes on the spec:
%   - y is a level variable from Q_Levels_Database.mat (CSV mirror as fallback).
%   - z_t is a standardised AR(p_innov) residual extracted from the
%     corresponding GPR level (World / Threat / Act).
%   - beta_h is already the level-change response (y_{t+h} - y_{t-1}),
%     so DO NOT cumulate beta_h across horizons.
%   - Lagged GPR LEVELS are included as controls; lagged z values are NOT.
%
% Output figure layout (kept identical to the original Part 2):
%   - Two figures total.
%   - Each figure: rows_per_figure x 2 tile layout.
%   - Left column  = World GPR innovation IRF.
%   - Right column = Threat and Act IRFs overlaid (estimated separately).
%
% IMPORTANT:
%   - log(VIX) is removed from the control vector everywhere.
%   - log(VIX) is still included as an outcome, constructed from VOX/VIX.
%% =======================================================================


clear; clc; close all;

this_dir = fileparts(mfilename('fullpath'));
if isempty(this_dir), this_dir = pwd; end
code_dir = fullfile(this_dir, 'code');
if exist(code_dir, 'dir'), addpath(code_dir); end


%% (1) USER SETTINGS -----------------------------------------------------

% Data file
cfg.datafile          = 'Q_Levels_Database.mat';
cfg.fallback_datafile = 'Q_Levels_Database.csv';

% Lag orders and horizon
cfg.p_innov           = 1;       % AR(1) for extracting GPR innovations
cfg.p_lp              = 4;       % LP(4) : # of lags of y, GPR, controls 
cfg.H                 = 12;      % max horizon (quarters)
cfg.ci                = 0.90;    % CI for IRF bands
cfg.shock_size        = 1;       % response to a 1-s.d. shock (z is z-scored)
cfg.standardize_innov = true;    % if true, z = AR residual divided by in-sample s.d.

% Output behaviour. Set save_results / save_figures to true to write to disk.
cfg.save_results      = false;
cfg.save_figures      = true;
cfg.show_figures      = true;
cfg.rows_per_figure   = 5;
cfg.horizon_label     = 'Horizon (quarters)';
cfg.output_dir        = 'Part2_Mechanism_LevelLP_NoVIX';

% File names for optional saved artefacts.
cfg.innov_file        = fullfile(cfg.output_dir, 'gpr_innovations_part2_level_ARonly.csv');
cfg.results_file      = fullfile(cfg.output_dir, 'part2_mechanism_level_lp_results_splitwise_noVIXcontrol.csv');
cfg.figure_file_1     = fullfile(cfg.output_dir, 'Part2_Figure1.png');   
cfg.figure_file_2     = fullfile(cfg.output_dir, 'Part2_Figure2.png');

% Create output directory 
if cfg.save_results || cfg.save_figures
    if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
end

% Console banner so the log makes the spec obvious at a glance.
fprintf('\n=== Part 2 mechanism LEVEL LP, splitwise, no VIX control ===\n');
fprintf('Specification: y_{t+h} - y_{t-1} on standardized z_t, lagged y levels, lagged GPR levels, and lagged controls.\n');
fprintf('GPR innovation AR lag p_innov = %d; LP lags p_lp = %d; horizon = 0:%d; shock size = %.2f s.d.\n', ...
    cfg.p_innov, cfg.p_lp, cfg.H, cfg.shock_size);


%% (2) LOAD LEVEL DATABASE -----------------------------------------------
% Primary: the .mat ships a MATLAB table
% Fallback: read the .csv mirror via readtable 
% NOTE : A warning is issued because the CSV can drift from the .mat 
%        if it is not regenerated after a data update

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
    error('Data file not found: neither %s nor %s. Place one of them on the MATLAB search path / cwd, or update cfg.datafile.', ...
        cfg.datafile, cfg.fallback_datafile);
end
T = height(DB);
varnames = DB.Properties.VariableNames;
fprintf('Data file used: %s\n', datafile_used);
fprintf('Loaded rows T = %d, variables = %d\n', T, numel(varnames));
fprintf('Variables available:\n');
fprintf('  %s\n', strjoin(varnames, ', '));

% Quarterly Data : 1986Q1 ~ 2025Q4 (160 quarters)
[quarter_labels, has_quarter] = get_quarter_labels(DB, T);
if has_quarter
    fprintf('Sample starts at %s and ends at %s\n', quarter_labels{1}, quarter_labels{end});
end

% Use the entire database sample
sample = true(T,1);
fprintf('Using full sample: %d / %d rows are active.\n', sum(sample), T);


%% (3) CONTROLS: NO VIX CONTROL ------------------------------------------
% Macro controls that enter the LP as p_lp lags
% NOTE: VIX is intentionally excluded from controls (see header).

controls      = [DB.Unemp, DB.FFR];      % T x 2: [Unemp, FFR]
control_names = {'Unemp', 'FFR'};

% No missing values; finite = 160/160
fprintf('\nControls loaded, excluding VIX by design:\n');
for j = 1:numel(control_names)
    fprintf('  Control %-12s finite = %3d / %3d\n', control_names{j}, sum(isfinite(controls(:,j))), T);
end


%% (4) OUTCOME SERIES ----------------------------------------------------
% NOTE : VIX (column 'VOX' in the database) is NOT a control here, 
%        but is retained as an outcome in log form. 
%        The 1e-8 floor guards against accidental zero entries before log.

lnVIX = log(max(DB.VOX, 1e-8));

% Outcome identifiers. 
% NOTE : Each id (except 'lnVIX') is also the column name in DB, 
%        so it doubles as the lookup key in the LP loop below.
outcome_ids = {'Real_WTI','Real_Gasoline','MICH','SPF_inf', ...
               'Two_PH_SPF_Inf','r_c','r_i','r_y','lnVIX'};

% Human-readable labels (used in figure titles and console prints).
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
% 3 GPR levels (overall, threat, act) → three sets of AR-only innovations. 
% The innovation z_t is the AR(p_innov) residual; if
% standardize_innov is true it is then divided by its in-sample s.d.,
% so a unit shock corresponds to one standard deviation of z.

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

% Quick first-stage diagnostics (sample size and AR R-squared).
fprintf('\n--- GPR innovation checks ---\n');
fprintf('World : AR nobs=%3d, R2=% .3f, finite z=%3d\n', fs_world.nobs,  fs_world.R2,  sum(isfinite(z_world)));
fprintf('Threat: AR nobs=%3d, R2=% .3f, finite z=%3d\n', fs_threat.nobs, fs_threat.R2, sum(isfinite(z_threat)));
fprintf('Act   : AR nobs=%3d, R2=% .3f, finite z=%3d\n', fs_act.nobs,    fs_act.R2,    sum(isfinite(z_act)));



%% (6) ESTIMATE LEVEL LOCAL PROJECTIONS ----------------------------------
% For each outcome we run THREE separate LPs (one per shock series).
% Results are stored both as nested structs (one struct per outcome,
% one field per horizon series) and as a long-format table for export.

results_world  = struct();
results_threat = struct();
results_act    = struct();
level_lp_results = table();

fprintf('\n--- Estimating Part 2 level LPs ---\n');
for i = 1:numel(outcome_ids)
    yid = outcome_ids{i};
    ylabel = outcome_labels{i};

    % lnVIX is constructed above; everything else is the same column name in DB.
    if strcmp(yid, 'lnVIX')
        y = lnVIX;
    else
        y = DB.(yid);
    end

    fprintf('\nOutcome: %s\n', ylabel);
    fprintf('  finite y = %3d / %3d\n', sum(isfinite(y)), T);

    % Three independent LPs (NOT a joint system) — splitwise specification.
    results_world.(yid) = estimate_lp_level_change_single_shock( ...
        y, z_world, LGPR, controls, sample, cfg, ylabel, 'world');

    results_threat.(yid) = estimate_lp_level_change_single_shock( ...
        y, z_threat, LGPRT, controls, sample, cfg, ylabel, 'threat');

    results_act.(yid) = estimate_lp_level_change_single_shock( ...
        y, z_act, LGPRA, controls, sample, cfg, ylabel, 'act');

    % Stash control names for downstream auditing.
    results_world.(yid).controls  = control_names;
    results_threat.(yid).controls = control_names;
    results_act.(yid).controls    = control_names;

    % Console diagnostic: finite betas and key horizon coefficients.
    print_lp_check(results_world.(yid), results_threat.(yid), results_act.(yid), cfg);

    % Long-format table accumulation: one row per (outcome, shock, horizon).
    tmpW = results_world.(yid).table;  tmpW.shock = repmat("world", height(tmpW), 1);
    tmpT = results_threat.(yid).table; tmpT.shock = repmat("threat", height(tmpT), 1);
    tmpA = results_act.(yid).table;    tmpA.shock = repmat("act", height(tmpA), 1);
    tmp = [tmpW; tmpT; tmpA];
    tmp.outcome = repmat(string(yid), height(tmp), 1);
    tmp.outcome_label = repmat(string(ylabel), height(tmp), 1);
    tmp.specification = repmat("level_change_y_tph_minus_y_tm1", height(tmp), 1);
    level_lp_results = [level_lp_results; tmp]; %#ok<AGROW>
end

% Render the two summary figures (left = World, right = Threat & Act).
figure_files = plot_part2_two_figures_splitwise_level( ...
    results_world, results_threat, results_act, outcome_ids, outcome_labels, cfg);

%% OPTIONAL SAVE ---------------------------------------------------------
% Only persist artefacts when save_results=true. Workspace variables
% remain available for interactive inspection regardless.
if cfg.save_results
    innovations = table( ...
        string({'world';'threat';'act'}), ...
        [fs_world.nobs; fs_threat.nobs; fs_act.nobs], ...
        [fs_world.R2; fs_threat.R2; fs_act.R2], ...
        [sum(isfinite(z_world)); sum(isfinite(z_threat)); sum(isfinite(z_act))], ...
        'VariableNames', {'shock','ar_nobs','ar_R2','finite_z'});
    writetable(innovations, cfg.innov_file);
    writetable(level_lp_results, cfg.results_file);
    save(fullfile(cfg.output_dir, 'part2_mechanism_level_lp_workspace.mat'), ...
        'cfg','results_world','results_threat','results_act','level_lp_results', ...
        'z_world','z_threat','z_act','fs_world','fs_threat','fs_act','control_names','figure_files');
    fprintf('\nSaved results to %s\n', cfg.output_dir);
else
    fprintf('\nNo result tables saved because cfg.save_results=false.\n');
    fprintf('Results are available in workspace: level_lp_results, results_world, results_threat, results_act.\n');
end


%% =======================================================================
%% Helper Functions
%% =======================================================================

%% (1) Load a MATLAB table out of a .mat file --------------------------------
% Defensive loader: opens the .mat, returns the first variable that is
% itself a table. As a fallback, a single struct is coerced via
% struct2table. Errors out if neither is possible, listing what was found.
%
% Inputs:
%   matfile : path to a .mat file.
%
% Output:
%   DB : MATLAB table.

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

%% (2) Best-effort extraction of a date / quarter label column -----------
%
% Inputs:
%   DB : MATLAB table.
%   T  : expected number of rows (height(DB)).
%
% Outputs:
%   quarter_labels : T-by-1 cellstr (empty strings if no column found).
%   has_quarter    : logical, true if a column was located.
%
% Looks for any case-insensitive column named quarter / Quarter /
% date / Date. Cells are returned as-is; other types are coerced to
% strings via cellstr(string(.)).

function [quarter_labels, has_quarter] = get_quarter_labels(DB, T)
 
    quarter_labels = repmat({''}, T, 1);
    has_quarter = false;
    names = DB.Properties.VariableNames;
    idx = find(strcmpi(names, 'quarter') | strcmpi(names, 'Quarter') | strcmpi(names, 'date') | strcmpi(names, 'Date'), 1);
    if isempty(idx), return; end
    q = DB.(names{idx});
    has_quarter = true;
    if iscell(q)
        quarter_labels = q(:);
    else
        quarter_labels = cellstr(string(q(:)));
    end
end

%% (3) Estimate an AR(p) on the level x and return the residuals(innovation)
% Estimate an AR(p) on the level x and return the residuals as the
% "innovation". Uses listwise deletion within the sample window.
%
% Model:  x_t = c + sum_{j=1..p} phi_j * x_{t-j} + e_t
%
% Inputs:
%   x      : T-by-1 series (column or row, both accepted).
%   sample : T-by-1 logical mask of admissible observations.
%   p      : AR order (>= 1).
%   x_name : string for diagnostic / error messages.
%
% Outputs:
%   innov : T-by-1 column with residuals at valid t's, NaN elsewhere.
%   info  : struct with name, p, nobs, beta, fitted, resid, t_index, R2.

function [innov, info] = extract_ar_level_innovation(x, sample, p, x_name)

    x = x(:);
    sample = sample(:);
    T = length(x);

    % Build [const, x_{t-1}, ..., x_{t-p}] in one shot via lagmatrix.
    % NaN-fills the first p rows automatically, which the mask below removes.
    Xlags = lagmatrix(x, 1:p);              % T x p
    X = [ones(T,1), Xlags];
    Y = x;

    % Sample-window mask: require sample(t) AND sample(t-1..t-p) all true,
    % so the regression uses only t's where both LHS and all lags are
    % marked active in the input mask.
    sample_window = sample;
    for j = 1:p
        sample_window = sample_window & [false(j,1); sample(1:end-j)];
    end

    % Final keep: in-window AND finite Y AND finite all of X's columns.
    good = sample_window & isfinite(Y) & all(isfinite(X), 2);
    Yg = Y(good);
    Xg = X(good, :);

    if isempty(Yg) || size(Xg,1) <= size(Xg,2)
        error('No usable observations in AR level shock extraction for %s.', x_name);
    end

    % OLS via backslash. Numerically stable enough for AR(small p).
    b = Xg \ Yg;
    yhat = Xg * b;
    resid = Yg - yhat;

    % Place the residuals back at their original time indices; rest is NaN.
    innov = nan(T, 1);
    innov(good) = resid;

    % Coefficient of determination (NaN if degenerate variance).
    ssr = sum(resid.^2);
    sst = sum((Yg - mean(Yg)).^2);
    if sst > 0
        R2 = 1 - ssr/sst;
    else
        R2 = NaN;
    end

    % Diagnostic bundle returned alongside the innovation series.
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

%% (4) Z-score x using the mean and s.d. ---------------------------------
% Z-score x using the mean and s.d. computed only over positions
% where `sample` is true and x is finite. Out-of-window values pass
% through the same affine transform but are NOT used to compute mu/sd.
%
% If the in-sample s.d. is zero or non-finite, the function returns
% the unstandardised series and emits a warning.

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

%% (5) Estimate level-change LP for ONE outcome × ONE shock --------------
% Run the level-change Local Projection at every horizon h = 0..H, for
% ONE outcome and ONE shock series. Each horizon is a separate OLS with
% Newey-West (Bartlett) HAC standard errors.
%
% Model at horizon h:
%   y_{t+h} - y_{t-1} = alpha + beta * z_t + Phi(L) y + Gamma(L) GPR
%                       + Delta(L) controls + e_{t+h}
%
% Inputs:
%   y         : T-by-1 outcome (level).
%   z         : T-by-1 standardised shock.
%   gpr_level : T-by-1 raw GPR level whose lags enter as controls.
%   controls  : T-by-nC additional macro controls; lags also enter.
%   sample    : T-by-1 logical mask.
%   cfg       : settings struct (uses H, p_lp, ci, shock_size).
%   y_label   : human-readable label, stored in res.label.
%   shock_tag : 'world' / 'threat' / 'act'.
%
% Output:
%   res : struct with fields h, beta, se, lb, ub, nobs, debug,
%         label, shock_tag, response_ylabel, table.

function res = estimate_lp_level_change_single_shock(y, z, gpr_level, controls, sample, cfg, y_label, shock_tag)

    H = cfg.H;
    % Two-sided z critical value for the requested confidence level.
    zcrit = norminv(0.5 + cfg.ci/2);

    % Pre-allocate per-horizon arrays. NaN signals "horizon dropped".
    beta = nan(H+1,1);
    se   = nan(H+1,1);
    lb   = nan(H+1,1);
    ub   = nan(H+1,1);
    nobs = nan(H+1,1);

    % Per-horizon debug counts (sample / NaN diagnostics).
    dbg_list = cell(H+1,1);

    for h = 0:H
        % Build the design matrix for this horizon. Y = y_{t+h} - y_{t-1};
        % X = [const, z_t, y-lags, GPR-lags, control-lags].
        [Y, X, ~, dbg] = build_lp_level_change_design(y, z, gpr_level, controls, sample, cfg.p_lp, h);
        dbg_list{h+1} = dbg;

        % Skip if too few observations to identify the regression.
        if isempty(Y) || size(X,1) <= size(X,2)
            continue;
        end

        % HAC bandwidth: Lazarus, Lewis, Stock & Watson (2018, JBES) rule
        % for the Bartlett kernel: S = ceil(1.3 * T^{1/2}). At typical
        % macro sample sizes this exceeds both Stock-Watson (2010) and
        % the h+1 truncation rules, dampening size distortions in HAR
        % inference at the cost of some power. Capped at n-1 for safety.
        n_lp = size(X,1);
        bw = min(max(ceil(1.3 * sqrt(n_lp)), 1), n_lp - 1);

        % OLS + NW-HAC standard errors.
        [b, se_all] = ols_hac(Y, X, bw);

        % Column 2 of X is the shock z_t, so b(2)/se_all(2) is beta_h / se_h.
        beta(h+1) = cfg.shock_size * b(2);
        se(h+1)   = cfg.shock_size * se_all(2);
        lb(h+1)   = beta(h+1) - zcrit * se(h+1);
        ub(h+1)   = beta(h+1) + zcrit * se(h+1);
        nobs(h+1) = size(X,1);
    end

    % Pack everything into a struct + a matching wide-format table.
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

%% (6) Build (Y, X) for one horizon of the level-change LP ---------------
% Construct the design matrix and outcome vector for ONE horizon h of
% the level-change LP. Vectorised entirely via lagmatrix to avoid the
% row-by-row scalar fill that dominated the original code.
%
% Row t (kept only for valid t) contains:
%   Y(t) = y_{t+h} - y_{t-1}
%   X(t) = [1, z_t, y_{t-1..t-p}, GPR_{t-1..t-p}, controls_{t-1..t-p}]
%
% Inputs:
%   y, z, gpr_level : T-by-1 series.
%   controls        : T-by-nC matrix (nC = number of macro controls).
%   sample          : T-by-1 logical mask.
%   p               : LP lag order.
%   h               : current horizon (>= 0).
%
% Outputs:
%   Y    : (#good)-by-1 outcome vector.
%   X    : (#good)-by-(2 + p + p + p*nC) regressor matrix.
%   good : T-by-1 logical, the rows kept.
%   dbg  : struct counting how many observations survive each filter,
%          useful for diagnosing why a horizon was dropped.

function [Y, X, good, dbg] = build_lp_level_change_design(y, z, gpr_level, controls, sample, p, h)

    y = y(:);
    z = z(:);
    gpr_level = gpr_level(:);
    sample = sample(:);
    T = length(y);

    if isempty(controls)
        controls = zeros(T,0);
    end
    nC = size(controls,2);

    % Build all lag blocks at once. Per code/lagmatrix.m, for a matrix
    % input with lags = 1:p, the result groups columns by lag:
    %   cols 1..nC      = controls(t-1, :)
    %   cols nC+1..2nC  = controls(t-2, :)  ...
    % which matches the original packing of one inner-j loop per lag.
    Ylag = lagmatrix(y, 1:p);              % T x p
    Glag = lagmatrix(gpr_level, 1:p);      % T x p
    if nC > 0
        Clag = lagmatrix(controls, 1:p);   % T x (p*nC)
    else
        Clag = zeros(T, 0);
    end

    % Forward outcome y_{t+h} aligned to row t. y(t-1) via lagmatrix(y,1).
    % The same indexing covers h == 0 (Yfwd(1:T) = y(1:T)) and h > 0.
    Yfwd = nan(T, 1);
    Yfwd(1:T-h) = y(1+h:end);
    Y0 = Yfwd - lagmatrix(y, 1);

    % Regressor block ordering: const, z_t, y-lags, GPR-lags, control lags.
    % NOTE: there are NO lagged z values in X by design (see header).
    X0 = [ones(T,1), z, Ylag, Glag, Clag];

    % Sample-window mask: sample(t) AND sample(t-1..t-p) AND sample(t+h).
    sample_window = sample;
    for j = 1:p
        sample_window = sample_window & [false(j,1); sample(1:end-j)];
    end
    if h == 0
        sample_fwd = sample;
    else
        % sample at t+h (forward shift): rows 1..T-h carry sample(1+h..T),
        % the last h rows are forced false because t+h falls off the end.
        sample_fwd = [sample(1+h:end); false(h,1)];
    end
    sample_ok = sample_window & sample_fwd;

    % Time-index validity: t must have p preceding rows AND h trailing
    % rows. This is the t_grid = (p+1):(T-h) of the original loop.
    t_valid = false(T, 1);
    t_valid(p+1 : T-h) = true;

    % Componentwise finiteness checks (all same length T).
    y_ok       = isfinite(Y0);
    z_ok       = isfinite(z);
    ylags_ok   = all(isfinite(Ylag), 2);
    gprlags_ok = all(isfinite(Glag), 2);
    if nC > 0
        controls_ok = all(isfinite(Clag), 2);
    else
        controls_ok = true(T, 1);
    end

    % Final mask: time valid AND in-sample AND every needed entry finite.
    good = t_valid & sample_ok & y_ok & z_ok & ylags_ok & gprlags_ok ...
        & controls_ok & all(isfinite(X0), 2);
    Y = Y0(good);
    X = X0(good, :);

    % Step-by-step retention counts to help diagnose dropped horizons.
    dbg = struct();
    dbg.n_candidate = sum(t_valid);
    dbg.sample_ok   = sum(t_valid & sample_ok);
    dbg.y_ok        = sum(t_valid & y_ok);
    dbg.z_ok        = sum(t_valid & z_ok);
    dbg.ylags_ok    = sum(t_valid & ylags_ok);
    dbg.gprlags_ok  = sum(t_valid & gprlags_ok);
    dbg.controls_ok = sum(t_valid & controls_ok);
    dbg.final_good  = sum(good);
end

%% (7) OLS with Newey-West (Bartlett) HAC standard errors ----------------
% Thin wrapper around MATLAB's hac() (Econometrics Toolbox). The signature
% [b, se, V] is preserved so callers do not change.
%
% Specification:
%   - kernel    : Bartlett ('weights','BT'), the Newey-West (1987) weight
%   - bandwidth : user-supplied truncation lag (clamped to [0, n-1])
%   - intercept : caller already includes a constant column in X, so we
%                 pass 'intercept', false to keep coefficient indexing
%   - smallT    : true -> applies the n/(n-k) finite-sample correction
%
% Inputs:
%   y  : n-by-1 dependent variable.
%   X  : n-by-k regressor matrix including a constant column.
%   bw : non-negative integer Bartlett truncation lag.
%
% Outputs:
%   b  : k-by-1 OLS coefficients.
%   se : k-by-1 HAC standard errors.
%   V  : k-by-k HAC covariance matrix.

function [b, se, V] = ols_hac(y, X, bw)

    [n, k] = size(X);
    if n <= k
        error('Not enough observations: n=%d, k=%d', n, k);
    end

    % Clamp bandwidth to [0, n-1].
    bw = min(max(bw, 0), n - 1);

    % hac() returns [EstCov, se, coeff]; reorder to [b, se, V].
    [V, se, b] = hac(X, y, ...
        'type',      'HAC',  ...
        'weights',   'BT',   ...
        'bandwidth', bw,     ...
        'intercept', false,  ...
        'smallT',    true,   ...
        'display',   'off');
end

%% (8) Print per-outcome LP diagnostics to the console -------------------
% Console summary for one outcome: how many horizons produced finite
% beta, the contemporaneous (h=0) sample size, and beta at h=0 and h=4.
%
% Inputs:
%   rw  : World-shock result struct  (output of estimate_lp_*).
%   rt  : Threat-shock result struct.
%   ra  : Act-shock result struct.
%   cfg : settings struct (uses H).
%
% Output:
%   (none) — writes to stdout.

function print_lp_check(rw, rt, ra, cfg)

    fprintf('  World: finite beta=%2d/%2d, nobs h0=%3.0f, beta h0=% .4f, beta h4=% .4f\n', ...
        sum(isfinite(rw.beta)), cfg.H+1, rw.nobs(1), get_beta_at_h(rw,0), get_beta_at_h(rw,4));
    fprintf('  Threat: finite beta=%2d/%2d, nobs h0=%3.0f, beta h0=% .4f, beta h4=% .4f\n', ...
        sum(isfinite(rt.beta)), cfg.H+1, rt.nobs(1), get_beta_at_h(rt,0), get_beta_at_h(rt,4));
    fprintf('  Act:    finite beta=%2d/%2d, nobs h0=%3.0f, beta h0=% .4f, beta h4=% .4f\n', ...
        sum(isfinite(ra.beta)), cfg.H+1, ra.nobs(1), get_beta_at_h(ra,0), get_beta_at_h(ra,4));
end

function b = get_beta_at_h(res, hval)
    % Look up the IRF value at horizon hval. Returns NaN when the horizon
    % is missing from res.h (e.g. the LP for that horizon was dropped).
    idx = find(res.h == hval, 1);
    if isempty(idx)
        b = NaN;
    else
        b = res.beta(idx);
    end
end

%% (9) Render two-column IRF figures (left=World, right=Threat/Act) -------
% Render IRFs as a sequence of figures, each laid out as a
% rows_per_figure × 2 tile grid. Left tile = World shock IRF; right
% tile = Threat and Act IRFs overlaid. Confidence-band fills come from
% plot_one_irf_with_ci (helper (10)).
%
% Inputs:
%   results_world / threat / act : structs keyed by outcome id.
%   outcome_ids / outcome_labels : same-length cell arrays of names and labels.
%   cfg : reads H, rows_per_figure, horizon_label, output_dir,
%         show_figures, save_figures, figure_file_1, figure_file_2.
%
% Output:
%   figure_files : cell array of figure paths (filled even when not saved).

function figure_files = plot_part2_two_figures_splitwise_level(results_world, results_threat, results_act, outcome_ids, outcome_labels, cfg)

    n_outcomes = numel(outcome_ids);
    n_per_fig  = cfg.rows_per_figure;
    n_figs     = ceil(n_outcomes / n_per_fig);
    h          = 0:cfg.H;

    % CI fill colours: gray for World, light blue for Threat, light red for Act.
    world_fill_color  = [0.65 0.65 0.65];
    threat_fill_color = [0.76 0.86 1.00];
    act_fill_color    = [1.00 0.82 0.82];

    figure_files = cell(n_figs,1);

    for f = 1:n_figs
        % Outcome indices belonging to this figure.
        idx_start = (f-1)*n_per_fig + 1;
        idx_end   = min(f*n_per_fig, n_outcomes);
        these_idx = idx_start:idx_end;

        % Hidden figure when show_figures=false (still renderable to PNG).
        if cfg.show_figures
            fig = figure('Color', 'w', 'Position', [60, 40, 1500, 1600]);
        else
            fig = figure('Color', 'w', 'Position', [60, 40, 1500, 1600], 'Visible','off');
        end
        tl = tiledlayout(n_per_fig, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

        for local_i = 1:n_per_fig
            if local_i <= numel(these_idx)
                i = these_idx(local_i);

                % Left panel: World shock IRF only.
                nexttile; hold on;
                rw = results_world.(outcome_ids{i});
                plot_one_irf_with_ci(gca, h, rw, world_fill_color, 'k');
                plot(h, zeros(size(h)), 'k:', 'LineWidth', 1.0);
                xlim([0 cfg.H]); grid on; box on;
                title(['World: ', outcome_labels{i}], 'FontWeight', 'bold', 'Interpreter','none');
                xlabel(cfg.horizon_label);
                ylabel('Level change: y_{t+h}-y_{t-1}');

                % Right panel: Threat (blue) and Act (red) IRFs overlaid.
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
                % Legend only on the first outcome to avoid clutter.
                if i == 1
                    legend({'Threat CI', 'Threat', 'Act CI', 'Act', 'Zero'}, 'Location', 'best');
                end
            else
                % Empty trailing tiles: blank axes to preserve grid layout.
                ax1 = nexttile; axis(ax1, 'off');
                ax2 = nexttile; axis(ax2, 'off');
            end
        end

        % Figure-level title with the spec parameters embedded.
        title(tl, sprintf(['Part 2: Candidate Mechanism LEVEL LPs ', ...
            '(Figure %d of %d; shock size = %.1f s.d., p_{innov} = %d, p_{LP} = %d)'], ...
            f, n_figs, cfg.shock_size, cfg.p_innov, cfg.p_lp), ...
            'FontWeight', 'bold', 'FontSize', 14);

        drawnow;

        % Map figure index -> output path. Figures 3+ get an auto name.
        if f == 1
            file_out = cfg.figure_file_1;
        elseif f == 2
            file_out = cfg.figure_file_2;
        else
            file_out = fullfile(cfg.output_dir, sprintf('part2_mechanisms_level_splitwise_noVIXcontrol_fig%d.png', f));
        end

        % Prefer exportgraphics (newer); fall back to print on older MATLAB.
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

%% (10) Plot a single IRF point estimate with translucent CI band --------
% Plot a single IRF (point estimate) with a translucent CI band on the
% supplied axes. Used by helper (9) once per panel.
%
% Inputs:
%   ax         : target axes handle.
%   h          : 1-by-(H+1) horizon vector.
%   r          : result struct (fields beta, lb, ub).
%   fill_color : 1-by-3 RGB for the CI fill.
%   line_color : color spec for the IRF line.
%
% Behaviour:
%   - If every beta is NaN, draws a placeholder text and turns axes off.
%   - CI band is drawn only when at least 2 finite (lb, ub) pairs exist.
%
% Output:
%   (none) — draws into the provided axes.

function plot_one_irf_with_ci(ax, h, r, fill_color, line_color)

    finite_beta = isfinite(r.beta(:));
    finite_ci = isfinite(r.lb(:)) & isfinite(r.ub(:));

    if sum(finite_beta) == 0
        text(ax, 0.5, 0.5, 'All beta = NaN', 'HorizontalAlignment','center', ...
            'Units','normalized', 'FontWeight','bold');
        axis(ax, 'off');
        return;
    end

    % Translucent CI polygon (only at finite (lb, ub) horizons).
    if sum(finite_ci) >= 2
        hci = h(finite_ci);
        ub = r.ub(finite_ci)';
        lb = r.lb(finite_ci)';
        fill(ax, [hci, fliplr(hci)], [ub, fliplr(lb)], fill_color, ...
            'EdgeColor','none','FaceAlpha',0.50);
    end

    % Solid IRF line on top of the band.
    plot(ax, h(finite_beta), r.beta(finite_beta), '-', 'Color', line_color, 'LineWidth', 2.0);
end
