function reset_sys{
    if ship:altitude < 1000 {
        gear on.
        brakes on.
    }   
    if ship:altitude < 50000 {
        rapierson().
        nervsoff().
    }  
    else{
    brakes off.
    gear off.
    }
    set targetPitch to 0.
        set targetRole to 0.
        set targetDirection to 90.
        lock dap_steering to heading(targetDirection, targetPitch, targetRole).
    
    set dapthrottle to 0.
    lock throttle to dapthrottle.
    if ship:periapsis > 70000 or ship:altitude > 300000{
        ag5 on.
        nervson().
        rapiersoff().
    }
    else{
        ag5 off.
    }
    lights on.
    set targetPitch to 0.
    set targetRole to 0.
    set targetDirection to 90.
    lock dap_steering to heading(targetDirection, targetPitch, targetRole).
    set turn_pitch to 0.
    set distance_pitch to 0.
    set aerostr_roll  to 0.
    set aerostr_heading to 90.
    if not(defined smooth_target_aoa or defined smooth_target_bank){
        set smooth_target_aoa to 0.
        set smooth_target_bank to 0.
    }
    
    
    
}
function rapierson{
    if rapiers = false{AG1 on.}
    set rapiers to true.

}
function rapiersoff{
     if rapiers = true{AG1 off.}
     set rapiers to false.
}
function togglerapiermode{
    toggle AG3.
}
function nervson{
    if nervs = false{AG2 on.}
    set nervs to true.
}
function nervsoff{
    if nervs = true{AG2 off.}
    set nervs to false.
}
function check_inputs{
    if TargetApoapsis < TargetPeriapsis or TargetPeriapsis < 75000 or TargetInclination < 0 or TargetInclination > 180 or TargetApoapsis > 84159286{
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
    set distance_between_reentry_target_IMPACTPOS to calcdistance(ship:geoposition,reentry_target) - calcdistance(ship:geoposition,addons:tr:impactpos).
    calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)).
    
        ADDONS:TR:RESETDESCENTPROFILE(20).
        set distance_between_runway_start_IMPACTPOS to calcdistance(ship:geoposition,reentry_target) - calcdistance(ship:geoposition,addons:tr:impactpos).
    
    
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
        if heading_error > 2.5{
            set entry_turnside to "right".
        }
        if heading_error < -2.5{
            set entry_turnside to "left".
        }
        if entry_turnside = "right"{
            set target_aoa to 20.
            set target_bank to -t_bank.
        }
        if entry_turnside = "left"{
            
            set target_aoa to 20.
            set target_bank to t_bank.
        }
                log_status("entry turnside = "+entry_turnside+" t_bank = "+t_bank+" percentage diff  = "+ percentage_diff+" heading error  = "+ heading_error).

    
    
}


