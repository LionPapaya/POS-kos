// DISPLAY ONLY. Run on a fresh, idle CPU, never alongside POS flight code.
// Imports contain GUI definitions and reference data, not flight executors.
// Launch from terminal: RUNPATH("0:/GUI_TEST.ks"). No files are written.
// Refuse to replace state owned by an existing POS session. No controls are released.
if defined dap or defined main_step or defined AVES {
    print "GUI_TEST requires a fresh idle CPU. Reboot before running it.".
    until false { wait 1. }
}
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui_dialogs.ks").

global dap is lex("dap_mode","AUTO").
global step is "gui_test".
global main_step is "gui_test".
global confirm_in is false.
global Lastest_status is "SYNTHETIC GUI TEST".
global AVES is lex("Speed",lex("Rotate",100),"Ascent",lex(
    "speed_build_target",400,"closed_cycle_min_altitude",22000,"rapier_cutoff_apoapsis",75000)).

function gui_test_ascent_sample {
    parameter preset.
    local sample is lex().
    set sample["airspeed"] to 0.
    set sample["alignment"] to 0.
    set sample["altitude"] to 0.
    set sample["apoapsis"] to 0.
    set sample["attitude_error"] to 0.
    set sample["burn_seconds"] to 0.
    set sample["burn_window_seconds"] to 0.
    set sample["climb_alt"] to 0.
    set sample["climb_speed"] to 0.
    set sample["command_kind"] to 0.
    set sample["command_valid"] to 0.
    set sample["cutoff_ap"] to 0.
    set sample["dap_mode"] to 0.
    set sample["downrange"] to 0.
    set sample["elapsed"] to 0.
    set sample["eta_apoapsis"] to 0.
    set sample["finished"] to 0.
    set sample["heading"] to 0.
    set sample["heading_command"] to 0.
    set sample["health"] to 0.
    set sample["inclination"] to 0.
    set sample["insertion_altitude_ready"] to 0.
    set sample["insertion_valid"] to 0.
    set sample["nervs"] to 0.
    set sample["orbit_valid"] to 0.
    set sample["outcome"] to 0.
    set sample["page"] to 0.
    set sample["periapsis"] to 0.
    set sample["phase"] to 0.
    set sample["pitch"] to 0.
    set sample["pitch_command"] to 0.
    set sample["rapier_mode"] to 0.
    set sample["rapiers"] to 0.
    set sample["recovery"] to 0.
    set sample["remaining_dv"] to 0.
    set sample["stop_reference_m"] to 0.
    set sample["stop_reference_valid"] to 0.
    set sample["surface_speed"] to 0.
    set sample["target_ap"] to 0.
    set sample["target_inc"] to 0.
    set sample["target_pe"] to 0.
    set sample["throttle"] to 0.
    set sample["ut"] to 0.
    set sample["v1_actual_speed"] to 0.
    set sample["v1_called"] to 0.
    set sample["v1_estimate"] to 0.
    set sample["v1_marker_speed"] to 0.
    set sample["v1_prediction"] to 0.
    set sample["vertical_speed"] to 0.
    set sample["vr_speed"] to 0.
    for flag in list("finished","recovery","v1_called","stop_reference_valid","insertion_valid",
        "insertion_altitude_ready","command_valid","rapiers","nervs") { set sample[flag] to false. }
    set sample["orbit_valid"] to true.
    set sample["page"] to "ASCENT 1 / 2".
    set sample["phase"] to "high_altitude_climb".
    set sample["health"] to "SYNTHETIC - no flight controller".
    set sample["dap_mode"] to "AUTO".
    set sample["rapier_mode"] to "AIR".
    set sample["command_kind"] to "angles".
    set sample["outcome"] to "Display fixture only".
    set sample["altitude"] to 15000.
    set sample["airspeed"] to 900.
    set sample["surface_speed"] to 880.
    set sample["vertical_speed"] to 70.
    set sample["pitch"] to 15.
    set sample["heading"] to 90.
    set sample["climb_alt"] to 20000.
    set sample["climb_speed"] to 1200.
    set sample["target_ap"] to 80000.
    set sample["target_pe"] to 80000.
    set sample["cutoff_ap"] to 85000.
    set sample["apoapsis"] to 60000.
    set sample["periapsis"] to -20000.
    set sample["vr_speed"] to 100.
    set sample["v1_estimate"] to 85.
    set sample["v1_prediction"] to lex("remaining_m",1800,"limited",false,"valid",true,"reason","fixture").
    if preset = "Takeoff" or preset = "V1 unavailable" {
        set sample["page"] to "TAKEOFF". set sample["phase"] to "launch".
        set sample["surface_speed"] to 60. set sample["airspeed"] to 65.
        if preset = "V1 unavailable" { set sample["v1_prediction"]["valid"] to false. }
    }
    if preset = "Ascent 2" {
        set sample["page"] to "ASCENT 2 / 2". set sample["phase"] to "closed_cycle_climb".
    }
    if preset = "Insertion" or preset = "Finished" {
        set sample["page"] to "CIRC". set sample["phase"] to "coast_align".
        set sample["insertion_valid"] to true. set sample["burn_window_seconds"] to 45.
        set sample["remaining_dv"] to 120. set sample["alignment"] to 2.
        set sample["burn_seconds"] to 30. set sample["eta_apoapsis"] to 60.
        if preset = "Finished" { set sample["finished"] to true. set sample["phase"] to "complete". }
    }
    if preset = "Open trajectory" { set sample["orbit_valid"] to false. }
    if preset = "Off chart" { set sample["altitude"] to 40000. set sample["airspeed"] to 2000. }
    return sample.
}

