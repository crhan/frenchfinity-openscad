function hintFileName(labels) =
    let(flat = flattenLabels(labels),
        name = str("frenchfinity_", feature, "_", joinLabels(flat), ".stl"))
    echo("filename proposal:", name)
    flat;

function flattenLabels(arr) =
    [for (item = arr) 
        if (is_list(item)) str(joinLabels(item)) else item];

function joinLabels(labels, i = 0) =
    i >= len(labels)
        ? ""
        : str(labels[i], i < len(labels)-1 ? "_" : "", joinLabels(labels, i + 1));

module labelVertical (text, width_box, y, x = 0) {
    if (render_text) {
        y_rotation = x > 0 ? 180 : 0;

        translate([width_box, x, y])
            xrot(90)
            yrot(y_rotation)
                text3d(text, size=text_size, height=text_depth, anchor=CENTER);
    }
}

// Adaptive vertical label block. Stacks `lines` on a face, centred in the Z
// region [z0, z1], shrinking the glyph size so the whole block always fits the
// region in height AND the face in width. This is what fixes the overflow /
// clipping that the fixed-size labelVertical above suffers on small parts (a
// short part would push the lower lines off the bottom and silently drop them).
// Same font calibration and proven baseline maths as the holder label blocks.
//   x_pos      X position of the (centred) text
//   y_face     Y position of the face (0 = front; > 0 = back, text flipped)
//   face_width available width (X) of the face
//   z0, z1     bottom / top of the Z region the block must stay within
module labelBlockVertical (lines, x_pos, y_face, face_width, z0, z1) {
    if (render_text && len(lines) > 0) {
        n        = len(lines);
        maxchars = max([for (s = lines) len(s)]);
        glyph_k  = 1.1;   // glyph height as a multiple of size (~1.02 measured)
        line_k   = 1.4;   // line pitch as a multiple of size
        char_k   = 0.70;  // glyph advance per char (~0.66 measured)
        margin   = 1.5;
        region_h = z1 - z0;

        size_fit_h = (region_h - 2 * margin) / (glyph_k + (n - 1) * line_k);
        size_fit_w = (face_width - 2 * margin) / (maxchars * char_k);
        size       = min(text_size, size_fit_h, size_fit_w);
        pitch      = size * line_k;
        glyph_h    = size * glyph_k;

        // baseline of the top line; centres the block within [z0, z1]
        ztop = z0 + (region_h - glyph_h + (n - 1) * pitch) / 2;

        for (i = [0 : n - 1])
            translate([x_pos, y_face, ztop - i * pitch])
                xrot(90)
                yrot(y_face > 0 ? 180 : 0)
                    text3d(lines[i], size = size, height = text_depth, anchor = CENTER);
    }
}