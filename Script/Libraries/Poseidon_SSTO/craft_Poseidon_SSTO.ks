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
    aeroturn((heading_to_target(reentry_target))).
    if step = "reentry_low"{
    if ship:airspeed > 1500{
        ADDONS:TR:RESETDESCENTPROFILE(20).
    if calcdistance(ship:geoposition,addons:tr:impactpos) < calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > 2{
        set distance_pitch to pitch_for_prograde()+15.
        brakes off.
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -1{
        set distance_pitch to pitch_for_prograde()+12.
        
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -3{
        brakes on.
    }
    if calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < 2 and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > -1{
        set distance_pitch to pitch_for_prograde()+8.
        brakes off.
        
    }
    if ship:airspeed > 1400 and ship:airspeed < 1500{
        rcs on.
    }
    }else if ship:airspeed > 700{
        ADDONS:TR:RESETDESCENTPROFILE(20).
    if calcdistance(ship:geoposition,addons:tr:impactpos) < calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > 2{
        set distance_pitch to 23.
        brakes off.
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -1{
        set distance_pitch to 20.
        
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -3{
        brakes on.
    }
    if calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < 2 and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > -1{
        set distance_pitch to 17.
        brakes off.
        
    }
    }else{
        ADDONS:TR:RESETDESCENTPROFILE(10).
        if calcdistance(ship:geoposition,addons:tr:impactpos) < calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > 2{
        set distance_pitch to 10.
        brakes off.
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -1{
        set distance_pitch to 5.
        
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -3{
        brakes on.
    }
    if calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < 2 and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > -1{
        set distance_pitch to 15.
        brakes off.
        
    }
    }
    }
    if step = "reentry_mid" or step = "reentry_high"{
    if ship:airspeed > 2300{
        ADDONS:TR:RESETDESCENTPROFILE(20).
    if calcdistance(ship:geoposition,addons:tr:impactpos) < calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > 2{
        set distance_pitch to pitch_for_prograde()+15.
        brakes off.
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -1{
        set distance_pitch to pitch_for_prograde()+12.
        
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -3{
        brakes on.
    }
    if calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < 2 and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > -1{
        set distance_pitch to pitch_for_prograde()+8.
        brakes off.
        
    }
    if ship:airspeed > 2200 and ship:airspeed < 2300{
        rcs on.
    }
    } else if ship:airspeed > 700{
        ADDONS:TR:RESETDESCENTPROFILE(20).
    if calcdistance(ship:geoposition,addons:tr:impactpos) < calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > 2{
        set distance_pitch to 23.
        brakes off.
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -1{
        set distance_pitch to 20.
        
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -3{
        brakes on.
    }
    if calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < 2 and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > -1{
        set distance_pitch to 17.
        brakes off.
        
    }
    }else{
        ADDONS:TR:RESETDESCENTPROFILE(10).
        if calcdistance(ship:geoposition,addons:tr:impactpos) < calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > 2{
        set distance_pitch to 10.
        brakes off.
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -1{
        set distance_pitch to 5.
        
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -3{
        brakes on.
    }
    if calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < 2 and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > -1{
        set distance_pitch to 15.
        brakes off.
        
    }
    }
    }
        if step = "reentry_int"{
    if ship:airspeed > 3000{
        
        ADDONS:TR:RESETDESCENTPROFILE(20).
    if calcdistance(ship:geoposition,addons:tr:impactpos) < calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > 2{
        set distance_pitch to pitch_for_prograde()+15.
        brakes off.
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -1{
        set distance_pitch to pitch_for_prograde()+13.
        
    }
    if calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < 2 and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > -1{
        set distance_pitch to pitch_for_prograde()+8.
        brakes off.
        
    }
    if ship:airspeed > 2900 and ship:airspeed < 3000{
        rcs on.
    }
    }else if ship:airspeed > 2500{
       
        
        ADDONS:TR:RESETDESCENTPROFILE(20).
    if calcdistance(ship:geoposition,addons:tr:impactpos) < calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > 2{
        set distance_pitch to pitch_for_prograde()+20.
        brakes off.
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -1{
        set distance_pitch to pitch_for_prograde()+18.
        
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -3{
        brakes on.
    }
    if calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < 2 and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > -1{
        set distance_pitch to pitch_for_prograde()+16.
        brakes off.
        
    }
    if ship:airspeed > 2400 and ship:airspeed < 2500{
        rcs on.
    }
    } else if ship:airspeed > 700{
        ADDONS:TR:RESETDESCENTPROFILE(20).
    if calcdistance(ship:geoposition,addons:tr:impactpos) < calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > 2{
        set distance_pitch to 23.
        brakes off.
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -1{
        set distance_pitch to 20.
        
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -3{
        brakes on.
    }
    if calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < 2 and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > -1{
        set distance_pitch to 17.
        brakes off.
        
    }
    }else{
        ADDONS:TR:RESETDESCENTPROFILE(10).
        if calcdistance(ship:geoposition,addons:tr:impactpos) < calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > 2{
        set distance_pitch to 10.
        brakes off.
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -1{
        set distance_pitch to 5.
        
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,reentry_target) and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < -3{
        brakes on.
    }
    if calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) < 2 and calc_percentage(distance_between_reentry_target_IMPACTPOS,calcdistance(ship:geoposition,reentry_target)) > -1{
        set distance_pitch to 15.
        brakes off.
        
    }
    }
    
    
}
}

function log_status {
    parameter message.
    if ship:altitude < 20000{
    log message + " | Altitude: " + ship:altitude + "m, Airspeed: " + ship:airspeed + "m/s, inputPitch: " + distance_pitch + ", Pitch: " + pitch_for() +  ", Throttle: " + throttle + ", Glideslope(V): " + calculate_vertical_glideslope_distance() + ", Glideslope(L): " + calculate_lateral_glideslope_distance() + ",runway_start_distance(m): "+ ((calcdistance(ship:geoPosition, runway_start))*1000)to ("0:/log.txt").
}
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


function check_abort{
    if abort_flag{
        check_engines(all).
    }
}
function check_engines{
    if ship:altitude < 21000{
        set nerv_expected to false.

    }
    if ship:altitude < 57000{
        set rapiers_expected to true.
        
    }
   set rapier_engines to ship:partstitledpattern("R.A.P.I.E.R").
   for all_rapiers in rapier_engines{
        
   }


}
function detect_failed_engines {
    parameter expectedState is true. // Expected engine running state
    parameter engineType is "".     // Engine type: "nerv" or "rapier"
    
    local engineCount is 0.         // Total number of detected engines
    local runningCount is 0.        // Number of engines in the expected state
    
    // Iterate through all parts matching the engine type
    for engine in ship:parts {
        if engine:title =  engineType {
            set engineCount to engineCount + 1.
            // Check engine's current state
            if (engine:engine:ignition = expectedState) {
                set runningCount to runningCount + 1.
            }
        }
    }
    
    // Output result to terminal
    print "Engine Type: " + engineType.
    print "Expected State: " + expectedState .
    print "Engines Running: " + runningCount + " / " + engineCount.
    
    // Return the result as a lexicon
    return lexicon("total", engineCount, "running", runningCount).
}
// Function to log telemetry data on every call
function logTelemetry {
    set log_filename to "reentrylog.txt".  // Fixed filename for telemetry data

    // Open or append to the file to log telemetry data
    if not(defined reentry_log_header_done){    
        log("Time,Altitude,Velocity,Latitude,Longitude,VerticalSpeed,rnw_distance,pitch,glideslope(L),acc") to log_filename.  // Write header if file is new
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
        round(ship:verticalspeed, 2) + ","+
        round(calcdistance_m(ship:geoposition,runway_start)) + ","+
        round(pitch_for()) + ","+
        round(calculate_lateral_glideslope_distance())+ ","+
        round(ship:sensors:acc:mag, 2)
    ) to log_filename.

}
function setup_landing_script{
    
    steeringManager:resetpids().
    set step to "Deorbit".
    set substep to "findStep".
    set running to true.
    clearScreen.  
    set old_hac_distance to 9999999999.
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

global Poseidon_SSTO is lex().
Poseidon_SSTO:add("Speed",Lexicon("MaxSpeed",2400,"MinSpeed",100,"Rotate",120)).
Poseidon_SSTO:add("MaxAeroturnAlt",60000).
Poseidon_SSTO:add("MaxRoll",40).
Poseidon_SSTO:add("MaxPitch",48).
Poseidon_SSTO:add("MinPitch",-30).
Poseidon_SSTO:add("MaxYaw",5).
Poseidon_SSTO:add("Glideslope_Angle",0.2).
Poseidon_SSTO:add("pitch_change_rate",2).
Poseidon_SSTO:add("StationaryThrottle",300).
Poseidon_SSTO:add("HacDistance",15000).
Poseidon_SSTO:add("HacRadius",7000).



global AVES is Poseidon_SSTO.
