// Libraries/Poseidon_SSTO/gui.ks
// Purpose: UI and HUD for the Poseidon reentry/landing assistant.
// - Provides GUI creation/update functions used by `Poseidon_SSTO_Reentry.ks`.
// - Contains logic for selecting landing location/runway and visual trajectory elements.
// The low-entry graph uses an offline nominal generated from successful flights.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/entry_nominal_profile.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/ascent_gui.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/return_gui.ks").

// Empirical KSP/Unity placement calibration for the five energy-versus-range
// pages. Shuttle offsets retain their console calibration. Prediction offsets
// refer to the fixed chart background. Their independent range scales match
// the calibration tool defaults between each page's numeric axis bounds.
global reentry_traj1_vsit_calibration is lex(
    "energy_px_per_km", 22.764,
    "range_px_per_km", 0.503,
    "pred_range_px_per_km", (220*539/457)/500,
    "ssto_x_offset", -4.2,
    "ssto_y_offset", -22.7,
    "pred_x_offset", 2.8,
    "pred_y_offset", 0
).
global reentry_traj2_vsit_calibration is lex(
    "energy_px_per_km", 13.658,
    "range_px_per_km", 0.706,
    "pred_range_px_per_km", (220*539/457)/350,
    "ssto_x_offset", -4.2,
    "ssto_y_offset", -17.7,
    "pred_x_offset", 2.8,
    "pred_y_offset", 0
).
global reentry_traj3_vsit_calibration is lex(
    "energy_px_per_km", 17.073,
    "range_px_per_km", 0.578,
    "pred_range_px_per_km", (220*539/457)/450,
    "ssto_x_offset", -4.2,
    "ssto_y_offset", -15.7,
    "pred_x_offset", 2.8,
    "pred_y_offset", 0
).
global reentry_traj4_vsit_calibration is lex(
    "energy_px_per_km", 22.946,
    "range_px_per_km", 1.061,
    "pred_range_px_per_km", (220*539/457)/250,
    "ssto_x_offset", -4.2,
    "ssto_y_offset", -9.9,
    "pred_x_offset", 2.8,
    "pred_y_offset", 0
).
global reentry_traj5_vsit_calibration is lex(
    "energy_px_per_km", 17.21,
    "range_px_per_km", 1.434,
    "pred_range_px_per_km", (220*539/457)/180,
    "ssto_x_offset", -4.2,
    "ssto_y_offset", -15.3,
    "pred_x_offset", 2.8,
    "pred_y_offset", 0
).

function update_readouts{
    if defined ascent_display_state { ascent_recovery_handoff_tick(). }
    runpath("0:/Poseidon_SSTO/Poseidon_SSTO_HUD.ks").

}

// Small live panel for the commands that DAP sends to the steering system
// during terminal (TEAM) guidance.  The source values differ by steering
// mode, so the panel always shows the final pitch/heading/roll command that
// the active DAP mode has produced.
function update_team_dap_gui {
    if not(defined step) {
        if defined team_dap_gui { team_dap_gui:hide(). }
        return.
    }
    if step <> "TEAM" {
        if defined team_dap_gui { team_dap_gui:hide(). }
        return.
    }

    if not(defined team_dap_gui){
        global team_dap_gui to gui(260).
        set team_dap_gui:style:width to 260.
        set team_dap_gui:style:hstretch to true.
        team_dap_gui:show().

        local title_box is team_dap_gui:addhbox().
        local title is title_box:addlabel("<size=16><b>TEAM DAP OUTPUTS</b></size>").
        set title:style:align to "center".

        local data_box is team_dap_gui:addvbox().
        global team_dap_mode_label is data_box:addlabel().
        global team_dap_pitch_label is data_box:addlabel().
        global team_dap_heading_label is data_box:addlabel().
        global team_dap_roll_label is data_box:addlabel().
        global team_dap_aoa_label is data_box:addlabel().
        global team_dap_bank_label is data_box:addlabel().
        global team_dap_bias_label is data_box:addlabel().
        global team_dap_throttle_label is data_box:addlabel().
        global team_dap_envelope_label is data_box:addlabel().
    } else {
        team_dap_gui:show().
    }

    local output_pitch is 0.
    local output_heading is 0.
    local output_roll is 0.

    if dap["dap_mode"] = "css" {
        set output_pitch to dap["css"]["pitch_out"].
        set output_heading to dap["css"]["yaw_out"].
        set output_roll to dap["css"]["roll_out"].
    } else if dap["str_mode"] = "aoa" {
        set output_pitch to dap["aoa"]["aoa_pitch"].
        set output_heading to dap["aoa"]["aoa_yaw"].
        set output_roll to dap["aoa"]["aoa_roll"].
    } else if dap["str_mode"] = "aerostr" {
        set output_pitch to dap["aerostr"]["targetPitch"].
        set output_heading to dap["aerostr"]["targetDirection"].
        set output_roll to dap["aerostr"]["targetRoll"].
    }

    set team_dap_mode_label:text to ("Mode: " + dap["dap_mode"] + " / " + dap["str_mode"]).
    set team_dap_pitch_label:text to ("CMD Pitch: " + round(output_pitch, 1) + " deg").
    set team_dap_heading_label:text to ("CMD Heading: " + round(output_heading, 1) + " deg").
    set team_dap_roll_label:text to ("CMD Roll: " + round(output_roll, 1) + " deg").
    if dap["dap_mode"] = "auto" and dap["str_mode"] = "aoa" {
        set team_dap_aoa_label:text to ("AoA: " + round(dap["aoa"]["target_aoa"], 1) + " / " + round(dap["aoa"]["smooth_target_aoa"], 1) + " deg").
        set team_dap_bank_label:text to ("Bank: " + round(dap["aoa"]["target_bank"], 1) + " / " + round(dap["aoa"]["smooth_target_bank"], 1) + " deg").
        set team_dap_bias_label:text to ("Pitch bias: " + round(dap["aoa"]["base_pitch"], 1) + " deg").
    } else {
        set team_dap_aoa_label:text to "AoA: n/a".
        set team_dap_bank_label:text to "Bank: n/a".
        set team_dap_bias_label:text to "Pitch bias: n/a".
    }
    set team_dap_throttle_label:text to ("CMD Throttle: " + round(dapthrottle, 2)).
    set team_dap_envelope_label:text to ("Envelope: " + dap["envelope"]["state"] + " | Terrain: " + dap["envelope"]["terrain_state"] + " / " + round(dap["envelope"]["terrain_worst_clearance"]) + " m").
}

