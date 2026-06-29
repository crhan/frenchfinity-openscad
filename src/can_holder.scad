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

can_holder_clearance = 2;     // bore = can_diameter + this (fit slack)
can_holder_rim       = 4;     // solid lip (along the bore axis) above the opening
can_holder_leadin    = 3;     // 45 deg lead-in chamfer at the bore mouth
can_holder_fillet    = 1.2;   // rounding on the vertical edges
can_holder_drain     = 6;     // drain hole diameter for bottom = "open"

function can_holder_outer_width () =
    can_holder_can_diameter + 2 * can_holder_padding;

function can_holder_bore_d () =
    can_holder_can_diameter + can_holder_clearance;

// solid base height below the bore floor (measured: ~9 + 0.3*pl)
function can_holder_base () = 9 + 0.3 * can_holder_padding_left;

// Vertical height of the flat top cap. The bore opening's high edge sits at
// base + ci*cos(a) + r*sin(a); the cap clears it by `rim` so a solid lip remains.
function can_holder_height () =
    let (a = can_holder_angle, r = can_holder_bore_d() / 2)
    can_holder_base()
    + can_holder_can_inset * cos(a)
    + r * sin(a)
    + can_holder_rim;

// Back wall thickness at the bore floor (the bore sits this far in front of the
// vertical back face). Small at the floor; the lean adds material higher up.
function can_holder_back_wall () = 3 + 0.12 * can_holder_padding_left;

// bore floor centre Y (back wall + bore radius)
function can_holder_bore_yc () =
    can_holder_back_wall() + can_holder_bore_d() / 2;

// total Y footprint (front-top reaches the furthest): back wall + bore lean + bore
// + front wall, generously rounded up for the trimming prism.
function can_holder_depth () =
    can_holder_bore_yc()
    + can_holder_can_inset * sin(can_holder_angle)
    + can_holder_bore_d() / 2
    + can_holder_padding + 6;

// bottom Z of the cleat block (the nut sits at up(H - 2*slot_distance_top)); the
// labels go below this on the back face.
function can_holder_cleat_bottom () =
    can_holder_height() - 2 * frenchfinity_1_0_slot_distance_top;

// The sharp solid (no bore). Built `fil` undersize on the faces that grow under
// the minkowski rounding below, so the rounded result lands on nominal sizes:
//   width  cd+2p   (footprint built w-2*fil)
//   front wall p   (front plane pulled in by fil)
// The vertical back / flat base are left as-is (the +fil there is harmless: the
// cleat overlaps the back, the base just gains a hair of height).
module can_holder_solid () {
    w     = can_holder_outer_width();
    a     = can_holder_angle;
    r     = can_holder_bore_d() / 2;
    base  = can_holder_base();
    rim   = can_holder_rim;
    ci    = can_holder_can_inset;
    H     = can_holder_height();
    D     = can_holder_depth();
    fil   = can_holder_fillet;
    big   = 2000;

    yc0   = can_holder_bore_yc();                 // bore floor centre Y
    Cf    = [w / 2, yc0, base];                   // bore floor centre point
    L     = ci + rim;                             // axial floor -> top plane

    intersection () {
        // (1) footprint prism (sharp; minkowski rounds the vertical edges). Built
        // fil narrower in X so the rounded part is exactly w wide.
        translate([fil, fil, 0])
            linear_extrude(H)
                square([w - 2 * fil, D]);

        // (2) keep BEHIND the front plane (parallel to the bore axis). Plane
        // normal (0,cos a,-sin a) -> face leans OUT (+Y) going up. Offset pulled
        // in by fil so the rounded front wall is exactly p.
        translate(Cf + (r + can_holder_padding - fil) * [0, cos(a), -sin(a)])
            rotate([-a, 0, 0])
                translate([-big / 2, -big, -big / 2])
                    cube(big);

        // (3) keep BELOW the top plane (perpendicular to the bore axis at axial L).
        translate(Cf + L * [0, sin(a), cos(a)])
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
    rim   = can_holder_rim;
    ci    = can_holder_can_inset;
    fil   = can_holder_fillet;
    cs    = can_holder_leadin;

    yc0   = can_holder_bore_yc();
    Cf    = [w / 2, yc0, base];
    L     = ci + rim;

    difference () {
        // round the vertical edges (the 1.0 fillets) with a vertical-cylinder
        // minkowski: rounds the 4 upright corners, keeps the base flat & printable.
        minkowski () {
            can_holder_solid();
            cylinder(r = fil, h = 0.01, $fn = 24);
        }

        // bore drilled along the tilted axis (leans +Y going up), with a 45 deg
        // lead-in at the mouth.
        translate(Cf)
            rotate([-a, 0, 0]) {
                cylinder(h = L + 2, r = r, $fn = 96);
                translate([0, 0, L - cs])
                    cylinder(h = cs + 2, r1 = r, r2 = r + cs, $fn = 96);
            }

        // drain / push-out hole through the base (1.0 "-hole-bottom" variant)
        if (can_holder_bottom == "open")
            translate([w / 2, yc0, -1])
                cylinder(d = can_holder_drain, h = base + 4, $fn = 64);
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
