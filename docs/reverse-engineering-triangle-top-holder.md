# 逆向 Triangle Top Holder（Triangle-Top-Holder.f3z → src/triangle_top_holder.scad）

> **2026-06-29 重建（commit 78f7d7f）**：早期移植错做成「薄前板 + 全深顶部托杯 + 巨大锥形支脚（中间空心）」；
> 比对 1.0 侧剖面后确认 1.0 是一块**实心板**。现已按实心板重建，本文同步更新。

最后一个移植件。1.0 源是 **loose f3z（XRef 容器）**，最初无 STL/可用预览，参数虽抽得出但几何无从确定，
一度记录跳过；后来用户**从 Fusion 导出了 2 个 STL**，据此完成功能保真移植。

## 参数（f3d_inspect，读 f3z 内嵌的 .f3d）

f3z 解包后内含两个 .f3d：一个是 XRef 进来的 french-plate（忽略），另一个是本体：

```
frenchfinity-triangle-top-holder-v{version}-tw{tool_width}-hh{holder_height}-th{triangle_height}-td{tool_depth}
```
→ `tool_width(tw)`、`holder_height(hh)`、`triangle_height(th)`、`tool_depth(td)`。

## 尺寸（stl_analyze，2 个样本，两点皆精确）

样本：`tw35 hh100 th25 td17.5` 与 `tw96 hh155 th47 td11`。两点联立即可解出三条线性关系：

```
dx = tool_width    + 12      # 槽宽 + 两侧各 6mm 壁（xwall）
dy = tool_depth    + 20.88   # 槽深 + 前壁 5 + 背壁 5 + cleat 公舌 10.88
dz = holder_height + 5
```
- A：`47 / 38.38 / 105`，B：`108 / 31.88 / 160`，两样本对三式逐一精确命中。
- `th`（triangle_height）**不进 bbox**——它是底部三角支脚（gusset）的高度，A=25、B=47，从侧剖面可见高度随之变化。
  支脚最深 Y=`td+10+8`（gusset=8），仍落在 cleat 公舌的 Y 范围内，故不撑大 dy。
- 注意 1.0 导出的是 **ASCII STL**，`stl_analyze` 只读二进制；先用 openscad `import` 转 `--export-format binstl` 再量：
  ```
  printf 'import("PATH");' > /tmp/i.scad
  openscad -o /tmp/c.stl --export-format binstl /tmp/i.scad
  ```

## 几何（实心板 + 顶部开槽 + 背面 cleat + 底部三角撑）

侧剖面（`projection(cut=true)` 实测）：自顶到底是一整块实心板，工具槽从**顶面**切入，背面顶部挂 cleat，
底部背侧有一小块三角楔撑住 cleat 下方的墙。

- **实心板**：`cube([w, d, hz])`——`w = tw+12`、`d = td+frontwall+backwall = td+10`、`hz = hh+5`，全宽、全深、全高。
  正面（Y=0 面）整面实心，刻字就刻在这里。
- **顶部工具槽**：`cube([tw, td, sd+1])` 从顶面切入，`tw×td` 矩形开口，工具竖直落入。
  下切深度 `sd = min(hz-12, td+18)`（保证槽底之下至少留 12mm 实板）；槽两侧各留 6mm 壁、前后各 5mm 壁。
- **底部三角撑（"triangle" / gusset）**：Y-Z 平面直角三角形 `polygon([[d,0],[d+8,0],[d,min(th,hz)]])`，
  沿 X 拉伸满宽（`rotate([90,0,90]) linear_extrude(w)`，同 hook 惯用法）。
  z=0 时最外凸到 Y=`d+8`，到 z=`th` 收回板背 Y=`d`；撑住 cleat 下方的墙（防翻）。
  它的最大 Y 仍小于 cleat 公舌，所以 dy 不变。
- **cleat**：`nut(w,false)` 贴板背（Y=`d`），`up(hz - 2*slot_distance_top) back(d)` 置于顶部，公舌朝 +Y；公差自动。

## 实现要点 / 功能保真取舍

- 三条 bbox 公式精确复刻；工具槽 `tw×td`、底部三角撑 `th`、cleat 一应俱全，与 1.0 实物互换。
- 与旧移植的根本区别：**不再是薄前板 + 全深托杯 + 锥形空心支脚**，而是一块实心板顶部开槽。
  实心板更省事、更稳，也与 1.0 侧剖面一致；1.0 三角撑过渡略圆滑，本移植用直边楔，属外形细节、功能等价。
- 文字 `v/tw/hh/th/td` 刻正面（X 读面，板已实心）floored，放不下溢到背面；字号自适应。

## 验证（mine vs 1.0 bbox）

```
A tw35 hh100 th25 td17.5     dx       dy       dz
mine                       47.00    37.35   105.00
1.0                        47.00    38.38   105.00
diff                        0.00    -1.03     0.00

B tw96 hh155 th47 td11       dx       dy       dz
mine                      108.00    30.85   160.00
1.0                       108.00    31.88   160.00
diff                        0.00    -1.03     0.00
```
dx/dz 精确；dy 短 1.03mm（标准 `nut()` 公舌 9.85 vs 名义 10.88，与全系一致）。
文字回归 `test/test_labels_fit.py`：triangle 4 例全过。

## 样例

`generated_stl/triangle_*.stl`（构建产物，不入库）。
