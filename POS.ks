RUNONCEPATH("0:/Libraries/rsvp/main.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_location_constants.ks").



set main_step to "findstep".
set closed to false.
set nervs to false.
set rapier_mode to "air".
set rapiers to false.
create_main_gui().

reset_sys().

until closed{
    DAP().
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
        runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks").
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
}