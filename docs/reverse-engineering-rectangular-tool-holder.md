# 从 Frenchfinity 1.0 (Fusion 360 / F3D) 逆向移植到 2.0 (OpenSCAD)

## —— 以 Rectangular Tool Holder 为例

本文档记录把 Frenchfinity 1.0（Fusion 360 参数化、以 `.f3d` 分发）的一个模型
逆向出其 **User Parameter（用户参数化生成）结构**，并移植到 Frenchfinity 2.0
（OpenSCAD）代码体系的完整过程。方法论本身是可复用的，文末附上其余尚未移植
模型的参数清单。

---

## 1. 两代的核心共性与差异

| | Frenchfinity 1.0 | Frenchfinity 2.0 |
|---|---|---|
| 建模方式 | Fusion 360 参数化 (User Parameters) | OpenSCAD 代码 + Customizer |
| 分发 | 每组参数导出一个 `.stl` | 一份 `.scad`，参数现调现生成 |
| 挂墙接口 | 法式斜接卯榫（燕尾舌） | 同一卯榫，`nut()` 模块 (`nuts.scad`) |
| 文件名 | ParametricText 插件按模板生成 | `hintFileName()` 打 `ECHO` 提示 |

两代共享**同一个挂墙卯榫**（French Cleat dovetail）。2.0 把它抽象成
`frenchfinity_1_0_slot_*` 参数 + `nut(width, include_filament_hole)` 模块，并刻意
保留对 1.0 的兼容（见 git log “legacy tolerance for the frenchfinty 1.0 nut”）。
**因此移植任何 holder 的本质 = 复刻它的本体几何 + 在背面挂上标准 `nut()`。**

最直观的差异：1.0 的 Rectangular Tool Holder 因为孔位有“中/左/右”三种选择，
就导出了 3 套 STL（整个文件夹共 35 个 STL）；2.0 只需一个 `hole_position`
枚举参数。**“多个 STL → 一个参数”正是迁移到 OpenSCAD 的核心收益。**

---

## 2. F3D 文件格式逆向（方法论）

`.f3d` 本质是一个 **ZIP 容器**：

```
$ file "Rectangular-Tool-Holder v24.f3d"   →  Zip archive data
$ unzip -l ...
  FusionAssetName[Active]/Design1/BulkStream.dat   (设计历史/参数)
  FusionAssetName[Active]/Design1/MetaStream.dat
  FusionAssetName[Active]/Breps.BlobParts/*.smb    (B-rep 几何, 私有二进制)
  FusionAssetName[Active]/Previews/small.png        (缩略图)
  ...
```

> 注意 1：里面的数据成员是 **Deflate 压缩**的（`unzip -v` 显示 BulkStream.dat
> 2541413→365899 ≈ 86%，BREP/MetaStream 同样压缩）；只有零字节目录项和极小的
> `Properties.dat` 是 `Stored`。`file` 之所以报 `method=store`，是因为它只看了
> 第一个条目（恰好是目录）。**因此不能直接 grep 原始容器，必须先解压/inflate**
> ——下面的 `zipfile.read()` 会透明解压，`unzip`/`strings` 同理需先解出文件。
>
> 注意 2：路径里的 `[Active]` 是 shell 的 glob 元字符，解压时要整体解压或转义。

### 2.1 关键突破：ParametricText 明文模板

`Design1/BulkStream.dat` 里嵌着 **ParametricText** 插件的数据，它以
**Python 格式串明文**存了文件名模板，直接暴露了所有 User Parameter 的精确名字：

```
frenchfinity-rectangular-tool-holder-v{version:.0f}
  -tw{tool_width:.2f}-tl{tool_length:.2f}-tsh{tool_slot_height:.2f}
  _hhw{holder_hole_width:.2f}-hole-center
```

抽取脚本（核心逻辑）：

```python
import zipfile, re
z = zipfile.ZipFile("Rectangular-Tool-Holder v24.f3d")
data = z.read("FusionAssetName[Active]/Design1/BulkStream.dat")
for s in re.findall(rb"[\x20-\x7e]{4,}", data):        # 抽 ASCII 串
    t = s.decode()
    if "frenchfinity" in t and "{" in t:               # 命中模板
        print(t)
        print(re.findall(r"\{([a-zA-Z_]\w*)", t))      # 参数名
```

