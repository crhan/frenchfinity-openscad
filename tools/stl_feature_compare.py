#!/usr/bin/env python3
"""Feature-level STL comparisons for reverse-engineering details.

`stl_diff.py` answers "how far apart are the surfaces overall?".  This script
answers narrower geometry questions that random surface sampling tends to hide.

Usage:
    tools/stl_feature_compare.py side-front-profile OURS.stl REF.stl
    tools/stl_feature_compare.py can-holder-audit OURS.stl REF.stl

The side-front-profile check aligns REF onto OURS using the same orientation
search as stl_diff.py, then slices near the left/right X sides and measures the
front boundary Y value over a Z band.  It reports both absolute front mismatch
and the side-edge pullback relative to an inner slice.  Missing or overdone
side/front fillets show up directly in the pullback columns.
"""

from __future__ import annotations

import argparse
from math import cos, sin
import sys
from pathlib import Path

import numpy as np
from scipy.spatial import KDTree

import build123d_can_holder
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


def surface_distance_samples(
    ours: np.ndarray,
    ref_aligned: np.ndarray,
    samples: int,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    ours_surface = stl_diff.sample_surface(ours, samples)
    ref_surface = stl_diff.sample_surface(ref_aligned, samples)
    ours_to_ref = KDTree(ref_surface).query(ours_surface)[0]
    ref_to_ours = KDTree(ours_surface).query(ref_surface)[0]
    return ours_surface, ref_surface, ours_to_ref, ref_to_ours


def zone_stats(points: np.ndarray, distances: np.ndarray, mask: np.ndarray) -> dict[str, float]:
    values = distances[mask]
    if len(values) == 0:
        return {"count": 0, "mean": 0.0, "p95": 0.0, "max": 0.0, "frac_gt_0_5": 0.0}
    return {
        "count": float(len(values)),
        "mean": float(values.mean()),
        "p95": float(np.percentile(values, 95)),
        "max": float(values.max()),
        "frac_gt_0_5": float((values > 0.5).mean()),
    }


def mouth_normal_std(triangles: np.ndarray, geo: build123d_can_holder.CanHolderGeometry) -> tuple[float, int]:
    axis = np.asarray((0.0, sin(geo.a), cos(geo.a)))
    center = np.asarray((geo.outer_width() / 2, geo.bore_yc(), geo.floor_z()))
    bore_len = geo.bore_length()
    bore_radius = geo.bore_diameter() / 2
    centroids = triangles.mean(axis=1)
    rel = centroids - center
    axial = rel @ axis
    radial = np.linalg.norm(rel - axial[:, None] * axis, axis=1)
    v0, v1, v2 = triangles[:, 0], triangles[:, 1], triangles[:, 2]
    normals = np.cross(v1 - v0, v2 - v0)
    normals /= np.linalg.norm(normals, axis=1)[:, None] + 1e-12
    normal_angles = np.degrees(np.arccos(np.clip(np.abs(normals @ axis), 0, 1)))
    mask = (
        (axial >= bore_len - geo.leadin - 2)
        & (axial <= bore_len + 2)
        & (radial >= bore_radius - 0.5)
        & (radial <= bore_radius + geo.leadin + 1)
    )
    values = normal_angles[mask]
    if len(values) == 0:
        return 0.0, 0
    return float(values.std()), int(len(values))


def print_gate(name: str, passed: bool, detail: str) -> bool:
    print(f"{'PASS' if passed else 'FAIL'} {name}: {detail}")
    return passed


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


def side_roundover_max_delta(ours: np.ndarray, ref_aligned: np.ndarray, geo: build123d_can_holder.CanHolderGeometry) -> float:
    ours_min = ours.reshape(-1, 3).min(axis=0)
    ours_max = ours.reshape(-1, 3).max(axis=0)
    z_min = max(geo.base() + 2, 5.0)
    z_max = min(geo.fronttop_z() - 4, geo.height() - 8)
    if z_max <= z_min:
        return 0.0
    z_values = np.arange(z_min, z_max + 1e-9, 5.0)
    offsets = [0.1, 0.25, 0.5, 1.0, 2.0]
    inner_offset = offsets[-1]
    max_delta = 0.0

    for x_base, sign in ((ours_min[0], 1.0), (ours_max[0], -1.0)):
        rows = []
        for offset in offsets:
            x_value = x_base + sign * offset
            ours_y = finite_mean(front_y_at_z(ours, x_value, z_values))
            ref_y = finite_mean(front_y_at_z(ref_aligned, x_value, z_values))
            rows.append((offset, ours_y, ref_y))
        ours_inner = next((ours_y for offset, ours_y, _ in rows if offset == inner_offset), None)
        ref_inner = next((ref_y for offset, _, ref_y in rows if offset == inner_offset), None)
        if ours_inner is None or ref_inner is None:
            continue
        for offset, ours_y, ref_y in rows:
            if offset > 0.5 or ours_y is None or ref_y is None:
                continue
            ours_pull = ours_y - ours_inner
            ref_pull = ref_y - ref_inner
            max_delta = max(max_delta, abs(ours_pull - ref_pull))
    return max_delta


def cmd_can_holder_audit(args: argparse.Namespace) -> int:
    ours, ref_aligned, rotation, translation = load_and_align(args.ours, args.ref)
    params = build123d_can_holder._params_from_reference(Path(args.ref), True, 1, "scad")
    geo = build123d_can_holder.CanHolderGeometry(params)
    ours_surface, ref_surface, ours_to_ref, ref_to_ours = surface_distance_samples(
        ours, ref_aligned, args.samples
    )

    print(f"OURS: {Path(args.ours).name}")
    print(f"REF : {Path(args.ref).name}  (aligned onto OURS)")
    print(f"R   : {rotation.tolist()}")
    print("t   : [%.3f, %.3f, %.3f]" % tuple(translation))
    print(
        "params: cd=%.2f pl=%.2f ci=%.2f p=%.2f angle=%.0f bottom=%s"
        % (
            params.can_diameter,
            params.padding_left,
            params.can_inset,
            params.padding,
            params.angle,
            params.bottom,
        )
    )
    print()

    ok = True

    side_delta = side_roundover_max_delta(ours, ref_aligned, geo)
    ok &= print_gate(
        "side/end roundovers",
        side_delta <= args.side_roundover_tolerance,
        f"max pullback delta {side_delta:.3f} mm "
        f"(limit {args.side_roundover_tolerance:.3f}; catches missing side fillets)",
    )

    width = geo.outer_width()
    label_z0 = geo.base() + 2
    label_z1 = geo.cleat_bottom() - 2
    label_mask = (
        (ref_surface[:, 1] >= -0.2)
        & (ref_surface[:, 1] <= 1.2)
        & (ref_surface[:, 2] >= label_z0)
        & (ref_surface[:, 2] <= label_z1)
        & (ref_surface[:, 0] >= 2)
        & (ref_surface[:, 0] <= width - 2)
    )
    label = zone_stats(ref_surface, ref_to_ours, label_mask)
    ok &= print_gate(
        "back label engravings",
        label["frac_gt_0_5"] <= args.label_missing_fraction,
        "ref->ours label-band frac>0.5mm %.2f, p95 %.3f mm, n=%d "
        "(high means labels/grooves are missing or misplaced)"
        % (label["frac_gt_0_5"], label["p95"], label["count"]),
    )

    if params.bottom == "open":
        drain_center_x, drain_center_y, drain_center_z = geo.bottom_hole_center()
        drain_half_len = geo.bottom_hole_length() / 2 + 2
        drain_radius = geo.bore_diameter() / 2 + 2
        ref_drain_radial2 = (
            (ref_surface[:, 1] - drain_center_y) ** 2
            + (ref_surface[:, 2] - drain_center_z) ** 2
        )
        ref_drain_mask = (
            (np.abs(ref_surface[:, 0] - drain_center_x) <= drain_half_len)
            & (ref_drain_radial2 <= drain_radius**2)
        )
        ours_drain_radial2 = (
            (ours_surface[:, 1] - drain_center_y) ** 2
            + (ours_surface[:, 2] - drain_center_z) ** 2
        )
        ours_drain_mask = (
            (np.abs(ours_surface[:, 0] - drain_center_x) <= drain_half_len)
            & (ours_drain_radial2 <= drain_radius**2)
        )
        ref_drain = zone_stats(ref_surface, ref_to_ours, ref_drain_mask)
        ours_drain = zone_stats(ours_surface, ours_to_ref, ours_drain_mask)
        drain_p95 = max(ref_drain["p95"], ours_drain["p95"])
        ok &= print_gate(
            "bottom push-out/drain hole",
            drain_p95 <= args.drain_tolerance,
            "local symmetric p95 %.3f mm (limit %.3f; high means lower-front void differs)"
            % (drain_p95, args.drain_tolerance),
        )

    axis = np.asarray((0.0, sin(geo.a), cos(geo.a)))
    bore_center = np.asarray((width / 2, geo.bore_yc(), geo.floor_z()))
    bore_len = geo.bore_length()
    bore_radius = geo.bore_diameter() / 2

    def mouth_mask(points: np.ndarray) -> np.ndarray:
        rel = points - bore_center
        axial = rel @ axis
        radial = np.linalg.norm(rel - axial[:, None] * axis, axis=1)
        return (
            (axial >= bore_len - geo.leadin * 2)
            & (axial <= bore_len + geo.leadin)
            & (radial >= bore_radius - 1)
            & (radial <= bore_radius + geo.leadin + 2)
        )

    ref_mouth = zone_stats(ref_surface, ref_to_ours, mouth_mask(ref_surface))
    ours_mouth = zone_stats(ours_surface, ours_to_ref, mouth_mask(ours_surface))
    mouth_p95 = max(ref_mouth["p95"], ours_mouth["p95"])
    normal_std, normal_count = mouth_normal_std(ours, geo)
    ok &= print_gate(
        "top bore mouth roundover",
        mouth_p95 <= args.mouth_tolerance and normal_std >= args.mouth_normal_std_min,
        "local symmetric p95 %.3f mm (limit %.3f), normal-angle std %.2f deg "
        "(min %.2f, n=%d; low std catches a conical chamfer band)"
        % (
            mouth_p95,
            args.mouth_tolerance,
            normal_std,
            args.mouth_normal_std_min,
            normal_count,
        ),
    )

    return 0 if ok else 1


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

    audit = sub.add_parser("can-holder-audit", help="check can-holder-specific features, not just bbox")
    audit.add_argument("ours")
    audit.add_argument("ref")
    audit.add_argument("--samples", type=int, default=80000)
    audit.add_argument("--side-roundover-tolerance", type=float, default=0.30)
    audit.add_argument("--label-missing-fraction", type=float, default=0.45)
    audit.add_argument("--drain-tolerance", type=float, default=3.00)
    audit.add_argument("--mouth-tolerance", type=float, default=0.65)
    audit.add_argument("--mouth-normal-std-min", type=float, default=8.0)

    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if args.command == "side-front-profile":
        return cmd_side_front_profile(args)
    if args.command == "can-holder-audit":
        return cmd_can_holder_audit(args)
    raise AssertionError(args.command)


if __name__ == "__main__":
    raise SystemExit(main())
