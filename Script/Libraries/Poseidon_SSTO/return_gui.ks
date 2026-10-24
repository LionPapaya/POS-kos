// Passive return display. Never select a target, solve a trajectory or command controls.
// Entry retains the five pages and the original fixed 16-slot energy sampler.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/ascent_recovery_gui.ks").

function return_get {
    parameter record, field, fallback.
    if record:haskey(field) { return record[field]. }
    return fallback.
}

function return_row {
    parameter parent_box, caption.
    return ascent_display_row(parent_box,caption).
}

function return_value {
    parameter field, actual_value, command_value is "--".
    set return_rows[field]["now"]:text to ""+actual_value.
    set return_rows[field]["goal"]:text to ""+command_value.
}

function return_marker {
    parameter parent_box, image_name, marker_size.
    local marker_widget is parent_box:addlabel().
    set marker_widget:image to "Libraries/gui_images/"+image_name+".png".
    set marker_widget:style:width to marker_size.
    set marker_widget:style:height to marker_size.
    set marker_widget:style:hstretch to false. set marker_widget:style:vstretch to false.
    set marker_widget:style:padding:h to 0. set marker_widget:style:padding:v to 0.
    set marker_widget:visible to false.
    return marker_widget.
}

// Widget rectangle placement, including Unity's adjacent-margin MAX rule.
function return_place {
    parameter marker_widget, point_x, point_y, marker_width, marker_height.
    parameter previous_widget, previous_top, previous_height.
    local marker_top is point_y-marker_height/2.
    local margin_delta is marker_top-previous_top-previous_height.
    set previous_widget:style:margin:bottom to min(0,margin_delta).
    set marker_widget:style:margin:top to margin_delta.
    set marker_widget:style:margin:bottom to 0.
    set marker_widget:style:margin:left to point_x-marker_width/2.
    set marker_widget:style:margin:right to 0.
    set marker_widget:style:width to marker_width. set marker_widget:style:height to marker_height.
    set marker_widget:visible to true.
    return marker_top.
}

