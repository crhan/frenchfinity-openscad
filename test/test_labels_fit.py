#!/usr/bin/env python3
"""Regression test: the engraved labels of every tool holder must stay inside
the part.

A ~1.5 mm engraving cannot grow the part's bounding box, so a label that does
not fit is silently clipped / dropped (this actually happened: a bottom line ran
off short parts). We therefore render the labels *as positive solids* (the
test/labels_only*.scad harnesses) and check their bounding box fits within the
region of the part that is guaranteed to be solid.

Each model registers a suite: its harness scad, the cases (parameter sets), and
a function that returns the allowed (zmin, zmax, ymin, ymax) box for a case. The
labels are intentionally allowed to poke through the side walls in X (that is how
the engraving cuts in), so only Z and Y are checked.

Run:  python3 test/test_labels_fit.py
Exit code 0 = all pass, 1 = a failure.
"""

import os
import shutil
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
EPS = 0.1  # float / fillet tolerance (mm)


def find_openscad():
    for cand in (
        shutil.which("openscad"),
        "/opt/homebrew/bin/openscad",
        "/usr/local/bin/openscad",
        "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD",
    ):
        if cand and os.path.exists(cand):
            return cand
    print("ERROR: openscad CLI not found", file=sys.stderr)
    sys.exit(2)


OSC = find_openscad()


def render(scad, params, out):
    cmd = [OSC, "-o", out, "--export-format", "binstl"]
    for k, v in params.items():
        if isinstance(v, bool):
            val = "true" if v else "false"   # OpenSCAD booleans are lowercase
        elif isinstance(v, str):
            val = f'"{v}"'
        else:
            val = v
        cmd += ["-D", f"{k}={val}"]
    cmd.append(scad)
    return subprocess.run(cmd, capture_output=True, text=True)


def bbox(stl):
    """Return (n_triangles, (xmin,ymin,zmin), (xmax,ymax,zmax)) or (0,None,None)."""
    with open(stl, "rb") as f:
        f.read(80)
        n = struct.unpack("<I", f.read(4))[0]
        data = f.read(n * 50)
    if n == 0:
        return 0, None, None
    lo = [float("inf")] * 3
    hi = [float("-inf")] * 3
    for t in range(n):
        base = t * 50 + 12  # skip the normal
        for vi in range(3):
            off = base + vi * 12
            x, y, z = struct.unpack_from("<fff", data, off)
            for a, c in enumerate((x, y, z)):
                lo[a] = min(lo[a], c)
                hi[a] = max(hi[a], c)
    return n, tuple(lo), tuple(hi)


# --------------------------------------------------------------------------
# Rectangular tool holder suite
# --------------------------------------------------------------------------
RTH = "rectangular_tool_holder_"


def rth_bounds(p):
    # Must match src/rectangular_tool_holder.scad: h = tsh + 15, l = tl + 10.
    # Labels are on the side wall: check Z (height) and Y (length).
    h = p[RTH + "tool_slot_height"] + 15
    l = p[RTH + "tool_length"] + 10
    return [(2, 0.0, h), (1, 0.0, l)]


RTH_CASES = [
    ("rth_default",    dict(tool_width=20, tool_length=60,  tool_slot_height=10, hole_width=8), False),
    ("rth_tiny_h1",    dict(tool_width=20, tool_length=60,  tool_slot_height=1,  hole_width=8), False),
    ("rth_tiny_h3",    dict(tool_width=20, tool_length=60,  tool_slot_height=3,  hole_width=8), False),
    ("rth_short_len",  dict(tool_width=20, tool_length=18,  tool_slot_height=10, hole_width=8), False),
    ("rth_tiny_both",  dict(tool_width=16, tool_length=15,  tool_slot_height=2,  hole_width=4), False),
    ("rth_big_text",   dict(tool_width=20, tool_length=60,  tool_slot_height=10, hole_width=8, text_size=12), False),
    ("rth_big_part",   dict(tool_width=52, tool_length=128, tool_slot_height=30, hole_width=36), False),
    ("rth_hole_left",  dict(tool_width=12.5, tool_length=46, tool_slot_height=5, hole_width=8, hole_position="left"), False),
    ("rth_hole_right", dict(tool_width=12.5, tool_length=46, tool_slot_height=5, hole_width=8, hole_position="right"), False),
    ("rth_text_off",   dict(tool_width=20, tool_length=60, tool_slot_height=10, hole_width=8, render_text=False), True),
]


# --------------------------------------------------------------------------
# Pliers holder suite
# --------------------------------------------------------------------------
PH = "pliers_holder_"


