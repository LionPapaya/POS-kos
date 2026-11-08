// Tests/POS_M2L_LSIT_GUI_Calibrate.ks
// Local-only visual calibration tool for the M2L / L/SIT displays.
//
// Run while the vessel is idle. The left window is the production reentry
// console. The right window selects L/SIT 1 or 2, one of the eight rotated
// shuttle bug images, and either that shuttle bug or the page-wide green
// reference bug. Each page/rotation keeps independent shuttle X/Y offsets.
// PRINT ALL writes the complete mapping for copying back into gui.ks.

set CONFIG:IPU to 2000.

RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").

// gui.ks normally receives this helper from the active Poseidon flight
// program. The standalone utility supplies the identical implementation.
function normalized_heading_error {
    parameter target_heading, current_heading.
    local heading_error is target_heading - current_heading.
    until abs(heading_error) <= 180 {
        if heading_error > 180 {
            set heading_error to heading_error - 360.
        }
        if heading_error < -180 {
            set heading_error to heading_error + 360.
        }
    }
    return heading_error.
}

global step is "calibration".
global console_mode is "L/SIT 1".

global lsit_cal_page is "L/SIT 1".
global lsit_cal_rotation is "0".
global lsit_cal_target is "SHUTTLE".
global lsit_cal_shuttle_along_m is 175000.
global lsit_cal_shuttle_cross_m is 0.
global lsit_cal_green_along_m is 175000.
global lsit_cal_green_cross_m is 0.
global lsit_cal_done is false.
global lsit_cal_output_root is "0:/POS_calibration".
global lsit_cal_output_file is
    lsit_cal_output_root + "/lsit_bug_calibration.csv".

// The synthetic runway only supplies geopositions to the production
// reentry_lsit_screen_position() function. No duplicate screen mapping lives
// in this tool.
global runway_start is LATLNG(0, 0).
global runway_heading is 90.

function lsit_cal_rotation_settings {
    return lex(
        "0", lex("x",0,"y",0),
        "45", lex("x",0,"y",0),
        "90", lex("x",0,"y",0),
        "135", lex("x",0,"y",0),
        "180", lex("x",0,"y",0),
        "225", lex("x",0,"y",0),
        "270", lex("x",0,"y",0),
        "315", lex("x",0,"y",0)
    ).
}

global lsit_cal_settings is lex(
    "L/SIT 1", lex(
        "shuttle", lsit_cal_rotation_settings(),
        "green", lex("x",0,"y",0)
    ),
    "L/SIT 2", lex(
        "shuttle", lsit_cal_rotation_settings(),
        "green", lex("x",0,"y",0)
    )
).

global lsit_cal_x_offset is 0.
global lsit_cal_y_offset is 0.
global lsit_cal_shuttle_final_x is 0.
global lsit_cal_shuttle_final_y is 0.
global lsit_cal_green_final_x is 0.
global lsit_cal_green_final_y is 0.
global lsit_cal_green_padding_y is 0.

function lsit_cal_read_number {
    parameter field, fallback.
    return field:text:tonumber(fallback).
}

function lsit_cal_target_settings {
    if lsit_cal_target = "GREEN REFERENCE" {
        return lsit_cal_settings[lsit_cal_page]["green"].
    }
    return lsit_cal_settings[lsit_cal_page]["shuttle"][lsit_cal_rotation].
}

function lsit_cal_max_along {
    if lsit_cal_page = "L/SIT 1" { return 350000. }
    return 50000.
}

function lsit_cal_max_cross {
    if lsit_cal_page = "L/SIT 1" { return 150000. }
    return 20000.
}

function lsit_cal_geoposition {
    parameter along_track_m, cross_track_m.
    local centerline_position is get_geoposition_along_heading(
        runway_start, runway_heading + 180, along_track_m
    ).
    return get_geoposition_along_heading(
        centerline_position, runway_heading + 90, cross_track_m
    ).
}

function lsit_cal_load_target {
    local settings is lsit_cal_target_settings().
    set lsit_cal_x_offset to settings["x"].
    set lsit_cal_y_offset to settings["y"].
    set lsit_cal_x_slider:value to lsit_cal_x_offset.
    set lsit_cal_y_slider:value to lsit_cal_y_offset.
    set lsit_cal_x_field:text to lsit_cal_x_offset:tostring.
    set lsit_cal_y_field:text to lsit_cal_y_offset:tostring.
}

