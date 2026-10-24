// Poseidon_SSTO/Poseidon_SSTO_Orbit_Main.ks
// Purpose: ascent and orbital insertion script for Poseidon SSTO.
// Guidance executes directly in flight steps; libraries hold reusable services.
set CONFIG:IPU to 2000.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/contingency.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/recovery_orbit.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/recovery_aed.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/terminal_route.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/rendezvous.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_aerosim.ks").
RUNONCEPATH("0:/Libraries/lib_location_constants.ks").

global abort_state is lex("active",false).
if defined recovery_engines { unset recovery_engines. }
set step to "launch".
set running to true.
clearScreen.  
                
set nervs to false.
set rapier_mode to "air".
set rapiers to false.
set circ_done to false.
set Lastest_status to "launching".
set orbitcalc to false.
local ascent is AVES["Ascent"].
local launch_heading is AVES["Ascent"]["default_launch_heading"].
local runway_heading is AVES["Ascent"]["default_launch_heading"].
local runway_altitude is 0.
local liftoff_altitude is ascent["liftoff_height_above_runway"] + runway_altitude.
local rotate_altitude is ascent["rotate_height_above_runway"] + runway_altitude.
local previous_speed is 0.
local speed_trend is 0.
local ascent_orbit_complete is false.


set confirm_in to false.
local Target_orbit is create_assent_gui().
set TargetPeriapsis to Target_orbit["Periapsis"].
set TargetApoapsis to Target_orbit["Apoapsis"].
set TargetInclination to Target_orbit["inclination"].
local ascent_rendezvous_target is 0.
local ascent_rendezvous_enabled is Target_orbit["RendezvousTarget"] <> "None".
if ascent_rendezvous_enabled {
    set ascent_rendezvous_target to Vessel(Target_orbit["RendezvousTarget"]).
    if ascent_rendezvous_target:body = ship:body and ascent_rendezvous_target:orbit:eccentricity < 1 {
        // The selected vessel's orbit is the insertion orbit.  The wait below
        // selects the phase; the same-body rendezvous routine removes the
        // remaining dispersions and performs the docking handoff.
        set TargetPeriapsis to ascent_rendezvous_target:orbit:periapsis.
        set TargetApoapsis to ascent_rendezvous_target:orbit:apoapsis.
        set TargetInclination to ascent_rendezvous_target:orbit:inclination.
    } else {
        set ascent_rendezvous_enabled to false.
    }
}
flight_log_begin("ascent").
flight_log_event("orbit_target","periapsis=" + TargetPeriapsis + "|apoapsis=" + TargetApoapsis + "|inclination=" + TargetInclination).
if ascent_rendezvous_enabled {
    flight_log_event("ascent_rendezvous_target","name="+ascent_rendezvous_target:name+"|body="+ship:body:name+"|insertion_periapsis="+TargetPeriapsis+"|insertion_apoapsis="+TargetApoapsis).
}

check_inputs().