function create_reentry_gui {
    set reentry_gui:style:width to 680.
    set reentry_gui:style:bg to "Libraries/gui_images/ascent_window.png".
    set reentry_gui:style:padding:h to 16. set reentry_gui:style:padding:v to 16.
    global return_body is reentry_gui:addvlayout().
    local phase_row is return_body:addhlayout().
    global console_titel is phase_row:addlabel("SETUP").
    ascent_display_label_style(console_titel,14).
    set console_titel:style:width to 350.
    global console_time is phase_row:addlabel("Select a runway").
    ascent_display_label_style(console_time,12,"right",true).
    set console_time:style:width to 280.
    global console_mode is "SETUP".
    global return_hero is return_body:addvlayout().
    set return_hero:style:bg to "Libraries/gui_images/ascent_panel.png".
    set return_hero:style:padding:h to 16. set return_hero:style:padding:v to 12.
    global return_title is return_hero:addlabel("RETURN GUIDANCE").
    global return_state_label is return_hero:addlabel("SETUP").
    global return_detail is return_hero:addlabel("Select a landing site and runway above.").
    ascent_display_label_style(return_title,12,"center",true).
    ascent_display_label_style(return_state_label,24,"center").
    ascent_display_label_style(return_detail,12,"center",true).
    global return_predictions is return_hero:addhlayout().
    global return_lower is return_predictions:addlabel("LOWER BANK --").
    global return_upper is return_predictions:addlabel("UPPER BANK --").
    for prediction_label in list(return_lower,return_upper) {
        set prediction_label:style:width to 300.
        ascent_display_label_style(prediction_label,14,"center").
    }
    global return_chart is return_body:addvlayout().
    set return_chart:style:width to 640. set return_chart:style:height to 280.
    set return_chart:style:padding:h to 0. set return_chart:style:padding:v to 0.
    global traj_disp_mainbox is return_chart.
    global return_origin is return_chart:addlabel("").
    set return_origin:style:height to 1. set return_origin:style:width to 1.
    set return_origin:style:padding:h to 0. set return_origin:style:padding:v to 0.
    global traj_disp_prediction_origin is return_origin.
    global traj_disp_prediction_path is list().
    for prediction_dot_index in range(0,16) {
        traj_disp_prediction_path:add(return_marker(return_chart,"entry_path_dot",2)).
    }
    global traj_disp_ssto is return_marker(return_chart,"ascent_vehicle",12).
    // Kept for calibration tools; the old static nominal bug is never displayed.
    global traj_disp_pred is return_marker(return_chart,"guid_pred_bug",8).
    global return_spatial_markers is list().
    for spatial_index in range(0,36) {
        return_spatial_markers:add(return_marker(return_chart,"ascent_path_dot",12)).
    }
    global return_gl_needle is return_marker(return_chart,"return_gl_needle",2).
    global return_gs_needle is return_marker(return_chart,"return_gs_needle",2).
    global return_stop_marker is return_marker(return_chart,"return_stop_marker",2).
    global return_legend is return_body:addlabel("").
    ascent_display_label_style(return_legend,11,"left",true).
    global return_columns is return_row(return_body,"FLIGHT").
    set return_columns["now"]:text to "NOW". set return_columns["goal"]:text to "COMMAND / REF".
    global return_rows is lex().
    for row_name in list("Altitude","Airspeed","Vertical speed","AoA","Bank","GL / centerline","GS / glideslope","Runway remaining","Est. stop distance") {
        return_rows:add(row_name,return_row(return_body,row_name)).
    }
    global return_next is return_body:addlabel("").
    global return_footer is return_body:addlabel("").
    ascent_display_label_style(return_next,13).
    ascent_display_label_style(return_footer,11,"left",true).
    global return_display_state is lex("next_update",-1,"mode","","track",list(),
        "track_ut",-1,"stop_sample_ut",-1,"stop_sample_speed",0,"stop_valid",false,
        "stop_deceleration",0,"stop_reason","not_on_ground","stop_distance",0,"stop_margin",0,
        "guidance_state","SETUP","cross_track",0,"glideslope_error",0,"runway_remaining",0,
        "angular_valid",false,"gl_angle",0,"gs_angle",0).
}

// Measured deceleration extrapolation only, with no fitted friction coefficient.
// Require continuous contact/braking and at least 1 s of speed history. No
// previous estimate survives a bounce, brake release, acceleration or long gap.
function return_stop_observe {
    parameter state, now_ut, ground_speed, on_ground, wheel_braking.
    local result is state:copy.
    set result["stop_valid"] to false.
    set result["stop_reason"] to "collecting_deceleration".
    if not on_ground or not wheel_braking {
        set result["stop_sample_ut"] to -1.
        set result["stop_deceleration"] to 0.
        set result["stop_reason"] to "not_braking".
        if not on_ground { set result["stop_reason"] to "not_on_ground". }
        return result.
    }
    if ground_speed < 1 {
        set result["stop_valid"] to true. set result["stop_distance"] to 0.
        set result["stop_reason"] to "stopped".
        return result.
    }
    local sample_ut is result["stop_sample_ut"].
    if sample_ut < 0 or now_ut-sample_ut > 2.5 or now_ut < sample_ut {
        set result["stop_sample_ut"] to now_ut.
        set result["stop_sample_speed"] to ground_speed.
        set result["stop_deceleration"] to 0.
        return result.
    }
    if ground_speed > result["stop_sample_speed"] {
        set result["stop_sample_ut"] to now_ut.
        set result["stop_sample_speed"] to ground_speed.
        set result["stop_deceleration"] to 0.
        set result["stop_reason"] to "accelerating".
        return result.
    }
    local elapsed_seconds is now_ut-sample_ut.
    if elapsed_seconds < 1 {
        set result["stop_valid"] to result["stop_deceleration"] >= 0.2.
    } else {
        local deceleration is (result["stop_sample_speed"]-ground_speed)/elapsed_seconds.
        set result["stop_sample_ut"] to now_ut.
        set result["stop_sample_speed"] to ground_speed.
        // Use the weaker of two successive measured intervals, not optimistic smoothing.
        if result["stop_deceleration"] >= 0.2 {
            set deceleration to min(deceleration,result["stop_deceleration"]).
        }
        set result["stop_deceleration"] to deceleration.
        set result["stop_valid"] to deceleration >= 0.2.
    }
    if result["stop_valid"] {
        set result["stop_distance"] to ground_speed*ground_speed/(2*result["stop_deceleration"]).
        set result["stop_reason"] to "measured_deceleration".
    } else { set result["stop_reason"] to "insufficient_deceleration". }
    return result.
}

