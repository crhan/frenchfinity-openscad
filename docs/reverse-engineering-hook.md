# 逆向 Hook（Hook v11.f3d → src/hook.scad）

第四个移植范例。方法见 `porting-playbook.md`；这里只记结论与坑。

## 参数（f3d_inspect）

```
frenchfinity-hook-v{version}-w{width}-h{height}-hd{hook_diameter}-t{thickness}-heh{hook_end_height}
```
→ `width(w)`、`height(h)`、`hook_diameter(hd)`、`thickness(t)`、`hook_end_height(heh)`。

## 尺寸（stl_analyze，9 个样本，全 R²=1.0）

```
dx (宽 X) = w
dz (高 Z) = h
dy (深 Y) = hook_diameter + 10.88     # hd 是钩弯，10.88 是 cleat
```
干净利落——这是参数和几何最直接的一个。

## 几何

一个 **J 形钩**：Y-Z 平面的 J 轮廓沿 X 拉伸 w（前视图就是个 w 宽的竖条）。
- 背面竖直 shank（带 cleat）从顶 z=h 下到弯心 z=hd/2。
- 底部 180° 弯，**外径 = hook_diameter**（内径 = hd - 2t）。
- 前侧上翘钩尖，高 = hook_end_height（从弯心往上）。
- 杆厚 = thickness（t），整体 X 截面是平的（w 宽矩形）。

`dy=hd+10.88` 直接说明：钩身 Y 跨度 = hd（弯外径），cleat 再加 10.88。

## 实现要点

- 2D J 轮廓（shank 矩形 + 上翘尖矩形 + 下半环 annulus），`rotate([90,0,90]) linear_extrude(w)`
  把轮廓的"深度→Y、高度→Z、拉伸→X"。
- cleat 复用 `nut(w,false)` 放 shank 背面顶部；公差自动。
- 文字刻在 shank 正面（-Y 面），`rotate([90,0,0])`（非镜像）。**用每参数一行（6 行）**而非
  1.0 的 2 行紧凑布局——窄钩（w=10）下 2 行长文字会挤爆/超界，分行后自适应可读。

## 验证

- bbox（mine vs 1.0）：w20/h80/hd34 → 20/43.85/80 vs 20/44.88/80；w20/h100/hd20 → 20/29.85/100
  vs 20/30.88/100。dx/dz 精确，dy 短 ~1mm（标准 `nut()`，已知）。
- 文字 `v/w/h/hd/t/heh` 正读不镜像；回归测试 `test/test_labels_fit.py`（hook 5 例全过）。

## 样例

`generated_stl/hook_*.stl`（构建产物，不入库）。
