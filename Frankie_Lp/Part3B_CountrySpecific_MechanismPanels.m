clear; clc; close all;
%% ============================================================
% PART 3 REDESIGNED: GPR AND OIL-MARKET SUPPLY-RISK TRANSMISSION
% Standalone file generated from the 9-panel redesigned master script.
%
% Required database:
%   Q_Part3_Database.mat
% CSV fallback:
%   Q_Part3_Database.csv
%
% Each figure uses 9 subplots:
%   World, Threat, Act, US, Israel, Russia, China, Venezuela, SaudiArabia
%% ============================================================

%% -------------------- USER SETTINGS --------------------
cfg.output_dir   = 'Part3B_MechanismResponses_AugmentedShock_Cumulative_9Panel';
cfg.datafile     = 'Q_Part3_Database.mat';
cfg.csv_fallback = 'Q_Part3_Database.csv';

cfg.p_innov = 1;
cfg.standardize_innov = true;

% Shock extraction mode.
%   'augmented' : baseline choice; removes predictability from lagged oil/macro variables.
%   'original'  : original univariate AR residual shock.
cfg.shock_extraction_mode = 'augmented';

% Number of lags of oil-market and macro variables used in the augmented GPR forecasting equation.
cfg.p_aug = 4;

% Predictor variables used to orthogonalize GPR innovations.
% Missing variables are skipped automatically.
cfg.aug_predictor_specs = {
    'g_Brent',       {'g_Brent'},       'Brent price growth';
    'g_WTI_Cru',     {'g_WTI_Cru'},     'WTI crude-oil price growth';
    'g_Gaso',        {'g_Gaso'},        'Gasoline price growth';
    'g_WorldCP',     {'g_WorldCP'},     'World crude-oil production growth';
    'g_MEastCP',     {'g_MEastCP'},     'Middle East crude-oil production growth';
    'g_USCP',        {'g_USCP'},        'U.S. crude-oil production growth';
    'g_RUCP',        {'g_RUCP'},        'Russia/USSR crude-oil production growth';
    'g_CHNCP',       {'g_CHNCP'},       'China crude-oil production growth';
    'g_VNZCP',       {'g_VNZCP'},       'Venezuela crude-oil production growth';
    'g_Usinv',       {'g_Usinv'},       'U.S. inventory growth';
    'g_OECD_inv',    {'g_OECD_inv'},    'OECD inventory growth';
    'gGDP_Forecast', {'gGDP_Forecast'}, 'Expected future global GDP growth';
    'gGDP_Revise',   {'gGDP_Revise'},   'Revision in expected future global GDP growth';
    'Headline_Pi',   {'Headline_Pi'},   'Headline CPI inflation';
    'Core_Pi',       {'Core_Pi'},       'Core CPI inflation';
    'Energy_CPI',    {'Energy_CPI'},    'Energy CPI inflation';
    'Policy_Rate',   {'Policy_Rate'},   'Policy rate';
    'Unemp',         {'Unemp','Unemployment'}, 'Unemployment rate';
    'g_ry',          {'g_ry'},          'Real GDP growth'
};

cfg.p_lp       = 4;
cfg.H          = 12;
cfg.ci         = 0.90;
cfg.shock_size = 2;
cfg.horizon_label = 'Horizon (quarters)';

% Response display mode.
%   'noncumulative'   : plot original horizon-by-horizon LP coefficients.
%   'cumulative_auto' : cumulate growth/flow variables only.
%   'cumulative_all'  : cumulate all variables except those explicitly excluded.
%
% Recommended:
%   Use 'cumulative_auto' as the main figure mode.
cfg.response_mode = 'cumulative_auto';

% Variables cumulated under cumulative_auto.
cfg.cumulative_var_ids = { ...
    'g_WorldCP','g_MEastCP','g_USCP','g_RUCP','g_CHNCP','g_VNZCP','g_Usinv','g_OECD_inv' ...
};

% Variables not cumulated even under cumulative_all.
cfg.never_cumulative_var_ids = { ...
    'gGDP_Forecast','gGDP_Revise' ...
};

% Approximate cumulative confidence interval method.
%   'rss'   : sqrt(sum of squared horizon-specific SEs), ignores cross-horizon covariance.
%   'naive' : cumulative sum of SEs, conservative and usually too wide.
cfg.cumulative_ci_method = 'rss';

cfg.save_figures = true;
cfg.show_figures = true;

cfg.control_aliases = { ...
    {'Unemp','Unemployment'}, ...
    {'Policy_Rate','FFR','EffPolicyRate','ShadowRate'} ...
};

% State-dependent design.
cfg.tight_var_aliases = {'g_OECD_inv'};
cfg.tight_percentile  = 50;
cfg.tight_lag         = 1;
cfg.tight_direction   = 'low';

% Short-horizon window used for optional sign-pattern classification.
cfg.classify_h0 = 0;
cfg.classify_h1 = 4;
%% -------------------------------------------------------

if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end

fprintf('\n=== %s ===\n', cfg.output_dir);
fprintf('Working directory: %s\n', pwd);
fprintf('Shock extraction mode: %s\n', cfg.shock_extraction_mode);
fprintf('Response display mode: %s\n', cfg.response_mode);

%% -------------------- LOAD DATABASE --------------------
if exist(cfg.datafile, 'file')
    fprintf('Loading MAT file: %s\n', cfg.datafile);
    raw = load(cfg.datafile);
else
    fprintf('MAT file not found. Loading CSV fallback: %s\n', cfg.csv_fallback);
    raw = struct('DB', readtable(cfg.csv_fallback, 'VariableNamingRule','preserve'));
end

DB = unpack_database(raw);
T  = infer_sample_length(DB);
varnames = get_varnames(DB);

fprintf('Sample length T = %d\n', T);
fprintf('Number of variables = %d\n', numel(varnames));

sample = get_sample(DB, T);
fprintf('Baseline sample observations = %d / %d\n', sum(sample), T);

[quarter_labels, has_quarter] = get_quarter_labels(DB, T);
if has_quarter
    fprintf('Sample starts at %s and ends at %s\n', quarter_labels{find(sample,1,'first')}, quarter_labels{find(sample,1,'last')});
end

[controls, control_names] = build_controls(DB, cfg.control_aliases);
fprintf('Controls loaded: %s\n', strjoin(control_names, ', '));
for cc = 1:numel(control_names)
    fprintf('  Control %-15s finite = %3d / %3d\n', control_names{cc}, sum(isfinite(controls(:,cc))), T);
end

