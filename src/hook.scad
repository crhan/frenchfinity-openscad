//
// Hook
//
// Reverse engineered from the Frenchfinity 1.0 Fusion 360 model "Hook v11.f3d".
// Original Fusion user parameters (kept as the public parameters, see
// frenchfinity.scad):
//
//   width           (w)   -> width of the hook bar (X)
//   height          (h)   -> overall height, top of shank to the cleat (Z)
//   hook_diameter   (hd)  -> OUTER diameter of the J bend
//   thickness       (t)   -> thickness of the hook bar
//   hook_end_height (heh) -> how far the upturned tip rises past the bend centre
//
// Geometry (verified against the original STLs, R^2 = 1.0):
//   dx (width)  = w
//   dz (height) = h
//   dy (depth)  = hook_diameter + 10.88   (hd is the bend, 10.88 is the cleat)
//
// The hook is a flat J profile in the Y-Z plane, extruded by w in X: a vertical
// shank at the back (carrying the french cleat), a 180-degree bend at the bottom
// of outer diameter hd, and a short upturned tip of height heh at the front.
//
// Orientation note: like the other holders the cleat sits at the +Y (back) end,
// the mirror of the 1.0 export (cleat at -Y).
//

// The cleat tongue depth in Y (so dy = hd + this). Matches the standard nut().
function hook_cleat_depth() =
    frenchfinity_1_0_slot_outer_width + frenchfinity_1_0_slot_inner_width;

// 2D J profile in (u, v) = (depth Y, height Z): u = 0 front (tip), u = hd back
// (shank / wall). Bar thickness t; bend outer radius hd/2.
module hook_profile_2d () {
    w_  = hook_width;     // unused here, kept for clarity
    h   = hook_height;
    hd  = hook_diameter;
    t   = hook_thickness;
    heh = hook_end_height;
    ro  = hd / 2;
    ri  = hd / 2 - t;
    cz  = hd / 2;         // bend centre Z (bottom of bend at Z = 0)

    union () {
        // shank (back): full height down to the bend centre
        translate([hd - t, cz]) square([t, h - cz]);
        // upturned tip (front): rises heh above the bend centre
        translate([0, cz]) square([t, heh]);
        // 180-degree bend: lower half of the annulus, centred at (hd/2, hd/2)
        intersection () {
            difference () {
                translate([hd / 2, cz]) circle(r = ro, $fn = 128);
                translate([hd / 2, cz]) circle(r = ri, $fn = 128);
            }
            translate([-1, -1]) square([hd + 2, cz + 1]);   // keep v <= cz
        }
    }
}

module hook_base () {
    // profile is in XY (X=depth, Y=height); rotate([90,0,90]) maps it so the
    // linear_extrude (along Z by w) becomes the X width, depth -> Y, height -> Z.
    rotate([90, 0, 90])
        linear_extrude(height = hook_width)
            hook_profile_2d();
}

module hook_with_nut () {
    w  = hook_width;
    h  = hook_height;
    hd = hook_diameter;

    union () {
        hook_base();
        // standard frenchfinity cleat tongue on the shank back (Y = hd), near
        // the top, same idiom as the other holders.
        up(h - (frenchfinity_1_0_slot_distance_top * 2))
            back(hd)
                nut(w, false);
    }
}

// Engrave the labels on the shank's front face (the wide -Y face you see once
// the hook is mounted). The 1.0 model packed everything onto the shank; we use
// one short line per value so even a narrow (w = 10) hook stays readable and in
// bounds. The shank front face is at Y = hd - t.
module hook_label_block (lines) {
    w        = hook_width;
    h        = hook_height;
    hd       = hook_diameter;
    t        = hook_thickness;
    cz       = hd / 2;
    engrave  = 1.0;
    margin   = 1.5;
    line_k   = 1.4;
    glyph_k  = 1.1;
    char_k   = 0.70;
    n        = len(lines);
    maxchars = max([for (s = lines) len(s)]);

    region_h = h - cz;                 // shank height available for text
    size_fit_h = (region_h - 2 * margin) / (glyph_k + (n - 1) * line_k);
    size_fit_w = (w - 2 * margin) / (maxchars * char_k);
    size       = min(text_size, size_fit_h, size_fit_w);
    pitch      = size * line_k;
    glyph_h    = size * glyph_k;

    // centre the block in the shank region [cz, h]
    z0 = cz + (region_h + glyph_h + (n - 1) * pitch) / 2 - glyph_h;

    if (render_text)
        for (i = [0 : n - 1])
            translate([w / 2, hd - t, z0 - i * pitch])
                rotate([90, 0, 0])
                    text3d(
                        lines[i],
                        size   = size,
                        height = engrave * 2,
                        anchor = CENTER
                    );
}

module hook_labels_only () {
    hook_label_block([
        final_version_prefix_calculated,
        str("w",   hook_width),
        str("h",   hook_height),
        str("hd",  hook_diameter),
        str("t",   hook_thickness),
        str("heh", hook_end_height)
    ]);
}

module hook_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        [str("w", hook_width), str("h", hook_height)],
        [str("hd", hook_diameter), str("t", hook_thickness), str("heh", hook_end_height)]
    ]);

    difference () {
        hook_with_nut();
        hook_labels_only();
    }
}

module feature_hook () {
    assert(hook_width  > 0, "width must be > 0");
    assert(hook_height > 0, "height must be > 0");
    assert(hook_diameter > 0, "hook_diameter must be > 0");
    assert(hook_thickness > 0, "thickness must be > 0");
    assert(hook_end_height >= 0, "hook_end_height must be >= 0");
    assert(
        hook_thickness < hook_diameter / 2,
        "thickness must be < hook_diameter/2 (otherwise the bend has no opening)"
    );
    assert(
        hook_height > hook_diameter / 2,
        "height must be > hook_diameter/2 (the shank needs to reach above the bend)"
    );

    hook_with_nut_and_text();
}
