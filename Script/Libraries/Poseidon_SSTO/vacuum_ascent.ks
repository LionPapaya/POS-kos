// Live vacuum ascent executive.  Landing ends with the Poseidon on its gear;
// this controller first uses RCS to stand it onto its tail/rear wheel, applies
// a bounded RAPIER liftoff kick, then continues on NERVs alone.

function vacuum_ascent_target_input {
    parameter ascent_config.
    local result is lex("valid",false,"altitude",0,"inclination",0,"heading",0).
    local dialog is GUI(440,250).
    dialog:addlabel("Poseidon vacuum ascent target orbit").
    dialog:addlabel("Circular orbit altitude (m)").
    local altitude_field is dialog:addtextfield(ascent_config["default_orbit_altitude"]:tostring).
    dialog:addlabel("Inclination (degrees, 0..180)").
    local inclination_field is dialog:addtextfield(ascent_config["default_inclination"]:tostring).
    local message is dialog:addlabel("The node at apoapsis will execute automatically.").
    local done is false.
    local launch is dialog:addbutton("Launch").
    set launch:onclick to {
        local requested_orbit_altitude is altitude_field:text:tonumber(-1).
        local requested_inclination is inclination_field:text:tonumber(-1).
        local maximum_orbit_altitude is ship:body:soiradius-ship:body:radius.
        local computed_launch_heading is vacuum_ascent_launch_heading(requested_inclination,ship:geoposition:lat).
        if requested_orbit_altitude >= ascent_config["minimum_orbit_altitude"] and requested_orbit_altitude < maximum_orbit_altitude and
           requested_inclination >= 0 and requested_inclination <= 180 and computed_launch_heading >= 0 {
            set result["altitude"] to requested_orbit_altitude.
            set result["inclination"] to requested_inclination.
            set result["heading"] to computed_launch_heading.
            set result["valid"] to true.
            set done to true.
        }else if computed_launch_heading < 0 {
            set message:text to "That inclination cannot be launched directly from this latitude.".
        }else{ set message:text to "Enter an orbit above the minimum altitude and inside this body's SOI.". }
    }.
    local cancel is dialog:addbutton("Cancel").
    set cancel:onclick to { set done to true. }.
    dialog:show().
    until done { wait 0.1. }
    dialog:hide().
    return result.
}

function vacuum_ascent_phase {
    parameter mission, phase, reason.
    set mission["phase"] to phase.
    set mission["reason"] to reason.
    set mission["phase_started"] to time:seconds.
    set step to phase.
    set substep to reason.
    set Lastest_status to reason.
    flight_log_event("vacuum_ascent_phase","phase="+phase+"|reason="+reason).
}

function vacuum_ascent_nerv_thrust {
    local thrust_available is 0.
    for engine in ship:partstitledpattern("LV-N") {
        if engine:ignition and not engine:flameout { set thrust_available to thrust_available+engine:availablethrust. }
    }
    return thrust_available.
}

function vacuum_ascent_tick {
    parameter mission, target_pitch is 90, attitude_error is 0, rapier_kick_active is false, node_dv is 0, node_eta is 0.
    local surface_up is ship:up:vector.
    local surface_velocity is ship:velocity:surface.
    local lateral_velocity is surface_velocity-surface_up*vdot(surface_velocity,surface_up).
    local nerv_twr is vacuum_ascent_nerv_thrust()/max(0.001,ship:mass*ship:body:mu/ship:body:radius^2).
    flight_log_capture_vacuum_ascent(mission["phase"],mission["target_altitude"],mission["target_inclination"],mission["launch_heading"],
        alt:radar,ship:verticalspeed,lateral_velocity:mag,target_pitch,attitude_error,nerv_twr,rapier_kick_active,
        ship:apoapsis,ship:periapsis,node_dv,node_eta).
    dap:update().
    flight_log_tick("vacuum_ascent",mission["phase"],mission["reason"]).
    if time:seconds >= mission["next_display"] {
        set mission["display"]:text to mission["phase"]+" | "+mission["reason"]+
            " | AP "+round(ship:apoapsis,0)+" m | PE "+round(ship:periapsis,0)+" m"+
            " | V "+round(ship:verticalspeed,1)+" m/s | H "+round(lateral_velocity:mag,1)+" m/s"+
            " | clearance "+round(alt:radar,1)+" m".
        set mission["next_display"] to time:seconds+0.5.
    }
}

