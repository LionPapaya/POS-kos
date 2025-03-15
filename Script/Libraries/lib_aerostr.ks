function aeroturn {
    declare parameter desired_heading. // Der gewünschte Kurs in Grad
    parameter turn_side is "calc". // Die Richtung, in die das Flugzeug drehen soll (links, rechts oder keine)
    parameter aoa is 20.

    local heading_error to desired_heading - compass_for().

    // Normalisiere den Fehler
    until abs(heading_error) <= 180 {
        if heading_error > 180 {
            set heading_error to heading_error - 360.
        } 
        if heading_error < -180 {
            set heading_error to heading_error + 360.
        }
    }

    // Calculate turn side if needed
    if turn_side = "calc" {
        if heading_error > 0 {
            set turn_side to "right".
        } else {
            set turn_side to "left".
        }
    }

    // Calculate roll based on heading_error
    local roll_angle to 0.
    if abs(heading_error) > 50 {
        set roll_angle to AVES["MaxRoll"].
    } else {
        set roll_angle to (abs(heading_error) ^ 2) * AVES["MaxRoll"] / (25 ^ 2).
    }
    if turn_side = "right" {
        set roll_angle to -roll_angle.
    }

    set dap["aoa"]["target_aoa"] to aoa.
    set dap["aoa"]["target_bank"] to roll_angle. 
}
function aerostr{
  if not(defined turn_roll){
    set turn_roll to 0.
  }
   set dap["aerostr"]["aerostr_pitch"] to (dap["aerostr"]["distance_pitch"]+dap["aerostr"]["turn_pitch"]).
   set dap["aerostr"]["aerostr_heading"] to dap["aerostr"]["turn_heading"].
    set dap["aerostr"]["aerostr_Roll"] to dap["aerostr"]["turn_roll"].

  checksrt_inputs(dap["aerostr"]["aerostr_pitch"],dap["aerostr"]["aerostr_heading"],dap["aerostr"]["aerostr_Roll"]).  
  set dap["aerostr"]["targetPitch"] to dap["aerostr"]["aerostr_pitch"].
  set dap["aerostr"]["targetDirection"] to dap["aerostr"]["aerostr_heading"].
  set dap["aerostr"]["targetRoll"] to dap["aerostr"]["aerostr_Roll"].
}
function checksrt_inputs{
  declare parameter input_pitch, input_heading, input_roll.
  local heading_err to input_heading - compass_for_prograde().
  if input_roll < -AVES["MaxRoll"]{
    set dap["aerostr"]["aerostr_Roll"] to -AVES["MaxRoll"].
  }
  if input_roll > AVES["MaxRoll"]{
    set dap["aerostr"]["aerostr_Roll"] to AVES["MaxRoll"].
  }
  if roll_for() < -AVES["MaxRoll"]{
    set dap["aerostr"]["aerostr_Roll"] to -AVES["MaxRoll"].
  }
  if roll_for() > AVES["MaxRoll"]{
    set dap["aerostr"]["aerostr_Roll"] to AVES["MaxRoll"].
  }
  if heading_err > AVES["MaxYaw"]{
    set dap["aerostr"]["aerostr_heading"] to compass_for_prograde() +AVES["MaxYaw"].
  }
  if heading_err < -AVES["MaxYaw"]{
    set dap["aerostr"]["aerostr_heading"] to compass_for_prograde() -AVES["MaxYaw"].
  }
  if input_pitch > AVES["MaxPitch"]{
    set dap["aerostr"]["aerostr_pitch"] to AVES["MaxPitch"].
  }
  if input_pitch < AVES["MinPitch"]{
    set dap["aerostr"]["aerostr_pitch"] to AVES["MinPitch"].
  }
  


}
function calc_vvdot {
    parameter distance.
    parameter speed.
    parameter t_alt.
    parameter alt_.
    local t is distance / speed.
    set t to t/AVES["TEAM_vvdot_t"].
    local vvdot is (t_alt - alt_) / t.
    return vvdot.
}
function calculate_glideslope_alt {
    parameter distance,rnw_alt is runway_altitude, gs is AVES["glideslope"].//angle1, target1, switch12, angle2.
    
    if distance >= gs["switch12"] {
        return ((distance - gs["target1"]) * gs["angle1"])+rnw_alt.
    }else {
        return (distance *  gs["angle2"])+rnw_alt.
    }
}
function calculate_distance_from_alt {
    parameter alt_, rnw_alt is runway_altitude, gs is AVES["glideslope"]. // angle1, target1, switch12, angle2.

    // Calculate the altitude difference
    local alt_diff is alt_ - rnw_alt.

    // Determine which segment of the glideslope the altitude falls into
    if alt_diff >= gs["switch12"] * gs["angle1"] {
        return (alt_diff / gs["angle1"]) + gs["target1"].
    } else {
        return alt_diff / gs["angle2"].
    }
}
function calculate_vertical_glideslope_distance {
    parameter distance is calcdistance_m(ship:geoposition,runway_start),alt_ is ship:altitude, gs is AVES["glideslope"].
    return calculate_glideslope_alt(distance)- alt_.
}
function aggressive_overcorrect_for_prograde {
    parameter target_heading. // Target heading for runway_start alignment

    // Monitor the current prograde vector heading
    local prograde_heading is compass_for_prograde().

    // Calculate the difference between current heading and prograde
    local heading_difference is target_heading - prograde_heading.

    // More aggressive overcorrection if the prograde is not aligned with the target heading
    if abs(heading_difference) > 1 {
        // If the prograde is significantly to the left, turn right more aggressively
        if heading_difference > 0 {
            set dap["aerostr"]["turn_heading"] to compass_for() + 10.  // Larger adjustment
        }
        // If the prograde is significantly to the right, turn left more aggressively
        if heading_difference < 0 {
            set dap["aerostr"]["turn_heading"] to compass_for() - 10.  // Larger adjustment
        }
        log_status("Aggressive overcorrection for prograde alignment: heading difference: " + heading_difference).
    } else {
        // If the heading difference is small, maintain the target heading
        set dap["aerostr"]["turn_heading"] to runway_heading.
    }
}
function aoa_bank_management {
    parameter target_aoa, target_bank.
    parameter base_pitch is  pitch_for_prograde().
    parameter css is false.

    // Normalize the bank angle to a range [-1, +1]
    set normalized_bank to target_bank / 90. // -1 for -90, 0 for 0, +1 for +90

    if not(css){
        set dap["aoa"]["aoa_pitch"] to base_pitch + (target_aoa * (1 - abs(normalized_bank))).
        set dap["aoa"]["aoa_yaw"] to compass_for_prograde() - (target_aoa * normalized_bank).
        set dap["aoa"]["aoa_roll"] to target_bank.
    }else{
        set dap["css"]["pitch_out"] to base_pitch + (target_aoa * (1 - abs(normalized_bank))).
        set dap["css"]["yaw_out"] to compass_for_prograde() - (target_aoa * normalized_bank).
        set dap["css"]["roll_out"] to target_bank.
    }
}
function is_within_team_interface {
        parameter simstate.
        parameter team_interface_box.
        parameter target_latlong.
        return simstate["altitude"] >= team_interface_box["min_altitude"] and
               simstate["altitude"] <= team_interface_box["max_altitude"] and
               calcdistance_m(target_latlong,simstate["latlong"]) < team_interface_box["dist_tolerance"].
}
function calculate_error {
    parameter simstate.
    parameter target_conditions.

    local altitude_error is abs(simstate["altitude"] - target_conditions["altitude"]).
    local speed_error is abs(simstate["velocity"]:mag - target_conditions["velocity"]).
    local pos_error is calcdistance(simstate["latlong"], target_conditions["latlong"]).

    // Weighted sum of errors
    return altitude_error*1.5 + speed_error*5 + pos_error*500.
}

