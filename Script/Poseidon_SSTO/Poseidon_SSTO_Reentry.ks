RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_location_constants.ks").
RUNONCEPATH("0:/Libraries/lib_aerosim.ks").

parameter force_tgt is lex("force",false,"Location","","Runway","").

IF SHIP:BODY:atm:exists{
//if ship:periapsis > 70000{
if not(force_tgt["force"]){
    setup_reentry_script().
}ELSE{
    setup_reentry_script(force_tgt["Location"],force_tgt["Runway"]).
}
//}
set deorbit_periapsis_set_flag to false.
dap:setup().
set console_mode to "DATA".
until running = false{
    update_readouts().
    dap:update().
    local e_gui_inputs is lex(
        "mode", console_mode,
        "alt", ship:altitude,
        "spd", ship:airspeed,
        "pitch", pitch_for(),
        "yaw", compass_for(),
        "roll", roll_for(),
        "mach", ADDONS:FAR:mach,
        "aoa", calc_aoa(),
        "l/d", 0
    ).
    if not(ADDONS:FAR:AEROFORCE = V(0,0,0)) and ship:altitude < body:atm:height + 10{
        local c_a_id is cur_aeroforce_ld().
        set e_gui_inputs["l/d"] to c_a_id["lift"]/c_a_id["drag"].
    }

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
            if deorbit_periapsis_set_flag = false{
                if ship:apoapsis < 100000{
                    set deorbit_periapsis to -10000.
                }else if ship:apoapsis < 200000{
                    set deorbit_periapsis to 10000.
                }else if ship:apoapsis < 500000{
                    set deorbit_periapsis to 12000.
                }else if ship:apoapsis < 1000000{
                    set deorbit_periapsis to 15000.
                }else if ship:apoapsis < 10000000{
                    set deorbit_periapsis to 18000.
                }else{
                    set deorbit_periapsis to 20000.
                }
                set deorbit_periapsis_set_flag to true.
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
                if deorbit:orbit:periapsis + 1000 > deorbit_periapsis and deorbit:orbit:periapsis - 1000 < deorbit_periapsis and deorbit_calc = false and NOT(addons:TR:hasimpact){
                    SET deorbit_periapsis TO deorbit_periapsis - 1000.
                }

                if Reentry_mode = "auto" or Reentry_mode = "EX"{
               
                
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
                    clearVecDraws().
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
    if step = "reentry_low" or step ="reentry_mid" or step = "reentry_high" or step ="reentry_int"{
       
        if ship:altitude > 75000{
            set Lastest_status to "coasting".
        }
        if ship:altitude < 75000 and ship:altitude > 65000{
            reset_sys().
            nervsoff().
            rapierson().
            set dap["str_mode"] to "aoa". 
            set dap["aoa"]["target_aoa"]  to AVES["EGAOA"].
            set dap["aoa"]["target_bank"] to 0.
            set ecrl_2hac to get_geoposition_along_heading(runway_start,runway_heading+180,Aves["HacDistance"]*2).
            if calcdistance(ship:geoposition,runway_start) > calcdistance(ship:geoposition,ecrl_2hac){
                set reentry_target to runway_start.
            }else{set reentry_target to ecrl_2hac.}
            update_readouts().
            if not(defined entry_traj){
               
                Global Team_interface  to define_TEAM_interface(runway_start,runway_heading,runway_altitude).
                log Team_interface["target_latlng"]  to log.txt.
                set entry_traj to calc_entry_traj(current_simstate(),Team_interface["target_altitude"],Team_interface["target_latlng"],Team_interface["team_interface_box"]).

                if entry_traj:converged{
                    set Lastest_status to "Guidance Converged in "+entry_traj["iterations"]+" iterations".
                    update_readouts().
                    wait 3.
                    set Lastest_status to "bank is "+entry_traj["bank"].
                    log "bank is "+entry_traj["bank"] to log.txt.
                    set basice_reentry_guidance to false.
                    set alpha_md_pid to pidloop(0.41,0.21,0.55).
                    set alpha_md_pid:maxoutput to entry_traj["bank"]+AVES["EG_am_range"].
                    set alpha_md_pid:minoutput to max(entry_traj["bank"]-AVES["EG_am_range"],0).
                    set alpha_md_pid:setpoint to 0.
                    local heading_error is heading_to_target(Team_interface["target_latlng"]) - compass_for_prograde().
                    if heading_error > 0{
                        set entry_turnside to "right".
                    }else{
                        set entry_turnside to "left".
                    }

                }else{
                    log "error: "+entry_traj["error"]["str"] to log.txt.
                    log "iterations: "+entry_traj["iterations"] to log.txt.
                    log entry_traj["error"]["max"] to log.txt.
                    log entry_traj["error"]["left"] to log.txt.
                    log entry_traj["error"]["right"] to log.txt.
                    log entry_traj["error"]["target"] to log.txt.
                    set Lastest_status to "Guidance algorithm failed to converge.".
                    update_readouts().
                    wait 5.
                    set Lastest_status to "Switching to basic reentry guidance protocol".
                    update_readouts().
                    set basice_reentry_guidance to true.
                }
            }
            
            

        }
        if  step = "reentry_low" {
            if ship:altitude > 30000 and ship:altitude < 70000{set console_mode to "TRAJ 1 low".}
            if ship:altitude < 30000 and ship:altitude > 10000{set console_mode to "TRAJ 2".}
        }else if step = "reentry_mid"{ 
            if ship:altitude > 30000 and ship:altitude < 70000{set console_mode to "TRAJ 1 mid".}
            if ship:altitude < 30000 and ship:altitude > 10000{set console_mode to "TRAJ 2".}
        }else if step =  "reentry_high"{
            if ship:altitude > 30000 and ship:altitude < 70000{set console_mode to "TRAJ 1 high".}
            if ship:altitude < 30000 and ship:altitude > 10000{set console_mode to "TRAJ 2 high".}
        }else if step ="reenrty_int"{
            if ship:altitude > 30000 and ship:altitude < 70000{set console_mode to "TRAJ 1 int".}
            if ship:altitude < 30000 and ship:altitude > 10000{set console_mode to "TRAJ 2 int".}
        }
        if ship:altitude < AVES["simulation"]["entry_ref_alt"] and ship:altitude > AVES["TEAMAltitude"]{
            set Lastest_status to "reentering".
            set dap["str_mode"] to "aoa".   
            if basice_reentry_guidance or not(defined entry_traj){
                goto_target().
            }else{
                local l is lex().
                for t in entry_traj["converged_sim"]["controll_inputs"]:keys{
                    l:add(t,calcdistance_m(Team_interface["target_latlng"],entry_traj["converged_sim"]["controll_inputs"][t]["simstate"]["latlong"])).
                }
                local t_ is FindClosestTimeStep(l,calcdistance_m(ship:geoposition,Team_interface["target_latlng"])).
                local s_step is entry_traj["converged_sim"]["controll_inputs"][t_]["simstate"].

                local e_ref is calculate_spacecraft_energy(s_step["altitude"],s_step["surfvel"]:mag).
                local e_dot is calculate_spacecraft_energy().
                set alpha_md_pid:setpoint to e_ref.


                    
                


                set dap["aoa"]["target_aoa"]  to AVES["EGAOA"].
                //local d_dot is 0.s
                //local cur_d_dot is cur_aeroforce_ld()["drag"].         s
                //set d_dot to aeroforce_ld(s_step["position"],s_step["surfvel"],list(AVES["EGAOA"],ba))["drag"].
                //set alpha_md_pid:setpoint to d_dot.

                log ("e_dot : "+ e_dot+ " e_ref : "+e_ref) to log_e.txt.

                local heading_error is heading_to_target(Team_interface["target_latlng"]) - compass_for_prograde().
                if heading_error > AVES["EG_rev°"]{
                    set entry_turnside to "right".
                }else if heading_error < -AVES["EG_rev°"]{
                    set entry_turnside to "left".
                }
                local bank_out is invert_in_range(alpha_md_pid:update(time:seconds,e_dot),alpha_md_pid:minoutput,alpha_md_pid:maxoutput).
                local d_t_a is time_to_alt(ship:altitude,ship:verticalspeed,AVES["TEAMAltitude"]).
                if not(d_t_A = 0) and d_t_A < 20 and abs(heading_error) < AVES["EG_rev°"] and time_to_pos(ship:geoposition,Team_interface["target_latlng"],ship:airspeed) > 15{
                    Set Lastest_status to "Low Altitude".
                    if  abs(heading_error) > 2{
                        set bank_out to 10.

                    }else {
                        set bank_out to  abs(heading_error) * 5.
                    }

                }
                if time_to_pos(ship:geoposition,Team_interface["target_latlng"],ship:airspeed) < 15{
                    set dap["aoa"] to max(time_to_pos(ship:geoposition,Team_interface["target_latlng"],ship:airspeed) / 1.5,5).
                    Set Lastest_status to "Transition".
                }
                if time_to_pos(ship:geoposition,Team_interface["target_latlng"],ship:airspeed) < 8{
                    if  abs(heading_error) > 2{
                        set bank_out to 10.

                    }else {
                        set bank_out to  abs(heading_error) * 5.
                    }
                }
                if entry_turnside = "right"{
                    set dap["aoa"]["target_bank"] to -bank_out.
                }else{
                    set dap["aoa"]["target_bank"] to bank_out.
                }
                
                log ("target_aoa"+dap["aoa"]["target_bank"]) to log.txt.
                log(s_step["altitude"]+","+s_step["latlong"]:lat+","+s_step["latlong"]:lng) to log_sim.txt.
                log(ship:altitude+","+ship:geoposition:lat+","+ship:geoposition:lng) to log_ship.txt.
                //log("vel "+s_step["surfvel"]:mag) to log_sim.txt.
                //log("vel "+ship:VELOCITY:SURFACE:mag) to log_ship.txt.
                log heading_error to log.txt.
                log entry_turnside to log.txt.
                //clearVecDraws().
                //draw_vector(s_step["latlong"],s_step["altitude"],ship:geoposition,ship:altitude,RGB(1,1,0),"Prediction").
                //arrow_ship(s_step["position"],"Prediction").
                

            }
          
           
        }
        if calc_aoa() > dap["aoa"]["smooth_target_aoa"]+1 and ship:altitude < 55000{
            rcs on.
        }else{
            rcs off.
            
        }
        if ship:altitude < AVES["TEAMAltitude"]{
            reset_sys().
            set step to "TEAM".
            set Lastest_status to "TEAM".
            clearVecDraws().
            set dap["aoa"]["target_bank"] to 0.
            set dap["aoa"]["target_aoa"] to 0.
            
        }
    }  
    if step = "TEAM"{
        local hac is create_hac().
        if not(defined TEAM_in){
            set TEAM_in to lex(
            "step","s_trn",
            "enmgt",true,
            "active_hac",hac[choose_hac()["active_hac"]],
            "active_hac_dir",choose_hac()["HAC_Direction"],
            "apch_mode","ovh"
            ).
        }
        //log TEAM_in to log.txt.
        local Active_HAC is choose_hac().

        log "log_team" to log_team_sim.txt.
        local TEAM_guid_out is TEAM_guid(Team_in).
        if TEAM_guid_out["gear_cmd"]{
            gear on.
        }else{
            gear off.
        }
        if TEAM_guid_out["airbrake_cmd"]{
            brakes on.
        }else{
            brakes off.
        }

        set TEAM_in to TEAM_guid_out["team_input"].
        if TEAM_guid_out["team_input"]["step"]  = "s_trn" or TEAM_guid_out:s_trn{
            if heading_to_target(TEAM_guid_out["team_input"]["active_hac"]) - compass_for() > 0{
                set dap["str_mode"] to "aoa".
                set dap["aoa"]["target_bank"] to 55.
                set dap["aoa"]["target_aoa"] to 30.
            }else{
                set dap["str_mode"] to "aoa".
                set dap["aoa"]["target_bank"] to -55.
                set dap["aoa"]["target_aoa"] to 30.
            }
        
        }else if TEAM_guid_out["team_input"]["step"]  = "bef"{
            set dap["str_mode"] to "aoa".
            local pid is pidloop(0.39,0.33,0.5).
            set pid:maxoutput to 20.
            set pid:minoutput to 0.
            set TEAM_dist to calcdistance_m(hac["hac_ercl"],runway_start)+calc_circle_distance(AVES["HacRadius"],runway_heading-compass_for())+calcdistance_m(ship:geoposition,get_geoposition_on_circle(TEAM_guid_out["active_hac"],AVES["hacRadius"],TEAM_guid_out["active_hac_dir"],heading_to_target(TEAM_guid_out["team_input"]["active_hac"]))).
            set dap["aoa"]["target_bank"] to 0.
            set dap["aoa"]["target_aoa"] to 0.
            set TEAM_targetalt to calculate_glideslope_alt(TEAM_dist).
            local vvdot is calc_vvdot(TEAM_dist,SHIP:AIRSPEED,TEAM_targetalt,SHIP:ALTITUDE).
            set pid:setpoint to vvdot.
            set dap["aoa"]["base_pitch"] to PID:UPDATE(TIME:SECONDS, SHIP:verticalspeed).

        }ELSE IF TEAM_guid_out["team_input"]["step"]  = "in"{
            set dap["str_mode"] to "aoa".
            Aeroturn(heading_to_target(TEAM_guid_out["ercl_hac_latlong"]),TEAM_guid_out["team_input"]["active_hac_dir"],25).
        }else if TEAM_guid_out["team_input"]["step"]  = "ex"{
            set dap["str_mode"] to "aoa".
            local pid is pidloop(0.31,0.33,0.3).
            set pid:maxoutput to 20.
            set pid:minoutput to -20.
            set TEAM_dist to calcdistance_m(ship:geoposition,runway_start).
            Aeroturn(heading_to_target(TEAM_guid_out["algn_pos"]),"calc",5).
            set TEAM_targetalt to calculate_glideslope_alt(TEAM_dist).
            local vvdot is calc_vvdot(TEAM_dist,SHIP:AIRSPEED,TEAM_targetalt,SHIP:ALTITUDE).
            set pid:setpoint to vvdot.
            set dap["aoa"]["base_pitch"] to PID:UPDATE(TIME:SECONDS, SHIP:verticalspeed).

        }else if TEAM_guid_out["team_input"]["step"] = "fla"{
           

            if TEAM_guid_out["gs"]{
                local pid is pidloop(0.29,0.3,0.4).
                set pid:maxoutput to 20.
                set pid:minoutput to -10.
                set TEAM_dist to calcdistance_m(ship:geoposition,runway_start).
                Aeroturn(heading_to_target(TEAM_guid_out["algn_pos"]),"calc",5).
                set TEAM_targetalt to calculate_glideslope_alt(TEAM_dist).
                local vvdot is calc_vvdot(TEAM_dist,SHIP:AIRSPEED,TEAM_targetalt,SHIP:ALTITUDE).
                set pid:setpoint to vvdot.
                set dap["aoa"]["base_pitch"] to PID:UPDATE(TIME:SECONDS, SHIP:verticalspeed).
            }else{
                set dap["strmode"] to "aerostr".
                set dap["aerostr"]["aerostr_Roll"] to 0.
                set dap["aerostr"]["targetDirection"] to runway_heading.
                local t_t_a is time_to_alt(ship:altitude,ship:verticalspeed,runway_altitude).
                if t_t_a > 3{
                    local pid is pidloop(0.29,0.3,0.4).
                    set pid:maxoutput to 10.
                    set pid:minoutput to 0.

                    local vvdot is -10.
                    set pid:setpoint to vvdot.
                    set dap["aerostr"]["distance_pitch"] to PID:UPDATE(TIME:SECONDS, SHIP:verticalspeed).
                }else{
                    local pid is pidloop(0.29,0.3,0.4).
                    set pid:maxoutput to 10.
                    set pid:minoutput to 0.

                    local vvdot is -1.
                    set pid:setpoint to vvdot.
                    set dap["aerostr"]["distance_pitch"] to PID:UPDATE(TIME:SECONDS, SHIP:verticalspeed).
                }
            }

        }else if TEAM_guid_out["team_input"]["step"] = "ROL"{
            set dap["strmode"] to "aerostr".
            set dap["aerostr"]["distance_pitch"] to 0.
            set dap["aerostr"]["aerostr_Roll"] to 0.
            set dap["aerostr"]["targetDirection"] to runway_heading.
            brakes on.
            if ship:airspeed < 5{
                set step to "end".
            }
        }else{
            log "error: "+TEAM_guid_out:dump to log.txt.
        }

    }
    if step = "TEAM_old"{

       if not(defined Active_HAC) or not(defined hac_ercl){
        create_HAC().
        choose_hac().
        set in_hac to false.
        set log to 0.
        rcs off.
        set TEAM_Pitch_PID to pidloop(0.29,0.43,0.3). 
       }
       if log = 10 or log > 10{
       log_status(Lastest_status).
       set log to 0.
       }else{
        set log to log + 1.
       }
       
       if calcdistance(ship:geoposition,Active_HAC_entry) < old_hac_distance and in_hac = false{ //before HAC entry
            Aeroturn(heading_to_target(Active_HAC_entry),"calc",15).
            set TEAM_dist to calcdistance_m(hac_ercl,runway_start)+calc_circle_distance(AVES["HacRadius"],runway_heading-compass_for())+calcdistance_m(ship:geoposition,Active_HAC_entry).
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
       if in_hac and not(ex_hac){  // In HAC
            set Lastest_status to "entered hac".
            if HAC_Direction = "Clockwise"{
                aeroturn(runway_heading,"right").
            }
            if HAC_Direction = "Anticlockwise"{
                aeroturn(runway_heading,"left").
            }
            set TEAM_dist to calcdistance_m(hac_ercl,runway_start)+calc_circle_distance(AVES["HacRadius"],runway_heading-compass_for()).
            
            if ship:airspeed < 120{
                set dapthrottle to 1.
            }
            if ship:airspeed > 150{
                set dapthrottle to 0.
            }
       }
       
       if abs(compass_for()-runway_heading) < 10 and in_hac{
            set ex_hac to true.
            set dap["aerostr"]["targetRoll"] to 0. 
            
       }
       
       if ship:altitude < 12000{set console_mode to "TRAJ 3".}
       if ex_hac{
            set Lastest_status to "completed hac".
            if Reentry_mode ="EX"{
                clearVecDraws().
                draw_vector( get_geoposition_along_heading(runway_start,runway_heading+180,(calcdistance_m(ship:geoposition,runway_start))),TEAM_targetalt,runway_start,runway_altitude,RGB(1,0,0),"Glideslope").
                pos_arrow(get_geoposition_along_heading(runway_start,runway_heading+180,(calcdistance_m(ship:geoposition,runway_start))),"Glideslope",TEAM_targetalt).
            }
            aeroturn(heading_to_target(            
            get_geoposition_along_heading(        
            runway_start,        
            runway_heading+180,        
            (calcdistance_m(ship:geoposition,runway_start)*0.4))),"calc",10).


            set TEAM_dist TO  calcdistance_m(ship:geoposition,runway_start).
            if ship:airspeed < 100{
                set dapthrottle to 1.
            }
            if ship:airspeed > 140{
                set dapthrottle to 0.
            }
            if abs(heading_to_target(            
            get_geoposition_along_heading(        
            runway_start,        
            runway_heading+180,        
            (calcdistance_m(ship:geoposition,runway_start)*0.4))) -compass_for()) < 5{
                set dap["str_mode"] to "aerostr".
                set dap["aerostr"]["targetDirection"] to heading_to_target(            
                get_geoposition_along_heading(        
                runway_start,        
                runway_heading+180,        
                (calcdistance_m(ship:geoposition,runway_start)*0.4))).

            set dap["aerostr"]["targetRoll"] to 0. 
            set dap["aerostr"]["targetPitch"] to dap["aoa"]["base_pitch"].
            }else{
                set dap["str_mode"] to "aoa".                
            }
       }          
       set alt_ovr_runway to ship:altitude - runway_altitude.
       set TEAM_targetalt to calculate_glideslope_alt(TEAM_dist).
       local vvdot is calc_vvdot(TEAM_dist,SHIP:AIRSPEED,TEAM_targetalt,SHIP:ALTITUDE).
       global hud_vvdot is vvdot.
       if calcdistance_m(ship:geoposition,runway_start) < 500 or alt_ovr_runway < 100{SET TEAM_Pitch_PID:SETPOINT TO VVDOT. set TEAM_Pitch_PID to pidloop(0.19,0.43,0.3).}else{SET TEAM_Pitch_PID:SETPOINT TO VVDOT.}
       set TEAM_Pitch_PID:minoutput to -35.
       set TEAM_Pitch_PID:maxoutput to 10.
       set dap["aoa"]["base_pitch"] to TEAM_Pitch_PID:UPDATE(TIME:SECONDS, SHIP:verticalspeed).
       set dap["aerostr"]["distance_pitch"] to dap["aoa"]["base_pitch"].


       
       log("Team alt: "+TEAM_targetalt+" Team Pitch: "+ dap["aerostr"]["distance_pitch"]) to log.txt.
       

        if ship:altitude < 200{
            gear on.
        }
        if calcdistance_m(ship:geoposition,runway_start) < 200{
            set step to "landing".
            set dap["str_mode"] to "aerostr".

        }
        global rnw_dis_display is TEAM_dist.    
       // Transition to landing if conditions met
        if alt_ovr_runway < 100{
            set step to "landing".
            set dap["str_mode"] to "aerostr".
            log_status("Transitioning to landing phase").
        }


    }
    
    if step = "landing"{
        if calcdistance_m(ship:geoposition,runway_start) > 500{
            set step to "TEAM".

        }else{
        if Reentry_mode ="EX"{clearVecDraws().}

        log_status("Landing phase initiated").
        set alt_ovr_runway to ship:altitude - runway_altitude.
        
        
        set dapthrottle to 0.
        gear on.
        aggressive_overcorrect_for_prograde(runway_heading).
        if alt_ovr_runway > 25{
        if ship:airspeed > 160 {
            brakes on.
            log_status("Brakes ON, airspeed above 160").
        }
        if ship:airspeed < 100 {
            brakes off.
            log_status("Brakes Off, altitude below 100").
        }
    
        set dap["aerostr"]["distance_pitch"] to 0.
        }else{
            if not(defined old_alt){
                set old_alt to ship:altitude.
            }
            brakes on. 
            if old_alt > ship:altitude{
                set dap["aerostr"]["distance_pitch"] to 5.
            }else{
                set dap["aerostr"]["distance_pitch"] to 0.
            }
            
            aggressive_overcorrect_for_prograde(runway_heading).
            set dap["aerostr"]["aerostr_Roll"] to 0.
        if ship:airspeed < 5 {
            
            log_status("Landing completed").
        }
        if ship:airspeed < 1 {
            set step to "end".
            log_status("Landing completed, switching to end phase").
        }
    }    
    set old_alt to ship:altitude.
    aerostr().
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
    update_readouts().
    update_reentry_gui(e_gui_inputs).
    wait 0.
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
        wait 0.
    }
}