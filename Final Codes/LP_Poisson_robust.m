%% =======================================================================
% LP_Poisson_robust.m
% ------------------------------------------------------------------------
% Poisson-residualized event-arrival shock analysis with GPR controls.
%
% Step 1.  Load pre-computed GPR shocks from AR_GPR_shock.m output:
%          Z_all.with_oil.{World, GPT, GPA}
%
% Step 2.  Estimate baseline level LP for each GPR shock:
%          y_{t+h} - y_{t-1} = α + β·z_t^{GPR} + controls + ε_{t+h}
%
% Step 3.  Poisson event-arrival residualization:
%          N_t^k ~ Poisson(λ_t^k)
%          log(λ_t^k) = α + γ·z_t^{WorldGPR} + ψ'GPR_{t-1} + ρ·N_{t-1}^k + η'W_{t-1}
%          z_t^{N,k} = (N_t - λ_hat) / sqrt(λ_hat)  (standardized Pearson residual)
%
% Step 4.  Joint LP: GPR shock + Poisson event-arrival shock
%          y_{t+h} - y_{t-1} = α + θ·z_t^{WorldGPR} + β·z_t^{N,k} + controls + ε_{t+h}
%
% Step 5.  Robustness: raw event count N_t^k (FWL baseline)
%
% Inference: Newey-West HAC SE, bandwidth = h+1.
%% =======================================================================

clear; clc; close all;

%% ========================================================================
%  USER SETTINGS
%% ========================================================================
cfg.datafile     = 'Q_Levels_Database.csv';
cfg.dummy_file   = 'oil_relevant_gpr_event_dummies_extended_onset_realized_1986Q1_2025Q4.csv';
cfg.shock_file   = 'GPR_shock_output/workspace_gpr_shock.mat';
cfg.output_dir   = 'LP_Poisson_robust_output';

cfg.save_results = true;
cfg.save_figures = true;
cfg.show_figures = true;

%% Figure style
cfg.use_latex_fonts       = true;
cfg.figure_font_size      = 16;
cfg.figure_title_font_size = 18;
cfg.figure_axis_line_width = 1.4;
cfg.ci_band_color  = [0.45 0.45 0.45];
cfg.ci_band_alpha  = 0.75;
cfg.irf_line_width = 3.2;
cfg.zero_line_width = 1.4;

%% Plot mode: 'aggregate', 'countries', or 'all'
cfg.plot_mode = 'countries';

%% LP specification
cfg.p_lp       = 4;
cfg.H          = 12;
cfg.ci         = 0.90;
cfg.shock_size = 1;

%% Compact event-count LP controls
cfg.use_compact_event_count_lp = true;
cfg.p_dynamic_lp_event_count   = 2;
cfg.p_macro_lp_event_count     = 1;

%% COVID dummy
cfg.use_covid_dummy   = true;
cfg.covid_dummy_name  = 'COVID_2020';
cfg.covid_quarters    = {'2020Q1','2020Q2','2020Q3','2020Q4'};

%% Event onset controls
cfg.event_onset_control_vars = { ...
    'OilSpecificThreatShock_EventOnset', ...
    'OilSpecificRealizedShock_EventOnset', ...
    'StrictSupplyDisruption_EventOnset', ...
    'ChokepointShippingRisk_EventOnset', ...
    'EnergySanction_EventOnset', ...
    'ProducerRegionRisk_EventOnset' ...
};
cfg.dummy_control_vars = [{'COVID_2020'}, cfg.event_onset_control_vars];

%% Event impulse variables (n_* count columns)
cfg.event_impulse_vars = { ...
    'n_OilSpecificThreatShock_EventOnset', ...
    'n_OilSpecificRealizedShock_EventOnset', ...
    'n_StrictSupplyDisruption_EventOnset', ...
    'n_ChokepointShippingRisk_EventOnset', ...
    'n_EnergySanction_EventOnset', ...
    'n_ProducerRegionRisk_EventOnset' ...
};

%% Analysis switches
cfg.run_event_residual_impulse_dashboards    = true;
cfg.run_gpr_plus_event_residual_lp           = true;
cfg.run_gpr_plus_event_count_lp              = false;
cfg.run_poisson_arrival_rawN_control_robustness = true;
cfg.run_event_onset_impulse_dashboards       = false;
cfg.run_event_residual_gpr_tests             = true;
cfg.gpr_high_threshold = 1.0;

%% Combined figure settings
cfg.make_combined_fig_12_14_16     = false;
cfg.skip_individual_fig_12_14_16   = false;
cfg.combined_fig_12_14_16_events   = { ...
    'n_EnergySanction_EventOnset',          'Energy sanction onset',          [0.00 0.00 0.00]; ...
    'n_ChokepointShippingRisk_EventOnset',  'Chokepoint shipping onset',      [0.85 0.10 0.10]; ...
    'n_StrictSupplyDisruption_EventOnset',  'Strict supply disruption onset', [0.05 0.25 0.90]  ...
};
cfg.combined_fig_12_14_16_ci_alpha   = 0.30;
cfg.combined_fig_12_14_16_line_width = 3.2;

%% Poisson residualization settings
cfg.poisson_exclude_gpr_from_intensity   = false;
cfg.poisson_include_current_gpr_shock    = true;
cfg.poisson_include_lagged_gpr_level     = true;
cfg.poisson_gpr_level_lags               = 1;
cfg.poisson_include_lagged_count         = true;
cfg.poisson_include_lagged_controls      = true;
cfg.poisson_standardize_predictors       = true;
cfg.poisson_min_positive_periods         = 4;
cfg.poisson_ridge_lambda                 = 1e-6;
cfg.poisson_gpr_timing                   = 'current';

%% Macro control variables (direct names)
cfg.macro_control_vars = {'Unemp', 'FFR', 'WEO_Growth', 'WEO_Revision', 'r_y', 'Indu_Prod'};

%% GPR shock specs
cfg.aggregate_shock_specs = {
    'World', 'LGPR',  'World GPR shock';
    'GPT',   'LGPRT', 'Global geopolitical threats shock';
    'GPA',   'LGPRA', 'Global geopolitical acts shock'
};

cfg.country_shock_specs = {
    'US',          'LGPRUS',  'U.S. GPR shock';
    'Israel',      'LGPRISR', 'Israel GPR shock';
    'Russia',      'LGPRRU',  'Russia GPR shock';
    'China',       'LGPRCHN', 'China GPR shock';
    'Venezuela',   'LGPRVZ',  'Venezuela GPR shock';
    'SaudiArabia', 'LGPRSAR', 'Saudi Arabia GPR shock'
};

%% Select shock block by plot_mode
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
        error('Unknown cfg.plot_mode = %s. Use aggregate, countries, or all.', cfg.plot_mode);
end

%% Outcome specifications
cfg.outcome_specs = {
    'Real_Brent',    'Real_Brent',    'Brent crude oil price';
    'Real_WTI',      'Real_WTI',      'WTI crude oil price';
    'Real_Gasoline', 'Real_Gasoline', 'Gasoline price';
    'inv_OECD',      'inv_OECD',      'OECD inventory';
    'inv_USA',       'inv_USA',       'U.S. inventory';
    'WorldCP',       'WorldCP',       'World crude-oil production'
};

cfg.dashboard_nrow   = 2;
cfg.dashboard_ncol   = 3;
cfg.horizon_label    = 'Horizon (quarters)';

%% GPR series for Poisson intensity
cfg.event_residual_poisson_gpr_var   = 'LGPR';
cfg.event_residual_poisson_gpr_label = 'World';
cfg.poisson_lagged_gpr_level_vars    = {'LGPR', 'LGPRT', 'LGPRA'};
cfg.poisson_lagged_gpr_level_labels  = {'WorldGPR', 'ThreatGPR', 'ActGPR'};

apply_latex_graphics_defaults(cfg);

%% ========================================================================
%  STEP 1: LOAD DATA AND GPR SHOCKS
%% ========================================================================
if cfg.save_results || cfg.save_figures
    if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
end

fprintf('\n=== Level LP with Poisson event-arrival residuals ===\n');
fprintf('Plot mode: %s | Shock block: %s | Shocks: %d\n', cfg.plot_mode, cfg.shock_group_label, size(cfg.shock_specs,1));

%% Load level database
if ~exist(cfg.datafile, 'file')
    error('Data file not found: %s', cfg.datafile);
end
DB = readtable(cfg.datafile, 'VariableNamingRule', 'preserve');
T = height(DB);
fprintf('Loaded %s: T=%d rows\n', cfg.datafile, T);

