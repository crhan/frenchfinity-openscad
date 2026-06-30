# Agent 须知（Frenchfinity OpenSCAD）

记录会让 agent 踩雷的、不可从常识推导的点。改动相关代码前请先读。

- **移植下一个 1.0 模型**：照 `docs/porting-playbook.md` 走（含待移植清单与命令）。
- **逆向工具**：`tools/f3d_inspect.py`（从 .f3d 抽参数/预览）、
  `tools/stl_analyze.py`（bbox 回归 / 截面 / 平面特征，**只读二进制 STL**）、
  `tools/stl_diff.py`（**我方 STL vs 1.0 STL 形状对比**：自动对齐[48 朝向+ICP]、
  报表面 Chamfer/Hausdorff 距离 + 体积比 + 定位差异区 + 渲染红蓝差异图。
  用法 `tools/stl_diff.py OURS.stl REF.stl [OUT_DIR]`。**这是判「像不像」的首选**，
  别再只靠 bbox 或手调 translate 对齐）。
- 第一个完整范例：`docs/reverse-engineering-rectangular-tool-holder.md`。
- 1.0 源文件在本仓库的 `FrenchFinity/`（gitignored reference data）。旧 NAS
  绝对路径已废弃，别再提示或依赖它。
  **目录名可能是简洁版**（`Bit-Holder`、`Tape-Holder`、`Can-Holder`…）而非旧的
  `Bit_Drill+Holder+French+Cleat+Frenchfinity` 长名——用
  `find "$B" -ipath "*关键词*" -iname "*.stl"` 兜底，别硬编码目录名。

**铁律：bbox 对 ≠ 形状对。** 别只用 `stl_analyze bbox` 回归来"对齐"——那样会造出
bbox 一致、形状完全错的废件（can 曾是横躺圆柱、tape 没转轴、bit 行往外悬挑……全是
这么来的，2026-06-29 整批重建）。**必须按图形验证**：把我方 STL 和 1.0 STL 在相同
相机下各渲 iso/side/front/top（openscad `import()` 读 ASCII+二进制；Fusion 导出的
ASCII STL 要先 `openscad -o x.stl --export-format binstl` 转二进制才能喂
`stl_analyze`），**亲眼看几何 + 切截面**定结构，再让 bbox 自然涌现。也别信子 agent 的
"functional_equivalent" 判定（曾把没转轴的 tape 判成功能等价）。
  **量化「像不像」用 `tools/stl_diff.py`**：它自动对齐后报表面偏差(mean/p95/max)+ 定位差异区 +
  出红蓝差异图。实测 can（bbox 仅差 0.04mm）表面偏差 mean 0.6/max 4.3mm——**bbox 全对、形状仍有
  真实局部差**（bore 居中、cleat 的 Z 位、文字），正是这条铁律。bbox 通过 ≠ 完成。
- 远端：`fork` = `crhan/frenchfinity-openscad`（推这里），`origin` = 上游 Bastelsaal。
  当前工作分支 `rectangular-tool-holder`。

**铁律：STL / 渲染 PNG 绝不进 git**（属构建产物，已 `.gitignore`；样例输出放
`generated_stl/`，也不提交）。唯一例外是 `frenchfinity-logo.png`。

## 环境

- Python 依赖统一用 `uv` 管理，运行仓库脚本默认用 `uv run python ...`；不要裸
  `pip install` 到系统 Python 或随手建不可复现 venv。
- **BOSL2 子模块默认是空的**。先 `git submodule update --init lib/BOSL2`，否则
  `up/yrot/xrot/left/text3d` 等全是 "unknown module"。
- **`src/grid.scad` 已补全**（曾长期缺失、git 历史里也没有，`feature="grid"` 旧版会失败）。
  现按 1.0 "Grid-Holder v5" 重建为分格收纳盒，参数 `grid_*`（注意内/外壁厚分开：
  `grid_inner_wall_thickness` / `grid_outer_wall_thickness`，对齐 1.0）。
- OpenSCAD CLI 默认导出 **ASCII STL**；要二进制加 `--export-format binstl`
  （自写的二进制解析器才能读）。
- 本机 OpenSCAD 2026.06.12 的默认 arm64 CLI 可能直接报
  `Incompatible processor. This Qt build requires the following features: neon`；验证时用
  `arch -x86_64 /Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD ...`（或临时 PATH wrapper）
  跑 CLI。
- 无法设置导出文件名：靠 `hintFileName()` 打 `ECHO: "filename proposal:"`，手动重命名。

## 配合公差（French cleat 卯榫）—— 别让打印件卡死

- 公舌（holder：`nut(w, false)` union）和母槽（wall/plate：`nut(w, true)` difference）
  **绝不能用同样的尺寸**——FDM 打印公件偏大、母件孔偏小，0 间隙 = 过盈卡死。
- 由 `frenchfinity_1_0_slot_tolerance`（默认 0.25）控制：这是**单边间隙**——公舌每个自由面
  都从名义（母槽）壁缩进这么多，所以一对相对面的**总间隙 = 2×该值**（0.25 → 总 0.5mm）。
  **只缩公舌**（`include_filament_hole == false` 那支），母槽保持名义值不变。逻辑在 `src/nuts.scad`。
- 改 `nuts.scad` 的卯榫几何后，确认**单边间隙 = tolerance**：颈/头 Z 高各缩 `2×tolerance`
  （上下每面留 tolerance），舌尖 Y 缩 `tolerance`（母槽腔深 4.5、公舌头深 4.25 不变）。
  比 1.0 更松（1.0 ≈ 0.125/面）；仍能与 1.0 母槽/公舌互换（只是间隙更大）。
- **`frenchfinity_1_0_slot_outer_width`（颈深）= 6.6，别再改回 5.6**（2026-06-29）。实测 1.0
  公舌总突出 10.9mm = 颈 6.6 + 头 4.5 − 0.25 公差；旧值 5.6 让**每个件**的卯榫舌都比 1.0 短
  ~1mm（与 1.0 实物互换性差）。作者原注释就写了「set to 6.6 or 6.5 ... compatible to legacy」。
  这是**全仓库共用件**，改它影响全部 feature 的 cleat（dy 各 +1mm，向 1.0 靠）——改完务必
  `python3 test/test_labels_fit.py` + 编译全 18 feature 复验。

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