这一步把“逆向几何”这个难题，降级成了“已知参数名 + 已知每个 STL 的参数取值，
再反推参数如何映射到尺寸”——后者用 STL 实测即可解。

### 2.2 STL 文件名 = 现成的参数样本

每个导出的 STL 文件名都编码了那次生成的参数取值，例如
`...-tw12.50-tl46.00-tsh5.00_hhw8.00-hole-center.stl`。35 个 STL 就是 35 组
“(参数 → 几何)”的标注样本，足够做回归。

---

## 3. 选定模型：Rectangular Tool Holder

理由：① 尚未移植；② 参数最干净（tw/tl/tsh/hhw + 孔位）；③ 几何最贴近 2.0 已有的
`box.scad` 范式（盒体 + 卯榫），可一次做对、忠实还原；④ “中/左/右”三孔位是
“3 个 STL → 1 个参数”收益的最佳示范。

真正的 User Parameters（确实出现在 ParametricText 模板的 `{...}` 里）只有 4 个
（外加 `version`）：

| 参数名 | STL 代号 | 含义 |
|---|---|---|
| `tool_width` | `tw` | 被收纳工具的宽度 |
| `tool_length` | `tl` | 工具长度 / 槽的可用长度 |
| `tool_slot_height` | `tsh` | 工具沉入槽的深度 |
| `holder_hole_width` | `hhw` | 前端开口 + 底部贯穿槽的宽度 |

> `hole_position`（center/left/right）**不是** Fusion 用户参数 —— 模板字符串里
> 根本没有 `hole_position`，三种孔位是写死在**三个不同文件名模板**末尾的字面后缀
> （`...-hole-center` / `-left` / `-right`），对应导出三套 STL。把它收成一个枚举
> 参数是 2.0 移植时引入的（也正是“3 套 STL → 1 个参数”收益的来源）。

---

## 4. 几何逆向（STL 实测）

STL 是自定义二进制（头部 `MW 1.0 ...`，标准 80 字节头 + uint32 三角面数 +
每面 50 字节）。用 numpy 解析顶点后做三类测量。

### 4.1 包围盒线性回归（参数 → 外形尺寸）

对所有样本拟合 `bbox 维度 = a·参数 + b`，得到 **R² = 1.000** 的干净关系：

```
dx (宽) = tool_width      + 10      (R²=1.000)   →  两侧各 5 mm 壁
dy (长) = tool_length     + 20.88   (R²=1.000)   →  后部卯榫/横壁结构
dz (高) = tool_slot_height + 15     (R²=1.000)   →  槽下方 15 mm 基座
hhw 不改变包围盒                                  →  是底面槽 / 前端开口的宽度
```

### 4.2 截面切片（三角形-平面求交 + 扫描线填充）

得到干净的实心截面后，定位每个特征的精确区间（以 tw29/tl71/tsh8/hhw15 为例，
本体 X[3..42] Y[44.73..136.61] Z[37..60]）：

- **工具槽**：通道宽 = `tw`（X 空腔 7.7..37.3 ≈ 29），两侧壁各 5 mm；
  槽深 = `tsh`（地板在顶下 8 处，tsh52 模型实测地板在 z=10 验证）；
  通道**顶部 + 前端均敞开**。
- **底部贯穿槽 / 前端收口**：z 低于通道地板后，空腔收窄到 `hhw`
  （X 15..30 = 15）；前端开口实测 = `hhw`（tw16→4.54, tw29→15.54, tw52→36.54，
  恒为 hhw+0.5）。即工具主体卡在 tw 宽的通道里、其窄部从 hhw 宽的前端与底部穿出。
- **后端卯榫**：背面伸出一段燕尾舌（Z 区间 45.7..53.9），即法式斜接公舌；
  对应 2.0 的标准 `nut()`。

### 4.3 长度方向分解

```
dy = tl + 20.88 = [卯榫舌 ~10.88] + [横壁 5] + [工具槽 = tl] + [前端收口唇 5]
```

### 4.4 “中/左/右”孔位的真相

