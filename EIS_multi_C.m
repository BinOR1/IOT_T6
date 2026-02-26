% Chương trình mô phỏng hệ điện hóa với mạch tương đương Randles
% Vẽ đồ thị Nyquist và Bode với nhiều giá trị Cdl khác nhau
% Rct = 0, luôn bật thành phần Warburg, Rs được cho trước
%
% Cách sử dụng:
%   EIS_multi_C(Cdl_list)
%   EIS_multi_C(Cdl_list, f1, fn)
%
% Ví dụ:
%   EIS_multi_C([1e-6, 10e-6, 100e-6])
%   EIS_multi_C([1e-6, 10e-6, 100e-6], 0.1, 1e5)

function EIS_multi_C(Cdl_list, f1, fn)

% --- Thông số cố định ---
Rs    = 100;    % Điện trở dung dịch (Ohm) - cho trước
% Rct = 0 (điện trở truyền điện tích bằng 0)
sigma = 500;    % Hệ số Warburg (Ohm.s^(-1/2))

% --- Giá trị mặc định cho dải tần số ---
if nargin < 2 || isempty(f1)
    f1 = 1;
end
if nargin < 3 || isempty(fn)
    fn = 100000;
end

% --- Dải tần số ---
num_points = 1000;
f     = logspace(log10(f1), log10(fn), num_points);
omega = 2 * pi * f;

% --- Màu sắc cho từng đường ---
colors = lines(numel(Cdl_list));

% --- Tạo figure ---
figure('Name', 'EIS - Nhiều giá trị Cdl', 'NumberTitle', 'off', ...
       'Position', [50, 50, 1400, 600]);

ax_nyq  = subplot(1, 2, 1);
hold(ax_nyq,  'on');

ax_bode = subplot(1, 2, 2);
hold(ax_bode, 'on');

legend_entries = {};

for k = 1:numel(Cdl_list)
    Cdl = Cdl_list(k);

    % Trở kháng từng thành phần
    Z_Cdl      = 1 ./ (1i * omega * Cdl);
    Z_W        = sigma * (1 - 1i) ./ sqrt(omega);  % Warburg (Rct=0 nên Z_faradaic = Z_W)

    % Tổng trở
    Z_parallel = (Z_W .* Z_Cdl) ./ (Z_W + Z_Cdl);
    Z_total    = Rs + Z_parallel;

    % --- Nyquist ---
    plot(ax_nyq, real(Z_total), -imag(Z_total), '-', ...
         'Color', colors(k,:), 'LineWidth', 2);
    % Đánh dấu điểm tần số thấp và cao
    plot(ax_nyq, real(Z_total(1)),   -imag(Z_total(1)),   'o', ...
         'Color', colors(k,:), 'MarkerFaceColor', colors(k,:), 'MarkerSize', 7);
    plot(ax_nyq, real(Z_total(end)), -imag(Z_total(end)), 's', ...
         'Color', colors(k,:), 'MarkerFaceColor', colors(k,:), 'MarkerSize', 7);

    % --- Bode biên độ ---
    loglog(ax_bode, f, abs(Z_total), '-', ...
           'Color', colors(k,:), 'LineWidth', 2);

    legend_entries{end+1} = cdl_label(Cdl); %#ok<AGROW>
end

% --- Định dạng Nyquist ---
grid(ax_nyq, 'on');
ax_nyq.XMinorGrid = 'on';
ax_nyq.YMinorGrid = 'on';
xlabel(ax_nyq, 'Z_{real} (Ω)',  'FontSize', 13, 'FontWeight', 'bold');
ylabel(ax_nyq, '-Z_{imag} (Ω)', 'FontSize', 13, 'FontWeight', 'bold');
title(ax_nyq,  'Đồ thị Nyquist', 'FontSize', 15, 'FontWeight', 'bold');
legend(ax_nyq, legend_entries, 'Location', 'best', 'FontSize', 11);
set(ax_nyq, 'FontSize', 11);

% --- Định dạng Bode ---
grid(ax_bode, 'on');
ax_bode.XMinorGrid = 'on';
ax_bode.YMinorGrid = 'on';
xlabel(ax_bode, 'Tần số (Hz)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel(ax_bode, '|Z| (Ω)',     'FontSize', 13, 'FontWeight', 'bold');
title(ax_bode,  'Đồ thị Bode - Biên độ', 'FontSize', 15, 'FontWeight', 'bold');
legend(ax_bode, legend_entries, 'Location', 'best', 'FontSize', 11);
xlim(ax_bode, [f1/1.5, fn*1.5]);
set(ax_bode, 'FontSize', 11);

sgtitle('Phân tích EIS - Rct=0, Warburg bật, Rs=100 Ω', ...
        'FontSize', 16, 'FontWeight', 'bold');

% --- Thông báo ---
disp('Thông số mô phỏng:');
disp(['  Rs    = ', num2str(Rs),    ' Ω']);
disp(['  Rct   = 0 Ω  (cố định)']);
disp(['  sigma = ', num2str(sigma), ' Ω.s^(-1/2)']);
disp(['  Dải tần số: ', num2str(f1), ' Hz – ', num2str(fn), ' Hz']);
disp('  Cdl:');
for k = 1:numel(Cdl_list)
    disp(['    ', cdl_label(Cdl_list(k))]);
end
end

function lbl = cdl_label(Cdl)
% Trả về chuỗi nhãn có đơn vị phù hợp cho giá trị Cdl
if Cdl >= 1e-3
    lbl = sprintf('Cdl = %.3g F',  Cdl);
elseif Cdl >= 1e-6
    lbl = sprintf('Cdl = %.3g µF', Cdl * 1e6);
else
    lbl = sprintf('Cdl = %.3g nF', Cdl * 1e9);
end
end
