// Tests/POS_Reentry_GUI_Calibrate.ks
// Standalone visual calibration tool for the five V/SIT trajectory pages.
//
// Run this while the vessel is idle, not during an active POS flight.  The
// left window is the real reentry trajectory display. The calibration window
// supplies one to ten evenly spaced test dots from each page's lower-left
// axis bound to its upper-right axis bound. Press PRINT VALUES after checking
// the dots and shuttle against the background axes.

set CONFIG:IPU to 2000.

RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").

global step is "reentry_low".
global console_mode is "TRAJ 1 V/SIT".

global cal_page is "TRAJ 1 V/SIT".
global cal_ssto_energy_km is 275.
global cal_ssto_range_km is 900.

// Seed each page from the two KSP-calibrated layouts. Pages 1-3 inherit the
// former upper display and pages 4-5 inherit the former lower display. Each
// page keeps independent values while it is refined in KSP.
global cal_page_settings is lex(
    "TRAJ 1 V/SIT", lex("energy_scale",22.764,"range_scale",0.503,
        "ssto_x",-4.2,"ssto_y",-22.7,"pred_x",2.8,"pred_y",0,
        "ssto_energy",275,"ssto_range",900),
    "TRAJ 2 V/SIT", lex("energy_scale",13.658,"range_scale",0.706,
        "ssto_x",-4.2,"ssto_y",-17.7,"pred_x",2.8,"pred_y",0,
        "ssto_energy",235,"ssto_range",625),
    "TRAJ 3 V/SIT", lex("energy_scale",17.073,"range_scale",0.578,
        "ssto_x",-4.2,"ssto_y",-15.7,"pred_x",2.8,"pred_y",0,
        "ssto_energy",190,"ssto_range",375),
    "TRAJ 4 V/SIT", lex("energy_scale",22.946,"range_scale",1.061,
        "ssto_x",-4.2,"ssto_y",-9.9,"pred_x",2.8,"pred_y",0,
        "ssto_energy",155,"ssto_range",175),
    "TRAJ 5 V/SIT", lex("energy_scale",17.21,"range_scale",1.434,
        "ssto_x",-4.2,"ssto_y",-15.3,"pred_x",2.8,"pred_y",0,
        "ssto_energy",120,"ssto_range",90)
).
// Dot steepness has its own per-page setting; changing it must not move the
// shuttle or change the shuttle's range scale.
for page_settings_name in cal_page_settings:keys {
    local page_settings is cal_page_settings[page_settings_name].
    local page_axes is cal_get_page_axes(page_settings_name).
    set page_settings["dot_range_scale"] to
        (reentry_vsit_chart_plot_bottom()-reentry_vsit_chart_plot_top()) /
        ((page_axes["range_max"]-page_axes["range_min"])/1000).
}
global cal_energy_px_per_km is cal_page_settings[cal_page]["energy_scale"].
global cal_range_px_per_km is cal_page_settings[cal_page]["range_scale"].
global cal_dot_range_px_per_km is cal_page_settings[cal_page]["dot_range_scale"].
global cal_ssto_x_offset is cal_page_settings[cal_page]["ssto_x"].
global cal_ssto_y_offset is cal_page_settings[cal_page]["ssto_y"].
global cal_pred_x_offset is cal_page_settings[cal_page]["pred_x"].
global cal_pred_y_offset is cal_page_settings[cal_page]["pred_y"].
global cal_dot_count is 5.
global cal_refresh_dots_only is false.
global cal_target_coordinate_labels is list().

global cal_ssto_base_x is 0.
global cal_ssto_base_y is 0.
global cal_pred_base_x is 0.
global cal_pred_base_y is 0.
global cal_ssto_final_x is 0.
global cal_ssto_final_y is 0.
global cal_pred_final_x is 0.
global cal_pred_final_y is 0.
global cal_pred_margin_y is 0.
global cal_done is false.

