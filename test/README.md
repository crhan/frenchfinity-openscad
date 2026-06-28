# Tests

## test_labels_fit.py — 文字必须刻在件内

防止「文字超出件高 / 丢行」回归。短件（`tool_slot_height` 小 → 件高小）若用固定字号，
最下面的标签会被推出件外（凹刻是减法，溢出的部分不会被刻出，于是标签悄无声息地丢失）。

做法：用 `labels_only.scad` 把矩形工具架的标签**单独渲染成实体**，再断言其包围盒落在
件高（`tool_slot_height + 15`）与件长（`tool_length + 10`）之内。X 方向（刻入侧壁的深度）
有意穿出墙面，不检查。

运行：

```
python3 test/test_labels_fit.py
```

退出码 0 = 全部通过；1 = 有用例文字溢出。只需 `python3`（无第三方依赖）和
`openscad` CLI（自动在常见路径查找）。

覆盖：默认件、极小件高（tsh=1/3）、极短件长、超大 `text_size`、大件、左/右孔位、
`render_text=false`（应无文字）。

> 改动 `src/rectangular_tool_holder.scad` 里文字相关代码（布局/字号/朝向）后务必运行。
