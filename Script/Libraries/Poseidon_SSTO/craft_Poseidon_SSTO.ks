function reset_sys{
    if ship:altitude < 1000 {
        gear on.
        brakes on.
    }   
    if ship:altitude < 50000 {
        rapierson().
        nervsoff().
        togglerapiermode("AIR").
    }  
    else{
    brakes off.
    gear off.
    }


    set dapthrottle to 0.
    if dap:haskey("envelope") {
        lock throttle to max(dapthrottle,dap["envelope"]["min_throttle"]).
    } else {
        lock throttle to dapthrottle.
    }
    if ship:periapsis > 70000 or ship:altitude > 300000{
        //ag5 on.
        nervson().
        rapiersoff().
        toggleRapierMode("AIR").
    }
    else{
        //ag5 off.
    }
    lights on.


 
    
    
}

function check_inputs{
    if TargetApoapsis < TargetPeriapsis or TargetPeriapsis < 75000 or TargetInclination < 0 or TargetInclination > 180 or TargetApoapsis > BODY:soiradius{
    set step to "end".
    set Lastest_status to "wrong setup".
    log ("apoapsis = "+TargetApoapsis+" Periapsis = "+TargetPeriapsis+" Inclination = "+TargetInclination) to log.txt.
    }
}

function goto_target{
    if not(defined reentry_target){
            set ecrl_2hac to get_geoposition_along_heading(runway_start,runway_heading+180,Aves["HacDistance"]*2).
            if calcdistance(ship:geoposition,runway_start) > calcdistance(ship:geoposition,ecrl_2hac){
                set reentry_target to runway_start.
            }else{set reentry_target to ecrl_2hac.}

        }
    local sim is current_simstate().
    
    set dap["aoa"]["target_aoa"] to AVES["EGAOA"](ship:altitude).
    local y is sim_with_bank(sim,0,0,reentry_target).
    local x is y["final_state"]["latlong"].

    set distance_between_runway_start_IMPACTPOS to calcdistance(ship:geoposition,reentry_target) - calcdistance(ship:geoposition,x).



        // Calculate the total runway distance dynamically

        // Calculate the percentage difference
        set percentage_diff to calc_percentage(distance_between_runway_start_IMPACTPOS, calcdistance(ship:geoposition,reentry_target)).

        // Calculate dynamic pitch
        // Map the percentage difference (-7% to -2%) to a pitch range (e.g., 90 to 17 degrees)
        if percentage_diff >= -7 and percentage_diff <= -2 {
            set t_bank to 70 - ((70 - 0) * abs(percentage_diff) / 7). // Linearly interpolate
        } else if percentage_diff > -2 {
            set t_bank to 0. // Default to minimal pitch above -2%
        } else {
            set t_bank to 70. // Default to max pitch below -7%
        }

        // Calculate brake state based on percentage difference
        if percentage_diff <= -10 {
            brakes on.
        } else {
            brakes off.
        }    
        local heading_error is heading_to_target(reentry_target) - compass_for_prograde().

            // Normalisiere den Fehler
        if abs(heading_error) <= 180{
            if heading_error > 180 {
                set heading_error to heading_error - 360.
            } 
            if heading_error < -180 {
                set heading_error to heading_error + 360.
            }
        }
        if not (defined entry_turnside){
            if heading_error > 0{
                set entry_turnside to "right".
            }
            if heading_error < 0{
                set entry_turnside to "left".
            }
        }
        if heading_error > AVES["EG_rev°"]{
            set entry_turnside to "right".
        }
        if heading_error < -AVES["EG_rev°"]{
            set entry_turnside to "left".
        }
        if entry_turnside = "right"{
          
            set dap["aoa"]["target_bank"] to -t_bank.
        }
        if entry_turnside = "left"{
            
           
            set dap["aoa"]["target_bank"] to t_bank.
        }
  

    
    
}