%% Get quarter labels
[quarter_labels, has_quarter] = get_quarter_labels(DB, T);
if has_quarter
    fprintf('Sample: %s to %s\n', quarter_labels{1}, quarter_labels{end});
end
sample = true(T, 1);

%% Load macro controls (direct variable names)
[controls, control_names] = load_vars_direct(DB, cfg.macro_control_vars, T);
fprintf('Macro controls: %s\n', strjoin(control_names, ', '));

%% Load GPR shocks: aggregate from file, country-specific extracted on-the-fly
loaded = struct();
if exist(cfg.shock_file, 'file')
    loaded = load(cfg.shock_file, 'Z_all', 'GPR_levels', 'innovation_info');
    fprintf('Loaded aggregate GPR shocks from: %s\n', cfg.shock_file);
else
    fprintf('GPR shock file not found: %s (will extract all shocks on-the-fly)\n', cfg.shock_file);
end

%% Controls for GPR shock extraction (needed for country-specific)
cfg.p_gpr_shock = 4;
gpr_shock_current_controls = [];
gpr_shock_lag1_oil_controls = [];
for v = {'Unemp', 'FFR'}
    x = get_series_if_exists(DB, v{1}, T);
    if ~isempty(x), gpr_shock_current_controls = [gpr_shock_current_controls, x]; end
end
for v = {'Real_Brent', 'Real_WTI', 'Real_Gasoline'}
    x = get_series_if_exists(DB, v{1}, T);
    if ~isempty(x), gpr_shock_lag1_oil_controls = [gpr_shock_lag1_oil_controls, x]; end
end

%% Map shock specs to data
Z = struct();
GPR_levels = struct();
innovation_info = table();

fprintf('\n--- Constructing GPR shocks ---\n');
for s = 1:size(cfg.shock_specs,1)
    sid = cfg.shock_specs{s,1};
    gpr_col = cfg.shock_specs{s,2};
    label = cfg.shock_specs{s,3};

    % Get GPR levels
    gpr_level = get_series_if_exists(DB, gpr_col, T);
    if isempty(gpr_level)
        error('GPR level variable %s not found in database', gpr_col);
    end
    GPR_levels.(sid) = gpr_level;

    % Try to load from file first (aggregate shocks)
    if isfield(loaded, 'Z_all') && isfield(loaded.Z_all, 'with_oil') && isfield(loaded.Z_all.with_oil, sid)
        Z.(sid) = loaded.Z_all.with_oil.(sid);
        fprintf('  %-12s: loaded from file, finite z = %d\n', sid, sum(isfinite(Z.(sid))));

        % Get diagnostics from loaded data
        if isfield(loaded, 'innovation_info') && istable(loaded.innovation_info)
            idx = find(strcmp(loaded.innovation_info.shock, sid) & strcmp(loaded.innovation_info.oil_spec, 'with_oil'), 1);
            if ~isempty(idx)
                row = loaded.innovation_info(idx, :);
                innovation_info = [innovation_info; table(string(sid), string(label), row.nobs, row.rsq, row.resid_sd, sum(isfinite(Z.(sid))), ...
                    'VariableNames', {'shock','label','nobs','rsq','resid_sd','finite_z'})]; %#ok<AGROW>
            end
        end
    else
        % Extract on-the-fly (country-specific shocks)
        innov = extract_ar_innovation(gpr_level, sample, cfg.p_gpr_shock, gpr_shock_current_controls, gpr_shock_lag1_oil_controls, sid);
        Z.(sid) = zscore_in_sample(innov.resid, sample);
        fprintf('  %-12s: extracted AR(%d), nobs=%d, R2=%.3f, finite z = %d\n', sid, cfg.p_gpr_shock, innov.nobs, innov.rsq, sum(isfinite(Z.(sid))));

        innovation_info = [innovation_info; table(string(sid), string(label), innov.nobs, innov.rsq, innov.std_resid, sum(isfinite(Z.(sid))), ...
            'VariableNames', {'shock','label','nobs','rsq','resid_sd','finite_z'})]; %#ok<AGROW>
    end
end

%% ========================================================================
%  STEP 2: LOAD AND ALIGN DUMMY CONTROLS
%% ========================================================================
fprintf('\n--- Loading event dummies ---\n');
[dummy_aligned, dummy_controls, dummy_control_names] = build_aligned_dummy_controls(DB, quarter_labels, has_quarter, T, cfg);

if ~isempty(dummy_control_names)
    fprintf('Dummy controls: %s\n', strjoin(dummy_control_names, ', '));
else
    fprintf('Dummy controls: none\n');
end

%% ========================================================================
%  STEP 3: ESTIMATE LEVEL LOCAL PROJECTIONS
%% ========================================================================
level_lp_results = table();
level_lp_struct = struct();

fprintf('\n--- Estimating level local projections ---\n');
for s = 1:size(cfg.shock_specs,1)
    sid = cfg.shock_specs{s,1};
    z = Z.(sid);
    gpr_level = GPR_levels.(sid);

    res_list = cell(size(cfg.outcome_specs,1), 1);
    plot_titles = cell(size(cfg.outcome_specs,1), 1);

    fprintf('Shock: %s\n', sid);
    for i = 1:size(cfg.outcome_specs,1)
        yid = cfg.outcome_specs{i,1};
        ycol = cfg.outcome_specs{i,2};
        ylabel_str = cfg.outcome_specs{i,3};

        y = get_series_if_exists(DB, ycol, T);
        if isempty(y)
            warning('Outcome %s not found. Skipping.', ycol);
            continue;
        end

        res = estimate_lp_level_change(y, z, gpr_level, controls, dummy_controls, sample, cfg);
        level_lp_struct.(sid).(yid) = res;

        tmp = res.table;
        tmp.shock = repmat(string(sid), height(tmp), 1);
        tmp.outcome = repmat(string(yid), height(tmp), 1);
        tmp.outcome_label = repmat(string(ylabel_str), height(tmp), 1);
        tmp.specification = repmat("level_change_y_tph_minus_y_tm1", height(tmp), 1);
        level_lp_results = [level_lp_results; tmp]; %#ok<AGROW>

        res_list{i} = res;
        plot_titles{i} = sprintf('%s, level-change response', ylabel_str);

        fprintf('  %-14s: nobs h0=%3.0f, beta h0=% .4f\n', yid, res.nobs(1), get_beta_at_h(res,0));
    end

    fig_title = sprintf('%s: level LP response to %s GPR shock', sid, cfg.shock_group_label);
    fig = plot_irf_dashboard(res_list, plot_titles, cfg, fig_title, cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);
    save_figure_if_needed(fig, cfg, fullfile(cfg.output_dir, ['dashboard_' clean_file_string(sid)]));
end

%% ========================================================================
%  STEP 4: POISSON-RESIDUAL EVENT IMPULSE DASHBOARDS
%% ========================================================================
event_residual_results = table();
event_joint_results = table();
event_joint_rawN_control_results = table();
event_residual_struct = struct();
event_residual_diagnostics = table();
event_residual_gpr_tests = table();

