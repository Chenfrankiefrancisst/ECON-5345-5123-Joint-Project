clear; clc; close all;

cfg.datafile = 'Q_Levels_Database.csv';
cfg.dummy_file = 'oil_relevant_gpr_event_dummies_extended_onset_realized_1986Q1_2025Q4.csv';

cfg.output_dir = 'Part3AB_Overlay_ExactLP_zN_vs_rawN_ThreeEvents';

cfg.save_results = false;
cfg.save_figures = true;
cfg.show_figures = true;
cfg.run_gpr_shock_dashboards = false;

cfg.use_latex_fonts = true;

cfg.figure_font_size = 16;
cfg.figure_title_font_size = 18;
cfg.figure_axis_line_width = 1.4;

cfg.ci_band_color = [0.45 0.45 0.45];
cfg.ci_band_alpha = 0.75;
cfg.irf_line_width = 3.2;
cfg.zero_line_width = 1.4;

cfg.plot_mode = 'countries';

cfg.p_gpr_shock = 4;
cfg.standardize_shock = true;

cfg.gpr_shock_current_control_aliases = { ...
    {'Unemp','Unemployment'}, ...
    {'FFR','FederalFundsRate','FedFunds','Policy_Rate','PolicyRate','FEDFUNDS'} ...
};

cfg.gpr_shock_lag1_oil_aliases = { ...
    {'Real_Brent','Brent','BrentOil','Brent_Price'}, ...
    {'Real_WTI','WTI','WTI_Oil','WTI_Price'}, ...
    {'Real_Gasoline','Gasoline','Gasoline_Price'} ...
};

cfg.p_lp = 4;

cfg.use_compact_event_count_lp = true;
cfg.p_dynamic_lp_event_count = 4;
cfg.p_macro_lp_event_count = 1;
cfg.include_current_business_controls_event_count = false;
cfg.include_oil_controls_event_count = true;

cfg.H = 12;
cfg.ci = 0.90;

cfg.shock_size = 1;

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

cfg.run_event_onset_impulse_dashboards = false;
cfg.run_event_residual_impulse_dashboards = true;
cfg.run_gpr_plus_event_residual_lp = true;
cfg.run_gpr_plus_event_count_lp = true;
cfg.run_poisson_arrival_rawN_control_robustness = false;

cfg.event_impulse_vars = { ...
    'n_ChokepointShippingRisk_EventOnset', ...
    'n_StrictSupplyDisruption_EventOnset', ...
    'n_EnergySanction_EventOnset' ...
};

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

cfg.event_residual_poisson_gpr_aliases = {'LGPR'};
cfg.event_residual_poisson_gpr_label = 'World';

cfg.poisson_exclude_gpr_from_intensity = false;
cfg.poisson_include_current_gpr_shock = true;
cfg.poisson_include_lagged_gpr_level = true;
cfg.poisson_gpr_level_lags = 1;
cfg.poisson_lagged_gpr_component_aliases = { ...
    {'LGPR'} ...
};
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

cfg.control_aliases = { ...
    {'Unemp','Unemployment'}, ...
    {'FFR','FederalFundsRate','FedFunds','Policy_Rate','PolicyRate','FEDFUNDS'}, ...
    {'WEO_Growth','gGDP_Forecast'}, ...
    {'WEO_Revision','gGDP_Revise'}, ...
    {'r_y','RealGDP','Real_Output'}, ...
    {'Indu_Prod','IndustrialProduction'} ...
};

cfg.aggregate_shock_specs = {
    'World',       {'LGPR'},    'World GPR shock';
    'GPT',         {'LGPRT'},   'Global geopolitical threats shock';
    'GPA',         {'LGPRA'},   'Global geopolitical acts shock'
};

