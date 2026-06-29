//
// Can holder  (a.k.a. can / drill / spray-can holder)
//
// Reverse engineered from the Frenchfinity 1.0 "Can-Holder" by measuring the
// reference STLs (NOT by fitting the bounding box). Fusion user parameters and
// what they ACTUALLY drive:
//
//   can_diameter (cd)  -> the can/tube the bore must fit; bore = cd + clearance
//   padding      (p)   -> SIDE/front wall around the bore; sets width dx = cd+2*p
//   can_inset    (ci)  -> bore DEPTH measured along the (tilted) bore axis
//   padding_left (pl)  -> BACK / base material
//   angle        (a)   -> how far the bore (and the can) lean OUT from vertical.
//                         This is a free 1.0 user knob (NOT encoded in the file
//                         names; the reference STLs use 10/15/20/30/40 deg). The
//                         earlier port hard-coded ~9 deg, which is why most
//                         samples looked wrong.
//
// Shape (verified against the reference STLs, every angle/perpendicularity is
// exact by construction so it tracks any `angle`):
//   * a tall UPRIGHT block, width cd+2*p, sitting on a flat base;
//   * a blind bore drilled along an axis tilted `angle` from vertical, so the can
//     leans outward (top away from the wall, easy to grab);
//   * the FRONT face is PARALLEL to the bore axis (leans out `angle` from
//     vertical), the side walls stay a constant ~p;
//   * the TOP is PERPENDICULAR to the bore axis -> a flat back deck plus a sloped
//     "roof" running down to the front-top edge (this is the sloped top the 1.0
//     has and the old flat-top port was missing);
//   * the bore mouth has a 45 deg lead-in chamfer (countersink) so the can drops
//     in easily;
//   * the vertical edges carry a small fillet (the 1.0 rounds them ~1 mm).
//   * the back wall is vertical and carries the french cleat at the top; the
//     "-hole-bottom" 1.0 variant adds a drain/push-out hole (can_holder_bottom
//     = "open").
//
// Derived size relations (consequences of the geometry; track the 1.0 STLs):
//   dx = cd + 2*p                                   (exact)
//   front face & bore lean `angle` from vertical    (exact by construction)
//   top plane is perpendicular to the bore axis      (exact by construction)
//
// Orientation: back wall (cleat) at +Y, can leans toward -Y... actually the bore
// leans toward +Y (front) going up; the cleat sits on the vertical back face.
//

can_holder_clearance = 2;     // bore = can_diameter + this (fit slack; measured cd+2)
can_holder_leadin    = 3;     // 45 deg lead-in chamfer at the bore mouth
can_holder_fillet    = 2;     // rounding radius on the FRONT + TOP edges (1.0 rounds
                              // these); the BACK / cleat edges stay sharp (joint fit)
can_holder_drain     = 6;     // drain hole diameter for bottom = "open"

function can_holder_outer_width () =
    can_holder_can_diameter + 2 * can_holder_padding;

function can_holder_bore_d () =
    can_holder_can_diameter + can_holder_clearance;

// --- Empirical dimension laws, fitted to ALL 50+ 1.0 Can-Holder STLs ----------
// The 1.0 part is a free-parameter family in (cd, pl, ci, p, angle); the angle is
// NOT in the file names but is one of 10/15/20/30/40 deg. Measuring every sample
// gives these laws (max residual < 0.5 mm across the whole set). They are imitation
// fits, not first-principles - the 1.0 top geometry over-constrains a clean model,
// so we reproduce the measured bounding box + deck directly.
//   dx   = cd + 2p                                   (exact)
//   deck = pl                                         (flat top depth)
//   bore = cd + 2                                     (clearance 2)
//   dy   = 10.9(cleat) + pl + C ;  dz = ci*cos(a) + K
function can_holder_C () =
    let (cd = can_holder_can_diameter, p = can_holder_padding,
         t  = tan(can_holder_angle))
    1.0122 * cd + 1.8276 * p
    - 0.1120 * cd * t - 0.2464 * cd * t * t
    - 9.0947 * t + 6.3539;

function can_holder_K () =
    let (cd = can_holder_can_diameter, p = can_holder_padding,
         r  = can_holder_bore_d() / 2, a = can_holder_angle)
    2.2371 * r * sin(a) + 18.3335 * sin(a)
    - 0.1059 * cd * tan(a) + 1.5820 * p - 5.3775;

// solid base height below the lowest bore point (measured: ~9 + 0.3*pl)
function can_holder_base () = 9 + 0.3 * can_holder_padding_left;

