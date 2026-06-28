# 逆向 Round Hanging Holder（Round-Hanging-Holder v8.f3d → src/round_hanging_holder.scad）

第三个移植范例。方法见 `porting-playbook.md`；这里只记结论与坑。

> **2026-06-29 重建（commit f159bd0）**：旧版误加了一道**全高前壁**、只在中间挖坑，
> 看上去像个封闭盒子。已按 1.0 真实形态重写——**前面全开、无前壁**，顶部在后壁之前
> 整段敞开。本文同步更新到当前实现。

## 参数（f3d_inspect）

```
frenchfinity-round-hanging-holder-v{version}-v{version}-td{tool_diameter}-hd{holder_depth}-bhw{bottom_hole_width}-id{inset_depth}
```
→ `tool_diameter(td)`、`holder_depth(hd)`、`bottom_hole_width(bhw)`、`inset_depth(id)`。

## 尺寸（stl_analyze，仅 4 个样本）

```
dz (高 Z) = td + 10            R²=1.0
dx (宽 X) = td + 10            （bhw=20 的样本成立；见下方坑）
dy (深 Y) = holder_depth + 20.88   R²=1.0（含后壁卯榫）
```

固定结构常量（绝对值，取自 1.0）：侧壁 5mm（每侧）、前/后端壁 5mm、Z 向余料 10mm。

## 几何

一条**沿 Y（前后向）的半圆托槽**（r=td/2）挖进块体顶部，圆形工具横躺其中：

- **托槽中心靠近块顶**：`zc = 高 - td/2 = td/2 + 10`，谷底 z=10；工具顶 ≈ 块顶（上半露出）。
- **前面全开，无前壁**——圆形工具从前方滑入。后壁之前的**整段顶部都被切掉**：
  两侧壁被削到托槽中心高度（zc），只留下后端那道全高墙。所以**侧视轮廓是
  「实心底座 + 后方高颈」的 L 形**，不是盒子。
- **后壁**（最后 5mm，全高）承载 french cleat（`nut(w, false)`，公舌自动缩 0.25mm）。
- 托槽下方一条 **bhw 宽的槽**从前贯到后壁、直通底部（推出 / 悬挂开口）。
- **inset_depth**：托槽圆柱向后壁多挖 id（工具在后壁里的座孔深度，受限 id≤5 不穿透后壁）。
- **刻字在两侧壁外表面**（Y 读面，z=2..zc-2）：前面已开、后壁被 cleat 占用，故移到左右侧壁；
  `labelLines` 触底字号、左壁装不下溢到右壁。

## 坑

1. **dx 的 bhw 干扰建不了模**：4 个样本里 bhw=20 的都满足 dx=td+10，但唯一 bhw=9 的样本
   dx 宽出约 10mm（td60 → 1.0 是 80.12，本实现取 td+10=70）。样本太少无法可靠建模这个交互，
   遂取干净的 dx=td+10（同 rectangular 的 hole-shrink 处理）。dx 偏差仅在该离群样本出现。
2. **刻字别再刻前壁**：前面是开口、后壁被 cleat 占着——只能刻两侧壁外表面（Y 读面）。
   右壁(+X) `rotate([90,0,90])`、左壁(-X) `rotate([90,0,-90])`，统一走 `labelFace`，别手转。
3. dx 非整数（如 td59 的 69.66）来自外缘微小圆角，本实现用平壁，差 <1mm（离群点除外）。

## 验证

bbox（mine vs 1.0）：

| 参数 | mine dx/dy/dz | 1.0 dx/dy/dz |
| --- | --- | --- |
| td39 hd21 bhw20 id5 | 49 / 40.85 / 49 | 49 / 41.88 / 49 |
| td59 hd9 bhw20 id2.25 | 69 / 28.85 / 69 | 69.66 / 29.88 / 69 |
| td60 hd24 bhw9 id2.25 | 70 / 43.85 / 70 | 80.12 / 44.88 / 70（dx 离群） |

- dx/dz 吻合（<1mm，离群样本除外）；dy 一致短 ~1mm（标准 `nut()` 比 1.0 卯榫浅，已知）。
- 公差：复用 `nut(w,false)`，公舌自动缩 0.25mm。
- 文字 `v/td/hd/bhw/id` 正读、触底字号、左右壁自适应不溢出；回归测试 `test/test_labels_fit.py`
  （round 5 例全过）。

## 样例

`generated_stl/round_td*.stl`（构建产物，不入库）。
