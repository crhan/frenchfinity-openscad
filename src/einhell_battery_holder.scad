//
// Einhell battery holder
//
// Reverse engineered from the Frenchfinity 1.0 "Einhell battery holder" .f3d /
// the single STL frenchfinity-einhell-battery-holder-v1-a20.00.stl. Only ONE
// sample exists (angle=20), so this is a functional port: `angle` is the sole
// parameter, everything else is fixed to the Einhell PXC battery and was
// measured from that one STL (not regressed).
//
//   angle (default 20) -> how far the battery seat leans back from horizontal
//
// Shape (verified against the single STL's cross sections + iso/side, NOT the
// bbox): the earlier port was a deep U-channel cradle; the 1.0 is a long, THIN
// flat SLAB (the battery seat) leaning up/back from a small base, with two
// shallow guide rails along its edges and a ~38 mm channel between them that the
// Einhell PXC battery slides into. A small base block at the bottom carries the
// cleat. Reference bbox at angle=20 is 55 x 111 x 89. Cleat at +Y (back).
//
// Only ONE sample exists (angle=20), so this is a functional port fixed to that
// STL; `angle` tilts the seat (best-guess mapping, can't be regressed).
//

einhell_battery_holder_width    = 55;   // holder width (X)
einhell_battery_holder_inner    = 38;   // battery channel width between the rails
einhell_battery_holder_wall     = 8;    // guide rail width each side (X)
einhell_battery_holder_slab     = 12;   // seat slab thickness
einhell_battery_holder_rail     = 10;   // guide rail height above the slab
einhell_battery_holder_seat_len = 105;  // seat length along the slab
einhell_battery_holder_base_d   = 22;   // base block depth (Y)
einhell_battery_holder_base_h   = 30;   // base block height (Z), carries the cleat

// seat tilt above horizontal (deg); a=20 -> 31 deg gives the 55x111x89 bbox.
function einhell_battery_holder_tilt () = einhell_battery_holder_angle + 11;

// The thin seat slab lying along its length (Y), open mouth up (+Z): a flat slab
// plus two shallow guide rails, channel + both ends open so the battery slides in.
module einhell_battery_holder_seat () {
    w     = einhell_battery_holder_width;
    inner = einhell_battery_holder_inner;
    wall  = einhell_battery_holder_wall;
    slab  = einhell_battery_holder_slab;
    rail  = einhell_battery_holder_rail;
    len   = einhell_battery_holder_seat_len;

    difference () {
        cube([w, len, slab + rail]);
        // battery channel between the two edge rails: open top, open both ends
        translate([wall, -1, slab])
            cube([inner, len + 2, rail + 1]);
    }
}

module einhell_battery_holder_body () {
    w     = einhell_battery_holder_width;
    base_d = einhell_battery_holder_base_d;
    base_h = einhell_battery_holder_base_h;
    slab  = einhell_battery_holder_slab;
    tilt  = einhell_battery_holder_tilt();

    union () {
        // small base block at the front bottom, carrying the cleat at +Y
        cube([w, base_d, base_h]);
        // thin seat slab, hinged at the base top-back and tilted up/back
        translate([0, base_d, base_h - slab])
            rotate([tilt, 0, 0])
                einhell_battery_holder_seat();
    }
}

module einhell_battery_holder_with_nut () {
    w      = einhell_battery_holder_width;
    base_d = einhell_battery_holder_base_d;
    base_h = einhell_battery_holder_base_h;

    union () {
        einhell_battery_holder_body();
        // cleat on the base block back face (+Y), near its top
        up(base_h - (frenchfinity_1_0_slot_distance_top * 2))
            back(base_d)
                nut(w, false);
    }
}

module einhell_battery_holder_labels_only () {
    w      = einhell_battery_holder_width;
    base_h = einhell_battery_holder_base_h;

    // engrave the 2-line v / a label on the base block front face (X-read, faces
    // -Y so no flip); the back face carries the cleat.
    labelFace(
        [final_version_prefix_calculated, str("a", einhell_battery_holder_angle)],
        ["x", w / 2, 0, w, 2, base_h - 2]
    );
}

module einhell_battery_holder_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        str("a", einhell_battery_holder_angle)
    ]);

    difference () {
        einhell_battery_holder_with_nut();
        einhell_battery_holder_labels_only();
    }
}

module feature_einhell_battery_holder () {
    assert(einhell_battery_holder_angle > 0 && einhell_battery_holder_angle < 90,
           "angle must be between 0 and 90");

    einhell_battery_holder_with_nut_and_text();
}
