function fig = lp_plot_irf(results, opts)
% LP_PLOT_IRF  Plot impulse response function with confidence bands.
%
%   fig = lp_plot_irf(results, opts)
%
%   Inputs:
%     results — struct from lp_estimate() with fields: h, beta, ci_lo, ci_hi
%     opts    — struct with optional fields:
%       .title      — string, plot title (default: 'Impulse Response')
%       .ylabel     — string, y-axis label (default: 'Response')
%       .xlabel     — string, x-axis label (default: 'Horizon (months)')
%       .color      — 1x3 RGB vector for the IRF line (default: [0.2 0.4 0.8])
%       .alpha_fill — scalar, transparency of CI band (default: 0.2)
%       .zero_line  — logical, draw horizontal zero line (default: true)
%       .fig_handle — existing figure handle to plot into (default: new figure)
%       .subplot_pos — [row col idx] for subplot placement (default: none)
%
%   Output:
%     fig — figure handle

    % --- Defaults ---
    if nargin < 2, opts = struct(); end
    if ~isfield(opts, 'title'),      opts.title      = 'Impulse Response'; end
    if ~isfield(opts, 'ylabel'),     opts.ylabel     = 'Response'; end
    if ~isfield(opts, 'xlabel'),     opts.xlabel     = 'Horizon (months)'; end
    if ~isfield(opts, 'color'),      opts.color      = [0.2 0.4 0.8]; end
    if ~isfield(opts, 'alpha_fill'), opts.alpha_fill  = 0.2; end
    if ~isfield(opts, 'zero_line'),  opts.zero_line   = true; end

    h     = results.h;
    beta  = results.beta;
    ci_lo = results.ci_lo;
    ci_hi = results.ci_hi;

    % Remove NaN horizons
    valid = ~isnan(beta);
    h     = h(valid);
    beta  = beta(valid);
    ci_lo = ci_lo(valid);
    ci_hi = ci_hi(valid);

    % --- Figure ---
    if isfield(opts, 'fig_handle')
        fig = opts.fig_handle;
        figure(fig);
    else
        fig = figure;
    end

    if isfield(opts, 'subplot_pos')
        subplot(opts.subplot_pos(1), opts.subplot_pos(2), opts.subplot_pos(3));
    end

    hold on;

    % Shaded confidence band
    fill([h; flipud(h)], [ci_hi; flipud(ci_lo)], ...
         opts.color, 'FaceAlpha', opts.alpha_fill, 'EdgeColor', 'none');

    % IRF line
    plot(h, beta, '-', 'Color', opts.color, 'LineWidth', 2);

    % Zero line
    if opts.zero_line
        yline(0, 'k--', 'LineWidth', 0.8);
    end

    hold off;

    % Labels
    title(opts.title, 'FontSize', 12);
    ylabel(opts.ylabel);
    xlabel(opts.xlabel);
    xlim([min(h), max(h)]);
    grid on;
    set(gca, 'FontSize', 10);
end