function cal_get_page_axes {
    parameter page_name.
    local energy_min is entry_nominal_traj1_energy_min.
    local energy_max is entry_nominal_traj1_energy_max.
    local range_min is entry_nominal_traj1_range_min.
    local range_max is entry_nominal_traj1_range_max.
    if page_name = "TRAJ 2 V/SIT" {
        set energy_min to entry_nominal_traj2_energy_min.
        set energy_max to entry_nominal_traj2_energy_max.
        set range_min to entry_nominal_traj2_range_min.
        set range_max to entry_nominal_traj2_range_max.
    } else if page_name = "TRAJ 3 V/SIT" {
        set energy_min to entry_nominal_traj3_energy_min.
        set energy_max to entry_nominal_traj3_energy_max.
        set range_min to entry_nominal_traj3_range_min.
        set range_max to entry_nominal_traj3_range_max.
    } else if page_name = "TRAJ 4 V/SIT" {
        set energy_min to entry_nominal_traj4_energy_min.
        set energy_max to entry_nominal_traj4_energy_max.
        set range_min to entry_nominal_traj4_range_min.
        set range_max to entry_nominal_traj4_range_max.
    } else if page_name = "TRAJ 5 V/SIT" {
        set energy_min to entry_nominal_traj5_energy_min.
        set energy_max to entry_nominal_traj5_energy_max.
        set range_min to entry_nominal_traj5_range_min.
        set range_max to entry_nominal_traj5_range_max.
    }
    return lex(
        "energy_min",energy_min,
        "energy_max",energy_max,
        "range_min",range_min,
        "range_max",range_max
    ).
}

function cal_build_prediction_path {
    parameter energy_min, energy_max, range_min, range_max, requested_count.
    local points is list().
    local point_count is max(2, requested_count).
    for point_index in range(0,point_count) {
        local fraction is 0.5.
        if requested_count > 1 {
            set fraction to 1-point_index/(point_count-1).
        }
        local energy is energy_min+(energy_max-energy_min)*fraction.
        local path_range is range_min+(range_max-range_min)*fraction.
        points:add(lex("energy",energy,"range",path_range)).
    }
    return points.
}

function cal_sync_production_calibration {
    local calibration is reentry_traj1_vsit_calibration.
    if cal_page = "TRAJ 2 V/SIT" {
        set calibration to reentry_traj2_vsit_calibration.
    } else if cal_page = "TRAJ 3 V/SIT" {
        set calibration to reentry_traj3_vsit_calibration.
    } else if cal_page = "TRAJ 4 V/SIT" {
        set calibration to reentry_traj4_vsit_calibration.
    } else if cal_page = "TRAJ 5 V/SIT" {
        set calibration to reentry_traj5_vsit_calibration.
    }
    set calibration["energy_px_per_km"] to cal_energy_px_per_km.
    set calibration["range_px_per_km"] to cal_range_px_per_km.
    set calibration["pred_range_px_per_km"] to cal_dot_range_px_per_km.
    set calibration["ssto_x_offset"] to cal_ssto_x_offset.
    set calibration["ssto_y_offset"] to cal_ssto_y_offset.
    set calibration["pred_x_offset"] to cal_pred_x_offset.
    set calibration["pred_y_offset"] to cal_pred_y_offset.
}

function cal_read_number {
    parameter field, fallback.
    return field:text:tonumber(fallback).
}

function cal_update_report {
    set cal_energy_scale_label:text to
        "Energy scale: " + round(cal_energy_px_per_km, 3) + " px per km".
    set cal_dot_steepness_label:text to
        "Dot steepness: " + round(cal_dot_range_px_per_km, 3) + " px per km".
    set cal_ssto_offset_label:text to
        "Shuttle offset:  X " + round(cal_ssto_x_offset, 1) +
        "   Y " + round(cal_ssto_y_offset, 1).
    set cal_pred_offset_label:text to
        "Path offset:     X " + round(cal_pred_x_offset, 1) +
        "   Y " + round(cal_pred_y_offset, 1).
    set cal_dot_count_label:text to "Dots: " + cal_dot_count.

    set cal_ssto_result_label:text to
        "Shuttle final: margin:h=" + round(cal_ssto_final_x, 1) +
        "  padding:top=" + round(cal_ssto_final_y, 1) +
        "  (22 px bug)".
    set cal_pred_result_label:text to
        "Path dots: " + cal_dot_count + " evenly spaced from upper-right to lower-left".
    set cal_absolute_result_label:text to
        "Path first dot: x=" + round(cal_pred_final_x, 1) +
        "  y=" + round(cal_pred_final_y, 1) +
        "  first chart margin=" + round(cal_pred_margin_y, 1).
}

