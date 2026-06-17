% 根据已经生成的超透镜半径矩阵写出 GDS 版图模板。
%
% 用法：
%   1. 先运行 ../Metalens/generate_target_radius_template.m，得到
%      target_radius_<project_tag>.mat。
%   2. 修改下面 cfg.project_tag 和 cfg.source_mat。
%   3. 在 MATLAB 中进入 GDS 文件夹，运行本脚本。
%
% 默认输出为反色版图：
%   曝光区域 = 单元方形背景
%   保护区域 = 中间圆形纳米柱 footprint

clear; clc;

cfg = struct();

% ===== 1. 输入设计文件 =====
% project_tag 应和 Metalens 设计脚本中的 cfg.project_tag 一致。
cfg.project_tag = 'hyperbolic_527_small';

% source_mat 默认读取相邻 Metalens 文件夹中生成的完整设计数据。
% 如果你的 target_radius_*.mat 放在其他位置，请直接修改这里。
cfg.source_mat = fullfile('..', 'Metalens', ['target_radius_' cfg.project_tag '.mat']);

% ===== 2. GDS 输出设置 =====
cfg.output_prefix = ['metalens_' cfg.project_tag];
cfg.layer_id = 1;
cfg.datatype = 0;
cfg.tone = 'inverse';
cfg.top_cell_name = 'TOP';
cfg.lens_cell_name = 'METALENS_TOP';
cfg.clear_cell_name = 'CLEAR_CELL';
cfg.inverse_cell_prefix = 'INV';
cfg.arc_points_per_quadrant = 12;
cfg.max_radius_fraction_in_cell = 0.98;

this_file = mfilename('fullpath');
out_dir = fileparts(this_file);
source_mat_abs = local_abs_path(out_dir, cfg.source_mat);

if ~isfile(source_mat_abs)
    error('找不到源半径矩阵 MAT 文件：%s', source_mat_abs);
end

S = load(source_mat_abs);
required_names = {'target_radius', 'target_index', 'radius_list_m', 'x_mask', 'y_mask'};
for k = 1:numel(required_names)
    if ~isfield(S, required_names{k})
        error('源 MAT 文件缺少变量：%s', required_names{k});
    end
end

target_radius = S.target_radius;
target_index = S.target_index;
radius_list_m = S.radius_list_m(:);
x_mask = S.x_mask(:).';
y_mask = S.y_mask(:).';

cfg_src = struct();
if isfield(S, 'cfg')
    cfg_src = S.cfg;
end
stats_src = struct();
if isfield(S, 'stats')
    stats_src = S.stats;
end

if isfield(cfg_src, 'period_m')
    period_um = cfg_src.period_m * 1e6;
else
    dx_um = abs(x_mask(2) - x_mask(1)) * 1e6;
    dy_um = abs(y_mask(2) - y_mask(1)) * 1e6;
    period_um = min(dx_um, dy_um);
end

if ~isequal(size(target_radius), size(target_index))
    error('target_radius 和 target_index 的矩阵尺寸不一致。');
end

out_gds = fullfile(out_dir, [cfg.output_prefix '_' cfg.tone '.gds']);
out_info = fullfile(out_dir, [cfg.output_prefix '_GDS_info.mat']);

fprintf('源 MAT 文件：%s\n', source_mat_abs);
fprintf('输出 GDS：%s\n', out_gds);
fprintf('网格尺寸：%d x %d，孔径内柱位数：%d\n', ...
    size(target_radius, 1), size(target_radius, 2), nnz(target_index > 0));
fprintf('周期 = %.6f um，GDS 层号 = %d/%d\n', period_um, cfg.layer_id, cfg.datatype);

if isfile(out_gds)
    delete(out_gds);
end

fid = fopen(out_gds, 'w');
if fid < 0
    error('无法打开输出 GDS 文件进行写入：%s', out_gds);
end
cleanup_obj = onCleanup(@() fclose(fid));

library_name = upper(regexprep(cfg.output_prefix, '[^A-Za-z0-9_]', '_'));
write_head(fid, library_name);

% 反色单元：每个 cell 写方形背景减去圆形柱 footprint 后的四个象限多边形。
write_clear_cell(fid, cfg, period_um);
write_inverse_unit_cells(fid, cfg, radius_list_m, period_um);

write_metalens_top(fid, cfg, target_index, x_mask, y_mask);