cfg.country_shock_specs = {
    'US',          {'LGPRUS'},  'U.S. GPR shock';
    'Israel',      {'LGPRISR'}, 'Israel GPR shock';
    'Russia',      {'LGPRRU'},  'Russia GPR shock';
    'China',       {'LGPRCHN'}, 'China GPR shock';
    'Venezuela',   {'LGPRVZ'},  'Venezuela GPR shock';
    'SaudiArabia', {'LGPRSAR'}, 'Saudi Arabia GPR shock'
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
        error('Unknown cfg.plot_mode = %s. Use aggregate, countries, or all.', cfg.plot_mode);
end

cfg.outcome_specs = {
    'Real_Brent',    {'Real_Brent'},    'Brent';
    'Real_WTI',      {'Real_WTI'},      'WTI';
    'Real_Gasoline', {'Real_Gasoline'}, 'Gasoline';
    'inv_OECD',      {'inv_OECD'},      'OECD inv.';
    'inv_USA',       {'inv_USA'},       'US inv.';
    'WorldCP',       {'WorldCP'},       'World prod.'
};

cfg.dashboard_nrow = 2;
cfg.dashboard_ncol = 3;
cfg.horizon_label = 'Horizon (quarters)';

apply_latex_graphics_defaults(cfg);

if cfg.save_results || cfg.save_figures
    if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
end

fprintf('\n=== Level LP, plot mode = %s, with COVID controls and Poisson event-arrival residuals ===\n', cfg.plot_mode);
fprintf('Selected shock block: %s; number of shocks = %d\n', cfg.shock_group_label, size(cfg.shock_specs,1));
fprintf('Data file: %s\n', cfg.datafile);
fprintf('Specification: y_{t+h} - y_{t-1} on standardized z_t and lagged level controls.\n');
fprintf('GPR shock extraction: AR(%d) in GPR levels + current macro controls + lag-1 oil-price controls.\n', ...
    cfg.p_gpr_shock);
fprintf('LP lags: %d; horizon: 0:%d; shock size: %.2f s.d.\n', cfg.p_lp, cfg.H, cfg.shock_size);

if ~exist(cfg.datafile, 'file')
    error('Data file not found: %s. Put Q_Levels_Database.csv in the same folder as this script.', cfg.datafile);
end

fprintf('Loading level database: %s\n', cfg.datafile);
DB = readtable(cfg.datafile, 'VariableNamingRule','preserve');
T = height(DB);
varnames = DB.Properties.VariableNames;
fprintf('Loaded rows T = %d, variables = %d\n', T, numel(varnames));

[quarter_labels, has_quarter] = get_quarter_labels(DB, T);
if has_quarter
    fprintf('Sample starts at %s and ends at %s\n', quarter_labels{1}, quarter_labels{end});
end

sample = true(T,1);
[controls, control_names] = build_controls(DB, cfg.control_aliases, T);
fprintf('Macro controls loaded: %s\n', strjoin(control_names, ', '));
for j = 1:numel(control_names)
    fprintf('  Control %-18s finite = %3d / %3d\n', control_names{j}, sum(isfinite(controls(:,j))), T);
end

[gpr_shock_current_controls, gpr_shock_current_control_names] = build_controls( ...
    DB, cfg.gpr_shock_current_control_aliases, T);

[gpr_shock_lag1_oil_controls, gpr_shock_lag1_oil_control_names] = build_controls( ...
    DB, cfg.gpr_shock_lag1_oil_aliases, T);

fprintf('GPR shock-extraction CURRENT controls loaded: %s\n', ...
    strjoin_or_none(gpr_shock_current_control_names));
for j = 1:numel(gpr_shock_current_control_names)
    fprintf('  Current GPR control %-18s finite = %3d / %3d\n', ...
        gpr_shock_current_control_names{j}, ...
        sum(isfinite(gpr_shock_current_controls(:,j))), T);
end

fprintf('GPR shock-extraction LAG-1 oil controls loaded: %s\n', ...
    strjoin_or_none(gpr_shock_lag1_oil_control_names));
for j = 1:numel(gpr_shock_lag1_oil_control_names)
    fprintf('  Lag-1 oil GPR control %-18s finite = %3d / %3d\n', ...
        gpr_shock_lag1_oil_control_names{j}, ...
        sum(isfinite(gpr_shock_lag1_oil_controls(:,j))), T);
end

[dummy_aligned, dummy_controls, dummy_control_names, dummy_info] = build_aligned_dummy_controls(DB, quarter_labels, has_quarter, T, cfg);

fprintf('\nDummy controls loaded into the LP as contemporaneous controls:\n');
if isempty(dummy_control_names)
    fprintf('  None.\n');
else
    for j = 1:numel(dummy_control_names)
        fprintf('  Dummy %-22s ones = %3d / %3d\n', dummy_control_names{j}, sum(dummy_controls(:,j) == 1), T);
    end
end

fprintf('\nAvailable aligned event dummy counts:\n');
if ~isempty(dummy_aligned)
    dn = dummy_aligned.Properties.VariableNames;
    for j = 1:numel(dn)
        if strcmpi(dn{j}, 'Quarter'), continue; end
        xj = dummy_aligned.(dn{j});
        if isnumeric(xj) || islogical(xj)
            fprintf('  %-22s ones = %3d\n', dn{j}, sum(double(xj(:)) == 1));
        end
    end
else
    fprintf('  No dummy table was loaded.\n');
end

Z = struct();
GPR_levels = struct();
innovation_info = table();

fprintf('\n--- Constructing standardized shocks from GPR AR residuals with business-cycle controls ---\n');
for s = 1:size(cfg.shock_specs,1)
    sid = cfg.shock_specs{s,1};
    aliases = cfg.shock_specs{s,2};
    label = cfg.shock_specs{s,3};

    gpr = get_required_series(DB, aliases, T);
    GPR_levels.(sid) = gpr;

    innov = extract_ar_level_innovation_mixed_controls(gpr, sample, cfg.p_gpr_shock, ...
        gpr_shock_current_controls, gpr_shock_lag1_oil_controls, sid);

    if cfg.standardize_shock
        z = zscore_in_sample(innov.resid, sample);
    else
        z = innov.resid;
    end
    Z.(sid) = z;

    innovation_info = [innovation_info; table(string(sid), string(label), innov.nobs, innov.rsq, innov.std_resid, sum(isfinite(z)), ...
        'VariableNames', {'shock','label','nobs','rsq','resid_sd','finite_z'})];

    fprintf('  %-6s: nobs=%3d, AR R2=% .3f, pearson resid sd=% .4f, finite z=%3d\n', ...
        sid, innov.nobs, innov.rsq, innov.std_resid, sum(isfinite(z)));
end

level_lp_results = table();
level_lp_struct = struct();

if isfield(cfg, 'run_gpr_shock_dashboards') && cfg.run_gpr_shock_dashboards
    fprintf('\n--- Estimating level local projections ---\n');
    for s = 1:size(cfg.shock_specs,1)
    sid = cfg.shock_specs{s,1};
    z = Z.(sid);
    gpr_level = GPR_levels.(sid);

    res_list = cell(size(cfg.outcome_specs,1),1);
    plot_titles = cell(size(cfg.outcome_specs,1),1);

    fprintf('\nShock: %s\n', sid);
    for i = 1:size(cfg.outcome_specs,1)
        yid = cfg.outcome_specs{i,1};
        ylabel = cfg.outcome_specs{i,3};
        y = get_required_series(DB, cfg.outcome_specs{i,2}, T);

        res = estimate_lp_level_change(y, z, gpr_level, controls, dummy_controls, sample, cfg);
        level_lp_struct.(sid).(yid) = res;

        tmp = res.table;
        tmp.shock = repmat(string(sid), height(tmp), 1);
        tmp.outcome = repmat(string(yid), height(tmp), 1);
        tmp.outcome_label = repmat(string(ylabel), height(tmp), 1);
        tmp.specification = repmat("level_change_y_tph_minus_y_tm1", height(tmp), 1);
        level_lp_results = [level_lp_results; tmp];

        res_list{i} = res;
        plot_titles{i} = ylabel;

        fprintf('  %-14s: finite beta=%2d/%2d, nobs h0=%3.0f, beta h0=% .4f, beta h4=% .4f\n', ...
            yid, sum(isfinite(res.beta)), cfg.H+1, res.nobs(1), get_beta_at_h(res,0), get_beta_at_h(res,4));
    end

    fig_title = sprintf('%s: level LP response to %s GPR shock', sid, cfg.shock_group_label);
    fig = plot_irf_dashboard(res_list, plot_titles, cfg, fig_title, cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);
    save_figure_if_needed(fig, cfg, fullfile(cfg.output_dir, ['dashboard_' clean_file_string(sid)]));
    end
end

event_impulse_results = table();
event_impulse_struct = struct();
event_residual_results = table();
event_joint_results = table();
event_joint_rawN_control_results = table();
event_residual_struct = struct();
event_residual_diagnostics = table();
event_residual_gpr_tests = table();

if isfield(cfg, 'run_event_residual_impulse_dashboards') && cfg.run_event_residual_impulse_dashboards && ~isempty(dummy_aligned)
    fprintf('\n--- Estimating Poisson-residual event impulse LPs ---\n');

    poisson_gpr_level = get_required_series(DB, cfg.event_residual_poisson_gpr_aliases, T);
    poisson_innov = extract_ar_level_innovation_mixed_controls(poisson_gpr_level, sample, cfg.p_gpr_shock, ...
        gpr_shock_current_controls, gpr_shock_lag1_oil_controls, cfg.event_residual_poisson_gpr_label);
    if cfg.standardize_shock
        z_for_poisson = zscore_in_sample(poisson_innov.resid, sample);
    else
        z_for_poisson = poisson_innov.resid;
    end
    gpr_level_for_poisson = zscore_in_sample(poisson_gpr_level, sample);

    [poisson_lambda_gpr_levels, poisson_lambda_gpr_level_names] = build_controls( ...
        DB, cfg.poisson_lagged_gpr_component_aliases, T);
    fprintf('Poisson log-intensity lag-1 GPR level controls loaded: %s\n', ...
        strjoin_or_none(poisson_lambda_gpr_level_names));

    event_resid_lp_dummy_controls = dummy_controls;
    event_resid_lp_dummy_names = dummy_control_names;

    if isfield(cfg, 'poisson_exclude_gpr_from_intensity') && cfg.poisson_exclude_gpr_from_intensity
        fprintf('Poisson MLE residualization: GPR EXCLUDED from intensity model. GPR retained only for tests / joint LP.\n');
    else
        fprintf('Poisson MLE residualization: GPR INCLUDED in intensity model.\n');
    end
    fprintf('GPR test series: %s; finite shock z = %d / %d; finite level z = %d / %d\n', ...
        cfg.event_residual_poisson_gpr_label, sum(isfinite(z_for_poisson)), T, sum(isfinite(gpr_level_for_poisson)), T);
    if isempty(event_resid_lp_dummy_names)
        fprintf('Residual-event LP dummy controls before event-specific drop: none.\n');
    else
        fprintf('Residual-event LP dummy controls before event-specific drop: %s\n', strjoin(event_resid_lp_dummy_names, ', '));
    end

    for dd = 1:numel(cfg.event_impulse_vars)
        did = cfg.event_impulse_vars{dd};
        [dseries, did_source] = get_event_count_or_dummy_series(dummy_aligned, did, T);
        if isempty(dseries) || sum(dseries > 0) == 0
            warning('Event count/dummy not found or all zero: %s. Skipping.', did);
            continue;
        end

        eres = estimate_poisson_event_residual(dseries, z_for_poisson, poisson_lambda_gpr_levels, controls, sample, cfg, did);
        event_residual_struct.(did).poisson = eres;
        event_residual_diagnostics = [event_residual_diagnostics; eres.diagnostics];

        if isfield(cfg, 'run_event_residual_gpr_tests') && cfg.run_event_residual_gpr_tests
            gtest = estimate_event_residual_gpr_relation(did, eres.z_event_resid, ...
                z_for_poisson, gpr_level_for_poisson, sample, cfg);
            event_residual_struct.(did).gpr_residual_test = gtest;
            event_residual_gpr_tests = [event_residual_gpr_tests; gtest];
        end

        if sum(isfinite(eres.z_event_resid)) == 0
            warning('No finite event residual shock for %s. Skipping LP dashboard.', did);
            continue;
        end

        drop_names = make_event_drop_candidates(did, did_source);
        [dummy_controls_dd, dummy_control_names_dd] = drop_dummy_controls_by_names( ...
            event_resid_lp_dummy_controls, event_resid_lp_dummy_names, drop_names);
        fprintf('  Poisson LP controls after drop: %s\n', strjoin_or_none(dummy_control_names_dd));


        res_list = cell(size(cfg.outcome_specs,1),1);
        plot_titles = cell(size(cfg.outcome_specs,1),1);

        fprintf('\nResidual event impulse: %s | source=%s | positive periods=%d | total count=%g | poisson nobs=%d | method=%s | pearson resid sd=% .4f\n', ...
            did, did_source, sum(dseries > 0), sum(dseries, 'omitnan'), eres.nobs, char(eres.method), eres.resid_sd);

        for i = 1:size(cfg.outcome_specs,1)
            yid = cfg.outcome_specs{i,1};
            ylabel = cfg.outcome_specs{i,3};
            y = get_required_series(DB, cfg.outcome_specs{i,2}, T);

            cfg_event = cfg;
            cfg_event.shock_size = 1;
            res = estimate_lp_level_change(y, eres.z_event_resid, poisson_gpr_level, controls, dummy_controls_dd, sample, cfg_event);
            event_residual_struct.(did).(yid) = res;

            tmp = res.table;
            tmp.impulse = repmat(string(did), height(tmp), 1);
            tmp.outcome = repmat(string(yid), height(tmp), 1);
            tmp.outcome_label = repmat(string(ylabel), height(tmp), 1);
            tmp.specification = repmat("poisson_residual_event_level_lp", height(tmp), 1);
            tmp.gpr_test_series = repmat(string(cfg.event_residual_poisson_gpr_label), height(tmp), 1);
            event_residual_results = [event_residual_results; tmp];

            res_list{i} = res;
            plot_titles{i} = ylabel;
        end

        if isfield(cfg, 'run_standalone_poisson_residual_dashboards') && cfg.run_standalone_poisson_residual_dashboards
            fig_title = sprintf('%s: level LP response to Poisson-residual event shock', did);
            fig = plot_irf_dashboard(res_list, plot_titles, cfg, fig_title, cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);
            save_figure_if_needed(fig, cfg, fullfile(cfg.output_dir, ['event_residual_dashboard_' clean_file_string(did)]));
        end

        if isfield(cfg, 'run_gpr_plus_event_residual_lp') && cfg.run_gpr_plus_event_residual_lp
            joint_list = cell(size(cfg.outcome_specs,1),1);
            joint_titles = cell(size(cfg.outcome_specs,1),1);

            for i = 1:size(cfg.outcome_specs,1)
                yid = cfg.outcome_specs{i,1};
                ylabel = cfg.outcome_specs{i,3};
                y = get_required_series(DB, cfg.outcome_specs{i,2}, T);

                [controls_with_lagN_event, cfg_joint] = make_overlay_lp_controls( ...
                    yid, controls, gpr_shock_lag1_oil_controls, ...
                    gpr_shock_lag1_oil_control_names, dseries, cfg);

                joint = estimate_lp_level_change_two_impulses( ...
                    y, z_for_poisson, eres.z_event_resid, poisson_gpr_level, ...
                    controls_with_lagN_event, dummy_controls_dd, sample, cfg_joint);
                event_residual_struct.(did).([yid '_joint_gpr_event']) = joint;

                joint_tmp = joint.table;
                joint_tmp.impulse = repmat(string(did), height(joint_tmp), 1);
                joint_tmp.outcome = repmat(string(yid), height(joint_tmp), 1);
                joint_tmp.outcome_label = repmat(string(ylabel), height(joint_tmp), 1);
                joint_tmp.specification = repmat("overlay_exact_lp_poisson_zN_plus_worldgpr", height(joint_tmp), 1);
                joint_tmp.gpr_test_series = repmat(string(cfg.event_residual_poisson_gpr_label), height(joint_tmp), 1);
                event_joint_results = [event_joint_results; joint_tmp];

                if isfield(cfg, 'run_poisson_arrival_rawN_control_robustness') && cfg.run_poisson_arrival_rawN_control_robustness
                    current_controls_rawN = [dummy_controls_dd, dseries(:)];
                    joint_rawN = estimate_lp_level_change_two_impulses(y, z_for_poisson, eres.z_event_resid, poisson_gpr_level, controls_with_lagN_event, current_controls_rawN, sample, cfg_joint);
                    event_residual_struct.(did).([yid '_joint_gpr_event_rawN_control']) = joint_rawN;

                    joint_rawN_tmp = joint_rawN.table;
                    joint_rawN_tmp.impulse = repmat(string(did), height(joint_rawN_tmp), 1);
                    joint_rawN_tmp.outcome = repmat(string(yid), height(joint_rawN_tmp), 1);
                    joint_rawN_tmp.outcome_label = repmat(string(ylabel), height(joint_rawN_tmp), 1);
                    joint_rawN_tmp.specification = repmat("gpr_plus_poisson_event_residual_with_current_rawN_control", height(joint_rawN_tmp), 1);
                    joint_rawN_tmp.gpr_test_series = repmat(string(cfg.event_residual_poisson_gpr_label), height(joint_rawN_tmp), 1);
                    event_joint_rawN_control_results = [event_joint_rawN_control_results; joint_rawN_tmp];
                end

                joint_list{i} = extract_two_impulse_component(joint, 2);
                joint_titles{i} = ylabel;
            end

            skip_individual_joint_fig = false;
            if isfield(cfg, 'skip_individual_fig_12_14_16') && cfg.skip_individual_fig_12_14_16 ...
                    && isfield(cfg, 'combined_fig_12_14_16_events') && ~isempty(cfg.combined_fig_12_14_16_events)
                skip_individual_joint_fig = any(strcmp(did, cfg.combined_fig_12_14_16_events(:,1)));
            end
            if isfield(cfg, 'skip_individual_poisson_overlay_events') && cfg.skip_individual_poisson_overlay_events ...
                    && isfield(cfg, 'poisson_vs_raw_overlay_events') && ~isempty(cfg.poisson_vs_raw_overlay_events)
                skip_individual_joint_fig = skip_individual_joint_fig || any(strcmp(did, cfg.poisson_vs_raw_overlay_events));
            end

            if ~skip_individual_joint_fig
                joint_fig_title = sprintf('%s: Poisson event-arrival shock, controlling for %s GPR shock', ...
                    did, cfg.event_residual_poisson_gpr_label);
                joint_fig = plot_irf_dashboard(joint_list, joint_titles, cfg, joint_fig_title, cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);
                save_figure_if_needed(joint_fig, cfg, fullfile(cfg.output_dir, ['joint_gpr_event_residual_dashboard_' clean_file_string(did)]));
            end
        end
    end

    if isfield(cfg, 'make_combined_fig_12_14_16') && cfg.make_combined_fig_12_14_16
        combined_fig_title = sprintf('Dummies of Interest: Poisson residual shocks controlling for %s GPR', ...
            cfg.event_residual_poisson_gpr_label);
        combined_fig_12_14_16 = plot_combined_fig_12_14_16_dashboard( ...
            event_residual_struct, cfg, combined_fig_title, ...
            cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);
        set(combined_fig_12_14_16, 'Name', 'Figure_12_14_16_combined', 'NumberTitle', 'off');
        save_figure_if_needed(combined_fig_12_14_16, cfg, ...
            fullfile(cfg.output_dir, 'Figure_12_14_16_combined_poisson_residual_control_world_gpr'));
    end
end

event_count_joint_results = table();
event_count_joint_struct = struct();

if isfield(cfg, 'run_gpr_plus_event_count_lp') && cfg.run_gpr_plus_event_count_lp && ~isempty(dummy_aligned)
    fprintf('\n--- Estimating FWL baseline: raw event count N_t^k controlling for GPR shock ---\n');

    world_gpr_level = get_required_series(DB, cfg.event_residual_poisson_gpr_aliases, T);

    world_innov = extract_ar_level_innovation_mixed_controls(world_gpr_level, sample, cfg.p_gpr_shock, ...
        gpr_shock_current_controls, gpr_shock_lag1_oil_controls, cfg.event_residual_poisson_gpr_label);

    if cfg.standardize_shock
        z_world_gpr = zscore_in_sample(world_innov.resid, sample);
    else
        z_world_gpr = world_innov.resid;
    end


    fprintf('FWL baseline GPR control: %s; finite z = %d / %d\n', ...
        cfg.event_residual_poisson_gpr_label, sum(isfinite(z_world_gpr)), T);

    for dd = 1:numel(cfg.event_impulse_vars)
        did = cfg.event_impulse_vars{dd};

        [N_event, did_source] = get_event_count_or_dummy_series(dummy_aligned, did, T);
        if isempty(N_event) || sum(N_event > 0) == 0
            warning('Event count/dummy not found or all zero: %s. Skipping.', did);
            continue;
        end

        drop_names = make_event_drop_candidates(did, did_source);
        [dummy_controls_dd, dummy_control_names_dd] = drop_dummy_controls_by_names( ...
            dummy_controls, dummy_control_names, drop_names);

        fprintf('\nFWL event-count impulse: %s | source=%s | positive periods=%d | total count=%g\n', ...
            did, did_source, sum(N_event > 0), sum(N_event, 'omitnan'));
        fprintf('  Current event controls after drop: %s\n', strjoin_or_none(dummy_control_names_dd));


        joint_list = cell(size(cfg.outcome_specs,1),1);
        joint_titles = cell(size(cfg.outcome_specs,1),1);

        for i = 1:size(cfg.outcome_specs,1)
            yid = cfg.outcome_specs{i,1};
            ylabel = cfg.outcome_specs{i,3};
            y = get_required_series(DB, cfg.outcome_specs{i,2}, T);

            [controls_with_lagN, cfg_joint] = make_overlay_lp_controls( ...
                yid, controls, gpr_shock_lag1_oil_controls, ...
                gpr_shock_lag1_oil_control_names, N_event, cfg);

            joint = estimate_lp_level_change_two_impulses( ...
                y, z_world_gpr, N_event, world_gpr_level, ...
                controls_with_lagN, dummy_controls_dd, sample, cfg_joint);

            event_count_joint_struct.(did).([yid '_joint_gpr_count']) = joint;

            joint_tmp = joint.table;
            joint_tmp.impulse = repmat(string(did), height(joint_tmp), 1);
            joint_tmp.outcome = repmat(string(yid), height(joint_tmp), 1);
            joint_tmp.outcome_label = repmat(string(ylabel), height(joint_tmp), 1);
            joint_tmp.specification = repmat("overlay_exact_lp_rawN_plus_worldgpr", height(joint_tmp), 1);
            joint_tmp.gpr_control_series = repmat(string(cfg.event_residual_poisson_gpr_label), height(joint_tmp), 1);
            event_count_joint_results = [event_count_joint_results; joint_tmp];

            joint_list{i} = extract_two_impulse_component(joint, 2);
            joint_titles{i} = ylabel;
        end

        skip_individual_raw_fig = false;
        if isfield(cfg, 'skip_individual_raw_count_overlay_events') && cfg.skip_individual_raw_count_overlay_events ...
                && isfield(cfg, 'poisson_vs_raw_overlay_events') && ~isempty(cfg.poisson_vs_raw_overlay_events)
            skip_individual_raw_fig = any(strcmp(did, cfg.poisson_vs_raw_overlay_events));
        end

        if ~skip_individual_raw_fig
            fig_title = sprintf('%s: raw event-arrival count, controlling for %s GPR shock', ...
                did, cfg.event_residual_poisson_gpr_label);

            fig = plot_irf_dashboard(joint_list, joint_titles, cfg, fig_title, ...
                cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);

            save_figure_if_needed(fig, cfg, ...
                fullfile(cfg.output_dir, ['fwl_raw_event_count_dashboard_' clean_file_string(did)]));
        end
    end
end

if isfield(cfg, 'make_poisson_vs_raw_overlay_dashboards') && cfg.make_poisson_vs_raw_overlay_dashboards
    fprintf('\n--- Drawing augmented overlay dashboards: Poisson arrival shock vs raw event count ---\n');

    for oo = 1:numel(cfg.poisson_vs_raw_overlay_events)
        did = cfg.poisson_vs_raw_overlay_events{oo};

        if ~isfield(event_residual_struct, did)
            warning('Overlay skipped: Poisson results not found for %s.', did);
            continue;
        end
        if ~isfield(event_count_joint_struct, did)
            warning('Overlay skipped: raw event-count results not found for %s.', did);
            continue;
        end

        label = clean_file_string(did);
        if isfield(cfg, 'poisson_vs_raw_overlay_labels') && numel(cfg.poisson_vs_raw_overlay_labels) >= oo
            label = cfg.poisson_vs_raw_overlay_labels{oo};
        end

        overlay_title = sprintf('%s: $z_t^{N,k}$ vs $N_t^k$', latex_escape_text(label));
        overlay_fig = plot_poisson_vs_raw_event_dashboard( ...
            event_residual_struct, event_count_joint_struct, did, cfg, overlay_title, ...
            cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);

        set(overlay_fig, 'Name', ['Overlay_poisson_vs_raw_' clean_file_string(did)], 'NumberTitle', 'off');
        save_figure_if_needed(overlay_fig, cfg, ...
            fullfile(cfg.output_dir, ['overlay_poisson_vs_raw_' clean_file_string(did)]));
    end
end

if isfield(cfg, 'run_event_onset_impulse_dashboards') && cfg.run_event_onset_impulse_dashboards && ~isempty(dummy_aligned)
    fprintf('\n--- Estimating optional RAW event-onset dummy impulse LPs ---\n');

    if isfield(GPR_levels, 'World')
        world_gpr_level = GPR_levels.World;
    else
        world_gpr_level = get_required_series(DB, {'LGPR'}, T);
    end

    for dd = 1:numel(cfg.event_impulse_vars)
        did = cfg.event_impulse_vars{dd};
        [dseries, did_source] = get_event_count_or_dummy_series(dummy_aligned, did, T);
        if isempty(dseries) || sum(dseries > 0) == 0
            warning('Event impulse count/dummy not found or all zero: %s. Skipping.', did);
            continue;
        end

        drop_names = make_event_drop_candidates(did, did_source);
        [dummy_controls_dd, dummy_control_names_dd] = drop_dummy_controls_by_names( ...
            dummy_controls, dummy_control_names, drop_names);
        fprintf('  Raw/count event LP controls after drop: %s\n', strjoin_or_none(dummy_control_names_dd));

        res_list = cell(size(cfg.outcome_specs,1),1);
        plot_titles = cell(size(cfg.outcome_specs,1),1);
        fprintf('\nRaw/count event impulse: %s | source=%s | positive periods=%d | total count=%g\n', did, did_source, sum(dseries > 0), sum(dseries, 'omitnan'));

        for i = 1:size(cfg.outcome_specs,1)
            yid = cfg.outcome_specs{i,1};
            ylabel = cfg.outcome_specs{i,3};
            y = get_required_series(DB, cfg.outcome_specs{i,2}, T);

            cfg_event = cfg;
            cfg_event.shock_size = 1;
            res = estimate_lp_level_change(y, dseries, world_gpr_level, controls, dummy_controls_dd, sample, cfg_event);
            event_impulse_struct.(did).(yid) = res;

            tmp = res.table;
            tmp.impulse = repmat(string(did), height(tmp), 1);
            tmp.outcome = repmat(string(yid), height(tmp), 1);
            tmp.outcome_label = repmat(string(ylabel), height(tmp), 1);
            tmp.specification = repmat("raw_event_onset_dummy_level_lp", height(tmp), 1);
            event_impulse_results = [event_impulse_results; tmp];

            res_list{i} = res;
            plot_titles{i} = ylabel;
        end

        fig_title = sprintf('%s: level LP response to raw event-onset dummy', did);
        fig = plot_irf_dashboard(res_list, plot_titles, cfg, fig_title, cfg.dashboard_nrow, cfg.dashboard_ncol, cfg.show_figures);
        save_figure_if_needed(fig, cfg, fullfile(cfg.output_dir, ['raw_event_onset_dashboard_' clean_file_string(did)]));
    end
end

if cfg.save_results
    mode_tag = clean_file_string(cfg.plot_mode);
    writetable(level_lp_results, fullfile(cfg.output_dir, ['level_lp_results_' mode_tag '.csv']));
    writetable(innovation_info, fullfile(cfg.output_dir, ['level_lp_gpr_shock_diagnostics_' mode_tag '.csv']));
    if exist('event_residual_results', 'var') && ~isempty(event_residual_results)
        writetable(event_residual_results, fullfile(cfg.output_dir, ['event_residual_lp_results_' mode_tag '.csv']));
    end
    if exist('event_joint_results', 'var') && ~isempty(event_joint_results)
        writetable(event_joint_results, fullfile(cfg.output_dir, ['event_joint_gpr_plus_poisson_results_' mode_tag '.csv']));
    end
    if exist('event_joint_rawN_control_results', 'var') && ~isempty(event_joint_rawN_control_results)
        writetable(event_joint_rawN_control_results, fullfile(cfg.output_dir, ['event_joint_gpr_plus_poisson_with_rawN_control_results_' mode_tag '.csv']));
    end
    if exist('event_count_joint_results', 'var') && ~isempty(event_count_joint_results)
        writetable(event_count_joint_results, fullfile(cfg.output_dir, ['event_count_fwl_gpr_results_' mode_tag '.csv']));
    end
    if exist('event_residual_diagnostics', 'var') && ~isempty(event_residual_diagnostics)
        writetable(event_residual_diagnostics, fullfile(cfg.output_dir, ['event_residual_poisson_diagnostics_' mode_tag '.csv']));
    end
    if exist('event_residual_gpr_tests', 'var') && ~isempty(event_residual_gpr_tests)
        writetable(event_residual_gpr_tests, fullfile(cfg.output_dir, ['event_residual_nonGPR_resid_on_GPR_tests_' mode_tag '.csv']));
    end
    save(fullfile(cfg.output_dir, ['workspace_level_lp_' mode_tag '.mat']), ...
        'cfg','Z','GPR_levels','innovation_info','level_lp_results','level_lp_struct','control_names','gpr_shock_control_names','dummy_aligned','dummy_controls','dummy_control_names','dummy_info','event_impulse_results','event_impulse_struct','event_residual_results','event_joint_results','event_joint_rawN_control_results','event_residual_struct','event_residual_diagnostics','event_residual_gpr_tests','event_count_joint_results','event_count_joint_struct');
    fprintf('\nSaved results in: %s\n', cfg.output_dir);
else
    if cfg.save_figures
        fprintf('\nFigures saved in: %s\n', cfg.output_dir);
        fprintf('CSV/MAT results not saved because cfg.save_results=false.\n');
    else
        fprintf('\nNo files saved because cfg.save_results=false and cfg.save_figures=false.\n');
    end
    fprintf('Workspace results: event_count_joint_results, event_residual_results, event_joint_results, event_residual_gpr_tests.\n');
end

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

function x = get_series_if_exists(DB, targets, T)
    if ischar(targets) || isstring(targets)
        targets = cellstr(targets);
    end
    names = DB.Properties.VariableNames;
    x = [];
    for ii = 1:numel(targets)
        target = char(targets{ii});
        idx = find(strcmpi(names, target), 1, 'first');
        if isempty(idx)
            idx = find(startsWith(names, target, 'IgnoreCase', true), 1, 'first');
        end
        if ~isempty(idx)
            raw = DB.(names{idx});
            if isnumeric(raw) || islogical(raw)
                x = double(raw(:));
                if numel(x) ~= T
                    warning('Variable %s has incompatible length and is skipped.', names{idx});
                    x = [];
                end
                return;
            else
                x = [];
                return;
            end
        end
    end
end

function x = get_required_series(DB, targets, T)
    x = get_series_if_exists(DB, targets, T);
    if isempty(x)
        if ischar(targets) || isstring(targets)
            msg = char(targets);
        else
            msg = strjoin(cellstr(targets), ', ');
        end
        error('Required numeric variable not found. Tried: %s', msg);
    end
end

function [controls, control_names] = build_controls(DB, control_aliases, T)
    controls = [];
    control_names = {};
    for i = 1:numel(control_aliases)
        x = get_series_if_exists(DB, control_aliases{i}, T);
        if ~isempty(x)
            controls = [controls, x];
            control_names{end+1} = char(control_aliases{i}{1});
        else
            warning('Control not found and skipped: %s', strjoin(control_aliases{i}, ', '));
        end
    end
end

function [dummy_aligned, dummy_controls, dummy_control_names, info] = build_aligned_dummy_controls(DB, quarter_labels, has_quarter, T, cfg)
    dummy_aligned = table();
    dummy_controls = zeros(T,0);
    dummy_control_names = {};
    info = struct();

    if ~has_quarter
        warning('No Quarter/Date column found in the level database. Dummy controls cannot be aligned.');
        return;
    end

    q_db = string(quarter_labels(:));
    dummy_aligned = table(q_db, 'VariableNames', {'Quarter'});

    if isfield(cfg, 'use_event_dummies') && cfg.use_event_dummies
        D = load_dummy_table_from_file(cfg);
        if ~isempty(D)
            qD = get_quarter_from_dummy_table(D);
            if isempty(qD)
                warning('Dummy file loaded, but no Quarter/date column was found. Event dummies are kept as zeros unless constructed below.');
            else
                qD = string(qD(:));
                dnames = D.Properties.VariableNames;
                [tf, loc] = ismember(q_db, qD);

                for j = 1:numel(dnames)
                    v = dnames{j};
                    if any(strcmpi(v, {'Quarter','quarter','Date','date','Time','time'}))
                        continue;
                    end

                    raw = D.(v);
                    if isnumeric(raw) || islogical(raw)
                        x = double(raw(:));
                    else

                        continue;
                    end

                    if numel(x) ~= numel(qD)
                        continue;
                    end

                    aligned = zeros(T,1);
                    aligned(tf) = x(loc(tf));
                    aligned(~isfinite(aligned)) = 0;

                    safe_v = matlab.lang.makeValidName(v);
                    dummy_aligned.(safe_v) = aligned;
                end
            end
        end
    end

    if isfield(cfg, 'event_episode_vars')
        for i = 1:numel(cfg.event_episode_vars)
            v = cfg.event_episode_vars{i};
            if ~ismember(v, dummy_aligned.Properties.VariableNames)
                dummy_aligned.(v) = zeros(T,1);
            end
        end
    end

    if isfield(cfg, 'use_covid_dummy') && cfg.use_covid_dummy
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

    base_onset_vars = unique([{'OilThreat','OilAct','ThreatOnly','ActOnly','ThreatAct','AnyOilEvent'}, cfg.event_episode_vars], 'stable');
    for i = 1:numel(base_onset_vars)
        v = base_onset_vars{i};
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
        else
            warning('Requested dummy control not found and skipped: %s', v);
        end
    end

    info.loaded_dummy_file = '';
    if isfield(cfg, 'dummy_file') && ~isempty(cfg.dummy_file) && exist(cfg.dummy_file, 'file')
        info.loaded_dummy_file = cfg.dummy_file;
    end
    info.dummy_control_names = dummy_control_names;
end

function D = load_dummy_table_from_file(cfg)
    D = table();

    if ~isfield(cfg, 'dummy_file') || isempty(cfg.dummy_file)
        warning('cfg.dummy_file is empty. Event dummies are kept as zeros.');
        return;
    end

    if ~exist(cfg.dummy_file, 'file')
        warning('Dummy CSV file not found: %s. Event dummies are kept as zeros.', cfg.dummy_file);
        return;
    end

    [~,~,ext] = fileparts(cfg.dummy_file);
    if ~strcmpi(ext, '.csv')
        error('This simplified version expects cfg.dummy_file to be a CSV file: %s', cfg.dummy_file);
    end

    D = readtable(cfg.dummy_file, 'VariableNamingRule','preserve');
    fprintf('\nLoaded dummy CSV file: %s\n', cfg.dummy_file);

    if ~istable(D)
        warning('Loaded dummy object is not a table. Event dummies are kept as zeros.');
        D = table();
    end
end

function q = get_quarter_from_dummy_table(D)
    q = [];
    if isempty(D), return; end
    names = D.Properties.VariableNames;
    candidates = {'Quarter','quarter','Date','date','time','Time'};
    for i = 1:numel(candidates)
        idx = find(strcmpi(names, candidates{i}), 1);
        if ~isempty(idx)
            raw = D.(names{idx});
            q = cellstr(string(raw(:)));
            return;
        end
    end
end

function x = get_dummy_series_from_table(D, varname)
    x = [];
    if isempty(D), return; end
    names = D.Properties.VariableNames;
    idx = find(strcmpi(names, varname), 1);
    if isempty(idx), return; end
    raw = D.(names{idx});
    if isnumeric(raw) || islogical(raw)
        x = double(raw(:));
    else
        x = double(str2double(string(raw(:))));
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

function x = get_dummy_series(dummy_aligned, varname, T)
    x = [];
    if isempty(dummy_aligned), return; end
    if ismember(varname, dummy_aligned.Properties.VariableNames)
        x = double(dummy_aligned.(varname)(:));
        if numel(x) ~= T
            x = [];
        end
    end
end

function [x, source_name] = get_event_count_or_dummy_series(dummy_aligned, varname, T)

    source_name = varname;
    x = get_dummy_series(dummy_aligned, varname, T);
    if ~isempty(x)
        return;
    end

    if startsWith(varname, 'n_')
        alt = regexprep(varname, '^n_', '');
        x = get_dummy_series(dummy_aligned, alt, T);
        if ~isempty(x)
            source_name = alt;
            return;
        end
    else
        alt = ['n_' varname];
        x = get_dummy_series(dummy_aligned, alt, T);
        if ~isempty(x)
            source_name = alt;
            return;
        end
    end
end

function [Xdrop, names_drop] = drop_dummy_control(X, names, name_to_drop)
    Xdrop = X;
    names_drop = names;
    idx = find(strcmp(names, name_to_drop), 1);
    if ~isempty(idx)
        Xdrop(:,idx) = [];
        names_drop(idx) = [];
    end
end

function candidates = make_event_drop_candidates(did, did_source)

    if nargin < 2 || isempty(did_source)
        did_source = did;
    end

    base1 = strip_count_prefix(did);
    base2 = strip_count_prefix(did_source);

    candidates = {char(did), char(did_source), char(base1), char(base2), ...
        ['n_' char(base1)], ['n_' char(base2)]};
    candidates = unique(candidates, 'stable');
end

function s = strip_count_prefix(s)
    s = char(s);
    if startsWith(s, 'n_')
        s = regexprep(s, '^n_', '');
    end
end

function [Xdrop, names_drop] = drop_dummy_controls_by_names(X, names, names_to_drop)
    Xdrop = X;
    names_drop = names;
    if isempty(names) || isempty(names_to_drop)
        return;
    end
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

function s = strjoin_or_none(names)
    if isempty(names)
        s = 'none';
    else
        s = strjoin(names, ', ');
    end
end

function [dummy_controls, dummy_control_names] = build_dummy_control_matrix_from_names(dummy_aligned, names, T)
    dummy_controls = zeros(T,0);
    dummy_control_names = {};
    if isempty(names) || isempty(dummy_aligned)
        return;
    end
    for i = 1:numel(names)
        v = names{i};
        x = get_dummy_series(dummy_aligned, v, T);
        if isempty(x)
            warning('Requested residual-LP dummy control not found and skipped: %s', v);
            continue;
        end
        x(~isfinite(x)) = 0;
        dummy_controls = [dummy_controls, x(:)];
        dummy_control_names{end+1} = v;
    end
end

function out = estimate_poisson_event_residual(N, z_gpr, gpr_level, controls, sample, cfg, label)

    N = double(N(:));
    N(~isfinite(N)) = NaN;
    N(N < 0) = NaN;
    if nargin < 2 || isempty(z_gpr)
        z_gpr = nan(size(N));
    else
        z_gpr = z_gpr(:);
    end
    T = length(N);
    if nargin < 3 || isempty(gpr_level)
        gpr_level = nan(T,0);
    else
        gpr_level = double(gpr_level);
        if isvector(gpr_level)
            gpr_level = gpr_level(:);
        end
        if size(gpr_level,1) ~= T
            error('GPR level matrix for Poisson intensity has %d rows, expected %d.', size(gpr_level,1), T);
        end
    end

    if isempty(controls)
        controls = zeros(T,0);
    end

    use_lagN = isfield(cfg, 'poisson_include_lagged_count') && cfg.poisson_include_lagged_count;
    use_lagC = isfield(cfg, 'poisson_include_lagged_controls') && cfg.poisson_include_lagged_controls && ~isempty(controls);

    p_gpr_level = 0;
    if isfield(cfg, 'poisson_include_lagged_gpr_level') && cfg.poisson_include_lagged_gpr_level
        p_gpr_level = cfg.poisson_gpr_level_lags;
    end
    p_gpr_level = max(0, round(p_gpr_level));
    min_lag = max(1, p_gpr_level);

    t_grid = (min_lag+1):T;
    Xraw = zeros(numel(t_grid), 0);
    pred_names = {};

    include_gpr_in_intensity = true;
    if isfield(cfg, 'poisson_exclude_gpr_from_intensity') && cfg.poisson_exclude_gpr_from_intensity
        include_gpr_in_intensity = false;
    end

    if include_gpr_in_intensity
        include_current_gpr_shock = true;
        if isfield(cfg, 'poisson_include_current_gpr_shock')
            include_current_gpr_shock = cfg.poisson_include_current_gpr_shock;
        end
        if include_current_gpr_shock
            gpr_timing = 'current';
            if isfield(cfg, 'poisson_gpr_timing')
                gpr_timing = lower(strtrim(cfg.poisson_gpr_timing));
            end
            switch gpr_timing
                case {'current','contemporaneous','t'}
                    Xraw = [Xraw, z_gpr(t_grid)];
                    pred_names{end+1} = 'z_GPR_t';
                case {'lagged','lag','tminus1','t-1'}
                    Xraw = [Xraw, z_gpr(t_grid-1)];
                    pred_names{end+1} = 'z_GPR_lag1';
                otherwise
                    error('Unknown cfg.poisson_gpr_timing=%s. Use current or lagged.', gpr_timing);
            end
        end

        if p_gpr_level > 0 && ~isempty(gpr_level)
            gpr_names = {};
            if isfield(cfg, 'poisson_lagged_gpr_component_labels') && ~isempty(cfg.poisson_lagged_gpr_component_labels)
                gpr_names = cfg.poisson_lagged_gpr_component_labels;
            end
            for jj = 1:p_gpr_level
                for gg = 1:size(gpr_level,2)
                    Xraw = [Xraw, gpr_level(t_grid-jj, gg)];
                    if numel(gpr_names) >= gg
                        base_name = gpr_names{gg};
                    else
                        base_name = sprintf('GPR_component%d', gg);
                    end
                    pred_names{end+1} = sprintf('%s_lag%d', base_name, jj);
                end
            end
        end
    end

    if use_lagN
        Xraw = [Xraw, N(t_grid-1)];
        pred_names{end+1} = 'lagN';
    end

    if use_lagC
        Xraw = [Xraw, controls(t_grid-1,:)];
        for j = 1:size(controls,2)
            pred_names{end+1} = sprintf('lagControl%d', j);
        end
    end

    Y = N(t_grid);
    valid = sample(t_grid) & sample(t_grid-min_lag) & isfinite(Y) & all(isfinite(Xraw),2);

    Yuse = Y(valid);
    Xuse_raw = Xraw(valid,:);

    min_positive = 4;
    if isfield(cfg, 'poisson_min_positive_periods')
        min_positive = cfg.poisson_min_positive_periods;
    end

    n_positive = sum(Yuse > 0);
    n_zero = sum(Yuse == 0);
    total_count = sum(Yuse);

    z_event_resid = nan(T,1);
    event_resid = nan(T,1);
    pearson_resid = nan(T,1);
    lambda_hat = nan(T,1);
    eta_hat = nan(T,1);
    b = nan(size(Xuse_raw,2)+1,1);
    method = "not_estimated";
    converged = false;

    if numel(Yuse) <= size(Xuse_raw,2) + 1 || n_positive < min_positive || total_count <= 0
        warning('Too few positive periods/counts for Poisson residualization of %s: n=%d, positive_periods=%d, total_count=%g.', ...
            label, numel(Yuse), n_positive, total_count);
        resid_sd = NaN;
        diag = table(string(label), string(method), converged, numel(Yuse), n_positive, n_zero, total_count, ...
            NaN, NaN, NaN, NaN, NaN, ...
            'VariableNames', {'event','method','converged','nobs','positive_periods','zero_periods','total_count','mean_lambda_positive','mean_lambda_zero','pearson_resid_sd','corr_N_lambda','deviance'});
        out = struct('label',label,'N',N,'z_event_resid',z_event_resid,'event_resid',event_resid, ...
            'pearson_resid',pearson_resid,'lambda_hat',lambda_hat,'eta_hat',eta_hat,'coeff',b, ...
            'predictor_names',{pred_names}, 'gpr_included_in_intensity', include_gpr_in_intensity, ...
            'gpr_level_lags_in_intensity', p_gpr_level, ...
            'nobs',numel(Yuse),'positive_periods',n_positive, ...
            'zero_periods',n_zero,'total_count',total_count,'method',method,'converged',converged, ...
            'resid_sd',resid_sd,'diagnostics',diag);
        return;
    end

    standardize_predictors = true;
    if isfield(cfg, 'poisson_standardize_predictors')
        standardize_predictors = cfg.poisson_standardize_predictors;
    end

    [Xuse, muX, sdX] = standardize_design_columns(Xuse_raw, standardize_predictors);

    [b, method, converged] = fit_poisson_count(Yuse, Xuse, cfg);

    eta_use = [ones(size(Xuse,1),1), Xuse] * b;
    lam_use = clamp_intensity(exp(max(min(eta_use, 30), -30)));

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
        corr_N_lambda = corr(Yuse, lam_use, 'Rows','complete');
    else
        corr_N_lambda = NaN;
    end
    dev = poisson_deviance(Yuse, lam_use);

    diag = table(string(label), string(method), converged, numel(Yuse), n_positive, n_zero, total_count, ...
        mean_lambda_positive, mean_lambda_zero, resid_sd, corr_N_lambda, dev, ...
        'VariableNames', {'event','method','converged','nobs','positive_periods','zero_periods','total_count','mean_lambda_positive','mean_lambda_zero','pearson_resid_sd','corr_N_lambda','deviance'});

    out = struct();
    out.label = label;
    out.N = N;
    out.z_event_resid = z_event_resid;
    out.event_resid = event_resid;
    out.pearson_resid = pearson_resid;
    out.lambda_hat = lambda_hat;
    out.eta_hat = eta_hat;
    out.coeff = b;
    out.predictor_names = pred_names;
    out.gpr_included_in_intensity = include_gpr_in_intensity;
    out.gpr_level_lags_in_intensity = p_gpr_level;
    out.predictor_mean = muX;
    out.predictor_sd = sdX;
    out.nobs = numel(Yuse);
    out.positive_periods = n_positive;
    out.zero_periods = n_zero;
    out.total_count = total_count;
    out.method = method;
    out.converged = converged;
    out.resid_sd = resid_sd;
    out.diagnostics = diag;
end

function outtab = estimate_event_residual_gpr_relation(event_id, z_event_resid, z_gpr_shock, gpr_level_std, sample, cfg)

    y  = double(z_event_resid(:));
    x1 = double(z_gpr_shock(:));
    x2 = double(gpr_level_std(:));
    sample = logical(sample(:));

    threshold = 1.0;
    if isfield(cfg, 'gpr_high_threshold')
        threshold = cfg.gpr_high_threshold;
    end

    valid = sample & isfinite(y) & isfinite(x1) & isfinite(x2);
    nobs = sum(valid);

    beta_shock = NaN; se_shock = NaN; t_shock = NaN; p_shock = NaN;
    beta_level = NaN; se_level = NaN; t_level = NaN; p_level = NaN;
    corr_shock = NaN; corr_level = NaN;

    if nobs > 5
        Y = y(valid);
        X = [ones(nobs,1), x1(valid), x2(valid)];
        [b, se] = ols_hac(Y, X, 0);

        beta_shock = b(2);
        se_shock = se(2);
        if isfinite(se_shock) && se_shock > 0
            t_shock = beta_shock / se_shock;
            p_shock = 2 * (1 - normal_cdf(abs(t_shock)));
        end

        beta_level = b(3);
        se_level = se(3);
        if isfinite(se_level) && se_level > 0
            t_level = beta_level / se_level;
            p_level = 2 * (1 - normal_cdf(abs(t_level)));
        end

        if std(Y) > 0 && std(x1(valid)) > 0
            corr_shock = corr(Y, x1(valid), 'Rows','complete');
        end
        if std(Y) > 0 && std(x2(valid)) > 0
            corr_level = corr(Y, x2(valid), 'Rows','complete');
        end
    end

    high_shock = valid & (x1 >= threshold);
    low_shock  = valid & (x1 <  threshold);
    high_level = valid & (x2 >= threshold);
    low_level  = valid & (x2 <  threshold);

    mean_resid_high_shock = mean(y(high_shock), 'omitnan');
    mean_resid_low_shock  = mean(y(low_shock),  'omitnan');
    mean_resid_high_level = mean(y(high_level), 'omitnan');
    mean_resid_low_level  = mean(y(low_level),  'omitnan');

    share_positive_high_shock = mean(y(high_shock) > 0, 'omitnan');
    share_positive_low_shock  = mean(y(low_shock)  > 0, 'omitnan');
    share_positive_high_level = mean(y(high_level) > 0, 'omitnan');
    share_positive_low_level  = mean(y(low_level)  > 0, 'omitnan');

    outtab = table(string(event_id), nobs, threshold, ...
        beta_shock, se_shock, t_shock, p_shock, corr_shock, ...
        beta_level, se_level, t_level, p_level, corr_level, ...
        sum(high_shock), mean_resid_high_shock, mean_resid_low_shock, ...
        share_positive_high_shock, share_positive_low_shock, ...
        sum(high_level), mean_resid_high_level, mean_resid_low_level, ...
        share_positive_high_level, share_positive_low_level, ...
        'VariableNames', {'event','nobs','high_threshold', ...
        'beta_gpr_shock','se_gpr_shock','t_gpr_shock','p_gpr_shock','corr_gpr_shock', ...
        'beta_gpr_level','se_gpr_level','t_gpr_level','p_gpr_level','corr_gpr_level', ...
        'n_high_gpr_shock','mean_resid_high_gpr_shock','mean_resid_low_gpr_shock', ...
        'share_pos_resid_high_gpr_shock','share_pos_resid_low_gpr_shock', ...
        'n_high_gpr_level','mean_resid_high_gpr_level','mean_resid_low_gpr_level', ...
        'share_pos_resid_high_gpr_level','share_pos_resid_low_gpr_level'});
end

function [Xstd, muX, sdX] = standardize_design_columns(X, do_standardize)
    Xstd = X;
    muX = zeros(1,size(X,2));
    sdX = ones(1,size(X,2));
    if ~do_standardize || isempty(X)
        return;
    end

    for j = 1:size(X,2)
        xj = X(:,j);
        mu = mean(xj, 'omitnan');
        sd = std(xj, 'omitnan');
        if isfinite(sd) && sd > 0
            Xstd(:,j) = (xj - mu) ./ sd;
            muX(j) = mu;
            sdX(j) = sd;
        else
            Xstd(:,j) = xj;
            muX(j) = 0;
            sdX(j) = 1;
        end
    end
end

function [b, method, converged] = fit_poisson_count(Y, X, cfg)
    Y = double(Y(:));
    X = double(X);
    k = size(X,2);

    if exist('glmfit', 'file') == 2
        try
            [b, ~, stats] = glmfit(X, Y, 'poisson', 'link', 'log');
            method = "glmfit_poisson";
            converged = true;
            if isfield(stats, 'se') && any(~isfinite(stats.se))
                converged = false;
            end
            return;
        catch ME
            warning('glmfit Poisson failed: %s. Falling back to fminsearch Poisson.', ME.message);
        end
    end

    ybar = max(mean(Y, 'omitnan'), 1e-6);
    b0 = zeros(k+1,1);
    b0(1) = log(ybar);

    lambda = 0;
    if isfield(cfg, 'poisson_ridge_lambda')
        lambda = cfg.poisson_ridge_lambda;
    end

    obj = @(theta) poisson_negloglik(theta, Y, X, lambda);
    opts = optimset('Display','off', 'MaxIter', 20000, 'MaxFunEvals', 50000, ...
        'TolX', 1e-8, 'TolFun', 1e-8);
    [b, ~, exitflag] = fminsearch(obj, b0, opts);
    method = "fminsearch_poisson";
    converged = exitflag > 0;
end

function nll = poisson_negloglik(theta, Y, X, lambda)
    eta = [ones(size(X,1),1), X] * theta(:);
    mu = clamp_intensity(exp(max(min(eta, 30), -30)));
    nll = -sum(Y .* log(mu) - mu - gammaln(Y + 1));
    if nargin >= 4 && isfinite(lambda) && lambda > 0
        nll = nll + lambda * sum(theta(2:end).^2);
    end
end

function mu = clamp_intensity(mu)
    mu = min(max(mu, 1e-8), 1e8);
end

function dev = poisson_deviance(Y, mu)
    Y = double(Y(:));
    mu = clamp_intensity(mu(:));
    term = zeros(size(Y));
    pos = Y > 0;
    term(pos) = Y(pos) .* log(Y(pos) ./ mu(pos)) - (Y(pos) - mu(pos));
    term(~pos) = mu(~pos);
    dev = 2 * sum(term, 'omitnan');
end

function p = normal_cdf(x)
    p = 0.5 .* erfc(-x ./ sqrt(2));
end

function f = normal_pdf(x)
    f = exp(-0.5 .* x.^2) ./ sqrt(2*pi);
end

function p = clamp_probability(p)
    p = min(max(p, 1e-8), 1 - 1e-8);
end

function Xlag = lag_one_matrix(X)

    if isempty(X)
        Xlag = X;
        return;
    end
    Xlag = nan(size(X));
    Xlag(2:end,:) = X(1:end-1,:);
end

function oil_keep = get_oil_keep_for_outcome(yid, oil_names)
    oil_keep = true(1, numel(oil_names));
    if strcmpi(yid, 'Real_Brent')
        oil_keep = ~strcmpi(oil_names, 'Real_Brent');
    elseif strcmpi(yid, 'Real_WTI')
        oil_keep = ~strcmpi(oil_names, 'Real_WTI');
    elseif strcmpi(yid, 'Real_Gasoline')
        oil_keep = ~strcmpi(oil_names, 'Real_Gasoline');
    end
end

function out = extract_ar_level_innovation_mixed_controls(x, sample, p, current_controls, lag1_controls, label)

    x = double(x(:));
    T = length(x);
    sample = logical(sample(:));

    if isempty(current_controls)
        current_controls = zeros(T,0);
    end
    if isempty(lag1_controls)
        lag1_controls = zeros(T,0);
    end

    current_controls = double(current_controls);
    lag1_controls = double(lag1_controls);

    if size(current_controls,1) ~= T
        error('Current-control matrix has incompatible length in GPR shock extraction for %s.', label);
    end
    if size(lag1_controls,1) ~= T
        error('Lag-1 oil-control matrix has incompatible length in GPR shock extraction for %s.', label);
    end

    nCurrent = size(current_controls, 2);
    nLag1 = size(lag1_controls, 2);

    t_grid = (p+1):T;
    n = numel(t_grid);

    k = 1 + p + nCurrent + nLag1;
    Y = nan(n,1);
    X = nan(n,k);
    keep = false(n,1);

    for ii = 1:n
        t = t_grid(ii);

        row = nan(1,k);
        c = 1;

        row(c) = 1;
        c = c + 1;

        for j = 1:p
            row(c) = x(t-j);
            c = c + 1;
        end

        if nCurrent > 0
            row(c:c+nCurrent-1) = current_controls(t,:);
            c = c + nCurrent;
        end

        if nLag1 > 0
            row(c:c+nLag1-1) = lag1_controls(t-1,:);
            c = c + nLag1;
        end

        Y(ii) = x(t);
        X(ii,:) = row;

        keep(ii) = sample(t) && all(sample(t-p:t));
    end

    good = keep & isfinite(Y) & all(isfinite(X),2);
    Yg = Y(good);
    Xg = X(good,:);
    tg = t_grid(good)';

    if isempty(Yg) || size(Xg,1) <= size(Xg,2)
        error('No usable observations in mixed-control AR shock extraction for %s.', label);
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

    out = struct();
    out.label = label;
    out.t_index = tg;
    out.coeff = b;
    out.fitted = fitted;
    out.resid = resid;
    out.nobs = numel(Yg);
    out.rsq = rsq;
    out.mean_resid = mean(u);
    out.std_resid = std(u);
    out.num_current_controls = nCurrent;
    out.num_lag1_controls = nLag1;
    out.specification = "AR(p) + current macro controls + lag-1 oil-price controls";
end

function out = extract_ar_level_innovation_with_controls(x, sample, p, bc_controls, control_timing, label)

    x = x(:);
    T = length(x);

    if nargin < 4 || isempty(bc_controls)
        bc_controls = zeros(T,0);
    end
    if nargin < 5 || isempty(control_timing)
        control_timing = 'contemporaneous';
    end
    control_timing = lower(strtrim(control_timing));

    if size(bc_controls,1) ~= T
        error('Business-cycle control matrix has incompatible length in GPR shock extraction for %s.', label);
    end

    nB = size(bc_controls,2);
    t_grid = (p+1):T;
    n = numel(t_grid);
    k = 1 + p + nB;

    Y = nan(n,1);
    X = nan(n,k);
    keep = false(n,1);

    for ii = 1:n
        t = t_grid(ii);
        row = nan(1,k);
        c = 1;
        row(c) = 1; c = c + 1;

        for j = 1:p
            row(c) = x(t-j);
            c = c + 1;
        end

        if nB > 0
            switch control_timing
                case {'contemporaneous','current','t'}
                    bvals = bc_controls(t,:);
                    sample_controls_ok = sample(t);
                case {'lagged','lag','tminus1','t-1'}
                    bvals = bc_controls(t-1,:);
                    sample_controls_ok = sample(t-1);
                otherwise
                    error('Unknown cfg.gpr_shock_control_timing=%s. Use contemporaneous or lagged.', control_timing);
            end
            row(c:c+nB-1) = bvals;
        else
            sample_controls_ok = true;
        end

        Y(ii) = x(t);
        X(ii,:) = row;
        keep(ii) = sample(t) && all(sample(t-p:t)) && sample_controls_ok;
    end

    good = keep & isfinite(Y) & all(isfinite(X),2);
    Yg = Y(good);
    Xg = X(good,:);
    tg = t_grid(good)';

    if isempty(Yg) || size(Xg,1) <= size(Xg,2)
        error('No usable observations in AR+controls GPR shock extraction for %s.', label);
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
        'nobs',numel(Yg),'rsq',rsq,'mean_resid',mean(u),'std_resid',std(u), ...
        'control_timing',control_timing,'num_business_cycle_controls',nB);