if cfg.run_event_residual_impulse_dashboards && ~isempty(dummy_aligned)
    fprintf('\n--- Estimating Poisson-residual event impulse LPs ---\n');

    % World GPR shock for Poisson intensity (always needed, regardless of plot_mode)
    poisson_gpr_level = get_series_if_exists(DB, cfg.event_residual_poisson_gpr_var, T);
    if isfield(Z, 'World')
        z_for_poisson = Z.World;
    elseif isfield(loaded, 'Z_all') && isfield(loaded.Z_all, 'with_oil') && isfield(loaded.Z_all.with_oil, 'World')
        z_for_poisson = loaded.Z_all.with_oil.World;
    else
        % Extract World GPR shock on-the-fly
        innov = extract_ar_innovation(poisson_gpr_level, sample, cfg.p_gpr_shock, gpr_shock_current_controls, gpr_shock_lag1_oil_controls, 'World');
        z_for_poisson = zscore_in_sample(innov.resid, sample);
        fprintf('  World GPR shock extracted on-the-fly for Poisson intensity\n');
    end
    gpr_level_for_poisson = zscore_in_sample(poisson_gpr_level, sample);

    % Lagged GPR levels for Poisson intensity
    [poisson_lambda_gpr_levels, poisson_lambda_gpr_names] = load_vars_direct(DB, cfg.poisson_lagged_gpr_level_vars, T);
    fprintf('Poisson intensity GPR levels: %s\n', strjoin(poisson_lambda_gpr_names, ', '));

    % Dummy controls for event LP
    event_resid_lp_dummy_controls = dummy_controls;
    event_resid_lp_dummy_names = dummy_control_names;

    if cfg.poisson_exclude_gpr_from_intensity
        fprintf('Poisson MLE: GPR EXCLUDED from intensity model.\n');
    else
        fprintf('Poisson MLE: GPR INCLUDED in intensity model.\n');
    end

    for dd = 1:numel(cfg.event_impulse_vars)
        did = cfg.event_impulse_vars{dd};
        [dseries, did_source] = get_event_count_or_dummy_series(dummy_aligned, did, T);
        if isempty(dseries) || sum(dseries > 0) == 0
            warning('Event count/dummy not found or all zero: %s. Skipping.', did);
            continue;
        end

        % Poisson intensity and Pearson residual
        eres = estimate_poisson_event_residual(dseries, z_for_poisson, poisson_lambda_gpr_levels, controls, sample, cfg, did);
        event_residual_struct.(did).poisson = eres;
        event_residual_diagnostics = [event_residual_diagnostics; eres.diagnostics]; %#ok<AGROW>

        % GPR relation test
        if cfg.run_event_residual_gpr_tests
            gtest = estimate_event_residual_gpr_relation(did, eres.z_event_resid, z_for_poisson, gpr_level_for_poisson, sample, cfg);
            event_residual_struct.(did).gpr_residual_test = gtest;
            event_residual_gpr_tests = [event_residual_gpr_tests; gtest]; %#ok<AGROW>
        end

        if sum(isfinite(eres.z_event_resid)) == 0
            warning('No finite event residual shock for %s. Skipping LP.', did);
            continue;
        end

        % Drop current event's raw dummy from controls
        drop_names = make_event_drop_candidates(did, did_source);
        [dummy_controls_dd, ~] = drop_dummy_controls_by_names(event_resid_lp_dummy_controls, event_resid_lp_dummy_names, drop_names);

        controls_with_lagN_event = [controls, dseries(:)];

        res_list = cell(size(cfg.outcome_specs,1), 1);
        plot_titles = cell(size(cfg.outcome_specs,1), 1);

        fprintf('\nPoisson event: %s | positive=%d | total=%g | method=%s\n', ...
            did, sum(dseries > 0), sum(dseries, 'omitnan'), char(eres.method));

        for i = 1:size(cfg.outcome_specs,1)
            yid = cfg.outcome_specs{i,1};
            ycol = cfg.outcome_specs{i,2};
            ylabel_str = cfg.outcome_specs{i,3};

            y = get_series_if_exists(DB, ycol, T);
            if isempty(y), continue; end

            cfg_event = cfg;
            cfg_event.shock_size = 1;
            res = estimate_lp_level_change(y, eres.z_event_resid, poisson_gpr_level, controls, dummy_controls_dd, sample, cfg_event);
            event_residual_struct.(did).(yid) = res;

            tmp = res.table;
            tmp.impulse = repmat(string(did), height(tmp), 1);
            tmp.outcome = repmat(string(yid), height(tmp), 1);
            tmp.outcome_label = repmat(string(ylabel_str), height(tmp), 1);
            tmp.specification = repmat("poisson_residual_event_level_lp", height(tmp), 1);
            tmp.gpr_test_series = repmat(string(cfg.event_residual_poisson_gpr_label), height(tmp), 1);
            event_residual_results = [event_residual_results; tmp]; %#ok<AGROW>

            res_list{i} = res;
            plot_titles{i} = sprintf('%s, level-change response', ylabel_str);
        end

        fig_title = sprintf('%s: level LP response to Poisson-residual event shock', did);
        fig = plot_irf_dashboard(res_list, plot_titles, cfg, fig_title, cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);
        save_figure_if_needed(fig, cfg, fullfile(cfg.output_dir, ['event_residual_dashboard_' clean_file_string(did)]));

        % Joint LP: GPR shock + Poisson event-arrival shock
        if cfg.run_gpr_plus_event_residual_lp
            joint_list = cell(size(cfg.outcome_specs,1), 1);
            joint_titles = cell(size(cfg.outcome_specs,1), 1);

            for i = 1:size(cfg.outcome_specs,1)
                yid = cfg.outcome_specs{i,1};
                ycol = cfg.outcome_specs{i,2};
                ylabel_str = cfg.outcome_specs{i,3};

                y = get_series_if_exists(DB, ycol, T);
                if isempty(y), continue; end

                cfg_joint = cfg;
                cfg_joint.shock_size_z1 = cfg.shock_size;
                cfg_joint.shock_size_z2 = 1;

                if cfg.use_compact_event_count_lp
                    cfg_joint.p_lp = cfg.p_dynamic_lp_event_count;
                end
                cfg_joint.p_control_lag_two_impulses = cfg.p_macro_lp_event_count;
                cfg_joint.n_full_lag_controls_two_impulses = 1;

                joint = estimate_lp_level_change_two_impulses(y, z_for_poisson, eres.z_event_resid, poisson_gpr_level, controls_with_lagN_event, dummy_controls_dd, sample, cfg_joint);
                event_residual_struct.(did).([yid '_joint_gpr_event']) = joint;

                joint_tmp = joint.table;
                joint_tmp.impulse = repmat(string(did), height(joint_tmp), 1);
                joint_tmp.outcome = repmat(string(yid), height(joint_tmp), 1);
                joint_tmp.outcome_label = repmat(string(ylabel_str), height(joint_tmp), 1);
                joint_tmp.specification = repmat("gpr_plus_poisson_event_residual_level_lp", height(joint_tmp), 1);
                joint_tmp.gpr_test_series = repmat(string(cfg.event_residual_poisson_gpr_label), height(joint_tmp), 1);
                event_joint_results = [event_joint_results; joint_tmp]; %#ok<AGROW>

                % Robustness: add raw N_t as control
                if cfg.run_poisson_arrival_rawN_control_robustness
                    current_controls_rawN = [dummy_controls_dd, dseries(:)];
                    joint_rawN = estimate_lp_level_change_two_impulses(y, z_for_poisson, eres.z_event_resid, poisson_gpr_level, controls_with_lagN_event, current_controls_rawN, sample, cfg_joint);
                    event_residual_struct.(did).([yid '_joint_gpr_event_rawN_control']) = joint_rawN;

                    joint_rawN_tmp = joint_rawN.table;
                    joint_rawN_tmp.impulse = repmat(string(did), height(joint_rawN_tmp), 1);
                    joint_rawN_tmp.outcome = repmat(string(yid), height(joint_rawN_tmp), 1);
                    joint_rawN_tmp.outcome_label = repmat(string(ylabel_str), height(joint_rawN_tmp), 1);
                    joint_rawN_tmp.specification = repmat("gpr_plus_poisson_event_residual_with_current_rawN_control", height(joint_rawN_tmp), 1);
                    joint_rawN_tmp.gpr_test_series = repmat(string(cfg.event_residual_poisson_gpr_label), height(joint_rawN_tmp), 1);
                    event_joint_rawN_control_results = [event_joint_rawN_control_results; joint_rawN_tmp]; %#ok<AGROW>
                end

                joint_list{i} = extract_two_impulse_component(joint, 2);
                joint_titles{i} = sprintf('%s, Poisson arrival shock controlling GPR', ylabel_str);
            end

            % Skip individual if combined requested
            skip_individual_joint_fig = false;
            if cfg.skip_individual_fig_12_14_16 && ~isempty(cfg.combined_fig_12_14_16_events)
                skip_individual_joint_fig = any(strcmp(did, cfg.combined_fig_12_14_16_events(:,1)));
            end

            if ~skip_individual_joint_fig
                joint_fig_title = sprintf('%s: Poisson event-arrival shock, controlling for %s GPR shock', did, cfg.event_residual_poisson_gpr_label);
                joint_fig = plot_irf_dashboard(joint_list, joint_titles, cfg, joint_fig_title, cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);
                save_figure_if_needed(joint_fig, cfg, fullfile(cfg.output_dir, ['joint_gpr_event_residual_dashboard_' clean_file_string(did)]));
            end
        end
    end

    %% Combined Figure 12/14/16
    if cfg.make_combined_fig_12_14_16
        combined_fig_title = sprintf('Dummies of Interest: Poisson residual shocks controlling for %s GPR', cfg.event_residual_poisson_gpr_label);
        combined_fig = plot_combined_fig_12_14_16_dashboard(event_residual_struct, cfg, combined_fig_title, cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);
        set(combined_fig, 'Name', 'Figure_12_14_16_combined', 'NumberTitle', 'off');
        save_figure_if_needed(combined_fig, cfg, fullfile(cfg.output_dir, 'Figure_12_14_16_combined_poisson_residual_control_world_gpr'));
    end