function lsit_cal_update_report {
    local active_rotation is lsit_cal_rotation + " deg".
    if lsit_cal_target = "GREEN REFERENCE" {
        set active_rotation to "PAGE-WIDE".
    }
    set lsit_cal_active_label:text to
        "<size=18><b>ACTIVE: " + lsit_cal_page + " | " +
        lsit_cal_target + " | ROT " + active_rotation + "</b></size>".
    set lsit_cal_offset_label:text to
        "Selected offset: X " + round(lsit_cal_x_offset, 1) +
        "   Y " + round(lsit_cal_y_offset, 1).
    set lsit_cal_result_label:text to
        "Shuttle absolute: X " + round(lsit_cal_shuttle_final_x, 1) +
        "  Y " + round(lsit_cal_shuttle_final_y, 1) +
        " | Green absolute: X " + round(lsit_cal_green_final_x, 1) +
        "  Y " + round(lsit_cal_green_final_y, 1).
    set lsit_cal_padding_label:text to
        "GUI styles: shuttle padding:top=" +
        round(lsit_cal_shuttle_final_y, 1) +
        " | green relative padding:top=" +
        round(lsit_cal_green_padding_y, 1).
}

function lsit_cal_refresh {
    local max_along_track is lsit_cal_max_along().
    local max_cross_track is lsit_cal_max_cross().

    set console_titel:text to
        "<size=20><b>" + lsit_cal_page + " CALIBRATION</b></size>".
    if lsit_cal_page = "L/SIT 1" {
        set traj_disp_mainbox:style:bg to
            "Libraries/gui_images/traj3_lsit_bg.png".
    } else {
        set traj_disp_mainbox:style:bg to
            "Libraries/gui_images/traj4_lsit_bg.png".
    }

    set traj_disp_ssto:image to
        "Libraries/gui_images/ssto_lsit_" + lsit_cal_rotation + ".png".
    set traj_disp_ssto:style:margin:top to 0.
    set traj_disp_ssto:visible to true.
    set traj_disp_pred:visible to true.
    hide_reentry_lsit_path().

    local shuttle_position is reentry_lsit_screen_position(
        lsit_cal_geoposition(
            lsit_cal_shuttle_along_m, lsit_cal_shuttle_cross_m
        ),
        max_along_track,
        max_cross_track
    ).
    local green_position is reentry_lsit_screen_position(
        lsit_cal_geoposition(
            lsit_cal_green_along_m, lsit_cal_green_cross_m
        ),
        max_along_track,
        max_cross_track
    ).

    local shuttle_offsets is
        lsit_cal_settings[lsit_cal_page]["shuttle"][lsit_cal_rotation].
    local green_offsets is lsit_cal_settings[lsit_cal_page]["green"].
    set lsit_cal_shuttle_final_x to
        shuttle_position["x"] + shuttle_offsets["x"].
    set lsit_cal_shuttle_final_y to
        shuttle_position["y"] + shuttle_offsets["y"].
    set lsit_cal_green_final_x to
        green_position["x"] + green_offsets["x"].
    set lsit_cal_green_final_y to
        green_position["y"] + green_offsets["y"].

    // This is the same cumulative-vbox convention used by update_reentry_gui:
    // the green widget receives a delta from the shuttle's absolute Y.
    set lsit_cal_green_padding_y to
        lsit_cal_green_final_y - lsit_cal_shuttle_final_y.
    set traj_disp_ssto:style:margin:h to lsit_cal_shuttle_final_x.
    set traj_disp_ssto:style:padding:top to lsit_cal_shuttle_final_y.
    set traj_disp_pred:style:margin:h to lsit_cal_green_final_x.
    set traj_disp_pred:style:padding:top to lsit_cal_green_padding_y.

    set traj_data_pitch:text to
        "S ATK " + round(lsit_cal_shuttle_along_m / 1000, 1) + " km".
    set traj_data_yaw:text to
        "S XTK " + round(lsit_cal_shuttle_cross_m / 1000, 1) + " km".
    set traj_data_roll:text to
        "G ATK " + round(lsit_cal_green_along_m / 1000, 1) + " km".
    set traj_data_mach:text to
        "G XTK " + round(lsit_cal_green_cross_m / 1000, 1) + " km".
    set traj_data_aoa:text to "ROT " + lsit_cal_rotation + " deg".
    set traj_data_ld:text to "TARGET " + lsit_cal_target.

    lsit_cal_update_report().
}

