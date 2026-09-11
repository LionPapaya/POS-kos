// Poseidon_SSTO/Poseidon_SSTO_Reentry.ks
// Purpose: main reentry orchestration script.
// - Invokes libraries and GUI, calculates deorbit nodes and entry guidance.
// - Coordinates `dap` and entry solver to guide the vehicle to a chosen runway.
set CONFIG:IPU to 2000.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/entry_guid.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/entry_recovery.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_location_constants.ks").
RUNONCEPATH("0:/Libraries/lib_aerosim.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/terminal_route.ks").

parameter force_tgt is lex("force",false,"Location","","Runway","").
if not SHIP:BODY:atm:exists {
    // Airless operations are intentionally not an alternate branch of entry
    // guidance.  The dedicated program owns its NERV-only deorbit, powered
    // descent, coordinate target, and tail-to-gear touchdown sequence.
    clearScreen.
    print "Reentry requires an atmosphere.".
    print "For an airless body run 0:/Poseidon_SSTO/Poseidon_SSTO_Vacuum_Landing.ks.".
} else if BODY:name <> "Kerbin" or not addons:available("FAR") {
    print "POS3 requires Poseidon on Kerbin with FAR.".
}else{
flight_log_begin("reentry").
if not(defined recovery_result) {
    global recovery_result is lex("complete",false,"success",false,"reason","running").
}else{
    set recovery_result to lex("complete",false,"success",false,"reason","running").
}
//if ship:periapsis >= BODY:atm:height{
if not(force_tgt["force"]){
    setup_reentry_script().
}ELSE{
    setup_reentry_script(force_tgt["Location"],force_tgt["Runway"]).
}
//}
// Reset every persistent entry/terminal value, including when launched from
// POS again after a skip or a previous landing on the same kOS processor.
set aerobrake_active to false.
set entry_flight_active to false.
entry_reset_plan().
set entry_retarget_count to 0.
set entry_attempted_targets to list(Location+"_"+runway_nr).
set Team_interface to define_TEAM_interface(runway_start,runway_heading,runway_altitude).
set reentry_target to Team_interface["target_latlng"].
set entry_original_target to reentry_target.
set entry_has_entered to false.
set entry_exit_since to -1.
set deorbit_search_start to time:seconds.
if defined terminal_route { unset terminal_route. }
if defined terminal_route_debug { unset terminal_route_debug. }
set terminal_route_runway_change_request to "".
flight_log_set_entry_target(Team_interface).
set deorbit_periapsis_set_flag to false.
dap:setup().
set console_mode to "DATA".
until running = false{
    update_readouts().
    local e_gui_inputs is lex(
        "mode", console_mode,
        "alt", ship:altitude,
        "spd", ship:airspeed,
        "guid_spd", 0,
        "guid_alt", 0,
        "guid_pos", 0,
        "guid_pos_valid", false,
        "pitch", pitch_for(),
        "yaw", compass_for(),
        "roll", roll_for(),
        "mach", ADDONS:FAR:mach,
        "aoa", calc_aoa(),
        "l/d", 0
    ).
    if not(ADDONS:FAR:AEROFORCE = V(0,0,0)) and ship:altitude < body:atm:height + 10{
        local c_a_id is cur_aeroforce_ld().
        set e_gui_inputs["l/d"] to c_a_id["lift"]/max(0.001,c_a_id["drag"]).
    }

    //if not (step = "Deorbit") and ship:altitude <70000{
    //    logTelemetry().
    //}
    if step = "Deorbit"{
        if substep = "findStep"{

            if ship:periapsis < BODY:atm:height{
                set step to entry_regime().
            }
            if ship:orbit:hasnextpatch and ship:orbit:eta:transition < ship:orbit:eta:periapsis {
                set step to "end".
                set Lastest_status to "SOI transition before entry: start POS3 on the inbound Kerbin patch".
            }
            if step = "Deorbit" and ship:orbit:eccentricity >= 1 {
                set step to "end".
                set Lastest_status to "Hyperbolic approach misses atmosphere: set approach periapsis first".
            }
            if step = "Deorbit" and not Addons:TR:Available{
                set step to "end".
                set Lastest_status to "TR Addon not installed".

            }
            set substep to "deorbit_manuver".

        }
        set console_mode to "DATA".
        if step = "Deorbit" and substep = "deorbit_manuver"{
        if ship:periapsis >= BODY:atm:height{
            if deorbit_periapsis_set_flag = false{
                if ship:apoapsis < 100000{
                    set deorbit_periapsis to -10000.
                }else if ship:apoapsis < 200000{
                    set deorbit_periapsis to 10000.
                }else if ship:apoapsis < 500000{
                    set deorbit_periapsis to 12000.
                }else if ship:apoapsis < 1000000{
                    set deorbit_periapsis to 15000.
                }else if ship:apoapsis < 10000000{
                    set deorbit_periapsis to 18000.
                }else{
                    set deorbit_periapsis to 20000.
                }
                set deorbit_periapsis_set_flag to true.
            }

                if deorbit_start = false{
                    set deorbit to node(time+400, 0, 0, 0).
                    add deorbit.
                    set deorbit_start to true.
                }
                 if deorbit:orbit:periapsis < deorbit_periapsis and deorbit_calc = false{
                    if  deorbit:orbit:periapsis + 10000 < deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde + 1.
                    }
                    if deorbit:orbit:periapsis + 1000 < deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde + 0.1.
                    }
                    if deorbit:orbit:periapsis + 100 < deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde + 0.01.
                    }
                }
                if deorbit:orbit:periapsis > deorbit_periapsis and deorbit_calc = false{
                    if  deorbit:orbit:periapsis - 10000 > deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde - 1.
                    }
                    if deorbit:orbit:periapsis - 1000 > deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde - 0.1.
                    }
                    if deorbit:orbit:periapsis - 100 > deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde - 0.01.
                    }
                }
                if deorbit:orbit:periapsis + 1000 > deorbit_periapsis and deorbit:orbit:periapsis - 1000 < deorbit_periapsis and deorbit_calc = false and NOT(addons:TR:hasimpact){
                    SET deorbit_periapsis TO deorbit_periapsis - 1000.
                }

                if Reentry_mode = "auto" or Reentry_mode = "EX"{


                if deorbit:orbit:periapsis + 1000 > deorbit_periapsis and deorbit:orbit:periapsis - 1000 < deorbit_periapsis and deorbit_calc = false and addons:TR:hasimpact {
                local impact_point is ADDONS:TR:impactpos.
                local runway_point is runway_start.


                local distance_to_runway is calcdistance(impact_point, runway_point).  // In kilometers


                if distance_to_runway > 50 {
                    set deorbit:time to deorbit:time + 1.
                } else if distance_to_runway <= 50{
                    set deorbit:time to deorbit:time + 0.1.
                }




            set lng_difference to abs(ADDONS:TR:impactpos:LNG - runway_start:LNG).
            }
                            }
            // If we're close enough to the runway
            if addons:TR:hasimpact{
                if calcdistance(ADDONS:TR:impactpos, runway_start) <= 10.5 and addons:TR:hasimpact{
                    set deorbit_calc to true.
                   set Lastest_status to "deorbit maneuver calculated successfully".

                   // Fine-tune the normal direction based on the latitude difference
                   if round(ADDONS:TR:impactpos:LAT) < round(runway_start:LAT) {
                      set deorbit:normal to deorbit:normal + 10.
                 }
                    if round(ADDONS:TR:impactpos:LAT) > round(runway_start:LAT) {
                        set deorbit:normal to deorbit:normal - 10.
             }
    }
    }               if deorbit_calc = true{
                    nervson().
                    rapiersoff().
                    set nd to deorbit.
                    clearVecDraws().
                    execute_node().

                    set step to entry_regime().

                }
                }
                }
        }
    if step = "Deorbit" and time:seconds-deorbit_search_start > 240 {
        set Lastest_status to "Deorbit search timed out: revise the approach".
        if deorbit_start and not deorbit_calc { remove deorbit. }
        set step to "end".
    }
    if step = "reentry_low" or step = "reentry_mid" or step = "reentry_high" or step = "reentry_int" {
        set entry_flight_active to true.
        set dap["dap_mode"] to "auto".
        set dap["str_mode"] to "aoa".
        set dapthrottle to 0.
        // Prepare entry attitude before the interface and on a late start.
        nervsoff(). rapiersoff(). brakes off. gear off. rcs on.
        set dap["aoa"]["target_aoa"] to entry_command_aoa(ship:altitude,ship:airspeed).
        if ship:altitude < BODY:atm:height { set entry_has_entered to true. }
        local metrics is atmospheric_metrics(-BODY:position,ship:velocity:orbit,ship:velocity:surface,
            ADDONS:FAR:AEROFORCE/max(0.001,ship:mass),ship:q*constant:atmtokpa,BODY:mu,BODY:radius).
        local reference is entry_update_plan(metrics).
        // A synchronous solve can span real physics ticks. Refresh protection
        // inputs before issuing the next actual bank command.
        set metrics to atmospheric_metrics(-BODY:position,ship:velocity:orbit,ship:velocity:surface,
            ADDONS:FAR:AEROFORCE/max(0.001,ship:mass),ship:q*constant:atmtokpa,BODY:mu,BODY:radius).
        local heading_error is entry_heading_error(heading_to_target(Team_interface["target_latlng"])-compass_for_prograde()).
        local bank_out is min(30,abs(heading_error)*0.5).
        if heading_error > AVES["EG_rev°"] { set entry_turnside to "right". }
        if heading_error < -AVES["EG_rev°"] { set entry_turnside to "left". }
        local guidance_reason is "basic_guidance".
        if reference["valid"] {
            local s_step is reference["state"].
            local e_ref is calculate_spacecraft_energy(s_step["altitude"],s_step["surfvel"]:mag,2.5,0.9).
            local e_actual is calculate_spacecraft_energy(ship:altitude,ship:airspeed,2.5,0.9).
            set alpha_md_pid:setpoint to e_ref.
            set bank_out to invert_in_range(alpha_md_pid:update(time:seconds,e_actual),alpha_md_pid:minoutput,alpha_md_pid:maxoutput).
            set e_gui_inputs["guid_alt"] to s_step["altitude"].
            set e_gui_inputs["guid_spd"] to s_step["surfvel"]:mag.
            set e_gui_inputs["guid_pos"] to s_step["latlong"].
            set e_gui_inputs["guid_pos_valid"] to true.
            set guidance_reason to "planned".
            flight_log_capture_entry_guidance(s_step,e_ref,e_actual,(e_ref-e_actual)/max(1,abs(e_ref)),heading_error,
                bank_out,max(0,(ship:altitude-Team_interface["target_altitude"])/max(1,-ship:verticalspeed)),entry_turnside,e_gui_inputs["l/d"]).
        }
        local load_reason is atmospheric_load_reason(metrics).
        if load_reason <> "normal" or ship:verticalspeed < -500 {
            // Preserve lift for high-energy pullout; do not chase crossrange
            // while the measured load/heat corridor is exceeded.
            set bank_out to 0.
            set guidance_reason to load_reason.
            if load_reason = "normal" { set guidance_reason to "steep_entry". }
        }
        if ship:altitude+min(0,ship:verticalspeed)*15 < Team_interface["target_altitude"] and ship:airspeed > 1500 {
            set bank_out to 0. set guidance_reason to "low_altitude_high_energy".
        }
        set bank_out to max(0,min(AVES["Entry"]["max_bank"],bank_out)).
        set dap["aoa"]["target_bank"] to bank_out.
        if entry_turnside = "right" { set dap["aoa"]["target_bank"] to -bank_out. }
        set Lastest_status to "Entry: "+guidance_reason+" -> "+Location+" "+runway_nr.
        set console_mode to "TRAJ 1 high".
        if step = "reentry_low" { set console_mode to "TRAJ 1 low". }
        if step = "reentry_mid" { set console_mode to "TRAJ 1 mid". }
        if step = "reentry_int" { set console_mode to "TRAJ 1 int". }
        if ship:altitude < 30000 { set console_mode to "TRAJ 2". }
        local plan_age is 0.
        if entry_traj:haskey("solve_ut") { set plan_age to time:seconds-entry_traj["solve_ut"]. }
        // A high entry may skip back out. A clear outbound interface crossing
        // returns control in space; it does not fabricate a landing success.
        if entry_has_entered and ship:altitude > BODY:atm:height+2000 and ship:verticalspeed > 0 {
            if entry_exit_since < 0 { set entry_exit_since to time:seconds. }
            if time:seconds-entry_exit_since > 3 {
                set recovery_result to lex("complete",true,"success",false,"reason","entry_skipped_to_space").
                set Lastest_status to "Entry skipped to space; coasting".
                set step to "end".
                flight_log_event("entry_skip_exit","eccentricity="+ship:orbit:eccentricity+"|apoapsis="+ship:apoapsis).
            }
        } else { set entry_exit_since to -1. }
        flight_log_capture_atmosphere("entry",metrics,0,false,guidance_reason,reference["valid"],plan_age,entry_retarget_count,step = "end").
        if ship:altitude <= Team_interface["target_altitude"] and ship:airspeed < 1500 {
            // A runway or screened land target still needs a plausible local
            // terminal range. Never command a terminal route to a remote site.
            local terminal_range is max(30000,calculate_distance_from_alt(ship:altitude,runway_altitude)*1.5).
            if calcdistance_m(ship:geoposition,runway_start) > terminal_range {
                set recovery_result to lex("complete",true,"success",false,"reason","no_reachable_terminal_area").
                set Lastest_status to "No reachable terminal area: take control".
                set step to "end".
            } else {
                set entry_flight_active to false.
                reset_sys(). set step to "TEAM". set Lastest_status to "TEAM: "+Location.
                rcs on. clearVecDraws().
                set dap["aoa"]["target_bank"] to 0.
            }
        }
    }
    if step = "TEAM"{
        if not(defined terminal_route){
            set terminal_route to terminal_route_init().
            clearVecDraws().
        }
        if terminal_route_runway_change_request <> "" {
            local requested_runway is terminal_route_runway_change_request.
            set terminal_route_runway_change_request to "".
            if terminal_route_runway_change_allowed(terminal_route) {
                local runway_change is terminal_route_change_runway(requested_runway).
                set Lastest_status to runway_change["message"].
                if runway_change["success"] {
                    // Recreate every waypoint and energy target for the new
                    // threshold before terminal guidance resumes.
                    set terminal_route to terminal_route_init().
                }
            }else{
                set Lastest_status to "Runway change locked: terminal approach is committed".
            }
        }
        set terminal_route to terminal_route_update(terminal_route).
        terminal_route_fly(terminal_route).
        update_team_dap_gui().
        update_terminal_route_gui().
        if ship:altitude > 22000{
            rcs on.
        }
        if terminal_route["gear"]{
            gear on.
        }else{
            gear off.
        }
        if terminal_route["airbrake"]{
            brakes on.
        }else{
            brakes off.
        }

        if terminal_route["phase"] = "final" or terminal_route["phase"] = "base"{
            abort_set_fuel_dump(ship:mass > AVES["TerminalRoute"]["max_landing_mass"]).
        }

        if terminal_route["landing_ready"]{
            // LandingGate has already been stable for its configured time.
            // Make one final LOC/GS/approach check here, without another timer.
            local landing_commit is terminal_route_landing_commit_check(terminal_route).
            if landing_commit["stable"] {
                if defined abort_state and abort_state:haskey("active") and abort_state["active"] { abort_set_fuel_dump(false). }
                abort_set_fuel_dump(false).
                set step to "landing".
                set dap["str_mode"] to "aerostr".
            }else{
                set terminal_route["go_around_count"] to terminal_route["go_around_count"] + 1.
                set terminal_route["go_around_reason"] to "landing_commit_unstable".
                terminal_route_change_phase(terminal_route,"go_around").
                set Lastest_status to "Go around: landing commit unstable (GS error " + round(landing_commit["glideslope_error"],1) + "m)".
            }
        }
    }


     if step = "landing"{
        set alt_ovr_runway to ship:altitude - runway_altitude.
        local landing_config is AVES["Landing"].
        set dapthrottle to 0.
        gear on.
        update_team_dap_gui().
        // The final flare deliberately remains a descent.  Interpolating the
        // desired sink rate by height produces a smooth flare without holding
        // the craft level over the runway.
        local desired_vs is landing_config["approach_vertical_speed"].
        if alt_ovr_runway < landing_config["flare_start_altitude"] {
            local flare_fraction is max(0,min(1,
                (landing_config["flare_start_altitude"] - alt_ovr_runway) /
                max(landing_config["flare_start_altitude"] - landing_config["touchdown_altitude"],1)
            )).
            set desired_vs to landing_config["approach_vertical_speed"] +
                (landing_config["touchdown_vertical_speed"] - landing_config["approach_vertical_speed"]) * flare_fraction.
        }

        // Keep aerostr control for final alignment.  Drive turn_pitch directly
        // so the flare has pitch authority without using distance_pitch.
        local flare_pitch is max(landing_config["minimum_turn_pitch"],min(
            landing_config["maximum_turn_pitch"],
            (desired_vs - ship:verticalspeed) * landing_config["pitch_gain"]
        )).
        set dap["str_mode"] to "aerostr".
        set dap["aerostr"]["turn_pitch"] to flare_pitch.
        set dap["aerostr"]["distance_pitch"] to 0.
        set dap["aerostr"]["turn_roll"] to 0.
        set dap["aerostr"]["turn_heading"] to heading_to_target(runway_end).

        // Use airbrakes and wheel brakes whenever the craft is faster than
        // the desired touchdown speed.  Keep wheel brakes on at touchdown so
        // rollout continues to decelerate on short runways.
        if ship:airspeed > landing_config["target_touchdown_speed"] {
            brakes on.
            log_status("Brakes ON, above target touchdown speed").
        } else if alt_ovr_runway > landing_config["wheel_brake_altitude"] {
            brakes off.
        }ELSE{
            brakes on.
            log_status("Wheel brakes ON").
        }
        if ship:airspeed < 5 {

            log_status("Landing completed").
        }
        if ship:airspeed < 1 {
            set recovery_result to lex("complete",true,"success",true,"reason","landing_complete").
            set step to "end".
            log_status("Landing completed, switching to end phase").
        }
    }
    if step = "end" {
        if not recovery_result["complete"] {
            set recovery_result to lex("complete",true,"success",false,"reason","recovery_ended_before_landing").
        }
        set running to false.
        set entry_flight_active to false.
        set dapthrottle to 0.
        set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.
        nervsoff(). rapiersoff().
        set dap["dap_mode"] to "off". dap:set_off().
        set warp to 0.
        update_readouts().
        log_status("Script ended, system reset").
        clearGuis().
    }
    if running {
        dap:update().
        if entry_flight_active { lock throttle to 0. }
    }
    update_readouts().
    update_reentry_gui(e_gui_inputs).
    flight_log_tick("reentry",step,substep).
    wait 0.
}
set entry_flight_active to false.
set dapthrottle to 0.
nervsoff(). rapiersoff().
set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.
set dap["dap_mode"] to "off". dap:set_off().
}
