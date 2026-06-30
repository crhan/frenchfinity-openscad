#!/usr/bin/env python3
"""CadQuery experiment for the Frenchfinity 1.0 Can-Holder.

Run with uv so CadQuery stays out of the repository:

    uv run --no-project --python 3.12 --with cadquery tools/cadquery_can_holder.py \
        --reference FrenchFinity/Can-Holder/frenchfinity-can-holder-v1-cd23.00-pl22.00-ci80.00-p8.00.stl \
        --output generated_stl/cadquery/can.stl \
        --diff-out generated_stl/cadquery/diff

The 1.0 file names do not encode the free Fusion `angle` parameter.  When a
reference STL is supplied and --angle is omitted, this script picks the best
angle from the known 1.0 set (10/15/20/30/40 deg) by bbox parity.
"""

from __future__ import annotations

import argparse
import math
import re
import struct
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    import cadquery as cq
except ImportError as exc:  # pragma: no cover - the message is for CLI users.
    raise SystemExit(
        "cadquery is not installed. Run via:\n"
        "  uv run --no-project --python 3.12 --with cadquery tools/cadquery_can_holder.py ..."
    ) from exc


ANGLE_CANDIDATES = (10.0, 15.0, 20.0, 30.0, 40.0)

# Can-holder-specific constants, copied from src/can_holder.scad.
CAN_HOLDER_CLEARANCE = 2.0
CAN_HOLDER_LEADIN = 3.0
CAN_HOLDER_FILLET = 2.0
CAN_HOLDER_DRAIN = 6.0
CAN_HOLDER_BORE_BOTTOM_EXTRA = 4.0

# Shared Frenchfinity 1.0 male cleat constants, copied from src/frenchfinity.scad.
SLOT_INNER_HEIGHT = 8.5
SLOT_INNER_WIDTH = 4.5
SLOT_OUTER_WIDTH = 6.6
SLOT_OUTER_HEIGHT = 6.5
SLOT_TOLERANCE = 0.25
FILAMENT_HOLE_SIZE = 1.70

# Label constants, copied from the OpenSCAD defaults.
TEXT_DEPTH = 1.0
TEXT_SIZE_MIN = 3.5
TEXT_LINE_SPACING = 1.35


@dataclass(frozen=True)
class CanHolderParams:
    can_diameter: float = 10.0
    padding: float = 10.0
    can_inset: float = 55.0
    padding_left: float = 16.0
    angle: float = 10.0
    bottom: str = "closed"
    version_prefix: str = "v1scad"

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
        if self.bottom not in {"closed", "open"}:
            raise ValueError("bottom must be one of: closed, open")


def deg_sin(angle: float) -> float:
    return math.sin(math.radians(angle))


def deg_cos(angle: float) -> float:
    return math.cos(math.radians(angle))


def deg_tan(angle: float) -> float:
    return math.tan(math.radians(angle))


def bore_d(params: CanHolderParams) -> float:
    return params.can_diameter + CAN_HOLDER_CLEARANCE


def outer_width(params: CanHolderParams) -> float:
    return params.can_diameter + 2 * params.padding


def can_holder_C(params: CanHolderParams) -> float:
    cd = params.can_diameter
    p = params.padding
    t = deg_tan(params.angle)
    return (
        1.0122 * cd
        + 1.8276 * p
        - 0.1120 * cd * t
        - 0.2464 * cd * t * t
        - 9.0947 * t
        + 6.3539
    )


def can_holder_K(params: CanHolderParams) -> float:
    cd = params.can_diameter
    p = params.padding
    r = bore_d(params) / 2
    a = params.angle
    return (
        2.2371 * r * deg_sin(a)
        + 18.3335 * deg_sin(a)
        - 0.1059 * cd * deg_tan(a)
        + 1.5820 * p
        - 5.3775
    )


def base_height(params: CanHolderParams) -> float:
    return 9.0 + 0.3 * params.padding_left


def holder_height(params: CanHolderParams) -> float:
    return params.can_inset * deg_cos(params.angle) + can_holder_K(params)


