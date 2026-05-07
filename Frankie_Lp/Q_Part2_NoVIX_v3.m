%% =======================================================================
%% [PART 2 v3] Candidate mechanism LEVEL LPs using AR-only GPR innovations
%%             LP estimation routed through ir_jorda (./code/ir_jorda.m).
%%             SPLITWISE version, no VIX control.
%% -----------------------------------------------------------------------
% This is a re-spec of Q_Part2_NoVIX_v2.m: the manual horizon-by-horizon
% OLS+HAC has been replaced by a single call to ir_jorda per
% (outcome, shock) pair. Shock construction (AR(1) innovations on the
% log-GPR level, in-sample z-scored) is unchanged.
%
% Why ir_jorda and not v2's manual LP?
%   - Single canonical LP routine across the project (Part 3B already
%     uses it).
%   - Cleaner dependency: ir_jorda + lrv_nw live in ./code/.
%
% LP specification mapping (NOTE the small differences from v2):
%
%   v2 (manual): y_{t+h} - y_{t-1}
%                = alpha + beta_h * z_t
%                + Phi(L) y_{t-1..t-p}
%                + Gamma(L) GPR_{t-1..t-p}
%                + Delta(L) controls_{t-1..t-p} + e_{t+h}
%
%   v3 (ir_jorda, Jflag=1, I=p, J=0, level=1, controls pre-expanded
%       into p lag columns):
%                y_{t+h} - y_{t-1}
%                = alpha + beta_h * z_t              (NO lagged shocks)
%                + Phi(L) y_{t-1..t-p}               (same as v2)
%                + Delta(L) controls_{t-1..t-p}      (LAGGED ONLY, p lags)
%                + e_{t+h}
%
%   This is exactly the lecture-note LP variant (3) of Baek's slide deck
%   and matches v2's spec EXCEPT that the lagged GPR levels (Gamma(L)
%   block in v2) are dropped. So v3 == "v2 minus the Gamma(L) block",
%   delivered through the ir_jorda routine.
%
%   Notes on how the spec is achieved through ir_jorda:
%     1. CONTROL LAGS via EXTERNAL EXPANSION + J=0. Instead of letting
%        ir_jorda lag the controls internally (which couples shock and
%        control lag counts), we pre-expand the controls into p separate
%        lag columns BEFORE passing them in:
%            controls_expanded = lagmatrix(controls, 1:p)   % T x (p*nC)
%        Then ir_jorda is called with J = 0 so that:
%          - shock side : single column at lag h = z_t (NO lagged shocks)
%          - "control" side under Jflag=1 : single column at lag h of each
%            pre-expanded column. At row tau with t = tau - h, that gives
%            controls_{t-1..t-p}, exactly v2's 4-lag control structure.
%        Setting Jflag=0 was rejected because it leaves controls aligned
%        to OUTCOME time t+h (future leak for h > 0). Jflag=1 with J = 0
%        is the only configuration that simultaneously (a) excludes
%        contemporaneous controls, (b) keeps p control lags, and
%        (c) excludes lagged shocks.
%     2. LAGGED GPR LEVELS (the Gamma(L) block in v2) are DROPPED. Under
%        the AR(1) shock construction z_t = GPR_t - phi*GPR_{t-1} - const,
%        OLS first-order conditions imply z_t is in-sample orthogonal to
%        GPR_{t-1}, so the GPR(L) block in v2 was largely redundant for
%        identification of beta_h. If GPR is well approximated by AR(1),
%        higher GPR lags carry no extra information either. Dropping
%        Gamma(L) costs 4 degrees of freedom in v2; dropping it here is
%        statistically defensible.
%     3. CONTEMPORANEOUS CONTROLS ARE EXCLUDED. Per supervisor instruction
%        and the lecture-note LP variant (3), controls must enter only at
%        lags >= 1 to avoid bad-control bias (a contemporaneous response
%        of FFR_t / Unemp_t to z_t would absorb part of the causal
%        channel). The lag-expansion + J=0 trick above ensures this.
%     4. NO LAGGED SHOCKS, in line with the standard LP formula. Earlier
%        v3 drafts were forced to include lagged shocks because of an
%        I = J = p (or I = p, J = p - 1) choice. With J = 0 the shock
%        block collapses to z_t alone, matching v1/v2 and the lecture
%        slides.
%     5. HAC bandwidth is a single constant per call (ir_jorda restriction).
%        We use the Lazarus (2018) rule: bw = round(0.18 * n_eff).
%
% Outputs are written to a SEPARATE folder (cfg.output_dir =
% 'Part2_Mechanism_LevelLP_NoVIX_v3') so that v2 results are preserved.
%
% External dependencies:
%   - ir_jorda  : ./code/ir_jorda.m   (calls regress() internally)
%   - lrv_nw    : ./code/lrv_nw.m     (Bartlett HAC long-run variance)
%   - lagmatrix : Econometrics Toolbox
%   - norminv   : Statistics and Machine Learning Toolbox (unused here but
%                 kept in case CI logic is moved out of ir_jorda later)
%% =======================================================================