function vacuum_ascent_stop {
    parameter mission, success, reason.
    set dapthrottle to 0.
    set ship:control:pilotmainthrottle to 0.
    nervsoff().
    rapiersoff().
    flight_log_event("vacuum_ascent_complete","success="+success+"|reason="+reason+"|apoapsis="+round(ship:apoapsis,1)+
        "|periapsis="+round(ship:periapsis,1)+"|inclination="+round(ship:orbit:inclination,3)).
    set vacuum_ascent_result to lex("complete",true,"success",success,"reason",reason).
    set vacuum_ascent_active to false.
    dap:set_off().
    sas off.
    rcs off.
    unlock throttle.
    set mission["running"] to false.
    mission["gui"]:hide().
    print "Poseidon vacuum ascent: "+reason.
}

function vacuum_ascent_plan_circularization {
    parameter mission.
    local ascent_config is mission["config"].
    local node_ut is time:seconds+ship:orbit:eta:apoapsis.
    local result is lex("valid",false,"reason","apoapsis_unavailable","node",0,"dv",0).
    if node_ut <= time:seconds+ascent_config["node_minimum_lead_time"] { return result. }
    local maneuver is node(node_ut,0,0,0).
    add maneuver.
    local apoapsis_radius is ship:body:radius+ship:apoapsis.
    local desired_speed is vacuum_ascent_circular_speed(apoapsis_radius,ship:body:mu).
    local current_speed is velocityat(ship,node_ut):orbit:mag.
    set maneuver:prograde to max(0,desired_speed-current_speed).
    local node_adjustment_iteration is 0.
    until node_adjustment_iteration >= ascent_config["node_iterations"] or abs(maneuver:orbit:periapsis-mission["target_altitude"]) <= ascent_config["orbit_tolerance"] {
        local periapsis_error is mission["target_altitude"]-maneuver:orbit:periapsis.
        local correction is max(-ascent_config["node_max_adjustment"],min(ascent_config["node_max_adjustment"],periapsis_error/ascent_config["node_error_gain"])).
        set maneuver:prograde to max(0,maneuver:prograde+correction).
        set node_adjustment_iteration to node_adjustment_iteration+1.
    }
    if abs(maneuver:orbit:periapsis-mission["target_altitude"]) > ascent_config["orbit_tolerance"] {
        remove maneuver.
        set result["reason"] to "circularization_node_not_converged".
        return result.
    }
    set result["valid"] to true.
    set result["reason"] to "circularization_node_ready".
    set result["node"] to maneuver.
    set result["dv"] to maneuver:deltav:mag.
    return result.
}

