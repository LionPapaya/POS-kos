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
        lock steering to heading(targetDirection, targetPitch, targetRole).
    

    lock throttle to 0.
    if ship:periapsis > 70000 or ship:altitude > 300000{
        ag5 on.
        nervson().
        rapiersoff().
    }
    else{
        ag5 off.
    }
    lights on.
    lock targetPitch to 0.
    lock targetRole to 0.
    lock targetDirection to 90.
    lock steering to heading(targetDirection, targetPitch, targetRole).
    set turn_pitch to 0.
    set distance_pitch to 0.
    set aerostr_roll  to 0.
    set aerostr_heading to 90.
    
    
    
}

function get_inputs_Launch{


RUNpath("0:/Libraries/lib_input_terminal.ks").

CLEARSCREEN.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:HEIGHT TO 25.
PRINT "+-------------------------------------------+".
PRINT "|Apoapsis>                                  |".
PRINT "|Periapsis>                                 |".
PRINT "|Inclination>                                |".
PRINT "+-------------------------------------------+".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "+-------------------------------------------+".
PRINT "|Type the name of the field you want to     |".
PRINT "|change, then type the value you want       |".
PRINT "|the field to hold and press enter.         |".
PRINT "|Type 'go' to end script.                   |".
PRINT "|                                           |".
PRINT "|EXAMPLE: typing 'Mode' will change         |".
PRINT "|the prompt from ':>' to ':number0:>'       |".
PRINT "|and the thing that you type will go to     |".
PRINT "|the 'Mode' field after enter is pressed.|".
PRINT "+-------------------------------------------+".

LOCAL fields IS LEXICON(
	"Apoapsis",LEXICON("maxLength",9,"col",15,"row",1,"str","80000","isNum",True,"inFunction",terminal_input_number@),
	"Inclination",LEXICON("maxLength",3,"col",15,"row",3,"str","0","isNum",TRUE,"inFunction",terminal_input_number@),
	"Periapsis",LEXICON("maxLength",30,"col",15,"row",2,"str","80000","isNum",True,"inFunction",terminal_input_number@)
	
).
LOCAL exitWords IS LIST(
	"ok",
	"start",
	"affirmative",
	"go",
	"enter"
).
LOCAL prompt IS ":> ".
LOCAL terminalData IS LIST(prompt).
LOCAL terminalRowStart IS 5.
LOCAL termPos IS 0.
LOCAL inField IS "".
LOCAL inFunction IS terminal_input_string@.
LOCAL fieldStr IS "".
LOCAL maxIn IS 45.
FOR key IN fields:KEYS {
	LOCAL field IS fields[key].
	PRINT (field["str"]) AT(field["col"],field["row"]).
}
LOCAL quit IS FALSE.
RCS OFF.
UNTIL quit OR RCS {
	SET termPos TO 0.
	FOR line in terminalData {
		SET termPos TO termPos + 1.
		PRINT "|" + line:PADRIGHT(43) + "|" AT(0,terminalRowStart + termPos).
	}
	LOCAL indentation IS terminalData[terminalData:LENGTH - 1]:LENGTH + 1.
	LOCAL inString IS inFunction(indentation,terminalRowStart + termPos,MIN(44 - indentation,maxIn),fieldStr).
	SET terminalData[terminalData:LENGTH - 1] TO terminalData[terminalData:LENGTH - 1] + inString.
	
	IF inField <> "" {
		LOCAL field IS fields[inField].
		SET field["str"] TO inString.
		PRINT (field["str"]):PADRIGHT(maxIn - 1) AT(field["col"],field["row"]).
		terminalData:ADD(prompt).
		SET inField TO "".
		SET maxIn TO 45.
		SET inFunction TO terminal_input_string@.
		SET fieldStr TO "".
	} ELSE IF fields:HASKEY(inString) {
		SET inField TO inString.
		LOCAL field IS fields[inField].
		SET maxIn TO field["maxLength"].
		SET inFunction TO field["inFunction"].
		SET fieldStr TO field["str"].
		terminalData:ADD(":" + inString + prompt).
	} ELSE IF exitWords:CONTAINS(inString) {
		SET quit TO TRUE.
	} ELSE {
		terminalData:ADD(" Not a valid field or command!").
		terminalData:ADD(prompt).
	}
	UNTIL terminalData:LENGTH <= 6 {
		terminalData:REMOVE(0).
	} 
}
SET TargetPeriapsis TO fields["Periapsis"]["str"].
SET TargetApoapsis TO fields["Apoapsis"]["str"].
SET TargetInclination TO fields["Inclination"]["str"].
clearscreen.

}
function update_readouts{
  runpath("0:/Poseidon_SSTO/Poseidon_SSTO_HUD.ks").

}

