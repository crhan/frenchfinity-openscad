//
// Grid (divided storage box)
//
// Restored implementation: frenchfinity.scad wired feature="grid" (include +
// dispatch + [Grid] params) but src/grid.scad was missing from the repo and from
// git history, so the feature was unbuildable. This rebuilds it from the
// Frenchfinity 1.0 "Grid-Holder v5.f3d" surface and the existing box.scad / cleat
// conventions.
//
// 1.0 Fusion user parameters: width, depth, height, rows, columns,
// outer_wall_thickness, inner_wall_thickness (mapped to the grid_* params in
// frenchfinity.scad). 1.0 kept the inner and outer wall thickness SEPARATE, so we
// do too (the previous single grid_wall_thickness lost that distinction).
//
// An open-top box split into rows x columns compartments by inner dividers, with
// the standard frenchfinity cleat tongue on the back, like box.scad.
//

module grid_base () {
    cube([grid_width, grid_depth, grid_height]);
}

// X compartment count = columns; Y compartment count = rows.
function grid_compartment_width () =
    (grid_width  - 2 * grid_outer_wall_thickness
                 - (grid_columns - 1) * grid_inner_wall_thickness) / grid_columns;

function grid_compartment_depth () =
    (grid_depth  - 2 * grid_outer_wall_thickness
                 - (grid_rows - 1) * grid_inner_wall_thickness) / grid_rows;

module grid_compartments () {
    outer = grid_outer_wall_thickness;
    inner = grid_inner_wall_thickness;
    floor = grid_outer_wall_thickness;       // bottom wall thickness
    cw    = grid_compartment_width();
    cd    = grid_compartment_depth();

    for (c = [0 : grid_columns - 1])
        for (r = [0 : grid_rows - 1])
            translate([
                outer + c * (cw + inner),
                outer + r * (cd + inner),
                floor
            ])
                cube([cw, cd, grid_height - floor + 1]);   // +1: open top
}

module empty_grid () {
    difference () {
        grid_base();
        grid_compartments();
    }
}

module empty_grid_with_nut () {
    union () {
        empty_grid();
        // standard frenchfinity cleat tongue at the back, same idiom as box.scad
        up(grid_height - (frenchfinity_1_0_slot_distance_top * 2))
            back(grid_depth)
                nut(grid_width, false);
    }
}

module empty_grid_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        [str("w", grid_width), str("d", grid_depth)],
        [str("h", grid_height), str("r", grid_rows), str("c", grid_columns)]
    ]);

    difference () {
        empty_grid_with_nut();
        // back face below the cleat, never smaller than the 1.0 glyph; spill to
        // the front wall if needed.
        labelLines(labels,
            ["x", grid_width / 2, grid_depth, grid_width, 2, grid_height - 17],
            ["x", grid_width / 2, 0,          grid_width, 2, grid_height - 17]);
    }
}

module feature_grid () {
    assert(grid_width  > 0, "grid_width must be > 0");
    assert(grid_depth  > 0, "grid_depth must be > 0");
    assert(grid_height > 0, "grid_height must be > 0");
    assert(grid_rows    >= 1, "grid_rows must be >= 1");
    assert(grid_columns >= 1, "grid_columns must be >= 1");
    assert(
        grid_compartment_width() > 0,
        "too many columns / walls too thick for grid_width (compartment width <= 0)"
    );
    assert(
        grid_compartment_depth() > 0,
        "too many rows / walls too thick for grid_depth (compartment depth <= 0)"
    );

    empty_grid_with_nut_and_text();
}
