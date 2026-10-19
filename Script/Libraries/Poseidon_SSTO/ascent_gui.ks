// Passive ascent display. Two ascent pages, then a separate insertion page.
// No steering, throttle, engine or abort decisions belong in this library.

function ascent_display_page {
    parameter flight_phase, recovery_phase_name is "", nominal_insertion is false.
    if flight_phase = "circ" or
       (flight_phase = "ato" and (recovery_phase_name = "coast_align" or recovery_phase_name = "insert" or
        (recovery_phase_name = "complete" and nominal_insertion))) { return "CIRC". }
    if flight_phase = "closed_cycle_climb" or flight_phase = "apoapsis_build" or
       flight_phase = "ato" { return "ASCENT 2 / 2". }
    return "ASCENT 1 / 2".
}

// Pixel coordinates match ascent_climb.png. Off-chart markers are hidden,
// never pinned to an edge where they could look like a valid trajectory.
function ascent_display_point {
    parameter chart_altitude, chart_speed.
    return lex("visible",chart_altitude >= 0 and chart_altitude <= 30000 and
        chart_speed >= 0 and chart_speed <= 1800,
        "x",52+568*max(0,min(1800,chart_speed))/1800,
        "y",192-168*max(0,min(30000,chart_altitude))/30000).
}

function ascent_display_health {
    parameter sample.
    if sample["finished"] { return "FINISHED - inspect final orbit / outcome". }
    if sample["recovery"] { return "RECOVERY - "+sample["phase"]. }
    if not sample["orbit_valid"] { return "CHECK - open trajectory / apsis data unavailable". }
    if sample["dap_mode"] <> "auto" and sample["dap_mode"] <> "AUTO" { return "MANUAL - DAP "+sample["dap_mode"]. }
    if sample["protection"] <> "normal" { return "PROTECTION - "+sample["protection"]. }
    if sample["phase"] = "rendezvous_window" { return "WAITING - rendezvous launch window". }
    if not sample["command_valid"] { return "MONITORING - steering command unavailable". }
    if sample["attitude_error"] > 5 { return "CHECK - steering error > 5 deg". }
    if sample["page"] = "CIRC" and sample["phase"] = "coast_align" {
        return "COAST / ALIGN - waiting for insertion window".
    }
    if not sample["progress_valid"] { return "MONITORING - measuring phase progress". }
    if sample["page"] = "ASCENT 2 / 2" and sample["apo_rate"] <= 0 {
        return "CHECK - apoapsis not increasing".
    }
    if sample["page"] = "CIRC" and sample["throttle"] > 0 and sample["peri_rate"] <= 0 {
        return "CHECK - periapsis not increasing".
    }
    if sample["page"] = "ASCENT 1 / 2" {
        if sample["phase"] = "launch" or sample["phase"] = "speed_build" {
            if sample["speed_rate"] <= 0 { return "CHECK - airspeed not increasing". }
        } else if sample["phase"] <> "rendezvous_window" and sample["vertical_speed"] <= 0 {
            return "CHECK - vehicle not climbing".
        }
        if sample["phase"] = "high_altitude_climb" and sample["speed_rate"] <= 0 {
            return "CHECK - climb is not gaining speed".
        }
    }
    return "TRACKING - steering within 5 deg / progress observed".
}

function ascent_display_init {
    global ascent_display_state is lex("next_update",0,"origin",ship:geoposition,
        "trend_ut",-1,"trend_phase","","speed",0,"apo",0,"peri",0,
        "progress_valid",false,"speed_rate",0,"apo_rate",0,"peri_rate",0).
    global ascent_display_log is lex("page","","phase","","health","","next_sample",0,"last_ut",-1).
}

