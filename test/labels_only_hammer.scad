// Test harness: render ONLY the hammer holder's engraved labels, as solids.
// NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

text_size      = 5;
text_size_min = 3.5;
text_depth     = 1;
render_text    = true;
version        = 1;
version_prefix = "scad";
final_version_prefix_calculated = str("v", version, version_prefix);

hammer_holder_width                  = 100;
hammer_holder_hammer_width           = 36;
hammer_holder_handle_hole_width      = 38;
hammer_holder_drop_protection_height = 5;
hammer_holder_drop_protection_width  = 3;

include <../src/labels.scad>
include <../src/hammer_holder.scad>

hammer_holder_labels_only();