write_begin_struct(fid, cfg.top_cell_name);
write_sref(fid, cfg.lens_cell_name, [0, 0]);
write_end_struct(fid);

write_end_lib(fid);
delete(cleanup_obj);

gds_info = struct();
gds_info.source_mat = source_mat_abs;
gds_info.output_gds = out_gds;
gds_info.output_info = out_info;
gds_info.tone = cfg.tone;
gds_info.layer_id = cfg.layer_id;
gds_info.datatype = cfg.datatype;
gds_info.period_um = period_um;
gds_info.radius_list_m = radius_list_m;
gds_info.cfg_gds = cfg;
gds_info.cfg_src = cfg_src;
gds_info.stats_src = stats_src;
gds_info.num_aperture_sites = nnz(target_index > 0);
gds_info.note = '反色 GDS：方形曝光单元中保留圆形纳米柱 footprint。';
save(out_info, 'gds_info', '-v7');

fprintf('完成。已写出 GDS 信息文件：%s\n', out_info);

function abs_path = local_abs_path(base_dir, path_in)
    if isfolder(path_in) || isfile(path_in)
        f = java.io.File(path_in);
    else
        f = java.io.File(base_dir, path_in);
    end
    abs_path = char(f.getCanonicalPath());
end

function write_head(fid, name)
    write_record(fid, 0, 2, int16(3));
    d = current_gds_time_vector();
    write_record(fid, 1, 2, [d d]);
    write_record(fid, 2, 6, name);
    write_real8_record(fid, 3, [1e-3, 1e-9]);
end

function write_begin_struct(fid, name)
    d = current_gds_time_vector();
    write_record(fid, 5, 2, [d d]);
    write_record(fid, 6, 6, name);
end

function write_end_struct(fid)
    write_record(fid, 7, 0, []);
end

function write_end_lib(fid)
    write_record(fid, 4, 0, []);
end

function d = current_gds_time_vector()
    t = datetime("now");
    d = int16([year(t), month(t), day(t), hour(t), minute(t), round(second(t))]);
end

function write_clear_cell(fid, cfg, period_um)
    h = period_um / 2;
    write_begin_struct(fid, cfg.clear_cell_name);
    uv = [-h, h, h, -h, -h; -h, -h, h, h, -h];
    write_polygon(fid, cfg, uv);
    write_end_struct(fid);
end

function write_inverse_unit_cells(fid, cfg, radius_list_m, period_um)
    h = period_um / 2;

    for k = 1:numel(radius_list_m)
        namek = sprintf('%s%03d', cfg.inverse_cell_prefix, k);
        r_um = radius_list_m(k) * 1e6;
        r_um = min(max(r_um, 0), cfg.max_radius_fraction_in_cell*h);

        write_begin_struct(fid, namek);
        for q = 0:3
            uv = make_quadrant_inverse_polygon(h, r_um, q, cfg.arc_points_per_quadrant);
            write_polygon(fid, cfg, uv);
        end
        write_end_struct(fid);
    end
end

function uv = make_quadrant_inverse_polygon(h, r, q, n_arc)
    theta0 = q * pi/2;
    theta1 = (q + 1) * pi/2;
    theta_mid = 0.5 * (theta0 + theta1);

    p_circle_0 = r * [cos(theta0); sin(theta0)];
    p_axis_0 = h * [cos(theta0); sin(theta0)];
    p_corner = h * [sign(cos(theta_mid)); sign(sin(theta_mid))];
    p_axis_1 = h * [cos(theta1); sin(theta1)];
    p_circle_1 = r * [cos(theta1); sin(theta1)];

    theta_arc = linspace(theta1, theta0, n_arc + 1);
    arc = r * [cos(theta_arc); sin(theta_arc)];

    if size(arc, 2) > 2
        arc_mid = arc(:, 2:end-1);
    else
        arc_mid = zeros(2, 0);
    end

    uv = [p_circle_0, p_axis_0, p_corner, p_axis_1, p_circle_1, arc_mid];
    uv(abs(uv) < 1e-12) = 0;
    uv(:, end+1) = uv(:, 1);
end