// Live state for the terminal-route planner.  The panel remains hidden until
// terminal_route_init/update/fly has populated terminal_route_debug.
function update_terminal_route_gui {

    if not (defined terminal_route_gui){
        global terminal_route_gui to gui(340).
        set terminal_route_gui:style:width to 340.
        set terminal_route_gui:style:hstretch to true.
        terminal_route_gui:show().
        local title_box is terminal_route_gui:addhbox().
        local title is title_box:addlabel("<size=16><b>TERMINAL ROUTE TELEMETRY</b></size>").
        set title:style:align to "center".
        local data_box is terminal_route_gui:addvbox().
        global terminal_route_phase_label is data_box:addlabel().
        global terminal_route_distance_label is data_box:addlabel().
        global terminal_route_altitude_label is data_box:addlabel().
        global terminal_route_vs_label is data_box:addlabel().
        global terminal_route_energy_label is data_box:addlabel().
        global terminal_route_command_label is data_box:addlabel().
        global terminal_route_controls_label is data_box:addlabel().
        global terminal_route_pid_lable is data_box:addlabel().
        local runway_change_box is data_box:addhbox().
        global terminal_route_runway_popup is runway_change_box:addpopupmenu().
        for runway in terminal_route_available_runways(Location) {
            terminal_route_runway_popup:addoption(runway).
        }
        global terminal_route_runway_change_button is runway_change_box:addbutton("CHANGE RUNWAY").
        global terminal_route_runway_change_label is data_box:addlabel().
        set terminal_route_runway_change_button:onclick to {
            if terminal_route_runway_change_allowed(terminal_route) {
                set terminal_route_runway_change_request to terminal_route_runway_popup:value.
            }else{
                set Lastest_status to "Runway change locked: terminal approach is committed".
            }
        }.
    } else {
        terminal_route_gui:show().
    }

    set terminal_route_phase_label:text to ("Target: " + terminal_route_debug["target_location"] + " runway " + terminal_route_debug["target_runway"] + " | " + terminal_route_debug["phase"] + " | " + terminal_route_debug["side"] + " | laps " + terminal_route_debug["hold_laps"]).
    set terminal_route_distance_label:text to ("Target / remaining: " + round(terminal_route_debug["target_distance"]) + " / " + round(terminal_route_debug["remaining_distance"]) + " m").
    set terminal_route_altitude_label:text to ("Altitude now / target: " + round(ship:altitude) + " / " + round(terminal_route_debug["target_altitude"]) + " m").
    set terminal_route_vs_label:text to ("Vertical speed now / target: " + round(ship:verticalspeed,1) + " / " + round(terminal_route_debug["desired_vertical_speed"],1) + " m/s").
    set terminal_route_energy_label:text to ("Energy margin / target: " + round(terminal_route_debug["energy_margin"]) + " / " + round(terminal_route_debug["target_energy"]) + " m").
    set terminal_route_command_label:text to ("AoA / bank / bias: " + round(terminal_route_debug["target_aoa"],1) + " / " + round(dap["aoa"]["target_bank"],1) + " / " + round(terminal_route_debug["pitch_bias"],1) + " deg").
    set terminal_route_controls_label:text to ("Throttle: " + round(terminal_route_debug["throttle"],2) + " | brake: " + terminal_route_debug["airbrake"] + " | gear: " + terminal_route_debug["gear"]).
    set terminal_route_pid_lable:text to ("PID log: " + terminal_route_debug["Pid_log"]).
    if terminal_route_runway_change_allowed(terminal_route) {
        set terminal_route_runway_change_label:text to ("Runway: " + runway_nr + " selected — change available").
    }else{
        set terminal_route_runway_change_label:text to ("Runway: " + runway_nr + " selected — CHANGE LOCKED").
    }
}
// Fast startup selection requires no impact prediction or trajectory solve.
// Prefer the nearest site; within 5 km choose the better landing direction.
function entry_initial_runway {
    parameter reference_position, arrival_heading.
    local best is lex("selected",false,"distance",9999999999,"heading_error",180).
    local nearest_distance is 9999999999.
    local candidates is list().
    local runway_table is Location_constants["kerbin"].
    for key in runway_table:keys {
        if key:endswith("_start") {
            local parts is key:split("_").
            if parts:length = 4 {
                local site_name is parts[0].
                local runway_id is parts[2].
                local end_key is site_name+"_runway_"+runway_id+"_end".
                if runway_table:haskey(end_key) and KerbinRunwayalt:haskey(site_name+"_runway") {
                    local site_distance is calcdistance(reference_position,runway_table[key]).
                    local site_heading is heading_between(runway_table[key],runway_table[end_key]).
                    set nearest_distance to min(nearest_distance,site_distance).
                    candidates:add(lex("selected",true,"location",site_name,"runway",runway_id,
                        "distance",site_distance,
                        "heading_error",abs(normalized_heading_error(site_heading,arrival_heading)))).
                }
            }
        }
    }
    // Anchor the 5 km direction tie-break to the true nearest threshold;
    // updating the anchor with each winner could drift through distant sites.
    for candidate in candidates {
        if candidate["distance"] <= nearest_distance+5 {
            if not best["selected"] or candidate["heading_error"] < best["heading_error"] or
               (candidate["heading_error"] = best["heading_error"] and candidate["distance"] < best["distance"]) {
                set best to candidate.
            }
        }
    }
    return best.
}

function setup_reentry_script{
    parameter Location_ is "".
    parameter runway_nr_ is "".
    parameter preserve_propulsion is false.
    if not preserve_propulsion {
        set steeringManager:ROLLCONTROLANGLERANGE to 180.
        steeringManager:resetpids().
    }
    set step to "Deorbit".
    set substep to "findStep".
    set running to true.
    clearScreen.  
    if not preserve_propulsion {
    if maxThrust > 110{
        set nervs to true.
    } 
    else{
        set nervs to false.
    }

    set rapier_mode to "air".
    set rapiers to false.
    }
    set Lastest_status to "Inizializing Script".
    set deorbit_start to false.
    set deorbit_calc to false.
    if not preserve_propulsion { dap:setup(). }

    if Location_ = "" or runway_nr_ = ""{
        create_reentry_display().
    }else{
        create_reentry_display(false,Location_,runway_nr_).
        set Reentry_mode to "Auto".
    }
   if Reentry_mode = "Man" or Reentry_mode = "Auto" or Reentry_mode = "Ex"{
    local a is Location+"_runway".
    local b is Location+"_runway_"+runway_nr+"_start".
    local c is Location+"_runway_"+runway_nr+"_end".
    set runway_altitude to KerbinRunwayalt[a].

    
    // Check if the "kerbin" lexicon contains the runway data
    if Location_constants:HASKEY("kerbin") {
        local kerbin_runways is Location_constants["kerbin"].

        // Check if the keys exist in the nested lexicon "kerbin"
        if kerbin_runways:HASKEY(b) {
            set runway_start to kerbin_runways[b].
        } else {
            flight_log_event("runway_lookup_failed","key=" + b).
        }

        if kerbin_runways:HASKEY(c) {
            set runway_end to kerbin_runways[c].
        } else {
            flight_log_event("runway_lookup_failed","key=" + c).
        }
    } else {
        flight_log_event("runway_lookup_failed","key=kerbin").
    }
}
set runway_heading to heading_between(runway_start, runway_end).
flight_log_set_runway(Location,runway_nr,runway_start,runway_end,runway_heading,runway_altitude).


   
    // SETTARGET is only safe after Trajectories has an impact prediction.
    // The reentry loop retries this pending setup after the deorbit node
    // produces one.
    set reentry_tr_target_pending to true.
    if ADDONS:TR:available {
        if ADDONS:TR:isvertwofour {
            ADDONS:TR:RESETDESCENTPROFILE(20).
        }
        if ADDONS:TR:hasimpact {
            ADDONS:TR:SETTARGET(runway_start).
            set reentry_tr_target_pending to false.
            flight_log_event("trajectories_target_armed","runway="+Location+"_"+runway_nr+"|phase=setup").
        }
    }
    reset_sys().                                                                             
   
}

