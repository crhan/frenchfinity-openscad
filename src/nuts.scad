module frenchfinity_1_0_nut(width, include_filament_hole) {
    // Fit tolerance: a male tongue must be slightly smaller than the female
    // groove it slides into, otherwise the printed parts jam (identical CAD
    // sizes + FDM over-extrusion = interference). In this codebase the male
    // tongue is always built with include_filament_hole == false and the female
    // groove with == true, so we shrink only the tongue. The groove keeps its
    // nominal size, which also keeps it cross-compatible with Frenchfinity 1.0
    // parts (1.0's tongue is ~0.25 mm smaller than its groove as well).
    tolerance = include_filament_hole ? 0 : frenchfinity_1_0_slot_tolerance;

    outer_width  = frenchfinity_1_0_slot_outer_width;
    inner_width  = frenchfinity_1_0_slot_inner_width;
    outer_height = frenchfinity_1_0_slot_outer_height;
    inner_height = frenchfinity_1_0_slot_inner_height;

    module filament_hole () {
        yrot(90)
        translate([
            outer_height / -2,
            (inner_width + outer_width),
            width / 2
        ])
        cylinder(d=filament_hole_size, h=width, center=true, $fn=100);
    }

    module basic_nut () {
        // Outer block (mouth side). The body-side face stays at Y = 0 (it is
        // buried in the holder body), the two Z faces are inset by tolerance/2.
        translate([0, 0, tolerance / 2])
        cube([
            width,
            outer_width,
            outer_height - tolerance,
        ]);
        // Inner block (the locking head). Inset on its far Y face and both Z
        // faces, kept centred in Z, so it clears the groove all the way round.
        translate([
            0,
            outer_width,
            ((outer_height - inner_height) / 2) + (tolerance / 2)
        ])
        cube([
            width,
            inner_width - tolerance,
            inner_height - tolerance,
        ]);
    }

    module final_basic_nut () {
        if (include_filament_hole) {
            union() {
                basic_nut();
                filament_hole();
            }
        } else {
            difference() {
                basic_nut();
                filament_hole();
            }
        }
    }

    final_basic_nut();
}

module nut(width, include_filament_hole) {
    module selected_nut () {
        // TODO: Add support for different nuts
        frenchfinity_1_0_nut(width, include_filament_hole);
    }

    if (!include_filament_hole) {
            selected_nut();
    }
    else {
            selected_nut();
    }
}
