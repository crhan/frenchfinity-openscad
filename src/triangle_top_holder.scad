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
// Shape: a tall flat front plate (carries the text). At the TOP a tool cradle -
// a pocket tw wide x td deep, open at the top, that the tool drops into, with a
// back wall behind it carrying the french cleat. At the BOTTOM a triangular
// gusset on the back (height th) - the "triangle" - that braces the plate and
// rests against the wall below the cleat (anti-tilt foot). Cleat at +Y (back).
//
// NOTE functional fidelity: the 1.0 distributes the top depth a little
// differently (thinner crown), but the tool slot (tw x td), the bottom triangle
// (th), the cleat and all three bbox dimensions match.
//

triangle_top_holder_xwall      = 6;   // X wall each side of the slot: dx = tw + 12
triangle_top_holder_frontwall  = 5;   // front plate thickness (Y)
triangle_top_holder_backwall   = 5;   // wall behind the slot (Y); td + 5 + 5 = td + 10
triangle_top_holder_floor      = 8;   // solid under the tool in the cradle (Z)

function triangle_top_holder_outer_width () =
    triangle_top_holder_tool_width + 2 * triangle_top_holder_xwall;

function triangle_top_holder_outer_height () =
    triangle_top_holder_holder_height + 5;

// Body depth front->back (excludes the cleat tongue): td + frontwall + backwall.
function triangle_top_holder_body_depth () =
    triangle_top_holder_tool_depth
    + triangle_top_holder_frontwall
    + triangle_top_holder_backwall;

// Cradle (top block) height: tall enough to seat the tool over the floor.
function triangle_top_holder_cradle_height () =
    min(triangle_top_holder_outer_height(),
        triangle_top_holder_floor + triangle_top_holder_tool_depth + 14);

module triangle_top_holder_body () {
    w     = triangle_top_holder_outer_width();
    hz    = triangle_top_holder_outer_height();
    d     = triangle_top_holder_body_depth();
    tw    = triangle_top_holder_tool_width;
    td    = triangle_top_holder_tool_depth;
    th    = triangle_top_holder_triangle_height;
    xw    = triangle_top_holder_xwall;
    fw    = triangle_top_holder_frontwall;
    floor_t = triangle_top_holder_floor;
    ch    = triangle_top_holder_cradle_height();

    union () {
        // front plate, full height
        cube([w, fw, hz]);

        // top cradle: full-depth block with a tool pocket open at the top
        difference () {
            translate([0, 0, hz - ch])
                cube([w, d, ch]);
            // tool slot: tw wide, td deep, open top, sitting on `floor_t`
            translate([xw, fw, hz - ch + floor_t])
                cube([tw, td, ch]);
        }

        // bottom-back triangular foot (height th): right triangle in Y-Z,
        // deepest (Y=d) at z=0, tapering to the front plate (Y=fw) at z=th.
        if (th > 0)
            rotate([90, 0, 90])
                linear_extrude(w)
                    polygon([[fw, 0], [d, 0], [fw, min(th, hz)]]);
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
