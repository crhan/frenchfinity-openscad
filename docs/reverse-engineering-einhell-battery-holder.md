# 逆向 Einhell 电池托（Einhell-Battery-Holder v12.f3d → src/einhell_battery_holder.scad）

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
电池托后仰角度，决定电池斜靠进槽的姿态。

## 尺寸（stl_analyze，仅 1 个样本，无法回归）

唯一样本 angle=20，实测 bbox：

```
dx (宽 X) = 55.00
dy (深 Y) = 111.11
dz (高 Z) = 89.17
```

因只有单点、没有第二个角度可对照，**做不了 `dim = k·angle + b` 这类拟合**；
只能用它做单样本 bbox 对位，确认移植件在 angle=20 下与 1.0 同尺寸。

## 几何

一个**斜靠式 U 形托**，由两段拼成：

- **后体（back body）**：底部竖直方块（`cube([w, ch, base+ch])`），背面 +Y 挂 cleat，
  电池斜靠时抵住它。
- **U 形托槽（cradle）**：floor + 两侧壁、顶开口、两端开口的沟槽
  （`difference` 挖出 inner 宽的通道）。从后体顶部 `translate([0, ch, base])` 后
  `rotate([angle+15, 0, 0])` 后仰——电池从开口落入、靠在后体上。
- 固定常量（实测）：外宽 `width=55`、内通道 `inner=41`、侧壁 `wall=7`、
  底厚 `floor=4`、槽长 `seat_len=115`、槽深 `channel=26`、后体高 `base=8`。

## 实现要点

- 后仰角是 `angle + 15`：`angle` 参数叠加固定的 15° 基准倾角（小 angle = 更平更前倾）。
- cleat 复用 `nut(w, false)`，挂在后体背面近顶处
  （`up(base+ch - slot_distance_top*2)` + `back(ch)`）；公差自动（只缩公舌）。
- 文字走 `labelLines()`：2 行 `v{version}` / `a{angle}` 刻在后体**背面**（X 读面，
  floored），装不下时溢到正面（`faceB`），对齐 `labels.scad` 约定、不自己手算。

## 验证

- bbox（mine vs 1.0）：唯一可比的 angle=20 一点 → 1.0 实测 `55 x 111.11 x 89.17`，
  与 .scad 头注参考值 `55 x 111 x 89` 一致。**单样本，仅作对位，无回归。**
- 文字 `v/a` 正读不镜像；布局回归 `test/test_labels_fit.py`。

## 样例

`generated_stl/einhell_battery_holder_*.stl`（构建产物，不入库）。
