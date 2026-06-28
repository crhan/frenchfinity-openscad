//
// Pliers holder
//
// Reverse engineered from the Frenchfinity 1.0 Fusion 360 model
// "Pilers-Holder v16.f3d". The original exposed these Fusion user parameters
// (kept here as the public parameters, see frenchfinity.scad):
//
//   height        (h)  -> overall height of the holder (the part grows downward)
//   hole_diameter (hd) -> width of the central slot cavity that grips the pliers
//
// Geometry (verified against the original STLs with tools/stl_analyze.py,
// R^2 = 1.0 across every reference export):
//   dx (width)  = hd + 15   (cavity width hd + a 7.5 mm side wall on each side)
//   dz (height) = h  + 6
//   dy (depth)  = 90.88      (fixed; the cleat + the boot foot, param independent)
//
// Only width scales with hd and only height scales with h; the depth and the
// whole foot/cleat structure are constant. The part grows DOWNWARD as h grows
// (the top, prongs and cleat stay put, the body extends down).
//
// Shape: a "boot" body - a full height back plate that carries the french cleat,
// stepping out toward the front into a seat and a bottom toe slab that support
// the pliers. A central keyhole slot is cut down the middle: a narrow front
// throat (so a pliers handle can slide in), widening to a capsule cavity behind
// a retaining leg, open at the top so the pliers drop in between two prongs.
//
// Orientation note: like rectangular_tool_holder / box the cleat sits at the +Y
// (back) end, the mirror of the 1.0 export (cleat at -Y). The slot is centred in
// X so the two side walls stay solid for the engraved labels.
//

// Fixed structural constants (absolute, from the 1.0 model).
pliers_holder_side_wall    = 7.5;   // wall on each side of the hole (X): dx = hd + 15
pliers_holder_base_extra   = 6;     // material added in Z: dz = h + 6
pliers_holder_body_depth   = 80;    // back face to toe tip (Y); + nut() ~= 90.1 (1.0: 90.88)
pliers_holder_plate_depth  = 12.5;  // full height back plate thickness (Y)
pliers_holder_seat_depth   = 54;    // seat reaches this far forward from the back (Y)
pliers_holder_toe_height   = 10;    // bottom slab thickness (Z), bottom anchored
pliers_holder_seat_frac    = 0.55;  // seat top as a fraction of the height above the toe
pliers_holder_prong_depth  = 13;    // depth of the top saddle notch (Z), top anchored
pliers_holder_hole_bridge  = 4;     // solid bridge between the saddle and the hole (Z)
pliers_holder_hole_floor   = 12;    // minimum solid material kept below the hole (Z)

function pliers_holder_outer_width() =
    pliers_holder_hole_diameter + (pliers_holder_side_wall * 2);

function pliers_holder_outer_height() =
    pliers_holder_height + pliers_holder_base_extra;

// Z of the step where the seat ends and the back-plate-only neck begins.
function pliers_holder_seat_top() =
    let (h = pliers_holder_outer_height())
    pliers_holder_toe_height +
    (h - pliers_holder_toe_height) * pliers_holder_seat_frac;

// Solid "boot": back plate (full height) + seat + bottom toe slab, stepping out
// toward the front so it costs less material while still supporting the pliers.
module pliers_holder_body () {
    w     = pliers_holder_outer_width();
    h     = pliers_holder_outer_height();
    d     = pliers_holder_body_depth;
    plate = pliers_holder_plate_depth;
    seat  = pliers_holder_seat_depth;
    toe   = pliers_holder_toe_height;
    stop  = pliers_holder_seat_top();

    union () {
        // bottom toe slab: full depth, the part that reaches farthest forward
        cube([w, d, toe]);
        // seat: steps back from the toe, up to the seat top
        translate([0, d - seat, 0])  cube([w, seat, stop]);
        // back plate / neck: full height, carries the cleat
        translate([0, d - plate, 0]) cube([w, plate, h]);
    }
}

// Total height (Z) of the see-through capsule hole. A tall stadium (~2*hd), but
// never so tall it eats the bridge below the saddle or the floor below it.
function pliers_holder_hole_height() =
    let (
        h     = pliers_holder_outer_height(),
        hd    = pliers_holder_hole_diameter,
        avail = h - pliers_holder_prong_depth - pliers_holder_hole_bridge
                  - pliers_holder_hole_floor
    )
    max(hd, min(2 * hd, avail));

// A stadium (capsule) prism whose axis runs along Y, so it reads as a see-through
// hole from the front: width wd (X), total height ht (Z), centred at (cx, cz),
// spanning Y in [y0, y1].
module pliers_holder_y_capsule (cx, cz, wd, ht, y0, y1) {
    r   = wd / 2;
    gap = max(0, ht - wd);   // centre-to-centre of the two end circles
    hull () {
        translate([cx, y0, cz - gap / 2]) rotate([-90, 0, 0]) cylinder(h = y1 - y0, r = r, $fn = 96);
        translate([cx, y0, cz + gap / 2]) rotate([-90, 0, 0]) cylinder(h = y1 - y0, r = r, $fn = 96);
    }
}

