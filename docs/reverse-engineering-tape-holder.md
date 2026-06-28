# 逆向 Tape Holder（Tape holder v16.f3z → src/tape_holder.scad）

胶带卷收纳座的移植范例。方法见 `porting-playbook.md`；这里只记结论与坑。
1.0 共 13 个 STL 样本，文件名编码了参数值，构成现成的「参数→几何」回归集。

> **2026-06-29 重建（commit 4bb4179）**：早期移植只是一个挖了 scoop 的矩形块、**没有中央转轴**
> （`rest_diameter` 仅用于刻字），卷子无法转动——属非功能件。现按 1.0 iso/side 渲染重建为
> 楔形体 + 双端高墙（horns）+ 凹弧卡槽 + 贯穿卷芯的转轴。

## 参数（f3d_inspect，从 .f3z 内解出的 .f3d）

```
frenchfinity-tape-holder-v{version}-tw{tape_width}-matd{max_tape_diameter}-mitd{min_tape_diameter}-rd{rest_diameter}
```

→ `tape_width(tw)`、`max_tape_diameter(matd)`、`min_tape_diameter(mitd)`、`rest_diameter(rd)`。

- `tw`：胶带卷宽度，决定卷槽宽 / 件宽（`dx = tw + 20`）。
- `matd`：满卷外径，决定凹弧曲率（卡槽半径 = matd/2）、件深与件高。
- `mitd`：空卷外径，主要作高度参考（1.0 高度随它走，本移植改按 matd，见下）。
- `rd`：**`rest_diameter`**——重建后实义为**中央转轴直径**，卷子套在这根轴上转动。
  文件名 token 仍是 `rd`（与 1.0 对齐）。
- 标签模板（竖排堆叠）：`v / tw / matd / mitd / rd`，与 .scad 的 `labelLines` 一致。

> 注：`.f3z` 是 zip，f3d_inspect 不直接吃；先 `unzip` 取出内部 `.f3d` 再 inspect。

## 尺寸（stl_analyze regress，13 个样本）

```
dx (宽 X) = 1.000*tw   + 20.000   (R^2 = 1.0000)
dy (深 Y) = 1.000*matd + 20.880   (R^2 = 1.0000)
dz (高 Z) = 0.694*mitd + 16.387   (R^2 = 0.9189)
```

- `dx = tw + 20`：卷槽宽 tw + 两侧各 10mm 端墙。
- `dy = matd + 20.88`：满卷外径 + 背墙 10 + cleat（10.88 即标准 cleat）。
- `dz`：1.0 高度单参数最佳拟合落在 mitd 上，但只有 R²=0.92（高度同时受 matd 影响，
  单参数吃不下）。**本移植不复刻这条经验式**：转轴/卡槽几何要求件高跟满卷半径走，
  故改用 `outer_height = 0.5*matd + 11`（卡槽底留 5mm 实壁、轴心上方留 6mm 背墙）。
  与 1.0 在小直径样本上很接近，大 mitd 样本会偏矮——高度为近似、非精确复刻。

## 几何

一个**楔形体**：背高前低，背墙满高 `h` 承载 cleat，顶面在后 35% 深度保持满高、
随后向前下斜到前缘高 `hf = h-14`（便于抽带）。中段沿 X 居中开一道宽 `tw` 的卷槽，
卷子卧入其中：

- **双端高墙（horns）**：卷槽左右各 10mm 端墙（`tape_holder_wall`），顶部开口只切中央
  `tw` 宽的槽（`cube([tw, d+2, seat+h])`），端墙保持满高，卷子从上方落入、两侧露出。
- **凹弧卡槽（cradle）**：一根轴沿 X、半径 `matd/2` 的圆柱横切卷槽（`seat = matd/2`），
  卷子贴弧而卧；弧心在 `(wall, matd/2, h-6)`。
- **中央转轴（spindle rod）**：difference 之后再 union 一根直径 `rd`、轴沿 X、跨满 `tw`
  的细圆柱，与弧心同心，**贯穿卷芯**桥接卷槽，卷子套上去即可转动。
- 背墙（`tape_holder_back` = 10mm，在 +Y）承载 cleat：复用 `nut(w, false)`，公差自动只缩公舌。

## 实现要点

- `outer_width = tw + 20`、`body_depth = matd + 10`、`outer_height = 0.5*matd + 11`。
- 楔形体：`rotate([90,0,90]) linear_extrude(w)` 挤出多边形
  `[[0,0],[d,0],[d,h],[d*0.65,h],[0,hf]]`（背满高、前下斜）。
- 卡槽 + 顶部开口：弧心 `(wall, matd/2, h-6)`，凹弧 `rotate([0,90,0]) cylinder(r=matd/2, h=tw)`；
  再用 `cube([tw, d+2, seat+h])` 把中央槽上方切空，仅留两端墙为 horns。
- 转轴：与凹弧同心 `cylinder(d=rd, h=tw)`，在 difference **之后** union 回去，桥接卷槽。
- cleat：`up(h - 2*slot_distance_top) back(d) nut(w, false)`，放背墙顶部。
- 文字：`labelLines` 把 `v/tw/matd/mitd/rd` 五行刻在**前下斜面**（X 读面，朝 -Y，不翻转，
  z∈[2, hf-2]），装不下时溢到**左端墙外侧面**（Y 读面，side="left"，z∈[2, hf-2]）——
  背面被 cleat 占用，故溢出方向选侧壁；自适应字号、不手算。

## 验证

bbox（mine vs 1.0），样本 `tw20-matd65-mitd45-rd4`：

```
            dx       dy       dz
1.0       40.00    85.88    43.75
mine      40.00    84.85    43.50
```

- `dx` 精确一致。
- `dy` 短约 1mm（标准 `nut()` cleat 比 1.0 略小，已知共性，见 hook 文档）。
- `dz` 仅差 0.25mm（重建前的旧版此处为 47.63，偏高约 3.9mm）。该样本满/空径接近，
  `0.5*matd+11` 命中很好；大 mitd 样本会偏矮，属上面所述高度近似的已知散布。

## 样例

`generated_stl/tape_holder_*.stl`（构建产物，不入库）。
