//
// Bit / drill holder
//
// Reverse engineered from the Frenchfinity 1.0 "Bit-Holder v68.f3d" (85 STLs).
// Functional + key-dimension port. Fusion user parameters:
//
//   rows         (r)   -> rows of bit holes (stacked up the slant)
//   columns      (c)   -> columns of bit holes (across the width)
//   hole_diameter(hd)  -> bit hole diameter
//   hole_padding (hp)  -> wall around each hole; columns SHARE their inner wall
//   angle        (a)   -> hole tilt from vertical (all 1.0 samples a=30)
//   height       (h)   -> bit hole depth / body height driver
//
// Verified against the 85 STLs (tools/stl_analyze.py) + the 1.0 cross sections:
//   dx = columns*hd + (columns+1)*hp   (exact: holes pitched hd+hp across X,
//                                        sharing the inner wall, hp on each edge)
//   rows stack UP the slab (pitch hd+hp), so dz grows and dy stays compact.
//
// Shape (the earlier port was an upright block whose rows spread OUT in Y into a
// long cantilever; the 1.0 stacks the rows UP a leaning SLAB so it stays a
// compact wall panel): a flat slab carries the r x c hole grid drilled
// perpendicular to its face, then leans `angle` from vertical so the bits project
// out and up. A vertical back plate carries the french cleat. Columns share inner
// walls (dx exact); rows are pitched hd+hp up the slant. Cleat at +Y (back).
//

bit_holder_plate     = 6;    // vertical back plate thickness (Y), carries the cleat
bit_holder_floor     = 6;    // solid below the bottom of each hole (slab back)

// Pitch (centre-to-centre) of holes in both axes. Columns AND rows share their
// inner wall, so the pitch is hd + hp (not the full cell) with hp on each edge.
function bit_holder_pitch () =
    bit_holder_hole_diameter + bit_holder_hole_padding;

function bit_holder_outer_width () =
    bit_holder_columns * bit_holder_hole_diameter
    + (bit_holder_columns + 1) * bit_holder_hole_padding;

// slab length along the slant (rows pitched hd+hp, hp on each end)
function bit_holder_slab_len () =
    bit_holder_rows * bit_holder_pitch () + bit_holder_hole_padding;

// slab thickness: bit hole depth + a solid floor behind it
function bit_holder_slab_thick () =
    bit_holder_height + bit_holder_floor;

// The flat slab in its own frame: hole grid drilled into the top (-Z), depth h.
module bit_holder_slab () {
    w     = bit_holder_outer_width();
    len   = bit_holder_slab_len();
    t     = bit_holder_slab_thick();
    hd    = bit_holder_hole_diameter;
    hp    = bit_holder_hole_padding;
    p     = bit_holder_pitch();

    difference () {
        cube([w, len, t]);
        // bore drilled DOWN from the top face (z = t) by `height`, leaving the
        // `floor` solid below; +1 overcut above the surface so it opens cleanly.
        for (rr = [0 : bit_holder_rows - 1])
            for (cc = [0 : bit_holder_columns - 1])
                translate([hp + hd / 2 + cc * p, hp + hd / 2 + rr * p, t - bit_holder_height])
                    cylinder(d = hd, h = bit_holder_height + 1, $fn = 48);
    }
}

module bit_holder_body () {
    w     = bit_holder_outer_width();
    plate = bit_holder_plate;
    t     = bit_holder_slab_thick();
    a     = bit_holder_angle;

    union () {
        // vertical back plate (carries the cleat at +Y = Y 0..plate)
        cube([w, plate, plate + t]);
        // leaning slab: reclined `a` from horizontal (gives the 1.0 compact panel
        // bbox), hinged at the plate front; its back edge merges into the plate.
        translate([0, plate, 0])
            rotate([a, 0, 0])
                bit_holder_slab();
    }
}

module bit_holder_with_nut () {
    w  = bit_holder_outer_width();
    h  = bit_holder_plate + bit_holder_slab_thick();

    union () {
        bit_holder_body();
        // cleat on the back plate (its outer face is at Y = 0), tongue out -Y
        up(h - (frenchfinity_1_0_slot_distance_top * 2))
            mirror([0, 1, 0])
                nut(w, false);
    }
}

module bit_holder_labels_only () {
    w  = bit_holder_outer_width();
    ph = bit_holder_plate + bit_holder_slab_thick();   // back plate height

    // v-r-c / hd-hp / a-h on the back plate face (X-read, the cleat/-Y side).
    labelLines(
        [
            str(final_version_prefix_calculated, "-r", bit_holder_rows, "-c", bit_holder_columns),
            str("hd", bit_holder_hole_diameter, "-hp", bit_holder_hole_padding),
            str("a", bit_holder_angle, "-h", bit_holder_height)
        ],
        ["x", w / 2, 0,                  w, 2, ph - 2],
        ["x", w / 2, bit_holder_plate,   w, 2, ph - 2]
    );
}

module bit_holder_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        [str("r", bit_holder_rows), str("c", bit_holder_columns)],
        [str("hd", bit_holder_hole_diameter), str("hp", bit_holder_hole_padding)],
        [str("a", bit_holder_angle), str("h", bit_holder_height)]
    ]);

    difference () {
        bit_holder_with_nut();
        bit_holder_labels_only();
    }
}

module feature_bit_holder () {
    assert(bit_holder_rows >= 1, "rows must be >= 1");
    assert(bit_holder_columns >= 1, "columns must be >= 1");
    assert(bit_holder_hole_diameter > 0, "hole_diameter must be > 0");
    assert(bit_holder_hole_padding > 0, "hole_padding must be > 0");
    assert(bit_holder_angle >= 0 && bit_holder_angle < 60, "angle must be in [0, 60)");
    assert(bit_holder_height > 0, "height must be > 0");

    bit_holder_with_nut_and_text();
}
