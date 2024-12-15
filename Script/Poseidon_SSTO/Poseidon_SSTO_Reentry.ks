RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_location_constants.ks").


IF SHIP:BODY:atm:exists{
//if ship:periapsis > 70000{
setup_reentry_script().
//}

until running = false{
    update_readouts().
    dap().
    update_reentry_gui().
    //if not (step = "Deorbit") and ship:altitude <70000{
    //    logTelemetry().
    //}
    if step = "Deorbit"{
        if substep = "findStep"{
           
            if ship:periapsis < 70000{
                if ship:apoapsis < 500000{
                        set step to "reentry_low".
                    }else if ship:apoapsis < 1000000{
                        set step to "reentry_mid".
                    }else if ship:apoapsis < 10000000{
                        set step to "reentry_high".
                    }else{
                        set step to "reentry_int". // interplanetary reentry or very high kerbin orbit
                    }
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
        set console_mode to "DATA".
        if substep = "deorbit_manuver"{   
        if ship:periapsis > 70000{
                if ship:apoapsis < 100000{
                    set deorbit_periapsis to -10000.
                }else if ship:apoapsis < 200000{
                    set deorbit_periapsis to 10000.
                }else if ship:apoapsis < 500000{
                    set deorbit_periapsis to 15000.
                }else if ship:apoapsis < 1000000{
                    set deorbit_periapsis to 20000.
                }else if ship:apoapsis < 10000000{
                    set deorbit_periapsis to 25000.
                }else{
                    set deorbit_periapsis to 30000.
                }

                if deorbit_start = false{
                    set deorbit to node(time+400, 0, 0, 0).
                    add deorbit.
                    set deorbit_start to true.
                } 
                 if deorbit:orbit:periapsis < deorbit_periapsis and deorbit_calc = false{
                    if  deorbit:orbit:periapsis + 10000 < deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde + 1.
                    }
                    if deorbit:orbit:periapsis + 1000 < deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde + 0.1.
                    }
                    if deorbit:orbit:periapsis + 100 < deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde + 0.01.
                    }
                }
                if deorbit:orbit:periapsis > deorbit_periapsis and deorbit_calc = false{
                    if  deorbit:orbit:periapsis - 10000 > deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde - 1.
                    }
                    if deorbit:orbit:periapsis - 1000 > deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde - 0.1.
                    }
                    if deorbit:orbit:periapsis - 100 > deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde - 0.01.
                    }
                } 
                if Reentry_mode = "auto" {
               
                
                if deorbit:orbit:periapsis + 1000 > deorbit_periapsis and deorbit:orbit:periapsis - 1000 < deorbit_periapsis and deorbit_calc = false and addons:TR:hasimpact {
                local impact_point is ADDONS:TR:impactpos.  
                local runway_point is runway_start.         
    
             
                local distance_to_runway is calcdistance(impact_point, runway_point).  // In kilometers

    
                if distance_to_runway > 50 {
                    set deorbit:time to deorbit:time + 1.  
                } else if distance_to_runway <= 50{
                    set deorbit:time to deorbit:time + 0.1.  
                }

    

               
            set lng_difference to abs(ADDONS:TR:impactpos:LNG - runway_start:LNG).
            }
                            }
            // If we're close enough to the runway
            if addons:TR:hasimpact{
                if calcdistance(ADDONS:TR:impactpos, runway_start) <= 10.5 and addons:TR:hasimpact{
                    set deorbit_calc to true.
                   set Lastest_status to "deorbit maneuver calculated successfully".

                   // Fine-tune the normal direction based on the latitude difference
                   if round(ADDONS:TR:impactpos:LAT) < round(runway_start:LAT) {
                      set deorbit:normal to deorbit:normal + 10.
                 }
                    if round(ADDONS:TR:impactpos:LAT) > round(runway_start:LAT) {
                        set deorbit:normal to deorbit:normal - 10.
             }
    } 
    }               if deorbit_calc = true{
                    nervson().
                    rapiersoff().
                    set nd to deorbit.
                    execute_node().

                    if ship:apoapsis < 500000{
                        set step to "reentry_low".
                    }else if ship:apoapsis < 1000000{
                        set step to "reentry_mid".
                    }else if ship:apoapsis < 10000000{
                        set step to "reentry_high".
                    }else{
                        set step to "reentry_int". // interplanetary reentry or verry high kerbin orbit
                    }
                    
                }
                }   
                }
        }
    if step = "reentry_low"{
       
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
            set targetDirection to compass_for_prograde().
            set ecrl_2hac to get_geoposition_along_heading(runway_start,runway_heading+180,Aves["HacDistance"]*2).
            if calcdistance(ship:geoposition,runway_start) > calcdistance(ship:geoposition,ecrl_2hac){
                set reentry_target to runway_start.
            }else{set reentry_target to ecrl_2hac.}

        }
        
        if ship:altitude > 30000 and ship:altitude < 70000{set console_mode to "TRAJ 1 low".}
        if ship:altitude < 30000 and ship:altitude > 10000{set console_mode to "TRAJ 2".}
        if ship:altitude < 65000{
            set Lastest_status to "reentering".
            goto_target().
            aerostr().
        }
        if pitch_for() > targetPitch+1 and ship:altitude < 55000{
            rcs on.
        }else{
            rcs off.
            
        }
        if ship:altitude < 25000{
            set step to "TEAM".
            set Lastest_status to "TEAM".
        }
    }  
        if step = "reentry_mid"{
       
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
            set targetDirection to compass_for_prograde().
            set ecrl_2hac to get_geoposition_along_heading(runway_start,runway_heading+180,Aves["HacDistance"]*2).
            if calcdistance(ship:geoposition,runway_start) > calcdistance(ship:geoposition,ecrl_2hac){
                set reentry_target to runway_start.
            }else{set reentry_target to ecrl_2hac.}

        }
        
        if ship:altitude > 30000 and ship:altitude < 70000{set console_mode to "TRAJ 1 mid".}
        if ship:altitude < 30000 and ship:altitude > 10000{set console_mode to "TRAJ 2".}
        if ship:altitude < 65000{
            set Lastest_status to "reentering".
            goto_target().
            aerostr().
        }
        if pitch_for() > targetPitch+1 and ship:altitude < 55000{
            rcs on.
        }else{
            rcs off.
            
        }
        if ship:altitude < 25000{
            set step to "TEAM".
            set Lastest_status to "TEAM".
        }
    } 
        if step = "reentry_high"{
       
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
            set targetDirection to compass_for_prograde().
            set ecrl_2hac to get_geoposition_along_heading(runway_start,runway_heading+180,Aves["HacDistance"]*2).
            if calcdistance(ship:geoposition,runway_start) > calcdistance(ship:geoposition,ecrl_2hac){
                set reentry_target to runway_start.
            }else{set reentry_target to ecrl_2hac.}

        }
        
        if ship:altitude > 30000 and ship:altitude < 70000{set console_mode to "TRAJ 1 high".}
        if ship:altitude < 30000 and ship:altitude > 10000{set console_mode to "TRAJ 2 hight".}
        if ship:altitude < 65000{
            set Lastest_status to "reentering".
            goto_target().
            aerostr().
        }
        if pitch_for() > targetPitch+1 and ship:altitude < 55000{
            rcs on.
        }else{
            rcs off.
            
        }
        if ship:altitude < 25000{
            set step to "TEAM".
            set Lastest_status to "TEAM".
        }
    } 
    if step = "reentry_int"{
       
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
            set targetDirection to compass_for_prograde().
            set ecrl_2hac to get_geoposition_along_heading(runway_start,runway_heading+180,Aves["HacDistance"]*2).
            if calcdistance(ship:geoposition,runway_start) > calcdistance(ship:geoposition,ecrl_2hac){
                set reentry_target to runway_start.
            }else{set reentry_target to ecrl_2hac.}

        }
        
        if ship:altitude > 30000 and ship:altitude < 70000{set console_mode to "TRAJ 1 int".}
        if ship:altitude < 30000 and ship:altitude > 10000{set console_mode to "TRAJ 2 int".}
        if ship:altitude < 65000{
            set Lastest_status to "reentering".
            goto_target().
            aerostr().
        }
        if pitch_for() > targetPitch+1 and ship:altitude < 55000{
            rcs on.
        }else{
            rcs off.
            
        }
        if ship:altitude < 25000{
            set step to "TEAM".
            set Lastest_status to "TEAM".
        }
    } 
    if step = "TEAM"{
       if not(defined Active_HAC) or not(defined hac_ercl){
        create_HAC().
        choose_hac().
        set in_hac to false.
        set log to 0.
        
       }
       if log = 10 or log > 10{
       log_status(Lastest_status).
       set log to 0.
       }else{
        set log to log + 1.
       }
       
       if calcdistance(ship:geoposition,Active_HAC_entry) < old_hac_distance and in_hac = false{
            Aeroturn(heading_to_target(Active_HAC_entry)).
        
            set TEAM_targetalt to calculate_vertical_glideslope_alt(
                    
                calcdistance_m(hac_ercl,runway_start)+
                
                calc_circle_distance(AVES["HacRadius"],runway_heading-compass_for())+
                
                calcdistance_m(ship:geoposition,Active_HAC_entry)).
           
            global rnw_dis_display is calcdistance_m(hac_ercl,runway_start)+calc_circle_distance(AVES["HacRadius"],runway_heading-compass_for())+calcdistance_m(ship:geoposition,Active_HAC_entry).

            set old_hac_distance to calcdistance(ship:geoposition,Active_HAC_entry).
            set Lastest_status to "intercepting hac".
            set in_hac  to false.
            set ex_hac to false.
            if ship:airspeed < 160{
                set dapthrottle to 1.
            }
            if ship:airspeed > 220{
                set dapthrottle to 0.
            }
       } else{
            set in_hac to true.
        
       }
       if in_hac and not(ex_hac){
            set Lastest_status to "entered hac".
            if HAC_Direction = "Clockwise"{
                aeroturn_force_dir(runway_heading,"right").
            }
            if HAC_Direction = "Anticlockwise"{
                aeroturn_force_dir(runway_heading,"left").
            }
            global rnw_dis_display is calcdistance_m(hac_ercl,runway_start)+calc_circle_distance(AVES["HacRadius"],runway_heading-compass_for()).
            set TEAM_targetalt to calculate_vertical_glideslope_alt(
                    
                calcdistance_m(hac_ercl,runway_start)+
                
                calc_circle_distance(AVES["HacRadius"],runway_heading-compass_for())).
                
            if ship:airspeed < 120{
                set dapthrottle to 1.
            }
            if ship:airspeed > 150{
                set dapthrottle to 0.
            }
       }
       
       if abs(compass_for()-runway_heading) < 20 and in_hac{
            set ex_hac to true.
            set targetRole to 0.
            
       }
       
       if ship:altitude < 12000{set console_mode to "TRAJ 3".}
       if ex_hac{
            set Lastest_status to "completed hac".
            aeroturn(heading_to_target(
            
            get_geoposition_along_heading(
        
            runway_start,
        
            runway_heading+180,
        
            (calcdistance_m(ship:geoposition,runway_start)*0.5)))).

            global rnw_dis_display is calcdistance_m(ship:geoposition,runway_start).
        
            set TEAM_targetalt to 
                
                calculate_vertical_glideslope_alt(
                    
                calcdistance_m(ship:geoposition,runway_start)).

                     if ship:airspeed < 100{
                        set dapthrottle to 1.
                    }
                    if ship:airspeed > 140{
                        set dapthrottle to 0.
                    }


       }
       aerostr().
       set TEAM_Pitch_PID to pidloop(0.17,0.19,0.3).
       SET TEAM_Pitch_PID:SETPOINT TO TEAM_targetalt-50.
       set TEAM_Pitch_PID:minoutput to -18.
       set TEAM_Pitch_PID:maxoutput to 20.
       
       log("Team alt: "+TEAM_targetalt+" Team Pitch: "+ distance_pitch) to log.txt.
       set distance_pitch to TEAM_Pitch_PID:UPDATE(TIME:SECONDS, ship:altitude).
        set alt_ovr_runway to ship:altitude - runway_altitude.
        if ship:altitude < 200{
            gear on.
        }
        if calcdistance_m(ship:geoposition,runway_start) < 200{
            lock targetRole to 0.
            lock targetDirection to runway_heading.

        }
       // Transition to landing if conditions met
        if alt_ovr_runway < 100 and abs(calculate_lateral_glideslope_distance()) < 10 and abs(calculate_vertical_glideslope_distance()) < 10 {
            set step to "landing".
            log_status("Transitioning to landing phase").
        }
        else if alt_ovr_runway < 100 and (abs(calculate_lateral_glideslope_distance()) > 10 or abs(calculate_vertical_glideslope_distance()) > 10) {
            set step to "landing".
            log_status("Approach failed, transitioning to landing").
        }



    }
    
    if step = "landing"{
        log_status("Landing phase initiated").
        set alt_ovr_runway to ship:altitude - runway_altitude.
        
        aerostr().
        set dapthrottle to 0.
        gear on.
        aggressive_overcorrect_for_prograde(runway_heading).
        if alt_ovr_runway > 35{
        if ship:airspeed > 160 {
            brakes on.
            log_status("Brakes ON, airspeed above 160").
        }
        if ship:airspeed < 100 {
            brakes off.
            log_status("Brakes Off, altitude below 100").
        }
    
        set distance_pitch to 0.
        }else{
            if not(defined old_alt){
                set old_alt to ship:altitude.
            }
            brakes on. 
            if old_alt > ship:altitude{
                set distance_pitch to 5.
            }else{
                set distance_pitch to 0.
            }
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
    set old_alt to ship:altitude.

    }    
    if step = "end" {
        set running to false.
        reset_sys().
        set warp to 0.
        update_readouts().
        log_status("Script ended, system reset").
        clearGuis().
    }
    update_readouts().
}    

}ELSE{


    setup_LANDING_SCRIPT().




    until not(running){
        update_readouts().
        dap().
        if step = "Deorbit"{
            if addons:TR:hasimpact{
                set Step to "s_burn".
            }
            if deorbit_start = false{
                    set deorbit to node(time+400, 0, 0, 0).
                    add deorbit.
                    set deorbit_start to true.
                    set deorbit_periapsis to -1000.
                } 
                if deorbit:orbit:periapsis < deorbit_periapsis and deorbit_calc = false{
                    if  deorbit:orbit:periapsis + 10000 < deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde + 1.
                    }
                    if deorbit:orbit:periapsis + 1000 < deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde + 0.1.
                    }
                    if deorbit:orbit:periapsis + 100 < deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde + 0.01.
                    }
                }
                if deorbit:orbit:periapsis > deorbit_periapsis and deorbit_calc = false{
                    if  deorbit:orbit:periapsis - 10000 > deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde - 1.
                    }
                    if deorbit:orbit:periapsis - 1000 > deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde - 0.1.
                    }
                    if deorbit:orbit:periapsis - 100 > deorbit_periapsis{
                        set deorbit:prograde to deorbit:prograde - 0.01.
                    }
                } 
                if deorbit:orbit:periapsis + 1000 > deorbit_periapsis and deorbit:orbit:periapsis - 1000 < deorbit_periapsis and deorbit_calc = false and addons:TR:hasimpact {
                    set deorbit_calc to true.
                }
                if deorbit_calc = true{
                    nervson().
                    rapiersoff().
                    set nd to deorbit.
                    execute_node().
                    set Step to "s_burn".
                }


        }
        if step = "s_burn"{
            doHoverslam().
            set step to "end".
        }
        if step = "end" {
        set running to false.
        reset_sys().
        set warp to 0.
        update_readouts().
        log_status("Script ended, system reset").
        clearGuis().
        }
    }
}