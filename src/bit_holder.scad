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
// Verified against the 85 STLs (tools/stl_analyze.py):
//   dx = columns*hd + (columns+1)*hp   (exact: holes pitched hd+hp across X,
//                                        sharing the inner wall, hp on each edge)
//   dz ~= 1.5*h + 10             (body height; the angled holes need a tall body)
//   dy grows with rows and the slant (trig of `angle`)
//
// Shape: a block leaning at `angle` (so the bits tilt up-and-out for easy grab),
// with an r x c grid of holes drilled into the top. A vertical back plate carries
// the french cleat. dx is exact (1.0 shares column walls); dy/dz are functional:
// 1.0 packs the rows into a leaning parallelogram, we use an upright block with
// angled holes, so multi-row dy runs larger than 1.0. Cleat at +Y (back).
//

bit_holder_plate     = 6;    // vertical back plate thickness (Y), carries the cleat
bit_holder_floor     = 6;    // solid below the deepest hole (Z)

// Row cell (Y): kept hd + 2*hp wide so the tilted hole stays inside its row.
function bit_holder_cell () =
    bit_holder_hole_diameter + 2 * bit_holder_hole_padding;

// Column pitch (X): centre-to-centre across columns. 1.0 shares the inner wall,
// so columns are pitched hd + hp (not the full cell) with hp on each outer edge.
function bit_holder_col_pitch () =
    bit_holder_hole_diameter + bit_holder_hole_padding;

function bit_holder_outer_width () =
    bit_holder_columns * bit_holder_hole_diameter
    + (bit_holder_columns + 1) * bit_holder_hole_padding;

function bit_holder_body_height () =
    1.5 * bit_holder_height + 10;

// One bit hole tilted by `angle` from vertical (the bit leans out toward -Y),
// entering the top at (x, y) and drilled `depth` deep along its axis.
module bit_holder_hole (x, y, ztop, depth, a) {
    translate([x, y, ztop])
        rotate([-a, 0, 0])              // tilt the bit toward -Y (out, away from wall)
            translate([0, 0, -depth])
                cylinder(d = bit_holder_hole_diameter, h = depth + 1, $fn = 48);
}

module bit_holder_body () {
    w     = bit_holder_outer_width();
    cell  = bit_holder_cell();
    colp  = bit_holder_col_pitch();
    hd    = bit_holder_hole_diameter;
    hp    = bit_holder_hole_padding;
    rows  = bit_holder_rows;
    cols  = bit_holder_columns;
    bh    = bit_holder_body_height();
    plate = bit_holder_plate;
    a     = bit_holder_angle;
    depth = bit_holder_height;          // bit hole depth along its axis
    // Columns share their inner wall (pitch hd+hp, hp on each edge) -> dx matches
    // 1.0 exactly. Rows are pitched by a full cell in Y so the tilted bit stays
    // inside its row. NOTE multi-row dy is approximate: 1.0 packs the rows up a
    // slant (a tighter parallelogram); we use an upright block, so dy runs larger.
    body_y = plate + rows * cell;

    difference () {
        cube([w, body_y, bh]);
        for (rr = [0 : rows - 1])
            for (cc = [0 : cols - 1])
                bit_holder_hole(
                    hp + hd / 2 + cc * colp,
                    plate + cell * (rr + 0.5),
                    bh,
                    depth,
                    a
                );
    }
}

module bit_holder_with_nut () {
    w  = bit_holder_outer_width();
    bh = bit_holder_body_height();

    union () {
        bit_holder_body();
        // cleat on the back plate (its outer face is at Y = 0), tongue out -Y
        up(bh - (frenchfinity_1_0_slot_distance_top * 2))
            mirror([0, 1, 0])
                nut(w, false);
    }
}

module bit_holder_labels_only () {
    w     = bit_holder_outer_width();
    bh    = bit_holder_body_height();
    plate = bit_holder_plate;

    // v-r-c / hd-hp / a-h on the back plate (X-read), floored, spilling to front.
    labelLines(
        [
            str(final_version_prefix_calculated, "-r", bit_holder_rows, "-c", bit_holder_columns),
            str("hd", bit_holder_hole_diameter, "-hp", bit_holder_hole_padding),
            str("a", bit_holder_angle, "-h", bit_holder_height)
        ],
        ["x", w / 2, 0,     w, 2, bh - 14],
        ["x", w / 2, plate, w, 2, bh - 14]
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
