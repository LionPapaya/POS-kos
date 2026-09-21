// Tests/POS_Reentry_GUI_Calibrate.ks
// Standalone visual calibration tool for the two V/SIT trajectory bugs.
//
// Run this while the vessel is idle, not during an active POS flight.  The
// left window is the real reentry trajectory display.  The second window
// supplies synthetic display values and independent screen-space offsets for
// the shuttle and green reference bugs.  Press PRINT VALUES when the two bugs
// are visually aligned and send the resulting terminal block back to the
// maintainer.

set CONFIG:IPU to 2000.

RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").

global step is "reentry_low".
global console_mode is "TRAJ 1 V/SIT".

global cal_page is "TRAJ 1 V/SIT".
global cal_ssto_energy_km is 225.
global cal_ssto_range_km is 400.
global cal_pred_range_km is 400.

// Production currently maps each page's complete RNG span over 220 pixels.
// Keep separate page values so calibrating one page does not alter the other.
global cal_traj1_range_px_per_km is
    220 / (entry_nominal_traj1_range_max / 1000).
global cal_traj2_range_px_per_km is
    220 / (entry_nominal_traj2_range_max / 1000).
global cal_range_px_per_km is cal_traj1_range_px_per_km.
global cal_traj1_energy_px_per_km is 650 /
    ((entry_nominal_traj1_energy_max - entry_nominal_traj1_energy_min) / 1000).
global cal_traj2_energy_px_per_km is 650 /
    ((entry_nominal_traj2_energy_max - entry_nominal_traj2_energy_min) / 1000).
global cal_energy_px_per_km is cal_traj1_energy_px_per_km.

global cal_ssto_x_offset is 0.
global cal_ssto_y_offset is 0.
global cal_pred_x_offset is 0.
global cal_pred_y_offset is 0.

global cal_ssto_base_x is 0.
global cal_ssto_base_y is 0.
global cal_pred_base_x is 0.
global cal_pred_base_y is 0.
global cal_ssto_final_x is 0.
global cal_ssto_final_y is 0.
global cal_pred_final_x is 0.
global cal_pred_final_y is 0.
global cal_pred_padding_y is 0.
global cal_done is false.

function cal_read_number {
    parameter field, fallback.
    return field:text:tonumber(fallback).
}

function cal_update_report {
    set cal_energy_scale_label:text to
        "Energy scale: " + round(cal_energy_px_per_km, 3) + " px per km".
    set cal_range_scale_label:text to
        "RNG scale: " + round(cal_range_px_per_km, 3) + " px per km".
    set cal_ssto_offset_label:text to
        "Shuttle offset:  X " + round(cal_ssto_x_offset, 1) +
        "   Y " + round(cal_ssto_y_offset, 1).
    set cal_pred_offset_label:text to
        "Green offset:    X " + round(cal_pred_x_offset, 1) +
        "   Y " + round(cal_pred_y_offset, 1).

    set cal_ssto_result_label:text to
        "Shuttle final: margin:h=" + round(cal_ssto_final_x, 1) +
        "  padding:top=" + round(cal_ssto_final_y, 1) +
        "  (22 px bug)".
    set cal_pred_result_label:text to
        "Green final: margin:h=" + round(cal_pred_final_x, 1) +
        "  padding:top=" + round(cal_pred_padding_y, 1) +
        "  (8 px bug)".
    set cal_absolute_result_label:text to
        "Plot Y: shuttle=" + round(cal_ssto_final_y, 1) +
        "  green=" + round(cal_pred_final_y, 1) +
        "  (green padding is relative)".
}

