# 逆向 Pliers Holder（Pilers-Holder v16.f3d → src/pliers_holder.scad）

第二个移植范例，流程照 `porting-playbook.md`。这里只记**结论**与**踩到的坑**；
通用方法见 playbook，第一个完整范例见 `reverse-engineering-rectangular-tool-holder.md`。

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
**zmax 恒为 60、zmin 随 h 下降** → 件**向下生长**（顶部叉齿/鞍口/cleat 固定，机体下延）。
脚底板恒 ~10mm（底锚定）。

## 3. 几何（切面 + 正交/透视渲染）

侧profile（Y-Z）是一只"靴"：靠墙全高背板 + 逐级向前(+Y)伸出的座和底托。
正面（X-Z）有两个**独立**特征：

1. **透空胶囊孔**（宽 hd，沿 Y 打穿）位于中下部 —— 这就是 `hole_diameter`。
2. **顶部圆弧鞍形 U 槽**，把顶边切成两根**自由叉齿**（在 cleat 之上）。

> 踩坑：一开始把"孔 + 叉口"误解成一个"钥匙槽盲腔"。原件顶视/iso 才看清是
> **两个独立特征**，且胶囊孔**真透空**（沿 Y 贯穿，侧面被 7.5mm 侧壁挡住所以侧视看不见）。
> cleat 在叉齿**下方**，不是标准的"距顶 2×slot_distance_top"。

## 4. 实现要点（src/pliers_holder.scad）

- 模块链同 rectangular：`_body()`→`_slot()`→`_with_nut()`→`_with_nut_and_text()`→`feature_…()`。
- 机体 = 三个 cube 并集（底托 / 座 / 背板），靴形。
- 槽 = 沿 Y 的胶囊 hull（透空孔）+ 顶部圆底 U 槽（叉齿）。
- cleat：复用 `nut(w,false)`，放在叉齿正下方背板上；**公差自动**（公舌缩 0.25mm，母槽不变）。
- 文字 `v/h/hd` 刻在 +X 侧壁的 **seat 矩形**内（恒为实心，短件也不溢出），
  旋转沿用已验证的 `rotate([90,0,90])`（非镜像）。

## 5. 验证

- bbox：dx=33、dz=86.00（与 1.0 精确吻合）；dy=89.85（目标 90.88，短 1.03mm，
  与 rectangular 同源——标准 `nut()` 比 1.0 卯榫略短，已知可接受）。
- 渲染：正面/侧面/iso/透视与 1.0 逐一对照吻合；文字 "v1scad/h80/hd18" 正读。
- 回归测试：`python3 test/test_labels_fit.py`（含 pliers 6 例，全过）。

## 6. 样例

`generated_stl/pliers_h{60,80,120,150}_hd{...}.stl`（构建产物，不入库）。
