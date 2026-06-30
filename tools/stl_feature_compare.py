#!/usr/bin/env python3
"""Feature-level STL comparisons for reverse-engineering details.

`stl_diff.py` answers "how far apart are the surfaces overall?".  This script
answers narrower geometry questions that random surface sampling tends to hide.

Usage:
    tools/stl_feature_compare.py side-front-profile OURS.stl REF.stl

The side-front-profile check aligns REF onto OURS using the same orientation
search as stl_diff.py, then slices near the left/right X sides and measures the
front boundary Y value over a Z band.  It reports both absolute front mismatch
and the side-edge pullback relative to an inner slice.  Missing or overdone
side/front fillets show up directly in the pullback columns.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np

import stl_diff


def slice_segments(tris: np.ndarray, axis: int, value: float) -> np.ndarray:
    other = [i for i in range(3) if i != axis]
    out = []
    for tri in tris:
        d = tri[:, axis] - value
        if (d > 0).sum() in (0, 3):
            continue
        pts = []
        for i in range(3):
            j = (i + 1) % 3
            if (d[i] > 0) != (d[j] > 0):
                u = d[i] / (d[i] - d[j])
                p = tri[i] + u * (tri[j] - tri[i])
                pts.append([p[other[0]], p[other[1]]])
        if len(pts) == 2:
            out.append(pts)
    return np.asarray(out)


def front_y_at_z(tris: np.ndarray, x_value: float, z_values: np.ndarray) -> list[float | None]:
    segs = slice_segments(tris, axis=0, value=x_value)
    if len(segs) == 0:
        return [None] * len(z_values)

    out: list[float | None] = []
    for z in z_values:
        ys = []
        for a, b in segs:
            if (a[1] <= z < b[1]) or (b[1] <= z < a[1]):
                u = (z - a[1]) / (b[1] - a[1])
                ys.append(a[0] + u * (b[0] - a[0]))
        out.append(max(ys) if ys else None)
    return out


def finite_mean(values: list[float | None]) -> float | None:
    finite = [v for v in values if v is not None]
    if not finite:
        return None
    return float(np.mean(finite))


def load_and_align(ours_path: str, ref_path: str) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    ours = stl_diff.load_stl(ours_path)
    ref = stl_diff.load_stl(ref_path)
    _, ours_centroid = stl_diff.vol_centroid(ours)
    _, ref_centroid = stl_diff.vol_centroid(ref)
    ours_surface = stl_diff.sample_surface(ours, stl_diff.N_SAMPLE)
    ref_surface = stl_diff.sample_surface(ref, stl_diff.N_SAMPLE)
    rotation, translation, _ = stl_diff.align(ours_surface, ref_surface, ours_centroid, ref_centroid)
    return ours, ref @ rotation.T + translation, rotation, translation


def cmd_side_front_profile(args: argparse.Namespace) -> int:
    ours, ref_aligned, rotation, translation = load_and_align(args.ours, args.ref)
    ours_min = ours.reshape(-1, 3).min(axis=0)
    ours_max = ours.reshape(-1, 3).max(axis=0)
    z_values = np.arange(args.z_min, args.z_max + 1e-9, args.z_step)
    offsets = [float(x) for x in args.offsets.split(",")]
    inner_offset = offsets[-1]

    print(f"OURS: {Path(args.ours).name}")
    print(f"REF : {Path(args.ref).name}  (aligned onto OURS)")
    print(f"R   : {rotation.tolist()}")
    print("t   : [%.3f, %.3f, %.3f]" % tuple(translation))
    print(f"Z band: {args.z_min:g}..{args.z_max:g} step {args.z_step:g}")
    print()
    print("dY = OURS front boundary - aligned REF front boundary")
    print("pullback = boundary at offset - boundary at inner offset")
    print()

    for side_name, x_base, sign in (
        ("x-min side", ours_min[0], 1.0),
        ("x-max side", ours_max[0], -1.0),
    ):
        rows = []
        for offset in offsets:
            x_value = x_base + sign * offset
            ours_y = finite_mean(front_y_at_z(ours, x_value, z_values))
            ref_y = finite_mean(front_y_at_z(ref_aligned, x_value, z_values))
            rows.append((offset, ours_y, ref_y))

        ours_inner = next((ours_y for offset, ours_y, _ in rows if offset == inner_offset), None)
        ref_inner = next((ref_y for offset, _, ref_y in rows if offset == inner_offset), None)

        print(side_name)
        print("  offset   dY(mm)   ours_pull   ref_pull   pull_delta")
        for offset, ours_y, ref_y in rows:
            if ours_y is None or ref_y is None or ours_inner is None or ref_inner is None:
                print(f"  {offset:6.2f}   no slice data")
                continue
            d_y = ours_y - ref_y
            ours_pull = ours_y - ours_inner
            ref_pull = ref_y - ref_inner
            print(
                f"  {offset:6.2f}  {d_y:+7.3f}  "
                f"{ours_pull:+9.3f}  {ref_pull:+8.3f}  {ours_pull - ref_pull:+10.3f}"
            )
        print()

    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    side = sub.add_parser("side-front-profile", help="compare exposed side/front edge fillet profiles")
    side.add_argument("ours")
    side.add_argument("ref")
    side.add_argument("--offsets", default="0.1,0.25,0.5,1.0,2.0,4.0")
    side.add_argument("--z-min", type=float, default=5.0)
    side.add_argument("--z-max", type=float, default=80.0)
    side.add_argument("--z-step", type=float, default=5.0)

    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if args.command == "side-front-profile":
        return cmd_side_front_profile(args)
    raise AssertionError(args.command)


if __name__ == "__main__":
    raise SystemExit(main())