end

%% ========================================================================
%  STEP 5: RAW EVENT COUNT N_t^k + GPR SHOCK (FWL BASELINE)
%% ========================================================================
event_count_joint_results = table();
event_count_joint_struct = struct();

if cfg.run_gpr_plus_event_count_lp && ~isempty(dummy_aligned)
    fprintf('\n--- Estimating FWL baseline: raw event count N_t^k controlling for GPR shock ---\n');

    world_gpr_level = get_series_if_exists(DB, cfg.event_residual_poisson_gpr_var, T);
    if isfield(Z, 'World')
        z_world_gpr = Z.World;
    elseif isfield(loaded, 'Z_all') && isfield(loaded.Z_all, 'with_oil') && isfield(loaded.Z_all.with_oil, 'World')
        z_world_gpr = loaded.Z_all.with_oil.World;
    else
        innov = extract_ar_innovation(world_gpr_level, sample, cfg.p_gpr_shock, gpr_shock_current_controls, gpr_shock_lag1_oil_controls, 'World');
        z_world_gpr = zscore_in_sample(innov.resid, sample);
    end

    for dd = 1:numel(cfg.event_impulse_vars)
        did = cfg.event_impulse_vars{dd};
        [N_event, did_source] = get_event_count_or_dummy_series(dummy_aligned, did, T);
        if isempty(N_event) || sum(N_event > 0) == 0
            warning('Event count/dummy not found: %s. Skipping.', did);
            continue;
        end

        drop_names = make_event_drop_candidates(did, did_source);
        [dummy_controls_dd, ~] = drop_dummy_controls_by_names(dummy_controls, dummy_control_names, drop_names);

        fprintf('FWL event-count: %s | positive=%d\n', did, sum(N_event > 0));

        controls_with_lagN = [controls, N_event(:)];
        joint_list = cell(size(cfg.outcome_specs,1), 1);
        joint_titles = cell(size(cfg.outcome_specs,1), 1);

        for i = 1:size(cfg.outcome_specs,1)
            yid = cfg.outcome_specs{i,1};
            ycol = cfg.outcome_specs{i,2};
            ylabel_str = cfg.outcome_specs{i,3};

            y = get_series_if_exists(DB, ycol, T);
            if isempty(y), continue; end

            current_fwl_controls = dummy_controls_dd;

            cfg_joint = cfg;
            cfg_joint.shock_size_z1 = cfg.shock_size;
            cfg_joint.shock_size_z2 = 1;

            if cfg.use_compact_event_count_lp
                cfg_joint.p_lp = cfg.p_dynamic_lp_event_count;
            end
            cfg_joint.p_control_lag_two_impulses = cfg.p_macro_lp_event_count;
            cfg_joint.n_full_lag_controls_two_impulses = 1;

            joint = estimate_lp_level_change_two_impulses(y, z_world_gpr, N_event, world_gpr_level, controls_with_lagN, current_fwl_controls, sample, cfg_joint);
            event_count_joint_struct.(did).([yid '_joint_gpr_count']) = joint;

            joint_tmp = joint.table;
            joint_tmp.impulse = repmat(string(did), height(joint_tmp), 1);
            joint_tmp.outcome = repmat(string(yid), height(joint_tmp), 1);
            joint_tmp.outcome_label = repmat(string(ylabel_str), height(joint_tmp), 1);
            joint_tmp.specification = repmat("fwl_raw_event_count_plus_gpr_level_lp", height(joint_tmp), 1);
            event_count_joint_results = [event_count_joint_results; joint_tmp]; %#ok<AGROW>

            joint_list{i} = extract_two_impulse_component(joint, 2);
            joint_titles{i} = sprintf('%s, raw event count controlling GPR', ylabel_str);
        end

        fig_title = sprintf('%s: raw event-arrival count, controlling for %s GPR shock', did, cfg.event_residual_poisson_gpr_label);
        fig = plot_irf_dashboard(joint_list, joint_titles, cfg, fig_title, cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);
        save_figure_if_needed(fig, cfg, fullfile(cfg.output_dir, ['fwl_raw_event_count_dashboard_' clean_file_string(did)]));
    end
end

%% ========================================================================
%  SAVE RESULTS
%% ========================================================================
if cfg.save_results
    mode_tag = clean_file_string(cfg.plot_mode);
    writetable(level_lp_results, fullfile(cfg.output_dir, ['level_lp_results_' mode_tag '.csv']));
    writetable(innovation_info, fullfile(cfg.output_dir, ['level_lp_gpr_shock_diagnostics_' mode_tag '.csv']));

    if ~isempty(event_residual_results)
        writetable(event_residual_results, fullfile(cfg.output_dir, ['event_residual_lp_results_' mode_tag '.csv']));
    end
    if ~isempty(event_joint_results)
        writetable(event_joint_results, fullfile(cfg.output_dir, ['event_joint_gpr_plus_poisson_results_' mode_tag '.csv']));
    end
    if ~isempty(event_joint_rawN_control_results)
        writetable(event_joint_rawN_control_results, fullfile(cfg.output_dir, ['event_joint_gpr_plus_poisson_with_rawN_control_results_' mode_tag '.csv']));
    end
    if ~isempty(event_count_joint_results)
        writetable(event_count_joint_results, fullfile(cfg.output_dir, ['event_count_fwl_gpr_results_' mode_tag '.csv']));
    end
    if ~isempty(event_residual_diagnostics)
        writetable(event_residual_diagnostics, fullfile(cfg.output_dir, ['event_residual_poisson_diagnostics_' mode_tag '.csv']));
    end
    if ~isempty(event_residual_gpr_tests)
        writetable(event_residual_gpr_tests, fullfile(cfg.output_dir, ['event_residual_nonGPR_resid_on_GPR_tests_' mode_tag '.csv']));
    end

    save(fullfile(cfg.output_dir, ['workspace_level_lp_' mode_tag '.mat']), ...
        'cfg', 'Z', 'GPR_levels', 'innovation_info', 'level_lp_results', 'level_lp_struct', 'control_names', ...
        'dummy_aligned', 'dummy_controls', 'dummy_control_names', ...
        'event_residual_results', 'event_joint_results', 'event_joint_rawN_control_results', ...
        'event_residual_struct', 'event_residual_diagnostics', 'event_residual_gpr_tests', ...
        'event_count_joint_results', 'event_count_joint_struct');

    fprintf('\nSaved results to: %s\n', cfg.output_dir);
else
    fprintf('\nNo files saved (cfg.save_results = false).\n');
end


%% ========================================================================
% Helper functions
%% ========================================================================

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

function [data, found_names] = load_vars_direct(DB, var_names, T)
    data = [];
    found_names = {};
    names = DB.Properties.VariableNames;
    for i = 1:numel(var_names)
        target = var_names{i};
        idx = find(strcmpi(names, target), 1);
        if ~isempty(idx)
            raw = DB.(names{idx});
            if isnumeric(raw) || islogical(raw)
                x = double(raw(:));
                if numel(x) == T
                    data = [data, x]; %#ok<AGROW>
                    found_names{end+1} = target; %#ok<AGROW>
                end
            end
        end
    end
end

function x = get_series_if_exists(DB, target, T)
    if iscell(target), target = target{1}; end
    x = [];
    names = DB.Properties.VariableNames;
    idx = find(strcmpi(names, char(target)), 1);
    if isempty(idx), return; end
    raw = DB.(names{idx});
    if isnumeric(raw) || islogical(raw)
        x = double(raw(:));
        if numel(x) ~= T, x = []; end
    end
end

