#!/usr/bin/env python3
"""build123d generator for the Frenchfinity 1.0 can-holder family.

The source of truth is the local Frenchfinity 1.0 STL corpus, especially
FrenchFinity/Can-Holder/*.stl.  File names provide cd/pl/ci/p/bottom, and the
hidden Fusion angle is inferred by matching the reference bbox against the known
1.0 angle set.  Generated STL files are build artifacts and must not be
committed.
"""

from __future__ import annotations

import argparse
import os
import re
import struct
from typing import Any
from dataclasses import dataclass
from math import cos, radians, sin, tan
from pathlib import Path

# ezdxf (pulled in by build123d) tries to create ~/.cache on import.  Keep this
# script self-contained in restricted/sandboxed runs.
os.environ.setdefault("XDG_CACHE_HOME", "/tmp")

from build123d import (  # noqa: E402
    Align,
    Box,
    BuildLine,
    BuildPart,
    BuildSketch,
    Cone,
    Cylinder,
    Locations,
    Mode,
    Plane,
    Polyline,
    Text,
    export_stl,
    extrude,
    fillet,
    make_face,
)


SLOT_INNER_HEIGHT = 8.5
SLOT_INNER_WIDTH = 4.5
SLOT_OUTER_WIDTH = 6.6
SLOT_OUTER_HEIGHT = 6.5
SLOT_DISTANCE_TOP = 7.394
SLOT_TOLERANCE = 0.25
FILAMENT_HOLE_SIZE = 1.70

TEXT_DEPTH = 1.0
TEXT_SIZE = 5.0
TEXT_SIZE_MIN = 3.5
TEXT_GLYPH_K = 1.3
TEXT_LINE_K = 1.5
TEXT_CHAR_K = 0.70
TEXT_MARGIN = 1.5
ANGLE_CANDIDATES = (10.0, 15.0, 20.0, 30.0, 40.0)


@dataclass(frozen=True)
class CanHolderParams:
    can_diameter: float = 10.0
    padding: float = 10.0
    can_inset: float = 55.0
    padding_left: float = 16.0
    angle: float = 10.0
    bottom: str = "closed"
    render_text: bool = True
    version: int = 1
    version_prefix: str = "scad"

    def validate(self) -> None:
        if self.can_diameter <= 0:
            raise ValueError("can_diameter must be > 0")
        if self.padding <= 0:
            raise ValueError("padding must be > 0")
        if self.can_inset <= 0:
            raise ValueError("can_inset must be > 0")
        if self.padding_left < 0:
            raise ValueError("padding_left must be >= 0")
        if not (0 <= self.angle < 60):
            raise ValueError("angle must be in [0, 60)")
        if self.bottom not in ("closed", "open"):
            raise ValueError("bottom must be one of: closed, open")


