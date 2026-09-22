// Poseidon_SSTO/Poseidon_SSTO_Reentry.ks
// Purpose: main reentry orchestration script.
// - Invokes libraries and GUI, calculates deorbit nodes and entry guidance.
// - Coordinates `dap` and entry solver to guide the vehicle to a chosen runway.
set CONFIG:IPU to 2000.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").
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
if not SHIP:BODY:atm:exists {
    // Airless operations are intentionally not an alternate branch of entry
    // guidance.  The dedicated program owns its NERV-only deorbit, powered
    // descent, coordinate target, and tail-to-gear touchdown sequence.
    clearScreen.
    print "Reentry requires an atmosphere.".
    print "For an airless body run 0:/Poseidon_SSTO/Poseidon_SSTO_Vacuum_Landing.ks.".
}else{
flight_log_begin("reentry").
if not(defined recovery_result) {
    global recovery_result is lex("complete",false,"success",false,"reason","running").
}else{
    set recovery_result to lex("complete",false,"success",false,"reason","running").
}
//if ship:periapsis > 70000{
if not(force_tgt["force"]){
    setup_reentry_script().
}ELSE{
    setup_reentry_script(force_tgt["Location"],force_tgt["Runway"]).
}
//}
set deorbit_periapsis_set_flag to false.
set landing_flare_started to false.
global entry_reference_time is -1.
global entry_predictive_bank is 0.
global entry_predictive_plan_bank is 0.
global entry_predictive_next_update is -1.
global entry_predictive_lower_bank is 0.
global entry_predictive_upper_bank is 0.
global entry_predictive_lower_miss is 0.
global entry_predictive_upper_miss is 0.
global entry_predictive_lower_range_error is 0.
global entry_predictive_upper_range_error is 0.
global entry_predictive_sensitivity is 0.
global entry_predictive_valid is false.
global entry_predictive_frozen is false.
global entry_team_closest_distance is 999999999.
global entry_team_gate_since is -1.
global team_handoff_transition_active is false.
global team_handoff_transition_start is 0.
global team_handoff_start_aoa is 0.
global team_handoff_start_bank is 0.
dap:setup().
set console_mode to "DATA".
until running = false{
    update_readouts().
    dap:update().
    // The TEAM interface is created only after the entry target is planned.
    // Keep the display input harmless during earlier deorbit/setup ticks.
    local entry_display_range_remaining is 0.
    if defined Team_interface {
        if Team_interface:haskey("target_latlng") {
            set entry_display_range_remaining to calcdistance_m(
                ship:geoposition, Team_interface["target_latlng"]
            ).
        }
    }
    local e_gui_inputs is lex(
        "mode", console_mode,
        "alt", ship:altitude,
        "spd", ship:airspeed,
        "guid_spd", 0,
        "guid_alt", 0,
        "guid_pos", 0,
        "guid_pos_valid", false,
        "range_remaining", entry_display_range_remaining,
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
            if not (defined entry_square_display){ 
                print("hey").
                set entry_begin_state to simulate_trajectory(current_simstate(), 0, "right", AVES["MaxAeroturnAlt"],ship:altitude+100,"EGAOA",AVES["simulation"]["timestep"]).
                print("calculating entry square").
                set entry_square_display to entry_possible_square(entry_begin_state,AVES["simulation"]["timestep"]+5).
                for i in entry_square_display{
                    //shift I latlng to account for planet rotation uning I["simtime"] and planet rotation rate
                    local rotation_rate is ship:body:rotationperiod / 360. // degrees per second
                    set i["latlong"] to latlng(i["latlong"]:lat, i["latlong"]:lng + (i["simtime"] * rotation_rate)).
                    pos_arrow(i["latlong"],"",AVES["MaxAeroturnAlt"]*10,0.2).
                }
            }
            set Lastest_status to "coasting".
        }
        if ship:altitude < 75000 and ship:altitude > 74000{
            set Lastest_status to "reentry guidance".
            clearVecDraws().
        }
        if ship:altitude < 75000 and ship:altitude > 65000{
            
            reset_sys().
            nervsoff().
            rapierson().
            set dap["str_mode"] to "aoa". 
            set dap["aoa"]["target_aoa"]  to AVES["EGAOA"](ship:altitude).
            set dap["aoa"]["target_bank"] to 0.
            set ecrl_2hac to get_geoposition_along_heading(runway_start,runway_heading+180,Aves["HacDistance"]*2).
            if calcdistance(ship:geoposition,runway_start) > calcdistance(ship:geoposition,ecrl_2hac){
                set reentry_target to runway_start.
            }else{set reentry_target to ecrl_2hac.}
            update_readouts().
            if not(defined entry_traj){
               
                // Prepare the TEAM interface and attempt to compute an entry trajectory.
                // - `define_TEAM_interface` builds the target box (altitude band, lat/lng center, tolerances).
                // - We record the target outside the solver, then call `calc_entry_traj` with the
                //   current simulated state to search for a bank profile that will guide the vehicle
                //   into the TEAM box. If this succeeds, the returned `entry_traj` lexicon contains
                //   the converged simulation plan and bank angle.
                Global Team_interface  to define_TEAM_interface(runway_start,runway_heading,runway_altitude).
                flight_log_set_entry_target(Team_interface).
                set entry_traj to calc_entry_traj(current_simstate(),Team_interface["target_altitude"],Team_interface["target_latlng"],Team_interface["team_interface_box"]).
                flight_log_entry_solver_result(entry_traj).
                set entry_reference_time to -1.

                if entry_traj:converged{
                    // Entry solver converged: configure guidance to follow the planned bank profile.
                    // - Provide user feedback via Lastest_status and logs.
                    // - Disable the basic reentry fallback and initialize the live-state
                    //   two-candidate predictive bank controller from the computed bank.
                    // - Determine which side (left/right) the initial entry turn should use by comparing
                    //   the heading-to-target and prograde directions.
                    set Lastest_status to "Guidance Converged in "+entry_traj["iterations"]+" iterations".
                    update_readouts().
                    wait 3.
                    set Lastest_status to "bank is "+entry_traj["bank"].
                    set basice_reentry_guidance to false.
                    set entry_predictive_plan_bank to entry_traj["bank"].
                    set entry_predictive_bank to entry_traj["bank"].
                    set entry_predictive_next_update to time:seconds+10.
                    local heading_error is heading_to_target(Team_interface["target_latlng"]) - compass_for_prograde().
                    if heading_error > 0{
                        set entry_turnside to "right".
                    }else{
                        set entry_turnside to "left".
                    }

                }else{
                    set Lastest_status to "Guidance algorithm failed to converge.".
                    update_readouts().
                    wait 5.
                    set Lastest_status to "Switching to basic reentry guidance protocol".
                    update_readouts().
                    set basice_reentry_guidance to true.
                }
            }
            
            

        }
        // The V/SIT is one energy/range corridor split into five zoomed energy
        // bands. Values outside the 100-290 km display span stay clamped on
        // the nearest edge while the logger records every live transition.
        if step = "reentry_low" or step = "reentry_mid" or
           step = "reentry_high" or step = "reentry_int" {
            if ship:altitude < 70000 {
                local entry_display_energy_height is entry_nominal_energy_height(
                    ship:altitude, ship:airspeed
                ).
                if entry_display_energy_height >= 260000 {
                    set console_mode to "TRAJ 1 V/SIT".
                } else if entry_display_energy_height >= 210000 {
                    set console_mode to "TRAJ 2 V/SIT".
                } else if entry_display_energy_height >= 170000 {
                    set console_mode to "TRAJ 3 V/SIT".
                } else if entry_display_energy_height >= 140000 {
                    set console_mode to "TRAJ 4 V/SIT".
                } else {
                    set console_mode to "TRAJ 5 V/SIT".
                }
            }
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
                            // Preserve malformed-data diagnostics in the event CSV.
                            flight_log_event("runway_key_invalid","key=" + key).
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
                                flight_log_event("runway_lookup_failed","key=" + b).
                            }
                            if kerbin_runways:HASKEY(c) {
                                set runway_end to kerbin_runways[c].
                            } else {
                                flight_log_event("runway_lookup_failed","key=" + c).
                            }
                        } else {
                            flight_log_event("runway_lookup_failed","key=kerbin").
                        }
                        set val_tgt_found to true.
                        break.
                    }
                    
                }
                set dap["str_mode"] to "aoa". 
                set dap["aoa"]["target_aoa"]  to AVES["EGAOA"](ship:altitude).
                set dap["aoa"]["target_bank"] to 0.
                dap:update().
                }
                if defined Team_interface{
                    set Team_interface to define_TEAM_interface(runway_start,runway_heading,runway_altitude).
                }else{
                    GLOBAL Team_interface to define_TEAM_interface(runway_start,runway_heading,runway_altitude).
                }
                flight_log_set_entry_target(Team_interface).
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
                flight_log_entry_solver_result(entry_traj).
                set entry_reference_time to -1.
                    

                }
            }else{
                local reference_segment is find_entry_reference_segment(entry_traj["converged_sim"]["controll_inputs"],ship:geoposition,entry_reference_time).
                if not reference_segment["valid"] {
                    set entry_reference_time to -1.
                    set reference_segment to find_entry_reference_segment(entry_traj["converged_sim"]["controll_inputs"],ship:geoposition).
                }
                local t_ is reference_segment["start_time"].
                local t2_ is reference_segment["end_time"].
                local reference_fraction is reference_segment["fraction"].
                set entry_reference_time to t_.
                local s_step1 is entry_traj["converged_sim"]["controll_inputs"][t_]["simstate"].
                local s_step2 is entry_traj["converged_sim"]["controll_inputs"][t2_]["simstate"].

                // Blend continuously along the selected adjacent path segment.
                local avg_lat is s_step1["latlong"]:lat+(s_step2["latlong"]:lat-s_step1["latlong"]:lat)*reference_fraction.
                local avg_lng is s_step1["latlong"]:lng+(s_step2["latlong"]:lng-s_step1["latlong"]:lng)*reference_fraction.
                
                local s_step is lex(
                    "simtime", s_step1["simtime"]+(s_step2["simtime"]-s_step1["simtime"])*reference_fraction,
                    "position", s_step1["position"]+(s_step2["position"]-s_step1["position"])*reference_fraction,
                    "velocity", s_step1["velocity"]+(s_step2["velocity"]-s_step1["velocity"])*reference_fraction,
                    "surfvel", s_step1["surfvel"]+(s_step2["surfvel"]-s_step1["surfvel"])*reference_fraction,
                    "altitude", s_step1["altitude"]+(s_step2["altitude"]-s_step1["altitude"])*reference_fraction,
                    "latlong", latlng(avg_lat, avg_lng)
                ).

                // Interpolate the two nearest reference energies directly.
                // Energy is quadratic in speed, so calculating it from the
                // blended state creates a non-linear target and visible d_e
                // changes as the selected trajectory samples advance.
                local e_ref1 is calculate_spacecraft_energy(s_step1["altitude"], s_step1["surfvel"]:mag).
                local e_ref2 is calculate_spacecraft_energy(s_step2["altitude"], s_step2["surfvel"]:mag).
                local e_ref is e_ref1+(e_ref2-e_ref1)*reference_fraction.
                local e_dot is calculate_spacecraft_energy(ship:altitude,ship:airspeed).
                set e_gui_inputs["guid_alt"] to s_step["altitude"].
                set e_gui_inputs["guid_spd"] to s_step["surfvel"]:mag.
                set e_gui_inputs["guid_pos"] to s_step["latlong"].
                set e_gui_inputs["guid_pos_valid"] to true.

                //set d_e to the % difference between the current energy and the reference energy.
                
                Global d_e to (e_ref - e_dot) / e_ref.

                set dap["aoa"]["target_aoa"]  to AVES["EGAOA"](ship:altitude).
                //local d_dot is 0.
                //local cur_d_dot is cur_aeroforce_ld()["drag"].         
                //set d_dot to aeroforce_ld(s_step["position"],s_step["surfvel"],list(AVES["EGAOA"],ba))["drag"].
                //set alpha_md_pid:setpoint to d_dot.

                local heading_error is heading_to_target(Team_interface["target_latlng"]) - compass_for_prograde().
                if heading_error > AVES["EG_rev°"]{
                    set entry_turnside to "right".
                }else if heading_error < -AVES["EG_rev°"]{
                    set entry_turnside to "left".
                }
                // Every ten seconds, simulate two complete trajectories from one
                // snapshot of the current live state. Their TEAM-box miss
                // distances choose the better candidate. The initial trajectory bank
                // remains the center of the overall authority envelope.
                if time:seconds >= entry_predictive_next_update {
                    local prediction_start_time is time:seconds.
                    set entry_predictive_next_update to prediction_start_time+10.
                    local prediction_start is current_simstate().
                    // Keep the body/model scalars consistent between candidates.
                    // Do not freeze SHIP:FACING: sim_aeroaccel_load deliberately
                    // samples the latest live vessel axes on every integration
                    // step for FAR and the Rodrigues force transformations.
                    local prediction_mu is BODY:mu.
                    local prediction_radius is BODY:radius.
                    local prediction_angularvel is BODY:angularvel.
                    local prediction_mass is SHIP:MASS.
                    local prediction_authority is AVES["EG_am_range"].
                    local prediction_minimum_bank is max(0,entry_predictive_plan_bank-prediction_authority).
                    local prediction_maximum_bank is min(90,entry_predictive_plan_bank+prediction_authority).
                    set entry_predictive_lower_bank to max(prediction_minimum_bank,entry_predictive_bank-3).
                    set entry_predictive_upper_bank to min(prediction_maximum_bank,entry_predictive_bank+3).

                    local prediction_low is sim_with_bank(
                        clone_simstate(prediction_start),entry_predictive_lower_bank,
                        Team_interface["target_altitude"],Team_interface["target_latlng"],AVES["simulation"]["timestep"],
                        prediction_mu,prediction_radius,prediction_angularvel,prediction_mass,
                        SHIP:FACING:FOREVECTOR:NORMALIZED,SHIP:FACING:TOPVECTOR:NORMALIZED,
                        VCRS(SHIP:FACING:TOPVECTOR:NORMALIZED,SHIP:FACING:FOREVECTOR:NORMALIZED):NORMALIZED,true
                    ).
                    local prediction_high is sim_with_bank(
                        clone_simstate(prediction_start),entry_predictive_upper_bank,
                        Team_interface["target_altitude"],Team_interface["target_latlng"],AVES["simulation"]["timestep"],
                        prediction_mu,prediction_radius,prediction_angularvel,prediction_mass,
                        SHIP:FACING:FOREVECTOR:NORMALIZED,SHIP:FACING:TOPVECTOR:NORMALIZED,
                        VCRS(SHIP:FACING:TOPVECTOR:NORMALIZED,SHIP:FACING:FOREVECTOR:NORMALIZED):NORMALIZED,true
                    ).
                    set entry_predictive_lower_miss to entry_team_box_miss(
                        prediction_low["final_state"],Team_interface["target_latlng"],Team_interface["team_interface_box"]
                    ).
                    set entry_predictive_upper_miss to entry_team_box_miss(
                        prediction_high["final_state"],Team_interface["target_latlng"],Team_interface["team_interface_box"]
                    ).
                    set entry_predictive_lower_range_error to entry_predictive_range_error(
                        prediction_start["latlong"],prediction_low["final_state"]["latlong"],Team_interface["target_latlng"]
                    ).
                    set entry_predictive_upper_range_error to entry_predictive_range_error(
                        prediction_start["latlong"],prediction_high["final_state"]["latlong"],Team_interface["target_latlng"]
                    ).
                    local prediction_command is entry_predictive_bank_command(
                        entry_predictive_bank,entry_predictive_lower_bank,entry_predictive_lower_range_error,
                        entry_predictive_lower_miss,entry_predictive_upper_bank,entry_predictive_upper_range_error,
                        entry_predictive_upper_miss,prediction_minimum_bank,prediction_maximum_bank,3
                    ).
                    set entry_predictive_valid to prediction_command["valid"].
                    set entry_predictive_sensitivity to prediction_command["sensitivity"].
                    local prediction_was_frozen is entry_predictive_frozen.
                    set entry_predictive_frozen to entry_predictive_valid and
                        abs(entry_predictive_sensitivity) < AVES["EntryHandoff"]["predictive_minimum_sensitivity"].
                    if entry_predictive_frozen <> prediction_was_frozen {
                        flight_log_event("entry_prediction_freeze","active="+entry_predictive_frozen+
                            "|sensitivity="+round(entry_predictive_sensitivity,3)+
                            "|threshold="+AVES["EntryHandoff"]["predictive_minimum_sensitivity"]+
                            "|held_bank="+round(entry_predictive_bank,3)).
                    }
                    if entry_predictive_frozen {
                        set entry_predictive_valid to false.
                    }
                    if entry_predictive_valid {
                        set entry_predictive_bank to prediction_command["bank"].
                    }
                    flight_log_entry_prediction(
                        entry_predictive_plan_bank,entry_predictive_bank,entry_predictive_lower_bank,
                        entry_predictive_lower_range_error,entry_predictive_lower_miss,entry_predictive_upper_bank,
                        entry_predictive_upper_range_error,entry_predictive_upper_miss,prediction_authority,
                        entry_predictive_sensitivity,entry_predictive_valid,entry_predictive_frozen,time:seconds-prediction_start_time,
                        entry_predictive_next_update
                    ).
                }
                local bank_out is entry_predictive_bank.
                local d_t_a is time_to_alt(ship:altitude,ship:verticalspeed,Team_interface["target_altitude"]).
                if entry_turnside = "right"{
                    set dap["aoa"]["target_bank"] to -bank_out.
                }else{
                    set dap["aoa"]["target_bank"] to bank_out.
                }
                flight_log_capture_entry_guidance(s_step,e_ref,e_dot,d_e,heading_error,dap["aoa"]["target_bank"],d_t_a,entry_turnside,e_gui_inputs["l/d"],t_,t2_,reference_fraction,reference_segment["cross_track"]).

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

            }
          
           
        }
        if calc_aoa() > dap["aoa"]["smooth_target_aoa"]+1 and ship:altitude < 55000{
            rcs on.
        }else{
            rcs off.
            
        }
        if defined Team_interface {
            local handoff_config is AVES["EntryHandoff"].
            local team_target_distance is calcdistance_m(ship:geoposition,Team_interface["target_latlng"]).
            set entry_team_closest_distance to min(entry_team_closest_distance,team_target_distance).
            local inside_team_gate is
                team_target_distance <= handoff_config["distance_tolerance"] and
                ship:altitude >= Team_interface["target_altitude"] + handoff_config["minimum_altitude_offset"] and
                ship:altitude <= Team_interface["target_altitude"] + handoff_config["maximum_altitude_offset"] and
                ship:airspeed <= handoff_config["maximum_airspeed"] and
                ship:verticalspeed <= handoff_config["maximum_climb_rate"].
            if inside_team_gate {
                if entry_team_gate_since < 0 { set entry_team_gate_since to time:seconds. }
            } else {
                set entry_team_gate_since to -1.
            }
            local team_gate_elapsed is 0.
            if entry_team_gate_since >= 0 { set team_gate_elapsed to time:seconds-entry_team_gate_since. }
            local team_handoff_reason is entry_team_handoff_reason(
                team_target_distance,entry_team_closest_distance,ship:altitude,
                Team_interface["target_altitude"],ship:airspeed,ship:verticalspeed,
                team_gate_elapsed,handoff_config
            ).
            if team_handoff_reason <> "" or ship:altitude < Team_interface["target_altitude"] + runway_altitude - 1000 {
                set team_handoff_start_aoa to dap["aoa"]["smooth_target_aoa"].
                set team_handoff_start_bank to dap["aoa"]["smooth_target_bank"].
                set team_handoff_transition_start to time:seconds.
                set team_handoff_transition_active to true.
                local handoff_reason is team_handoff_reason.
                if handoff_reason = "" { set handoff_reason to "below_runway_altitude_gate". }
                flight_log_event("team_handoff","reason="+handoff_reason+
                    "|distance="+round(team_target_distance,1)+"|closest_distance="+round(entry_team_closest_distance,1)+
                    "|altitude="+round(ship:altitude,1)+"|target_altitude="+round(Team_interface["target_altitude"],1)+
                    "|airspeed="+round(ship:airspeed,1)+"|vertical_speed="+round(ship:verticalspeed,2)+
                    "|start_aoa="+round(team_handoff_start_aoa,2)+"|start_bank="+round(team_handoff_start_bank,2)).
                reset_sys().
                set step to "TEAM".
                set Lastest_status to "TEAM".
                rcs on.
                clearVecDraws().
                set dap["aoa"]["target_aoa"] to team_handoff_start_aoa.
                set dap["aoa"]["target_bank"] to team_handoff_start_bank.
                set dap["str_mode"] to "aoa".
            }
        } else if ship:altitude < runway_altitude - 1000 {
            set team_handoff_start_aoa to dap["aoa"]["smooth_target_aoa"].
            set team_handoff_start_bank to dap["aoa"]["smooth_target_bank"].
            set team_handoff_transition_start to time:seconds.
            set team_handoff_transition_active to true.
            flight_log_event("team_handoff","reason=below_runway_altitude_without_interface"+
                "|altitude="+round(ship:altitude,1)+"|runway_altitude="+round(runway_altitude,1)+
                "|start_aoa="+round(team_handoff_start_aoa,2)+"|start_bank="+round(team_handoff_start_bank,2)).
            reset_sys().
            set step to "TEAM".
            set Lastest_status to "TEAM".
            rcs on.
            clearVecDraws().
            set dap["aoa"]["target_aoa"] to team_handoff_start_aoa.
            set dap["aoa"]["target_bank"] to team_handoff_start_bank.
            set dap["str_mode"] to "aoa".
        }
    }
    if step = "TEAM"{
        if not(defined terminal_route){
            set terminal_route to terminal_route_init().
            clearVecDraws().
        }
        if terminal_route_runway_change_request <> "" {
            local requested_runway is terminal_route_runway_change_request.
            set terminal_route_runway_change_request to "".
            if terminal_route_runway_change_allowed(terminal_route) {
                local runway_change is terminal_route_change_runway(requested_runway).
                set Lastest_status to runway_change["message"].
                if runway_change["success"] {
                    // Recreate every waypoint and energy target for the new
                    // threshold before terminal guidance resumes.
                    set terminal_route to terminal_route_init().
                }
            }else{
                set Lastest_status to "Runway change locked: terminal approach is committed".
            }
        }
        set terminal_route to terminal_route_update(terminal_route).
        terminal_route_fly(terminal_route).
        if team_handoff_transition_active {
            local transition_elapsed is time:seconds-team_handoff_transition_start.
            local raw_team_aoa is dap["aoa"]["target_aoa"].
            local raw_team_bank is dap["aoa"]["target_bank"].
            if dap["str_mode"] = "aoa" {
                set dap["aoa"]["target_aoa"] to entry_handoff_rate_limit(
                    team_handoff_start_aoa,raw_team_aoa,transition_elapsed,
                    AVES["EntryHandoff"]["transition_aoa_rate"]
                ).
                set dap["aoa"]["target_bank"] to entry_handoff_rate_limit(
                    team_handoff_start_bank,raw_team_bank,transition_elapsed,
                    AVES["EntryHandoff"]["transition_bank_rate"]
                ).
                if abs(dap["aoa"]["target_aoa"]-raw_team_aoa) <= AVES["EntryHandoff"]["transition_capture_tolerance"] and
                   abs(dap["aoa"]["target_bank"]-raw_team_bank) <= AVES["EntryHandoff"]["transition_capture_tolerance"] {
                    set team_handoff_transition_active to false.
                    flight_log_event("team_handoff_blend_complete","elapsed="+round(transition_elapsed,2)+
                        "|aoa="+round(raw_team_aoa,2)+"|bank="+round(raw_team_bank,2)).
                }
            } else {
                set team_handoff_transition_active to false.
                flight_log_event("team_handoff_blend_complete","elapsed="+round(transition_elapsed,2)+"|reason=steering_mode_changed").
            }
            set terminal_route_debug["handoff_blend_active"] to team_handoff_transition_active.
            set terminal_route_debug["handoff_blend_elapsed"] to transition_elapsed.
            set terminal_route_debug["handoff_raw_target_aoa"] to raw_team_aoa.
            set terminal_route_debug["handoff_raw_target_bank"] to raw_team_bank.
        }
        update_team_dap_gui().
        update_terminal_route_gui().
        if ship:altitude > 22000{
            rcs on.
        }
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

        if terminal_route["phase"] = "final" or terminal_route["phase"] = "base"{
            abort_set_fuel_dump(ship:mass > AVES["TerminalRoute"]["max_landing_mass"]).
        }

        if terminal_route["landing_ready"]{
            // LandingGate has already been stable for its configured time.
            // Make one final LOC/GS/approach check here, without another timer.
            local landing_commit is terminal_route_landing_commit_check(terminal_route).
            if landing_commit["stable"] {
                if defined abort_state and abort_state:haskey("active") and abort_state["active"] { abort_set_fuel_dump(false). }
                abort_set_fuel_dump(false).
                flight_log_event("landing_handoff","distance="+round(terminal_route["remaining_distance"],1)+
                    "|altitude="+round(ship:altitude-runway_altitude,1)+"|vertical_speed="+round(ship:verticalspeed,2)+
                    "|target_vertical_speed="+round(terminal_route_debug["desired_vertical_speed"],2)+
                    "|profile_region="+terminal_route["profile_region"]+"|glideslope_error="+round(landing_commit["glideslope_error"],1)).
                set terminal_route_debug["preflare_pullup_active"] to false.
                set terminal_route_debug["preflare_pullup_fraction"] to 0.
                set step to "landing".
                set dap["str_mode"] to "aerostr".
            }else{
                flight_log_event("landing_commit_rejected","distance="+round(terminal_route["remaining_distance"],1)+
                    "|altitude="+round(ship:altitude-runway_altitude,1)+"|vertical_speed="+round(ship:verticalspeed,2)+
                    "|airspeed="+round(ship:airspeed,2)+"|glideslope_error="+round(landing_commit["glideslope_error"],1)+
                    "|cross_track="+round(terminal_route["geometry"]["cross_track"],1)+
                    "|heading_error="+round(terminal_route["geometry"]["heading_error"],1)+
                    "|gpws_state="+dap["envelope"]["terrain_state"]).
                set terminal_route["go_around_count"] to terminal_route["go_around_count"] + 1.
                set terminal_route["go_around_reason"] to "landing_commit_unstable".
                terminal_route_change_phase(terminal_route,"go_around").
                set Lastest_status to "Go around: landing commit unstable (GS error " + round(landing_commit["glideslope_error"],1) + "m)".
            }
        }
    }

      
     if step = "landing"{
        set alt_ovr_runway to ship:altitude - runway_altitude.
        local landing_config is AVES["Landing"].
        set dapthrottle to 0.
        gear on.
        update_team_dap_gui().
        // The final flare deliberately remains a descent.  Interpolating the
        // desired sink rate by height produces a smooth flare without holding
        // the craft level over the runway.
        local desired_vs is landing_config["approach_vertical_speed"].
        local flare_fraction is 0.
        if alt_ovr_runway < landing_config["flare_start_altitude"] {
            set flare_fraction to max(0,min(1,
                (landing_config["flare_start_altitude"] - alt_ovr_runway) /
                max(landing_config["flare_start_altitude"] - landing_config["touchdown_altitude"],1)
            )).
            set desired_vs to landing_config["approach_vertical_speed"] +
                (landing_config["touchdown_vertical_speed"] - landing_config["approach_vertical_speed"]) * flare_fraction.
            if not landing_flare_started {
                set landing_flare_started to true.
                flight_log_event("landing_flare_start","altitude="+round(alt_ovr_runway,1)+
                    "|distance="+round(calcdistance_m(ship:geoposition,runway_start),1)+
                    "|vertical_speed="+round(ship:verticalspeed,2)+"|target_vertical_speed="+round(desired_vs,2)).
            }
        }
        set terminal_route_debug["landing_desired_vs"] to desired_vs.
        set terminal_route_debug["landing_flare_fraction"] to flare_fraction.

        // Keep aerostr control for final alignment.  Drive turn_pitch directly
        // so the flare has pitch authority without using distance_pitch.
        local flare_pitch is max(landing_config["minimum_turn_pitch"],min(
            landing_config["maximum_turn_pitch"],
            (desired_vs - ship:verticalspeed) * landing_config["pitch_gain"]
        )).
        set dap["str_mode"] to "aerostr".
        set dap["aerostr"]["turn_pitch"] to flare_pitch.
        set dap["aerostr"]["distance_pitch"] to 0.
        set dap["aerostr"]["turn_roll"] to 0.
        set dap["aerostr"]["turn_heading"] to heading_to_target(runway_end).

        local landing_brake_command is landing_brake_decision(brakes,ship:airspeed,
            ship:status = "LANDED",alt_ovr_runway,landing_config).
        local brake_reason is "speed_band".
        if ship:status = "LANDED" or alt_ovr_runway <= landing_config["wheel_brake_altitude"] {
            set brake_reason to "wheel_contact_zone".
        }
        if landing_brake_command <> brakes or terminal_route_debug["brake_mode"] <> "landing" or
           terminal_route_debug["brake_reason"] <> brake_reason {
            flight_log_approach_brake("landing",brake_reason,landing_brake_command,
                AVES["TerminalRoute"]["ApproachSpeed"]["target_speed"],
                landing_config["brake_on_speed"],landing_config["brake_off_speed"],terminal_route["energy_margin"]).
        }
        set terminal_route_debug["brake_mode"] to "landing".
        set terminal_route_debug["brake_reason"] to brake_reason.
        set terminal_route_debug["airbrake"] to landing_brake_command.
        if landing_brake_command { brakes on. } else { brakes off. }
        if ship:status = "LANDED" and ship:airspeed < 5 {

            log_status("Landing completed").
        }
        // A momentary stall or a bounce can have near-zero airspeed while
        // still airborne.  Only wheel contact is a valid terminal condition.
        if ship:status = "LANDED" and ship:airspeed < 1 {
            set recovery_result to lex("complete",true,"success",true,"reason","landing_complete").
            set step to "end".
            log_status("Landing completed, switching to end phase").
        }
    }
    if step = "end" {
        if not recovery_result["complete"] {
            set recovery_result to lex("complete",true,"success",false,"reason","recovery_ended_before_landing").
        }
        set running to false.
        reset_sys().
        set warp to 0.
        update_readouts().
        log_status("Script ended, system reset").
        clearGuis().
    }
    update_readouts().
    update_reentry_gui(e_gui_inputs).
    flight_log_entry_display_mode(
        reentry_display_active_mode,
        entry_nominal_energy_height(ship:altitude,ship:airspeed),
        entry_display_range_remaining
    ).
    flight_log_tick("reentry",step,substep).
    wait 0.
}
}
