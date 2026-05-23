%% =======================================================================
% LP_Poisson.m
% ------------------------------------------------------------------------
% Poisson-Residualized Local Projection Analysis for Geopolitical Shocks
%
% Step 1.  Load pre-computed GPR shocks z_t from AR_GPR_shock.m output:
%          Uses "with_oil" variant (GPR_shock_output/workspace_gpr_shock.mat)
%
% Step 2.  Poisson event-arrival residualization:
%          N_t^k ~ Poisson(lambda_t^k), log(lambda_t^k) = a + b*z_t^{GPR} + ...
%          Pearson residual: z_t^{N,k} = (N_t - lambda_t) / sqrt(lambda_t), standardized
%
% Step 3.  LP estimation (two variants):
%          (a) LP with Poisson residual: y_{t+h} - y_{t-1} = a + b*z_t^{N,k} + controls + e
%          (b) LP with raw event count:  y_{t+h} - y_{t-1} = a + b*N_t^k + controls + e
%          Newey-West HAC SE, bandwidth = h+1
%
% Step 4.  Overlay dashboards
%          compare (a) vs (b) to show residualization effect
%% =======================================================================

clear; clc; close all;

%% User Setting
cfg.datafile = 'Q_Levels_Database.csv';
cfg.dummy_file = 'oil_relevant_gpr_event_dummies_extended_onset_realized_1986Q1_2025Q4.csv';

cfg.output_dir = 'LP_Poisson_output';

cfg.save_results = false;
cfg.save_figures = true;
cfg.show_figures = true;

cfg.use_latex_fonts = true;

cfg.figure_font_size = 16;
cfg.figure_title_font_size = 18;
cfg.figure_axis_line_width = 1.4;

cfg.ci_band_color = [0.45 0.45 0.45];
cfg.ci_band_alpha = 0.75;
cfg.irf_line_width = 3.2;
cfg.zero_line_width = 1.4;

% 'aggregate': World, GPT, GPA | 'countries': US, Israel, etc. | 'all': both
cfg.plot_mode = 'countries';

%% GPR shock settings (loaded from AR_GPR_shock.m output)
cfg.gpr_shock_lag1_oil_controls = {'Real_Brent', 'Real_WTI', 'Real_Gasoline'};  % used for LP controls

%% LP specification
cfg.p_lp = 4;

cfg.use_compact_event_count_lp = true;
cfg.p_dynamic_lp_event_count = 4;
cfg.p_macro_lp_event_count = 1;
cfg.include_current_business_controls_event_count = false;
cfg.include_oil_controls_event_count = true;

cfg.H = 12;
cfg.ci = 0.90;

cfg.shock_size = 1;

%% Dummy controls
cfg.use_covid_dummy = true;
cfg.covid_dummy_name = 'COVID_2020';
cfg.covid_quarters = {'2020Q1','2020Q2','2020Q3','2020Q4'};

cfg.use_event_dummies = true;

cfg.event_episode_vars = { ...
    'OilThreat','OilAct','ThreatOnly','ActOnly','ThreatAct','AnyOilEvent', ...
    'OilRealization','StrictSupplyDisruption','ChokepointShippingRisk', ...
    'EnergySanction','ProducerRegionRisk','OilSpecificShock', ...
    'OilSpecificRealizedShock','OilSpecificThreatShock' ...
};

cfg.event_onset_control_vars = { ...
    'OilSpecificThreatShock_EventOnset', ...
    'OilSpecificRealizedShock_EventOnset', ...
    'StrictSupplyDisruption_EventOnset', ...
    'ChokepointShippingRisk_EventOnset', ...
    'EnergySanction_EventOnset', ...
    'ProducerRegionRisk_EventOnset' ...
};

cfg.dummy_control_vars = [{'COVID_2020'}, cfg.event_onset_control_vars];

%% Analysis switches
cfg.run_gpr_shock_dashboards = false;
cfg.run_event_onset_impulse_dashboards = false;
cfg.run_event_residual_impulse_dashboards = true;
cfg.run_gpr_plus_event_residual_lp = true;
cfg.run_gpr_plus_event_count_lp = true;

cfg.run_poisson_arrival_rawN_control_robustness = false;

%% Event impulse variables
cfg.event_impulse_vars = { ...
    'n_ChokepointShippingRisk_EventOnset', ...
    'n_StrictSupplyDisruption_EventOnset', ...
    'n_EnergySanction_EventOnset' ...
};

%% Overlay dashboard settings
cfg.make_poisson_vs_raw_overlay_dashboards = true;
cfg.poisson_vs_raw_overlay_events = cfg.event_impulse_vars;
cfg.poisson_vs_raw_overlay_labels = { ...
    'Chokepoint shipping onset', ...
    'Strict supply disruption onset', ...
    'Energy sanction onset' ...
};

cfg.poisson_vs_raw_raw_color = [0.05 0.25 0.90];
cfg.poisson_vs_raw_poisson_color = [0.85 0.10 0.10];
cfg.poisson_vs_raw_ci_alpha = 0.22;
cfg.poisson_vs_raw_line_width = 3.2;
cfg.poisson_vs_raw_poisson_line_style = '--';
cfg.poisson_vs_raw_raw_line_style = '-';

cfg.run_standalone_poisson_residual_dashboards = false;
cfg.skip_individual_poisson_overlay_events = true;
cfg.skip_individual_raw_count_overlay_events = true;

cfg.make_combined_fig_12_14_16 = false;
cfg.skip_individual_fig_12_14_16 = false;

cfg.combined_fig_12_14_16_events = { ...
    'n_ChokepointShippingRisk_EventOnset',  'Chokepoint shipping onset',      [0.85 0.10 0.10]; ...
    'n_StrictSupplyDisruption_EventOnset',  'Strict supply disruption onset', [0.05 0.25 0.90]; ...
    'n_EnergySanction_EventOnset',          'Energy sanction onset',          [0.00 0.00 0.00]  ...
};

cfg.combined_fig_12_14_16_ci_alpha = 0.30;
cfg.combined_fig_12_14_16_line_width = 3.2;

%% Poisson model settings
cfg.event_residual_poisson_gpr_var = 'LGPR';
cfg.event_residual_poisson_gpr_label = 'World';

cfg.poisson_exclude_gpr_from_intensity = false;
cfg.poisson_include_current_gpr_shock = true;
cfg.poisson_include_lagged_gpr_level = true;
cfg.poisson_gpr_level_lags = 1;
cfg.poisson_lagged_gpr_vars = {'LGPR'};
cfg.poisson_lagged_gpr_component_labels = {'WorldGPR'};

cfg.run_event_residual_gpr_tests = true;
cfg.gpr_high_threshold = 1.0;