%% -------------------- DEFINE SHOCKS --------------------
shock_specs = {
    'World',       {'LGPR'},     'World GPR innovation';
    'Threat',      {'LGPRT'},    'Threat GPR innovation';
    'Act',         {'LGPRA'},    'Act GPR innovation';
    'US',          {'LGPRUS'},   'United States GPR innovation';
    'Israel',      {'LGPRISR'},  'Israel GPR innovation';
    'Russia',      {'LGPRRU'},   'Russia GPR innovation';
    'China',       {'LGPRCHN'},  'China GPR innovation';
    'Venezuela',   {'LGPRVZ'},   'Venezuela GPR innovation';
    'SaudiArabia', {'LGPRSAR'},  'Saudi Arabia GPR innovation'
};

aggregate_shock_ids = {'World','Threat','Act'};
country_shock_ids   = {'US','Israel','Russia','China','Venezuela','SaudiArabia'};
all_shock_ids  = shock_specs(:,1)';
plot_shock_ids = all_shock_ids;

%% -------------------- BUILD AUGMENTATION PREDICTORS --------------------
[Xaug, aug_pred_names, aug_pred_labels] = build_predictor_matrix(DB, cfg.aug_predictor_specs, T);

fprintf('\nAugmentation predictors used in GPR shock extraction:\n');
for pp = 1:numel(aug_pred_names)
    fprintf('  %-15s : %s\n', aug_pred_names{pp}, aug_pred_labels{pp});
end

aug_predictor_table = table(string(aug_pred_names(:)), string(aug_pred_labels(:)), ...
    'VariableNames', {'predictor','label'});
writetable(aug_predictor_table, fullfile(cfg.output_dir, 'diagnostics_augmented_shock_predictors.csv'));

%% -------------------- CONSTRUCT ORIGINAL AND AUGMENTED GPR INNOVATIONS --------------------
Z_original = struct();
Z_augmented = struct();
Z = struct();

innovation_info = table();

fprintf('\n--- Constructing original and augmented GPR innovations ---\n');
for s = 1:size(shock_specs,1)
    sid = shock_specs{s,1};
    x = get_required_series(DB, shock_specs{s,2});

    innov_orig = extract_ar_innovation(x, sample, cfg.p_innov, sid);
    innov_aug  = extract_augmented_innovation(x, Xaug, sample, cfg.p_innov, cfg.p_aug, sid);

    if cfg.standardize_innov
        z_orig = zscore_in_sample(innov_orig.resid, sample);
        z_aug  = zscore_in_sample(innov_aug.resid,  sample);
    else
        z_orig = innov_orig.resid;
        z_aug  = innov_aug.resid;
    end

    Z_original.(sid) = z_orig;
    Z_augmented.(sid) = z_aug;

    switch lower(cfg.shock_extraction_mode)
        case {'original','univariate','ar'}
            Z.(sid) = z_orig;
        case {'augmented','aug','orthogonalized'}
            Z.(sid) = z_aug;
        otherwise
            error('Unknown cfg.shock_extraction_mode: %s', cfg.shock_extraction_mode);
    end

    use_corr = sample & isfinite(z_orig) & isfinite(z_aug);
    if sum(use_corr) > 3
        cmat = corrcoef(z_orig(use_corr), z_aug(use_corr));
        corr_orig_aug = cmat(1,2);
    else
        corr_orig_aug = NaN;
    end

    nfinite_z = sum(isfinite(Z.(sid)));

    fprintf('Shock %-12s: orig R2=% .3f, aug R2=% .3f, corr(orig,aug)=% .3f, finite z=%3d\n', ...
        sid, innov_orig.rsq, innov_aug.rsq, corr_orig_aug, nfinite_z);

    innovation_info = [innovation_info; table(string(sid), string(cfg.shock_extraction_mode), ...
        innov_orig.nobs, innov_orig.rsq, innov_orig.std_resid, sum(isfinite(z_orig)), ...
        innov_aug.nobs, innov_aug.rsq, innov_aug.std_resid, sum(isfinite(z_aug)), ...
        corr_orig_aug, nfinite_z, ...
        'VariableNames', {'shock','active_shock_mode', ...
        'orig_nobs','orig_rsq','orig_resid_sd','finite_z_original', ...
        'aug_nobs','aug_rsq','aug_resid_sd','finite_z_augmented', ...
        'corr_original_augmented','finite_z_active'})]; %#ok<AGROW>
end

writetable(innovation_info, fullfile(cfg.output_dir, 'diagnostics_innovations_original_vs_augmented.csv'));

%% -------------------- DEFINE VARIABLES --------------------
outcome_specs = {
    'g_Brent',      {'g_Brent'},      'Brent price growth';
    'g_WTI_Cru',    {'g_WTI_Cru'},    'WTI crude-oil price growth';
    'g_Gaso',       {'g_Gaso'},       'Gasoline price growth';
    'Headline_Pi',  {'Headline_Pi'},  'Headline CPI inflation';
    'Core_Pi',      {'Core_Pi'},      'Core CPI inflation';
    'Energy_CPI',   {'Energy_CPI'},   'Energy CPI inflation';
    'Policy_Rate',  {'Policy_Rate'},  'Policy rate';
    'g_ry',         {'g_ry'},         'Real GDP growth'
};

mechanism_specs = {
    'g_WorldCP',    {'g_WorldCP'},    'World crude-oil production growth';
    'g_MEastCP',    {'g_MEastCP'},    'Middle East crude-oil production growth';
    'g_USCP',       {'g_USCP'},       'U.S. crude-oil production growth';
    'g_RUCP',       {'g_RUCP'},       'Russia/USSR crude-oil production growth';
    'g_CHNCP',      {'g_CHNCP'},      'China crude-oil production growth';
    'g_VNZCP',      {'g_VNZCP'},      'Venezuela crude-oil production growth';
    'g_Usinv',      {'g_Usinv'},      'U.S. inventory growth';
    'g_OECD_inv',   {'g_OECD_inv'},   'OECD inventory growth';
    'gGDP_Forecast',{'gGDP_Forecast'},'Expected future global GDP growth';
    'gGDP_Revise', {'gGDP_Revise'},  'Revision in expected future global GDP growth'
};

aggregate_channel_specs = {
    'g_WorldCP',     {'g_WorldCP'},      'World crude-oil production growth';
    'g_OECD_inv',    {'g_OECD_inv'},     'OECD inventory growth';
    'gGDP_Forecast', {'gGDP_Forecast'},  'Expected future global GDP growth';
    'gGDP_Revise',   {'gGDP_Revise'},    'Revision in expected future global GDP growth'
};