底视图三连（见 §7 图）显示：所谓的“孔”是底座里沿长度方向的贯穿槽，
`hole-center/left/right` = 这条槽（连同前端收口）在 **X 方向的位置**。
Fusion 为此导出 3 套 STL，而 body 在世界坐标里被整体平移（这只是 Fusion
导出排版，不是几何本质）。

**一个被发现的 1.0 artifact**：center 时槽宽精确 = hhw；但 left/right 时
1.0 的槽宽相对 hhw 发生了**非线性收缩**（hhw8→4.75, hhw4→4.5, hhw9→7.5…，无干净规律），
应是 Fusion 草图约束的副作用。2.0 移植时**规范化**为：槽保持完整 `hhw` 宽度，
并贴紧对应一侧的通道内壁（见 §6 设计决策）。

> **手性说明**：2.0 沿用 `box.scad` 的「卯榫在 +Y 背面」朝向，而 1.0 导出件把
> 卯榫放在 −Y 端，二者沿 X-Z 面互为 **Y 镜像**。`center` 因 X 对称完全一致；
> 但 `left`/`right` 在物理装配后会落到与同名 1.0 STL **相反**的一侧。`left`/`right`
> 在此按 2.0 件自身坐标系（OpenSCAD 预览所见）定义。绝大多数实际件用的是 `center`，
> 不受影响。

---

## 5. 1.0 ↔ 2.0 参数映射表

| 1.0 来源 | 2.0 (`frenchfinity.scad`) | 默认值 |
|---|---|---|
| `tool_width` (Fusion 参数) | `rectangular_tool_holder_tool_width` | 20 |
| `tool_length` (Fusion 参数) | `rectangular_tool_holder_tool_length` | 60 |
| `tool_slot_height` (Fusion 参数) | `rectangular_tool_holder_tool_slot_height` | 10 |
| `holder_hole_width` (Fusion 参数) | `rectangular_tool_holder_hole_width` | 8 |
| `-hole-center/-left/-right` (3 套 STL 的文件名后缀, 非 Fusion 参数) | `rectangular_tool_holder_hole_position` (1 个枚举) | "center" |
| — (固定结构常量) | `_side_wall=5, _end_wall=5, _base_below=15` | — |

固定常量来自 §4.1 的回归截距，硬编码在 `rectangular_tool_holder.scad`。

---

## 6. OpenSCAD 实现

新增 `src/rectangular_tool_holder.scad`，并接入 `src/frenchfinity.scad`
（参数区 `/* [Rectangular tool holder] */`、feature 枚举、`include`、
`render_selected_feature` 分支），完全沿用 2.0 既有架构：

- 构造范式与 `box.scad` 一致：`difference()` 挖槽 → `union()` 挂 `nut()` →
  `difference()` 刻文字。
- 本体 = `cube([tw+10, tl+10, tsh+15])`；挖工具槽（顶+前敞开）；
  用**一条全高度的 hhw 宽 cube** 同时切出底部贯穿槽和前端收口
  （二者实测为同一条路径，一起平移）。
- 卯榫沿用 `box.scad` 惯用法 `up(H - slot_distance_top*2) back(L) nut(W, false)`，
  实测落点（z 8.7..16.9）与 1.0 卯榫一致。
- `hintFileName()` 输出 `tw/tl/tsh/hhw/hole` 代号，与 1.0 命名对齐。

### 设计决策

1. **left/right 规范化**：不照搬 1.0 的槽宽收缩 artifact；改为完整 `hhw` 宽 +
   贴壁偏移（center 与 1.0 完全一致；left/right 是更合理的实现）。
2. **卯榫用 2.0 标准 `nut()`**：保证与 2.0 wall anchor 互配，而非逐毫米复刻
   1.0 燕尾。代价是总长 `dy` 比 1.0 短 0.78 mm（2.0 `nut()` 深 10.1 vs 1.0 ~10.88），
   可忽略。
3. **通道宽 = tw（无间隙）**：1.0 实测 tw+0.54 仅出现在顶沿，是 2 mm 圆角在
   顶下 1 mm 处的外扩（2−√3≈0.27/侧），通道本体实为 tw，故 2.0 取 tw 忠实。
