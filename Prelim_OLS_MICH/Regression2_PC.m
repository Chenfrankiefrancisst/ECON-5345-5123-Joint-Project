%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PHILLIPS-CURVE EXTENSIONS
% Converted for AAAIRF2_EPi_x_aligned.mat
%
% Logic:
%   MACRO(:,1) = E_t[pi_{t+1}]
%   Inf_t      = pi_t
%   MACRO(:,5) = oil price change already
%                => DO NOT difference it again
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; clc;

%% ========================================================================
% LOAD DATA
% ========================================================================
load('AAAIRF2_EPi_x_aligned.mat');

%% ========================================================================
% EXTRACT VARIABLES
% ========================================================================
pi_t      = Inf_t;          % actual inflation
oilchg_t  = MACRO(:,5);     % already oil price change
x_t       = -OUTPUT_GAP;     % output gap
pi_e_t    = MACRO(:,1);     % expected inflation E_t[pi_{t+1}]
eta_T     = ETA_GPRT.^2;       % threat shock
eta_A     = ETA_GPRA.^2;       % act shock

%% ========================================================================
% FORCE COLUMN VECTORS
% ========================================================================
pi_t     = pi_t(:);
oilchg_t = oilchg_t(:);
x_t      = x_t(:);
pi_e_t   = pi_e_t(:);
eta_T    = eta_T(:);
eta_A    = eta_A(:);

%% ========================================================================
% BUILD LAGS
% ========================================================================
pi_lag      = [NaN; pi_t(1:end-1)];
pie_lag     = [NaN; pi_e_t(1:end-1)];
oilchg_lag  = [NaN; oilchg_t(1:end-1)];

%% ========================================================================
% BUILD TABLE
% ========================================================================
tbl = table(pi_t, pi_lag, pi_e_t, pie_lag, x_t, oilchg_t, oilchg_lag, eta_T, eta_A);
tbl = rmmissing(tbl);

fprintf('\n============================================================\n');
fprintf('Final regression sample size = %d\n', height(tbl));
fprintf('============================================================\n\n');

%% ========================================================================
% MODEL FORMULAS
% ========================================================================
formula_1  = 'pi_e_t = alpha + rho*pi_{t-1}^e + lambda_T*eta_T + lambda_A*eta_A + u_t';
formula_1B = 'pi_e_t = alpha + rho*pi_{t-1}^e + xi*oilchg_t + lambda_T*eta_T + lambda_A*eta_A + u_t';
formula_2  = 'pi_t = alpha + rho*pi_{t-1} + beta*pi_e_t + kappa*x_t + gamma_T*eta_T + gamma_A*eta_A + u_t';
formula_3  = 'pi_t = alpha + rho*pi_{t-1} + beta*pi_e_t + kappa*x_t + theta*oilchg_t + gamma_T*eta_T + gamma_A*eta_A + u_t';
formula_4  = 'oilchg_t = alpha + rho*oilchg_{t-1} + omega_T*eta_T + omega_A*eta_A + u_t';

%% ========================================================================
% REGRESSIONS
% ========================================================================
mdl_exp_direct     = fitlm(tbl, 'pi_e_t ~ pie_lag + eta_T + eta_A');
mdl_exp_direct_oil = fitlm(tbl, 'pi_e_t ~ pie_lag + oilchg_t + eta_T + eta_A');
mdl_pc_base        = fitlm(tbl, 'pi_t ~ pi_lag + pi_e_t + x_t + eta_T + eta_A');
mdl_pc_oil         = fitlm(tbl, 'pi_t ~ pi_lag + pi_e_t + x_t + oilchg_t + eta_T + eta_A');
mdl_oil_direct     = fitlm(tbl, 'oilchg_t ~ oilchg_lag + eta_T + eta_A');

%% ========================================================================
% DISPLAY EACH RESULT IN MATLAB
% ========================================================================
show_model_result('Model (1): Expected inflation directly on shocks', formula_1, mdl_exp_direct);
show_model_result('Model (1B): Expected inflation on shocks + oil price change', formula_1B, mdl_exp_direct_oil);
show_model_result('Model (2): Phillips curve with expected inflation', formula_2, mdl_pc_base);
show_model_result('Model (3): Phillips curve with expected inflation + oil price change', formula_3, mdl_pc_oil);
show_model_result('Model (4): Oil price change directly on shocks', formula_4, mdl_oil_direct);

%% ========================================================================
% KEY COMPARISON IN MATLAB
% ========================================================================
disp(' ');
disp('================ KEY COMPARISON ================');

coef_base = mdl_pc_base.Coefficients;
coef_oil  = mdl_pc_oil.Coefficients;

idxT_base = strcmp(coef_base.Properties.RowNames, 'eta_T');
idxA_base = strcmp(coef_base.Properties.RowNames, 'eta_A');

