# Unit 超原子库模板说明

这个文件夹保存“单元扫参 -> 相位库”的模板。它对应我们前面学习过的 `Unit_SiC` 部分。

## 目标

先用周期边界条件模拟一个超原子单元，扫描圆柱半径，得到：

- `phix_527.mat`：不同半径对应的透射相位，单位是 rad。
- `Tx_527.mat`：不同半径对应的透射率。

后续整片超透镜不是重新优化每一根柱子，而是把理想相位分布映射到这个相位库上，选择最接近目标相位的半径。生成 GDS 时也会继续使用这个半径库索引，使版图中的每个 cell 和相位库中的半径一一对应。

## 当前 527 nm SiC 基础参数

- 工作波长：`527 nm`
- 周期：`224 nm`
- SiC 圆柱高度：`600 nm`
- 半径扫描范围：`44 nm` 到 `92 nm`
- 半径步长：`0.5 nm`
- 扫描点数：`97`
- SiC 折射率近似：`n = 2.67`

## 操作流程

1. 在 Lumerical FDTD 中打开或新建单元模型。
2. 设置周期边界条件，建立半径 sweep，sweep 名称建议保持为 `radius`。
3. 运行 sweep。
4. 打开 `unit_sweep_template.lsf`，确认顶部参数和 sweep 结果名正确。
5. 运行 `unit_sweep_template.lsf`，得到 `phix_527.mat` 和 `Tx_527.mat`。
6. 在 MATLAB 里运行 `plot_unit_phase_library_template.m` 检查相位覆盖和透过率。
7. 完成整片超透镜设计并确认半径矩阵后，可进入 `../GDS` 文件夹生成版图。

## 最常修改的参数

- 改波长：同步修改 FDTD 光源波长、监视器波长、`wavelength_tag`。
- 改材料：同步修改 FDTD 材料或折射率，并重新扫参。
- 改高度/周期：必须重新扫参；旧相位库不能直接复用。
- 改半径范围/步长：修改 sweep 设置，并同步修改 `radius_min_nm`、`radius_max_nm`、`radius_points`。

## 防止报错

- `getsweepdata(sweep_name,"phase")` 和 `getsweepdata(sweep_name,"T")` 中的结果名必须和 FDTD sweep 结果完全一致。
- 如果 MATLAB 设计脚本找不到 `phix_527.mat`，优先检查文件是否放在模板 Metalens 脚本中设置的 `unit_dir` 路径。
- 设计不同波长时不要只改文件名，单元模型本身也必须重新仿真。
- 如果后续要导出 GDS，必须确保 `target_index` 对应的半径顺序和本相位库的半径顺序一致。