4. **顶沿圆角**：1.0 通道口有 2 mm 圆角，2.0 当前为直角（纯外观差异），
   作为后续 refinement（呼应 TODO.md “radius der leiste anpassbar machen”）。

---

## 7. 验证结果

用 `openscad` CLI 以多组参数生成 STL（`--export-format binstl`），与 1.0
ground truth 逐项对比：

| 用例 | 来源 | dx | dy | dz | 通道宽 | 槽宽 | 槽心X |
|---|---|---|---|---|---|---|---|
| tw29 tl71 tsh8 hhw15 center | 1.0 | 39.00 | 91.88 | 23.00 | 29.54¹ | 15.00 | 19.5 |
| | **2.0** | **39.00** | 91.10 | **23.00** | 29.00 | **15.00** | **19.5** |
| tw16 tl29 tsh10 hhw4 center | 1.0 | 26.00 | 49.88 | 25.00 | 16.54¹ | 4.00 | 13.0 |
| | **2.0** | **26.00** | 49.10 | **25.00** | 16.00 | **4.00** | **13.0** |
| tw52 tl128 tsh10 hhw36 center | 1.0 | 62.00 | 148.88 | 25.00 | 52.54¹ | 36.00 | 31.0 |
| | **2.0** | **62.00** | 148.10 | **25.00** | 52.00 | **36.00** | **31.0** |
| tw12.5 tl46 tsh5 hhw8 left | 1.0 | 22.50 | 66.88 | 20.00 | — | 4.75² | 7.38 |
| | **2.0** | **22.50** | 66.10 | **20.00** | — | 8.00² | 9.0 |

¹ 顶沿圆角效应（见决策 3）。 ² left/right 规范化（见决策 1）；表中按各自坐标系
的低 X 边量取槽心，2.0 相对 1.0 还存在 §4.4 所述 Y 镜像，故 left/right 同名件物理
落在相反一侧（center 不受影响）。其余维度全部精确吻合。

视觉对比：分别渲染 1.0 ground-truth STL 与 2.0 OpenSCAD 输出的立体图、底视图
（center/left/right），形状一致——U 形长槽 + 后端卯榫 + 底部贯穿槽随孔位左右平移。
渲染图属构建产物、不入库；需要时用以下命令复现：

```
echo 'import("<1.0 或 2.0 的 .stl>");' > /tmp/v.scad
openscad -o /tmp/v.png --imgsize=440,440 --camera=0,0,0,55,0,25,0 --viewall --autocenter /tmp/v.scad
```

---

## 8. 过程中踩到的坑（给下一个 agent）

- **BOSL2 子模块默认未初始化**：`lib/BOSL2` 为空，`up/yrot/xrot/left` 全是
  unknown module。验证前必须 `git submodule update --init lib/BOSL2`。
- **`src/grid.scad` 缺失**：`frenchfinity.scad` 第 102 行 `include <grid.scad>`
  且 `feature_grid()` 被调用，但该文件不在仓库、git 历史里也没有 → 主文件目前
  带警告编译，选 `feature="grid"` 会失败。**这是预存问题，不在本次范围内**，
  但移植时需知晓（不影响其它 feature）。
- **OpenSCAD 默认导出 ASCII STL**：用 numpy 二进制解析器会失败；
  导出时加 `--export-format binstl`。
- **F3D 路径含 `[Active]`**：是 glob 元字符，解压脚本需整体解压或转义。
- **文件名提案**：OpenSCAD 无法设置导出文件名，靠 `hintFileName()` 打
  `ECHO: "filename proposal:"`，需手动重命名（README 已说明）。

---

## 9. 可复用方法论 & 待移植清单

**复用步骤**：① 解压 F3D ZIP；② 从 `Design1/BulkStream.dat` 抽 ParametricText
模板得参数名；③ 按 STL 文件名收集参数样本；④ numpy 解析 STL 做包围盒回归 +
截面切片，反推参数→几何；⑤ 按 2.0 架构写 `*.scad` + 挂 `nut()` + 接入主文件；
⑥ `openscad` CLI 渲染 + 包围盒对比 ground truth 迭代。

