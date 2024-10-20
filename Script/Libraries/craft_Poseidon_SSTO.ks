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
    log ("apoapsis = "+TargetApoapsis+" Periapsis = "+TargetPeriapsis+" Inclination = "+TargetInclination) to log.txt.
    }
}
function setup_reentry_script{
    set step to "Deorbit".
    set substep to "findStep".
    set running to true.
    clearScreen.  
    set old_hac_distance to 9999999999.
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
    create_reentry_display().
   if Reentry_mode = "man" or Reentry_mode = "mannual" {
    local a is Location+"_runway".
    local b is Location+"_runway_"+runway_nr+"_start".
    local c is Location+"_runway_"+runway_nr+"_end".
    set runway_altitude to KerbinRunwayalt[a].
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
log ("runway heading = "+runway_heading) to log.txt.

   
    ADDONS:TR:SETTARGET(runway_start).
    ADDONS:TR:RESETDESCENTPROFILE(20).
    set targetPitch to 5.
    set targetRole to 0.
    set targetDirection to 90.
    reset_sys().
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


// Landing phase refinement
function landing_phase {
    log_status("Landing phase initiated").
    
    aerostr().
    set dapthrottle to 0.
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
        aggressive_overcorrect_for_prograde(runway_heading).
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
    
}
function create_reentry_display {
    local location_to_runways is lexicon().
    
    
        set confirm_in to false.
    
    
    // DEBUG: Log all keys in location_constants to ensure they are structured as expected
    
    local kerbin_runways is Location_constants["kerbin"].
    for key in kerbin_runways:keys {
        

        // Only process keys that end with "_start"
        if key:endswith("_start") {
            // Split the key by underscores
            local split_key is key:split("_").

            // Check if the split key has at least 3 parts (location, "runway", and number)
            if split_key:length >= 3 {
                // Extract location name and runway number
                local location_name is split_key[0].  // First part before the underscore is the location name
                local runway_number is split_key[2].  // Runway number after the second underscore

                // Add the location to the lexicon if it doesn't already exist
                if not location_to_runways:haskey(location_name) {
                    location_to_runways:add(location_name, list()).
                    
                }

                // Add the runway number to the list of runways for this location
                location_to_runways[location_name]:add(runway_number).
                
            } else {
                // Debugging: Log a warning if the key does not have the expected format
                log "Warning: Key '" + key + "' does not follow expected format." to "0:/log.txt".
            }
        }
    }

    // DEBUG: Log final contents of location_to_runways to verify population
    
    for loc in location_to_runways:keys {
        
    }

    set abort_flag to false.
    set end to false.
    
    global reentry_gui to gui(800).
    set reentry_gui:style:width to 800.

    reentry_gui:show().
    // GUI Setup
    local Title_BOX is reentry_gui:addhbox().
    set reentry_gui:style:hstretch to true.
    set gui_titel to "Poseidon Operation System".
    set titel to Title_BOX:addlabel(gui_titel).
    set titel:style:align to ("LEFT").
    set titel:text to " <size=30><b>"+gui_titel+"</b></size>".

    GLOBAL minb IS title_box:ADDBUTTON("-").
    set minb:style:margin:h to 7.
    set minb:style:margin:v to 7.
    set minb:style:width to 20.
    set minb:style:height to 20.
    set minb:TOGGLE to TRUE.

    function minimizecheck {
        set pressed to minb:pressed.

        IF pressed {
            reentry_gui:SHOWONLY(title_box).
            SET reentry_gui:STYLE:HEIGHT TO 50.
        } ELSE {
            SET reentry_gui:STYLE:HEIGHT TO 0.
            for w in reentry_gui:WIDGETS {
                w:SHOW().
            }
        }
    }
    set minb:onclick to minimizecheck@.

    GLOBAL quitb IS title_box:ADDBUTTON("X").
    set quitb:style:margin:h to 7.
    set quitb:style:margin:v to 7.
    set quitb:style:width to 20.
    set quitb:style:height to 20.
    SET quit_program TO false.

    function quitcheck {
        SET step to "end".
        
    }
    SET quitb:ONCLICK TO quitcheck@.

    GLOBAL toggels_box IS reentry_gui:ADDHLAYOUT().
    SET toggels_box:STYLE:WIDTH TO reentry_gui:style:width - 16.

    GLOBAL dap_mode_box IS toggels_box:ADDHLAYOUT().
    SET dap_mode_box:STYLE:WIDTH TO 105.
    GLOBAL dap_mode_text IS dap_mode_box:ADDLABEL("<b>DAP</b>"). 
    set dap_mode_text:style:margin:v to -3.
    GLOBAL dap_mode_menu IS dap_mode_box:addpopupmenu().
    set dap_mode_menu:style:margin:v to -3.
    SET dap_mode_menu:STYLE:WIDTH TO 65.
    SET dap_mode_menu:STYLE:HEIGHT TO 25.
    SET dap_mode_menu:STYLE:ALIGN TO "center".
    dap_mode_menu:addoption("AUTO").
    dap_mode_menu:addoption("CSS").
    dap_mode_menu:addoption("OFF").
    toggels_box:addspacing(8).
    set dap_mode_menu:onchange to update_dap@.
    
    function update_dap {
        parameter decoy is 1.
        set dap_mode to dap_mode_menu:value.
    }

GLOBAL Reentry_mode_box IS toggels_box:ADDHLAYOUT().
    SET Reentry_mode_box:STYLE:WIDTH TO 105.
    GLOBAL Reentry_mode_text IS Reentry_mode_box:ADDLABEL("<b>Mode</b>"). 
    set Reentry_mode_text:style:margin:v to -3.
    GLOBAL Reentry_mode_menu IS Reentry_mode_box:addpopupmenu().
    set Reentry_mode_menu:style:margin:v to -3.
    SET Reentry_mode_menu:STYLE:WIDTH TO 65.
    SET Reentry_mode_menu:STYLE:HEIGHT TO 25.
    SET Reentry_mode_menu:STYLE:ALIGN TO "center".
    Reentry_mode_menu:addoption("AUTO").
    Reentry_mode_menu:addoption("Man").
    Reentry_mode_menu:addoption("Ex").
    toggels_box:addspacing(8).
    



    GLOBAL abort_b is toggels_box:ADDBUTTON("ABORT").
    SET abort_b:STYLE:WIDTH TO 55.
    SET abort_b:STYLE:HEIGHT TO 25.
    set abort_b:style:margin:v to -3.
    set abort_b:STYLE:BG to "Libraries/gui_images/abort_btn.png".

    FUNCTION manual_abort_trigger {
        if abort_flag {
            return.
        }
        getvoice(0):play(note(300,0.5)).
        set abort_flag to true.
    }
    SET abort_b:ONCLICK TO manual_abort_trigger@.

    // Location Selection Popup Menu
    local location_box is toggels_box:addhlayout().
    local location_label is location_box:addlabel("<b>Location:</b> ").
    local location_popup is location_box:addpopupmenu().
    SET location_popup:STYLE:HEIGHT TO 25.

    // Add unique locations to the popup menu
    for loc in location_to_runways:keys {
        location_popup:addoption(loc).
    }
    location_box:show().

    // Runway Selection Popup Menu (dynamically updated)
    local runway_box is toggels_box:addhlayout().
    local runway_label is runway_box:addlabel("<b>Runway:</b> ").
    local runway_popup is runway_box:addpopupmenu().
    SET runway_popup:STYLE:HEIGHT TO 25.
    runway_box:show().

    // Function to update runways based on location selection
    function update_runway_options {
        parameter dummy is "lol".
        local selected_location is location_popup:value.
        local available_runways is location_to_runways[selected_location].

        // Clear current runway options
        runway_popup:clear().
        
        // Add available runways for the selected location
        for runway in available_runways {
            runway_popup:addoption(runway).
        }
    }

    // Trigger runway update when the location is changed
    set location_popup:onchange to update_runway_options@.
    
    // Initialize runway options for the default selected location
    update_runway_options().

    // OK button to finalize the inputs
    local ok_box is toggels_box:addhlayout().
    local ok_button is ok_box:addbutton("OK").
    ok_box:show().

    // Function to confirm and capture the inputs
    function confirm_inputs {
        set Location to location_popup:value.
        set runway_nr to runway_popup:value.
        set Reentry_mode to Reentry_mode_menu:value.
        set confirm_in to true.
        log "Selected Location: " + Location + ", Runway: " + runway_nr to "0:/log.txt".
        
        
    }
    set ok_button:onclick to confirm_inputs@.

  create_reentry_gui().
    


    
    until confirm_in or step= "end"{
        wait 0.0001.
        update_reentry_gui().
    }
}
function create_reentry_gui{
      // Add the image to the vbox
    set console to reentry_gui:addvbox().
    set console:style:height to 300.
    set console:STYLE:BG to "Libraries/gui_images/console.png".
    set console_mode to "SETUP".
    set console_titel to console:addlabel("<size=20><b>"+console_mode+"</b></size>").
    set console_titel:style:align to "center".
    set console_time to console:addlabel((timestamp():clock)).
    set console_time:style:align to "right".
    set console_titel:style:margin:bottom to -30.
    set console_time:style:margin:top to -30.
}
function update_reentry_gui{
    set console_titel:text to ("<size=20><b>"+console_mode+"</b></size>").
    if console_mode = "DATA"{
        set console_time:text to ((timestamp():clock)).
        
    }
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
Poseidon_SSTO:add("HacDistance",10000).
Poseidon_SSTO:add("HacRadius",3000).



global AVES is Poseidon_SSTO.

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

FUNCTION pos_arrow {
	PARAMETER pos.
	PARAMETER lab is "deafault".
	PARAMETER len IS 5000.
	PARAMETER wdh IS 3.
	
	LOCAL start IS pos:POSITION.
	LOCAL end IS (pos:POSITION - SHIP:ORBIT:BODY:POSITION).
	
	VECDRAW(
      start,//{return start.},
      end:NORMALIZED*len,//{return end.},
      RGB(1,0,0),
      lab,
      1,
      TRUE,
      wdh
    ).
}