function vacuum_ascent_execute_node {
    parameter mission, maneuver.
    local ascent_config is mission["config"].
    local estimated_acceleration is max(0.001,ship:availablethrust/max(0.001,ship:mass)).
    local duration is maneuver:deltav:mag/estimated_acceleration+0.1.
    local initial_dv is maneuver:deltav.
    local node_dv is initial_dv:mag.
    vacuum_ascent_phase(mission,"vacuum_ascent_coast","coasting to automatic circularization burn").
    until maneuver:eta <= duration/2+ascent_config["node_coast_lead_time"] {
        if mission["cancel"] { return false. }
        set dap["vector"]["targetVector"] to maneuver:deltav.
        set dapthrottle to 0.
        vacuum_ascent_tick(mission,0,vang(maneuver:deltav,ship:facing:vector),false,node_dv,maneuver:eta).
        if maneuver:eta > duration/2+ascent_config["node_coast_lead_time"]+10 {
            warpto(maneuver:time-duration/2-ascent_config["node_coast_lead_time"]).
        }
        wait 0.1.
    }
    local alignment_deadline is min(maneuver:time-duration/2,time:seconds+ascent_config["node_alignment_timeout"]).
    until vang(maneuver:deltav,ship:facing:vector) <= ascent_config["node_alignment_error"] {
        if mission["cancel"] or time:seconds >= alignment_deadline { return false. }
        set dap["vector"]["targetVector"] to maneuver:deltav.
        set dapthrottle to 0.
        vacuum_ascent_tick(mission,0,vang(maneuver:deltav,ship:facing:vector),false,node_dv,maneuver:eta).
        wait 0.
    }
    until maneuver:eta <= duration/2 {
        if mission["cancel"] { return false. }
        set dap["vector"]["targetVector"] to maneuver:deltav.
        set dapthrottle to 0.
        vacuum_ascent_tick(mission,0,vang(maneuver:deltav,ship:facing:vector),false,node_dv,maneuver:eta).
        wait 0.
    }
    vacuum_ascent_phase(mission,"vacuum_ascent_circularize","executing automatic circularization node").
    until maneuver:deltav:mag <= ascent_config["node_completion_dv"] or vdot(initial_dv,maneuver:deltav) <= 0 {
        if mission["cancel"] { return false. }
        local current_acceleration is max(0.001,ship:availablethrust/max(0.001,ship:mass)).
        set dap["vector"]["targetVector"] to maneuver:deltav.
        set dapthrottle to min(1,maneuver:deltav:mag/current_acceleration).
        vacuum_ascent_tick(mission,0,vang(maneuver:deltav,ship:facing:vector),false,node_dv,maneuver:eta).
        wait 0.
    }
    set dapthrottle to 0.
    remove maneuver.
    return true.
}