function [dummy_aligned, dummy_controls, dummy_control_names] = build_aligned_dummy_controls(DB, quarter_labels, has_quarter, T, cfg)
    dummy_aligned = table();
    dummy_controls = zeros(T, 0);
    dummy_control_names = {};

    if ~has_quarter
        warning('No Quarter column found. Cannot align dummy controls.');
        return;
    end

    q_db = string(quarter_labels(:));
    dummy_aligned = table(q_db, 'VariableNames', {'Quarter'});

    % Load dummy CSV
    if exist(cfg.dummy_file, 'file')
        D = readtable(cfg.dummy_file, 'VariableNamingRule', 'preserve');
        qD = get_quarter_from_table(D);
        if ~isempty(qD)
            qD = string(qD(:));
            dnames = D.Properties.VariableNames;
            [tf, loc] = ismember(q_db, qD);

            for j = 1:numel(dnames)
                v = dnames{j};
                if any(strcmpi(v, {'Quarter','quarter','Date','date'}))
                    continue;
                end
                raw = D.(v);
                if ~(isnumeric(raw) || islogical(raw)), continue; end
                x = double(raw(:));
                if numel(x) ~= numel(qD), continue; end

                aligned = zeros(T, 1);
                aligned(tf) = x(loc(tf));
                aligned(~isfinite(aligned)) = 0;

                safe_v = matlab.lang.makeValidName(v);
                dummy_aligned.(safe_v) = aligned;
            end
        end
        fprintf('Loaded dummy file: %s\n', cfg.dummy_file);
    end

    % COVID dummy
    if cfg.use_covid_dummy
        covid = double(ismember(q_db, string(cfg.covid_quarters(:))));
        dummy_aligned.(cfg.covid_dummy_name) = covid;
    end

    % Build control matrix
    for i = 1:numel(cfg.dummy_control_vars)
        v = cfg.dummy_control_vars{i};
        if ismember(v, dummy_aligned.Properties.VariableNames)
            x = double(dummy_aligned.(v)(:));
            x(~isfinite(x)) = 0;
            dummy_controls = [dummy_controls, x]; %#ok<AGROW>
            dummy_control_names{end+1} = v; %#ok<AGROW>
        end
    end
end

function q = get_quarter_from_table(D)
    q = [];
    if isempty(D), return; end
    names = D.Properties.VariableNames;
    for cand = {'Quarter','quarter','Date','date'}
        idx = find(strcmpi(names, cand{1}), 1);
        if ~isempty(idx)
            q = cellstr(string(D.(names{idx})(:)));
            return;
        end
    end
end

function [x, source_name] = get_event_count_or_dummy_series(dummy_aligned, varname, T)
    source_name = varname;
    x = get_dummy_series(dummy_aligned, varname, T);
    if ~isempty(x), return; end

    if startsWith(varname, 'n_')
        alt = regexprep(varname, '^n_', '');
        x = get_dummy_series(dummy_aligned, alt, T);
        if ~isempty(x), source_name = alt; return; end
    else
        alt = ['n_' varname];
        x = get_dummy_series(dummy_aligned, alt, T);
        if ~isempty(x), source_name = alt; return; end
    end
end

function x = get_dummy_series(dummy_aligned, varname, T)
    x = [];
    if isempty(dummy_aligned), return; end
    if ismember(varname, dummy_aligned.Properties.VariableNames)
        x = double(dummy_aligned.(varname)(:));
        if numel(x) ~= T, x = []; end
    end
end

function candidates = make_event_drop_candidates(did, did_source)
    if nargin < 2 || isempty(did_source), did_source = did; end
    base1 = regexprep(char(did), '^n_', '');
    base2 = regexprep(char(did_source), '^n_', '');
    candidates = unique({char(did), char(did_source), base1, base2, ['n_' base1], ['n_' base2]}, 'stable');
end

function [Xdrop, names_drop] = drop_dummy_controls_by_names(X, names, names_to_drop)
    Xdrop = X;
    names_drop = names;
    if isempty(names) || isempty(names_to_drop), return; end
    if ischar(names_to_drop) || isstring(names_to_drop)
        names_to_drop = cellstr(names_to_drop);
    end
    keep = true(1, numel(names_drop));
    for j = 1:numel(names_drop)
        keep(j) = ~any(strcmp(names_drop{j}, names_to_drop));
    end
    Xdrop = Xdrop(:, keep);
    names_drop = names_drop(keep);
end

function z = zscore_in_sample(x, sample)
    x = x(:);
    use = sample & isfinite(x);
    mu = mean(x(use));
    sd = std(x(use));
    if ~isfinite(sd) || sd == 0
        z = x;
    else
        z = (x - mu) ./ sd;
    end
end

function out = estimate_poisson_event_residual(N, z_gpr, gpr_level, controls, sample, cfg, label)
    N = double(N(:));
    N(~isfinite(N)) = NaN;
    N(N < 0) = NaN;
    T = length(N);

    if isempty(z_gpr), z_gpr = nan(T, 1); else, z_gpr = z_gpr(:); end
    if isempty(gpr_level), gpr_level = nan(T, 0); end
    if isempty(controls), controls = zeros(T, 0); end

    use_lagN = cfg.poisson_include_lagged_count;
    use_lagC = cfg.poisson_include_lagged_controls && ~isempty(controls);

    p_gpr_level = 0;
    if cfg.poisson_include_lagged_gpr_level
        p_gpr_level = cfg.poisson_gpr_level_lags;
    end
    min_lag = max(1, p_gpr_level);

    t_grid = (min_lag+1):T;
    Xraw = zeros(numel(t_grid), 0);
    pred_names = {};

    include_gpr = ~cfg.poisson_exclude_gpr_from_intensity;

    if include_gpr && cfg.poisson_include_current_gpr_shock
        Xraw = [Xraw, z_gpr(t_grid)];
        pred_names{end+1} = 'z_GPR_t';
    end

    if include_gpr && p_gpr_level > 0 && ~isempty(gpr_level)
        gpr_names = cfg.poisson_lagged_gpr_level_labels;
        for jj = 1:p_gpr_level
            for gg = 1:size(gpr_level, 2)
                Xraw = [Xraw, gpr_level(t_grid-jj, gg)]; %#ok<AGROW>
                if numel(gpr_names) >= gg
                    pred_names{end+1} = sprintf('%s_lag%d', gpr_names{gg}, jj); %#ok<AGROW>
                end
            end
        end
    end

    if use_lagN
        Xraw = [Xraw, N(t_grid-1)];
        pred_names{end+1} = 'lagN';
    end

    if use_lagC
        Xraw = [Xraw, controls(t_grid-1, :)];
        for j = 1:size(controls, 2)
            pred_names{end+1} = sprintf('lagControl%d', j); %#ok<AGROW>
        end
    end

    Y = N(t_grid);
    valid = sample(t_grid) & sample(t_grid-min_lag) & isfinite(Y) & all(isfinite(Xraw), 2);

    Yuse = Y(valid);
    Xuse_raw = Xraw(valid, :);

    min_positive = cfg.poisson_min_positive_periods;
    n_positive = sum(Yuse > 0);
    n_zero = sum(Yuse == 0);
    total_count = sum(Yuse);

    z_event_resid = nan(T, 1);
    event_resid = nan(T, 1);
    pearson_resid = nan(T, 1);
    lambda_hat = nan(T, 1);
    eta_hat = nan(T, 1);
    b = nan(size(Xuse_raw, 2)+1, 1);
    method = "not_estimated";
    converged = false;
    resid_sd = NaN;

    if numel(Yuse) <= size(Xuse_raw, 2) + 1 || n_positive < min_positive || total_count <= 0
        diag = table(string(label), string(method), converged, numel(Yuse), n_positive, n_zero, total_count, ...
            NaN, NaN, NaN, NaN, NaN, ...
            'VariableNames', {'event','method','converged','nobs','positive_periods','zero_periods','total_count','mean_lambda_positive','mean_lambda_zero','pearson_resid_sd','corr_N_lambda','deviance'});
        out = struct('label',label,'N',N,'z_event_resid',z_event_resid,'event_resid',event_resid, ...
            'pearson_resid',pearson_resid,'lambda_hat',lambda_hat,'eta_hat',eta_hat,'coeff',b, ...
            'predictor_names',{pred_names},'nobs',numel(Yuse),'positive_periods',n_positive, ...
            'zero_periods',n_zero,'total_count',total_count,'method',method,'converged',converged, ...
            'resid_sd',resid_sd,'diagnostics',diag);
        return;
    end

    [Xuse, muX, sdX] = standardize_design_columns(Xuse_raw, cfg.poisson_standardize_predictors);
    [b, method, converged] = fit_poisson_count(Yuse, Xuse, cfg);

    eta_use = [ones(size(Xuse, 1), 1), Xuse] * b;
    lam_use = min(max(exp(max(min(eta_use, 30), -30)), 1e-8), 1e8);

    raw_use = Yuse - lam_use;
    pearson_use = raw_use ./ sqrt(lam_use);
    resid_sd = std(pearson_use, 'omitnan');
    if isfinite(resid_sd) && resid_sd > 0
        z_use = (pearson_use - mean(pearson_use, 'omitnan')) ./ resid_sd;
    else
        z_use = pearson_use;
    end

    idx = t_grid(valid);
    eta_hat(idx) = eta_use;
    lambda_hat(idx) = lam_use;
    event_resid(idx) = raw_use;
    pearson_resid(idx) = pearson_use;
    z_event_resid(idx) = z_use;

    mean_lambda_positive = mean(lam_use(Yuse > 0), 'omitnan');
    mean_lambda_zero = mean(lam_use(Yuse == 0), 'omitnan');
    if std(Yuse) > 0 && std(lam_use) > 0
        corr_N_lambda = corr(Yuse, lam_use, 'Rows', 'complete');
    else
        corr_N_lambda = NaN;
    end
    dev = poisson_deviance(Yuse, lam_use);

    diag = table(string(label), string(method), converged, numel(Yuse), n_positive, n_zero, total_count, ...
        mean_lambda_positive, mean_lambda_zero, resid_sd, corr_N_lambda, dev, ...
        'VariableNames', {'event','method','converged','nobs','positive_periods','zero_periods','total_count','mean_lambda_positive','mean_lambda_zero','pearson_resid_sd','corr_N_lambda','deviance'});

    out = struct('label',label,'N',N,'z_event_resid',z_event_resid,'event_resid',event_resid, ...
        'pearson_resid',pearson_resid,'lambda_hat',lambda_hat,'eta_hat',eta_hat,'coeff',b, ...
        'predictor_names',{pred_names},'predictor_mean',muX,'predictor_sd',sdX, ...
        'nobs',numel(Yuse),'positive_periods',n_positive,'zero_periods',n_zero,'total_count',total_count, ...
        'method',method,'converged',converged,'resid_sd',resid_sd,'diagnostics',diag);