cfg.poisson_include_lagged_count = true;
cfg.poisson_include_lagged_controls = true;
cfg.poisson_standardize_predictors = true;
cfg.poisson_min_positive_periods = 4;
cfg.poisson_ridge_lambda = 1e-6;
cfg.poisson_gpr_timing = 'current';

cfg.event_residual_lp_dummy_control_vars = cfg.dummy_control_vars;

%% Control variables
cfg.control_vars = {'Unemp', 'FFR', 'WEO_Growth', 'WEO_Revision', 'r_y', 'Indu_Prod'};

%% Shock specifications
cfg.aggregate_shock_specs = {
    'World',       'LGPR',    'World GPR shock';
    'GPT',         'LGPRT',   'Global geopolitical threats shock';
    'GPA',         'LGPRA',   'Global geopolitical acts shock'
};

cfg.country_shock_specs = {
    'US',          'LGPRUS',  'U.S. GPR shock';
    'Israel',      'LGPRISR', 'Israel GPR shock';
    'Russia',      'LGPRRU',  'Russia GPR shock';
    'China',       'LGPRCHN', 'China GPR shock';
    'Venezuela',   'LGPRVZ',  'Venezuela GPR shock';
    'SaudiArabia', 'LGPRSAR', 'Saudi Arabia GPR shock'
};

switch lower(strtrim(cfg.plot_mode))
    case {'aggregate','agg','global'}
        cfg.shock_specs = cfg.aggregate_shock_specs;
        cfg.shock_group_label = 'aggregate';
    case {'countries','country','country_specific','country-specific'}
        cfg.shock_specs = cfg.country_shock_specs;
        cfg.shock_group_label = 'country-specific';
    case {'all','both'}
        cfg.shock_specs = [cfg.aggregate_shock_specs; cfg.country_shock_specs];
        cfg.shock_group_label = 'selected';
    otherwise
        error('Unknown cfg.plot_mode = %s.', cfg.plot_mode);
end

%% Outcome specifications
cfg.outcome_specs = {
    'Real_Brent',    'Real_Brent',    'Brent';
    'Real_WTI',      'Real_WTI',      'WTI';
    'Real_Gasoline', 'Real_Gasoline', 'Gasoline';
    'inv_OECD',      'inv_OECD',      'OECD inv.';
    'inv_USA',       'inv_USA',       'US inv.';
    'WorldCP',       'WorldCP',       'World prod.'
};

cfg.dashboard_nrow = 2;
cfg.dashboard_ncol = 3;
cfg.horizon_label = 'Horizon (quarters)';

apply_latex_graphics_defaults(cfg);

if cfg.save_results || cfg.save_figures
    if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
end

fprintf('\n=== Level LP, plot mode = %s ===\n', cfg.plot_mode);
fprintf('Output: %s\n', cfg.output_dir);

%% Load data
if ~exist(cfg.datafile, 'file')
    error('Data file not found: %s', cfg.datafile);
end

DB = readtable(cfg.datafile, 'VariableNamingRule','preserve');
T = height(DB);
fprintf('Loaded: %s (T=%d)\n', cfg.datafile, T);

[quarter_labels, has_quarter] = get_quarter_labels(DB, T);
if has_quarter
    fprintf('Sample: %s to %s\n', quarter_labels{1}, quarter_labels{end});
end

sample = true(T,1);

%% Load controls
[controls, control_names] = load_vars_direct(DB, cfg.control_vars, T);
fprintf('Macro controls: %s\n', strjoin(control_names, ', '));

[gpr_shock_lag1_oil_controls, gpr_shock_lag1_oil_control_names] = load_vars_direct(DB, cfg.gpr_shock_lag1_oil_controls, T);
fprintf('Oil controls for LP: %s\n', strjoin(gpr_shock_lag1_oil_control_names, ', '));

%% Load dummies
[dummy_aligned, dummy_controls, dummy_control_names, dummy_info] = build_aligned_dummy_controls(DB, quarter_labels, has_quarter, T, cfg);

fprintf('\nDummy controls:\n');
for j = 1:numel(dummy_control_names)
    fprintf('  %-22s ones=%3d/%d\n', dummy_control_names{j}, sum(dummy_controls(:,j)==1), T);
end

%% =======================================================================
%  Step 1: Load pre-computed GPR shocks from AR_GPR_shock.m output
%% =======================================================================

shock_mat_file = 'GPR_shock_output/workspace_gpr_shock.mat';
if ~exist(shock_mat_file, 'file')
    error('Pre-computed shock file not found: %s\nRun AR_GPR_shock.m first.', shock_mat_file);
end

loaded = load(shock_mat_file, 'Z_all', 'GPR_levels', 'innovation_info');
Z = loaded.Z_all.with_oil;          % use "with_oil" variant (includes lag-1 oil controls)
GPR_levels = loaded.GPR_levels;
innovation_info = loaded.innovation_info(strcmp(loaded.innovation_info.variant, 'with_oil'), :);

fprintf('\n--- Loaded GPR shocks from %s (with_oil) ---\n', shock_mat_file);
for s = 1:size(cfg.shock_specs,1)
    sid = cfg.shock_specs{s,1};
    if isfield(Z, sid)
        row = innovation_info(strcmp(innovation_info.shock, sid), :);
        if ~isempty(row)
            fprintf('  %-12s: nobs=%3d, R2=%.3f\n', sid, row.nobs, row.rsq);
        end
    end
end

%% GPR shock LPs (optional validation)
level_lp_results = table();
level_lp_struct = struct();

if cfg.run_gpr_shock_dashboards
    fprintf('\n--- GPR shock LPs ---\n');
    for s = 1:size(cfg.shock_specs,1)
        sid = cfg.shock_specs{s,1};
        z = Z.(sid);
        gpr_level = GPR_levels.(sid);

        res_list = cell(size(cfg.outcome_specs,1),1);
        plot_titles = cell(size(cfg.outcome_specs,1),1);

        for i = 1:size(cfg.outcome_specs,1)
            yid = cfg.outcome_specs{i,1};
            yvar = cfg.outcome_specs{i,2};
            ylabel = cfg.outcome_specs{i,3};
            y = DB.(yvar);

            res = estimate_lp_level_change(y, z, gpr_level, controls, dummy_controls, sample, cfg);
            level_lp_struct.(sid).(yid) = res;

            tmp = res.table;
            tmp.shock = repmat(string(sid), height(tmp), 1);
            tmp.outcome = repmat(string(yid), height(tmp), 1);
            level_lp_results = [level_lp_results; tmp];

            res_list{i} = res;
            plot_titles{i} = ylabel;
        end

        fig_title = sprintf('%s: LP response', sid);
        fig = plot_irf_dashboard(res_list, plot_titles, cfg, fig_title, cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);
        save_figure_if_needed(fig, cfg, fullfile(cfg.output_dir, ['dashboard_' sid]));
    end
