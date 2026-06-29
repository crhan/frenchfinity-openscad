# 逆向 Can-Holder（Can-Holder v42.f3d → src/can_holder.scad）

罐架 / 钻头架 / 喷罐架。方法见 `porting-playbook.md`；这里只记结论与坑。

> 2026-06-29（commit f61dd49）按真实横截面几何重建：旧版是「拟合 bbox」得来的，形状完全错。
>
> 2026-06-29（第二轮）用户按图形复核发现仍「少了一些倒圆角」。逐层测量后发现差的
> 不止圆角，而是**整个顶部 + 倾角模型都错**。本文已对齐这次的构造式重建。
>
> 2026-06-29（第三轮）一对一 STL 复核：自渲 PNG 比对 1.0 后，发现文字面错了（1.0 刻在竖直背面
> cleat 下方,旧版刻在斜前面）。已改到背面（见下）。
>
> 2026-06-29（**第四轮,本次**）用户在切片器里加载我方 vs 1.0,圈出三处:① 前顶棱 1.0 是**圆**的、
> 我方是**尖**的;② 背面竖棱(榫卯侧)我方被圆了、**必须改回尖**(否则结合面不对);③ 顶部 bore 开口
> 我方被后平台切到、成「不完整的弧」。三处全部修复:**选择性倒角**（球 minkowski 圆前+顶,
> union 尖角背墙板保住榫卯侧）+ 重设 `H` 让平台前沿落在开口后缘（开口完整）。详见「实现」。

## 这次（第二轮）查出的真实结构 vs 旧版

| 特征 | 旧版（错） | 1.0 真实 |
|---|---|---|
| 倾角 | 硬编码 `tilt=9°` | **自由用户参数 `angle`**（filename **不**编码；样本实测 10/15/20/30/40°） |
| 顶面 | 水平平顶 | **垂直于 bore 轴**：后部小平台 + 前部 ⊥bore 斜屋脊下到前顶角 |
| bore 开口 | 直筒、无倒角 | **45° 锥形导入倒角(countersink)** |
| 竖棱 | 直角 | **~1mm 圆角**（用户说的「倒圆角」） |
| 前面斜角 | `ci·sin9°`（太浅） | = `angle`，与 bore 轴平行（exact by construction） |

**关键**：`angle` 不在 filename 里。对 ~40 个样本测前面斜角，得到的是离散的 10/15/20/30/40°，
与 cd/ci/pl 没有干净函数关系 → 它是 Fusion 里的一个用户旋钮，移植必须**暴露成参数**
（`can_holder_angle`，默认 10）。旧版把它写死成 9°，所以大多数样本一对就错。

## 参数（f3d_inspect）

```
frenchfinity-can-holder-v{version}-cd{can_diameter}-pl{padding_left}-ci{can_inset}-p{padding}
                                                                              （+「-hole-bottom」变体）
```

各参数**实际驱动什么**：

- `can_diameter(cd)` —— 罐/管直径；孔径 = `cd + clearance`（clearance=2）。
- `padding(p)` —— **前墙/侧墙**料厚，定宽度 `dx = cd + 2p`。
- `can_inset(ci)` —— **孔深**，沿（倾斜的）孔轴方向量。
- `padding_left(pl)` —— 背/底料；影响实心底高 `base = 9 + 0.3·pl` 与背墙厚。
- `angle(a)` —— **filename 不编码的用户旋钮**：bore 与罐向外倾出的角度。
- `version(v)`。

`-hole-bottom` 变体 = 杯底排水/顶出孔，移植里折叠成 `can_holder_bottom`(`closed`/`open`)。

## 几何（真实形状）

一块竖直实心块，宽 `cd+2p`，坐在平底上；沿一条**倾斜 `angle`** 的轴钻深盲孔，罐向外倾出好抓：

- **背墙竖直**（Y=0），顶部承 french cleat。
- **前面与 bore 轴平行**（向 +Y 外倾 `angle`），侧墙保持恒定 ~`p`。
- **顶面垂直于 bore 轴** → 后部一小块水平平台 + 前部斜屋脊（屋脊斜率 = `tan(angle)`），
  这就是 1.0 有、旧平顶版缺的「斜顶」。
- **bore 口 45° 锥形导入倒角**（`leadin=3`），罐易落入。
- **竖棱 ~1mm 圆角**（`fillet=1.2`）。
- `can_holder_bottom=="open"` 时底部加一个直径 6 的竖直排水/顶出孔。
- 朝向：cleat 在背面（Y=0 竖直面）。

## 实现（构造法 —— 让角度/垂直度精确成立）

不再用「YZ 多边形 + bbox 拟合」，而是用半空间求交，让 OpenSCAD 自己算三角函数：

```
solid(inset) = 足迹棱柱(flat top@H, 各面缩 inset)
        ∩ 前斜面 (法向 (0,cos a,-sin a)，即 +Y 绕 X 转 -a → 向 +Y 外倾)
        ∩ ⊥bore 顶面 (法向 = bore 轴 (0,sin a,cos a)，轴向 L=ci+rim 处)
body  = union(
          intersection(minkowski(solid(fil), 球 r=fil), z≥0),   # 前+顶+前竖棱倒圆、平底
          intersection(solid(0), Y≤kb))                          # 背墙板:恢复尖角(榫卯侧)
        − bore 圆柱(沿轴, rotate([-a,0,0])) − 45°导入锥 − 可选排水孔
```

- **三处旋转都是 `[-a,0,0]`**（不是 `[a,0,0]`）：才能让前面与 bore 都向 +Y 上倾。
  写反会得到「上窄下宽」的倒梯形（踩过）。