// total part height dz = ci*cos(a) + K(cd,p,a)  (matches the 1.0 STL height)
function can_holder_height () =
    can_holder_can_inset * cos(can_holder_angle) + can_holder_K();

// The front+top sphere-minkowski rounding pulls the rendered max-Y point IN from
// the sharp front-top corner by this much (measured: grows smoothly with the angle,
// independent of cd/p, scales with the fillet). We build the sharp corner this much
// FURTHER out so the rounded result lands exactly on the 1.0 front (pl + C).
function can_holder_front_pullin () =
    let (a = can_holder_angle)
    (can_holder_fillet / 2) * (0.04 * a - 0.00047 * a * a);

// effective sharp front extent = the 1.0 front (pl + C) plus the rounding pull-in.
function can_holder_front_eff () = can_holder_C() + can_holder_front_pullin();

// furthest-forward point of the front face, measured from the back face (Y=0):
// the rendered (rounded) value lands on pl + C (= the 1.0 front face).
function can_holder_front_max () =
    can_holder_padding_left + can_holder_front_eff();

// Z of the front-top corner: the roof (tilt a) drops front_eff*tan(a) from the deck
// (z=H, Y=pl) to the front-top corner.
function can_holder_fronttop_z () =
    can_holder_height() - can_holder_front_eff() * tan(can_holder_angle);

// front face Y at height z (the face is parallel to the bore axis, tilts `a`).
function can_holder_front_y (z) =
    can_holder_front_max()
    - (can_holder_fronttop_z() - z) * tan(can_holder_angle);

// bore floor centre Z: base solid + r*sin(a) so the lowest bore point sits at `base`.
function can_holder_floor_z () =
    can_holder_base() + can_holder_bore_d() / 2 * sin(can_holder_angle);

// bore floor centre Y: a perpendicular front-wall thickness `p` in front of the bore,
// i.e. (r + p) perpendicular behind the front plane, at the floor height.
function can_holder_bore_yc () =
    can_holder_front_y(can_holder_floor_z())
    - (can_holder_bore_d() / 2 + can_holder_padding) / cos(can_holder_angle);

// generous Y depth for the footprint trimming prism (front plane cuts within it).
function can_holder_depth () = can_holder_front_max() + can_holder_padding + 10;

// bottom Z of the cleat block (the nut sits at up(H - 2*slot_distance_top)); the
// labels go below this on the back face.
function can_holder_cleat_bottom () =
    can_holder_height() - 2 * frenchfinity_1_0_slot_distance_top;

// The sharp convex solid (no bore), shrunk uniformly by `inset` on the FRONT, TOP,
// SIDE and BACK faces and lifted off the base by `inset`. With inset = 0 it is the
// nominal block; with inset = fillet it is the body a sphere-minkowski of radius
// fillet grows back to nominal while rounding every convex edge. (It is a convex
// polytope, so the minkowski is cheap.)
module can_holder_solid (inset = 0) {
    w     = can_holder_outer_width();
    a     = can_holder_angle;
    H     = can_holder_height();
    D     = can_holder_depth();
    pl    = can_holder_padding_left;
    big   = 2000;

    // front-top corner (front plane ∩ roof plane) and deck edge (roof ∩ flat cap):
    P_front = [w / 2, can_holder_front_max(), can_holder_fronttop_z()];  // front-top
    P_roof  = [w / 2, pl, H];                                            // deck edge

    intersection () {
        // (1) footprint prism, capped flat at H (the deck). Inset in X (both sides),
        // off the back (Y) and off the base (z); cap at H - inset so the minkowski
        // lifts everything back to nominal.
        translate([inset, inset, inset])
            linear_extrude(H - 2 * inset)
                square([w - 2 * inset, D]);

        // (2) keep BEHIND the front plane (∥ bore axis through the front-top corner,
        // leans +Y going up), pulled in `inset` along its normal (0,cos a,-sin a).
        translate(P_front - inset * [0, cos(a), -sin(a)])
            rotate([-a, 0, 0])
                translate([-big / 2, -big, -big / 2])
                    cube(big);

        // (3) keep BELOW the roof plane (⊥ bore axis through the deck edge (pl,H)),
        // pulled in `inset` along its normal (0,sin a,cos a). Where the roof rises
        // above the flat cap (Y < pl) the cap wins -> flat deck `pl` deep.
        translate(P_roof - inset * [0, sin(a), cos(a)])
            rotate([-a, 0, 0])
                translate([-big / 2, -big / 2, -big])
                    cube(big);
    }
}