function write_metalens_top(fid, cfg, target_index, x_mask, y_mask)
    write_begin_struct(fid, cfg.lens_cell_name);

    [rows, cols] = find(target_index > 0);
    n = numel(rows);
    for k = 1:n
        idx = double(target_index(rows(k), cols(k)));
        namek = sprintf('%s%03d', cfg.inverse_cell_prefix, idx);
        xy_um = [x_mask(cols(k)), y_mask(rows(k))] * 1e6;
        write_sref(fid, namek, xy_um);

        if mod(k, 1000) == 0 || k == n
            fprintf('  已放置 %d/%d 个单元\n', k, n);
        end
    end

    write_end_struct(fid);
end

function write_sref(fid, cellname, xy_um)
    write_record(fid, 10, 0, []);
    write_record(fid, 18, 6, cellname);
    write_record(fid, 16, 3, int32(round(xy_um(:).' * 1000)));
    write_record(fid, 17, 0, []);
end

function write_polygon(fid, cfg, uv)
    dbu_um = 1e-3;
    uv = round(uv / dbu_um) * dbu_um;

    if any(uv(:,1) ~= uv(:,end))
        uv(:,end+1) = uv(:,1);
    end

    d = diff(uv, 1, 2);
    keep = [true, any(d ~= 0, 1)];
    uv = uv(:, keep);
    if size(uv, 2) < 4
        return;
    end
    if any(uv(:,1) ~= uv(:,end))
        uv(:,end+1) = uv(:,1);
    end

    x = uv(1,:);
    y = uv(2,:);
    area2 = sum(x(1:end-1).*y(2:end) - x(2:end).*y(1:end-1));
    if abs(area2) < 1e-12
        return;
    end

    write_record(fid, 8, 0, []);
    write_record(fid, 13, 2, int16(cfg.layer_id));
    write_record(fid, 14, 2, int16(cfg.datatype));
    write_record(fid, 16, 3, int32(reshape(uv * 1000, 1, 2*size(uv,2))));
    write_record(fid, 17, 0, []);
end

function write_record(fid, rec_type, data_type, data)
    switch data_type
        case 0
            rec_len = uint16(4);
            fwrite(fid, rec_len, 'uint16', 0, 'ieee-be');
            fwrite(fid, uint8([rec_type, data_type]), 'uint8');
        case 2
            data = int16(data(:).');
            rec_len = uint16(4 + 2*numel(data));
            fwrite(fid, rec_len, 'uint16', 0, 'ieee-be');
            fwrite(fid, uint8([rec_type, data_type]), 'uint8');
            fwrite(fid, data, 'int16', 0, 'ieee-be');
        case 3
            data = int32(data(:).');
            rec_len = uint16(4 + 4*numel(data));
            fwrite(fid, rec_len, 'uint16', 0, 'ieee-be');
            fwrite(fid, uint8([rec_type, data_type]), 'uint8');
            fwrite(fid, data, 'int32', 0, 'ieee-be');
        case 6
            bytes = uint8(char(data));
            if mod(numel(bytes), 2) == 1
                bytes(end+1) = 0;
            end
            rec_len = uint16(4 + numel(bytes));
            fwrite(fid, rec_len, 'uint16', 0, 'ieee-be');
            fwrite(fid, uint8([rec_type, data_type]), 'uint8');
            fwrite(fid, bytes, 'uint8');
        otherwise
            error('不支持的 GDS 数据类型：%d', data_type);
    end
end

function write_real8_record(fid, rec_type, values)
    bytes = [];
    for v = values(:).'
        bytes = [bytes, real8_bytes(v)]; %#ok<AGROW>
    end
    rec_len = uint16(4 + numel(bytes));
    fwrite(fid, rec_len, 'uint16', 0, 'ieee-be');
    fwrite(fid, uint8([rec_type, 5]), 'uint8');
    fwrite(fid, uint8(bytes), 'uint8');
end

function b = real8_bytes(x)
    if x == 0
        b = zeros(1,8);
        return;
    end

    sign_bit = 0;
    if x < 0
        sign_bit = 128;
        x = -x;
    end

    exponent = 64;
    mantissa = x;
    while mantissa >= 1
        mantissa = mantissa / 16;
        exponent = exponent + 1;
    end
    while mantissa < 1/16
        mantissa = mantissa * 16;
        exponent = exponent - 1;
    end

    b = zeros(1,8);
    b(1) = sign_bit + exponent;
    for k = 2:8
        mantissa = mantissa * 256;
        b(k) = floor(mantissa);
        mantissa = mantissa - b(k);
    end
end
