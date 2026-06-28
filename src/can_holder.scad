//
// Can holder  (a.k.a. can / drill / spray-can holder)
//
// Reverse engineered from the Frenchfinity 1.0 "Can-Holder v42.f3d". Functional
// + key-dimension port (not a vertex clone). Fusion user parameters:
//
//   can_diameter (cd)  -> bore the can/tube sits in
//   padding      (p)   -> wall around the bore; sets the width: dx = cd + 2p
//   can_inset    (ci)  -> how deep the can sits (length along the tilted axis)
//   padding_left (pl)  -> extra back/base material (depth/height)
//
// Verified against the 53 reference STLs (tools/stl_analyze.py):
//   dx = cd + 2p            (R^2 = 1.0, exact)
//   dz ~= 0.867*ci + ...    (0.867 ~= cos 30deg -> the bore tilts ~30deg so the
//                            can leans outward away from the wall)
//   dy ~= 0.94*cd + 0.755*pl + 1.432*p + ...  (multivariate, R^2 ~ 0.997)
// dy/dz are multivariate fits (functional sizing, not vertex-perfect); dx is exact.
//
// Shape: a vertical back plate carrying the french cleat, with an open-top
// cylindrical cup (bore = can_diameter, wall = padding) fused in front of it and
// tilted ~30deg so the can leans up-and-out. The "-hole-bottom" 1.0 export
// variant (a drain / push-out hole in the cup bottom) is folded into the
// can_holder_bottom enum.
//
// Orientation: cleat at +Y (back), like the other holders.
//

can_holder_tilt        = 30;   // bore tilt from vertical (deg); cos(30)~=0.867 = dz/ci
can_holder_plate_depth = 8;    // back plate thickness (Y)
can_holder_base        = 6;    // solid material below the cup (Z)
can_holder_drain       = 6;    // bottom drain hole diameter for bottom="open"

function can_holder_outer_width() =
    can_holder_can_diameter + 2 * can_holder_padding;

// A cylinder (outer cup or inner bore) tilted by can_holder_tilt, leaning the
// top toward -Y (out, away from the +Y wall). Its base sits at the origin.
module can_holder_tilted_cylinder (d, h) {
    rotate([can_holder_tilt, 0, 0])
        cylinder(d = d, h = h, $fn = 96);
}

module can_holder_body () {
    w     = can_holder_outer_width();
    cd    = can_holder_can_diameter;
    p     = can_holder_padding;
    ci    = can_holder_can_inset;
    pl    = can_holder_padding_left;
    plate = can_holder_plate_depth;
    base  = can_holder_base;
    cx    = w / 2;

    // total envelope (matches the regression so the bbox tracks 1.0)
    h = 0.867 * ci + 0.323 * cd + 0.268 * pl + 1.55 * p + 1.69;
    d = 0.94 * cd + 0.755 * pl + 1.432 * p + 0.07 * ci + 17.48 - 10.88; // body (cleat adds 10.88)

    // cup centre sits forward of the plate, tilted base near the bottom-front
    cup_y = d - plate - (cd / 2 + p) * 0.4;

    difference () {
        union () {
            // vertical back plate (cleat + labels)
            translate([0, d - plate, 0]) cube([w, plate, h]);
            // tilted cup, fused to the plate; flattened to the envelope below
            intersection () {
                translate([cx, cup_y, base])
                    can_holder_tilted_cylinder(cd + 2 * p, ci + cd);
                cube([w, d, h]);          // clip to the envelope (flat bottom/top/back)
            }
        }
        // the bore the can drops into (open top)
        translate([cx, cup_y, base + 2])
            can_holder_tilted_cylinder(cd, ci + cd);
        // bottom drain / push-out hole (1.0 "-hole-bottom" variant)
        if (can_holder_bottom == "open")
            translate([cx, cup_y, -1])
                cylinder(d = can_holder_drain, h = base + 4, $fn = 64);
    }
}

module can_holder_with_nut () {
    w  = can_holder_outer_width();
    cd = can_holder_can_diameter;
    p  = can_holder_padding;
    ci = can_holder_can_inset;
    pl = can_holder_padding_left;
    plate = can_holder_plate_depth;
    h = 0.867 * ci + 0.323 * cd + 0.268 * pl + 1.55 * p + 1.69;
    d = 0.94 * cd + 0.755 * pl + 1.432 * p + 0.07 * ci + 17.48 - 10.88;

    union () {
        can_holder_body();
        up(h - (frenchfinity_1_0_slot_distance_top * 2))
            back(d)
                nut(w, false);
    }
}

module can_holder_labels_only () {
    w  = can_holder_outer_width();
    cd = can_holder_can_diameter;
    p  = can_holder_padding;
    ci = can_holder_can_inset;
    pl = can_holder_padding_left;
    plate = can_holder_plate_depth;
    h = 0.867 * ci + 0.323 * cd + 0.268 * pl + 1.55 * p + 1.69;
    d = 0.94 * cd + 0.755 * pl + 1.432 * p + 0.07 * ci + 17.48 - 10.88;

    // 1.0 stacked v / cd / pl / ci / p on the back plate face; engrave on the
    // wide back face (X-read) with floor, spilling to the plate front face.
    labelLines(
        [
            final_version_prefix_calculated,
            str("cd", can_holder_can_diameter),
            str("pl", can_holder_padding_left),
            str("ci", can_holder_can_inset),
            str("p",  can_holder_padding)
        ],
        ["x", w / 2, d,         w, 2, h - 17],
        ["x", w / 2, d - plate, w, 2, h - 17]
    );
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
    assert(
        can_holder_bottom == "closed" || can_holder_bottom == "open",
        "bottom must be one of: closed, open"
    );

    can_holder_with_nut_and_text();
}
