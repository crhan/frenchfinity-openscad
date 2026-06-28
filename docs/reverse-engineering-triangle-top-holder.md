# 逆向 Triangle Top Holder（Triangle-Top-Holder.f3z → src/triangle_top_holder.scad）

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
dx = tool_width    + 12      # 槽宽 + 两侧各 6mm 壁
dy = tool_depth    + 20.88   # 槽深 + 背壁 + cleat（10.88）
dz = holder_height + 5
```
- A：`47 / 38.38 / 105`，B：`108 / 31.88 / 160`，两样本对三式逐一精确命中。
- `th`（triangle_height）**不进 bbox**——它是底部三角支脚的高度，A=25、B=47，从侧剖面可见高度随之变化。
- 注意 1.0 导出的是 **ASCII STL**，`stl_analyze` 只读二进制；先用 openscad `import` 转 `--export-format binstl` 再量。

## 几何（直立前板 + 顶部托槽 + 底部三角支脚 + 背面 cleat）

侧剖面（`projection(cut=true)` 实测）：顶部一段全深的托槽，中段薄板，底部一块往背面外凸的三角楔。

- **前板**：`cube([tw+12, frontwall, hh+5])`，全高平面，正面刻字。
- **顶部托槽**：全深块 `cube([w, td+10, cradle_h])` 挖一个 `tw×td` 顶开口槽（落差 `floor=8` 托底），
  工具竖直落入；背壁承 cleat。
- **底部三角支脚（"triangle"）**：Y-Z 平面的直角三角形，底（z=0）最深 Y=`td+10`、到 z=`th` 收回前板，
  沿 X 拉伸满宽（`rotate([90,0,90]) linear_extrude` 同 hook 的惯用法）。撑住薄板、并抵住 cleat 下方的墙
  （防翻支脚）。
- **cleat**：`nut(w,false)` 置于托槽背面（Y=`td+10`）顶部 `up(hz - 2*slot_distance_top) back(d)`；公差自动。

## 实现要点 / 功能保真取舍

- 三条 bbox 公式精确复刻；工具槽 `tw×td`、底部三角 `th`、cleat 一应俱全，与 1.0 实物互换。
- 1.0 的顶冠更"瘦"（托槽背壁略微内倾、与下方薄板过渡更连续），本移植用全深托槽块 + 一道台阶，
  **顶部略比 1.0 敦实**；底部三角是直边楔，1.0 是更圆滑的过渡。均为外形细节，功能等价。
- 文字 `v/tw/hh/th/td` 刻正面（X 读面）floored，放不下溢到背面；字号自适应。

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
