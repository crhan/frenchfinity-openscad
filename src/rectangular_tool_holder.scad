//
// Rectangular tool holder
//
// Reverse engineered from the Frenchfinity 1.0 Fusion 360 model
// "Rectangular-Tool-Holder v24.f3d". The original exposed these Fusion user
// parameters (kept here as the public parameters, see frenchfinity.scad):
//
//   tool_width       (tw)  -> width of the rectangular tool that is held
//   tool_length      (tl)  -> length of the tool / usable channel length
//   tool_slot_height (tsh) -> how deep the tool sinks into the channel
//   holder_hole_width(hhw) -> width of the front opening AND the bottom slot
//
// hole_position (left|center|right) is NOT a 1.0 user parameter: the 1.0 model
// shipped three separate STL exports (...-hole-center/-left/-right). 2.0 folds
// those three exports into a single enum parameter.
//
// Geometry (verified against the original STLs, see report):
//   - the body is a tool_width wide channel, open at the top and at the front,
//     closed at the back by a cross wall that also carries the french cleat
//   - side walls are 5 mm, the channel is tool_slot_height deep
//   - a holder_hole_width wide slot runs through the base and narrows the front
//     opening, so the slim part of a tool can stick out the front / bottom while
//     the body rests in the channel
//   - the back carries the standard frenchfinity nut() tongue, just like box.scad
//
// Note on orientation: like box.scad the cleat sits at the +Y (back) end, which
// is the mirror of the 1.0 export (cleat at -Y). "center" is identical; for
// "left"/"right" the hole is defined in this part's own frame.
//

// Fixed structural constants (absolute, derived from the 1.0 model: dx=tw+10,
// dy=tl+20.88, dz=tsh+15 with R^2 = 1.0 across every reference STL).
rectangular_tool_holder_side_wall   = 5;  // left / right walls (X)
rectangular_tool_holder_end_wall    = 5;  // back cross wall and front lip depth (Y)
rectangular_tool_holder_base_below  = 15; // material below the channel floor (Z)

function rectangular_tool_holder_outer_width() =
    rectangular_tool_holder_tool_width + (rectangular_tool_holder_side_wall * 2);

function rectangular_tool_holder_outer_length() =
    rectangular_tool_holder_tool_length + (rectangular_tool_holder_end_wall * 2);

function rectangular_tool_holder_outer_height() =
    rectangular_tool_holder_tool_slot_height + rectangular_tool_holder_base_below;

// X position of the through hole. "center" matches the 1.0 model exactly; for
// "left" / "right" the 1.0 Fusion model shrank the hole width (a sketch
// constraint artifact) - here the hole keeps its full holder_hole_width and is
// pushed flush against the corresponding channel wall instead.
function rectangular_tool_holder_hole_x() =
    let(
        w        = rectangular_tool_holder_outer_width(),
        wall     = rectangular_tool_holder_side_wall,
        hhw      = rectangular_tool_holder_hole_width
    )
    rectangular_tool_holder_hole_position == "left"  ? wall :
    rectangular_tool_holder_hole_position == "right" ? w - wall - hhw :
                                                       (w - hhw) / 2;

module rectangular_tool_holder_base () {
    w            = rectangular_tool_holder_outer_width();
    l            = rectangular_tool_holder_outer_length();
    h            = rectangular_tool_holder_outer_height();
    wall         = rectangular_tool_holder_side_wall;
    end          = rectangular_tool_holder_end_wall;
    tsh          = rectangular_tool_holder_tool_slot_height;
    hhw          = rectangular_tool_holder_hole_width;
    channel_floor= h - tsh;
    hole_x       = rectangular_tool_holder_hole_x();

    difference () {
        cube([w, l, h]);

        // tool channel: open at the top, full tool width, between the front lip
        // and the back cross wall.
        translate([wall, end, channel_floor])
            cube([
                rectangular_tool_holder_tool_width,
                rectangular_tool_holder_tool_length,
                tsh + 1
            ]);

        // the hole: a single holder_hole_width slot that runs from the open
        // front to the cross wall over the full height. Below the channel floor
        // it is the bottom push-out slot, at channel height it narrows the front
        // opening down to holder_hole_width (the front retaining lip).
        translate([hole_x, -1, -1])
            cube([hhw, (l - end) + 1, h + 2]);
    }
}

module rectangular_tool_holder_with_nut () {
    w = rectangular_tool_holder_outer_width();
    l = rectangular_tool_holder_outer_length();
    h = rectangular_tool_holder_outer_height();

    union () {
        rectangular_tool_holder_base();

        // standard frenchfinity cleat tongue at the back, same idiom as box.scad
        up(h - (frenchfinity_1_0_slot_distance_top * 2))
            back(l)
                nut(w, false);
    }
}

module rectangular_tool_holder_with_nut_and_text () {
    w      = rectangular_tool_holder_outer_width();
    l      = rectangular_tool_holder_outer_length();
    h      = rectangular_tool_holder_outer_height();
    labels = hintFileName([
        final_version_prefix_calculated,
        [
            str("tw", rectangular_tool_holder_tool_width),
            str("tl", rectangular_tool_holder_tool_length)
        ],
        [
            str("tsh", rectangular_tool_holder_tool_slot_height),
            str("hhw", rectangular_tool_holder_hole_width)
        ],
        str("hole", rectangular_tool_holder_hole_position)
    ]);

    // Lay the labels out so the whole block always fits inside the part height
    // (real holders are only ~20-25 mm tall, so the box.scad fixed step would
    // push the last - and most important - line off the bottom). The pitch
    // shrinks for short parts and the block is centred vertically.
    count = len(labels);
    pitch = count > 1 ? min(7, (h - text_size) / (count - 1)) : 0;
    top   = (h + (count - 1) * pitch) / 2;

    difference () {
        rectangular_tool_holder_with_nut();

        for (i = [0 : count - 1])
            labelVertical(
                labels[i],
                w / 2,
                top - i * pitch,
                l
            );
    }
}

module feature_rectangular_tool_holder () {
    // Fail loudly on inputs that would silently produce junk instead of a usable
    // part (a negative/zero size, or a hole so wide it eats the side walls).
    assert(rectangular_tool_holder_tool_width  > 0, "tool_width must be > 0");
    assert(rectangular_tool_holder_tool_length > 0, "tool_length must be > 0");
    assert(rectangular_tool_holder_tool_slot_height > 0, "tool_slot_height must be > 0");
    assert(rectangular_tool_holder_hole_width  > 0, "hole_width must be > 0");
    assert(
        rectangular_tool_holder_hole_width <= rectangular_tool_holder_tool_width,
        "hole_width must be <= tool_width (otherwise the hole cuts through the side walls)"
    );
    assert(
        rectangular_tool_holder_hole_position == "left"  ||
        rectangular_tool_holder_hole_position == "center" ||
        rectangular_tool_holder_hole_position == "right",
        "hole_position must be one of: left, center, right"
    );

    rectangular_tool_holder_with_nut_and_text();
}
