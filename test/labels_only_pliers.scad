// Test harness: render ONLY the pliers holder's engraved labels, as solids.
// test_labels_fit.py checks that this geometry stays inside the part so the
// labels can never overflow again. NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

// --- the few globals the label path reads (normally set in frenchfinity.scad) ---
text_size      = 5;
render_text    = true;
version        = 1;
version_prefix = "scad";
final_version_prefix_calculated = str("v", version, version_prefix);

pliers_holder_height        = 80;
pliers_holder_hole_diameter = 18;

// Only the label modules are exercised here; nut()/hintFileName() are not reached.
include <../src/pliers_holder.scad>

pliers_holder_labels_only();