end

%% =======================================================================
%  Step 2 + Step 3(a): Poisson residualization and LP
%% =======================================================================

event_residual_results = table();
event_joint_results = table();
event_residual_struct = struct();
event_residual_diagnostics = table();
event_residual_gpr_tests = table();

if cfg.run_event_residual_impulse_dashboards && ~isempty(dummy_aligned)
    fprintf('\n--- Poisson-residual event LPs ---\n');

    poisson_gpr_level = DB.(cfg.event_residual_poisson_gpr_var);
    z_for_poisson = Z.(cfg.event_residual_poisson_gpr_label);   % use pre-loaded shock
    gpr_level_for_poisson = zscore_in_sample(poisson_gpr_level, sample);

    [poisson_lambda_gpr_levels, ~] = load_vars_direct(DB, cfg.poisson_lagged_gpr_vars, T);

    event_resid_lp_dummy_controls = dummy_controls;
    event_resid_lp_dummy_names = dummy_control_names;

    for dd = 1:numel(cfg.event_impulse_vars)
        did = cfg.event_impulse_vars{dd};
        [dseries, did_source] = get_event_series(dummy_aligned, did, T);
        if isempty(dseries) || sum(dseries > 0) == 0
            warning('Event %s not found or all zero.', did);
            continue;
        end

        eres = estimate_poisson_event_residual(dseries, z_for_poisson, poisson_lambda_gpr_levels, controls, sample, cfg, did);
        event_residual_struct.(did).poisson = eres;
        event_residual_diagnostics = [event_residual_diagnostics; eres.diagnostics];

        if cfg.run_event_residual_gpr_tests
            gtest = estimate_event_residual_gpr_relation(did, eres.z_event_resid, z_for_poisson, gpr_level_for_poisson, sample, cfg);
            event_residual_struct.(did).gpr_residual_test = gtest;
            event_residual_gpr_tests = [event_residual_gpr_tests; gtest];
        end

        if sum(isfinite(eres.z_event_resid)) == 0
            warning('No finite residual for %s.', did);
            continue;
        end

        drop_names = make_event_drop_candidates(did, did_source);
        [dummy_controls_dd, dummy_names_dd] = drop_dummy_controls_by_names(event_resid_lp_dummy_controls, event_resid_lp_dummy_names, drop_names);

        fprintf('%s: positive=%d, nobs=%d, method=%s\n', did, sum(dseries>0), eres.nobs, char(eres.method));

        res_list = cell(size(cfg.outcome_specs,1),1);
        plot_titles = cell(size(cfg.outcome_specs,1),1);

        for i = 1:size(cfg.outcome_specs,1)
            yid = cfg.outcome_specs{i,1};
            yvar = cfg.outcome_specs{i,2};
            ylabel = cfg.outcome_specs{i,3};
            y = DB.(yvar);

            cfg_event = cfg;
            cfg_event.shock_size = 1;
            res = estimate_lp_level_change(y, eres.z_event_resid, poisson_gpr_level, controls, dummy_controls_dd, sample, cfg_event);
            event_residual_struct.(did).(yid) = res;

            tmp = res.table;
            tmp.impulse = repmat(string(did), height(tmp), 1);
            tmp.outcome = repmat(string(yid), height(tmp), 1);
            event_residual_results = [event_residual_results; tmp];

            res_list{i} = res;
            plot_titles{i} = ylabel;
        end

        if cfg.run_gpr_plus_event_residual_lp
            joint_list = cell(size(cfg.outcome_specs,1),1);

            for i = 1:size(cfg.outcome_specs,1)
                yid = cfg.outcome_specs{i,1};
                yvar = cfg.outcome_specs{i,2};
                ylabel = cfg.outcome_specs{i,3};
                y = DB.(yvar);

                [controls_joint, cfg_joint] = make_overlay_lp_controls(yid, controls, gpr_shock_lag1_oil_controls, gpr_shock_lag1_oil_control_names, dseries, cfg);

                joint = estimate_lp_level_change_two_impulses(y, z_for_poisson, eres.z_event_resid, poisson_gpr_level, controls_joint, dummy_controls_dd, sample, cfg_joint);
                event_residual_struct.(did).([yid '_joint_gpr_event']) = joint;

                joint_tmp = joint.table;
                joint_tmp.impulse = repmat(string(did), height(joint_tmp), 1);
                joint_tmp.outcome = repmat(string(yid), height(joint_tmp), 1);
                event_joint_results = [event_joint_results; joint_tmp];

                joint_list{i} = extract_two_impulse_component(joint, 2);
            end
        end
    end
end

%% =======================================================================
%  Step 3(b): Raw event count LPs
%% =======================================================================
event_count_joint_results = table();
event_count_joint_struct = struct();

if cfg.run_gpr_plus_event_count_lp && ~isempty(dummy_aligned)
    fprintf('\n--- Raw event count LPs ---\n');

    world_gpr_level = DB.(cfg.event_residual_poisson_gpr_var);
    z_world_gpr = Z.(cfg.event_residual_poisson_gpr_label);   % use pre-loaded shock

    for dd = 1:numel(cfg.event_impulse_vars)
        did = cfg.event_impulse_vars{dd};

        [N_event, did_source] = get_event_series(dummy_aligned, did, T);
        if isempty(N_event) || sum(N_event > 0) == 0
            continue;
        end

        drop_names = make_event_drop_candidates(did, did_source);
        [dummy_controls_dd, ~] = drop_dummy_controls_by_names(dummy_controls, dummy_control_names, drop_names);

        fprintf('%s: positive=%d\n', did, sum(N_event>0));

        for i = 1:size(cfg.outcome_specs,1)
            yid = cfg.outcome_specs{i,1};
            yvar = cfg.outcome_specs{i,2};
            y = DB.(yvar);

            [controls_joint, cfg_joint] = make_overlay_lp_controls(yid, controls, gpr_shock_lag1_oil_controls, gpr_shock_lag1_oil_control_names, N_event, cfg);

            joint = estimate_lp_level_change_two_impulses(y, z_world_gpr, N_event, world_gpr_level, controls_joint, dummy_controls_dd, sample, cfg_joint);
            event_count_joint_struct.(did).([yid '_joint_gpr_count']) = joint;

            joint_tmp = joint.table;
            joint_tmp.impulse = repmat(string(did), height(joint_tmp), 1);
            joint_tmp.outcome = repmat(string(yid), height(joint_tmp), 1);
            event_count_joint_results = [event_count_joint_results; joint_tmp];
        end
    end
end