def front_pullin(params: CanHolderParams) -> float:
    a = params.angle
    return (CAN_HOLDER_FILLET / 2.0) * (0.04 * a - 0.00047 * a * a)


def front_eff(params: CanHolderParams) -> float:
    return can_holder_C(params) + front_pullin(params)


def front_max(params: CanHolderParams) -> float:
    return params.padding_left + front_eff(params)


def fronttop_z(params: CanHolderParams) -> float:
    return holder_height(params) - front_eff(params) * deg_tan(params.angle)


def front_y(params: CanHolderParams, z: float) -> float:
    return front_max(params) - (fronttop_z(params) - z) * deg_tan(params.angle)


def floor_z(params: CanHolderParams) -> float:
    return base_height(params) + bore_d(params) / 2.0 * deg_sin(params.angle)


def bore_yc(params: CanHolderParams) -> float:
    return (
        front_y(params, floor_z(params))
        - (bore_d(params) / 2.0 + params.padding) / deg_cos(params.angle)
        - 0.37
    )


def cleat_origin(params: CanHolderParams) -> float:
    return holder_height(params) - 10.19 - SLOT_OUTER_HEIGHT / 2.0


def cleat_bottom(params: CanHolderParams) -> float:
    # Kept aligned with src/can_holder.scad, not used for cleat placement.
    return holder_height(params) - 2.0 * 7.394


def side_profile(params: CanHolderParams) -> list[tuple[float, float]]:
    h = holder_height(params)
    pl = params.padding_left
    return [
        (0.0, 0.0),
        (front_y(params, 0.0), 0.0),
        (front_max(params), fronttop_z(params)),
        (pl, h),
        (0.0, h),
    ]


def bbox_for_params(params: CanHolderParams) -> tuple[float, float, float]:
    """Expected OpenSCAD/1.0-style bbox, including male cleat protrusion."""
    zs = [p[1] for p in side_profile(params)]
    cleat_tip = -SLOT_OUTER_WIDTH - SLOT_INNER_WIDTH + SLOT_TOLERANCE
    # The sharp front-top profile is built further out by front_pullin(); the
    # fillet pulls the rendered max-Y point back to padding_left + C, matching
    # the measured Frenchfinity 1.0 bbox.
    rendered_front = params.padding_left + can_holder_C(params)
    return (
        outer_width(params),
        rendered_front - cleat_tip,
        max(zs) - min(0.0, cleat_origin(params) + 0.0),
    )


def make_box_from_bounds(bounds: tuple[float, float, float, float, float, float]) -> cq.Workplane:
    xmin, xmax, ymin, ymax, zmin, zmax = bounds
    return (
        cq.Workplane("XY")
        .box(xmax - xmin, ymax - ymin, zmax - zmin, centered=(False, False, False))
        .translate((xmin, ymin, zmin))
    )


def make_outer_shell(params: CanHolderParams) -> cq.Workplane:
    """Extrude the YZ profile along X, then fillet only the 1.0 rounded edges."""
    profile = side_profile(params)
    width = outer_width(params)
    shell = cq.Workplane("YZ").polyline(profile).close().extrude(width)

    rounded_points = [
        (width / 2.0, front_max(params), fronttop_z(params)),
        (width / 2.0, params.padding_left, holder_height(params)),
    ]
    for point in rounded_points:
        shell = shell.edges(cq.selectors.NearestToPointSelector(point)).fillet(CAN_HOLDER_FILLET)
    return shell


def axis_vector(params: CanHolderParams) -> tuple[float, float, float]:
    return (0.0, deg_sin(params.angle), deg_cos(params.angle))


def point_on_axis(
    start: tuple[float, float, float],
    direction: tuple[float, float, float],
    distance: float,
) -> tuple[float, float, float]:
    return tuple(start[i] + direction[i] * distance for i in range(3))


