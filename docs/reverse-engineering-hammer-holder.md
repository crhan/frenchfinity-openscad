# 逆向 Hammer Holder（Hammer-Holder v32.f3d → src/hammer_holder.scad）

Frenchfinity 1.0「Hammer-Holder v32」的功能 + 关键尺寸移植（9 个参考 STL）。
方法见 `porting-playbook.md`；这里只记结论与坑。

> **2026-06-29 重建（commit f6203a6）**：早先的移植用「两条独立侧轨 + 平底矩形槽」，
> 与 1.0 不符。1.0 实为**整块实心摇篮（cradle）+ 圆底 U 形手柄槽 + 实心前壁**。本文已
> 改写为当前实现。

## 参数（f3d_inspect）

```
frenchfinity-hammer-holder-v{version}-w{width}-hw{hammer_width}-hhw{handle_hole_width}-dph{drop_protection_height}-dpw{drop_protection_width}
```
→ `width(w)` 总宽 / 背板宽（X）、`hammer_width(hw)` 头座前后进深、
`handle_hole_width(hhw)` 手柄垂落的中央 U 槽宽（X）、`drop_protection_height(dph)`
前壁高出座面的部分（挡头滑落）、`drop_protection_width(dpw)` 前壁厚（Y）。

## 尺寸（stl_analyze，9 样本）

```
dx (宽 X) = w                         # R²=1.0，精确
dz (高 Z) = 50                        # 常量，与所有参数无关
dy (深 Y) = hw + 2*dpw + 26.88        # 其中 10.88 是 cleat
```
注意 `dy` 同时依赖 `hw` 和 `dpw`。工具的自动回归是**单变量**的，只拿 `dy` 对单个
code 拟合，得不到干净结果。手工把双参数公式 `dy = hw + 2*dpw + 26.88` 代入全部 9 个
样本逐个精确命中（如 hw32.5/dpw3 → 65.38，hw52/dpw5 → 88.88，全中），与 .scad 头注
一致，故以此为准。

## 几何

整高 50mm **背板**立在 +Y，承载 french cleat。背板前方是一整块**较矮的实心摇篮块**
（`cradle_h = 38`，低于背板顶），从顶面向下铣出一道**中央 U 形手柄槽**：

- 槽宽 = `hhw`，**底部为圆弧**（半径 `r = hhw/2`，圆心 `zc = cradle_h - 8`，即上方留
  8mm 直壁段、下方接半圆）。锤**头**横搁在 U 槽两侧的摇篮肩面上，锤**柄**垂落进 U 槽。
- U 槽**不切穿前壁**：前面留一道厚 `dpw` 的**实心前壁**（防滑 drop-protection），槽
  从 `y = dpw` 处才开始向后挖。前壁因此保持完整，正面可刻字，也对齐 1.0 的正面外观。
- 前壁在座面（`z = cradle_h`）之上再**升高 `dph`**，形成挡头滑落的前唇。

`dy = hw + 2*dpw + 26.88` 拆开看：头座进深 hw、前后各一道 dpw、背板 5、连接 11，合计
hw+2*dpw+16 的本体，再加 cleat 10.88。

## 实现要点

- 固定量：`height=50`、`plate_depth=5`（背板厚）、`cradle_h=38`（座高）。
- 本体（`hammer_holder_body`）= 全高背板 `cube` + 实心摇篮 `cube` **difference 掉**
  U 槽（矩形直壁段 + 横放 `cylinder` 圆底，`$fn=96`）+ 顶上一道前唇 `cube`。
  `body_depth() = hw + 2*dpw + plate(5) + 11`。
- cleat 复用 `nut(w, false)` 贴背板顶部背面（+Y）；公差自动（只缩公舌）。
- 文字：1.0 的三行堆叠 `v-w / hw-hhw / dph-dpw`，刻在**实心前壁**上（`labelFace`，X 读
  面、朝 -Y，装好后正对使用者），区间 `["x", w/2, 0, w, 2, rh-2]`。不再刻背板。

## 验证（mine vs 1.0 bbox）

| 参数 | mine | 1.0 |
|---|---|---|
| w100 / hw36 / hhw38 / dph5 / dpw3 | 100 / 67.85 / 50 | 100 / 68.88 / 50 |

dx / dz 精确；dy 短约 1.03mm——标准 `nut()` 的 cleat 进深约 9.85 而 1.0 为 10.88，
属已知偏差（与 hook 同源）。功能与互换性不受影响。

## 样例

`generated_stl/hammer_holder_*.stl`（构建产物，不入库）。