function rapierson{
    if rapiers = false{toggle AG1.}
    set rapiers to true.

}
function rapiersoff{
     if rapiers = true{toggle AG1.}
     set rapiers to false.
}
function togglerapiermode{
    toggle AG3.
}
function nervson{
    if nervs = false{toggle AG2.}
    set nervs to true.
}
function nervsoff{
    if nervs = true{toggle AG2.}
    set nervs to false.
}
function check_inputs{
    if TargetApoapsis < TargetPeriapsis or TargetPeriapsis < 75000 or TargetInclination < 0 or TargetInclination > 180 or TargetApoapsis > 84159286{
    set step to "end".
    set Lastest_status to "wrong setup".
    }
}
function setup_reentry_script{
    set step to "Deorbit".
    set substep to "find step".
    set running to true.
    clearScreen.  
    if maxThrust > 110{
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
    get_inputs_reentry().
   if Reentry_mode = "man" or Reentry_mode = "mannual" {
    local a is Location+"_runway".
    local b is Location+"_runway_"+runway_nr+"_start".
    local c is Location+"_runway_"+runway_nr+"_end".
    
    LOG "Constructed keys: a=" + a + ", b=" + b + ", c=" + c TO "log.txt".
    LOG ("Keys of Location_constants "+Location_constants:keys) TO "log.txt".
    LOG ("Values of Location_constants "+Location_constants:values) TO "log.txt".

    // Check if the "kerbin" lexicon contains the runway data
    if Location_constants:HASKEY("kerbin") {
        local kerbin_runways is Location_constants["kerbin"].

        // Check if the keys exist in the nested lexicon "kerbin"
        if kerbin_runways:HASKEY(b) {
            set runway_start to kerbin_runways[b].
        } else {
            LOG "Key " + b + " not found in kerbin_runways." TO "log.txt".
        }

        if kerbin_runways:HASKEY(c) {
            set runway_end to kerbin_runways[c].
        } else {
            LOG "Key " + c + " not found in kerbin_runways." TO "log.txt".
        }
    } else {
        LOG "Key 'kerbin' not found in Location_constants." TO "log.txt".
    }
}
set runway_heading to heading_between(runway_start, runway_end).

    set runway_start to 
    ADDONS:TR:SETTARGET(runway_start).
    ADDONS:TR:RESETDESCENTPROFILE(30).
    set targetPitch to 5.
    set targetRole to 0.
    set targetDirection to 90.
    reset_sys().
}
function goto_target{
    set distance_between_runway_start_IMPACTPOS to calcdistance(ship:geoposition,runway_start) - calcdistance(ship:geoposition,addons:tr:impactpos).
    calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)).
    aeroturn((heading_to_target(runway_start))).
    if calcdistance(ship:geoposition,addons:tr:impactpos) < calcdistance(ship:geoposition,runway_start) and calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) > 2{
        set distance_pitch to 20.
        brakes off.
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,runway_start) and calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) < -1{
        set distance_pitch to 32.
        
    }
    if calcdistance(ship:geoposition,addons:tr:impactpos) > calcdistance(ship:geoposition,runway_start) and calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) < -3{
        brakes on.
    }
    if calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) < 2 and calc_percentage(distance_between_runway_start_IMPACTPOS,calcdistance(ship:geoposition,runway_start)) > -1{
        set distance_pitch to 28.
        brakes off.
        
    }
    
}

