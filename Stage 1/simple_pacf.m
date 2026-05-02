function [pacf, lags] = simple_pacf(x, nlags)
% SIMPLE_PACF  Sample partial autocorrelation via Durbin-Levinson recursion.
%              No toolbox required.
%
%   [pacf, lags] = simple_pacf(x, nlags)
%     pacf : (nlags+1) x 1 vector, pacf(1) = 1 (lag 0 convention),
%                                  pacf(k+1) = phi_{kk}
%     lags : (nlags+1) x 1 vector, 0:nlags
%
%   Matches MATLAB's parcorr(x, 'NumLags', nlags) output convention.

    [acf, ~] = simple_acf(x, nlags);

    pacf = zeros(nlags+1, 1);
    pacf(1) = 1;  % convention: lag-0 PACF = 1

    if nlags >= 1
        phi = zeros(nlags, nlags);
        phi(1,1) = acf(2);
        pacf(2)  = phi(1,1);

        for k = 2:nlags
            num = acf(k+1) - sum(phi(k-1, 1:k-1)' .* acf(k:-1:2));
            den = 1         - sum(phi(k-1, 1:k-1)' .* acf(2:k));
            phi(k,k) = num / den;

            for j = 1:k-1
                phi(k,j) = phi(k-1,j) - phi(k,k) * phi(k-1, k-j);
            end
            pacf(k+1) = phi(k,k);
        end
    end

    lags = (0:nlags)';
end
