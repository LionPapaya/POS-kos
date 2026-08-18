
// Poseidon_SSTO/Poseidon_SSTO_Orbit_Main.ks
// Purpose: ascent and orbital insertion script for Poseidon SSTO.
// - Loads the Poseidon libraries and runs the aircraft-style ascent/circularization flow.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
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
log("targetperiapsis: "+TargetPeriapsis) to (log.txt).
log("targetapoapsis: "+Targetapoapsis) to (log.txt).
log("targetInclination: "+TargetInclination) to (log.txt).

check_inputs().

reset_sys().
dap:setup().
print("1").
log location_constants to "log_location_constants.txt".
local active_runway is find_active_runway().
print("2").
log(active_runway) to "log_runway.txt".
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
set dap_mode to "auto".
set dap["str_mode"] to "aerostr".
print("3").
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
            rapierson().
            set dapthrottle to 1.
        }   
        if ship:thrust > AVES["StationaryThrottle"]{
            brakes off.
            if t0 = -1{
                set t0 to time:seconds.
            }
                
                
                if ship:airspeed > AVES["Speed"]["Rotate"]{
                    
                    set step to "rotate".
                    set Lastest_status to "rotating".
                    Set warpmode to "physics".
                    
                }
            //decide_abort_mode().
        }

        
    if ship:altitude > liftoff_altitude and ship:airspeed <= AVES["Speed"]["Rotate"]{
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
        if ship:altitude > rotate_altitude{
            gear off.
            set step to "speed_build".
            set warp to 0.
            set dap["str_mode"] to "aerostr".
            set assent_heading to launch_heading.
        }
    }
    if step = "speed_build"{
        update_team_dap_gui().
        
        set dap["aerostr"]["turn_heading"] to assent_heading.
        set dap["aerostr"]["targetPitch"] to ascent["shallow_climb_pitch"].
        set dap["aerostr"]["turn_pitch"] to ascent["shallow_climb_pitch"].
        if ship:airspeed >= ascent["speed_build_target"] or ship:altitude >= ascent["climb_altitude"] {
            set step to "high_altitude_climb".
            set Lastest_status to "speed target reached".
        }
    }
    if step = "high_altitude_climb"{
        update_team_dap_gui().
        set dap["str_mode"] to "aerostr".
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
        log ("climb_time: "+climb_time+" speed_time: "+speed_time + " altitude: " + ship:altitude + " airspeed: " + ship:airspeed + " verticalspeed: " + ship:verticalspeed + " accel_in_prograde: " + accel_in_prograde + " pfp_tgt: " + pfp_tgt) to "climb_log.txt".

        if ship:altitude >= ascent["climb_altitude"] {
            nervson().
            set step to "nerv_assist".
            set Lastest_status to "nervs on".
        }
    }
    if step = "nerv_assist"{
        set dap["str_mode"] to "aerostr".
        set dap["aerostr"]["turn_heading"] to assent_heading.
        set dap["aerostr"]["turn_pitch"] to ascent["nerv_pitch"].
        if ship:verticalspeed <= ascent["vertical_speed_recovery_threshold"] {
            set dap["aerostr"]["turn_pitch"] to ascent["nerv_pitch"] + ascent["vertical_speed_recovery_pitch"].
        }
        if speed_trend <= ascent["speed_gain_threshold"] and ship:altitude >= ascent["closed_cycle_min_altitude"] {
            set step to "closed_cycle_climb".
            set Lastest_status to "transitioning to closed cycle".
        }
    }
    if step = "closed_cycle_climb"{
            
            togglerapiermode("CLOSED").
            
            set Lastest_status to "rapiers in closed cycle".
            set dap["str_mode"] to "aerostr".
            set dap["aerostr"]["turn_heading"] to assent_heading.
            if dap["aerostr"]["turn_pitch"] < ascent["closed_cycle_pitch_max"]{
                set dap["aerostr"]["turn_pitch"] to dap["aerostr"]["turn_pitch"] + ascent["closed_cycle_pitch_rate"].
            }else{
                set warp to 1.
            }
            rcs on.
            if ship:apoapsis > ascent["rapier_cutoff_apoapsis"] {
                rapiersoff().
                set dap["aerostr"]["turn_pitch"] to ascent["apoapsis_build_pitch"].
                set step to "apoapsis_build".
                set Lastest_status to "nerv apoapsis build".
            }
    }
    if step = "apoapsis_build"{
        set dap["str_mode"] to "aerostr".
        set dap["aerostr"]["turn_heading"] to assent_heading.
        set dap["aerostr"]["turn_pitch"] to ascent["apoapsis_build_pitch"].
        if ship:verticalspeed <= ascent["vertical_speed_recovery_threshold"] {
            set dap["aerostr"]["turn_pitch"] to ascent["apoapsis_build_pitch"] + ascent["vertical_speed_recovery_pitch"].
        }
        if ship:apoapsis > TargetApoapsis + ascent["apoapsis_margin"] {
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
        set Lastest_status to "Runway abort".
        brakes on.
        set dapthrottle to 0.
        rapiersoff().
        set dap["aerostr"]["targetPitch"] to -5.
        if ship:airspeed < 1{
            set Lastest_status to "abort complete".
            set step to "end".
        }    
    }
    if step = "ati"{
        set Lastest_status to "ati".
        set warp to 0.
        RUN "0:/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks"(lex("force",TRUE,"Location","Kola-Island","Runway","20")).
        SET step to "end".
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