function cal_refresh {
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
        "range_remaining", cal_ssto_range_km * 1000,
        "pitch", 0,
        "yaw", 0,
        "roll", 0,
        "mach", 0,
        "aoa", 0,
        "l/d", 0
    ).

    // First let the production GUI update its labels, background, and bugs.
    update_reentry_gui(display_inputs).

    // Repeat the production coordinate calculation so the offsets remain
    // explicit and can be copied directly into gui.ks after calibration.
    local page_energy_min is entry_nominal_traj1_energy_min.
    local page_energy_max is entry_nominal_traj1_energy_max.
    if cal_page = "TRAJ 2 V/SIT" {
        set page_energy_min to entry_nominal_traj2_energy_min.
        set page_energy_max to entry_nominal_traj2_energy_max.
    }

    local clamped_energy_km is max(
        page_energy_min / 1000,
        min(page_energy_max / 1000, cal_ssto_energy_km)
    ).
    set cal_ssto_base_x to 50 +
        (clamped_energy_km - page_energy_min / 1000) * cal_energy_px_per_km.
    set cal_ssto_base_y to 140 -
        cal_ssto_range_km * cal_range_px_per_km.
    set cal_pred_base_x to cal_ssto_base_x.
    set cal_pred_base_y to 140 -
        cal_pred_range_km * cal_range_px_per_km.

    set cal_ssto_final_x to cal_ssto_base_x + cal_ssto_x_offset.
    set cal_ssto_final_y to cal_ssto_base_y + cal_ssto_y_offset.
    set cal_pred_final_x to cal_pred_base_x + cal_pred_x_offset.
    set cal_pred_final_y to cal_pred_base_y + cal_pred_y_offset.

    set traj_disp_ssto:style:margin:h to cal_ssto_final_x.
    set traj_disp_ssto:style:padding:top to cal_ssto_final_y.
    set traj_disp_pred:style:margin:h to cal_pred_final_x.

    // The widgets are children of the same vbox.  Therefore the reference
    // bug needs a delta from the shifted shuttle Y, even though its slider is
    // presented as an independent absolute screen translation.
    set cal_pred_padding_y to cal_pred_final_y - cal_ssto_final_y.
    set traj_disp_pred:style:padding:top to cal_pred_padding_y.

    cal_update_report().
}

function cal_apply_fields {
    set cal_ssto_energy_km to cal_read_number(
        cal_ssto_energy_field, cal_ssto_energy_km
    ).
    set cal_ssto_range_km to cal_read_number(
        cal_ssto_range_field, cal_ssto_range_km
    ).
    set cal_pred_range_km to cal_read_number(
        cal_pred_range_field, cal_pred_range_km
    ).
    cal_refresh().
}

function cal_page_changed {
    parameter new_page.
    set cal_page to new_page.
    if cal_page = "TRAJ 1 V/SIT" {
        set cal_range_px_per_km to cal_traj1_range_px_per_km.
        set cal_energy_px_per_km to cal_traj1_energy_px_per_km.
    } else {
        set cal_range_px_per_km to cal_traj2_range_px_per_km.
        set cal_energy_px_per_km to cal_traj2_energy_px_per_km.
    }
    set cal_range_scale_slider:value to cal_range_px_per_km.
    set cal_energy_scale_slider:value to cal_energy_px_per_km.
    cal_refresh().
}

function cal_energy_scale_changed {
    parameter new_value.
    set cal_energy_px_per_km to round(new_value, 3).
    if cal_page = "TRAJ 1 V/SIT" {
        set cal_traj1_energy_px_per_km to cal_energy_px_per_km.
    } else {
        set cal_traj2_energy_px_per_km to cal_energy_px_per_km.
    }
    cal_refresh().
}

function cal_range_scale_changed {
    parameter new_value.
    set cal_range_px_per_km to round(new_value, 3).
    if cal_page = "TRAJ 1 V/SIT" {
        set cal_traj1_range_px_per_km to cal_range_px_per_km.
    } else {
        set cal_traj2_range_px_per_km to cal_range_px_per_km.
    }
    cal_refresh().
}

function cal_ssto_x_changed {
    parameter new_value.
    set cal_ssto_x_offset to round(new_value, 1).
    cal_refresh().
}

function cal_ssto_y_changed {
    parameter new_value.
    set cal_ssto_y_offset to round(new_value, 1).
    cal_refresh().
}

function cal_pred_x_changed {
    parameter new_value.
    set cal_pred_x_offset to round(new_value, 1).
    cal_refresh().
}

function cal_pred_y_changed {
    parameter new_value.
    set cal_pred_y_offset to round(new_value, 1).
    cal_refresh().
}

function cal_reset_offsets {
    set cal_ssto_x_offset to 0.
    set cal_ssto_y_offset to 0.
    set cal_pred_x_offset to 0.
    set cal_pred_y_offset to 0.
    set cal_ssto_x_slider:value to 0.
    set cal_ssto_y_slider:value to 0.
    set cal_pred_x_slider:value to 0.
    set cal_pred_y_slider:value to 0.
    cal_refresh().
}