class CanHolderGeometry:
    clearance = 2.0
    leadin = 3.0
    fillet_radius = 2.0

    def __init__(self, params: CanHolderParams):
        params.validate()
        self.p = params

    @property
    def a(self) -> float:
        return radians(self.p.angle)

    def outer_width(self) -> float:
        return self.p.can_diameter + 2 * self.p.padding

    def bore_diameter(self) -> float:
        return self.p.can_diameter + self.clearance

    def c_law(self) -> float:
        cd = self.p.can_diameter
        p = self.p.padding
        t = tan(self.a)
        return (
            1.0122 * cd
            + 1.8276 * p
            - 0.1120 * cd * t
            - 0.2464 * cd * t * t
            - 9.0947 * t
            + 6.3539
        )

    def k_law(self) -> float:
        cd = self.p.can_diameter
        p = self.p.padding
        r = self.bore_diameter() / 2
        a = self.a
        return (
            2.2371 * r * sin(a)
            + 18.3335 * sin(a)
            - 0.1059 * cd * tan(a)
            + 1.5820 * p
            - 5.3775
        )

    def base(self) -> float:
        return 9 + 0.3 * self.p.padding_left

    def height(self) -> float:
        return self.p.can_inset * cos(self.a) + self.k_law()

    def front_pullin(self) -> float:
        a = self.p.angle
        return (self.fillet_radius / 2) * (0.04 * a - 0.00047 * a * a)

    def front_eff(self) -> float:
        return self.c_law() + self.front_pullin()

    def front_max(self) -> float:
        return self.p.padding_left + self.front_eff()

    def fronttop_z(self) -> float:
        return self.height() - self.front_eff() * tan(self.a)

    def front_y(self, z: float) -> float:
        return self.front_max() - (self.fronttop_z() - z) * tan(self.a)

    def floor_z(self) -> float:
        return self.base() + self.bore_diameter() / 2 * sin(self.a)

    def bore_yc(self) -> float:
        return (
            self.front_y(self.floor_z())
            - (self.bore_diameter() / 2 + self.p.padding) / cos(self.a)
            - 0.37
        )

    def cleat_origin(self) -> float:
        return self.height() - 10.19 - SLOT_OUTER_HEIGHT / 2

    def cleat_bottom(self) -> float:
        return self.height() - 2 * SLOT_DISTANCE_TOP

    def side_profile(self) -> list[tuple[float, float]]:
        return [
            (0, 0),
            (self.front_y(0), 0),
            (self.front_max(), self.fronttop_z()),
            (self.p.padding_left, self.height()),
            (0, self.height()),
        ]

    def bore_length(self) -> float:
        a = self.a
        return sin(a) * (self.p.padding_left - self.bore_yc()) + cos(a) * (
            self.height() - self.floor_z()
        )

    def bore_bottom_extra(self) -> float:
        # The paired closed/open references are best matched by moving the
        # blind-bore bottom a short fixed distance down its tilted axis.  This
        # keeps every open sample's bbox matched while approximating the lower
        # push-out opening without adding a separate small drain hole.
        return 6.0 if self.p.bottom == "open" else 0.0

    def filename(self, output: Path | None) -> Path:
        if output is not None:
            return output
        suffix = "-hole-bottom" if self.p.bottom == "open" else ""
        return Path(
            "generated_stl"
        ) / (
            "build123d-can-holder-"
            f"v{self.p.version}-cd{self.p.can_diameter:g}-pl{self.p.padding_left:g}-"
            f"ci{self.p.can_inset:g}-p{self.p.padding:g}-a{self.p.angle:g}{suffix}.stl"
        )


def _long_edge_at(part, width: float, y: float, z: float, tol: float = 1e-4):
    matches = []
    for edge in part.edges():
        bb = edge.bounding_box()
        dx = bb.max.X - bb.min.X
        dy = bb.max.Y - bb.min.Y
        dz = bb.max.Z - bb.min.Z
        if (
            abs(dx - width) <= tol
            and dy <= tol
            and dz <= tol
            and abs(bb.min.Y - y) <= tol
            and abs(bb.min.Z - z) <= tol
        ):
            matches.append(edge)
    if len(matches) != 1:
        raise RuntimeError(f"expected one X edge at y={y:.4f}, z={z:.4f}; got {len(matches)}")
    return matches[0]


def _add_body(geo: CanHolderGeometry) -> None:
    width = geo.outer_width()
    profile = geo.side_profile()

    with BuildSketch(Plane.YZ) as sketch:
        with BuildLine():
            Polyline(profile, close=True)
        make_face()
    extrude(sketch.sketch, amount=width)

    geo_part = BuildPart._get_context().part
    rounded_edges = [
        _long_edge_at(geo_part, width, profile[2][0], profile[2][1]),
        _long_edge_at(geo_part, width, profile[3][0], profile[3][1]),
    ]
    fillet(rounded_edges, radius=geo.fillet_radius)

    width = geo.outer_width()
    r = geo.bore_diameter() / 2
    axis = (0, sin(geo.a), cos(geo.a))
    cf = (width / 2, geo.bore_yc(), geo.floor_z())
    bore_len = geo.bore_length()
    rot = (-geo.p.angle, 0, 0)

    bore_start = (
        cf[0] - axis[0] * geo.bore_bottom_extra(),
        cf[1] - axis[1] * geo.bore_bottom_extra(),
        cf[2] - axis[2] * geo.bore_bottom_extra(),
    )
    with Locations(bore_start):
        Cylinder(
            r,
            bore_len + 2 + geo.bore_bottom_extra(),
            rotation=rot,
            align=(Align.CENTER, Align.CENTER, Align.MIN),
            mode=Mode.SUBTRACT,
        )

    cone_base = (
        cf[0] + axis[0] * (bore_len - geo.leadin),
        cf[1] + axis[1] * (bore_len - geo.leadin),
        cf[2] + axis[2] * (bore_len - geo.leadin),
    )
    with Locations(cone_base):
        Cone(
            r,
            r + geo.leadin,
            geo.leadin + 2,
            rotation=rot,
            align=(Align.CENTER, Align.CENTER, Align.MIN),
            mode=Mode.SUBTRACT,
        )