function ascent_display_collect {
    local cfg is AVES["Ascent"].
    local display_phase is step.
    local recovery_phase_name is "".
    local nominal_insert is false.
    local recovering is false.
    local finished is step = "end".
    local display_outcome is "".
    if defined abort_state and abort_state:haskey("mode") {
        set recovery_phase_name to abort_state["phase"].
        set recovering to abort_state["active"].
        if abort_state:haskey("nominal_insertion") { set nominal_insert to abort_state["nominal_insertion"]. }
        if nominal_insert { set recovering to false. }
        if abort_state["mode"] = "ato" and (step = "ato" or finished) {
            set display_phase to "ato".
        }
        if finished and abort_state:haskey("result") { set display_outcome to abort_state["result"]["reason"]. }
    }
    local page_name is ascent_display_page(display_phase,recovery_phase_name,nominal_insert).
    if display_phase = "ato" { set display_phase to recovery_phase_name. }
    local sample is lex("ut",time:seconds,"phase",display_phase,"page",page_name,
        "finished",finished,"recovery",recovering,"outcome",display_outcome,
        "dap_mode",dap["dap_mode"],"protection",dap["envelope"]["state"],
        "altitude",ship:altitude,"airspeed",ship:airspeed,"surface_speed",ship:velocity:surface:mag,
        "vertical_speed",ship:verticalspeed,"apoapsis",0,"periapsis",0,
        "orbit_valid",ship:orbit:eccentricity < 1,
        "inclination",ship:orbit:inclination,"eta_apoapsis",0,
        "target_ap",TargetApoapsis,"target_pe",TargetPeriapsis,"target_inc",TargetInclination,
        "climb_alt",cfg["climb_altitude"],"climb_speed",cfg["climb_target_speed"],
        "cutoff_ap",TargetApoapsis+cfg["apoapsis_margin"],
        "pitch",pitch_for(),"heading",compass_for(),"command_valid",false,
        "pitch_command",0,"heading_command",0,"attitude_error",0,"command_kind","none",
        "throttle",dapthrottle,"rapier_mode",rapier_mode,"rapiers",rapiers,"nervs",nervs,
        "downrange",calcdistance_m(ascent_display_state["origin"],ship:geoposition),
        "elapsed",0,"burn_seconds",-1,"alignment",-1).
    // kOS can throw while pushing an infinite apsis suffix onto its stack.
    // Avoid reading those suffixes at all on an escape trajectory.
    if sample["orbit_valid"] {
        set sample["apoapsis"] to ship:apoapsis.
        set sample["periapsis"] to ship:periapsis.
        set sample["eta_apoapsis"] to ship:orbit:eta:apoapsis.
    }
    if defined t0 and t0 >= 0 { set sample["elapsed"] to max(0,time:seconds-t0). }
    if dap["dap_mode"] = "auto" or dap["dap_mode"] = "AUTO" {
        if dap["str_mode"] = "aerostr" or dap["str_mode"] = "aoa" {
            local command_group is dap["aerostr"].
            local pitch_key is "targetPitch".
            local heading_key is "targetDirection".
            if dap["str_mode"] = "aoa" {
                set command_group to dap["aoa"].
                set pitch_key to "aoa_pitch". set heading_key to "aoa_yaw".
            }
            set sample["pitch_command"] to command_group[pitch_key].
            set sample["heading_command"] to command_group[heading_key].
            set sample["attitude_error"] to max(abs(sample["pitch"]-sample["pitch_command"]),
                abs(normalized_heading_error(sample["heading"],sample["heading_command"]))).
            set sample["command_kind"] to "angles".
            set sample["command_valid"] to true.
        } else if dap["str_mode"] = "vector" {
            set sample["command_kind"] to "vector".
            set sample["command_valid"] to dap["vector"]["targetVector"]:mag > 0.
            if sample["command_valid"] {
                set sample["attitude_error"] to vang(ship:facing:vector,dap["vector"]["targetVector"]).
            }
        }
        // The ascent executive directly locks dap_steering to prograde here.
        if ship:altitude > cfg["space_altitude"] and
           (step = "apoapsis_build" or step = "closed_cycle_climb") {
            set sample["command_kind"] to "prograde".
            set sample["command_valid"] to ship:velocity:orbit:mag > 0.
            if sample["command_valid"] {
                set sample["attitude_error"] to vang(ship:facing:vector,ship:velocity:orbit).
            }
        }
    }
    if defined abort_state and nominal_insert {
        if abort_state:haskey("burn_seconds") { set sample["burn_seconds"] to abort_state["burn_seconds"]. }
        if abort_state:haskey("alignment") { set sample["alignment"] to abort_state["alignment"]. }
    }
    // Measure progress over elapsed seconds, never per control-loop iteration.
    local trend_dt is time:seconds-ascent_display_state["trend_ut"].
    if display_phase <> ascent_display_state["trend_phase"] or trend_dt > 3 or trend_dt < 0 {
        set ascent_display_state["trend_ut"] to -1.
        set ascent_display_state["progress_valid"] to false.
    }
    if ascent_display_state["trend_ut"] < 0 or trend_dt >= 2 {
        if ascent_display_state["trend_ut"] >= 0 {
            set ascent_display_state["speed_rate"] to (ship:airspeed-ascent_display_state["speed"])/trend_dt.
            set ascent_display_state["apo_rate"] to (sample["apoapsis"]-ascent_display_state["apo"])/trend_dt.
            set ascent_display_state["peri_rate"] to (sample["periapsis"]-ascent_display_state["peri"])/trend_dt.
            set ascent_display_state["progress_valid"] to true.
        }
        set ascent_display_state["trend_ut"] to time:seconds.
        set ascent_display_state["trend_phase"] to display_phase.
        set ascent_display_state["speed"] to ship:airspeed.
        set ascent_display_state["apo"] to sample["apoapsis"].
        set ascent_display_state["peri"] to sample["periapsis"].
    }
    for trend_key in list("progress_valid","speed_rate","apo_rate","peri_rate") {
        set sample[trend_key] to ascent_display_state[trend_key].
    }
    set sample["health"] to ascent_display_health(sample).
    return sample.
}