country_channel_map = struct();
country_channel_map.World       = {'g_WorldCP'};
country_channel_map.Threat      = {'g_WorldCP'};
country_channel_map.Act         = {'g_WorldCP'};
country_channel_map.US          = {'g_USCP'};
country_channel_map.Russia      = {'g_RUCP'};
country_channel_map.China       = {'g_CHNCP'};
country_channel_map.Venezuela   = {'g_VNZCP'};
country_channel_map.Israel      = {'g_MEastCP'};
country_channel_map.SaudiArabia = {'g_MEastCP'};

country_channel_label = struct();
country_channel_label.World       = 'World crude-oil production growth';
country_channel_label.Threat      = 'World crude-oil production growth';
country_channel_label.Act         = 'World crude-oil production growth';
country_channel_label.US          = 'U.S. crude-oil production growth';
country_channel_label.Russia      = 'Russia/USSR crude-oil production growth';
country_channel_label.China       = 'China crude-oil production growth';
country_channel_label.Venezuela   = 'Venezuela crude-oil production growth';
country_channel_label.Israel      = 'Middle East crude-oil production growth';
country_channel_label.SaudiArabia = 'Middle East crude-oil production growth';

%% ============================================================
% PART 3B. MECHANISM RESPONSES
%% ============================================================
fprintf('\n=== Part 3B: mechanism responses to all 9 GPR shocks ===\n');

part3B_results = table();
part3B_struct = struct();

for i = 1:size(mechanism_specs,1)
    mid = mechanism_specs{i,1};
    mlabel = mechanism_specs{i,3};
    m = get_required_series(DB, mechanism_specs{i,2});

    res_list = cell(numel(plot_shock_ids),1);
    plot_titles = cell(numel(plot_shock_ids),1);

    fprintf('\nMechanism: %s | finite m=%d/%d\n', mid, sum(isfinite(m)), T);

    for s = 1:numel(plot_shock_ids)
        sid = plot_shock_ids{s};
        res_raw = estimate_lp_baseline(m, Z.(sid), controls, sample, cfg);
        res = apply_response_mode_to_result(res_raw, mid, cfg);
        part3B_struct.(mid).(sid) = res;

        tmp = res.table;
        tmp.part = repmat("Part3B_mechanism_response", height(tmp), 1);
        tmp.mechanism = repmat(string(mid), height(tmp), 1);
        tmp.mechanism_label = repmat(string(mlabel), height(tmp), 1);
        tmp.shock = repmat(string(sid), height(tmp), 1);
        part3B_results = [part3B_results; tmp]; %#ok<AGROW>

        res_list{s} = res;
        plot_titles{s} = sid;

        fprintf('  %-12s: mode=%-16s, finite beta=%2d/%2d, nobs h0=%3.0f, beta h0=% .4f\n', ...
            sid, res.response_mode_label, sum(isfinite(res.beta)), cfg.H+1, res.nobs(1), res.beta(1));
    end

    fig_title = sprintf('Part 3B mechanism response: %s', mlabel);
    fig = plot_irf_set(res_list, plot_titles, cfg, fig_title, 3, 3, cfg.show_figures);
    save_figure_if_needed(fig, cfg, fullfile(cfg.output_dir, ['Part3B_mechanism_' clean_file_string(mid)]));
end

writetable(part3B_results, fullfile(cfg.output_dir, 'part3B_mechanism_responses_long.csv'));

save(fullfile(cfg.output_dir, 'Part3B_MechanismResponses_workspace.mat'), ...
    'cfg', 'Z', 'Z_original', 'Z_augmented', 'innovation_info', 'part3B_struct', 'part3B_results', ...
    'control_names', 'aggregate_shock_ids', 'country_shock_ids', 'all_shock_ids', 'plot_shock_ids');

fprintf('\nDone. Part 3B results saved in folder: %s\n', cfg.output_dir);

%% ======================= LOCAL HELPER FUNCTIONS =======================

function DB = unpack_database(raw)
    fns = fieldnames(raw);
    for i = 1:numel(fns)
        if istable(raw.(fns{i}))
            DB = raw.(fns{i});
            return;
        end
    end
    DB = raw;
end

function T = infer_sample_length(DB)
    names = get_varnames(DB);
    if istable(DB)
        T = height(DB);
    else
        T = [];
        for i = 1:numel(names)
            x = DB.(names{i});
            if isnumeric(x) || islogical(x)
                T = numel(x);
                return;
            end
        end
        error('Cannot infer sample length from DB.');
    end
end

function names = get_varnames(DB)
    if istable(DB)
        names = DB.Properties.VariableNames;
    else
        names = fieldnames(DB);
    end
end

function [quarter_labels, has_quarter] = get_quarter_labels(DB, T)
    q = get_series_raw_if_exists(DB, {'quarter','Quarter','date','Date'});
    has_quarter = false;
    quarter_labels = repmat({''}, T, 1);
    if isempty(q), return; end
    has_quarter = true;
    if iscell(q)
        quarter_labels = q(:);
    elseif isstring(q)
        quarter_labels = cellstr(q(:));
    elseif isdatetime(q)
        quarter_labels = cellstr(string(q(:)));
    elseif isnumeric(q)
        quarter_labels = cellstr(string(q(:)));
    else
        quarter_labels = cellstr(string(q(:)));
    end
end

function x = get_series_raw_if_exists(DB, targets)
    if ischar(targets) || isstring(targets)
        targets = cellstr(targets);
    end
    names = get_varnames(DB);
    x = [];
    for ii = 1:numel(targets)
        target = char(targets{ii});
        idx = find(strcmpi(names, target), 1, 'first');
        if isempty(idx)
            idx = find(startsWith(names, target, 'IgnoreCase', true), 1, 'first');
        end
        if ~isempty(idx)
            name = names{idx};
            if istable(DB)
                x = DB.(name);
            else
                x = DB.(name);
            end
            return;
        end
    end
end

function x = get_series_if_exists(DB, targets)
    xraw = get_series_raw_if_exists(DB, targets);
    if isempty(xraw)
        x = [];
        return;
    end
    if iscell(xraw) || isstring(xraw) || isdatetime(xraw) || iscategorical(xraw) || ischar(xraw)
        x = [];
        return;
    end
    x = double(xraw(:));
end

function x = get_required_series(DB, targets)
    x = get_series_if_exists(DB, targets);
    if isempty(x)
        if ischar(targets) || isstring(targets)
            msg = char(targets);
        else
            msg = strjoin(cellstr(targets), ', ');
        end
        error('Required numeric variable not found. Tried: %s', msg);
    end
end

function sample = get_sample(DB, T)
    sample = get_series_if_exists(DB, {'H1_sample'});
    if isempty(sample)
        sample = true(T,1);
    else
        sample = isfinite(sample) & (sample ~= 0);
    end
