function EIS_multi_C(Cdl_list, f1, fn, sigma)
% Standard Randles circuit: Z = Rs + (Rct + Z_W) || Cdl
% Without Rct (Rct=0), there is no RC time constant, so both the Nyquist
% impedance plot and the complex capacitance plot show only the 45-degree
% Warburg diffusion line with no semicircle. Adding Rct creates the RC
% relaxation feature that produces the Nyquist-like semicircle.
%
% sigma (Warburg coefficient, Ohm.s^(-1/2)) controls the low-frequency
% diffusion tail. Pass sigma=0 to disable Warburg entirely.
% Call EIS_Warburg_effect to compare multiple sigma values side-by-side.
Rs  = 100;  % solution resistance (Ohm)
Rct = 300;  % charge transfer resistance (Ohm)

if nargin < 2 || isempty(f1)
    f1 = 1;
end
if nargin < 3 || isempty(fn)
    fn = 100000;
end
if nargin < 4 || isempty(sigma)
    sigma = 50;  % Warburg coefficient (Ohm.s^(-1/2))
end

num_points = 1000;
f     = logspace(log10(f1), log10(fn), num_points);
omega = 2 * pi * f;

colors = lines(numel(Cdl_list));

figure('Name', 'EIS - Multiple Cdl Values', 'NumberTitle', 'off', ...
       'Position', [50, 50, 1400, 600]);

ax_nyq = subplot(1, 2, 1);
hold(ax_nyq, 'on');

ax_C = subplot(1, 2, 2);
hold(ax_C, 'on');

legend_entries = {};

for k = 1:numel(Cdl_list)
    Cdl = Cdl_list(k);

    % Impedance components
    Z_Cdl = 1 ./ (1i * omega * Cdl);
    Z_W   = sigma * (1 - 1i) ./ sqrt(omega);

    % Standard Randles circuit: (Rct + Z_W) in series, then || Cdl
    Z_faradaic = Rct + Z_W;
    Z_parallel = (Z_faradaic .* Z_Cdl) ./ (Z_faradaic + Z_Cdl);
    Z_total    = Rs + Z_parallel;

    % |Z|^2 (magnitude squared)
    Z_total_amp = real(Z_total).^2 + imag(Z_total).^2;

    % Complex capacitance: C* = -1/(j*omega*Z)
    % C' = -Z'' / (omega * |Z|^2)
    % C'' =  Z'  / (omega * |Z|^2)
    C_real = -imag(Z_total) ./ (omega .* Z_total_amp);
    C_imag =  real(Z_total) ./ (omega .* Z_total_amp);

    % --- Nyquist plot ---
    plot(ax_nyq, real(Z_total), -imag(Z_total), '-', ...
         'Color', colors(k,:), 'LineWidth', 2);
    % High-frequency start (circle) and low-frequency end (square)
    plot(ax_nyq, real(Z_total(1)),   -imag(Z_total(1)),   'o', ...
         'Color', colors(k,:), 'MarkerFaceColor', colors(k,:), 'MarkerSize', 7);
    plot(ax_nyq, real(Z_total(end)), -imag(Z_total(end)), 's', ...
         'Color', colors(k,:), 'MarkerFaceColor', colors(k,:), 'MarkerSize', 7);

    % --- Complex capacitance plot (C' vs C'') ---
    plot(ax_C, C_real, C_imag, '-', 'Color', colors(k,:), 'LineWidth', 2);
    % High-frequency start (circle) and low-frequency end (square)
    plot(ax_C, C_real(1),   C_imag(1),   'o', ...
         'Color', colors(k,:), 'MarkerFaceColor', colors(k,:), 'MarkerSize', 7);
    plot(ax_C, C_real(end), C_imag(end), 's', ...
         'Color', colors(k,:), 'MarkerFaceColor', colors(k,:), 'MarkerSize', 7);

    legend_entries{end+1} = cdl_label(Cdl); %#ok<AGROW>
end

% Nyquist axes
grid(ax_nyq, 'on');
ax_nyq.XMinorGrid = 'on';
ax_nyq.YMinorGrid = 'on';
xlabel(ax_nyq, 'Z_{real} (\Omega)',  'FontSize', 13, 'FontWeight', 'bold');
ylabel(ax_nyq, '-Z_{imag} (\Omega)', 'FontSize', 13, 'FontWeight', 'bold');
title(ax_nyq, 'Nyquist', 'FontSize', 15, 'FontWeight', 'bold');
legend(ax_nyq, legend_entries, 'Location', 'best', 'FontSize', 11);
set(ax_nyq, 'FontSize', 11);

% Complex capacitance axes
grid(ax_C, 'on');
ax_C.XMinorGrid = 'on';
ax_C.YMinorGrid = 'on';
xlabel(ax_C, 'C'' (F)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel(ax_C, 'C'''' (F)', 'FontSize', 13, 'FontWeight', 'bold');
title(ax_C, 'Complex Capacitance', 'FontSize', 15, 'FontWeight', 'bold');
legend(ax_C, legend_entries, 'Location', 'best', 'FontSize', 11);
set(ax_C, 'FontSize', 11);

sgtitle('EIS Analysis', 'FontSize', 16, 'FontWeight', 'bold');
end

function lbl = cdl_label(Cdl)
if Cdl >= 1e-3
    lbl = sprintf('Cdl = %.3g F',  Cdl);
elseif Cdl >= 1e-6
    lbl = sprintf('Cdl = %.3g \muF', Cdl * 1e6);
else
    lbl = sprintf('Cdl = %.3g nF', Cdl * 1e9);
end
end