function cal_refresh {
    local axes is cal_get_page_axes(cal_page).
    cal_sync_production_calibration().
    local prediction_points is cal_build_prediction_path(
        axes["energy_min"],axes["energy_max"],
        axes["range_min"],axes["range_max"],cal_dot_count
    ).
    local display_inputs is lex(
        "mode", cal_page,
        // Speed zero makes the production energy calculation return the
        // directly entered energy height as its altitude term.
        "alt", cal_ssto_energy_km * 1000,
        "spd", 0,
        "guid_spd", 0,
        "guid_alt", 0,
        "guid_pos", 0,
        "guid_pos_valid", false,
        // Keep the production updater from laying out calibration markers.
        // The calibration window positions its own dots below.
        "prediction_path", list(),
        "prediction_path_valid", false,
        "range_remaining", cal_ssto_range_km * 1000,
        "pitch", 0,
        "yaw", 0,
        "roll", 0,
        "mach", 0,
        "aoa", 0,
        "l/d", 0
    ).

    // The production GUI also restores the console origin after the fixed
    // chart height, keeping the shuttle and readouts inside the display.
    // Test dots are positioned below
    // from this page's axes so their calibration layout stays independent of
    // the live prediction trace.
    if not cal_refresh_dots_only {
        update_reentry_gui(display_inputs).
    }
    // This calibration view only uses the small entry-path dots. The legacy
    // square guidance marker can be left visible by another GUI mode, so hide
    // it explicitly after every production refresh.
    set traj_disp_pred:visible to false.
    set traj_disp_pred:style:width to 0.
    set traj_disp_pred:style:height to 0.
    set traj_disp_pred:style:padding:top to 0.
    set traj_disp_pred:style:margin:top to 0.
    for lsit_marker in traj_disp_path {
        set lsit_marker:visible to false.
        set lsit_marker:style:width to 0.
        set lsit_marker:style:height to 0.
        set lsit_marker:style:padding:top to 0.
        set lsit_marker:style:margin:top to 0.
    }

    local clamped_energy_km is max(
        axes["energy_min"] / 1000,
        min(axes["energy_max"] / 1000, cal_ssto_energy_km)
    ).
    set cal_ssto_base_x to 50 +
        (clamped_energy_km - axes["energy_min"] / 1000) * cal_energy_px_per_km.
    set cal_ssto_base_y to 140 -
        (cal_ssto_range_km-axes["range_min"] / 1000) * cal_range_px_per_km.
    local first_point is prediction_points[0].
    set cal_pred_base_x to 50 +
        (first_point["energy"]-axes["energy_min"])/1000 * cal_energy_px_per_km.
    set cal_pred_base_y to reentry_vsit_chart_plot_bottom() -
        (first_point["range"]-axes["range_min"])/1000 * cal_dot_range_px_per_km.

    set cal_ssto_final_x to cal_ssto_base_x + cal_ssto_x_offset.
    set cal_ssto_final_y to cal_ssto_base_y + cal_ssto_y_offset.
    set cal_pred_final_x to cal_pred_base_x + cal_pred_x_offset.
    set cal_pred_final_y to cal_pred_base_y + cal_pred_y_offset.
    // Calibration dots use a larger icon than the flight trace, making each
    // sample easy to see while still sharing the production chart coordinates.
    // Dots are children of the fixed chart background. Move their rectangles,
    // keeping image padding zero so the visible area cannot collapse.
    local previous_rect_y is 0.
    local previous_rect_height is 1.
    for marker_index in range(0,traj_disp_prediction_path:length) {
        local marker is traj_disp_prediction_path[marker_index].
        if marker_index < cal_dot_count {
            local point is prediction_points[marker_index].
            local point_x is 50 +
                (point["energy"]-axes["energy_min"])/1000 *
                cal_energy_px_per_km + cal_pred_x_offset.
            local point_y_base is reentry_vsit_chart_plot_bottom() -
                (point["range"]-axes["range_min"])/1000 *
                cal_dot_range_px_per_km.
            local point_y is point_y_base + cal_pred_y_offset.
            set previous_rect_y to place_reentry_vsit_prediction_dot(
                marker_index,point_x,point_y,8,previous_rect_y,previous_rect_height
            ).
            set previous_rect_height to 8.
            local coordinate_label is cal_target_coordinate_labels[marker_index].
            set coordinate_label:text to
                "<size=12>D" + (marker_index+1) +
                " E" + round(point["energy"]/1000,1) +
                " R" + round(point["range"]/1000,1) +
                " X" + round(point_x,1) + " Y" + round(point_y,1) + "</size>".
        } else {
            set marker:visible to false.
            if marker_index < 10 {
                local coordinate_label is cal_target_coordinate_labels[marker_index].
                set coordinate_label:text to "".
            }
        }
    }
    // Report the actual rectangle margin against the fixed chart origin.
    set cal_pred_margin_y to traj_disp_prediction_path[0]:style:margin:top.

    cal_update_report().
}

