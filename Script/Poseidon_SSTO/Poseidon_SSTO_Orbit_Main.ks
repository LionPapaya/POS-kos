RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_aerosim.ks").




set step to "Launch".
set running to true.
clearScreen.  

set nervs to false.
set rapier_mode to "air".
set rapiers to false.
set circ_done to false.
set Lastest_status to "launching".
set orbitcalc to false.


//min periapsis = 75000  ----->  apoapsis > periapsis
//Inclination between 0 and 180
local Target_orbit is create_assent_gui().
set TargetPeriapsis to Target_orbit["Periapsis"].
set TargetApoapsis to Target_orbit["Apoapsis"].
set TargetInclination to Target_orbit["inclination"].
log("targetperiapsis: "+TargetPeriapsis) to (log.txt).
log("targetapoapsis: "+Targetapoapsis) to (log.txt).
log("targetInclination: "+TargetInclination) to (log.txt).

check_inputs().

reset_sys().
dap:setup().
set t0 to -1.
set dap_mode to "auto".
until running = false{
    update_readouts().
    dap:update().
    update_assent_gui().

    if ship:altitude < 70000 and ship:airspeed < 2100{
        set console_mode to "assent".
    }else{
         set console_mode to "Data".
    }
    if step = "Launch"{
         
        if ship:altitude < 85{
             
            rapierson().
            set dapthrottle to 1.
        }   
        if ship:thrust > AVES["StationaryThrottle"]{
            brakes off.
            if t0 = -1{
                set t0 to time:seconds.
            }
                
                
                if ship:airspeed > AVES["Speed"]["Rotate"]{
                    
                    set step to "rotate".
                    set Lastest_status to "rotating".
                    Set warpmode to "physics".
                    
                }
            //decide_abort_mode().
        }

        
    if ship:altitude > 85{
        set Lastest_status to "not in lift off conditon".
        set step to "end".
    }
    }
    if step = "rotate"{
        set dap["aerostr"]["targetPitch"] to 15.
        //decide_abort_mode().
        if ship:altitude > 90{
            gear off.
            set step to "assent".
            set warp to 0.
            //set assent_heading to calculate_heading(TargetInclination, ship:latitude).
            SET ASSENT_HEADING TO TargetInclination + 90.
            
        }
    }
    if step = "assent"{
        //decide_abort_mode().
        if ship:airspeed < 440{
            
            IF SHIP:AIRSPEED > 400{
                SET STEP TO "ATI".
            }
            if ship:altitude < 200{
                set aoa_pitch to 17.
            }else{
                set aoa_pitch to 10.
            }
            set dap["str_mode"] to "aoa".
            set base_pitch to -1.
            aeroturn(assent_heading,"calc",aoa_pitch).
        }else{
            set dap["str_mode"] to "aerostr".
            set dap["aerostr"]["targetDirection"] to assent_heading.
        }
        if airspeed > 440 and ship:altitude < 15000{set dap["aerostr"]["targetPitch"] to  15. set warp to 1.}
        
        if ship:altitude > 15000 and ship:altitude < 20000 and dap["aerostr"]["targetPitch"] > 2{
            
            set dap["aerostr"]["targetPitch"] to dap["aerostr"]["targetPitch"] - 0.4.
            wait 0.55.
            if not (ship:apoapsis > ship:altitude + 500){
                set dap["aerostr"]["targetPitch"] to 7.
            }
            }
        if ship:altitude > 20000 and ship:altitude < 23000{   
        set dap["aerostr"]["targetPitch"] to 10.
        set warp to 0.
        nervson().
        set Lastest_status to "nervs on".
        }
        if ship:altitude > 23000 and ship:altitude < 57000{
            if rapier_mode = "air"{
                togglerapiermode("CLOSED").
            }   
            set Lastest_status to "rapiers in closed cycle".
            if dap["aerostr"]["targetPitch"] < 30{
                set dap["aerostr"]["targetPitch"] to dap["aerostr"]["targetPitch"] + 1.
                wait 0.5.
            }else{
                set warp to 1.
            }
            
            rcs on.
        }    
        if ship:apoapsis > 57000{
            rapiersoff().
            set dap["aerostr"]["targetPitch"] to 15.
            rcs off.
        } 
        if ship:altitude > 70000{
            lock dap_steering to prograde.
            set Lastest_status to "Space".
            ag5 on.
        }   
        if ship:apoapsis > TargetApoapsis {
            set Step to "circ".
            rapiersoff().
            set dapthrottle to 0.
            wait 2.
        

            
        }
    }
    if step = "circ"{
        if circ_done = false{
            set circ to node( time+eta:apoapsis, 0, 0, 0).
            add circ.
            set circ_done to true.
        }    
        if circ:orbit:periapsis < TargetPeriapsis and orbitcalc = false{
            if  circ:orbit:periapsis + 10000 < TargetPeriapsis{
                set circ:prograde to circ:prograde + 10.
            }
            if circ:orbit:periapsis + 1000 < TargetPeriapsis{
                set circ:prograde to circ:prograde + 1.
            }
            if circ:orbit:periapsis + 100 < TargetPeriapsis{
                set circ:prograde to circ:prograde + 0.1.
            }
        }
        if circ:orbit:periapsis > TargetPeriapsis and orbitcalc = false{
            if  circ:orbit:periapsis - 10000 > TargetPeriapsis{
                set circ:prograde to circ:prograde - 10.
            }
            if circ:orbit:periapsis - 1000 > TargetPeriapsis{
                set circ:prograde to circ:prograde - 1.
            }
            if circ:orbit:periapsis - 100 > TargetPeriapsis{
                set circ:prograde to circ:prograde - 0.1.
            }
        }
        if circ:orbit:periapsis + 500 > TargetPeriapsis and  circ:orbit:periapsis - 500 < TargetPeriapsis and orbitcalc = false{
            set orbitcalc to true.
            set Lastest_status to "manuver calculated succesfully".
            
        }
        if orbitcalc = true{
            nervson().
            rapiersoff().
            execute_node().
            set step to "end".
        }
        
        

    }
    if step = "runway_abort"{
        set Lastest_status to "Runway abort".
        brakes on.
        set dapthrottle to 0.
        rapiersoff().
        set dap["aerostr"]["targetPitch"] to -5.
        if ship:airspeed < 1{
            set Lastest_status to "abort complete".
            set step to "end".
        }    
    }
    if step = "ati"{
        set Lastest_status to "ati".
        set warp to 0.
        RUN "0:/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks"(lex("force",TRUE,"Location","Kola-Island","Runway","20")).
        SET step to "end".
    }
    if step = "end"{
        set running to false.
        //set Lastest_status to "ending".
        reset_sys().
        set warp to 0.
        update_readouts().
        assent_gui:hide().
    }
    wait 0.
    check_abort().
}