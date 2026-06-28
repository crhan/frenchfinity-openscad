//
// Einhell battery holder
//
// Reverse engineered from the Frenchfinity 1.0 "Einhell battery holder" .f3d /
// the single STL frenchfinity-einhell-battery-holder-v1-a20.00.stl. Only ONE
// sample exists (angle=20), so this is a functional port: `angle` is the sole
// parameter, everything else is fixed to the Einhell PXC battery and was
// measured from that one STL (not regressed).
//
//   angle (default 20) -> how far the battery cradle leans back from vertical
//
// Fixed constants (measured): holder width 55, inner cradle width ~41, side wall
// ~7, floor ~3.5, battery seat length ~80. Reference bbox at angle=20 is
// 55 x 111 x 89. A back body carries the cleat; a U-channel cradle (floor + two
// side walls, open top) leans back by `angle` so the battery drops in and rests
// against the back. Cleat at +Y (back).
//

einhell_battery_holder_width      = 55;   // holder / cradle outer width (X)
einhell_battery_holder_inner      = 41;   // inner channel width (battery body)
einhell_battery_holder_wall       = 7;    // cradle side wall (X)
einhell_battery_holder_floor      = 4;    // cradle floor thickness
einhell_battery_holder_seat_len   = 115;  // battery seat length along the cradle
einhell_battery_holder_channel    = 26;   // cradle depth (wraps the battery)
einhell_battery_holder_base       = 8;    // back body height (Z) carrying the cleat

// The U-channel cradle, lying along its length (Y) with the open mouth up (+Z);
// floor + two side walls, open at the top and both ends so the battery slides in.
module einhell_battery_holder_cradle () {
    w     = einhell_battery_holder_width;
    inner = einhell_battery_holder_inner;
    wall  = einhell_battery_holder_wall;
    floor = einhell_battery_holder_floor;
    len   = einhell_battery_holder_seat_len;
    ch    = einhell_battery_holder_channel;

    difference () {
        cube([w, len, ch]);
        // battery channel: open top, open both ends
        translate([(w - inner) / 2, -1, floor])
            cube([inner, len + 2, ch]);
    }
}

module einhell_battery_holder_body () {
    w    = einhell_battery_holder_width;
    base = einhell_battery_holder_base;
    ch   = einhell_battery_holder_channel;
    a    = einhell_battery_holder_angle;

    union () {
        // back body: vertical block at the back carrying the cleat
        cube([w, ch, base + ch]);
        // reclined cradle: the battery seat leans back from the body, rising up
        // and forward. `angle` reclines it (smaller angle = flatter / more forward).
        translate([0, ch, base])
            rotate([a + 15, 0, 0])
                einhell_battery_holder_cradle();
    }
}

module einhell_battery_holder_with_nut () {
    w   = einhell_battery_holder_width;
    base = einhell_battery_holder_base;
    ch  = einhell_battery_holder_channel;

    union () {
        einhell_battery_holder_body();
        // cleat on the back body, near its top
        up(base + ch - (frenchfinity_1_0_slot_distance_top * 2))
            back(ch)
                nut(w, false);
    }
}

module einhell_battery_holder_labels_only () {
    w    = einhell_battery_holder_width;
    base = einhell_battery_holder_base;
    ch   = einhell_battery_holder_channel;

    // 1.0 engraved a 2-line v / a label; put it on the back body's back face
    // (X-read), floored, spilling to the front face.
    labelLines(
        [final_version_prefix_calculated, str("a", einhell_battery_holder_angle)],
        ["x", w / 2, ch, w, 2, base + ch - 14],
        ["x", w / 2, 0,  w, 2, base + ch - 14]
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
