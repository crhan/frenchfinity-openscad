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
// Shape (verified against the 1.0 front/iso renders + cross sections, NOT the
// bbox -- the earlier port used two separate rails with a flat-bottomed
// rectangular channel; the 1.0 is a SOLID cradle block with a rounded U-notch):
// a tall (50 mm) back plate carries the french cleat; in front of it a lower
// solid cradle block has a central U-notch (width handle_hole_width, ROUNDED
// bottom) cut through it -- the hammer HEAD rests on the cradle top to either
// side of the notch and the HANDLE hangs in the U. A raised lip at the front of
// each shoulder (drop_protection) stops the head sliding off. Cleat at +Y.
//

hammer_holder_height      = 50;  // fixed total height (Z), per 1.0
hammer_holder_plate_depth = 5;   // back plate thickness (Y)
hammer_holder_cradle_h    = 38;  // cradle (head-seat) height (Z), below the plate top

function hammer_holder_body_depth () =
    hammer_holder_hammer_width + 2 * hammer_holder_drop_protection_width
        + hammer_holder_plate_depth + 11;   // + cleat(10.88) => dy = hw + 2*dpw + 26.88

module hammer_holder_body () {
    w     = hammer_holder_width;
    h     = hammer_holder_height;
    d     = hammer_holder_body_depth();
    plate = hammer_holder_plate_depth;
    rh    = hammer_holder_cradle_h;
    hhw   = hammer_holder_handle_hole_width;
    dph   = hammer_holder_drop_protection_height;
    dpw   = hammer_holder_drop_protection_width;
    cd    = d - plate;                 // cradle depth in front of the back plate
    r     = hhw / 2;                   // rounded U-notch radius
    zc    = rh - 8;                    // rounded-bottom centre (8 mm straight sides)

    union () {
        // full-height back plate (cleat + labels)
        translate([0, d - plate, 0]) cube([w, plate, h]);
        difference () {
            // solid cradle block (head seat) in front of the plate
            cube([w, cd, rh]);
            // central handle U-notch: straight sides + rounded bottom, cut from
            // the top behind a solid front wall (dpw, the drop protection) so the
            // front face stays solid for the labels (matches the 1.0 front).
            translate([w / 2 - r, dpw, zc]) cube([hhw, cd - dpw + 2, rh]);
            translate([w / 2, dpw, zc])
                rotate([-90, 0, 0])
                    cylinder(r = r, h = cd - dpw + 2, $fn = 96);
        }
        // drop-protection: the front wall rises dph above the head seat
        translate([0, 0, rh]) cube([w, dpw, dph]);
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
    w  = hammer_holder_width;
    rh = hammer_holder_cradle_h;

    // engrave v-w / hw-hhw / dph-dpw on the solid front wall (X-read, faces -Y so
    // it reads the right way), the visible face once the holder is mounted.
    labelFace(
        [
            str(final_version_prefix_calculated, "-w", hammer_holder_width),
            str("hw", hammer_holder_hammer_width, "-hhw", hammer_holder_handle_hole_width),
            str("dph", hammer_holder_drop_protection_height, "-dpw", hammer_holder_drop_protection_width)
        ],
        ["x", w / 2, 0, w, 2, rh - 2]
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