end

function [controls, control_names] = build_controls(DB, control_aliases)
    controls = [];
    control_names = {};
    for i = 1:numel(control_aliases)
        x = get_series_if_exists(DB, control_aliases{i});
        if ~isempty(x)
            controls = [controls, x]; %#ok<AGROW>
            control_names{end+1} = char(control_aliases{i}{1}); %#ok<AGROW>
        else
            warning('Control not found and skipped: %s', strjoin(control_aliases{i}, ', '));
        end
    end
end

function channels = build_channel_matrix(DB, channel_specs)
    channels = [];
    for i = 1:size(channel_specs,1)
        x = get_required_series(DB, channel_specs{i,2});
        channels = [channels, x(:)]; %#ok<AGROW>
    end
end

function [Xpred, pred_names, pred_labels] = build_predictor_matrix(DB, predictor_specs, T)
    Xpred = [];
    pred_names = {};
    pred_labels = {};

    for i = 1:size(predictor_specs,1)
        vid = predictor_specs{i,1};
        aliases = predictor_specs{i,2};
        label = predictor_specs{i,3};

        x = get_series_if_exists(DB, aliases);
        if isempty(x)
            warning('Augmentation predictor not found and skipped: %s', vid);
            continue;
        end

        if numel(x) ~= T
            warning('Augmentation predictor %s has incompatible length and is skipped.', vid);
            continue;
        end

        Xpred = [Xpred, x(:)]; %#ok<AGROW>
        pred_names{end+1} = vid; %#ok<AGROW>
        pred_labels{end+1} = label; %#ok<AGROW>
    end
end

function out = extract_ar_innovation(x, sample, p, label)
    x = x(:);
    T = length(x);
    t_grid = (p+1):T;
    n = numel(t_grid);
    k = 1 + p;
    Y = nan(n,1);
    X = nan(n,k);
    keep = false(n,1);

    for ii = 1:n
        t = t_grid(ii);
        row = nan(1,k);
        row(1) = 1;
        for j = 1:p
            row(1+j) = x(t-j);
        end
        Y(ii) = x(t);
        X(ii,:) = row;
        keep(ii) = sample(t) && all(sample(t-p:t));
    end

    good = keep & isfinite(Y) & all(isfinite(X),2);
    Yg = Y(good);
    Xg = X(good,:);
    tg = t_grid(good)';

    if isempty(Yg)
        error('No usable observations in AR innovation extraction for %s.', label);
    end

    b = Xg \ Yg;
    fitted = nan(T,1);
    resid  = nan(T,1);
    fitted(tg) = Xg * b;
    resid(tg)  = Yg - Xg * b;

    u = resid(tg);
    sse = sum(u.^2);
    sst = sum((Yg - mean(Yg)).^2);
    if sst > 0
        rsq = 1 - sse / sst;
    else
        rsq = NaN;
    end

    out = struct('label',label,'t_index',tg,'coeff',b,'fitted',fitted,'resid',resid, ...
        'nobs',numel(Yg),'rsq',rsq,'mean_resid',mean(u),'std_resid',std(u));
end

function out = extract_augmented_innovation(gpr, Xpred, sample, p_gpr, p_x, label)
    gpr = gpr(:);
    T = length(gpr);

    if isempty(Xpred)
        warning('No augmentation predictors available. Falling back to univariate AR for %s.', label);
        out = extract_ar_innovation(gpr, sample, p_gpr, label);
        return;
    end

    maxp = max(p_gpr, p_x);
    t_grid = (maxp+1):T;
    n = numel(t_grid);
    nX = size(Xpred,2);

    k = 1 + p_gpr + p_x*nX;
    Y = nan(n,1);
    X = nan(n,k);
    keep = false(n,1);

    for ii = 1:n
        t = t_grid(ii);
        c = 1;
        row = nan(1,k);

        row(c) = 1; c = c + 1;

        for j = 1:p_gpr
            row(c) = gpr(t-j);
            c = c + 1;
        end

        for j = 1:p_x
            vals = Xpred(t-j,:);
            row(c:c+nX-1) = vals;
            c = c + nX;
        end

        Y(ii) = gpr(t);
        X(ii,:) = row;
        keep(ii) = sample(t) && all(sample(t-maxp:t));
    end

    good = keep & isfinite(Y) & all(isfinite(X),2);
    Yg = Y(good);
    Xg = X(good,:);
    tg = t_grid(good)';

    if isempty(Yg) || size(Xg,1) <= size(Xg,2)
        warning('Augmented innovation for %s has too few observations: n=%d, k=%d. Falling back to univariate AR.', ...
            label, size(Xg,1), size(Xg,2));
        out = extract_ar_innovation(gpr, sample, p_gpr, label);
        return;
    end

    b = Xg \ Yg;
    fitted = nan(T,1);
    resid  = nan(T,1);

    fitted(tg) = Xg * b;
    resid(tg)  = Yg - Xg * b;

    u = resid(tg);
    sse = sum(u.^2);
    sst = sum((Yg - mean(Yg)).^2);
    if sst > 0
        rsq = 1 - sse / sst;
    else
        rsq = NaN;
    end

    out = struct('label',label,'t_index',tg,'coeff',b,'fitted',fitted,'resid',resid, ...
        'nobs',numel(Yg),'rsq',rsq,'mean_resid',mean(u),'std_resid',std(u));
end

function z = zscore_in_sample(x, sample)
    x = x(:);
    use = sample & isfinite(x);
    mu = mean(x(use));
    sd = std(x(use));
    z = (x - mu) ./ sd;
end

function [state, info] = build_lagged_state_dummy(x, sample, pct, lag_len, direction)
    x = x(:);
    use = sample & isfinite(x);
    threshold = percentile_no_toolbox(x(use), pct);

    T = length(x);
    state = nan(T,1);

    for t = (lag_len+1):T
        xlag = x(t-lag_len);
        if ~isfinite(xlag), continue; end
        if strcmpi(direction, 'low')
            state(t) = double(xlag <= threshold);
        elseif strcmpi(direction, 'high')
            state(t) = double(xlag >= threshold);
        else
            error('direction must be either low or high.');
        end
    end

    info = struct('threshold', threshold, 'pct', pct, 'lag', lag_len, 'direction', direction);
end

function q = percentile_no_toolbox(x, pct)
    x = sort(x(isfinite(x)));
    if isempty(x)
        q = NaN;
        return;
    end
    if pct <= 0
        q = x(1);
        return;
    elseif pct >= 100
        q = x(end);
        return;
    end
    r = 1 + (numel(x)-1) * pct / 100;
    lo = floor(r);
    hi = ceil(r);
    if lo == hi
        q = x(lo);
    else
        q = x(lo) + (r-lo) * (x(hi)-x(lo));
    end
