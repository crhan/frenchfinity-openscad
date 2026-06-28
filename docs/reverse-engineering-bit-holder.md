# 逆向 Bit / Drill Holder（Bit-Holder v68.f3d → src/bit_holder.scad）

钻头 / 批头收纳座的移植。方法见 `porting-playbook.md`。1.0 共 85 个 STL 样本 + 两个工程文件（v59、v68）。

> **2026-06-29 重建（commit d3676d9）**：行向由「直立块向 Y 外伸的长悬臂」改为
> 「沿斜面**向上叠**成紧凑面板」——rows 现在向上叠、不再向外伸，bbox 随之贴近 1.0。

## 参数（f3d_inspect）

v68 抽不到用户参数，改读 **Bit-Holder v59.f3d**：

```
frenchfinity-bit-holder-v{version}-r{rows}-c{columns}-hd{hole_diameter}-hp{hole_padding}-a{angle}-h{height}
```
→ `rows(r)`、`columns(c)`、`hole_diameter(hd)`、`hole_padding(hp)`、`angle(a)`、`height(h)`。
所有 85 个样本 **a=30**（斜面一律后仰 30°，钻头朝外上方探出，好抓取）。

## 几何（斜置料板 + r×c 孔网格 + 竖直背板 cleat）

整体是一块**斜置料板（slab）**铰接在一面**竖直背板**上：

- **料板** `bit_holder_slab()`：`cube([w, len, t])`，板面钻 **r×c 孔网格**，孔轴垂直板面、钻深 `h`。
  - 宽 `w = c*hd + (c+1)*hp`（X 向；列间**共享内壁**，两侧各留一道 hp）——与 1.0 一致，逐列精确。
  - 长 `len = r*(hd+hp) + hp`（顺斜面方向；行间也**共享内壁**，两端各留 hp）。
  - 厚 `t = h + floor(6)`（孔深 + 背后实心底）。
  - 孔心：列 `hp + hd/2 + cc*(hd+hp)`、行 `hp + hd/2 + rr*(hd+hp)`——**两轴同 pitch `hd+hp`、同享内壁**。
- **斜置**：料板绕 X 轴自水平后仰 `angle`（`translate([0,plate,0]) rotate([a,0,0])`，铰接在背板正面；
  等价地，孔轴自竖直方向倾斜 `angle`）。行因此**沿斜面向上叠**，整体保持 1.0 那种紧凑墙板。
- **背板** `cube([w, plate(6), plate+t])`：竖直、位于 +Y，承载 french cleat
  （`nut(w,false)` 镜像到 -Y，置于 `up(bh - 2*slot_distance_top)`，公差自动）。
- 文字走 `labelLines`：刻在**背板**（X 读面、-Y 侧）floored，放不下溢到正面；字号自适应。

> **已修 (2026-06-29)**：重建初稿曾把钻孔 cylinder 起点放在 `z = t+1`（板顶 `z = t` 之上
> 1mm），与料板不相交，`difference()` 成了空操作、孔没真减出来（bbox 不变故未即时发现）。
> 已改为从板顶向下钻 `z ∈ [t-height, t+1]`，留 `floor` 实底。下方 bbox 验证不受影响（孔为内部特征）。

## 尺寸（mine vs 1.0 bbox）

新设计三维都可由几何直接给出（不再像旧直立块那样 dy 无法回归）：

```
dx = c*hd + (c+1)*hp                 （精确）
dz = len*sin a + t*cos a             （slab 主导，> 背板高 plate+t）
dy = len*cos a + plate + cleat 伸出   （cleat 舌伸到 -Y ≈ -9.85 决定下界）
```

```
r1c1·hd10·hp10·a30·h20      dx       dy       dz
mine                      30.00    41.83    37.52
1.0                       30.50    37.29    40.25
diff                      -0.50    +4.54    -2.73

r3c1·hd6.5·hp12·a30·h16     dx       dy       dz
mine                      30.50    74.31    52.80
1.0                       31.00    70.64    55.50
diff                      -0.50    +3.67    -2.70
```

- **dx 逐列精确**（差 -0.5 为 1.0 外圆角/外偏）。
- **dy/dz 已贴近 1.0**：旧直立块单行 dy 曾偏 +8.56，重建后腰斩到 +4.54、且不随行数发散
  （r3 仍只 +3.67）。残差来自 cleat 在 -Y 的伸出量、行/列 pitch 与 1.0 圆角的微差。

## 样例

`generated_stl/bit_*.stl`（构建产物，不入库）。
