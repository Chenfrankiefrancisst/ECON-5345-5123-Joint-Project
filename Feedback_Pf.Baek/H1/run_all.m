%% RUN_ALL  Execute the full H1 analysis pipeline in one go.
%
%  H1: GPR as a Cost-Push Shock
%  Pipeline: download -> s01 (load) -> s02 (explore) -> s03 (LP)
%
%  Usage (in MATLAB):
%    >> run('Feedback_Pf.Baek/H1/run_all.m')
%    or open this file and press F5.
%
%  This script automatically downloads raw data if not already present,
%  then runs the full pipeline (s01 -> s02 -> s03).
%
%  Output:
%    data/h1_baseline.mat          — merged monthly dataset
%    output/fig_gpr_indices.png    — GPR/GPT/GPA time series
%    output/fig_macro_variables.png
%    output/fig_log_variables.png
%    output/fig_correlation_matrix.png
%    output/fig_gpr_acf.png
%    output/fig_h1_baseline.png    — baseline LP IRFs (6 panels)
%    output/fig_h1_robust1_unrate.png
%    output/fig_h1_robust2_unrate_vix.png
%    output/fig_h1_comparison.png  — overlay of all 3 specs
%    output/fig_h1_lag_selection.png
%    output/h1_results.mat         — all LP results
% -----------------------------------------------------------------------

clear; clc; close all;

%% === Setup ===
h1_root = fileparts(mfilename('fullpath'));
addpath(fullfile(h1_root, 'code'));

fprintf('========================================\n');
fprintf('  H1 Pipeline: GPR as Cost-Push Shock\n');
fprintf('  Root: %s\n', h1_root);
fprintf('========================================\n');

%% === Step 0: Download raw data if missing ===
raw_dir = fullfile(h1_root, 'data', 'raw');
if ~exist(fullfile(raw_dir, 'gpr_caldara_iacoviello.xls'), 'file')
    fprintf('\n>>> Step 0: Raw data not found. Downloading ...\n\n');
    run(fullfile(h1_root, 'scripts', 'download_data.m'));
end

%% === Step 1: Load and merge data ===
fprintf('\n>>> Step 1/3: Loading data (s01_load_data) ...\n\n');
run(fullfile(h1_root, 'scripts', 's01_load_data.m'));

%% === Step 2: Exploratory data analysis ===
fprintf('\n>>> Step 2/3: Exploratory analysis (s02_explore_data) ...\n\n');
run(fullfile(h1_root, 'scripts', 's02_explore_data.m'));

%% === Step 3: H1 LP estimation + robustness ===
fprintf('\n>>> Step 3/3: H1 LP estimation (s03_run_h1) ...\n\n');
run(fullfile(h1_root, 'scripts', 's03_run_h1.m'));

%% === Summary ===
fprintf('\n========================================\n');
fprintf('  H1 Pipeline Complete!\n');
fprintf('========================================\n');
fprintf('  Data:    %s\n', fullfile(h1_root, 'data'));
fprintf('  Figures: %s\n', fullfile(h1_root, 'output'));
fprintf('  Results: %s\n', fullfile(h1_root, 'output', 'h1_results.mat'));
fprintf('\n  Next: inspect IRF figures and check H1 success criteria.\n');
fprintf('  H1 supported if CPI(+) and IP(-) significant at h=6-24.\n');