function log_status {
    parameter message.
    if ship:altitude < 70000{
    log message + " | Altitude: " + ship:altitude + "m, Airspeed: " + ship:airspeed + "m/s, inputPitch: " + distance_pitch + ", Pitch: " + pitch_for() +  ", Throttle: " + throttle + ", Glideslope(V): " + calculate_vertical_glideslope_distance() + ", Glideslope(L): " + calculate_lateral_glideslope_distance() + ",runway_start_distance(m): "+ ((calcdistance(ship:geoPosition, runway_start))*1000)to ("0:/log.txt").
}
}
function lerp {
    parameter start, end, t.
    return start + (end - start) * t.
}
function dap{
    if not(defined dap_mode){
        set dap_mode to "auto".
    }
    if dap_mode = "auto"{
       
        lock steering to dap_steering.
        SET SAS TO FALSE.
        
        lock throttle to dapthrottle.
        if ship:altitude < 70000{
            set steeringmanager:pitchtorquefactor to 1.
            set steeringmanager:yawtorquefactor to 0.5.
            set steeringmanager:rollcontrolanglerange to 100.
            steeringManager:resetpids().
        }else{
            set steeringmanager:pitchtorquefactor to 1.
            set steeringmanager:yawtorquefactor to 1.
            set steeringmanager:rollcontrolanglerange to 5.
            steeringManager:resetpids().
        }
        if not (defined str_mode){
            set str_mode to "aerostr".
        }
        if str_mode = "aoa"{
            if not (defined aoa_pitch or defined aoa_yaw or defined aoa_roll){
                set aoa_pitch to 0.
                set aoa_yaw to 90.
                set aoa_roll to 0.
            }
            if not(defined target_aoa or defined target_bank){
                set target_aoa to 0.
                set target_bank to 0.
            }
            set smooth_target_aoa to lerp(smooth_target_aoa, target_aoa, AVES["Rotation_rate"]).
            set smooth_target_bank to lerp(smooth_target_bank, target_bank, AVES["Rotation_rate"]).
        
            lock dap_steering to heading(aoa_yaw,aoa_pitch,aoa_roll).
            aoa_bank_management(smooth_target_aoa,smooth_target_bank).
            
        }
        if str_mode = "aerostr"{
            lock dap_steering to heading(targetDirection,targetPitch,targetrole).
        }

    }
    if dap_mode = "css"{
        set sas to false.
             // Capture pilot control inputs
        set pilot_pitch to SHIP:CONTROL:PILOTPITCH.
        set pilot_yaw to SHIP:CONTROL:PILOTYAW.
        set pilot_roll to SHIP:CONTROL:PILOTROLL.
        lock steering to heading(targetDirection, targetPitch, targetRole).
        // Convert pilot controls to target values
        set target_pitch to SHIP:FACING:PITCH + (pilot_pitch * 10). // Adjust sensitivity as needed
        set target_yaw to compass_for() + (pilot_yaw * 10).   // Adjust sensitivity as needed
        set target_roll to SHIP:FACING:ROLL + (pilot_roll * 10).    // Adjust sensitivity as needed

        until target_yaw <= 360 and target_yaw >=0{
        if target_yaw > 360 {
            set target_yaw to target_yaw- 360.
        } 
        if target_yaw < 0 {
            set target_yaw to target_yaw + 360.
        }
        }
    
        aerostr(target_pitch, target_yaw, target_roll).
        lock throttle to SHIP:CONTROL:PILOTMAINTHROTTLE.
        
    }
    if dap_mode = "off"{
        SET SAS TO TRUE.
        UNLOCK steering.
        lock throttle to SHIP:CONTROL:PILOTMAINTHROTTLE.
        
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
    if rapier_status["extra"] > 0 {
        set abort_scenario to abort_scenario + rapier_status["extra"] + "RO Extra, ".
    }

    // Check NERV engines
    local nerv_status is check_engines("nerv").
    if nerv_status["failed"] > 0 {
        set abort_flag to true.
        set abort_scenario to abort_scenario + nerv_status["failed"] + "NO, ".
    }
    if nerv_status["extra"] > 0 {
        set abort_scenario to abort_scenario + nerv_status["extra"] + "NO Extra, ".
    }

    // Remove trailing comma and space
    if abort_scenario:LENGTH > 0 {
        set abort_scenario to abort_scenario:SUBSTRING(0, abort_scenario:LENGTH - 2).
    }

    // Populate the lexicon
    abort_info:add("abort", abort_flag).
    abort_info:add("scenario", abort_scenario).

    return abort_info.
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
            } else if all_rapiers:ignition and not rapiers_expected {
                log "RAPIER engine " + all_rapiers:name + " is running when it shouldn't be! Shutting down." to "0:/log.txt".
                all_rapiers:doevent("Shutdown Engine").
                set extra_engines to extra_engines + 1.
            }
        }
    }
    
    if engine_type = "all" or engine_type = "nerv" {
        set nerv_engines to ship:partstitledpattern("LV-N Atomic Rocket Motor").
        for all_nervs in nerv_engines {
            if not all_nervs:ignition and nerv_expected {
                log "NERV engine " + all_nervs:name + " is not running!" to "0:/log.txt".
                set failed_engines to failed_engines + 1.
            } else if all_nervs:ignition and not nerv_expected {
                log "NERV engine " + all_nervs:name + " is running when it shouldn't be! Shutting down." to "0:/log.txt".
                all_nervs:doevent("Shutdown Engine").
                set extra_engines to extra_engines + 1.
            }
        }
    }

    local engine_status is lexicon().
    engine_status:add("failed", failed_engines).
    engine_status:add("extra", extra_engines).

    return engine_status.
}

// Function to count occurrences of a substring
function count_occurrences {
    parameter str, substr.
    local count is 0.
    local pos is str:INDEXOF(substr).
    until not( pos >= 0) {
        set count to count + 1.
        set pos to str:INDEXOF(substr, pos + substr:LENGTH).
    }
    return count.
}

