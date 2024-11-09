RUNONCEPATH("0:/Libraries/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").




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
get_inputs_Launch().
set TargetPeriapsis to str_to_num(TargetPeriapsis).
set TargetApoapsis to str_to_num(TargetApoapsis).
set TargetInclination to str_to_num(TargetInclination).
log("targetperiapsis: "+TargetPeriapsis) to (log.txt).
log("targetapoapsis: "+Targetapoapsis) to (log.txt).
log("targetInclination: "+TargetInclination) to (log.txt).

check_inputs().

reset_sys().

set dap_mode to "auto".
until running = false{
    update_readouts().
    dap().
    //check_abort().
    if step = "Launch"{
         
        if ship:altitude < 85{
             
            rapierson().
            set dapthrottle to 1.
        }   
        if ship:thrust > AVES["StationaryThrottle"]{
            brakes off.
                
                
                if ship:airspeed > AVES["Speed"]["Rotate"]{
                    
                    set step to "rotate".
                    set Lastest_status to "rotating".
                    Set warpmode to "physics".
                    
                }
        }
               
        
    if ship:altitude > 85{
        set Lastest_status to "not in lift off conditon".
        set step to "end".
    }
    }
    if step = "rotate"{
        set targetPitch to 15.
        if ship:altitude > 90{
            gear off.
            set step to "assent".
            set warp to 0.
        }
    }
    if step = "assent"{
        if ship:airspeed < 440{
            set distance_pitch to  10.
            aeroturn((TargetInclination+90)). 
            if ship:altitude < 200{
                set distance_pitch to 17.
            }
            
        }
        if airspeed > 440 and ship:altitude < 15000{set targetPitch to  15. set warp to 1.}
        
        if ship:altitude > 15000 and ship:altitude < 20000 and targetPitch > 2{
            
            set targetPitch to targetPitch - 0.4.
            wait 0.55.
            if not (ship:apoapsis > ship:altitude + 500){
                set targetPitch to 7.
            }
            }
        if ship:altitude > 20000 and ship:altitude < 23000{   
        set targetPitch to 10.
        set warp to 0.
        nervson().
        set Lastest_status to "nervs on".
        }
        if ship:altitude > 23000 and ship:altitude < 57000{
            if rapier_mode = "air"{
                togglerapiermode().
                set rapier_mode to "closed".
            }   
            set Lastest_status to "rapiers in closed cycle".
            if TargetPitch < 30{
                set targetPitch to targetPitch + 1.
                wait 0.5.
            }   
            set warp to 1.
            rcs on.
        }    
        if ship:apoapsis > 57000{
            rapiersoff().
            set targetPitch to 15.
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
    if step = "abort"{

    }
    if step = "runway_abort"{
        set Lastest_status to "Runway abort".
        brakes on.
        set dapthrottle to 0.
        rapiersoff().
        set targetPitch to -5.
        if ship:airspeed < 1{
            set Lastest_status to "abort complete".
            set step to "end".
        }    
    }
    
    if step = "end"{
        set running to false.
        //set Lastest_status to "ending".
        reset_sys().
        set warp to 0.
        update_readouts().
    }
}