% 超透镜半径分布生成器和嵌入式 FDTD 建模脚本模板。
%
% 工作流程：
%   单元相位库 -> 目标相位 -> 最近相位匹配半径图 -> Lumerical .lsf。
%
% 主要输出：
%   target_radius_<project_tag>.mat        完整 MATLAB 结果，便于检查
%   target_radius_<project_tag>_fdtd.mat   小型数值 MAT 备用文件
%   target_radius_<project_tag>.csv        CSV 备用文件
%   structure_lens_<project_tag>.lsf       嵌入式 FDTD 建模脚本
%
% 重要：
%   请在 Metalens 文件夹中运行本脚本。默认从
%   ../Unit/phix_527.mat 和 ../Unit/Tx_527.mat 读取单元相位库。

clear; clc;

cfg = struct();

% ===== 1. 项目名称和设计类型 =====
% project_tag 控制所有输出文件名。建议只使用英文字母、数字和下划线。
cfg.project_tag = 'hyperbolic_527_small';

% phase_model:
%   'hyperbolic' : 精确球面波相位，通常是聚焦设计的首选。
%   'quadratic'  : 近轴近似相位，适合用于对比和学习。
cfg.phase_model = 'hyperbolic';

% theta_deg 控制生成的 .lsf 中 FDTD 光源的入射角。
% 做离轴比较时，保持透镜相位不变，只修改 theta_deg。
% theta=10 表示平面波在 x-z 平面内倾斜 10 度入射。
cfg.theta_deg = 0;
cfg.phi_deg = 0;

% ===== 2. 单元相位库参数 =====
cfg.lambda_m = 527e-9;
cfg.period_m = 224e-9;
cfg.pillar_height_m = 600e-9;
cfg.sic_index = 2.67;
cfg.radius_start_m = 44e-9;
cfg.radius_stop_m = 92e-9;
cfg.unit_dir = fullfile('..', 'Unit');
cfg.phix_mat_file = fullfile(cfg.unit_dir, 'phix_527.mat');
cfg.Tx_mat_file = fullfile(cfg.unit_dir, 'Tx_527.mat');

% ===== 3. 超透镜尺寸和焦距 =====
% R_lens_m 会被取整到最接近的整数个晶格周期。
% 在下面的小型学习模型中，R_eff = 22*224 nm = 4.928 um。
cfg.R_lens_m = 5e-6;
cfg.f_m = 10e-6;

% ===== 4. 半径匹配选项 =====
% 初学时建议保持 false：只按最近相位选择半径。
% 如果希望轻微偏向高透射率半径，可以设为 true。
cfg.use_transmission_weight = false;
cfg.transmission_weight = 0.15;

% ===== 5. FDTD 建模选项 =====
cfg.substrate_thickness_m = 1.0e-6;
cfg.sim_z_min_m = -0.5e-6;
cfg.sim_z_max_m = 1.3e-6;
cfg.sim_margin_xy_m = 1.0e-6;
cfg.source_extra_span_m = 0.6e-6;
cfg.mesh_accuracy = 2;
cfg.simulation_time_s = 1000e-15;
cfg.output_fsp_name = ['Metalens_' cfg.project_tag '.fsp'];

out_file = ['target_radius_' cfg.project_tag '.mat'];
fdtd_mat_file = ['target_radius_' cfg.project_tag '_fdtd.mat'];
radius_csv_file = ['target_radius_' cfg.project_tag '.csv'];
x_csv_file = ['x_mask_' cfg.project_tag '.csv'];
y_csv_file = ['y_mask_' cfg.project_tag '.csv'];
lsf_file = ['structure_lens_' cfg.project_tag '.lsf'];

if ~isfile(cfg.phix_mat_file)
    error('找不到相位库文件：%s', cfg.phix_mat_file);
end

S = load(cfg.phix_mat_file);
if isfield(S, 'phix')
    phix = double(S.phix(:));
else
    names = fieldnames(S);
    phix = double(S.(names{1})(:));
end