// Ordinary labels in horizontal rows. Fixed column widths keep changing
// values aligned without relying on tabs or a platform-specific font.
function ascent_display_row {
    parameter parent_box, row_name.
    local row_box is parent_box:addhlayout().
    local caption is row_box:addlabel(row_name).
    set caption:style:width to 220.
    local now_label is row_box:addlabel("--").
    set now_label:style:width to 205. set now_label:style:align to "right".
    local goal_label is row_box:addlabel("--").
    set goal_label:style:width to 205. set goal_label:style:align to "right".
    return lex("box",row_box,"now",now_label,"goal",goal_label).
}

function create_assent_gui {
    global assent_gui is gui(680).
    set assent_gui:style:width to 680.
    local title_row is assent_gui:addhlayout().
    local title_label is title_row:addlabel("<b>POSEIDON ASCENT</b>").
    set title_label:style:width to 550.
    global assent_minb is title_row:addbutton("-").
    set assent_minb:toggle to true.
    global assent_quitb is title_row:addbutton("X").
    global ascent_display_body is assent_gui:addvlayout().
    set assent_minb:onclick to {
        set ascent_display_body:visible to not assent_minb:pressed.
    }.
    set assent_quitb:onclick to { set step to "end". assent_gui:hide(). }.
    local mode_row is ascent_display_body:addhlayout().
    mode_row:addlabel("DAP").
    global assent_dap_mode_menu is mode_row:addpopupmenu().
    for mode_name in list("AUTO","CSS","OFF") { assent_dap_mode_menu:addoption(mode_name). }
    set assent_dap_mode_menu:value to "AUTO".
    set assent_dap_mode_menu:onchange to {
        parameter selected_mode.
        set dap["dap_mode"] to selected_mode.
    }.
    global ascent_display_target is mode_row:addlabel("Target orbit: setup").
    global ascent_display_setup is ascent_display_body:addvbox().
    local target_row is ascent_display_setup:addhlayout().
    target_row:addlabel("Ap (m)").
    global assent_apoapsis_input is target_row:addtextfield("80000").
    set assent_apoapsis_input:style:width to 100.
    target_row:addlabel("Pe (m)").
    global assent_periapsis_input is target_row:addtextfield("80000").
    set assent_periapsis_input:style:width to 100.
    target_row:addlabel("Inc (deg)").
    global assent_inclination_input is target_row:addtextfield("0").
    set assent_inclination_input:style:width to 70.
    local rendezvous_row is ascent_display_setup:addhlayout().
    rendezvous_row:addlabel("Rendezvous").
    global assent_rendezvous_menu is rendezvous_row:addpopupmenu().
    assent_rendezvous_menu:addoption("None").
    set assent_rendezvous_menu:value to "None".
    list targets in all_vessels.
    for rendezvous_candidate in all_vessels {
        if rendezvous_candidate <> ship and rendezvous_candidate:body = ship:body {
            assent_rendezvous_menu:addoption(rendezvous_candidate:name).
        }
    }
    local start_button is ascent_display_setup:addbutton("Start ascent").
    global ascent_display_setup_message is ascent_display_setup:addlabel("Set the target orbit, then start.").
    set start_button:onclick to {
        local input_ap is assent_apoapsis_input:text:tonumber(-1).
        local input_pe is assent_periapsis_input:text:tonumber(-1).
        local input_inc is assent_inclination_input:text:tonumber(-999).
        if input_pe > ship:body:atm:height and input_ap >= input_pe and abs(input_inc) <= 180 {
            set confirm_in to true.
        } else {
            set ascent_display_setup_message:text to "Use Ap >= Pe, Pe above atmosphere, inclination -180..180 deg.".
        }
    }.
    global ascent_display_flight is ascent_display_body:addvlayout().
    ascent_display_flight:hide().
    global ascent_display_heading is ascent_display_flight:addlabel().
    global ascent_display_status is ascent_display_flight:addlabel().
    global ascent_display_chart is ascent_display_flight:addvlayout().
    set ascent_display_chart:style:width to 640. set ascent_display_chart:style:height to 230.
    set ascent_display_chart:style:bg to "Libraries/gui_images/ascent_climb.png".
    set ascent_display_chart:style:padding:h to 0. set ascent_display_chart:style:padding:v to 0.
    global ascent_display_vehicle is ascent_display_chart:addlabel().
    set ascent_display_vehicle:image to "Libraries/gui_images/ascent_vehicle.png".
    global ascent_display_goal is ascent_display_chart:addlabel().
    set ascent_display_goal:image to "Libraries/gui_images/ascent_target.png".
    for chart_marker in list(ascent_display_vehicle,ascent_display_goal) {
        set chart_marker:style:width to 12. set chart_marker:style:height to 12.
        set chart_marker:style:hstretch to false. set chart_marker:style:vstretch to false.
        set chart_marker:style:padding:h to 0. set chart_marker:style:padding:v to 0.
        set chart_marker:style:margin:h to 0. set chart_marker:style:margin:v to 0.
    }
    global ascent_display_summary is ascent_display_flight:addlabel().
    global ascent_display_rows is lex().
    for field_name in list("Altitude / ASL","Speed","Vertical speed","Pitch","Heading","Apoapsis","Periapsis","Inclination") {
        set ascent_display_rows[field_name] to ascent_display_row(ascent_display_flight,field_name).
    }
    global ascent_display_next is ascent_display_flight:addlabel().
    global ascent_display_footer is ascent_display_flight:addlabel().
    if not defined confirm_in { global confirm_in is false. }
    assent_gui:show().
    until confirm_in or step = "end" { wait 0.001. }
    ascent_display_setup:hide(). ascent_display_flight:show().
    set assent_rendezvous_menu:enabled to false.
    return lex("Apoapsis",assent_apoapsis_input:text:tonumber(-1),
        "Periapsis",assent_periapsis_input:text:tonumber(-1),
        "Inclination",assent_inclination_input:text:tonumber(-999),"RendezvousTarget",assent_rendezvous_menu:value).
}

