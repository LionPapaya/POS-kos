RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/entry_guid.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_location_constants.ks").
RUNONCEPATH("0:/Libraries/lib_aerosim.ks").



dap:setup().
set console_mode to "DATA".
set Step to "Turn 1".
set running to true.
dap:set_aoa_auto().
set dap["aoa"]["target_aoa"] to 18.
set dap["aoa"]["target_bank"] to 0.
local time_start is time.
until time - time_start > 5{
    dap:update().
    wait 0.
}
set loopCounter to 0.
dap:set_css().
local start_hed is compass_for_prograde().
// initialize simple turn-radius logger (uses calc_turn_radius already loaded)
// header is written once (overwrites previous file on each run)
log "time_s,turn_radius_m,cur_heading" to "0:/turn_radius_log.txt".
local prev_pos is ship:geoposition.
local prev_hed is compass_for().
wait 0.
until running = false{
    dap:update().


    // run the sampling/logging only once every 20 main-loop iterations



    set loopCounter to loopCounter + 1.

    if loopCounter >= 60 {
        // sample current position/heading and log a turn-radius estimate
        local cur_pos is ship:geoposition.
        local cur_hed is compass_for().
        local radius is 0.
        // call the pre-loaded calc_turn_radius function (guard against absence)
        set radius to calc_turn_radius(prev_pos, prev_hed, cur_pos, cur_hed).
        local csvline is round(time:seconds) + ", " + round(radius) + ", " + round(cur_hed).
        log csvline to "0:/turn_radius_log.txt".
        // advance previous sample
        set prev_pos to cur_pos.
        set prev_hed to cur_hed.
        set loopCounter to 0.
    }

    if Step  ="Turn 1"{
        //aeroturn(start_hed-20,"calc",40,20000).
        if abs(compass_for_prograde() - normalize(start_hed-20)) < 5{
            set Step to "Turn 2".
        }

    }
    if Step = "Turn 2" {
        //aeroturn(start_hed + 30, "left", 25, 50000).
        if abs(compass_for_prograde() - (normalize(start_hed + 30))) < 5 {
            set Step to "Turn 3".
        }
    }

    if Step = "Turn 3" {
        //aeroturn(start_hed - 45, "calc", 26, 15000).
        if abs(compass_for_prograde() - normalize((start_hed - 45))) < 5 {
            set Step to "Turn 4".
        }
    }

    if Step = "Turn 4" {
        //aeroturn(start_hed).
        if abs(compass_for_prograde() - normalize((start_hed))) < 5 {
            set Step to "end".
        }
    }



    if step = "end" {
        set running to false.
        reset_sys().
        set warp to 0.
        update_readouts().
        log_status("Script ended, system reset").
        clearGuis().
    }
    wait 0.
}