function log_status {
    parameter message.
    if ship:altitude < 70000{
    log message + " | Altitude: " + ship:altitude + "m, Airspeed: " + ship:airspeed + "m/s, inputPitch: " + dap["aerostr"]["distance_pitch"] + ", Pitch: " + pitch_for() +  ", Throttle: " + throttle + ", Glideslope(V): " + calculate_vertical_glideslope_distance()+ ",runway_start_distance(m): "+ ((calcdistance(ship:geoPosition, runway_start))*1000)to ("0:/log.txt").
}
}


function check_abort {
    local abort_info is lexicon().
    local abort_flag is false.
    local abort_scenario is "".

    // Check RAPIER engines
    local rapier_status is check_engines("rapier").
    if rapier_status["failed"] > 0 {
        set abort_flag to true.
        set abort_scenario to abort_scenario + rapier_status["failed"] + "RO, ".
    }


    // Check NERV engines
    local nerv_status is check_engines("nerv").
    if nerv_status["failed"] > 0 {
        set abort_flag to true.
        set abort_scenario to abort_scenario + nerv_status["failed"] + "NO, ".
    }



    // Populate the lexicon
    abort_info:add("abort", abort_flag).
    abort_info:add("scenario", lex("rapiers_out",rapier_status["failed"],"nervs_out",nerv_status["failed"])).
    abort_info:add("scenario_disp", abort_scenario).

    if abort_flag {
        log "Abort needed: " + abort_scenario to "0:/log.txt".
        ask_abort_mode(abort_info["scenario"]).
    }
    return abort_info.
}
function ask_abort_modes{
    parameter scenarios.
    local abort_lex is AVES["AbortModes"].



    if abort_mode = "runway_abort" {
        set step to "runway_abort".
        log "Executing runway abort." to "0:/log.txt".
 
    } else if abort_mode = "ati" {
        set step to "ati".
        log "Executing abort to island (ATI)." to "0:/log.txt".
   
    } else if abort_mode = "toa" {
        set step to "toa".
        log "Executing trans-oceanic abort (TOA)." to "0:/log.txt".
       
    } else if abort_mode = "ato" {
        set step to "ato".
        log "Executing abort to orbit (ATO)." to "0:/log.txt".
 
    } else if abort_mode = "cont" {
        set step to "cont".
        log "Executing contingency abort (CONT)." to "0:/log.txt".
  
    }
}
function check_engines {
    parameter engine_type.
    local failed_engines is 0.
    local extra_engines is 0.
    
    if ship:altitude < 21000 {
        set nerv_expected to false.
    }
    if ship:altitude < 57000 {
        set rapiers_expected to true.
    }
    
    if engine_type = "all" or engine_type = "rapier" {
        set rapier_engines to ship:partstitledpattern("R.A.P.I.E.R").
        for all_rapiers in rapier_engines {
            if not all_rapiers:ignition and rapiers_expected {
                log "RAPIER engine " + all_rapiers:name + " is not running!" to "0:/log.txt".
                set failed_engines to failed_engines + 1.
            }
        }
    }
    
    if engine_type = "all" or engine_type = "nerv" {
        set nerv_engines to ship:partstitledpattern("LV-N Atomic Rocket Motor").
        for all_nervs in nerv_engines {
            if not all_nervs:ignition and nerv_expected {
                log "NERV engine " + all_nervs:name + " is not running!" to "0:/log.txt".
                set failed_engines to failed_engines + 1.
            }
        }
    }

    local engine_status is lexicon().
    engine_status:add("failed", failed_engines).

    return engine_status.
}


