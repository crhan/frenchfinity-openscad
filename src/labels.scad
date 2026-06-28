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

// --- Adaptive engraved label blocks -----------------------------------------
//
// Stacks label lines on a face, centred in a Z region, shrinking the glyph size
// so the block fits the region in height AND the face in width. Two guarantees:
//
//   * never smaller than the floor (text_size_min): Frenchfinity 1.0 engraved a
//     fixed ~3.5 mm glyph on every part; shrinking below that is unreadable /
//     unprintable, so we stop there.
//   * never overflow: if the lines do not fit one face at the floor, the overflow
//     half moves to the OPPOSITE face (labelLines with a second face) rather than
//     shrinking further. (Only a part too small even for split 3.5 mm text - the
//     same parts 1.0 could not label either - still overflows.)
//
// A "face" is a descriptor list:
//   X-read (front / back face, text reads along X):  ["x", x_centre, y_face, width, z0, z1]
//     y_face > 0 is a back face and the text is flipped so it still reads right way.
//   Y-read (left / right side wall, text reads along Y): ["y", y_centre, x_face, length, z0, z1, side]
//     side is "right" (+X wall) or "left" (-X wall).

TEXT_GLYPH_K = 1.3;   // glyph height as a multiple of size. Worst case: a line
                      // with an ascender (b,d,h,l) AND an underscore separator
                      // (e.g. "w40_d25") spans ~1.28*size top-to-bottom; using
                      // 1.3 for fitting keeps such lines from overflowing.
TEXT_LINE_K  = 1.5;   // line pitch as a multiple of size (> glyph_k, no overlap)
TEXT_CHAR_K  = 0.70;  // glyph advance per char (~0.66 measured)
TEXT_MARGIN  = 1.5;

// glyph size for n lines of mc chars in a (region_h x region_w) area, clamped
// to [text_size_min, text_size].
function labelSize(n, mc, region_h, region_w) =
    max(text_size_min,
        min(text_size,
            (region_h - 2 * TEXT_MARGIN) / (TEXT_GLYPH_K + (n - 1) * TEXT_LINE_K),
            (region_w - 2 * TEXT_MARGIN) / (mc * TEXT_CHAR_K)));

// how many lines fit a region of height region_h at the floor size.
function labelCapacity(region_h) =
    max(0, floor((region_h - 2 * TEXT_MARGIN - text_size_min * TEXT_GLYPH_K)
                 / (text_size_min * TEXT_LINE_K)) + 1);

// baseline Z of the top line so the block is centred in [z0, z0+region_h].
function labelZTop(n, size, region_h, z0) =
    z0 + (region_h - size * TEXT_GLYPH_K + (n - 1) * size * TEXT_LINE_K) / 2;

// Engrave all `lines` on a single face.
module labelFace (lines, face) {
    n = len(lines);
    if (render_text && n > 0) {
        kind   = face[0];
        z0     = face[4];
        rheight = face[5] - z0;
        rwidth = face[3];
        mc     = max([for (s = lines) len(s)]);
        size   = labelSize(n, mc, rheight, rwidth);

        // Skip degenerate regions (e.g. a part too short to hold any glyph).
        if (size > 0.3 && rheight > 2 * TEXT_MARGIN) {
            pitch = size * TEXT_LINE_K;
            zt    = labelZTop(n, size, rheight, z0);

            for (i = [0 : n - 1])
                if (kind == "x")
                    translate([face[1], face[2], zt - i * pitch])
                        xrot(90)
                        yrot(face[2] > 0 ? 180 : 0)
                            text3d(lines[i], size = size, height = text_depth, anchor = CENTER);
                else
                    translate([face[2], face[1], zt - i * pitch])
                        rotate(face[6] == "right" ? [90, 0, 90] : [90, 0, -90])
                            text3d(lines[i], size = size, height = text_depth * 2, anchor = CENTER);
        }
    }
}

// Engrave `lines` flat on a HORIZONTAL top face (reads along X, lines stacked
// along Y), centred on (x_c, y_c) within a (width x depth) area at height z_top.
// Cuts text_depth down into the surface. Use for parts whose only roomy flat
// area is a top deck (combs / cradles whose vertical walls are too short for
// stacked text). Same floor + fit sizing as labelFace.
module labelTop (lines, x_c, y_c, width, depth, z_top) {
    n = len(lines);
    if (render_text && n > 0) {
        mc   = max([for (s = lines) len(s)]);
        size = labelSize(n, mc, depth, width);
        if (size > 0.3 && depth > 2 * TEXT_MARGIN) {
            pitch = size * TEXT_LINE_K;
            ytop  = y_c + (n - 1) * pitch / 2;     // back line, stack toward -Y
            // sink the glyphs so their TOP sits flush with z_top, cutting down
            for (i = [0 : n - 1])
                translate([x_c, ytop - i * pitch, z_top - text_depth])
                    text3d(lines[i], size = size, height = text_depth * 2, anchor = CENTER);
        }
    }
}

// Engrave `lines`, spilling the overflow half onto faceB when they will not fit
// faceA at the floor size. Pass a single face for no-spill behaviour.
module labelLines (lines, faceA, faceB = undef) {
    n   = len(lines);
    cap = labelCapacity(faceA[5] - faceA[4]);
    if (n <= cap || is_undef(faceB))
        labelFace(lines, faceA);
    else {
        n1 = ceil(n / 2);
        labelFace([for (i = [0 : n1 - 1]) lines[i]], faceA);
        labelFace([for (i = [n1 : n - 1]) lines[i]], faceB);
    }
}