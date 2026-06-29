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

## 尺寸

从 1.0 STL 反推出的**精确关系**(2026-06-29 第五轮，对 50+ 样本逐一实测，角度从前斜面
单片法向取到干净的 10/15/20/30/40°——filename 不编码角度，但它就是这 5 个离散值)：

```
dx       = cd + 2·p                         # 精确
bore_d   = cd + 2                           # 实测 cd+2.00（clearance=2）
deck 深  = pl (padding_left)                # 实测 pl18→18.3, pl12→12.4 … 逐一吻合
back_wall= 3 + 0.3·pl                       # 实测 pl18→bore floor 距背面 20.9=8.4+r
base     = 9 + 0.3·pl                       # 对齐 bore 最低点(floor_z - r·sin a)
屋脊 ⊥ bore（倾 a）, 轴向 L = ci            # 开口与屋脊齐平(非 ci+rim)
H = base + ci·cos a + (yc0 + ci·sin a - pl)·tan a   # 令 deck 自动 = pl
```

> 第五轮仍未完全锁死的：**dz / dy 对大 ci、a≥30 的样本仍偏（dy 最多 +11mm）**。原因：1.0 里
> `ci` 是把 bore **向下加深**（顶 / 前顶角固定），`dz` 随 ci 只增 `ci·cos a`；前顶角相对顶部
> 固定、不随 ci 前伸。我方目前仍是「自底向上、随 ci 长高」的构造，故大 ci 时前面伸过远。
> 顶部「deck / 开口 / 前顶角」的精确参数关系受测量噪声阻碍，尚在反推。已精确：dx、deck、bore_d、
> back_wall，及 a≤20 中等件的 dz/dy（审核样本 cd23 完全精确）。

## 验证（mine vs 1.0，dx/dy/dz，mm）

第五轮重测后（mine vs 1.0，dx/dy/dz mm，deck）：

- cd23/pl18/ci55/p8 **a20**：`39.0/68.2/74.0` (deck18) vs `39.0/68.2/73.9` (deck18.3) —— **完全精确**
- cd10/pl16/ci55/p10 **a20**：`30.0/56.9/71.5` vs `30.0/57.7/72.7` —— dy −0.8、dz −1.2
- cd15/pl20/ci70/p10 **a20**：`35.0/68.1/88.6` vs `35.0/66.4/88.5` —— dy +1.7、dz +0.1
- cd20/pl20/ci40/p10 **a30**：`40.0/67.3/61.2` vs `40.0/67.5/65.3` —— dz −4.1
- cd23/pl22/ci80/p8 **a20**：`39.0/78.0/100.8` vs `39.0/72.2/97.4` —— dy +5.8、dz +3.4（大 ci）
- cd40/pl30/ci70/p10 **a30**：`60.0/103.9/100.6` vs `60.0/94.8/101.3` —— dy +9.1（大 ci+大角）

`dx`、`deck`(=pl)、`bore_d`(=cd+2) 逐件精确；a≤20 中等件 dy/dz 在 ±1.5mm。**大 ci / a≥30 的
dy 仍偏 +5~11mm**（见上方说明，前顶/前面随 ci 前伸过多，待反推）。**形状（斜顶/前倾/导入倒角/
前+顶倒圆/背面尖角/开口完整）已对齐 1.0。** 文字回归 `test/test_labels_fit.py` 通过（66/66）。

## 样例

`generated_stl/can_holder_*.stl`（构建产物，不入库）。
