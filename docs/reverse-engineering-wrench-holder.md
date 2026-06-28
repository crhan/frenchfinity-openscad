# 逆向 Wrench Holder（Wrench-Holder v26.f3d → src/wrench_holder.scad）

扳手架。方法见 `porting-playbook.md`；这里只记结论与坑。
属**功能 + 关键尺寸保真件**（非逐面复刻）：横截面随 `scale` 缩放、槽数随 `width` 增长。

## 参数（f3d_inspect）

```
frenchfinity-wrench-holder-v{version}-ww{wrench_width}-w{width}-s{scale}
```
→ `width(w)`、`scale(s)`、`wrench_width(ww)`。三个 Fusion 用户参数：

- `width(w)`：架体往墙外伸出的长度（Y），越大梳齿越多、槽越多。
- `scale(s)`：缩放横截面（X 宽、Z 高），不动 Y。
- `wrench_width(ww)`：梳齿之间的槽口间隙，**只影响内部、不改 bbox**。

## 尺寸（stl_analyze，35 个样本）

```
dy (深 Y) = 1.000*w + 25.880        # R²=1.0000，精确（其中 10.88 是 cleat）
dx (宽 X) = 44.768*s + 4.490        # R²=0.9913，scale 主导宽度
dz (高 Z) = max(14.20, 11.2*s+7.4)  # scale 主导高度，带下限
```

- `dy` 与 `width` 是全仓库最干净的一条：斜率精确 1.0、截距 25.88。
- `dz`：工具的单段线性拟合给 `9.931*s + 8.983`（R²=0.9799），但那是被小件
  下限拉偏的结果。改用「下限 + 线性」两段式后对样本几乎精确（实测对照见下），
  故头注与 .scad 采用 `max(14.20, 11.2*s+7.4)`：
  s=0.40→14.20（实测 14.20）、s=1.00→18.60（实测 18.64）、s=1.78→27.34（实测 27.41）。
- `ww` 与 `dx/dy/dz` 都只是因为它和 s/w 同步增长才相关（dx≈5.6\*ww 等 R²≈0.96），
  实际只决定槽口宽，单独变 `ww` 时 bbox 不变 —— 与头注一致。

## 几何

一个朝前开口的**双梳齿插槽架**，cleat 在 +Y（后）：

- 后端一块 cleat 底座（Y 深 `base=15`），承载 french cleat 卯榫。
- 两条侧轨（梳背）从底座往前贯穿全长，各占 X 宽的 30%。
- 底部一层通槽地板（Z 厚 = 高的 30%）。
- 两侧轨各向内伸出一排梳齿（每齿向内伸 = 轨宽 ×0.6），齿与齿之间形成一排
  开顶插槽；扳手落进槽里、卡在齿间。
- 槽节距 `pitch = wrench_width + 4`（齿长 4mm@scale1），齿数 = `floor((w-4)/pitch)`。
- 底座中央一个 ⌀3 螺孔/料孔贯穿地板。

横截面（轨 + 通道 + 高）随 `scale` 缩放；槽数随 `width` 增长。

## 实现要点

- 横截面尺寸不直接存，用函数算：`outer_width()=44.77*s+4.49`、
  `outer_height()=max(14.20,11.2*s+7.4)`、`rail_width()=outer_width*0.30`。
- body 的 Y 长 = `width + base(15)`；cleat 复用 `nut(w,false)` 贴后顶，公差自动。
- 文字刻在两条长侧轨的侧面（Y 读）：右轨 `v / ww`、左轨 `w / s`，
  走 `labelLines`，封顶不溢出（轨够长）。后面被满宽 cleat 挡住、架体短（~18mm），
  故不刻正面/背面。

## 验证（mine vs 1.0 bbox）

| 样本 (ww/w/s) | mine dx/dy/dz | 1.0 dx/dy/dz |
|---|---|---|
| 8.0 / 56 / 1.00 | 49.26 / 80.85 / 18.60 | 48.49 / 81.88 / 18.64 |
| 3.4 / 27 / 0.40 | 22.40 / 51.85 / 15.66 | 26.15 / 52.88 / 14.20 |

- `dy` 短 ~1mm：标准 `nut()` 公舌实际伸出 9.85（5.6+4.5-0.25）而非名义 10.88，已知偏差。
- `dx` 大件几乎吻合（+0.77，scad 走回归线、1.0 实测略低于线）；
  **小件偏窄**：s=0.40 时线性式给 22.40，1.0 实测 26.15，差 ~3.7mm —— 线性式在
  小 scale 端低估了宽度（dx 也有类似下限行为，线性模型没建）。
- `dz` 大件精确；**小件（高被 floor 到 14.20）偏高 ~1.5mm**：此时 cleat 定位
  `up(h-2*slot_distance_top)` 为负，卯榫锁头下探到 z≈-1.46，使 mine dz=15.66 > 14.20。
- 文字回归测试 `python3 test/test_labels_fit.py`（含 wrench 例）通过。

## 样例

`generated_stl/wrench_holder_*.stl`（构建产物，不入库）。
