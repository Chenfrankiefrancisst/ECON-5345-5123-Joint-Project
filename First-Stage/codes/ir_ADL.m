function [imp, cb, shock, lag_length, adl_coef] = ir_ADL(y,X,I,J,level,L_imp,alpha,N_B,mindelay,IC,trend)
% Single equation method using autoregressive distributed lags model by Romer and Romer (2004).
% INPUT
% y = dependent variable
% X = shock / control variables if X has multiple columns. In such a case,
% the first column should be the shock variable.
% I = Number of endogenous lags included. If it is not single, we choose
% the optimal I among the candidates based on the IC specified.
% J = The number of lagged shocks.
% level = 0 if y in the first difference
% level = 1 if y in level
% Impulse responses will be derived in level. If level == 0, then it will
% be cumulated.
% L_imp = maximum horizon for the impulse respnse. Default is J.
% alpha = confidence level. ex) alpha = 0.95 -> 95% confidence bands.
% 1 sd = .68, 1.68 sd = .90, 1.96 sd = .95, etc. Default is 95%.
% Confidence bands are obtained by Monte Carlo simulations. Simulation size
% is N_B, default is 1000.
% mindelay = minimum delay assumption indicator. Default is 0.
% mindelay = 0 if x(0) is included.
% mindelay = 1 if x(0) is not included. The contemporaneous response is 0.
% IC = 0 / 1 / 2 if BIC / Hannan-Quinn / AIC is used to choose I,
% respectively. Default is 0.
% trend = 0 / 1 / 2 / 3; constant / linear / quadratic / cubic time trend.
%  Default is 0.
%
% OUTPUT
% imp = impulse response coefficients to unit response in x. L_imp+1 elements
% cb  = alpha-level confidence bands centered around imp. 
% lag_length = results related lag selection. e.g. I(selected), 
% I(set of candidates), J, Information criterion evaluated, etc.
% adl_coeff  = estimated coefficients for the Autoregressive Distributed
% Lag model including phi and theta.

% required: adltoma.m, lrv_nw.m
% Written by Byoungchan Lee, 8/13/2017

if length(y) ~= length(X)
    disp('error: match the sample size of y and X')
end
if nargin < 6
    L_imp = J;
end
if nargin < 7
    alpha = .95;
end
if nargin < 8
    N_B = 1000;
end
if nargin < 9
    mindelay = 0;
end
if nargin < 10
    IC = 0;
end
if nargin < 11
    trend = 0;
end

ql = (1-alpha)/2;
qu = (1+alpha)/2;


shock.mean = mean(X(:,1));
shock.std  = std(X(:,1));

