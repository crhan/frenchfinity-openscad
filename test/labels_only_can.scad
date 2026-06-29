// Test harness: render ONLY the can holder's engraved labels, as solids.
// NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

text_size      = 5;
text_size_min = 3.5;
text_depth     = 1;
render_text    = true;
version        = 1;
version_prefix = "scad";
final_version_prefix_calculated = str("v", version, version_prefix);

can_holder_can_diameter = 10;
can_holder_padding      = 10;
can_holder_can_inset    = 55;
can_holder_padding_left = 16;
can_holder_angle        = 10;
can_holder_bottom       = "closed";

include <../src/labels.scad>
include <../src/can_holder.scad>

can_holder_labels_only();
