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
    set distance_between_runway_start_IMPACTPOS to calcdistance(ship:geoposition,runway_start) - calcdistance(ship:geoposition,addons:tr:impactpos).
    calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)).
    aeroturn((heading_to_target(runway_start))).
    if ship:airspeed > 700{
    if calcdistance(ship:geoposition,addons:tr:impactpos) < calcdistance(ship:geoposition,runway_start) and calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) > 2{
        set distance_pitch to 23.
        brakes off.
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,runway_start) and calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) < -1{
        set distance_pitch to 20.
        
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,runway_start) and calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) < -3{
        brakes on.
    }
    if calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) < 2 and calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) > -1{
        set distance_pitch to 17.
        brakes off.
        
    }
    }else{
        ADDONS:TR:RESETDESCENTPROFILE(10).
        if calcdistance(ship:geoposition,addons:tr:impactpos) < calcdistance(ship:geoposition,runway_start) and calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) > 2{
        set distance_pitch to 10.
        brakes off.
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,runway_start) and calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) < -1{
        set distance_pitch to 5.
        
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,runway_start) and calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) < -3{
        brakes on.
    }
    if calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) < 2 and calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) > -1{
        set distance_pitch to 15.
        brakes off.
        
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
Poseidon_SSTO:add("HacRadius",8000).



global AVES is Poseidon_SSTO.