function cal_apply_fields {
    set cal_ssto_energy_km to cal_read_number(
        cal_ssto_energy_field, cal_ssto_energy_km
    ).
    set cal_ssto_range_km to cal_read_number(
        cal_ssto_range_field, cal_ssto_range_km
    ).
    set cal_page_settings[cal_page]["ssto_energy"] to cal_ssto_energy_km.
    set cal_page_settings[cal_page]["ssto_range"] to cal_ssto_range_km.
    cal_refresh().
}

function cal_page_changed {
    parameter new_page.
    set cal_page to new_page.
    local settings is cal_page_settings[cal_page].
    set cal_energy_px_per_km to settings["energy_scale"].
    set cal_range_px_per_km to settings["range_scale"].
    set cal_dot_range_px_per_km to settings["dot_range_scale"].
    set cal_ssto_x_offset to settings["ssto_x"].
    set cal_ssto_y_offset to settings["ssto_y"].
    set cal_pred_x_offset to settings["pred_x"].
    set cal_pred_y_offset to settings["pred_y"].
    set cal_ssto_energy_km to settings["ssto_energy"].
    set cal_ssto_range_km to settings["ssto_range"].
    set cal_dot_steepness_slider:value to cal_dot_range_px_per_km.
    set cal_energy_scale_slider:value to cal_energy_px_per_km.
    set cal_ssto_x_slider:value to cal_ssto_x_offset.
    set cal_ssto_y_slider:value to cal_ssto_y_offset.
    set cal_pred_x_slider:value to cal_pred_x_offset.
    set cal_pred_y_slider:value to cal_pred_y_offset.
    set cal_ssto_energy_field:text to cal_ssto_energy_km:tostring.
    set cal_ssto_range_field:text to cal_ssto_range_km:tostring.
    cal_refresh().
}

function cal_energy_scale_changed {
    parameter new_value.
    set cal_energy_px_per_km to round(new_value, 3).
    set cal_page_settings[cal_page]["energy_scale"] to cal_energy_px_per_km.
    cal_refresh().
}

function cal_dot_steepness_changed {
    parameter new_value.
    set cal_dot_range_px_per_km to round(new_value, 3).
    set cal_page_settings[cal_page]["dot_range_scale"] to cal_dot_range_px_per_km.
    set cal_refresh_dots_only to true.
    cal_refresh().
    set cal_refresh_dots_only to false.
}

function cal_ssto_x_changed {
    parameter new_value.
    set cal_ssto_x_offset to round(new_value, 1).
    set cal_page_settings[cal_page]["ssto_x"] to cal_ssto_x_offset.
    cal_refresh().
}

function cal_ssto_y_changed {
    parameter new_value.
    set cal_ssto_y_offset to round(new_value, 1).
    set cal_page_settings[cal_page]["ssto_y"] to cal_ssto_y_offset.
    cal_refresh().
}

function cal_pred_x_changed {
    parameter new_value.
    set cal_pred_x_offset to round(new_value, 1).
    set cal_page_settings[cal_page]["pred_x"] to cal_pred_x_offset.
    cal_refresh().
}

function cal_pred_y_changed {
    parameter new_value.
    set cal_pred_y_offset to round(new_value, 1).
    set cal_page_settings[cal_page]["pred_y"] to cal_pred_y_offset.
    // A Y-only adjustment does not need the production display update. Leave
    // the shuttle and widget tree alone to avoid a hide/show flash.
    set cal_refresh_dots_only to true.
    cal_refresh().
    set cal_refresh_dots_only to false.
}

