// Test harness: render ONLY the tape holder's engraved labels, as solids.
// NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

text_size      = 5;
text_size_min = 3.5;
text_depth     = 1;
render_text    = true;
version        = 1;
version_prefix = "scad";
final_version_prefix_calculated = str("v", version, version_prefix);

tape_holder_tape_width        = 20;
tape_holder_max_tape_diameter = 65;
tape_holder_min_tape_diameter = 45;
tape_holder_rod_diameter      = 4;

include <../src/labels.scad>
include <../src/tape_holder.scad>

tape_holder_labels_only();