end

function [Xstd, muX, sdX] = standardize_design_columns(X, do_standardize)
    Xstd = X;
    muX = zeros(1, size(X, 2));
    sdX = ones(1, size(X, 2));
    if ~do_standardize || isempty(X), return; end
    for j = 1:size(X, 2)
        xj = X(:, j);
        mu = mean(xj, 'omitnan');
        sd = std(xj, 'omitnan');
        if isfinite(sd) && sd > 0
            Xstd(:, j) = (xj - mu) ./ sd;
            muX(j) = mu;
            sdX(j) = sd;
        end
    end
end

function [b, method, converged] = fit_poisson_count(Y, X, cfg)
    Y = double(Y(:));
    k = size(X, 2);

    if exist('glmfit', 'file') == 2
        try
            [b, ~, stats] = glmfit(X, Y, 'poisson', 'link', 'log');
            method = "glmfit_poisson";
            converged = true;
            if isfield(stats, 'se') && any(~isfinite(stats.se))
                converged = false;
            end
            return;
        catch
        end
    end

    ybar = max(mean(Y, 'omitnan'), 1e-6);
    b0 = zeros(k+1, 1);
    b0(1) = log(ybar);

    lambda = cfg.poisson_ridge_lambda;
    obj = @(theta) poisson_negloglik(theta, Y, X, lambda);
    opts = optimset('Display', 'off', 'MaxIter', 20000, 'MaxFunEvals', 50000, 'TolX', 1e-8, 'TolFun', 1e-8);
    [b, ~, exitflag] = fminsearch(obj, b0, opts);
    method = "fminsearch_poisson";
    converged = exitflag > 0;
end

function nll = poisson_negloglik(theta, Y, X, lambda)
    eta = [ones(size(X, 1), 1), X] * theta(:);
    mu = min(max(exp(max(min(eta, 30), -30)), 1e-8), 1e8);
    nll = -sum(Y .* log(mu) - mu - gammaln(Y + 1));
    if isfinite(lambda) && lambda > 0
        nll = nll + lambda * sum(theta(2:end).^2);
    end
end

function dev = poisson_deviance(Y, mu)
    Y = double(Y(:));
    mu = min(max(mu(:), 1e-8), 1e8);
    term = zeros(size(Y));
    pos = Y > 0;
    term(pos) = Y(pos) .* log(Y(pos) ./ mu(pos)) - (Y(pos) - mu(pos));
    term(~pos) = mu(~pos);
    dev = 2 * sum(term, 'omitnan');
end

function outtab = estimate_event_residual_gpr_relation(event_id, z_event_resid, z_gpr_shock, gpr_level_std, sample, cfg)
    y = double(z_event_resid(:));
    x1 = double(z_gpr_shock(:));
    x2 = double(gpr_level_std(:));
    sample = logical(sample(:));
    threshold = cfg.gpr_high_threshold;

    valid = sample & isfinite(y) & isfinite(x1) & isfinite(x2);
    nobs = sum(valid);

    beta_shock = NaN; se_shock = NaN; t_shock = NaN; p_shock = NaN;
    beta_level = NaN; se_level = NaN; t_level = NaN; p_level = NaN;
    corr_shock = NaN; corr_level = NaN;

    if nobs > 5
        Y = y(valid);
        X = [ones(nobs, 1), x1(valid), x2(valid)];
        [b, se] = ols_hac(Y, X, 0);

        beta_shock = b(2); se_shock = se(2);
        if isfinite(se_shock) && se_shock > 0
            t_shock = beta_shock / se_shock;
            p_shock = 2 * (1 - normal_cdf(abs(t_shock)));
        end

        beta_level = b(3); se_level = se(3);
        if isfinite(se_level) && se_level > 0
            t_level = beta_level / se_level;
            p_level = 2 * (1 - normal_cdf(abs(t_level)));
        end

        if std(Y) > 0 && std(x1(valid)) > 0
            corr_shock = corr(Y, x1(valid), 'Rows', 'complete');
        end
        if std(Y) > 0 && std(x2(valid)) > 0
            corr_level = corr(Y, x2(valid), 'Rows', 'complete');
        end
    end

    high_shock = valid & (x1 >= threshold);
    low_shock = valid & (x1 < threshold);
    high_level = valid & (x2 >= threshold);
    low_level = valid & (x2 < threshold);

    outtab = table(string(event_id), nobs, threshold, ...
        beta_shock, se_shock, t_shock, p_shock, corr_shock, ...
        beta_level, se_level, t_level, p_level, corr_level, ...
        sum(high_shock), mean(y(high_shock), 'omitnan'), mean(y(low_shock), 'omitnan'), ...
        mean(y(high_shock) > 0, 'omitnan'), mean(y(low_shock) > 0, 'omitnan'), ...
        sum(high_level), mean(y(high_level), 'omitnan'), mean(y(low_level), 'omitnan'), ...
        mean(y(high_level) > 0, 'omitnan'), mean(y(low_level) > 0, 'omitnan'), ...
        'VariableNames', {'event','nobs','high_threshold', ...
        'beta_gpr_shock','se_gpr_shock','t_gpr_shock','p_gpr_shock','corr_gpr_shock', ...
        'beta_gpr_level','se_gpr_level','t_gpr_level','p_gpr_level','corr_gpr_level', ...
        'n_high_gpr_shock','mean_resid_high_gpr_shock','mean_resid_low_gpr_shock', ...
        'share_pos_resid_high_gpr_shock','share_pos_resid_low_gpr_shock', ...
        'n_high_gpr_level','mean_resid_high_gpr_level','mean_resid_low_gpr_level', ...
        'share_pos_resid_high_gpr_level','share_pos_resid_low_gpr_level'});
end

