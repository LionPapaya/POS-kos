RUNONCEPATH("0:/Libraries/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_location_constants.ks").
RUNONCEPATH("0:/Libraries/lib_gui.ks").
//if ship:periapsis > 70000{
setup_reentry_script().
//}

until running = false{
    update_readouts().
    dap().
    update_reentry_gui().
    
    if step = "Deorbit"{
        if substep = "findStep"{
           
            if ship:periapsis < 70000{
                set step to "reentry".
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
                if deorbit_start = false{
                    set deorbit to node(time+ship:orbit:period, 0, 0, 0).
                    add deorbit.
                    set deorbit_start to true.
                } 
                 if deorbit:orbit:periapsis < -10000 and deorbit_calc = false{
                    if  deorbit:orbit:periapsis + 10000 < -10000{
                        set deorbit:prograde to deorbit:prograde + 10.
                    }
                    if deorbit:orbit:periapsis + 1000 < -10000{
                        set deorbit:prograde to deorbit:prograde + 1.
                    }
                    if deorbit:orbit:periapsis + 100 < -10000{
                        set deorbit:prograde to deorbit:prograde + 0.1.
                    }
                }
                if deorbit:orbit:periapsis > -10000 and deorbit_calc = false{
                    if  deorbit:orbit:periapsis - 10000 > -10000{
                        set deorbit:prograde to deorbit:prograde - 10.
                    }
                    if deorbit:orbit:periapsis - 1000 > -10000{
                        set deorbit:prograde to deorbit:prograde - 1.
                    }
                    if deorbit:orbit:periapsis - 100 > -10000{
                        set deorbit:prograde to deorbit:prograde - 0.1.
                    }
                } 
                if Reentry_mode = "auto" {
               
                
                if deorbit:orbit:periapsis + 1000 > -10000 and deorbit:orbit:periapsis - 1000 < -10000 and deorbit_calc = false and addons:TR:hasimpact {
                local impact_point is ADDONS:TR:impactpos.  // Impact position
                local runway_point is runway_start.         // Runway start position
    
                // Calculate the distance between the impact position and the runway start in kilometers
                local distance_to_runway is calcdistance(impact_point, runway_point).  // In kilometers

                // Adjust time more aggressively when farther from the runway_start
                if distance_to_runway > 10 {
                    set deorbit:time to deorbit:time + 10.  // Larger step for larger distances (> 10 km)
                } else if distance_to_runway <= 10 and distance_to_runway > 1.5 {
                    set deorbit:time to deorbit:time + 1.  // Smaller step for closer distances (between 1.5 and 10 km)
                }

    

                // Log the longitude difference for debugging purposes
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
            set targetDirection to compass_for_prograde().

        }
        if ship:altitude < 65000{
            set Lastest_status to "reentering".
            goto_target().
            aerostr().
        }
        if ship:altitude < 25000{
            set step to "TEAM".
            set Lastest_status to "TEAM".
        }
    }    
    if step = "TEAM"{
       if not(defined Active_HAC){
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

            

            set old_hac_distance to calcdistance(ship:geoposition,Active_HAC_entry).
            set Lastest_status to "intercepting hac".
            set in_hac  to false.
            set ex_hac to false.
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
            set TEAM_targetalt to calculate_vertical_glideslope_alt(
                    
                calcdistance_m(hac_ercl,runway_start)+
                
                calc_circle_distance(AVES["HacRadius"],runway_heading-compass_for())).
       }
       
       if abs(compass_for()-runway_heading) < 20 and in_hac{
            set ex_hac to true.
       }
       
       
       if ex_hac{
            set Lastest_status to "completed hac".
            aeroturn(heading_to_target(
            
            get_geoposition_along_heading(
        
            runway_start,
        
            runway_heading+180,
        
            (calcdistance_m(ship:geoposition,runway_start)*0.5)))).


        
            set TEAM_targetalt to 
                
                calculate_vertical_glideslope_alt(
                    
                calcdistance_m(ship:geoposition,runway_start)).




       }
       aerotstr().
       set TEAM_Pitch_PID to pidloop(0.17,0.19,0.2).
       SET TEAM_Pitch_PID:SETPOINT TO TEAM_targetalt-50.
       set TEAM_Pitch_PID:minoutput to -25.
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
        if alt_ovr_runway > 35{// Manage brakes during landing
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
    if step = "end" {
        set running to false.
        reset_sys().
        set warp to 0.
        update_readouts().
        log_status("Script ended, system reset").
        clearguis.
    }
    update_readouts().
}    