- **倒角是「选择性」的（2026-06-29 第四轮，按用户图形反馈）**：1.0 只圆**前面 + 顶部**棱,
  **背面(cleat/贴墙侧)竖棱必须保持尖**——否则 french cleat 榫卯结合面不对(用户实测发现)。
  做法:`minkowski(solid(fil), 球 r=fil)` 把所有凸棱圆成 fil(`solid` 是凸多面体,minkowski 很快),
  ∩ `z≥0` 切平底(可打印),再 **union 一块名义尖角背墙板(`Y≤kb`, `kb=back_wall+fil+1`)** 把背面
  竖棱/背顶棱盖回尖角。`solid(inset)` 把足迹各面缩 `inset`、顶帽放到 `H-inset`,球长回名义尺寸
  → `dx` 仍精确。**别用竖直圆柱 minkowski**(只圆竖棱、顶棱仍是尖的,这正是前几轮「前顶棱不一样」的根因)。
- **顶部「后平台 + 斜屋脊」与 bore 开口的关系(第四轮修)**:`H` 取**开口后缘恰好落在平台前沿**
  (见 `can_holder_height()`),否则平台太深会切到开口、留下「不完整的弧」(用户图#3 发现)。
- **文字刻在竖直背面（cleat / 贴墙面），cleat 下方**——与 1.0 一致。第三轮发现:1.0 把
  `v1/cd/pl/ci/p` 五行刻在背面 Y=0 面 cleat 下方,**不是**斜前面。用标准
  `labelFace(lines, ["x", w/2, 0, w, base+2, cleat_bottom-2])`（同 einhell/hammer）：`text3d`
  anchor=CENTER 跨 Y=0 面、刻进 +Y、从外侧正读;`cleat_bottom = H - 2·slot_distance_top`。
- **文字刻在竖直背面（cleat / 贴墙面），cleat 下方**——与 1.0 一致。2026-06-29 第三轮
  按图形复核（自渲 PNG 对比）发现:1.0 把 `v1/cd/pl/ci/p` 五行刻在背面 Y=0 面 cleat 下方,
  **不是**斜前面;旧版刻在斜前面,一眼就不对,这才是「还是不对」的真正原因。改用标准
  `labelFace(lines, ["x", w/2, 0, w, base+2, cleat_bottom-2])`（同 einhell/hammer）：`text3d`
  anchor=CENTER 跨 Y=0 面、刻进 +Y、从外侧正读;`cleat_bottom = H - 2·slot_distance_top`。

## 尺寸（2026-06-29 第六轮：对全部 50+ 样本拟合的经验律，残差 <0.5mm）

角度是自由参数 ∈ {10,15,20,30,40}（filename 不编码；从前斜面**最大单片**法向 bin 取到干净值）。
逐样本实测后,以下律忠实复刻全样本(「先模仿」——1.0 顶部几何对干净一阶模型是**过约束**的,
故直接复刻实测包围盒 + deck,而非纯一阶推导)：

```
dx   = cd + 2·p                              # 精确
deck = pl                                    # 平顶深度 = padding_left
bore = cd + 2                                # clearance 2
dy   = 10.9(cleat) + pl + C(cd,p,a)          # C: max 0.28mm
dz   = ci·cos a + K(cd,p,a)                  # K: max 0.25mm

C = 1.0122·cd + 1.8276·p − 0.1120·cd·tan a − 0.2464·cd·tan²a − 9.0947·tan a + 6.3539
K = 2.2371·r·sin a + 18.3335·sin a − 0.1059·cd·tan a + 1.5820·p − 5.3775   (r=(cd+2)/2)
```

**关键结构**:1.0 里 `ci` 把 bore **向下加深**(顶部/前顶角/deck 相对顶部固定),所以 `dz` 随 ci
只增 `ci·cos a`、前面几乎不随 ci 前伸。构造改为:平底锚定,屋脊⊥bore 过 deck 边 `(pl, H)`,
前斜面 ∥bore 过前顶角 `(pl+C, H−C·tan a)`,bore 钻到屋脊齐平。**dz/deck/dx 逐件精确**。

> **dy 仍恒偏 ~1.7mm 短**(非随参数发散,是常数):≈ cleat 突出差(1.0 卯榫舌突出 10.9,
> 2.0 共用 `nut()` 突出 9.85,差 ~1mm)+ 前顶圆角把最前点拉回(~0.7mm)。cleat 是**全仓库
> 共用件**,不应为 can 单独改 → 已带方案请用户定夺(见会话)。

## 验证（mine vs 1.0，dx/dy/dz，mm；第六轮）

- cd23/pl18/ci55/p8 a20：`39.0/66.5/73.9` vs `39.0/68.2/73.9` —— dx✓ dz✓ dy−1.7(cleat)
- cd20/pl20/ci40/p10 a30：`40.0/65.8/65.3` vs `40.0/67.5/65.3` —— dz✓ dy−1.7
- cd23/pl22/ci80/p8 a20：`39.0/70.5/97.4` vs `39.0/72.2/97.4` —— dz✓ dy−1.7（大 ci 不再发散）
- cd40/pl30/ci70/p10 a30：`60.0/93.1/101.3` vs `60.0/94.8/101.3` —— dz✓ dy−1.7
- cd26/pl35/ci60/p10 a40：`46.0/80.4/86.0` vs `46.0/82.5/85.8` —— dz✓ dy−2.1

`dx`、`deck`(=pl)、`dz`、前面位置逐件精确;**dy 仅差恒定 cleat 量**(待定方案)。**形状（斜顶/
前倾/导入倒角/前+顶倒圆/背面尖角/开口完整/平台=pl）已对齐 1.0。** 文字回归通过（66/66）。

## 样例

`generated_stl/can_holder_*.stl`（构建产物，不入库）。