% information criterion to choose I when we have multiple candidate
if ~isscalar(I)
    maxI = max(I);
    N_I = length(I);
    ICvalue = zeros(N_I,1);
    
    for idx = 1:N_I
        L_max = max([maxI, J]);
        T = length(y) - L_max;    % Same data set and sample size for IC comparison
        
        reg_y = y(L_max+1:end);  % regressand
        
        X_y = lagmatrix(y, 1:1:maxI);  % endogenous lag
        I_temp = I(idx);
        
        
        if trend == 0
            trend_temp = [];
        elseif trend == 1
            trend_temp = (1:1:T)';
        elseif trend == 2
            trend_temp = [(1:1:T)', (1:1:T)'.^2];
        else
            trend_temp = [(1:1:T)', (1:1:T)'.^2, (1:1:T)'.^3];
        end
        
        
        if mindelay == 0    % No restrictions on contemporaneous response
            X_x  = lagmatrix(X(:,1),  0:1:J); % exogenous lag
            reg_X = [X_y(:,1:1:I_temp), X_x, X(:,2:end)]; % The last element is controls.
            reg_X = reg_X(L_max+1:end,:);
            reg_X = [ones(T,1), reg_X, trend_temp];     % regressor
            
            [~,~,R] = regress(reg_y, reg_X);
            
        else                % No contemporaneous response
            X_x  = lagmatrix(X(:,1),  1:1:J); % exogenous lag
            reg_X = [X_y(:,1:1:I_temp), X_x, X(:,2:end)]; % The last element is controls.
            reg_X = reg_X(L_max+1:end,:);
            reg_X = [ones(T,1), reg_X, trend_temp];     % regressor
            
            [~,~,R] = regress(reg_y, reg_X);
            
        end
        
        if IC == 0      % BIC
            ICvalue(idx) = log(det(sum(R.^2)/T)) + (I_temp+J-mindelay) * log(T) / T;
        elseif IC == 1  % Hannan-Quinn
            ICvalue(idx) = log(det(sum(R.^2)/T)) + 2*(I_temp+J-mindelay) * log(log(T)) / T;
        else            % AIC
            ICvalue(idx) = log(det(sum(R.^2)/T)) + 2*(I_temp+J-mindelay) / T;
        end
        
    end
    
    Iset = I;
    [~,idx_I] = min(ICvalue(:));
    I = Iset(idx_I);
else
    Iset = I;
    ICvalue = [];

end


% Estimation

if mindelay == 0    % No restrictions on contemporaneous response
    L_max = max([I, J]);
    T = length(y) - L_max;
    
    
    if trend == 0
        trend_temp = [];
    elseif trend == 1
        trend_temp = (1:1:T)';
    elseif trend == 2
        trend_temp = [(1:1:T)', (1:1:T)'.^2];
    else
        trend_temp = [(1:1:T)', (1:1:T)'.^2, (1:1:T)'.^3];
    end
    
    
    
    reg_y = y(L_max+1:end);  % regressand
    
    X_y = lagmatrix(y, 1:1:I);  % endogenous lag
    X_x  = lagmatrix(X(:,1),  0:1:J); % exogenous lag
    reg_X = [X_y, X_x, X(:,2:end)]; % The last element is controls.
    reg_X = reg_X(L_max+1:end,:);
    reg_X = [ones(T,1), reg_X, trend_temp];     % regressor
    
    [beta,~,R] = regress(reg_y, reg_X);
    
    % Impulse response
    phi = beta(2:I+1);
    theta = beta(I+2:I+J+2);
    imp = adltoma(phi,theta,L_imp,level);
    
    % Confidence bands
    SigmaX = reg_X' * reg_X / T;
    Omega  = lrv_nw(reg_X.*repmat(R,1,size(reg_X,2)), round(0.75 * T^(1/3) - 1));
    % Lag length is choosen by following Stock and Watson (2010)'s rule of thumb.
    V = (SigmaX \ Omega / SigmaX )/T;
    
    % Check validity for simulation
    [~,chk] = cholcov(V);
    while chk ~= 0
        V = (V + V')/2;
        [VM,DM] = eig(V);
        DM = max(DM,0);
        V = VM * DM / VM;
        [~,chk] = cholcov(V);
    end
    
    imp_temp = zeros(1+L_imp,N_B);
    for b = 1:N_B
        beta_temp = mvnrnd(beta, V)';
        phi_temp = beta_temp(2:I+1);
        theta_temp = beta_temp(I+2:I+J+2);
        imp_temp(:,b) = adltoma(phi_temp,theta_temp,L_imp,level);
    end
    
    cb = quantile(imp_temp, [ql, qu], 2);
    
else                % No contemporaneous response
    L_max = max([I, J]);
    T = length(y) - L_max;
    
    
    
    if trend == 0
        trend_temp = [];
    elseif trend == 1
        trend_temp = (1:1:T)';
    elseif trend == 2
        trend_temp = [(1:1:T)', (1:1:T)'.^2];
    else
        trend_temp = [(1:1:T)', (1:1:T)'.^2, (1:1:T)'.^3];
    end

    reg_y = y(L_max+1:end);  % regressand
    
    X_y = lagmatrix(y, 1:1:I);  % endogenous lag
    X_x  = lagmatrix(X(:,1),  1:1:J); % exogenous lag
    reg_X = [X_y, X_x, X(:,2:end)]; % The last element is controls.
    reg_X = reg_X(L_max+1:end,:);
    reg_X = [ones(T,1), reg_X, trend_temp];     % regressor
    
    [beta,~,R] = regress(reg_y, reg_X);
    
    % Impulse response
    phi = beta(2:I+1);
    theta = [0;beta(I+2:I+J+1)];
    imp = adltoma(phi,theta,L_imp,level);
     
    % Confidence bands
    SigmaX = reg_X' * reg_X / T;
    Omega  = lrv_nw(reg_X.*repmat(R,1,size(reg_X,2)), round(0.75 * T^(1/3) - 1));
    % Lag length is choosen by following Stock and Watson's rule of thumb.
    V = (SigmaX \ Omega / SigmaX )/T;
    
    % Check validity for simulation
    [~,chk] = cholcov(V);
    while chk ~= 0
        V = (V + V')/2;
        [VM,DM] = eig(V);
        DM = max(DM,0);
        V = VM * DM / VM;
        [~,chk] = cholcov(V);
    end
    
    imp_temp = zeros(1+L_imp,N_B);
    for b = 1:N_B
        beta_temp = mvnrnd(beta, V)';
        phi_temp = beta_temp(2:I+1);
        theta_temp = [0;beta_temp(I+2:I+J+1)];
        imp_temp(:,b) = adltoma(phi_temp,theta_temp,L_imp,level);
    end
    
    cb = quantile(imp_temp, [ql, qu], 2);
    
end

lag_length.Iset = Iset;
lag_length.I = I;
lag_length.J = J;
lag_length.IC = IC;
lag_length.ICvalue = ICvalue;

adl_coef.phi = phi;
adl_coef.theta = theta;
