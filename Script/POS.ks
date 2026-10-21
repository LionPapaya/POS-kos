// POS.ks
// Purpose: top-level launcher/menu for Poseidon scripts.
// - Loads shared libraries and selects the appropriate Poseidon sub-script (orbit, reentry, docking) based on vessel conditions.
set CONFIG:IPU to 2000.
if not(defined(POS_LOGGING_ENABLED)) {
    global POS_LOGGING_ENABLED is false.
}
//run "POS_AI.ks".
RUNONCEPATH("0:/Libraries/rsvp/main.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_location_constants.ks").
RUNONCEPATH("0:/Libraries/lib_aerosim.ks").

global manual_logging_active is false.
local manual_saved_log_mode is POS_LOGGING_MODE.
local manual_saved_log_level is POS_LOG_LEVEL.
set main_step to "findstep".
set closed to false.
set nervs to false.
set rapier_mode to "air".
set rapiers to false.
create_main_gui().

reset_sys().
dap:setup().

until closed{
    // A manual recording stays in this menu, independently of ascent approval.
    if manual_logging_active and main_step <> "manual_log" {
        flight_log_event("manual_flight_end","next_program="+main_step).
        set manual_logging_active to false.
        set dap["l_t"] to time:seconds.
        set POS_LOGGING_MODE to manual_saved_log_mode.
        set POS_LOG_LEVEL to manual_saved_log_level.
        set manual_log_status:text to "Manual flight recording stopped".
        set manual_log_stop:visible to false.
    }
    if main_step = "manual_log" and not(manual_logging_active) {
        set manual_saved_log_mode to POS_LOGGING_MODE.
        set manual_saved_log_level to POS_LOG_LEVEL.
        // A recorder must contain samples, even if normal logging is off/low.
        // Preserve high mode; restore the previous setting when recording ends.
        if POS_LOG_LEVEL < 2 {
            set POS_LOGGING_MODE to "medium".
            set POS_LOG_LEVEL to 2.
        }
        set step to "manual_flight".
        if defined abort_state { set abort_state to lex("active",false). }
        set dap["str_mode"] to "aerostr".
        dap:set_off().
        set main_dap_mode_menu:index to 2.
        flight_log_begin("manual").
        local manual_runway is find_active_runway().
        if manual_runway["heading"] >= 0 {
            flight_log_set_runway(manual_runway["location"],manual_runway["runway_num"],
                manual_runway["start"],manual_runway["end"],manual_runway["heading"],manual_runway["altitude"]).
        }
        flight_log_event("manual_flight_begin","control=off|mode="+POS_LOGGING_MODE).
        set manual_logging_active to true.
        set manual_log_status:text to "Recording: "+POS_LOG_SESSION+" (OFF / CSS)".
        set manual_log_stop:visible to true.
    }
    // OFF is a passive recorder: do not run protection/control updates that
    // could reclaim steering. CSS uses the existing assisted control behavior.
    if not(manual_logging_active) or dap["dap_mode"] <> "off" { DAP:update(). }
    if manual_logging_active {
        set dapthrottle to ship:control:pilotmainthrottle.
        flight_log_tick("manual","manual_flight","").
        poseidon_gui_main:show().
    }
    if main_step = "findstep"{
        
        if ship:body:atm:exists{
        if ship:altitude > ship:body:atm:HEIGHT{
            set main_step to "ask_Step".
        }
        if ship:altitude < ship:body:atm:HEIGHT{
            set main_step to "POS3".
        }
        if alt:radar < 10{
            set main_step to "POS1".
        }
        }else{
            set main_step to "ask_Step".
        }
        

    }
    if main_step = "ask_Step"{
        poseidon_gui_main:show().
    }
    if main_step = "POS1"{
        poseidon_gui_main:hide().
        runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Orbit_Main.ks").
        set main_step to "ask_Step".
    }  
    if main_step = "POS3"{
        poseidon_gui_main:hide().
        //runpath("0:/Poseidon_SSTO/Aeroturn.ks").
        runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks").
        set main_step to "ask_Step".
    }
    if main_step = "Aerobrake"{
        poseidon_gui_main:hide().
        runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Aerobrake.ks").
        set main_step to "ask_Step".
    }
    if main_step = "POS4"{
        poseidon_gui_main:hide().
        runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Vacuum_Landing.ks", "ASK", "ASK", -1, 90, "suborbital").
        set main_step to "ask_Step".
    }
    if main_step = "POS5"{
        poseidon_gui_main:hide().
        runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Vacuum_Landing.ks", 0, 0, -1, 90, "convenient").
        set main_step to "ask_Step".
    }
    if main_step = "POS6"{
        poseidon_gui_main:hide().
        runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Vacuum_Ascent.ks").
        set main_step to "ask_Step".
    }
    if main_step = "OM1"{
        poseidon_gui_main:hide().
        runpath("0:/Poseidon_SSTO/Poseidon_SSTO_OM1.ks").
        set main_step to "ask_Step".
    }
    if main_step = "POS2"{
        poseidon_gui_main:hide().
        runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Docking.ks").
        set main_step to "ask_Step".
    }
    if main_step = "Test"{
        poseidon_gui_main:hide().
        runpath("0:/gui_test.ks").
        set main_step to "ask_Step".
    }
    wait 0.

}
