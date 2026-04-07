%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EXPECTED-INFLATION TAYLOR RULE REGRESSIONS
% Dataset: AAAIRF2_EPi_x_aligned.m2
%
% Variable mapping:
%   MACRO(:,1) = E_t[pi_{t+1}]
%   Inf_t      = pi_t
%   Other data order unchanged
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; clc;

%% ========================================================================
% LOAD DATA
% ========================================================================
load('AAAIRF2_EPi_x_aligned.mat');

%% ========================================================================
% EXTRACT VARIABLES
% ========================================================================
pi_t    = Inf_t;          % actual inflation
i_t     = MACRO(:,2);     % policy rate
oil_t   = MACRO(:,5);     % oil variable
x_t     = -OUTPUT_GAP;     % output gap
pi_e_t  = MACRO(:,1);     % expected inflation E_t[pi_{t+1}]
eta_T   = ETA_GPRT.^2;       % threat shock
eta_A   = ETA_GPRA.^2;       % act shock

%% ========================================================================
% FORCE COLUMN VECTORS
% ========================================================================
pi_t   = pi_t(:);
i_t    = i_t(:);
oil_t  = oil_t(:);
x_t    = x_t(:);
pi_e_t = pi_e_t(:);
eta_T  = eta_T(:);
eta_A  = eta_A(:);

%% ========================================================================
% BUILD LAGS / TRANSFORMS
% ========================================================================
i_lag   = [NaN; i_t(1:end-1)];
pi_lag  = [NaN; pi_t(1:end-1)];
pie_lag = [NaN; pi_e_t(1:end-1)];

%% ========================================================================
% BUILD TABLE
% ========================================================================
tbl = table(i_t, i_lag, pi_t, pi_lag, pi_e_t, pie_lag, ...
            x_t, oil_t, eta_T, eta_A);

tbl = rmmissing(tbl);

fprintf('\n============================================================\n');
fprintf('Final regression sample size = %d\n', height(tbl));
fprintf('============================================================\n\n');

%% ========================================================================
% MODEL FORMULAS
% ========================================================================
formula_A = 'i_t = alpha + rho i_{t-1} + phi_pi pi_t + phi_x x_t + nu_t';
formula_B = 'i_t = alpha + rho i_{t-1} + phi_pi E_t[pi_{t+1}] + phi_x x_t + nu_t';
formula_C = 'i_t = alpha + rho i_{t-1} + phi_pi E_t[pi_{t+1}] + phi_x x_t + psi_T eta_T + psi_A eta_A + nu_t';
formula_D = 'i_t = alpha + rho i_{t-1} + phi_pi E_t[pi_{t+1}] + phi_x x_t + delta Delta oil_t + psi_T eta_T + psi_A eta_A + nu_t';
formula_E = 'wedge_t = alpha + psi_T eta_T + psi_A eta_A + nu_t';
formula_F = 'pi_t = alpha + rho pi_{t-1} + beta E_t[pi_{t+1}] + kappa x_t + gamma_T eta_T + gamma_A eta_A + u_t';

%% ========================================================================
% REGRESSIONS
% ========================================================================
mdl_A = fitlm(tbl, 'i_t ~ i_lag + pi_t + x_t');
mdl_B = fitlm(tbl, 'i_t ~ i_lag + pi_e_t + x_t');
mdl_C = fitlm(tbl, 'i_t ~ i_lag + pi_e_t + x_t + eta_T + eta_A');
mdl_D = fitlm(tbl, 'i_t ~ i_lag + pi_e_t + x_t + oil_t + eta_T + eta_A');

tbl.wedge_exp = mdl_B.Residuals.Raw;
mdl_E = fitlm(tbl, 'wedge_exp ~ eta_T + eta_A');

mdl_F = fitlm(tbl, 'pi_t ~ pi_lag + pi_e_t + x_t + eta_T + eta_A');