def _add_male_cleat(geo: CanHolderGeometry) -> None:
    width = geo.outer_width()
    origin = geo.cleat_origin()
    tol = SLOT_TOLERANCE
    neck_h = SLOT_OUTER_HEIGHT - 2 * tol
    head_h = SLOT_INNER_HEIGHT - 2 * tol
    head_depth = SLOT_INNER_WIDTH - tol

    with Locations((0, -SLOT_OUTER_WIDTH, origin + tol)):
        Box(width, SLOT_OUTER_WIDTH, neck_h, align=(Align.MIN, Align.MIN, Align.MIN), mode=Mode.ADD)

    with Locations((0, -(SLOT_OUTER_WIDTH + head_depth), origin + (SLOT_OUTER_HEIGHT - SLOT_INNER_HEIGHT) / 2 + tol)):
        Box(width, head_depth, head_h, align=(Align.MIN, Align.MIN, Align.MIN), mode=Mode.ADD)

    with Locations((width / 2, -(SLOT_OUTER_WIDTH + SLOT_INNER_WIDTH), origin + SLOT_OUTER_HEIGHT / 2)):
        Cylinder(
            FILAMENT_HOLE_SIZE / 2,
            width + 2,
            rotation=(0, 90, 0),
            align=(Align.CENTER, Align.CENTER, Align.CENTER),
            mode=Mode.SUBTRACT,
        )


def _label_size(lines: list[str], region_h: float, region_w: float) -> float:
    max_chars = max(len(line) for line in lines)
    return max(
        TEXT_SIZE_MIN,
        min(
            TEXT_SIZE,
            (region_h - 2 * TEXT_MARGIN) / (TEXT_GLYPH_K + (len(lines) - 1) * TEXT_LINE_K),
            (region_w - 2 * TEXT_MARGIN) / (max_chars * TEXT_CHAR_K),
        ),
    )


def _label_z_top(line_count: int, size: float, region_h: float, z0: float) -> float:
    return z0 + (region_h - size * TEXT_GLYPH_K + (line_count - 1) * size * TEXT_LINE_K) / 2


def _subtract_labels(geo: CanHolderGeometry) -> None:
    if not geo.p.render_text:
        return

    lines = [
        f"v{geo.p.version}{geo.p.version_prefix}",
        f"cd{geo.p.can_diameter:.2f}",
        f"pl{geo.p.padding_left:.2f}",
        f"ci{geo.p.can_inset:.2f}",
        f"p{geo.p.padding:.2f}",
    ]
    width = geo.outer_width()
    z0 = geo.base() + 2
    z1 = geo.cleat_bottom() - 2
    region_h = z1 - z0
    if region_h <= 2 * TEXT_MARGIN:
        return

    # 1.0 can-holder labels use a fixed ~3.5 mm glyph; do not scale them up to
    # the generic OpenSCAD text_size.
    size = TEXT_SIZE_MIN
    if size <= 0.3:
        return

    pitch = size * TEXT_LINE_K
    z_top = _label_z_top(len(lines), size, region_h, z0)
    with BuildSketch(Plane.XZ) as sketch:
        for idx, line in enumerate(lines):
            with Locations((width / 2, z_top - idx * pitch)):
                Text(line, size)
    # Plane.XZ's positive normal is -Y; use a negative amount to cut into +Y.
    extrude(sketch.sketch, amount=-(TEXT_DEPTH * 2), mode=Mode.SUBTRACT)