// Page bounds are identical to the existing five entry displays.
function return_entry_page {
    parameter display_mode.
    local pages is list(
        list(entry_nominal_traj1_energy_min,entry_nominal_traj1_energy_max,entry_nominal_traj1_range_min,entry_nominal_traj1_range_max),
        list(entry_nominal_traj2_energy_min,entry_nominal_traj2_energy_max,entry_nominal_traj2_range_min,entry_nominal_traj2_range_max),
        list(entry_nominal_traj3_energy_min,entry_nominal_traj3_energy_max,entry_nominal_traj3_range_min,entry_nominal_traj3_range_max),
        list(entry_nominal_traj4_energy_min,entry_nominal_traj4_energy_max,entry_nominal_traj4_range_min,entry_nominal_traj4_range_max),
        list(entry_nominal_traj5_energy_min,entry_nominal_traj5_energy_max,entry_nominal_traj5_range_min,entry_nominal_traj5_range_max)).
    for page_index in range(0,5) {
        if display_mode = "TRAJ "+(page_index+1)+" V/SIT" {
            return lex("number",page_index+1,"energy_min",pages[page_index][0],"energy_max",pages[page_index][1],
                "range_min",pages[page_index][2],"range_max",pages[page_index][3]).
        }
    }
    return lex("number",0).
}

function return_entry_xy {
    parameter energy_height, range_m, page.
    return lex("x",52+568*(energy_height-page["energy_min"])/(page["energy_max"]-page["energy_min"]),
        "y",232-208*(range_m-page["range_min"])/(page["range_max"]-page["range_min"])).
}

function return_signed_range {
    parameter residual.
    local sign_text is "+". if residual < 0 { set sign_text to "". }
    return sign_text+round(residual/1000,2)+" km".
}

function return_render_entry {
    parameter inputs, page.
    set return_chart:style:bg to "Libraries/gui_images/return_entry_"+page["number"]+".png".
    set return_title:text to "ENTRY GUIDANCE".
    set return_state_label:text to "PLANNING / WAITING".
    set return_detail:text to "Waiting for a converged entry plan".
    set return_lower:text to "LOWER BANK --". set return_upper:text to "UPPER BANK --".
    local basic_mode is false.
    if defined basice_reentry_guidance { set basic_mode to basice_reentry_guidance. }
    if basic_mode {
        set return_state_label:text to "BASIC FALLBACK".
        set return_detail:text to "Basic guidance active / predictive candidates unavailable".
    } else if defined entry_traj and entry_traj:haskey("converged") and entry_traj["converged"] {
        set return_state_label:text to "CONVERGED / PREDICTIVE".
        set return_detail:text to "Plan converged / waiting for predictive update".
        if defined entry_predictive_frozen and entry_predictive_frozen {
            set return_state_label:text to "PREDICTIVE / BANK HELD".
            set return_detail:text to "Low sensitivity / last candidate snapshot / bank update frozen".
        } else if defined entry_predictive_valid and entry_predictive_valid {
            set return_detail:text to "Predictive update valid / signed range error to TEAM target".
        }
        if defined entry_predictive_next_update and entry_predictive_next_update > 0 and
           (entry_predictive_valid or entry_predictive_frozen) {
            set return_lower:text to "LOWER BANK "+round(entry_predictive_lower_bank,1)+" deg\n"+
                return_signed_range(entry_predictive_lower_range_error).
            set return_upper:text to "UPPER BANK "+round(entry_predictive_upper_bank,1)+" deg\n"+
                return_signed_range(entry_predictive_upper_range_error).
        }
    }
    local energy_height is entry_nominal_energy_height(inputs["alt"],inputs["spd"]).
    local points is list().
    if return_get(inputs,"prediction_path_valid",false) and not basic_mode {
        set points to reentry_vsit_display_points(return_get(inputs,"prediction_path",list()),
            page["energy_min"],page["energy_max"],page["range_min"],page["range_max"],energy_height).
    }
    local previous_widget is return_origin. local previous_top is 0. local previous_height is 1.
    for marker_index in range(0,points:length) {
        local point_xy is return_entry_xy(points[marker_index]["energy"],points[marker_index]["range"],page).
        local marker_widget is traj_disp_prediction_path[marker_index].
        set previous_top to return_place(marker_widget,point_xy["x"],point_xy["y"],2,2,
            previous_widget,previous_top,previous_height).
        set previous_widget to marker_widget. set previous_height to 2.
    }
    if energy_height >= page["energy_min"] and energy_height <= page["energy_max"] and
       inputs["range_remaining"] >= page["range_min"] and inputs["range_remaining"] <= page["range_max"] {
        local vehicle_xy is return_entry_xy(energy_height,inputs["range_remaining"],page).
        return_place(traj_disp_ssto,vehicle_xy["x"],vehicle_xy["y"],12,12,previous_widget,previous_top,previous_height).
    }
    set return_legend:text to "Historical band: reference only / prediction dots / vehicle: circle".
    set return_next:text to "NEXT: TEAM interface / "+inputs["mode"].
    // No nominal-deviation number: this average is neither a command nor a safety envelope.
}

