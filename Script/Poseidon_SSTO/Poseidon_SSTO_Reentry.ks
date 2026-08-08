// Poseidon_SSTO/Poseidon_SSTO_Reentry.ks
// Purpose: main reentry orchestration script.
// - Invokes libraries and GUI, calculates deorbit nodes and entry guidance.
// - Coordinates `dap` and entry solver to guide the vehicle to a chosen runway.
// Notes: header comments only; no code changed.
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
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/terminal_route.ks").

parameter force_tgt is lex("force",false,"Location","","Runway","").

IF SHIP:BODY:atm:exists{
//if ship:periapsis > 70000{
if not(force_tgt["force"]){
    setup_reentry_script().
}ELSE{
    setup_reentry_script(force_tgt["Location"],force_tgt["Runway"]).
}
local AI_SUPERVISED is false. // will log state and action data for supervised learning of the entry guidance model. Set to false to disable logging.
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
        "guid_spd", 0,
        "guid_alt", 0,
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
               
                // Prepare the TEAM interface and attempt to compute an entry trajectory.
                // - `define_TEAM_interface` builds the target box (altitude band, lat/lng center, tolerances).
                // - We log the target lat/long for debugging and then call `calc_entry_traj` with the
                //   current simulated state to search for a bank profile that will guide the vehicle
                //   into the TEAM box. If this succeeds, the returned `entry_traj` lexicon contains
                //   the converged simulation plan and bank angle.
                Global Team_interface  to define_TEAM_interface(runway_start,runway_heading,runway_altitude).
                log Team_interface["target_latlng"]  to log.txt.
                set entry_traj to calc_entry_traj(current_simstate(),Team_interface["target_altitude"],Team_interface["target_latlng"],Team_interface["team_interface_box"]).

                if entry_traj:converged{
                    // Entry solver converged: configure guidance to follow the planned bank profile.
                    // - Provide user feedback via Lastest_status and logs.
                    // - Disable the basic reentry fallback and initialize the alpha modulation PID.
                    // - Set PID output limits around the computed bank angle (entry_traj["bank"]).
                    // - Determine which side (left/right) the initial entry turn should use by comparing
                    //   the heading-to-target and prograde directions.
                    set Lastest_status to "Guidance Converged in "+entry_traj["iterations"]+" iterations".
                    update_readouts().
                    wait 3.
                    set Lastest_status to "bank is "+entry_traj["bank"].
                    log "bank is "+entry_traj["bank"] to log.txt.
                    set basice_reentry_guidance to false.
                    set alpha_md_pid to pidloop(0.26,0.31,0.65).
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
                    if entry_traj["error"]:HASKEY("min_bank"){
                    log entry_traj["error"]["min_bank"] to log.txt.
                    }
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
            if not (defined basice_reentry_guidance) {
                global basice_reentry_guidance is false.
            }
            
            // --- Fallback runway search / coarse entry plan ---------------------------------
            // This block runs when either:
            //  * the simplified/basic reentry guidance is enabled (`basice_reentry_guidance`),
            //  * or we do not currently have a computed `entry_traj` plan from the solver.
            //
            // Purpose:
            // 1) Produce a small set of forward-simulated endpoints (eg_pos_zone) that indicate the
            //    approximate reachability envelope for a set of common bank angles.
            // 2) Scan the `Location_constants` runway entries and find any runway whose start/end
            //    points lie inside that envelope (i.e. likely reachable without the full solver).
            // 3) If a candidate runway is found, set runway_start/runway_end/runway_altitude and
            //    assemble the `Team_interface` lexicon so later logic can attempt to compute a
            //    refined `entry_traj` or fall back to simpler guidance.
            //
            // Notes:
            // - This is intentionally conservative and coarse — it's a fallback when the solver
            //   isn't available or hasn't converged yet. The more accurate solver (`calc_entry_traj`)
            //   is still preferred when available.
            if basice_reentry_guidance or not(defined entry_traj){
                if not(defined val_tgt){
                    // Build a coarse reachability envelope by simulating a few bank endpoints.
                    // `eg_pos_zone` is a list of simulated final-state lexicons (one per test bank angle)
                    // produced by `entry_possible_square(current_simstate(), ...)`. Each element holds a
                    // `latlng` key that we test against runway points below.
                    global eg_pos_zone is entry_possible_square(current_simstate(),AVES["simulation"]["timestep"]).

                    // Create a mapping of location -> list(runway_numbers) by inspecting the
                    // keys in Location_constants["kerbin"]. Keys we care about end with "_start".
                    // Example key format: "location_runway_1_start". We split the key by '_' and
                    // use the first element as the location identifier and the third as the runway id.
                    local location_to_runways is lexicon().
                    local kerbin_runways is Location_constants["kerbin"].
                    for key in kerbin_runways:keys {
                    if key:endswith("_start") {                    
                        // Split the key to extract a location name and runway number.
                        local split_key is key:split("_").                   
                        if split_key:length >= 3 {              
                            local location_name is split_key[0].  
                            local runway_number is split_key[2].                  
                            if not location_to_runways:haskey(location_name) {
                                location_to_runways:add(location_name, list()).
                            }
                            location_to_runways[location_name]:add(runway_number).                
                        } else {                
                            // Guard: if a key doesn't match expected format, log it for debugging.
                            log "Warning: Key '" + key + "' does not follow expected format." to "0:/log.txt".
                        }
                    }
                }  
                local val_tgt_found is false.
                for loc in location_to_runways:keys {
                for runway in location_to_runways[loc] {
                    local runway_start_key is loc + "_runway_" + runway + "_start".
                    local runway_end_key is loc + "_runway_" + runway + "_end".
                    local runway_start_pos is Location_constants["kerbin"][runway_start_key].
                    local runway_end_pos is Location_constants["kerbin"][runway_end_key].
                    if check_target_in_square(runway_start_pos,eg_pos_zone[0]["latlng"],eg_pos_zone[1]["latlng"],eg_pos_zone[2]["latlng"],eg_pos_zone[3]["latlng"]){
                        // We found a runway candidate whose start/end falls inside the reachability envelope.
                        // The code below extracts the runway metadata (altitude and start/end positions) from
                        // the `Location_constants` and `KerbinRunwayalt` tables.
                        local a is Loc+"_runway". set runway_altitude to KerbinRunwayalt[a].
                        local b is Loc+"_runway_"+runway+"_start".
                        local c is Loc+"_runway_"+runway+"_end".
                        if Location_constants:HASKEY("kerbin") {
                            local kerbin_runways is Location_constants["kerbin"].
                            if kerbin_runways:HASKEY(b) {
                                set runway_start to kerbin_runways[b].
                            } else {
                                LOG "Key " + b + " not found in kerbin_runways." TO "log.txt".
                            }
                            if kerbin_runways:HASKEY(c) {
                                set runway_end to kerbin_runways[c].
                            } else {
                                LOG "Key " + c + " not found in kerbin_runways." TO "log.txt".
                            }
                        } else {
                            LOG "Key 'kerbin' not found in Location_constants." TO "log.txt".
                        }
                        set val_tgt_found to true.
                        break.
                    }
                    
                }
                set dap["str_mode"] to "aoa". 
                set dap["aoa"]["target_aoa"]  to AVES["EGAOA"].
                set dap["aoa"]["target_bank"] to 0.
                dap:update().
                }
                if defined Team_interface{
                    set Team_interface to define_TEAM_interface(runway_start,runway_heading,runway_altitude).
                }else{
                    GLOBAL Team_interface to define_TEAM_interface(runway_start,runway_heading,runway_altitude).
                }
                if defined entry_traj{
                    if time_to_alt(ship:altitude,ship:verticalspeed,AVES["simulation"]["entry_ref_alt"]) < 10{
                        set entry_traj to calc_entry_traj(current_simstate(),Team_interface["target_altitude"],Team_interface["target_latlng"],Team_interface["team_interface_box"],"time",10).   
                    }else{
                        set entry_traj to calc_entry_traj(current_simstate(),Team_interface["target_altitude"],Team_interface["target_latlng"],Team_interface["team_interface_box"]).   
                    }
                }else{
                    if time_to_alt(ship:altitude,ship:verticalspeed,AVES["simulation"]["entry_ref_alt"]) < 10{
                        global entry_traj to calc_entry_traj(current_simstate(),Team_interface["target_altitude"],Team_interface["target_latlng"],Team_interface["team_interface_box"],"time",10).
                    }else{
                        GLOBAL entry_traj to calc_entry_traj(current_simstate(),Team_interface["target_altitude"],Team_interface["target_latlng"],Team_interface["team_interface_box"]).   
                    }          
                }     
                    

                }
            }else{
                local l is lex().
                for t in entry_traj["converged_sim"]["controll_inputs"]:keys{
                    l:add(t,calcdistance_m(Team_interface["target_latlng"],entry_traj["converged_sim"]["controll_inputs"][t]["simstate"]["latlong"])).
                }
                //get closest time step to target latlng
                local t_ is FindClosestTimeStep(l,calcdistance_m(ship:geoposition,Team_interface["target_latlng"])).
                // get second closest time step to target latlng
                l:remove(findkeywithvalue(l,t_)).
                local t2_ is findClosestTimeStep(l,calcdistance_m(ship:geoposition,Team_interface["target_latlng"])).

                local cur_target_dist is calcdistance_m(ship:geoposition, Team_interface["target_latlng"]).
                local d1 is calcdistance_m(entry_traj["converged_sim"]["controll_inputs"][t_]["simstate"]["latlong"], Team_interface["target_latlng"]).
                local d2 is calcdistance_m(entry_traj["converged_sim"]["controll_inputs"][t2_]["simstate"]["latlong"], Team_interface["target_latlng"]).

                // Weight by inverse distance from the current distance (small eps to avoid div0)
                local eps is 0.00001.
                local w1 is 1 / (abs(d1 - cur_target_dist) + eps).
                local w2 is 1 / (abs(d2 - cur_target_dist) + eps).
                local s_step1 is entry_traj["converged_sim"]["controll_inputs"][t_]["simstate"].
                local s_step2 is entry_traj["converged_sim"]["controll_inputs"][t2_]["simstate"].

                local wsum is w1 + w2.
                if wsum = 0 { set wsum to eps. }.

                // Create a weighted average s_step from both simulation states
                // Compute weighted average latitude and longitude separately
                local avg_lat is (s_step1["latlong"]:lat * w1 + s_step2["latlong"]:lat * w2) / wsum.
                local avg_lng is (s_step1["latlong"]:lng * w1 + s_step2["latlong"]:lng * w2) / wsum.
                
                local s_step is lex(
                    "simtime", (s_step1["simtime"] * w1 + s_step2["simtime"] * w2) / wsum,
                    "position", (s_step1["position"] * w1 + s_step2["position"] * w2) / wsum,
                    "velocity", (s_step1["velocity"] * w1 + s_step2["velocity"] * w2) / wsum,
                    "surfvel", (s_step1["surfvel"] * w1 + s_step2["surfvel"] * w2) / wsum,
                    "altitude", (s_step1["altitude"] * w1 + s_step2["altitude"] * w2) / wsum,
                    "latlong", latlng(avg_lat, avg_lng)
                ).

                local e_ref is calculate_spacecraft_energy(s_step["altitude"], s_step["surfvel"]:mag, 2.5, 0.9).
                local e_dot is calculate_spacecraft_energy(ship:altitude,ship:airspeed,2.5,0.9).
                set alpha_md_pid:setpoint to e_ref.
                
                set e_gui_inputs["guid_alt"] to s_step["altitude"].
                set e_gui_inputs["guid_spd"] to s_step["surfvel"]:mag.

                //set d_e to the % difference between the current energy and the reference energy.
                
                Global d_e to (e_ref - e_dot) / e_ref.

                set dap["aoa"]["target_aoa"]  to AVES["EGAOA"].
                //local d_dot is 0.
                //local cur_d_dot is cur_aeroforce_ld()["drag"].         
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
                if time_to_pos(ship:geoposition,Team_interface["target_latlng"],ship:airspeed) < 35{
                    set dap["aoa"]["target_aoa"] to max(time_to_pos(ship:geoposition,Team_interface["target_latlng"],ship:airspeed) / 1.5,5).
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
                
                //log ("target_aoa"+dap["aoa"]["target_bank"]) to log.txt.
                //log(s_step["altitude"]+","+s_step["latlong"]:lat+","+s_step["latlong"]:lng) to log_sim.txt.
                //log(ship:altitude+","+ship:geoposition:lat+","+ship:geoposition:lng) to log_ship.txt.
                //log("vel "+s_step["surfvel"]:mag) to log_sim.txt.
                //log("vel "+ship:VELOCITY:SURFACE:mag) to log_ship.txt.
                //log heading_error to log.txt.
                //log entry_turnside to log.txt.
                //clearVecDraws().
                //draw_vector(s_step["latlong"],s_step["altitude"],ship:geoposition,ship:altitude,RGB(1,1,0),"Prediction").
                //arrow_ship(s_step["position"],"Prediction").

                set facing_vec to ship:facing:vector.
                if not (defined old_facing_vec){
                    set old_facing_vec to facing_vec.
                }
                set ship_rotate to facing_vec - old_facing_vec.
                log ship:altitude +","+ ship:velocity:surface:x +","+ ship:velocity:surface:y +"," + ship:velocity:surface:z +","+ ship:sensors:acc:x +","+ ship:sensors:acc:y +","+ ship:sensors:acc:z +","+ship:facing:vector:x +","+ ship:facing:vector:y +","+ ship:facing:vector:z +","+ roll_for() +","+ ship:mass +","+ ship_rotate:x +","+ ship_rotate:y +","+ ship_rotate:z +","+ runway_start:position:x +","+ runway_start:position:y +","+ runway_start:position:z +","+ runway_end:position:x +","+ runway_end:position:y +","+ runway_end:position:z to POS_AI_LOG_SUPERVISED.txt.
                log dapthrottle +","+ dap["aoa"]["target_aoa"]+","+dap["aoa"]["target_bank"]+","+ dap["aoa"]["base_pitch"] +","+ gear+","+brakes to POS_AI_LOG_SUPERVISED.txt.
                set old_facing_vec to facing_vec.
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
            rcs on.
            clearVecDraws().
            set dap["aoa"]["target_bank"] to 0.
            set dap["str_mode"] to "aoa".
            
        }
    }  
    if step = "TEAM"{
        if not(defined terminal_route){
            set terminal_route to terminal_route_init().
            clearVecDraws().
        }
        set terminal_route to terminal_route_update(terminal_route).
        terminal_route_fly(terminal_route).

        if terminal_route["gear"]{
            gear on.
        }else{
            gear off.
        }
        if terminal_route["airbrake"]{
            brakes on.
        }else{
            brakes off.
        }

        set TEAM_dist to terminal_route["remaining_distance"].
        set TEAM_targetalt to terminal_route["target_altitude"].
        set hud_vvdot to (TEAM_targetalt - ship:altitude) / max(TEAM_dist / max(ship:airspeed,80),5).
        if terminal_route["landing_ready"]{
            set step to "landing".
            set dap["str_mode"] to "aerostr".
        }
    }
    if step = "TEAM_TEST"{
        local hac is create_hac().
        if not(defined TEAM_in){
            set TEAM_in to lex(
            "step","bef",
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
        if TEAM_guid_out["team_input"]["step"]  = "bef"{
            set dap["str_mode"] to "aoa".
            local pid is pidloop(0.39,0.33,0.5).
            set pid:maxoutput to 20.
            set pid:minoutput to 0.
            set TEAM_dist to calcdistance_m(hac["hac_ercl"],runway_start)+calc_circle_distance(AVES["HacRadius"],runway_heading-compass_for())+calcdistance_m(ship:geoposition,get_geoposition_on_circle(TEAM_guid_out["active_hac"],AVES["hacRadius"],TEAM_guid_out["active_hac_dir"],heading_to_target(TEAM_guid_out["team_input"]["active_hac"]))).
            Aeroturn(heading_to_target(TEAM_guid_out["hac_entry_pos"]),"calc",5).
            set TEAM_targetalt to calculate_glideslope_alt(TEAM_dist/0.5).
            local vvdot is calc_vvdot(TEAM_dist/0.5,SHIP:AIRSPEED,TEAM_targetalt,SHIP:ALTITUDE).
            set pid:setpoint to vvdot.
            set dap["aoa"]["base_pitch"] to PID:UPDATE(TIME:SECONDS, SHIP:verticalspeed).

        }ELSE IF TEAM_guid_out["team_input"]["step"]  = "in"{
            set dap["str_mode"] to "aoa".
            local pos is 0.
            local rad is 0.
            if TEAM_guid_out["active_hac_dir"] = "clockwise"{
                set pos to get_geoposition_on_circle(TEAM_guid_out["active_hac"],AVES["hacRadius"],TEAM_guid_out["active_hac_dir"],min(compass_for_prograde()-20,runway_heading)).
                set rad to calc_turn_radius(ship:geoposition,compass_for_prograde(),pos,min(compass_for_prograde()-20,runway_heading)).
            }else{
                set pos to get_geoposition_on_circle(TEAM_guid_out["active_hac"],AVES["hacRadius"],TEAM_guid_out["active_hac_dir"],max(compass_for_prograde()+20,runway_heading)).
                set rad to calc_turn_radius(ship:geoposition,compass_for_prograde(),pos,max(compass_for_prograde()+20,runway_heading)).
            }            
            Aeroturn(heading_to_target(TEAM_guid_out["ercl_hac_latlong"]),TEAM_guid_out["team_input"]["active_hac_dir"],10,rad).
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
    if step = "TEAM_MAIN_GUID"{

        if ship:altitude < 10000{set console_mode to "TRAJ 3".}
        set rnw_dis_display to calcdistance_m(ship:geoposition,runway_start).
        local rnw is lex(
            "runway_start",runway_start,
            "runway_end",runway_end,
            "runway_heading",runway_heading,
            "runway_altitude",runway_altitude
        ).
        local ercl_lineup is lex(
            "ercl_fnl_latlong",get_geoposition_along_heading(runway_start,runway_heading+180,AVES["HacDistance"]),
            "ercl_fnl_alt", calculate_glideslope_alt(AVES["HacDistance"]),
            "ercl_fnl_spd", 200
        ).
        if not(defined Team_mode){
       set Team_mode to "Tra". // Tra /BEF /fnl / FLA
       if  ship:altitude < Aves["TeamAltitude"] - 1000{
        SET Team_mode TO "bef".
        }
       if ship:altitude < ercl_lineup["ercl_fnl_alt"]{
        SET Team_mode TO "FNL".
        }if  ship:altitude < runway_altitude + 100{
        SET Team_mode TO "FLA".
        }
    }
    if not(defined low_trn){
        set low_trn to false.

    }
    If step = "TEAM_MAIN_GUID" and Team_mode = "Tra"{
        rcs on.
        brakes on.
        set dap["str_mode"] to "aoa".
        set dap["aoa"]["target_bank"] to 0.
        if not(defined TEAM_Transition_AOA){
            set TEAM_Transition_AOA to calc_aoa().
        }
        if calc_aoa() > TEAM_Transition_AOA{
            set TEAM_Transition_AOA to calc_aoa().
        }
        // Gradually reduce target AOA to transition value
        // at TEAM altitude (25000) should be TEAM_Transition_AOA
        // at Team atitude -1000 should be 5 degrees
        set dap["aoa"]["target_aoa"] to max(5, TEAM_Transition_AOA * ((ship:altitude - (AVES["TeamAltitude"] - 1000)) / 1000)).



        if ship:altitude < AVES["TeamAltitude"] - 1000{
            set Team_mode to "bef".

        }
    }
    IF step = "TEAM_MAIN_GUID" and Team_mode = "bef"{
        set dap["str_mode"] to "aoa".
        IF NOT(defined START_DIST){
            set START_DIST to calcdistance_m(ship:geoposition,ercl_lineup["ercl_fnl_latlong"]).
           
        }
        if not(defined start_spd){
            set start_spd to ship:airspeed.
        }
        local cur_dist is calcdistance_m(ship:geoposition,ercl_lineup["ercl_fnl_latlong"]).
        local cur_spd is ship:airspeed.

        local needed_spd is start_spd * (cur_dist / START_DIST).
        if needed_spd < 180{
            set needed_spd to 180.
        }
        local team_aoa_cmd is 0.
        if cur_spd <= needed_spd{
            brakes off.
            set team_aoa_cmd to 5.
        }if cur_spd <= needed_spd+20{
            brakes off.
            set team_aoa_cmd to 10.
        }if cur_spd > needed_spd+20{
            brakes on.
            set team_aoa_cmd to 10.
        }
        aeroturn(heading_to_target(ercl_lineup["ercl_fnl_latlong"]),"calc",team_aoa_cmd).

        set vs_dot to calc_vvdot(cur_dist, cur_spd, ercl_lineup["ercl_fnl_alt"], ship:altitude).
        if not (defined vs_pis){
            set vs_pis to pidloop(0.29,0.43,0.3).
        }
        set vs_pis:maxoutput to 20.
        set vs_pis:minoutput to -30.
        set vs_pis:setpoint to vs_dot.
        set hud_vvdot to vs_dot.
        set dap["aoa"]["base_pitch"] to vs_pis:update(time:seconds, ship:verticalspeed).
        // Linear transition: if heading difference is 0, switch at 0m; if 180, switch at 5000m
        local heading_diff is abs(compass_for() - rnw["runway_heading"]).
        if heading_diff > 180 { set heading_diff to 360 - heading_diff. }
        local switch_dist is AVES["HacDistance"] * (heading_diff / 180).

        if cur_dist < switch_dist {
            set Team_mode to "FNL".
            if ship:altitude < calculate_glideslope_alt(calcdistance_m(ship:geoposition, rnw["runway_start"])) {
                set low_trn to true.
            }
        }
        }


if step = "TEAM_MAIN_GUID" and Team_mode = "FNL" {
    if abs(heading_to_target(rnw["runway_start"]) - rnw["runway_heading"]) < 2 and abs(compass_for_prograde() - rnw["runway_heading"]) < 2 {
        dap:set_aerostr_auto().

    }else{
        dap:set_aoa_auto().
    }

    // Calculate target position
    local dist_to_rnw is calcdistance_m(ship:geoposition, rnw["runway_start"]).

    local tgt_pos is get_geoposition_along_heading(
        rnw["runway_start"],
        rnw["runway_heading"] + 180,
        dist_to_rnw * 0.7
    ).

    // Calculate target altitude
    local dist_to_tgt is calcdistance_m(ship:geoposition, tgt_pos).

    local tgt_alt is calculate_glideslope_alt(dist_to_tgt) +50.
    set alt_ovr_runway to ship:altitude - runway_altitude.
    set vs_dot to calc_vvdot(dist_to_tgt, ship:airspeed, tgt_alt, ship:altitude).

    if not (defined vs_pis) {
        set vs_pis to pidloop(0.25,0.6,0.4).
    }
    if low_trn and ship:altitude + 100 < calculate_glideslope_alt(calcdistance_m(ship:geoposition, rnw["runway_start"])) {
        set vs_dot to 0.
        
        
    }else if low_trn{
        vs_pis:reset().
    }else{
        set low_trn to false.
    }
    set vs_pis:maxoutput to 15.
    set vs_pis:minoutput to -20.
    if vs_dot > 10 {
        set vs_dot to 0.
        
    }
    set vs_pis:setpoint to vs_dot.
    set hud_vvdot to vs_dot.
    

    if dap["str_mode"] = "aerostr"{
        set dap["aerostr"]["targetDirection"] to heading_to_target(tgt_pos).
        set dap["aerostr"]["targetRoll"] to 0.
        set dap["aerostr"]["distance_pitch"] to vs_pis:update(time:seconds, ship:verticalspeed).
        if ship:airspeed > 150 and dap["aerostr"]["distance_pitch"] < 2{
            brakes on.
        } else {
            brakes off.
        }
        if ship:airspeed > 190{
            brakes on.
        }
    }else{
        set dap["aoa"]["base_pitch"] to vs_pis:update(time:seconds, ship:verticalspeed).
        aeroturn(heading_to_target(tgt_pos), "calc", 5).
        if ship:airspeed > 150 and dap["aoa"]["base_pitch"] < 2{
            brakes on.
        } else {
            brakes off.
        }
        if ship:airspeed > 190{
            brakes on.
        }
    }

    if ship:altitude < rnw["runway_altitude"] + 100 or calcdistance_m(ship:geoposition, runway_start) < 500 {
        set Team_mode to "FLA".
    }
}
    if step = "TEAM_MAIN_GUID" and Team_mode = "FLA"{
        set dap["str_mode"] to "aerostr".
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
        IF SHIP:verticalspeed > 0 {
            set dap["aerostr"]["distance_pitch"] to 0.
        }ELSE IF SHIP:verticalspeed > -1 {
            set dap["aerostr"]["distance_pitch"] to 3.
        }ELSE IF SHIP:verticalspeed > -2 {
            set dap["aerostr"]["distance_pitch"] to 5.
        }ELSE IF SHIP:verticalspeed > -3 {
            set dap["aerostr"]["distance_pitch"] to 6.
        }ELSE IF SHIP:verticalspeed > -3 {
            set dap["aerostr"]["distance_pitch"] to 8.
        }ELSE IF SHIP:verticalspeed > -4 {
            set dap["aerostr"]["distance_pitch"] to 10.
        }ELSE{
            set dap["aerostr"]["distance_pitch"] to 15.}
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
                if dap["str_mode"] = "aoa"{
                set facing_vec to ship:facing:vector.
                if not (defined old_facing_vec){
                    set old_facing_vec to facing_vec.
                }
                set ship_rotate to facing_vec - old_facing_vec.
                log ship:altitude +","+ ship:velocity:surface:x +","+ ship:velocity:surface:y +"," + ship:velocity:surface:z +","+ ship:sensors:acc:x +","+ ship:sensors:acc:y +","+ ship:sensors:acc:z +","+ship:facing:vector:x +","+ ship:facing:vector:y +","+ ship:facing:vector:z +","+ roll_for() +","+ ship:mass +","+ ship_rotate:x +","+ ship_rotate:y +","+ ship_rotate:z +","+ runway_start:position:x +","+ runway_start:position:y +","+ runway_start:position:z +","+ runway_end:position:x +","+ runway_end:position:y +","+ runway_end:position:z to POS_AI_LOG_SUPERVISED.txt.
                log dapthrottle +","+ dap["aoa"]["target_aoa"]+","+dap["aoa"]["target_bank"]+","+ dap["aoa"]["base_pitch"] +","+ gear+","+brakes to POS_AI_LOG_SUPERVISED.txt.
                set old_facing_vec to facing_vec.
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