function closest_simstate {
    parameter simstates.
    parameter target_conditions.

    local closest_simstate_ is simstates[0]["final_state"].
    local min_error is calculate_error(simstates[0]["final_state"], target_conditions).

    for simstate_ in simstates {
        local error is calculate_error(simstate_["final_state"], target_conditions).
        if error < min_error {
            set min_error to error.
            set closest_simstate_ to simstate_["final_state"].
        }
    }

    return closest_simstate_.
}
function check_cur_error {
    parameter simstate.
    parameter bank_side.
    parameter bank_angle.
    parameter target_latlong.
    parameter target_altitude.

    // Simulate the trajectory with the given bank_side and bank_angle
    local simulated_state is simulate_trajectory(simstate, bank_angle, bank_side, target_altitude).

    // Calculate the cur_state_error
    local cur_state_error is calcdistance(simstate["latlng"], target_latlong) - calcdistance(simstate["latlng"], simulated_state["latlng"]).

    // Calculate the cur_state_%error
    local cur_state_error_p is calc_percentage(cur_state_error, calcdistance(simstate["latlng"], target_latlong)).

    return cur_state_error_p.
}
function check_if_entry_possible{
    parameter simstate.
    parameter target_latlng.
    parameter timestep is AVES["simulation"]["timestep"].

    local check_45 is sim_with_bank(simstate, 45, AVES["TEAMAltitude"], target_latlng)["final_state"].
    local c is false.
    if calcdistance_m(check_45["latlong"], simstate["latlong"]) >  calcdistance_m(simstate["latlong"], target_latlng) {
        set c to true.
    }
    local check is 0.
    if not(c){
    local max_distance is simulate_trajectory(simstate, 0, "right", AVES["TEAMAltitude"],simstate["altitude"]+100,AVES["egaoa"],timestep).
    local right_distance is simulate_trajectory(simstate, 45, "right", AVES["TEAMAltitude"],simstate["altitude"]+100,AVES["egaoa"],timestep).
    local left_distance is simulate_trajectory(simstate, 45, "left", AVES["TEAMAltitude"],simstate["altitude"]+100,AVES["egaoa"],timestep).
    local left_distance_t to left_distance["latlong"].
    local right_distance_t to right_distance["latlong"].
    set check to check_target_in_triangle(target_latlng,max_distance["latlong"],right_distance_t,left_distance_t).

    check:add("left_pos",left_distance_t).
    check:add("right_pos",right_distance_t).
    check:add("max_pos",max_distance["latlong"]).
    check:add("max",45).
    check:add("min",0).


    }else{
        local min_distance is sim_with_bank(simstate, 90 , AVES["TEAMAltitude"],target_latlng)["final_state"].
        local right_distance is simulate_trajectory(simstate, 45, "right", AVES["TEAMAltitude"],simstate["altitude"]+100,AVES["egaoa"],timestep).
        local left_distance is simulate_trajectory(simstate, 45, "left", AVES["TEAMAltitude"],simstate["altitude"]+100,AVES["egaoa"],timestep).
        local left_distance_t to left_distance["latlong"].
        local right_distance_t to right_distance["latlong"].
        local hed is heading_between(left_distance_t,right_distance_t).
        local dist is calcdistance_m(left_distance_t,right_distance_t)/6.
        local back_right is get_geoposition_along_heading(min_distance["latlong"],hed,dist).
        local back_left is get_geoposition_along_heading(min_distance["latlong"],hed+180,dist).
        set check to check_target_in_square(target_latlng,left_distance_t,right_distance_t,back_right,back_left).

        

        check:add("left_pos",left_distance_t).
        check:add("right_pos",right_distance_t).
        check:add("max_pos",min_distance["latlong"]).
        check:add("max",90).
        check:add("min",45).

    }
    return check.
}
function entry_possible_square{
    parameter simstate.
    parameter timestep is AVES["simulation"]["timestep"].
    print "1".
    local out is list(
        simulate_trajectory(simstate, 0, "right",  20000,simstate["altitude"]+100,AVES["egaoa"],timestep),
        simulate_trajectory(simstate, 45, "right",  20000,simstate["altitude"]+100,AVES["egaoa"],timestep),
        simulate_trajectory(simstate, 45, "left",  20000,simstate["altitude"]+100,AVES["egaoa"],timestep),
        simulate_trajectory(simstate, 90, "left", 20000,simstate["altitude"]+100,AVES["egaoa"],timestep)

    ). 
    return out.
}
function sim_with_bank{
    parameter simstate.
    parameter bank_angle.
    parameter target_altitude.
    parameter target_latlong.
    parameter timestep is AVES["simulation"]["timestep"].

    local out is lex().
    local contrl is lex().

    local hed is compass_for_simstate(simstate).
    local hed2tgt is heading_between(simstate["latlong"],target_latlong).
    local heading_error is hed - hed2tgt.
    if heading_error > 0{
        set bank_side to "right".
    }
    if heading_error < 0{
        set bank_side to "left".
    }
    until simstate["altitude"] < target_altitude{
        set hed to compass_for_simstate(simstate).
        set hed2tgt to heading_between(simstate["latlong"],target_latlong).
        set heading_error to hed - hed2tgt.
        if abs(heading_error) > 20{
            log hed to log_hed.txt.
            log hed2tgt to log_hed.txt.
            log simstate to log_hed.txt.
        }
        log "" to log_hed.txt.
        if heading_error > AVES["EG_rev°"]{
            set bank_side to "right".
            //log "right" to log.txt.
        }
        if heading_error < -AVES["EG_rev°"]{
            set bank_side to "left".
            //log "left" to log.txt.
        }
        contrl:add(simstate["simtime"],lex("simstate",simstate,"inputs",lex("bank_side",bank_side,"bank_angle",bank_angle))).
        set simstate to simulate_trajectory_time(simstate,bank_angle,bank_side,timestep).

    }
    out:add("control",contrl).
    out:add("final_state",simstate).
    return out.
}
function calc_entry_traj {
    parameter input_simstate.
    parameter target_altitude.
    parameter target_latlong.
    parameter team_interface_box.


    local output is lex("converged",false).
    output:add("iterations",1).
    local org_timestep is AVES["simulation"]["timestep"].
    set AVES["simulation"]["timestep"] to 1.
    local start_sim is simulate_trajectory(input_simstate, 0, "left", AVES["simulation"]["entry_ref_alt"],input_simstate["altitude"]+100).
    //log start_sim to log.txt.
    set AVES["simulation"]["timestep"] to org_timestep.
    local is_eg_pos is check_if_entry_possible(start_sim,target_latlong).
    local bank_angle is 0.
    local tgt_dist is calcdistance_m(start_sim["latlong"],target_latlong).
    local lower_bound is lex("bank",is_eg_pos["min"],"dist",99999999999).
    local upper_bound is lex("bank",is_eg_pos["max"],"dist",99999999999).
    output:add("crossrange",calcdistance_m(is_eg_pos["left_pos"],is_eg_pos["right_pos"])/2). // Crossrange is the distance between the left and right positions / 2
    if not is_eg_pos["is_inside"]{
        output:add("error",lex("str","Target not reachable", "max", is_eg_pos["max_pos"],"left",is_eg_pos["left_pos"],"right",is_eg_pos["right_pos"], "target",target_latlong)).

        set output:converged to false.
        return output.
    }else{
        if is_eg_pos["distance2"] < is_eg_pos["distance3"]{
            set bank_side to "right".
        }else{
            set bank_side to "left".
        }
        local avg_dist is avg(list(calcdistance_m(start_sim["latlong"],is_eg_pos["right_pos"]),calcdistance_m(start_sim["latlong"],is_eg_pos["left_pos"]))).
        if is_eg_pos["max"] = 45{
            set upper_bound["dist"] to avg_dist.
            set lower_bound["dist"] to calcdistance_m(start_sim["latlong"],is_eg_pos["max_pos"]).
        }else{
            set upper_bound["dist"] to calcdistance_m(start_sim["latlong"],is_eg_pos["max_pos"]).
            set lower_bound["dist"] to avg_dist.
        }

    }

    until output:converged  or output["iterations"] > AVES["simulation"]["max_iterations"]{
                
        set simstate to clone_simstate(start_sim).
        local control_outputs is lex(0,lex("simstate",simstate,"inputs",lex("bank_side",bank_side,"bank_angle",bank_angle))).

        local d_u is upper_bound["dist"] - tgt_dist.
        local d_l is lower_bound["dist"] - tgt_dist.

        local pred_b is find_zero_input(lower_bound["bank"],d_l,upper_bound["bank"], d_u).
        local predict is sim_with_bank(simstate, pred_b, target_altitude, target_latlong).
        local dist is calcdistance_m(predict["final_state"]["latlong"], simstate["latlong"]).

        if dist > tgt_dist {
            set upper_bound["bank"] to pred_b.
            set upper_bound["dist"] to dist.
        } else {
            set lower_bound["bank"] to pred_b.
            set lower_bound["dist"] to dist.
        }
        local log is "log"+output["iterations"]+".txt".
        for _sim_ in predict["control"]:keys{
            local c is predict["control"][_sim_]["simstate"].
            log c["simtime"]+",("+c["latlong"]:lat+","+c["latlong"]:lng+")" to log.

        }


        log "upper_bound: " + upper_bound["bank"] + " " + upper_bound["dist"] + " lower_bound: " + lower_bound["bank"] + " " + lower_bound["dist"] to log.txt.

        log "Iteration: " + output["iterations"] + ", Distance to target: " + calcdistance_m(predict["final_state"]["latlong"], target_latlong) + ", Predicted bank angle: " + pred_b +", latlng: " + predict["final_state"]["latlong"] + "tgt_latlng"+ target_latlong to log.txt.
        //log "final_state"+predict["final_state"] to log.txt.
        if is_within_team_interface(predict["final_state"],team_interface_box,target_latlong){
            set output:converged to true.
            set control_outputs to merge_lex(control_outputs,predict["control"]). // Merge the control outputs
            local converged_sim is lex("controll_inputs", control_outputs).
            output:add ("converged_sim",converged_sim).
            set output:final_state to predict["final_state"].
            output:add("bank",pred_b).
            output:add("error",lex("str","Converged", "max", is_eg_pos["max_pos"],"left",is_eg_pos["left_pos"],"right",is_eg_pos["right_pos"], "target",target_latlong)).
            return output.

        }


        set output["iterations"] to output["iterations"] + 1.

    }
     output:add("error",lex("str","To many iteration", "max", is_eg_pos["max_pos"],"left",is_eg_pos["left_pos"],"right",is_eg_pos["right_pos"], "target",target_latlong)).
    set output:converged to false.

    return output.
}