end

function out = extract_ar_level_innovation(x, sample, p, label)
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

    if isempty(Yg) || size(Xg,1) <= size(Xg,2)
        error('No usable observations in AR level shock extraction for %s.', label);
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
    if ~isfinite(sd) || sd == 0
        warning('Shock standard deviation is zero or invalid. Returning unstandardized residual.');
        z = x;
    else
        z = (x - mu) ./ sd;
    end
end

function res = estimate_lp_level_change(y, z, gpr_level, controls, dummy_controls, sample, cfg)
    H = cfg.H;
    zcrit = normal_icdf(0.5 + cfg.ci/2);

    beta = nan(H+1,1);
    se   = nan(H+1,1);
    lb   = nan(H+1,1);
    ub   = nan(H+1,1);
    nobs = nan(H+1,1);

    for h = 0:H
        [Y, X] = build_lp_level_change_design(y, z, gpr_level, controls, dummy_controls, sample, cfg.p_lp, h);
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
    res.response_ylabel = 'Level change: y_{t+h} - y_{t-1}';
    res.table = table((0:H)', beta, se, lb, ub, nobs, ...
        'VariableNames', {'h','beta','se','lb','ub','nobs'});
end


function [controls_overlay, cfg_joint] = make_overlay_lp_controls(yid, macro_controls, oil_controls, oil_names, event_count, cfg)
    oil_keep = get_oil_keep_for_outcome(yid, oil_names);
    oil_minus_y = oil_controls(:, oil_keep);
    controls_overlay = [macro_controls, oil_minus_y, event_count(:)];

    cfg_joint = cfg;
    if isfield(cfg, 'p_dynamic_lp_event_count') && ~isempty(cfg.p_dynamic_lp_event_count)
        cfg_joint.p_lp = cfg.p_dynamic_lp_event_count;
    end
    if isfield(cfg, 'p_macro_lp_event_count') && ~isempty(cfg.p_macro_lp_event_count)
        cfg_joint.p_control_lag_two_impulses = cfg.p_macro_lp_event_count;
    else
        cfg_joint.p_control_lag_two_impulses = 1;
    end
    cfg_joint.n_full_lag_controls_two_impulses = size(oil_minus_y, 2) + 1;
    cfg_joint.shock_size_z1 = cfg.shock_size;
    cfg_joint.shock_size_z2 = 1;
