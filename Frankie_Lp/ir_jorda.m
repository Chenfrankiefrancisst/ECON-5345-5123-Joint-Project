function [imp, cb, shock, lag_length, residual, sd] = ir_jorda(y,X,I,J,Jflag,level,L_imp,alpha,trend,IC,L_NW)
% Single equation method using local projection.
% INPUT
% y = dependent variable
% X = shock / control variables if X has multiple columns. In such a case,
% the first column should be the shock variable.
% I = Number of endogenous lags included. If it is not a scalar, we choose
% the optimal I among the candidates based on the IC specified.
% J = The number of lagged shocks. If it is not a scalar, we choose
% the optimal I among the candidates based on the IC specified.
% Jflag = 0: J applies to only shocks, not controls.
% Jflag = 1: J applies to both shocks, and controls.
% level = 0 if y is I(1)
% y(+h) - y(-1) = trend + beta(L) Delta y(L) + gamma(L)x(L) + e
% level = 1 if y is I(0)
% y(+h) - y(-1) = trend + beta(L)y(L) + gamma(L)x(L) + e
% Impulse responses will be derived in level.
% L_imp = maximum horizon for the impulse respnse. Default is 20.
% alpha = confidence level. ex) alpha = 0.95 -> 95% confidence bands.
% 1 sd = .68, 1.68 sd = .90, 1.96 sd = .95, etc. Default is 95%.
% Confidence bands are obtained by Newey-West variance estimator.
% trend = 0 / 1 / 2 / 3; constant / linear / quadratic / cubic time trend.
% Default is a linear trend.
% IC = 0 / 1 / 2 if BIC / Hannan-Quinn / AIC is used to choose I,
% respectively. Default is 0.
% L_NW = Lag length for the Newey-West Variance estimator with the Bartlett kernel. 
%        If it is -1, then we use a simple rule of the thumb 
%        by Stock and Watson (2010), which is the default.
%
% OUTPUT
% imp = impulse response coefficients to unit response in x. L_imp+1 elements
% cb  = alpha-level confidence bands centered around imp.
% shock = E(shock) and standard deviation(shock)
% lag_length = results related lag selection. e.g. I(selected),
% I(set of candidates), J(selected), J(set of candidates),
% Information criterion evaluated, etc.
% residual = length(y) * (L_imp + 1). (t, h+1)- element = regression
% residual at t for h-period ahead forecasting.
% sd = standard deviation used for constructing the confidence band.

% required: lrv_nw.m
% Written by Byoungchan Lee, 4/06/2017

residual = nan(length(y), L_imp+1);

if length(y) ~= length(X)
    disp('error: match the sample size of y and X')
end
if nargin < 7
    L_imp = 20;
end
if nargin < 8
    alpha = .95;
end
if nargin < 9
    trend = 1;
end
if nargin < 10
    IC = 0;
end
if nargin < 11
    L_NW = -1;
end

% initialize
imp = zeros(L_imp+1,1);
cb = zeros(L_imp+1,2);
sd = zeros(L_imp+1,1);

% Shock summary statistics
shock.mean = mean(X(:,1));
shock.std  = std(X(:,1));

% When level == 0
dy = [nan;diff(y)];

% Number of control variables
N_C = size(X,2)-1;

