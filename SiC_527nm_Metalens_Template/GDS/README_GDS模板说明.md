# GDS 版图生成模板说明

这个文件夹保存“半径矩阵 -> GDS 版图”的模板。它用于把 `Metalens` 文件夹中已经生成并检查过的 `target_radius_项目名.mat` 转换成可在 KLayout 等版图软件中打开的 `.gds` 文件。

## 文件功能

- `generate_gds_from_target_radius_template.m`  
  MATLAB GDS 生成模板。读取 `target_radius`、`target_index`、`radius_list_m`、`x_mask` 和 `y_mask`，写出反色 GDS 版图和一份 GDS 信息 `.mat` 文件。

## 推荐使用流程

1. 先运行 `../Metalens/generate_target_radius_template.m`，得到 `target_radius_项目名.mat`。
2. 确认该半径矩阵已经用于 FDTD 建模或至少完成基本检查。
3. 打开 `GDS/generate_gds_from_target_radius_template.m`。
4. 修改顶部参数：
   - `cfg.project_tag`：与 `Metalens` 设计脚本中的 `cfg.project_tag` 一致。
   - `cfg.source_mat`：目标半径矩阵 `.mat` 的路径。
   - `cfg.layer_id` / `cfg.datatype`：加工平台要求的 GDS 层号。
5. 在 MATLAB 中进入 `GDS` 文件夹并运行脚本。
6. 用 KLayout 打开输出的 `metalens_项目名_inverse.gds` 检查版图。

## 输出文件

脚本默认生成：

- `metalens_项目名_inverse.gds`：反色 GDS 版图。
- `metalens_项目名_GDS_info.mat`：记录输入 MAT 路径、层号、周期、cell 命名、设计参数等信息。

## 版图结构

默认输出为反色版图：

```text
曝光区域 = 单元方形背景
保护区域 = 中间圆形纳米柱 footprint
```

GDS 层级结构包括：

- `TOP`：顶层 cell。
- `METALENS_TOP`：整片超透镜排布 cell。
- `INV001` 到 `INVxxx`：不同半径对应的反色单元 cell。
- `CLEAR_CELL`：完整方形曝光单元，预留备用。

脚本使用 `target_index(i,j)` 选择对应的 `INVxxx` 单元，并按 `x_mask/y_mask` 坐标逐个放置到 `METALENS_TOP` 中。因此 GDS 版图和 MATLAB/FDTD 使用的半径矩阵一一对应。

## KLayout 检查要点

打开 GDS 后建议检查：

1. 顶层 cell 是否为 `TOP`。
2. 是否能看到 `METALENS_TOP`。
3. 层号是否符合加工要求，默认是 `1/0`。
4. 用 Ruler 量测主图案直径，是否约等于 `2*R_eff`。
5. 先保持层级查看，不要急着 flatten。

## 注意事项

- GDS 只描述二维版图，不包含柱高、材料折射率、光源、monitor 等三维仿真信息。
- 当前模板默认生成反色版图，是否符合真实加工流程需要和加工平台确认。
- 如果加工平台需要正色柱图案，可以在本脚本基础上把单元 cell 改成圆形 pillar polygon。
- 建议先用小口径模型测试 GDS 写出和打开，再生成大口径版图。
- 生成大尺寸超透镜时，GDS 文件可能很大，写入过程中不要中断 MATLAB。
