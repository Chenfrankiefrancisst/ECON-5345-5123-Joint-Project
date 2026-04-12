%% RUN_ALL  H1 full pipeline — download, load, explore, estimate.
%
%  H1: GPR as a Cost-Push Shock
%  Everything runs from this single file. No prerequisites.
%
%  Usage:  >> run('Feedback_Pf.Baek/H1/run_all.m')
%          or open this file and press F5.
%
%  Data sources:
%    FRED (https://fred.stlouisfed.org)  — INDPRO, CPIAUCSL, UNRATE,
%                                           VIXCLS, FEDFUNDS, DCOILWTICO
%    Caldara & Iacoviello GPR index      — matteoiacoviello.com/gpr.htm
%
%  Output:
%    data/h1_baseline.mat          — merged monthly dataset
%    output/fig_*.png              — exploratory figures (5)
%    output/fig_h1_*.png           — LP IRF figures (5)
%    output/h1_results.mat         — all LP results
% -----------------------------------------------------------------------

clear; clc; close all;

H1_ROOT = 'D:\OneDrive\SKKU PhD\2026 Spring - 거시실증분석\Team Project (with HKUST)\repo\Feedback_Pf.Baek\H1';
cd(H1_ROOT);
addpath(fullfile(H1_ROOT, 'code'));

raw_dir = fullfile(H1_ROOT, 'data', 'raw');
data_dir = fullfile(H1_ROOT, 'data');
out_dir  = fullfile(H1_ROOT, 'output');
if ~exist(raw_dir, 'dir'), mkdir(raw_dir); end
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

fprintf('========================================\n');
fprintf('  H1 Pipeline: GPR as Cost-Push Shock\n');
fprintf('  Root: %s\n', H1_ROOT);
fprintf('========================================\n');

%% ====================================================================
%  STEP 0: DOWNLOAD RAW DATA
%  ====================================================================
%  Downloads from FRED and Caldara-Iacoviello website.
%  Skips files that already exist.

fprintf('\n============================================================\n');
fprintf('  STEP 0: DOWNLOAD RAW DATA\n');
fprintf('============================================================\n');

% --- FRED series ---
%  Source: https://fred.stlouisfed.org/graph/fredgraph.csv?id=SERIES
%  Each URL returns a 2-column CSV: observation_date, value
fred = {
    'INDPRO',     'industrial_production'   % Industrial Production Index
    'CPIAUCSL',   'cpi_all_urban'           % CPI All Urban Consumers
    'UNRATE',     'unemployment_rate'       % Unemployment Rate (robustness)
    'VIXCLS',     'vix_daily'              % VIX (robustness, daily->monthly)
    'FEDFUNDS',   'fed_funds_rate'         % Fed Funds Rate (Stage 4+)
    'DCOILWTICO', 'oil_wti'               % WTI Oil Price (Stage 4+)
};

for i = 1:size(fred, 1)
    code  = fred{i, 1};
    label = fred{i, 2};
    fname = sprintf('%s__%s.csv', label, code);
    fpath = fullfile(raw_dir, fname);

    if exist(fpath, 'file')
        fprintf('  skip  %s (already exists)\n', code);
        continue;
    end

    url = sprintf('https://fred.stlouisfed.org/graph/fredgraph.csv?id=%s', code);
    fprintf('  downloading %s from FRED ... ', code);

    % Try curl first (works on Windows 10+), fall back to websave
    curl_cmd = sprintf('curl -sSL --fail --retry 3 -o "%s" "%s"', fpath, url);
    [status, ~] = system(curl_cmd);
    if status == 0 && exist(fpath, 'file')
        fprintf('ok -> %s\n', fname);
    else
        % Fallback: websave
        try
            websave(fpath, url, weboptions('Timeout', 60));
            fprintf('ok (websave) -> %s\n', fname);
        catch ME
            fprintf('FAIL: %s\n', ME.message);
            fprintf('    Manual: go to https://fred.stlouisfed.org/series/%s\n', code);
            fprintf('    Click "Download" -> CSV, save as %s\n', fname);
        end
    end
end

% --- Caldara & Iacoviello GPR ---
%  Source: https://www.matteoiacoviello.com/gpr_files/data_gpr_export.xls
%  Contains monthly columns: month, GPR, GPRT (threats), GPRA (acts), ...
gpr_path = fullfile(raw_dir, 'gpr_caldara_iacoviello.xls');
if exist(gpr_path, 'file')
    fprintf('  skip  GPR (already exists)\n');
else
    fprintf('  downloading GPR index ... ');
    gpr_url = 'https://www.matteoiacoviello.com/gpr_files/data_gpr_export.xls';
    curl_cmd = sprintf('curl -sSL --fail --retry 3 -o "%s" "%s"', gpr_path, gpr_url);
    [status, ~] = system(curl_cmd);
    if status == 0 && exist(gpr_path, 'file')
        fprintf('ok\n');
    else
        try
            websave(gpr_path, gpr_url, weboptions('Timeout', 60));
            fprintf('ok (websave)\n');
        catch ME
            fprintf('FAIL: %s\n', ME.message);
            fprintf('    Manual: go to https://www.matteoiacoviello.com/gpr.htm\n');
            fprintf('    Download the XLS file, save as gpr_caldara_iacoviello.xls\n');
        end
    end
end

% --- Verify all required files ---
required = {'gpr_caldara_iacoviello.xls', ...
            'industrial_production__INDPRO.csv', ...
            'cpi_all_urban__CPIAUCSL.csv', ...
            'unemployment_rate__UNRATE.csv', ...
            'vix_daily__VIXCLS.csv'};
missing = {};
for k = 1:length(required)
    if ~exist(fullfile(raw_dir, required{k}), 'file')
        missing{end+1} = required{k}; %#ok<SAGROW>
    end
end
if ~isempty(missing)
    fprintf('\n  ERROR: Missing files:\n');
    for k = 1:length(missing)
        fprintf('    - %s\n', missing{k});
    end
    error('Download failed. Please download manually and place in:\n  %s', raw_dir);
end
fprintf('\n  All required files present.\n');

%% ====================================================================
%  STEP 1: LOAD AND MERGE DATA
%  ====================================================================
%  Reads raw CSV/XLS, aggregates daily->monthly, merges into one table,
%  trims to sample period, adds log transformations.
%  Saves: data/h1_baseline.mat

fprintf('\n============================================================\n');
fprintf('  STEP 1: LOAD AND MERGE DATA\n');
fprintf('============================================================\n');

% --- 1a. Load GPR data ---
fprintf('\n--- Loading GPR data ---\n');
gpr_raw = readtable(gpr_path);
fprintf('GPR file: %d rows, %d columns\n', height(gpr_raw), width(gpr_raw));

% Parse date from "month" column (format: "1985m01" or similar)
col_names = lower(gpr_raw.Properties.VariableNames);
month_col = find(contains(col_names, 'month'), 1);

raw_month = gpr_raw{:, month_col};
if iscell(raw_month) || isstring(raw_month)
    raw_str = string(raw_month);
    tokens = regexp(raw_str, '(\d{4})[mM](\d{1,2})', 'tokens');
    yr = nan(height(gpr_raw), 1);
    mo = nan(height(gpr_raw), 1);
    for k = 1:length(tokens)
        if ~isempty(tokens{k})
            yr(k) = str2double(tokens{k}{1}{1});
            mo(k) = str2double(tokens{k}{1}{2});
        end
    end
    gpr_dates = datetime(yr, mo, ones(length(yr), 1));
    fprintf('Date parsed from "month" column (YYYYmMM format).\n');
elseif isdatetime(raw_month)
    gpr_dates = raw_month;
elseif isnumeric(raw_month)
    gpr_dates = datetime(raw_month, 'ConvertFrom', 'datenum');
else
    error('Cannot parse GPR date column (class: %s).', class(raw_month));
end

% Find GPR, GPRT (threats), GPRA (acts) columns
gpr_col = find(strcmpi(col_names, 'gpr'), 1);
gpt_col = find(strcmpi(col_names, 'gprt'), 1);
if isempty(gpt_col), gpt_col = find(strcmpi(col_names, 'gpt'), 1); end
gpa_col = find(strcmpi(col_names, 'gpra'), 1);
if isempty(gpa_col), gpa_col = find(strcmpi(col_names, 'gpa'), 1); end

if isempty(gpr_col) || isempty(gpt_col) || isempty(gpa_col)
    fprintf('Available columns:\n');
    for i = 1:length(col_names)
        fprintf('  [%d] %s\n', i, gpr_raw.Properties.VariableNames{i});
    end
    error('Cannot auto-detect GPR/GPT/GPA columns. Check names above.');
end

GPR = gpr_raw{:, gpr_col};
GPT = gpr_raw{:, gpt_col};
GPA = gpr_raw{:, gpa_col};
fprintf('Using: GPR=%s, GPT=%s, GPA=%s\n', ...
    gpr_raw.Properties.VariableNames{gpr_col}, ...
    gpr_raw.Properties.VariableNames{gpt_col}, ...
    gpr_raw.Properties.VariableNames{gpa_col});

gpr_tbl = table(gpr_dates, GPR, GPT, GPA, 'VariableNames', {'date','GPR','GPT','GPA'});

% --- 1b. Load FRED series ---
fprintf('\n--- Loading FRED series ---\n');

fred_series = {
    'industrial_production__INDPRO.csv',   'INDPRO'
    'cpi_all_urban__CPIAUCSL.csv',         'CPI'
    'unemployment_rate__UNRATE.csv',       'UNRATE'
    'vix_daily__VIXCLS.csv',              'VIX'
    'fed_funds_rate__FEDFUNDS.csv',        'FFR'
    'oil_wti__DCOILWTICO.csv',             'WTI'
};

fred_tables = {};
for i = 1:size(fred_series, 1)
    fname = fullfile(raw_dir, fred_series{i, 1});
    label = fred_series{i, 2};

    if ~exist(fname, 'file')
        fprintf('  %s: FILE NOT FOUND, skipping\n', label);
        fred_tables{i} = table(); %#ok<SAGROW>
        continue;
    end

    raw = readtable(fname, 'TextType', 'string');
    fprintf('  %s: %d rows\n', label, height(raw));

    dates_i = datetime(raw{:, 1}, 'InputFormat', 'yyyy-MM-dd');

    vals_raw = raw{:, 2};
    if isstring(vals_raw) || iscellstr(vals_raw)
        vals_raw = strrep(string(vals_raw), '.', 'NaN');
        vals_i = double(vals_raw);
    else
        vals_i = double(vals_raw);
    end

    fred_tables{i} = table(dates_i, vals_i, 'VariableNames', {'date', label}); %#ok<SAGROW>
end

% --- 1c. Aggregate daily series to monthly ---
fprintf('\n--- Aggregating daily series to monthly ---\n');

for i = 1:length(fred_tables)
    tbl = fred_tables{i};
    if isempty(tbl), continue; end
    label = tbl.Properties.VariableNames{2};

    yrs = year(tbl.date);
    obs_per_yr = height(tbl) / (max(yrs) - min(yrs) + 1);

    if obs_per_yr > 100  % daily data
        fprintf('  %s: daily (%.0f obs/yr) -> monthly mean\n', label, obs_per_yr);
        ym = dateshift(tbl.date, 'start', 'month');
        [groups, month_starts] = findgroups(ym);
        monthly_vals = splitapply(@nanmean, tbl{:, 2}, groups);
        fred_tables{i} = table(month_starts, monthly_vals, ...
                                'VariableNames', {'date', label});
    else
        fprintf('  %s: already monthly\n', label);
    end
end

% --- 1d. Merge into master table ---
fprintf('\n--- Merging ---\n');
master = gpr_tbl;
for i = 1:length(fred_tables)
    if ~isempty(fred_tables{i})
        master = innerjoin(master, fred_tables{i}, 'Keys', 'date');
    end
end
fprintf('Merged: %d months, %d variables\n', height(master), width(master));

% --- 1e. Trim to sample ---
sample_start = datetime(1985, 1, 1);
sample_end   = datetime(2025, 12, 1);
mask = master.date >= sample_start & master.date <= sample_end;
master = master(mask, :);
fprintf('Sample: %s to %s (%d months)\n', ...
    datestr(master.date(1)), datestr(master.date(end)), height(master));

% --- 1f. Log transformations ---
master.log_IP  = log(master.INDPRO);
master.log_CPI = log(master.CPI);
master.log_WTI = log(master.WTI);
master.log_GPR = log(master.GPR);
master.log_GPT = log(master.GPT);
master.log_GPA = log(master.GPA);
master.log_VIX = log(master.VIX);
fprintf('Log transformations added.\n');

% --- 1g. Missing value check ---
fprintf('\n--- Missing values ---\n');
var_names = master.Properties.VariableNames;
for v = 2:length(var_names)
    n_miss = sum(isnan(master{:, v}));
    if n_miss > 0
        fprintf('  WARNING: %s has %d missing (%.1f%%)\n', ...
            var_names{v}, n_miss, 100*n_miss/height(master));
    end
end

% --- 1h. Save ---
save(fullfile(data_dir, 'h1_baseline.mat'), 'master');
fprintf('Saved: data/h1_baseline.mat\n');

%% ====================================================================
%  STEP 2: EXPLORATORY DATA ANALYSIS
%  ====================================================================
fprintf('\n============================================================\n');
fprintf('  STEP 2: EXPLORATORY DATA ANALYSIS\n');
fprintf('============================================================\n');

cd(H1_ROOT);
run(fullfile(H1_ROOT, 'scripts', 's02_explore_data.m'));

%% ====================================================================
%  STEP 3: H1 LP ESTIMATION + ROBUSTNESS
%  ====================================================================
fprintf('\n============================================================\n');
fprintf('  STEP 3: H1 LP ESTIMATION\n');
fprintf('============================================================\n');

cd(H1_ROOT);
run(fullfile(H1_ROOT, 'scripts', 's03_run_h1.m'));

%% === Summary ===
fprintf('\n========================================\n');
fprintf('  H1 Pipeline Complete!\n');
fprintf('========================================\n');
fprintf('  Data:    %s\n', fullfile(H1_ROOT, 'data'));
fprintf('  Figures: %s\n', fullfile(H1_ROOT, 'output'));
fprintf('  Results: %s\n', fullfile(H1_ROOT, 'output', 'h1_results.mat'));
fprintf('\n  Next: inspect IRF figures and check H1 success criteria.\n');
fprintf('  H1 supported if CPI(+) and IP(-) significant at h=6-24.\n');
