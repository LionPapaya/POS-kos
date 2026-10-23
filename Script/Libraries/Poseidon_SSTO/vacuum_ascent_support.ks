// Live vacuum ascent support routines. The main flight loop lives in the program entry script.

// Supporting routines for the vacuum ascent entry script. Landing ends with
// the Poseidon on its gear; ascent first uses RCS to stand it onto its tail,
// applies a bounded RAPIER liftoff kick, then continues on NERVs alone.

function vacuum_ascent_target_input {
    parameter ascent_config.
    local result is lex("valid",false,"altitude",0,"inclination",0,"heading",0).
    local dialog is GUI(440,250).
    dialog:addlabel("Poseidon vacuum ascent target orbit").
    dialog:addlabel("Circular orbit altitude (m)").
    local altitude_field is dialog:addtextfield(ascent_config["default_orbit_altitude"]:tostring).
    dialog:addlabel("Inclination (degrees, 0..180)").
    local inclination_field is dialog:addtextfield(ascent_config["default_inclination"]:tostring).
    local message is dialog:addlabel("Inclination doglegs are best effort; apoapsis node executes automatically.").
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
            set message:text to "Enter an inclination from 0 to 180 degrees.".
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
    local warp_before is warp.
    set warp to 0.
    set dapthrottle to 0.
    set ship:control:pilotmainthrottle to 0.
    nervsoff().
    rapiersoff().
    flight_log_event("vacuum_ascent_complete","success="+success+"|reason="+reason+"|apoapsis="+round(ship:apoapsis,1)+
        "|periapsis="+round(ship:periapsis,1)+"|inclination="+round(ship:orbit:inclination,3)+
        "|target_inclination="+mission["target_inclination"]+
        "|inclination_error="+abs(ship:orbit:inclination-mission["target_inclination"])+
        "|phase="+mission["phase"]+"|warp_before="+warp_before).
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
        if mission["cancel"] {
            local abort_warp is warp.
            set warp to 0.
            flight_log_event("vacuum_ascent_node_coast_exit","reason=pilot_cancelled|warp_before="+
                abort_warp+"|eta="+maneuver:eta).
            return false.
        }
        set dap["vector"]["targetVector"] to maneuver:deltav.
        set dapthrottle to 0.
        vacuum_ascent_tick(mission,0,vang(maneuver:deltav,ship:facing:vector),false,node_dv,maneuver:eta).
        if maneuver:eta > duration/2+ascent_config["node_coast_lead_time"]+10 {
            warpto(maneuver:time-duration/2-ascent_config["node_coast_lead_time"]).
        }
        wait 0.1.
    }
    local coast_warp is warp.
    set warp to 0.
    flight_log_event("vacuum_ascent_node_coast_exit","reason=alignment_ready|warp_before="+
        coast_warp+"|eta="+maneuver:eta).
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
