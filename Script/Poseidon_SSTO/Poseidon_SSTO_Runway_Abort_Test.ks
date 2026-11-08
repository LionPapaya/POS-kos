// Poseidon_SSTO_Runway_Abort_Test.ks
// Standalone data-collection run for the future V1 (commit/abort) runway gate.
// Start it while lined up on a runway.  It starts a normal full-throttle
// RAPIER takeoff roll; press the UI ABORT TAKEOFF button at any chosen point.

RUNONCEPATH("0:/Libraries/lib_location_constants.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").

global runway_abort_test_state is "setup".
global runway_abort_test_abort_requested is false.
global runway_abort_test_roll_distance is 0.
global runway_abort_test_abort_roll_distance is -1.
global runway_abort_test_abort_speed is -1.
global runway_abort_test_abort_time is -1.
global runway_abort_test_start_time is time:seconds.
global runway_abort_test_status_label is 0.
global runway_abort_test_roll_label is 0.
global runway_abort_test_speed_label is 0.



//Set wheel brakes to 200%
for gear_part in ship:partstitledpattern("GEAR") {
    //log  gear_part:allmodules to "mods.log".
    local brake_mod is gear_part:getmodule("ModuleWheelBrakes").
    brake_mod:setfield("brakes",200).

    }
// Keep this callback deliberately small.  The same control commands used by
// the ascent script's `runway_abort` state are applied as soon as the button is
// clicked; the main loop then captures and logs the result.
function runway_abort_test_abort {
    if runway_abort_test_state = "rolling" {
        set runway_abort_test_abort_requested to true.
        rapiersoff().
        brakes on.
        set dapthrottle to 0.
        set dap["aerostr"]["targetPitch"] to AVES["Abort"]["RunwayStop"]["command_pitch"].
    }
}

function runway_abort_test_create_gui {
    GLOBAL panel is gui(300, 130).
    set panel:style:width to 300.
    set panel:style:height to 170.

    local title_row is panel:addhbox().
    title_row:addlabel("<size=16><b>RUNWAY ABORT TEST</b></size>").
    global runway_abort_test_status_label to panel:addlabel("Arming takeoff roll...").
    global runway_abort_test_roll_label to panel:addlabel("Roll distance: 0 m").
    global runway_abort_test_speed_label to panel:addlabel("Surface speed: 0 m/s").

    local button_row is panel:addhbox().
    local abort_button is button_row:addbutton("ABORT TAKEOFF").
    set abort_button:onclick to runway_abort_test_abort@.
    panel:show().
}

clearScreen.
print "Poseidon runway abort test".
print "Press ABORT TAKEOFF at different roll distances to collect stopping data.".

// This is the normal ground portion of the ascent setup, without the rest of
// the ascent state machine.  The active runway supplies the same heading lock.
set rapier_mode to "air".
set rapiers to false.
dap:setup().
local active_runway is find_active_runway().
local runway_heading is active_runway["heading"].
if runway_heading < 0 { set runway_heading to compass_for(). }
set dap["dap_mode"] to "auto".
set dap["str_mode"] to "aerostr".
set dap["aerostr"]["turn_heading"] to runway_heading.
set dap["aerostr"]["targetPitch"] to 0.
set dap["aerostr"]["turn_pitch"] to 0.
set dap["aerostr"]["targetRoll"] to 0.

gear on.
brakes on.
togglerapiermode("AIR").
rapierson().
runway_abort_test_create_gui().

// Match the ascent script: hold the brakes while the RAPIERs spool, then
// release them only once useful thrust is available.  The takeoff-distance
// reference is the position at that brake release.
set dapthrottle to 1.
set runway_abort_test_status_label:text to "SPOOLING RAPIERs — brakes held".
until ship:thrust > AVES["StationaryThrottle"] {
    dap:update().
    wait 0.
}
brakes off.
set runway_abort_test_state to "rolling".
set runway_abort_test_start_time to time:seconds.
local runway_abort_test_start_position is ship:geoposition.

until runway_abort_test_state = "complete" {
    local now is time:seconds.
    set runway_abort_test_roll_distance to calcdistance_m(runway_abort_test_start_position, ship:geoposition).
    dap:update().

    if runway_abort_test_abort_requested and runway_abort_test_state = "rolling" {
        set runway_abort_test_state to "braking".
        set runway_abort_test_abort_roll_distance to runway_abort_test_roll_distance.
        set runway_abort_test_abort_speed to ship:velocity:surface:mag.
        set runway_abort_test_abort_time to now.
    }

    if runway_abort_test_state = "braking" {
        // Reassert the ascent script's runway-abort commands until stopped.
        brakes on.
        set dapthrottle to 0.
        rapiersoff().
        set dap["aerostr"]["targetPitch"] to AVES["Abort"]["RunwayStop"]["command_pitch"].
        if ship:velocity:surface:mag < AVES["Abort"]["RunwayStop"]["stop_speed"] {
            set runway_abort_test_state to "complete".
        }
    }

    set runway_abort_test_status_label:text to choose "FULL THROTTLE — press ABORT TAKEOFF" if runway_abort_test_state = "rolling" else "BRAKING — hold runway heading".
    set runway_abort_test_roll_label:text to "Roll distance: " + round(runway_abort_test_roll_distance, 1) + " m".
    set runway_abort_test_speed_label:text to "Surface speed: " + round(ship:velocity:surface:mag, 1) + " m/s".
    wait 0.
}

local stopping_distance is runway_abort_test_roll_distance - runway_abort_test_abort_roll_distance.
local result is "abort_roll_m=" + round(runway_abort_test_abort_roll_distance, 1) +
    ", stop_distance_m=" + round(stopping_distance, 1) +
    ", total_roll_m=" + round(runway_abort_test_roll_distance, 1) +
    ", abort_surface_speed_mps=" + round(runway_abort_test_abort_speed, 1) +
    ", abort_elapsed_s=" + round(runway_abort_test_abort_time - runway_abort_test_start_time, 2).
print "RUNWAY ABORT TEST COMPLETE".
print result.
//log "ut,abort_roll_m,stop_distance_m,total_roll_m,abort_surface_speed_mps,abort_elapsed_s" to "runway_abort_tests.csv".
log time:seconds + "," + round(runway_abort_test_abort_roll_distance, 1) + "," +
    round(stopping_distance, 1) + "," + round(runway_abort_test_roll_distance, 1) + "," +
    round(runway_abort_test_abort_speed, 1) + "," +
    round(runway_abort_test_abort_time - runway_abort_test_start_time, 2) to "runway_abort_tests.csv".
set runway_abort_test_status_label:text to "COMPLETE — result logged to runway_abort_tests.csv".
set runway_abort_test_roll_label:text to "Abort / stop: " + round(runway_abort_test_abort_roll_distance, 1) + " / " + round(stopping_distance, 1) + " m".
set runway_abort_test_speed_label:text to "Stopped — brakes remain on".
