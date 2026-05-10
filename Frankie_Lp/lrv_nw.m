function V = lrv_nw(data, lag)
% data = T by N = (x_1, x_2, ..., x_T)' where x_i is a N dimensional
% vector.
% lag = Newey-West(Bartlett) kernel lag
% V = 1 / (lag+1) * G(-lag) + 2 / (lag+1) * G( -lag+1) + ... + G(0) + ... +
% 1 / (lag+1) * G(lag)'


[T,N] = size(data);

V = data' * data / T;               % G(0)

for i = 1:lag
    data_temp = [zeros(i,N);data(1:end-i,:)];
    G_temp = data'*data_temp / T ;
    
    V = V + (1-i/(lag+1))*(G_temp + G_temp');
end