def build_can_holder(params: CanHolderParams):
    geo = CanHolderGeometry(params)
    with BuildPart() as part:
        _add_body(geo)
        _add_male_cleat(geo)
        _subtract_labels(geo)
    return part.part


def _read_stl_bbox(path: Path) -> tuple[float, float, float]:
    raw = path.read_bytes()
    verts: list[tuple[float, float, float]] = []
    if len(raw) >= 84:
        count = struct.unpack("<I", raw[80:84])[0]
        if len(raw) == 84 + count * 50:
            for i in range(count):
                rec = raw[84 + i * 50 : 84 + (i + 1) * 50]
                floats = struct.unpack("<12f", rec[:48])
                verts.extend((floats[j], floats[j + 1], floats[j + 2]) for j in (3, 6, 9))
        else:
            for line in raw.decode("ascii", "ignore").splitlines():
                parts = line.split()
                if len(parts) == 4 and parts[0] == "vertex":
                    verts.append((float(parts[1]), float(parts[2]), float(parts[3])))
    if not verts:
        raise ValueError(f"cannot read STL vertices from {path}")
    mins = [min(v[i] for v in verts) for i in range(3)]
    maxs = [max(v[i] for v in verts) for i in range(3)]
    return tuple(maxs[i] - mins[i] for i in range(3))


def _load_stl_triangles(path: Path):
    import numpy as np

    raw = path.read_bytes()
    if len(raw) >= 84:
        count = struct.unpack("<I", raw[80:84])[0]
        if len(raw) == 84 + count * 50:
            rec = np.frombuffer(raw[84:], dtype=np.uint8).reshape(count, 50)
            floats = rec[:, :48].copy().view("<f4").reshape(count, 12)
            return floats[:, 3:12].reshape(count, 3, 3).astype("float64")

    verts = []
    for line in raw.decode("ascii", "ignore").splitlines():
        parts = line.split()
        if len(parts) == 4 and parts[0] == "vertex":
            verts.append((float(parts[1]), float(parts[2]), float(parts[3])))
    if not verts:
        raise ValueError(f"cannot read STL vertices from {path}")
    return np.asarray(verts, dtype="float64").reshape(-1, 3, 3)


def _mesh_volume(triangles: Any) -> float:
    import numpy as np

    v0, v1, v2 = triangles[:, 0], triangles[:, 1], triangles[:, 2]
    signed = np.einsum("ij,ij->i", v0, np.cross(v1, v2)) / 6.0
    return float(abs(signed.sum()))


def _sample_surface(triangles: Any, samples: int, seed: int):
    import numpy as np

    rng = np.random.default_rng(seed)
    v0, v1, v2 = triangles[:, 0], triangles[:, 1], triangles[:, 2]
    area = 0.5 * np.linalg.norm(np.cross(v1 - v0, v2 - v0), axis=1)
    idx = rng.choice(len(triangles), size=samples, p=area / area.sum())
    u = rng.random(samples)
    v = rng.random(samples)
    flip = u + v > 1.0
    u[flip] = 1 - u[flip]
    v[flip] = 1 - v[flip]
    a, b, c = v0[idx], v1[idx], v2[idx]
    return a + (b - a) * u[:, None] + (c - a) * v[:, None]