end

function res = estimate_lp_level_change_two_impulses(y, z1, z2, gpr_level, controls, dummy_controls, sample, cfg)
    H = cfg.H;
    zcrit = normal_icdf(0.5 + cfg.ci/2);

    scale1 = cfg.shock_size;
    scale2 = 1;
    if isfield(cfg, 'shock_size_z1'), scale1 = cfg.shock_size_z1; end
    if isfield(cfg, 'shock_size_z2'), scale2 = cfg.shock_size_z2; end

    beta1 = nan(H+1,1); se1 = nan(H+1,1); lb1 = nan(H+1,1); ub1 = nan(H+1,1);
    beta2 = nan(H+1,1); se2 = nan(H+1,1); lb2 = nan(H+1,1); ub2 = nan(H+1,1);
    nobs = nan(H+1,1);

    for h = 0:H
        [Y, X] = build_lp_level_change_design_two_impulses(y, z1, z2, gpr_level, controls, dummy_controls, sample, cfg.p_lp, h, cfg);
        if isempty(Y) || size(X,1) <= size(X,2)
            continue;
        end

        bw = min(h + 1, size(X,1)-1);
        [b, se_all] = ols_hac(Y, X, bw);

        beta1(h+1) = scale1 * b(2);
        se1(h+1)   = scale1 * se_all(2);
        lb1(h+1)   = beta1(h+1) - zcrit * se1(h+1);
        ub1(h+1)   = beta1(h+1) + zcrit * se1(h+1);

        beta2(h+1) = scale2 * b(3);
        se2(h+1)   = scale2 * se_all(3);
        lb2(h+1)   = beta2(h+1) - zcrit * se2(h+1);
        ub2(h+1)   = beta2(h+1) + zcrit * se2(h+1);

        nobs(h+1) = size(X,1);
    end

    res = struct();
    res.h = (0:H)';
    res.beta1 = beta1; res.se1 = se1; res.lb1 = lb1; res.ub1 = ub1;
    res.beta2 = beta2; res.se2 = se2; res.lb2 = lb2; res.ub2 = ub2;
    res.nobs = nobs;
    res.response_ylabel = 'Level change: y_{t+h} - y_{t-1}';
    res.table = table((0:H)', beta1, se1, lb1, ub1, beta2, se2, lb2, ub2, nobs, ...
        'VariableNames', {'h','beta_gpr','se_gpr','lb_gpr','ub_gpr','beta_event','se_event','lb_event','ub_event','nobs'});
