% 绘制并检查从 Lumerical FDTD 导出的单元相位库。
%
% 设计其他波长或材料时，需要修改这些参数：
%   lambda_nm       : 文件名中使用的波长标签
%   radius_min_nm   : 扫描的起始半径
%   radius_max_nm   : 扫描的结束半径
%   如果导出的文件名不同，也要修改 phix_file/Tx_file

clear; clc; close all;

lambda_nm = 527;
radius_min_nm = 44;
radius_max_nm = 92;

phix_file = sprintf('phix_%d.mat', lambda_nm);
Tx_file = sprintf('Tx_%d.mat', lambda_nm);

S = load(phix_file);
T = load(Tx_file);

if isfield(S, 'phix')
    phix = double(S.phix(:));
else
    names = fieldnames(S);
    phix = double(S.(names{1})(:));
end

if isfield(T, 'Tx')
    Tx = double(T.Tx(:));
else
    names = fieldnames(T);
    Tx = double(T.(names{1})(:));
end

radius_nm = linspace(radius_min_nm, radius_max_nm, numel(phix)).';
phase_cycles = (unwrap(phix) - phix(1)) / (2*pi);

fprintf('单元相位库：%d 个半径采样点\n', numel(radius_nm));
fprintf('半径范围：%.2f 到 %.2f nm\n', min(radius_nm), max(radius_nm));
fprintf('相位覆盖：%.4f 个周期\n', max(phase_cycles) - min(phase_cycles));
fprintf('透射率 最小/平均/最大：%.4f / %.4f / %.4f\n', min(Tx), mean(Tx), max(Tx));

figure('Color', 'w');
yyaxis left;
plot(radius_nm, phase_cycles, 'ko-', 'LineWidth', 1.2, 'MarkerSize', 4);
ylabel('相位 / 2\pi');
yyaxis right;
plot(radius_nm, Tx, 'r-', 'LineWidth', 1.2);
ylabel('透射率 T');
xlabel('半径 (nm)');
title(sprintf('%d nm 单元相位库', lambda_nm));
grid on;

saveas(gcf, sprintf('unit_phase_library_%d.png', lambda_nm));
