//
// Hammer holder
//
// Reverse engineered from the Frenchfinity 1.0 "Hammer-Holder v32.f3d" (9
// reference STLs). Functional + key-dimension port. Fusion user parameters:
//
//   width                 (w)   -> overall width / back plate width (X)
//   hammer_width          (hw)  -> front-to-back size of the head seat (Y depth)
//   handle_hole_width     (hhw) -> central channel the handle hangs through (X)
//   drop_protection_height(dph) -> front lip height that stops the head sliding off
//   drop_protection_width (dpw) -> front lip thickness (Y)
//
// Verified against the 9 STLs (tools/stl_analyze.py):
//   dx = width                              (R^2 = 1.0, exact)
//   dz = 50                                 (constant, independent of all params)
//   dy = hammer_width + 2*dpw + 26.88       (exact; 10.88 of it is the cleat)
//
// Shape: a full-height (50 mm) back plate carrying the french cleat; from its
// lower half two side rails project forward, the hammer HEAD rests across them
// and the HANDLE hangs through the central channel (handle_hole_width) between
// them; a raised lip at the front of each rail (drop_protection) stops the head
// sliding off. Cleat at +Y (back), like the other holders.
//

hammer_holder_height     = 50;   // fixed total height (Z), per 1.0
hammer_holder_plate_depth = 5;   // back plate thickness (Y)
hammer_holder_rail_height = 25;  // cradle / rail height (Z); head rests on top
hammer_holder_floor       = 2;   // thin floor under the handle channel (Z)

function hammer_holder_body_depth () =
    hammer_holder_hammer_width + 2 * hammer_holder_drop_protection_width
        + hammer_holder_plate_depth + 11;   // + cleat(10.88) => dy = hw + 2*dpw + 26.88

function hammer_holder_rail_width () =
    (hammer_holder_width - hammer_holder_handle_hole_width) / 2;

module hammer_holder_body () {
    w     = hammer_holder_width;
    h     = hammer_holder_height;
    d     = hammer_holder_body_depth();
    plate = hammer_holder_plate_depth;
    rail  = hammer_holder_rail_width();
    rh    = hammer_holder_rail_height;
    dph   = hammer_holder_drop_protection_height;
    dpw   = hammer_holder_drop_protection_width;
    floor = hammer_holder_floor;

    union () {
        // full-height back plate (cleat + labels)
        translate([0, d - plate, 0]) cube([w, plate, h]);
        // two side rails the head rests across (lower half)
        cube([rail, d - plate, rh]);
        translate([w - rail, 0, 0]) cube([rail, d - plate, rh]);
        // thin floor under the handle channel
        cube([w, d - plate, floor]);
        // drop-protection lip at the front of each rail
        translate([0,        0, rh]) cube([rail, dpw, dph]);
        translate([w - rail, 0, rh]) cube([rail, dpw, dph]);
    }
}

module hammer_holder_with_nut () {
    w = hammer_holder_width;
    h = hammer_holder_height;
    d = hammer_holder_body_depth();

    union () {
        hammer_holder_body();
        up(h - (frenchfinity_1_0_slot_distance_top * 2))
            back(d)
                nut(w, false);
    }
}

module hammer_holder_labels_only () {
    w = hammer_holder_width;
    h = hammer_holder_height;
    d = hammer_holder_body_depth();
    plate = hammer_holder_plate_depth;

    // 1.0 stacked v-w / hw-hhw / dph-dpw on the body; engrave on the wide back
    // plate (X-read) with floor, spilling to the plate front face.
    labelLines(
        [
            str(final_version_prefix_calculated, "-w", hammer_holder_width),
            str("hw", hammer_holder_hammer_width, "-hhw", hammer_holder_handle_hole_width),
            str("dph", hammer_holder_drop_protection_height, "-dpw", hammer_holder_drop_protection_width)
        ],
        ["x", w / 2, d,         w, 2, h - 17],
        ["x", w / 2, d - plate, w, 2, h - 17]
    );
}

module hammer_holder_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        str("w",   hammer_holder_width),
        [str("hw", hammer_holder_hammer_width), str("hhw", hammer_holder_handle_hole_width)],
        [str("dph", hammer_holder_drop_protection_height), str("dpw", hammer_holder_drop_protection_width)]
    ]);

    difference () {
        hammer_holder_with_nut();
        hammer_holder_labels_only();
    }
}

module feature_hammer_holder () {
    assert(hammer_holder_width > 0, "width must be > 0");
    assert(hammer_holder_hammer_width > 0, "hammer_width must be > 0");
    assert(hammer_holder_handle_hole_width > 0, "handle_hole_width must be > 0");
    assert(hammer_holder_drop_protection_height >= 0, "drop_protection_height must be >= 0");
    assert(hammer_holder_drop_protection_width >= 0, "drop_protection_width must be >= 0");
    assert(
        hammer_holder_handle_hole_width < hammer_holder_width,
        "handle_hole_width must be < width (otherwise there are no side rails)"
    );

    hammer_holder_with_nut_and_text();
}
