#!/usr/bin/env python3
"""Compare two STL meshes — OURS (2.0, generated) vs a 1.0 REFERENCE — and say
how close the shapes are, then show WHERE they differ.

Why this exists: the project's iron rule is "bbox parity != shape parity". Eyeballing
renders is slow and subjective; this gives a number ("how alike") AND localizes the
mismatch so you know what to fix. It auto-aligns the two meshes (the 1.0 Fusion exports
sit at arbitrary positions / orientations / mirrors), so you do NOT have to hand-tune a
translate() in a coordinate frame ever again.

Method (no external mesh libs, just numpy + scipy):
  1. load both STLs (binary or ASCII),
  2. find the best of the 48 axis-aligned orientations (rotations + mirrors) and the
     translation that maps REF onto OURS (centroid seed + a few ICP translation steps),
  3. score similarity by symmetric surface distance (Chamfer / Hausdorff) on area-
     weighted surface samples, plus a volume ratio and bbox match,
  4. localize: report the regions where OURS has EXTRA material and where it is MISSING
     material (so you know which feature is off),
  5. if an out-dir is given and `openscad` is on PATH, render the aligned overlay and the
     two difference solids (red = our extra, blue = missing) from iso/side/front/top.

Usage:
    tools/stl_diff.py OURS.stl REF.stl [OUT_DIR]
    tools/stl_diff.py OURS.stl REF.stl OUT_DIR --no-render   # numbers only

Exit code 0 always (it's a report, not a gate). Read the report.
"""
import sys, os, struct, itertools, shutil, subprocess
import numpy as np
from scipy.spatial import KDTree

RNG = np.random.default_rng(0)          # fixed seed -> reproducible
N_SAMPLE = 40000                        # surface points for the final metrics
N_SUB = 2000                            # subsample for the orientation search
NEAR = 0.5                              # "matching" surface tolerance (mm)


# ----------------------------------------------------------------------------- IO
def load_stl(path):
    """Return an (n,3,3) float array of triangle vertices. Binary or ASCII."""
    with open(path, "rb") as f:
        raw = f.read()
    if len(raw) >= 84:
        n = struct.unpack("<I", raw[80:84])[0]
        if len(raw) == 84 + n * 50:                     # well-formed binary
            rec = np.frombuffer(raw[84:84 + n * 50], dtype=np.uint8).reshape(n, 50)
            flo = rec[:, :48].copy().view("<f4").reshape(n, 12)
            return flo[:, 3:12].reshape(n, 3, 3).astype(np.float64)
    # ASCII fallback
    verts = []
    for line in raw.decode("ascii", "ignore").splitlines():
        s = line.split()
        if len(s) == 4 and s[0] == "vertex":
            verts.append((float(s[1]), float(s[2]), float(s[3])))
    v = np.asarray(verts, np.float64)
    return v.reshape(-1, 3, 3)


# ------------------------------------------------------------------- mesh helpers
def vol_centroid(t):
    """Absolute volume and the volume-weighted centroid (divergence theorem)."""
    v0, v1, v2 = t[:, 0], t[:, 1], t[:, 2]
    sv = np.einsum("ij,ij->i", v0, np.cross(v1, v2)) / 6.0   # signed tetra volumes
    vol = sv.sum()
    cent = (v0 + v1 + v2) / 4.0
    c = (cent * sv[:, None]).sum(0) / vol
    return abs(vol), c


def sample_surface(t, n):
    """n points sampled uniformly over the surface (area-weighted triangles)."""
    v0, v1, v2 = t[:, 0], t[:, 1], t[:, 2]
    area = 0.5 * np.linalg.norm(np.cross(v1 - v0, v2 - v0), axis=1)
    idx = RNG.choice(len(t), size=n, p=area / area.sum())
    u, w = RNG.random(n), RNG.random(n)
    flip = u + w > 1.0
    u[flip], w[flip] = 1 - u[flip], 1 - w[flip]
    a, b, c = v0[idx], v1[idx], v2[idx]
    return a + (b - a) * u[:, None] + (c - a) * w[:, None]


