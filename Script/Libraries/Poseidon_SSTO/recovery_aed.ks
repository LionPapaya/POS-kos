// AED prediction and screening services. The flight executive stays in Orbit Main.
// These functions never issue steering, engine, logger or warp commands.
function recovery_aed_config {
    return lex("capture_speed",330,"maximum_capture_speed",350,
        "minimum_capture_height",2500,"maximum_capture_height",12000,
        "capture_fraction",0.6,"capture_altitude_tolerance",700,
        "capture_distance",6000,"capture_heading",20,"capture_bank",15,
        "capture_sink",45,"capture_settle",2,
        "prediction_dt",4,"prediction_horizon",600,"search_timeout",24,
        "predictor_steps_per_tick",2,"prediction_refresh",12,
        "minimum_clearance",700,"maximum_bank",35,
        "low_drag_aoa",6,"drag_aoa",20,"thin_aoa",8,
        "assist_time",30,"assist_dv",180,"assist_throttle",0.6,
        "assist_fuel_fraction",0.08,"capture_energy_tolerance",1800,
        "maximum_duration",1200,"powered_speed_band",60,"turn_room_fraction",0.8,
        "maximum_prediction_age",60,"diversion_bank_gain",4,
        "diversion_minimum_q",0.03,"flight_path_gain",0.8,
        "team_distance",20000,"team_height_tolerance",2500,"team_heading",45,
        "team_energy_minimum",-500,"team_energy_maximum",5000,
        "team_settle",0.5,"airbreathing_height",10000,"rocket_height",14000,
        "maximum_diversion_bank",120,"upright_diversion_bank",70,"steep_bank_height",7000,
        "steep_bank_speed",800,"steep_bank_height_margin",2500,"team_runway_distance",60000).
}
function recovery_aed_turn_distance {
    parameter speed_value, heading_error, gravity_value, config_AED.
    return speed_value^2/(max(gravity_value,0.01)*tan(config_AED["maximum_bank"])) *
        abs(heading_error)*constant:degtorad.
}
// A failed forecast is not a propulsion failure. This uses the live, limited,
// resource-accessible power estimate rather than the installed engine count.
function recovery_aed_power_available {
    parameter power.
    return power["healthy_rapiers"] > 0 and power["thrust"] > 0 and power["dv"] > 0.
}
// Exploratory diversion only: geometry does not certify a landing or TEAM
// capture. The normal predictor and actual capture gate must still approve it.
function recovery_aed_powered_target {
    parameter search, input_state, config_AED.
    local preferred is lex("selected",false,"score",1e12).
    local gravity_value is ship:body:mu/ship:body:radius^2.
    for candidate in search["candidates"] {
        local intake is candidate["capture_interface"].
        local range_now is calcdistance_m(input_state["latlong"],intake["target_latlng"]).
        local course_error is normalized_heading_error(
            heading_between(input_state["latlong"],intake["target_latlng"]),compass_for_simstate(input_state)).
        local route_cost is range_now+recovery_aed_turn_distance(input_state["surfvel"]:mag,
            course_error,gravity_value,config_AED).
        if route_cost < preferred["score"] {
            // Copy the candidate so exploratory steering cannot alter the
            // predictor's feasibility result or its best-candidate cache.
            set preferred to lex("selected",true,"provisional",true,
                "location",candidate["location"],"runway_num",candidate["runway_num"],
                "start",candidate["start"],"end",candidate["end"],
                "heading",candidate["heading"],"altitude",candidate["altitude"],
                "capture_interface",intake,"distance_m",range_now,"score",route_cost,
                "screen",lex("feasible",false,"reason","powered_exploration","energy_margin",0)).
        }
    }
    return preferred.
}
// Steer immediately while decelerating. The arc estimate is diagnostic: a
// shrinking distance must not level the wings and force an overshoot.
function recovery_aed_powered_command {
    parameter speed_value, sink_value, clearance, distance_value, course_error,
        gravity_value, dynamic_pressure, config_AED.
    parameter capture_clearance is clearance.
    local arc_m is recovery_aed_turn_distance(speed_value,course_error,gravity_value,config_AED).
    local can_turn is clearance >= config_AED["minimum_clearance"] and
        dynamic_pressure > config_AED["diversion_minimum_q"] and speed_value >= 120.
    local bank_value is 0.
    local bank_limit is config_AED["maximum_bank"].
    if clearance >= config_AED["minimum_capture_height"] and speed_value >= 200 and
       sink_value >= -config_AED["capture_sink"] {
        set bank_limit to config_AED["upright_diversion_bank"].
    }
    if clearance >= config_AED["steep_bank_height"] and speed_value >= config_AED["steep_bank_speed"] and
       clearance-capture_clearance >= config_AED["steep_bank_height_margin"] and
       sink_value >= -config_AED["capture_sink"] and dynamic_pressure > 0.1 {
        set bank_limit to config_AED["maximum_diversion_bank"].
    }
    local intent_value is "powered_diversion".
    if can_turn {
        set bank_value to max(-bank_limit,min(bank_limit,
            -config_AED["diversion_bank_gain"]*course_error)).
    } else if abs(course_error) > config_AED["capture_heading"] {
        set intent_value to "turn_authority_limited".
    }
    local time_to_capture is max(30,distance_value/max(120,speed_value)).
    local desired_vs is max(-config_AED["capture_sink"],min(10,
        (capture_clearance-clearance)/time_to_capture)).
    local actual_gamma is arcsin(max(-1,min(1,sink_value/max(1,speed_value)))).
    local desired_gamma is arcsin(max(-1,min(1,desired_vs/max(1,speed_value)))).
    local aoa_value is max(0,min(config_AED["drag_aoa"],config_AED["low_drag_aoa"]+
        config_AED["flight_path_gain"]*(desired_gamma-actual_gamma)+
        2*(1/cos(min(70,abs(bank_value)))-1))).
    if abs(bank_value) > 90 {
        // Inverted lift lowers the flight path. Do not divide by cos(bank)
        // across 90 degrees or use the upright feedback sign here.
        set aoa_value to max(4,min(12,config_AED["low_drag_aoa"]-
            config_AED["flight_path_gain"]*(desired_gamma-actual_gamma))).
    }
    // Brakes shed excess energy without commanding a lofting 20-degree AoA.
    local brake_value is dynamic_pressure > 0.1 and
        speed_value > config_AED["maximum_capture_speed"] and clearance > config_AED["minimum_clearance"] and
        (clearance > config_AED["minimum_capture_height"]+config_AED["minimum_clearance"] or
         sink_value >= -config_AED["capture_sink"]).
    local throttle_value is max(0,min(1,(config_AED["capture_speed"]-speed_value)/config_AED["powered_speed_band"])).
    if clearance < config_AED["minimum_capture_height"]+config_AED["minimum_clearance"] and sink_value < -5 {
        set throttle_value to max(throttle_value,config_AED["assist_throttle"]).
    }
    return lex("aoa",aoa_value,"bank",bank_value,"throttle",throttle_value,
        "intent",intent_value,"turn_distance",arc_m,"turn_ready",can_turn,
        "desired_vs",desired_vs,"airbrake",brake_value,"bank_limit",bank_limit).
}
function recovery_aed_terminal_intake {
    parameter runway_distance,runway_height,config_AED.
    local energy_config is AVES["TerminalRoute"]["EnergyPlan"].
    local final_distance is AVES["TerminalRoute"]["final_distance"].
    local gravity_value is ship:body:mu/ship:body:radius^2.
    local final_height is calculate_glideslope_alt(final_distance,runway_height)-runway_height.
    // Include room for TEAM's circuit and the configured drag uncertainty.
    local route_distance is runway_distance+2*final_distance.
    local budget is terminal_energy_budget(route_distance,final_distance,final_height,
        min(200,AVES["TerminalRoute"]["EnergyPlan"]["circuit_turn_speed"]),gravity_value,
        max(0.05,energy_config["initial_clean_loss"]),0,energy_config).
    local required_energy is budget["required"]+budget["reserve"].
    local route_height is runway_height+max(config_AED["minimum_capture_height"],
        min(config_AED["maximum_capture_height"],required_energy+1000-
            config_AED["capture_speed"]^2/(2*gravity_value))).
    return lex("required",required_energy,"target_altitude",route_height).
}
// TEAM can build its own intercept/pattern. A live intake check may approve
// a provisional destination without requiring an unpowered forecast to pass.
function recovery_aed_team_gate {
    parameter range_error,height_error,speed_value,sink_rate,course_error,bank_angle,
        clearance,energy_margin,config_AED.
    parameter runway_range is 1e12.
    local ready_now is (range_error <= config_AED["team_distance"] or
        runway_range <= config_AED["team_runway_distance"]) and
        clearance <= config_AED["maximum_capture_height"]+config_AED["team_height_tolerance"] and
        speed_value <= config_AED["maximum_capture_speed"] and speed_value >= 120 and
        sink_rate >= -config_AED["capture_sink"] and sink_rate <= 10 and
        abs(course_error) <= config_AED["team_heading"] and
        abs(bank_angle) <= config_AED["maximum_bank"] and
        clearance >= config_AED["minimum_clearance"] and
        energy_margin >= config_AED["team_energy_minimum"] and
        energy_margin <= config_AED["team_energy_maximum"].
    return lex("valid",ready_now,"reason","live_TEAM_intake","distance",range_error,
        "height_error",height_error,"heading",course_error,"energy_margin",energy_margin).
}
function recovery_aed_energy {
    parameter current_height,current_speed,capture_height,capture_speed,gravity_value.
    return current_height-capture_height+
        (current_speed^2-capture_speed^2)/(2*max(gravity_value,0.01)).
}
// Conservative independent propulsion budget; the aero predictor is unpowered.
function recovery_aed_assist {
    parameter power,lf_amount,ox_amount,lf_reserve,ox_reserve,config_AED.
    local available_lf is max(0,lf_amount-lf_reserve).
    local available_ox is max(0,ox_amount-ox_reserve).
    local seconds_allowed is config_AED["assist_time"].
    if power["lf_flow"] > 0 {
        set seconds_allowed to min(seconds_allowed,
            available_lf*config_AED["assist_fuel_fraction"]/power["lf_flow"]).
    }
    if power["ox_flow"] > 0 {
        set seconds_allowed to min(seconds_allowed,
            available_ox*config_AED["assist_fuel_fraction"]/power["ox_flow"]).
    }
    local dv_allowed is min(config_AED["assist_dv"],min(power["dv"],
        max(0,power["acceleration"])*seconds_allowed)).
    return lex("time",max(0,seconds_allowed),"dv",max(0,dv_allowed),
        "lf",power["lf_flow"]*max(0,seconds_allowed),
        "ox",power["ox_flow"]*max(0,seconds_allowed)).
}
// Solve the upstream point against the real terminal intake profile and work
// budget at <=350m/s. The terminal clean-loss model is never used at ascent speed.
function recovery_aed_interface {
    parameter threshold,rnw_heading,rnw_height,current_height,config_AED.
    local height_above is min(config_AED["maximum_capture_height"],
        (current_height-rnw_height)*config_AED["capture_fraction"]).
    local valid_height is height_above >= config_AED["minimum_capture_height"].
    local capture_height is rnw_height+max(0,height_above).
    local speed_reference is AVES["TerminalRoute"]["EnergyPlan"]["circuit_turn_speed"].
    set speed_reference to min(speed_reference,200).
    local energy_config is AVES["TerminalRoute"]["EnergyPlan"].
    local clean_loss is max(0.05,energy_config["initial_clean_loss"]).
    local final_distance is AVES["TerminalRoute"]["final_distance"].
    local gravity_value is ship:body:mu/ship:body:radius^2.
    local final_height is calculate_glideslope_alt(final_distance,rnw_height)-rnw_height.
    local intake_energy is height_above+config_AED["capture_speed"]^2/(2*gravity_value).
    local final_energy is final_height+speed_reference^2/(2*gravity_value).
    local upstream_distance is max(calculate_distance_from_alt(capture_height,rnw_height),
        final_distance+max(0,intake_energy-final_energy)/clean_loss).
    local terminal_budget is terminal_energy_budget(upstream_distance,final_distance,
        final_height,speed_reference,gravity_value,clean_loss,0,energy_config).
    local target_point is get_geoposition_along_heading(threshold,rnw_heading+180,upstream_distance).
    return lex("valid",valid_height,"target_altitude",capture_height,
        "target_latlng",target_point,"ercl_target",target_point,
        "ercl_distance",upstream_distance,"approach_bearing",rnw_heading,
        "lateral_offset",0,"terminal_required",terminal_budget["required"],
        "terminal_reference_speed",speed_reference,
        "team_interface_box",lex("min_altitude",capture_height-config_AED["capture_altitude_tolerance"],
            "max_altitude",capture_height+config_AED["capture_altitude_tolerance"],
            "dist_tolerance",config_AED["capture_distance"])).
}
function recovery_aed_screen {
    parameter candidate_distance,heading_error,speed_value,gravity_value,
        low_prediction,drag_prediction,assist_budget,config_AED.
    local result is lex("feasible",false,"reason","prediction_nonconverged",
        "energy_margin",0,"assist_required",0,"score",999999999).
    if not low_prediction["converged"] or not drag_prediction["converged"] { return result. }
    local turn_distance is recovery_aed_turn_distance(speed_value,heading_error,gravity_value,config_AED).
    if turn_distance > candidate_distance {
        set result["reason"] to "insufficient_turn_room". return result.
    }
    local reachable_distance is low_prediction["range"].
    local dissipation_distance is drag_prediction["range"].
    local extension is 0.5*assist_budget["dv"]*assist_budget["time"].
    if candidate_distance > reachable_distance+extension {
        set result["reason"] to "energy_shortage". return result.
    }
    if candidate_distance < dissipation_distance*0.85 {
        set result["reason"] to "excessive_arrival_energy". return result.
    }
    if drag_prediction["speed"] > config_AED["maximum_capture_speed"] {
        set result["reason"] to "drag_family_too_fast". return result.
    }
    set result["feasible"] to true.
    set result["reason"] to "feasible".
    set result["assist_required"] to max(0,candidate_distance-reachable_distance).
    set result["energy_margin"] to reachable_distance-candidate_distance.
    // Prefer feasible candidates ahead only after energy and turn screening.
    set result["score"] to candidate_distance+abs(heading_error)*2000.
    return result.
}
function recovery_aed_capture_gate {
    parameter range_error,height_error,speed_value,sink_rate,heading_error,bank_angle,
        clearance,energy_margin,elapsed_stable,config_AED.
    local ready_now is range_error <= config_AED["capture_distance"] and
        abs(height_error) <= config_AED["capture_altitude_tolerance"] and
        speed_value <= config_AED["maximum_capture_speed"] and speed_value >= 120 and
        sink_rate < -0.5 and sink_rate >= -config_AED["capture_sink"] and
        abs(heading_error) <= config_AED["capture_heading"] and
        abs(bank_angle) <= config_AED["capture_bank"] and
        clearance >= config_AED["minimum_clearance"] and
        abs(energy_margin) <= config_AED["capture_energy_tolerance"].
    return lex("valid",ready_now,"ready",ready_now and elapsed_stable >= config_AED["capture_settle"]).
}
function recovery_aed_prediction {
    parameter input_state,capture_height,bearing,profile,config_AED.
    return lex("state",clone_simstate(input_state),"origin",input_state["latlong"],
        "capture_height",capture_height,"bearing",bearing,"profile",profile,
        "complete",false,"converged",false,"reason","running","range",0,
        "speed",input_state["surfvel"]:mag,"steps",0).
}
// Small work slices keep the live DAP/engine monitor running between calls.
// Every family has both an integration horizon and a wall-clock search deadline.
function recovery_aed_prediction_step {
    parameter prediction,config_AED.
    if prediction["complete"] { return prediction. }
    local sim_state is prediction["state"].
    local heading_error is normalized_heading_error(prediction["bearing"],compass_for_simstate(sim_state)).
    local simulated_bank is max(-config_AED["maximum_bank"],
        min(config_AED["maximum_bank"],-heading_error*0.7)).
    local simulated_aoa is config_AED["low_drag_aoa"].
    if prediction["profile"] = "drag" {
        set simulated_aoa to config_AED["drag_aoa"].
        if sim_state["altitude"] > 35000 { set simulated_aoa to config_AED["thin_aoa"]. }
    }
    local aero_acceleration is sim_aeroaccel_load(sim_state["position"],sim_state["surfvel"],
        list(simulated_aoa,simulated_bank),ship:body:radius).
    set sim_state to update_simstate_total_accel(sim_state,
        aero_acceleration+gravitacc(sim_state["position"],ship:body:mu),
        config_AED["prediction_dt"],ship:body:angularvel,ship:body:radius).
    set prediction["state"] to sim_state.
    set prediction["steps"] to prediction["steps"]+1.
    set prediction["range"] to calcdistance_m(prediction["origin"],sim_state["latlong"]).
    set prediction["speed"] to sim_state["surfvel"]:mag.
    local clearance is sim_state["altitude"]-max(0,sim_state["latlong"]:terrainheight).
    if clearance < config_AED["minimum_clearance"] {
        set prediction["complete"] to true. set prediction["reason"] to "terrain".
    } else if sim_state["altitude"] <= prediction["capture_height"] and
        vdot(sim_state["surfvel"],sim_state["position"]:normalized) < 0 {
        set prediction["complete"] to true. set prediction["converged"] to true.
        set prediction["reason"] to "descending_capture_crossing".
    } else if sim_state["simtime"] >= config_AED["prediction_horizon"] {
        set prediction["complete"] to true. set prediction["reason"] to "horizon".
    }
    return prediction.
}
function recovery_aed_search {
    parameter input_state,rejected,assist_budget,config_AED.
    parameter existing_target is lex("selected",false).
    local candidates is list().
    local table is Location_constants["kerbin"].
    for key in table:keys {
        if key:endswith("_start") {
            local parts is key:split("_").
            if parts:length = 4 {
                local site is parts[0]. local runway_id is parts[2].
                local end_key is site+"_runway_"+runway_id+"_end".
                local height_key is site+"_runway".
                if table:haskey(end_key) and KerbinRunwayalt:haskey(height_key) and
                    not rejected:haskey(site+"_"+runway_id) {
                    local direction is heading_between(table[key],table[end_key]).
                    local intake is recovery_aed_interface(table[key],direction,
                        KerbinRunwayalt[height_key],input_state["altitude"],config_AED).
                    if existing_target["selected"] and existing_target["location"] = site and
                        existing_target["runway_num"] = runway_id {
                        set intake to existing_target["capture_interface"].
                    }
                    if intake["valid"] {
                        candidates:add(lex("selected",true,"location",site,"runway_num",runway_id,
                            "start",table[key],"end",table[end_key],"heading",direction,
                            "altitude",KerbinRunwayalt[height_key],"capture_interface",intake,
                            "runway_distance",calcdistance_m(input_state["latlong"],table[key]),
                            "distance",calcdistance_m(input_state["latlong"],intake["target_latlng"]),
                            "bearing",heading_between(input_state["latlong"],intake["target_latlng"]),
                            "score",999999999)).
                    }
                }
            }
        }
    }
    // Stable insertion sort by actual runway proximity, not location-table
    // insertion order or the potentially far upstream capture point.
    local nearby_index is 1.
    until nearby_index >= candidates:length {
        local nearby is candidates[nearby_index].
        local previous_index is nearby_index-1.
        until previous_index < 0 {
            if candidates[previous_index]["runway_distance"] <= nearby["runway_distance"] { break. }
            set candidates[previous_index+1] to candidates[previous_index].
            set previous_index to previous_index-1.
        }
        set candidates[previous_index+1] to nearby.
        set nearby_index to nearby_index+1.
    }
    if existing_target["selected"] {
        local reorder_index is 0.
        until reorder_index >= candidates:length {
            local reevaluate is candidates[reorder_index].
            if reevaluate["location"] = existing_target["location"] and
                reevaluate["runway_num"] = existing_target["runway_num"] {
                local first_candidate is candidates[0].
                set candidates[0] to reevaluate.
                set candidates[reorder_index] to first_candidate.
                break.
            }
            set reorder_index to reorder_index+1.
        }
    }
    return lex("candidates",candidates,"index",0,"family","low","prediction",0,
        "input",input_state,"input_ut",time:seconds,"assist",assist_budget,"started",time:seconds,
        "complete",false,"reason","running","best",lex("selected",false,"score",999999999),"rejections",lexicon()).
}
function recovery_aed_search_refresh_candidate {
    parameter search, input_state, config_AED, retained_target.
    local candidate is search["candidates"][search["index"]].
    set search["input"] to input_state.
    set search["input_ut"] to time:seconds.
    if not retained_target["selected"] or
       retained_target["location"] <> candidate["location"] or
       retained_target["runway_num"] <> candidate["runway_num"] or
       (retained_target:haskey("provisional") and retained_target["provisional"]) {
        set candidate["capture_interface"] to recovery_aed_interface(candidate["start"],candidate["heading"],
            candidate["altitude"],input_state["altitude"],config_AED).
    }
    set candidate["distance"] to calcdistance_m(input_state["latlong"],candidate["capture_interface"]["target_latlng"]).
    set candidate["bearing"] to heading_between(input_state["latlong"],candidate["capture_interface"]["target_latlng"]).
    return search.
}
function recovery_aed_search_resume {
    parameter search.
    set search["complete"] to false.
    set search["reason"] to "running".
    set search["started"] to time:seconds.
    set search["rejections"] to lex().
    return search.
}
function recovery_aed_search_step {
    parameter search,config_AED.
    if search["complete"] { return search. }
    if search["index"] >= search["candidates"]:length {
        set search["reason"] to "exhausted".
        set search["complete"] to true. return search.
    }
    if time:seconds-search["started"] > config_AED["search_timeout"] {
        set search["reason"] to "timeout".
        set search["complete"] to true. return search.
    }
    local candidate is search["candidates"][search["index"]].
    if not candidate["capture_interface"]["valid"] {
        set search["rejections"][candidate["location"]+"_"+candidate["runway_num"]] to "capture_height_unavailable".
        set search["index"] to search["index"]+1.
        set search["prediction"] to 0.
        set search["family"] to "low".
        return search.
    }
    // Reject an impossible immediate turn before spending the entire slice
    // integrating two trajectories. Powered recovery can revisit it slower.
    if search["prediction"] = 0 and search["family"] = "low" and
       recovery_aed_turn_distance(search["input"]["surfvel"]:mag,
            normalized_heading_error(candidate["bearing"],compass_for_simstate(search["input"])),
            ship:body:mu/ship:body:radius^2,config_AED) > candidate["distance"] {
        set search["rejections"][candidate["location"]+"_"+candidate["runway_num"]] to "insufficient_turn_room".
        set search["index"] to search["index"]+1.
        return search.
    }
    if search["prediction"] = 0 {
        set search["prediction"] to recovery_aed_prediction(search["input"],
            candidate["capture_interface"]["target_altitude"],candidate["bearing"],search["family"],config_AED).
    }
    local slice_index is 0.
    until slice_index >= config_AED["predictor_steps_per_tick"] or search["prediction"]["complete"] {
        set search["prediction"] to recovery_aed_prediction_step(search["prediction"],config_AED).
        set slice_index to slice_index+1.
    }
    if search["prediction"]["complete"] {
        if search["family"] = "low" {
            set candidate["low"] to search["prediction"].
            set search["family"] to "drag".
        } else {
            set candidate["drag"] to search["prediction"].
            local screening is recovery_aed_screen(candidate["distance"],
                normalized_heading_error(candidate["bearing"],compass_for_simstate(search["input"])),
                search["input"]["surfvel"]:mag,ship:body:mu/ship:body:radius^2,
                candidate["low"],candidate["drag"],search["assist"],config_AED).
            if search:haskey("input_ut") and time:seconds-search["input_ut"] > config_AED["maximum_prediction_age"] {
                set screening["feasible"] to false.
                set screening["reason"] to "prediction_stale".
            }
            set candidate["screen"] to screening.
            if screening["feasible"] {
                set candidate["provisional"] to false.
                set candidate["score"] to screening["score"].
                if candidate["score"] < search["best"]["score"] { set search["best"] to candidate. }
                // Nearest viable runway wins; do not wait for distant sites.
                set search["reason"] to "feasible".
                set search["complete"] to true.
            } else {
                set search["rejections"][candidate["location"]+"_"+candidate["runway_num"]] to screening["reason"].
            }
            set search["family"] to "low". set search["index"] to search["index"]+1.
        }
        set search["prediction"] to 0.
    }
    return search.
}