function return_render_team {
    parameter inputs.
    set return_title:text to "TERMINAL GUIDANCE".
    set return_state_label:text to Location+" RWY "+runway_nr.
    local route_phase is return_get(terminal_route,"phase","waiting").
    set return_detail:text to "TEAM / "+route_phase+" / runway-relative view".
    set return_chart:style:height to 200.
    set return_chart:style:bg to "Libraries/gui_images/ascent_panel.png".
    local track_samples is return_display_state["track"].
    if time:seconds-return_display_state["track_ut"] >= 2 {
        track_samples:add(ship:geoposition).
        if track_samples:length > 24 { track_samples:remove(0). }
        set return_display_state["track_ut"] to time:seconds.
    }
    local positions is list(runway_start). local kinds is list("runway").
    for track_position in track_samples { positions:add(track_position). kinds:add("track"). }
    local route_positions is reentry_lsit_terminal_path().
    for route_position in route_positions { positions:add(route_position). kinds:add("fix"). }
    positions:add(ship:geoposition). kinds:add("vehicle").
    local raw_points is list().
    for point_index in range(0,positions:length) {
        local frame_point is ascent_recovery_xy(calcdistance_m(runway_start,positions[point_index]),
            heading_between(runway_start,positions[point_index]),runway_heading).
        set frame_point["kind"] to kinds[point_index]. raw_points:add(frame_point).
    }
    local mapped is ascent_recovery_map(raw_points).
    local previous_widget is return_origin. local previous_top is 0. local previous_height is 1.
    for point_index in range(0,min(mapped["points"]:length,return_spatial_markers:length)) {
        local point_xy is mapped["points"][point_index].
        local marker_widget is return_spatial_markers[point_index].
        local image_name is "ascent_path_dot".
        if point_xy["kind"] = "runway" { set image_name to "ascent_runway". }
        if point_xy["kind"] = "fix" { set image_name to "ascent_target". }
        if point_xy["kind"] = "vehicle" { set image_name to "ascent_vehicle". }
        set marker_widget:image to "Libraries/gui_images/"+image_name+".png".
        set previous_top to return_place(marker_widget,point_xy["x"],point_xy["y"],12,12,
            previous_widget,previous_top,previous_height).
        set previous_widget to marker_widget. set previous_height to 12.
    }
    set return_legend:text to "Runway rectangle / flown track dots / guidance crosses / vehicle circle\n"+
        "Runway frame span "+round(mapped["scale_m"]/1000,1)+" km / symbols not to scale".
    set return_next:text to "NEXT: Final intercept / GL and GS capture".
}