function create_reentry_display {
    parameter wait_for_confirm is true.
    parameter force_loaction is "".
    parameter force_runway is "".
    local location_to_runways is lexicon().

    // A quickloaded kOS session can retain a partially initialized constants
    // lexicon while RUNONCEPATH skips this library.  Rebuild it before the
    // automatic target selector relies on its runway keys.
    local location_constants_ready is defined location_constants.
    if location_constants_ready {
        if not location_constants:haskey("kerbin") {
            set location_constants_ready to false.
        } else if not location_constants["kerbin"]:haskey("KSC_runway_09_start") or not location_constants["kerbin"]:haskey("KSC_runway_09_end") {
            set location_constants_ready to false.
        }
    }
    if not(defined KerbinRunwayalt) {
        set location_constants_ready to false.
    } else if not KerbinRunwayalt:haskey("KSC_runway") {
        set location_constants_ready to false.
    }
    if not location_constants_ready {
        if defined location_constants {
            unset location_constants.
        }
        if defined KerbinRunwayalt {
            unset KerbinRunwayalt.
        }
        runpath("0:/Libraries/lib_location_constants.ks").
    }

    // A forced re-entry target does not enter the confirmation loop below.  Copy
    // it into the selections before building the display so setup_reentry_script
    // can use it as soon as this function returns.
    if not wait_for_confirm {
        set Location to force_loaction.
        set runway_nr to force_runway.
    }
    
    
        set confirm_in to false.
    
    

    local kerbin_runways is Location_constants["kerbin"].
    for key in kerbin_runways:keys {
        

        // Only process keys that end with "_start"
        if key:endswith("_start") {
            // Split the key by underscores
            local split_key is key:split("_").

            // Check if the split key has at least 3 parts (location, "runway", and number)
            if split_key:length >= 3 {
                // Extract location name and runway number
                local location_name is split_key[0].  // First part before the underscore is the location name
                local runway_number is split_key[2].  // Runway number after the second underscore

                // Add the location to the lexicon if it doesn't already exist
                if not location_to_runways:haskey(location_name) {
                    location_to_runways:add(location_name, list()).
                    
                }

                // Add the runway number to the list of runways for this location
                location_to_runways[location_name]:add(runway_number).
                
            } else {
                // Debugging: Log a warning if the key does not have the expected format
                flight_log_event("runway_key_invalid","key=" + key).
            }
        }
    }



    set abort_flag to false.
    set end to false.
    
    global reentry_gui to gui(680).
    set reentry_gui:style:width to 680.

    reentry_gui:show().
    // GUI Setup
    local Title_BOX is reentry_gui:addhlayout().
    set reentry_gui:style:hstretch to true.
    set gui_titel to "POSEIDON RETURN".
    set titel to Title_BOX:addlabel(gui_titel).
    set titel:style:align to ("LEFT").
    set titel:text to "<size=16><b>"+gui_titel+"</b></size>".
    ascent_display_label_style(titel,16).
    set titel:style:width to 560.

    GLOBAL minb IS title_box:ADDBUTTON("-").
    set minb:style:margin:h to 7.
    set minb:style:margin:v to 7.
    set minb:style:width to 20.
    set minb:style:height to 20.
    set minb:TOGGLE to TRUE.

    function minimizecheck {
        set pressed to minb:pressed.

        IF pressed {
            reentry_gui:SHOWONLY(title_box).
            SET reentry_gui:STYLE:HEIGHT TO 50.
        } ELSE {
            SET reentry_gui:STYLE:HEIGHT TO 0.
            for w in reentry_gui:WIDGETS {
                w:SHOW().
            }
        }
    }
    set minb:onclick to minimizecheck@.

    GLOBAL quitb IS title_box:ADDBUTTON("X").
    set quitb:style:margin:h to 7.
    set quitb:style:margin:v to 7.
    set quitb:style:width to 20.
    set quitb:style:height to 20.
    SET quit_program TO false.

    function quitcheck {
        SET step to "end".
        
    }
    SET quitb:ONCLICK TO quitcheck@.

    GLOBAL toggels_box IS reentry_gui:ADDHLAYOUT().
    SET toggels_box:STYLE:WIDTH TO 640.

    GLOBAL dap_mode_box IS toggels_box:ADDHLAYOUT().
    SET dap_mode_box:STYLE:WIDTH TO 105.
    GLOBAL dap_mode_text IS dap_mode_box:ADDLABEL("<b>DAP</b>"). 
    set dap_mode_text:style:margin:v to -3.
    ascent_display_label_style(dap_mode_text,12).
    GLOBAL dap_mode_menu IS dap_mode_box:addpopupmenu().
    set dap_mode_menu:style:margin:v to -3.
    SET dap_mode_menu:STYLE:WIDTH TO 65.
    SET dap_mode_menu:STYLE:HEIGHT TO 25.
    SET dap_mode_menu:STYLE:ALIGN TO "center".
    dap_mode_menu:addoption("AUTO").
    dap_mode_menu:addoption("CSS").
    dap_mode_menu:addoption("OFF").
    toggels_box:addspacing(8).
    set dap_mode_menu:onchange to update_dap@.
    
    function update_dap {
        parameter decoy is 1.
        set dap["dap_mode"] to dap_mode_menu:value.
        if (dap["dap_mode"] = "OFF") {
			set dap_mode_menu:STYLE:BG to "Libraries/gui_images/abort_btn.png".
		} else {
			set dap_mode_menu:STYLE:BG to "Libraries/gui_images/default_btn.png". 
		}
    }

GLOBAL Reentry_mode_box IS toggels_box:ADDHLAYOUT().
    SET Reentry_mode_box:STYLE:WIDTH TO 105.
    GLOBAL Reentry_mode_text IS Reentry_mode_box:ADDLABEL("<b>Mode</b>"). 
    set Reentry_mode_text:style:margin:v to -3.
    ascent_display_label_style(Reentry_mode_text,12).
    GLOBAL Reentry_mode_menu IS Reentry_mode_box:addpopupmenu().
    set Reentry_mode_menu:style:margin:v to -3.
    SET Reentry_mode_menu:STYLE:WIDTH TO 65.
    SET Reentry_mode_menu:STYLE:HEIGHT TO 25.
    SET Reentry_mode_menu:STYLE:ALIGN TO "center".
    Reentry_mode_menu:addoption("AUTO").
    Reentry_mode_menu:addoption("Man").
    Reentry_mode_menu:addoption("Ex").
    toggels_box:addspacing(8).
    



    // Target setup occupies its own row in the 680px ascent-sized window.
    local return_target_setup is reentry_gui:addhlayout().
    set return_target_setup:style:width to 640.
    // Location Selection Popup Menu
    local location_box is return_target_setup:addhlayout().
    local location_label is location_box:addlabel("<b>Location:</b> ").
    ascent_display_label_style(location_label,12).
    local location_popup is location_box:addpopupmenu().
    SET location_popup:STYLE:HEIGHT TO 25.
    set location_popup:style:width to 230.

    // Add unique locations to the popup menu
    for loc in location_to_runways:keys {
        location_popup:addoption(loc).
    }
    // kOS popup menus can begin without a selected value. Select a valid
    // entry before the runway callback indexes the location table.
    if location_to_runways:keys:length > 0 {
        set location_popup:index to 0.
    }
    location_box:show().

    // Runway Selection Popup Menu (dynamically updated)
    local runway_box is return_target_setup:addhlayout().
    local runway_label is runway_box:addlabel("<b>Runway:</b> ").
    ascent_display_label_style(runway_label,12).
    local runway_popup is runway_box:addpopupmenu().
    SET runway_popup:STYLE:HEIGHT TO 25.
    set runway_popup:style:width to 70.
    runway_box:show().

    // Function to update runways based on location selection
    function update_runway_options {
        parameter dummy is "lol".
        local selected_location is location_popup:value.
        if not location_to_runways:haskey(selected_location) { return. }
        local available_runways is location_to_runways[selected_location].

        // Clear current runway options
        runway_popup:clear().
        
        // Add available runways for the selected location
        for runway in available_runways {
            runway_popup:addoption(runway).
        }
    }

    // Trigger runway update when the location is changed
    set location_popup:onchange to update_runway_options@.
    
    update_runway_options().

    // OK button to finalize the inputs
    local ok_box is return_target_setup:addhlayout().
    local ok_button is ok_box:addbutton("OK").
    ok_box:show().

    // Function to confirm and capture the inputs
    function confirm_inputs {
        set Location to location_popup:value.
        set runway_nr to runway_popup:value.
        set Reentry_mode to Reentry_mode_menu:value.
        set confirm_in to true.
        
        
    }
    set ok_button:onclick to confirm_inputs@.

  create_reentry_gui().
    


    
    until confirm_in or step = "end" or not(wait_for_confirm) {
        wait 0.0001.
        update_reentry_gui().
        
        // A late start must enter the control loop even while TR has no impact.
        if ship:altitude < 72000 {
            local initial_reference is ship:geoposition.
            local initial_reason is "position_without_impact".
            if ADDONS:TR:available and ADDONS:TR:hasimpact {
                set initial_reference to ADDONS:TR:IMPACTPOS.
                set initial_reason to "trajectories_impact".
            }
            local initial_selection is entry_initial_runway(initial_reference,compass_for_prograde()).
            if initial_selection["selected"] {
                set Location to initial_selection["location"].
                set runway_nr to initial_selection["runway"].
                set Reentry_mode to "Auto".
                set confirm_in to true.
                flight_log_event("entry_automatic_target","reason="+initial_reason+
                    "|runway="+Location+"_"+runway_nr+
                    "|distance_km="+round(initial_selection["distance"],2)).
            }
        }
    }
    
}

