// Test harness: render ONLY the hook's engraved labels, as solids.
// test_labels_fit.py checks that this geometry stays inside the shank face so
// the labels can never overflow. NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

// --- the few globals the label path reads (normally set in frenchfinity.scad) ---
text_size      = 5;
text_size_min = 3.5;
text_depth     = 1;
render_text    = true;
version        = 1;
version_prefix = "scad";
final_version_prefix_calculated = str("v", version, version_prefix);

hook_width      = 20;
hook_height     = 80;
hook_diameter   = 34;
hook_thickness  = 6;
hook_end_height = 10;

// Only the label modules are exercised here; nut()/hintFileName() are not reached.
include <../src/labels.scad>
include <../src/hook.scad>

hook_labels_only();
