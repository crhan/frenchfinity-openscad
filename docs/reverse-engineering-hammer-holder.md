# 逆向 Hammer Holder（Hammer-Holder v32.f3d → src/hammer_holder.scad）

Frenchfinity 1.0「Hammer-Holder v32」的功能 + 关键尺寸移植（9 个参考 STL）。
方法见 `porting-playbook.md`；这里只记结论与坑。

## 参数（f3d_inspect）

```
frenchfinity-hammer-holder-v{version}-w{width}-hw{hammer_width}-hhw{handle_hole_width}-dph{drop_protection_height}-dpw{drop_protection_width}
```
→ `width(w)` 总宽 / 背板宽（X）、`hammer_width(hw)` 头座前后进深、
`handle_hole_width(hhw)` 手柄垂落的中央槽宽（X）、`drop_protection_height(dph)`
前唇高（挡头滑落）、`drop_protection_width(dpw)` 前唇厚（Y）。

## 尺寸（stl_analyze，9 样本）

```
dx (宽 X) = w                         # R²=1.0，精确
dz (高 Z) = 50                        # 常量，与所有参数无关，R²=1.0
dy (深 Y) = hw + 2*dpw + 26.88        # 其中 10.88 是 cleat
```
注意 `dy` 同时依赖 `hw` 和 `dpw`。工具的自动回归是**单变量**的，只拿 `dy` 对单个
code 拟合，得到 `dy = 1.100*hw + 30.35（R²=0.9639）`——不是干净拟合。手工把双参数
公式 `dy = hw + 2*dpw + 26.88` 代入全部 9 个样本，**逐个精确命中**（如 hw32.5/dpw3
→ 65.38，hw52/dpw5 → 88.88，全中），与 .scad 头注一致，故以此为准。

## 几何

整高 50mm **背板**立在 +Y，承载 french cleat；从背板下半部向前伸出**两条侧轨**
（轨高 25mm），锤**头**横搁在两轨顶面，锤**柄**从两轨之间的中央槽（hhw）垂落而下。
- 两侧轨各宽 `rail_width = (w - hhw)/2`，中间留出 hhw 的过柄槽。
- 槽底有一层薄**地板**（2mm）兜住。
- 每条轨的前端立一道**防滑唇**（drop-protection），高 dph、厚 dpw，落在 z=轨高 处。

`dy = hw + 2*dpw + 26.88` 拆开看：头座进深 hw、前后各一道 dpw 唇、背板 5、连接 11，
合计 hw+2*dpw+16 的本体，再加 cleat 10.88。

## 实现要点

- 本体 = 背板 + 两侧轨 + 薄地板 + 两道前唇，全部矩形 `cube` 并集（`hammer_holder_body`）。
  `body_depth() = hw + 2*dpw + plate(5) + 11`。
- cleat 复用 `nut(w, false)` 贴背板顶部背面；公差自动（只缩公舌）。
- 文字沿用 1.0 的三行堆叠 `v-w / hw-hhw / dph-dpw`，刻在**宽背板**上（X 读面），
  用 `labelLines` 双面：装不下的溢到背板前面（`["x", …, d]` 与 `["x", …, d-plate]`）。

## 验证（mine vs 1.0 bbox）

| 参数 | mine | 1.0 |
|---|---|---|
| w44 / hw38 / dpw5 | 44 / 73.85 / 50 | 44 / 74.88 / 50 |
| w100 / hw41 / dpw3 | 100 / 72.85 / 50 | 100 / 73.88 / 50 |

dx / dz 精确；dy 短约 1.03mm——标准 `nut()` 的 cleat 进深约 9.85 而 1.0 为 10.88，
属已知偏差（与 hook 同源）。功能与互换性不受影响。

## 样例

`generated_stl/hammer_holder_*.stl`（构建产物，不入库）。