// Convert a geoposition to runway-relative coordinates.  Positive along-track
// is on the approach side of the threshold; cross-track is signed.
function reentry_lsit_geometry {
    parameter position.
    local distance is calcdistance_m(runway_start, position).
    local outward_heading is runway_heading + 180.
    local bearing_from_threshold is heading_between(runway_start, position).
    local bearing_error is normalized_heading_error(bearing_from_threshold, outward_heading).
    return lex(
        "distance", distance,
        "along_track", distance * cos(bearing_error),
        "cross_track", distance * sin(bearing_error)
    ).
}

function hide_reentry_vsit_prediction_path {
    // Keep the chart origin visible on V/SIT even with no prediction. An
    // empty Unity layout ignores its fixed height, changing console flow.
    for prediction_dot in traj_disp_prediction_path {
        set prediction_dot:visible to false.
    }
}

// Chart-local axis positions from support/build_entry_nominal.py. The source
// image is 539px tall, cropped by 82px, then drawn at 380px GUI height.
function reentry_vsit_chart_plot_top {
    return (94*539-82*380)/457.
}

function reentry_vsit_chart_plot_bottom {
    return (314*539-82*380)/457.
}

function place_reentry_vsit_prediction_dot {
    parameter marker_index, point_x, point_y, marker_size.
    parameter previous_rect_y, previous_rect_height.
    local marker is traj_disp_prediction_path[marker_index].
    local previous_widget is traj_disp_prediction_origin.
    if marker_index > 0 {
        set previous_widget to traj_disp_prediction_path[marker_index-1].
    } else {
        set traj_disp_prediction_origin:visible to true.
        set traj_disp_mainbox:style:padding:left to 0.
    }
    local marker_top is round(point_y-marker_size/2).
    local marker_left is round(point_x-marker_size/2).
    local margin_delta is marker_top-previous_rect_y-previous_rect_height.
    // Unity collapses adjacent vertical margins with MAX. A negative top
    // margin alone is suppressed by a zero bottom margin on the earlier
    // widget. Pair both margins to move the entire rectangle upward.
    set previous_widget:style:margin:bottom to min(0,margin_delta).
    set marker:style:margin:top to margin_delta.
    set marker:style:margin:bottom to 0.
    set marker:style:margin:left to marker_left.
    set marker:style:margin:right to 0.
    set traj_disp_mainbox:style:padding:left to min(
        traj_disp_mainbox:style:padding:left,marker_left
    ).
    set marker:style:padding:v to 0.
    set marker:style:padding:h to 0.
    set marker:style:width to marker_size.
    set marker:style:height to marker_size.
    set marker:style:hstretch to false.
    set marker:style:vstretch to false.
    set marker:visible to true.
    return marker_top.
}