function cal_dot_count_changed {
    parameter new_value.
    set cal_dot_count to max(1,min(10,round(new_value))).
    set cal_dot_count_slider:value to cal_dot_count.
    cal_refresh().
}

function cal_reset_offsets {
    set cal_ssto_x_offset to 0.
    set cal_ssto_y_offset to 0.
    set cal_pred_x_offset to 0.
    set cal_pred_y_offset to 0.
    set cal_page_settings[cal_page]["ssto_x"] to 0.
    set cal_page_settings[cal_page]["ssto_y"] to 0.
    set cal_page_settings[cal_page]["pred_x"] to 0.
    set cal_page_settings[cal_page]["pred_y"] to 0.
    set cal_ssto_x_slider:value to 0.
    set cal_ssto_y_slider:value to 0.
    set cal_pred_x_slider:value to 0.
    set cal_pred_y_slider:value to 0.
    cal_refresh().
}

function cal_print_values {
    print "".
    print "--- POS V/SIT PATH CALIBRATION ---".
    print "Page: " + cal_page.
    print "Shuttle: E=" + cal_ssto_energy_km + " km  RNG=" +
        cal_ssto_range_km + " km".
    print "Path dots: " + cal_dot_count + " evenly spaced from the page's " +
        "maximum energy/range to its minimum energy/range.".
    print "Energy scale: " + round(cal_energy_px_per_km, 3) + " px per km".
    print "RNG scale: " + round(cal_range_px_per_km, 3) + " px per km".
    print "Dot steepness: " + round(cal_dot_range_px_per_km, 3) + " px per km".
    print "Shuttle offset: X=" + round(cal_ssto_x_offset, 1) +
        " Y=" + round(cal_ssto_y_offset, 1).
    print "Path offset:    X=" + round(cal_pred_x_offset, 1) +
        " Y=" + round(cal_pred_y_offset, 1).
    print "Shuttle style: margin:h=" + round(cal_ssto_final_x, 1) +
        " padding:top=" + round(cal_ssto_final_y, 1).
    print "Path first dot: x=" + round(cal_pred_final_x, 1) +
        " y=" + round(cal_pred_final_y, 1) +
        " first chart margin:top=" + round(cal_pred_margin_y, 1).
    print "-------------------------------".
}

// Open only the production trajectory console, without starting reentry or
// changing vehicle controls.
global reentry_gui is GUI(800, 430).
set reentry_gui:style:width to 800.
reentry_gui:show().
create_reentry_gui().

global calibration_gui is GUI(520, 900).
set calibration_gui:style:width to 520.

local cal_title is calibration_gui:addlabel(
    "<size=20><b>V/SIT PATH CALIBRATION</b></size>"
).
set cal_title:style:align to "center".

local cal_help is calibration_gui:addlabel(
    "Left window shows the shuttle and 1-10 test dots, evenly spaced from " +
    "each page's upper-right axis limit to its lower-left limit."
).

local page_row is calibration_gui:addhlayout().
page_row:addlabel("Display page").
global cal_page_menu is page_row:addpopupmenu().
cal_page_menu:addoption("TRAJ 1 V/SIT").
cal_page_menu:addoption("TRAJ 2 V/SIT").
cal_page_menu:addoption("TRAJ 3 V/SIT").
cal_page_menu:addoption("TRAJ 4 V/SIT").
cal_page_menu:addoption("TRAJ 5 V/SIT").
// Real kOS requires VALUE to receive the exact encapsulated option object.
// Selecting by index avoids a System.String -> Structure cast failure.
set cal_page_menu:index to 0.
set cal_page_menu:onchange to cal_page_changed@.

calibration_gui:addlabel("<b>Shuttle graph values</b>").
local ssto_energy_row is calibration_gui:addhlayout().
ssto_energy_row:addlabel("Energy height (km)").
global cal_ssto_energy_field is
    ssto_energy_row:addtextfield(cal_ssto_energy_km:tostring).
local ssto_range_row is calibration_gui:addhlayout().
ssto_range_row:addlabel("RNG (km)").
global cal_ssto_range_field is
    ssto_range_row:addtextfield(cal_ssto_range_km:tostring).