%% =======================================================================
%  Step 4: Overlay dashboards (Poisson residual vs raw count)
%% =======================================================================
if cfg.make_poisson_vs_raw_overlay_dashboards
    fprintf('\n--- Overlay dashboards ---\n');

    for oo = 1:numel(cfg.poisson_vs_raw_overlay_events)
        did = cfg.poisson_vs_raw_overlay_events{oo};

        if ~isfield(event_residual_struct, did) || ~isfield(event_count_joint_struct, did)
            warning('Overlay skipped for %s', did);
            continue;
        end

        label = cfg.poisson_vs_raw_overlay_labels{oo};
        overlay_title = sprintf('%s: $z_t^{N,k}$ vs $N_t^k$', latex_escape_text(label));

        overlay_fig = plot_poisson_vs_raw_dashboard(event_residual_struct, event_count_joint_struct, did, cfg, overlay_title, cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);
        save_figure_if_needed(overlay_fig, cfg, fullfile(cfg.output_dir, ['overlay_' clean_file_string(did)]));
    end
end

%% Save results
if cfg.save_results
    mode_tag = clean_file_string(cfg.plot_mode);
    writetable(innovation_info, fullfile(cfg.output_dir, ['gpr_diagnostics_' mode_tag '.csv']));
    if ~isempty(event_residual_diagnostics)
        writetable(event_residual_diagnostics, fullfile(cfg.output_dir, ['poisson_diagnostics_' mode_tag '.csv']));
    end
    fprintf('\nResults saved to: %s\n', cfg.output_dir);
end

fprintf('\n=== Done ===\n');

%% Helper functions

function [quarter_labels, has_quarter] = get_quarter_labels(DB, T)
    quarter_labels = repmat({''}, T, 1);
    has_quarter = false;
    names = DB.Properties.VariableNames;
    for cand = {'quarter', 'Quarter', 'date', 'Date'}
        idx = find(strcmp(names, cand{1}), 1);
        if ~isempty(idx)
            q = DB.(names{idx});
            has_quarter = true;
            if iscell(q), quarter_labels = q(:);
            else, quarter_labels = cellstr(string(q(:))); end
            return;
        end
    end
end

function [data, names] = load_vars_direct(DB, varlist, T)
    data = [];
    names = {};
    for i = 1:numel(varlist)
        v = varlist{i};
        if ismember(v, DB.Properties.VariableNames)
            raw = DB.(v);
            if isnumeric(raw) || islogical(raw)
                data = [data, double(raw(:))];
                names{end+1} = v;
            end
        else
            warning('Variable not found: %s', v);
        end
    end
end

function [dummy_aligned, dummy_controls, dummy_control_names, info] = build_aligned_dummy_controls(DB, quarter_labels, has_quarter, T, cfg)
    dummy_aligned = table();
    dummy_controls = zeros(T,0);
    dummy_control_names = {};
    info = struct();

    if ~has_quarter, return; end

    q_db = string(quarter_labels(:));
    dummy_aligned = table(q_db, 'VariableNames', {'Quarter'});

    if cfg.use_event_dummies && exist(cfg.dummy_file, 'file')
        D = readtable(cfg.dummy_file, 'VariableNamingRule','preserve');
        qD = [];
        for cand = {'quarter','Quarter','date','Date'}
            if ismember(cand{1}, D.Properties.VariableNames)
                qD = string(D.(cand{1}));
                break;
            end
        end

        if ~isempty(qD)
            [tf, loc] = ismember(q_db, qD);
            for v = D.Properties.VariableNames
                vn = v{1};
                if any(strcmpi(vn, {'Quarter','quarter','Date','date','year','qtr'})), continue; end
                raw = D.(vn);
                if isnumeric(raw) || islogical(raw)
                    x = double(raw(:));
                    if numel(x) == numel(qD)
                        aligned = zeros(T,1);
                        aligned(tf) = x(loc(tf));
                        aligned(~isfinite(aligned)) = 0;
                        dummy_aligned.(matlab.lang.makeValidName(vn)) = aligned;
                    end
                end
            end
        end
    end

    if cfg.use_covid_dummy
        covid = double(ismember(q_db, string(cfg.covid_quarters(:))));
        dummy_aligned.(cfg.covid_dummy_name) = covid;
    end

    if ~ismember('AnyOilEvent', dummy_aligned.Properties.VariableNames)
        if ismember('OilThreat', dummy_aligned.Properties.VariableNames) && ismember('OilAct', dummy_aligned.Properties.VariableNames)
            dummy_aligned.AnyOilEvent = double((dummy_aligned.OilThreat ~= 0) | (dummy_aligned.OilAct ~= 0));
        else
            dummy_aligned.AnyOilEvent = zeros(T,1);
        end
    end

    base_vars = unique([{'OilThreat','OilAct','ThreatOnly','ActOnly','ThreatAct','AnyOilEvent'}, cfg.event_episode_vars], 'stable');
    for i = 1:numel(base_vars)
        v = base_vars{i};
        if ismember(v, dummy_aligned.Properties.VariableNames)
            oname = [v '_Onset'];
            if ~ismember(oname, dummy_aligned.Properties.VariableNames)
                dummy_aligned.(oname) = construct_onset_dummy(double(dummy_aligned.(v)(:)));
            end
        end
    end

    for i = 1:numel(cfg.dummy_control_vars)
        v = cfg.dummy_control_vars{i};
        if ismember(v, dummy_aligned.Properties.VariableNames)
            x = double(dummy_aligned.(v)(:));
            x(~isfinite(x)) = 0;
            dummy_controls = [dummy_controls, x];
            dummy_control_names{end+1} = v;
        end
    end
end

function onset = construct_onset_dummy(x)
    x = double(x(:) ~= 0);
    onset = zeros(size(x));
    if isempty(x), return; end
    onset(1) = x(1);
    if numel(x) >= 2
        onset(2:end) = double(x(2:end) == 1 & x(1:end-1) == 0);
    end
end

function [x, source] = get_event_series(dummy_aligned, varname, T)
    source = varname;
    x = [];
    if isempty(dummy_aligned), return; end

    if ismember(varname, dummy_aligned.Properties.VariableNames)
        x = double(dummy_aligned.(varname)(:));
        if numel(x) == T, return; end
    end

    if startsWith(varname, 'n_')
        alt = regexprep(varname, '^n_', '');
    else
        alt = ['n_' varname];
    end
    if ismember(alt, dummy_aligned.Properties.VariableNames)
        x = double(dummy_aligned.(alt)(:));
        source = alt;
    end
end

function candidates = make_event_drop_candidates(did, did_source)
    if nargin < 2, did_source = did; end
    base1 = regexprep(char(did), '^n_', '');
    base2 = regexprep(char(did_source), '^n_', '');
    candidates = unique({char(did), char(did_source), base1, base2, ['n_' base1], ['n_' base2]}, 'stable');
