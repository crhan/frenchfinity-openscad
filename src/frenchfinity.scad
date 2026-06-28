include <../lib/BOSL2/std.scad>

//
// Parameters
//
//

/* [Feature] */
feature = "wall_anchor"; //[box, can_holder, einhell_battery_holder, french_plate, grid, gridfinity_adapter, hammer_holder, hook, pliers_holder, rectangular_tool_holder, round_hanging_holder, screw_plate, screw_driver, small_hole_holder, wall_anchor, wrench_holder]

/* [Wall anchor] */
wall_anchor_height                = 60;
wall_anchor_width                 = 100;
wall_anchor_depth                 = 20;
wall_anchor_bottom_angle          = 45;
wall_anchor_render_screw_holes    = true;
wall_anchor_screw_thread_diameter = 2;
wall_anchor_screw_head_height     = 2;
wall_anchor_screw_head_diameter   = 4.3;
wall_anchor_screw_distance        = 30;

/* [French plate] */
french_plate_width                = 100;
french_plate_height               = 100;
french_plate_depth                = 20;

/* [Screw plate] */
screw_plate_width                 = 160;
screw_plate_height                = 100;
screw_plate_depth                 = 20;
screw_plate_screw_thread_diameter = 4;
screw_plate_screw_head_diameter   = 8;
screw_plate_screw_head_height     = 4;
screw_plate_screw_hole_padding    = 40;

/* [Screwdriver] */
screwdriver_bottom_height = 10;
screwdriver_handle_width  = 26;
screwdriver_padding_sides = 10;
screwdriver_padding_top   = 40;
screwdriver_stick_width   = 18;
screwdriver_inset_height  = 10;

/* [Rectangular tool holder] */
// Width of the rectangular tool that is held (tw)
rectangular_tool_holder_tool_width  = 20;
// Length of the tool / usable channel length (tl)
rectangular_tool_holder_tool_length = 60;
// How deep the tool sinks into the channel (tsh)
rectangular_tool_holder_tool_slot_height = 10;
// Width of the front opening and the bottom push-out slot (hhw)
rectangular_tool_holder_hole_width  = 8;
rectangular_tool_holder_hole_position = "center"; //[left, center, right]

/* [Can holder] */
// Diameter of the can / tube the holder cradles (cd)
can_holder_can_diameter = 10;
// Wall around the bore; width = cd + 2*padding (p)
can_holder_padding      = 10;
// How deep the can sits, along the tilted axis (ci)
can_holder_can_inset    = 55;
// Extra back / base material (pl)
can_holder_padding_left = 16;
// Bottom drain / push-out hole (1.0 "-hole-bottom" variant)
can_holder_bottom       = "closed"; //[closed, open]

/* [Einhell battery holder] */
// How far the battery cradle leans back from vertical (a)
einhell_battery_holder_angle = 20;

/* [Gridfinity adapter] */
// Gridfinity cells across the width (gc)
gridfinity_adapter_grid_columns = 3;
// Gridfinity cells up the tilted bed (gr)
gridfinity_adapter_grid_rows = 3;
// Bed tilt knob; bed leans ~2*angle from horizontal (a)
gridfinity_adapter_angle = 10;

/* [Hammer holder] */
// Overall width / back plate width (w)
hammer_holder_width                  = 100;
// Front-to-back size of the head seat (hw)
hammer_holder_hammer_width           = 36;
// Central channel the handle hangs through (hhw)
hammer_holder_handle_hole_width      = 38;
// Front lip height that stops the head sliding off (dph)
hammer_holder_drop_protection_height = 5;
// Front lip thickness (dpw)
hammer_holder_drop_protection_width  = 3;

/* [Hook] */
// Width of the hook bar (w)
hook_width           = 20;
// Overall height, top of shank to the cleat (h)
hook_height          = 80;
// Outer diameter of the J bend (hd)
hook_diameter        = 34;
// Thickness of the hook bar (t)
hook_thickness       = 6;
// How far the upturned tip rises past the bend centre (heh)
hook_end_height      = 10;

/* [Pliers holder] */
// Overall height of the holder (h); the body grows downward as this grows
pliers_holder_height        = 80;
// Width of the central slot cavity that grips the pliers (hd)
pliers_holder_hole_diameter = 18;

/* [Round hanging holder] */
// Diameter of the round tool that is cradled (td)
round_hanging_holder_tool_diameter     = 39;
// Length of the cradle trough along the tool axis (hd)
round_hanging_holder_holder_depth      = 21;
// Width of the slot under the trough, the push-out / hang-through opening (bhw)
round_hanging_holder_bottom_hole_width = 20;
// How deep the tool seats into the back wall (id)
round_hanging_holder_inset_depth       = 3;

