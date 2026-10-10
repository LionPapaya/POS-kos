// NERV ascent from a completed airless-body landing.  The live executive
// presents a target-orbit dialog, performs the brief closed-cycle RAPIER
// liftoff kick, and automatically executes its circularization node.
set CONFIG:IPU to 2000.
parameter target_altitude_override is "ASK".
parameter target_inclination_override is "ASK".

RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/vacuum_ascent_guidance.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/vacuum_ascent_support.ks").

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

vacuum_ascent_run(target_altitude_override,target_inclination_override).