calibration_gui:addlabel("<b>Test path dots</b>").
global cal_dot_count_label is calibration_gui:addlabel("Dots: 5").
local dot_count_row is calibration_gui:addhlayout().
dot_count_row:addlabel("1").
global cal_dot_count_slider is dot_count_row:addhslider(cal_dot_count, 1, 10).
dot_count_row:addlabel("10 dots").
set cal_dot_count_slider:onchange to cal_dot_count_changed@.

calibration_gui:addlabel("<b>Target dots: energy/range km, chart X/Y px</b>").
for coordinate_row_index in range(0,5) {
    local coordinate_row is calibration_gui:addhlayout().
    local first_coordinate_label is coordinate_row:addlabel("").
    local second_coordinate_label is coordinate_row:addlabel("").
    cal_target_coordinate_labels:add(first_coordinate_label).
    cal_target_coordinate_labels:add(second_coordinate_label).
}

local apply_values_button is calibration_gui:addbutton("APPLY DISPLAY VALUES").
set apply_values_button:onclick to cal_apply_fields@.

calibration_gui:addlabel("<b>Energy horizontal scale</b>").
global cal_energy_scale_label is calibration_gui:addlabel("").
local energy_scale_row is calibration_gui:addhlayout().
energy_scale_row:addlabel("0.5").
global cal_energy_scale_slider is energy_scale_row:addhslider(
    cal_energy_px_per_km, 0.5, 30
).
energy_scale_row:addlabel("30 px / km").
set cal_energy_scale_slider:onchange to cal_energy_scale_changed@.

calibration_gui:addlabel("<b>Dot line steepness (dots only)</b>").
global cal_dot_steepness_label is calibration_gui:addlabel("").
local range_scale_row is calibration_gui:addhlayout().
range_scale_row:addlabel("0.05").
global cal_dot_steepness_slider is range_scale_row:addhslider(
    cal_dot_range_px_per_km, 0.05, 2
).
range_scale_row:addlabel("2 px / km").
set cal_dot_steepness_slider:onchange to cal_dot_steepness_changed@.

calibration_gui:addlabel("<b>Shuttle bug (22 px)</b>").
global cal_ssto_offset_label is calibration_gui:addlabel("").
local ssto_x_row is calibration_gui:addhlayout().
ssto_x_row:addlabel("X  -80").
global cal_ssto_x_slider is ssto_x_row:addhslider(cal_ssto_x_offset, -80, 80).
ssto_x_row:addlabel("+80").
local ssto_y_row is calibration_gui:addhlayout().
ssto_y_row:addlabel("Y  -80").
global cal_ssto_y_slider is ssto_y_row:addhslider(cal_ssto_y_offset, -80, 80).
ssto_y_row:addlabel("+80").
set cal_ssto_x_slider:onchange to cal_ssto_x_changed@.
set cal_ssto_y_slider:onchange to cal_ssto_y_changed@.

calibration_gui:addlabel("<b>Calibration path dots (8 px each)</b>").
global cal_pred_offset_label is calibration_gui:addlabel("").
local pred_x_row is calibration_gui:addhlayout().
pred_x_row:addlabel("X  -80").
global cal_pred_x_slider is pred_x_row:addhslider(cal_pred_x_offset, -80, 80).
pred_x_row:addlabel("+80").
local pred_y_row is calibration_gui:addhlayout().
pred_y_row:addlabel("All dots UP -400").
global cal_pred_y_slider is pred_y_row:addhslider(cal_pred_y_offset, -400, 400).
pred_y_row:addlabel("+400 DOWN").
set cal_pred_x_slider:onchange to cal_pred_x_changed@.
set cal_pred_y_slider:onchange to cal_pred_y_changed@.

global cal_ssto_result_label is calibration_gui:addlabel("").
global cal_pred_result_label is calibration_gui:addlabel("").
global cal_absolute_result_label is calibration_gui:addlabel("").

local button_row is calibration_gui:addhlayout().
local reset_button is button_row:addbutton("RESET OFFSETS").
local print_button is button_row:addbutton("PRINT VALUES").
local close_button is button_row:addbutton("CLOSE").
set reset_button:onclick to cal_reset_offsets@.
set print_button:onclick to cal_print_values@.
set close_button:onclick to { set cal_done to true. }.

calibration_gui:show().
cal_refresh().

until cal_done {
    wait 0.1.
}

calibration_gui:dispose().
reentry_gui:dispose().
print "V/SIT path calibration closed.".