end

function [Xdrop, names_drop] = drop_dummy_controls_by_names(X, names, to_drop)
    Xdrop = X; names_drop = names;
    if isempty(names) || isempty(to_drop), return; end
    keep = true(1, numel(names));
    for j = 1:numel(names)
        keep(j) = ~any(strcmp(names{j}, to_drop));
    end
    Xdrop = Xdrop(:, keep);
    names_drop = names(keep);
end

% AR(p) shock extraction: x_t = a + sum rho_j x_{t-j} + current_t + lag1_{t-1} + u_t
function out = extract_ar_level_innovation_mixed_controls(x, sample, p, current_ctrl, lag1_ctrl, label)
    x = double(x(:));
    T = length(x);
    if isempty(current_ctrl), current_ctrl = zeros(T,0); end
    if isempty(lag1_ctrl), lag1_ctrl = zeros(T,0); end

    nC = size(current_ctrl, 2);
    nL = size(lag1_ctrl, 2);
    t_grid = (p+1):T;
    n = numel(t_grid);
    k = 1 + p + nC + nL;

    Y = nan(n,1); X = nan(n,k); keep = false(n,1);

    for ii = 1:n
        t = t_grid(ii);
        c = 1; row = nan(1,k);
        row(c) = 1; c = c + 1;
        for j = 1:p, row(c) = x(t-j); c = c + 1; end
        if nC > 0, row(c:c+nC-1) = current_ctrl(t,:); c = c + nC; end
        if nL > 0, row(c:c+nL-1) = lag1_ctrl(t-1,:); end
        Y(ii) = x(t); X(ii,:) = row;
        keep(ii) = sample(t) && all(sample(t-p:t));
    end

    good = keep & isfinite(Y) & all(isfinite(X),2);
    Yg = Y(good); Xg = X(good,:); tg = t_grid(good)';

    if isempty(Yg) || size(Xg,1) <= size(Xg,2)
        error('Insufficient obs for %s', label);
    end

    b = Xg \ Yg;
    fitted = nan(T,1); resid = nan(T,1);
    fitted(tg) = Xg * b; resid(tg) = Yg - Xg * b;
    u = resid(tg);
    sst = sum((Yg - mean(Yg)).^2);
    rsq = max(0, 1 - sum(u.^2) / sst);

    out = struct('label',label,'coeff',b,'fitted',fitted,'resid',resid,'nobs',numel(Yg),'rsq',rsq,'std_resid',std(u));
end

function z = zscore_in_sample(x, sample)
    x = x(:);
    use = sample & isfinite(x);
    mu = mean(x(use)); sd = std(x(use));
    if sd > 0, z = (x - mu) ./ sd; else, z = x; end
end

% Poisson GLM: N_t ~ Poisson(lambda_t), returns standardized Pearson residual
function out = estimate_poisson_event_residual(N, z_gpr, gpr_level, controls, sample, cfg, label)
    N = double(N(:));
    N(~isfinite(N)) = NaN;
    N(N < 0) = NaN;
    if isempty(z_gpr), z_gpr = nan(size(N)); else, z_gpr = z_gpr(:); end
    T = length(N);
    if isempty(gpr_level), gpr_level = nan(T,0); else
        gpr_level = double(gpr_level);
        if isvector(gpr_level), gpr_level = gpr_level(:); end
    end
    if isempty(controls), controls = zeros(T,0); end

    use_lagN = isfield(cfg, 'poisson_include_lagged_count') && cfg.poisson_include_lagged_count;
    use_lagC = isfield(cfg, 'poisson_include_lagged_controls') && cfg.poisson_include_lagged_controls && ~isempty(controls);

    p_gpr = 0;
    if isfield(cfg, 'poisson_include_lagged_gpr_level') && cfg.poisson_include_lagged_gpr_level
        p_gpr = cfg.poisson_gpr_level_lags;
    end
    min_lag = max(1, p_gpr);

    t_grid = (min_lag+1):T;
    Xraw = zeros(numel(t_grid), 0);

    include_gpr = ~(isfield(cfg, 'poisson_exclude_gpr_from_intensity') && cfg.poisson_exclude_gpr_from_intensity);

    if include_gpr
        if isfield(cfg, 'poisson_include_current_gpr_shock') && cfg.poisson_include_current_gpr_shock
            gpr_timing = 'current';
            if isfield(cfg, 'poisson_gpr_timing'), gpr_timing = lower(strtrim(cfg.poisson_gpr_timing)); end
            switch gpr_timing
                case {'current','contemporaneous','t'}, Xraw = [Xraw, z_gpr(t_grid)];
                case {'lagged','lag','tminus1','t-1'}, Xraw = [Xraw, z_gpr(t_grid-1)];
            end
        end
        if p_gpr > 0 && ~isempty(gpr_level)
            for jj = 1:p_gpr
                for gg = 1:size(gpr_level,2)
                    Xraw = [Xraw, gpr_level(t_grid-jj, gg)];
                end
            end
        end
    end

    if use_lagN, Xraw = [Xraw, N(t_grid-1)]; end
    if use_lagC, Xraw = [Xraw, controls(t_grid-1,:)]; end

    Y = N(t_grid);
    valid = sample(t_grid) & sample(t_grid-min_lag) & isfinite(Y) & all(isfinite(Xraw),2);
    Yuse = Y(valid); Xuse_raw = Xraw(valid,:);

    min_pos = 4;
    if isfield(cfg, 'poisson_min_positive_periods'), min_pos = cfg.poisson_min_positive_periods; end

    n_pos = sum(Yuse > 0);
    n_zero = sum(Yuse == 0);
    total_count = sum(Yuse);

    z_event_resid = nan(T,1);
    lambda_hat = nan(T,1);
    method = "not_estimated";
    converged = false;
    resid_sd = NaN;

    if numel(Yuse) > size(Xuse_raw,2) + 1 && n_pos >= min_pos && total_count > 0
        Xuse = Xuse_raw;
        if isfield(cfg, 'poisson_standardize_predictors') && cfg.poisson_standardize_predictors
            for j = 1:size(Xuse,2)
                mu = mean(Xuse(:,j)); sd = std(Xuse(:,j));
                if sd > 0, Xuse(:,j) = (Xuse(:,j) - mu) / sd; end
            end
        end

        [b, method, converged] = fit_poisson_count(Yuse, Xuse, cfg);
        eta_use = [ones(size(Xuse,1),1), Xuse] * b;
        lam_use = exp(max(min(eta_use, 30), -30));
        lam_use = max(min(lam_use, 1e8), 1e-8);

        pearson_use = (Yuse - lam_use) ./ sqrt(lam_use);
        resid_sd = std(pearson_use, 'omitnan');
        if isfinite(resid_sd) && resid_sd > 0
            z_use = (pearson_use - mean(pearson_use, 'omitnan')) ./ resid_sd;
        else
            z_use = pearson_use;
        end

        idx = t_grid(valid);
        lambda_hat(idx) = lam_use;
        z_event_resid(idx) = z_use;
    end

    diag = table(string(label), string(method), converged, numel(Yuse), n_pos, n_zero, total_count, ...
        NaN, NaN, resid_sd, NaN, NaN, ...
        'VariableNames', {'event','method','converged','nobs','positive_periods','zero_periods','total_count', ...
        'mean_lambda_positive','mean_lambda_zero','pearson_resid_sd','corr_N_lambda','deviance'});

    out = struct('label',label,'N',N,'z_event_resid',z_event_resid,'lambda_hat',lambda_hat,...
        'nobs',numel(Yuse),'positive_periods',n_pos,'method',method,'converged',converged,'resid_sd',resid_sd,'diagnostics',diag);
