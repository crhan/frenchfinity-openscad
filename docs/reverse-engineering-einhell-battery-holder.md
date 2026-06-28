# 逆向 Einhell 电池托（Einhell-Battery-Holder v12.f3d → src/einhell_battery_holder.scad）

> **2026-06-29 重建（commit ab043e6）**：早先那版移植成了深 U 形摇篮槽，是错的。
> 重新比对单样本 STL 的截面/侧视后改为**薄平板斜座**——本文已按当前实现重写。

又一个移植范例。方法见 `porting-playbook.md`；这里只记结论与坑。

**特殊情况：1.0 源目录只有 1 个 STL**
(`frenchfinity-einhell-battery-holder-v1-a20.00.stl`，angle=20)，**无法做回归**
（回归需要多个样本拟合参数↔尺寸）。所以本件是**功能保真移植**：`angle` 是唯一参数，
其余几何全部固定到 Einhell PXC 电池、并从这一个 STL 实测，未经回归。

## 参数（f3d_inspect）

```
frenchfinity-einhell-battery-holder-v{version}-a{angle}
```
→ 暴露的参数只有 `version` 和 `angle`。移植版以 `angle`（默认 20）为唯一可调项：
电池座的后仰角度，决定电池斜插进槽的姿态。

## 尺寸（stl_analyze，仅 1 个样本，无法回归）

唯一样本 angle=20，1.0 实测 bbox：

```
dx (宽 X) = 55.00
dy (深 Y) = 111.11
dz (高 Z) = 89.17
```

因只有单点、没有第二个角度可对照，**做不了 `dim = k·angle + b` 这类拟合**；
只能用它做单样本 bbox 对位，确认移植件在 angle=20 下与 1.0 同尺寸。

## 几何

不是 U 形摇篮，而是一块**薄平板斜座**，由两段拼成：

- **底座方块（base block）**：底部一个小竖直方块 `cube([w, base_d, base_h])`
  （`base_d=22` 深、`base_h=30` 高），背面 +Y 近顶处挂 cleat；正面 -Y 刻字。
  电池斜插时由它把整件抬高、并承担与墙板的连接。
- **薄座板（seat slab）**：从底座顶部背缘 `translate([0, base_d, base_h-slab])`
  起，`rotate([tilt, 0, 0])` 后仰立起。座板本体是一块薄板（`slab=12` 厚），
  两侧各留一条导轨（`wall=8` 宽、`rail=10` 高），中间挖出 `inner=38` 宽的通道
  （`difference` 减掉，**顶开口、两端都开口**）。Einhell PXC 电池就从这条通道
  上方/端口滑入，靠两条导轨夹住、沿座板斜躺。
- 固定常量（实测，对齐电池）：外宽 `width=55`、内通道 `inner=38`、单侧导轨
  `wall=8`、座板厚 `slab=12`、导轨高 `rail=10`、座长 `seat_len=105`、
  底座深 `base_d=22`、底座高 `base_h=30`。

## 实现要点

- 座板倾角是 `tilt = angle + 11`（`einhell_battery_holder_tilt()`）：`angle` 叠加
  固定 11° 基准。angle=20 → 31° 是给出 `55x111x89` 那条 bbox 的取值；小 angle = 更平。
- cleat 复用 `nut(w, false)`，挂在底座背面近顶处
  （`up(base_h - slot_distance_top*2)` + `back(base_d)`）；公差自动（只缩公舌）。
- 文字走 `labelFace()`：2 行 `v{version}` / `a{angle}` 刻在**底座正面**（-Y，X 读面，
  不翻转——背面被 cleat 占用）。face 描述符 `["x", w/2, 0, w, 2, base_h-2]`，
  对齐 `labels.scad` 约定、不自己手算。

## 验证

- bbox（mine vs 1.0）：唯一可比的 angle=20 一点 → 我的件实测 `55 x 112 x 90.94`，
  1.0 实测 `55 x 111.11 x 89.17`，吻合。**单样本，仅作对位，无回归。**
- 文字 `v/a` 正读不镜像；布局回归 `test/test_labels_fit.py`。

## 样例

`generated_stl/einhell_battery_holder_*.stl`（构建产物，不入库）。