end

function comp = extract_two_impulse_component(joint, which_component)
    comp = struct();
    comp.h = joint.h;
    comp.nobs = joint.nobs;
    if which_component == 1
        comp.beta = joint.beta1;
        comp.se = joint.se1;
        comp.lb = joint.lb1;
        comp.ub = joint.ub1;
    else
        comp.beta = joint.beta2;
        comp.se = joint.se2;
        comp.lb = joint.lb2;
        comp.ub = joint.ub2;
    end
    comp.response_ylabel = joint.response_ylabel;
    comp.table = table(comp.h, comp.beta, comp.se, comp.lb, comp.ub, comp.nobs, ...
        'VariableNames', {'h','beta','se','lb','ub','nobs'});
end

function [Y, X, good, dbg] = build_lp_level_change_design_two_impulses(y, z1, z2, gpr_level, controls, dummy_controls, sample, p, h, cfg)
    y = y(:);
    z1 = z1(:);
    z2 = z2(:);
    gpr_level = gpr_level(:);
    T = length(y);

    if nargin < 10 || isempty(cfg)
        cfg = struct();
    end

    if isempty(controls)
        controls = zeros(T,0);
    end
    if isempty(dummy_controls)
        dummy_controls = zeros(T,0);
    end
    nC = size(controls,2);
    nD = size(dummy_controls,2);

    p_control = p;
    if isfield(cfg, 'p_control_lag_two_impulses') && ~isempty(cfg.p_control_lag_two_impulses)
        p_control = cfg.p_control_lag_two_impulses;
    end
    p_control = max(0, min(p, round(p_control)));

    n_full_lag_controls = 0;
    if isfield(cfg, 'n_full_lag_controls_two_impulses') && ~isempty(cfg.n_full_lag_controls_two_impulses)
        n_full_lag_controls = cfg.n_full_lag_controls_two_impulses;
    end
    n_full_lag_controls = max(0, min(nC, round(n_full_lag_controls)));

    n_short = nC - n_full_lag_controls;
    controls_short = controls(:, 1:n_short);
    controls_full  = controls(:, n_short+1:nC);
    nC_short = size(controls_short,2);
    nC_full  = size(controls_full,2);

    p_max = max(p, p_control);

    t_grid = (p_max+1):(T-h);
    n = numel(t_grid);
    k = 1 + 2 + nD + p + p + p_control*nC_short + p*nC_full;
    X0 = nan(n,k);
    Y0 = nan(n,1);

    sample_ok = false(n,1);
    y_ok = false(n,1);
    z_ok = false(n,1);
    dummy_ok = true(n,1);
    ylags_ok = false(n,1);
    gprlags_ok = false(n,1);
    controls_ok = true(n,1);

    for ii = 1:n
        t = t_grid(ii);
        c = 1;
        row = nan(1,k);

        Y0(ii) = y(t+h) - y(t-1);

        row(c) = 1; c = c + 1;
        row(c) = z1(t); c = c + 1;
        row(c) = z2(t); c = c + 1;

        if nD > 0
            valsD = dummy_controls(t,:);
            row(c:c+nD-1) = valsD;
            dummy_ok(ii) = all(isfinite(valsD));
            c = c + nD;
        end

        ylag = nan(1,p);
        for j = 1:p
            ylag(j) = y(t-j);
            row(c) = ylag(j); c = c + 1;
        end

        gprlag = nan(1,p);
        for j = 1:p
            gprlag(j) = gpr_level(t-j);
            row(c) = gprlag(j); c = c + 1;
        end

        ctrl_block = [];

        if nC_short > 0 && p_control > 0
            for j = 1:p_control
                valsC = controls_short(t-j,:);
                row(c:c+nC_short-1) = valsC;
                ctrl_block = [ctrl_block, valsC];
                c = c + nC_short;
            end
        end

        if nC_full > 0
            for j = 1:p
                valsC = controls_full(t-j,:);
                row(c:c+nC_full-1) = valsC;
                ctrl_block = [ctrl_block, valsC];
                c = c + nC_full;
            end
        end

        X0(ii,:) = row;

        sample_ok(ii) = sample(t) && sample(t+h) && all(sample(t-p_max:t));
        y_ok(ii) = isfinite(Y0(ii));
        z_ok(ii) = isfinite(z1(t)) && isfinite(z2(t));
        ylags_ok(ii) = all(isfinite(ylag));
        gprlags_ok(ii) = all(isfinite(gprlag));
        if (nC_short > 0 && p_control > 0) || nC_full > 0
            controls_ok(ii) = all(isfinite(ctrl_block));
        end
    end

    good = sample_ok & y_ok & z_ok & dummy_ok & ylags_ok & gprlags_ok & controls_ok & all(isfinite(X0),2);
    Y = Y0(good);
    X = X0(good,:);

    dbg = struct();
    dbg.n_candidate = n;
    dbg.sample_ok = sum(sample_ok);
    dbg.y_ok = sum(y_ok);
    dbg.z_ok = sum(z_ok);
    dbg.dummy_ok = sum(dummy_ok);
    dbg.ylags_ok = sum(ylags_ok);
    dbg.gprlags_ok = sum(gprlags_ok);
    dbg.controls_ok = sum(controls_ok);
    dbg.final_good = sum(good);
    dbg.p_full = p;
    dbg.p_control = p_control;
    dbg.n_short_lag_controls = nC_short;
    dbg.n_full_lag_controls = nC_full;