end

function [b, method, converged] = fit_poisson_count(Y, X, cfg)
    Y = double(Y(:)); k = size(X,2);
    if exist('glmfit', 'file') == 2
        try
            [b, ~, stats] = glmfit(X, Y, 'poisson', 'link', 'log');
            method = "glmfit_poisson";
            converged = ~any(~isfinite(stats.se));
            return;
        catch, end
    end
    b0 = zeros(k+1,1); b0(1) = log(max(mean(Y), 1e-6));
    lambda = 0; if isfield(cfg, 'poisson_ridge_lambda'), lambda = cfg.poisson_ridge_lambda; end
    obj = @(theta) poisson_nll(theta, Y, X, lambda);
    opts = optimset('Display','off', 'MaxIter', 20000, 'TolX', 1e-8, 'TolFun', 1e-8);
    [b, ~, exitflag] = fminsearch(obj, b0, opts);
    method = "fminsearch_poisson"; converged = exitflag > 0;
end

function nll = poisson_nll(theta, Y, X, lambda)
    eta = [ones(size(X,1),1), X] * theta(:);
    mu = exp(max(min(eta, 30), -30));
    mu = max(min(mu, 1e8), 1e-8);
    nll = -sum(Y .* log(mu) - mu - gammaln(Y + 1));
    if lambda > 0, nll = nll + lambda * sum(theta(2:end).^2); end
end

function outtab = estimate_event_residual_gpr_relation(event_id, z_event, z_gpr, gpr_level, sample, cfg)
    y = double(z_event(:)); x1 = double(z_gpr(:)); x2 = double(gpr_level(:));
    threshold = 1.0; if isfield(cfg, 'gpr_high_threshold'), threshold = cfg.gpr_high_threshold; end
    valid = sample & isfinite(y) & isfinite(x1) & isfinite(x2);
    nobs = sum(valid);
    beta_shock = NaN; se_shock = NaN; corr_shock = NaN;
    beta_level = NaN; se_level = NaN; corr_level = NaN;
    if nobs > 5
        Y = y(valid); X = [ones(nobs,1), x1(valid), x2(valid)];
        [b, se] = ols_hac(Y, X, 0);
        beta_shock = b(2); se_shock = se(2);
        beta_level = b(3); se_level = se(3);
        corr_shock = corr(Y, x1(valid), 'Rows','complete');
        corr_level = corr(Y, x2(valid), 'Rows','complete');
    end
    outtab = table(string(event_id), nobs, threshold, beta_shock, se_shock, corr_shock, beta_level, se_level, corr_level, ...
        'VariableNames', {'event','nobs','threshold','beta_gpr_shock','se_gpr_shock','corr_gpr_shock','beta_gpr_level','se_gpr_level','corr_gpr_level'});
end

function [controls_out, cfg_out] = make_overlay_lp_controls(yid, macro_ctrl, oil_ctrl, oil_names, event_count, cfg)
    oil_keep = true(1, numel(oil_names));
    for i = 1:numel(oil_names)
        if strcmpi(yid, oil_names{i}), oil_keep(i) = false; end
    end
    controls_out = [macro_ctrl, oil_ctrl(:, oil_keep), event_count(:)];
    cfg_out = cfg;
    if isfield(cfg, 'p_dynamic_lp_event_count'), cfg_out.p_lp = cfg.p_dynamic_lp_event_count; end
    if isfield(cfg, 'p_macro_lp_event_count'), cfg_out.p_control_lag_two_impulses = cfg.p_macro_lp_event_count;
    else, cfg_out.p_control_lag_two_impulses = 1; end
    cfg_out.n_full_lag_controls_two_impulses = sum(oil_keep) + 1;
    cfg_out.shock_size_z1 = cfg.shock_size;
    cfg_out.shock_size_z2 = 1;
end

