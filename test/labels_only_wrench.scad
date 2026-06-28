// Test harness: render ONLY the wrench holder's engraved labels, as solids.
// NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

text_size      = 5;
text_size_min = 3.5;
text_depth     = 1;
render_text    = true;
version        = 1;
version_prefix = "scad";
final_version_prefix_calculated = str("v", version, version_prefix);

wrench_holder_width        = 40;
wrench_holder_wrench_width = 8;
wrench_holder_scale        = 1;

include <../src/labels.scad>
include <../src/wrench_holder.scad>

wrench_holder_labels_only();