// Sample the latest path at the 16 fixed energy positions spanning this
// display. Only retain the remaining path ahead of the live shuttle and
// inside both displayed axes. Never clamp off-page points onto an edge or
// extrapolate beyond the simulated TEAM endpoint.
function reentry_vsit_display_points {
    parameter points, page_energy_min, page_energy_max.
    parameter page_range_min, page_range_max, current_energy.
    local displayed_points is list().
    if points:length < 2 { return displayed_points. }
    local segment_index is 0.
    local path_energy_max is points[0]["energy"].
    local path_energy_min is points[points:length-1]["energy"].
    for display_slot in range(0,16) {
        local sample_energy is page_energy_max -
            (page_energy_max-page_energy_min)*display_slot/15.
        if sample_energy <= current_energy and
           sample_energy <= path_energy_max and sample_energy >= path_energy_min {
            // Energy decreases along the prediction. Advance this cursor once
            // through the path while sampling the display from right to left.
            until segment_index >= points:length-2 or
                  points[segment_index+1]["energy"] <= sample_energy {
                set segment_index to segment_index+1.
            }
            local high_point is points[segment_index].
            local low_point is points[segment_index+1].
            local energy_span is high_point["energy"]-low_point["energy"].
            if energy_span > 0 {
                local fraction is (high_point["energy"]-sample_energy)/energy_span.
                local sample_range is high_point["range"] +
                    (low_point["range"]-high_point["range"])*fraction.
                if sample_range >= page_range_min and sample_range <= page_range_max {
                    displayed_points:add(lex("energy",sample_energy,"range",sample_range)).
                }
            }
        }
    }
    return displayed_points.
}

// The path keeps fixed chart coordinates between solver updates. Resampling
// uses this page's full-width spacing; advancing the shuttle only removes
// passed samples, without moving the remaining dots or stretching their gaps.
function update_reentry_vsit_prediction_path {
    parameter points.
    parameter page_energy_min.
    parameter page_energy_max.
    parameter page_range_min.
    parameter page_range_max.
    parameter current_energy.
    parameter calibration.
    local display_points is reentry_vsit_display_points(
        points,page_energy_min,page_energy_max,
        page_range_min,page_range_max,current_energy
    ).
    local visible_count is display_points:length.
    if visible_count = 0 {
        hide_reentry_vsit_prediction_path().
        return 0.
    }
    local previous_rect_y is 0.
    local previous_rect_height is 1.
    for marker_index in range(0,traj_disp_prediction_path:length) {
        local marker is traj_disp_prediction_path[marker_index].
        if marker_index < visible_count {
            local path_point is display_points[marker_index].
            local energy_from_left_km is (path_point["energy"]-page_energy_min)/1000.
            local point_x is 50 + energy_from_left_km*calibration["energy_px_per_km"]+
                calibration["pred_x_offset"].
            local point_y is reentry_vsit_chart_plot_bottom() -
                (path_point["range"]-page_range_min)/1000*calibration["pred_range_px_per_km"]+
                calibration["pred_y_offset"].
            set previous_rect_y to place_reentry_vsit_prediction_dot(
                marker_index,point_x,point_y,2,previous_rect_y,previous_rect_height
            ).
            set previous_rect_height to 2.
        } else {
            set marker:visible to false.
            set marker:style:width to 2.
            set marker:style:height to 2.
        }
    }
    return visible_count.
}

// Build the remaining terminal route in flight order.  These are real route
// vertices from terminal_route, not a decorative static line.
function reentry_lsit_terminal_path {
    local result is list().
    if not(defined terminal_route) { return result. }
    local phase is terminal_route["phase"].

    if phase = "intercept" or phase = "hold" {
        local first_hold_index is terminal_route["hold_index"].
        for hold_offset in range(0, 4) {
            result:add(terminal_route["hold_points"][mod(first_hold_index + hold_offset, 4)]).
        }
        result:add(terminal_route["downwind_fix"]).
    } else if phase = "reposition" or phase = "go_around" or phase = "downwind" {
        result:add(terminal_route["downwind_fix"]).
    }

    if phase <> "final" {
        result:add(terminal_route["base_fix"]).
        result:add(terminal_route["final_fix"]).
    } else {
        result:add(terminal_route_current_target(terminal_route)).
    }
    result:add(runway_start).
    return result.
}