function log_status {
    parameter message.
    log message + " | Altitude: " + ship:altitude + "m, Airspeed: " + ship:airspeed + "m/s, inputPitch: " + distance_pitch + ", Pitch: " + pitch_for() +  ", Throttle: " + throttle + ", Glideslope(V): " + calculate_vertical_glideslope_distance() + ", Glideslope(L): " + calculate_lateral_glideslope_distance() + ",runway_start_distance(m): "+ ((calcdistance(ship:geoPosition, runway_start))*1000)to ("0:/log.txt").
}
// Refined pitch adjustment function
function adjust_pitch_for_glideslope {
    set vertical_distance to calculate_vertical_glideslope_distance()+20.

    // Adjust distance_pitch based on glideslope
    if vertical_distance < -2000 {
        smooth_pitch_adjustment(15).  // Gradual climb if below glideslope
    } else if vertical_distance < -1000{
        smooth_pitch_adjustment(10). 
    }else if vertical_distance < -500{
        smooth_pitch_adjustment(5). 
    }else if vertical_distance < -100{
        smooth_pitch_adjustment(4). 
    }else if vertical_distance < -50{
        smooth_pitch_adjustment(3). 
    }else if vertical_distance > 1000 {
        smooth_pitch_adjustment(-23).  // Gradual descent if above glideslope
    } else if vertical_distance > 600 {
        smooth_pitch_adjustment(-12).  // Gradual descent if above glideslope
    }else if vertical_distance > 500 {
        smooth_pitch_adjustment(-8).  // Gradual descent if above glideslope
    }else if vertical_distance > 50 {
        smooth_pitch_adjustment(-4).  // Gradual descent if above glideslope
    }else if vertical_distance > 20 {
        smooth_pitch_adjustment(-1).  // Gradual descent if above glideslope
    }else {
        smooth_pitch_adjustment(2).  // Level out near the glideslope
    }

    // Apply distance_pitch to the ship's pitch control
    
}
// Dynamic throttle and brake control
function manage_airspeed_and_brakes {
    if calcdistance(ship:geoposition,runway_start) <25{
        if ship:airspeed > 150 {
        brakes on.
        lock throttle to 0.  // Moderate throttle to maintain speed
        log_status("Throttle at 0%, Brakes ON").
    } else if ship:airspeed > 130{
        brakes off.
        lock throttle to 0.  // Increase throttle when airspeed is low
        log_status("Throttle at 0%, Brakes OFF").
    }else if ship:airspeed > 120{
        brakes off.
        lock throttle to 0.2.  // Increase throttle when airspeed is low
        log_status("Throttle at 20%, Brakes OFF").
    } else if ship:airspeed > 100{
        brakes off.
        lock throttle to 0.5.  // Increase throttle when airspeed is low
        log_status("Throttle at 50%, Brakes OFF").
    }
    else if ship:airspeed > 80{
        brakes off.
        lock throttle to 1.  // Increase throttle when airspeed is low
        log_status("Throttle at 100%, Brakes OFF").
    }
    } else{
        brakes off.
        log_status("Throttle at 0%, Brakes OFF").
    }
}

// High-altitude approach phase
function high_altitude_approach_phase {
    if ship:altitude > 12000 {
        // Aggressive descent to rapidly lower altitude
        set distance_pitch to -15.
        lock throttle to 1.
        aerostr().

        if ship:airspeed > 300 {
            lock throttle to 0.8.
            brakes off.  // Reduce throttle if airspeed gets too high
        }
        if ship:airspeed > 400 {
            lock throttle to 0.  // Reduce throttle if airspeed gets too high
        }
        if ship:airspeed > 450 {
            brakes on.  
        }
        
        log_status("Aggressive descent active, lowering altitude").
    }
}// Approach phase refinement
function approach_phase {
    log_status("Approach phase initiated").
    aerostr().
  // Calculate lateral glideslope distance (how far the aircraft is from the centerline)
     adjust_heading_based_on_glideslope().
    
    // Logging lateral glideslope distance and corrections for high precision
    log "Lateral glideslope distance: " + lateral_glideslope + " meters, heading adjustment: " + heading_adjustment to "0:/log.txt".

    


    adjust_pitch_for_glideslope().
    manage_airspeed_and_brakes().

    // Transition to landing if conditions met
    if ship:altitude < 500 and abs(calculate_lateral_glideslope_distance()) < 10 and abs(calculate_vertical_glideslope_distance()) < 10 {
        set step to "landing".
        log_status("Transitioning to landing phase").
    }
    else if ship:altitude < 500 and (abs(calculate_lateral_glideslope_distance()) > 10 or abs(calculate_vertical_glideslope_distance()) > 10) {
        set step to "landing".
        log_status("Approach failed, transitioning to landing").
    }
}

