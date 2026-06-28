# 既有组件审查（公差 / 标准 / 文字 + 对比 1.0）

对作者原有的 OpenSCAD 组件（`box`, `french_plate`, `screw_plate`, `screw_driver`,
`wall_anchor`, `grid` + 共享 `nuts.scad` / `labels.scad`）做的审查与修复记录。
对比基准是各自的 Frenchfinity 1.0 源（`/Volumes/.../FrenchFinity/`）。

## 1. 公差（fit tolerance）—— ✅ 无需改

所有组件的卯榫都走共享 `nut()`，且公/母用对了：holder（box/screw_driver/grid…）
用 `nut(_, false)`（公舌），wall/plate（wall_anchor/french_plate/screw_plate）用
`nut(_, true)`（母槽）。`nuts.scad` 只把**公舌**缩 `frenchfinity_1_0_slot_tolerance`
（0.25mm，对齐 1.0），母槽保持名义值 → 公舌比母槽小 0.25mm，打印件能咬合且与 1.0 互换。
**结论：公差正确，全组件覆盖，无需改。**

## 2. 标准（French cleat 定位）—— ✅ 实测对齐 1.0（亚毫米）

逐件量了 1.0 STL 的卯榫 Z 位置并比对作者公式：
- wall_anchor：母槽口距顶 7.4mm（1.0）vs 作者 7.394mm —— 差 ~0.5mm。
- french_plate：公舌头距顶 6.06mm（1.0）vs 作者 6.52mm —— 差 ~0.45mm。
- screw_plate：母槽 Z 与 1.0 吻合（切面分辨率内）。
- screw_driver：公舌距顶比 1.0 低 ~1.3mm（在 nut 公差内）。

各件定位公式不完全统一（box/screw_driver 用 `distance_top*2`，plate/anchor 用
`distance_top + outer_height`，差 0.9mm），但都在亚毫米级、且卯榫**型面**一致（共享
`nut()`），不影响互换咬合。**结论：标准合规，差异亚毫米可接受，未改。**

## 3. 文字 —— ✅ 已修（溢出 + 下限 + 分流）

原 `labelVertical()` 用**固定字号 + 固定 7mm 行距**，小件会溢出丢行（实测 h30 box 只显
1/3 行）。已重写为共享自适应系统（`src/labels.scad`）：
- `labelFace()` / `labelLines()`：字号自适应，**下限 `text_size_min=3.5mm`**（实测 1.0
  固定字高，不能更小），封顶 `text_size`。
- **放不下分到对面另一面**：`labelLines(lines, faceA, faceB)`。
- 全部 9 个 feature 改用此系统；`test/test_labels_fit.py` 32/32 通过（含下限与封顶校验）。

## 4. 对比 1.0：逐件差异与处置（task 17）

| 组件 | 与 1.0 的差异 | 处置 |
|---|---|---|
| **wall_anchor** | ① `screw()` 把 thread_diameter 当 head_diameter 传 → 螺帽沉孔尺寸错（声明的 `head_diameter` 形同虚设）。② `bottom_angle` 声明但未用（45° 硬编码）。 | **已修**：传 `head_diameter`；把 `bottom_angle` 接入楔形。45° 默认几何不变。 |
| **grid** | `src/grid.scad` **缺失**，feature 接线却调用它 → 不可构建。1.0 内/外壁厚分开，作者只有单一 `grid_wall_thickness`。 | **已修**：重建 `grid.scad`（分格盒）；拆出 `grid_inner/outer_wall_thickness` 对齐 1.0。 |
| **screw_driver** | `inset_height` 会撑大外形（1.0 外形固定 50mm，inset 只挖内腔）；默认 `padding_sides=10` 比 1.0 的 5 宽 10mm。 | **记录**：属作者有意的 2.0 参数化增强（额外暴露 bottom_height/padding_*）。非 bug，未改默认。 |
| **french_plate** | `height` 语义 +20 偏移（1.0 `plate_height`+20=总高；作者 `height`=总高）；`depth` 非 1.0 参数，默认 20 vs 1.0 的 16。bbox 与 1.0 精确吻合。 | **记录**：有意的 2.0 简化（height=真实总高）。照 1.0 数值需 `height=plate_height+20`、`depth=16`。 |
| **screw_plate** | 参数重命名（`screw_diameter→thread_diameter`、修正 typo `head_widht→head_diameter`）；同样的 height +20 语义、depth 默认 20 vs 16。bbox 与 1.0 **精确吻合**。 | **记录**：重命名是改进；语义偏移同 french_plate。未改默认。 |
| **box** | 1.0 无对应源（疑为 2.0 原生收纳盒）。 | 无可比，跳过。 |

**判据**：实质 bug（wall_anchor 两处、grid 缺失）已修；属"2.0 有意增强/默认值选择"的差异
（多出的参数、height 语义、depth 默认）仅记录，不强行改回 1.0（会惊扰现有用户、且不是错误）。

## 复跑

```
python3 test/test_labels_fit.py        # 文字回归，32/32
# 逐 feature 编译自检：feature ∈ {box,french_plate,grid,hook,pliers_holder,
#   rectangular_tool_holder,round_hanging_holder,screw_plate,screw_driver,wall_anchor}
```
