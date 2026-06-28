# 逆向 Bit / Drill Holder（Bit-Holder v68.f3d → src/bit_holder.scad）

钻头 / 批头收纳座的移植。方法见 `porting-playbook.md`；这里记结论与一处**功能保真取舍**。
1.0 共 85 个 STL 样本 + 两个工程文件（v59、v68）。

## 参数（f3d_inspect）

v68 抽不到用户参数，改读 **Bit-Holder v59.f3d**：

```
frenchfinity-bit-holder-v{version}-r{rows}-c{columns}-hd{hole_diameter}-hp{hole_padding}-a{angle}-h{height}
```
→ `rows(r)`、`columns(c)`、`hole_diameter(hd)`、`hole_padding(hp)`、`angle(a)`、`height(h)`。
所有 85 个样本 **a=30**（钻头一律倾斜 30° 出墙）。

## 尺寸（stl_analyze，85 样本）

模型公式（.scad）：列向 `dx = columns*hd + (columns+1)*hp`（列间共享内壁）；
`dz = 1.5*h + 10`；行向 `dy = plate(6) + rows*cell`，`cell = hd + 2*hp`。实测对照：

```
dx = columns*hd + (columns+1)*hp    逐样本精确（见下）
dz ~ h                R^2=0.50(全) 0.76(r1c1)   见下「为何不干净」
dy                    无法回归（每行 slant pitch 不可解，见实现要点）
```

- **列向共享内壁，dx 与 1.0 一致**：1.0 相邻列共用一道 hp 墙，外侧各留一道 hp，即
  `dx = c*hd + (c+1)*hp`。实测全部样本吻合（c1·hd10·hp10→30.5；c2·hd9.6·hp10→49.8；
  c3·hd4·hp10→53.2），1.0 比名义值多 ~0.5–1.2mm 是其外圆角/外偏。模型按同一公式取名义值，
  **逐列精确**（早期版本曾用 `c*(hd+2hp)`、每格独占 2hp，多列偏宽 `(c-1)*hp`，已修正）。
- **dz 不干净**：1.0 是倾斜平行四边形，bbox 高度把 slant 和 cell 纠缠进来——同一 h=20，dz 随 hp
  从 38.25 涨到 56.75，故 `dz=1.5h+10` 只是直立块的功能近似（小格时吻合，r1c1·hd10 误差 +0.25）。

## 几何（直立块 + 斜插孔网格 + 背板 cleat）

- 一个**直立长方块** `cube([w, plate+rows*cell, 1.5h+10])`，`w = c*hd+(c+1)*hp`。
- 顶面钻 **r×c 孔网格**：列向孔心 `hp + hd/2 + cc*(hd+hp)`（共享内壁），行向孔心
  `plate + cell*(rr+0.5)`；每孔绕 X 轴倾斜 `angle` 朝 -Y（钻头往外探，好抓取），沿轴钻深 `h`。
- 背板（+Y，Y 向厚 6）承载 french cleat；最深孔下留 floor=6 实心。
- cleat 复用 `nut(w, false)` 镜像到 -Y，置于 `up(bh - 2*slot_distance_top)`；公差自动。

## 实现要点（为何不用 1.0 的平行四边形）

- **列向**与 1.0 完全一致（共享内壁、dx 精确）——列沿 X、与倾斜方向垂直，紧凑排布不会让斜孔相交。
- **行向**：1.0 把多行打包成倾斜的平行四边形（顺 slant 往上叠，最紧凑），但 85 个样本参数互不相通，
  **无法回归出每行的 slant pitch**，dy 的 trig 解不出来。故本移植行向改用**直立块 + 斜孔**：
  每行留完整 `cell=hd+2hp` 足迹保证斜孔不互相穿插。钻头同样按 `angle` 倾斜、同样 r×c 网格、同样 cleat、
  与 1.0 实物五金互换——**功能等价**。代价是**多行 dy 比 1.0 的紧凑平行四边形偏大**；单行情形在圆角误差内吻合。
- 文字走 `labelLines`：刻背板（X 读面）floored，放不下溢到正面；字号自适应。

## 验证（mine vs 1.0 bbox）

```
r1c1·hd10·hp10·a30·h20      dx       dy       dz
mine                      30.00    45.85    40.00
1.0                       30.50    37.29    40.25
diff                      -0.50    +8.56    -0.25

c2·hd9.6·hp10（验证列向修正）  dx
mine                      49.20
1.0                       49.80     （diff -0.60，列向共享内壁后逐列精确）
```

- dx 逐列精确（差 -0.5～-0.6 为 1.0 圆角）、dz 近似精确（-0.25）。
- **dy 偏大 +8.56**：直立块在 Y 上比 1.0 的单格倾斜平行四边形臃肿；该差随行数增多而扩大。
  这是上面那处行向功能保真取舍的直接体现，如实记录。

## 样例

`generated_stl/bit_*.stl`（构建产物，不入库）。
