# Frenchfinity 1.0 (F3D) → 2.0 (OpenSCAD) 移植手册

把一个 1.0 Fusion 模型移植成 2.0 OpenSCAD feature 的可复用流程。第一个完整范例
（Rectangular Tool Holder）见 `reverse-engineering-rectangular-tool-holder.md`；
踩过的雷见根目录 `AGENTS.md`。**做下一个模型时照本手册走。**

1.0 源文件目录：`/Volumes/home/Drive/3D模型/FrenchFinity/`

## 0. 环境（一次性）

```
git submodule update --init lib/BOSL2     # 否则 up/yrot/text3d 全是 unknown module
which openscad                              # 渲染/验证需要 CLI
```

## 1. 抽参数（F3D → User Parameter 名字）

```
python3 tools/f3d_inspect.py "<.../某模型文件夹>" --preview /tmp/m.png
```

F3D 是 ZIP，`Design*/BulkStream.dat` 里有 ParametricText 明文模板，直接给出**精确
参数名**。`--preview` 导出缩略图，先看清形状。注意：模板里的字面后缀（如
`-hole-center/-left/-right`）**不是** Fusion 参数，是导出文件名后缀；2.0 可把它们
收成一个枚举参数（这正是迁移收益）。

## 2. 收样本 + 反推几何

每个 1.0 STL 的文件名都编码了那次的参数取值（`code12.34`），是现成的样本：

```
python3 tools/stl_analyze.py regress "<.../某模型文件夹>/*.stl"   # 拟合 bbox 维度=a*参数+b
python3 tools/stl_analyze.py slice  <one.stl> z 40                 # 某平面的实心截面(ASCII)
python3 tools/stl_analyze.py planes <one.stl> x                    # 平面特征(壁面)坐标
python3 tools/stl_analyze.py bbox   <one.stl>
```

R²≈1.0 的回归给出外形尺寸公式（如 `dx = tw + 10`）；用 `slice` 看横截面定位空腔、
孔、卯榫；用 `planes` 取精确壁厚。还可以用 openscad 把 ground-truth STL 渲染成多角度
PNG 直接看（`echo 'import("x.stl");' > /tmp/v.scad; openscad -o v.png --viewall ...`）。
目标产出：每个参数 → 几何的映射，以及固定结构常量（壁厚等）。

## 3. 实现 OpenSCAD 模块（照搬 2.0 架构）

新建 `src/<feature>.scad`，模块链与现有 feature 一致：
`<feature>_base()` → `_with_nut()` → `_with_nut_and_text()` → `feature_<feature>()`。

必守的约定：

- **挂墙卯榫**：复用 `nut(width, include_filament_hole)`。holder 是**公舌**
  → `nut(w, false)` 用 union 加在背面（朝 +Y，惯用法 `up(H - slot_distance_top*2) back(L) nut(w,false)`）。
  **公差自动生效**（公舌按 `frenchfinity_1_0_slot_tolerance` 缩 0.25mm，母槽不变）——
  不要自己改卯榫尺寸。
- **文字**：刻在件上最显眼的外表面（参考 1.0 的位置）；内容用 1.0 的参数布局。
  字号必须**自适应**件尺寸、`text3d` 是基线锚定、左右面旋转别搞反（见 AGENTS.md）。
  可复用 `rectangular_tool_holder_label_block` 的写法。
- **文件名提案**：`labels = hintFileName([...])`（含全部参数 + 枚举），保留 ECHO。
- **健壮性**：feature 模块开头 `assert()` 校验正值、枚举合法、关键不等式
  （如孔宽 ≤ 工具宽，避免静默掏穿壁）。

接入 `src/frenchfinity.scad`：① feature 枚举加项；② 新增 `/* [<Feature>] */` 参数区
（带 Customizer 注释/下拉，默认值取常见样本）；③ `include <<feature>.scad>`；
④ `render_selected_feature()` 加分支。

## 4. 验证