%% ========================================================================
% DISPLAY EACH RESULT IN MATLAB
% ========================================================================
show_model_result('Model (A): Backward-looking Taylor rule', formula_A, mdl_A);
show_model_result('Model (B): Expected-inflation Taylor rule', formula_B, mdl_B);
show_model_result('Model (C): Expected-inflation Taylor + geopolitical shocks', formula_C, mdl_C);
show_model_result('Model (D): Expected-inflation Taylor + oil + geopolitical shocks', formula_D, mdl_D);
show_model_result('Model (E): Wedge regression', formula_E, mdl_E);
show_model_result('Model (F): Phillips curve with expected inflation', formula_F, mdl_F);

%% ========================================================================
% BUILD ONE LATEX LONGTABLE
% ========================================================================
models = {mdl_A, mdl_B, mdl_C, mdl_D, mdl_E, mdl_F};
model_names = {'(A)','(B)','(C)','(D)','(E)','(F)'};

row_labels = { ...
    'Constant', ...
    '$i_{t-1}$', ...
    '$\pi_t$', ...
    '$\pi_{t-1}$', ...
    '$E_t[\pi_{t+1}]$', ...
    '$x_t$', ...
    '$\eta_T$', ...
    '$\eta_A$', ...
    '$\Delta oil_t$'};

coef_names = { ...
    '(Intercept)', ...
    'i_lag', ...
    'pi_t', ...
    'pi_lag', ...
    'pi_e_t', ...
    'x_t', ...
    'eta_T', ...
    'eta_A', ...
    'oil_t'};

formula_latex = { ...
    '$i_t=\alpha+\rho i_{t-1}+\phi_\pi \pi_t+\phi_x x_t+\nu_t$', ...
    '$i_t=\alpha+\rho i_{t-1}+\phi_\pi E_t[\pi_{t+1}]+\phi_x x_t+\nu_t$', ...
    '$i_t=\alpha+\rho i_{t-1}+\phi_\pi E_t[\pi_{t+1}]+\phi_x x_t+\psi_T\eta_T+\psi_A\eta_A+\nu_t$', ...
    '$i_t=\alpha+\rho i_{t-1}+\phi_\pi E_t[\pi_{t+1}]+\phi_x x_t+\delta \Delta oil_t+\psi_T\eta_T+\psi_A\eta_A+\nu_t$', ...
    '$wedge_t=\alpha+\psi_T\eta_T+\psi_A\eta_A+\nu_t$', ...
    '$\pi_t=\alpha+\rho \pi_{t-1}+\beta E_t[\pi_{t+1}]+\kappa x_t+\gamma_T\eta_T+\gamma_A\eta_A+u_t$'};

nModels = length(models);
nVars   = length(coef_names);

coef_str = strings(nVars, nModels);
se_str   = strings(nVars, nModels);

R2      = zeros(1,nModels);
AdjR2   = zeros(1,nModels);
RMSE    = zeros(1,nModels);
Nobs    = zeros(1,nModels);

for m = 1:nModels
    mdl = models{m};
    coefTab = mdl.Coefficients;

    R2(m)    = mdl.Rsquared.Ordinary;
    AdjR2(m) = mdl.Rsquared.Adjusted;
    RMSE(m)  = mdl.RMSE;
    Nobs(m)  = mdl.NumObservations;

    for v = 1:nVars
        idx = strcmp(coefTab.Properties.RowNames, coef_names{v});
        if any(idx)
            est = coefTab.Estimate(idx);
            se  = coefTab.SE(idx);
            p   = coefTab.pValue(idx);

            coef_str(v,m) = sprintf('%.3f%s', est, sigstars(p));
            se_str(v,m)   = sprintf('(%.3f)', se);
        else
            coef_str(v,m) = "";
            se_str(v,m)   = "";
        end
    end
end

%% ========================================================================
% GENERATE LATEX LONGTABLE
% ========================================================================
latex = "";

latex = latex + sprintf('\\begin{longtable}{p{3.2cm}p{10.8cm}}\n');
latex = latex + sprintf('\\caption{Model formulas for expected-inflation regressions}\\\\\n');
latex = latex + sprintf('\\hline\\hline\n');
latex = latex + sprintf('Model & Formula \\\\\n');
latex = latex + sprintf('\\hline\n');
latex = latex + sprintf('\\endfirsthead\n');

