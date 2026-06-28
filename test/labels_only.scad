// Test harness: render ONLY the rectangular tool holder's engraved labels, as
// solids. The test (test_labels_fit.py) checks that this geometry stays inside
// the part, so the labels can never overflow the part again.
//
// This is NOT part of the model. Parameters are overridable via -D.

include <../lib/BOSL2/std.scad>

// --- the few globals the label path reads (normally set in frenchfinity.scad) ---
text_size      = 5;
render_text    = true;
version        = 1;
version_prefix = "scad";
final_version_prefix_calculated = str("v", version, version_prefix);

rectangular_tool_holder_tool_width       = 20;
rectangular_tool_holder_tool_length      = 60;
rectangular_tool_holder_tool_slot_height = 10;
rectangular_tool_holder_hole_width       = 8;
rectangular_tool_holder_hole_position    = "center";

// Only the label modules are exercised here; the nut()/hintFileName() calls in
// the other modules are never reached, so their includes are not needed.
include <../src/rectangular_tool_holder.scad>

rectangular_tool_holder_labels_only();