def make_body(params: CanHolderParams, *, render_text: bool = True) -> cq.Workplane:
    width = outer_width(params)
    radius = bore_d(params) / 2.0
    center_floor = (width / 2.0, bore_yc(params), floor_z(params))
    direction = axis_vector(params)

    axial_length = (
        deg_sin(params.angle) * (params.padding_left - bore_yc(params))
        + deg_cos(params.angle) * (holder_height(params) - floor_z(params))
    )

    body = make_outer_shell(params)

    bore_start = point_on_axis(center_floor, direction, -CAN_HOLDER_BORE_BOTTOM_EXTRA)
    bore = cq.Solid.makeCylinder(
        radius,
        axial_length + 2.0 + CAN_HOLDER_BORE_BOTTOM_EXTRA,
        pnt=bore_start,
        dir=direction,
    )
    body = body.cut(cq.Workplane("XY").add(bore))

    leadin_start = point_on_axis(center_floor, direction, axial_length - CAN_HOLDER_LEADIN)
    leadin = cq.Solid.makeCone(
        radius,
        radius + CAN_HOLDER_LEADIN,
        CAN_HOLDER_LEADIN + 2.0,
        pnt=leadin_start,
        dir=direction,
    )
    body = body.cut(cq.Workplane("XY").add(leadin))

    if params.bottom == "open":
        drain = cq.Solid.makeCylinder(
            CAN_HOLDER_DRAIN / 2.0,
            floor_z(params) + 4.0,
            pnt=(width / 2.0, bore_yc(params), -1.0),
            dir=(0.0, 0.0, 1.0),
        )
        body = body.cut(cq.Workplane("XY").add(drain))

    if render_text:
        body = cut_labels(body, params)

    return body


def make_male_cleat(params: CanHolderParams) -> cq.Workplane:
    width = outer_width(params)
    z0 = cleat_origin(params)
    tol = SLOT_TOLERANCE

    neck = make_box_from_bounds(
        (
            0.0,
            width,
            -SLOT_OUTER_WIDTH,
            0.0,
            z0 + tol,
            z0 + SLOT_OUTER_HEIGHT - tol,
        )
    )
    head = make_box_from_bounds(
        (
            0.0,
            width,
            -(SLOT_OUTER_WIDTH + SLOT_INNER_WIDTH - tol),
            -SLOT_OUTER_WIDTH,
            z0 + ((SLOT_OUTER_HEIGHT - SLOT_INNER_HEIGHT) / 2.0) + tol,
            z0
            + ((SLOT_OUTER_HEIGHT - SLOT_INNER_HEIGHT) / 2.0)
            + SLOT_INNER_HEIGHT
            - tol,
        )
    )
    cleat = neck.union(head)

    filament_hole = cq.Solid.makeCylinder(
        FILAMENT_HOLE_SIZE / 2.0,
        width + 2.0,
        pnt=(-1.0, -(SLOT_OUTER_WIDTH + SLOT_INNER_WIDTH), z0 + SLOT_OUTER_HEIGHT / 2.0),
        dir=(1.0, 0.0, 0.0),
    )
    return cleat.cut(cq.Workplane("XY").add(filament_hole))


def label_font_size(_lines: list[str], _params: CanHolderParams) -> float:
    return TEXT_SIZE_MIN


def cut_labels(body: cq.Workplane, params: CanHolderParams) -> cq.Workplane:
    lines = [
        params.version_prefix,
        f"cd{fmt_number(params.can_diameter)}",
        f"pl{fmt_number(params.padding_left)}",
        f"ci{fmt_number(params.can_inset)}",
        f"p{fmt_number(params.padding)}",
    ]
    size = label_font_size(lines, params)
    z_low = base_height(params) + 2.0
    z_high = cleat_bottom(params) - 2.0
    if z_high <= z_low:
        return body

    z_center = (z_low + z_high) / 2.0
    line_step = size * TEXT_LINE_SPACING
    # Fixed plane on the back face.  Viewed from the wall/cleat side (-Y), local
    # X is model +X and local Y is model +Z, so the text is not mirrored or
    # vertically inverted.  Negative distance cuts back into the body (+Y).
    label_plane = cq.Plane(
        origin=(outer_width(params) / 2.0, 0.0, z_center),
        xDir=(1.0, 0.0, 0.0),
        normal=(0.0, -1.0, 0.0),
    )
    wp = cq.Workplane(label_plane).add(body.val())
    for i, line in enumerate(lines):
        z_offset = ((len(lines) - 1) / 2.0 - i) * line_step
        wp = wp.center(0.0, z_offset).text(
            line,
            size,
            -TEXT_DEPTH,
            combine="cut",
            font="Arial",
            halign="center",
            valign="center",
        ).center(0.0, -z_offset)
    return wp


