%% DOWNLOAD_DATA  Download raw data for H1 analysis.
%
%  Downloads FRED series and the Caldara-Iacoviello GPR index
%  into data/raw/. Run this once before running run_all.m.
%
%  Usage (in MATLAB):
%    >> run('Feedback_Pf.Baek/H1/scripts/download_data.m')
%
%  Output:
%    data/raw/industrial_production__INDPRO.csv
%    data/raw/cpi_all_urban__CPIAUCSL.csv
%    data/raw/unemployment_rate__UNRATE.csv
%    data/raw/vix_daily__VIXCLS.csv
%    data/raw/fed_funds_rate__FEDFUNDS.csv
%    data/raw/oil_wti__DCOILWTICO.csv
%    data/raw/gpr_caldara_iacoviello.xls
% -----------------------------------------------------------------------

if ~exist('H1_ROOT','var'), clear; clc; end

%% === Paths ===
proj_root = fileparts(fileparts(mfilename('fullpath')));
raw_dir   = fullfile(proj_root, 'data', 'raw');
if ~exist(raw_dir, 'dir'), mkdir(raw_dir); end

fprintf('=== H1 Data Download ===\n');
fprintf('Save to: %s\n\n', raw_dir);

%% === FRED series ===
fred = {
    'INDPRO',     'industrial_production'
    'CPIAUCSL',   'cpi_all_urban'
    'UNRATE',     'unemployment_rate'
    'VIXCLS',     'vix_daily'
    'FEDFUNDS',   'fed_funds_rate'
    'DCOILWTICO', 'oil_wti'
};

fprintf('--- FRED series (CSV) ---\n');
for i = 1:size(fred, 1)
    code  = fred{i, 1};
    label = fred{i, 2};
    fname = sprintf('%s__%s.csv', label, code);
    fpath = fullfile(raw_dir, fname);
    url   = sprintf('https://fred.stlouisfed.org/graph/fredgraph.csv?id=%s', code);

    try
        websave(fpath, url);
        fprintf('  ok   %s -> %s\n', code, fname);
    catch ME
        fprintf('  FAIL %s: %s\n', code, ME.message);
    end
end

%% === Caldara & Iacoviello GPR ===
fprintf('\n--- Caldara & Iacoviello GPR (xls) ---\n');
gpr_url  = 'https://www.matteoiacoviello.com/gpr_files/data_gpr_export.xls';
gpr_path = fullfile(raw_dir, 'gpr_caldara_iacoviello.xls');

try
    websave(gpr_path, gpr_url);
    fprintf('  ok   GPR/GPT/GPA\n');
catch ME
    fprintf('  FAIL GPR: %s\n', ME.message);
    fprintf('  -> Download manually from: https://www.matteoiacoviello.com/gpr.htm\n');
end

%% === Verify ===
fprintf('\n--- Verification ---\n');
files = dir(fullfile(raw_dir, '*'));
files = files(~[files.isdir]);
fprintf('  %d files in data/raw/\n', length(files));
for i = 1:length(files)
    fprintf('    %s (%.0f KB)\n', files(i).name, files(i).bytes/1024);
end

fprintf('\n=== Download complete ===\n');
fprintf('Next: run(''Feedback_Pf.Baek/H1/run_all.m'')\n');
