RUNONCEPATH("0:/Libraries/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_location_constants.ks").
setup_reentry_script().


until running = false{
    update_readouts().
    
    if step = "Deorbit"{
        if substep = "find step"{
            if ship:periapsis < 70000{
                set step to "find_landing".
            }
            if ship:orbit:hasnextpatch{
                set step to "end".
                set Lastest_status to "not in reentry condition".
            }
            if not Addons:TR:Available{ 
                set step to "end".
                set Lastest_status to "TR Addon not installed".

            }
            set substep to "deorbit_manuver".
        }
        
        if substep = "deobit_manuver"{   
        if ship:periapsis > 70000{
                if deorbit_start = false{
                    set deorbit to node(time+ship:orbit:period, 0, 0, 0).
                    add deorbit.
                    set deorbit_start to true.
                }    
                if deorbit:orbit:periapsis < -20000 and deorbit_calc = false{
                    if  deorbit:orbit:periapsis + 10000 < -20000{
                        set deorbit:prograde to deorbit:prograde + 10.
                    }
                    if deorbit:orbit:periapsis + 1000 < -20000{
                        set deorbit:prograde to deorbit:prograde + 1.
                    }
                    if deorbit:orbit:periapsis + 100 < -20000{
                        set deorbit:prograde to deorbit:prograde + 0.1.
                    }
                }
                if deorbit:orbit:periapsis > -20000 and deorbit_calc = false{
                    if  deorbit:orbit:periapsis - 10000 > -20000{
                        set deorbit:prograde to deorbit:prograde - 10.
                    }
                    if deorbit:orbit:periapsis - 1000 > -20000{
                        set deorbit:prograde to deorbit:prograde - 1.
                    }
                    if deorbit:orbit:periapsis - 100 > -20000{
                        set deorbit:prograde to deorbit:prograde - 0.1.
                    }
                }
                
                if deorbit:orbit:periapsis + 1000 > -20000 and  deorbit:orbit:periapsis - 1000 < -20000 and deorbit_calc = false{
                    if abs(ADDONS:TR:impactpos:LAT - runway_start:LAT) <= 1.5  and round(ADDONS:TR:impactpos:LNG) = round(runway_start:LNG){
                        set deorbit_calc to true.
                        set Lastest_status to "deorbit manuver calculated succesfully".
                    }                      
                    set lng_difference to abs(ADDONS:TR:impactpos:LNG - runway_start:LNG).

                        // Adjust time more aggressively when farther from the runway_start
                    if ADDONS:TR:impactpos:LNG < runway_start:LNG {
                        if lng_difference > 10 {
                            set deorbit:time to deorbit:time + 10.  // Larger step for larger distances
                        } else {
                            set deorbit:time to deorbit:time + 1.  // Smaller step for closer distances
                        }
                    }

                    if ADDONS:TR:impactpos:LNG > runway_start:LNG {
                        if lng_difference > 10 {
                            set deorbit:time to deorbit:time - 10.  // Larger step for larger distances
                        } else {
                            set deorbit:time to deorbit:time - 1.  // Smaller step for closer distances
                        }
                    }
                    if round(ADDONS:TR:impactpos:LNG) = round(runway_start:LNG){
                        
                    if round(ADDONS:TR:impactpos:LAT) < round(runway_start:LAT){
                        set deorbit:normal to deorbit:normal + 10.
                    }
                    if round(ADDONS:TR:impactpos:LAT) > round(runway_start:LAT){
                        set deorbit:normal to deorbit:normal - 10.
                    } 
                    }
                }
                if deorbit_calc = true{
                    nervson().
                    rapiersoff().
                    set nd to deorbit.
                    execute_node().
                    set step to "reentry".
                }
                }   
                }
        }
    if step = "reentry"{
        
        if ship:altitude > 75000{
            set Lastest_status to "coasting".
        }
        if ship:altitude < 75000 and ship:altitude > 65000{
            set Lastest_status to "entryinterface".
            reset_sys().
            nervsoff().
            rapierson().
            set targetPitch to 5.
            set targetRole to 0.
            set targetDirection to 90.

        }
        if ship:altitude < 65000 and ship:altitude > 15000{
            set Lastest_status to "reentering".
            goto_target().
            aerostr().
        }
        if ship:altitude < 15000{
            set step to "approach".
            set Lastest_status to "entry complete".
        }
    }    
    if step = "approach"{
          if ship:altitude > 12000 {
            high_altitude_approach_phase().
        } 
        if ship:altitude < 12000 {
            // Once below 5000 meters, switch to regular approach
            approach_phase().
        }
    }
    
    if step = "landing"{
         landing_phase().
    }    
    if step = "end" {
        set running to false.
        reset_sys().
        set warp to 0.
        update_readouts().
        log_status("Script ended, system reset").
    }
    update_readouts().
}    