def make_can_holder(params: CanHolderParams, *, render_text: bool = True) -> cq.Workplane:
    params.validate()
    return make_body(params, render_text=render_text).union(make_male_cleat(params))


def fmt_number(value: float) -> str:
    return f"{value:.2f}"


def parse_reference_name(path: str | Path, *, angle: float | None = None) -> CanHolderParams:
    name = Path(path).name
    tokens = {key: float(val) for key, val in re.findall(r"([a-z]+)(\d+(?:\.\d+)?)", name)}
    missing = [key for key in ("cd", "pl", "ci", "p") if key not in tokens]
    if missing:
        raise ValueError(f"reference filename is missing parameter token(s): {', '.join(missing)}")
    return CanHolderParams(
        can_diameter=tokens["cd"],
        padding_left=tokens["pl"],
        can_inset=tokens["ci"],
        padding=tokens["p"],
        angle=10.0 if angle is None else angle,
        bottom="open" if "-hole-bottom" in name else "closed",
    )


def read_stl_vertices(path: str | Path):
    raw = Path(path).read_bytes()
    if len(raw) >= 84:
        tri_count = struct.unpack("<I", raw[80:84])[0]
        if len(raw) == 84 + tri_count * 50:
            import numpy as np

            rec = np.frombuffer(raw[84 : 84 + tri_count * 50], dtype=np.uint8).reshape(tri_count, 50)
            floats = rec[:, :48].copy().view("<f4").reshape(tri_count, 12)
            return floats[:, 3:12].reshape(-1, 3).astype(float)

    verts: list[tuple[float, float, float]] = []
    for line in raw.decode("ascii", "ignore").splitlines():
        parts = line.split()
        if len(parts) == 4 and parts[0] == "vertex":
            verts.append((float(parts[1]), float(parts[2]), float(parts[3])))
    if not verts:
        raise ValueError(f"could not read STL vertices from {path}")

    import numpy as np

    return np.asarray(verts, dtype=float)


def stl_bbox_dims(path: str | Path) -> tuple[float, float, float]:
    verts = read_stl_vertices(path)
    dims = verts.max(axis=0) - verts.min(axis=0)
    return tuple(float(x) for x in dims)


def pick_angle_from_bbox(base_params: CanHolderParams, reference: str | Path) -> tuple[float, float]:
    ref_dims = stl_bbox_dims(reference)
    best_angle = ANGLE_CANDIDATES[0]
    best_error = float("inf")
    for candidate in ANGLE_CANDIDATES:
        params = CanHolderParams(
            can_diameter=base_params.can_diameter,
            padding=base_params.padding,
            can_inset=base_params.can_inset,
            padding_left=base_params.padding_left,
            angle=candidate,
            bottom=base_params.bottom,
            version_prefix=base_params.version_prefix,
        )
        dims = bbox_for_params(params)
        error = max(abs(a - b) for a, b in zip(dims, ref_dims))
        if error < best_error:
            best_angle = candidate
            best_error = error
    return best_angle, best_error


def export_stl(part: cq.Workplane, output: str | Path) -> None:
    out = Path(output)
    out.parent.mkdir(parents=True, exist_ok=True)
    cq.exporters.export(
        part,
        str(out),
        exportType=cq.exporters.ExportTypes.STL,
        tolerance=0.05,
        angularTolerance=0.05,
        opt={"ascii": False},
    )


