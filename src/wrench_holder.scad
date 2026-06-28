//
// Wrench holder
//
// Reverse engineered from the Frenchfinity 1.0 "Wrench-Holder v26.f3d" (35
// reference STLs). Functional + key-dimension port. Fusion user parameters:
//
//   width        (w)   -> length of the rack out from the wall (Y); more = more slots
//   scale        (s)   -> scales the rack cross-section (X width and Z height)
//   wrench_width (ww)  -> the slot gap between comb teeth (does NOT change the bbox)
//
// Verified against the 35 STLs (tools/stl_analyze.py):
//   dy = width + 25.88                 (R^2 = 1.0, exact; 10.88 of it is the cleat)
//   dx = 44.77*scale + 4.49            (R^2 = 0.99, scale drives the width)
//   dz = max(14.20, 11.2*scale + 7.4)  (scale drives height, floored)
//   wrench_width: internal slot gap only (bbox identical when only ww changes)
//
// Shape: a cleat base at the back, two side rails (combs) running forward with
// inward teeth that form a row of open-top slots; a wrench drops into a slot and
// is held between the teeth. Cleat at +Y (back). The cross-section (rails +
// channel + height) scales with `scale`; the slot count grows with `width`.
//

wrench_holder_base_depth = 15;   // cleat base block depth (Y): dy = width + base + 10.88
wrench_holder_tooth      = 4;    // tooth length along Y at scale 1 (slot pitch = ww + tooth)

function wrench_holder_outer_width () =
    44.77 * wrench_holder_scale + 4.49;

function wrench_holder_outer_height () =
    max(14.20, 11.2 * wrench_holder_scale + 7.4);

function wrench_holder_rail_width () =
    wrench_holder_outer_width() * 0.30;     // each side rail (X)

module wrench_holder_body () {
    w     = wrench_holder_outer_width();
    h     = wrench_holder_outer_height();
    L     = wrench_holder_width + wrench_holder_base_depth;   // body Y (+ cleat = dy)
    base  = wrench_holder_base_depth;
    rail  = wrench_holder_rail_width();
    floor_t = h * 0.30;                       // channel floor thickness (Z)
    tooth = wrench_holder_tooth;
    pitch = wrench_holder_wrench_width + tooth;
    teeth = max(1, floor((wrench_holder_width - tooth) / pitch));
    tin   = rail * 0.6;                       // how far a tooth reaches inward (X)

    difference () {
        union () {
            // cleat base block at the back
            translate([0, L - base, 0]) cube([w, base, h]);
            // two side rails (combs) running the full length forward
            cube([rail, L, h]);
            translate([w - rail, 0, 0]) cube([rail, L, h]);
            // channel floor
            cube([w, L, floor_t]);
            // inward teeth on each rail, forming the slots
            for (i = [0 : teeth - 1])
                translate([0, tooth / 2 + i * pitch, 0]) {
                    translate([rail, 0, 0])           cube([tin, tooth, h]);
                    translate([w - rail - tin, 0, 0]) cube([tin, tooth, h]);
                }
        }
        // screw / filament relief hole through the base, near the bottom
        translate([w / 2, L - base / 2, -1])
            cylinder(d = 3, h = floor_t + 2, $fn = 48);
    }
}

module wrench_holder_with_nut () {
    w = wrench_holder_outer_width();
    h = wrench_holder_outer_height();
    L = wrench_holder_width + wrench_holder_base_depth;

    union () {
        wrench_holder_body();
        up(h - (frenchfinity_1_0_slot_distance_top * 2))
            back(L)
                nut(w, false);
    }
}

module wrench_holder_labels_only () {
    w = wrench_holder_outer_width();
    h = wrench_holder_outer_height();
    L = wrench_holder_width + wrench_holder_base_depth;

    // The rack is short (~18 mm) and the full-width cleat covers the back face,
    // so engrave on the long rail SIDE faces (Y-read) like the rectangular
    // holder: v / ww on the right rail, w / s on the left. Floored, no spill
    // (the rails are long enough).
    labelLines(
        [final_version_prefix_calculated, str("ww", wrench_holder_wrench_width)],
        ["y", L / 2, w, L, 1.5, h - 1.5, "right"]
    );
    labelLines(
        [str("w", wrench_holder_width), str("s", wrench_holder_scale)],
        ["y", L / 2, 0, L, 1.5, h - 1.5, "left"]
    );
}

module wrench_holder_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        str("ww", wrench_holder_wrench_width),
        [str("w", wrench_holder_width), str("s", wrench_holder_scale)]
    ]);

    difference () {
        wrench_holder_with_nut();
        wrench_holder_labels_only();
    }
}

module feature_wrench_holder () {
    assert(wrench_holder_width > 0, "width must be > 0");
    assert(wrench_holder_scale > 0, "scale must be > 0");
    assert(wrench_holder_wrench_width > 0, "wrench_width must be > 0");

    wrench_holder_with_nut_and_text();
}