function create_main_gui{
    global poseidon_gui_main to gui(400).
    set poseidon_gui_main:style:width to 0.

    poseidon_gui_main:show().
    // GUI Setup
    local Title_BOX is poseidon_gui_main:addhbox().
    set poseidon_gui_main:style:hstretch to true.
    set gui_titel to "POSEIDON OPERATING SYSTEM".
    set titel to Title_BOX:addlabel(gui_titel).
    set titel:style:align to ("LEFT").
    set titel:text to " <size=20><b>"+gui_titel+"</b></size>".


    GLOBAL Main_toggels_box IS poseidon_gui_main:ADDHLAYOUT().
    SET Main_toggels_box:STYLE:WIDTH TO poseidon_gui_main:style:width - 16.

    GLOBAL main_dap_mode_box IS Main_toggels_box:ADDHLAYOUT().
    SET main_dap_mode_box:STYLE:WIDTH TO 105.
    GLOBAL main_dap_mode_text IS main_dap_mode_box:ADDLABEL("<b>DAP</b>"). 
    set main_dap_mode_text:style:margin:v to -3.
    GLOBAL main_dap_mode_menu IS main_dap_mode_box:addpopupmenu().
    set main_dap_mode_menu:style:margin:v to -3.
    SET main_dap_mode_menu:STYLE:WIDTH TO 65.
    SET main_dap_mode_menu:STYLE:HEIGHT TO 25.
    SET main_dap_mode_menu:STYLE:ALIGN TO "center".
    main_dap_mode_menu:addoption("AUTO").
    main_dap_mode_menu:addoption("CSS").
    main_dap_mode_menu:addoption("OFF").
    Main_toggels_box:addspacing(8).
    set main_dap_mode_menu:onchange to main_update_dap@.
    
    function main_update_dap {
        parameter decoy is 1.
        if main_step = "manual_log" {
            if main_dap_mode_menu:value = "CSS" {
                set dap["str_mode"] to "aerostr".
                set dap["l_t"] to time:seconds.
                dap:set_css().
            } else {
                dap:set_off().
                if main_dap_mode_menu:index <> 2 { set main_dap_mode_menu:index to 2. }
            }
        } else { set dap["dap_mode"] to main_dap_mode_menu:value. }
        if dap["dap_mode"] = "off" {
            set main_dap_mode_menu:style:bg to "Libraries/gui_images/abort_btn.png".
        } else {
            set main_dap_mode_menu:style:bg to "Libraries/gui_images/default_btn.png".
        }
    }

    local Programm_box is main_toggels_box:addhlayout().
    local Programm_label is Programm_box:addlabel("<b>Programm</b> ").
    SET Programm_label:STYLE:width TO 80.
    local Programm_popup is Programm_box:addpopupmenu().
    SET Programm_popup:STYLE:HEIGHT TO 25.
    SET Programm_popup:STYLE:width TO 170.
    Programm_popup:addoption("Select program").
    Programm_popup:addoption("Manual Flight Logging").
    Programm_popup:addoption("Launch").
    Programm_popup:addoption("Aerobraking").
    Programm_popup:addoption("Landing").
    Programm_popup:addoption("Vacuum Landing (Suborbital)").
    Programm_popup:addoption("Vacuum Landing (Convenient)").
    Programm_popup:addoption("Vacuum Ascent").
    Programm_popup:addoption("Orbital Maneuvering").
    Programm_popup:addoption("Docking").
    Programm_popup:addoption("Test").
    set Programm_popup:onchange to changeProgramm@.

    function changeProgramm{
        parameter decoy is 1.
        if Programm_popup:value = "Select program" { set main_step to "ask_Step". }
        if Programm_popup:value = "Manual Flight Logging" { set main_step to "manual_log". }
        if Programm_popup:value = "Launch"{
            set main_step to "POS1".
        }
        if Programm_popup:value = "Aerobraking"{
            set main_step to "Aerobrake".
        }
        if Programm_popup:value = "Landing"{
            set main_step to "POS3".
        }
        if Programm_popup:value = "Vacuum Landing (Suborbital)"{
            set main_step to "POS4".
        }
        if Programm_popup:value = "Vacuum Landing (Convenient)"{
            set main_step to "POS5".
        }
        if Programm_popup:value = "Vacuum Ascent"{
            set main_step to "POS6".
        }
        if Programm_popup:value = "Orbital Maneuvering"{
            set main_step to "OM1".
        }
        if Programm_popup:value = "Docking"{
            set main_step to "POS2".
        }
        if Programm_popup:value = "Test"{
            set main_step to "Test".
        }
    }
    global manual_log_status is poseidon_gui_main:addlabel("Manual flight: select Manual Flight Logging").
    global manual_log_stop is poseidon_gui_main:addbutton("Stop manual recording").
    set manual_log_stop:visible to false.
    set manual_log_stop:onclick to {
        set main_step to "ask_Step".
        set Programm_popup:index to 0.
    }.

}
function get_inputs_rsvp {
    // Initialize GUI and variables
    local rsvp_gui is GUI(400, 300).
    set rsvp_gui:style:width to 400.
    set rsvp_gui:style:height to 300.

    local confirm_in is false.

    rsvp_gui:show().
    
    // Title
    local title_box is rsvp_gui:addhbox().
    set title_box:style:hstretch to true.
    set title_box:style:margin:v to 10.
    local title_label is title_box:addlabel("<size=18><b>Orbital Maneuvering Inputs</b></size>").
    title_box:show().

    // Input Fields
    local input_box is rsvp_gui:addvbox().
    set input_box:style:margin:v to 10.
    set input_box:style:margin:h to 10.

    // Target Field
    local target_box is input_box:addhlayout().
    local target_label is target_box:addlabel("Target:").
    local target_menu is target_box:addpopupmenu().
    
    set target_menu:onchange to {
        parameter new_value.
        set OM_Target to new_value.
    }.
    target_box:show().

    // Target Type Selector
    local target_type_box is input_box:addhlayout().
    local target_type_label is target_type_box:addlabel("Target Type:").
    local target_type_menu is target_type_box:addpopupmenu().
    target_type_menu:addoption("Body").
    target_type_menu:addoption("Vessel").
    
    set target_type_menu:onchange to {
        parameter new_value.
        set OM_Target_type to new_value.
        update_target_options(target_type_menu:value).
    }.
    target_type_box:show().

    // Nodes Selector
    local nodes_box is input_box:addhlayout().
    local nodes_label is nodes_box:addlabel("Nodes:").
    local nodes_menu is nodes_box:addpopupmenu().
    nodes_menu:addoption("both").
    nodes_menu:addoption("first").
    set nodes_menu:onchange to {
        parameter new_value.
        set OM_Nodes to new_value.
    }.
    nodes_box:show().

    // Orbit Type Selector
    local orbit_type_box is input_box:addhlayout().
    local orbit_type_label is orbit_type_box:addlabel("Orbit Type:").
    local orbit_type_menu is orbit_type_box:addpopupmenu().
    orbit_type_menu:addoption("circular").
    orbit_type_menu:addoption("elliptical").
    orbit_type_menu:addoption("none").
    set orbit_type_menu:onchange to {
        parameter new_value.
        set OM_Orbit_Type to new_value.
    }.
    orbit_type_box:show().

    // Orbit Orientation Selector
    local orbit_orientation_box is input_box:addhlayout().
    local orbit_orientation_label is orbit_orientation_box:addlabel("Orbit Orientation:").
    local orbit_orientation_menu is orbit_orientation_box:addpopupmenu().
    orbit_orientation_menu:addoption("prograde").
    orbit_orientation_menu:addoption("retrograde").

    set orbit_orientation_menu:onchange to {
        parameter new_value.
        set OM_Orbit_Orientation to new_value.
    }.
    orbit_orientation_box:show().

    input_box:show().

    // OK Button to Finalize Inputs
    local ok_button_box is rsvp_gui:addhbox().
    set ok_button_box:style:margin:v to 15.
    local ok_button is ok_button_box:addbutton("OK").
    set ok_button:onclick to {
        set confirm_in to true.
        rsvp_gui:hide().
    }.
    ok_button_box:show().

    // Function to dynamically update target options
    function update_target_options {
        parameter target_type.

        target_menu:clear(). // Clear the existing options
        
        if target_type = "Body" {
            // Add all celestial bodies
            for bleh in buildlist("bodies") {
                target_menu:addoption(bleh:name).
            }
        } else if target_type = "Vessel" {
            // Add all active vessels
            List Targets in all_vessels.
            for listed_vessel in all_vessels{
                target_menu:addoption(listed_vessel:name).
            }
        }
    }

    // Initialize the Target options for the default Target Type
    update_target_options(target_type_menu:value ).

    // Wait for confirmation
    until confirm_in {
        wait 0.01.
    }

    // Return the finalized inputs
    set OM_Target to target_menu:value.
    set OM_Target_type to remove_spaces(target_type_menu:value).
    set OM_Nodes to remove_spaces(nodes_menu:value).
    set OM_Orbit_Type to remove_spaces(orbit_type_menu:value).
    set OM_Orbit_Orientation to remove_spaces( orbit_orientation_menu:value).

    clearscreen.
}