local chooser is gui(460).
pos_gui_window_style(chooser,460).
chooser:addlabel("<b>POS GUI TEST / DISPLAY ONLY</b>").
local warning is chooser:addlabel("Synthetic values. Dialog actions return inputs only. Modal dialogs: finish with their own OK / Cancel / X.").
set warning:style:wordwrap to true. set warning:style:width to 420.
local selection is chooser:addpopupmenu().
local cases is list("Main menu","Ascent setup","Takeoff","V1 unavailable","Ascent 1","Ascent 2",
    "Insertion","Finished","Open trajectory","Off chart","Return structure",
    "Entry 1","Entry 2","Entry 3","Entry 4","Entry 5","Entry fallback",
    "RSVP inputs","OM mode","Rendezvous target","Periapsis","Circularisation","Apoapsis","Inclination","PDI coordinates","TEAM AoA","TEAM CSS","TEAM aero").
local commands is pos_om_catalog().
for case_name in cases { selection:addoption(case_name). }
for command in commands { selection:addoption("OM: "+command["label"]). }
set selection:index to 0.
local requested is false. local done is false. local back is false.
local open_button is chooser:addbutton("Open selected GUI").
local exit_button is chooser:addbutton("Exit harness").
local back_button is chooser:addbutton("Close preview / return to selector").
set back_button:visible to false.
local test_status is chooser:addlabel("Idle. No flight scripts loaded.").
set test_status:style:wordwrap to true. set test_status:style:width to 420.
set open_button:onclick to { set requested to true. }.
set exit_button:onclick to { set done to true. }.
set back_button:onclick to { set back to true. }.
set chooser:x to 1400.
set chooser:y to 100.
chooser:show().
until done {
    if requested {
        set requested to false. set back to false.
        set open_button:enabled to false. set exit_button:enabled to false.
        set selection:enabled to false.
        local choice is selection:value.
        set test_status:text to "Inspecting "+choice+" / SYNTHETIC".
        local preview is "none".
        set step to "gui_test". set confirm_in to false.
        if choice = "Main menu" {
            create_main_gui().
            // Replace the one callback that can dispatch DAP methods.
            set main_dap_mode_menu:onchange to { parameter mode. set dap["dap_mode"] to mode. }.
            set preview to poseidon_gui_main.
        } else if selection:index >= cases:length {
            local ignored is pos_om_inputs(commands[selection:index-cases:length]).
        } else if choice:startswith("TEAM ") {
            set step to "TEAM".
            set dap to lex("dap_mode","auto","str_mode","aoa",
                "aoa",lex("aoa_pitch",12,"aoa_yaw",90,"aoa_roll",15,"target_aoa",10,
                    "smooth_target_aoa",9,"target_bank",15,"smooth_target_bank",14,"base_pitch",2),
                "css",lex("pitch_out",5,"yaw_out",90,"roll_out",0),
                "aerostr",lex("targetPitch",7,"targetDirection",90,"targetRoll",0),
                "envelope",lex("state","fixture","terrain_state","fixture","terrain_worst_clearance",500)).
            global dapthrottle is 0.25.
            global team_dap_next_display is -1.
            if choice = "TEAM CSS" { set dap["dap_mode"] to "css". }
            if choice = "TEAM aero" { set dap["str_mode"] to "aerostr". }
            update_team_dap_gui().
            set preview to team_dap_gui.
        } else if choice = "PDI coordinates" { local ignored is vacuum_target_input("ASK","ASK").
        } else if choice = "RSVP inputs" { get_inputs_rsvp().
        } else if choice = "OM mode" { local ignored is get_om_mode().
        } else if choice = "Rendezvous target" { local ignored is get_rendezvous_target().
        } else if choice = "Periapsis" { local ignored is get_inputs_Periapsis().
        } else if choice = "Circularisation" { local ignored is get_inputs_circliurisation().
        } else if choice = "Apoapsis" { local ignored is get_inputs_Apoapsis().
        } else if choice = "Inclination" { local ignored is get_inputs_Inclination().
        } else if choice = "Return structure" or choice:startswith("Entry ") {
            // Bypass live create_reentry_display setup, automatic runway selection and telemetry.
            global reentry_gui is gui(680). pos_gui_window_style(reentry_gui,680).
            set reentry_gui:y to 40.
            create_reentry_gui().
            set preview to reentry_gui.
            if choice:startswith("Entry ") {
                local page_number is selection:index-10.
                if choice = "Entry fallback" { set page_number to 3. }
                global basice_reentry_guidance is choice = "Entry fallback".
                local page is return_entry_page("TRAJ "+page_number+" V/SIT").
                local inputs is lex("alt",(page["energy_min"]+page["energy_max"])/2,"spd",0,
                    "range_remaining",(page["range_min"]+page["range_max"])/2,"mode","SYNTHETIC").
                return_render_entry(inputs,page).
            }
            reentry_gui:show().
        } else {
            // Setup blocks only for this case; the others bypass confirmation for fixtures.
            set confirm_in to choice <> "Ascent setup".
            local ignored is create_assent_gui().
            set preview to assent_gui.
            if step <> "end" { update_assent_gui(gui_test_ascent_sample(choice)). }
        }
        if preview <> "none" {
            set back_button:visible to true.
            if choice = "Ascent 1" or choice = "Ascent 2" {
                local refresh_index is 0.
                until back {
                    wait 0.5.
                    set refresh_index to refresh_index+1.
                    local refreshed_sample is gui_test_ascent_sample(choice).
                    set refreshed_sample["altitude"] to 15000+refresh_index.
                    update_assent_gui(refreshed_sample).
                }
            } else { until back { wait 0.1. } }
            preview:dispose().
            // TEAM updater tests DEFINED to decide whether to rebuild its widgets.
            if choice:startswith("TEAM ") { unset team_dap_gui. }
            set back_button:visible to false.
        }
        set test_status:text to "Returned from "+choice+". Inputs discarded; no operation dispatched.".
        set main_step to "gui_test".
        set open_button:enabled to true. set exit_button:enabled to true. set selection:enabled to true.
    }
    wait 0.1.
}
chooser:dispose().
print "GUI test closed. Reboot CPU before normal POS use (test globals remain).".

// RSVP formatting helper; no terminal-input or flight libraries needed.
function remove_spaces {
    parameter value.
    return value:replace(" ","").
}
