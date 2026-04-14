function imp = adltoma(phi,theta,N,level)
% N: order of Imp-rep.
% level = 0 ; y is in the first differences
% level = 1 ; y is in level
% phi(L)y_t = c + theta(L)x_t + v_t.
% psi(L) = phi(L)^{-1} theta(L) + v
% ex. (1 - 0.5 L) y_t = c + (2 + 3 L - 4 L^2 ) x_t + v_t
% phi = 0.5,
% theta = [2;3;-4].

psi = zeros(N+1,1);

phi = [phi; zeros(N + 1,1)];
theta = [theta; zeros(N + 1,1)];

psi(1) = theta(1);
for t = 1:N
    psi(t+1) = flipud(psi(1:t))'*phi(1:t) + theta(t+1);
end

if level == 1
    imp = psi;
elseif level == 0
    imp = cumsum(psi);
end
