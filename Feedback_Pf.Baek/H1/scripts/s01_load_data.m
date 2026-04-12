%% S01_LOAD_DATA  Load and merge H1 baseline + robustness data.
%
%  Loads raw data downloaded by download_data.sh, aligns to monthly
%  frequency, and saves a master dataset.
%
%  Required raw files (in ../data/raw/):
%    - gpr_caldara_iacoviello.xls        GPR, GPT, GPA indices
%    - industrial_production__INDPRO.csv
%    - cpi_all_urban__CPIAUCSL.csv
%    - unemployment_rate__UNRATE.csv      (robustness control)
%    - vix_daily__VIXCLS.csv             (robustness control)
%    - fed_funds_rate__FEDFUNDS.csv      (Stage 4+)
%    - oil_wti__DCOILWTICO.csv           (Stage 4+)
%
%  Output:
%    ../data/h1_baseline.mat
%
%  Usage:  >> run('scripts/s01_load_data.m')
% -----------------------------------------------------------------------

if ~exist('H1_ROOT','var'), clear; clc; end

%% === Paths ===
proj_root  = fileparts(fileparts(mfilename('fullpath')));
raw_dir    = fullfile(proj_root, 'data', 'raw');
out_dir    = fullfile(proj_root, 'data');

fprintf('Project root: %s\n', proj_root);
fprintf('Raw data dir: %s\n', raw_dir);

%% === 1. Load GPR data (Caldara & Iacoviello) ===
fprintf('\n--- Loading GPR data ---\n');
gpr_file = fullfile(raw_dir, 'gpr_caldara_iacoviello.xls');
gpr_raw  = readtable(gpr_file);

fprintf('GPR file columns: ');
fprintf('%s  ', gpr_raw.Properties.VariableNames{:});
fprintf('\n');

% Auto-detect date columns
col_names = lower(gpr_raw.Properties.VariableNames);
month_col = find(contains(col_names, 'month'), 1);
year_col  = find(contains(col_names, 'year'), 1);

if ~isempty(month_col) && ~isempty(year_col)
    % Separate year and month columns
    gpr_dates = datetime(gpr_raw{:, year_col}, gpr_raw{:, month_col}, ...
                         ones(height(gpr_raw), 1));
    fprintf('Date constructed from year + month columns.\n');
elseif ~isempty(month_col)
    % Single "month" column — could be "1985m01" format or datetime
    raw_month = gpr_raw{:, month_col};
    if iscell(raw_month) || isstring(raw_month)
        % Parse "1985m01" or "1985M01" format
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
        fprintf('Date from datetime "month" column.\n');
    elseif isnumeric(raw_month)
        % Numeric serial date or Excel date number
        gpr_dates = datetime(raw_month, 'ConvertFrom', 'datenum');
        fprintf('Date converted from numeric "month" column.\n');
    else
        error('Cannot parse "month" column (class: %s).', class(raw_month));
    end
else
    date_col = find(contains(col_names, 'date'), 1);
    if ~isempty(date_col)
        gpr_dates = datetime(gpr_raw{:, date_col});
        fprintf('Date from date column.\n');
    else
        error('Cannot detect date columns in GPR file. Check column names above.');
    end
end

% Auto-detect GPR, GPT, GPA columns
% Actual file uses: GPR, GPRT (threats), GPRA (acts)
gpr_col = find(strcmpi(col_names, 'gpr'), 1);
if isempty(gpr_col)
    gpr_col = find(contains(col_names, 'gpr') & ~contains(col_names, 'gprt') & ...
                   ~contains(col_names, 'gpra') & ~contains(col_names, 'gprh') & ...
                   ~contains(col_names, 'gprc') & ~contains(col_names, 'gpr_'), 1);
end
gpt_col = find(strcmpi(col_names, 'gprt'), 1);
if isempty(gpt_col)
    gpt_col = find(contains(col_names, 'threat') | strcmpi(col_names, 'gpt'), 1);
end
gpa_col = find(strcmpi(col_names, 'gpra'), 1);
if isempty(gpa_col)
    gpa_col = find(contains(col_names, 'act') | strcmpi(col_names, 'gpa'), 1);
end