// Everything cut from the body, as a positive. Two features, both centred in X
// and cut through the whole depth (Y) so they read as real openings from the
// front: a see-through capsule hole (width hd) low-middle, and a rounded saddle
// notch in the top edge that splits the top into two prongs (above the cleat).
module pliers_holder_slot () {
    w   = pliers_holder_outer_width();
    h   = pliers_holder_outer_height();
    d   = pliers_holder_body_depth;
    hd  = pliers_holder_hole_diameter;
    cx  = w / 2;
    hh  = pliers_holder_hole_height();

    // capsule hole: top anchored, sitting a bridge below the saddle notch
    hole_top = h - pliers_holder_prong_depth - pliers_holder_hole_bridge;
    hole_cz  = hole_top - hh / 2;
    pliers_holder_y_capsule(cx, hole_cz, hd, hh, -1, d + 1);

    // saddle notch: rounded U cut into the top edge -> two prongs
    saddle_bot = h - pliers_holder_prong_depth;
    translate([cx, -1, saddle_bot])
        rotate([-90, 0, 0]) cylinder(h = d + 2, d = hd, $fn = 96);   // rounded bottom
    translate([cx - hd / 2, -1, saddle_bot])
        cube([hd, d + 2, pliers_holder_prong_depth + 1]);            // straight sides up
}

module pliers_holder_with_nut () {
    w = pliers_holder_outer_width();
    h = pliers_holder_outer_height();
    d = pliers_holder_body_depth;

    // cleat sits on the back plate just below the saddle notch (as in 1.0, where
    // the prongs are free above the cleat), high enough to clear the hole.
    cleat_top = h - pliers_holder_prong_depth;

    union () {
        difference () {
            pliers_holder_body();
            pliers_holder_slot();
        }
        // standard frenchfinity cleat tongue on the back plate, same idiom as
        // rectangular_tool_holder / box.
        up(cleat_top - frenchfinity_1_0_slot_outer_height)
            back(d)
                nut(w, false);
    }
}

// Engrave the label block on a side wall (the large X faces, which stay solid
// because the slot is centred). The 1.0 model stacked v / h / hd on one face;
// we keep them within the always-solid seat rectangle so even the shortest part
// never pushes a line off the material. side = "right" (+X) or "left" (-X).
module pliers_holder_label_block (lines, side) {
    w        = pliers_holder_outer_width();
    d        = pliers_holder_body_depth;
    seat     = pliers_holder_seat_depth;
    stop     = pliers_holder_seat_top();
    engrave  = 1.5;
    margin   = 2.0;
    line_k   = 1.4;
    glyph_k  = 1.1;
    char_k   = 0.70;
    n        = len(lines);
    maxchars = max([for (s = lines) len(s)]);

    // The text lives inside the seat rectangle: Y in [d - seat, d], Z in [0, stop].
    region_y = seat;
    region_z = stop;
    yc       = d - (seat / 2);

    size_fit_h = (region_z - 2 * margin) / (glyph_k + (n - 1) * line_k);
    size_fit_w = (region_y - 2 * margin) / (maxchars * char_k);
    size       = min(text_size, size_fit_h, size_fit_w);
    pitch      = size * line_k;
    glyph_h    = size * glyph_k;

    // text3d is baseline anchored vertically: centre the block inside [0, stop].
    z0 = (region_z + glyph_h + (n - 1) * pitch) / 2 - glyph_h;

    if (render_text)
        for (i = [0 : n - 1])
            translate([side == "right" ? w : 0, yc, z0 - i * pitch])
                rotate(side == "right" ? [90, 0, 90] : [90, 0, -90])
                    text3d(
                        lines[i],
                        size   = size,
                        height = engrave * 2,
                        anchor = CENTER
                    );
}

// All engraving solids as positives. Single source for the label content so the
// production model (which subtracts it) and the test harness stay in sync.
module pliers_holder_labels_only () {
    pliers_holder_label_block(
        [
            final_version_prefix_calculated,
            str("h",  pliers_holder_height),
            str("hd", pliers_holder_hole_diameter)
        ],
        "right"
    );
}

module pliers_holder_with_nut_and_text () {
    // Keep the 2.0 filename proposal echo (ECHO: "filename proposal:", ...).
    labels = hintFileName([
        final_version_prefix_calculated,
        str("h",  pliers_holder_height),
        str("hd", pliers_holder_hole_diameter)
    ]);

    difference () {
        pliers_holder_with_nut();
        pliers_holder_labels_only();
    }
}

module feature_pliers_holder () {
    // Fail loudly on inputs that would silently produce junk.
    assert(pliers_holder_height > 0, "height must be > 0");
    assert(pliers_holder_hole_diameter > 0, "hole_diameter must be > 0");
    assert(
        pliers_holder_hole_diameter < pliers_holder_outer_width() - 2,
        "hole_diameter leaves no side wall"
    );

    pliers_holder_with_nut_and_text();
}
