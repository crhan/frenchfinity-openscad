// Test harness: exercise the shared adaptive labelBlockVertical directly with a
// configurable line count and region, so the overflow fix used by every author
// component (box / french_plate / screw_plate / wall_anchor / screw_driver) is
// guarded. test_labels_fit.py checks the engraved block stays inside the region.
// NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

text_size   = 5;
render_text = true;
text_depth  = 1;

// region / layout parameters (overridable via -D)
lb_n     = 5;    // number of lines
lb_z0    = 2;    // region bottom (Z)
lb_z1    = 40;   // region top (Z)
lb_fw    = 30;   // face width (X)
lb_xpos  = 0;    // X centre
lb_yface = 0;    // Y face

include <../src/labels.scad>

lines = [for (i = [0 : lb_n - 1]) str("ln", i, "_abcd")];
labelBlockVertical(lines, lb_xpos, lb_yface, lb_fw, lb_z0, lb_z1);
