# 逆向 Tape Holder（Tape holder v16.f3z → src/tape_holder.scad）

胶带卷收纳座的移植范例。方法见 `porting-playbook.md`；这里只记结论与坑。
1.0 共 13 个 STL 样本，文件名编码了参数值，构成现成的「参数→几何」回归集。

## 参数（f3d_inspect，从 .f3z 内解出的 .f3d）

```
frenchfinity-tape-holder-v{version}-tw{tape_width}-matd{max_tape_diameter}-mitd{min_tape_diameter}-rd{rest_diameter}
```

→ `tape_width(tw)`、`max_tape_diameter(matd)`、`min_tape_diameter(mitd)`、`rest_diameter(rd)`。

- `tw`：胶带卷宽度，决定卷槽 / 件宽。
- `matd`：满卷外径，决定凹弧曲率与件深。
- `mitd`：空卷外径，决定件高。
- `rd`：1.0 Fusion 参数名是 **`rest_diameter`**（座底一个小倒角/让位），移植后 .scad 同样命名
  `tape_holder_rest_diameter`、文件名 token 仍是 `rd`（与 1.0 对齐）。回归里 rd 对任何 bbox 维度
  都无贡献（只是座底圆角，本移植未实现该倒角），下面尺寸公式不含它。
- 标签模板（竖排堆叠）：`v / tw / matd / mitd / rd`，与 .scad 的 `labelLines` 一致。

> 注：`.f3z` 是 zip，f3d_inspect 不直接吃；先 `unzip` 取出内部 `.f3d` 再 inspect。

## 尺寸（stl_analyze regress，13 个样本）

```
dx (宽 X) = 1.000*tw   + 20.000   (R^2 = 1.0000)
dy (深 Y) = 1.000*matd + 20.880   (R^2 = 1.0000)
dz (高 Z) = 0.694*mitd + 16.387   (R^2 = 0.9189)
```

- `dx = tw + 20`：卷槽宽 tw + 两侧各 10mm 壁。
- `dy = matd + 20.88`：满卷外径 + 背墙 + cleat（10.88 即标准 cleat）。
- `dz ≈ 0.694*mitd + 16.4`：**只有 R²=0.92，是近似**。件高主要随空卷外径 mitd 走，
  但实测还残留对 matd（凹弧深度）的弱相关，单参数线性拟合吃不下，故有几 mm 散布。
  移植里直接采用了这条近似式（`outer_height = 0.694*mitd + 16.4`），需知有此误差。

## 几何

一个矩形块，顶面切出一道**横向凹圆弧（scoop）**，胶带卷躺在弧里：
- 卷槽宽 `tw`，夹在左右各 10mm 侧壁之间（`tape_holder_wall`）。
- scoop 是一根**轴沿 X**、半径 ≈ `matd/2` 的圆柱，横跨卷槽切除；半径被夹到 `h-4` 以内防穿底。
- scoop 偏向**前方**，使背墙保持高、前侧敞开便于抽带；顶面在 scoop 上方再开一刀，让卷能从上方落入。
- 背墙（`tape_holder_back` = 10mm，在 +Y）承载 cleat：复用 `nut(w, false)`，公差自动只缩公舌。

## 实现要点

- `outer_width = tw + 2*10`、`body_depth = matd + 10`、`outer_height = 0.694*mitd + 16.4`。
- scoop：`rr = min(matd/2, h-4)`，圆柱 `rotate([0,90,0]) cylinder(r=rr, h=tw)`，
  z 抬到 `h + rr*0.15`（弧心略高于顶面，得到合适弧深）。
- 顶部开口：scoop 上方加一块 `cube` 切掉，胶带卷可从上方放入。
- cleat：`up(h - 2*slot_distance_top) back(d) nut(w, false)`，放背墙顶部。
- 文字：`labelLines` 把 `v/tw/matd/mitd/rd` 五行竖排刻在**正面（X 读面，贴底 z=2）**，
  装不下时溢到**背面**（`["x", w/2, d, w, 2, h-16]`），自适应字号、不手算。

## 验证

bbox（mine vs 1.0），样本 `tw20-matd65-mitd45-rd4`：

```
            dx       dy       dz
1.0       40.00    85.88    43.75
mine      40.00    84.85    47.63
```

- `dx` 精确一致。
- `dy` 短约 1mm（标准 `nut()` cleat 比 1.0 略小，已知共性，见 hook 文档）。
- `dz` 高约 3.9mm：正是上面 R²=0.92 近似式的散布——本样本实测落在拟合线下方
  （`0.694*45+16.4 = 47.6`，而 1.0 实物 43.75）。功能可用，高度非精确复刻。

## 样例

`generated_stl/tape_holder_*.stl`（构建产物，不入库）。