end

function [Y, X, good, dbg] = build_lp_level_change_design(y, z, gpr_level, controls, dummy_controls, sample, p, h)
    y = y(:);
    z = z(:);
    gpr_level = gpr_level(:);
    T = length(y);

    if isempty(controls)
        controls = zeros(T,0);
    end
    if isempty(dummy_controls)
        dummy_controls = zeros(T,0);
    end
    nC = size(controls,2);
    nD = size(dummy_controls,2);

    t_grid = (p+1):(T-h);
    n = numel(t_grid);

    k = 1 + 1 + nD + p + p + p*nC;
    X0 = nan(n,k);
    Y0 = nan(n,1);

    sample_ok = false(n,1);
    y_ok = false(n,1);
    z_ok = false(n,1);
    dummy_ok = true(n,1);
    ylags_ok = false(n,1);
    gprlags_ok = false(n,1);
    controls_ok = true(n,1);

    for ii = 1:n
        t = t_grid(ii);
        c = 1;
        row = nan(1,k);

        Y0(ii) = y(t+h) - y(t-1);

        row(c) = 1; c = c + 1;
        row(c) = z(t); c = c + 1;

        if nD > 0
            valsD = dummy_controls(t,:);
            row(c:c+nD-1) = valsD;
            dummy_ok(ii) = all(isfinite(valsD));
            c = c + nD;
        end

        ylag = nan(1,p);
        for j = 1:p
            ylag(j) = y(t-j);
            row(c) = ylag(j); c = c + 1;
        end

        gprlag = nan(1,p);
        for j = 1:p
            gprlag(j) = gpr_level(t-j);
            row(c) = gprlag(j); c = c + 1;
        end

        ctrl_block = [];
        if nC > 0
            for j = 1:p
                valsC = controls(t-j,:);
                row(c:c+nC-1) = valsC;
                ctrl_block = [ctrl_block, valsC];
                c = c + nC;
            end
        end

        X0(ii,:) = row;

        sample_ok(ii) = sample(t) && sample(t+h) && all(sample(t-p:t));
        y_ok(ii) = isfinite(Y0(ii));
        z_ok(ii) = isfinite(z(t));
        ylags_ok(ii) = all(isfinite(ylag));
        gprlags_ok(ii) = all(isfinite(gprlag));
        if nC > 0
            controls_ok(ii) = all(isfinite(ctrl_block));
        end
    end

    good = sample_ok & y_ok & z_ok & dummy_ok & ylags_ok & gprlags_ok & controls_ok & all(isfinite(X0),2);
    Y = Y0(good);
    X = X0(good,:);

    dbg = struct();
    dbg.n_candidate = n;
    dbg.sample_ok = sum(sample_ok);
    dbg.y_ok = sum(y_ok);
    dbg.z_ok = sum(z_ok);
    dbg.dummy_ok = sum(dummy_ok);
    dbg.ylags_ok = sum(ylags_ok);
    dbg.gprlags_ok = sum(gprlags_ok);
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

