#!/usr/bin/env python3
"""Binary-STL analysis helpers for reverse engineering Frenchfinity 1.0 parts.

The 1.0 STLs are binary (80-byte header + uint32 count + 50 bytes/triangle) and
their file names encode the parameter values (e.g. ...-tw12.50-tl46.00...). That
makes them a free set of (parameters -> geometry) samples. This script turns
those samples into the numbers you need to write the OpenSCAD module.

Subcommands:
  bbox    <stl...>                 bounding box + dx/dy/dz of each file
  regress <glob>                   fit every bbox dim to every `code<number>`
                                   token in the file names (finds dx = tw + 10 ...)
  slice   <stl> <x|y|z> <value>    ASCII filled cross-section at that plane
  planes  <stl> <x|y|z>            dominant feature planes (flat faces) on an axis

Examples:
  python tools/stl_analyze.py regress 'Hook+.../*.stl'
  python tools/stl_analyze.py slice part.stl y 90
"""

import glob as globlib
import re
import struct
import sys

import numpy as np


def read_stl(path):
    """Return (n, verts) where verts is (n,3,3) float array (3 verts/triangle)."""
    with open(path, "rb") as f:
        f.read(80)
        n = struct.unpack("<I", f.read(4))[0]
        data = f.read(n * 50)
    t = np.frombuffer(data, np.uint8).reshape(n, 50)
    return n, t[:, :48].copy().view("<f4").reshape(n, 4, 3)[:, 1:, :]


def bbox(verts):
    v = verts.reshape(-1, 3)
    return v.min(0), v.max(0)


def parse_tokens(name):
    """Extract {code: value} from a filename, e.g. tw12.50 -> {'tw':12.5}."""
    out = {}
    for code, val in re.findall(r"([A-Za-z]+)(\d+\.?\d*)", name):
        out.setdefault(code, float(val))  # first occurrence wins (skip the 'v1')
    return out


def slice_segments(verts, axis, val):
    """2D segments where the mesh crosses the plane axis==val (other two axes)."""
    other = [i for i in range(3) if i != axis]
    out = []
    for tri in verts:
        d = tri[:, axis] - val
        if (d > 0).sum() in (0, 3):
            continue
        pts = []
        for i in range(3):
            j = (i + 1) % 3
            if (d[i] > 0) != (d[j] > 0):
                t = d[i] / (d[i] - d[j])
                p = tri[i] + t * (tri[j] - tri[i])
                pts.append([p[other[0]], p[other[1]]])
        if len(pts) == 2:
            out.append(pts)
    return np.array(out), other


def cmd_bbox(args):
    print(f"{'dx':>9}{'dy':>9}{'dz':>9}  {'xmin':>8}{'ymin':>8}{'zmin':>8}  file")
    for p in args:
        _, v = read_stl(p)
        mn, mx = bbox(v)
        d = mx - mn
        print(f"{d[0]:9.2f}{d[1]:9.2f}{d[2]:9.2f}  {mn[0]:8.2f}{mn[1]:8.2f}{mn[2]:8.2f}  {p.split('/')[-1]}")


def cmd_regress(args):
    files = sorted(globlib.glob(args[0]))
    if not files:
        print("no files match", args[0]); return
    rows = []
    for p in files:
        toks = parse_tokens(p.split("/")[-1])
        _, v = read_stl(p)
        mn, mx = bbox(v)
        rows.append((toks, (mx - mn)))
    codes = sorted({c for toks, _ in rows for c in toks})
    print(f"{len(files)} files, parameter codes: {codes}\n")
    for axis, an in enumerate("dx dy dz".split()):
        for c in codes:
            xs = np.array([toks.get(c, np.nan) for toks, _ in rows])
            ys = np.array([d[axis] for _, d in rows])
            m = ~np.isnan(xs)
            if m.sum() < 3 or np.ptp(xs[m]) == 0:
                continue
            A = np.vstack([xs[m], np.ones(m.sum())]).T
            sol, *_ = np.linalg.lstsq(A, ys[m], rcond=None)
            yp = A @ sol
            ss = ((ys[m] - yp) ** 2).sum()
            tot = ((ys[m] - ys[m].mean()) ** 2).sum()
            r2 = 1 - ss / tot if tot > 0 else 1.0
            if r2 > 0.9:
                print(f"  {an} = {sol[0]:.3f}*{c} + {sol[1]:.3f}   (R^2={r2:.4f})")


def cmd_slice(args):
    path, axis_s, val = args[0], args[1], float(args[2])
    axis = "xyz".index(axis_s)
    _, v = read_stl(path)
    segs, other = slice_segments(v, axis, val)
    if len(segs) == 0:
        print("empty slice"); return
    allp = segs.reshape(-1, 2)
    x0, x1 = allp[:, 0].min(), allp[:, 0].max()
    y0, y1 = allp[:, 1].min(), allp[:, 1].max()
    w, h = 78, 30
    grid = [[" "] * w for _ in range(h)]
    for r in range(h):
        yy = y1 - (y1 - y0) * (r + 0.5) / h
        xs = []
        for a, b in segs:
            if (a[1] <= yy < b[1]) or (b[1] <= yy < a[1]):
                t = (yy - a[1]) / (b[1] - a[1])
                xs.append(a[0] + t * (b[0] - a[0]))
        xs.sort()
        for k in range(0, len(xs) - 1, 2):
            ca = int((xs[k] - x0) / (x1 - x0 + 1e-9) * (w - 1))
            cb = int((xs[k + 1] - x0) / (x1 - x0 + 1e-9) * (w - 1))
            for c in range(ca, cb + 1):
                grid[r][c] = "#"
    names = "XYZ"
    print(f"{axis_s}={val}  (horiz {names[other[0]]} [{x0:.1f}..{x1:.1f}], "
          f"vert {names[other[1]]} [{y0:.1f}..{y1:.1f}])")
    for row in grid:
        print("".join(row))


def cmd_planes(args):
    from collections import Counter
    path, axis_s = args[0], args[1]
    axis = "xyz".index(axis_s)
    _, v = read_stl(path)
    coords = np.round(v.reshape(-1, 3)[:, axis], 2)
    c = Counter(coords.tolist())
    thr = max(50, len(coords) // 200)
    planes = sorted(k for k, n in c.items() if n >= thr)
    print(f"{axis_s} dominant planes (>= {thr} verts):", [f"{p:.2f}" for p in planes])


def main():
    if len(sys.argv) < 2:
        print(__doc__); return 1
    cmd, rest = sys.argv[1], sys.argv[2:]
    fn = {"bbox": cmd_bbox, "regress": cmd_regress, "slice": cmd_slice, "planes": cmd_planes}.get(cmd)
    if not fn:
        print(__doc__); return 1
    fn(rest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