// Angular AIRCRAFT deviation, not fly-to commands. kOS trig uses degrees.
// GS compares elevation angles to the current profile point; this preserves
// the steep/preflare/shallow profile rather than assuming a fixed 3deg slope.
function return_final_needles {
    parameter cross_track, along_track, horizontal_range, height_above_runway, reference_height.
    local result is lex("valid",false,"gl_angle",0,"gs_angle",0,"gl_x",320,"gs_y",140).
    // There is no forward approach reference at or beyond the threshold.
    if along_track <= 0 or horizontal_range <= 0 { return result. }
    local gl_angle is arctan2(-cross_track,along_track).
    local gs_angle is arctan2(height_above_runway,horizontal_range)-
        arctan2(reference_height,horizontal_range).
    set result["valid"] to true.
    set result["gl_angle"] to gl_angle. set result["gs_angle"] to gs_angle.
    set result["gl_x"] to 320+max(-1,min(1,gl_angle/2.5))*150.
    set result["gs_y"] to 140-max(-1,min(1,gs_angle/0.7))*85.
    return result.
}

function return_render_final {
    parameter inputs, geometry.
    set return_title:text to "FINAL APPROACH".
    set return_state_label:text to "GL / GS".
    local reference_altitude is calculate_glideslope_alt(geometry["distance"]).
    local gs_error is inputs["alt"]-reference_altitude.
    set return_display_state["cross_track"] to geometry["cross_track"].
    set return_display_state["glideslope_error"] to gs_error.
    // reentry_lsit_geometry uses outward heading: negative XTK is runway-right.
    local lateral_text is "RIGHT". if geometry["cross_track"] > 0 { set lateral_text to "LEFT". }
    local vertical_text is "HIGH". if gs_error < 0 { set vertical_text to "LOW". }
    set return_detail:text to "GL "+round(abs(geometry["cross_track"]),1)+" m "+lateral_text+
        " / GS "+round(abs(gs_error),1)+" m "+vertical_text.
    set return_chart:style:bg to "Libraries/gui_images/return_final.png".
    local needles is return_final_needles(geometry["cross_track"],geometry["along_track"],geometry["distance"],
        inputs["alt"]-runway_altitude,reference_altitude-runway_altitude).
    set return_display_state["angular_valid"] to needles["valid"].
    set return_display_state["gl_angle"] to needles["gl_angle"].
    set return_display_state["gs_angle"] to needles["gs_angle"].
    if needles["valid"] {
        local first_top is return_place(return_gl_needle,needles["gl_x"],140,3,150,return_origin,0,1).
        return_place(return_gs_needle,320,needles["gs_y"],260,3,return_gl_needle,first_top,150).
        set return_detail:text to return_detail:text+"\nGL "+round(needles["gl_angle"],2)+" deg / GS "+round(needles["gs_angle"],2)+" deg".
    }
    set return_legend:text to "Aircraft angular deviation / GL scale +/-2.5 deg / GS +/-0.7 deg".
    if not needles["valid"] { set return_legend:text to "Threshold passed / angular reference unavailable / metre offsets retained". }
    return_value("GL / centerline",round(abs(geometry["cross_track"]),1)+" m "+lateral_text,"0 m").
    return_value("GS / glideslope",round(abs(gs_error),1)+" m "+vertical_text,"0 m").
    set return_next:text to "NEXT: Preflare / flare / "+round(geometry["distance"]/1000,2)+" km to threshold".
}

