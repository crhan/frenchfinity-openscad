//
// Tape holder
//
// Reverse engineered from the Frenchfinity 1.0 "Tape Holder" (13 STLs).
// Functional + key-dimension port. Fusion user parameters:
//
//   tape_width       (tw)   -> roll width; sets the slot: dx = tw + 20
//   max_tape_diameter(matd) -> full roll OD; sets the cradle curve and depth
//   min_tape_diameter(mitd) -> empty roll OD; sets the body height
//   rest_diameter    (rd)   -> a small relief at the cradle bottom (rounding)
//
// Verified against the 13 STLs (tools/stl_analyze.py):
//   dx = tape_width + 20            (R^2 = 1.0, exact: roll slot + 10mm walls)
//   dy = max_tape_diameter + 20.88  (R^2 = 1.0, fits the full roll OD + cleat)
//   dz ~= 0.69*min_tape_diameter + 16.4  (R^2 = 0.92)
//
// Shape: a block with a concave cylindrical scoop (radius ~matd/2) cut into the
// top, open toward the front, that the tape roll rests in; a back wall carries
// the cleat. The roll slot is tw wide between two 10mm side walls. Cleat at +Y.
//

tape_holder_wall = 10;   // side wall each side of the roll (X): dx = tw + 20
tape_holder_back = 10;   // back wall depth behind the roll (Y) before the cleat

function tape_holder_outer_width () =
    tape_holder_tape_width + 2 * tape_holder_wall;

function tape_holder_body_depth () =
    tape_holder_max_tape_diameter + tape_holder_back;

function tape_holder_outer_height () =
    0.694 * tape_holder_min_tape_diameter + 16.4;

module tape_holder_body () {
    w     = tape_holder_outer_width();
    d     = tape_holder_body_depth();
    h     = tape_holder_outer_height();
    tw    = tape_holder_tape_width;
    wall  = tape_holder_wall;
    matd  = tape_holder_max_tape_diameter;
    r     = matd / 2;

    difference () {
        cube([w, d, h]);
        // concave scoop the roll sits in: a cylinder (axis X) across the roll
        // slot, centred toward the front so the back wall stays tall and the
        // front is scooped open for dispensing. Clamp the radius to the body.
        rr = min(r, h - 4);
        translate([wall, d - tape_holder_back - rr, h + rr * 0.15])
            rotate([0, 90, 0])
                cylinder(r = rr, h = tw, $fn = 128);
        // open the top above the scoop so the roll drops in
        translate([wall, -1, h])
            cube([tw, d + 2, rr + 2]);
    }
}

module tape_holder_with_nut () {
    w = tape_holder_outer_width();
    d = tape_holder_body_depth();
    h = tape_holder_outer_height();

    union () {
        tape_holder_body();
        up(h - (frenchfinity_1_0_slot_distance_top * 2))
            back(d)
                nut(w, false);
    }
}

module tape_holder_labels_only () {
    w = tape_holder_outer_width();
    d = tape_holder_body_depth();
    h = tape_holder_outer_height();

    // 1.0 stacked v / tw / matd / mitd / rd on the front; engrave on the front
    // face (X-read), floored, spilling to the back face.
    labelLines(
        [
            final_version_prefix_calculated,
            str("tw",   tape_holder_tape_width),
            str("matd", tape_holder_max_tape_diameter),
            str("mitd", tape_holder_min_tape_diameter),
            str("rd",   tape_holder_rest_diameter)
        ],
        ["x", w / 2, 0, w, 2, h - 2],
        ["x", w / 2, d, w, 2, h - 16]
    );
}

module tape_holder_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        [str("tw", tape_holder_tape_width), str("matd", tape_holder_max_tape_diameter)],
        [str("mitd", tape_holder_min_tape_diameter), str("rd", tape_holder_rest_diameter)]
    ]);

    difference () {
        tape_holder_with_nut();
        tape_holder_labels_only();
    }
}

module feature_tape_holder () {
    assert(tape_holder_tape_width > 0, "tape_width must be > 0");
    assert(tape_holder_max_tape_diameter > 0, "max_tape_diameter must be > 0");
    assert(tape_holder_min_tape_diameter > 0, "min_tape_diameter must be > 0");
    assert(
        tape_holder_min_tape_diameter <= tape_holder_max_tape_diameter,
        "min_tape_diameter must be <= max_tape_diameter"
    );

    tape_holder_with_nut_and_text();
}
