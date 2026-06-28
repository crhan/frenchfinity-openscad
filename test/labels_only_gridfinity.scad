// Test harness: render ONLY the gridfinity adapter's engraved labels.
// NOT part of the model; -D overridable.

include <../lib/BOSL2/std.scad>

text_size      = 5;
text_size_min = 3.5;
text_depth     = 1;
render_text    = true;
version        = 1;
version_prefix = "scad";
final_version_prefix_calculated = str("v", version, version_prefix);

gridfinity_adapter_grid_columns = 3;
gridfinity_adapter_grid_rows    = 3;
gridfinity_adapter_angle        = 10;

include <../src/labels.scad>
include <../src/gridfinity_adapter.scad>

gridfinity_adapter_labels_only();