def orientations():
    """All 48 signed axis permutations (24 rotations + 24 mirrors)."""
    for perm in itertools.permutations(range(3)):
        for signs in itertools.product((1.0, -1.0), repeat=3):
            M = np.zeros((3, 3))
            for row, col in enumerate(perm):
                M[row, col] = signs[row]
            yield M


# --------------------------------------------------------------------- alignment
def align(A_pts, B_pts, cA, cB):
    """Find R (one of 48) + t mapping B onto A. Returns (R, t, score_mm)."""
    Asub = A_pts[RNG.choice(len(A_pts), N_SUB)]
    treeA = KDTree(Asub)
    best = (float("inf"), np.eye(3), np.zeros(3))
    for R in orientations():
        t = cA - cB @ R.T
        Bsub = (B_pts[RNG.choice(len(B_pts), N_SUB)] @ R.T) + t
        for _ in range(6):                              # ICP, translation only
            _, i = treeA.query(Bsub)
            shift = (Asub[i] - Bsub).mean(0)
            Bsub += shift
            t = t + shift
        score = treeA.query(Bsub)[0].mean()
        if score < best[0]:
            best = (score, R, t)
    return best[1], best[2], best[0]


# --------------------------------------------------------------------- localize
def hot_regions(pts, dist, thr, bin_mm=6.0, top=6):
    """Cluster the points whose deviation > thr into coarse bins; report the worst."""
    mask = dist > thr
    if not mask.any():
        return []
    p, d = pts[mask], dist[mask]
    keys = np.floor(p / bin_mm).astype(int)
    buckets = {}
    for k, pt, dd in zip(map(tuple, keys), p, d):
        b = buckets.setdefault(k, [0, np.zeros(3), 0.0])
        b[0] += 1
        b[1] += pt
        b[2] = max(b[2], dd)
    rows = [(c, ctr / c, mx) for c, ctr, mx in buckets.values()]
    rows.sort(key=lambda r: -r[0])
    return rows[:top]


# ------------------------------------------------------------------------ render
def render(ours, ref, R, t, out):
    osc = shutil.which("openscad") or "/opt/homebrew/bin/openscad"
    if not os.path.exists(osc) and not shutil.which("openscad"):
        print("  (openscad not found — skipping render)")
        return
    M = "[[%s],[%s],[%s],[0,0,0,1]]" % (
        ",".join("%.9f" % x for x in (*R[0], t[0])),
        ",".join("%.9f" % x for x in (*R[1], t[1])),
        ",".join("%.9f" % x for x in (*R[2], t[2])),
    )
    a, b = os.path.abspath(ours), os.path.abspath(ref)
    refT = 'multmatrix(%s) import("%s");' % (M, b)
    scads = {
        "overlay": 'color([0.85,0.30,0.25,0.55]) import("%s");\n'
                   'color([0.30,0.55,0.95,0.55]) %s' % (a, refT),
        "diff": 'color([0.90,0.20,0.15]) difference(){ import("%s"); %s }\n'
                'color([0.20,0.45,0.95]) difference(){ %s import("%s"); }'
                % (a, refT, refT, a),
    }
    cams = {"iso": "0,0,0,55,0,25,0", "side": "0,0,0,90,0,90,0",
            "front": "0,0,0,90,0,0,0", "top": "0,0,0,0,0,0,0"}
    os.makedirs(out, exist_ok=True)
    for name, body in scads.items():
        sp = os.path.join(out, "_%s.scad" % name)
        with open(sp, "w") as f:
            f.write(body + "\n")
        for cam, c in cams.items():
            png = os.path.join(out, "diff_%s_%s.png" % (name, cam))
            subprocess.run([osc, "-o", png, "--imgsize=700,700", "--camera=" + c,
                            "--viewall", "--autocenter", "--colorscheme=Tomorrow", sp],
                           capture_output=True)
    print("  rendered overlay + difference views -> %s/diff_*.png" % out)


