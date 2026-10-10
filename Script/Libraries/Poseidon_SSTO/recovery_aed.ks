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
        "maximum_duration",1200).
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
    local turn_distance is speed_value^2/(max(gravity_value,0.01)*tan(config_AED["maximum_bank"])) *
        abs(heading_error)*constant:degtorad.
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
                            "distance",calcdistance_m(input_state["latlong"],intake["target_latlng"]),
                            "bearing",heading_between(input_state["latlong"],intake["target_latlng"]),
                            "score",999999999)).
                    }
                }
            }
        }
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
        "input",input_state,"assist",assist_budget,"started",time:seconds,
        "complete",false,"best",lex("selected",false,"score",999999999),"rejections",lexicon()).
}
function recovery_aed_search_step {
    parameter search,config_AED.
    if search["complete"] { return search. }
    if time:seconds-search["started"] > config_AED["search_timeout"] or
        search["index"] >= search["candidates"]:length {
        set search["complete"] to true. return search.
    }
    local candidate is search["candidates"][search["index"]].
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
            set candidate["screen"] to screening.
            if screening["feasible"] {
                set candidate["score"] to screening["score"].
                if candidate["score"] < search["best"]["score"] { set search["best"] to candidate. }
            } else {
                set search["rejections"][candidate["location"]+"_"+candidate["runway_num"]] to screening["reason"].
            }
            set search["family"] to "low". set search["index"] to search["index"]+1.
        }
        set search["prediction"] to 0.
    }
    return search.
}