function check_om_nodes{




CLEARSCREEN.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:HEIGHT TO 23.
PRINT "+-------------------------------------------+".
PRINT "|Execute>                                   |".
PRINT "+-------------------------------------------+".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "+-------------------------------------------+".
PRINT "|Type the name of the field you want to     |".
PRINT "|change, then type the value you want       |".
PRINT "|the field to hold and press enter.         |".
PRINT "|Type 'go' to end script.                   |".
PRINT "|                                           |".
PRINT "|EXAMPLE: typing 'Target' will change       |".
PRINT "|the prompt from ':>' to ':Target:>'        |".
PRINT "|and the thing that you type will go to     |".
PRINT "|the 'Target' field after enter is pressed. |".
PRINT "+-------------------------------------------+".

LOCAL fields IS LEXICON(
    "Execute",LEXICON("maxLength",7,"col",12,"row",1,"str","True","isNum",FALSE,"inFunction",terminal_input_string@)

).
LOCAL exitWords IS LIST(
	"ok",
	"start",
	"affirmative",
	"go",
	"enter"
).
LOCAL prompt IS ":> ".
LOCAL terminalData IS LIST(prompt).
LOCAL terminalRowStart IS 5.
LOCAL termPos IS 0.
LOCAL inField IS "".
LOCAL inFunction IS terminal_input_string@.
LOCAL fieldStr IS "".
LOCAL maxIn IS 45.
FOR key IN fields:KEYS {
	LOCAL field IS fields[key].
	PRINT (field["str"]) AT(field["col"],field["row"]).
}
LOCAL quit IS FALSE.
RCS OFF.
UNTIL quit OR RCS {
	SET termPos TO 0.
	FOR line in terminalData {
		SET termPos TO termPos + 1.
		PRINT "|" + line:PADRIGHT(43) + "|" AT(0,terminalRowStart + termPos).
	}
	LOCAL indentation IS terminalData[terminalData:LENGTH - 1]:LENGTH + 1.
	LOCAL inString IS inFunction(indentation,terminalRowStart + termPos,MIN(44 - indentation,maxIn),fieldStr).
	SET terminalData[terminalData:LENGTH - 1] TO terminalData[terminalData:LENGTH - 1] + inString.
	
	IF inField <> "" {
		LOCAL field IS fields[inField].
		SET field["str"] TO inString.
		PRINT (field["str"]):PADRIGHT(maxIn - 1) AT(field["col"],field["row"]).
		terminalData:ADD(prompt).
		SET inField TO "".
		SET maxIn TO 45.
		SET inFunction TO terminal_input_string@.
		SET fieldStr TO "".
	} ELSE IF fields:HASKEY(inString) {
		SET inField TO inString.
		LOCAL field IS fields[inField].
		SET maxIn TO field["maxLength"].
		SET inFunction TO field["inFunction"].
		SET fieldStr TO field["str"].
		terminalData:ADD(":" + inString + prompt).
	} ELSE IF exitWords:CONTAINS(inString) {
		SET quit TO TRUE.
	} ELSE {
		terminalData:ADD(" Not a valid field or command!").
		terminalData:ADD(prompt).
	}
	UNTIL terminalData:LENGTH <= 6 {
		terminalData:REMOVE(0).
	} 
}
set OM_Execute to fields["Execute"]["str"].

clearscreen.

}
function get_om_mode {
    // Initialize GUI and variables
    local OM_gui is GUI(400, 300).
    set OM_gui:style:width to 400.
    set OM_gui:style:height to 300.

    local confirm_in is false.

    OM_gui:show().
    
    // Title
    local title_box is OM_gui:addhbox().
    set title_box:style:hstretch to true.
    set title_box:style:margin:v to 10.
    local title_label is title_box:addlabel("<size=18><b>Orbital Maneuvering Mode selector</b></size>").
    title_box:show().

    // Input Fields
    local input_box is OM_gui:addvbox().
    set input_box:style:margin:v to 10.
    set input_box:style:margin:h to 10.

    // Target Type Selector
    local OM_MODE_box is input_box:addhlayout().
    local OM_MODE_label is OM_MODE_box :addlabel("OM MODE:").
    local OM_MODE_menu is OM_MODE_box :addpopupmenu().
    OM_MODE_menu:addoption("RSVP").
    OM_MODE_menu:addoption("Rendezvous").
    OM_MODE_menu:addoption("Execute node").
    for command in pos_om_catalog() { OM_MODE_menu:addoption(command["label"]). }

    set OM_MODE_menu:onchange to {
        parameter new_value.
        set OM_Mode to new_value.
    }.
    OM_MODE_box :show().

    input_box:show().

    // OK Button to Finalize Inputs
    local ok_button_box is OM_gui:addhbox().
    set ok_button_box:style:margin:v to 15.
    local ok_button is ok_button_box:addbutton("OK").
    set ok_button:onclick to {
        set confirm_in to true.
        OM_gui:hide().
    }.
    ok_button_box:show().




    // Wait for confirmation
    until confirm_in {
        wait 0.01.
    }
    clearscreen.
    // Return the finalized inputs
    return OM_MODE_menu:value.
}

