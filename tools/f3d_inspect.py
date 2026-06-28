#!/usr/bin/env python3
"""Pull the user parameters out of a Fusion 360 .f3d (Frenchfinity 1.0).

A .f3d is a ZIP whose data members are Deflate-compressed. The model's design
history lives in `.../Design*/BulkStream.dat`, which embeds the ParametricText
plug-in's format strings as plain text -- and those strings name every user
parameter, e.g.:

    frenchfinity-hook-v{version:.0f}-w{width:.2f}-h{height:.2f}-hd{hook_diameter:.2f}...

So you get the exact parameter names for free, without opening Fusion. This
script prints those templates + parameter names and (optionally) extracts the
preview thumbnail so you can see the shape.

Usage:
  python tools/f3d_inspect.py <file.f3d | folder> [--preview out.png]
  python tools/f3d_inspect.py --all <root-folder>     # scan every .f3d under root
"""

import glob as globlib
import os
import re
import sys
import zipfile


def ascii_strings(b, n=4):
    return [s.decode("ascii") for s in re.findall(rb"[\x20-\x7e]{%d,}" % n, b)]


def inspect(f3d):
    """Return (templates set, params set)."""
    templates, params = set(), set()
    try:
        z = zipfile.ZipFile(f3d)
    except Exception as e:
        return templates, params, str(e)
    targets = [n for n in z.namelist() if re.search(r"Design\d*/(Bulk|Meta)Stream\.dat$", n)]
    for t in targets:
        for s in ascii_strings(z.read(t)):
            if "{" in s and re.search(r"\{[a-zA-Z_]\w*", s):
                if "frenchfinity" in s.lower() or "{_.newline}" in s or re.search(r"\{[a-z_]+:", s):
                    templates.add(s)
                for m in re.findall(r"\{([a-zA-Z_]\w*)(?::[^}]*)?\}", s):
                    params.add(m)
    return templates, params, None


def extract_preview(f3d, out):
    z = zipfile.ZipFile(f3d)
    prev = [n for n in z.namelist() if n.lower().endswith("previews/small.png")]
    if not prev:
        return False
    with open(out, "wb") as f:
        f.write(z.read(prev[0]))
    return True


def find_main_f3d(folder):
    cands = (globlib.glob(os.path.join(folder, "*.f3d"))
             + globlib.glob(os.path.join(folder, "**", "*.f3d"), recursive=True))
    cands = sorted(set(cands), key=os.path.getsize, reverse=True)
    return cands[0] if cands else None


def report(f3d, preview=None):
    print(f"### {os.path.basename(f3d)}")
    templates, params, err = inspect(f3d)
    if err:
        print("  ERROR:", err); return
    for t in sorted(templates):
        print("  TMPL:", t[:200])
    print("  PARAMS:", sorted(params))
    if preview and extract_preview(f3d, preview):
        print("  preview ->", preview)


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__); return 1
    if a[0] == "--all":
        root = a[1]
        for d in sorted(os.listdir(root)):
            p = os.path.join(root, d)
            if os.path.isdir(p):
                f = find_main_f3d(p)
                if f:
                    report(f)
                    print()
        for f in sorted(globlib.glob(os.path.join(root, "*.f3d"))):
            report(f); print()
        return 0
    target = a[0]
    preview = a[a.index("--preview") + 1] if "--preview" in a else None
    f3d = target if target.endswith(".f3d") else find_main_f3d(target)
    if not f3d:
        print("no .f3d found at", target); return 1
    report(f3d, preview)
    return 0


if __name__ == "__main__":
    sys.exit(main())
