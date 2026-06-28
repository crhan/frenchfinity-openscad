//
// Small hole holder
//
// Reverse engineered from the Frenchfinity 1.0 "Small hole holder v6" .f3d.
// NOTE: that source is a loose .f3d with NO exported STLs, so this is a
// functional port from the recovered Fusion user-parameter expressions, not a
// bbox-verified clone. Public parameters:
//
//   hole_width  (hw) -> width of the rectangular tool hole
//   hole_length (hl) -> length of the rectangular tool hole
//   tool_width  (tw) -> drives the plate height (tw + padding) so the tool's
//                       shoulder lands on the plate
//
// Recovered fixed constants (1.0): hole_tolerance = 0.5 (subtracted from hole_width
// so the printed hole is snug), padding = 5, wall_thickness = 5, draft angle = 2deg
// (a ~0.17mm taper over the 5mm wall - negligible, omitted), 21mm minimum plate
// width (to host the cleat cross-section).
//
//   plate width  = max(21, padding + hole_width - hole_tolerance) = max(21, hw + 4.5)
//   plate height = tool_width + padding = tool_width + 5
//   hole opening = (hole_width - hole_tolerance) x hole_length
//
// A small French-cleat plate with one rectangular through-hole; a tool with a
// rectangular shaft drops through until a wider shoulder rests on the plate.
// Cleat at +Y (back), like the other holders.
//

small_hole_holder_tolerance     = 0.5;   // shrink applied to hole_width (snug)
small_hole_holder_padding        = 5;    // plate height margin over tool_width
small_hole_holder_wall_thickness = 5;    // plate thickness (Y)
small_hole_holder_min_width      = 21;   // minimum plate width (cleat cross-section)

function small_hole_holder_outer_width () =
    max(small_hole_holder_min_width,
        small_hole_holder_padding + small_hole_holder_hole_width - small_hole_holder_tolerance);

function small_hole_holder_outer_height () =
    small_hole_holder_tool_width + small_hole_holder_padding;

module small_hole_holder_base () {
    w  = small_hole_holder_outer_width();
    h  = small_hole_holder_outer_height();
    t  = small_hole_holder_wall_thickness;
    hw = small_hole_holder_hole_width - small_hole_holder_tolerance;
    hl = small_hole_holder_hole_length;

    difference () {
        cube([w, t, h]);
        // rectangular through-hole, centred
        translate([(w - hw) / 2, -1, (h - hl) / 2])
            cube([hw, t + 2, hl]);
    }
}

module small_hole_holder_with_nut () {
    w = small_hole_holder_outer_width();
    h = small_hole_holder_outer_height();
    t = small_hole_holder_wall_thickness;

    union () {
        small_hole_holder_base();
        up(h - (frenchfinity_1_0_slot_distance_top * 2))
            back(t)
                nut(w, false);
    }
}

module small_hole_holder_labels_only () {
    w = small_hole_holder_outer_width();
    h = small_hole_holder_outer_height();
    t = small_hole_holder_wall_thickness;

    // 1.0 engraved v-hw / tw-hl; one short line per value on the wide back face
    // (X-read, the thin side walls are too narrow), floored, spilling to the
    // front face. The cleat tongue protrudes from the back; the recessed text
    // beside/under it stays inside the plate.
    labelLines(
        [
            final_version_prefix_calculated,
            str("hw", small_hole_holder_hole_width),
            str("tw", small_hole_holder_tool_width),
            str("hl", small_hole_holder_hole_length)
        ],
        ["x", w / 2, t, w, 2, h - 2],
        ["x", w / 2, 0, w, 2, h - 2]
    );
}

module small_hole_holder_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        str("hw", small_hole_holder_hole_width),
        [str("tw", small_hole_holder_tool_width), str("hl", small_hole_holder_hole_length)]
    ]);

    difference () {
        small_hole_holder_with_nut();
        small_hole_holder_labels_only();
    }
}

module feature_small_hole_holder () {
    assert(small_hole_holder_hole_width > small_hole_holder_tolerance, "hole_width must be > tolerance (0.5)");
    assert(small_hole_holder_hole_length > 0, "hole_length must be > 0");
    assert(small_hole_holder_tool_width > 0, "tool_width must be > 0");
    assert(
        small_hole_holder_hole_length < small_hole_holder_outer_height() - 2,
        "hole_length too tall for the plate (increase tool_width)"
    );

    small_hole_holder_with_nut_and_text();
}
