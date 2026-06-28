# 逆向 Can-Holder（Can-Holder v42.f3d → src/can_holder.scad）

罐架 / 钻头架 / 喷罐架。方法见 `porting-playbook.md`；这里只记结论与坑。

> 2026-06-29（commit f61dd49）**按真实横截面几何重建**：旧版是「拟合 bbox」得来的，
> 形状完全错（曾把一根 30° 斜圆柱「杯」intersection 进盒子里）。现版以 6 个参考 STL
> 的侧向横截面逐一隔离参数测出，**不再用 bbox 驱动几何**。本文已对齐重建后的代码。

## 参数（f3d_inspect）

```
frenchfinity-can-holder-v{version}-cd{can_diameter}-pl{padding_left}-ci{can_inset}-p{padding}
                                                                              （+「-hole-bottom」变体）
```

各参数**实际驱动什么**（这是旧版搞错的根源，必须看准）：

- `can_diameter(cd)` —— 要插入的罐/管直径；孔径 = `cd + clearance`（clearance=2.4）。
- `padding(p)` —— **前墙/侧墙**料厚，定宽度 `dx = cd + 2p`。
- `can_inset(ci)` —— **孔深**，沿（倾斜的）孔轴方向量。
- `padding_left(pl)` —— **背墙**厚（朝墙/cleat 一侧）；并影响实心底高 `base = 9 + 0.3·pl`。
- `version(v)`。

`-hole-bottom` 变体 = 杯底排水/顶出孔，移植里折叠成 `can_holder_bottom`(`closed`/`open`)。

## 几何（真实形状）

一块**竖直的实心块**，宽 `cd+2p`，从**顶面钻一个深盲孔**，孔轴绕 X 倾 `tilt=9°`，
让罐子向外（顶部离墙）倾出、好抓：

- **背墙竖直**，厚 `pl`，位于 `Y=D`，顶部承 french cleat。
- **前面斜切**，与孔轴平行（顶部向 `-Y` 探出、底部缩回），使前/侧墙保持恒定 ~`p`。
  前面在高度 `z` 处的 Y：`front_y(z) = -ci·sin(tilt)·z/H`。
- **实心底** `base = 9 + 0.3·pl` 位于孔底之下。
- 盲孔从顶钻入：`bd = cd + 2.4`，`rotate([9,0,0])`，孔上方留 `rim=4` 实心唇（高侧）。
- `can_holder_bottom=="open"` 时，底部增加一个直径 6 的竖直排水/顶出孔（= 1.0 `-hole-bottom`）。
- 朝向：cleat 在 +Y（背面），与其它 holder 一致。

实现：块身是 `rotate([90,0,90]) linear_extrude(w)` 把 YZ 多边形
`[[D,0],[0,0],[yft,H],[D,H]]`（背-底、前-底、前-顶探出 `yft=-ci·sin(tilt)`、背-顶）
沿 X 拉满宽度；再 `difference` 减去倾斜盲孔（及可选排水孔）。**没有任何 intersection。**

## 尺寸

```
dx = cd + 2·p                                  # 精确，R²=1.0
H  = base + ci·cos(tilt) + rim                 # base=9+0.3·pl, tilt=9°, rim=4
D  = (cd+2.4) + p + pl                         # 背墙 Y（前墙 p + 孔 + 背墙 pl）
dy ≈ (cd+2.4) + p + pl + ci·sin(tilt) + cleat  # 含前面探出与 cleat 凸起
```

`0.3·pl` 的底高项与 `cos9°` 的孔倾，是横截面逐例测出的经验关系；**功能近似**，
在小 ci / 大 pl 的极端例会有几 mm 偏差（见验证）。

## 实现要点

- 固定常量（头注 + .scad）：`tilt=9`、`clearance=2.4`、`rim=4`、`drain=6`。
- cleat 复用 `nut(w,false)`，`up(H - slot_distance_top*2) back(D)`；公差自动（只缩公舌）。
- 文字 `v/cd/pl/ci/p` 5 行刻在**斜切前面**上，每行按其高度的 `front_y(z)` 定位，
  即使斜面也能贴面刻入；尺寸/居中复用 `labels.scad`（floor + fit 保证）。
  装不下时下半部分溢出到**背墙下区**（X-read 面）。
- `hintFileName` 另出紧凑 2 行布局并附 `hole` 状态。

## 验证

bbox（mine vs 1.0，单位 mm，dx/dy/dz）：

- cd12/pl10/ci70/p10：`32.00/55.20/85.14` vs `32.00/55.70/85.04`
- cd6/pl12/ci55/p10：`26.00/48.85/70.92` vs `26.00/49.94/71.34`
- cd20/pl26/ci80/p10：`40.00/80.76/99.82` vs `40.00/77.10/99.62`
- cd20/pl20/ci40/p10：`40.00/68.51/58.51` vs `40.00/67.52/65.30`（小 ci，dz 短 ~6.8）
- cd7/pl18/ci55/p8（open）：`23.00/53.85/72.72` vs `23.00/53.12/68.44`（大 pl，dz 长 ~4.3）

`dx` 逐 mm 命中。`dy` 多在 ±1mm 内（cd20/pl26/ci80 偏 +3.7）。`dz` 在正常 pl、
ci≥55 时 ±0.5mm；小 ci 或大 pl 的极端例偏几 mm（`0.3·pl` 底高项为功能近似）。
文字回归 `python3 test/test_labels_fit.py`：can_holder 各例通过。

## 样例

`generated_stl/can_holder_*.stl`（构建产物，不入库）。