end

function res = estimate_lp_baseline(y, z, controls, sample, cfg)
    H = cfg.H;
    zcrit = normal_icdf(0.5 + cfg.ci/2);

    beta = nan(H+1,1);
    se   = nan(H+1,1);
    lb   = nan(H+1,1);
    ub   = nan(H+1,1);
    nobs = nan(H+1,1);

    for h = 0:H
        [Y, X] = build_lp_design(y, z, controls, sample, cfg.p_lp, h, [], [], []);
        if isempty(Y) || size(X,1) <= size(X,2)
            continue;
        end

        bw = min(h + 1, size(X,1)-1);
        [b, se_all] = ols_hac(Y, X, bw);

        beta(h+1) = cfg.shock_size * b(2);
        se(h+1)   = cfg.shock_size * se_all(2);
        lb(h+1)   = beta(h+1) - zcrit * se(h+1);
        ub(h+1)   = beta(h+1) + zcrit * se(h+1);
        nobs(h+1) = size(X,1);
    end

    res = struct();
    res.h = (0:H)';
    res.beta = beta;
    res.se = se;
    res.lb = lb;
    res.ub = ub;
    res.nobs = nobs;
    res.table = table((0:H)', beta, se, lb, ub, nobs, ...
        'VariableNames', {'h','beta','se','lb','ub','nobs'});
end

function res = estimate_lp_state_dependent(y, z, state, controls, sample, cfg)
    H = cfg.H;
    zcrit = normal_icdf(0.5 + cfg.ci/2);

    beta_normal = nan(H+1,1);
    se_normal   = nan(H+1,1);
    lb_normal   = nan(H+1,1);
    ub_normal   = nan(H+1,1);

    kappa    = nan(H+1,1);
    se_kappa = nan(H+1,1);
    lb_kappa = nan(H+1,1);
    ub_kappa = nan(H+1,1);

    beta_tight = nan(H+1,1);
    se_tight   = nan(H+1,1);
    lb_tight   = nan(H+1,1);
    ub_tight   = nan(H+1,1);

    nobs = nan(H+1,1);

    for h = 0:H
        [Y, X] = build_lp_design(y, z, controls, sample, cfg.p_lp, h, [], state, []);
        if isempty(Y) || size(X,1) <= size(X,2)
            continue;
        end

        bw = min(h + 1, size(X,1)-1);
        [b, se_all, V] = ols_hac(Y, X, bw);

        % Column order: const, z, z*state, state, ...
        beta_normal(h+1) = cfg.shock_size * b(2);
        se_normal(h+1)   = cfg.shock_size * se_all(2);

        kappa(h+1)    = cfg.shock_size * b(3);
        se_kappa(h+1) = cfg.shock_size * se_all(3);

        beta_tight(h+1) = cfg.shock_size * (b(2) + b(3));
        Vsum = V(2,2) + V(3,3) + 2*V(2,3);
        se_tight(h+1) = cfg.shock_size * sqrt(max(Vsum,0));

        lb_normal(h+1) = beta_normal(h+1) - zcrit * se_normal(h+1);
        ub_normal(h+1) = beta_normal(h+1) + zcrit * se_normal(h+1);

        lb_kappa(h+1) = kappa(h+1) - zcrit * se_kappa(h+1);
        ub_kappa(h+1) = kappa(h+1) + zcrit * se_kappa(h+1);

        lb_tight(h+1) = beta_tight(h+1) - zcrit * se_tight(h+1);
        ub_tight(h+1) = beta_tight(h+1) + zcrit * se_tight(h+1);

        nobs(h+1) = size(X,1);
    end

    res = struct();
    res.h = (0:H)';
    res.beta_normal = beta_normal;
    res.se_normal = se_normal;
    res.lb_normal = lb_normal;
    res.ub_normal = ub_normal;
    res.kappa = kappa;
    res.se_kappa = se_kappa;
    res.lb_kappa = lb_kappa;
    res.ub_kappa = ub_kappa;
    res.beta_tight = beta_tight;
    res.se_tight = se_tight;
    res.lb_tight = lb_tight;
    res.ub_tight = ub_tight;
    res.nobs = nobs;

    res.table = table((0:H)', beta_normal, se_normal, lb_normal, ub_normal, ...
        kappa, se_kappa, lb_kappa, ub_kappa, ...
        beta_tight, se_tight, lb_tight, ub_tight, nobs, ...
        'VariableNames', {'h','beta_normal','se_normal','lb_normal','ub_normal', ...
        'kappa_tight_increment','se_kappa','lb_kappa','ub_kappa', ...
        'beta_tight_total','se_tight','lb_tight','ub_tight','nobs'});
end

function res = estimate_lp_channel_pair(y, z, channels, controls, sample, cfg)
    H = cfg.H;
    zcrit = normal_icdf(0.5 + cfg.ci/2);

    beta_baseline = nan(H+1,1);
    se_baseline   = nan(H+1,1);
    lb_baseline   = nan(H+1,1);
    ub_baseline   = nan(H+1,1);

    beta_channel = nan(H+1,1);
    se_channel   = nan(H+1,1);
    lb_channel   = nan(H+1,1);
    ub_channel   = nan(H+1,1);

    absorbed       = nan(H+1,1);
    abs_reduction  = nan(H+1,1);
    nobs           = nan(H+1,1);

    for h = 0:H
        [Yc, Xc, good_channel] = build_lp_design(y, z, controls, sample, cfg.p_lp, h, channels, [], []);
        [Yb, Xb] = build_lp_design(y, z, controls, sample, cfg.p_lp, h, [], [], good_channel);

        if isempty(Yc) || isempty(Yb) || size(Xc,1) <= size(Xc,2) || size(Xb,1) <= size(Xb,2)
            continue;
        end

        bwc = min(h + 1, size(Xc,1)-1);
        bwb = min(h + 1, size(Xb,1)-1);

        [bc, sec] = ols_hac(Yc, Xc, bwc);
        [bb, seb] = ols_hac(Yb, Xb, bwb);

        beta_baseline(h+1) = cfg.shock_size * bb(2);
        se_baseline(h+1)   = cfg.shock_size * seb(2);
        lb_baseline(h+1)   = beta_baseline(h+1) - zcrit * se_baseline(h+1);
        ub_baseline(h+1)   = beta_baseline(h+1) + zcrit * se_baseline(h+1);

        beta_channel(h+1) = cfg.shock_size * bc(2);
        se_channel(h+1)   = cfg.shock_size * sec(2);
        lb_channel(h+1)   = beta_channel(h+1) - zcrit * se_channel(h+1);
        ub_channel(h+1)   = beta_channel(h+1) + zcrit * se_channel(h+1);

        absorbed(h+1)      = beta_baseline(h+1) - beta_channel(h+1);
        abs_reduction(h+1) = abs(beta_baseline(h+1)) - abs(beta_channel(h+1));
        nobs(h+1)          = size(Xc,1);
    end

    res = struct();
    res.h = (0:H)';
    res.beta_baseline = beta_baseline;
    res.se_baseline = se_baseline;
    res.lb_baseline = lb_baseline;
    res.ub_baseline = ub_baseline;
    res.beta_channel = beta_channel;
    res.se_channel = se_channel;
    res.lb_channel = lb_channel;
    res.ub_channel = ub_channel;
    res.absorbed = absorbed;
    res.abs_reduction = abs_reduction;
    res.nobs = nobs;

    res.table = table((0:H)', beta_baseline, se_baseline, lb_baseline, ub_baseline, ...
        beta_channel, se_channel, lb_channel, ub_channel, absorbed, abs_reduction, nobs, ...
        'VariableNames', {'h','beta_baseline_common','se_baseline','lb_baseline','ub_baseline', ...
        'beta_remaining_with_channels','se_remaining','lb_remaining','ub_remaining', ...
        'absorbed_beta','abs_reduction','nobs_common'});