radius_list_m = linspace(cfg.radius_start_m, cfg.radius_stop_m, numel(phix)).';

Tx = [];
if isfile(cfg.Tx_mat_file)
    ST = load(cfg.Tx_mat_file);
    if isfield(ST, 'Tx')
        Tx = double(ST.Tx(:));
    else
        names = fieldnames(ST);
        Tx = double(ST.(names{1})(:));
    end
end
if isempty(Tx) || numel(Tx) ~= numel(phix)
    Tx = ones(size(phix));
end

lib_phase = mod(phix, 2*pi);

N_periods = round(cfg.R_lens_m / cfg.period_m);
U = 2*N_periods + 1;
R_eff_m = N_periods * cfg.period_m;

x_mask = (-N_periods:N_periods) * cfg.period_m;
y_mask = x_mask;
[X, Y] = meshgrid(x_mask, y_mask);
R2 = X.^2 + Y.^2;
aperture_mask = R2 <= R_eff_m^2;

switch lower(cfg.phase_model)
    case 'hyperbolic'
        target_phase = -2*pi/cfg.lambda_m * (sqrt(R2 + cfg.f_m^2) - cfg.f_m);
    case 'quadratic'
        target_phase = -2*pi/cfg.lambda_m * R2 / (2*cfg.f_m);
    otherwise
        error('未知的 phase_model：%s', cfg.phase_model);
end
target_phase_wrapped = mod(target_phase, 2*pi);

target_radius = zeros(U, U);
target_index = zeros(U, U, 'uint16');
phase_error_rad = nan(U, U);
target_transmission = nan(U, U);
tx_norm = Tx ./ max(Tx);

for row = 1:U
    for col = 1:U
        if ~aperture_mask(row, col)
            continue;
        end
        dphi = angle(exp(1i * (lib_phase - target_phase_wrapped(row, col))));
        cost = abs(dphi);
        if cfg.use_transmission_weight
            cost = cost + cfg.transmission_weight * (1 - tx_norm);
        end
        [~, idx] = min(cost);
        target_index(row, col) = uint16(idx);
        target_radius(row, col) = radius_list_m(idx);
        phase_error_rad(row, col) = dphi(idx);
        target_transmission(row, col) = Tx(idx);
    end
end

stats = struct();
stats.U = U;
stats.N_periods = N_periods;
stats.R_eff_m = R_eff_m;
stats.num_sites_total = U * U;
stats.num_sites_in_aperture = nnz(aperture_mask);
stats.radius_min_nm = min(target_radius(aperture_mask)) * 1e9;
stats.radius_max_nm = max(target_radius(aperture_mask)) * 1e9;
stats.phase_error_rms_rad = sqrt(mean(phase_error_rad(aperture_mask).^2, 'omitnan'));
stats.phase_error_max_abs_rad = max(abs(phase_error_rad(aperture_mask)), [], 'omitnan');
stats.transmission_min = min(target_transmission(aperture_mask), [], 'omitnan');
stats.transmission_mean = mean(target_transmission(aperture_mask), 'omitnan');

save(out_file, 'cfg', 'target_radius', 'target_index', 'target_phase', ...
    'target_phase_wrapped', 'phase_error_rad', 'target_transmission', ...
    'aperture_mask', 'x_mask', 'y_mask', 'radius_list_m', 'lib_phase', ...
    'phix', 'Tx', 'stats', '-v7');

lambda_m = cfg.lambda_m;
period_m = cfg.period_m;
pillar_height_m = cfg.pillar_height_m;
f_m = cfg.f_m;
R_eff_m_for_fdtd = R_eff_m;
U_double = double(U);
save(fdtd_mat_file, 'target_radius', 'x_mask', 'y_mask', 'lambda_m', ...
    'period_m', 'pillar_height_m', 'f_m', 'R_eff_m_for_fdtd', 'U_double', '-v7');

writematrix(target_radius, radius_csv_file);
writematrix(x_mask(:), x_csv_file);
writematrix(y_mask(:), y_csv_file);

