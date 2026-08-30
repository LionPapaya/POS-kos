
// Poseidon_SSTO/Poseidon_SSTO_Orbit_Main.ks
// Purpose: ascent and orbital insertion script for Poseidon SSTO.
// - Loads the Poseidon libraries and runs the aircraft-style ascent/circularization flow.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_aerosim.ks").
RUNONCEPATH("0:/Libraries/lib_location_constants.ks").

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


local Target_orbit is create_assent_gui().
set TargetPeriapsis to Target_orbit["Periapsis"].
set TargetApoapsis to Target_orbit["Apoapsis"].
set TargetInclination to Target_orbit["inclination"].
if POS_LOGGING_ENABLED { log("targetperiapsis: "+TargetPeriapsis) to (log.txt). }
if POS_LOGGING_ENABLED { log("targetapoapsis: "+Targetapoapsis) to (log.txt). }
if POS_LOGGING_ENABLED { log("targetInclination: "+TargetInclination) to (log.txt). }

check_inputs().

reset_sys().
dap:setup().
print("1").
if POS_LOGGING_ENABLED { log location_constants to "log_location_constants.txt". }
local active_runway is find_active_runway().
print("2").
if POS_LOGGING_ENABLED { log(active_runway) to "log_runway.txt". }
if active_runway["heading"] >= 0 {
    set runway_heading to active_runway["heading"].
}
if active_runway["altitude"] >= 0 {
    set runway_altitude to active_runway["altitude"].
    set liftoff_altitude to runway_altitude + ascent["liftoff_height_above_runway"].
    set rotate_altitude to runway_altitude + ascent["rotate_height_above_runway"].
}
set dap["aerostr"]["turn_heading"] to runway_heading.
set launch_heading to calculate_heading(TargetInclination, ship:latitude).
if launch_heading < 0 {
    set launch_heading to ascent["inclination_heading_fallback"].
}
set previous_speed to ship:airspeed.
set t0 to -1.
local takeoff_start_position is ship:geoposition.
local abort_info is lex().
global abort_state is lex("active",false).
set dap_mode to "auto".
set dap["str_mode"] to "aerostr".
print("3").
rapierson().
until running = false{
    update_readouts().
    dap:update().
    update_assent_gui().

    if ship:altitude < ascent["display_altitude"] and ship:airspeed < ascent["display_speed"]{
        set console_mode to "assent".
    }else{
         set console_mode to "Data".
    }
    set speed_trend to ship:airspeed - previous_speed.
    set previous_speed to ship:airspeed.

    if step = "launch"{ 
        update_team_dap_gui().
         
        if ship:altitude < liftoff_altitude{
            set dap["aerostr"]["targetPitch"] to 0.
            set dap["aerostr"]["turn_heading"] to runway_heading.
            
            set dapthrottle to 1.
        }   
        if ship:thrust > AVES["StationaryThrottle"]{
            brakes off.
            if t0 = -1{
                set t0 to time:seconds.
                set takeoff_start_position to ship:geoposition.
            }
        }

        // Once the brakes have released, keep monitoring engine health even
        // if an engine loss pulls total thrust back below StationaryThrottle.
        // The threshold is an arming condition, not an abort-monitor gate.
        if t0 <> -1 {
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
                        if POS_LOGGING_ENABLED {
                            log "Runway abort rejected: rolled=" + round(runway_abort_check["roll_distance_m"]) +
                                "m, need=" + round(runway_abort_check["required_stop_distance_m"]) +
                                "m, remaining=" + round(runway_abort_check["runway_remaining_m"]) + "m" to "0:/log_abort.txt".
                        }
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
            if runway_to_ascent_error > ascent["runway_alignment_heading_threshold"] {
                set step to "ascent_alignment".
                set Lastest_status to "aligning ascent heading".
                set dap["str_mode"] to "aoa".
            }else{
                set step to "speed_build".
                set dap["str_mode"] to "aerostr".
            }
        }
    }
    if step = "ascent_alignment"{
        update_team_dap_gui().
        set assent_heading to calculate_heading(TargetInclination, ship:latitude).
        if assent_heading < 0 {
            set assent_heading to ascent["inclination_heading_fallback"].
        }

        // AoA steering turns through bank.  A positive heading error is a turn
        // to the right, which uses a negative bank in the kOS steering convention.
        local alignment_heading_error is normalized_heading_error(assent_heading,compass_for_prograde()).
        local alignment_bank is min(ascent["runway_alignment_bank"],max(10,abs(alignment_heading_error) * 2)).
        set dap["str_mode"] to "aoa".
        set dap["aoa"]["target_aoa"] to ascent["runway_alignment_target_aoa"].
        if alignment_heading_error > 0 {
            set dap["aoa"]["target_bank"] to -alignment_bank.
        }else{
            set dap["aoa"]["target_bank"] to alignment_bank.
        }

        // Do not build speed while making the initial cross-runway turn.
        // Ramp from full to idle between 200 and 300 m/s, rather than
        // abruptly cutting thrust, to hold the turn below the speed limit.
        local throttle_ramp_width is ascent["runway_alignment_speed_limit"] - ascent["runway_alignment_throttle_ramp_start"].
        set dapthrottle to max(0,min(1,(ascent["runway_alignment_speed_limit"] - ship:airspeed) / throttle_ramp_width)).

        set abort_info to check_abort(step).
        if abort_info["abort"]{
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        }
        if step = "ascent_alignment" and abs(alignment_heading_error) <= ascent["runway_alignment_completion_tolerance"] {
            set dap["aoa"]["target_bank"] to 0.
            set dapthrottle to 1.
            set dap["str_mode"] to "aerostr".
            set step to "speed_build".
            set Lastest_status to "ascent heading aligned".
        }
    }
    if step = "speed_build"{
        update_team_dap_gui().
        set assent_heading to calculate_heading(TargetInclination, ship:latitude).  
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
        set assent_heading to calculate_heading(TargetInclination, ship:latitude).  
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
        // log as much as possible to a file for analysis
        if POS_LOGGING_ENABLED { log ("climb_time: "+climb_time+" speed_time: "+speed_time + " altitude: " + ship:altitude + " airspeed: " + ship:airspeed + " verticalspeed: " + ship:verticalspeed + " accel_in_prograde: " + accel_in_prograde + " pfp_tgt: " + pfp_tgt) to "climb_log.txt". }

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
        }
        set dap["str_mode"] to "aerostr".
        set assent_heading to calculate_heading(TargetInclination, ship:latitude).  
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
    if step = "closed_cycle_climb"{
            set abort_info to check_abort(step).
            if abort_info["abort"] {
                set abort_state to create_abort_state(abort_info,step,active_runway).
                set step to abort_state["mode"].
            }
            togglerapiermode("CLOSED").
            update_team_dap_gui().
            set Lastest_status to "rapiers in closed cycle".
            set dap["str_mode"] to "aerostr".
            set assent_heading to calculate_heading(TargetInclination, ship:latitude).  
            set dap["aerostr"]["turn_heading"] to assent_heading.
            if dap["aerostr"]["turn_pitch"] < ascent["closed_cycle_pitch_max"]{
                set dap["aerostr"]["turn_pitch"] to dap["aerostr"]["turn_pitch"] + ascent["closed_cycle_pitch_rate"].
            }else{
                set warp to 1.
            }
            rcs on.
            if step = "closed_cycle_climb" and ship:apoapsis > ascent["rapier_cutoff_apoapsis"] {
                rapiersoff().
                set dap["aerostr"]["turn_pitch"] to ascent["apoapsis_build_pitch"].
                set step to "apoapsis_build".
                set Lastest_status to "nerv apoapsis build".
            }
    }
    if step = "apoapsis_build"{
        update_team_dap_gui().
        set abort_info to check_abort(step).
        if abort_info["abort"] {
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        }
        set dap["str_mode"] to "aerostr".
        set dap["aerostr"]["turn_heading"] to assent_heading.
        set assent_heading to calculate_heading(TargetInclination, ship:latitude).  
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
    if ship:altitude > ascent["space_altitude"] and (step = "apoapsis_build" or step = "closed_cycle_climb"){
            lock dap_steering to prograde.
            set Lastest_status to "Space".
            ag5 on.
    }
    
    if step = "circ"{
        if circ_done = false{
            set circ to node( time+eta:apoapsis, 0, 0, 0).
            add circ.
            set circ_done to true.
        }    
        if circ:orbit:periapsis < TargetPeriapsis and orbitcalc = false{
            if  circ:orbit:periapsis + 10000 < TargetPeriapsis{
                set circ:prograde to circ:prograde + 10.
            }
            if circ:orbit:periapsis + 1000 < TargetPeriapsis{
                set circ:prograde to circ:prograde + 1.
            }
            if circ:orbit:periapsis + 100 < TargetPeriapsis{
                set circ:prograde to circ:prograde + 0.1.
            }
        }
        if circ:orbit:periapsis > TargetPeriapsis and orbitcalc = false{
            if  circ:orbit:periapsis - 10000 > TargetPeriapsis{
                set circ:prograde to circ:prograde - 10.
            }
            if circ:orbit:periapsis - 1000 > TargetPeriapsis{
                set circ:prograde to circ:prograde - 1.
            }
            if circ:orbit:periapsis - 100 > TargetPeriapsis{
                set circ:prograde to circ:prograde - 0.1.
            }
        }
        if circ:orbit:periapsis + 500 > TargetPeriapsis and  circ:orbit:periapsis - 500 < TargetPeriapsis and orbitcalc = false{
            set orbitcalc to true.
            set Lastest_status to "manuver calculated succesfully".
            
        }
        if orbitcalc = true{
            nervson().
            rapiersoff().
            execute_node().
            set step to "end".
        }
        
        

    }
    if step = "runway_abort"{
        set abort_state to abort_refresh_state(abort_state).
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
    }if step = "rtls"{
        set abort_state to abort_refresh_state(abort_state).
        if not(defined rtls_handoff_time){
            set rtls_handoff_time to 0.
        }
        if abort_state["mode"] = "contingency_abort" {
            set step to "contingency_abort".
        }else{
            local rtls_config is AVES["Abort"]["RTLS"].
            local rtls_policy is rtls_config[abort_state["submode"]].
            set abort_state["policy"] to lex(
                "use_nervs",rtls_policy["use_nervs"],"fuel_dump",rtls_policy["fuel_dump"],
                "target_mass",rtls_policy["target_mass"],"turn_bank",rtls_config["turn_bank"]
            ).
            if abort_state["phase"] = "initialize" {
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
                    set step to "end".
                }    
            }
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
                local atr_policy is AVES["Abort"]["RTLS"][abort_state["submode"]].
                set abort_state["policy"] to lex(
                    "use_nervs",atr_policy["use_nervs"],"fuel_dump",atr_policy["fuel_dump"],
                    "target_mass",atr_policy["target_mass"],"turn_bank",0
                ).
                abort_set_fuel_dump(abort_state["policy"]["fuel_dump"] and ship:mass > abort_state["policy"]["target_mass"]).
                set Lastest_status to "ATR " + abort_state["submode"] + " to " + abort_state["target"]["location"] + " " + abort_state["target"]["runway_num"].
                set abort_state["handoff"]["started"] to true.
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
    if step = "ati"{
        set Lastest_status to "ati".
        set warp to 0.
        RUN "0:/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks"(lex("force",TRUE,"Location","Kola-Island","Runway","20")).
        SET step to "end".
    }
    if step = "contingency_abort"{
        abort_set_fuel_dump(false).
        set Lastest_status to "4RO contingency abort detected - mode not implemented".
        set abort_state["result"]["success"] to false.
        set abort_state["result"]["reason"] to "4RO_unimplemented".
    }
    if step = "end"{
        set running to false.
        //set Lastest_status to "ending".
        reset_sys().
        set warp to 0.
        update_readouts().
        assent_gui:hide().
    }
    wait 0.
    //check_abort().
}
