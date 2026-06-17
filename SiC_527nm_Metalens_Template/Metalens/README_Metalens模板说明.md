# Metalens 超透镜模板说明

这个文件夹保存“整片超透镜设计 -> FDTD 建模 -> 后处理”的模板。若需要加工版图，后续再进入相邻的 `GDS` 文件夹，把本文件夹生成的半径矩阵转换为 GDS。

## 文件功能

- `generate_target_radius_template.m`  
  MATLAB 主模板。读取 `../Unit/phix_527.mat` 和 `../Unit/Tx_527.mat`，生成目标半径矩阵，并自动写出一个可在 Lumerical 中运行的嵌入式建模脚本。

- `farfield_template.lsf`  
  FDTD 运行结束后的远场后处理模板，生成 `x-z` 传播图和焦平面 `x-y` 图。

- `focus_metrics_template.lsf`  
  定量检查模板，输出实际焦点位置、x/y 方向 FWHM，以及三张线切图。

- `focus_efficiency_template.lsf`  
  初步聚焦效率模板。它的意义是估计进入焦斑桶的能量比例，适合用于同一规则下比较不同设计。

## 推荐使用流程

1. 复制整个 `Metalens_template` 文件夹，改成新项目名。
2. 在 `Unit` 文件夹中准备好当前波长、材料、周期、高度对应的 `phix_527.mat` 和 `Tx_527.mat`。
3. 打开 `Metalens/generate_target_radius_template.m`。
4. 修改顶部 `cfg` 参数。
5. 在 MATLAB 中运行该脚本，得到：
   - `target_radius_项目名.mat`
   - `target_radius_项目名_fdtd.mat`
   - `target_radius_项目名.csv`
   - `structure_lens_项目名.lsf`
6. 在 Lumerical FDTD 中运行 `structure_lens_项目名.lsf`，它会自动建立结构、光源、监视器，并保存 `.fsp`。
7. 点击 FDTD 的 `Run` 运行仿真。
8. 仿真结束后运行 `farfield_template.lsf`，得到 `Exz_项目名.jpg` 和 `Exy_项目名.jpg`。
9. 再运行 `focus_metrics_template.lsf`，得到三张线切图和 `focus_metrics_项目名.mat`。
10. 如果需要效率估计，再运行 `focus_efficiency_template.lsf`。
11. 如果需要二维加工版图，进入 `../GDS` 文件夹运行 `generate_gds_from_target_radius_template.m`。

## 最常修改的参数

在 `generate_target_radius_template.m` 中：

- `cfg.project_tag`：项目标签，决定输出文件名。
- `cfg.phase_model`：`hyperbolic` 或 `quadratic`。
- `cfg.theta_deg`：入射角。0 度是正入射；10 度用于离轴比较。
- `cfg.lambda_m`：工作波长。
- `cfg.period_m`：超原子周期。
- `cfg.pillar_height_m`：纳米柱高度。
- `cfg.sic_index`：材料折射率近似。
- `cfg.radius_start_m` / `cfg.radius_stop_m`：相位库半径范围，必须和 Unit 扫参一致。
- `cfg.R_lens_m`：目标半径。脚本会自动取最接近的整数周期半径。
- `cfg.f_m`：设计焦距。
- `cfg.mesh_accuracy`：FDTD 网格精度。学习小模型可用 2，更精细验证可提高，但会变慢。

在后处理 LSF 中：

- `project_tag`：必须和你希望输出的图名一致。
- `f`：设计焦距。
- `theta_deg`：必须和建模脚本中的入射角一致。
- `r`：图像显示范围。焦点离轴时，脚本会自动加 `f*sin(theta)` 的 x 偏移。
- `z` 范围：如果焦点不在图中，扩大 `z = linspace(...)` 的范围。

## 双曲相位与二次相位的区别

双曲相位：

```text
phi = -2*pi/lambda * (sqrt(x^2 + y^2 + f^2) - f)
```

它对应精确球面波聚焦，是常用的高 NA 超透镜设计相位。

二次相位：

```text
phi = -2*pi/lambda * (x^2 + y^2)/(2*f)
```

它是双曲相位在小孔径、低 NA 条件下的近轴近似。

因此在我们的小尺寸模型里，两者正入射结果非常相似；离轴 10 度后，二者在 `x-z` 传播图、实际焦点 z 位置和旁瓣上开始出现可观察差异。想让差异更明显，可以增大入射角或增大透镜半径。

## 防止报错

- 如果 Lumerical 报 `matlabload cannot open file`，优先使用本模板生成的嵌入式 `structure_lens_项目名.lsf`，它不依赖 `matlabload`。
- 不要在 Lumerical 脚本中使用 MATLAB 的 `...` 续行写法。
- 如果 `set("name","FDTD")` 报 `name is inactive`，删除这句；默认 FDTD 区域已经能正常使用。
- 如果 `set("angle theta",theta_deg)` 报错，在 Lumerical GUI 中点开 source，确认该版本的角度属性名；正常 2024 R1 中可以这样设置。
- 如果后处理报 monitor 没有数据，说明 `.fsp` 还没有成功 Run，或当前文件不是仿真完成后的文件。
- 如果焦点图完全空白，检查 `monitor` 名称、`z` 范围、`f` 和 `theta_deg` 是否对应当前模型。
- 生成 GDS 前，建议确认当前 `target_radius_项目名.mat` 已经是你希望导出版图的最终半径矩阵。
