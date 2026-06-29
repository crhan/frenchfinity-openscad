# 逆向 Can-Holder（Can-Holder v42.f3d → src/can_holder.scad）

罐架 / 钻头架 / 喷罐架。方法见 `porting-playbook.md`；这里只记结论与坑。

> 2026-06-29（commit f61dd49）按真实横截面几何重建：旧版是「拟合 bbox」得来的，形状完全错。
>
> 2026-06-29（第二轮）用户按图形复核发现仍「少了一些倒圆角」。逐层测量后发现差的
> 不止圆角，而是**整个顶部 + 倾角模型都错**。本文已对齐这次的构造式重建。
>
> 2026-06-29（**第三轮，本次**）一对一 STL 复核：自渲 PNG 比对 1.0 后，形状（斜顶/前倾/
> 导入倒角/竖棱圆角/cleat 位置）其实已对齐,**真正剩下的差异是文字面**——1.0 刻在竖直背面
> cleat 下方,旧版刻在斜前面。已改到背面（见下）。圆角量级实测与 1.0 相当（前角 r≈0.9mm），
> 不再加大。

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
solid = 圆角足迹棱柱(flat top@H, 略缩 fil 以补偿 minkowski 涨大)
        ∩ 前斜面 (法向 (0,cos a,-sin a)，即 +Y 绕 X 转 -a → 向 +Y 外倾)
        ∩ ⊥bore 顶面 (法向 = bore 轴 (0,sin a,cos a)，轴向 L=ci+rim 处)
body  = minkowski(solid, 竖直圆柱 r=fil)        # 只圆 4 条竖棱，保留平底可打印
        − bore 圆柱(沿轴, rotate([-a,0,0])) − 45°导入锥 − 可选排水孔
```

- **三处旋转都是 `[-a,0,0]`**（不是 `[a,0,0]`）：才能让前面与 bore 都向 +Y 上倾。
  写反会得到「上窄下宽」的倒梯形（踩过）。
- **minkowski 用竖直圆柱**（不是球）：只圆竖棱、底面保持平（可贴床打印）；
  并把足迹宽度按 `w-2·fil`、前面偏移按 `r+p-fil` 预缩，圆完后正好落在名义尺寸（`dx` 仍精确）。
- **文字刻在竖直背面（cleat / 贴墙面），cleat 下方**——与 1.0 一致。2026-06-29 第三轮
  按图形复核（自渲 PNG 对比）发现:1.0 把 `v1/cd/pl/ci/p` 五行刻在背面 Y=0 面 cleat 下方,
  **不是**斜前面;旧版刻在斜前面,一眼就不对,这才是「还是不对」的真正原因。改用标准
  `labelFace(lines, ["x", w/2, 0, w, base+2, cleat_bottom-2])`（同 einhell/hammer）：`text3d`
  anchor=CENTER 跨 Y=0 面、刻进 +Y、从外侧正读;`cleat_bottom = H - 2·slot_distance_top`。

## 尺寸

```
dx = cd + 2·p                                          # 精确
前面 & bore 向 +Y 外倾 angle                            # 构造保证
顶面 ⊥ bore 轴                                          # 构造保证
H  = base + ci·cos(a) + (cd+clearance)/2·sin(a) + rim  # flat-cap 高
```

## 验证（mine vs 1.0，dx/dy/dz，mm）

- cd23/pl18/ci55/p8 **a20**：`39.00/67.03/74.37` vs `39.00/68.16/73.91` —— dy −1.1、dz +0.5
- cd10/pl16/ci55/p10 **a20**：`30.00/55.98/71.54` vs `30.00/57.70/72.71` —— dy −1.7、dz −1.2
- cd40/pl30/ci70/p10 **a30**：`60.00/101.46/93.13` vs `60.00/94.84/101.28` —— 大角度大罐偏差较大

`dx` 逐 mm 命中；常用 a≤20 例 dy/dz 在 ±2mm。a30 大罐的高度仍偏 ~8mm（H 公式对角度的
追踪是功能近似，未对全 40 样本完美拟合）。**形状（斜顶/前倾/导入倒角/竖棱圆角）按图形已对齐 1.0。**
文字回归 `python3 test/test_labels_fit.py`：can_holder 各例通过（66/66）。

## 样例

`generated_stl/can_holder_*.stl`（构建产物，不入库）。