function ascent_display_place {
    parameter marker_widget, chart_point.
    set marker_widget:visible to chart_point["visible"].
    // Each image consumes zero net vertical flow so both share chart origin.
    set marker_widget:style:margin:left to chart_point["x"]-6.
    set marker_widget:style:margin:top to chart_point["y"]-6.
    set marker_widget:style:margin:bottom to -chart_point["y"]-6.
}

function ascent_display_value {
    parameter field_name, current_value, target_value is "--".
    set ascent_display_rows[field_name]["now"]:text to current_value.
    set ascent_display_rows[field_name]["goal"]:text to target_value.
}

function update_assent_gui {
    parameter inputs is "auto".
    if inputs = "auto" {
        if time:seconds < ascent_display_state["next_update"] and step <> "end" { return. }
        set ascent_display_state["next_update"] to time:seconds+0.5.
        set inputs to ascent_display_collect().
    }
    global ascent_display_data is inputs.
    set ascent_display_heading:text to "<b>"+inputs["page"]+" | "+inputs["phase"]+"</b>".
    set ascent_display_status:text to inputs["health"].
    set ascent_display_target:text to "Target: "+round(inputs["target_ap"]/1000,1)+" x "+
        round(inputs["target_pe"]/1000,1)+" km / "+round(inputs["target_inc"],1)+" deg".
    local menu_mode is "OFF".
    if inputs["dap_mode"] = "auto" or inputs["dap_mode"] = "AUTO" { set menu_mode to "AUTO". }
    if inputs["dap_mode"] = "css" or inputs["dap_mode"] = "CSS" { set menu_mode to "CSS". }
    set assent_dap_mode_menu:value to menu_mode.
    local air_page is inputs["page"] = "ASCENT 1 / 2".
    local circ_page is inputs["page"] = "CIRC".
    set ascent_display_chart:visible to air_page.
    for orbit_field in list("Apoapsis","Periapsis","Inclination") {
        set ascent_display_rows[orbit_field]["box"]:visible to not air_page.
    }
    local vehicle_point is ascent_display_point(inputs["altitude"],inputs["airspeed"]).
    local goal_point is ascent_display_point(inputs["climb_alt"],inputs["climb_speed"]).
    ascent_display_place(ascent_display_vehicle,vehicle_point).
    // The climb aimpoint does not apply during takeoff or NERV assist.
    set goal_point["visible"] to goal_point["visible"] and inputs["phase"] = "high_altitude_climb".
    ascent_display_place(ascent_display_goal,goal_point).
    ascent_display_value("Altitude / ASL",round(inputs["altitude"]/1000,1)+" km").
    ascent_display_value("Speed",round(inputs["surface_speed"])+" m/s surface").
    if air_page { ascent_display_value("Speed",round(inputs["airspeed"])+" m/s air"). }
    ascent_display_value("Vertical speed",round(inputs["vertical_speed"],1)+" m/s").
    ascent_display_value("Pitch",round(inputs["pitch"],1)+" deg","CMD: --").
    ascent_display_value("Heading",round(inputs["heading"],1)+" deg","CMD: --").
    if inputs["command_kind"] = "angles" {
        ascent_display_value("Pitch",round(inputs["pitch"],1)+" deg","CMD: "+round(inputs["pitch_command"],1)+" deg").
        ascent_display_value("Heading",round(inputs["heading"],1)+" deg","CMD: "+round(inputs["heading_command"],1)+" deg").
    }
    ascent_display_value("Apoapsis",round(inputs["apoapsis"]/1000,1)+" km","GOAL: "+round(inputs["target_ap"]/1000,1)+" km").
    ascent_display_value("Periapsis",round(inputs["periapsis"]/1000,1)+" km","GOAL: "+round(inputs["target_pe"]/1000,1)+" km").
    ascent_display_value("Inclination",round(inputs["inclination"],1)+" deg","GOAL: "+round(inputs["target_inc"],1)+" deg").
    local next_text is "Next: follow active recovery guidance".
    local summary_text is "Apoapsis cutoff: "+round(inputs["cutoff_ap"]/1000,1)+" km | remaining "+
        round(max(0,inputs["cutoff_ap"]-inputs["apoapsis"])/1000,1)+" km".
    if air_page {
        set summary_text to "Vehicle dot / climb target cross | 0-30 km / 0-1800 m/s".
        if not vehicle_point["visible"] { set summary_text to "Vehicle outside chart - use numeric readouts". }
        if inputs["phase"] = "launch" { set next_text to "Next: rotate at "+AVES["Speed"]["Rotate"]+" m/s airspeed". }
        if inputs["phase"] = "rotate" { set next_text to "Next: clear runway, then align / build speed". }
        if inputs["phase"] = "ascent_alignment" { set next_text to "Next: align ascent heading, then build speed". }
        if inputs["phase"] = "speed_build" { set next_text to "Next: climb at "+AVES["Ascent"]["speed_build_target"]+" m/s OR "+round(inputs["climb_alt"]/1000,1)+" km". }
        if inputs["phase"] = "high_altitude_climb" {
            set next_text to "Next: NERV on at "+round(inputs["climb_alt"]/1000,1)+" km ("+
                round(max(0,inputs["climb_alt"]-inputs["altitude"])/1000,1)+" km remaining)".
            ascent_display_value("Altitude / ASL",round(inputs["altitude"]/1000,1)+" km","PLAN: "+round(inputs["climb_alt"]/1000,1)+" km").
            ascent_display_value("Speed",round(inputs["airspeed"])+" m/s air","PLAN: "+round(inputs["climb_speed"])+" m/s").
        }
        if inputs["phase"] = "nerv_assist" { set next_text to "Next: closed cycle above "+round(AVES["Ascent"]["closed_cycle_min_altitude"]/1000,1)+" km when speed gain falls". }
        if inputs["phase"] = "rendezvous_window" { set next_text to "Next: wait for rendezvous launch window". }
    } else {
        if inputs["phase"] = "closed_cycle_climb" {
            set next_text to "Next: RAPIER cutoff above "+round(AVES["Ascent"]["rapier_cutoff_apoapsis"]/1000,1)+" km apoapsis".
        }
        if inputs["phase"] = "apoapsis_build" { set next_text to "Next: cutoff above "+round(inputs["cutoff_ap"]/1000,1)+" km apoapsis, then insertion". }
    }
    if circ_page {
        set summary_text to "ETA apoapsis: "+round(inputs["eta_apoapsis"],1)+" s | burn estimate: --".
        if inputs["burn_seconds"] >= 0 {
            set summary_text to "ETA apoapsis: "+round(inputs["eta_apoapsis"],1)+" s | burn estimate: "+round(inputs["burn_seconds"],1)+" s".
        }
        set next_text to "Next: align and coast to the insertion window".
        if inputs["phase"] = "insert" { set next_text to "Next: raise periapsis; monitor actual versus requested orbit". }
    }
    if not inputs["orbit_valid"] {
        set summary_text to "Open trajectory - apoapsis, periapsis and ETA unavailable".
        ascent_display_value("Apoapsis","OPEN","GOAL: "+round(inputs["target_ap"]/1000,1)+" km").
        ascent_display_value("Periapsis","OPEN","GOAL: "+round(inputs["target_pe"]/1000,1)+" km").
    }
    if inputs["recovery"] { set next_text to "Recovery: "+inputs["phase"]+" | "+Lastest_status. }
    if inputs["finished"] { set next_text to "Outcome: "+inputs["outcome"]+" | inspect final orbit errors above". }
    set ascent_display_summary:text to summary_text.
    set ascent_display_next:text to next_text.
    local error_text is "--".
    if inputs["command_valid"] { set error_text to round(inputs["attitude_error"],1)+" deg ("+inputs["command_kind"]+")". }
    set ascent_display_footer:text to "THR "+round(inputs["throttle"]*100)+"% | RAPIER "+inputs["rapier_mode"]+
        "/"+inputs["rapiers"]+" | NERV "+inputs["nervs"]+" | downrange "+round(inputs["downrange"]/1000,1)+
        " km\nT+ "+round(inputs["elapsed"],1)+" s | steering error "+error_text+" | sample UT "+round(inputs["ut"],1).
}