function return_render_rollout {
    parameter inputs, geometry.
    local runway_length is calcdistance_m(runway_start,runway_end).
    local remaining_distance is runway_length+geometry["along_track"].
    set return_display_state["cross_track"] to geometry["cross_track"].
    set return_display_state["runway_remaining"] to remaining_distance.
    set return_display_state to return_stop_observe(return_display_state,time:seconds,ship:groundspeed,
        ship:status = "LANDED",brakes).
    set return_display_state["stop_margin"] to remaining_distance-return_display_state["stop_distance"].
    set return_title:text to "PREDICTED STOPPING MARGIN".
    set return_state_label:text to "-- / UNAVAILABLE".
    ascent_display_label_style(return_state_label,24,"center").
    set return_detail:text to "Collecting measured ground deceleration / "+return_display_state["stop_reason"].
    local previous_widget is return_origin. local previous_top is 0. local previous_height is 1.
    set return_chart:style:bg to "Libraries/gui_images/return_rollout.png".
    local runway_scale is max(1,runway_length).
    local vehicle_x is 52+min(1.15,max(-0.05,-geometry["along_track"]/runway_scale))*500.
    set previous_top to return_place(traj_disp_ssto,vehicle_x,140,12,12,previous_widget,previous_top,previous_height).
    if return_display_state["stop_valid"] {
        set return_state_label:text to round(return_display_state["stop_margin"])+" m".
        if return_display_state["stop_margin"] >= 0 {
            set return_state_label:text to "+"+round(return_display_state["stop_margin"])+" m".
        } else { set return_state_label:style:textcolor to RGBA(0.94,0.66,0.63,1). }
        set return_detail:text to "Measured deceleration extrapolation / braking must continue".
        local stop_x is vehicle_x+return_display_state["stop_distance"]/runway_scale*500.
        // Out-of-strip predictions stay off the strip; the number retains the full margin.
        if stop_x >= 35 and stop_x <= 625 {
            return_place(return_stop_marker,stop_x,140,3,44,traj_disp_ssto,previous_top,12).
        } else { set return_detail:text to "Predicted stop off strip / full margin shown above". }
    }
    local side_text is "RIGHT". if geometry["cross_track"] > 0 { set side_text to "LEFT". }
    return_value("GL / centerline",round(abs(geometry["cross_track"]),1)+" m "+side_text,"0 m").
    set return_rows["Airspeed"]["caption"]:text to "Ground speed".
    return_value("Airspeed",round(ship:groundspeed,1)+" m/s","STOP").
    return_value("Runway remaining",round(remaining_distance)+" m","Runway end").
    return_value("Est. stop distance","--","Unavailable").
    if return_display_state["stop_valid"] {
        return_value("Est. stop distance",round(return_display_state["stop_distance"])+" m","MEASURED TREND").
    }
    set return_legend:text to "Vehicle circle / cyan stop marker / full strip = "+round(runway_length)+" m".
    set return_next:text to "NEXT: Full stop".
}

