// Test harness: render ONLY the round hanging holder's engraved labels, as
// solids. test_labels_fit.py checks that this geometry stays inside the front
// wall so the labels can never overflow. NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

// --- the few globals the label path reads (normally set in frenchfinity.scad) ---
text_size      = 5;
render_text    = true;
version        = 1;
version_prefix = "scad";
final_version_prefix_calculated = str("v", version, version_prefix);

round_hanging_holder_tool_diameter     = 39;
round_hanging_holder_holder_depth      = 21;
round_hanging_holder_bottom_hole_width = 20;
round_hanging_holder_inset_depth       = 3;

// Only the label modules are exercised here; nut()/hintFileName() are not reached.
include <../src/round_hanging_holder.scad>

round_hanging_holder_labels_only();