function b = get_beta_at_h(res, hval)
    idx = find(res.h == hval, 1);
    if isempty(idx)
        b = NaN;
    else
        b = res.beta(idx);
    end
end

function fig = plot_irf_dashboard(res_list, titles, cfg, fig_title, nrow, ncol, show_figures)
    if show_figures
        fig = figure('Color','w','Position',[80,60,1500,850]);
    else
        fig = figure('Color','w','Position',[80,60,1500,850], 'Visible','off');
    end

    use_latex = isfield(cfg, 'use_latex_fonts') && cfg.use_latex_fonts;
    fs = 12;
    if isfield(cfg, 'figure_font_size'), fs = cfg.figure_font_size; end
    title_fs = 14;
    if isfield(cfg, 'figure_title_font_size'), title_fs = cfg.figure_title_font_size; end

    for i = 1:numel(res_list)
        ax = subplot(nrow, ncol, i, 'Parent', fig);
        hold(ax, 'on');

        if use_latex
            set(ax, 'TickLabelInterpreter','latex', 'FontSize', fs);
        else
            set(ax, 'FontSize', fs);
        end

        r = res_list{i};
        h = r.h(:)';

        finite_beta = isfinite(r.beta);
        finite_ci = isfinite(r.lb) & isfinite(r.ub);

        if sum(finite_beta) == 0
            if use_latex
                text(ax, 0.5, 0.5, latex_escape_text('All beta = NaN'), ...
                    'HorizontalAlignment','center', 'Units','normalized', ...
                    'FontWeight','bold', 'Interpreter','latex', 'FontSize', fs);
                title(ax, latex_escape_text(titles{i}), 'Interpreter','latex', 'FontSize', fs);
            else
                text(ax, 0.5, 0.5, 'All beta = NaN', 'HorizontalAlignment','center', ...
                    'Units','normalized', 'FontWeight','bold', 'FontSize', fs);
                title(ax, titles{i}, 'Interpreter','none', 'FontSize', fs);
            end
            axis(ax, 'off');
            continue;
        end

        ci_color = [0.45 0.45 0.45];
        if isfield(cfg, 'ci_band_color'), ci_color = cfg.ci_band_color; end

        ci_alpha = 0.75;
        if isfield(cfg, 'ci_band_alpha'), ci_alpha = cfg.ci_band_alpha; end

        irf_lw = 3.2;
        if isfield(cfg, 'irf_line_width'), irf_lw = cfg.irf_line_width; end

        zero_lw = 1.4;
        if isfield(cfg, 'zero_line_width'), zero_lw = cfg.zero_line_width; end

        axis_lw = 1.4;
        if isfield(cfg, 'figure_axis_line_width'), axis_lw = cfg.figure_axis_line_width; end

        if sum(finite_ci) >= 2
            hci = h(finite_ci);
            ub = r.ub(finite_ci)';
            lb = r.lb(finite_ci)';
            fill(ax, [hci, fliplr(hci)], [ub, fliplr(lb)], ci_color, ...
                'EdgeColor','none', ...
                'FaceAlpha', ci_alpha, ...
                'HandleVisibility','off');
        end

        plot(ax, h(finite_beta), r.beta(finite_beta), 'k-', ...
            'LineWidth', irf_lw);

        plot(ax, h, zeros(size(h)), 'k--', ...
            'LineWidth', zero_lw);

        grid(ax, 'on');
        box(ax, 'on');
        xlim(ax, [0 cfg.H]);

        if use_latex
            set(ax, ...
                'FontSize', fs, ...
                'FontWeight', 'bold', ...
                'LineWidth', axis_lw, ...
                'TickLabelInterpreter', 'latex');

            xlabel(ax, ['\textbf{' latex_escape_text(cfg.horizon_label) '}'], ...
                'Interpreter','latex', 'FontSize', fs, 'FontWeight','bold');

            ylabel(ax, '$\mathbf{y}_{t+h}-\mathbf{y}_{t-1}$', ...
                'Interpreter','latex', 'FontSize', fs, 'FontWeight','bold');

            title(ax, ['\textbf{' latex_escape_text(titles{i}) '}'], ...
                'Interpreter','latex', 'FontSize', fs, 'FontWeight','bold');
        else
            set(ax, ...
                'FontSize', fs, ...
                'FontWeight', 'bold', ...
                'LineWidth', axis_lw);

            xlabel(ax, cfg.horizon_label, ...
                'FontSize', fs, 'FontWeight','bold');

            ylabel(ax, 'Level change', ...
                'FontSize', fs, 'FontWeight','bold');

            title(ax, titles{i}, ...
                'Interpreter','none', 'FontSize', fs, 'FontWeight','bold');
        end
    end

    if use_latex
        sgtitle(fig, ['\textbf{' latex_escape_text(fig_title) '}'], ...
            'Interpreter','latex', ...
            'FontSize', title_fs, ...
            'FontWeight','bold');
    else
        sgtitle(fig, fig_title, ...
            'Interpreter','none', ...
            'FontSize', title_fs, ...
            'FontWeight','bold');
    end
    drawnow;
end