end

function [Y, X, good, dbg] = build_lp_design(y, z, controls, sample, p, h, extra_current, state, force_good)
    y = y(:);
    z = z(:);
    T = length(y);

    if isempty(controls)
        controls = zeros(T,0);
    end
    if isempty(extra_current)
        extra_current = zeros(T,0);
    end

    nC = size(controls,2);
    nE = size(extra_current,2);
    has_state = ~isempty(state);
    if has_state
        state = state(:);
    end

    t_grid = (p+1):(T-h);
    n = numel(t_grid);

    k = 1 + 1;  % constant and current z
    if has_state
        k = k + 2; % z*state and state main effect
    end
    k = k + nE + p + p + p*nC; % channels, y lags, z lags, controls lags

    X0 = nan(n,k);
    Y0 = nan(n,1);

    sample_ok = false(n,1);
    Y_ok = false(n,1);
    z_current_ok = false(n,1);
    state_ok = true(n,1);
    extra_ok = true(n,1);
    y_lags_ok = false(n,1);
    z_lags_ok = false(n,1);
    controls_ok = true(n,1);

    for ii = 1:n
        t = t_grid(ii);
        c = 1;
        row = nan(1,k);

        row(c) = 1; c = c + 1;
        row(c) = z(t); c = c + 1;

        if has_state
            st = state(t);
            row(c) = z(t) * st; c = c + 1;
            row(c) = st; c = c + 1;
            state_ok(ii) = isfinite(st);
        end

        if nE > 0
            valsE = extra_current(t,:);
            row(c:c+nE-1) = valsE;
            c = c + nE;
            extra_ok(ii) = all(isfinite(valsE));
        end

        ylag = nan(1,p);
        zlag = nan(1,p);

        for j = 1:p
            ylag(j) = y(t-j);
            row(c) = ylag(j); c = c + 1;
        end

        for j = 1:p
            zlag(j) = z(t-j);
            row(c) = zlag(j); c = c + 1;
        end

        ctrl_block = [];
        if nC > 0
            for j = 1:p
                valsC = controls(t-j,:);
                row(c:c+nC-1) = valsC;
                ctrl_block = [ctrl_block, valsC]; %#ok<AGROW>
                c = c + nC;
            end
        end

        Y0(ii) = y(t+h);
        X0(ii,:) = row;

        sample_ok(ii) = sample(t) && sample(t+h) && all(sample(t-p:t));
        Y_ok(ii) = isfinite(Y0(ii));
        z_current_ok(ii) = isfinite(z(t));
        y_lags_ok(ii) = all(isfinite(ylag));
        z_lags_ok(ii) = all(isfinite(zlag));

        if nC > 0
            controls_ok(ii) = all(isfinite(ctrl_block));
        end
    end

    good = sample_ok & Y_ok & z_current_ok & state_ok & extra_ok & ...
        y_lags_ok & z_lags_ok & controls_ok & all(isfinite(X0),2);

    if ~isempty(force_good)
        force_good = force_good(:);
        if numel(force_good) ~= numel(good)
            error('force_good has incompatible length.');
        end
        good = good & force_good;
    end

    Y = Y0(good);
    X = X0(good,:);

    dbg = struct();
    dbg.n_candidate = n;
    dbg.sample_ok = sum(sample_ok);
    dbg.Y_ok = sum(Y_ok);
    dbg.z_current_ok = sum(z_current_ok);
    dbg.state_ok = sum(state_ok);
    dbg.extra_ok = sum(extra_ok);
    dbg.y_lags_ok = sum(y_lags_ok);
    dbg.z_lags_ok = sum(z_lags_ok);
    dbg.controls_ok = sum(controls_ok);
    dbg.final_good = sum(good);
end