def _point_triangle_distance_squared(points: Any, triangles: Any):
    import numpy as np

    p = points
    a = triangles[:, 0]
    b = triangles[:, 1]
    c = triangles[:, 2]
    ab = b - a
    ac = c - a
    ap = p - a
    d1 = np.einsum("ij,ij->i", ab, ap)
    d2 = np.einsum("ij,ij->i", ac, ap)
    out = np.full(len(points), np.inf)

    mask = (d1 <= 0) & (d2 <= 0)
    out[mask] = np.einsum("ij,ij->i", ap[mask], ap[mask])

    bp = p - b
    d3 = np.einsum("ij,ij->i", ab, bp)
    d4 = np.einsum("ij,ij->i", ac, bp)
    mask = (d3 >= 0) & (d4 <= d3)
    out[mask] = np.minimum(out[mask], np.einsum("ij,ij->i", bp[mask], bp[mask]))

    vc = d1 * d4 - d3 * d2
    mask = (vc <= 0) & (d1 >= 0) & (d3 <= 0)
    v = np.zeros(len(points))
    denom = d1 - d3
    np.divide(d1, denom, out=v, where=denom != 0)
    proj = a + v[:, None] * ab
    dist = np.einsum("ij,ij->i", p - proj, p - proj)
    out[mask] = np.minimum(out[mask], dist[mask])

    cp = p - c
    d5 = np.einsum("ij,ij->i", ab, cp)
    d6 = np.einsum("ij,ij->i", ac, cp)
    mask = (d6 >= 0) & (d5 <= d6)
    out[mask] = np.minimum(out[mask], np.einsum("ij,ij->i", cp[mask], cp[mask]))

    vb = d5 * d2 - d1 * d6
    mask = (vb <= 0) & (d2 >= 0) & (d6 <= 0)
    w = np.zeros(len(points))
    denom = d2 - d6
    np.divide(d2, denom, out=w, where=denom != 0)
    proj = a + w[:, None] * ac
    dist = np.einsum("ij,ij->i", p - proj, p - proj)
    out[mask] = np.minimum(out[mask], dist[mask])

    va = d3 * d6 - d5 * d4
    mask = (va <= 0) & ((d4 - d3) >= 0) & ((d5 - d6) >= 0)
    w = np.zeros(len(points))
    denom = (d4 - d3) + (d5 - d6)
    np.divide(d4 - d3, denom, out=w, where=denom != 0)
    proj = b + w[:, None] * (c - b)
    dist = np.einsum("ij,ij->i", p - proj, p - proj)
    out[mask] = np.minimum(out[mask], dist[mask])

    remaining = np.isinf(out)
    if remaining.any():
        denom = va + vb + vc
        v = np.zeros(len(points))
        w = np.zeros(len(points))
        np.divide(vb, denom, out=v, where=denom != 0)
        np.divide(vc, denom, out=w, where=denom != 0)
        proj = a + ab * v[:, None] + ac * w[:, None]
        dist = np.einsum("ij,ij->i", p - proj, p - proj)
        out[remaining] = dist[remaining]
    return out


def _point_to_mesh_distances(points: Any, triangles: Any, k: int):
    import numpy as np
    from scipy.spatial import KDTree

    centroids = triangles.mean(axis=1)
    k = min(k, len(triangles))
    _, idx = KDTree(centroids).query(points, k=k)
    if k == 1:
        idx = idx[:, None]
    best = np.full(len(points), np.inf)
    for start in range(0, len(points), 4096):
        stop = min(start + 4096, len(points))
        candidate_idx = idx[start:stop]
        repeated_points = np.repeat(points[start:stop], k, axis=0)
        candidate_triangles = triangles[candidate_idx.reshape(-1)]
        dist2 = _point_triangle_distance_squared(repeated_points, candidate_triangles).reshape(stop - start, k)
        best[start:stop] = np.sqrt(dist2.min(axis=1))
    return best