function fig = plot_combined_fig_12_14_16_dashboard(event_residual_struct, cfg, fig_title, nrow, ncol, show_figures)

    if show_figures
        fig = figure('Color','w','Position',[80,60,1550,900]);
    else
        fig = figure('Color','w','Position',[80,60,1550,900], 'Visible','off');
    end

    use_latex = isfield(cfg, 'use_latex_fonts') && cfg.use_latex_fonts;

    fs = 12;
    if isfield(cfg, 'figure_font_size'), fs = cfg.figure_font_size; end
    title_fs = 14;
    if isfield(cfg, 'figure_title_font_size'), title_fs = cfg.figure_title_font_size; end
    axis_lw = 1.4;
    if isfield(cfg, 'figure_axis_line_width'), axis_lw = cfg.figure_axis_line_width; end
    zero_lw = 1.4;
    if isfield(cfg, 'zero_line_width'), zero_lw = cfg.zero_line_width; end

    line_lw = 3.2;
    if isfield(cfg, 'combined_fig_12_14_16_line_width')
        line_lw = cfg.combined_fig_12_14_16_line_width;
    elseif isfield(cfg, 'irf_line_width')
        line_lw = cfg.irf_line_width;
    end

    ci_alpha = 0.30;
    if isfield(cfg, 'combined_fig_12_14_16_ci_alpha')
        ci_alpha = cfg.combined_fig_12_14_16_ci_alpha;
    end

    event_specs = cfg.combined_fig_12_14_16_events;

    for i = 1:size(cfg.outcome_specs,1)
        yid = cfg.outcome_specs{i,1};
        panel_title = cfg.outcome_specs{i,3};
        joint_field = [yid '_joint_gpr_event'];

        ax = subplot(nrow, ncol, i, 'Parent', fig);
        hold(ax, 'on');

        if use_latex
            set(ax, 'TickLabelInterpreter','latex', 'FontSize', fs);
        else
            set(ax, 'FontSize', fs);
        end

        any_plotted = false;

        for ee = 1:size(event_specs,1)
            did = event_specs{ee,1};
            legend_label = event_specs{ee,2};
            this_color = event_specs{ee,3};

            if ~isfield(event_residual_struct, did)
                warning('Combined Figure 12/14/16: missing event result %s. Skipping.', did);
                continue;
            end
            if ~isfield(event_residual_struct.(did), joint_field)
                warning('Combined Figure 12/14/16: missing joint field %s for %s. Skipping.', joint_field, did);
                continue;
            end

            joint = event_residual_struct.(did).(joint_field);
            r = extract_two_impulse_component(joint, 2);

            h = r.h(:)';
            finite_beta = isfinite(r.beta);
            finite_ci = isfinite(r.lb) & isfinite(r.ub);

            if sum(finite_ci) >= 2
                hci = h(finite_ci);
                ub = r.ub(finite_ci)';
                lb = r.lb(finite_ci)';
                fill(ax, [hci, fliplr(hci)], [ub, fliplr(lb)], this_color, ...
                    'EdgeColor','none', ...
                    'FaceAlpha', ci_alpha, ...
                    'HandleVisibility','off');
            end

            if sum(finite_beta) >= 1
                plot(ax, h(finite_beta), r.beta(finite_beta), '-', ...
                    'Color', this_color, ...
                    'LineWidth', line_lw, ...
                    'DisplayName', legend_label);
                any_plotted = true;
            end
        end

        plot(ax, 0:cfg.H, zeros(1, cfg.H+1), 'k--', ...
            'LineWidth', zero_lw, ...
            'HandleVisibility','off');

        grid(ax, 'on');
        box(ax, 'on');
        xlim(ax, [0 cfg.H]);

        if use_latex
            set(ax, ...
                'FontSize', fs, ...
                'FontWeight', 'bold', ...
                'LineWidth', axis_lw, ...
                'TickLabelInterpreter', 'latex');

            xlabel(ax, ['\textbf{' latex_escape_text(cfg.horizon_label) '}'], ...
                'Interpreter','latex', 'FontSize', fs, 'FontWeight','bold');

            ylabel(ax, '$\mathbf{y}_{t+h}-\mathbf{y}_{t-1}$', ...
                'Interpreter','latex', 'FontSize', fs, 'FontWeight','bold');

            title(ax, ['\textbf{' latex_escape_text(panel_title) '}'], ...
                'Interpreter','latex', 'FontSize', fs, 'FontWeight','bold');
        else
            set(ax, ...
                'FontSize', fs, ...
                'FontWeight', 'bold', ...
                'LineWidth', axis_lw);

            xlabel(ax, cfg.horizon_label, 'FontSize', fs, 'FontWeight','bold');
            ylabel(ax, 'Level change', 'FontSize', fs, 'FontWeight','bold');
            title(ax, panel_title, 'Interpreter','none', 'FontSize', fs, 'FontWeight','bold');
        end

        if any_plotted
            if use_latex
                lgd = legend(ax, 'show', 'Location','best', 'Interpreter','latex');
            else
                lgd = legend(ax, 'show', 'Location','best');
            end
            set(lgd, 'FontSize', max(fs-3, 8), 'Box','off');
        end
    end

    if use_latex
        sgtitle(fig, ['\textbf{' latex_escape_text(fig_title) '}'], ...
            'Interpreter','latex', 'FontSize', title_fs, 'FontWeight','bold');
    else
        sgtitle(fig, fig_title, 'Interpreter','none', 'FontSize', title_fs, 'FontWeight','bold');
    end

    drawnow;
end

function fig = plot_poisson_vs_raw_event_dashboard(event_residual_struct, event_count_joint_struct, did, cfg, fig_title, nrow, ncol, show_figures)

    if show_figures
        fig = figure('Color','w','Position',[80,60,1550,900]);
    else
        fig = figure('Color','w','Position',[80,60,1550,900], 'Visible','off');
    end

    use_latex = isfield(cfg, 'use_latex_fonts') && cfg.use_latex_fonts;

    fs = 12;
    if isfield(cfg, 'figure_font_size'), fs = cfg.figure_font_size; end
    title_fs = 14;
    if isfield(cfg, 'figure_title_font_size'), title_fs = cfg.figure_title_font_size; end
    axis_lw = 1.4;
    if isfield(cfg, 'figure_axis_line_width'), axis_lw = cfg.figure_axis_line_width; end
    zero_lw = 1.4;
    if isfield(cfg, 'zero_line_width'), zero_lw = cfg.zero_line_width; end

    line_lw = 3.2;
    if isfield(cfg, 'poisson_vs_raw_line_width'), line_lw = cfg.poisson_vs_raw_line_width; end

    raw_color = [0.05 0.25 0.90];
    if isfield(cfg, 'poisson_vs_raw_raw_color'), raw_color = cfg.poisson_vs_raw_raw_color; end

    poisson_color = [0.85 0.10 0.10];
    if isfield(cfg, 'poisson_vs_raw_poisson_color'), poisson_color = cfg.poisson_vs_raw_poisson_color; end

    ci_alpha = 0.22;
    if isfield(cfg, 'poisson_vs_raw_ci_alpha'), ci_alpha = cfg.poisson_vs_raw_ci_alpha; end

    raw_style = '-';
    if isfield(cfg, 'poisson_vs_raw_raw_line_style'), raw_style = cfg.poisson_vs_raw_raw_line_style; end
    poisson_style = '--';
    if isfield(cfg, 'poisson_vs_raw_poisson_line_style'), poisson_style = cfg.poisson_vs_raw_poisson_line_style; end

    for i = 1:size(cfg.outcome_specs,1)
        ax = subplot(nrow, ncol, i, 'Parent', fig);
        hold(ax, 'on');

        if use_latex
            set(ax, 'TickLabelInterpreter','latex', 'FontSize', fs);
        else
            set(ax, 'FontSize', fs);
        end

        yid = cfg.outcome_specs{i,1};
        outcome_label = cfg.outcome_specs{i,3};

        raw_field = [yid '_joint_gpr_count'];
        poisson_field = [yid '_joint_gpr_event'];

        has_raw = isfield(event_count_joint_struct, did) && isfield(event_count_joint_struct.(did), raw_field);
        has_poisson = isfield(event_residual_struct, did) && isfield(event_residual_struct.(did), poisson_field);

        h_raw_line = gobjects(1);
        h_poisson_line = gobjects(1);

        if has_raw
            raw_comp = extract_two_impulse_component(event_count_joint_struct.(did).(raw_field), 2);
            h_raw_line = plot_irf_with_band(ax, raw_comp, raw_color, ci_alpha, raw_style, line_lw, ...
                'Raw event count $N_t^k$');
        end

        if has_poisson
            poisson_comp = extract_two_impulse_component(event_residual_struct.(did).(poisson_field), 2);
            h_poisson_line = plot_irf_with_band(ax, poisson_comp, poisson_color, ci_alpha, poisson_style, line_lw, ...
                'Poisson arrival shock $z_t^{N,k}$');
        end

        if ~has_raw && ~has_poisson
            if use_latex
                text(ax, 0.5, 0.5, latex_escape_text('Missing raw and Poisson results'), ...
                    'HorizontalAlignment','center', 'Units','normalized', ...
                    'FontWeight','bold', 'Interpreter','latex', 'FontSize', fs);
                title(ax, latex_escape_text(outcome_label), 'Interpreter','latex', 'FontSize', fs);
            else
                text(ax, 0.5, 0.5, 'Missing raw and Poisson results', ...
                    'HorizontalAlignment','center', 'Units','normalized', ...
                    'FontWeight','bold', 'FontSize', fs);
                title(ax, outcome_label, 'Interpreter','none', 'FontSize', fs);
            end
            axis(ax, 'off');
            continue;
        end

        hgrid = 0:cfg.H;
        plot(ax, hgrid, zeros(size(hgrid)), 'k--', 'LineWidth', zero_lw, 'HandleVisibility','off');

        grid(ax, 'on');
        box(ax, 'on');
        xlim(ax, [0 cfg.H]);

        if use_latex
            set(ax, ...
                'FontSize', fs, ...
                'FontWeight', 'bold', ...
                'LineWidth', axis_lw, ...
                'TickLabelInterpreter', 'latex');

            xlabel(ax, ['\textbf{' latex_escape_text(cfg.horizon_label) '}'], ...
                'Interpreter','latex', 'FontSize', fs, 'FontWeight','bold');

            ylabel(ax, '$\mathbf{y}_{t+h}-\mathbf{y}_{t-1}$', ...
                'Interpreter','latex', 'FontSize', fs, 'FontWeight','bold');

            title(ax, ['\textbf{' latex_escape_text(outcome_label) '}'], ...
                'Interpreter','latex', 'FontSize', fs, 'FontWeight','bold');
        else
            set(ax, ...
                'FontSize', fs, ...
                'FontWeight', 'bold', ...
                'LineWidth', axis_lw);

            xlabel(ax, cfg.horizon_label, ...
                'FontSize', fs, 'FontWeight','bold');

            ylabel(ax, 'Level change', ...
                'FontSize', fs, 'FontWeight','bold');

            title(ax, outcome_label, ...
                'Interpreter','none', 'FontSize', fs, 'FontWeight','bold');
        end

        if i == 1
            handles = gobjects(0);
            labels = {};
            if has_raw && isgraphics(h_raw_line)
                handles(end+1) = h_raw_line;
                labels{end+1} = 'Raw event count $N_t^k$';
            end
            if has_poisson && isgraphics(h_poisson_line)
                handles(end+1) = h_poisson_line;
                labels{end+1} = 'Poisson shock $z_t^{N,k}$';
            end
            if ~isempty(handles)
                if use_latex
                    legend(ax, handles, labels, 'Interpreter','latex', 'Location','best', ...
                        'FontSize', max(10, fs-2), 'Box','off');
                else
                    legend(ax, handles, strrep(labels, '$',''), 'Interpreter','none', ...
                        'Location','best', 'FontSize', max(10, fs-2), 'Box','off');
                end
            end
        end
    end

    if use_latex
        sgtitle(fig, fig_title, ...
            'Interpreter','latex', ...
            'FontSize', title_fs, ...
            'FontWeight','bold');
    else
        sgtitle(fig, regexprep(fig_title, '\$|\{|\}|\^|_', ''), ...
            'Interpreter','none', ...
            'FontSize', title_fs, ...
            'FontWeight','bold');
    end

    drawnow;
end

function h_line = plot_irf_with_band(ax, r, color, ci_alpha, line_style, line_lw, display_name)
    h = r.h(:)';
    finite_beta = isfinite(r.beta);
    finite_ci = isfinite(r.lb) & isfinite(r.ub);

    if sum(finite_ci) >= 2
        hci = h(finite_ci);
        ub = r.ub(finite_ci)';
        lb = r.lb(finite_ci)';
        fill(ax, [hci, fliplr(hci)], [ub, fliplr(lb)], color, ...
            'EdgeColor','none', ...
            'FaceAlpha', ci_alpha, ...
            'HandleVisibility','off');
    end

    if sum(finite_beta) > 0
        h_line = plot(ax, h(finite_beta), r.beta(finite_beta), ...
            'LineStyle', line_style, ...
            'Color', color, ...
            'LineWidth', line_lw, ...
            'DisplayName', display_name);
    else
        h_line = gobjects(1);
    end
end

function apply_latex_graphics_defaults(cfg)
    if isfield(cfg, 'use_latex_fonts') && cfg.use_latex_fonts
        set(groot, 'defaultTextInterpreter','latex');
        set(groot, 'defaultAxesTickLabelInterpreter','latex');
        set(groot, 'defaultLegendInterpreter','latex');
    end

    if isfield(cfg, 'figure_font_size')
        set(groot, 'defaultAxesFontSize', cfg.figure_font_size);
        set(groot, 'defaultTextFontSize', cfg.figure_font_size);
    end
    set(groot, 'defaultAxesFontWeight','bold');
    set(groot, 'defaultTextFontWeight','bold');
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
    if ~cfg.save_figures
        return;
    end
    if isempty(fig) || ~isgraphics(fig, 'figure')
        warning('Invalid figure handle. Skipping save: %s', base_path);
        return;
    end

    drawnow;
    try
        savefig(fig, [base_path '.fig']);
    catch ME
        warning('Could not save .fig file. Reason: %s', ME.message);
    end

    try
        exportgraphics(fig, [base_path '.png'], 'Resolution', 300);
    catch
        try
            print(fig, [base_path '.png'], '-dpng', '-r300');
        catch ME2
            warning('Could not save png. Reason: %s', ME2.message);
        end
    end
end

function s = clean_file_string(s)
    s = char(s);
    s = regexprep(s, '[^A-Za-z0-9_\-]+', '_');
    s = regexprep(s, '_+', '_');
end
