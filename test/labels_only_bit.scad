// Test harness: render ONLY the bit holder's engraved labels, as solids.
// NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

text_size      = 5;
text_size_min = 3.5;
text_depth     = 1;
render_text    = true;
version        = 1;
version_prefix = "scad";
final_version_prefix_calculated = str("v", version, version_prefix);

bit_holder_rows          = 1;
bit_holder_columns       = 1;
bit_holder_hole_diameter = 10;
bit_holder_hole_padding  = 10;
bit_holder_angle         = 30;
bit_holder_height        = 20;

include <../src/labels.scad>
include <../src/bit_holder.scad>

bit_holder_labels_only();
