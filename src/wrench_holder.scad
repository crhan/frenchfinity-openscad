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
// Shape (verified against the 1.0 STL cross-section by cross-section AND the
// top-down render, NOT by the bbox): a tall full-width cleat block at the back,
// and TWO continuous side rails that cantilever forward from it with an OPEN
// channel between them (no floor). Notches (slots, width = wrench_width) are cut
// from the top into the INNER edge of each rail (the channel-facing side); the
// outer edge of each rail stays continuous for strength. A wrench is laid across
// the channel and drops into an aligned inner-notch pair; the head rests on the
// rail tops, the handle hangs in the open channel. Cleat at +Y (back). The
// cross-section scales with `scale`, the slot count grows with `width`.
//
// Measured at scale 1 (ww8/w60): cleat block h 18.6, rails ~11 tall (0.6 h),
// notch depth ~5 (0.27 h), tooth ~3.3, slot = ww, rack region Y = width (60),
// solid back block ~15 deep.
//

wrench_holder_base_depth = 15;   // solid cleat block depth (Y): dy = width + base + 10.88
wrench_holder_tooth      = 3.3;  // tooth (divider) width along Y; slot pitch = ww + tooth

function wrench_holder_outer_width () =
    44.77 * wrench_holder_scale + 4.49;

function wrench_holder_outer_height () =      // cleat block height (Z)
    max(14.20, 11.2 * wrench_holder_scale + 7.4);

function wrench_holder_rail_height () =       // rails are shorter than the cleat
    wrench_holder_outer_height() * 0.60;

function wrench_holder_slot_depth () =        // notch depth cut into the rail top
    wrench_holder_outer_height() * 0.27;

function wrench_holder_rail_width () =        // each side rail (X)
    wrench_holder_outer_width() * 0.18;

function wrench_holder_margin () =            // rack inset from the block edge (X)
    wrench_holder_outer_width() * 0.11;

module wrench_holder_body () {
    w      = wrench_holder_outer_width();
    h      = wrench_holder_outer_height();
    rh     = wrench_holder_rail_height();
    sd     = wrench_holder_slot_depth();
    L      = wrench_holder_width + wrench_holder_base_depth;   // body Y (+ cleat = dy)
    base   = wrench_holder_base_depth;
    rail   = wrench_holder_rail_width();
    margin = wrench_holder_margin();
    tooth  = wrench_holder_tooth;
    pitch  = wrench_holder_wrench_width + tooth;
    rack   = wrench_holder_width;                              // slotted length (Y)
    slots  = max(1, floor((rack - tooth) / pitch));
    span   = rack - (slots * pitch - wrench_holder_wrench_width); // leftover, to centre
    y0     = max(tooth, span / 2);                            // first slot start

    difference () {
        union () {
            // full-width cleat block at the back
            translate([0, L - base, 0]) cube([w, base, h]);
            // two short side rails cantilevered forward, open channel between
            translate([margin,           0, 0]) cube([rail, L - base, rh]);
            translate([w - margin - rail, 0, 0]) cube([rail, L - base, rh]);
        }
        // notches cut from the top into the INNER edge of each rail
        ndepth = rail * 0.7;                                  // how far into the rail (X)
        for (i = [0 : slots - 1])
            translate([0, y0 + i * pitch, rh - sd]) {
                // left rail: notch on its right (inner) edge
                translate([margin + rail - ndepth, 0, 0])
                    cube([ndepth, wrench_holder_wrench_width, sd + 1]);
                // right rail: notch on its left (inner) edge
                translate([w - margin - rail, 0, 0])
                    cube([ndepth, wrench_holder_wrench_width, sd + 1]);
            }
        // screw / filament relief hole through the back block, near the bottom
        translate([w / 2, L - base / 2, -1])
            cylinder(d = 3, h = h + 2, $fn = 48);
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
    w      = wrench_holder_outer_width();
    h      = wrench_holder_outer_height();
    rh     = wrench_holder_rail_height();
    L      = wrench_holder_width + wrench_holder_base_depth;
    rack   = wrench_holder_width;                 // rail length (Y)
    margin = wrench_holder_margin();

    // The rails are short in Z (one line tall). Put the version + ww flat on the
    // cleat block's top deck (the only roomy flat area), and w / s as single
    // lines along the long rail outer faces (Y-read, correct orientation).
    labelTop([final_version_prefix_calculated,
              str("ww", wrench_holder_wrench_width)],
             w / 2, L - wrench_holder_base_depth / 2,
             w, wrench_holder_base_depth, h);
    labelFace([str("w", wrench_holder_width)],
              ["y", rack / 2, w - margin, rack - 2, 0.5, rh - 0.5, "right"]);
    labelFace([str("s", wrench_holder_scale)],
              ["y", rack / 2, margin,     rack - 2, 0.5, rh - 0.5, "left"]);
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