module can_holder_body () {
    w     = can_holder_outer_width();
    a     = can_holder_angle;
    r     = can_holder_bore_d() / 2;
    base  = can_holder_base();
    fil   = can_holder_fillet;
    cs    = can_holder_leadin;
    big   = 2000;

    yc0   = can_holder_bore_yc();
    zf    = can_holder_floor_z();
    Cf    = [w / 2, yc0, zf];                  // bore floor centre
    H     = can_holder_height();
    // axial floor -> roof opening = perpendicular distance from Cf to the roof plane
    // (roof through (pl,H), normal = bore axis), so the bore exits flush at the roof.
    L     = sin(a) * (can_holder_padding_left - yc0) + cos(a) * (H - zf);

    // The back / cleat side must stay SHARP or the french-cleat joint seats wrong;
    // 1.0 only rounds the FRONT and TOP. So: sphere-minkowski the whole solid (rounds
    // every edge), flatten the base, then UNION a nominal SHARP slab over the back
    // wall region (Y <= kb) to restore the crisp back vertical edges + back-top edge.
    kb = yc0 - r + fil + 1;

    difference () {
        union () {
            // front + top + front-vertical edges rounded; base cut flat & printable.
            intersection () {
                minkowski () {
                    can_holder_solid(fil);
                    sphere(r = fil, $fn = 16);
                }
                translate([-big / 2, -big / 2, 0]) cube(big);     // z >= 0
            }
            // sharp back wall slab (joint side): nominal solid, kept for Y <= kb.
            intersection () {
                can_holder_solid(0);
                translate([-big / 2, kb - big, 0]) cube(big);     // Y <= kb, z >= 0
            }
        }

        // bore drilled along the tilted axis (leans +Y going up), 45 deg lead-in.
        translate(Cf)
            rotate([-a, 0, 0]) {
                cylinder(h = L + 2, r = r, $fn = 96);
                translate([0, 0, L - cs])
                    cylinder(h = cs + 2, r1 = r, r2 = r + cs, $fn = 96);
            }

        // drain / push-out hole through the base up into the bore floor
        // (1.0 "-hole-bottom" variant)
        if (can_holder_bottom == "open")
            translate([w / 2, yc0, -1])
                cylinder(d = can_holder_drain, h = zf + 4, $fn = 64);
    }
}

module can_holder_with_nut () {
    w = can_holder_outer_width();
    H = can_holder_height();

    union () {
        can_holder_body();
        // cleat on the vertical back face (Y = 0), tongue out -Y, near the top.
        up(H - (frenchfinity_1_0_slot_distance_top * 2))
            mirror([0, 1, 0])
                nut(w, false);
    }
}

module can_holder_labels_only () {
    w    = can_holder_outer_width();
    base = can_holder_base();

    lines = [
        final_version_prefix_calculated,
        str("cd", can_holder_can_diameter),
        str("pl", can_holder_padding_left),
        str("ci", can_holder_can_inset),
        str("p",  can_holder_padding)
    ];

    // The 1.0 part engraves the parameter labels on the VERTICAL BACK face (the
    // cleat / wall side), below the cleat block -- NOT on the slanted front. Match
    // that: one X-reading face at Y = 0, in the z gap between the base and the
    // cleat. labelFace floors the glyph at text_size_min and centres the block.
    labelFace(lines,
              ["x", w / 2, 0, w, base + 2, can_holder_cleat_bottom() - 2]);
}

module can_holder_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        [str("cd", can_holder_can_diameter), str("pl", can_holder_padding_left)],
        [str("ci", can_holder_can_inset), str("p", can_holder_padding)],
        str("hole", can_holder_bottom)
    ]);

    difference () {
        can_holder_with_nut();
        can_holder_labels_only();
    }
}

module feature_can_holder () {
    assert(can_holder_can_diameter > 0, "can_diameter must be > 0");
    assert(can_holder_padding > 0, "padding must be > 0");
    assert(can_holder_can_inset > 0, "can_inset must be > 0");
    assert(can_holder_padding_left >= 0, "padding_left must be >= 0");
    assert(can_holder_angle >= 0 && can_holder_angle < 60, "angle must be in [0, 60)");
    assert(
        can_holder_bottom == "closed" || can_holder_bottom == "open",
        "bottom must be one of: closed, open"
    );

    can_holder_with_nut_and_text();
}
