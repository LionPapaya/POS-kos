
function get_inputs_Launch{




CLEARSCREEN.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:HEIGHT TO 25.
PRINT "+-------------------------------------------+".
PRINT "|Apoapsis>                                  |".
PRINT "|Periapsis>                                 |".
PRINT "|Inclination>                               |".
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
PRINT "|the prompt from ':>' to ':Mode:>'          |".
PRINT "|and the thing that you type will go to     |".
PRINT "|the 'Mode' field after enter is pressed.   |".
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
   if Reentry_mode = "Man" or Reentry_mode = "Auto" {
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
    set gui_titel to "Reentry and Landing Assistant".
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
        set step to "abort".
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
function create_main_gui{
    global poseidon_gui_main to gui(500).
    set poseidon_gui_main:style:width to 0.

    poseidon_gui_main:show().
    // GUI Setup
    local Title_BOX is poseidon_gui_main:addhbox().
    set poseidon_gui_main:style:hstretch to true.
    set gui_titel to "POSEIDON OPERATING SYSTEM".
    set titel to Title_BOX:addlabel(gui_titel).
    set titel:style:align to ("LEFT").
    set titel:text to " <size=30><b>"+gui_titel+"</b></size>".


    GLOBAL Main_toggels_box IS poseidon_gui_main:ADDHLAYOUT().
    SET Main_toggels_box:STYLE:WIDTH TO poseidon_gui_main:style:width - 16.

    GLOBAL main_dap_mode_box IS Main_toggels_box:ADDHLAYOUT().
    SET main_dap_mode_box:STYLE:WIDTH TO 105.
    GLOBAL main_dap_mode_text IS main_dap_mode_box:ADDLABEL("<b>DAP</b>"). 
    set main_dap_mode_text:style:margin:v to -3.
    GLOBAL main_dap_mode_menu IS main_dap_mode_box:addpopupmenu().
    set main_dap_mode_menu:style:margin:v to -3.
    SET main_dap_mode_menu:STYLE:WIDTH TO 65.
    SET main_dap_mode_menu:STYLE:HEIGHT TO 25.
    SET main_dap_mode_menu:STYLE:ALIGN TO "center".
    main_dap_mode_menu:addoption("AUTO").
    main_dap_mode_menu:addoption("CSS").
    main_dap_mode_menu:addoption("OFF").
    Main_toggels_box:addspacing(8).
    set main_dap_mode_menu:onchange to main_update_dap@.
    
    function main_update_dap {
        parameter decoy is 1.
        set dap_mode to main_dap_mode_menu:value.
    }


    local Programm_box is main_toggels_box:addhlayout().
    local Programm_label is Programm_box:addlabel("<b>Programm</b> ").
    local Programm_popup is Programm_box:addpopupmenu().
    SET Programm_popup:STYLE:HEIGHT TO 25.
    Programm_popup:addoption("Launch").
    Programm_popup:addoption("Landing").
    Programm_popup:addoption("Orbital Maneuvering").
    Programm_popup:addoption("Docking").
    set Programm_popup:onchange to changeProgramm@.

    function changeProgramm{
        parameter decoy is 1.
        if Programm_popup:value = "Launch"{
            set main_step to "POS1".
        }
        if Programm_popup:value = "Landing"{
            set main_step to "POS3".
        }
        if Programm_popup:value = "Orbital Maneuvering"{
            set main_step to "OM1".
        }
        if Programm_popup:value = "Docking"{
            set main_step to "POS2".
        }
    }

}
function get_inputs_OM {
    // Initialize GUI and variables
    local OM_gui is GUI(400, 300).
    set OM_gui:style:width to 400.
    set OM_gui:style:height to 300.

    local confirm_in is false.

    OM_gui:show().
    
    // Title
    local title_box is OM_gui:addhbox().
    set title_box:style:hstretch to true.
    set title_box:style:margin:v to 10.
    local title_label is title_box:addlabel("<size=18><b>Orbital Maneuvering Inputs</b></size>").
    title_box:show().

    // Input Fields
    local input_box is OM_gui:addvbox().
    set input_box:style:margin:v to 10.
    set input_box:style:margin:h to 10.

    // Target Field
    local target_box is input_box:addhlayout().
    local target_label is target_box:addlabel("Target:").
    local target_menu is target_box:addpopupmenu().
    
    set target_menu:onchange to {
        parameter new_value.
        set OM_Target to new_value.
    }.
    target_box:show().

    // Target Type Selector
    local target_type_box is input_box:addhlayout().
    local target_type_label is target_type_box:addlabel("Target Type:").
    local target_type_menu is target_type_box:addpopupmenu().
    target_type_menu:addoption("Body").
    target_type_menu:addoption("Vessel").
    
    set target_type_menu:onchange to {
        parameter new_value.
        set OM_Target_type to new_value.
        update_target_options(target_type_menu:value).
    }.
    target_type_box:show().

    // Nodes Selector
    local nodes_box is input_box:addhlayout().
    local nodes_label is nodes_box:addlabel("Nodes:").
    local nodes_menu is nodes_box:addpopupmenu().
    nodes_menu:addoption("both").
    nodes_menu:addoption("first").
    set nodes_menu:onchange to {
        parameter new_value.
        set OM_Nodes to new_value.
    }.
    nodes_box:show().

    // Orbit Type Selector
    local orbit_type_box is input_box:addhlayout().
    local orbit_type_label is orbit_type_box:addlabel("Orbit Type:").
    local orbit_type_menu is orbit_type_box:addpopupmenu().
    orbit_type_menu:addoption("circular").
    orbit_type_menu:addoption("elliptical").
    orbit_type_menu:addoption("none").
    set orbit_type_menu:onchange to {
        parameter new_value.
        set OM_Orbit_Type to new_value.
    }.
    orbit_type_box:show().

    // Orbit Orientation Selector
    local orbit_orientation_box is input_box:addhlayout().
    local orbit_orientation_label is orbit_orientation_box:addlabel("Orbit Orientation:").
    local orbit_orientation_menu is orbit_orientation_box:addpopupmenu().
    orbit_orientation_menu:addoption("prograde").
    orbit_orientation_menu:addoption("retrograde").

    set orbit_orientation_menu:onchange to {
        parameter new_value.
        set OM_Orbit_Orientation to new_value.
    }.
    orbit_orientation_box:show().

    input_box:show().

    // OK Button to Finalize Inputs
    local ok_button_box is OM_gui:addhbox().
    set ok_button_box:style:margin:v to 15.
    local ok_button is ok_button_box:addbutton("OK").
    set ok_button:onclick to {
        set confirm_in to true.
        OM_gui:hide().
    }.
    ok_button_box:show().

    // Function to dynamically update target options
    function update_target_options {
        parameter target_type.

        target_menu:clear(). // Clear the existing options
        
        if target_type = "Body" {
            // Add all celestial bodies
            for bleh in buildlist("bodies") {
                target_menu:addoption(bleh:name).
            }
        } else if target_type = "Vessel" {
            // Add all active vessels
            List Targets in all_vessels.
            for vessel in all_vessels{
                target_menu:addoption(vessel:name).
            }
        }
    }

    // Initialize the Target options for the default Target Type
    update_target_options(target_type_menu:value ).

    // Wait for confirmation
    until confirm_in {
        wait 0.01.
    }

    // Return the finalized inputs
    set OM_Target to target_menu:value.
    set OM_Target_type to remove_spaces(target_type_menu:value).
    set OM_Nodes to remove_spaces(nodes_menu:value).
    set OM_Orbit_Type to remove_spaces(orbit_type_menu:value).
    set OM_Orbit_Orientation to remove_spaces( orbit_orientation_menu:value).

    clearscreen.
}


function check_om_nodes{




CLEARSCREEN.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:HEIGHT TO 23.
PRINT "+-------------------------------------------+".
PRINT "|Execute>                                   |".
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
PRINT "|EXAMPLE: typing 'Target' will change       |".
PRINT "|the prompt from ':>' to ':Target:>'        |".
PRINT "|and the thing that you type will go to     |".
PRINT "|the 'Target' field after enter is pressed. |".
PRINT "+-------------------------------------------+".

LOCAL fields IS LEXICON(
    "Execute",LEXICON("maxLength",7,"col",12,"row",1,"str","True","isNum",FALSE,"inFunction",terminal_input_string@)

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
set OM_Execute to fields["Execute"]["str"].

clearscreen.

}