clear; clc; close all;

% Add local helpers folder; ir_jorda lives in ./code/.
this_dir = fileparts(mfilename('fullpath'));
if isempty(this_dir), this_dir = pwd; end
code_dir = fullfile(this_dir, 'code');
if exist(code_dir, 'dir')
    addpath(code_dir);
else
    warning('Local code/ folder not found at %s; ir_jorda may be unavailable.', code_dir);
end


%% (1) USER SETTINGS -----------------------------------------------------

% Data file
cfg.datafile          = 'Q_Levels_Database.mat';
cfg.fallback_datafile = 'Q_Levels_Database.csv';

% Lag orders and horizon
cfg.p_innov           = 1;       % AR(1) for extracting GPR innovations
cfg.p_lp              = 4;       % LP lags: passed to ir_jorda as I and J
cfg.H                 = 12;      % max horizon (quarters)
cfg.ci                = 0.90;    % CI for IRF bands (alpha argument of ir_jorda)
cfg.shock_size        = 1;       % response to a 1-s.d. shock
cfg.standardize_innov = true;    % z = AR residual / in-sample s.d.

% Bandwidth rule for the single L_NW passed to ir_jorda.
%   'lazarus2018': bw = round(0.18 * n_eff)
%   'newey-west' : bw = max(H, ceil(1.3 * sqrt(n_eff)))
cfg.bandwidth_rule    = 'lazarus2018';

% Output behaviour. Written to a v3-specific folder so v2 outputs stay.
cfg.save_results      = false;
cfg.save_figures      = true;
cfg.show_figures      = true;
cfg.rows_per_figure   = 5;
cfg.horizon_label     = 'Horizon (quarters)';
cfg.output_dir        = 'Part2_Mechanism_LevelLP_NoVIX_v3';

cfg.innov_file        = fullfile(cfg.output_dir, 'gpr_innovations_part2_v3.csv');
cfg.results_file      = fullfile(cfg.output_dir, 'part2_mechanism_level_lp_results_v3.csv');
cfg.figure_file_1     = fullfile(cfg.output_dir, 'Part2_v3_Figure1.png');
cfg.figure_file_2     = fullfile(cfg.output_dir, 'Part2_v3_Figure2.png');

if cfg.save_results || cfg.save_figures
    if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
end

% Console banner
fprintf('\n=== Part 2 v3 LEVEL LP via ir_jorda, splitwise, no VIX control ===\n');
fprintf('Specification: y_{t+h} - y_{t-1} on z_t (current shock only, no lagged shocks), y-lags (1..%d), controls (lags only, t-1..t-%d).\n', ...
    cfg.p_lp, cfg.p_lp);
fprintf('AR p_innov=%d; LP p=%d; horizon=0:%d; shock size=%.2f s.d.; bandwidth rule=%s\n', ...
    cfg.p_innov, cfg.p_lp, cfg.H, cfg.shock_size, cfg.bandwidth_rule);


%% (2) LOAD LEVEL DATABASE -----------------------------------------------

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
    error('Data file not found: neither %s nor %s.', cfg.datafile, cfg.fallback_datafile);
end
T = height(DB);
varnames = DB.Properties.VariableNames;
fprintf('Data file used: %s\n', datafile_used);
fprintf('Loaded rows T = %d, variables = %d\n', T, numel(varnames));

