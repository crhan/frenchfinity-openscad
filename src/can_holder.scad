//
// Can holder  (a.k.a. can / drill / spray-can holder)
//
// Reverse engineered from the Frenchfinity 1.0 "Can-Holder" by measuring the
// reference STLs cross-section by cross-section (NOT by fitting the bounding box
// -- an earlier version matched the bbox with a regression but had completely
// wrong geometry). Fusion user parameters and what they ACTUALLY drive:
//
//   can_diameter (cd)  -> the can/tube the bore must fit; bore = cd + clearance
//   padding      (p)   -> SIDE/front wall around the bore; sets width dx = cd+2*p
//   can_inset    (ci)  -> bore DEPTH measured along the (tilted) bore axis
//   padding_left (pl)  -> BACK wall thickness (toward the wall/cleat side)
//
// Shape (verified against the side cross-sections of 6 reference STLs, isolating
// each parameter -- the bbox was deliberately NOT used to drive the geometry):
// a tall UPRIGHT block, width cd+2*p, with a deep blind bore drilled from the
// TOP and tilted ~9 deg so the can leans outward (top away from the wall, easy
// to grab). The back wall is vertical, thickness pl, and carries the french
// cleat at the top; the front face is slanted parallel to the bore axis (top
// juts forward, bottom recedes), so the FRONT/side walls stay a constant ~p.
// A solid base (~9 + 0.3*pl) sits below the bore floor; the "-hole-bottom" 1.0
// variant adds a drain/push-out hole through that base (can_holder_bottom="open").
//
// Derived size relations (consequences of the geometry; they track the 1.0 STLs
// across cd/p/ci/pl variation, each within ~1mm):
//   dx = cd + 2*p                                   (exact)
//   dz = ci*cos(tilt) + 0.3*pl + ~13                (within ~1mm)
//   dy = (cd+clear) + p + pl + ci*sin(tilt) + cleat (within ~1mm)
//
// Orientation: cleat at +Y (back), like the other holders.
//

can_holder_tilt      = 9;     // bore tilt from vertical (deg); can leans outward
can_holder_clearance = 2.4;   // bore = can_diameter + this (fit slack, matches 1.0)
can_holder_rim       = 4;     // solid lip above the bore opening (high side)
can_holder_drain     = 6;     // drain hole diameter for bottom = "open"

function can_holder_outer_width () =
    can_holder_can_diameter + 2 * can_holder_padding;

// solid base height below the bore floor (measured: ~9 + 0.3*pl)
function can_holder_base () = 9 + 0.3 * can_holder_padding_left;

// total height = base + vertical run of the bore + top lip
function can_holder_height () =
    can_holder_base()
    + can_holder_can_inset * cos(can_holder_tilt)
    + can_holder_rim;

// back wall Y (vertical, carries the cleat): front wall p + bore + back wall pl.
function can_holder_depth () =
    (can_holder_can_diameter + can_holder_clearance)
    + can_holder_padding             // front wall
    + can_holder_padding_left;        // back wall (toward the cleat)

// front face Y at height z: B(0,0) at the base, leaning to (-ci*sin(tilt), H) up top
function can_holder_front_y (z) =
    -can_holder_can_inset * sin(can_holder_tilt) * z / can_holder_height();

module can_holder_body () {
    w     = can_holder_outer_width();
    cd    = can_holder_can_diameter;
    p     = can_holder_padding;
    ci    = can_holder_can_inset;
    T     = can_holder_tilt;
    bd    = cd + can_holder_clearance;
    base  = can_holder_base();
    H     = can_holder_height();
    D     = can_holder_depth();             // back wall Y
    yft   = -ci * sin(T);                    // front-top Y (frontmost point)
    y_bot = bd / 2 + p;                      // bore bottom centre Y

    difference () {
        // upright block: vertical back wall (Y=D), slanted front (B->C), flat
        // top/bottom. Extruded across the full width in X (hook/triangle idiom).
        rotate([90, 0, 90])
            linear_extrude(w)
                polygon([[D, 0], [0, 0], [yft, H], [D, H]]);

        // deep blind bore drilled from the top, tilted so the top leans to -Y
        translate([w / 2, y_bot, base])
            rotate([T, 0, 0])
                cylinder(d = bd, h = ci + can_holder_rim / cos(T) + 10, $fn = 96);

        // drain / push-out hole through the base (1.0 "-hole-bottom" variant)
        if (can_holder_bottom == "open")
            translate([w / 2, y_bot, -1])
                cylinder(d = can_holder_drain, h = base + 4, $fn = 64);
    }
}

module can_holder_with_nut () {
    w = can_holder_outer_width();
    D = can_holder_depth();
    H = can_holder_height();

    union () {
        can_holder_body();
        up(H - (frenchfinity_1_0_slot_distance_top * 2))
            back(D)
                nut(w, false);
    }
}

// label lines stacked on the slanted FRONT face, each line placed at the front
// surface's Y for its own height so it engraves flush despite the slant. Sizing
// + centring reuse the shared labels.scad helpers (floor + fit guarantees).
module can_holder_front_labels (lines, z0, z1) {
    n = len(lines);
    if (render_text && n > 0) {
        w      = can_holder_outer_width();
        rheight = z1 - z0;
        rwidth  = w;
        mc     = max([for (s = lines) len(s)]);
        size   = labelSize(n, mc, rheight, rwidth);
        if (size > 0.3 && rheight > 2 * TEXT_MARGIN) {
            pitch = size * TEXT_LINE_K;
            zt    = labelZTop(n, size, rheight, z0);
            for (i = [0 : n - 1])
                let (z = zt - i * pitch)
                    translate([w / 2, can_holder_front_y(z), z])
                        xrot(90)
                            text3d(lines[i], size = size, height = text_depth,
                                   anchor = CENTER);
        }
    }
}

module can_holder_labels_only () {
    w = can_holder_outer_width();
    H = can_holder_height();
    D = can_holder_depth();
    base = can_holder_base();

    lines = [
        final_version_prefix_calculated,
        str("cd", can_holder_can_diameter),
        str("pl", can_holder_padding_left),
        str("ci", can_holder_can_inset),
        str("p",  can_holder_padding)
    ];

    // primary front region (below the opening); spill onto the back wall lower
    // region for parts too small to hold every line at the floor size.
    z0 = base + 2;
    z1 = H - can_holder_rim - 2;
    cap = labelCapacity(z1 - z0);
    n   = len(lines);
    if (n <= cap)
        can_holder_front_labels(lines, z0, z1);
    else {
        n1 = ceil(n / 2);
        can_holder_front_labels([for (i = [0 : n1 - 1]) lines[i]], z0, z1);
        labelFace([for (i = [n1 : n - 1]) lines[i]],
                  ["x", w / 2, D, w, base + 2, H - can_holder_rim - 2]);
    }
}

module can_holder_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        [str("cd", can_holder_can_diameter), str("pl", can_holder_padding_left)],
        [str("ci", can_holder_can_inset), str("p", can_holder_padding)],
        str("hole", can_holder_bottom)
    ]);

    difference () {
        can_holder_with_nut();
        can_holder_labels_only();
    }
}

module feature_can_holder () {
    assert(can_holder_can_diameter > 0, "can_diameter must be > 0");
    assert(can_holder_padding > 0, "padding must be > 0");
    assert(can_holder_can_inset > 0, "can_inset must be > 0");
    assert(can_holder_padding_left >= 0, "padding_left must be >= 0");
    assert(
        can_holder_bottom == "closed" || can_holder_bottom == "open",
        "bottom must be one of: closed, open"
    );

    can_holder_with_nut_and_text();
}