def ph_bounds(p):
    # Labels live inside the always-solid seat rectangle (see pliers_holder.scad):
    # Z in [0, seat_top], Y in [body_depth - seat_depth, body_depth].
    toe, seat_frac, base_extra = 10, 0.55, 6
    body_depth, seat_depth = 80, 54
    h = p[PH + "height"] + base_extra
    seat_top = toe + (h - toe) * seat_frac
    return [(2, 0.0, seat_top), (1, body_depth - seat_depth, body_depth)]


PH_CASES = [
    ("ph_default",   dict(height=80,  hole_diameter=18), False),
    ("ph_tiny",      dict(height=40,  hole_diameter=12), False),
    ("ph_short",     dict(height=60,  hole_diameter=14), False),
    ("ph_tall",      dict(height=150, hole_diameter=23), False),
    ("ph_big_text",  dict(height=80,  hole_diameter=18, text_size=12), False),
    ("ph_text_off",  dict(height=80,  hole_diameter=18, render_text=False), True),
]


# --------------------------------------------------------------------------
# Round hanging holder suite
# --------------------------------------------------------------------------
RHH = "round_hanging_holder_"


def rhh_bounds(p):
    # Labels are on the solid front wall (the X-Z face): check Z (height) and
    # X (width). w = td + 10, h = td + 10 (see round_hanging_holder.scad).
    td = p[RHH + "tool_diameter"]
    w = td + 10
    h = td + 10
    return [(2, 0.0, h), (0, 0.0, w)]


RHH_CASES = [
    ("rhh_default", dict(tool_diameter=39, holder_depth=21, bottom_hole_width=20, inset_depth=5), False),
    ("rhh_small",   dict(tool_diameter=9,  holder_depth=9,  bottom_hole_width=8,  inset_depth=2.25), False),
    ("rhh_big",     dict(tool_diameter=60, holder_depth=24, bottom_hole_width=9,  inset_depth=2.25), False),
    ("rhh_deep",    dict(tool_diameter=39, holder_depth=40, bottom_hole_width=20, inset_depth=4), False),
    ("rhh_text_off", dict(tool_diameter=39, holder_depth=21, bottom_hole_width=20, inset_depth=5, render_text=False), True),
]


SUITES = [
    ("rectangular_tool_holder", os.path.join(HERE, "labels_only.scad"),        RTH, rth_bounds, RTH_CASES),
    ("pliers_holder",           os.path.join(HERE, "labels_only_pliers.scad"), PH,  ph_bounds,  PH_CASES),
    ("round_hanging_holder",    os.path.join(HERE, "labels_only_round.scad"),  RHH, rhh_bounds, RHH_CASES),
]

AXIS_NAME = {0: "X", 1: "Y", 2: "Z"}


def main():
    tmp = tempfile.mkdtemp(prefix="labels_test_")
    failures = total = 0

    for model, scad, prefix, bounds, cases in SUITES:
        print(f"=== {model} ===")
        for name, raw, expect_empty in cases:
            total += 1
            # prefix model-specific keys; pass shared keys (text_size, render_text) through
            shared = ("text_size", "render_text")
            params = {(k if k in shared else prefix + k): v for k, v in raw.items()}
            out = os.path.join(tmp, name + ".stl")
            r = render(scad, params, out)

            if expect_empty:
                n = 0
                if os.path.exists(out) and os.path.getsize(out) > 84:
                    n, _, _ = bbox(out)
                if n == 0:
                    print(f"[PASS] {name}: no text rendered (render_text=false)")
                else:
                    print(f"[FAIL] {name}: expected no text but got {n} triangles")
                    failures += 1
                continue

            if r.returncode != 0 or not os.path.exists(out):
                print(f"[FAIL] {name}: openscad render failed\n{r.stderr.strip()[:300]}")
                failures += 1
                continue
            n, lo, hi = bbox(out)
            if n == 0 or lo is None or hi is None:
                print(f"[FAIL] {name}: labels are empty (nothing engraved)")
                failures += 1
                continue

            errs = []
            report = []
            for axis, amin, amax in bounds(params):
                a = AXIS_NAME[axis]
                if lo[axis] < amin - EPS:
                    errs.append(f"{a} below region ({lo[axis]:.2f} < {amin:.1f})")
                if hi[axis] > amax + EPS:
                    errs.append(f"{a} above region ({hi[axis]:.2f} > {amax:.1f})")
                report.append(f"{a} {lo[axis]:.2f}..{hi[axis]:.2f}/{amin:.1f}..{amax:.1f}")

            if errs:
                print(f"[FAIL] {name}: " + "; ".join(errs) + "  [" + ", ".join(report) + "]")
                failures += 1
            else:
                print(f"[PASS] {name}: text fits  " + "  ".join(report))

    print()
    if failures:
        print(f"FAILED: {failures}/{total} cases")
        return 1
    print(f"OK: all {total} cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
