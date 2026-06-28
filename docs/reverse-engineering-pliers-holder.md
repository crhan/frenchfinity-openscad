# 逆向 Pliers Holder（Pilers-Holder v16.f3d → src/pliers_holder.scad）

第二个移植范例，流程照 `porting-playbook.md`。这里只记**结论**与**踩到的坑**；
通用方法见 playbook，第一个完整范例见 `reverse-engineering-rectangular-tool-holder.md`。

> **2026-06-29 精修（commit 0b190a1）：正面改为实心。** 早先的移植把胶囊腔 + 鞍口
> 直接切穿正面（看上去透空）；原件 1.0 正面是**封闭**的，钳子从**顶部**装入。现在
> 两处切削都只切穿「座深」（Y 落在 `[front_wall, body_depth - plate]`），正面壁与
> 背板/cleat 都保持实心，标签也随之移到实心正面。

## 1. 参数（f3d_inspect）

ParametricText 模板：
```
frenchfinity-pilers-holder-v{version}-h{height}-hd{hole_diameter}
v{version}{nl}h{height}{nl}hd{hole_diameter}
```
→ 两个 User Parameter：`height (h)`、`hole_diameter (hd)`（外加 version）。

## 2. 尺寸回归（stl_analyze regress，12 个样本，R²=1.0）

```
dx (宽 X) = hole_diameter + 15      # 孔宽 hd + 两侧各 7.5mm 壁
dz (高 Z) = height + 6
dy (深 Y) = 90.88                    # 常数，与参数无关
```

只有**宽随 hd、高随 h**；深度与整套脚/卯榫结构全固定。比较不同 h 的 bbox 发现
**zmax 恒定、zmin 随 h 下降** → 件**向下生长**（顶部叉齿/鞍口/cleat 固定，机体下延）。
脚底板恒 ~10mm（底锚定）。

## 3. 几何（切面 + 正交/透视渲染）

侧 profile（Y-Z）是一只"靴"：靠墙全高背板 + 逐级向前伸出的座和底托。
中间挖两个**独立**特征，从**顶部**装入钳子：

1. **胶囊腔**（宽 hd，沿 Y 的 stadium hull）位于中下部 —— 这就是 `hole_diameter`。
   顶锚定，距顶部鞍口下方留一道 `hole_bridge` 桥；总高 `max(hd, min(2·hd, 可用空间))`，
   既不吃掉桥、也给孔底留 `hole_floor` 实料。
2. **顶部圆弧鞍形 U 槽**（圆底圆柱 + 直壁向上），把顶边切成两根**自由叉齿**（在 cleat 之上）。

**两处切削都只在「座深」范围内（Y∈`[front_wall=6, body_depth-plate=67.5]`）**，所以：
- 正面壁（6mm）实心 → 正面封闭，对齐 1.0；
- 背板/cleat（12.5mm）实心 → cleat 有完整附着面。

> 踩坑（已在 2026-06-29 修正）：一开始按"侧/iso 看不到孔"误判孔是**沿 Y 真透空**，
> 把胶囊 + 鞍口切穿了正面。其实 1.0 **正面是封闭的，钳子从顶部塞入**；现已把两处
> 切削限制在座深之内。另：cleat 在叉齿**下方**，不是标准的"距顶 2×slot_distance_top"。

## 4. 实现要点（src/pliers_holder.scad）

- 模块链同 rectangular：`_body()`→`_slot()`→`_with_nut()`→`_with_nut_and_text()`→`feature_…()`。
- `_body()` = 三个 cube 并集，靴形：底托（全深、toe=10、底锚定）/ 座（从背面向前 seat=54、
  到 `seat_top`，由 `seat_frac=0.55` 定）/ 背板（全高、plate=12.5、承 cleat）。
- `_slot()` = 沿 Y 的胶囊 hull（`_y_capsule`）+ 顶部圆底 U 槽；二者居中于 X，
  且 Y 仅 `[front_wall, body_depth-plate]` → 正面与背板留实。
- cleat：复用 `nut(w,false)`，放在叉齿正下方背板上（`cleat_top = h - prong_depth`）；
  **公差自动**（公舌缩 0.25mm，母槽不变）。
- 文字 `v/h/hd` 刻在**实心正面**（X 读面，朝 -Y，不翻转）的下部座区：
  `labelFace([...], ["x", w/2, 0, w, 2, seat_top])`。原先刻在 +X 侧壁，精修后随正面变实心而迁移。

关键常数（绝对值，取自 1.0）：`side_wall=7.5`、`base_extra=6`、`body_depth=80`、
`plate_depth=12.5`、`seat_depth=54`、`toe_height=10`、`seat_frac=0.55`、`prong_depth=13`、
`hole_bridge=4`、`hole_floor=12`、`front_wall=6`。

## 5. 验证

- bbox（h80/hd18）：dx=33.00、dz=86.00（1.0 为 86.06，吻合）；dy=89.85
  （目标 90.88，短 1.03mm，与 rectangular 同源——标准 `nut()` 比 1.0 卯榫略短，已知可接受）。
- 渲染：正面/侧面/iso/透视与 1.0 逐一对照吻合；**正面实心**、钳子从顶部入；
  文字 "v1scad/h80/hd18" 在正面正读。
- 回归测试：`python3 test/test_labels_fit.py`（含 pliers 例，全过）。

## 6. 样例

`generated_stl/pliers_h{60,80,120,150}_hd{...}.stl`（构建产物，不入库）。