function lsit_cal_store_offsets {
    local settings is lsit_cal_target_settings().
    set settings["x"] to lsit_cal_x_offset.
    set settings["y"] to lsit_cal_y_offset.
}

function lsit_cal_apply_fields {
    set lsit_cal_shuttle_along_m to lsit_cal_read_number(
        lsit_cal_shuttle_along_field, lsit_cal_shuttle_along_m
    ).
    set lsit_cal_shuttle_cross_m to lsit_cal_read_number(
        lsit_cal_shuttle_cross_field, lsit_cal_shuttle_cross_m
    ).
    set lsit_cal_green_along_m to lsit_cal_read_number(
        lsit_cal_green_along_field, lsit_cal_green_along_m
    ).
    set lsit_cal_green_cross_m to lsit_cal_read_number(
        lsit_cal_green_cross_field, lsit_cal_green_cross_m
    ).
    set lsit_cal_x_offset to lsit_cal_read_number(
        lsit_cal_x_field, lsit_cal_x_offset
    ).
    set lsit_cal_y_offset to lsit_cal_read_number(
        lsit_cal_y_field, lsit_cal_y_offset
    ).
    lsit_cal_store_offsets().
    set lsit_cal_x_slider:value to lsit_cal_x_offset.
    set lsit_cal_y_slider:value to lsit_cal_y_offset.
    lsit_cal_refresh().
}

function lsit_cal_page_changed {
    parameter new_page.
    set lsit_cal_page to new_page.
    if lsit_cal_page = "L/SIT 1" {
        set lsit_cal_shuttle_along_m to 175000.
        set lsit_cal_green_along_m to 175000.
    } else {
        set lsit_cal_shuttle_along_m to 25000.
        set lsit_cal_green_along_m to 25000.
    }
    set lsit_cal_shuttle_along_field:text to
        lsit_cal_shuttle_along_m:tostring.
    set lsit_cal_green_along_field:text to
        lsit_cal_green_along_m:tostring.
    lsit_cal_load_target().
    lsit_cal_refresh().
}

function lsit_cal_rotation_changed {
    parameter new_rotation.
    set lsit_cal_rotation to new_rotation.
    lsit_cal_load_target().
    lsit_cal_refresh().
}

function lsit_cal_target_changed {
    parameter new_target.
    set lsit_cal_target to new_target.
    lsit_cal_load_target().
    lsit_cal_refresh().
}

function lsit_cal_x_changed {
    parameter new_value.
    set lsit_cal_x_offset to round(new_value, 1).
    lsit_cal_store_offsets().
    set lsit_cal_x_field:text to lsit_cal_x_offset:tostring.
    lsit_cal_refresh().
}

function lsit_cal_y_changed {
    parameter new_value.
    set lsit_cal_y_offset to round(new_value, 1).
    lsit_cal_store_offsets().
    set lsit_cal_y_field:text to lsit_cal_y_offset:tostring.
    lsit_cal_refresh().
}

function lsit_cal_reset_selected {
    set lsit_cal_x_offset to 0.
    set lsit_cal_y_offset to 0.
    lsit_cal_store_offsets().
    set lsit_cal_x_slider:value to 0.
    set lsit_cal_y_slider:value to 0.
    set lsit_cal_x_field:text to "0".
    set lsit_cal_y_field:text to "0".
    lsit_cal_refresh().
}

function lsit_cal_print_current {
    print "".
    print "--- POS M2L / L-SIT CURRENT CALIBRATION ---".
    print "Page: " + lsit_cal_page.
    print "Target: " + lsit_cal_target +
        " | rotation=" + lsit_cal_rotation + " deg".
    print "Offset: X=" + round(lsit_cal_x_offset, 1) +
        " Y=" + round(lsit_cal_y_offset, 1).
    print "Shuttle absolute: X=" + round(lsit_cal_shuttle_final_x, 1) +
        " Y=" + round(lsit_cal_shuttle_final_y, 1).
    print "Green absolute: X=" + round(lsit_cal_green_final_x, 1) +
        " Y=" + round(lsit_cal_green_final_y, 1).
    print "-------------------------------------------".
}

