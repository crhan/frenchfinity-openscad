# 逆向 Round Hanging Holder（Round-Hanging-Holder v8.f3d → src/round_hanging_holder.scad）

第三个移植范例。方法见 `porting-playbook.md`；这里只记结论与坑。

## 参数（f3d_inspect）

```
frenchfinity-round-hanging-holder-v{version}-v{version}-td{tool_diameter}-hd{holder_depth}-bhw{bottom_hole_width}-id{inset_depth}
```
→ `tool_diameter(td)`、`holder_depth(hd)`、`bottom_hole_width(bhw)`、`inset_depth(id)`。

## 尺寸（stl_analyze，仅 4 个样本）

```
dz (高 Z) = td + 10            R²=1.0
dy (深 Y) = holder_depth + 20.88   R²=1.0
dx (宽 X) = td + 10            （bhw=20 的样本成立；见下方坑）
```

## 几何

箱体上一条**沿 Y 的半圆托槽**（r=td/2），圆形工具躺在里面：
- 托槽两侧轨高 = td/2 + 5，谷底 z=5，工具中心在轨顶、上半露出。
- **前壁**（实心、全高 td+10）刻字；**后壁**（全高）带 cleat；托槽夹在两壁间，长 = holder_depth。
- 托槽下方一条 **bhw 宽的槽**连到底部（推出 / 悬挂开口）。
- **inset_depth** = 工具在后壁里的座孔深度（托槽圆柱向后壁多挖 id）。

## 坑

1. **dx 的 bhw 干扰建不了模**：4 个样本里 bhw=20 的都满足 dx=td+10，但唯一 bhw=9 的样本
   dx 宽出约 10mm（td60→80.12）。样本太少无法可靠建模这个交互，遂取干净的 dx=td+10
   （同 rectangular 的 hole-shrink артефакт处理）。dx 偏差仅在该离群样本出现。
2. **文字朝向**：前壁是 -Y 面，正确旋转是 `rotate([90,0,0])`；用 `rotate([90,0,180])` 会镜像。
3. dx 非整数（69.66 / 80.12）来自外缘微小圆角，本实现用平壁，差 <1mm（离群点除外）。

## 验证

- bbox（mine vs 1.0）：td39 → 49/40.85/49 vs 49/41.88/49；td59 → 69/28.85/69 vs 69.66/29.88/69。
  dx/dz 吻合（<1mm），dy 短 ~1mm（标准 `nut()` 比 1.0 卯榫浅，已知）。
- 公差：复用 `nut(w,false)`，公舌自动缩 0.25mm。
- 文字 `v/td/hd/bhw/id` 正读、自适应、不溢出；回归测试 `test/test_labels_fit.py`（round 5 例全过）。

## 样例

`generated_stl/round_td*.stl`（构建产物，不入库）。
