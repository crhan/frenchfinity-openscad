# 逆向 Small hole holder（Small hole holder v6.f3d → src/small_hole_holder.scad）

## 引子

本件与其它范例不同：1.0 源是一个**散落的 `.f3d`，没有导出任何 STL**。
因此这不是「bbox 回归克隆」，而是一次**功能移植**——从 Fusion 工程里恢复出来的
user-parameter 表达式与固定常量重建几何。

直接后果：**无法跑 `stl_analyze` 回归**（没有 1.0 STL 可比对），验证只能靠
「OpenSCAD 能编译 + 文字回归测试」。报告里的数字**全部来自 .scad 头注**，不臆造。

## 参数

公开参数（命名沿用 1.0 user-parameter）：

- `hole_width (hw)` —— 矩形工具孔的宽度
- `hole_length (hl)` —— 矩形工具孔的长度
- `tool_width (tw)` —— 驱动板高（= tw + padding），让工具的肩部正好搭在板上

## 恢复出的固定常量与尺寸公式

1.0 工程中恢复出的固定常量：

```
hole_tolerance = 0.5     // 从 hole_width 里减掉，让打印孔偏紧（snug）
padding        = 5       // 板高在 tool_width 之上的余量
wall_thickness = 5       // 板厚（Y 向）
draft angle    = 2deg    // 5mm 壁上约 0.17mm 锥度，可忽略，已省略
min plate width = 21     // 最小板宽（容纳 cleat 截面）
```

尺寸公式：

```
plate width  = max(21, padding + hole_width - hole_tolerance) = max(21, hw + 4.5)
plate height = tool_width + padding = tool_width + 5
hole opening = (hole_width - hole_tolerance) x hole_length
```

注意 `hole_tolerance` 只缩**孔**（`hw - 0.5`），让打印出的孔对工具偏紧；
这与 cleat 卯榫公差（`frenchfinity_1_0_slot_tolerance`）是两套独立的东西。

## 几何

一块带**单个矩形通孔**的法式卯榫小板：带矩形杆的工具从孔里穿过，
直到更宽的肩部搭在板面上挂住。

- 板体：`cube([w, t, h])`，孔居中、沿 Y 打穿（`t+2` 保证彻底贯通）。
- cleat：复用 `nut(w, false)` 放在 **+Y（背面）**顶部，与其它 holder 一致；
  公差由 `nut()` 自动处理。

## 实现要点

- `feature_small_hole_holder()` 带断言守护：`hw > 0.5`、`hl > 0`、`tw > 0`，
  以及 `hole_length < plate_height - 2`（孔太高放不下时提示加大 tool_width）。
- 文字：1.0 是 `v-hw / tw-hl` 两行紧凑刻印。这里走 `labelLines()`，每个值一短行刻在
  **宽的背面（X-read）**——窄的侧壁太细放不下；装不下时溢到正面（faceB）。
  cleat 公舌从背面凸出，凹刻文字落在它旁边/下方，仍留在板体内。

## 验证

**无 1.0 STL，故无 bbox 可比对。** 验证手段只有两条：

1. OpenSCAD CLI 能干净编译、断言不触发；
2. 文字回归 `python3 test/test_labels_fit.py`（确认刻字包围盒落在件高/件长内）。

## 样例

`generated_stl/small_hole_holder_*.stl`（构建产物，不入库）。