function lsit_cal_log_current {
    // LOG appends. Create the header only for a new file so rerunning the
    // utility preserves earlier calibration records instead of replacing them.
    if not exists(lsit_cal_output_root) {
        createdir(lsit_cal_output_root).
    }
    if not exists(lsit_cal_output_file) {
        log "page,target,rotation_deg,offset_x_px,offset_y_px,shuttle_along_m,shuttle_cross_m,green_along_m,green_cross_m,shuttle_final_x_px,shuttle_final_y_px,green_final_x_px,green_final_y_px,green_relative_padding_y_px"
            to lsit_cal_output_file.
    }
    local record_rotation is lsit_cal_rotation.
    if lsit_cal_target = "GREEN REFERENCE" {
        set record_rotation to "page-wide".
    }
    log lsit_cal_page + "," + lsit_cal_target + "," + record_rotation +
        "," + round(lsit_cal_x_offset, 1) +
        "," + round(lsit_cal_y_offset, 1) +
        "," + round(lsit_cal_shuttle_along_m, 1) +
        "," + round(lsit_cal_shuttle_cross_m, 1) +
        "," + round(lsit_cal_green_along_m, 1) +
        "," + round(lsit_cal_green_cross_m, 1) +
        "," + round(lsit_cal_shuttle_final_x, 1) +
        "," + round(lsit_cal_shuttle_final_y, 1) +
        "," + round(lsit_cal_green_final_x, 1) +
        "," + round(lsit_cal_green_final_y, 1) +
        "," + round(lsit_cal_green_padding_y, 1)
        to lsit_cal_output_file.
    set lsit_cal_log_status_label:text to
        "LOGGED (append): " + lsit_cal_page + " | " +
        lsit_cal_target + " | ROT " + record_rotation +
        " | X " + round(lsit_cal_x_offset, 1) +
        " Y " + round(lsit_cal_y_offset, 1).
}

function lsit_cal_print_all {
    print "".
    print "--- POS M2L / L-SIT COMPLETE CALIBRATION ---".
    for page_name in list("L/SIT 1", "L/SIT 2") {
        print page_name + " GREEN: X=" +
            round(lsit_cal_settings[page_name]["green"]["x"], 1) +
            " Y=" + round(
                lsit_cal_settings[page_name]["green"]["y"], 1
            ).
        for rotation_name in list(
            "0", "45", "90", "135", "180", "225", "270", "315"
        ) {
            local item is
                lsit_cal_settings[page_name]["shuttle"][rotation_name].
            print page_name + " SSTO " + rotation_name + " deg: X=" +
                round(item["x"], 1) + " Y=" + round(item["y"], 1).
        }
    }
    print "---------------------------------------------".
}

// Open only the production trajectory console; no flight controls are changed.
global reentry_gui is GUI(800, 430).
set reentry_gui:style:width to 800.
reentry_gui:show().
create_reentry_gui().

global lsit_cal_gui is GUI(580, 720).
set lsit_cal_gui:style:width to 580.

local title is lsit_cal_gui:addlabel(
    "<size=20><b>M2L / L-SIT BUG CALIBRATION</b></size>"
).
set title:style:align to "center".
global lsit_cal_active_label is lsit_cal_gui:addlabel("").
set lsit_cal_active_label:style:align to "center".

local help is lsit_cal_gui:addlabel(
    "Choose page, rotation, and target. The highlighted selection owns its " +
    "X/Y offsets; changing it does not change any other rotation."
).
local output_help is lsit_cal_gui:addlabel(
    "LOG CURRENT appends CSV records to " + lsit_cal_output_file +
    ". Existing records are never cleared by this tool."
).

local page_row is lsit_cal_gui:addhlayout().
page_row:addlabel("Display").
global lsit_cal_page_menu is page_row:addpopupmenu().
lsit_cal_page_menu:addoption("L/SIT 1").
lsit_cal_page_menu:addoption("L/SIT 2").
set lsit_cal_page_menu:index to 0.
set lsit_cal_page_menu:onchange to lsit_cal_page_changed@.