function vacuum_ascent_run {
    parameter target_altitude_override is "ASK", target_inclination_override is "ASK".
    if ship:body:atm:exists or not ship:body:hassolidsurface {
        print "Vacuum ascent requires an airless body with a solid surface.". return.
    }
    if ship:status <> "LANDED" and ship:status <> "PRELAUNCH" {
        print "Start vacuum ascent after the Poseidon has landed.". return.
    }
    if hasnode { print "Vacuum ascent requires an empty maneuver plan. Existing nodes were kept.". return. }
    local ascent_config is AVES["VacuumAscent"].
    local ascent_target is vacuum_ascent_target_input(ascent_config).
    if target_altitude_override <> "ASK" { set ascent_target["altitude"] to target_altitude_override:tostring:tonumber(-1). }
    if target_inclination_override <> "ASK" { set ascent_target["inclination"] to target_inclination_override:tostring:tonumber(-1). }
    if target_altitude_override <> "ASK" or target_inclination_override <> "ASK" {
        set ascent_target["heading"] to vacuum_ascent_launch_heading(ascent_target["inclination"],ship:geoposition:lat).
        set ascent_target["valid"] to ascent_target["altitude"] >= ascent_config["minimum_orbit_altitude"] and ascent_target["heading"] >= 0.
    }
    if not ascent_target["valid"] { print "Vacuum ascent target cancelled or invalid.". return. }
    local nerv_engines is ship:partstitledpattern("LV-N").
    if nerv_engines:length = 0 { print "Vacuum ascent needs active LV-N engines.". return. }
    if not(defined vacuum_ascent_active) { global vacuum_ascent_active is true. } else { set vacuum_ascent_active to true. }
    if not(defined rapier_mode) { global rapier_mode is "off". }
    flight_log_begin("vacuum_ascent").
    flight_log_set_vacuum_ascent_target(ascent_target["altitude"],ascent_target["inclination"],ascent_target["heading"]).
    local gui_ is GUI(500,210).
    local display is gui_:addlabel("Preparing Poseidon vacuum ascent").
    local cancel is gui_:addbutton("Abort ascent / release controls").
    local mission is lex("config",ascent_config,"target_altitude",ascent_target["altitude"],"target_inclination",ascent_target["inclination"],
        "launch_heading",ascent_target["heading"],"phase","vacuum_ascent_setup","reason","preflight","phase_started",time:seconds,
        "started",time:seconds,"running",true,"cancel",false,"gui",gui_,"display",display,"next_display",0).
    set cancel:onclick to { set mission["cancel"] to true. }.
    gui_:show().
    rapiersoff().
    nervsoff().
    brakes on.
    sas off.
    rcs on.
    dap:setup().
    set dap["envelope"]["min_throttle"] to 0.
    set dap["vector"]["targetVector"] to ship:up:vector.
    dap:set_vector_auto().
    wait 0.
    vacuum_ascent_phase(mission,"vacuum_ascent_orient_vertical","using RCS until the minimum liftoff pitch is reached").
    until not mission["running"] {
        if mission["cancel"] { vacuum_ascent_stop(mission,false,"pilot_cancelled"). return. }
        if time:seconds-mission["started"] > ascent_config["maximum_ascent_duration"] {
            vacuum_ascent_stop(mission,false,"ascent_timeout"). return.
        }
        local surface_up is ship:up:vector.
        local vertical_error is vang(surface_up,ship:facing:vector).
        if mission["phase"] = "vacuum_ascent_orient_vertical" {
            set dap["vector"]["targetVector"] to surface_up.
            set dapthrottle to 0.
            local standing_pitch is 90-vertical_error.
            vacuum_ascent_tick(mission,90,vertical_error,false,0,0).
            if vacuum_ascent_liftoff_pitch_ready(standing_pitch,ascent_config["minimum_liftoff_pitch"]) {
                flight_log_event("vacuum_ascent_liftoff_attitude","required_pitch="+ascent_config["minimum_liftoff_pitch"]+
                    "|actual_pitch="+round(standing_pitch,2)+"|vertical_error="+round(vertical_error,2)).
                vacuum_ascent_phase(mission,"vacuum_ascent_nerv_spool","minimum liftoff pitch reached; spooling NERVs").
                nervson().
            }else if time:seconds-mission["phase_started"] >= ascent_config["vertical_timeout"] {
                vacuum_ascent_stop(mission,false,"minimum_liftoff_pitch_not_reached"). return.
            }
        }else if mission["phase"] = "vacuum_ascent_nerv_spool" {
            set dap["vector"]["targetVector"] to surface_up.
            set dapthrottle to 0.
            vacuum_ascent_tick(mission,90,vertical_error,false,0,0).
            if time:seconds-mission["phase_started"] >= ascent_config["nerv_spool_time"] {
                local nerv_twr is vacuum_ascent_nerv_thrust()/max(0.001,ship:mass*ship:body:mu/ship:body:radius^2).
                if nerv_twr < ascent_config["minimum_nerv_twr"] {
                    vacuum_ascent_stop(mission,false,"insufficient_nerv_twr"). return.
                }
                togglerapiermode("CLOSED").
                rapierson().
                set dapthrottle to 1.
                vacuum_ascent_phase(mission,"vacuum_ascent_rapier_kick","full-throttle RAPIER liftoff kick").
                flight_log_event("vacuum_ascent_rapier_kick","duration_limit="+ascent_config["rapier_kick_duration"]+"|nerv_twr="+round(nerv_twr,3)).
            }
        }else if mission["phase"] = "vacuum_ascent_rapier_kick" {
            set dap["vector"]["targetVector"] to surface_up.
            set dapthrottle to 1.
            vacuum_ascent_tick(mission,90,vertical_error,true,0,0).
            if alt:radar >= ascent_config["liftoff_radar_altitude"] and ship:verticalspeed >= ascent_config["liftoff_vertical_speed"] {
                brakes off.
                gear off.
                rapiersoff().
                set dapthrottle to 1.
                vacuum_ascent_phase(mission,"vacuum_ascent_gear_retract","airborne; gear retracting on NERV thrust").
                flight_log_event("vacuum_ascent_liftoff","radar_altitude="+round(alt:radar,2)+"|vertical_speed="+round(ship:verticalspeed,2)).
            }else if time:seconds-mission["phase_started"] >= ascent_config["rapier_kick_duration"] {
                vacuum_ascent_stop(mission,false,"rapier_kick_did_not_liftoff"). return.
            }
        }else if mission["phase"] = "vacuum_ascent_gear_retract" {
            set dap["vector"]["targetVector"] to surface_up.
            set dapthrottle to 1.
            vacuum_ascent_tick(mission,90,vertical_error,false,0,0).
            if time:seconds-mission["phase_started"] >= ascent_config["gear_retract_time"] {
                vacuum_ascent_phase(mission,"vacuum_ascent_nerv_climb","NERV-only vertical terrain clearance").
            }
        }else if mission["phase"] = "vacuum_ascent_nerv_climb" {
            set dap["vector"]["targetVector"] to surface_up.
            set dapthrottle to 1.
            vacuum_ascent_tick(mission,90,vertical_error,false,0,0).
            if alt:radar >= ascent_config["pitch_start_clearance"] {
                vacuum_ascent_phase(mission,"vacuum_ascent_pitch_and_accelerate","pitching down on launch heading to build apoapsis").
            }
        }else if mission["phase"] = "vacuum_ascent_pitch_and_accelerate" {
            local current_launch_heading is vacuum_ascent_launch_heading(mission["target_inclination"],ship:geoposition:lat).
            if current_launch_heading < 0 { vacuum_ascent_stop(mission,false,"launch_plane_became_unreachable"). return. }
            local surface_velocity is ship:velocity:surface.
            local lateral_velocity is surface_velocity-surface_up*vdot(surface_velocity,surface_up).
            local target_pitch is vacuum_ascent_pitch_target(alt:radar,ship:verticalspeed,lateral_velocity:mag,ship:apoapsis,mission["target_altitude"],ascent_config).
            set mission["launch_heading"] to current_launch_heading.
            set dap["vector"]["targetVector"] to heading(current_launch_heading,target_pitch,0):vector.
            set dapthrottle to 1.
            vacuum_ascent_tick(mission,target_pitch,vang(dap["vector"]["targetVector"],ship:facing:vector),false,0,0).
            if ship:apoapsis >= mission["target_altitude"]+ascent_config["apoapsis_margin"] {
                set dapthrottle to 0.
                vacuum_ascent_phase(mission,"vacuum_ascent_plan_circularize","planning automatic apoapsis circularization").
            }
        }else if mission["phase"] = "vacuum_ascent_plan_circularize" {
            set dapthrottle to 0.
            vacuum_ascent_tick(mission,0,0,false,0,0).
            local plan is vacuum_ascent_plan_circularization(mission).
            if not plan["valid"] { vacuum_ascent_stop(mission,false,plan["reason"]). return. }
            flight_log_event("vacuum_ascent_node","ut="+round(plan["node"]:time,2)+"|dv="+round(plan["dv"],2)+
                "|target_altitude="+mission["target_altitude"]+"|predicted_periapsis="+round(plan["node"]:orbit:periapsis,1)).
            if not vacuum_ascent_execute_node(mission,plan["node"]) {
                vacuum_ascent_stop(mission,false,"circularization_burn_incomplete"). return.
            }
            if abs(ship:periapsis-mission["target_altitude"]) > ascent_config["orbit_tolerance"] or
               abs(ship:apoapsis-mission["target_altitude"]) > ascent_config["orbit_tolerance"] {
                vacuum_ascent_stop(mission,false,"orbit_target_outside_tolerance"). return.
            }
            vacuum_ascent_phase(mission,"vacuum_ascent_complete","target circular orbit achieved").
            vacuum_ascent_stop(mission,true,"target_circular_orbit_achieved").
            return.
        }
        wait 0.
    }
}
