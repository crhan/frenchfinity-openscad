//
// Round hanging holder
//
// Reverse engineered from the Frenchfinity 1.0 Fusion 360 model
// "Round-Hanging-Holder v8.f3d". Original Fusion user parameters (kept as the
// public parameters, see frenchfinity.scad):
//
//   tool_diameter      (td)  -> diameter of the round tool that is cradled
//   holder_depth       (hd)  -> length of the cradle trough along the tool axis
//   bottom_hole_width  (bhw) -> width of the slot under the trough (push-out /
//                               hang-through opening)
//   inset_depth        (id)  -> how deep the tool seats into the back wall
//
// Geometry (verified against the original STLs with tools/stl_analyze.py):
//   dz (height) = td + 10                    (R^2 = 1.0)
//   dy (depth)  = holder_depth + 20.88       (R^2 = 1.0)
//   dx (width)  = td + 10                     (the cradle is td wide + 5 mm walls)
//
// Shape (verified against the 1.0 STL cross sections + iso, NOT the bbox -- the
// earlier port added a tall FRONT wall the 1.0 does not have, which made it read
// as a deep closed box): a semicircular trough (radius td/2, axis front-to-back)
// is cut into the top so its centre sits near the top of the block (tool top ~=
// block top). The FRONT is OPEN (no front wall) -- the round tool slides in from
// the front; a single tall BACK wall carries the french cleat. A bhw-wide slot
// runs under the trough to the bottom (hang-through / push-out). The trough seats
// id into the back wall. The two short side walls (5 mm) flank the trough.
//
// NOTE on dx: across the four reference STLs dx = td + 10 holds for every export
// with bhw = 20, but the single bhw = 9 export is ~10 mm wider. With only four
// samples that interaction can't be modelled reliably, so (like the rectangular
// holder's hole-shrink artifact) we take the clean dx = td + 10 relationship.
//
// Orientation note: like the other holders the cleat sits at the +Y (back) end,
// the mirror of the 1.0 export (cleat at -Y).
//

// Fixed structural constants (absolute, from the 1.0 model).
round_hanging_holder_side_wall = 5;   // wall on each side of the trough (X): dx = td + 10
round_hanging_holder_end_wall  = 5;   // front (label) and back (cleat) walls (Y)
round_hanging_holder_base_extra = 10; // material in Z: dz = td + 10, rail top = td/2 + 5

function round_hanging_holder_outer_width() =
    round_hanging_holder_tool_diameter + (round_hanging_holder_side_wall * 2);

function round_hanging_holder_outer_height() =
    round_hanging_holder_tool_diameter + round_hanging_holder_base_extra;

function round_hanging_holder_outer_depth() =
    round_hanging_holder_holder_depth + (round_hanging_holder_end_wall * 2);

// Z of the trough centre: the tool seats high so its top reaches the block top.
function round_hanging_holder_trough_z() =
    round_hanging_holder_outer_height() - round_hanging_holder_tool_diameter / 2;

module round_hanging_holder_base () {
    w     = round_hanging_holder_outer_width();
    h     = round_hanging_holder_outer_height();
    d     = round_hanging_holder_outer_depth();
    end   = round_hanging_holder_end_wall;
    td    = round_hanging_holder_tool_diameter;
    bhw   = round_hanging_holder_bottom_hole_width;
    id    = round_hanging_holder_inset_depth;
    zc    = round_hanging_holder_trough_z();
    cx    = w / 2;
    floor = zc - td / 2;                   // trough floor Z
    back  = d - end;                       // front face of the back wall

    difference () {
        cube([w, d, h]);

        // semicircular trough (axis Y) from the OPEN front to the back wall,
        // seating id into the back wall.
        translate([cx, -1, zc])
            rotate([-90, 0, 0])
                cylinder(h = back + id + 1, r = td / 2, $fn = 128);

        // open the whole top in front of the back wall: the side walls are cut
        // down to the trough centre (leaving the tall back/cleat wall), so the
        // side profile is the 1.0 "solid base + tall back neck" L, not a box.
        translate([-1, -1, zc])
            cube([w + 2, back + 1, h - zc + 1]);

        // bhw slot under the trough, front-to-back, down to the bottom
        translate([cx - bhw / 2, -1, -1])
            cube([bhw, back + 1, floor + 1]);
    }
}

module round_hanging_holder_with_nut () {
    w = round_hanging_holder_outer_width();
    h = round_hanging_holder_outer_height();
    d = round_hanging_holder_outer_depth();

    union () {
        round_hanging_holder_base();
        // standard frenchfinity cleat tongue on the back wall, same idiom as
        // rectangular_tool_holder / box.
        up(h - (frenchfinity_1_0_slot_distance_top * 2))
            back(d)
                nut(w, false);
    }
}

// All engraving solids. The 1.0 model stacked v / td / hd / bhw / id on the
// front wall (the -Y face you see once mounted); labelLines floors the glyph at
// the 1.0 size and spills onto the back wall (below the cleat) if the front
// cannot hold all five lines at that size.
module round_hanging_holder_labels_only () {
    w  = round_hanging_holder_outer_width();
    d  = round_hanging_holder_outer_depth();
    zc = round_hanging_holder_trough_z();

    // The front is open and the back wall carries the cleat, so engrave on the
    // two side-wall outer faces (Y-read): floored, spilling left -> right.
    labelLines(
        [
            final_version_prefix_calculated,
            str("td",  round_hanging_holder_tool_diameter),
            str("hd",  round_hanging_holder_holder_depth),
            str("bhw", round_hanging_holder_bottom_hole_width),
            str("id",  round_hanging_holder_inset_depth)
        ],
        ["y", d / 2, text_depth,     d, 2, zc - 2, "left"],
        ["y", d / 2, w - text_depth, d, 2, zc - 2, "right"]
    );
}

module round_hanging_holder_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        [
            str("td",  round_hanging_holder_tool_diameter),
            str("hd",  round_hanging_holder_holder_depth)
        ],
        [
            str("bhw", round_hanging_holder_bottom_hole_width),
            str("id",  round_hanging_holder_inset_depth)
        ]
    ]);

    difference () {
        round_hanging_holder_with_nut();
        round_hanging_holder_labels_only();
    }
}

module feature_round_hanging_holder () {
    assert(round_hanging_holder_tool_diameter > 0, "tool_diameter must be > 0");
    assert(round_hanging_holder_holder_depth  > 0, "holder_depth must be > 0");
    assert(round_hanging_holder_bottom_hole_width > 0, "bottom_hole_width must be > 0");
    assert(round_hanging_holder_inset_depth   >= 0, "inset_depth must be >= 0");
    assert(
        round_hanging_holder_bottom_hole_width <= round_hanging_holder_tool_diameter,
        "bottom_hole_width must be <= tool_diameter"
    );
    assert(
        round_hanging_holder_inset_depth <= round_hanging_holder_end_wall,
        "inset_depth must be <= 5 (it cannot cut through the back wall)"
    );

    round_hanging_holder_with_nut_and_text();
}
