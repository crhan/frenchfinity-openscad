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
- **`src/grid.scad` 缺失**（预存问题）：`frenchfinity.scad` 引用了它且调用
  `feature_grid()`，但文件不在仓库、git 历史里也没有。选 `feature="grid"` 会失败，
  其它 feature 不受影响。别误以为是自己改坏的。
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

1. **位置**：刻在两侧长壁（±X 外表面），**不要刻在背面**（会和卯榫挤在一起）。
   复刻 1.0 布局：右壁 `v{version}`+`tw`，左壁 `tl`+`tsh`+`hhw`。
2. **朝向**：右壁(+X) 用 `rotate([90,0,90])`、左壁(-X) 用 `rotate([90,0,-90])`，
   否则从外侧看是**镜像**的。
3. **`text3d` 竖直是基线锚定**（从原点往上长约 1×size，中心在 +size/2，不是几何居中）。
   字高 ≈ 1.02×size、字宽 ≈ 0.66×size/字符（实测）。手动居中要补偿基线。
4. **字号必须按件高/件长自适应缩小**（封顶 `text_size`）。短件（小 `tool_slot_height`
   → 件高小）用固定字号会让文字**超出件高 / 丢行**。见
   `rectangular_tool_holder_label_block`。

**任何改动文字布局/字号/朝向的代码后，必须运行回归测试：**

```
python3 test/test_labels_fit.py
```

它对一批参数（含极小件）渲染「纯文字」solids，断言文字包围盒落在件高/件长之内。
退出码 0 = 通过。详见 `test/README.md`。

## 改 prompt 文件的约定

本仓库 `CLAUDE.md` 是指向 `AGENTS.md` 的软链接，**只维护 `AGENTS.md` 这一份真源**，
别把两边写成两份内容。