```
# 编译无错
openscad -o /tmp/t.stl --export-format binstl -D 'feature="<feature>"' src/frenchfinity.scad
# 包围盒/截面对比 ground truth（用 tools/stl_analyze.py 量自己的输出再比 1.0）
# 文字回归测试（若该 feature 有刻字，按 test/ 套路加一个或复用思路）
python3 test/test_labels_fit.py
```

要求：核心尺寸与 1.0 吻合（小差异如用标准 nut() 带来的 ~1mm 可接受并记录）；
公舌比母槽小 0.25mm；文字不溢出件外、正读不镜像。

## 5. 提交

精准 `git add` 改的源码/文档/测试。**绝不提交 STL / 渲染 PNG**（已 gitignore，属构建
产物）。commit 信息写清做了什么、为什么。推送到 fork（remote `fork` =
`crhan/frenchfinity-openscad`，origin = 上游）。

## 待移植清单

**全部 1.0 模型均已处理。** 原始 9 个清单模型 + 后来发现的 Bit/Tape 都已移植；
唯一未实现的是 Triangle Top Holder（原因见下，无法可靠逆向）。

**未实现（仅 1 个）：Triangle Top Holder**（`Triangle-Top-Holder.f3z`）
- f3z 是 XRef 容器，嵌套两个 .f3d；逆向出参数：`tool_width`(≈18)、`holder_height`、
  `triangle_height`、`tool_depth`（另一个嵌套 f3d 是 XRef 进来的 french-plate，忽略）。
- **但没有 STL、预览只显示 XRef 的墙板、也没有结构尺寸表达式** → 只有参数名,无法确定
  "triangle top" 到底是什么形状、四个参数怎么映射到几何。强行建模等于凭空发明,不是移植。
- **建议**：要做的话,在 Fusion 里打开导出一个 STL（哪怕一个样本）,就能照 playbook 逆向。

**重复/跳过**：`1740069021_Rectangular-Tool-Holder-f3z`、`Frenchfinity-Bit-Holder-f3z`
是已移植件的重复；`Screwdriver-Holder-f3z` 即已有的 `screw_driver`。

已完成：
- rectangular_tool_holder（本手册的范例，见 `reverse-engineering-rectangular-tool-holder.md`）
- pliers_holder（height, hole_diameter；见 `reverse-engineering-pliers-holder.md`）
- round_hanging_holder（td, holder_depth, bhw, inset_depth；见 `reverse-engineering-round-hanging-holder.md`）
- hook（width, height, hook_diameter, thickness, hook_end_height；见 `reverse-engineering-hook.md`）
- can_holder（can_diameter, padding, can_inset, padding_left + bottom 枚举；功能保真：倾斜罐杯+背板cleat，dx=cd+2p 精确）
- hammer_holder（width, hammer_width, handle_hole_width, drop_protection_height, drop_protection_width；功能保真：背板+双轨+手柄槽+防掉唇，dx=width/dz=50 精确）
- wrench_holder（width, wrench_width, scale；功能保真：双梳齿插槽架，dy=width+25.88 精确）
- small_hole_holder（hole_width, hole_length, tool_width；功能保真,无 1.0 STL 仅按 f3d 参数推；带 cleat 的矩形孔板）
- einhell_battery_holder（angle；功能保真,仅 1 个 1.0 STL；倾斜 U 槽电池座+背板cleat）
- gridfinity_adapter（grid_columns, grid_rows, angle；功能保真：斜置 gridfinity 底板(42mm,带倒角卡槽)+楔形+cleat，dx=42*gc 精确）
- bit_holder（rows, columns, hole_diameter, hole_padding, angle, height；功能保真：r×c 斜插孔块，dx=c*(hd+2hp) 精确；多行 dy 偏大于 1.0 的平行四边形）
- tape_holder（tape_width, max/min_tape_diameter, rest_diameter；功能保真：胶带卷凹槽座，dx=tw+20/dy=matd+20.88 精确）
已存在于 2.0（已审查对比 1.0，见 `audit-existing-components.md`）：
wall_anchor / french_plate / screw_plate / screw_driver / box / grid（已补全）。
