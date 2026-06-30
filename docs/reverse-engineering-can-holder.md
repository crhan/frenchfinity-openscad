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
> 2026-06-29（第四轮）用户在切片器里加载我方 vs 1.0,圈出三处:① 前顶棱 1.0 是**圆**的、
> 我方是**尖**的;② 背面竖棱(榫卯侧)我方被圆了、**必须改回尖**(否则结合面不对);③ 顶部 bore 开口
> 我方被后平台切到、成「不完整的弧」。三处全部修复:**选择性倒角**（球 minkowski 圆前+顶,
> union 尖角背墙板保住榫卯侧）+ 重设 `H` 让平台前沿落在开口后缘（开口完整）。详见「实现」。
>
> 2026-06-30：按用户要求重写倒圆角实现，弃用球 minkowski/union 修补，改用 BOSL2
> `rounded_prism()` 从 YZ 侧面轮廓沿 X 挤出，`joint_sides=[0,0,fillet,fillet,0]`
> 在单个 VNF 里只圆前顶/平台转折，背面 cleat 侧保持尖角且没有 CSG 接缝。
>
> 2026-06-30（v2.1 review）：按代码对比重新复查 `generated_stl/review/Can-Holder.v2.1.ours.stl`
> vs `Can-Holder.ref.stl`。bbox 几乎完全对齐但 surface 热点仍明显；修复两处肉眼问题：
> 左右端面 perimeter 也用 BOSL2 roundover，补上侧边外圆角；bore 平底端沿孔轴向下多切 4mm，
> 去掉水平截面里明显的平切线；背面文字改成 1.0 的两位小数格式和固定 3.5mm 字高。

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

不再用「YZ 多边形 + bbox 拟合」。外壳先按实测经验律算出 YZ 侧面轮廓，再用 BOSL2
`rounded_prism()` 直接生成带选择性圆角的 VNF；bore、导入锥和排水孔仍用 CSG difference：

```
profile = [
  back-bottom,
  front-bottom,
  front-top,
  deck/front-roof transition,
  back-top
]
outer = BOSL2 rounded_prism(profile, height=width,
                            joint_sides=[0,0,fillet,fillet,0],
                            joint_bot=fillet, joint_top=fillet)
        mapped from BOSL2 Z-extrusion back to model X-extrusion
body  = outer − bore 圆柱(沿轴, rotate([-a,0,0]), bottom_extra=4)
             − 45°导入锥 − 可选排水孔
```

- **三处旋转都是 `[-a,0,0]`**（不是 `[a,0,0]`）：才能让前面与 bore 都向 +Y 上倾。
  写反会得到「上窄下宽」的倒梯形（踩过）。
- **倒角是「选择性」的（2026-06-30 BOSL2 重写）**：1.0 只圆**前面 + 顶部**棱,
  **背面(cleat/贴墙侧)竖棱必须保持尖**——否则 french cleat 榫卯结合面不对。当前做法是把
  YZ 侧面轮廓作为 BOSL2 `rounded_prism()` 的 profile，`joint_sides` 按 profile 顶点逐项控制：
  `[back-bottom, front-bottom, front-top, deck-transition, back-top] = [0,0,fillet,fillet,0]`。
  `joint_bot=joint_top=fillet` 给左右端面 perimeter 也加 roundover，补齐从水平截面能看到的
  侧边外圆角。这比 `minkowski()+union()` 更接近 Fusion 的 B-rep 圆角：圆角和尖角在同一个
  VNF 中生成，没有两块 CSG 拼出来的台阶/缝。
- **bore 底部不是球头**：试过球头会把 volume ratio 从约 0.956 拉坏到约 0.918。1.0 更像是
  同一根斜圆柱沿轴向下多切一点，让平底 cap 藏到更深处；当前 `can_holder_bore_bottom_extra=4`
  后，代码对比 p95 从约 1.42 降到约 1.28，max 从约 4.47 降到约 3.17，水平截面里的平切线消失。
- **顶部「后平台 + 斜屋脊」与 bore 开口的关系(第四轮修)**:`H` 取**开口后缘恰好落在平台前沿**
  (见 `can_holder_height()`),否则平台太深会切到开口、留下「不完整的弧」(用户图#3 发现)。
- **文字刻在竖直背面（cleat / 贴墙面），cleat 下方**——与 1.0 一致。2026-06-29 第三轮
  按图形复核（自渲 PNG 对比）发现：1.0 把 `v1/cd/pl/ci/p` 五行刻在背面 Y=0 面 cleat 下方，
  **不是**斜前面；旧版刻在斜前面，一眼就不对。2026-06-30 v2.1 再修文字细节：1.0 F3D
  文本模板是 `cd{:.2f}/pl{:.2f}/ci{:.2f}/p{:.2f}`，且字高约 3.5mm；can holder 因此不走通用
  adaptive 放大，固定 `text_size_min` 并用 `text_depth*2` 保证背面刻入深度。

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
前斜面 ∥bore 过前顶角 `(pl+C, H−C·tan a)`,bore 钻到屋脊齐平。

**dy 的两处修正(第七轮,2026-06-29)**:
1. **共用 `nut()` 的 `outer_width` 5.6→6.6**(全仓库件)。作者早在 `frenchfinity.scad:190`
   注释「set this to 6.6 or 6.5 ... compatible to legacy frenchfinity parts」——5.6 让每个件的
   卯榫舌都比 1.0 短 ~1mm。改 6.6 后:母槽 6.6+4.5=11.1(=1.0 母槽)、公舌 6.6+4.25=10.85
   (≈1.0 的 10.9,差 0.05 = 保留的 FDM 打印间隙,1.0 自己 STL 也留了 ~0.2)。**保留 0.25 公差**,
   不必去掉(STL 与 1.0 实质一致且仍可打印)。
2. **前顶圆角拉回补偿**:球 minkowski 把最前点拉回 `pullin(a)=0.04a−0.00047a²`(fil=2,实测随
   角度单调、与 cd/p 无关)。前面按 `pl+C+pullin` 建,圆完正好落在 `pl+C`(=1.0)。

## 验证（mine vs 1.0，dx/dy/dz，mm;第七轮——全样本精确到 ±0.3mm）

- cd23/pl18/ci55/p8 a20：`39.0/68.1/73.9` vs `39.0/68.2/73.9`
- cd20/pl20/ci40/p10 a30：`40.0/67.5/65.3` vs `40.0/67.5/65.3` —— 精确
- cd23/pl22/ci80/p8 a20：`39.0/72.1/97.4` vs `39.0/72.2/97.4`（大 ci 不发散)
- cd40/pl30/ci70/p10 a30：`60.0/94.8/101.3` vs `60.0/94.8/101.3` —— 精确
- cd26/pl35/ci60/p10 a40：`46.0/82.2/86.0` vs `46.0/82.5/85.8`（最差 dy−0.3)
- cd10/pl10/ci70/p10 a10：`30.0/53.7/84.7` vs `30.0/53.7/84.7` —— 精确
- cd18/pl30/ci120/p10 a15：`38.0/80.4/136.4` vs `38.0/80.5/136.4`

