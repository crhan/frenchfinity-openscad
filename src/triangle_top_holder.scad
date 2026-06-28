//
// Triangle Top Holder
//
// Reverse engineered from the Frenchfinity 1.0 "Triangle-Top-Holder" (loose
// f3z, XRef container; 2 STLs exported by the user). Functional + key-dimension
// port. Fusion user parameters:
//
//   tool_width      (tw) -> width of the tool slot (X)
//   tool_depth      (td) -> depth of the tool slot (Y)
//   holder_height   (hh) -> overall body height (Z)
//   triangle_height (th) -> height of the bottom-back triangular foot
//
// Verified against the 2 STLs (tools/stl_analyze.py), both exact:
//   dx = tool_width  + 12            (6mm wall each side of the slot)
//   dy = tool_depth  + 20.88         (slot depth + back + cleat)
//   dz = holder_height + 5
//
// Shape (verified against the 1.0 STL cross sections + iso/side, NOT the bbox --
// the earlier port made a thin front plate with a full-depth top CUP and a huge
// tapering foot, leaving the middle hollow; the 1.0 is a SOLID plate): a solid
// plate (depth td + walls) the full height, with the tool slot (tw x td) cut into
// the TOP, the french cleat on the back near the top, and a small triangular
// gusset on the bottom-back (height th, the "triangle") that braces against the
// wall below the cleat. Cleat at +Y (back).
//

triangle_top_holder_xwall      = 6;   // X wall each side of the slot: dx = tw + 12
triangle_top_holder_frontwall  = 5;   // plate in front of the slot (Y)
triangle_top_holder_backwall   = 5;   // plate behind the slot (Y); td + 5 + 5 = td + 10
triangle_top_holder_gusset     = 8;   // bottom-back brace depth (Y) at z = 0

function triangle_top_holder_outer_width () =
    triangle_top_holder_tool_width + 2 * triangle_top_holder_xwall;

function triangle_top_holder_outer_height () =
    triangle_top_holder_holder_height + 5;

// Body depth front->back (excludes the cleat tongue): td + frontwall + backwall.
function triangle_top_holder_body_depth () =
    triangle_top_holder_tool_depth
    + triangle_top_holder_frontwall
    + triangle_top_holder_backwall;

// Tool slot depth (Z from the top): the tool's top drops into the slot.
function triangle_top_holder_slot_depth () =
    min(triangle_top_holder_outer_height() - 12,
        triangle_top_holder_tool_depth + 18);

module triangle_top_holder_body () {
    w     = triangle_top_holder_outer_width();
    hz    = triangle_top_holder_outer_height();
    d     = triangle_top_holder_body_depth();
    tw    = triangle_top_holder_tool_width;
    td    = triangle_top_holder_tool_depth;
    th    = triangle_top_holder_triangle_height;
    xw    = triangle_top_holder_xwall;
    fw    = triangle_top_holder_frontwall;
    g     = triangle_top_holder_gusset;
    sd    = triangle_top_holder_slot_depth();

    union () {
        // SOLID plate, full depth, full height
        difference () {
            cube([w, d, hz]);
            // tool slot cut into the top: tw wide, td deep, open at the top
            translate([xw, fw, hz - sd])
                cube([tw, td, sd + 1]);
        }
        // bottom-back triangular gusset (height th): braces the wall below the
        // cleat. Right triangle in Y-Z: deepest (Y = d + g) at z = 0, back to the
        // plate (Y = d) at z = th. Stays within the cleat's Y, so dy is unchanged.
        if (th > 0)
            rotate([90, 0, 90])
                linear_extrude(w)
                    polygon([[d, 0], [d + g, 0], [d, min(th, hz)]]);
    }
}

module triangle_top_holder_with_nut () {
    w  = triangle_top_holder_outer_width();
    hz = triangle_top_holder_outer_height();
    d  = triangle_top_holder_body_depth();

    union () {
        triangle_top_holder_body();
        // cleat behind the cradle (its back face is at Y = d), tongue out +Y
        up(hz - (frenchfinity_1_0_slot_distance_top * 2))
            back(d)
                nut(w, false);
    }
}

module triangle_top_holder_labels_only () {
    w  = triangle_top_holder_outer_width();
    hz = triangle_top_holder_outer_height();
    d  = triangle_top_holder_body_depth();

    // 1.0 stacks v / tw / hh / th / td on the front; engrave on the front face
    // (X-read), floored, spilling to the back face.
    labelLines(
        [
            final_version_prefix_calculated,
            str("tw", triangle_top_holder_tool_width),
            str("hh", triangle_top_holder_holder_height),
            str("th", triangle_top_holder_triangle_height),
            str("td", triangle_top_holder_tool_depth)
        ],
        ["x", w / 2, 0, w, 2, hz - 2],
        ["x", w / 2, d, w, 2, hz - 2]
    );
}

module triangle_top_holder_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        [str("tw", triangle_top_holder_tool_width), str("hh", triangle_top_holder_holder_height)],
        [str("th", triangle_top_holder_triangle_height), str("td", triangle_top_holder_tool_depth)]
    ]);

    difference () {
        triangle_top_holder_with_nut();
        triangle_top_holder_labels_only();
    }
}

module feature_triangle_top_holder () {
    assert(triangle_top_holder_tool_width > 0, "tool_width must be > 0");
    assert(triangle_top_holder_tool_depth > 0, "tool_depth must be > 0");
    assert(triangle_top_holder_holder_height > 0, "holder_height must be > 0");
    assert(triangle_top_holder_triangle_height >= 0, "triangle_height must be >= 0");

    triangle_top_holder_with_nut_and_text();
}
