//
// Gridfinity adapter
//
// Reverse engineered from the Frenchfinity 1.0 "Gridfinity-Frenchfinity Adapter"
// (4 reference STLs). Functional + key-dimension port. Fusion user parameters:
//
//   grid_columns -> gridfinity cells across the width (X)
//   grid_rows    -> gridfinity cells up the tilted bed
//   angle        -> bed tilt knob (the bed leans back ~2*angle from horizontal)
//
// Verified against the 4 STLs (tools/stl_analyze.py, R^2 = 1.0):
//   dx = 42 * grid_columns                  (exact, 42mm gridfinity pitch)
//   dy = 42*cos(20)*rows + 14.10 = 39.467*rows + 14.10   (cleat + margin)
//   dz = 42*sin(20)*rows + 8.83  = 14.365*rows + 8.83    (base/front-edge)
// All four samples are angle=10 and measure a 20deg bed tilt, so the bed tilt is
// 2*angle (single-angle inference). The standard gridfinity 42mm baseplate cells
// sit on the slanted top; the wedge below hangs on the cleat.
//
// Cleat at +Y (back), like the other holders. The gridfinity socket uses the
// standard chamfered profile so real gridfinity bins seat in it.
//

gridfinity_adapter_pitch    = 42;    // gridfinity grid pitch
gridfinity_adapter_bed      = 5;     // baseplate thickness (perpendicular to bed)
gridfinity_adapter_corner   = 3.75;  // gridfinity outer corner radius
gridfinity_adapter_clear    = 0.5;   // total X/Y clearance per cell (bin fit)

// Standard gridfinity baseplate socket profile (heights, from the top opening
// down): a 2.15 mm 45deg lead-in chamfer, 1.8 mm vertical, 0.8 mm 45deg chamfer
// -- so a real gridfinity bin foot clips in. Total 4.75 mm.
gridfinity_adapter_lip_top  = 2.15;
gridfinity_adapter_lip_mid  = 1.80;
gridfinity_adapter_lip_bot  = 0.80;

function gridfinity_adapter_tilt () = 2 * gridfinity_adapter_angle;

// 2D rounded square of half-size `half`.
module gf_rsq (half) {
    r = gridfinity_adapter_corner;
    offset(r) square([2 * (half - r), 2 * (half - r)], center = true);
}

// one thin rounded-square layer at height z, half-size `half`.
module gf_layer (z, half) {
    translate([0, 0, z]) linear_extrude(0.02) gf_rsq(half);
}

// One gridfinity cell socket, subtractive, cut downward from z = 0 (bed top),
// using the standard 3-step baseplate profile so real bins seat/clip.
module gf_socket () {
    h0  = gridfinity_adapter_pitch / 2 - gridfinity_adapter_clear / 2;  // ~20.75
    ct  = gridfinity_adapter_lip_top;
    cm  = gridfinity_adapter_lip_mid;
    cb  = gridfinity_adapter_lip_bot;
    bed = gridfinity_adapter_bed;
    h1  = h0 - ct;          // half after the top chamfer
    h2  = h1 - cb;          // half after the bottom chamfer
    z1  = -ct;              // bottom of the top chamfer
    z2  = z1 - cm;          // bottom of the straight section
    z3  = z2 - cb;          // socket floor

    union () {
        hull () { gf_layer(0.01, h0); gf_layer(z1, h1); }   // top lead-in chamfer
        hull () { gf_layer(z1, h1);   gf_layer(z2, h1); }   // vertical
        hull () { gf_layer(z2, h1);   gf_layer(z3, h2); }   // bottom chamfer
        // socket floor sits at z3; a thin solid floor (bed - 4.75) remains below.
    }
}

// Flat gridfinity baseplate slab (cols x rows cells), sockets cut from the top.
module gf_bed_flat () {
    p    = gridfinity_adapter_pitch;
    cols = gridfinity_adapter_grid_columns;
    rows = gridfinity_adapter_grid_rows;
    bed  = gridfinity_adapter_bed;

    difference () {
        cube([p * cols, p * rows, bed]);
        for (c = [0 : cols - 1])
            for (r = [0 : rows - 1])
                translate([p * (c + 0.5), p * (r + 0.5), bed])
                    gf_socket();
    }
}

module gridfinity_adapter_solid () {
    p    = gridfinity_adapter_pitch;
    cols = gridfinity_adapter_grid_columns;
    rows = gridfinity_adapter_grid_rows;
    bed  = gridfinity_adapter_bed;
    tilt = gridfinity_adapter_tilt();
    bw   = p * cols;
    bl   = p * rows;
    foot = bl * cos(tilt);          // bed Y footprint
    rise = bl * sin(tilt);          // bed Z rise

    union () {
        // the tilted baseplate, low edge at the front (Y=0), high edge at the back
        translate([0, 0, 0])
            rotate([tilt, 0, 0])
                gf_bed_flat();
        // solid wedge filling under the bed down to the floor (hull of the
        // tilted slab's underside with its floor footprint)
        hull () {
            rotate([tilt, 0, 0])
                translate([0, 0, -0.01]) cube([bw, bl, 0.01]);
            cube([bw, foot, 0.01]);
        }
        // small back wall so the cleat has a flat vertical face
        translate([0, foot - 0.01, 0]) cube([bw, 0.01 + 4, rise + bed]);
    }
}

module gridfinity_adapter_with_nut () {
    p    = gridfinity_adapter_pitch;
    cols = gridfinity_adapter_grid_columns;
    rows = gridfinity_adapter_grid_rows;
    bed  = gridfinity_adapter_bed;
    tilt = gridfinity_adapter_tilt();
    bw   = p * cols;
    bl   = p * rows;
    foot = bl * cos(tilt);
    rise = bl * sin(tilt);

    union () {
        gridfinity_adapter_solid();
        // cleat on the back wall, near the top
        up(rise + bed - (frenchfinity_1_0_slot_distance_top * 2))
            back(foot + 4)
                nut(bw, false);
    }
}

module gridfinity_adapter_labels_only () {
    p    = gridfinity_adapter_pitch;
    cols = gridfinity_adapter_grid_columns;
    rows = gridfinity_adapter_grid_rows;
    bed  = gridfinity_adapter_bed;
    tilt = gridfinity_adapter_tilt();
    bw   = p * cols;
    bl   = p * rows;
    foot = bl * cos(tilt);
    rise = bl * sin(tilt);

    // v / gr / gc / a on the back wall (X-read), floored, spilling to the side.
    labelLines(
        [
            final_version_prefix_calculated,
            str("gr", gridfinity_adapter_grid_rows),
            str("gc", gridfinity_adapter_grid_columns),
            str("a",  gridfinity_adapter_angle)
        ],
        ["x", bw / 2, foot + 4, bw, 2, rise + bed - 14],
        ["x", bw / 2, foot,     bw, 2, rise + bed - 14]
    );
}

module gridfinity_adapter_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        [str("gr", gridfinity_adapter_grid_rows), str("gc", gridfinity_adapter_grid_columns)],
        str("a", gridfinity_adapter_angle)
    ]);

    difference () {
        gridfinity_adapter_with_nut();
        gridfinity_adapter_labels_only();
    }
}

module feature_gridfinity_adapter () {
    assert(gridfinity_adapter_grid_columns >= 1, "grid_columns must be >= 1");
    assert(gridfinity_adapter_grid_rows >= 1, "grid_rows must be >= 1");
    assert(gridfinity_adapter_angle > 0 && gridfinity_adapter_angle < 45,
           "angle must be between 0 and 45");

    gridfinity_adapter_with_nut_and_text();
}