function [b, se, V] = ols_hac(y, X, bw)
    [n, k] = size(X);
    if n <= k
        error('Not enough observations: n=%d, k=%d', n, k);
    end

    b = X \ y;
    u = y - X*b;

    bw = min(max(bw,0), n-1);
    XtX_inv = pinv(X' * X);

    S = zeros(k, k);
    for t = 1:n
        xt = X(t, :)';
        S = S + (u(t)^2) * (xt * xt');
    end

    for L = 1:bw
        wL = 1 - L / (bw + 1);
        Gamma = zeros(k, k);
        for t = (L+1):n
            xt = X(t, :)';
            xtL = X(t-L, :)';
            Gamma = Gamma + u(t) * u(t-L) * (xt * xtL');
        end
        S = S + wL * (Gamma + Gamma');
    end

    V = (n / (n - k)) * XtX_inv * S * XtX_inv;
    se = sqrt(max(diag(V),0));
end

function q = normal_icdf(p)
    q = -sqrt(2) * erfcinv(2 * p);
end

function fig = plot_irf_set(res_list, titles, cfg, fig_title, nrow, ncol, show_figures)
    h = 0:cfg.H;
    if show_figures
        fig = figure('Color','w','Position',[80,60,1500,900]);
    else
        fig = figure('Color','w','Position',[80,60,1500,900], 'Visible','off');
    end

    for i = 1:numel(res_list)
        ax = subplot(nrow, ncol, i, 'Parent', fig);
        hold(ax, 'on');
        r = res_list{i};

        finite_beta = isfinite(r.beta);
        finite_ci = isfinite(r.lb) & isfinite(r.ub);

        if sum(finite_beta) == 0
            text(ax, 0.5, 0.5, 'All beta = NaN', 'HorizontalAlignment','center', ...
                'Units','normalized', 'FontWeight','bold');
            title(ax, titles{i}, 'Interpreter','none');
            axis(ax, 'off');
            continue;
        end

        if all(finite_ci)
            fill(ax, [h, fliplr(h)], [r.ub', fliplr(r.lb')], [0.75 0.75 0.75], ...
                'EdgeColor','none','FaceAlpha',0.55);
        end
        plot(ax, h(finite_beta), r.beta(finite_beta), 'k-', 'LineWidth', 2.0);
        plot(ax, h, zeros(size(h)), 'k--', 'LineWidth', 1.0);
        grid(ax, 'on'); box(ax, 'on'); xlim(ax, [0 cfg.H]);
        xlabel(ax, cfg.horizon_label);
        if isfield(r, 'response_ylabel')
            ylabel(ax, r.response_ylabel);
        else
            ylabel(ax, 'Response');
        end
        title(ax, titles{i}, 'Interpreter','none');
    end

    sgtitle(fig, fig_title, 'Interpreter','none', 'FontSize', 14, 'FontWeight','bold');
    drawnow;
end

function fig = plot_state_irf_set(res_list, titles, cfg, fig_title, nrow, ncol, show_figures)
    h = 0:cfg.H;
    if show_figures
        fig = figure('Color','w','Position',[80,60,1500,900]);
    else
        fig = figure('Color','w','Position',[80,60,1500,900], 'Visible','off');
    end

    for i = 1:numel(res_list)
        ax = subplot(nrow, ncol, i, 'Parent', fig);
        hold(ax, 'on');
        r = res_list{i};

        plot(ax, h, zeros(size(h)), 'k--', 'LineWidth', 1.0);

        finite_n = isfinite(r.beta_normal);
        finite_t = isfinite(r.beta_tight);

        if sum(finite_n) == 0 && sum(finite_t) == 0
            text(ax, 0.5, 0.5, 'All beta = NaN', 'HorizontalAlignment','center', ...
                'Units','normalized', 'FontWeight','bold');
            title(ax, titles{i}, 'Interpreter','none');
            axis(ax, 'off');
            continue;
        end

        plot(ax, h(finite_n), r.beta_normal(finite_n), 'k-', 'LineWidth', 2.0);
        plot(ax, h(finite_t), r.beta_tight(finite_t), 'k--', 'LineWidth', 2.0);

        grid(ax, 'on'); box(ax, 'on'); xlim(ax, [0 cfg.H]);
        xlabel(ax, cfg.horizon_label);
        if isfield(r, 'response_ylabel')
            ylabel(ax, r.response_ylabel);
        else
            ylabel(ax, 'Response');
        end
        title(ax, titles{i}, 'Interpreter','none');
        legend(ax, {'zero','normal state','tight state'}, 'Location','best');
    end

    sgtitle(fig, fig_title, 'Interpreter','none', 'FontSize', 14, 'FontWeight','bold');
    drawnow;
end

function fig = plot_channel_pair_set(res_list, titles, cfg, fig_title, nrow, ncol, show_figures)
    h = 0:cfg.H;
    if show_figures
        fig = figure('Color','w','Position',[80,60,1500,900]);
    else
        fig = figure('Color','w','Position',[80,60,1500,900], 'Visible','off');
    end

    for i = 1:numel(res_list)
        ax = subplot(nrow, ncol, i, 'Parent', fig);
        hold(ax, 'on');
        r = res_list{i};

        plot(ax, h, zeros(size(h)), 'k--', 'LineWidth', 1.0);

        finite_b = isfinite(r.beta_baseline);
        finite_c = isfinite(r.beta_channel);

        if sum(finite_b) == 0 && sum(finite_c) == 0
            text(ax, 0.5, 0.5, 'All beta = NaN', 'HorizontalAlignment','center', ...
                'Units','normalized', 'FontWeight','bold');
            title(ax, titles{i}, 'Interpreter','none');
            axis(ax, 'off');
            continue;
        end

        plot(ax, h(finite_b), r.beta_baseline(finite_b), 'k-', 'LineWidth', 2.0);
        plot(ax, h(finite_c), r.beta_channel(finite_c), 'k--', 'LineWidth', 2.0);

        grid(ax, 'on'); box(ax, 'on'); xlim(ax, [0 cfg.H]);
        xlabel(ax, cfg.horizon_label);
        if isfield(r, 'response_ylabel')
            ylabel(ax, r.response_ylabel);
        else
            ylabel(ax, 'Response');
        end
        title(ax, titles{i}, 'Interpreter','none');
        legend(ax, {'zero','baseline, common sample','with channels'}, 'Location','best');
    end

    sgtitle(fig, fig_title, 'Interpreter','none', 'FontSize', 14, 'FontWeight','bold');
    drawnow;
end

function res = apply_response_mode_to_result(res, var_id, cfg)
    raw_beta = res.beta;
    raw_se   = res.se;
    raw_lb   = res.lb;
    raw_ub   = res.ub;

    do_cum = should_cumulate_variable(var_id, cfg);

    if do_cum
        beta = cumulative_sum_omitnan(raw_beta);

        switch lower(cfg.cumulative_ci_method)
            case 'rss'
                se = cumulative_rss_se(raw_se);
            case 'naive'
                se = cumulative_sum_omitnan(raw_se);
            otherwise
                error('Unknown cfg.cumulative_ci_method: %s', cfg.cumulative_ci_method);
        end

        zcrit = normal_icdf(0.5 + cfg.ci/2);
        lb = beta - zcrit * se;
        ub = beta + zcrit * se;

        response_mode_label = "cumulative";
        response_ylabel = "Cumulative response";
    else
        beta = raw_beta;
        se   = raw_se;
        lb   = raw_lb;
        ub   = raw_ub;

        response_mode_label = "noncumulative";
        response_ylabel = "Response";
    end

    res.raw_beta = raw_beta;
    res.raw_se   = raw_se;
    res.raw_lb   = raw_lb;
    res.raw_ub   = raw_ub;

    res.beta = beta;
    res.se   = se;
    res.lb   = lb;
    res.ub   = ub;

    res.is_cumulative = do_cum;
    res.response_mode_label = response_mode_label;
    res.response_ylabel = response_ylabel;
    res.variable_id_for_transform = string(var_id);

    res.table = table(res.h, beta, se, lb, ub, res.nobs, ...
        raw_beta, raw_se, raw_lb, raw_ub, ...
        repmat(string(var_id), numel(res.h), 1), ...
        repmat(response_mode_label, numel(res.h), 1), ...
        repmat(do_cum, numel(res.h), 1), ...
        'VariableNames', {'h','beta','se','lb','ub','nobs', ...
        'raw_beta','raw_se','raw_lb','raw_ub', ...
        'transform_variable','response_mode','is_cumulative'});
end

function do_cum = should_cumulate_variable(var_id, cfg)
    mode = lower(char(cfg.response_mode));
    vid = char(var_id);

    switch mode
        case {'none','noncumulative','no_cumulative','raw'}
            do_cum = false;

        case {'cumulative','cumulative_all','cum_all'}
            do_cum = true;
            if isfield(cfg, 'never_cumulative_var_ids')
                do_cum = do_cum && ~any(strcmp(vid, cfg.never_cumulative_var_ids));
            end

        case {'cumulative_auto','cum_auto','auto'}
            do_cum = any(strcmp(vid, cfg.cumulative_var_ids));
            if isfield(cfg, 'never_cumulative_var_ids')
                do_cum = do_cum && ~any(strcmp(vid, cfg.never_cumulative_var_ids));
            end

        otherwise
            error('Unknown cfg.response_mode: %s', cfg.response_mode);
    end
end

function y = cumulative_sum_omitnan(x)
    x = x(:);
    y = nan(size(x));
    running = 0;
    seen = false;

    for i = 1:numel(x)
        if isfinite(x(i))
            running = running + x(i);
            seen = true;
        end

        if seen
            y(i) = running;
        end
    end
end

function se_cum = cumulative_rss_se(se)
    se = se(:);
    se_cum = nan(size(se));
    running_var = 0;
    seen = false;

    for i = 1:numel(se)
        if isfinite(se(i))
            running_var = running_var + se(i)^2;
            seen = true;
        end

        if seen
            se_cum(i) = sqrt(running_var);
        end
    end
end


function save_figure_if_needed(fig, cfg, base_path)
    if ~cfg.save_figures
        return;
    end
    if isempty(fig) || ~isgraphics(fig, 'figure')
        warning('Invalid figure handle. Skipping save: %s', base_path);
        return;
    end

    out_png = [base_path '.png'];
    out_fig = [base_path '.fig'];

    drawnow;

    try
        savefig(fig, out_fig);
    catch ME
        warning('Could not save .fig file %s. Reason: %s', out_fig, ME.message);
    end

    try
        exportgraphics(fig, out_png, 'Resolution', 300);
    catch
        try
            print(fig, out_png, '-dpng', '-r300');
        catch ME2
            warning('Could not save png %s. Reason: %s', out_png, ME2.message);
        end
    end
end

function s = clean_file_string(s)
    s = char(s);
    s = regexprep(s, '[^A-Za-z0-9_\-]+', '_');
    s = regexprep(s, '_+', '_');
end

function out = average_horizon_beta(res, fieldname, h0, h1)
    h = res.h;
    use = h >= h0 & h <= h1 & isfinite(res.(fieldname));
    if any(use)
        out = mean(res.(fieldname)(use), 'omitnan');
    else
        out = NaN;
    end
end

function classification_table = classify_patterns(part3A_struct, part3B_struct, shock_ids, cfg)
    rows = table();

    for s = 1:numel(shock_ids)
        sid = shock_ids{s};

        oil_candidates = {'g_Brent','g_WTI_Cru','g_Gaso'};
        oil_beta = NaN;
        oil_used = "";

        for k = 1:numel(oil_candidates)
            oid = oil_candidates{k};
            if isfield(part3A_struct, oid) && isfield(part3A_struct.(oid), sid)
                val = average_horizon_beta(part3A_struct.(oid).(sid), 'beta', cfg.classify_h0, cfg.classify_h1);
                if isfinite(val)
                    oil_beta = val;
                    oil_used = string(oid);
                    break;
                end
            end
        end

        prod_beta = NaN;
        prod_used = "";
        prod_candidates = {'g_WorldCP','g_MEastCP'};
        for k = 1:numel(prod_candidates)
            mid = prod_candidates{k};
            if isfield(part3B_struct, mid) && isfield(part3B_struct.(mid), sid)
                val = average_horizon_beta(part3B_struct.(mid).(sid), 'beta', cfg.classify_h0, cfg.classify_h1);
                if isfinite(val)
                    prod_beta = val;
                    prod_used = string(mid);
                    break;
                end
            end
        end

        inv_beta = NaN;
        if isfield(part3B_struct, 'g_OECD_inv') && isfield(part3B_struct.g_OECD_inv, sid)
            inv_beta = average_horizon_beta(part3B_struct.g_OECD_inv.(sid), 'beta', cfg.classify_h0, cfg.classify_h1);
        end

        forecast_beta = NaN;
        revise_beta = NaN;
        if isfield(part3B_struct, 'gGDP_Forecast') && isfield(part3B_struct.gGDP_Forecast, sid)
            forecast_beta = average_horizon_beta(part3B_struct.gGDP_Forecast.(sid), 'beta', cfg.classify_h0, cfg.classify_h1);
        end
        if isfield(part3B_struct, 'gGDP_Revise') && isfield(part3B_struct.gGDP_Revise, sid)
            revise_beta = average_horizon_beta(part3B_struct.gGDP_Revise.(sid), 'beta', cfg.classify_h0, cfg.classify_h1);
        end

        if oil_beta > 0 && prod_beta < 0 && inv_beta < 0
            pattern = "realized_supply_disruption";
        elseif oil_beta > 0 && ~(prod_beta < 0)
            pattern = "supply_risk_or_precautionary_pricing";
        elseif oil_beta > 0 && inv_beta > 0
            pattern = "precautionary_inventory_accumulation";
        elseif oil_beta < 0 && (forecast_beta < 0 || revise_beta < 0)
            pattern = "global_demand_or_risk_off";
        else
            pattern = "mixed_or_weak_pattern";
        end

        row = table(string(sid), cfg.classify_h0, cfg.classify_h1, ...
            oil_used, oil_beta, prod_used, prod_beta, inv_beta, forecast_beta, revise_beta, pattern, ...
            'VariableNames', {'shock','h0','h1','oil_price_variable','avg_oil_price_beta', ...
            'production_variable','avg_production_beta','avg_oecd_inventory_beta', ...
            'avg_gdp_forecast_beta','avg_gdp_revision_beta','classification'});
        rows = [rows; row]; %#ok<AGROW>
    end

    classification_table = rows;
end