if isempty(gpr_col) || isempty(gpt_col) || isempty(gpa_col)
    fprintf('\nWARNING: Could not auto-detect all GPR columns.\n');
    fprintf('Available columns:\n');
    for i = 1:length(col_names)
        fprintf('  [%d] %s\n', i, gpr_raw.Properties.VariableNames{i});
    end
    error('Please set gpr_col, gpt_col, gpa_col manually and rerun.');
end

GPR = gpr_raw{:, gpr_col};
GPT = gpr_raw{:, gpt_col};
GPA = gpr_raw{:, gpa_col};
fprintf('GPR: %s | GPT: %s | GPA: %s\n', ...
        gpr_raw.Properties.VariableNames{gpr_col}, ...
        gpr_raw.Properties.VariableNames{gpt_col}, ...
        gpr_raw.Properties.VariableNames{gpa_col});

gpr_tbl = table(gpr_dates, GPR, GPT, GPA, 'VariableNames', {'date','GPR','GPT','GPA'});

%% === 2. Load FRED series ===
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

    raw = readtable(fname, 'TextType', 'string');
    fprintf('  %s: %d rows, columns: %s\n', label, height(raw), ...
            strjoin(raw.Properties.VariableNames, ', '));

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

%% === 3. Aggregate daily series to monthly ===
fprintf('\n--- Aggregating daily series to monthly ---\n');

for i = 1:length(fred_tables)
    tbl = fred_tables{i};
    label = tbl.Properties.VariableNames{2};

    yrs = year(tbl.date);
    obs_per_yr = height(tbl) / (max(yrs) - min(yrs) + 1);

    if obs_per_yr > 100  % daily data
        fprintf('  %s: daily (%.0f obs/yr) -> monthly mean.\n', label, obs_per_yr);
        ym = dateshift(tbl.date, 'start', 'month');
        [groups, month_starts] = findgroups(ym);
        monthly_vals = splitapply(@nanmean, tbl{:, 2}, groups);
        fred_tables{i} = table(month_starts, monthly_vals, ...
                                'VariableNames', {'date', label});
        fprintf('    -> %d monthly observations\n', height(fred_tables{i}));
    else
        fprintf('  %s: already monthly (%.0f obs/yr).\n', label, obs_per_yr);
    end
end

%% === 4. Merge into master monthly panel ===
fprintf('\n--- Merging into master panel ---\n');

master = gpr_tbl;
for i = 1:length(fred_tables)
    master = innerjoin(master, fred_tables{i}, 'Keys', 'date');
end

fprintf('Master panel: %d months, %d variables\n', height(master), width(master));
fprintf('Date range: %s to %s\n', datestr(min(master.date)), datestr(max(master.date)));

%% === 5. Trim to sample period ===
sample_start = datetime(1985, 1, 1);
sample_end   = datetime(2025, 12, 1);

mask = master.date >= sample_start & master.date <= sample_end;
master = master(mask, :);

fprintf('\nAfter trimming to %s - %s:\n', datestr(sample_start), datestr(sample_end));
fprintf('  %d months, %d variables\n', height(master), width(master));

%% === 6. Construct log transformations ===
master.log_IP  = log(master.INDPRO);
master.log_CPI = log(master.CPI);
master.log_WTI = log(master.WTI);
master.log_GPR = log(master.GPR);
master.log_GPT = log(master.GPT);
master.log_GPA = log(master.GPA);
master.log_VIX = log(master.VIX);

fprintf('\nLog transformations added.\n');

%% === 7. Report missing values ===
fprintf('\n--- Missing value check ---\n');
var_names = master.Properties.VariableNames;
for v = 2:length(var_names)
    n_miss = sum(isnan(master{:, v}));
    if n_miss > 0
        fprintf('  WARNING: %s has %d missing values (%.1f%%)\n', ...
                var_names{v}, n_miss, 100*n_miss/height(master));
    end
end
fprintf('  Total observations: %d months\n', height(master));

%% === 8. Save ===
save_path = fullfile(out_dir, 'h1_baseline.mat');
save(save_path, 'master');

fprintf('\nSaved: %s\n', save_path);
fprintf('=== s01_load_data complete ===\n');