/* [Small hole holder] */
// Width of the rectangular tool hole (hw)
small_hole_holder_hole_width  = 6;
// Length of the rectangular tool hole (hl)
small_hole_holder_hole_length = 8;
// Drives the plate height = tool_width + 5 (tw)
small_hole_holder_tool_width  = 20;

/* [Wrench holder] */
// Length of the rack out from the wall; more length = more slots (w)
wrench_holder_width        = 40;
// Width of a wrench slot, the gap between comb teeth (ww)
wrench_holder_wrench_width = 8;
// Scales the rack cross-section (width & height) (s)
wrench_holder_scale        = 1;

/* [Box] */
box_width          = 50;
box_depth          = 30;
box_height         = 60;
box_wall_thickness = 2;

/* [Grid] */
grid_width = 200;
grid_depth = 50;
grid_height = 60;
grid_rows = 4;
grid_columns = 4;
// 1.0 keeps the outer shell and inner divider thicknesses separate
grid_outer_wall_thickness = 2;
grid_inner_wall_thickness = 2;

/* [Frenchfinity 1.0 slot] */
frenchfinity_1_0_slot_inner_height     = 8.5;
frenchfinity_1_0_slot_inner_width      = 4.5;
// You may have to set this to 6.6 or 6.5 to generate wall anchors compatible to legacy frenchfinity parts
frenchfinity_1_0_slot_outer_width      = 5.6;
frenchfinity_1_0_slot_outer_height     = 6.5;
frenchfinity_1_0_slot_distance_top     = 7.394;
// Fit clearance between a male tongue and a female groove. The tongue is shrunk
// by this much so the printed parts actually slide together. 0.25 matches the
// Frenchfinity 1.0 fit; raise it for a looser fit, lower it for a tighter one.
frenchfinity_1_0_slot_tolerance        = 0.25;

/* [Miscellaneous] */
filament_hole_size = 1.70;

/* [Text] */
render_text = true;
text_depth  = 1;
text_size   = 5;
// Smallest engraved glyph we allow. Frenchfinity 1.0 used a fixed ~3.5 mm glyph
// on every part (measured from the 1.0 STLs); going below that is unreadable and
// hard to print. Labels shrink only down to this floor, then overflow lines move
// to the opposite face instead of shrinking further.
text_size_min = 3.5;


/* [Versioning] */
version        = 1;
version_prefix = "scad";

//
// Helper variables (usually end with "_calculated")
//

frenchfinity_1_0_slot_total_width_calculated = frenchfinity_1_0_slot_inner_width + frenchfinity_1_0_slot_outer_width;
frenchfinity_1_0_slot_total_height_calculated = frenchfinity_1_0_slot_outer_height;
final_version_prefix_calculated= str("v", version, version_prefix);

//
// Base imports
//

include <labels.scad>
include <nuts.scad>
include <rounded_corners.scad>
include <screws.scad>

//
// Features
//

include <box.scad>
include <can_holder.scad>
include <einhell_battery_holder.scad>
include <french_plate.scad>
include <grid.scad>
include <gridfinity_adapter.scad>
include <hammer_holder.scad>
include <hook.scad>
include <pliers_holder.scad>
include <rectangular_tool_holder.scad>
include <round_hanging_holder.scad>
include <screw_driver.scad>
include <screw_plate.scad>
include <small_hole_holder.scad>
include <wall_anchor.scad>
include <wrench_holder.scad>











//
// Selected feature
//

module render_selected_feature () {
    if (feature == "box")          feature_box();
    if (feature == "can_holder")   feature_can_holder();
    if (feature == "einhell_battery_holder") feature_einhell_battery_holder();
    if (feature == "french_plate") feature_french_plate();
    if (feature == "grid")         feature_grid();
    if (feature == "gridfinity_adapter") feature_gridfinity_adapter();
    if (feature == "hammer_holder") feature_hammer_holder();
    if (feature == "hook")         feature_hook();
    if (feature == "pliers_holder") feature_pliers_holder();
    if (feature == "rectangular_tool_holder") feature_rectangular_tool_holder();
    if (feature == "round_hanging_holder") feature_round_hanging_holder();
    if (feature == "screw_plate")  feature_screw_plate();
    if (feature == "screw_driver") feature_screw_driver();
    if (feature == "small_hole_holder") feature_small_hole_holder();
    if (feature == "wall_anchor")  feature_wall_anchor();
    if (feature == "wrench_holder") feature_wrench_holder();
}

render_selected_feature();