def run_diff(ours: str | Path, reference: str | Path, diff_out: str | Path, *, render: bool) -> int:
    script = Path(__file__).with_name("stl_diff.py")
    cmd = [sys.executable, str(script), str(ours), str(reference), str(diff_out)]
    if not render:
        cmd.append("--no-render")
    return subprocess.run(cmd, check=False).returncode


def build_params_from_args(args: argparse.Namespace) -> CanHolderParams:
    if args.reference:
        params = parse_reference_name(args.reference, angle=args.angle)
        if args.angle is None:
            picked_angle, bbox_error = pick_angle_from_bbox(params, args.reference)
            print(f"auto angle: {picked_angle:g} deg (bbox max error {bbox_error:.2f} mm)", flush=True)
            params = CanHolderParams(
                can_diameter=params.can_diameter,
                padding=params.padding,
                can_inset=params.can_inset,
                padding_left=params.padding_left,
                angle=picked_angle,
                bottom=params.bottom,
                version_prefix=params.version_prefix,
            )
        return params

    required = {
        "--can-diameter": args.can_diameter,
        "--padding": args.padding,
        "--can-inset": args.can_inset,
        "--padding-left": args.padding_left,
    }
    missing = [name for name, value in required.items() if value is None]
    if missing:
        raise ValueError("missing required parameter(s) without --reference: " + ", ".join(missing))
    return CanHolderParams(
        can_diameter=args.can_diameter,
        padding=args.padding,
        can_inset=args.can_inset,
        padding_left=args.padding_left,
        angle=10.0 if args.angle is None else args.angle,
        bottom=args.bottom,
    )


def default_output_path(args: argparse.Namespace, params: CanHolderParams) -> Path:
    if args.output:
        return Path(args.output)
    if args.reference:
        return Path("generated_stl/cadquery") / Path(args.reference).name
    suffix = "-hole-bottom" if params.bottom == "open" else ""
    return Path("generated_stl/cadquery") / (
        f"frenchfinity-can-holder-v1-cd{params.can_diameter:.2f}"
        f"-pl{params.padding_left:.2f}-ci{params.can_inset:.2f}-p{params.padding:.2f}"
        f"-a{params.angle:.2f}{suffix}.stl"
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", help="1.0 Can-Holder STL; parse params from filename")
    parser.add_argument("--output", help="output STL path")
    parser.add_argument("--diff-out", help="optional stl_diff output directory")
    parser.add_argument("--angle", type=float, help="can lean angle; auto-picked from bbox when omitted with --reference")
    parser.add_argument("--can-diameter", type=float, help="cd")
    parser.add_argument("--padding", type=float, help="p")
    parser.add_argument("--can-inset", type=float, help="ci")
    parser.add_argument("--padding-left", type=float, help="pl")
    parser.add_argument("--bottom", choices=("closed", "open"), default="closed")
    parser.add_argument("--no-text", action="store_true", help="skip engraved back-face labels")
    parser.add_argument("--render-diff", action="store_true", help="let stl_diff render PNGs in --diff-out")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    params = build_params_from_args(args)
    params.validate()

    output = default_output_path(args, params)
    print(
        "build CadQuery can holder: "
        f"cd={params.can_diameter:g} pl={params.padding_left:g} "
        f"ci={params.can_inset:g} p={params.padding:g} "
        f"angle={params.angle:g} bottom={params.bottom}",
        flush=True,
    )
    part = make_can_holder(params, render_text=not args.no_text)
    export_stl(part, output)
    print(f"wrote {output}", flush=True)

    actual_dims = stl_bbox_dims(output)
    expected_dims = bbox_for_params(params)
    print(
        "bbox generated: "
        f"{actual_dims[0]:.2f} {actual_dims[1]:.2f} {actual_dims[2]:.2f} mm",
        flush=True,
    )
    print(
        "bbox expected : "
        f"{expected_dims[0]:.2f} {expected_dims[1]:.2f} {expected_dims[2]:.2f} mm",
        flush=True,
    )

    if args.reference and args.diff_out:
        return run_diff(output, args.reference, args.diff_out, render=args.render_diff)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