local rotation_row is lsit_cal_gui:addhlayout().
rotation_row:addlabel("SSTO rotation").
global lsit_cal_rotation_menu is rotation_row:addpopupmenu().
for rotation_name in list(
    "0", "45", "90", "135", "180", "225", "270", "315"
) {
    lsit_cal_rotation_menu:addoption(rotation_name).
}
set lsit_cal_rotation_menu:index to 0.
set lsit_cal_rotation_menu:onchange to lsit_cal_rotation_changed@.

local target_row is lsit_cal_gui:addhlayout().
target_row:addlabel("Move target").
global lsit_cal_target_menu is target_row:addpopupmenu().
lsit_cal_target_menu:addoption("SHUTTLE").
lsit_cal_target_menu:addoption("GREEN REFERENCE").
set lsit_cal_target_menu:index to 0.
set lsit_cal_target_menu:onchange to lsit_cal_target_changed@.

lsit_cal_gui:addlabel("<b>Test geometry (metres from runway)</b>").
local shuttle_geometry_row is lsit_cal_gui:addhlayout().
shuttle_geometry_row:addlabel("Shuttle ATK / XTK").
global lsit_cal_shuttle_along_field is
    shuttle_geometry_row:addtextfield(
        lsit_cal_shuttle_along_m:tostring
    ).
global lsit_cal_shuttle_cross_field is
    shuttle_geometry_row:addtextfield(
        lsit_cal_shuttle_cross_m:tostring
    ).
local green_geometry_row is lsit_cal_gui:addhlayout().
green_geometry_row:addlabel("Green ATK / XTK").
global lsit_cal_green_along_field is
    green_geometry_row:addtextfield(lsit_cal_green_along_m:tostring).
global lsit_cal_green_cross_field is
    green_geometry_row:addtextfield(lsit_cal_green_cross_m:tostring).

lsit_cal_gui:addlabel("<b>Selected target offset (pixels)</b>").
global lsit_cal_offset_label is lsit_cal_gui:addlabel("").
local exact_offset_row is lsit_cal_gui:addhlayout().
exact_offset_row:addlabel("Exact X / Y").
global lsit_cal_x_field is exact_offset_row:addtextfield("0").
global lsit_cal_y_field is exact_offset_row:addtextfield("0").
local apply_button is exact_offset_row:addbutton("APPLY FIELDS").
set apply_button:onclick to lsit_cal_apply_fields@.

local x_row is lsit_cal_gui:addhlayout().
x_row:addlabel("X  -300").
global lsit_cal_x_slider is x_row:addhslider(0, -300, 300).
x_row:addlabel("+300").
set lsit_cal_x_slider:onchange to lsit_cal_x_changed@.

local y_row is lsit_cal_gui:addhlayout().
y_row:addlabel("Y  -300").
global lsit_cal_y_slider is y_row:addhslider(0, -300, 300).
y_row:addlabel("+300").
set lsit_cal_y_slider:onchange to lsit_cal_y_changed@.

global lsit_cal_result_label is lsit_cal_gui:addlabel("").
global lsit_cal_padding_label is lsit_cal_gui:addlabel("").
global lsit_cal_log_status_label is lsit_cal_gui:addlabel(
    "Nothing logged yet this run."
).

local buttons_a is lsit_cal_gui:addhlayout().
local reset_button is buttons_a:addbutton("RESET SELECTED").
local log_current_button is buttons_a:addbutton("LOG CURRENT (APPEND)").
set reset_button:onclick to lsit_cal_reset_selected@.
set log_current_button:onclick to lsit_cal_log_current@.

local buttons_b is lsit_cal_gui:addhlayout().
local print_all_button is buttons_b:addbutton("PRINT ALL").
local close_button is buttons_b:addbutton("CLOSE").
set print_all_button:onclick to lsit_cal_print_all@.
set close_button:onclick to { set lsit_cal_done to true. }.

lsit_cal_gui:show().
lsit_cal_load_target().
lsit_cal_refresh().

until lsit_cal_done {
    wait 0.1.
}

lsit_cal_gui:dispose().
reentry_gui:dispose().
print "M2L / L-SIT bug calibration closed.".