[quarter_labels, has_quarter] = get_quarter_labels(DB, T);
if has_quarter
    fprintf('Sample starts at %s and ends at %s\n', quarter_labels{1}, quarter_labels{end});
end

sample = true(T,1);
fprintf('Using full sample: %d / %d rows are active.\n', sum(sample), T);


%% (3) CONTROLS: NO VIX CONTROL ------------------------------------------
% [Unemp, FFR]; passed UNLAGGED at this stage. estimate_lp_via_ir_jorda
% pre-expands them into p separate lag columns (lagmatrix(., 1:p)) and
% calls ir_jorda with J=0 so that the regression contains controls at
% lags t-1..t-p only (no contemporaneous controls, no lagged shocks).
% See header note 1.

controls      = [DB.Unemp, DB.FFR];
control_names = {'Unemp', 'FFR'};

fprintf('\nControls loaded, excluding VIX by design:\n');
for j = 1:numel(control_names)
    fprintf('  Control %-12s finite = %3d / %3d\n', ...
        control_names{j}, sum(isfinite(controls(:,j))), T);
end


%% (4) OUTCOME SERIES ----------------------------------------------------

lnVIX = log(max(DB.VOX, 1e-8));

outcome_ids = {'Real_WTI','Real_Gasoline','MICH','SPF_inf', ...
               'Two_PH_SPF_Inf','r_c','r_i','r_y','lnVIX'};

outcome_labels = { ...
    'Real WTI crude oil price', ...
    'Real gasoline price', ...
    'Michigan expected inflation', ...
    'SPF expected inflation (current)', ...
    'SPF expected inflation (2-step ahead)', ...
    'Real consumption level', ...
    'Real investment level', ...
    'Real GDP level', ...
    'log(VIX/VOX)' };


%% (5) CONSTRUCT STANDARDIZED GPR SHOCKS ---------------------------------
% Identical to v2: AR(p_innov) residual on the log-GPR level,
% in-sample z-scored.

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

fprintf('\n--- GPR innovation checks ---\n');
fprintf('World : AR nobs=%3d, R2=% .3f, finite z=%3d\n', fs_world.nobs,  fs_world.R2,  sum(isfinite(z_world)));
fprintf('Threat: AR nobs=%3d, R2=% .3f, finite z=%3d\n', fs_threat.nobs, fs_threat.R2, sum(isfinite(z_threat)));
fprintf('Act   : AR nobs=%3d, R2=% .3f, finite z=%3d\n', fs_act.nobs,    fs_act.R2,    sum(isfinite(z_act)));


%% (6) ESTIMATE LEVEL LOCAL PROJECTIONS (via ir_jorda) -------------------

results_world  = struct();
results_threat = struct();
results_act    = struct();
level_lp_results = table();

fprintf('\n--- Estimating Part 2 v3 level LPs via ir_jorda ---\n');
for i = 1:numel(outcome_ids)
    yid = outcome_ids{i};
    ylabel = outcome_labels{i};

    if strcmp(yid, 'lnVIX')
        y = lnVIX;
    else
        y = DB.(yid);
    end

    fprintf('\nOutcome: %s\n', ylabel);
    fprintf('  finite y = %3d / %3d\n', sum(isfinite(y)), T);

    % Three independent splitwise LPs, one per shock series.
    results_world.(yid) = estimate_lp_via_ir_jorda( ...
        y, z_world, controls, sample, cfg, ylabel, 'world');

    results_threat.(yid) = estimate_lp_via_ir_jorda( ...
        y, z_threat, controls, sample, cfg, ylabel, 'threat');

    results_act.(yid) = estimate_lp_via_ir_jorda( ...
        y, z_act, controls, sample, cfg, ylabel, 'act');

    results_world.(yid).controls  = control_names;
    results_threat.(yid).controls = control_names;
    results_act.(yid).controls    = control_names;

    print_lp_check(results_world.(yid), results_threat.(yid), results_act.(yid), cfg);

    tmpW = results_world.(yid).table;  tmpW.shock = repmat("world", height(tmpW), 1);
    tmpT = results_threat.(yid).table; tmpT.shock = repmat("threat", height(tmpT), 1);
    tmpA = results_act.(yid).table;    tmpA.shock = repmat("act", height(tmpA), 1);
    tmp = [tmpW; tmpT; tmpA];
    tmp.outcome = repmat(string(yid), height(tmp), 1);
    tmp.outcome_label = repmat(string(ylabel), height(tmp), 1);
    tmp.specification = repmat("level_change_y_tph_minus_y_tm1_ir_jorda", height(tmp), 1);
    level_lp_results = [level_lp_results; tmp]; %#ok<AGROW>