function get_rendezvous_target {
    local rendezvous_gui is GUI(420,220).
    local confirmed is false.
    rendezvous_gui:show().
    local row is rendezvous_gui:addhbox().
    row:addlabel("<size=18><b>Same-body rendezvous target</b></size>").
    local target_row is rendezvous_gui:addhlayout().
    target_row:addlabel("Vessel:").
    local target_menu is target_row:addpopupmenu().
    target_menu:addoption("None").
    list targets in all_vessels.
    for rendezvous_candidate in all_vessels {
        if rendezvous_candidate <> ship and rendezvous_candidate:body = ship:body {
            target_menu:addoption(rendezvous_candidate:name).
        }
    }
    local button_row is rendezvous_gui:addhbox().
    local ok_button is button_row:addbutton("Plan and execute").
    set ok_button:onclick to { set confirmed to true. rendezvous_gui:hide(). }.
    until confirmed { wait 0.01. }
    return target_menu:value.
}
function get_inputs_Periapsis {
    // Initialize GUI and variables
    local Periapsis_gui is GUI(400, 300).
    set Periapsis_gui:style:width to 400.
    set Periapsis_gui:style:height to 300.

    local confirm_in is false.

    Periapsis_gui:show().
    
    // Title
    local title_box is Periapsis_gui:addhbox().
    set title_box:style:hstretch to true.
    set title_box:style:margin:v to 10.
    local title_label is title_box:addlabel("<size=18><b>Orbital Maneuvering Periapsis</b></size>").
    title_box:show().

    // Input Fields
    local input_box is Periapsis_gui:addvbox().
    set input_box:style:margin:v to 10.
    set input_box:style:margin:h to 10.

    // Target Type Selector
    local Periapsis_box is input_box:addhlayout().
    local Periapsis_label is Periapsis_box :addlabel("location:").
    local Periapsis_menu is Periapsis_box :addpopupmenu().
    Periapsis_menu:addoption("Apoapsis").
    Periapsis_menu:addoption("Periapsis").

    // Target Type Selector
    local Periapsis_alt_box is input_box:addhlayout().
    local Periapsis_alt_label is Periapsis_alt_box:addlabel("Periapsis alt:").
    local Periapsis_alt_menu is Periapsis_alt_box:addtextfield().
 
    local Periapsis_alt_label_value is Periapsis_alt_box:addlabel(Periapsis_alt_menu:text+"Meters").

    Periapsis_box :show().

    input_box:show().

    // OK Button to Finalize Inputs
    local ok_button_box is Periapsis_gui:addhbox().
    set ok_button_box:style:margin:v to 15.
    local ok_button is ok_button_box:addbutton("OK").
    set ok_button:onclick to {
        set confirm_in to true.
        Periapsis_gui:hide().
    }.
    ok_button_box:show().




    // Wait for confirmation
    until confirm_in {
        wait 0.01.
        set Periapsis_alt_label_value:text to (Periapsis_alt_menu:text+"Meters").
    }
    clearscreen.
    // Return the finalized inputs
    return list(Periapsis_menu:value,Periapsis_alt_menu:text).
}
function get_inputs_circliurisation {
    // Initialize GUI and variables
    local circliurisation_gui is GUI(400, 300).
    set circliurisation_gui:style:width to 400.
    set circliurisation_gui:style:height to 300.

    local confirm_in is false.

    circliurisation_gui:show().
    
    // Title
    local title_box is circliurisation_gui:addhbox().
    set title_box:style:hstretch to true.
    set title_box:style:margin:v to 10.
    local title_label is title_box:addlabel("<size=18><b>Orbital Maneuvering circliurisation</b></size>").
    title_box:show().

    // Input Fields
    local input_box is circliurisation_gui:addvbox().
    set input_box:style:margin:v to 10.
    set input_box:style:margin:h to 10.

    // Target Type Selector
    local circliurisation_box is input_box:addhlayout().
    local circliurisation_label is circliurisation_box :addlabel("location:").
    local circliurisation_menu is circliurisation_box :addpopupmenu().
    circliurisation_menu:addoption("Periapsis").
    circliurisation_menu:addoption("Apoapsis").




    circliurisation_box :show().

    input_box:show().

    // OK Button to Finalize Inputs
    local ok_button_box is circliurisation_gui:addhbox().
    set ok_button_box:style:margin:v to 15.
    local ok_button is ok_button_box:addbutton("OK").
    set ok_button:onclick to {
        set confirm_in to true.
        circliurisation_gui:hide().
    }.
    ok_button_box:show().




    // Wait for confirmation
    until confirm_in {
        wait 0.01.
        
    }
    clearscreen.
    // Return the finalized inputs
    return circliurisation_menu:value.
}
function get_inputs_Apoapsis {
    // Initialize GUI and variables
    local Apoapsis_gui is GUI(400, 300).
    set Apoapsis_gui:style:width to 400.
    set Apoapsis_gui:style:height to 300.

    local confirm_in is false.

    Apoapsis_gui:show().
    
    // Title
    local title_box is Apoapsis_gui:addhbox().
    set title_box:style:hstretch to true.
    set title_box:style:margin:v to 10.
    local title_label is title_box:addlabel("<size=18><b>Orbital Maneuvering Apoapsis</b></size>").
    title_box:show().

    // Input Fields
    local input_box is Apoapsis_gui:addvbox().
    set input_box:style:margin:v to 10.
    set input_box:style:margin:h to 10.

    // Target Type Selector
    local Apoapsis_box is input_box:addhlayout().
    local Apoapsis_label is Apoapsis_box :addlabel("location:").
    local Apoapsis_menu is Apoapsis_box :addpopupmenu().
    Apoapsis_menu:addoption("Periapsis").
    Apoapsis_menu:addoption("Apoapsis").


    // Target Type Selector
    local Apoapsis_alt_box is input_box:addhlayout().
    local Apoapsis_alt_label is Apoapsis_alt_box:addlabel("Apoapsis alt:").
    local Apoapsis_alt_menu is Apoapsis_alt_box:addtextfield().
 
    local Apoapsis_alt_label_value is Apoapsis_alt_box:addlabel(Apoapsis_alt_menu:text+"Meters").

    Apoapsis_box :show().

    input_box:show().

    // OK Button to Finalize Inputs
    local ok_button_box is Apoapsis_gui:addhbox().
    set ok_button_box:style:margin:v to 15.
    local ok_button is ok_button_box:addbutton("OK").
    set ok_button:onclick to {
        set confirm_in to true.
        Apoapsis_gui:hide().
    }.
    ok_button_box:show().




    // Wait for confirmation
    until confirm_in {
        wait 0.01.
        set Apoapsis_alt_label_value:text to (Apoapsis_alt_menu:text+"Meters").
    }
    clearscreen.
    // Return the finalized inputs
    return list(Apoapsis_menu:value,Apoapsis_alt_menu:text).
}
function get_inputs_Inclination {
    // Initialize GUI and variables
    local Inclination_gui is GUI(400, 300).
    set Inclination_gui:style:width to 400.
    set Inclination_gui:style:height to 300.

    local confirm_in is false.

    Inclination_gui:show().
    
    // Title
    local title_box is Inclination_gui:addhbox().
    set title_box:style:hstretch to true.
    set title_box:style:margin:v to 10.
    local title_label is title_box:addlabel("<size=18><b>Orbital Maneuvering Inclination</b></size>").
    title_box:show().

    // Input Fields
    local input_box is Inclination_gui:addvbox().
    set input_box:style:margin:v to 10.
    set input_box:style:margin:h to 10.

    // Target Type Selector
    local Inclination_box is input_box:addhlayout().
    local Inclination_label is Inclination_box :addlabel("location:").
    local Inclination_menu is Inclination_box :addpopupmenu().
    Inclination_menu:addoption("Descending").
    Inclination_menu:addoption("Ascending").


    // Target Type Selector
    local Inclination_alt_box is input_box:addhlayout().
    local Inclination_alt_label is Inclination_alt_box:addlabel("Inclination Deg:").
    local Inclination_alt_menu is Inclination_alt_box:addtextfield().
 
    local Inclination_alt_label_value is Inclination_alt_box:addlabel(Inclination_alt_menu:text+"Degrees").

    Inclination_box :show().

    input_box:show().

    // OK Button to Finalize Inputs
    local ok_button_box is Inclination_gui:addhbox().
    set ok_button_box:style:margin:v to 15.
    local ok_button is ok_button_box:addbutton("OK").
    set ok_button:onclick to {
        set confirm_in to true.
        Inclination_gui:hide().
    }.
    ok_button_box:show().




    // Wait for confirmation
    until confirm_in {
        wait 0.01.
        set Inclination_alt_label_value:text to (Inclination_alt_menu:text+"Degrees").
    }
    clearscreen.
    // Return the finalized inputs
    return list(Inclination_menu:value,Inclination_alt_menu:text).
}