# --------------------------------------------------------------------------- main
def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    if len(args) < 2:
        print(__doc__)
        sys.exit(2)
    ours_p, ref_p = args[0], args[1]
    out = args[2] if len(args) > 2 else None

    A = load_stl(ours_p)        # ours
    B = load_stl(ref_p)         # 1.0 reference
    volA, cA = vol_centroid(A)
    volB, cB = vol_centroid(B)
    Asurf, Bsurf = sample_surface(A, N_SAMPLE), sample_surface(B, N_SAMPLE)

    R, t, _ = align(Asurf, Bsurf, cA, cB)
    Bal = Bsurf @ R.T + t                       # ref surface, aligned onto ours

    treeB = KDTree(Bal)
    treeA = KDTree(Asurf)
    dAB = treeB.query(Asurf)[0]                 # ours -> ref  (large = our EXTRA material)
    dBA = treeA.query(Bal)[0]                   # ref  -> ours (large = our MISSING material)

    def bbox(p):
        return p.min(0), p.max(0)
    amin, amax = bbox(Asurf)
    bmin, bmax = bbox(Bal)

    is_ident = np.allclose(R, np.eye(3))
    is_mirror = np.linalg.det(R) < 0
    print("=" * 70)
    print("STL diff   OURS: %s" % os.path.basename(ours_p))
    print("            REF: %s" % os.path.basename(ref_p))
    print("=" * 70)
    print("alignment   : %s%s   t=[%.2f, %.2f, %.2f]" % (
        "identity" if is_ident else "rotated", " +MIRROR" if is_mirror else "", *t))
    if not is_ident:
        print("              R=%s" % R.tolist())
    print("bbox ours   : [%.2f %.2f %.2f]" % tuple(amax - amin))
    print("bbox ref    : [%.2f %.2f %.2f]  (aligned)" % tuple(bmax - bmin))
    print("bbox dim Δ  : [%+.2f %+.2f %+.2f]" % tuple((amax - amin) - (bmax - bmin)))
    print("volume      : ours %.0f / ref %.0f mm³   ratio %.3f" % (volA, volB, volA / volB))
    print("-" * 70)
    print("surface deviation after alignment (mm):")
    print("  ours→ref  mean %.3f  p95 %.3f  max %.3f" % (
        dAB.mean(), np.percentile(dAB, 95), dAB.max()))
    print("  ref→ours  mean %.3f  p95 %.3f  max %.3f" % (
        dBA.mean(), np.percentile(dBA, 95), dBA.max()))
    haus = max(dAB.max(), dBA.max())
    within = 100.0 * ((dAB < NEAR).sum() + (dBA < NEAR).sum()) / (len(dAB) + len(dBA))
    print("  symmetric Hausdorff %.3f mm   |   %.1f%% of surface within %.2fmm" % (
        haus, within, NEAR))
    # one-line verdict
    if haus < NEAR and abs(volA / volB - 1) < 0.02:
        verdict = "MATCH — shapes are essentially identical"
    elif np.percentile(np.r_[dAB, dBA], 95) < 1.0:
        verdict = "CLOSE — minor local differences (see regions below)"
    else:
        verdict = "DIFFERENT — real shape mismatch (see regions below)"
    print("  VERDICT: %s" % verdict)

    thr = max(NEAR, np.percentile(np.r_[dAB, dBA], 90))
    extra = hot_regions(Asurf, dAB, thr)
    missing = hot_regions(Bal, dBA, thr)
    if extra:
        print("-" * 70)
        print("OURS has EXTRA material (ref doesn't), worst spots [x y z]  maxΔmm:")
        for c, ctr, mx in extra:
            print("  (%7.1f %7.1f %7.1f)  Δ≤%.2f   (%d pts)" % (*ctr, mx, c))
    if missing:
        print("-" * 70)
        print("OURS is MISSING material (ref has it), worst spots [x y z]  maxΔmm:")
        for c, ctr, mx in missing:
            print("  (%7.1f %7.1f %7.1f)  Δ≤%.2f   (%d pts)" % (*ctr, mx, c))

    if out and "--no-render" not in flags:
        print("-" * 70)
        render(ours_p, ref_p, R, t, out)


if __name__ == "__main__":
    main()