// Landing phase refinement
function landing_phase {
    log_status("Landing phase initiated").
    
    aerostr().
    lock throttle to 0.
    gear on.
    
    if ship:altitude > 250{// Manage brakes during landing
    if ship:airspeed > 160 {
        brakes on.
        log_status("Brakes ON, airspeed above 160").
    }
    if ship:altitude < 100 {
        brakes off.
        log_status("Brakes Off, altitude below 100").
    }
    
    // Adjust pitch based on vertical glideslope distance
    adjust_pitch_for_glideslope().
    }else{
        brakes on. set distance_pitch to 10.
        aerostr().
        aggressive_overcorrect_for_prograde().
        set aerostr_roll to 0.
    if ship:airspeed < 5 {
            
            log_status("Landing completed").
        }
        if ship:airspeed < 1 {
            set step to "end".
            log_status("Landing completed, switching to end phase").
        }
    }    
    // Final approach adjustments
    
}function get_inputs_reentry{


RUNpath("0:/Libraries/lib_input_terminal.ks").

CLEARSCREEN.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:HEIGHT TO 25.
PRINT "+-------------------------------------------+".
PRINT "|Mode>                                      |".
PRINT "|Location>                                  |".
PRINT "|runway_nr>                                 |".
PRINT "+-------------------------------------------+".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "|                                           |".
PRINT "+-------------------------------------------+".
PRINT "|Type the name of the field you want to     |".
PRINT "|change, then type the value you want       |".
PRINT "|the field to hold and press enter.         |".
PRINT "|Type 'go' to end script.                   |".
PRINT "|                                           |".
PRINT "|EXAMPLE: typing 'Mode' will change         |".
PRINT "|the prompt from ':>' to ':number0:>'       |".
PRINT "|and the thing that you type will go to     |".
PRINT "|the 'Mode' field after enter is pressed.|".
PRINT "+-------------------------------------------+".

LOCAL fields IS LEXICON(
	"Mode",LEXICON("maxLength",9,"col",11,"row",1,"str","Man","isNum",FALSE,"inFunction",terminal_input_string@),
	"runway_nr",LEXICON("maxLength",3,"col",11,"row",3,"str","09","isNum",TRUE,"inFunction",terminal_input_number@),
	"Location",LEXICON("maxLength",30,"col",11,"row",2,"str","KSC","isNum",FALSE,"inFunction",terminal_input_string@)
	
).
LOCAL exitWords IS LIST(
	"ok",
	"start",
	"affirmative",
	"go",
	"enter"
).
LOCAL prompt IS ":> ".
LOCAL terminalData IS LIST(prompt).
LOCAL terminalRowStart IS 5.
LOCAL termPos IS 0.
LOCAL inField IS "".
LOCAL inFunction IS terminal_input_string@.
LOCAL fieldStr IS "".
LOCAL maxIn IS 45.
FOR key IN fields:KEYS {
	LOCAL field IS fields[key].
	PRINT (field["str"]) AT(field["col"],field["row"]).
}
LOCAL quit IS FALSE.
RCS OFF.
UNTIL quit OR RCS {
	SET termPos TO 0.
	FOR line in terminalData {
		SET termPos TO termPos + 1.
		PRINT "|" + line:PADRIGHT(43) + "|" AT(0,terminalRowStart + termPos).
	}
	LOCAL indentation IS terminalData[terminalData:LENGTH - 1]:LENGTH + 1.
	LOCAL inString IS inFunction(indentation,terminalRowStart + termPos,MIN(44 - indentation,maxIn),fieldStr).
	SET terminalData[terminalData:LENGTH - 1] TO terminalData[terminalData:LENGTH - 1] + inString.
	
	IF inField <> "" {
		LOCAL field IS fields[inField].
		SET field["str"] TO inString.
		PRINT (field["str"]):PADRIGHT(maxIn - 1) AT(field["col"],field["row"]).
		terminalData:ADD(prompt).
		SET inField TO "".
		SET maxIn TO 45.
		SET inFunction TO terminal_input_string@.
		SET fieldStr TO "".
	} ELSE IF fields:HASKEY(inString) {
		SET inField TO inString.
		LOCAL field IS fields[inField].
		SET maxIn TO field["maxLength"].
		SET inFunction TO field["inFunction"].
		SET fieldStr TO field["str"].
		terminalData:ADD(":" + inString + prompt).
	} ELSE IF exitWords:CONTAINS(inString) {
		SET quit TO TRUE.
	} ELSE {
		terminalData:ADD(" Not a valid field or command!").
		terminalData:ADD(prompt).
	}
	UNTIL terminalData:LENGTH <= 6 {
		terminalData:REMOVE(0).
	} 
}
SET Reentry_mode TO fields["Mode"]["str"].
SET runway_nr TO fields["runway_nr"]["str"].
SET Location TO fields["Location"]["str"].
clearscreen.

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
Poseidon_SSTO:add("StationaryThrottle",240).


global AVES is Poseidon_SSTO.