end

figure_files = plot_part2_two_figures_splitwise_level( ...
    results_world, results_threat, results_act, outcome_ids, outcome_labels, cfg);


%% OPTIONAL SAVE ---------------------------------------------------------

if cfg.save_results
    innovations = table( ...
        string({'world';'threat';'act'}), ...
        [fs_world.nobs; fs_threat.nobs; fs_act.nobs], ...
        [fs_world.R2; fs_threat.R2; fs_act.R2], ...
        [sum(isfinite(z_world)); sum(isfinite(z_threat)); sum(isfinite(z_act))], ...
        'VariableNames', {'shock','ar_nobs','ar_R2','finite_z'});
    writetable(innovations, cfg.innov_file);
    writetable(level_lp_results, cfg.results_file);
    save(fullfile(cfg.output_dir, 'part2_v3_workspace.mat'), ...
        'cfg','results_world','results_threat','results_act','level_lp_results', ...
        'z_world','z_threat','z_act','fs_world','fs_threat','fs_act', ...
        'control_names','figure_files');
    fprintf('\nSaved results to %s\n', cfg.output_dir);
else
    fprintf('\nNo result tables saved because cfg.save_results=false.\n');
end


%% =======================================================================
%% Helper Functions
%% =======================================================================

%% (1) Load a MATLAB table out of a .mat file ----------------------------
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
    error('No table found inside %s. Top-level variables: %s', ...
        matfile, strjoin(fnames, ', '));
end


%% (2) Best-effort quarter-label extraction -----------------------------
function [quarter_labels, has_quarter] = get_quarter_labels(DB, T)
    quarter_labels = repmat({''}, T, 1);
    has_quarter = false;
    names = DB.Properties.VariableNames;
    idx = find(strcmpi(names,'quarter') | strcmpi(names,'date'), 1);
    if isempty(idx), return; end
    q = DB.(names{idx});
    has_quarter = true;
    if iscell(q)
        quarter_labels = q(:);
    else
        quarter_labels = cellstr(string(q(:)));
    end
end


%% (3) AR(p) innovation on a level series -------------------------------
% Identical to v2's extract_ar_level_innovation.
function [innov, info] = extract_ar_level_innovation(x, sample, p, x_name)
    x = x(:); sample = sample(:); T = length(x);

    Xlags = lagmatrix(x, 1:p);
    X = [ones(T,1), Xlags];
    Y = x;

    sample_window = sample;
    for j = 1:p
        sample_window = sample_window & [false(j,1); sample(1:end-j)];
    end

    good = sample_window & isfinite(Y) & all(isfinite(X), 2);
    Yg = Y(good); Xg = X(good, :);

    if isempty(Yg) || size(Xg,1) <= size(Xg,2)
        error('No usable observations in AR level shock extraction for %s.', x_name);
    end

    b = Xg \ Yg;
    yhat = Xg * b;
    resid = Yg - yhat;

    innov = nan(T, 1);
    innov(good) = resid;

    ssr = sum(resid.^2);
    sst = sum((Yg - mean(Yg)).^2);
    R2 = 1 - ssr/sst;

    info = struct('name',x_name,'p',p,'nobs',numel(Yg), ...
        'beta',b,'fitted',yhat,'resid',resid, ...
        't_index',find(good),'R2',R2);
end


%% (4) In-sample z-score ------------------------------------------------
function z = zscore_in_sample(x, sample)
    x = x(:); use = sample & isfinite(x);
    mu = mean(x(use)); sd = std(x(use));
    if ~isfinite(sd) || sd == 0
        warning('Shock standard deviation is zero or invalid.');
        z = x;
    else
        z = (x - mu) ./ sd;
    end
