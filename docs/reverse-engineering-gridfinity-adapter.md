# 逆向 Gridfinity Adapter（Gridfinity-Holder v24.f3d → src/gridfinity_adapter.scad）

把 1.0「Gridfinity-Frenchfinity Adapter」移植成 2.0 feature。它是个**斜置的
gridfinity 底板**：标准 42mm 网格的格盘倾斜架在墙上的法式卯榫（French cleat）上，
让 gridfinity bin 斜插展示/取放。方法见 `porting-playbook.md`；这里只记结论与坑。

参考样本只有 **4 个 STL**（全是 `a10.00`，gr/gc 变化），所以回归 R²=1.0 仅供参考——
单一 angle 无法独立验证 tilt 与 angle 的关系，下面会点明。

## 参数（f3d_inspect）

```
frenchfinity-gridfinity-adapter-v{version}-gr{grid_rows}-gc{grid_columns}-a{angle}
```
→ `grid_columns(gc)`、`grid_rows(gr)`、`angle(a)`。

- `grid_columns`：沿宽度 X 的 gridfinity 格数。
- `grid_rows`：沿斜置床面方向的格数。
- `angle`：床面倾斜旋钮。实测床面相对水平倾 **~20°**，而样本全是 `a10`，故推断
  **tilt = 2 × angle**（单一角度的推断，无第二组角度可证伪，见 .scad 头注）。

## 尺寸（stl_analyze regress，4 个样本，R²=1.0 仅供参考）

```
dx (宽 X) = 42.000*gc + 0.000        # 42mm gridfinity 标准间距，精确
dy (深 Y) = 39.467*gr + 14.095       # 39.467 = 42*cos(20)，14.10 = cleat+余量
dz (高 Z) = 14.365*gr + 8.833        # 14.365 = 42*sin(20)，8.83 = 底/前缘
```
与 .scad 头注完全一致（头注写 14.10 / 8.83，工具实测 14.095 / 8.833，四舍五入同值）。
`dx=42*gc` 精确印证用的就是标准 42mm 网格间距。

## 几何（重点）

1. **标准 gridfinity 42mm 网格**：床面是 cols×gc 的格盘，每格 42mm 间距、4mm 圆角。
2. **倒角卡槽（chamfered socket）**：每格往下挖一个 socket，顶部带 `chamfer=2.4` 的
   斜切唇口（gridfinity bin 的卡爪 lip），下接直壁口袋。半边尺寸
   `42/2 - clear/2 ≈ 20.75`（`clear=0.5` 是单格 X/Y 配合间隙），保证真实 gridfinity
   bin 能坐进去。
3. **楔形 tilt**：整块格盘绕 X 转 `tilt=2*angle`，前缘低（Y=0）、后缘高；床下用 hull
   把斜板底面与地面投影连成实心楔，撑到地面。
4. **cleat 在 +Y（背面）**：后缘加一道薄竖直墙给卯榫一个平面，`nut(bw, false)` 贴在
   背墙近顶处（和其它 holder 一致，公差自动只缩公舌）。

## 实现要点

- socket 用 `hull(顶部满尺寸 → 下沉 chamfer 后缩一圈)` 做倒角唇，再接 `linear_extrude`
  的直壁口袋；整体从 `z=0`（床面顶）向下挖（`gf_socket`）。
- 床面 `rotate([tilt,0,0])` 后，楔体 = `hull(斜板底面 cube, 地面 footprint cube)`。
  `foot = bl*cos(tilt)`（Y 投影）、`rise = bl*sin(tilt)`（Z 抬升）。
- cleat 复用 `nut(bw,false)`；位置 `up(rise+bed - slot_distance_top*2) back(foot+4)`。
- 文字 `v/gr/gc/a` 刻在背墙（X 读面），`labelLines` 自带「装不下溢到侧面」回退。
- `feature_*` 开头 `assert`：`gc>=1`、`gr>=1`、`0<angle<45`。

## 验证（mine vs 1.0 bbox，openscad 渲染对比）

| 样本 | 1.0 (dx/dy/dz) | mine (dx/dy/dz) | 差 |
|------|----------------|-----------------|----|
| gr2-gc3-a10 | 126.00 / 93.03 / 37.56 | 126.00 / 94.49 / 33.74 | dx 精确 / dy +1.46 / dz −3.82 |
| gr3-gc5-a10 | 210.00 / 132.50 / 51.93 | 210.00 / 133.96 / 48.10 | dx 精确 / dy +1.46 / dz −3.83 |

属**功能保真件**，偏差如实记录（两样本差值高度一致，是系统性而非随机）：

- **dx 精确**：42mm 网格还原无误。
- **dy 偏大 ~1.46mm**：本作的 cleat 段（背墙 4mm + 标准 `nut()` 凸出）合计 ~15.56mm，
  1.0 为 14.10mm，2.0 标准卯榫凸出略多。
- **dz 偏矮 ~3.83mm**：本作 dz = `rise + bed`（= 14.365*gr + 5），1.0 截距是 8.83，
  即 1.0 在床底/前缘多 ~3.83mm 厚度（或 cleat 略高出床面顶）。本作未复刻这段额外料，
  不影响 gridfinity 坐合与上墙，仅整体略矮。

## 样例

`generated_stl/gridfinity_adapter_*.stl`（构建产物，不入库）。