latex = latex + sprintf('\\hline\\hline\n');
latex = latex + sprintf('Model & Formula \\\\\n');
latex = latex + sprintf('\\hline\n');
latex = latex + sprintf('\\endhead\n');

for m = 1:nModels
    latex = latex + sprintf('%s & %s \\\\\n', model_names{m}, formula_latex{m});
end

latex = latex + sprintf('\\hline\\hline\n');
latex = latex + sprintf('\\end{longtable}\n\n');

latex = latex + sprintf('\\begin{longtable}{lcccccc}\n');
latex = latex + sprintf('\\caption{Expected-inflation regression results}\\\\\n');
latex = latex + sprintf('\\hline\\hline\n');
latex = latex + sprintf(' & (A) & (B) & (C) & (D) & (E) & (F) \\\\\n');
latex = latex + sprintf('\\hline\n');
latex = latex + sprintf('\\endfirsthead\n');

latex = latex + sprintf('\\hline\\hline\n');
latex = latex + sprintf(' & (A) & (B) & (C) & (D) & (E) & (F) \\\\\n');
latex = latex + sprintf('\\hline\n');
latex = latex + sprintf('\\endhead\n');

for v = 1:nVars
    row1 = row_labels{v};
    row2 = ' ';
    for m = 1:nModels
        row1 = [row1, sprintf(' & %s', coef_str(v,m))];
        row2 = [row2, sprintf(' & %s', se_str(v,m))];
    end
    row1 = [row1, ' \\'];
    row2 = [row2, ' \\'];

    latex = latex + string(row1) + newline;
    latex = latex + string(row2) + newline;
end

rowR2 = 'R$^2$';
rowAdj = 'Adj. R$^2$';
rowRMSE = 'RMSE';
rowN = '$N$';

for m = 1:nModels
    rowR2   = [rowR2,   sprintf(' & %.3f', R2(m))];
    rowAdj  = [rowAdj,  sprintf(' & %.3f', AdjR2(m))];
    rowRMSE = [rowRMSE, sprintf(' & %.3f', RMSE(m))];
    rowN    = [rowN,    sprintf(' & %d',   Nobs(m))];
end

latex = latex + sprintf('\\hline\n');
latex = latex + string([rowR2, ' \\']) + newline;
latex = latex + string([rowAdj, ' \\']) + newline;
latex = latex + string([rowRMSE, ' \\']) + newline;
latex = latex + string([rowN, ' \\']) + newline;
latex = latex + sprintf('\\hline\\hline\n');
latex = latex + sprintf('\\multicolumn{7}{p{15cm}}{\\footnotesize Notes: Standard errors in parentheses. *** $p<0.01$, ** $p<0.05$, * $p<0.10$.}\\\\\n');
latex = latex + sprintf('\\end{longtable}\n');

%% ========================================================================
% SHOW LATEX IN MATLAB
% ========================================================================
disp(' ');
disp('==================== LATEX LONGTABLE CODE ====================');
disp(char(latex));
disp('==============================================================');

%% ========================================================================
% WRITE ONE LATEX FILE
% ========================================================================
fid = fopen('expected_inflation_regression_longtable.tex', 'w');
fprintf(fid, '%s', char(latex));
fclose(fid);

disp('Saved successfully: expected_inflation_regression_longtable.tex');

%% ========================================================================
% LOCAL FUNCTIONS
% ========================================================================
function show_model_result(title_str, formula_str, mdl)
    fprintf('\n============================================================\n');
    fprintf('%s\n', title_str);
    fprintf('Formula: %s\n', formula_str);
    fprintf('============================================================\n');
    disp(mdl);

    coefTab = mdl.Coefficients;
    disp('Coefficient table:');
    disp(coefTab);

    fprintf('R-squared      : %.4f\n', mdl.Rsquared.Ordinary);
    fprintf('Adjusted R-sq. : %.4f\n', mdl.Rsquared.Adjusted);
    fprintf('RMSE           : %.4f\n', mdl.RMSE);
    fprintf('N              : %d\n', mdl.NumObservations);
end

function s = sigstars(p)
    if p < 0.01
        s = '***';
    elseif p < 0.05
        s = '**';
    elseif p < 0.10
        s = '*';
    else
        s = '';
    end
end