end


%% (5) Estimate level-change LP via ir_jorda for ONE outcome x shock ----
% Wraps ir_jorda(level=1, Jflag=1, J=0) and supplies controls already
% expanded into p separate lag columns. See file header for the spec
% mapping vs v2's manual LP.
%
% Inputs:
%   y         : T-by-1 outcome (level).
%   z         : T-by-1 standardised shock (current value enters X col 1).
%   controls  : T-by-nC macro controls, passed UNLAGGED. They are
%               expanded into p lag columns inside this function via
%               lagmatrix(controls, 1:p) before being handed to ir_jorda.
%               Combined with J = 0 in ir_jorda, the resulting regression
%               contains controls only at lags t-1..t-p (exactly p lags
%               per control), with NO contemporaneous controls_t and NO
%               lagged shocks. See header notes 1, 3, 4.
%   sample    : T-by-1 logical mask.
%   cfg       : settings struct (uses H, p_lp, ci, shock_size, bandwidth_rule).
%   y_label   : human-readable label.
%   shock_tag : 'world' / 'threat' / 'act'.
%
% Output:
%   res : struct with same fields as v2's output (h, beta, se, lb, ub,
%         nobs, label, shock_tag, response_ylabel, table).

function res = estimate_lp_via_ir_jorda(y, z, controls, sample, cfg, y_label, shock_tag)

    H = cfg.H;
    p = cfg.p_lp;

    % Pre-allocate so we can return early on empty input.
    beta = nan(H+1,1);
    se   = nan(H+1,1);
    lb   = nan(H+1,1);
    ub   = nan(H+1,1);
    nobs = nan(H+1,1);

    % Build X: col 1 = shock, cols 2..end = controls EXPANDED into p
    % separate lag columns. With J = 0 in ir_jorda, each pre-expanded
    % column will be picked up at "lag 0" relative to the shock-time
    % alignment; i.e., the column that holds c_{tau-k} at original row
    % tau will appear in the design as c_{(tau-h)-k} = c_{t-k}. So
    % the resulting design matrix contains controls at lags t-1..t-p
    % and NO lagged shocks.
    z = z(:);
    controls_expanded = lagmatrix(controls, 1:p);   % T x (p * nC)
    X = [z, controls_expanded];

    % Trim to the largest contiguous in-sample block. ir_jorda's HAC
    % variance is computed on the full reg_X before listwise deletion,
    % so internal NaNs poison SigmaX (Part 3B comment). The lag
    % expansion above injects NaN rows at t = 1..p, which `use` will
    % exclude — so the effective sample begins at t = p + 1.
    use       = sample(:) & isfinite(y(:)) & all(isfinite(X), 2);
    first_use = find(use, 1, 'first');
    last_use  = find(use, 1, 'last');

    if isempty(first_use) || (last_use - first_use + 1) <= (2*p + 2)
        warning('Insufficient contiguous data for %s | %s; returning NaN IRF.', ...
            y_label, shock_tag);
        res = pack_lp_result(y_label, shock_tag, beta, se, lb, ub, nobs, H);
        return;
    end

    y_block = y(first_use:last_use);
    X_block = X(first_use:last_use, :);
    n_eff   = numel(y_block);

    % Inner-NaN guard (should not trigger if `use` is contiguous).
    if any(~isfinite(y_block)) || any(any(~isfinite(X_block)))
        warning('Internal NaNs after trim for %s | %s; HAC may be unreliable.', ...
            y_label, shock_tag);
    end

    % HAC bandwidth (single value for all horizons).
    bw = pick_bandwidth(cfg.bandwidth_rule, H, n_eff);
    bw = max(min(bw, n_eff - 1), 0);

    % Single ir_jorda call returns IRF for h = 0..H.
    %   y         : level outcome
    %   X         : [shock, expanded controls c_{tau-1..tau-p}]
    %   I = p     : own-lags of y (t-1..t-p), matches v2.
    %   J = 0     : single column at lag h for the shock AND for each
    %               pre-expanded control column.
    %                 - shock  : z_t (NO lagged shocks).
    %                 - controls : the k-th pre-expanded column lands as
    %                              c_{t-k}, giving c_{t-1..t-p} overall.
    %   Jflag = 1 : same lag-h alignment applied to the control block,
    %               required for the shock-time alignment of controls.
    %   level = 1 : I(0) RHS (lags of y in levels)
    %   trend = 0 : constant only
    %   IC    = 0 : unused (scalar I, J)
    try
        [imp, cb, ~, ~, ~, sd] = ir_jorda( ...
            y_block, X_block, ...
            p, 0, 1, 1, ...
            H, cfg.ci, 0, 0, bw);
    catch ME
        warning('ir_jorda failed for %s | %s: %s', y_label, shock_tag, ME.message);
        res = pack_lp_result(y_label, shock_tag, beta, se, lb, ub, nobs, H);
        return;
    end

    % Scale to a cfg.shock_size-sigma shock.
    beta = imp(:) * cfg.shock_size;
    se   = sd(:)  * cfg.shock_size;
    lb   = cb(:,1) * cfg.shock_size;
    ub   = cb(:,2) * cfg.shock_size;

    % Approximate per-horizon nobs: ir_jorda drops max(I, J) + h rows
    % from the head at horizon h. With I = p and J = 0, max(I, J) = p.
    L_head = max(p, 0);    % = p here
    nobs   = max(n_eff - L_head - (0:H)', 0);

    res = pack_lp_result(y_label, shock_tag, beta, se, lb, ub, nobs, H);
end


%% (6) Pack LP outputs into a result struct + table ---------------------
function res = pack_lp_result(y_label, shock_tag, beta, se, lb, ub, nobs, H)
    res = struct();
    res.label           = y_label;
    res.shock_tag       = shock_tag;
    res.h               = (0:H)';
    res.beta            = beta;
    res.se              = se;
    res.lb              = lb;
    res.ub              = ub;
    res.nobs            = nobs;
    res.response_ylabel = 'Level change: y_{t+h} - y_{t-1}';
    res.table = table((0:H)', beta, se, lb, ub, nobs, ...
        'VariableNames', {'h','beta','se','lb','ub','nobs'});
end


%% (7) HAC bandwidth picker ---------------------------------------------
function bw = pick_bandwidth(rule, H, n_eff)
    switch lower(rule)
        case 'lazarus2018'
            bw = round(0.18 * n_eff);
        case 'newey-west'
            bw = max(H, ceil(1.3 * sqrt(n_eff)));
        otherwise
            warning('Unknown bandwidth rule %s; falling back to lazarus2018.', rule);
            bw = round(0.18 * n_eff);
    end
end


%% (8) Console diagnostic per outcome -----------------------------------
function print_lp_check(rw, rt, ra, cfg)
    fprintf('  World:  finite beta=%2d/%2d, nobs h0=%3.0f, beta h0=% .4f, beta h4=% .4f\n', ...
        sum(isfinite(rw.beta)), cfg.H+1, rw.nobs(1), get_beta_at_h(rw,0), get_beta_at_h(rw,4));
    fprintf('  Threat: finite beta=%2d/%2d, nobs h0=%3.0f, beta h0=% .4f, beta h4=% .4f\n', ...
        sum(isfinite(rt.beta)), cfg.H+1, rt.nobs(1), get_beta_at_h(rt,0), get_beta_at_h(rt,4));
    fprintf('  Act:    finite beta=%2d/%2d, nobs h0=%3.0f, beta h0=% .4f, beta h4=% .4f\n', ...
        sum(isfinite(ra.beta)), cfg.H+1, ra.nobs(1), get_beta_at_h(ra,0), get_beta_at_h(ra,4));
end


function b = get_beta_at_h(res, hval)
    idx = find(res.h == hval, 1);
    if isempty(idx), b = NaN; else, b = res.beta(idx); end
end


%% (9) Two-figure plot (left=World, right=Threat/Act) -------------------
% Identical to v2's plotting helper; only the figure-title prefix is
% updated to flag the v3 spec.
function figure_files = plot_part2_two_figures_splitwise_level( ...
        results_world, results_threat, results_act, outcome_ids, outcome_labels, cfg)

    n_outcomes = numel(outcome_ids);
    n_per_fig  = cfg.rows_per_figure;
    n_figs     = ceil(n_outcomes / n_per_fig);
    h          = 0:cfg.H;

    world_fill_color  = [0.65 0.65 0.65];
    threat_fill_color = [0.76 0.86 1.00];
    act_fill_color    = [1.00 0.82 0.82];

    figure_files = cell(n_figs,1);

    for f = 1:n_figs
        idx_start = (f-1)*n_per_fig + 1;
        idx_end   = min(f*n_per_fig, n_outcomes);
        these_idx = idx_start:idx_end;

        if cfg.show_figures
            fig = figure('Color','w','Position',[60, 40, 1500, 1600]);
        else
            fig = figure('Color','w','Position',[60, 40, 1500, 1600],'Visible','off');
        end
        tl = tiledlayout(n_per_fig, 2, 'TileSpacing','compact','Padding','compact');

        for local_i = 1:n_per_fig
            if local_i <= numel(these_idx)
                i = these_idx(local_i);

                nexttile; hold on;
                rw = results_world.(outcome_ids{i});
                plot_one_irf_with_ci(gca, h, rw, world_fill_color, 'k');
                plot(h, zeros(size(h)), 'k:', 'LineWidth', 1.0);
                xlim([0 cfg.H]); grid on; box on;
                title(['World: ', outcome_labels{i}], 'FontWeight','bold','Interpreter','none');
                xlabel(cfg.horizon_label);
                ylabel('Level change: y_{t+h}-y_{t-1}');

                nexttile; hold on;
                rt = results_threat.(outcome_ids{i});
                ra = results_act.(outcome_ids{i});
                plot_one_irf_with_ci(gca, h, rt, threat_fill_color, 'b');
                plot_one_irf_with_ci(gca, h, ra, act_fill_color, 'r');
                plot(h, zeros(size(h)), 'k:', 'LineWidth', 1.0);
                xlim([0 cfg.H]); grid on; box on;
                title(['Threat / Act: ', outcome_labels{i}], 'FontWeight','bold','Interpreter','none');
                xlabel(cfg.horizon_label);
                ylabel('Level change: y_{t+h}-y_{t-1}');
                if i == 1
                    legend({'Threat CI','Threat','Act CI','Act','Zero'}, 'Location','best');
                end
            else
                ax1 = nexttile; axis(ax1,'off');
                ax2 = nexttile; axis(ax2,'off');
            end
        end

        title(tl, sprintf(['Part 2 v3 (ir\\_jorda): Mechanism LEVEL LPs ', ...
            '(Figure %d of %d; shock = %.1f s.d., p_{innov} = %d, p_{LP} = %d, bw = %s)'], ...
            f, n_figs, cfg.shock_size, cfg.p_innov, cfg.p_lp, cfg.bandwidth_rule), ...
            'FontWeight','bold','FontSize',14);

        drawnow;

        if f == 1
            file_out = cfg.figure_file_1;
        elseif f == 2
            file_out = cfg.figure_file_2;
        else
            file_out = fullfile(cfg.output_dir, ...
                sprintf('Part2_v3_Figure%d.png', f));
        end

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


%% (10) Plot a single IRF with translucent CI band ---------------------
function plot_one_irf_with_ci(ax, h, r, fill_color, line_color)

    finite_beta = isfinite(r.beta(:));
    finite_ci = isfinite(r.lb(:)) & isfinite(r.ub(:));

    if sum(finite_beta) == 0
        text(ax, 0.5, 0.5, 'All beta = NaN', 'HorizontalAlignment','center', ...
            'Units','normalized','FontWeight','bold');
        axis(ax,'off');
        return;
    end

    if sum(finite_ci) >= 2
        hci = h(finite_ci);
        ub = r.ub(finite_ci)';
        lb = r.lb(finite_ci)';
        fill(ax, [hci, fliplr(hci)], [ub, fliplr(lb)], fill_color, ...
            'EdgeColor','none','FaceAlpha',0.50);
    end

    plot(ax, h(finite_beta), r.beta(finite_beta), '-', ...
        'Color', line_color, 'LineWidth', 2.0);
end