`dx`、`deck`(=pl)、`dz`、`dy` 全样本(全 cd/pl/ci/p × angle 10/15/20/30/40)逐件精确(±0.3mm)。
2026-06-30 BOSL2 重写后全量复验 `FrenchFinity/Can-Holder/*.stl`：53/53 编译成功，逐件从
bbox 反推最匹配 angle(10/15/20/30/40) 后重新生成，全部 bbox 误差 <0.5mm；最大偏差仍为
`dy=-0.30mm/dz=+0.25mm`（cd26/pl35/ci60/p10/a40，旧文档已知最差样本）。`hole-bottom`
变体 cd23/pl22/ci80/p8/a20 编译为 manifold，bbox `39.00/72.15/97.40` vs 1.0
`39.00/72.16/97.40`。
**主体结构(斜顶/前倾/导入倒角/前+顶倒圆/背面尖角/开口完整/平台=pl)已对齐 1.0。**
v2.1 继续用 surface diff 追踪局部圆角/文字/孔底差异；文字回归通过(66/66)。

2026-06-30 v2.1 review 对比产物：

- `generated_stl/review/Can-Holder.v2.1.diff.txt`
- `generated_stl/review/Can-Holder.v2.1.official-diff.txt`
- `generated_stl/review/Can-Holder.v2.1.x-sections.png`
- `generated_stl/review/Can-Holder.v2.1.z-sections.png`

`official-diff.txt` 来自项目首选 `tools/stl_diff.py`：bbox Δ `[+0.00,-0.01,+0.00]`，
volume ratio `0.936`，`ours→ref` mean/p95/max =
`0.452/0.825/2.884mm`，`ref→ours` mean/p95/max = `0.440/0.799/2.000mm`，
symmetric Hausdorff `2.884mm`，`62.8%` surface within `0.50mm`，脚本判定 `CLOSE`。
剩余热点集中在背面顶部文字/cleat 附近（extra，z≈63）和背面低位孔/文字附近（missing，z≈21-34）。

## 卯榫配合验证（2026-06-29，求交集实测，已通过）

用户要求确认 can 公舌与 1.0 wall anchor（`FrenchFinity/Wall-Anchor/...w60.00.stl`）母槽**形成配合间隙**。

**结论：完美配合，0.0000 mm³ 干涉，`nut()` 无需任何改动。**

方法（脚本在 `scratchpad/can/`）：把 1.0 wall anchor 重心化到干净坐标（`wa2.stl`：X[0,60] Y[0,20] Z[1,60]，与原始件同一零件，仅平移），用三角形×切平面精确切出母槽轮廓；默认 can（`can_def.stl`）按配合位 `translate([15,20,-9.04])`（X 对中、背面 Y 贴配合面、舌中 Z 49.36 对槽中）放入，`intersection()` 求重叠体积。

- 1.0 母槽是**矩形 T 形槽，不是斜燕尾**：颈 Z[46.11,52.61]（高 6.5）、腔 Z[45.11,53.61]（高 8.5），颈/腔过渡是 `Y=13.40` 处**直角竖直台阶**；腔背壁中央有让位斜面凹到 Y=7.37（给**更多**间隙，不是倒角）；背角本身（Y=8.90）是**尖角**。**没有「燕尾后角倒角」可逆向。**
- 我方公舌（0.25 公差）：颈 Z 6.25、头 Z 8.25、突出 10.85，映射进槽后每个颈/腔 Z 面留 0.125mm、舌尖留 0.25mm 间隙。
- 求交 = **0.0000 mm³**（872 个面是零厚度贴合接触面）。自检：公舌 Z 偏 ±0.5mm → ~122 mm³，证明测试**能**测出干涉（故 0 是真配合，非假阴性）。

> 历史教训：更早一次用**原始** wall anchor（不同坐标系 Y[19.61,39.61]）+ 手调平移报过「~165mm³」，那是 ~0.5mm **对齐误差**造成的（公舌扎进实体），不是形状缺陷。配合求交测试只有在**双方对齐位经过验证**时才有效——务必先扰动一方确认能报出非零、并目视确认对齐，再信那个数。

## 样例

`generated_stl/can_holder_*.stl`（构建产物，不入库）。
