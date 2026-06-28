// Test harness: render ONLY the triangle top holder's engraved labels, as solids.
// NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

text_size      = 5;
text_size_min = 3.5;
text_depth     = 1;
render_text    = true;
version        = 1;
version_prefix = "scad";
final_version_prefix_calculated = str("v", version, version_prefix);

triangle_top_holder_tool_width      = 35;
triangle_top_holder_tool_depth      = 17.5;
triangle_top_holder_holder_height   = 100;
triangle_top_holder_triangle_height = 25;

include <../src/labels.scad>
include <../src/triangle_top_holder.scad>

triangle_top_holder_labels_only();