function cal_print_values {
    print "".
    print "--- POS V/SIT BUG CALIBRATION ---".
    print "Page: " + cal_page.
    print "Shuttle: E=" + cal_ssto_energy_km + " km  RNG=" +
        cal_ssto_range_km + " km".
    print "Guidance RNG=" + cal_pred_range_km + " km".
    print "Energy scale: " + round(cal_energy_px_per_km, 3) + " px per km".
    print "RNG scale: " + round(cal_range_px_per_km, 3) + " px per km".
    print "Shuttle offset: X=" + round(cal_ssto_x_offset, 1) +
        " Y=" + round(cal_ssto_y_offset, 1).
    print "Green offset:   X=" + round(cal_pred_x_offset, 1) +
        " Y=" + round(cal_pred_y_offset, 1).
    print "Shuttle style: margin:h=" + round(cal_ssto_final_x, 1) +
        " padding:top=" + round(cal_ssto_final_y, 1).
    print "Green style:   margin:h=" + round(cal_pred_final_x, 1) +
        " padding:top=" + round(cal_pred_padding_y, 1).
    print "-------------------------------".
}

// Open only the production trajectory console, without starting reentry or
// changing vehicle controls.
global reentry_gui is GUI(800, 430).
set reentry_gui:style:width to 800.
reentry_gui:show().
create_reentry_gui().

global calibration_gui is GUI(520, 700).
set calibration_gui:style:width to 520.

local cal_title is calibration_gui:addlabel(
    "<size=20><b>V/SIT BUG CALIBRATION</b></size>"
).
set cal_title:style:align to "center".

local cal_help is calibration_gui:addlabel(
    "Enter graph E and RNG directly in km. Adjust RNG scale first, " +
    "then use X/Y offsets for final alignment."
).

local page_row is calibration_gui:addhlayout().
page_row:addlabel("Display page").
global cal_page_menu is page_row:addpopupmenu().
cal_page_menu:addoption("TRAJ 1 V/SIT").
cal_page_menu:addoption("TRAJ 2 V/SIT").
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

calibration_gui:addlabel("<b>Green guidance graph value</b>").
local pred_range_row is calibration_gui:addhlayout().
pred_range_row:addlabel("RNG (km)").
global cal_pred_range_field is
    pred_range_row:addtextfield(cal_pred_range_km:tostring).

local apply_values_button is calibration_gui:addbutton("APPLY DISPLAY VALUES").
set apply_values_button:onclick to cal_apply_fields@.

calibration_gui:addlabel("<b>Energy horizontal scale</b>").
global cal_energy_scale_label is calibration_gui:addlabel("").
local energy_scale_row is calibration_gui:addhlayout().
energy_scale_row:addlabel("0.5").
global cal_energy_scale_slider is energy_scale_row:addhslider(
    cal_energy_px_per_km, 0.5, 15
).
energy_scale_row:addlabel("15 px / km").
set cal_energy_scale_slider:onchange to cal_energy_scale_changed@.

calibration_gui:addlabel("<b>RNG vertical scale</b>").
global cal_range_scale_label is calibration_gui:addlabel("").
local range_scale_row is calibration_gui:addhlayout().
range_scale_row:addlabel("0.05").
global cal_range_scale_slider is range_scale_row:addhslider(
    cal_range_px_per_km, 0.05, 1.2
).
range_scale_row:addlabel("1.2 px / km").
set cal_range_scale_slider:onchange to cal_range_scale_changed@.

calibration_gui:addlabel("<b>Shuttle bug (22 px)</b>").
global cal_ssto_offset_label is calibration_gui:addlabel("").
local ssto_x_row is calibration_gui:addhlayout().
ssto_x_row:addlabel("X  -80").
global cal_ssto_x_slider is ssto_x_row:addhslider(0, -80, 80).
ssto_x_row:addlabel("+80").
local ssto_y_row is calibration_gui:addhlayout().
ssto_y_row:addlabel("Y  -80").
global cal_ssto_y_slider is ssto_y_row:addhslider(0, -80, 80).
ssto_y_row:addlabel("+80").
set cal_ssto_x_slider:onchange to cal_ssto_x_changed@.
set cal_ssto_y_slider:onchange to cal_ssto_y_changed@.

calibration_gui:addlabel("<b>Green reference bug (8 px)</b>").
global cal_pred_offset_label is calibration_gui:addlabel("").
local pred_x_row is calibration_gui:addhlayout().
pred_x_row:addlabel("X  -80").
global cal_pred_x_slider is pred_x_row:addhslider(0, -80, 80).
pred_x_row:addlabel("+80").
local pred_y_row is calibration_gui:addhlayout().
pred_y_row:addlabel("Y  -80").
global cal_pred_y_slider is pred_y_row:addhslider(0, -80, 80).
pred_y_row:addlabel("+80").
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
print "V/SIT bug calibration closed.".
