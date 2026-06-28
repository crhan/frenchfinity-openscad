# Agent 须知（Frenchfinity OpenSCAD）

记录会让 agent 踩雷的、不可从常识推导的点。改动相关代码前请先读。

- **移植下一个 1.0 模型**：照 `docs/porting-playbook.md` 走（含待移植清单与命令）。
- **逆向工具**：`tools/f3d_inspect.py`（从 .f3d 抽参数/预览）、
  `tools/stl_analyze.py`（bbox 回归 / 截面 / 平面特征）。
- 第一个完整范例：`docs/reverse-engineering-rectangular-tool-holder.md`。
- 1.0 源文件在 `/Volumes/home/Drive/3D模型/FrenchFinity/`。
- 远端：`fork` = `crhan/frenchfinity-openscad`（推这里），`origin` = 上游 Bastelsaal。
  当前工作分支 `rectangular-tool-holder`。

**铁律：STL / 渲染 PNG 绝不进 git**（属构建产物，已 `.gitignore`；样例输出放
`generated_stl/`，也不提交）。唯一例外是 `frenchfinity-logo.png`。

## 环境

- **BOSL2 子模块默认是空的**。先 `git submodule update --init lib/BOSL2`，否则
  `up/yrot/xrot/left/text3d` 等全是 "unknown module"。
- **`src/grid.scad` 已补全**（曾长期缺失、git 历史里也没有，`feature="grid"` 旧版会失败）。
  现按 1.0 "Grid-Holder v5" 重建为分格收纳盒，参数 `grid_*`（注意内/外壁厚分开：
  `grid_inner_wall_thickness` / `grid_outer_wall_thickness`，对齐 1.0）。
- OpenSCAD CLI 默认导出 **ASCII STL**；要二进制加 `--export-format binstl`
  （自写的二进制解析器才能读）。
- 无法设置导出文件名：靠 `hintFileName()` 打 `ECHO: "filename proposal:"`，手动重命名。

## 配合公差（French cleat 卯榫）—— 别让打印件卡死

- 公舌（holder：`nut(w, false)` union）和母槽（wall/plate：`nut(w, true)` difference）
  **绝不能用同样的尺寸**——FDM 打印公件偏大、母件孔偏小，0 间隙 = 过盈卡死。
- 由 `frenchfinity_1_0_slot_tolerance`（默认 0.25，对齐 1.0）控制：**只缩公舌**
  （`include_filament_hole == false` 那支），母槽保持名义值不变。这样既有 0.25mm 间隙、
  又与 1.0 实物互换。逻辑在 `src/nuts.scad`。
- 改 `nuts.scad` 的卯榫几何后，确认公/母仍差 0.25mm（母槽腔深 4.5、公舌头深 4.25）。

## 文字刻印 —— 改动后必须跑回归测试

刻在件上的尺寸标签很容易出问题，已踩过的雷：

1. **统一走 `src/labels.scad` 的 `labelLines()` / `labelFace()`**，别再各写一套。face 描述符：
   X 读面（前/后，沿 X 排字）`["x", x_center, y_face, width, z0, z1]`（`y_face>0` 为背面会翻转）；
   Y 读面（左/右侧壁，沿 Y 排字）`["y", y_center, x_face, length, z0, z1, side]`（side=`"right"`/`"left"`）。
2. **位置**：刻在外表能看到的面（侧壁或正面），**别和卯榫/螺孔挤在一起**（给 z 区间留出 cleat）。
3. **朝向别镜像**：右壁(+X) `rotate([90,0,90])`、左壁(-X) `rotate([90,0,-90])`、
   前/后面由 `y_face` 符号自动翻转（`labelFace` 已处理）。
4. **字号有下限 `text_size_min`（=3.5mm，实测 1.0 固定字高）**，封顶 `text_size`。
   **绝不能比 1.0 小**（打不出/看不清）。`text_size_min` 在 `frenchfinity.scad`。
5. **放不下就分到对面另一面**：`labelLines(lines, faceA, faceB)`——一面在下限尺寸下装不下时，
   多出的一半挪到 `faceB`，而**不是**继续缩小。只有连分两面、下限尺寸都装不下的**极小件**
   （1.0 同样标不下）才会溢出。
6. `text3d` 竖直近似基线锚定；字高 ≈ 1.3×size（含上伸部+下划线最坏情况，`TEXT_GLYPH_K`）、
   字宽 ≈ 0.70×size/字符。`labelFace` 已按此居中，别手算。

**任何改动文字布局/字号/朝向的代码后，必须运行回归测试：**

```
python3 test/test_labels_fit.py
```

它对一批参数（含极小件）渲染「纯文字」solids，断言文字包围盒落在件高/件长之内。
退出码 0 = 通过。详见 `test/README.md`。

## 改 prompt 文件的约定

本仓库 `CLAUDE.md` 是指向 `AGENTS.md` 的软链接，**只维护 `AGENTS.md` 这一份真源**，
别把两边写成两份内容。
