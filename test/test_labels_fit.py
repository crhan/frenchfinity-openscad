#!/usr/bin/env python3
"""Regression test: the engraved labels of the rectangular tool holder must
always stay inside the part.

A 1.5 mm engraving cannot grow the part's bounding box, so a label that does not
fit is silently clipped / dropped (this actually happened: the bottom line ran
off short parts). We therefore render the labels *as positive solids*
(test/labels_only.scad) and check their bounding box fits within the part:

    part height h = tool_slot_height + 15   (base_below)
    part length l = tool_length      + 10   (2 * end_wall)

The labels are intentionally allowed to poke through the side walls in X (that is
how the engraving cuts in), so only Z (height) and Y (length) are checked.

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
SCAD = os.path.join(HERE, "labels_only.scad")

# Must match the constants in src/rectangular_tool_holder.scad.
BASE_BELOW = 15   # part height  = tool_slot_height + base_below
END_WALL_2 = 10   # part length  = tool_length      + 2 * end_wall
EPS = 0.1         # float / fillet tolerance (mm)


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


def render(params, out):
    cmd = [OSC, "-o", out, "--export-format", "binstl"]
    for k, v in params.items():
        if isinstance(v, bool):
            val = "true" if v else "false"   # OpenSCAD booleans are lowercase
        elif isinstance(v, str):
            val = f'"{v}"'
        else:
            val = v
        cmd += ["-D", f"{k}={val}"]
    cmd.append(SCAD)
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r


def bbox(stl):
    """Return (n_triangles, (xmin,ymin,zmin), (xmax,ymax,zmax)) or (0,...)."""
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
                if c < lo[a]:
                    lo[a] = c
                if c > hi[a]:
                    hi[a] = c
    return n, tuple(lo), tuple(hi)


# (name, params, expect_empty)
CASES = [
    ("default",        dict(rectangular_tool_holder_tool_width=20, rectangular_tool_holder_tool_length=60,  rectangular_tool_holder_tool_slot_height=10, rectangular_tool_holder_hole_width=8), False),
    ("tiny_height_1",  dict(rectangular_tool_holder_tool_width=20, rectangular_tool_holder_tool_length=60,  rectangular_tool_holder_tool_slot_height=1,  rectangular_tool_holder_hole_width=8), False),
    ("tiny_height_3",  dict(rectangular_tool_holder_tool_width=20, rectangular_tool_holder_tool_length=60,  rectangular_tool_holder_tool_slot_height=3,  rectangular_tool_holder_hole_width=8), False),
    ("short_length",   dict(rectangular_tool_holder_tool_width=20, rectangular_tool_holder_tool_length=18,  rectangular_tool_holder_tool_slot_height=10, rectangular_tool_holder_hole_width=8), False),
    ("tiny_both",      dict(rectangular_tool_holder_tool_width=16, rectangular_tool_holder_tool_length=15,  rectangular_tool_holder_tool_slot_height=2,  rectangular_tool_holder_hole_width=4), False),
    ("big_text",       dict(rectangular_tool_holder_tool_width=20, rectangular_tool_holder_tool_length=60,  rectangular_tool_holder_tool_slot_height=10, rectangular_tool_holder_hole_width=8, text_size=12), False),
    ("big_part",       dict(rectangular_tool_holder_tool_width=52, rectangular_tool_holder_tool_length=128, rectangular_tool_holder_tool_slot_height=30, rectangular_tool_holder_hole_width=36), False),
    ("hole_left",      dict(rectangular_tool_holder_tool_width=12.5, rectangular_tool_holder_tool_length=46, rectangular_tool_holder_tool_slot_height=5, rectangular_tool_holder_hole_width=8, rectangular_tool_holder_hole_position="left"), False),
    ("hole_right",     dict(rectangular_tool_holder_tool_width=12.5, rectangular_tool_holder_tool_length=46, rectangular_tool_holder_tool_slot_height=5, rectangular_tool_holder_hole_width=8, rectangular_tool_holder_hole_position="right"), False),
    ("render_text_off", dict(rectangular_tool_holder_tool_width=20, rectangular_tool_holder_tool_length=60, rectangular_tool_holder_tool_slot_height=10, rectangular_tool_holder_hole_width=8, render_text=False), True),
]


def main():
    tmp = tempfile.mkdtemp(prefix="rth_labels_test_")
    failures = 0
    for name, params, expect_empty in CASES:
        out = os.path.join(tmp, name + ".stl")
        r = render(params, out)

        if expect_empty:
            # No text -> OpenSCAD has nothing to export ("top level object is
            # empty"); that is the correct outcome, not a failure.
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

        tsh = params["rectangular_tool_holder_tool_slot_height"]
        tl = params["rectangular_tool_holder_tool_length"]
        h = tsh + BASE_BELOW
        l = tl + END_WALL_2

        errs = []
        if lo[2] < -EPS:
            errs.append(f"text below part bottom (zmin={lo[2]:.2f} < 0)")
        if hi[2] > h + EPS:
            errs.append(f"text above part top (zmax={hi[2]:.2f} > h={h})")
        if lo[1] < -EPS:
            errs.append(f"text past front (ymin={lo[1]:.2f} < 0)")
        if hi[1] > l + EPS:
            errs.append(f"text past back (ymax={hi[1]:.2f} > l={l})")

        if errs:
            print(f"[FAIL] {name}: " + "; ".join(errs)
                  + f"  [Z {lo[2]:.2f}..{hi[2]:.2f} in 0..{h}, Y {lo[1]:.2f}..{hi[1]:.2f} in 0..{l}]")
            failures += 1
        else:
            print(f"[PASS] {name}: text fits  Z {lo[2]:.2f}..{hi[2]:.2f}/0..{h}  Y {lo[1]:.2f}..{hi[1]:.2f}/0..{l}")

    print()
    if failures:
        print(f"FAILED: {failures}/{len(CASES)} cases")
        return 1
    print(f"OK: all {len(CASES)} cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