def _shape_diff_metrics(ours: Path, reference: Path, samples: int, triangle_candidates: int) -> dict[str, float]:
    import numpy as np

    ours_tri = _load_stl_triangles(ours)
    ref_tri = _load_stl_triangles(reference)
    ours_points = _sample_surface(ours_tri, samples, seed=1)
    ref_points = _sample_surface(ref_tri, samples, seed=2)

    # The 1.0 STLs use arbitrary translations, but the generated geometry uses
    # the same axes.  Align by bbox minimum so this is a deterministic code-level
    # comparison, not a visual/model interpretation.
    offset = ours_tri.reshape(-1, 3).min(axis=0) - ref_tri.reshape(-1, 3).min(axis=0)
    ref_tri = ref_tri + offset
    ref_points = ref_points + offset

    ours_to_ref = _point_to_mesh_distances(ours_points, ref_tri, k=triangle_candidates)
    ref_to_ours = _point_to_mesh_distances(ref_points, ours_tri, k=triangle_candidates)
    hausdorff = max(float(ours_to_ref.max()), float(ref_to_ours.max()))
    within = 100.0 * (
        (ours_to_ref < 0.5).sum() + (ref_to_ours < 0.5).sum()
    ) / (len(ours_to_ref) + len(ref_to_ours))
    vol_ours = _mesh_volume(ours_tri)
    vol_ref = _mesh_volume(ref_tri)
    return {
        "volume_ratio": vol_ours / vol_ref,
        "ours_ref_mean": float(ours_to_ref.mean()),
        "ours_ref_p95": float(np.percentile(ours_to_ref, 95)),
        "ours_ref_p99": float(np.percentile(ours_to_ref, 99)),
        "ours_ref_max": float(ours_to_ref.max()),
        "ref_ours_mean": float(ref_to_ours.mean()),
        "ref_ours_p95": float(np.percentile(ref_to_ours, 95)),
        "ref_ours_p99": float(np.percentile(ref_to_ours, 99)),
        "ref_ours_max": float(ref_to_ours.max()),
        "symmetric_p95": max(float(np.percentile(ours_to_ref, 95)), float(np.percentile(ref_to_ours, 95))),
        "symmetric_p99": max(float(np.percentile(ours_to_ref, 99)), float(np.percentile(ref_to_ours, 99))),
        "symmetric_hausdorff": hausdorff,
        "within_0_5_pct": within,
    }


def _parse_reference_params(path: Path) -> dict[str, float | str]:
    name = path.name
    tokens = dict((key, float(value)) for key, value in re.findall(r"(cd|pl|ci|p)(\d+(?:\.\d+)?)", name))
    required = {"cd", "pl", "ci", "p"}
    if not required.issubset(tokens):
        raise ValueError(f"reference filename does not encode cd/pl/ci/p: {path}")
    return {
        "can_diameter": tokens["cd"],
        "padding_left": tokens["pl"],
        "can_inset": tokens["ci"],
        "padding": tokens["p"],
        "bottom": "open" if "hole-bottom" in name else "closed",
    }


def _expected_bbox(params: CanHolderParams) -> tuple[float, float, float]:
    geo = CanHolderGeometry(params)
    cleat_tip = -(SLOT_OUTER_WIDTH + SLOT_INNER_WIDTH - SLOT_TOLERANCE)
    rendered_front = params.padding_left + geo.c_law()
    return (geo.outer_width(), rendered_front - cleat_tip, geo.height())


def _pick_reference_angle(base: dict[str, float | str], reference: Path) -> float:
    ref_dims = _read_stl_bbox(reference)
    best_angle = ANGLE_CANDIDATES[0]
    best_score = float("inf")
    for angle in ANGLE_CANDIDATES:
        params = CanHolderParams(
            can_diameter=float(base["can_diameter"]),
            padding=float(base["padding"]),
            can_inset=float(base["can_inset"]),
            padding_left=float(base["padding_left"]),
            angle=angle,
            bottom=str(base["bottom"]),
            render_text=False,
        )
        expected = _expected_bbox(params)
        score = sum((expected[i] - ref_dims[i]) ** 2 for i in range(3))
        if score < best_score:
            best_score = score
            best_angle = angle
    return best_angle


def _params_from_args(args: argparse.Namespace) -> CanHolderParams:
    reference_params: dict[str, float | str] = {}
    if args.reference is not None:
        reference_params = _parse_reference_params(args.reference)
    angle = (
        args.angle
        if args.angle is not None
        else _pick_reference_angle(reference_params, args.reference)
        if args.reference is not None
        else 10.0
    )
    return CanHolderParams(
        can_diameter=args.can_diameter
        if args.can_diameter is not None
        else float(reference_params.get("can_diameter", 10.0)),
        padding=args.padding if args.padding is not None else float(reference_params.get("padding", 10.0)),
        can_inset=args.can_inset
        if args.can_inset is not None
        else float(reference_params.get("can_inset", 55.0)),
        padding_left=args.padding_left
        if args.padding_left is not None
        else float(reference_params.get("padding_left", 16.0)),
        angle=angle,
        bottom=args.bottom if args.bottom is not None else str(reference_params.get("bottom", "closed")),
        render_text=not args.no_text,
        version=args.version,
        version_prefix=args.version_prefix,
    )