// Function to check abort conditions
function check_abort_conditions {
    local current_time is missiontime.
    local current_speed is ship:velocity:surface:mag.
    local current_altitude is ship:altitude.
    local abort_info is check_abort().
    
    for mode_name in AVES["AbortModes"]:keys {
        local mode is AVES["AbortModes"][mode_name].
        if current_speed <= mode["speed"] and current_altitude >= mode["altitude"] and current_time >= mode["min_time"] and current_time <= mode["max_time"] {
            if abort_info["abort"] {
                local rapiers_out is count_occurrences(abort_info["scenario"], "RO").
                local nervs_out is count_occurrences(abort_info["scenario"], "NO").
                if rapiers_out >= mode["rapiers_out"] and nervs_out >= mode["nervs_out"] {
                    for scenario in mode["scenarios"] {
                        if abort_info["scenario"]:contains(scenario) {
                            log "Abort triggered: " + mode_name to "0:/log.txt".
                            return mode_name.
                        }
                    }
                }
            }
        }
    }
    return "no_abort".
}

// Function to decide which abort mode to use
function decide_abort_mode {
    local abort_mode is check_abort_conditions().
    if abort_mode = "runway_abort" {
        // Handle runway abort
        log "Executing runway abort." to "0:/log.txt".
        // Add runway abort handling code here
    } else if abort_mode = "rtls" {
        // Handle return to launch site
        log "Executing return to launch site (RTLS)." to "0:/log.txt".
        // Add RTLS handling code here
    } else if abort_mode = "ati" {
        // Handle abort to island
        log "Executing abort to island (ATI)." to "0:/log.txt".
        // Add ATI handling code here
    } else if abort_mode = "toa" {
        // Handle trans-oceanic abort
        log "Executing trans-oceanic abort (TOA)." to "0:/log.txt".
        // Add TOA handling code here
    } else if abort_mode = "ato" {
        // Handle abort to orbit
        log "Executing abort to orbit (ATO)." to "0:/log.txt".
        // Add ATO handling code here
    } else if abort_mode = "cont" {
        // Handle contingency abort
        log "Executing contingency abort (CONT)." to "0:/log.txt".
        // Add CONT handling code here
    } else {
        log "No abort needed." to "0:/log.txt".
    }
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
    set targetPitch to 0.
    set targetRole to 0.
    set targetDirection to 90.
    reset_sys().                                                                             
   
}

local Poseidon_SSTO is lex().
Poseidon_SSTO:add("Speed",Lexicon("MaxSpeed",2400,"MinSpeed",100,"Rotate",120)).
Poseidon_SSTO:add("MaxAeroturnAlt",60000).
Poseidon_SSTO:add("MaxRoll",40).
Poseidon_SSTO:add("MaxPitch",48).
Poseidon_SSTO:add("MinPitch",-30).
Poseidon_SSTO:add("MaxYaw",40).
Poseidon_SSTO:add("Rotation_rate",0.01).
Poseidon_SSTO:add("Glideslope_Angle",0.2).
Poseidon_SSTO:add("pitch_change_rate",2).
Poseidon_SSTO:add("StationaryThrottle",300).
Poseidon_SSTO:add("HacDistance",15000).
Poseidon_SSTO:add("HacRadius",7000).
local abort_modes is lex().
abort_modes:add("runway_abort", Lexicon(
    "speed", 80,
     "altitude", 0,
      "rapiers_out", 1,
       "nervs_out", 0,
        "min_time", 0,
         "max_time", 100,
          "scenarios", list("1RO")
          )).
abort_modes:add("rtls", Lexicon(
    "speed", 0,
     "altitude", 0, 
     "rapiers_out", 2,
      "nervs_out", 0,
       "min_time", 0,
        "max_time", 2000,
         "scenarios", list("2RO", "1RO")
         )).
abort_modes:add("ati", Lexicon(
    "speed", 0,
     "altitude", 0,
      "rapiers_out", 3,
       "nervs_out", 0,
        "min_time", 0,
         "max_time", 3000,
          "scenarios", list("3RO")
          )).
abort_modes:add("toa", Lexicon(
    "speed", 0,
     "altitude", 0, 
     "rapiers_out", 4,
      "nervs_out", 0,
       "min_time", 0,
        "max_time", 4000, 
        "scenarios", list("4RO")
       )).
abort_modes:add("ato", Lexicon(
    "speed", 0,
     "altitude", 0,
      "rapiers_out", 0,
       "nervs_out", 1,
        "min_time", 0, 
        "max_time", 5000,
         "scenarios", list("1NO")
        )).
abort_modes:add("cont", Lexicon(
    "speed", 0,
     "altitude", 0,
      "rapiers_out", 0,
       "nervs_out", 2, 
       "min_time", 0,
        "max_time", 6000, 
        "scenarios", list("2NO")
       )).


Poseidon_SSTO:add("AbortModes", abort_modes).

global AVES is Poseidon_SSTO.
