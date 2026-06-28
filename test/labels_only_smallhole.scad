// Test harness: render ONLY the small hole holder's engraved labels, as solids.
// NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

text_size      = 5;
text_size_min = 3.5;
text_depth     = 1;
render_text    = true;
version        = 1;
version_prefix = "scad";
final_version_prefix_calculated = str("v", version, version_prefix);

small_hole_holder_hole_width  = 6;
small_hole_holder_hole_length = 8;
small_hole_holder_tool_width  = 20;

include <../src/labels.scad>
include <../src/small_hole_holder.scad>

small_hole_holder_labels_only();
