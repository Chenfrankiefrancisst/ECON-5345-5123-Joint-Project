%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% FULL VAR / SVARX FROM ALIGNED DATAFILE
%%%
%%% Uses:
%%%   Aligned_GPR_ExpInf_1985Q1_2025Q2.mat
%%%
%%% Does:
%%%   1. load aligned NEW_GPRW / NEW_GPRA / NEW_GPRT
%%%   2. extract first-column structural shocks eta(:,1)
%%%   3. run SVARX for all three systems
%%%   4. align shocks + macro block + output gap
%%%   5. save compact dataset
%%%   6. plot structural shocks
%%%   7. plot Linear / Quadratic / Total IRFs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; clc; close all;

set(0,'defaultAxesFontName', 'Times');
set(0,'defaultAxesLineStyleOrder','-|--|:', 'defaultLineLineWidth',1.5);
set(0,'defaulttextinterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
set(0,'defaultLegendInterpreter','latex');

rng('default');
rng(0);

addpath('Functions');
addpath('Data');

%% ========================================================================
% LOAD ALIGNED DATA
% ========================================================================
load('Aligned_GPR_ExpInf_1985Q1_2025Q2.mat', ...
    'NEW_GPRW','NEW_GPRA','NEW_GPRT','OUTPUT_GAP_full','dates_aligned');

if ~exist('NEW_GPRW','var') || ~exist('NEW_GPRA','var') || ~exist('NEW_GPRT','var')
    error('Aligned datafile does not contain NEW_GPRW / NEW_GPRA / NEW_GPRT.');
end

if ~isequal(size(NEW_GPRW), size(NEW_GPRA), size(NEW_GPRT))
    error('NEW_GPRW, NEW_GPRA, NEW_GPRT must have the same size.');
end

[T, K] = size(NEW_GPRW);
fprintf('Loaded aligned data: T = %d, K = %d\n', T, K);

if K < 9
    error('Need at least 9 columns in each NEW matrix.');
end

%% ========================================================================
% SETTINGS
% ========================================================================
n   = 9;      % 1 GPR + 8 macro variables
p   = 2;      % lag order
c   = 1;
hor = 49;

cum       = 0;
pos_shock = 1;
nonlin    = 1;
restr     = 2;
q         = 0;

tvec = 0:hor-1;

%% ========================================================================
% NAMES / COLORS
% ========================================================================
target_names = {'GPR(World)','GPR-Act','GPR-Threat'};
target_colors = [0 0 0;   % black
                 1 0 0;   % red
                 0 0 1];  % blue
numT = numel(target_names);

VARnames = { ...
    'GPR'; ...
    'Expected Inflation'; ...
    'Policy Rate'; ...
    '1 Year Government Yield'; ...
    'Real Economic Activity'; ...
    'Oil Price'; ...
    'Gold Spot'; ...
    'Durables'; ...
    'SP 500' ...
};

macro_names = { ...
    'Expected Inflation', ...
    'Policy Rate', ...
    '1 Year Government Yield', ...
    'Real Economic Activity', ...
    'Oil Price', ...
    'Gold Spot', ...
    'Durables', ...
    'SP500' ...
};

%% ========================================================================
% STORAGE FOR IRFs
% ========================================================================
LinIRF    = zeros(hor,n,numT);
SqIRF     = zeros(hor,n,numT);
TotIRF    = zeros(hor,n,numT);

LinHi68   = zeros(hor,n,numT);
LinLo68   = zeros(hor,n,numT);
LinHi90   = zeros(hor,n,numT);
LinLo90   = zeros(hor,n,numT);

SqHi68    = zeros(hor,n,numT);
SqLo68    = zeros(hor,n,numT);
SqHi90    = zeros(hor,n,numT);
SqLo90    = zeros(hor,n,numT);

TotHi68   = zeros(hor,n,numT);
TotLo68   = zeros(hor,n,numT);
TotHi90   = zeros(hor,n,numT);
TotLo90   = zeros(hor,n,numT);

%% ========================================================================
% STORAGE FOR SHOCKS
% ========================================================================
ETA_GPRW = [];
ETA_GPRA = [];
ETA_GPRT = [];

ETA_all_GPRW = [];
ETA_all_GPRA = [];
ETA_all_GPRT = [];

%% ========================================================================
% RUN 3 SYSTEMS
% ========================================================================
for ii = 1:numT

    switch ii
        case 1
            vardata = NEW_GPRW(:,1:n);
        case 2
            vardata = NEW_GPRA(:,1:n);
        case 3
            vardata = NEW_GPRT(:,1:n);
        otherwise
            error('Unexpected shock index.');
    end

    % Structural identification via Cholesky
    [D,S,C,BigA,pi_hat,Y,X,Y_initial,Yfit,err,eta] = chol_irf(vardata,n,p,c,hor);

    finshock         = eta(:,pos_shock);
    finshock_squared = finshock.^2;

    switch ii
        case 1
            ETA_GPRW     = finshock;
            ETA_all_GPRW = eta;
        case 2
            ETA_GPRA     = finshock;
            ETA_all_GPRA = eta;
        case 3
            ETA_GPRT     = finshock;
            ETA_all_GPRT = eta;
    end

    % Data used in SVARX after lag trimming
    finaldata = vardata(p+1:end,:);
    news      = [finshock finshock_squared];
    m         = size(news,2);

    % This script/function is assumed to create:
    %   C_wold, HighC, LowC, HighC90, LowC90
    SVARX

    s = 2 * std(finshock);

    for v_idx = 1:n

        col_lin = (v_idx-1)*m + 1;
        col_sq  = col_lin + 1;

        % Linear IRF
        lin_irf   = s    * C_wold(:, col_lin);
        lin_hi90  = s    * HighC90(:, col_lin);
        lin_lo90  = s    * LowC90(:, col_lin);
        lin_hi68  = s    * HighC(:,   col_lin);
        lin_lo68  = s    * LowC(:,    col_lin);

        % Quadratic IRF
        sq_irf    = (s^2) * C_wold(:, col_sq);
        sq_hi90   = (s^2) * HighC90(:, col_sq);
        sq_lo90   = (s^2) * LowC90(:, col_sq);
        sq_hi68   = (s^2) * HighC(:,   col_sq);
        sq_lo68   = (s^2) * LowC(:,    col_sq);

        % Total IRF
        tot_irf = lin_irf + sq_irf;

        % 90% bands
        lin_up90 = lin_hi90 - lin_irf;
        lin_dn90 = lin_irf  - lin_lo90;
        sq_up90  = sq_hi90  - sq_irf;
        sq_dn90  = sq_irf   - sq_lo90;

        tot_up90 = sqrt(lin_up90.^2 + sq_up90.^2);
        tot_dn90 = sqrt(lin_dn90.^2 + sq_dn90.^2);

        tot_hi90 = tot_irf + tot_up90;
        tot_lo90 = tot_irf - tot_dn90;

        % 68% bands
        lin_up68 = lin_hi68 - lin_irf;
        lin_dn68 = lin_irf  - lin_lo68;
        sq_up68  = sq_hi68  - sq_irf;
        sq_dn68  = sq_irf   - sq_lo68;

        tot_up68 = sqrt(lin_up68.^2 + sq_up68.^2);
        tot_dn68 = sqrt(lin_dn68.^2 + sq_dn68.^2);

        tot_hi68 = tot_irf + tot_up68;
        tot_lo68 = tot_irf - tot_dn68;

        % Store
        LinIRF(:,v_idx,ii)  = lin_irf;
        SqIRF(:,v_idx,ii)   = sq_irf;
        TotIRF(:,v_idx,ii)  = tot_irf;

        LinHi68(:,v_idx,ii) = lin_hi68;
        LinLo68(:,v_idx,ii) = lin_lo68;
        LinHi90(:,v_idx,ii) = lin_hi90;
        LinLo90(:,v_idx,ii) = lin_lo90;

        SqHi68(:,v_idx,ii)  = sq_hi68;
        SqLo68(:,v_idx,ii)  = sq_lo68;
        SqHi90(:,v_idx,ii)  = sq_hi90;
        SqLo90(:,v_idx,ii)  = sq_lo90;

        TotHi68(:,v_idx,ii) = tot_hi68;
        TotLo68(:,v_idx,ii) = tot_lo68;
        TotHi90(:,v_idx,ii) = tot_hi90;
        TotLo90(:,v_idx,ii) = tot_lo90;
    end
end

%% ========================================================================
% ALIGN MACRO / OUTPUT GAP / DATES
% ========================================================================
MACRO = NEW_GPRW(p+1:end, 2:n);

if exist('OUTPUT_GAP_full','var')
    if length(OUTPUT_GAP_full) == T
        OUTPUT_GAP = OUTPUT_GAP_full(p+1:end);
    elseif length(OUTPUT_GAP_full) == T-p
        OUTPUT_GAP = OUTPUT_GAP_full;
    else
        error('OUTPUT_GAP_full length mismatch.');
    end
else
    error('OUTPUT_GAP_full not found in aligned datafile.');
end

if exist('dates_aligned','var') && ~isempty(dates_aligned)
    shock_dates = dates_aligned(p+1:end);
    macro_dates = dates_aligned(p+1:end);
else
    shock_dates = [];
    macro_dates = [];
end

%% ========================================================================
% FINAL SIZE CHECK
% ========================================================================
L = length(ETA_GPRW);

if length(ETA_GPRA) ~= L || length(ETA_GPRT) ~= L
    error('Shock series lengths do not match.');
end

if size(MACRO,1) ~= L
    error('MACRO length does not match structural shock length.');
end

if length(OUTPUT_GAP) ~= L
    error('OUTPUT_GAP length does not match structural shock length.');
end

fprintf('Final aligned sample length = %d\n', L);

%% ========================================================================
% BUILD AND SAVE COMPACT DATASET
% ========================================================================
DATA_ALL = [ETA_GPRW, ETA_GPRT, ETA_GPRA, OUTPUT_GAP, MACRO];

data_names = { ...
    'ETA_GPRW', ...
    'ETA_GPRT', ...
    'ETA_GPRA', ...
    'OUTPUT_GAP', ...
    'Expected Inflation', ...
    'Policy Rate', ...
    '1 Year Government Yield', ...
    'Real Economic Activity', ...
    'Oil Price', ...
    'Gold Spot', ...
    'Durables', ...
    'SP500' ...
};

save('AAAIRF_and_structural_shocks_GPR_ExpInf_1985Q1_2025Q2.mat', ...
    'ETA_GPRW','ETA_GPRT','ETA_GPRA', ...
    'MACRO','macro_names', ...
    'OUTPUT_GAP', ...
    'shock_dates','macro_dates', ...
    'DATA_ALL','data_names');

disp('Saved compact dataset: AAAIRF_and_structural_shocks_GPR_ExpInf_1985Q1_2025Q2.mat');

%% ========================================================================
% PREVIEW
% ========================================================================
disp('First 10 rows of aligned compact dataset:');
disp(array2table(DATA_ALL(1:min(10,end),:), 'VariableNames', data_names));

%% ========================================================================
% PLOT STRUCTURAL SHOCK SERIES
% ========================================================================
figure;
plot(ETA_GPRW,'k','LineWidth',1.5); hold on;
plot(ETA_GPRA,'r','LineWidth',1.5);
plot(ETA_GPRT,'b','LineWidth',1.5);
yline(0,'k--');

legend('GPR World shock','GPR Act shock','GPR Threat shock','Location','best');
title('Structural shock series: first Cholesky shock');
grid on;
box on;

if ~isempty(shock_dates)
    shock_labels = string(shock_dates);
else
    start_year = 1985;
    start_quarter = 2;   % because p = 1
    shock_labels = strings(L,1);
    for t = 1:L
        q_index = start_quarter + (t-1);
        year_t = start_year + floor((q_index-1)/4);
        quarter_t = mod(q_index-1,4) + 1;
        shock_labels(t) = sprintf('%dQ%d', year_t, quarter_t);
    end
end

tick_pos = 1:4:L;
if tick_pos(1) ~= 1
    tick_pos = [1 tick_pos];
end

set(gca, 'XTick', tick_pos, ...
         'XTickLabel', shock_labels(tick_pos), ...
         'XTickLabelRotation', 45);
xlabel('Quarter');

%% ========================================================================
% PLOT IRFS
% ========================================================================
plot_irf_3shocks( ...
    LinIRF, LinLo68, LinHi68, LinLo90, LinHi90, ...
    VARnames, tvec, target_names, target_colors, ...
    'Linear IRFs: GPR(World) vs GPR-Act vs GPR-Threat');

plot_irf_3shocks( ...
    SqIRF, SqLo68, SqHi68, SqLo90, SqHi90, ...
    VARnames, tvec, target_names, target_colors, ...
    'Quadratic IRFs: GPR(World) vs GPR-Act vs GPR-Threat');

plot_irf_3shocks( ...
    TotIRF, TotLo68, TotHi68, TotLo90, TotHi90, ...
    VARnames, tvec, target_names, target_colors, ...
    'Total IRFs: GPR(World) vs GPR-Act vs GPR-Threat');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Local plotting function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function plot_irf_3shocks(IRF,Lo68,Hi68,Lo90,Hi90, ...
                          VARnames,tvec,target_names,target_colors,TitleName)

figure;
tiledlayout(3,3,'TileSpacing','compact','Padding','compact');

nvar = numel(VARnames);
numT = numel(target_names);

CI_colors = [ ...
    0.50 0.50 0.50;   % World
    1.00 0.40 0.40;   % Act
    0.30 0.40 1.00];  % Threat

for v = 1:nvar

    nexttile; hold on; box on;
    plot(tvec,0*tvec,'k-','LineWidth',0.5,'HandleVisibility','off');

    for k = 1:numT

        % 90% CI
        fill([tvec fliplr(tvec)], ...
             [Lo90(:,v,k)' fliplr(Hi90(:,v,k)')], ...
             CI_colors(k,:), ...
             'FaceAlpha',0.12,'EdgeColor','none', ...
             'HandleVisibility','off');

        % 68% CI
        fill([tvec fliplr(tvec)], ...
             [Lo68(:,v,k)' fliplr(Hi68(:,v,k)')], ...
             CI_colors(k,:), ...
             'FaceAlpha',0.22,'EdgeColor','none', ...
             'HandleVisibility','off');

        % IRF line
        plot(tvec, IRF(:,v,k), ...
             'Color', target_colors(k,:), 'LineWidth',2.5);
    end

    title(VARnames{v}, 'FontSize',16, 'FontWeight','bold');
    grid on;
    xlim([tvec(1) tvec(end)]);
    set(gca,'FontSize',12);

    if v == 1
        legend(target_names,'NumColumns',3,'Location','southoutside', ...
               'FontSize',12);
    end
end

sgtitle(TitleName,'FontSize',18,'FontWeight','bold');

end