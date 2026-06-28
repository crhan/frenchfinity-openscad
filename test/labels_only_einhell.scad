// Test harness: render ONLY the einhell battery holder's engraved labels.
// NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

text_size      = 5;
text_size_min = 3.5;
text_depth     = 1;
render_text    = true;
version        = 1;
version_prefix = "scad";
final_version_prefix_calculated = str("v", version, version_prefix);

einhell_battery_holder_angle = 20;

include <../src/labels.scad>
include <../src/einhell_battery_holder.scad>

einhell_battery_holder_labels_only();