function res = estimate_lp_level_change(y, z, gpr_level, controls, dummy_controls, sample, cfg)
    H = cfg.H;
    zcrit = normal_icdf(0.5 + cfg.ci/2);

    beta = nan(H+1, 1);
    se = nan(H+1, 1);
    lb = nan(H+1, 1);
    ub = nan(H+1, 1);
    nobs = nan(H+1, 1);

    for h = 0:H
        [Y, X] = build_lp_level_change_design(y, z, gpr_level, controls, dummy_controls, sample, cfg.p_lp, h);
        if isempty(Y) || size(X, 1) <= size(X, 2), continue; end

        bw = min(h + 1, size(X, 1)-1);
        [b, se_all] = ols_hac(Y, X, bw);

        beta(h+1) = cfg.shock_size * b(2);
        se(h+1) = cfg.shock_size * se_all(2);
        lb(h+1) = beta(h+1) - zcrit * se(h+1);
        ub(h+1) = beta(h+1) + zcrit * se(h+1);
        nobs(h+1) = size(X, 1);
    end

    res = struct('h', (0:H)', 'beta', beta, 'se', se, 'lb', lb, 'ub', ub, 'nobs', nobs, ...
        'response_ylabel', 'Level change: y_{t+h} - y_{t-1}', ...
        'table', table((0:H)', beta, se, lb, ub, nobs, 'VariableNames', {'h','beta','se','lb','ub','nobs'}));
end

function res = estimate_lp_level_change_two_impulses(y, z1, z2, gpr_level, controls, dummy_controls, sample, cfg)
    H = cfg.H;
    zcrit = normal_icdf(0.5 + cfg.ci/2);

    scale1 = cfg.shock_size;
    scale2 = 1;
    if isfield(cfg, 'shock_size_z1'), scale1 = cfg.shock_size_z1; end
    if isfield(cfg, 'shock_size_z2'), scale2 = cfg.shock_size_z2; end

    beta1 = nan(H+1, 1); se1 = nan(H+1, 1); lb1 = nan(H+1, 1); ub1 = nan(H+1, 1);
    beta2 = nan(H+1, 1); se2 = nan(H+1, 1); lb2 = nan(H+1, 1); ub2 = nan(H+1, 1);
    nobs = nan(H+1, 1);

    for h = 0:H
        [Y, X] = build_lp_level_change_design_two_impulses(y, z1, z2, gpr_level, controls, dummy_controls, sample, cfg.p_lp, h, cfg);
        if isempty(Y) || size(X, 1) <= size(X, 2), continue; end

        bw = min(h + 1, size(X, 1)-1);
        [b, se_all] = ols_hac(Y, X, bw);

        beta1(h+1) = scale1 * b(2);
        se1(h+1) = scale1 * se_all(2);
        lb1(h+1) = beta1(h+1) - zcrit * se1(h+1);
        ub1(h+1) = beta1(h+1) + zcrit * se1(h+1);

        beta2(h+1) = scale2 * b(3);
        se2(h+1) = scale2 * se_all(3);
        lb2(h+1) = beta2(h+1) - zcrit * se2(h+1);
        ub2(h+1) = beta2(h+1) + zcrit * se2(h+1);

        nobs(h+1) = size(X, 1);
    end

    res = struct('h', (0:H)', 'beta1', beta1, 'se1', se1, 'lb1', lb1, 'ub1', ub1, ...
        'beta2', beta2, 'se2', se2, 'lb2', lb2, 'ub2', ub2, 'nobs', nobs, ...
        'response_ylabel', 'Level change: y_{t+h} - y_{t-1}', ...
        'table', table((0:H)', beta1, se1, lb1, ub1, beta2, se2, lb2, ub2, nobs, ...
        'VariableNames', {'h','beta_gpr','se_gpr','lb_gpr','ub_gpr','beta_event','se_event','lb_event','ub_event','nobs'}));
end

function comp = extract_two_impulse_component(joint, which_component)
    comp = struct('h', joint.h, 'nobs', joint.nobs);
    if which_component == 1
        comp.beta = joint.beta1; comp.se = joint.se1; comp.lb = joint.lb1; comp.ub = joint.ub1;
    else
        comp.beta = joint.beta2; comp.se = joint.se2; comp.lb = joint.lb2; comp.ub = joint.ub2;
    end
    comp.response_ylabel = joint.response_ylabel;
    comp.table = table(comp.h, comp.beta, comp.se, comp.lb, comp.ub, comp.nobs, 'VariableNames', {'h','beta','se','lb','ub','nobs'});
end

function [Y, X] = build_lp_level_change_design(y, z, gpr_level, controls, dummy_controls, sample, p, h)
    y = y(:); z = z(:); gpr_level = gpr_level(:);
    T = length(y);

    if isempty(controls), controls = zeros(T, 0); end
    if isempty(dummy_controls), dummy_controls = zeros(T, 0); end
    nC = size(controls, 2);
    nD = size(dummy_controls, 2);

    t_grid = (p+1):(T-h);
    n = numel(t_grid);
    k = 1 + 1 + nD + p + p + p*nC;
    X0 = nan(n, k);
    Y0 = nan(n, 1);

    for ii = 1:n
        t = t_grid(ii);
        c = 1;
        row = nan(1, k);

        Y0(ii) = y(t+h) - y(t-1);
        row(c) = 1; c = c + 1;
        row(c) = z(t); c = c + 1;

        if nD > 0
            row(c:c+nD-1) = dummy_controls(t, :);
            c = c + nD;
        end

        for j = 1:p, row(c) = y(t-j); c = c + 1; end
        for j = 1:p, row(c) = gpr_level(t-j); c = c + 1; end

        if nC > 0
            for j = 1:p
                row(c:c+nC-1) = controls(t-j, :);
                c = c + nC;
            end
        end

        X0(ii, :) = row;
    end

    good = all(isfinite([Y0, X0]), 2) & sample(t_grid');
    Y = Y0(good);
    X = X0(good, :);
end

function [Y, X] = build_lp_level_change_design_two_impulses(y, z1, z2, gpr_level, controls, dummy_controls, sample, p, h, cfg)
    y = y(:); z1 = z1(:); z2 = z2(:); gpr_level = gpr_level(:);
    T = length(y);

    if isempty(controls), controls = zeros(T, 0); end
    if isempty(dummy_controls), dummy_controls = zeros(T, 0); end
    nC = size(controls, 2);
    nD = size(dummy_controls, 2);

    p_control = p;
    if isfield(cfg, 'p_control_lag_two_impulses')
        p_control = max(0, min(p, round(cfg.p_control_lag_two_impulses)));
    end

    n_full_lag_controls = 0;
    if isfield(cfg, 'n_full_lag_controls_two_impulses')
        n_full_lag_controls = max(0, min(nC, round(cfg.n_full_lag_controls_two_impulses)));
    end

    n_short = nC - n_full_lag_controls;
    controls_short = controls(:, 1:n_short);
    controls_full = controls(:, n_short+1:nC);
    nC_short = size(controls_short, 2);
    nC_full = size(controls_full, 2);

    p_max = max(p, p_control);
    t_grid = (p_max+1):(T-h);
    n = numel(t_grid);
    k = 1 + 2 + nD + p + p + p_control*nC_short + p*nC_full;
    X0 = nan(n, k);
    Y0 = nan(n, 1);

    for ii = 1:n
        t = t_grid(ii);
        c = 1;
        row = nan(1, k);

        Y0(ii) = y(t+h) - y(t-1);
        row(c) = 1; c = c + 1;
        row(c) = z1(t); c = c + 1;
        row(c) = z2(t); c = c + 1;

        if nD > 0
            row(c:c+nD-1) = dummy_controls(t, :);
            c = c + nD;
        end

        for j = 1:p, row(c) = y(t-j); c = c + 1; end
        for j = 1:p, row(c) = gpr_level(t-j); c = c + 1; end

        if nC_short > 0 && p_control > 0
            for j = 1:p_control
                row(c:c+nC_short-1) = controls_short(t-j, :);
                c = c + nC_short;
            end
        end

        if nC_full > 0
            for j = 1:p
                row(c:c+nC_full-1) = controls_full(t-j, :);
                c = c + nC_full;
            end
        end

        X0(ii, :) = row;
    end

    good = all(isfinite([Y0, X0]), 2) & sample(t_grid');
    Y = Y0(good);
    X = X0(good, :);
end

function [b, se] = ols_hac(y, X, bw)
    [n, k] = size(X);
    if n <= k, error('Not enough observations: n=%d, k=%d', n, k); end

    b = X \ y;
    u = y - X*b;

    bw = min(max(bw, 0), n-1);
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
    se = sqrt(max(diag(V), 0));
end

function q = normal_icdf(p)
    q = -sqrt(2) * erfcinv(2 * p);
end

function p = normal_cdf(x)
    p = 0.5 .* erfc(-x ./ sqrt(2));
end

function b = get_beta_at_h(res, hval)
    idx = find(res.h == hval, 1);
    if isempty(idx), b = NaN; else, b = res.beta(idx); end
end

function fig = plot_irf_dashboard(res_list, titles, cfg, fig_title, nrow, ncol, show_figures)
    if show_figures
        fig = figure('Color', 'w', 'Position', [80, 60, 1500, 850]);
    else
        fig = figure('Color', 'w', 'Position', [80, 60, 1500, 850], 'Visible', 'off');
    end

    use_latex = isfield(cfg, 'use_latex_fonts') && cfg.use_latex_fonts;
    fs = cfg.figure_font_size;
    title_fs = cfg.figure_title_font_size;

    for i = 1:numel(res_list)
        if isempty(res_list{i}), continue; end
        ax = subplot(nrow, ncol, i, 'Parent', fig);
        hold(ax, 'on');

        if use_latex
            set(ax, 'TickLabelInterpreter', 'latex', 'FontSize', fs);
        else
            set(ax, 'FontSize', fs);
        end

        r = res_list{i};
        h = r.h(:)';
        finite_beta = isfinite(r.beta);
        finite_ci = isfinite(r.lb) & isfinite(r.ub);

        if sum(finite_beta) == 0
            text(ax, 0.5, 0.5, 'All beta = NaN', 'HorizontalAlignment', 'center', 'Units', 'normalized');
            axis(ax, 'off');
            continue;
        end

        if sum(finite_ci) >= 2
            hci = h(finite_ci);
            fill(ax, [hci, fliplr(hci)], [r.ub(finite_ci)', fliplr(r.lb(finite_ci)')], cfg.ci_band_color, ...
                'EdgeColor', 'none', 'FaceAlpha', cfg.ci_band_alpha, 'HandleVisibility', 'off');
        end

        plot(ax, h(finite_beta), r.beta(finite_beta), 'k-', 'LineWidth', cfg.irf_line_width);
        plot(ax, h, zeros(size(h)), 'k--', 'LineWidth', cfg.zero_line_width);

        grid(ax, 'on'); box(ax, 'on');
        xlim(ax, [0 cfg.H]);

        set(ax, 'FontSize', fs, 'FontWeight', 'bold', 'LineWidth', cfg.figure_axis_line_width);
        xlabel(ax, cfg.horizon_label, 'FontSize', fs);
        ylabel(ax, 'Level change', 'FontSize', fs);

        if use_latex
            title(ax, ['\textbf{' latex_escape_text(titles{i}) '}'], 'Interpreter', 'latex', 'FontSize', fs);
        else
            title(ax, titles{i}, 'Interpreter', 'none', 'FontSize', fs);
        end
    end

    if use_latex
        sgtitle(fig, ['\textbf{' latex_escape_text(fig_title) '}'], 'Interpreter', 'latex', 'FontSize', title_fs);
    else
        sgtitle(fig, fig_title, 'Interpreter', 'none', 'FontSize', title_fs);
    end
    drawnow;
end

function fig = plot_combined_fig_12_14_16_dashboard(event_residual_struct, cfg, fig_title, nrow, ncol, show_figures)
    if show_figures
        fig = figure('Color', 'w', 'Position', [80, 60, 1550, 900]);
    else
        fig = figure('Color', 'w', 'Position', [80, 60, 1550, 900], 'Visible', 'off');
    end

    use_latex = isfield(cfg, 'use_latex_fonts') && cfg.use_latex_fonts;
    fs = cfg.figure_font_size;
    title_fs = cfg.figure_title_font_size;
    line_lw = cfg.combined_fig_12_14_16_line_width;
    ci_alpha = cfg.combined_fig_12_14_16_ci_alpha;
    event_specs = cfg.combined_fig_12_14_16_events;

    for i = 1:size(cfg.outcome_specs, 1)
        yid = cfg.outcome_specs{i, 1};
        panel_title = cfg.outcome_specs{i, 3};
        joint_field = [yid '_joint_gpr_event'];

        ax = subplot(nrow, ncol, i, 'Parent', fig);
        hold(ax, 'on');

        for ee = 1:size(event_specs, 1)
            did = event_specs{ee, 1};
            legend_label = event_specs{ee, 2};
            this_color = event_specs{ee, 3};

            if ~isfield(event_residual_struct, did), continue; end
            if ~isfield(event_residual_struct.(did), joint_field), continue; end

            joint = event_residual_struct.(did).(joint_field);
            r = extract_two_impulse_component(joint, 2);

            h = r.h(:)';
            finite_beta = isfinite(r.beta);
            finite_ci = isfinite(r.lb) & isfinite(r.ub);

            if sum(finite_ci) >= 2
                hci = h(finite_ci);
                fill(ax, [hci, fliplr(hci)], [r.ub(finite_ci)', fliplr(r.lb(finite_ci)')], this_color, ...
                    'EdgeColor', 'none', 'FaceAlpha', ci_alpha, 'HandleVisibility', 'off');
            end

            if sum(finite_beta) >= 1
                plot(ax, h(finite_beta), r.beta(finite_beta), '-', 'Color', this_color, ...
                    'LineWidth', line_lw, 'DisplayName', legend_label);
            end
        end

        plot(ax, 0:cfg.H, zeros(1, cfg.H+1), 'k--', 'LineWidth', cfg.zero_line_width, 'HandleVisibility', 'off');

        grid(ax, 'on'); box(ax, 'on');
        xlim(ax, [0 cfg.H]);

        set(ax, 'FontSize', fs, 'FontWeight', 'bold', 'LineWidth', cfg.figure_axis_line_width);
        xlabel(ax, cfg.horizon_label, 'FontSize', fs);
        ylabel(ax, 'Level change', 'FontSize', fs);
        title(ax, panel_title, 'Interpreter', 'none', 'FontSize', fs);

        legend(ax, 'show', 'Location', 'best', 'FontSize', max(fs-3, 8), 'Box', 'off');
    end

    sgtitle(fig, fig_title, 'Interpreter', 'none', 'FontSize', title_fs);
    drawnow;
end

function apply_latex_graphics_defaults(cfg)
    if cfg.use_latex_fonts
        set(groot, 'defaultTextInterpreter', 'latex');
        set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
        set(groot, 'defaultLegendInterpreter', 'latex');
    end
    set(groot, 'defaultAxesFontSize', cfg.figure_font_size);
    set(groot, 'defaultTextFontSize', cfg.figure_font_size);
    set(groot, 'defaultAxesFontWeight', 'bold');
    set(groot, 'defaultTextFontWeight', 'bold');
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
    if isempty(fig) || ~isgraphics(fig, 'figure')
        warning('Invalid figure handle. Skipping save: %s', base_path);
        return;
    end

    drawnow;

    all_axes = findall(fig, 'Type', 'axes');
    for ax = all_axes(:)'
        if isprop(ax, 'Toolbar')
            ax.Toolbar.Visible = 'off';
        end
    end

    try
        savefig(fig, [base_path '.fig']);
    catch ME
        warning('Could not save .fig: %s', ME.message);
    end

    try
        exportgraphics(fig, [base_path '.png'], 'Resolution', 300);
    catch
        try
            print(fig, [base_path '.png'], '-dpng', '-r300');
        catch ME2
            warning('Could not save png: %s', ME2.message);
        end
    end
end

function s = clean_file_string(s)
    s = char(s);
    s = regexprep(s, '[^A-Za-z0-9_\-]+', '_');
    s = regexprep(s, '_+', '_');
end

function out = extract_ar_innovation(x, sample, p, current_controls, lag1_controls, label)
    % Extract GPR innovation from AR(p) + current controls + lag-1 oil controls
    x = double(x(:));
    T = length(x);
    sample = logical(sample(:));

    if isempty(current_controls), current_controls = zeros(T, 0); end
    if isempty(lag1_controls), lag1_controls = zeros(T, 0); end

    nCurrent = size(current_controls, 2);
    nLag1 = size(lag1_controls, 2);

    t_grid = (p+1):T;
    n = numel(t_grid);
    k = 1 + p + nCurrent + nLag1;
    Y = nan(n, 1);
    X = nan(n, k);

    for ii = 1:n
        t = t_grid(ii);
        c = 1;
        row = nan(1, k);

        row(c) = 1; c = c + 1;
        for j = 1:p
            row(c) = x(t-j); c = c + 1;
        end
        if nCurrent > 0
            row(c:c+nCurrent-1) = current_controls(t, :);
            c = c + nCurrent;
        end
        if nLag1 > 0
            row(c:c+nLag1-1) = lag1_controls(t-1, :);
        end

        Y(ii) = x(t);
        X(ii, :) = row;
    end

    good = isfinite(Y) & all(isfinite(X), 2) & sample(t_grid');
    Yg = Y(good);
    Xg = X(good, :);
    tg = t_grid(good)';

    if isempty(Yg) || size(Xg, 1) <= size(Xg, 2)
        error('No usable observations in AR shock extraction for %s.', label);
    end

    b = Xg \ Yg;
    fitted = nan(T, 1);
    resid = nan(T, 1);
    fitted(tg) = Xg * b;
    resid(tg) = Yg - Xg * b;

    u = resid(tg);
    sse = sum(u.^2);
    sst = sum((Yg - mean(Yg)).^2);
    rsq = 1 - sse / sst;
    if sst == 0, rsq = NaN; end

    out = struct('label', label, 't_index', tg, 'coeff', b, 'fitted', fitted, 'resid', resid, ...
        'nobs', numel(Yg), 'rsq', rsq, 'mean_resid', mean(u), 'std_resid', std(u));
end