**尚未移植的 1.0 模型**（已扫描出参数名，可直接接力）：

| 模型 | User Parameters |
|---|---|
| Can Holder | can_diameter, padding_left, can_inset, padding |
| Hook | width, height, hook_diameter, thickness, hook_end_height |
| Hammer Holder | width, hammer_width, handle_hole_width, drop_protection_height, drop_protection_width |
| Pliers Holder | height, hole_diameter |
| Round Hanging Holder | tool_diameter, holder_depth, bottom_hole_width, inset_depth |
| Wrench Holder | wrench_width, width, scale |
| Gridfinity Adapter | grid_rows, grid_columns, angle |
| Einhell Battery Holder | angle |
| Small Hole Holder | hole_width, tool_width, hole_length |

（已移植且可用：wall_anchor / french_plate / screw_plate / screw_driver / box；
另：grid 已接线进 frenchfinity.scad，但 `src/grid.scad` 缺失、暂不可用，见 §8）

---

## 10. 文字刻印（与 1.0 对齐）

逆向 1.0 的文字（从 `Design1/BulkStream.dat` 的 ParametricText 模板 + STL 几何分析）：

- **内容**：两个文字块，`v{version}` / `tw{...}` 和 `tl{...}` / `tsh{...}` / `hhw{...}`
  （数值 2 位小数、版本整数）。
- **位置**：刻在**两侧长壁**（±X 外表面，约 2mm 深、竖直居中、沿长度方向）——
  即装到墙上后**实际看得见**的面，而不是背面。几何分析实测：左壁 -X 区域
  Z[41.4..53.6]（3 行），右壁 +X 区域 Z[43.7..51.1]（2 行），均深约 2mm。

2.0 移植：
- 文字从背面（与卯榫挤在一起、小件上行距压缩到糊）改到**两侧壁**，复刻 1.0 布局
  （右壁 `v`+`tw`，左壁 `tl`+`tsh`+`hhw`），凹刻 1.5mm，按 `text_size` 竖直居中。
- 朝向经 OpenSCAD 渲染逐一校正（右壁 `rotate([90,0,90])`、左壁 `rotate([90,0,-90])`），
  保证从外侧看**正读不镜像**。受 `render_text` 开关控制。

## 11. 配合公差（与 1.0 对齐）—— 重要

**官方标准（frenchfinity.xyz/#faq）**：French cleat 宽 ≥20mm、高 55mm、角 45°；
间距 ≥ 2×高度 + 10–20mm。**站点未规定燕尾卯榫的配合公差**，故公差以 1.0 为基准。

**发现的问题**：2.0 里公舌（holder，`nut(w,false)` union）和母槽（wall anchor /
plate，`nut(w,true)` difference）调用**同一个 `nut()`、尺寸完全相同 → 配合间隙 = 0**。
FDM 打印时公件会偏大、母件孔会偏小，0 间隙 = 过盈，**打印件无法顺利咬合**。

**1.0 实测**（公母燕尾 mid-X 剖面）：

| 部位 | 1.0 母槽(wall anchor) | 1.0 公舌(holder) | 间隙 |
|---|---|---|---|
| 内腔/舌头深度 (Y) | 4.50 | 4.26 | **≈0.25mm** |

即 1.0 把**公舌缩小约 0.25mm**、母槽保持名义值。

**修复（`nuts.scad` + 全局参数 `frenchfinity_1_0_slot_tolerance = 0.25`）**：
- 仅当 `include_filament_hole == false`（即公舌）时，把卯榫的舌头深度与高度按公差
  内缩（深面缩 0.25、上下各缩 0.125）；母槽（`true`）保持名义值不变。
- 改动只在共享的 `nut()` 里，**全系统所有 holder 一次对齐**，无需改各 feature 调用点。

**验证**（生成 2.0 件实测）：母槽腔深 4.50（未变）、公舌头深 4.25 → **间隙 0.25mm**，
与 1.0 一致。母槽尺寸不变意味着 2.0 件与 1.0 件**可互换**（2.0 公舌 4.25 进 1.0 母槽
4.50、1.0 公舌 4.26 进 2.0 母槽 4.50 都留有间隙）。需要更松/更紧改这一个参数即可。
