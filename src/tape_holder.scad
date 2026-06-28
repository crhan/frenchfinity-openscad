//
// Tape holder
//
// Reverse engineered from the Frenchfinity 1.0 "Tape Holder" (13 STLs).
// Functional + key-dimension port. Fusion user parameters:
//
//   tape_width       (tw)   -> roll width; sets the slot: dx = tw + 20
//   max_tape_diameter(matd) -> full roll OD; sets the cradle curve and depth
//   min_tape_diameter(mitd) -> empty roll OD; (height/headroom reference)
//   rest_diameter    (rd)   -> the central SPINDLE ROD the roll turns on
//
// Verified against the 13 STLs (tools/stl_analyze.py) + the 1.0 iso/side renders:
//   dx = tape_width + 20            (R^2 = 1.0, exact: roll slot + 10mm walls)
//   dy = max_tape_diameter + 20.88  (R^2 = 1.0, fits the full roll OD + cleat)
//   dz ~= 0.5*max_tape_diameter + 11
//
// Shape (the earlier port was just a scooped box with NO rod -- non-functional):
// two tall end walls (horns) flank a tw-wide slot; a concave cradle (radius
// ~matd/2) is scooped into the slot so the roll nests; a thin SPINDLE ROD of
// diameter rest_diameter bridges the slot through the roll's core so the roll
// spins. The lower block carries the cleat at +Y (back) and the labels on the
// -Y (front) face.
//

tape_holder_wall = 10;   // end wall each side of the roll (X): dx = tw + 20
tape_holder_back = 10;   // back wall depth behind the roll (Y) before the cleat

function tape_holder_outer_width () =
    tape_holder_tape_width + 2 * tape_holder_wall;

function tape_holder_body_depth () =
    tape_holder_max_tape_diameter + tape_holder_back;

function tape_holder_outer_height () =
    0.5 * tape_holder_max_tape_diameter + 11;

module tape_holder_body () {
    w     = tape_holder_outer_width();
    d     = tape_holder_body_depth();
    h     = tape_holder_outer_height();
    tw    = tape_holder_tape_width;
    wall  = tape_holder_wall;
    matd  = tape_holder_max_tape_diameter;
    seat  = matd / 2;                       // cradle radius = full roll OD/2
    yc    = matd / 2;                       // roll centre Y (front of roll at Y=0)
    zc    = h - 6;                          // roll/rod centre Z (just below back horn)
    hf    = h - 14;                         // front edge height (wedge slopes down)

    union () {
        difference () {
            // wedge body: tall at the back (cleat), sloping down to a low front,
            // extruded across the full width (Y=0 front, Y=d back).
            rotate([90, 0, 90])
                linear_extrude(w)
                    polygon([[0, 0], [d, 0], [d, h], [d * 0.65, h], [0, hf]]);
            // concave cradle scooped into the slot only, so the end walls stay
            // tall as horns; the roll nests in the valley.
            translate([wall, yc, zc])
                rotate([0, 90, 0])
                    cylinder(r = seat, h = tw, $fn = 160);
            // open the slot top so the roll drops in / sticks out
            translate([wall, -1, zc])
                cube([tw, d + 2, seat + h]);
        }
        // central spindle rod the roll core turns on, bridging the slot
        translate([wall, yc, zc])
            rotate([0, 90, 0])
                cylinder(d = tape_holder_rest_diameter, h = tw, $fn = 48);
    }
}

module tape_holder_with_nut () {
    w = tape_holder_outer_width();
    d = tape_holder_body_depth();
    h = tape_holder_outer_height();

    union () {
        tape_holder_body();
        up(h - (frenchfinity_1_0_slot_distance_top * 2))
            back(d)
                nut(w, false);
    }
}

module tape_holder_labels_only () {
    w  = tape_holder_outer_width();
    d  = tape_holder_body_depth();
    h  = tape_holder_outer_height();
    hf = h - 14;                            // front (wedge) face height

    // Engrave on the low front (X-read, faces -Y, no flip), spilling onto the
    // left end-wall outer face (Y-read) since the back face carries the cleat.
    labelLines(
        [
            final_version_prefix_calculated,
            str("tw",   tape_holder_tape_width),
            str("matd", tape_holder_max_tape_diameter),
            str("mitd", tape_holder_min_tape_diameter),
            str("rd",   tape_holder_rest_diameter)
        ],
        ["x", w / 2, 0, w, 2, hf - 2],
        ["y", d / 2, text_depth, d, 2, hf - 2, "left"]
    );
}

module tape_holder_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        [str("tw", tape_holder_tape_width), str("matd", tape_holder_max_tape_diameter)],
        [str("mitd", tape_holder_min_tape_diameter), str("rd", tape_holder_rest_diameter)]
    ]);

    difference () {
        tape_holder_with_nut();
        tape_holder_labels_only();
    }
}

module feature_tape_holder () {
    assert(tape_holder_tape_width > 0, "tape_width must be > 0");
    assert(tape_holder_max_tape_diameter > 0, "max_tape_diameter must be > 0");
    assert(tape_holder_min_tape_diameter > 0, "min_tape_diameter must be > 0");
    assert(
        tape_holder_min_tape_diameter <= tape_holder_max_tape_diameter,
        "min_tape_diameter must be <= max_tape_diameter"
    );

    tape_holder_with_nut_and_text();
}