// Function to log telemetry data on every call
function logTelemetry {
    set log_filename to "assentlog3.txt".  // Fixed filename for telemetry data

    // Open or append to the file to log telemetry data
    if not(defined reentry_log_header_done){    
        log("Time,Altitude,Velocity,Latitude,Longitude,VerticalSpeed,pitch") to log_filename.  // Write header if file is new
        set reentry_log_header_done to true.
    }
    
    // Collect telemetry data
    set ves_latitude to ship:geoposition:lat.     // Latitude of the ship
    set ves_longitude to ship:geoposition:lng.    // Longitude of the ship
    
    // Write telemetry data to log file
    log(
        round(missiontime, 2) + "," +
        round(ship:altitude, 2) + "," +
        round(ship:velocity:surface:mag, 2) + "," +
        round(ves_latitude, 5) + "," +
        round(ves_longitude, 5) + "," +
        round(ship:verticalspeed, 2) + "," +
        round(pitch_for())
    ) to log_filename.
}
function setup_landing_script{
    
    steeringManager:resetpids().
    set step to "Deorbit".
    set substep to "findStep".
    set running to true.
    clearScreen.  
    if maxThrust = 120{
        set nervs to true.
    } 
    else{
        set nervs to false.
    }

    set rapier_mode to "air".
    set rapiers to false.
    set Lastest_status to "Inizializing Script".
    set deorbit_start to false.
    set deorbit_calc to false.
    dap:setup().
    reset_sys().                                                                             
   
}

