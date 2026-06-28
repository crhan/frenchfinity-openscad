// Test harness: exercise the shared adaptive labelFace directly with a
// configurable line count and region, so the floor + fit logic used by every
// component is guarded. test_labels_fit.py checks the engraved block stays
// inside the region (when it fits at the floor) and never shrinks below the
// floor. NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

text_size     = 5;
text_size_min = 3.5;
render_text   = true;
text_depth    = 1;

// region / layout parameters (overridable via -D)
lb_n     = 5;    // number of lines
lb_z0    = 2;    // region bottom (Z)
lb_z1    = 40;   // region top (Z)
lb_fw    = 30;   // face width (X)
lb_xpos  = 0;    // X centre
lb_yface = 0;    // Y face

include <../src/labels.scad>

lines = [for (i = [0 : lb_n - 1]) str("ln", i, "_ab")];
labelFace(lines, ["x", lb_xpos, lb_yface, lb_fw, lb_z0, lb_z1]);