write_embedded_lsf(lsf_file, target_radius, cfg, U, R_eff_m);

fprintf('已保存完整 MATLAB 文件：%s\n', out_file);
fprintf('已保存 FDTD 备用 MAT 文件：%s\n', fdtd_mat_file);
fprintf('已保存嵌入式建模脚本：%s\n', lsf_file);
fprintf('网格尺寸：%d x %d，孔径内晶格点数：%d\n', U, U, stats.num_sites_in_aperture);
fprintf('R_eff = %.3f um，f = %.3f um，theta = %.2f deg\n', R_eff_m*1e6, cfg.f_m*1e6, cfg.theta_deg);
fprintf('透镜内半径范围：%.2f 到 %.2f nm\n', stats.radius_min_nm, stats.radius_max_nm);
fprintf('相位误差 RMS = %.4f rad，最大绝对值 = %.4f rad\n', stats.phase_error_rms_rad, stats.phase_error_max_abs_rad);
fprintf('透射率 最小/平均 = %.4f / %.4f\n', stats.transmission_min, stats.transmission_mean);

function write_embedded_lsf(file_name, target_radius, cfg, U, R_eff_m)
    fid = fopen(file_name, 'w');
    if fid < 0
        error('无法打开 %s 进行写入。', file_name);
    end
    cleanup_obj = onCleanup(@() fclose(fid));

    fprintf(fid, '# 嵌入式 527 nm SiC 超透镜建模脚本模板。\n');
    fprintf(fid, '# 由 generate_target_radius_template.m 自动生成。\n');
    fprintf(fid, '# 本脚本直接嵌入 target_radius 数值，从而避免使用 matlabload。\n\n');
    fprintf(fid, 'switchtolayout;\n');
    fprintf(fid, 'deleteall;\n\n');
    fprintf(fid, 'wavelength = %.16g;\n', cfg.lambda_m);
    fprintf(fid, 'period = %.16g;\n', cfg.period_m);
    fprintf(fid, 'pillar_height = %.16g;\n', cfg.pillar_height_m);
    fprintf(fid, 'f = %.16g;\n', cfg.f_m);
    fprintf(fid, 'sic_index = %.16g;\n', cfg.sic_index);
    fprintf(fid, 'theta_deg = %.16g;\n', cfg.theta_deg);
    fprintf(fid, 'phi_deg = %.16g;\n', cfg.phi_deg);
    fprintf(fid, 'U = %d;\n', U);
    fprintf(fid, 'lens_radius = %.16g;\n', R_eff_m);
    fprintf(fid, 'sim_margin_xy = %.16g;\n', cfg.sim_margin_xy_m);
    fprintf(fid, 'source_monitor_span = 2*lens_radius + %.16g;\n\n', cfg.source_extra_span_m);
    fprintf(fid, 'target_radius = matrix(U,U);\n');

    [rows, cols] = find(target_radius > 0);
    for k = 1:numel(rows)
        fprintf(fid, 'target_radius(%d,%d) = %.16g;\n', rows(k), cols(k), target_radius(rows(k), cols(k)));
    end

    fprintf(fid, '\naddcircle;\n');
    fprintf(fid, 'set("name","substrate");\n');
    fprintf(fid, 'set("x",0); set("y",0);\n');
    fprintf(fid, 'set("z min",%.16g);\n', -cfg.substrate_thickness_m);
    fprintf(fid, 'set("z max",0);\n');
    fprintf(fid, 'set("radius",lens_radius + 0.8e-6);\n');
    fprintf(fid, 'set("material","<Object defined dielectric>");\n');
    fprintf(fid, 'set("index",sic_index);\n\n');

    fprintf(fid, 'addgroup;\n');
    fprintf(fid, 'set("name","structure");\n\n');
    fprintf(fid, 'for(i=1:U) {\n');
    fprintf(fid, '    y_pos = -lens_radius + (i-1)*period;\n');
    fprintf(fid, '    for(j=1:U) {\n');
    fprintf(fid, '        radius_ij = target_radius(i,j);\n');
    fprintf(fid, '        if(radius_ij > 0) {\n');
    fprintf(fid, '            x_pos = -lens_radius + (j-1)*period;\n');
    fprintf(fid, '            addcircle;\n');
    fprintf(fid, '            set("name","nanopillar");\n');
    fprintf(fid, '            set("x",x_pos); set("y",y_pos);\n');
    fprintf(fid, '            set("z min",0); set("z max",pillar_height);\n');
    fprintf(fid, '            set("radius",radius_ij);\n');
    fprintf(fid, '            set("material","<Object defined dielectric>");\n');
    fprintf(fid, '            set("index",sic_index);\n');
    fprintf(fid, '            addtogroup("structure");\n');
    fprintf(fid, '        }\n');
    fprintf(fid, '    }\n');
    fprintf(fid, '}\n\n');

    fprintf(fid, 'addfdtd;\n');
    fprintf(fid, 'set("dimension","3D");\n');
    fprintf(fid, 'set("x",0); set("y",0);\n');
    fprintf(fid, 'set("x span",2*lens_radius + 2*sim_margin_xy);\n');
    fprintf(fid, 'set("y span",2*lens_radius + 2*sim_margin_xy);\n');
    fprintf(fid, 'set("z min",%.16g);\n', cfg.sim_z_min_m);
    fprintf(fid, 'set("z max",%.16g);\n', cfg.sim_z_max_m);
    fprintf(fid, 'set("mesh accuracy",%d);\n', cfg.mesh_accuracy);
    fprintf(fid, 'set("simulation time",%.16g);\n', cfg.simulation_time_s);
    fprintf(fid, 'set("x min bc","PML"); set("x max bc","PML");\n');
    fprintf(fid, 'set("y min bc","PML"); set("y max bc","PML");\n');
    fprintf(fid, 'set("z min bc","PML"); set("z max bc","PML");\n\n');

    fprintf(fid, 'addtfsf;\n');
    fprintf(fid, 'set("name","x plane");\n');
    fprintf(fid, 'set("injection axis","z-axis");\n');
    fprintf(fid, 'set("direction","Forward");\n');
    fprintf(fid, 'set("x",0); set("y",0);\n');
    fprintf(fid, 'set("x span",source_monitor_span);\n');
    fprintf(fid, 'set("y span",source_monitor_span);\n');
    fprintf(fid, 'set("z min",-0.35e-6);\n');
    fprintf(fid, 'set("z max",1.05e-6);\n');
    fprintf(fid, 'set("center wavelength",wavelength);\n');
    fprintf(fid, 'set("wavelength span",0);\n');
    fprintf(fid, 'set("polarization angle",0);\n');
    fprintf(fid, 'set("angle theta",theta_deg);\n');
    fprintf(fid, 'set("angle phi",phi_deg);\n\n');

    fprintf(fid, 'addpower;\n');
    fprintf(fid, 'set("name","monitor");\n');
    fprintf(fid, 'set("monitor type","2D Z-normal");\n');
    fprintf(fid, 'set("x",0); set("y",0);\n');
    fprintf(fid, 'set("x span",source_monitor_span);\n');
    fprintf(fid, 'set("y span",source_monitor_span);\n');
    fprintf(fid, 'set("z",pillar_height + 0.25e-6);\n');
    fprintf(fid, 'set("override global monitor settings",1);\n');
    fprintf(fid, 'set("frequency points",1);\n\n');

    fprintf(fid, 'save("%s");\n', cfg.output_fsp_name);
    fprintf(fid, '?"已建立超透镜工程：%s";\n', cfg.output_fsp_name);
    fprintf(fid, '?"网格 U = " + num2str(U);\n');
    fprintf(fid, '?"透镜半径 (um) = " + num2str(lens_radius*1e6);\n');
    fprintf(fid, '?"设计焦距 (um) = " + num2str(f*1e6);\n');
    fprintf(fid, '?"光源 theta (deg) = " + num2str(theta_deg);\n');
end
