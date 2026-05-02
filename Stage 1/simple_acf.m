function [acf, lags] = simple_acf(x, nlags)
% SIMPLE_ACF  Sample autocorrelation function (no toolbox required).
%
%   [acf, lags] = simple_acf(x, nlags)
%     acf  : (nlags+1) x 1 vector, acf(1) = 1 (lag 0), acf(k+1) = r_k
%     lags : (nlags+1) x 1 vector, 0:nlags
%
%   Matches MATLAB's autocorr(x, 'NumLags', nlags) output convention.

    x = x(:);
    x = x(~isnan(x));
    n = length(x);
    xm = x - mean(x);
    c0 = sum(xm.^2);

    acf = zeros(nlags+1, 1);
    acf(1) = 1;
    for k = 1:nlags
        acf(k+1) = sum(xm(1:n-k) .* xm(k+1:n)) / c0;
    end
    lags = (0:nlags)';
end