function update_reentry_gui {
    parameter inputs is lex("mode",console_mode,"alt",ship:altitude,"spd",ship:airspeed,
        "range_remaining",0,"aoa",calc_aoa(),"roll",roll_for(),"mach",ADDONS:FAR:mach,"l/d",0).
    if not defined return_display_state { return. }
    local display_mode is inputs["mode"].
    if defined step and (step = "TEAM" or step = "landing") and defined terminal_route {
        set display_mode to "L/SIT 1".
        if terminal_route["phase"] = "base" { set display_mode to "L/SIT 2". }
        if terminal_route["phase"] = "final" or step = "landing" {
            // A straight-in arrival can enter final well outside the pattern.
            // Retain TEAM until within the live base waypoint's threshold range.
            local base_range is calcdistance_m(runway_start,terminal_route["base_fix"]).
            local threshold_range is calcdistance_m(runway_start,ship:geoposition).
            if threshold_range <= base_range { set display_mode to "FINAL". }
        }
        if ship:status = "LANDED" or (defined landing_ground_contact_seen and landing_ground_contact_seen) {
            set display_mode to "ROLLOUT".
        }
    }
    // Source loop can run at control frequency; the UI updates at 2 Hz. Force
    // phase transitions immediately, without adding work to prediction loops.
    if time:seconds < return_display_state["next_update"] and display_mode = return_display_state["mode"] { return. }
    if display_mode <> return_display_state["mode"] and
       not ((display_mode = "L/SIT 1" or display_mode = "L/SIT 2") and
            (return_display_state["mode"] = "L/SIT 1" or return_display_state["mode"] = "L/SIT 2")) {
        set return_display_state["track"] to list().
        set return_display_state["track_ut"] to -1.
    }
    set return_display_state["mode"] to display_mode.
    set return_display_state["next_update"] to time:seconds+0.5.
    global reentry_display_active_mode is display_mode.
    set console_titel:text to display_mode.
    if defined Location and defined runway_nr { set console_time:text to Location+" RWY "+runway_nr. }
    set return_origin:style:margin:bottom to 0.
    for marker_widget in traj_disp_prediction_path { set marker_widget:visible to false. }
    for marker_widget in return_spatial_markers { set marker_widget:visible to false. }
    for marker_widget in list(traj_disp_ssto,traj_disp_pred,return_gl_needle,return_gs_needle,return_stop_marker) {
        set marker_widget:visible to false.
    }
    set return_chart:style:height to 280.
    set return_display_state["angular_valid"] to false.
    local page is return_entry_page(display_mode).
    local is_entry is page["number"] > 0.
    set return_predictions:visible to is_entry.
    set return_chart:visible to is_entry or display_mode = "L/SIT 1" or display_mode = "L/SIT 2" or
        display_mode = "FINAL" or display_mode = "ROLLOUT".
    for field_name in return_rows:keys { set return_rows[field_name]["box"]:visible to false. }
    for field_name in list("Altitude","Airspeed","Vertical speed","AoA","Bank") {
        set return_rows[field_name]["box"]:visible to true.
    }
    return_value("Altitude",round(inputs["alt"])+" m ASL").
    set return_rows["Airspeed"]["caption"]:text to "Airspeed".
    return_value("Airspeed",round(inputs["spd"],1)+" m/s").
    return_value("Vertical speed",round(ship:verticalspeed,1)+" m/s").
    return_value("AoA",round(return_get(inputs,"aoa",0),1)+" deg").
    return_value("Bank",round(return_get(inputs,"roll",0),1)+" deg").
    if defined dap {
        return_value("AoA",round(return_get(inputs,"aoa",0),1)+" deg",round(dap["aoa"]["target_aoa"],1)+" deg").
        return_value("Bank",round(return_get(inputs,"roll",0),1)+" deg",round(dap["aoa"]["target_bank"],1)+" deg").
    }
    set return_legend:text to "". set return_next:text to "".
    ascent_display_label_style(return_state_label,24,"center").
    if is_entry { return_render_entry(inputs,page). }
    else if (display_mode = "L/SIT 1" or display_mode = "L/SIT 2") and defined terminal_route {
        return_render_team(inputs).
        if defined terminal_route_debug {
            return_value("Altitude",round(inputs["alt"])+" m ASL",round(return_get(terminal_route_debug,"target_altitude",0))+" m ASL").
            return_value("Vertical speed",round(ship:verticalspeed,1)+" m/s",round(return_get(terminal_route_debug,"desired_vertical_speed",0),1)+" m/s").
        }
    } else if display_mode = "FINAL" or display_mode = "ROLLOUT" {
        local geometry is reentry_lsit_geometry(ship:geoposition).
        for field_name in list("AoA","Bank") { set return_rows[field_name]["box"]:visible to false. }
        set return_rows["GL / centerline"]["box"]:visible to true.
        if display_mode = "FINAL" {
            set return_rows["GS / glideslope"]["box"]:visible to true.
            return_render_final(inputs,geometry).
        } else {
            set return_rows["Runway remaining"]["box"]:visible to true.
            set return_rows["Est. stop distance"]["box"]:visible to true.
            return_render_rollout(inputs,geometry).
        }
    } else {
        set return_title:text to "RETURN GUIDANCE".
        set return_state_label:text to display_mode.
        set return_detail:text to "Select target / monitor current flight state".
    }
    if display_mode <> "ROLLOUT" {
        set return_display_state["stop_sample_ut"] to -1.
        set return_display_state["stop_valid"] to false.
        set return_display_state["stop_deceleration"] to 0.
    }
    set return_display_state["guidance_state"] to return_state_label:text.
    if display_mode = "ROLLOUT" { set return_display_state["guidance_state"] to "ROLLOUT". }
    set return_footer:text to "DAP "+dap["dap_mode"]+" / 2 Hz display / "+timestamp():clock.
}