idxT_oil  = strcmp(coef_oil.Properties.RowNames, 'eta_T');
idxA_oil  = strcmp(coef_oil.Properties.RowNames, 'eta_A');
idxOil    = strcmp(coef_oil.Properties.RowNames, 'oilchg_t');

fprintf('Base Phillips: eta_T = %.4f (p = %.4f)\n', ...
    coef_base.Estimate(idxT_base), coef_base.pValue(idxT_base));
fprintf('Base Phillips: eta_A = %.4f (p = %.4f)\n', ...
    coef_base.Estimate(idxA_base), coef_base.pValue(idxA_base));

fprintf('Phillips + oil: eta_T = %.4f (p = %.4f)\n', ...
    coef_oil.Estimate(idxT_oil), coef_oil.pValue(idxT_oil));
fprintf('Phillips + oil: eta_A = %.4f (p = %.4f)\n', ...
    coef_oil.Estimate(idxA_oil), coef_oil.pValue(idxA_oil));
fprintf('Phillips + oil: oilchg_t = %.4f (p = %.4f)\n', ...
    coef_oil.Estimate(idxOil), coef_oil.pValue(idxOil));

fprintf('Base Phillips R^2 = %.4f, Adj.R^2 = %.4f\n', ...
    mdl_pc_base.Rsquared.Ordinary, mdl_pc_base.Rsquared.Adjusted);
fprintf('Phillips + oil R^2 = %.4f, Adj.R^2 = %.4f\n', ...
    mdl_pc_oil.Rsquared.Ordinary, mdl_pc_oil.Rsquared.Adjusted);

%% ========================================================================
% BUILD LATEX LONGTABLES
% ========================================================================
models = {mdl_exp_direct, mdl_exp_direct_oil, mdl_pc_base, mdl_pc_oil, mdl_oil_direct};
model_names = {'(1)','(1B)','(2)','(3)','(4)'};

row_labels = { ...
    'Constant', ...
    '$\pi_{t-1}$', ...
    '$E_t[\pi_{t+1}]_{t-1}$', ...
    '$E_t[\pi_{t+1}]$', ...
    '$x_t$', ...
    '$oilchg_t$', ...
    '$oilchg_{t-1}$', ...
    '$\eta_T$', ...
    '$\eta_A$'};

coef_names = { ...
    '(Intercept)', ...
    'pi_lag', ...
    'pie_lag', ...
    'pi_e_t', ...
    'x_t', ...
    'oilchg_t', ...
    'oilchg_lag', ...
    'eta_T', ...
    'eta_A'};

formula_latex = { ...
    '$\pi_t^e=\alpha+\rho \pi_{t-1}^e+\lambda_T\eta_T+\lambda_A\eta_A+u_t$', ...
    '$\pi_t^e=\alpha+\rho \pi_{t-1}^e+\xi oilchg_t+\lambda_T\eta_T+\lambda_A\eta_A+u_t$', ...
    '$\pi_t=\alpha+\rho \pi_{t-1}+\beta \pi_t^e+\kappa x_t+\gamma_T\eta_T+\gamma_A\eta_A+u_t$', ...
    '$\pi_t=\alpha+\rho \pi_{t-1}+\beta \pi_t^e+\kappa x_t+\theta oilchg_t+\gamma_T\eta_T+\gamma_A\eta_A+u_t$', ...
    '$oilchg_t=\alpha+\rho oilchg_{t-1}+\omega_T\eta_T+\omega_A\eta_A+u_t$'};

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
% GENERATE LATEX CODE
% ========================================================================
latex = "";

latex = latex + sprintf('\\begin{longtable}{p{3.2cm}p{10.8cm}}\n');
latex = latex + sprintf('\\caption{Model formulas for Phillips-curve extensions}\\\\\n');
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

latex = latex + sprintf('\\begin{longtable}{lccccc}\n');
latex = latex + sprintf('\\caption{Phillips-curve extension regression results}\\\\\n');
latex = latex + sprintf('\\hline\\hline\n');
latex = latex + sprintf(' & (1) & (1B) & (2) & (3) & (4) \\\\\n');
latex = latex + sprintf('\\hline\n');
latex = latex + sprintf('\\endfirsthead\n');

latex = latex + sprintf('\\hline\\hline\n');
latex = latex + sprintf(' & (1) & (1B) & (2) & (3) & (4) \\\\\n');
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
latex = latex + sprintf('\\multicolumn{6}{p{14cm}}{\\footnotesize Notes: Standard errors in parentheses. *** $p<0.01$, ** $p<0.05$, * $p<0.10$. In this dataset, $MACRO(:,1)=E_t[\\pi_{t+1}]$, $Inf\\_t=\\pi_t$, and $MACRO(:,5)$ is already oil price change, so it is not differenced again.}\\\\\n');
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
fid = fopen('pc_extensions_AAAIRF2_longtable.tex', 'w');
fprintf(fid, '%s', char(latex));
fclose(fid);

disp('Saved successfully: pc_extensions_AAAIRF2_longtable.tex');

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