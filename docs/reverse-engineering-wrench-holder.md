# 逆向 Wrench Holder（Wrench-Holder v26.f3d → src/wrench_holder.scad）

扳手架。方法见 `porting-playbook.md`；这里只记结论与坑。
属**功能 + 关键尺寸保真件**（非逐面复刻）：横截面随 `scale` 缩放、槽数随 `width` 增长。

> **2026-06-29 重建**（commit a137076）：旧版是 bbox 过拟合、形状是错的（渲染成一块满是方
> 形口袋的实心块）。现按 1.0 STL 的**逐张横截面 + 俯视渲染**重建为正确形状（开放通道 +
> 内侧切槽），下文几何/实现/验证均以重建后的 .scad 为准。

## 参数（f3d_inspect）

```
frenchfinity-wrench-holder-v{version}-ww{wrench_width}-w{width}-s{scale}
```
→ `width(w)`、`scale(s)`、`wrench_width(ww)`。三个 Fusion 用户参数：

- `width(w)`：架体往墙外伸出的长度（Y），越大槽越多。
- `scale(s)`：缩放横截面（X 宽、Z 高），不动 Y。
- `wrench_width(ww)`：槽口宽度，**只影响内部、不改 bbox**。

## 尺寸（stl_analyze，35 个样本）

```
dy (深 Y) = 1.000*w + 25.880        # R²=1.0000，精确（其中 10.88 是 cleat 公舌）
dx (宽 X) = 44.768*s + 4.490        # R²=0.9913，scale 主导宽度
dz (高 Z) = max(14.20, 11.2*s+7.4)  # scale 主导高度，带下限
```

- `dy` 与 `width` 是全仓库最干净的一条：斜率精确 1.0、截距 25.88（= base 15 + 卯榫 10.88）。
- `dz`：工具的单段线性拟合给 `9.931*s + 8.983`（R²=0.9799），但被小件下限拉偏。改用
  「下限 + 线性」两段式 `max(14.20, 11.2*s+7.4)` 后对样本几乎精确：
  s=0.40→14.20（实测 14.20）、s=1.00→18.60（实测 18.64）、s=1.78→27.34（实测 27.41）。
- `ww` 与 `dx/dy/dz` 都只是因为它和 s/w 同步增长才相关，实际只决定槽口宽，
  单独变 `ww` 时 bbox 不变 —— 与头注一致。

## 几何

朝前开口的**双轨扳手架**，cleat 在 +Y（后）。**没有地板**，两轨之间是开放通道：

- 后端一块**满宽 cleat 块**（X 满宽 `w`、Y 深 `base=15`、Z 满高 `h`），承载 french cleat
  卯榫。
- 从 cleat 往前**悬挑两条侧轨**（cantilever），各占 X 宽 18%（`rail=outer_width*0.18`），
  内缩 `margin=outer_width*0.11`，Y 长 = `width`，**只到 60% 高**（`rh=outer_height*0.60`，
  比 cleat 矮）。
- 两轨之间是**开放通道、无地板**——这是与旧错版（实心块/方口袋）的根本区别。
- 槽口（notch，槽宽 = `wrench_width`）从**轨顶**切进轨的**内侧边**（朝通道那一面）：
  切入 X 深 `ndepth=rail*0.7`、Z 深 `sd=outer_height*0.27`；轨的外侧边保持连续、保强度。
  两轨的内侧槽**对齐成对**。
- 扳手横放、落进对齐的一对内侧槽：**头搁在轨顶、柄悬在开放通道里**。
- 槽节距 `pitch = wrench_width + tooth`（`tooth=3.3mm`），槽数 = `max(1,floor((w-tooth)/pitch))`，
  靠 `span/y0` 居中。
- cleat 块中央一个 ⌀3 螺孔/料孔从底部贯穿（靠下）。

scale=1（ww8/w60）实测：cleat 块高 18.6，轨高 ~11（0.6h），槽深 ~5（0.27h），齿 ~3.3。

## 实现要点

- 横截面尺寸不直接存，用函数算：`outer_width()=44.77*s+4.49`、
  `outer_height()=max(14.20,11.2*s+7.4)`、`rail_height()=outer_height*0.60`、
  `slot_depth()=outer_height*0.27`、`rail_width()=outer_width*0.18`、`margin()=outer_width*0.11`。
- body 的 Y 长 = `width + base(15)`；cleat 复用 `nut(w,false)` 贴后顶
  （`up(h-2*slot_distance_top) back(L)`），公差自动。
- 文字：轨太矮（仅一行高），故 **version + ww 平刻在 cleat 顶面**（`labelTop`，唯一宽敞平面，
  字朝 X 读、行沿 Y 堆叠、自顶面下沉）；**w / s 各刻在一条长轨的外侧面**（`labelFace`，Y 读、
  朝向正确）：右轨（+X）刻 `w`、左轨（-X）刻 `s`。后端被满宽 cleat 挡住，不刻正/背面。

## 验证（mine vs 1.0 bbox）

| 样本 (ww/w/s) | mine dx/dy/dz | 1.0 dx/dy/dz |
|---|---|---|
| 8.0 / 60 / 1.00  | 49.26 / 84.85 / 18.60 | 48.49 / 85.88 / 18.64 |
| 3.4 / 27 / 0.40  | 22.40 / 51.85 / 15.66 | 26.15 / 52.88 / 14.20 |
| 15.0 / 74 / 1.78 | 84.18 / 98.85 / 27.34 | 86.31 / 99.88 / 27.41 |

- `dy` 全程稳定短 ~1.0mm（84.85/51.85/98.85 vs 85.88/52.88/99.88）：标准 `nut()` 公舌实际
  伸出略小于名义 10.88，三档常量偏差、已知。
- `dx` 中/大件吻合（+0.77 / -2.13）；**小件偏窄 ~3.7mm**（22.40 vs 26.15）：线性式在小 scale
  端低估宽度（dx 也有下限行为，线性模型没建）。
- `dz` 中/大件精确（18.60 vs 18.64、27.34 vs 27.41）；**小件偏高 ~1.5mm**（被 floor 到 14.20
  时，cleat 定位 `up(h-2*slot_distance_top)` 为负，卯榫锁头下探到 z≈-1.46，使 mine dz=15.66）。
- 文字回归测试 `python3 test/test_labels_fit.py`（含 wrench 例）通过。

## 样例

`generated_stl/wrench_holder_*.stl`（构建产物，不入库）。