% information criterion to choose I & J when we have multiple candidates
if ~isscalar(I) || ~isscalar(J)
    maxI = max(I);
    N_I = length(I);
    maxJ = max(J);
    N_J = length(J);
    ICvalue = zeros(N_I,N_J,L_imp+1);
    Iset = I;
    Jset = J;
    I = zeros(L_imp+1,1);
    J = zeros(L_imp+1,1);
    
    for idxt = 0:L_imp
        L_max = max([maxI, maxJ]);
        
        if level == 0
            L_max = L_max + 1; % Because of initial NaN in dy.
        end

        reg_y = - diff(lagmatrix(y,[0,idxt+1]),1,2);
        reg_y = reg_y(idxt+L_max+1:end);
        
        
        if level == 0
            X_y  = lagmatrix(dy, idxt+1:1:idxt+maxI);
        else
            X_y  = lagmatrix(y, idxt+1:1:idxt+maxI);
        end
       
        X_x  = lagmatrix(X(:,1), idxt:1:idxt+maxJ);
        T = length(y) - L_max - idxt;

        if Jflag == 1
        X_o  = lagmatrix(X(:,2:end), idxt:1:idxt+maxJ);
        end
        
        if trend == 0
            trend_temp = [];
        elseif trend == 1
            trend_temp = (1:1:T)';
        elseif trend == 2
            trend_temp = [(1:1:T)', (1:1:T)'.^2];
        else
            trend_temp = [(1:1:T)', (1:1:T)'.^2, (1:1:T)'.^3];
        end
        
        for idxI = 1:N_I
            for idxJ = 1:N_J
                I_temp = Iset(idxI);
                J_temp = Jset(idxJ);
                
                if Jflag == 0
                    reg_X = [X_y(:,1:1:I_temp), X_x(:,1:1:J_temp+1), X(:,2:end)];
                else
                    reg_X = [X_y(:,1:1:I_temp), X_x(:,1:1:J_temp+1), X_o(:,1:1:((J_temp+1)*N_C))];
                end
                reg_X = reg_X(idxt+L_max+1:end,:);
                reg_X = [ones(T,1), reg_X, trend_temp];
                
                [~,~,R] = regress(reg_y, reg_X);
                
                if IC == 0      % BIC
                    ICvalue(idxI,idxJ,idxt+1) = log(det(sum(R.^2)/T)) + (I_temp+J_temp*(N_C+1)) * log(T) / T;
                elseif IC == 1  % Hannan-Quinn
                    ICvalue(idxI,idxJ,idxt+1) = log(det(sum(R.^2)/T)) + 2*(I_temp+J_temp*(N_C+1)) * log(log(T)) / T;
                else            % AIC
                    ICvalue(idxI,idxJ,idxt+1) = log(det(sum(R.^2)/T)) + 2*(I_temp+J_temp*(N_C+1)) / T;
                end
            end
        end
        
        ICvalue_temp = ICvalue(:,:,idxt+1);
        [~,idx_IJ] = min(ICvalue_temp(:));
        [I_idx, J_idx] = ind2sub(size(ICvalue_temp),idx_IJ);
        
        I(idxt+1) = Iset(I_idx);
        J(idxt+1) = Jset(J_idx);
    end
else
    Iset = I;
    Jset = J;
    I = I*ones(L_imp+1,1);
    J = J*ones(L_imp+1,1);
    ICvalue = [];
    
end

% Estimation



for idxt = 0:L_imp
    if level == 0
        L_max = max([I(idxt+1)+1, J(idxt+1)]);  % Because of initial NaN in dy.
    else
        L_max = max([I(idxt+1), J(idxt+1)]);
    end

    reg_y = - diff(lagmatrix(y,[0,idxt+1]),1,2);
    reg_y = reg_y(idxt+L_max+1:end);
    
    
    if level == 0
        X_y  = lagmatrix(dy, idxt+1:1:idxt+I(idxt+1));
    else
        X_y  = lagmatrix(y, idxt+1:1:idxt+I(idxt+1));
    end

    X_x  = lagmatrix(X(:,1), idxt:1:idxt+J(idxt+1));
    
    if Jflag == 1
        X_o  = lagmatrix(X(:,2:end), idxt:1:idxt+J(idxt+1));
    end

    T = length(y) - L_max - idxt;
    
    if trend == 0
        trend_temp = [];
    elseif trend == 1
        trend_temp = (1:1:T)';
    elseif trend == 2
        trend_temp = [(1:1:T)', (1:1:T)'.^2];
    else
        trend_temp = [(1:1:T)', (1:1:T)'.^2, (1:1:T)'.^3];
    end
    
    
    if Jflag == 0
        reg_X = [X_y, X_x, X(:,2:end)];
    else
        reg_X = [X_y, X_x, X_o];
    end
    
    reg_X = reg_X(idxt+L_max+1:end,:);
    reg_X = [ones(T,1), reg_X, trend_temp];
    
    [beta,~,R] = regress(reg_y, reg_X);
    imp(idxt+1) = beta(1+I(idxt+1)+1);
    
    % Confidence bands
    SigmaX = reg_X' * reg_X / T;
    if L_NW == -1
        L_NW = round(0.75 * length(R)^(1/3) - 1);
    end
    Omega  = lrv_nw(reg_X.*repmat(R,1,size(reg_X,2)), L_NW);
    V = (SigmaX \ Omega / SigmaX )/T;
    sd_temp = sqrt(V(1+I(idxt+1)+1,1+I(idxt+1)+1));
    cb(idxt+1,:) = imp(idxt+1) + sd_temp*[norminv((1-alpha)/2,0,1), norminv((1+alpha)/2,0,1)];
    
    sd(idxt+1) = sd_temp;
    
    % Residual
    residual(L_max + idxt + 1:end, idxt+1) = R;
end

lag_length.Iset = Iset;
lag_length.I = I;
lag_length.Jset = Jset;
lag_length.J = J;
lag_length.ICvalue = ICvalue;
