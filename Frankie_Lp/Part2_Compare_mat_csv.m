% compare_mat_csv.m  -- script form (no function wrapper, no leading underscore)
% Compare Q_Levels_Database.mat and Q_Levels_Database.csv contents.

here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
mat_path = fullfile(here, 'Q_Levels_Database.mat');
csv_path = fullfile(here, 'Q_Levels_Database.csv');

fprintf('======================================================================\n');
fprintf('MAT: %s\n', mat_path);
fprintf('CSV: %s\n', csv_path);
fprintf('======================================================================\n\n');

S = load(mat_path);
top = fieldnames(S);
fprintf('[MAT] top-level vars: %s\n', strjoin(top, ', '));
for k = 1:numel(top)
    v = S.(top{k});
    fprintf('   %-20s class=%s size=[%s]\n', top{k}, class(v), num2str(size(v)));
end

T_mat = [];
for k = 1:numel(top)
    if istable(S.(top{k}))
        T_mat = S.(top{k});
        fprintf('\n[MAT] using table variable "%s"\n', top{k});
        break;
    end
end
if isempty(T_mat) && numel(top) == 1 && isstruct(S.(top{1}))
    T_mat = struct2table(S.(top{1}));
    fprintf('\n[MAT] coerced struct "%s" -> table\n', top{1});
end
if isempty(T_mat)
    error('Could not extract a table from the MAT file.');
end

fprintf('[MAT] rows = %d, cols = %d\n', height(T_mat), width(T_mat));
fprintf('[MAT] columns:\n');
fprintf('   %s\n', strjoin(T_mat.Properties.VariableNames, ', '));

T_csv = readtable(csv_path, 'VariableNamingRule','preserve');
fprintf('\n[CSV] rows = %d, cols = %d\n', height(T_csv), width(T_csv));
fprintf('[CSV] columns:\n');
fprintf('   %s\n', strjoin(T_csv.Properties.VariableNames, ', '));

csv_cols = T_csv.Properties.VariableNames;
mat_cols = T_mat.Properties.VariableNames;
common = intersect(csv_cols, mat_cols, 'stable');
csv_only = setdiff(csv_cols, mat_cols, 'stable');
mat_only = setdiff(mat_cols, csv_cols, 'stable');

fprintf('\n--- Column comparison ---\n');
fprintf('Common columns (%d): %s\n', numel(common), strjoin(common, ', '));
if ~isempty(csv_only), fprintf('CSV-only (%d): %s\n', numel(csv_only), strjoin(csv_only, ', ')); end
if ~isempty(mat_only), fprintf('MAT-only (%d): %s\n', numel(mat_only), strjoin(mat_only, ', ')); end

fprintf('\n--- Per-column numeric comparison ---\n');
fprintf('  %-25s  %7s %7s  %10s %10s  %12s\n', 'column', 'len_csv', 'len_mat', 'finite_csv', 'finite_mat', 'max|diff|');
n_mismatch = 0;
for k = 1:numel(common)
    name = common{k};
    a = T_csv.(name);
    b = T_mat.(name);
    if iscell(a) || isstring(a) || iscategorical(a) || isdatetime(a) || iscalendarduration(a)
        sa = string(a); sb = string(b);
        nmin = min(numel(sa), numel(sb));
        eq = sum(sa(1:nmin) == sb(1:nmin));
        fprintf('  %-25s  %7d %7d  %10s %10s  %12s  (string eq %d/%d)\n', ...
            name, numel(a), numel(b), '-', '-', '-', eq, nmin);
        if eq < nmin, n_mismatch = n_mismatch + 1; end
        continue;
    end
    a = double(a); b = double(b);
    nmin = min(numel(a), numel(b));
    a = a(1:nmin); b = b(1:nmin);
    fa = isfinite(a); fb = isfinite(b);
    use = fa & fb;
    if any(use)
        d = max(abs(a(use) - b(use)));
    else
        d = NaN;
    end
    fprintf('  %-25s  %7d %7d  %10d %10d  %12.4g\n', ...
        name, numel(T_csv.(name)), numel(T_mat.(name)), sum(fa), sum(fb), d);
    if ~isnan(d) && d > 1e-8
        n_mismatch = n_mismatch + 1;
    end
end

fprintf('\nSummary\n');
fprintf('----------------------------------------------------------------------\n');
fprintf('CSV rows = %d, MAT rows = %d\n', height(T_csv), height(T_mat));
fprintf('Common columns: %d / CSV-only: %d / MAT-only: %d\n', numel(common), numel(csv_only), numel(mat_only));
if n_mismatch == 0
    fprintf('All common columns match within 1e-8 tolerance.\n');
else
    fprintf('Numeric/text mismatches on %d column(s).\n', n_mismatch);
end