def _params_from_reference(reference: Path, render_text: bool, version: int, version_prefix: str) -> CanHolderParams:
    base = _parse_reference_params(reference)
    return CanHolderParams(
        can_diameter=float(base["can_diameter"]),
        padding=float(base["padding"]),
        can_inset=float(base["can_inset"]),
        padding_left=float(base["padding_left"]),
        angle=_pick_reference_angle(base, reference),
        bottom=str(base["bottom"]),
        render_text=render_text,
        version=version,
        version_prefix=version_prefix,
    )


def _bbox_delta(ours: tuple[float, float, float], ref: tuple[float, float, float]) -> tuple[float, float, float]:
    return tuple(ours[i] - ref[i] for i in range(3))


def _format_dims(values: tuple[float, float, float]) -> str:
    return "/".join(f"{v:.2f}" for v in values)


def generate_reference_folder(args: argparse.Namespace) -> int:
    references = sorted(args.reference_dir.glob("*.stl"))
    if not references:
        raise SystemExit(f"no STL files found in {args.reference_dir}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    bbox_failures = 0
    shape_failures = 0
    for reference in references:
        params = _params_from_reference(reference, not args.no_text, args.version, args.version_prefix)
        output = args.output_dir / reference.name
        export_stl(
            build_can_holder(params),
            output,
            tolerance=args.tolerance,
            angular_tolerance=args.angular_tolerance,
            ascii_format=args.ascii,
        )
        ref_bbox = _read_stl_bbox(reference)
        out_bbox = _read_stl_bbox(output)
        delta = _bbox_delta(out_bbox, ref_bbox)
        max_abs = max(abs(v) for v in delta)
        shape = None
        if args.shape_report:
            shape = _shape_diff_metrics(output, reference, args.shape_samples, args.shape_triangle_candidates)
            shape_failed = (
                shape["symmetric_p95"] > args.shape_p95_tolerance
                or shape["symmetric_hausdorff"] > args.shape_max_tolerance
                or abs(shape["volume_ratio"] - 1.0) > args.volume_ratio_tolerance
            )
            shape_failures += int(shape_failed)
        bbox_failed = max_abs > args.bbox_tolerance
        bbox_failures += int(bbox_failed)
        rows.append((reference.name, params, out_bbox, ref_bbox, delta, max_abs, shape))

    report_lines = [
        "# build123d can-holder batch report",
        f"reference_dir: {args.reference_dir}",
        f"output_dir: {args.output_dir}",
        f"count: {len(rows)}",
        f"bbox_tolerance: {args.bbox_tolerance:.2f} mm",
        f"bbox_failures: {bbox_failures}",
        f"shape_samples: {args.shape_samples if args.shape_report else 'not-run'}",
        f"shape_triangle_candidates: {args.shape_triangle_candidates if args.shape_report else 'not-run'}",
        f"shape_p95_tolerance: {args.shape_p95_tolerance:.2f} mm",
        f"shape_max_tolerance: {args.shape_max_tolerance:.2f} mm",
        f"volume_ratio_tolerance: {args.volume_ratio_tolerance:.3f}",
        f"shape_failures: {shape_failures if args.shape_report else 'not-run'}",
        "",
    ]
    header = [
        "bbox_status",
        "shape_status",
        "bbox_max_abs",
        "angle",
        "bottom",
        "ours_bbox",
        "ref_bbox",
        "bbox_delta",
        "volume_ratio",
        "sym_p95",
        "sym_p99",
        "sym_max",
        "within_0.5_pct",
        "file",
    ]
    report_lines.append("\t".join(header))
    for name, params, out_bbox, ref_bbox, delta, max_abs, shape in rows:
        bbox_status = "BBOX_OK" if max_abs <= args.bbox_tolerance else "BBOX_FAIL"
        if shape is None:
            shape_status = "SHAPE_NOT_RUN"
            shape_values = ["", "", "", ""]
        else:
            shape_failed = (
                shape["symmetric_p95"] > args.shape_p95_tolerance
                or shape["symmetric_hausdorff"] > args.shape_max_tolerance
                or abs(shape["volume_ratio"] - 1.0) > args.volume_ratio_tolerance
            )
            shape_status = "SHAPE_FAIL" if shape_failed else "SHAPE_OK"
            shape_values = [
                f"{shape['volume_ratio']:.3f}",
                f"{shape['symmetric_p95']:.3f}",
                f"{shape['symmetric_p99']:.3f}",
                f"{shape['symmetric_hausdorff']:.3f}",
                f"{shape['within_0_5_pct']:.1f}",
            ]
        report_lines.append(
            "\t".join(
                [
                    bbox_status,
                    shape_status,
                    f"{max_abs:.2f}",
                    f"{params.angle:g}",
                    params.bottom,
                    _format_dims(out_bbox),
                    _format_dims(ref_bbox),
                    _format_dims(delta),
                    *shape_values,
                    name,
                ]
            )
        )
    report = "\n".join(report_lines) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(report)
        print(args.report)
    else:
        print(report, end="")
    return 1 if bbox_failures or shape_failures else 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--reference",
        type=Path,
        help="Frenchfinity 1.0 STL; filename supplies cd/pl/ci/p and angle is inferred by bbox when omitted",
    )
    parser.add_argument("--reference-dir", type=Path, help="generate every *.stl in this 1.0 can-holder folder")
    parser.add_argument("--output-dir", type=Path, default=Path("generated_stl/build123d_can_holder"))
    parser.add_argument("--report", type=Path, help="write a tab-separated batch validation report")
    parser.add_argument("--bbox-tolerance", type=float, default=0.5, help="batch bbox pass threshold in mm")
    parser.add_argument("--shape-report", action="store_true", help="include sampled code-level surface distance metrics in batch report")
    parser.add_argument("--shape-samples", type=int, default=2000, help="surface samples per mesh for --shape-report")
    parser.add_argument("--shape-triangle-candidates", type=int, default=2048, help="nearest triangle centroids considered per sampled point")
    parser.add_argument("--shape-p95-tolerance", type=float, default=1.25, help="batch shape p95 pass threshold in mm")
    parser.add_argument("--shape-max-tolerance", type=float, default=25.0, help="batch sampled Hausdorff/max pass threshold in mm")
    parser.add_argument("--volume-ratio-tolerance", type=float, default=0.05, help="allowed absolute volume ratio error for shape gate")
    parser.add_argument("-o", "--output", type=Path, help="STL output path; default goes under generated_stl/")
    parser.add_argument("--can-diameter", "--cd", type=float)
    parser.add_argument("--padding", "-p", type=float)
    parser.add_argument("--can-inset", "--ci", type=float)
    parser.add_argument("--padding-left", "--pl", type=float)
    parser.add_argument("--angle", "-a", type=float)
    parser.add_argument("--bottom", choices=("closed", "open"))
    parser.add_argument("--no-text", action="store_true", help="omit engraved parameter labels")
    parser.add_argument("--version", type=int, default=1)
    parser.add_argument("--version-prefix", default="scad")
    parser.add_argument("--ascii", action="store_true", help="write ASCII STL instead of binary STL")
    parser.add_argument("--tolerance", type=float, default=0.001, help="STL linear mesh tolerance")
    parser.add_argument("--angular-tolerance", type=float, default=0.1, help="STL angular mesh tolerance")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.reference_dir is not None:
        return generate_reference_folder(args)

    params = _params_from_args(args)
    geo = CanHolderGeometry(params)
    output = geo.filename(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    part = build_can_holder(params)
    export_stl(
        part,
        output,
        tolerance=args.tolerance,
        angular_tolerance=args.angular_tolerance,
        ascii_format=args.ascii,
    )
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