local Poseidon_SSTO is lex().
Poseidon_SSTO:add("Speed",Lexicon("MaxSpeed",2400,"MinSpeed",100,"Rotate",100)).
// Aircraft-style ascent profile.  Keep all Poseidon-specific ascent tuning here
// so the flight logic remains readable and can be adjusted without hunting for
// thresholds in the state machine.
Poseidon_SSTO:add("Ascent",lex(
    "liftoff_height_above_runway",13,
    "rotate_height_above_runway",18,
    "rotate_pitch",20,
    "display_altitude",70000,
    "display_speed",2100,
    "default_launch_heading",90,
    "shallow_climb_pitch",10,
    "speed_build_target",440,
    "speed_build_pitch",10,
    "climb_altitude",20000,
    "climb_target_speed",1500,
    "climb_pitch",15,
    "nerv_activation_altitude",20000,
    "minimum_climb_vertical_speed",5,
    "closed_cycle_min_altitude",23000,
    "closed_cycle_max_altitude",57000,
    "closed_cycle_pitch_start",10,
    "closed_cycle_pitch_rate",1,
    "closed_cycle_pitch_max",30,
    "rapier_cutoff_apoapsis",57000,
    "apoapsis_build_pitch",15,
    "space_altitude",70000,
    "heading_tolerance",5,
    "speed_gain_threshold",0.5,
    "vertical_speed_recovery_pitch",2,
    "vertical_speed_recovery_threshold",0,
    "apoapsis_margin",500,
    "inclination_heading_fallback",90
)).
Poseidon_SSTO:add("MaxAeroturnAlt",60000).
Poseidon_SSTO:add("MaxRoll",40).
Poseidon_SSTO:add("MaxPitch",48).
Poseidon_SSTO:add("MinPitch",-30).
Poseidon_SSTO:add("MaxYaw",40).
Poseidon_SSTO:add("Rotation_rate",lex("high",10,"low",18)).
Poseidon_SSTO:add("Pitch_rate",lex("high",4,"low",9)).
Poseidon_SSTO:add("Glideslope",lex("angle1",0.268,"angle2",0.0875,"target1",450,"switch12",700)).
Poseidon_SSTO:add("StationaryThrottle",300).
Poseidon_SSTO:add("HacDistance",10000).
Poseidon_SSTO:add("HacRadius",1500).
Poseidon_SSTO:add("ERCLSpeed",150).
Poseidon_SSTO:add("Aeroturn_Radius",20000).
Poseidon_SSTO:add("TEAM_v_margin",20).
Poseidon_SSTO:add("TEAMAltitude",25000).
Poseidon_SSTO:add("TEAM_vvdot_t",5).
Poseidon_SSTO:add("Envelope",lex(
    "low_speed",115,
    "minimum_safe_speed",110,
    "low_speed_throttle",0.65,
    "high_speed",800,
    "entry_speed",1350,
    "max_aoa_low_speed",10,
    "max_aoa_normal",30,
    "max_aoa_high_speed",25,
    "max_aoa_entry",20,
    "max_aoa_recovery",8,
    "max_bank_low_speed",25,
    "max_bank_normal",90,
    "max_bank_high_speed",120,
    "max_bank_entry",120,
    "max_bank_recovery",0,
    "rcs_error_aoa",0.75,
    "rcs_error_general",1.5,
    "rcs_pitchdown_confirm_time",0.25,
    "rcs_general_confirm_time",0.5,
    "rcs_release_time",1.0,
    "upset_aoa",35,
    "upset_confirm_time",0.75,
    "recovery_safe_aoa",15,
    "recovery_exit_pitch",30
)).
Poseidon_SSTO:add("TerminalRoute",lex(
    "final_distance",10000,
    "base_offset",3000,
    "downwind_extension",8000,
    "hold_radius",2500,
    "target_speed",132,
    "minimum_speed",112,
    "final_brake_speed",140,
    "low_energy_margin",220,
    "brake_energy",150,
    "hold_exit_energy",250,
    "rehold_energy",99999,
    "phase_change_delay",12,
    "hold_descent_rate",24,
    "downwind_descent_rate",20,
    "final_descent_rate",28,
    "final_vs_distance_factor",0.7,
    "early_descent_margin",250,
    "hold_aoa_max",22,
    "bank_deadband",4,
    "bank_full_error",30,
    "bank_max",40,
    "intercept_hold_distance",1500,
    "downwind_to_base_distance",6000,
    "base_to_final_distance",6000,
    "final_lead_fraction",0.5,
    "final_lead_min",1500,
    "final_lead_max",8000,
    "pitch_bias_min",-18,
    "pitch_bias_max",12,
    "descent_min_aoa",5,
    "descent_aoa_max",12,
    "descent_aoa_gain",0.4,
    "time_to_go_min_speed",80,
    "time_to_go_min",5,
    "final_time_to_go_min",3,
    "hold_descent_time_limit",20,
    "downwind_descent_time_limit",20,
    "final_descent_time_limit",15,
    "final_pitch_pid_p",0.5,
    "final_pitch_pid_i",0.2,
    "final_pitch_pid_d",0.4,
    "final_pitch_pid_max",15,
    "final_pitch_pid_min",-35,
    "pitch_bias_gain",0.35,
    "nominal_target_aoa",16,
    "max_energy_aoa",30,
    "high_energy_threshold",300,
    "energy_aoa_gain_denominator",120,
    "final_alignment_heading_tolerance",1.5,
    "final_heading_correction",2,
    "final_aoa_offset",5,
    "debug_log_interval",0.5
)).
Poseidon_SSTO:add("EG_rev°",5).
Poseidon_SSTO:add("EG_am_range",20).
Poseidon_SSTO:add("EGAOA",{
parameter alt_ is ship:altitude.
    if alt_ <= 20000 {
        return 10.
    }

    if alt_ >= 60000 {
        return 20.
    }

    if alt_ < 35000 {
        local x is (alt_ - 30000) / 5000.
    
    return 7.716203
        + 10.098967 * alt_ / 100000
        + 4.1949411
        + 6.63635039 * x
        - 2.33703759 * x * x
        - 6.10762857 * x * x * x
        + 1.61617832 * x * x * x * x
        + 2.77708547 * x * x * x * x * x.
    }   

    return 7.716203
        + 10.098967 * alt_ / 100000
        + 6.632180.
    }).
Poseidon_SSTO:add("simulation",lex("timestep",5,"entry_ref_alt",60000,"max_iterations",10,"dist_tolerance",5000)).
local abort_modes is lex().
//abort_modes:add().


Poseidon_SSTO:add("AbortModes", abort_modes).

global AVES is Poseidon_SSTO.