% LP level-change: y_{t+h} - y_{t-1} = a + b*z_t + lags + dummies + e
function res = estimate_lp_level_change(y, z, gpr_level, controls, dummy_controls, sample, cfg)
    H = cfg.H;
    zcrit = norminv(0.5 + cfg.ci/2);
    beta = nan(H+1,1); se = nan(H+1,1); lb = nan(H+1,1); ub = nan(H+1,1); nobs = nan(H+1,1);

    for h = 0:H
        [Y, X] = build_lp_design(y, z, gpr_level, controls, dummy_controls, sample, cfg.p_lp, h);
        if isempty(Y) || size(X,1) <= size(X,2), continue; end
        bw = min(h + 1, size(X,1)-1);
        [b, se_all] = ols_hac(Y, X, bw);
        beta(h+1) = cfg.shock_size * b(2);
        se(h+1) = cfg.shock_size * se_all(2);
        lb(h+1) = beta(h+1) - zcrit * se(h+1);
        ub(h+1) = beta(h+1) + zcrit * se(h+1);
        nobs(h+1) = size(X,1);
    end

    res = struct('h',(0:H)','beta',beta,'se',se,'lb',lb,'ub',ub,'nobs',nobs);
    res.table = table((0:H)', beta, se, lb, ub, nobs, 'VariableNames', {'h','beta','se','lb','ub','nobs'});
end

% Joint LP with two impulses: y_{t+h} - y_{t-1} = a + b1*z1 + b2*z2 + ...
function res = estimate_lp_level_change_two_impulses(y, z1, z2, gpr_level, controls, dummy_controls, sample, cfg)
    H = cfg.H;
    zcrit = norminv(0.5 + cfg.ci/2);
    scale1 = cfg.shock_size; scale2 = 1;
    if isfield(cfg, 'shock_size_z1'), scale1 = cfg.shock_size_z1; end
    if isfield(cfg, 'shock_size_z2'), scale2 = cfg.shock_size_z2; end

    beta1 = nan(H+1,1); se1 = nan(H+1,1); lb1 = nan(H+1,1); ub1 = nan(H+1,1);
    beta2 = nan(H+1,1); se2 = nan(H+1,1); lb2 = nan(H+1,1); ub2 = nan(H+1,1);
    nobs = nan(H+1,1);

    for h = 0:H
        [Y, X] = build_lp_design_two(y, z1, z2, gpr_level, controls, dummy_controls, sample, cfg.p_lp, h, cfg);
        if isempty(Y) || size(X,1) <= size(X,2), continue; end
        bw = min(h + 1, size(X,1)-1);
        [b, se_all] = ols_hac(Y, X, bw);
        beta1(h+1) = scale1 * b(2); se1(h+1) = scale1 * se_all(2);
        lb1(h+1) = beta1(h+1) - zcrit * se1(h+1); ub1(h+1) = beta1(h+1) + zcrit * se1(h+1);
        beta2(h+1) = scale2 * b(3); se2(h+1) = scale2 * se_all(3);
        lb2(h+1) = beta2(h+1) - zcrit * se2(h+1); ub2(h+1) = beta2(h+1) + zcrit * se2(h+1);
        nobs(h+1) = size(X,1);
    end

    res = struct('h',(0:H)','beta1',beta1,'se1',se1,'lb1',lb1,'ub1',ub1,'beta2',beta2,'se2',se2,'lb2',lb2,'ub2',ub2,'nobs',nobs);
    res.table = table((0:H)', beta1, se1, lb1, ub1, beta2, se2, lb2, ub2, nobs, ...
        'VariableNames', {'h','beta_gpr','se_gpr','lb_gpr','ub_gpr','beta_event','se_event','lb_event','ub_event','nobs'});
end

function comp = extract_two_impulse_component(joint, which)
    comp = struct('h',joint.h,'nobs',joint.nobs);
    if which == 1
        comp.beta = joint.beta1; comp.se = joint.se1; comp.lb = joint.lb1; comp.ub = joint.ub1;
    else
        comp.beta = joint.beta2; comp.se = joint.se2; comp.lb = joint.lb2; comp.ub = joint.ub2;
    end
end

% LP design matrix: [const, z_t, dummies_t, y_lags, gpr_lags, ctrl_lags]
function [Y, X] = build_lp_design(y, z, gpr_level, controls, dummy_controls, sample, p, h)
    y = y(:); z = z(:); gpr_level = gpr_level(:);
    T = length(y);
    if isempty(controls), controls = zeros(T,0); end
    if isempty(dummy_controls), dummy_controls = zeros(T,0); end
    nC = size(controls,2); nD = size(dummy_controls,2);

    t_grid = (p+1):(T-h);
    n = numel(t_grid);
    k = 1 + 1 + nD + p + p + p*nC;

    Y = nan(n,1); X = nan(n,k); good = false(n,1);

    for ii = 1:n
        t = t_grid(ii);
        Y(ii) = y(t+h) - y(t-1);
        c = 1; row = nan(1,k);
        row(c) = 1; c = c + 1;
        row(c) = z(t); c = c + 1;
        if nD > 0, row(c:c+nD-1) = dummy_controls(t,:); c = c + nD; end
        for j = 1:p, row(c) = y(t-j); c = c + 1; end
        for j = 1:p, row(c) = gpr_level(t-j); c = c + 1; end
        if nC > 0
            for j = 1:p, row(c:c+nC-1) = controls(t-j,:); c = c + nC; end
        end
        X(ii,:) = row;
        good(ii) = sample(t) && sample(t+h) && all(sample(t-p:t)) && isfinite(Y(ii)) && all(isfinite(row));
    end
    Y = Y(good); X = X(good,:);
end

function [Y, X] = build_lp_design_two(y, z1, z2, gpr_level, controls, dummy_controls, sample, p, h, cfg)
    y = y(:); z1 = z1(:); z2 = z2(:); gpr_level = gpr_level(:);
    T = length(y);
    if isempty(controls), controls = zeros(T,0); end
    if isempty(dummy_controls), dummy_controls = zeros(T,0); end
    nC = size(controls,2); nD = size(dummy_controls,2);

    p_ctrl = p;
    if isfield(cfg, 'p_control_lag_two_impulses'), p_ctrl = min(p, cfg.p_control_lag_two_impulses); end
    n_full = 0;
    if isfield(cfg, 'n_full_lag_controls_two_impulses'), n_full = min(nC, cfg.n_full_lag_controls_two_impulses); end
    n_short = nC - n_full;
    p_max = max(p, p_ctrl);

    t_grid = (p_max+1):(T-h);
    n = numel(t_grid);
    k = 1 + 2 + nD + p + p + p_ctrl*n_short + p*n_full;

    Y = nan(n,1); X = nan(n,k); good = false(n,1);

    for ii = 1:n
        t = t_grid(ii);
        Y(ii) = y(t+h) - y(t-1);
        c = 1; row = nan(1,k);
        row(c) = 1; c = c + 1;
        row(c) = z1(t); c = c + 1;
        row(c) = z2(t); c = c + 1;
        if nD > 0, row(c:c+nD-1) = dummy_controls(t,:); c = c + nD; end
        for j = 1:p, row(c) = y(t-j); c = c + 1; end
        for j = 1:p, row(c) = gpr_level(t-j); c = c + 1; end
        if n_short > 0 && p_ctrl > 0
            for j = 1:p_ctrl, row(c:c+n_short-1) = controls(t-j, 1:n_short); c = c + n_short; end
        end
        if n_full > 0
            for j = 1:p, row(c:c+n_full-1) = controls(t-j, n_short+1:nC); c = c + n_full; end
        end
        X(ii,:) = row;
        good(ii) = sample(t) && sample(t+h) && all(sample(t-p_max:t)) && isfinite(Y(ii)) && all(isfinite(row));
    end
    Y = Y(good); X = X(good,:);
end

% OLS with Newey-West HAC SE (Bartlett kernel, bandwidth bw)
function [b, se] = ols_hac(y, X, bw)
    [n, k] = size(X);
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
            xt = X(t, :)'; xtL = X(t-L, :)';
            Gamma = Gamma + u(t) * u(t-L) * (xt * xtL');
        end
        S = S + wL * (Gamma + Gamma');
    end
    V = (n / (n - k)) * XtX_inv * S * XtX_inv;
    se = sqrt(max(diag(V),0));
end

%% Plotting functions

function fig = plot_irf_dashboard(res_list, titles, cfg, fig_title, nrow, ncol, show_figures)
    if show_figures, fig = figure('Color','w','Position',[80,60,1500,850]);
    else, fig = figure('Color','w','Position',[80,60,1500,850], 'Visible','off'); end
    use_latex = isfield(cfg, 'use_latex_fonts') && cfg.use_latex_fonts;
    fs = cfg.figure_font_size;

    for i = 1:numel(res_list)
        ax = subplot(nrow, ncol, i); hold(ax, 'on');
        r = res_list{i}; h = r.h(:)';
        fb = isfinite(r.beta); fc = isfinite(r.lb) & isfinite(r.ub);
        if sum(fb) == 0
            text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment','center', 'Units','normalized');
            title(ax, titles{i}, 'Interpreter','none'); continue;
        end
        if sum(fc) >= 2
            hci = h(fc);
            fill(ax, [hci, fliplr(hci)], [r.ub(fc)', fliplr(r.lb(fc)')], cfg.ci_band_color, 'EdgeColor','none', 'FaceAlpha', cfg.ci_band_alpha);
        end
        plot(ax, h(fb), r.beta(fb), 'k-', 'LineWidth', cfg.irf_line_width);
        plot(ax, h, zeros(size(h)), 'k--', 'LineWidth', cfg.zero_line_width);
        grid(ax, 'on'); box(ax, 'on'); xlim(ax, [0 cfg.H]);
        xlabel(ax, cfg.horizon_label, 'FontSize', fs);
        ylabel(ax, 'Level change', 'FontSize', fs);
        if use_latex, title(ax, ['\textbf{' latex_escape_text(titles{i}) '}'], 'Interpreter','latex');
        else, title(ax, titles{i}, 'Interpreter','none'); end
    end
    if use_latex, sgtitle(fig, ['\textbf{' latex_escape_text(fig_title) '}'], 'Interpreter','latex');
    else, sgtitle(fig, fig_title, 'Interpreter','none'); end
    drawnow;
end

function fig = plot_poisson_vs_raw_dashboard(ers, ecjs, did, cfg, fig_title, nrow, ncol, show_figures)
    if show_figures, fig = figure('Color','w','Position',[80,60,1550,900]);
    else, fig = figure('Color','w','Position',[80,60,1550,900], 'Visible','off'); end
    use_latex = isfield(cfg, 'use_latex_fonts') && cfg.use_latex_fonts;
    fs = cfg.figure_font_size;
    lw = cfg.poisson_vs_raw_line_width; ci_alpha = cfg.poisson_vs_raw_ci_alpha;
    raw_col = cfg.poisson_vs_raw_raw_color; poi_col = cfg.poisson_vs_raw_poisson_color;
    raw_sty = cfg.poisson_vs_raw_raw_line_style; poi_sty = cfg.poisson_vs_raw_poisson_line_style;

    for i = 1:size(cfg.outcome_specs,1)
        ax = subplot(nrow, ncol, i); hold(ax, 'on');
        yid = cfg.outcome_specs{i,1}; olabel = cfg.outcome_specs{i,3};
        raw_f = [yid '_joint_gpr_count']; poi_f = [yid '_joint_gpr_event'];
        has_raw = isfield(ecjs, did) && isfield(ecjs.(did), raw_f);
        has_poi = isfield(ers, did) && isfield(ers.(did), poi_f);

        if has_raw
            rc = extract_two_impulse_component(ecjs.(did).(raw_f), 2);
            plot_irf_band(ax, rc, raw_col, ci_alpha, raw_sty, lw);
        end
        if has_poi
            pc = extract_two_impulse_component(ers.(did).(poi_f), 2);
            plot_irf_band(ax, pc, poi_col, ci_alpha, poi_sty, lw);
        end

        plot(ax, 0:cfg.H, zeros(1,cfg.H+1), 'k--', 'LineWidth', cfg.zero_line_width);
        grid(ax, 'on'); box(ax, 'on'); xlim(ax, [0 cfg.H]);
        xlabel(ax, cfg.horizon_label, 'FontSize', fs);
        ylabel(ax, 'Level change', 'FontSize', fs);
        if use_latex, title(ax, ['\textbf{' latex_escape_text(olabel) '}'], 'Interpreter','latex');
        else, title(ax, olabel, 'Interpreter','none'); end
        if i == 1 && (has_raw || has_poi)
            if use_latex, legend(ax, {'Raw $N_t^k$', 'Poisson $z_t^{N,k}$'}, 'Interpreter','latex', 'Location','best', 'Box','off');
            else, legend(ax, {'Raw N_t', 'Poisson z_t'}, 'Location','best', 'Box','off'); end
        end
    end
    if use_latex, sgtitle(fig, fig_title, 'Interpreter','latex');
    else, sgtitle(fig, regexprep(fig_title, '\$|\{|\}|\^|_', ''), 'Interpreter','none'); end
    drawnow;
end

function plot_irf_band(ax, r, col, ci_alpha, lsty, lw)
    h = r.h(:)'; fb = isfinite(r.beta); fc = isfinite(r.lb) & isfinite(r.ub);
    if sum(fc) >= 2
        hci = h(fc);
        fill(ax, [hci, fliplr(hci)], [r.ub(fc)', fliplr(r.lb(fc)')], col, 'EdgeColor','none', 'FaceAlpha', ci_alpha, 'HandleVisibility','off');
    end
    if sum(fb) > 0
        plot(ax, h(fb), r.beta(fb), 'LineStyle', lsty, 'Color', col, 'LineWidth', lw);
    end
end

function apply_latex_graphics_defaults(cfg)
    if isfield(cfg, 'use_latex_fonts') && cfg.use_latex_fonts
        set(groot, 'defaultTextInterpreter','latex');
        set(groot, 'defaultAxesTickLabelInterpreter','latex');
        set(groot, 'defaultLegendInterpreter','latex');
    end
    if isfield(cfg, 'figure_font_size'), set(groot, 'defaultAxesFontSize', cfg.figure_font_size); end
    set(groot, 'defaultAxesFontWeight','bold');
    set(groot, 'defaultLineLineWidth', 2.0);
end

function s = latex_escape_text(s)
    s = char(string(s));
    s = strrep(s, '\', '\textbackslash{}');
    s = strrep(s, '_', '\_');
    s = strrep(s, '%', '\%');
    s = strrep(s, '&', '\&');
    s = strrep(s, '#', '\#');
end

function save_figure_if_needed(fig, cfg, base_path)
    if ~cfg.save_figures, return; end
    if isempty(fig) || ~isgraphics(fig, 'figure'), return; end
    drawnow;
    try, savefig(fig, [base_path '.fig']); catch, end
    try, exportgraphics(fig, [base_path '.png'], 'Resolution', 300);
    catch, try, print(fig, [base_path '.png'], '-dpng', '-r300'); catch, end, end
end

function s = clean_file_string(s)
    s = char(s);
    s = regexprep(s, '[^A-Za-z0-9_\-]+', '_');
    s = regexprep(s, '_+', '_');
end
