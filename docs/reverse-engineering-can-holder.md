# 逆向 Can-Holder（Can-Holder v42.f3d → src/can_holder.scad）

罐架 / 钻头架 / 喷罐架。方法见 `porting-playbook.md`；这里只记结论与坑。
**功能保真 + 关键尺寸移植，非顶点克隆**：dx 精确，dy/dz 为多元拟合。

## 参数（f3d_inspect）

```
frenchfinity-can-holder-v{version}-cd{can_diameter}-pl{padding_left}-ci{can_inset}-p{padding}
                                                                              （+「-hole-bottom」变体）
```
→ `can_diameter(cd)` 内孔径、`padding(p)` 孔壁厚、`can_inset(ci)` 罐插入深、
`padding_left(pl)` 背/底料厚、`version(v)`。
`-hole-bottom` 变体 = 杯底排水/顶出孔，移植里折叠成 `can_holder_bottom`(`closed`/`open`)。

## 尺寸（stl_analyze，53 个样本）

regress 工具只做「单变量、R²>0.9」拟合，所以输出有限：

```
dx = 1.011*cd + 18.635   (R²=0.9943)    # 截距 18.6 其实是 2p（样本 p 多为 10）
dy = 1.147*cd + 48.282   (R²=0.9136)    # 弱拟合，dy 实为多元
dz                                      # 无单变量拟合达 R²>0.9 → 未输出（dz 由 ci 主导但多元）
```

单变量工具吃不下「2p」「多元」这些项。bbox 实测交叉验证后，真实关系（.scad 头注用的）是：

```
dx = cd + 2p                                              # 精确，R²=1.0
dz ≈ 0.867*ci + 0.323*cd + 0.268*pl + 1.55*p + 1.69      # 多元，±~1.5mm；0.867=cos30°→孔倾 30°
dy ≈ 0.94*cd + 0.755*pl + 1.432*p + 0.07*ci + 17.48      # 多元，R²≈0.997，±~1mm（含 cleat）
```

`dx` 实测精确：cd6/p10→26.00、cd20/p10→40.00、cd7/p8→23.00，逐 mm 命中。
`0.867≈cos30°` 直接说明孔轴绕 X 倾 ~30°，罐子向外上方倾出（离墙）。

## 几何

竖直背板（承 cleat + 文字）+ 前方融合一个**开口朝上的圆柱杯**：
- 杯外径 = `cd+2p`、内孔 = `cd`、壁厚 = `p`；整杯绕 X `rotate([30,0,0])` 倾斜。
- 杯用 `intersection` 裁进包络立方体 `[w,d,h]` → 平底/平顶/平背。
- `can_holder_bottom=="open"` 时杯底挖一个直径 6 的竖直排水孔（= 1.0 `-hole-bottom`）。
- 朝向：cleat 在 +Y（背面），与其它 holder 一致。

## 实现要点

- 固定常量：`plate_depth=8`、`base=6`、`drain=6`、`tilt=30`（头注 + .scad）。
- 杯心 `cup_y = d - plate - (cd/2+p)*0.4` 是经验定位，让倾斜杯底坐在前下方。
- cleat 复用 `nut(w,false)`，`up(h - slot_distance_top*2) back(d)`；公差自动（只缩公舌）。
- 文字 `v/cd/pl/ci/p` 5 行刻在**宽背面（X-read）**，装不下溢出到背板前面；
  `hintFileName` 另出 2 行紧凑布局并附 `hole` 状态。

## 验证

bbox（mine vs 1.0，单位 mm，dx/dy/dz）：
- cd6/pl10/ci70/p10：`26.00/48.86/82.50` vs `26.00/49.79/83.99`
- cd20/pl20/ci40/p10：`40.00/67.47/63.69` vs `40.00/67.52/65.30`

dx 精确；dy 短 ~0.05–0.9mm（标准 `nut()`，已知）；dz 短 ~1.5mm（包络公式为功能近似）。
文字回归 `test/test_labels_fit.py`：can_holder 4 例（ch_default/big/small/text_off）全过，总 62 例 OK。

## 样例

`generated_stl/can_holder_*.stl`（构建产物，不入库）。