reset_sys().
dap:setup().
print("1").
local active_runway is find_active_runway().
print("2").
if active_runway["heading"] >= 0 {
    set runway_heading to active_runway["heading"].
}
if active_runway["altitude"] >= 0 {
    set runway_altitude to active_runway["altitude"].
    set liftoff_altitude to runway_altitude + ascent["liftoff_height_above_runway"].
    set rotate_altitude to runway_altitude + ascent["rotate_height_above_runway"].
}
if active_runway["heading"] >= 0 {
    flight_log_set_runway(active_runway["location"],active_runway["runway_num"],active_runway["start"],active_runway["end"],active_runway["heading"],active_runway["altitude"]).
}
set dap["aerostr"]["turn_heading"] to runway_heading.
local inclination_command is ascent_inclination_guidance(TargetInclination,ship:latitude).
local inclination_log is lex("mode","","northbound",true,"next_sample",0).
if not inclination_command["valid"] {
    print "Invalid inclination target.".
    set running to false.
    set Lastest_status to "Invalid inclination target".
    flight_log_event("ascent_inclination_rejected","target_inclination="+TargetInclination+
        "|latitude="+ship:latitude).
}
// Script scope cannot RETURN. Only enter preflight and guidance with a valid command.
if inclination_command["valid"] {
set launch_heading to inclination_command["heading"].
flight_log_inclination_observe(inclination_command,TargetInclination,ship:latitude,inclination_log).
set previous_speed to ship:airspeed.
set t0 to -1.
ascent_display_init().
local takeoff_start_position is ship:geoposition.
local takeoff_estimate is assess_takeoff_runway(active_runway).
set ascent_display_state["takeoff_estimate"] to takeoff_estimate.
set ascent_display_state["takeoff_start_position"] to takeoff_start_position.
local takeoff_evidence is lex("released",false,"rotated",false,"airborne",false,
    "screen_reached",false,"next_sample",0,"base_altitude_m",ship:altitude).
print("Takeoff estimate: " + takeoff_estimate["reason"]).
print("Runway requirement " + round(takeoff_estimate["required_runway_m"]) + " m; available " +
    round(takeoff_estimate["remaining_runway_m"]) + " m; departure to 35m " + round(takeoff_estimate["required_departure_m"]) + " m").
flight_log_takeoff_prediction(takeoff_estimate,"preflight").
// Check the departure before any engine spool/brake release. A finite sampled
// route is monitored again by GPWS in flight; it is not a terrain guarantee.
brakes on.
set dapthrottle to 0.
global departure_runway_altitude is runway_altitude.
local departure_config is terrain_navigation_config(AVES["Envelope"]["Terrain"]["Navigation"],ship:mass).
print("Checking departure terrain corridors...").
global departure_route is terrain_departure_plan(active_runway,takeoff_estimate,launch_heading,departure_config).
global ascent_alignment_debug is lex("bank",0,"aoa",0,"pitch_floor",ascent["rotate_pitch"]).
flight_log_departure_plan(departure_route).
flight_log_event("takeoff_preflight_policy","override_refusals="+AVES["Takeoff"]["override_preflight_refusals"]).
if not departure_route["valid"] {
    if AVES["Takeoff"]["override_preflight_refusals"] {
        print("WARNING: TAKEOFF OVERRIDE: no checked departure corridor ("+departure_route["reason"]+"). Attempting takeoff.").
        set Lastest_status to "Takeoff override: departure route unchecked".
        flight_log_event("departure_takeoff_overridden","reason="+departure_route["reason"]+"|fallback=orbital_course|in_flight_protection=active").
        // Preserve the failed plan. terrain_departure_course() uses the
        // orbital course fallback; do not label an unchecked route valid.
    } else {
        print("TAKEOFF HELD: no checked departure corridor ("+departure_route["reason"]+").").
        set Lastest_status to "Departure terrain route unavailable".
        flight_log_event("departure_takeoff_held","reason="+departure_route["reason"]).
        // End through the script loop guard; this is not a function return.
        set running to false.
    }
}
local v1_announced is false.
local takeoff_spool is takeoff_spool_init(takeoff_spool_samples():keys,AVES["Takeoff"]["Spool"]).
local takeoff_spool_log is lex("status","","reason","","blocked_engine","","next_sample",0).
local abort_info is lex().
set dap_mode to "auto".
set dap["str_mode"] to "aerostr".
if ascent_rendezvous_enabled { set step to "rendezvous_window". }
print("3").
global recovery_nominal_cutoff is false.
if running {
    recovery_register_engines().
    // reset_sys only selects atmospheric engine configuration below 1 km.
    // Elevated runways must start in the same intended air-breathing mode.
    nervsoff().
    togglerapiermode("AIR").
    rapierson().
}
until running = false{
    if step = "launch" or step = "rotate" or step = "ascent_alignment" or
       step = "speed_build" or step = "high_altitude_climb" or step = "nerv_assist" or
       step = "closed_cycle_climb" or step = "apoapsis_build" {
        set inclination_command to ascent_inclination_guidance(TargetInclination,ship:latitude,inclination_command["northbound"]).
        flight_log_inclination_observe(inclination_command,TargetInclination,ship:latitude,inclination_log).
    }
    update_readouts().
    dap:update().
    update_assent_gui().
    flight_log_ascent_display_observe(ascent_display_data,ascent_display_log).
    set speed_trend to ship:airspeed - previous_speed.
    set previous_speed to ship:airspeed.

    if step = "rendezvous_window" {
        // Predict the target's location at nominal insertion time. Holding
        // here keeps the vehicle on the runway until the target crosses the
        // launch-site corridor, instead of departing at an arbitrary phase.
        local nominal_insertion_time is time:seconds+ascent["rendezvous_nominal_insertion_time"].
        local predicted_target_radius is positionat(ascent_rendezvous_target,nominal_insertion_time)-ship:body:position.
        local launch_site_radius is ship:position-ship:body:position.
        local launch_phase_error is vang(predicted_target_radius,launch_site_radius).
        brakes on.
        set dapthrottle to 0.
        set Lastest_status to "Waiting for rendezvous launch window ("+round(launch_phase_error,1)+" deg)".
        flight_log_capture_rendezvous(ascent_rendezvous_target,"launch_window",0,false).
        if launch_phase_error <= ascent["rendezvous_window_angle"] {
            set step to "launch".
            set Lastest_status to "Rendezvous launch window open".
            flight_log_event("ascent_rendezvous_window","phase_error_deg="+round(launch_phase_error,2)+"|nominal_insertion_ut="+round(nominal_insertion_time,1)).
        }
    }
    if step = "launch"{ 
        update_team_dap_gui().
         
        if ship:altitude < liftoff_altitude{
            set dap["aerostr"]["targetPitch"] to 0.
            set dap["aerostr"]["turn_heading"] to runway_heading.
            
            set dapthrottle to 1.
        }   
        if t0 = -1 {
            brakes on.
            set takeoff_spool to takeoff_spool_update(takeoff_spool,takeoff_spool_samples(),
                time:seconds,ship:control:mainthrottle).
            flight_log_takeoff_spool_observe(takeoff_spool,takeoff_spool_log).
            set Lastest_status to "Engine spool: "+takeoff_spool["reason"]+" "+takeoff_spool["blocked_engine"].
            if takeoff_spool["status"] = "ready" {
                brakes off.
                set t0 to time:seconds.
                set takeoff_start_position to ship:geoposition.
                set takeoff_evidence["base_altitude_m"] to ship:altitude.
                set takeoff_estimate to assess_takeoff_runway(active_runway).
                set ascent_display_state["takeoff_estimate"] to takeoff_estimate.
                set ascent_display_state["takeoff_start_position"] to takeoff_start_position.
                flight_log_takeoff_prediction(takeoff_estimate,"brake_release").
                set Lastest_status to "Takeoff roll".
            } else if takeoff_spool["status"] = "timeout" {
                set dapthrottle to 0.
                brakes on.
                set Lastest_status to "Takeoff held: engine spool timeout ("+takeoff_spool["reason"]+
                    " "+takeoff_spool["blocked_engine"]+")".
                print(Lastest_status).
                set step to "end".
            }
        }

        // Readiness is latched at brake release. Engine losses during the roll
        // always reach the existing abort monitor, independent of total thrust.
        if t0 <> -1 {
            // V1 is the last point at which the empirical runway-stop model
            // permits a rejected takeoff.  Beyond it, an engine failure uses
            // the RTLS path, which can first fly the vehicle clear of the
            // runway before turning back.
            if not v1_announced {
                local v1_check is runway_abort_feasibility(takeoff_start_position,active_runway["end"]).
                if not v1_check["permitted"] {
                    set v1_announced to true.
                    // Passive speed-marker capture. The runway test above,
                    // not the GUI's estimated speed, remains the V1 decision.
                    set ascent_display_state["v1_called"] to true.
                    set ascent_display_state["v1_actual_speed"] to ship:velocity:surface:mag.
                    set Lastest_status to "V1 - RTLS preferred".
                    flight_log_event("v1","rolled_m=" + round(v1_check["roll_distance_m"]) + "|required_m=" + round(v1_check["required_stop_distance_m"]) + "|remaining_m=" + round(v1_check["runway_remaining_m"]) + "|model_valid=" + v1_check["model_valid"] + "|surface_speed_mps="+ascent_display_state["v1_actual_speed"]+"|airspeed_mps="+ship:airspeed+"|preferred_abort=rtls").
                }
            }
            if ship:airspeed > AVES["Speed"]["Rotate"]{
                set step to "rotate".
                set Lastest_status to "rotating".
                Set warpmode to "physics".
            }
            set abort_info to check_abort(step).
            if abort_info["abort"]{
                set abort_state to create_abort_state(abort_info,step,active_runway).
                if abort_state["mode"] = "runway_abort" {
                    local runway_abort_check is runway_abort_feasibility(takeoff_start_position,active_runway["end"]).
                    set abort_state["runway_stop"] to runway_abort_check.
                    if not runway_abort_check["permitted"] {
                        set abort_state["mode"] to "rtls".
                        flight_log_event("runway_abort_rejected","rolled_m=" + round(runway_abort_check["roll_distance_m"]) + "|required_m=" + round(runway_abort_check["required_stop_distance_m"]) + "|remaining_m=" + round(runway_abort_check["runway_remaining_m"])).
                    }
                }
                set step to abort_state["mode"].
            }
        }

        
    if step = "launch" and ship:altitude > liftoff_altitude and ship:airspeed <= AVES["Speed"]["Rotate"]{
        set Lastest_status to "not in lift off conditon".
        set step to "end".
    }
    }
    if step = "rotate"{
        update_team_dap_gui().
        set dap["aerostr"]["targetPitch"] to ascent["rotate_pitch"].
        set dap["aerostr"]["turn_pitch"] to ascent["rotate_pitch"].
        set dap["aerostr"]["turn_heading"] to runway_heading.
        //decide_abort_mode().
        set abort_info to check_abort(step).
        if abort_info["abort"]{
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        }
        if step = "rotate" and ship:altitude > rotate_altitude{
            gear off.
            set warp to 0.
            set assent_heading to launch_heading.
            local runway_to_ascent_error is abs(normalized_heading_error(launch_heading,runway_heading)).
            if departure_route["valid"] or runway_to_ascent_error > ascent["runway_alignment_heading_threshold"] {
                set step to "ascent_alignment".
                set Lastest_status to "aligning ascent heading".
                set dap["str_mode"] to "aoa".
                set dap["aoa"]["smooth_target_aoa"] to max(ascent["runway_alignment_target_aoa"],calc_aoa()).
                set dap["aoa"]["smooth_target_bank"] to 0.
            }else{
                set step to "speed_build".
                set dap["str_mode"] to "aerostr".
            }
        }
    }
    if step = "ascent_alignment"{
        update_team_dap_gui().
        set assent_heading to inclination_command["heading"].

        local orbital_course is assent_heading.
        local route_index_before is departure_route["index"].
        set assent_heading to terrain_departure_course(departure_route,ship:geoposition,orbital_course,departure_config).
        if departure_route["index"] <> route_index_before {
            flight_log_event("departure_waypoint","index="+departure_route["index"]+
                "|count="+departure_route["waypoints"]:length+"|course="+round(assent_heading,2)).
        }
        local alignment_heading_error is normalized_heading_error(assent_heading,compass_for_prograde()).
        set ascent_alignment_debug to terrain_alignment_command(alignment_heading_error,ship:verticalspeed,
            calc_aoa(),pitch_for(),pitch_for_prograde(),ascent).
        set dap["str_mode"] to "aoa".
        set dap["aoa"]["target_aoa"] to ascent_alignment_debug["aoa"].
        set dap["aoa"]["target_bank"] to ascent_alignment_debug["bank"].
        // Keep turns early and slow enough to follow the checked curve. Full
        // power remains available when climb is weak; GPWS has final priority.
        local throttle_ramp_width is ascent["runway_alignment_speed_limit"] - ascent["runway_alignment_throttle_ramp_start"].
        set dapthrottle to max(0,min(1,(ascent["runway_alignment_speed_limit"] - ship:airspeed) / throttle_ramp_width)).
        if ship:verticalspeed < ascent["alignment_target_vs"] { set dapthrottle to 1. }

        set abort_info to check_abort(step).
        if abort_info["abort"]{
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        }
        // Once the checked dogleg is behind us and both courses agree,
        // resume normal acceleration without flying the remaining straight
        // verification waypoints at the alignment speed limit.
        local departure_turn_pending is abs(normalized_heading_error(departure_route["first_course"],orbital_course)) >
            ascent["runway_alignment_completion_tolerance"] and
            departure_route["index"]*1000 < departure_config["departure_dogleg_distance"].
        if step = "ascent_alignment" and not departure_turn_pending and
           abs(normalized_heading_error(orbital_course,compass_for_prograde())) <= ascent["runway_alignment_completion_tolerance"] and
           abs(alignment_heading_error) <= ascent["runway_alignment_completion_tolerance"] {
            set departure_route["index"] to departure_route["waypoints"]:length.
            set dap["aoa"]["target_bank"] to 0.
            set dapthrottle to 1.
            set dap["str_mode"] to "aerostr".
            set step to "speed_build".
            set Lastest_status to "ascent heading aligned".
        }
    }
    if step = "speed_build"{
        update_team_dap_gui().
        set assent_heading to inclination_command["heading"].
        set dap["aerostr"]["turn_heading"] to assent_heading.
        set dap["aerostr"]["targetPitch"] to ascent["shallow_climb_pitch"].
        set dap["aerostr"]["turn_pitch"] to ascent["shallow_climb_pitch"].
        set abort_info to check_abort(step).
        if abort_info["abort"]{
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        }
        if step = "speed_build" and (ship:airspeed >= ascent["speed_build_target"] or ship:altitude >= ascent["climb_altitude"]) {
            set step to "high_altitude_climb".
            set Lastest_status to "speed target reached".
        }
    }
    if step = "high_altitude_climb"{
        update_team_dap_gui().
        set abort_info to check_abort(step).
        if abort_info["abort"]{
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        }
        set dap["str_mode"] to "aerostr".
        set assent_heading to inclination_command["heading"].
        set dap["aerostr"]["turn_heading"] to assent_heading.
        //set dap["aerostr"]["targetPitch"] to ascent["climb_pitch"].
        //calc time to alt climb alt
        local climb_time is time_to_alt(ship:altitude,ship:verticalspeed,ascent["climb_altitude"]).
        //time to speed
        //local accel_v is ship:sensors:acc.

        //local accel_in_prograde is vectorDotProduct(accel_v,ship:velocity:surface)/accel_v:mag.

        local accel_in_prograde is ship:sensors:acc:mag.
        local speed_time is time_to_alt(ship:airspeed,accel_in_prograde,ascent["climb_target_speed"]).
        
        // calculate the prograde pitch needed to make the altitude gain and speed gain finish at the same time.
        // assume the same constant acceleration over the speed build window, and model the vertical climb as the
        // prograde path distance times sin(pitch). this gives a target pitch in degrees so the vessel reaches
        // climb_altitude at the same time it reaches climb_target_speed.
        local alt_to_climb is ascent["climb_altitude"] - ship:altitude.
        local avg_speed is (ship:airspeed + ascent["climb_target_speed"]) / 2.
        local tvs is alt_to_climb / speed_time.
        local pfp_tgt is arcsin(tvs / avg_speed).
        local aoa_ascent is calc_aoa().
        local pitch_tgt is pfp_tgt + aoa_ascent.
        if pitch_tgt > dap["aerostr"]["turn_pitch"]{
            if pitch_tgt > dap["aerostr"]["turn_pitch"] + 0.1{
                set dap["aerostr"]["turn_pitch"] to dap["aerostr"]["turn_pitch"] + 0.1.
                
            }else{
                set dap["aerostr"]["turn_pitch"] to pitch_tgt.
            }
        }else if pitch_tgt < dap["aerostr"]["turn_pitch"]{
            if pitch_tgt < dap["aerostr"]["targetPitch"] - 0.1{
                set dap["aerostr"]["turn_pitch"] to dap["aerostr"]["turn_pitch"] - 0.1.
            }else{
                set dap["aerostr"]["turn_pitch"] to pitch_tgt.
            }
        }
        //set dap["aerostr"]["targetPitch"] to pitch_tgt.
        if step = "high_altitude_climb" and ship:altitude >= ascent["climb_altitude"] {
            nervson().
            set step to "nerv_assist".
            set Lastest_status to "nervs on".
        }
    }
    if step = "nerv_assist"{
        update_team_dap_gui().
        set abort_info to check_abort(step).
        if abort_info["abort"] {
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        } else {
            set dap["str_mode"] to "aerostr".
            set assent_heading to inclination_command["heading"].
            set dap["aerostr"]["turn_heading"] to assent_heading.
            set dap["aerostr"]["turn_pitch"] to ascent["nerv_pitch"].
            if ship:verticalspeed <= ascent["vertical_speed_recovery_threshold"] {
                set dap["aerostr"]["turn_pitch"] to ascent["nerv_pitch"] + ascent["vertical_speed_recovery_pitch"].
            }
            if step = "nerv_assist" and speed_trend <= ascent["speed_gain_threshold"] and ship:altitude >= ascent["closed_cycle_min_altitude"] {
                set step to "closed_cycle_climb".
                set Lastest_status to "transitioning to closed cycle".
            }
        }
    }
    if step = "closed_cycle_climb"{
            set abort_info to check_abort(step).
            if abort_info["abort"] {
                set abort_state to create_abort_state(abort_info,step,active_runway).
                set step to abort_state["mode"].
            } else {
                togglerapiermode("CLOSED").
                update_team_dap_gui().
                set Lastest_status to "rapiers in closed cycle".
                set dap["str_mode"] to "aerostr".
                set assent_heading to inclination_command["heading"].
                set dap["aerostr"]["turn_heading"] to assent_heading.
                if dap["aerostr"]["turn_pitch"] < ascent["closed_cycle_pitch_max"]{
                    set dap["aerostr"]["turn_pitch"] to dap["aerostr"]["turn_pitch"] + ascent["closed_cycle_pitch_rate"].
                }else{
                    set warp to 1.
                }
                rcs on.
                if step = "closed_cycle_climb" and ship:apoapsis > ascent["rapier_cutoff_apoapsis"] {
                    set recovery_nominal_cutoff to true.
                    rapiersoff().
                    set dap["aerostr"]["turn_pitch"] to ascent["apoapsis_build_pitch"].
                    set step to "apoapsis_build".
                    set Lastest_status to "nerv apoapsis build".
                }
            }
    }
    if step = "apoapsis_build"{
        update_team_dap_gui().
        set abort_info to check_abort(step).
        if abort_info["abort"] {
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        } else {
            set dap["str_mode"] to "aerostr".
            set assent_heading to inclination_command["heading"].
            set dap["aerostr"]["turn_heading"] to assent_heading.
            set dap["aerostr"]["turn_pitch"] to ascent["apoapsis_build_pitch"].
            if ship:verticalspeed <= ascent["vertical_speed_recovery_threshold"] {
                set dap["aerostr"]["turn_pitch"] to ascent["apoapsis_build_pitch"] + ascent["vertical_speed_recovery_pitch"].
            }
            if step = "apoapsis_build" and ship:apoapsis > TargetApoapsis + ascent["apoapsis_margin"] {
                set Step to "circ".
                togglerapiermode("AIR").
                rapiersoff().
                set dapthrottle to 0.
                wait 2.
            }
        }
    }
    if ship:altitude > ascent["space_altitude"] and (step = "apoapsis_build" or step = "closed_cycle_climb"){
            lock dap_steering to prograde.
            set Lastest_status to "Space".
            ag5 on.
    }
    
    if step = "circ" {
        set abort_info to check_abort("circ").
        if abort_info["abort"] {
            set abort_state to create_abort_state(abort_info,"circ",active_runway).
            set step to abort_state["mode"].
        } else {
            // A zero-loss managed context uses the same insertion monitor.
            set abort_info to lex("abort",true,"mode","ato","scenario",lex("rapiers_out",0,"nervs_out",0),
                "engines",abort_engine_snapshot()).
            set abort_state to create_abort_state(abort_info,"circ",active_runway).
            set abort_state["nominal_cutoff"] to true.
            set abort_state["nominal_insertion"] to true.
            set abort_state["mode"] to "ato".
            set abort_state["phase"] to "coast_align".
            set abort_state["rapier_continue"] to false.
            set abort_state["orbit_started_ut"] to time:seconds.
            set abort_state["progress_ut"] to time:seconds.
            set abort_state["progress_value"] to ship:periapsis.
            set abort_state["last_update_ut"] to time:seconds.
            set step to "ato".
        }
    }
    if step = "runway_abort"{
        set abort_state to abort_refresh_state(abort_state).
        if abort_state["mode"] = "contingency_abort" {
            set step to "contingency_abort".
        } else {
        set Lastest_status to "Runway abort".
        brakes on.
        set dapthrottle to 0.
        rapiersoff().
        set dap["aerostr"]["targetPitch"] to AVES["Abort"]["RunwayStop"]["command_pitch"].
        if ship:airspeed < AVES["Abort"]["RunwayStop"]["stop_speed"]{
            set Lastest_status to "abort complete".
            set abort_state["result"]["success"] to true.
            set abort_state["result"]["reason"] to "stopped_on_runway".
            set abort_state["active"] to false.
            set step to "end".
        }
        }
    }if step = "rtls"{
        set abort_state to abort_refresh_state(abort_state).
        if not(defined rtls_handoff_time){
            set rtls_handoff_time to 0.
        }
        if abort_state["mode"] = "contingency_abort" {
            set step to "contingency_abort".
        }else{
            local rtls_config is AVES["Abort"]["RTLS"].
            local rtls_policy is rtls_config[max(1,min(3,abort_state["scenario"]["rapiers_out"]))+"RO"].
            set abort_state["policy"] to lex(
                "use_nervs",rtls_policy["use_nervs"],"fuel_dump",rtls_policy["fuel_dump"],
                "target_mass",rtls_policy["target_mass"],"turn_bank",rtls_config["turn_bank"]
            ).
            if abort_state["phase"] = "initialize" {
                // Alignment may have ramped thrust to idle. RTLS owns thrust
                // from entry onward, including an already-airborne turnback.
                set dapthrottle to 1.
                set rtls_log_evidence to lex("phase","","active",true,"next_sample",0).
                set abort_state["target"] to lex(
                    "selected",true,"location",active_runway["Location"],"runway_num",active_runway["runway_num"],
                    "start",active_runway["start"],"end",active_runway["end"],"heading",active_runway["heading"],
                    "altitude",active_runway["altitude"],"distance_m",calcdistance_m(ship:geoposition,active_runway["start"]),"score",0
                ).
                // An RTLS chosen during launch, or just after the rotate
                // command, must first fly away from the runway.  Turning on
                // the ground is neither controllable nor recoverable.
                if ship:altitude <= liftoff_altitude {
                    set abort_state["phase"] to "takeoff_escape".
                }else{
                    set abort_state["phase"] to "turnback".
                }
                set abort_state["phase_entered"] to time:seconds.
            }
            set Lastest_status to "Abort RTLS " + abort_state["submode"] + " | " + abort_state["phase"].
            rapierson().
            if abort_state["policy"]["use_nervs"] { nervson(). }else{ nervsoff(). }
            local oxidizer_available is false.
            for res in ship:resources {
                if res:name = "Oxidizer" and res:amount > 0 { set oxidizer_available to true. }
            }
            if oxidizer_available { togglerapiermode("closed"). }else{ togglerapiermode("air"). }
            abort_set_fuel_dump(abort_state["policy"]["fuel_dump"] and ship:mass > abort_state["policy"]["target_mass"]).
            if abort_state["phase"] = "takeoff_escape" {
                // Use the ordinary takeoff controls until clearly airborne.
                // This covers an RTLS selected late in launch and an engine
                // failure immediately after rotation but before liftoff.
                // Keep the RTLS policy selected above: healthy RAPIERs are
                // in closed cycle when oxidizer is available, NERVs follow
                // the 1RO/2RO/3RO policy, and fuel dumping is already active.
                // A severe RAPIER-out case needs that full configured thrust
                // before it can safely lift off.
                rapierson().
                brakes off.
                gear on.
                set dap["str_mode"] to "aerostr".
                set dapthrottle to 1.
                set dap["aerostr"]["turn_heading"] to runway_heading.
                set dap["aerostr"]["targetPitch"] to ascent["rotate_pitch"].
                set dap["aerostr"]["turn_pitch"] to ascent["rotate_pitch"].
                if ship:altitude > liftoff_altitude {
                    set abort_state["phase"] to "turnback".
                    set abort_state["phase_entered"] to time:seconds.
                }
            }else if abort_state["phase"]= "turnback"{
                if calcdistance_m(ship:geoposition,active_runway["end"]) > rtls_config["gear_retract_distance"] { gear off. }
                if ship:altitude > rotate_altitude {
                    set dap["aerostr"]["turn_pitch"] to calc_aoa() - pitch_for_prograde() + rtls_config["airborne_pitch_margin"].
                }else{
                    set dap["aerostr"]["turn_pitch"] to calc_aoa() - pitch_for_prograde() + rtls_config["low_alt_pitch_margin"].
                }
                if ship:airspeed > rtls_config["minimum_turn_speed"] {
                    set abort_state["phase"] to "turnback".
                    set dap["str_mode"] to "aoa".
                    local rtls_heading_error is normalized_heading_error(heading_to_target(active_runway["start"]),compass_for_prograde()).
                    if rtls_heading_error > 0 {
                        set dap["aoa"]["target_bank"] to -rtls_config["turn_bank"].
                    }else{
                        set dap["aoa"]["target_bank"] to rtls_config["turn_bank"].
                    }
                    // Climb through the turnaround and hand reentry a stable
                    // reciprocal departure, rather than handing off part-way
                    // through the turn based only on heading change.
                    set dap["aoa"]["target_aoa"] to max(rtls_config["turnback_climb_aoa"],max(rtls_config["target_aoa_min"],-pitch_for_prograde())).
                    if pitch_for_prograde() > rtls_config["turnback_max_prograde_pitch"] {
                        set dap["aoa"]["base_pitch"] to rtls_config["turnback_max_prograde_pitch"].
                    }else if ship:verticalspeed < 0{
                        set dap["aoa"]["base_pitch"] to ((ship:verticalspeed)*(-1))/2.
                    }else{
                        set dap["aoa"]["base_pitch"] to 0.
                    }
                    local reciprocal_heading is runway_heading + 180.
                    if reciprocal_heading >= 360 { set reciprocal_heading to reciprocal_heading - 360. }
                    local reciprocal_heading_error is abs(normalized_heading_error(reciprocal_heading,compass_for_prograde())).
                    local handoff_altitude is runway_altitude + rtls_config["handoff_minimum_altitude"].
                    if reciprocal_heading_error <= rtls_config["reciprocal_heading_tolerance"] and ship:altitude >= handoff_altitude and not abort_state["handoff"]["started"] {

                        set abort_state["phase"] to "handoff".
                        set abort_state["display_handoff_position"] to ship:geoposition.
                        set abort_state["display_handoff_ut"] to time:seconds.
                        set abort_state["phase_entered"] to time:seconds.
                        set rtls_handoff_time to time:seconds.

                    }
                }else{
                    set dap["str_mode"] to "aerostr".
                }
            }else{
                //now phase is handoff
                if time:seconds - rtls_handoff_time < 4{
                    set dap["str_mode"] to "aerostr".
                    set dap["aerostr"]["turn_pitch"] to 5.
                    set dap["aerostr"]["turn_heading"] to compass_for_prograde().
                    set dap["aerostr"]["turn_roll"] to 0.

                }else{
                    set abort_state["handoff"]["started"] to true.
                    set dap["aoa"]["target_bank"] to 0.
                    set dap["aoa"]["target_aoa"] to 0.
                    set dap["aoa"]["base_pitch"] to 0.
                    set dap["str_mode"] to "aoa".
                    RUN "0:/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks"(lex(
                            "force",TRUE,"Location",active_runway["Location"],"Runway",active_runway["runway_num"],
                            "context",lex("mission","abort","abort_mode","rtls","preserve_propulsion",true,"allow_go_around",true)
                    )).
                    set abort_state["handoff"]["complete"] to true.
                    set abort_state["result"]["success"] to recovery_result["success"].
                    set abort_state["result"]["reason"] to recovery_result["reason"].
                    set abort_state["active"] to false.
                    set abort_state["phase"] to "complete".
                    set abort_state["phase_entered"] to time:seconds.
                    set step to "end".
                }    
            }
            flight_log_rtls_observe(abort_state,rtls_log_evidence).
        }
    }
    if step = "atr"{
        set abort_state to abort_refresh_state(abort_state).
        if abort_state["mode"] = "contingency_abort" {
            set step to "contingency_abort".
        }else{
            if not abort_state["target"]["selected"] {
                set abort_state["target"] to abort_select_runway().
                set abort_state["phase"] to "runway_selected".
            }
            if abort_state["target"]["selected"] and not abort_state["handoff"]["started"] {
                local atr_policy is AVES["Abort"]["RTLS"][max(1,min(3,abort_state["scenario"]["rapiers_out"]))+"RO"].
                set abort_state["policy"] to lex(
                    "use_nervs",atr_policy["use_nervs"],"fuel_dump",atr_policy["fuel_dump"],
                    "target_mass",atr_policy["target_mass"],"turn_bank",0
                ).
                abort_set_fuel_dump(abort_state["policy"]["fuel_dump"] and ship:mass > abort_state["policy"]["target_mass"]).
                set Lastest_status to "ATR " + abort_state["submode"] + " to " + abort_state["target"]["location"] + " " + abort_state["target"]["runway_num"].
                set abort_state["handoff"]["started"] to true.
                set abort_state["display_handoff_position"] to ship:geoposition.
                set abort_state["display_handoff_ut"] to time:seconds.
                RUN "0:/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks"(lex(
                    "force",TRUE,"Location",abort_state["target"]["location"],"Runway",abort_state["target"]["runway_num"],
                    "context",lex("mission","abort","abort_mode","atr","preserve_propulsion",true,"allow_go_around",true)
                )).
                set abort_state["handoff"]["complete"] to true.
                set abort_state["result"]["success"] to recovery_result["success"].
                set abort_state["result"]["reason"] to recovery_result["reason"].
                set abort_state["active"] to false.
                set step to "end".
            }else if not abort_state["target"]["selected"] {
                set Lastest_status to "ATR: no runway inside geometric search range".
            }
        }
    }
    if step = "ato" or step = "aed" or step = "edr" {
        // BEGIN MANAGED ABORT TICK
        local failures_before is abort_state["scenario"]["rapiers_out"]+abort_state["scenario"]["nervs_out"].
        set abort_state to abort_refresh_state(abort_state).
        recovery_apply_limits().
        local failures_after is abort_state["scenario"]["rapiers_out"]+abort_state["scenario"]["nervs_out"].
        if failures_after > failures_before {
            // An engine failure abandons the original mission orbit and rendezvous.
            if abort_state:haskey("nominal_insertion") {
                abort_state:remove("nominal_insertion").
            }
            local selected_mode is recovery_select_mode(abort_state,abort_state["current_ascent_phase"]).
            if selected_mode <> abort_state["mode"] {
                recovery_transition(abort_state,selected_mode,"new_engine_failure").
            }
        }
        // Capture ownership after observation; a transfer inside guidance waits for
        // the next loop tick instead of also running the destination controller.
        local recovery_tick_mode is abort_state["mode"].
        if failures_after > failures_before and recovery_tick_mode = "ato" {
            recovery_phase(abort_state,"initialize").
        }
        // BEGIN ATO STEP
        if step = "ato" and recovery_tick_mode = "ato" {
            local abort_tick_complete is false.
            local cfg is recovery_orbit_config().
            if abort_state:haskey("nominal_insertion") and abort_state["nominal_insertion"] {
                set cfg["target_ap"] to TargetApoapsis.
            }
            set warp to 0.
            abort_set_fuel_dump(false).
            if abort_state["phase"] = "initialize" {
                if abort_state["scenario"]["nervs_out"] > 0 {
                    recovery_ato_reject(abort_state,"nerv_failure").
                    set abort_tick_complete to true.
                }
                if not abort_tick_complete {
                    local layout is recovery_rapier_layout().
                    local rapier_continue is abort_state["scenario"]["rapiers_out"] = 1 or
                        (abort_state["scenario"]["rapiers_out"] = 2 and layout["opposite_pair"]).
                    if abort_state["nominal_cutoff"] {
                        set rapier_continue to false.
                    }
                    // A same-side pair and an uncalibrated single survivor are isolated. Their
                    // identities stay healthy so a later diversion can deliberately reuse them.
                    recovery_set_isolated("rapier",not rapier_continue).
                    recovery_set_isolated("nerv",false).
                    nervson().
                    if rapier_continue {
                        rapierson().
                        if abort_state["current_ascent_phase"] = "closed_cycle_climb" {
                            togglerapiermode("CLOSED").
                        }
                    }
                    set abort_state["power"] to recovery_power(abort_state,rapier_continue,true).
                    local power is abort_state["power"].
                    if not power["usable"] or power["acceleration"] < cfg["minimum_acceleration"] {
                        recovery_ato_reject(abort_state,"insufficient_permitted_thrust").
                        set abort_tick_complete to true.
                    }
                    if not abort_tick_complete {
                        local radial_mps is vdot(ship:velocity:orbit,ship:up:vector).
                        local tangent_mps is (ship:velocity:orbit-ship:up:vector*radial_mps):mag.
                        if rapier_continue {
                            set abort_state["orbit_budget"] to contingency_orbit_budget(ship:body:mu,ship:body:radius,
                                ship:altitude,ship:velocity:orbit:mag,radial_mps,cfg["target_ap"],power["vacuum_dv"],
                                power["acceleration"],contingency_config()).
                            if not abort_state["orbit_budget"]["possible"] {
                                recovery_ato_reject(abort_state,"nominal_orbit_fuel_budget").
                                set abort_tick_complete to true.
                            }
                            if not abort_tick_complete {
                                set abort_state["rapier_continue"] to true.
                                recovery_phase(abort_state,"nominal_continue").
                            }
                        } else {
                            if ship:altitude < cfg["minimum_escape_height"] or tangent_mps < cfg["minimum_escape_horizontal_speed"] {
                                recovery_ato_reject(abort_state,"nerv_escape_too_early").
                                set abort_tick_complete to true.
                            }
                            if not abort_tick_complete {
                                local best_prediction is lex("possible",false,"reason","no_pitch_candidate").
                                local prediction_started is time:seconds.
                                // Current measured drag is pessimistically held through the remaining
                                // atmosphere. Fuel is reserved for a 200 m/s model-error allowance.
                                local drag_bound is 0.
                                if ship:altitude < ship:body:atm:height {
                                    local aero_live is cur_aeroaccel_ld().
                                    set drag_bound to max(0,-vdot(aero_live["load"],ship:velocity:surface:normalized)).
                                }
                                local fuel_seconds is min(power["burn_time"],cfg["timeout"])-
                                    cfg["loss_allowance"]/max(0.01,power["acceleration"]).
                                for candidate_pitch in list(30,45,60) {
                                    dap:update().
                                    local predicted is recovery_escape_prediction(ship:body:mu,ship:body:radius,
                                        ship:body:atm:height,ship:altitude,radial_mps,tangent_mps,ship:mass,
                                        power["thrust"],power["mass_flow"],max(0,fuel_seconds),candidate_pitch,drag_bound,cfg).
                                    if predicted["possible"] {
                                        if not best_prediction["possible"] or predicted["burn_seconds"] < best_prediction["burn_seconds"] {
                                            set best_prediction to predicted.
                                        }
                                    }
                                    wait 0.
                                    if time:seconds-prediction_started > 6 {
                                        break.
                                    }
                                }
                                set abort_state["orbit_prediction"] to best_prediction.
                                flight_log_event("recovery_orbit_prediction","possible="+best_prediction["possible"]+
                                    "|reason="+best_prediction["reason"]+"|duration="+(time:seconds-prediction_started)).
                                if not best_prediction["possible"] {
                                    recovery_ato_reject(abort_state,best_prediction["reason"]).
                                    set abort_tick_complete to true.
                                }
                                if not abort_tick_complete {
                                    set abort_state["rapier_continue"] to false.
                                    set abort_state["escape_pitch"] to best_prediction["pitch"].
                                    recovery_phase(abort_state,"nerv_only_escape").
                                }
                            }
                        }
                        if not abort_tick_complete {
                            set abort_state["orbit_attempted"] to true.
                            set abort_state["orbit_started_ut"] to time:seconds.
                            set abort_state["progress_ut"] to time:seconds.
                            set abort_state["progress_value"] to ship:apoapsis.
                            set abort_state["pitch"] to pitch_for().
                            set abort_state["last_update_ut"] to time:seconds.
                            set abort_state["assist_speed_ut"] to time:seconds.
                            set abort_state["assist_speed"] to ship:airspeed.
                            set abort_state["assist_acceleration"] to 1e9.
                            flight_log_event("recovery_orbit_attempt","rapier_continue="+abort_state["rapier_continue"]+
                                "|goal_ap="+cfg["target_ap"]+"|goal_pe="+(ship:body:atm:height+cfg["safe_clearance"])+
                                "|dv_available="+power["dv"]+"|burn_time="+power["burn_time"]).
                            set abort_tick_complete to true.
                        }
                    }
                }
            }
            if not abort_tick_complete {
                local safe_height is ship:body:atm:height+cfg["safe_clearance"].
                if abort_state:haskey("nominal_insertion") and abort_state["nominal_insertion"] {
                    set safe_height to max(ship:body:atm:height+5000,TargetPeriapsis-300).
                }
                if ship:orbit:eccentricity < 1 and ship:periapsis >= safe_height {
                    recovery_phase(abort_state,"orbital_hold").
                    recovery_finish(abort_state,"ato_orbit_complete",true,false).
                    set abort_tick_complete to true.
                }
                if not abort_tick_complete {
                    local rapier_continue is abort_state["rapier_continue"] and not abort_state["nominal_cutoff"].
                    set abort_state["power"] to recovery_power(abort_state,rapier_continue,true).
                    local power is abort_state["power"].
                    local radial_mps is vdot(ship:velocity:orbit,ship:up:vector).
                    if not power["usable"] or ship:liquidfuel <= abort_state["lf_reserve"] or
                        time:seconds-abort_state["orbit_started_ut"] > cfg["timeout"] or
                        ship:orbit:eccentricity >= 1 or (radial_mps < -100 and ship:altitude < safe_height) {
                        recovery_ato_reject(abort_state,"fuel_thrust_time_or_descent").
                        set abort_tick_complete to true.
                    }
                    if not abort_tick_complete {
                        local dt_seconds is max(0,min(1,time:seconds-abort_state["last_update_ut"])).
                        set abort_state["last_update_ut"] to time:seconds.
                        set dap["dap_mode"] to "auto".
                        brakes off.
                        gear off.
                        if abort_state["phase"] = "nominal_continue" or abort_state["phase"] = "nerv_only_escape" or
                            abort_state["phase"] = "apoapsis_build" {
                            local desired_pitch is AVES["Ascent"]["nerv_pitch"].
                            if abort_state["phase"] = "nominal_continue" {
                                if abort_state["current_ascent_phase"] = "nerv_assist" {
                                    // Measure acceleration over elapsed time, independent of IPU
                                    // and prediction work, before giving up air-breathing thrust.
                                    if time:seconds-abort_state["assist_speed_ut"] >= 1 {
                                        set abort_state["assist_acceleration"] to (ship:airspeed-abort_state["assist_speed"])/
                                            (time:seconds-abort_state["assist_speed_ut"]).
                                        set abort_state["assist_speed"] to ship:airspeed.
                                        set abort_state["assist_speed_ut"] to time:seconds.
                                    }
                                    if ship:altitude >= AVES["Ascent"]["closed_cycle_min_altitude"] and
                                        abort_state["assist_acceleration"] <= cfg["assist_min_acceleration"] {
                                        set abort_state["current_ascent_phase"] to "closed_cycle_climb".
                                        togglerapiermode("CLOSED").
                                        flight_log_event("recovery_ascent_phase","to=closed_cycle_climb|acceleration="+
                                            abort_state["assist_acceleration"]+"|altitude="+ship:altitude).
                                    }
                                }
                                if abort_state["current_ascent_phase"] = "closed_cycle_climb" {
                                    set desired_pitch to AVES["Ascent"]["closed_cycle_pitch_max"].
                                }
                                if ship:apoapsis >= AVES["Ascent"]["rapier_cutoff_apoapsis"] {
                                    set abort_state["nominal_cutoff"] to true.
                                    set recovery_nominal_cutoff to true.
                                    recovery_set_isolated("rapier",true).
                                    set abort_state["current_ascent_phase"] to "apoapsis_build".
                                    recovery_phase(abort_state,"apoapsis_build").
                                }
                            }
                            if abort_state["phase"] = "apoapsis_build" {
                                set desired_pitch to AVES["Ascent"]["apoapsis_build_pitch"].
                            }
                            if abort_state["phase"] = "nerv_only_escape" {
                                set desired_pitch to abort_state["escape_pitch"].
                            }
                            if ship:altitude < ship:body:atm:height {
                                set desired_pitch to min(desired_pitch,pitch_for_prograde()+cfg["pullup_aoa"]).
                            }
                            set abort_state["pitch"] to abort_state["pitch"]+max(-cfg["pitch_rate"]*dt_seconds,
                                min(cfg["pitch_rate"]*dt_seconds,desired_pitch-abort_state["pitch"])).
                            set dap["str_mode"] to "aerostr".
                            set dap["aerostr"]["turn_heading"] to compass_for_prograde().
                            set dap["aerostr"]["turn_pitch"] to abort_state["pitch"].
                            set dap["aerostr"]["turn_roll"] to 0.
                            set dapthrottle to 1.
                            if ship:apoapsis >= cfg["target_ap"] {
                                recovery_set_isolated("rapier",true).
                                set abort_state["nominal_cutoff"] to true.
                                set recovery_nominal_cutoff to true.
                                set abort_state["current_ascent_phase"] to "circ".
                                set dapthrottle to 0.
                                recovery_phase(abort_state,"coast_align").
                                set abort_state["progress_ut"] to time:seconds.
                                set abort_state["progress_value"] to ship:periapsis.
                            }
                        } else {
                            local tangent is ship:velocity:orbit-ship:up:vector*radial_mps.
                            if tangent:mag < 1 {
                                recovery_ato_reject(abort_state,"no_orbital_tangent"). set abort_tick_complete to true.
                            }
                            if not abort_tick_complete {
                                set dap["str_mode"] to "vector".
                                set dap["vector"]["targetVector"] to tangent:normalized.
                                set abort_state["alignment"] to vang(ship:facing:vector,tangent).
                                local radius_now is ship:body:radius+ship:altitude.
                                local target_speed is sqrt(max(0,ship:body:mu*(2/radius_now-
                                    2/(radius_now+ship:body:radius+safe_height+100)))).
                                local remaining_dv is max(0,target_speed-tangent:mag).
                                set abort_state["burn_seconds"] to remaining_dv/max(0.01,power["acceleration"]).
                                // Passive GUI evidence from the same calculation and time gate
                                // used below. These fields never participate in control decisions.
                                set abort_state["display_remaining_dv"] to remaining_dv.
                                set abort_state["display_window_ut"] to time:seconds+ship:orbit:eta:apoapsis-
                                    abort_state["burn_seconds"]/2-15.
                                set abort_state["display_altitude_ready"] to ship:altitude >= safe_height.
                                set abort_state["display_insertion_ut"] to time:seconds.
                                set dapthrottle to 0.
                                if abort_state["phase"] = "coast_align" and ship:altitude >= safe_height and
                                    ship:orbit:eta:apoapsis <= abort_state["burn_seconds"]/2+15 {
                                    recovery_phase(abort_state,"insert").
                                }
                                if abort_state["phase"] = "insert" and abort_state["alignment"] <= cfg["alignment"] {
                                    set dapthrottle to min(1,remaining_dv/max(0.01,power["acceleration"]*5)).
                                }
                            }
                        }
                        if not abort_tick_complete {
                            if time:seconds-abort_state["progress_ut"] >= cfg["progress_seconds"] {
                                local actual_progress is ship:apoapsis.
                                if abort_state["phase"] = "coast_align" or abort_state["phase"] = "insert" {
                                    set actual_progress to ship:periapsis.
                                }
                                if abort_state["phase"] <> "coast_align" and actual_progress-abort_state["progress_value"] < cfg["minimum_gain"] {
                                    recovery_ato_reject(abort_state,"orbit_not_progressing").
                                    set abort_tick_complete to true.
                                }
                                if not abort_tick_complete {
                                    set abort_state["progress_ut"] to time:seconds.
                                    set abort_state["progress_value"] to actual_progress.
                                }
                            }
                        }
                    }
                }
            }
        }
        // END ATO STEP
        // BEGIN AED STEP
        if step = "aed" and recovery_tick_mode = "aed" {
            local abort_tick_complete is false.
            local cfg is recovery_aed_config().
            if abort_state["phase"] = "initialize" {
                set kuniverse:timewarp:warp to 0.
                abort_set_fuel_dump(false).
                set abort_state["orbit_abandoned"] to true.
                set abort_state["suppress_orbit"] to true.
                set abort_state["aed_started"] to time:seconds.
                set abort_state["aed_last_update"] to time:seconds.
                set abort_state["aed_aoa"] to dap["aoa"]["smooth_target_aoa"].
                set abort_state["aed_bank"] to dap["aoa"]["smooth_target_bank"].
                set abort_state["aed_throttle"] to dapthrottle.
                set abort_state["aed_capture_since"] to -1.
                set abort_state["aed_assist_time"] to 0.
                set abort_state["aed_assist_dv"] to 0.
                set abort_state["aed_assist_lf"] to 0.
                set abort_state["aed_assist_ox"] to 0.
                set abort_state["aed_last_lf"] to ship:liquidfuel.
                set abort_state["aed_last_ox"] to ship:oxidizer.
                set abort_state["aed_last_search"] to time:seconds.
                set abort_state["aed_intent"] to "ascending_coast".
                set abort_state["aed_committed"] to false.
                set abort_state["aed_powered"] to false.
                set abort_state["aed_search_cycles"] to 0.
                set abort_state["aed_propulsion_mode"] to "ClosedCycle".
                set abort_state["aed_power_retry_until"] to -1.
                set abort_state["aed_air_retry_after"] to -1.
                recovery_set_isolated("rapier",false).
                recovery_set_isolated("nerv",true).
                togglerapiermode("CLOSED").
                rapierson().
                nervsoff().
                recovery_apply_limits().
                local power is recovery_power(abort_state,true,false).
                local assist is recovery_aed_assist(power,ship:liquidfuel,ship:oxidizer,
                    abort_state["lf_reserve"],abort_state["ox_reserve"],cfg).
                set abort_state["aed_assist_budget"] to assist.
                set abort_state["aed_search"] to recovery_aed_search(current_simstate(),abort_state["rejected_targets"],assist,cfg).
                set abort_state["aed_logged_search_index"] to -1.
                flight_log_event("aed_search_started","order=nearest_runway|candidates="+abort_state["aed_search"]["candidates"]:length).
                if recovery_aed_power_available(power) {
                    local exploratory is recovery_aed_powered_target(abort_state["aed_search"],current_simstate(),cfg).
                    if exploratory["selected"] {
                        set abort_state["target"] to exploratory.
                        set abort_state["aed_powered"] to true.
                        flight_log_event("aed_diversion_target","location="+exploratory["location"]+
                            "|runway="+exploratory["runway_num"]+"|provisional=True|distance="+exploratory["distance_m"]).
                    }
                }
                recovery_phase(abort_state,"select_runway").
            }
            local dt_aed is max(0,min(0.25,time:seconds-abort_state["aed_last_update"])).
            set abort_state["aed_last_update"] to time:seconds.
            set abort_state["aed_assist_lf"] to abort_state["aed_assist_lf"]+max(0,abort_state["aed_last_lf"]-ship:liquidfuel).
            set abort_state["aed_assist_ox"] to abort_state["aed_assist_ox"]+max(0,abort_state["aed_last_ox"]-ship:oxidizer).
            set abort_state["aed_last_lf"] to ship:liquidfuel.
            set abort_state["aed_last_ox"] to ship:oxidizer.
            // Prefer LF-only jet flight after descending into the atmosphere.
            // Mode changes have a short settling window before loss assessment.
            local aed_engine_mode is abort_state["aed_propulsion_mode"].
            if ship:altitude <= cfg["airbreathing_height"] and ship:airspeed <= 600 and
               time:seconds >= abort_state["aed_air_retry_after"] {
                set aed_engine_mode to "AirBreathing".
            } else if ship:altitude >= cfg["rocket_height"] {
                set aed_engine_mode to "ClosedCycle".
            }
            if aed_engine_mode <> abort_state["aed_propulsion_mode"] {
                local mode_command is "CLOSED".
                if aed_engine_mode = "AirBreathing" { set mode_command to "AIR". }
                togglerapiermode(mode_command).
                rapierson().
                set abort_state["aed_propulsion_mode"] to aed_engine_mode.
                set abort_state["aed_power_retry_until"] to time:seconds+1.
                flight_log_event("aed_propulsion_mode","mode="+aed_engine_mode+"|reason=altitude_speed"+
                    "|altitude="+ship:altitude+"|speed="+ship:airspeed).
            }
            if time:seconds <= abort_state["aed_power_retry_until"] { rapierson(). }
            local power is recovery_power(abort_state,true,false).
            // Reserves protect the orbit budget, not a compulsory engine cut
            // during an airborne diversion. Release them before declaring loss.
            if not recovery_aed_power_available(power) and
               (abort_state["lf_reserve"] > 0 or abort_state["ox_reserve"] > 0) and
               ship:liquidfuel > 0 and
               (aed_engine_mode = "AirBreathing" or ship:oxidizer > 0) {
                local layout is recovery_rapier_layout().
                if layout["healthy"] > 0 {
                    flight_log_event("aed_reserve_released","lf_reserve="+abort_state["lf_reserve"]+
                        "|ox_reserve="+abort_state["ox_reserve"]+"|lf="+ship:liquidfuel+"|ox="+ship:oxidizer).
                    set abort_state["lf_reserve"] to 0.
                    set abort_state["ox_reserve"] to 0.
                    rapierson().
                    set abort_state["aed_power_retry_until"] to time:seconds+1.
                    set power to recovery_power(abort_state,true,false).
                    flight_log_event("aed_propulsion_restart","reason=reserve_released|mode="+aed_engine_mode).
                }
            }
            if not recovery_aed_power_available(power) and aed_engine_mode = "AirBreathing" and
               time:seconds > abort_state["aed_power_retry_until"] and ship:oxidizer > 0 and
               recovery_rapier_layout()["healthy"] > 0 {
                togglerapiermode("CLOSED").
                rapierson().
                set abort_state["aed_propulsion_mode"] to "ClosedCycle".
                set abort_state["aed_air_retry_after"] to time:seconds+30.
                set abort_state["aed_power_retry_until"] to time:seconds+1.
                set power to recovery_power(abort_state,true,false).
                flight_log_event("aed_propulsion_mode","mode=ClosedCycle|reason=jet_power_unavailable").
            }
            set abort_state["power"] to power.
            if abort_state["aed_throttle"] > 0 {
                set abort_state["aed_assist_time"] to abort_state["aed_assist_time"]+dt_aed.
                set abort_state["aed_assist_dv"] to abort_state["aed_assist_dv"]+
                    power["acceleration"]*abort_state["aed_throttle"]*dt_aed.
            }
            if not recovery_aed_power_available(power) {
                if time:seconds <= abort_state["aed_power_retry_until"] and ship:liquidfuel > 0 and
                   recovery_rapier_layout()["healthy"] > 0 {
                    set dapthrottle to 0.
                    set abort_tick_complete to true.
                } else {
                    recovery_transition(abort_state,"edr","aed_rapier_unavailable"). set abort_tick_complete to true.
                }
            }
            if not abort_tick_complete {
                if time:seconds-abort_state["aed_started"] > cfg["maximum_duration"] and
                   not abort_state:haskey("aed_deadline_logged") {
                    set abort_state["aed_deadline_logged"] to true.
                    set abort_state["aed_powered"] to true.
                    flight_log_event("aed_powered_replan","reason=aed_timeout|power_available=True").
                }
                if not abort_tick_complete {
                    local desired_aoa is cfg["low_drag_aoa"].
                    local desired_bank is 0.
                    local throttle_aed is 0.
                    set dap["dap_mode"] to "auto".
                    set dap["str_mode"] to "aoa".
                    set dap["aoa"]["base_pitch"] to 0.
                    // During a search preserve range and a climbing flight path. The predictor
                    // advances only a small number of bounded steps after these live commands.
                    if ship:verticalspeed > 5 {
                        set desired_aoa to max(0,min(10,abort_state["aed_aoa"])).
                    }
                    if abort_state["target"]["selected"] {
                        local aed_target_site is abort_state["target"].
                        local intake is aed_target_site["capture_interface"].
                        local distance_aed is calcdistance_m(ship:geoposition,intake["target_latlng"]).
                        local course_error is normalized_heading_error(heading_to_target(intake["target_latlng"]),compass_for_prograde()).
                        set desired_bank to max(-cfg["maximum_bank"],min(cfg["maximum_bank"],-0.6*course_error)).
                        local gravity_aed is ship:body:mu/ship:body:radius^2.
                        local energy_aed is recovery_aed_energy(ship:altitude,ship:airspeed,
                            intake["target_altitude"],cfg["capture_speed"],gravity_aed).
                        local terminal_actual is ship:altitude-aed_target_site["altitude"]+ship:airspeed^2/(2*gravity_aed).
                        local terminal_margin is terminal_actual-intake["terminal_required"].
                        set abort_state["aed_energy"] to energy_aed.
                        set abort_state["aed_energy_margin"] to terminal_margin.
                        set abort_state["aed_distance"] to distance_aed.
                        set abort_state["aed_heading_error"] to course_error.
                        local intent is abort_state["aed_intent"].
                        if ship:verticalspeed > 5 {
                            set intent to "ascending_coast".
                        } else if energy_aed > 2200 and ship:altitude < 35000 and ship:q > 0.1 {
                            set intent to "energy_dissipation".
                        } else if energy_aed < -500 or terminal_margin < -500 {
                            set intent to "powered_extension".
                        } else if intent <> "energy_dissipation" or energy_aed < 1200 {
                            set intent to "descending_capture".
                        }
                        if not abort_state["aed_powered"] and intent <> abort_state["aed_intent"] {
                            set abort_state["aed_intent"] to intent.
                            flight_log_event("aed_intent","intent="+intent+"|energy="+round(energy_aed,1)).
                        }
                        if intent = "energy_dissipation" {
                            set desired_aoa to cfg["drag_aoa"].
                        }
                        if intent = "powered_extension" and not abort_state["aed_powered"] {
                            set desired_aoa to 4.
                            local assist is abort_state["aed_assist_budget"].
                            local assist_available is abort_state["aed_assist_time"] < assist["time"] and
                                abort_state["aed_assist_dv"] < assist["dv"] and
                                abort_state["aed_assist_lf"] < assist["lf"] and
                                (assist["ox"] <= 0 or abort_state["aed_assist_ox"] < assist["ox"]) and
                                ship:liquidfuel > abort_state["lf_reserve"] and ship:oxidizer > abort_state["ox_reserve"].
                            // The small assist allowance limits predictor credit;
                            // it must not prohibit burning remaining usable fuel.
                            set throttle_aed to cfg["assist_throttle"].
                            if not assist_available and not abort_state:haskey("aed_assist_limit_logged") {
                                set abort_state["aed_assist_limit_logged"] to true.
                                flight_log_event("aed_powered_extension","reason=forecast_assist_budget_exhausted"+
                                    "|power_available=True|lf="+ship:liquidfuel+"|ox="+ship:oxidizer).
                            }
                        }
                        // No high-speed TEAM holding turn: all capture conditions must hold
                        // continuously before control leaves Orbit Main.
                        local clearance_aed is ship:altitude-max(0,ship:geoposition:terrainheight).
                        local gate is recovery_aed_capture_gate(distance_aed,ship:altitude-intake["target_altitude"],
                            ship:airspeed,ship:verticalspeed,
                            normalized_heading_error(aed_target_site["heading"],compass_for_prograde()),roll_for(),
                            clearance_aed,terminal_margin,0,cfg).
                        local provisional is aed_target_site:haskey("provisional") and aed_target_site["provisional"].
                        local settle_aed is cfg["capture_settle"].
                        set abort_state["aed_capture_reason"] to "forecast_capture".
                        if provisional or abort_state["aed_powered"] {
                            local runway_range is calcdistance_m(ship:geoposition,aed_target_site["start"]).
                            local live_intake is recovery_aed_terminal_intake(runway_range,aed_target_site["altitude"],cfg).
                            local live_margin is terminal_actual-live_intake["required"].
                            local runway_course_error is normalized_heading_error(
                                heading_to_target(aed_target_site["start"]),compass_for_prograde()).
                            set gate to recovery_aed_team_gate(distance_aed,ship:altitude-intake["target_altitude"],
                                ship:airspeed,ship:verticalspeed,runway_course_error,roll_for(),clearance_aed,
                                live_margin,cfg,runway_range).
                            set abort_state["aed_runway_distance"] to runway_range.
                            set abort_state["aed_terminal_required"] to live_intake["required"].
                            set abort_state["aed_energy_margin"] to live_margin.
                            set settle_aed to cfg["team_settle"].
                            set abort_state["aed_capture_reason"] to gate["reason"].
                        }
                        set abort_state["aed_capture_valid"] to gate["valid"].
                        if gate["valid"] {
                            if abort_state["aed_capture_since"] < 0 {
                                set abort_state["aed_capture_since"] to time:seconds.
                            }
                            recovery_phase(abort_state,"capture").
                            if time:seconds-abort_state["aed_capture_since"] >= settle_aed {
                                set abort_state["aed_committed"] to true.
                                set abort_state["capture_interface"] to intake.
                                set abort_state["handoff_phase"] to "TEAM".
                                set abort_state["handoff_ready"] to true.
                                brakes off.
                                flight_log_event("aed_TEAM_capture","reason="+abort_state["aed_capture_reason"]+
                                    "|provisional="+provisional+"|distance="+distance_aed+
                                    "|height_error="+(ship:altitude-intake["target_altitude"])+
                                    "|speed="+ship:airspeed+"|vs="+ship:verticalspeed+
                                    "|runway_distance="+calcdistance_m(ship:geoposition,aed_target_site["start"])+
                                    "|energy_margin="+abort_state["aed_energy_margin"]).
                                recovery_phase(abort_state,"TEAM").
                            }
                        } else {
                            set abort_state["aed_capture_since"] to -1.
                            if abort_state["phase"] = "capture" {
                                recovery_phase(abort_state,"energy_transit").
                            }
                        }
                        // Refresh forecasts in transit without interrupting the continuous
                        // control law or replacing a target until the prior one is rejected.
                        if not abort_state["aed_committed"] and abort_state["phase"] <> "capture" and time:seconds-abort_state["aed_last_search"] > cfg["prediction_refresh"] and
                            abort_state["aed_search"]["complete"] {
                            set abort_state["aed_search"] to recovery_aed_search(current_simstate(),abort_state["rejected_targets"],
                                lex("time",max(0,abort_state["aed_assist_budget"]["time"]-abort_state["aed_assist_time"]),
                                "dv",max(0,abort_state["aed_assist_budget"]["dv"]-abort_state["aed_assist_dv"])),cfg,abort_state["target"]).
                            set abort_state["aed_logged_search_index"] to -1.
                            set abort_state["aed_last_search"] to time:seconds.
                        }
                    }
                    if abort_state["aed_powered"] and not abort_state["aed_committed"] {
                        local diversion_distance is cfg["capture_distance"].
                        local diversion_error is 0.
                        local diversion_height is ship:altitude.
                        if abort_state["target"]["selected"] {
                            // Approach the actual airfield; chasing its far upstream
                            // predictor point produced flight 333's shallow intercept.
                            local diversion_target is abort_state["target"]["start"].
                            set diversion_distance to calcdistance_m(ship:geoposition,diversion_target).
                            local diversion_intake is recovery_aed_terminal_intake(diversion_distance,
                                abort_state["target"]["altitude"],cfg).
                            set diversion_height to diversion_intake["target_altitude"].
                            set diversion_error to normalized_heading_error(heading_to_target(diversion_target),compass_for_prograde()).
                        }
                        local powered_command is recovery_aed_powered_command(ship:airspeed,ship:verticalspeed,
                            ship:altitude-max(0,ship:geoposition:terrainheight),diversion_distance,diversion_error,
                            ship:body:mu/ship:body:radius^2,ship:q,cfg,
                            diversion_height-max(0,ship:geoposition:terrainheight)).
                        set desired_aoa to powered_command["aoa"].
                        set desired_bank to powered_command["bank"].
                        set throttle_aed to powered_command["throttle"].
                        set abort_state["aed_turn_distance"] to powered_command["turn_distance"].
                        set abort_state["aed_turn_ready"] to powered_command["turn_ready"].
                        set abort_state["aed_desired_vs"] to powered_command["desired_vs"].
                        set abort_state["aed_airbrake"] to powered_command["airbrake"].
                        set abort_state["aed_bank_limit"] to powered_command["bank_limit"].
                        set abort_state["aed_heading_error"] to diversion_error.
                        set abort_state["aed_capture_height"] to diversion_height.
                        local steep_bank_now is abs(desired_bank) > 90.
                        if not abort_state:haskey("aed_steep_bank") or abort_state["aed_steep_bank"] <> steep_bank_now {
                            set abort_state["aed_steep_bank"] to steep_bank_now.
                            flight_log_event("aed_bank_authority","steep="+steep_bank_now+"|bank="+desired_bank+
                                "|limit="+powered_command["bank_limit"]+"|clearance="+(ship:altitude-max(0,ship:geoposition:terrainheight))+
                                "|speed="+ship:airspeed+"|vs="+ship:verticalspeed+"|q="+ship:q).
                        }
                        if powered_command["airbrake"] { brakes on. } else { brakes off. }
                        if abort_state["aed_intent"] <> powered_command["intent"] {
                            set abort_state["aed_intent"] to powered_command["intent"].
                            flight_log_event("aed_intent","intent="+abort_state["aed_intent"]+
                                "|turn_distance="+powered_command["turn_distance"]+"|turn_ready="+powered_command["turn_ready"]).
                        }
                    }
                    // Envelope DAP still owns q/thermal/terrain/stall protection. AED command
                    // continuity uses actual/smoothed entry values instead of an abrupt reset.
                    if ship:altitude > 35000 {
                        set desired_aoa to min(desired_aoa,cfg["thin_aoa"]).
                    }
                    set abort_state["aed_aoa"] to abort_state["aed_aoa"]+max(-3*dt_aed,min(3*dt_aed,desired_aoa-abort_state["aed_aoa"])).
                    set abort_state["aed_bank"] to abort_state["aed_bank"]+max(-10*dt_aed,min(10*dt_aed,desired_bank-abort_state["aed_bank"])).
                    set dap["aoa"]["target_aoa"] to abort_state["aed_aoa"].
                    set dap["aoa"]["target_bank"] to abort_state["aed_bank"].
                    set abort_state["aed_throttle"] to abort_state["aed_throttle"]+
                        max(-0.5*dt_aed,min(0.5*dt_aed,throttle_aed-abort_state["aed_throttle"])).
                    set dapthrottle to abort_state["aed_throttle"].
                    recovery_apply_limits().
                    if not abort_state["aed_search"]["complete"] and not abort_state["aed_committed"] and
                       abort_state["phase"] <> "capture" {
                        local pending_search is abort_state["aed_search"].
                        if pending_search:haskey("index") and pending_search["index"] < pending_search["candidates"]:length and
                           pending_search["prediction"] = 0 and pending_search["family"] = "low" {
                            set pending_search to recovery_aed_search_refresh_candidate(pending_search,current_simstate(),
                                cfg,abort_state["target"]).
                        }
                        if pending_search:haskey("index") and pending_search["index"] < pending_search["candidates"]:length and
                           pending_search["index"] <> abort_state["aed_logged_search_index"] {
                            local pending_candidate is pending_search["candidates"][pending_search["index"]].
                            set abort_state["aed_logged_search_index"] to pending_search["index"].
                            set abort_state["aed_candidate"] to pending_candidate["location"]+"_"+pending_candidate["runway_num"].
                            flight_log_event("aed_candidate_started","target="+abort_state["aed_candidate"]+
                                "|index="+pending_search["index"]+"|distance="+pending_candidate["distance"]).
                        }
                        set abort_state["aed_search"] to recovery_aed_search_step(abort_state["aed_search"],cfg).
                        if abort_state["aed_search"]["complete"] {
                            for rejected_key in abort_state["aed_search"]["rejections"]:keys {
                                flight_log_event("aed_candidate_rejected","target="+rejected_key+
                                    "|reason="+abort_state["aed_search"]["rejections"][rejected_key]).
                            }
                            if abort_state["target"]["selected"] and not abort_state["aed_committed"] and abort_state["phase"] <> "capture" {
                                local target_key is abort_state["target"]["location"]+"_"+abort_state["target"]["runway_num"].
                                local retained_feasible is false.
                                for reevaluated in abort_state["aed_search"]["candidates"] {
                                    if reevaluated:haskey("screen") and reevaluated["location"]+"_"+reevaluated["runway_num"] = target_key and
                                        reevaluated["screen"]["feasible"] {
                                        set retained_feasible to true.
                                    }
                                }
                                if not retained_feasible and abort_state["aed_search"]["rejections"]:haskey(target_key) and
                                   not abort_state["aed_powered"] {
                                    set abort_state["rejected_targets"][target_key] to "live_prediction_rejected".
                                    flight_log_event("aed_target_rejected","target="+target_key+"|reason=live_prediction_rejected").
                                    set abort_state["target"] to lex("selected",false).
                                    set abort_state["aed_capture_since"] to -1.
                                }
                            }
                            if not abort_state["target"]["selected"] or abort_state["aed_powered"] {
                                if abort_state["aed_search"]["best"]["selected"] {
                                    set abort_state["aed_powered"] to false.
                                    set abort_state["target"] to abort_state["aed_search"]["best"].
                                    recovery_phase(abort_state,"energy_transit").
                                    flight_log_event("aed_runway_selected","location="+abort_state["target"]["location"]+
                                        "|runway="+abort_state["target"]["runway_num"]+
                                        "|altitude="+abort_state["target"]["capture_interface"]["target_altitude"]+
                                        "|energy_margin="+abort_state["target"]["screen"]["energy_margin"]).
                                } else {
                                    // A search deadline / unpowered rejection is not
                                    // evidence that a powered diversion is impossible.
                                    set abort_state["aed_powered"] to true.
                                    set abort_state["aed_capture_since"] to -1.
                                    recovery_phase(abort_state,"powered_replan").
                                    local search is abort_state["aed_search"].
                                    local search_reason is "exhausted".
                                    if search:haskey("reason") { set search_reason to search["reason"]. }
                                    local exploratory is recovery_aed_powered_target(search,current_simstate(),cfg).
                                    if exploratory["selected"] {
                                        set abort_state["target"] to exploratory.
                                        flight_log_event("aed_diversion_target","location="+exploratory["location"]+
                                            "|runway="+exploratory["runway_num"]+"|provisional=True|distance="+exploratory["distance_m"]).
                                    }
                                    set abort_state["aed_search_cycles"] to abort_state["aed_search_cycles"]+1.
                                    flight_log_event("aed_search_result","reason="+search_reason+
                                        "|cycle="+abort_state["aed_search_cycles"]+"|power_available=True|action=powered_replan").
                                    if search_reason = "timeout" {
                                        // Keep unfinished integrations and the next
                                        // candidate; never restart at runway zero.
                                        set abort_state["aed_search"] to recovery_aed_search_resume(search).
                                    } else {
                                        set abort_state["rejected_targets"] to lex().
                                        local remaining_assist is recovery_aed_assist(power,ship:liquidfuel,ship:oxidizer,
                                            abort_state["lf_reserve"],abort_state["ox_reserve"],cfg).
                                        set abort_state["aed_search"] to recovery_aed_search(current_simstate(),
                                            abort_state["rejected_targets"],remaining_assist,cfg).
                                        set abort_state["aed_logged_search_index"] to -1.
                                    }
                                    set abort_state["aed_last_search"] to time:seconds.
                                }
                            }
                        }
                    }
                }
            }
        }
        // END AED STEP
        // BEGIN EDR STEP
        if step = "edr" and recovery_tick_mode = "edr" {
            local abort_tick_complete is false.
            local cfg is recovery_orbit_config().
            set warp to 0.
            abort_set_fuel_dump(false).
            set dapthrottle to 0.
            if abort_state["phase"] = "initialize" {
                set abort_state["return_started_ut"] to time:seconds.
                set abort_state["suppress_orbit"] to true.
                set abort_state["orbit_abandoned"] to true.
                set abort_state["entry_verified"] to false.
                set abort_state["return_attempted"] to false.
                // An already-suborbital trajectory needs no automatic retrograde burn.
                if ship:periapsis < ship:body:atm:height {
                    recovery_set_isolated("rapier",true).
                    recovery_set_isolated("nerv",true).
                    recovery_phase(abort_state,"passive_return").
                } else {
                    recovery_set_isolated("rapier",false).
                    recovery_set_isolated("nerv",false).
                    local layout is recovery_rapier_layout().
                    if layout["healthy"] < 3 and not layout["opposite_pair"] {
                        recovery_set_isolated("rapier",true).
                    }
                    togglerapiermode("CLOSED").
                    rapierson().
                    nervson().
                    recovery_apply_limits().
                    set abort_state["power"] to recovery_power(abort_state,true,true).
                    local power is abort_state["power"].
                    local radial_mps is vdot(ship:velocity:orbit,ship:up:vector).
                    local tangent_mps is (ship:velocity:orbit-ship:up:vector*radial_mps):mag.
                    set abort_state["return_plan"] to recovery_return_burn(ship:body:mu,ship:body:radius,
                        ship:altitude,tangent_mps,cfg["deorbit_pe"],power["acceleration"],power["dv"]).
                    // Long weak burns require a separate finite-duration margin. Reject
                    // a burn that cannot fit the available propellant or recovery time.
                    if not abort_state["return_plan"]["possible"] or
                        abort_state["return_plan"]["burn_seconds"] > min(180,power["burn_time"]*0.8) {
                        recovery_finish(abort_state,"edr_deorbit_unavailable_orbit_hold",false,true).
                        set abort_tick_complete to true.
                    }
                    if not abort_tick_complete {
                        local predicted is recovery_return_prediction(ship:body:mu,ship:body:radius,
                            ship:body:atm:height,ship:altitude,radial_mps,
                            max(0,tangent_mps-abort_state["return_plan"]["dv"]),ship:body:angularvel:mag,1800).
                        if not predicted["possible"] {
                            recovery_finish(abort_state,"edr_entry_prediction_rejected_orbit_hold",false,true).
                            set abort_tick_complete to true.
                        }
                        if not abort_tick_complete {
                            local footprint is get_geoposition_along_heading(ship:geoposition,compass_for_prograde(),predicted["downrange"]).
                            set abort_state["target"] to recovery_edr_select_target(footprint,cfg).
                            if not abort_state["target"]["selected"] {
                                recovery_finish(abort_state,"edr_no_return_runway_orbit_hold",false,true).
                                set abort_tick_complete to true.
                            }
                            if not abort_tick_complete {
                                set abort_state["return_plan"]["footprint"] to footprint.
                                set abort_state["return_plan"]["entry_speed"] to predicted["entry_speed"].
                                set abort_state["return_plan"]["entry_slope"] to predicted["entry_slope"].
                                set abort_state["burn_started_ut"] to -1.
                                recovery_phase(abort_state,"align_return").
                                flight_log_event("recovery_return_plan","dv="+abort_state["return_plan"]["dv"]+
                                    "|burn_seconds="+abort_state["return_plan"]["burn_seconds"]+
                                    "|runway="+abort_state["target"]["location"]+"_"+abort_state["target"]["runway_num"]+
                                    "|entry_slope="+predicted["entry_slope"]+"|model=ballistic_geometric_screen").
                            }
                        }
                    }
                }
                if not abort_tick_complete {
                    set abort_tick_complete to true.
                }
            }
            if not abort_tick_complete {
                if time:seconds-abort_state["return_started_ut"] > cfg["return_timeout"] {
                    recovery_finish(abort_state,"edr_return_timeout",false,true).
                    set abort_tick_complete to true.
                }
                if not abort_tick_complete {
                    local radial_mps is vdot(ship:velocity:orbit,ship:up:vector).
                    local tangent is ship:velocity:orbit-ship:up:vector*radial_mps.
                    if abort_state["phase"] = "align_return" or abort_state["phase"] = "return_burn" {
                        if tangent:mag < 1 {
                            recovery_finish(abort_state,"edr_no_orbital_tangent",false,true). set abort_tick_complete to true.
                        }
                        if not abort_tick_complete {
                            set dap["str_mode"] to "vector".
                            set dap["vector"]["targetVector"] to -tangent:normalized.
                            set abort_state["alignment"] to vang(ship:facing:vector,-tangent).
                            set abort_state["power"] to recovery_power(abort_state,true,true).
                            if ship:periapsis <= cfg["deorbit_pe"] {
                                set dapthrottle to 0.
                                recovery_set_isolated("rapier",true).
                                recovery_set_isolated("nerv",true).
                                recovery_phase(abort_state,"verify_return").
                            } else if abort_state["alignment"] <= cfg["return_alignment"] and abort_state["power"]["usable"] {
                                if abort_state["burn_started_ut"] < 0 {
                                    set abort_state["burn_started_ut"] to time:seconds.
                                }
                                set abort_state["return_attempted"] to true.
                                recovery_phase(abort_state,"return_burn").
                                set dapthrottle to min(1,max(0.05,(ship:periapsis-cfg["deorbit_pe"])/10000)).
                                if time:seconds-abort_state["burn_started_ut"] > abort_state["return_plan"]["burn_seconds"]*1.5+10 {
                                    set dapthrottle to 0.
                                    if ship:periapsis < ship:body:atm:height {
                                        recovery_phase(abort_state,"verify_return").
                                    } else {
                                        recovery_finish(abort_state,"edr_burn_not_progressing_orbit_hold",false,true).
                                    }
                                }
                            } else if time:seconds-abort_state["phase_entered"] > 60 {
                                recovery_finish(abort_state,"edr_alignment_or_thrust_unavailable",false,true).
                            }
                            set abort_tick_complete to true.
                        }
                    }
                    if not abort_tick_complete {
                        if ship:periapsis >= ship:body:atm:height {
                            recovery_finish(abort_state,"edr_return_trajectory_not_verified",false,true).
                            set abort_tick_complete to true.
                        }
                        if not abort_tick_complete {
                            if not abort_state["entry_verified"] or
                                (abort_state:haskey("entry_check_ut") and time:seconds-abort_state["entry_check_ut"] > 30) {
                                local actual_return is recovery_return_prediction(ship:body:mu,ship:body:radius,
                                    ship:body:atm:height,ship:altitude,radial_mps,tangent:mag,
                                    ship:body:angularvel:mag,1800).
                                if not actual_return["possible"] {
                                    recovery_transition(abort_state,"contingency_abort","edr_actual_entry_geometry_rejected").
                                    set abort_tick_complete to true.
                                }
                                if not abort_tick_complete {
                                    local actual_footprint is get_geoposition_along_heading(ship:geoposition,
                                        compass_for_prograde(),actual_return["downrange"]).
                                    if ADDONS:TR:available and ADDONS:TR:hasimpact {
                                        set actual_footprint to ADDONS:TR:impactpos.
                                    }
                                    set abort_state["target"] to recovery_edr_select_target(actual_footprint,cfg).
                                    set abort_state["entry_verified"] to true.
                                    set abort_state["entry_check_ut"] to time:seconds.
                                    set abort_state["actual_return"] to actual_return.
                                    flight_log_event("recovery_return_verified","periapsis="+ship:periapsis+
                                        "|entry_slope="+actual_return["entry_slope"]+"|entry_speed="+actual_return["entry_speed"]+
                                        "|runway_available="+abort_state["target"]["selected"]).
                                }
                            }
                            if not abort_tick_complete {
                                set dap["str_mode"] to "vector".
                                set dap["vector"]["targetVector"] to ship:velocity:orbit:normalized.
                                if ship:altitude <= ship:body:atm:height and radial_mps < 0 {
                                    if not abort_state["target"]["selected"] {
                                        local footprint is ship:geoposition.
                                        if ADDONS:TR:available and ADDONS:TR:hasimpact {
                                            set footprint to ADDONS:TR:impactpos.
                                        }
                                        set abort_state["target"] to recovery_edr_select_target(footprint,cfg).
                                    }
                                    if abort_state["target"]["selected"] {
                                        // Normal entry starts only after a real descending atmosphere
                                        // crossing; it skips its deorbit setup and retains all restrictions.
                                        recovery_set_isolated("rapier",false).
                                        recovery_set_isolated("nerv",false).
                                        togglerapiermode("AIR").
                                        rapierson().
                                        nervsoff().
                                        recovery_apply_limits().
                                        set abort_state["handoff_ready"] to true.
                                        set abort_state["handoff_phase"] to "reentry_low".
                                        recovery_phase(abort_state,"entry_handoff").
                                    } else {
                                        recovery_transition(abort_state,"contingency_abort","edr_no_reachable_runway").
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        // END EDR STEP
        // BEGIN ABORT HANDOFF
        set Lastest_status to abort_state["mode"]+": "+abort_state["phase"].
        if abort_state["active"] and abort_state:haskey("handoff_ready") and abort_state["handoff_ready"] {
            set abort_state["handoff"]["started"] to true.
            set abort_state["display_handoff_position"] to ship:geoposition.
            set abort_state["display_handoff_ut"] to time:seconds.
            local handoff_context is lex("mission","abort","abort_mode",abort_state["mode"],
                "preserve_propulsion",true,"allow_go_around",true,"initial_phase",abort_state["handoff_phase"]).
            if abort_state:haskey("capture_interface") {
                set handoff_context["capture_interface"] to abort_state["capture_interface"].
            }
            flight_log_event("recovery_handoff","mode="+abort_state["mode"]+
                "|phase="+abort_state["handoff_phase"]+"|runway="+abort_state["target"]["location"]+
                "_"+abort_state["target"]["runway_num"]).
            update_assent_gui().
            runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks",lex("force",true,
                "Location",abort_state["target"]["location"],"Runway",abort_state["target"]["runway_num"],
                "context",handoff_context)).
            set abort_state["handoff"]["complete"] to true.
            recovery_finish(abort_state,recovery_result["reason"],recovery_result["success"],
                not recovery_result["success"]).
        }
        if not abort_state["active"] and abort_state["result"]["success"] and
            abort_state["mode"] = "ato" and abort_state:haskey("nominal_insertion") {
            set ascent_orbit_complete to true.
        }
        // END MANAGED ABORT TICK
    }
    if step = "contingency_abort"{
        set abort_state to abort_refresh_state(abort_state).
        contingency_update(abort_state).
        set Lastest_status to "Contingency: " + abort_state["phase"].
        if not abort_state["active"] {
            set Lastest_status to "Contingency: " + abort_state["result"]["reason"].
            set step to "end".
        }
    }
    if step = "end"{
        set running to false.
        //set Lastest_status to "ending".
        if abort_state:haskey("managed") and abort_state["managed"] or
           (abort_state:haskey("mode") and abort_state["mode"] = "contingency_abort") {
            // The contingency executive already secured or released controls.
            // reset_sys would re-enable engines/gear and overwrite pilot throttle.
        } else { reset_sys(). }
        // Preserve the failed-spool ground hold after generic system cleanup.
        if takeoff_spool["status"] = "timeout" { brakes on. }
        set warp to 0.
        update_readouts().
        update_assent_gui().
        flight_log_ascent_display_observe(ascent_display_data,ascent_display_log).
    }
    if t0 >= 0 and not takeoff_evidence["screen_reached"] {
        flight_log_takeoff_observe(takeoff_evidence,takeoff_estimate,takeoff_start_position,t0,step).
    }
    flight_log_tick("ascent",step,"").
    wait 0.
    //check_abort().
}
flight_log_event("ascent_inclination_result","orbit_complete="+ascent_orbit_complete+
    "|target_inclination="+TargetInclination+"|inclination="+ship:orbit:inclination+
    "|inclination_error="+abs(ship:orbit:inclination-TargetInclination)).
if ascent_rendezvous_enabled and ascent_orbit_complete {
    set Lastest_status to "Refining rendezvous for docking handoff".
    local ascent_rendezvous_result is rendezvous_same_body(ascent_rendezvous_target).
    if not ascent_rendezvous_result["docking_ready"] {
        set Lastest_status to "Rendezvous needs refinement: "+ascent_rendezvous_result["reason"].
    }
}
} // Valid inclination preflight and guidance.