function TEAM_guid{
    parameter team_input.
    parameter sim_in is current_simstate().
    parameter hacs is create_HAC().
    parameter rnw is lex("pos",runway_start,"head",runway_heading,"alt",runway_altitude).

    local HAC is lex("HAC1",hacs["HAC1"],"HAC2",hacs["HAC2"]).
    


    local team_internal is lex(
        //regarding current status
        "sim", clone_simstate(sim_in),
        "step", "s_trn", //valid step is "s_trn","bef","in","ex","fla","ROL"
        "ENMGT", true,

        //regarding current HAC and entry
        "active_hac",hacs[choose_hac()["active_hac"]],
        "active_hac_dir",choose_hac()["HAC_Direction"],
        "ercl_hac_alt",hacs["HAC_ERCL_ALT"],
        "ercl_hac_latlong",hacs["HAC_ERCL"],
        "hac_entry", lex(
            "alt",0,
            "latlng", hacs[choose_hac()["active_hac"]],
            "vel",0,
            "dist",0),
        "apch_mode","ovh",
        
        


        "dummy",0
    ).
    local out is lex(
        "s_trn",false,
        "enlow",false,
        "change_hac",false,
        "team_input",lex(
            "step",team_internal["step"],
            "enmgt",team_internal["ENMGT"],
            "active_hac",team_internal["active_hac"],
            "active_hac_dir",team_internal["active_hac_dir"],
            "apch_mode",team_internal["apch_mode"]
        ),
        "ercl_hac_latlong",team_internal["ercl_hac_latlong"],
        "algn_pos", latlng(0,0),
        "gs", true,
        "gear_cmd" , false,
        "airbrake_cmd", false,


        "dummy",0
    ).
    if not(team_input = lex()){
        set team_internal["step"] to team_input["step"].
        set team_internal["ENMGT"] to team_input["enmgt"].
        set team_internal["active_hac"] to team_input["active_hac"].
        set team_internal["active_hac_dir"] to team_input["active_hac_dir"].
        set team_internal["apch_mode"] to team_input["apch_mode"].
    }

    if team_internal["step"] = "s_trn" or team_internal["step"] = "bef"{
        //log team_internal["active_hac"] to log_team_sim.txt.
        local h_s is calc_hacstate(team_internal["active_hac"],AVES["HacRadius"],heading_between(team_internal["sim"]["latlong"],team_internal["active_hac"]),rnw["head"],team_internal["active_hac_dir"]).
        set team_internal["hac_entry"]["latlng"] to h_s["latlng"].
        set team_internal["hac_entry"]["alt"] to h_s["alt"].
        set team_internal["hac_entry"]["vel"] to h_s["vel"].
        set team_internal["hac_entry"]["dist"] to h_s["dist"].
        clearVecDraws().
        pos_arrow(h_s["latlng"],"HAC_entry",h_s["alt"],1).
        pos_arrow(team_internal["ercl_hac_latlong"],"ERCL_HAC",team_internal["ercl_hac_alt"],1).
        draw_vector(team_internal["ercl_hac_latlong"],team_internal["ercl_hac_alt"],rnw["pos"],rnw["alt"],RGB(1, 0, 0)," ",1).
        for angle in range(rnw["head"],compass_for(),20){
            local h_s is calc_hacstate(team_internal["active_hac"],AVES["HacRadius"],angle,rnw["head"],team_internal["active_hac_dir"]).
            pos_arrow(h_s["latlng"]," ",h_s["alt"],0.1).
        }

        

        
        if calcdistance_m(team_internal["hac_entry"]["latlng"],team_internal["sim"]["latlong"]) < 500{
            set team_internal["step"] to "in".
        }
    }   
    log "per ENMGT" to log_team_sim.txt.
    if team_internal["ENMGT"]{
        local sim is clone_simstate(team_internal["sim"]).
        //log "pre_turn" to log_team_sim.txt.
        log team_internal["hac_entry"]["latlng"] to log_team_sim.txt.
        set sim to simulate_trajectory_hed_pos(sim,team_internal["hac_entry"]["latlng"]).
        //log "aft_turn" to log_team_sim.txt.
        log team_internal["hac_entry"]["latlng"] to log_team_sim.txt.
        log heading_between(sim["latlong"],team_internal["hac_entry"]["latlng"]) to log_team_sim.txt.
        log "per ENMGT" to log_team_sim.txt.
        //log compass_for_simstate(sim)+" , "+heading_between(team_internal["sim"]["latlong"],team_internal["hac_entry"]["latlng"]) to log_team_sim.txt.
        local pid is pidloop(0.29,0.43,0.3).
        set pid:maxoutput to 20.
        set pid:minoutput to 0.
        local vvdot is 0.
        local dist_ is calcdistance_m(team_internal["hac_entry"]["latlng"],sim["latlong"]).
        local old_dist is dist_.
        
        log sim to simstate.log.
        //log "pre_decent" to log_team_sim.txt.
        //log old_dist to log_team_sim.txt.
        //log dist_ to log_team_sim.txt.
        //log sim["altitude"] to log_team_sim.txt.
        //log team_internal["hac_entry"]["latlng"] to log_team_sim.txt.
        //log team_internal["hac_entry"]["alt"]-1000 to log_team_sim.txt.
        log sim["simtime"] to log_team_sim.txt.
        until old_dist < dist_ or sim["altitude"] < team_internal["hac_entry"]["alt"]-100{
            local dist is team_internal["hac_entry"]["dist"] + calcdistance_m(team_internal["hac_entry"]["latlng"],sim["latlong"]).
            local tgt_alt is calculate_glideslope_alt(dist).
            local tgt_vvdot is calc_vvdot(dist,team_internal["hac_entry"]["vel"],tgt_alt,sim["altitude"]).
            set pid:setpoint to tgt_vvdot.
            local old_alt is sim["altitude"].
            local aoa to pid:update(sim["simtime"],vvdot).
            set sim to simulate_trajectory_time(sim,0,"right",AVES["simulation"]["timestep"],aoa,AVES["simulation"]["timestep"]/3).
            local vvdot to (sim["altitude"]-old_alt)/AVES["simulation"]["timestep"].
            log sim["simtime"]+ ",(" +sim["latlong"]:lat+ ","+sim["latlong"]:lng+"),"+sim["altitude"]+","+sim["surfvel"]:mag to log_team_sim_.txt.
            //log"in loop" to log_team_sim.txt.
            set old_dist to dist_.
            set dist_ to calcdistance_m(team_internal["hac_entry"]["latlng"],sim["latlong"]).
        
        }
        log "aft_decent" to log_team_sim.txt.
        log old_dist + " , " + calcdistance_m(team_internal["hac_entry"]["latlng"],sim["latlong"]) to log_team_sim.txt.
        log team_internal["hac_entry"]["alt"] to log_team_sim.txt.
        log team_internal["hac_entry"]["alt"]:typename to log_team_sim.txt.
        log sim["altitude"] + " , " + (team_internal["hac_entry"]["alt"]-100) to log_team_sim.txt.
        
        log "aft_decent" to log_team_sim.txt.
        if sim["altitude"] < team_internal["hac_entry"]["alt"]-100 or sim["surfvel"]:mag < team_internal["hac_entry"]["vel"]{
            // to low energy switch to direct
            if team_internal["apch_mode"] = "ovh"{

                set team_internal["apch_mode"] to "dir".
                if choose_hac()["active_hac"] = "HAC2"{
                    set team_internal["active_hac"] to HAC["HAC1"].
                }else{
                    set team_internal["active_hac"] to HAC["HAC2"].
                }
                if team_internal["active_hac_dir"] = "Clockwise"{
                    set team_internal["active_hac_dir"] to "antiClockwise".
                }else{
                    set team_internal["active_hac_dir"] to "Clockwise".
                }
                local h_s is calc_hacstate(team_internal["active_hac"],AVES["HacRadius"],heading_between(sim["latlong"],team_internal["active_hac"]),rnw["head"],team_internal["active_hac_dir"]).
                set team_internal["hac_entry"]["latlng"] to h_s["latlng"].
                set team_internal["hac_entry"]["alt"] to h_s["alt"].
                set team_internal["hac_entry"]["vel"] to h_s["vel"].
                set team_internal["hac_entry"]["dist"] to h_s["dist"].
                set out:change_hac to true.
                log "1"to "log.txt".
                //log team_internal to "log.txt".
                //log out to "log.txt".
                //log sim to "log.txt".
                return out.

            }else{
                set out:enlow to true.
                
                set out["team_input"]["step"] to "ex".
                log "2"to "log.txt".
                //log team_internal to "log.txt".
                //log out to "log.txt".
                //log sim to "log.txt".
                return out.
            }
        }else if calcdistance_m(team_internal["hac_entry"]["latlng"],sim["latlong"]) < 1000 and sim["surfvel"]:mag > team_internal["hac_entry"]["vel"]{
            if sim["surfvel"]:mag < team_internal["hac_entry"]["vel"]+ AVES["TEAM_v_margin"]{
                SET OUT["team_input"]["step"] TO "BEF".
                
                set out:s_trn to false.
                log "4"to "log.txt".
                //log team_internal to "log.txt".
                //log out to "log.txt".
                //log sim to "log.txt".
                return out.

            }else if sim["surfvel"]:mag > team_internal["hac_entry"]["vel"]+ AVES["TEAM_v_margin"] or sim["altitude"] > team_internal["hac_entry"]["alt"]+100{
                set out:team_input:step to "s_trn".
                set out["airbrake_cmd"] to true.
                set out:s_trn to true.
                log "5"to "log.txt".
                //log team_internal to "log.txt".
                //log out to "log.txt".
                //log sim to "log.txt".
                return out.
                
            }
            

        }else{
            log "10"to "log.txt".
            log calcdistance_m(team_internal["hac_entry"]["latlng"],sim["latlong"]) to "log.txt".
            log sim["surfvel"]:mag to "log.txt".
            log team_internal["hac_entry"]["vel"] to "log.txt".
            //log out to "log.txt".
                //log sim to "log.txt".
                return out.
        }

    }
    IF team_internal["STEP"] = "BEF"{
        LOCAL DIST IS CALCDISTANCE_M(team_internal["hac_entry"]["latlng"],team_internal["sim"]["latlong"]).
        IF DIST < 500{
            set team_internal["step"] to "in".
            SET OUT["team_input"]["step"] TO "IN".
        }
        if dist < 700{
            set team_internal["ENMGT"] to false.
            SET OUT["team_input"]["enmgt"] TO false.
        }

        log "6"to "log.txt".
        RETURN OUT.
    }
    if team_internal["step"] = "in"{
        if abs(heading_between(team_internal["sim"]["latlong"],rnw["pos"]) - compass_for_simstate(team_internal["sim"])) < 5{
        SET OUT["team_input"]["step"] TO "ex".
        log "7"to "log.txt".
        RETURN OUT.
        
        }
    }
    if team_internal["step"] = "ex"{
        set out["algn_pos"] to get_geoposition_along_heading(        
            rnw["pos"],        
            rnw["head"]+180,        
            (calcdistance_m(team_internal["sim"]["latlong"],rnw["pos"])*0.4)).
        LOCAL DIST IS CALCDISTANCE_M(team_internal["hac_entry"]["latlng"],team_internal["sim"]["latlong"]).
        if dist < AVES["glideslope"]["switch12"]{
            SET OUT["team_input"]["step"] TO "fla".
        }
        log "8"to "log.txt".
        RETURN OUT.
    }
    if Team_internal["step"] = "fla"{
        set out["gear_cmd"] to team_internal["sim"]["altitude"] - rnw["alt"] < 150.
        local alt_ovr_runway is team_internal["sim"]["altitude"] - rnw["alt"].
        if alt_ovr_runway < 100{
            set out["gs"] to false.
            if alt_ovr_runway < 15{
                SET OUT["team_input"]["step"] TO "rol".
                set out["airbrake_cmd"] to true.
            }

        }
    }


    log "9"to "log.txt".
    return out.
}