function reset_sys{
    if defined abort_state and abort_state:haskey("managed") and abort_state["managed"] {
        set dapthrottle to 0.
        if dap:haskey("envelope") { set dap["envelope"]["min_throttle"] to 0. }
        lock throttle to recovery_throttle(dapthrottle,0).
        recovery_apply_limits().
        return.
    }
    if ship:altitude < 1000 {
        gear on.
        brakes on.
    }   
    if ship:altitude < 50000 {
        rapierson().
        nervsoff().
        togglerapiermode("AIR").
    }  
    else{
    brakes off.
    gear off.
    }
    //Set wheel brakes to 200%
    for gear_part in ship:partstitledpattern("GEAR") {
    //log  gear_part:allmodules to "mods.log".
    local brake_mod is gear_part:getmodule("ModuleWheelBrakes").
    brake_mod:setfield("brakes",200).
    }


    set dapthrottle to 0.
    if dap:haskey("envelope") {
        // reset_sys is also the terminal safety path.  Do not preserve a
        // temporary terrain/upset protection throttle floor after the
        // guidance loop has stopped: doing so leaves the craft firewalled
        // with no later DAP tick available to clear it.
        set dap["envelope"]["min_throttle"] to 0.
        lock throttle to max(dapthrottle,dap["envelope"]["min_throttle"]).
    } else {
        lock throttle to dapthrottle.
    }
    if ship:periapsis > 70000 or ship:altitude > 300000{
        //ag5 on.
        nervson().
        rapiersoff().
        toggleRapierMode("AIR").
    }
    else{
        //ag5 off.
    }
    lights on.


 
    
    
}

function check_inputs{
    if TargetApoapsis < TargetPeriapsis or TargetPeriapsis < 75000 or TargetInclination < 0 or TargetInclination > 180 or TargetApoapsis > BODY:soiradius{
    set step to "end".
    set Lastest_status to "wrong setup".
    flight_log_event("input_invalid","apoapsis=" + TargetApoapsis + "|periapsis=" + TargetPeriapsis + "|inclination=" + TargetInclination).
    }
}

// Continuous range-control law: 2% overshoot needs no range reduction;
// 7% or more requests the maximum basic-entry bank.
function basic_entry_bank_magnitude {
    parameter percentage_error.
    return max(0,min(70,70*(-percentage_error-2)/5)).
}

function goto_target{
    if not(defined reentry_target){
            set ecrl_2hac to get_geoposition_along_heading(runway_start,runway_heading+180,Aves["HacDistance"]*2).
            if calcdistance(ship:geoposition,runway_start) > calcdistance(ship:geoposition,ecrl_2hac){
                set reentry_target to runway_start.
            }else{set reentry_target to ecrl_2hac.}

        }
    local sim is current_simstate().
    
    set dap["aoa"]["target_aoa"] to AVES["EGAOA"](ship:altitude).
    local basic_target_altitude is 0.
    if defined Team_interface {
        set reentry_target to Team_interface["target_latlng"].
        set basic_target_altitude to Team_interface["target_altitude"].
        // Keep a descending prediction while the handoff speed gate is pending.
        if ship:altitude <= basic_target_altitude {
            set basic_target_altitude to max(runway_altitude,ship:altitude-1000).
        }
    }
    local y is sim_with_bank(sim,0,basic_target_altitude,reentry_target).
    local x is y["final_state"]["latlong"].

    set distance_between_runway_start_IMPACTPOS to calcdistance(ship:geoposition,reentry_target) - calcdistance(ship:geoposition,x).



        // Calculate the total runway distance dynamically

        // Calculate the percentage difference
        set percentage_diff to 0.
        local basic_target_distance is calcdistance(ship:geoposition,reentry_target).
        if basic_target_distance > 0.001 {
            set percentage_diff to calc_percentage(distance_between_runway_start_IMPACTPOS, basic_target_distance).
        }

        set t_bank to basic_entry_bank_magnitude(percentage_diff).

        // Calculate brake state based on percentage difference
        if percentage_diff <= -10 {
            brakes on.
        } else {
            brakes off.
        }    
        local heading_error is normalized_heading_error(heading_to_target(reentry_target),compass_for_prograde()).
        // A lateral undershoot still deserves a turn if a modest bank reduces
        // predicted geographic miss. Do not spend range on a turn that worsens it.
        if t_bank < 1 and abs(heading_error) > AVES["EG_rev°"] and ship:altitude > basic_target_altitude {
            local turn_probe_bank is min(25,abs(heading_error)).
            local turn_probe is sim_with_bank(sim,turn_probe_bank,basic_target_altitude,reentry_target).
            if calcdistance(turn_probe["final_state"]["latlong"],reentry_target) < calcdistance(x,reentry_target) {
                set t_bank to turn_probe_bank.
            }
        }
        if not (defined entry_turnside) or
           (entry_turnside <> "right" and entry_turnside <> "left") {
            if heading_error >= 0{
                set entry_turnside to "right".
            }
            if heading_error < 0{
                set entry_turnside to "left".
            }
        }
        if heading_error > AVES["EG_rev°"]{
            set entry_turnside to "right".
        }
        if heading_error < -AVES["EG_rev°"]{
            set entry_turnside to "left".
        }
        if entry_turnside = "right"{
          
            set dap["aoa"]["target_bank"] to -t_bank.
        }
        if entry_turnside = "left"{
            
           
            set dap["aoa"]["target_bank"] to t_bank.
        }
  

    
    
}


function log_status {
    parameter message.
    if ship:altitude < 70000{
    flight_log_event("status","message=" + message + "|altitude=" + round(ship:altitude,1) + "|airspeed=" + round(ship:airspeed,1) + "|pitch=" + round(pitch_for(),2) + "|throttle=" + round(throttle,3)).
}
}


function normalized_heading_error {
    parameter target_heading, current_heading.
    local error is target_heading - current_heading.
    until abs(error) <= 180 {
        if error > 180 { set error to error - 360. }
        if error < -180 { set error to error + 360. }
    }
    return error.
}

function abort_engine_snapshot {
    local snapshot is lex(
        "rapier", lex("installed",0,"working",0,"failed",0,"failed_ids",lex()),
        "nerv", lex("installed",0,"working",0,"failed",0,"failed_ids",lex())
    ).
    if defined recovery_engines {
        for identity in recovery_engines:keys { set recovery_engines[identity]["present"] to false. }
        for kind in list("rapier","nerv") {
            local pattern is "R.A.P.I.E.R".
            if kind = "nerv" { set pattern to "LV-N". }
            for engine_part in ship:partstitledpattern(pattern) {
                local identity is "part_"+engine_part:uid.
                if recovery_engines:haskey(identity) {
                    set recovery_engines[identity]["present"] to true.
                    set recovery_engines[identity]["part"] to engine_part.
                }
            }
        }
        for identity in recovery_engines:keys {
            local entry is recovery_engines[identity].
            local kind is entry["kind"].
            local was_failed is entry["failed"].
            set snapshot[kind]["installed"] to snapshot[kind]["installed"]+1.
            if not entry["present"] {
                set entry["failed"] to true.
                set entry["failure_reason"] to "missing_part".
            } else if entry["desired"] and not entry["isolated"] and not entry["failed"] {
                if not entry["part"]:ignition {
                    set entry["failed"] to true.
                    set entry["failure_reason"] to "commanded_engine_shutdown".
                } else if ship:control:mainthrottle > 0.05 and time:seconds-entry["commanded_since"] >= 2 {
                    if entry["part"]:flameout or entry["part"]:availablethrust <= 0 or entry["part"]:thrust <= 0.01 {
                        if entry["fault_since"] < 0 { set entry["fault_since"] to time:seconds. }
                        if time:seconds-entry["fault_since"] >= 2 {
                            set entry["failed"] to true.
                            set entry["failure_reason"] to "no_delivered_thrust".
                        }
                    } else { set entry["fault_since"] to -1. }
                } else { set entry["fault_since"] to -1. }
            }
            if entry["failed"] and not was_failed {
                flight_log_event("recovery_engine_failure","id="+identity+"|kind="+kind+"|reason="+entry["failure_reason"]).
            }
            if entry["failed"] { snapshot[kind]["failed_ids"]:add(identity,true). }
            else { set snapshot[kind]["working"] to snapshot[kind]["working"]+1. }
        }
        for kind in list("rapier","nerv") {
            set snapshot[kind]["failed"] to snapshot[kind]["failed_ids"]:keys:length.
        }
        return snapshot.
    }
    local rapier_parts is ship:partstitledpattern("R.A.P.I.E.R").
    set snapshot["rapier"]["installed"] to rapier_parts:length.
    for engine_part in rapier_parts {
        if engine_part:ignition {
            set snapshot["rapier"]["working"] to snapshot["rapier"]["working"] + 1.
        }else{
            snapshot["rapier"]["failed_ids"]:add("part_" + engine_part:uid,true).
        }
    }
    set snapshot["rapier"]["failed"] to snapshot["rapier"]["installed"] - snapshot["rapier"]["working"].

    local nerv_parts is ship:partstitledpattern("LV-N").
    set snapshot["nerv"]["installed"] to nerv_parts:length.
    for engine_part in nerv_parts {
        if engine_part:ignition {
            set snapshot["nerv"]["working"] to snapshot["nerv"]["working"] + 1.
        }else{
            snapshot["nerv"]["failed_ids"]:add("part_" + engine_part:uid,true).
        }
    }
    set snapshot["nerv"]["failed"] to snapshot["nerv"]["installed"] - snapshot["nerv"]["working"].
    return snapshot.
}

function check_abort {
    parameter phase is step.
    local engines is abort_engine_snapshot().
    // Intentionally shut-down engines are not failures.  During ascent all
    // commanded RAPIERs are expected; NERVs become expected after activation.
    if not rapiers and not(defined recovery_engines){
        set engines["rapier"]["failed"] to 0.
        set engines["rapier"]["failed_ids"] to lex().
    }
    if not nervs and not(defined recovery_engines){
        set engines["nerv"]["failed"] to 0.
        set engines["nerv"]["failed_ids"] to lex().
    }
    local abort_flag is engines["rapier"]["failed"] > 0 or engines["nerv"]["failed"] > 0.
    local scenario_display is "".
    if engines["rapier"]["failed"] > 0 { set scenario_display to scenario_display + engines["rapier"]["failed"] + "RO, ". }
    if engines["nerv"]["failed"] > 0 { set scenario_display to scenario_display + engines["nerv"]["failed"] + "NO, ". }
    local abort_info is lex(
        "abort",abort_flag,"mode","",
        "scenario",lex("rapiers_out",engines["rapier"]["failed"],"nervs_out",engines["nerv"]["failed"]),
        "scenario_disp",scenario_display,"engines",engines
    ).
    if abort_flag {
        set abort_info["mode"] to ask_abort_modes(abort_info["scenario"],phase).
        flight_log_event("abort_detected","phase=" + phase + "|scenario=" + scenario_display + "|mode=" + abort_info["mode"]).
    }
    return abort_info.
}

// Empirical V1 runway-stop model, fitted from the dedicated Poseidon abort
// runs.  It returns a conservative stopping requirement from the distance
// rolled since brake release; do not use it beyond the tested roll range.
function runway_abort_stop_distance {
    parameter takeoff_roll_distance_m.
    local model is AVES["Abort"]["RunwayStop"].
    return max(0, model["distance_slope"] * takeoff_roll_distance_m + model["distance_margin_m"]).
}

// Assess whether an abort begun now can stop before the departure runway end.
// The start position must be captured exactly when the launch brakes release.
function runway_abort_feasibility {
    parameter takeoff_start_position, runway_end_position.
    local roll_distance is calcdistance_m(takeoff_start_position, ship:geoposition).
    local stop_distance is runway_abort_stop_distance(roll_distance).
    local runway_remaining is calcdistance_m(ship:geoposition, runway_end_position).
    local model_valid is roll_distance <= AVES["Abort"]["RunwayStop"]["validated_roll_distance_m"].
    return lex(
        "roll_distance_m",roll_distance,
        "required_stop_distance_m",stop_distance,
        "runway_remaining_m",runway_remaining,
        "model_valid",model_valid,
        "permitted",model_valid and stop_distance <= runway_remaining
    ).
}

// Brake-release readiness only. This does not predict runway performance.
// Pure state transitions below are exercised through the real kOS runtime.
function takeoff_spool_init {
    parameter expected_ids, spool_config.
    return lex("expected_ids",expected_ids:copy,"config",spool_config,
        "status","waiting","reason","not_started","blocked_engine","",
        "started",-1,"elapsed",0,"samples",lex(),"throttle_actual",0).
}

function takeoff_spool_engine_reason {
    parameter sample, spool_config.
    if not sample["ignition"] { return "engine_shutdown". }
    if sample["mode"] <> "AirBreathing" { return "wrong_engine_mode". }
    if sample["flameout"] { return "engine_flameout". }
    if sample["thrust_limit"] < 99.9 { return "engine_thrust_limited". }
    if sample["available_kn"] < spool_config["minimum_available_kn"] { return "no_available_thrust". }
    if sample["thrust_kn"] < spool_config["ready_fraction"]*sample["available_kn"] {
        return "engine_spooling".
    }
    return "ready".
}

function takeoff_spool_update {
    parameter spool_state, engine_samples, now_seconds, throttle_actual.
    if spool_state["status"] <> "waiting" { return spool_state. }
    local spool_config is spool_state["config"].
    if spool_state["started"] < 0 { set spool_state["started"] to now_seconds. }
    set spool_state["elapsed"] to now_seconds-spool_state["started"].
    set spool_state["samples"] to engine_samples.
    set spool_state["throttle_actual"] to throttle_actual.
    set spool_state["reason"] to "checking_engines".
    set spool_state["blocked_engine"] to "".
    local all_ready is true.
    if spool_state["expected_ids"]:length = 0 {
        set all_ready to false.
        set spool_state["reason"] to "no_engines".
    }
    for engine_id in spool_state["expected_ids"] {
        local engine_reason is "missing_engine".
        if engine_samples:haskey(engine_id) {
            set engine_reason to takeoff_spool_engine_reason(engine_samples[engine_id],spool_config).
            set engine_samples[engine_id]["reason"] to engine_reason.
        }
        if engine_reason <> "ready" and all_ready {
            set all_ready to false.
            set spool_state["reason"] to engine_reason.
            set spool_state["blocked_engine"] to engine_id.
        }
    }
    if throttle_actual < 0.99 and all_ready {
        set all_ready to false.
        set spool_state["reason"] to "waiting_full_throttle".
    }
    // Timeout wins at the boundary. Preserve the blocking reason for diagnosis.
    if spool_state["elapsed"] >= spool_config["timeout_seconds"] {
        set spool_state["status"] to "timeout".
    } else if all_ready {
        set spool_state["status"] to "ready".
        set spool_state["reason"] to "engines_ready".
    }
    return spool_state.
}

// Live sampling is separate from readiness math and from all predictors.
function takeoff_spool_samples {
    local engine_samples is lex().
    for engine_part in ship:partstitledpattern("R.A.P.I.E.R") {
        engine_samples:add("part_"+engine_part:uid,lex(
            "ignition",engine_part:ignition,"flameout",engine_part:flameout,
            "mode",engine_part:mode,"thrust_kn",engine_part:thrust,
            "available_kn",engine_part:availablethrust,"thrust_limit",engine_part:thrustlimit)).
    }
    return engine_samples.
}

// Empirical Poseidon takeoff envelope. Every craft-specific coefficient,
// validity range and named-departure exception is configured in AVES.
function takeoff_performance {
    parameter takeoff_mass_t, remaining_runway_m, rotation_speed_mps, rotation_pitch_deg.
    parameter density_ratio is 1, thrust_ratio is 1.
    parameter departure_site is "", runway_direction is "", start_offset_m is 0.
    parameter model_config is AVES["Takeoff"].
    parameter field_altitude_m is 72.68.
    local result is lex("model_valid",false,"sufficient",false,
        "liftoff_fits",false,"screen_fits",false,"reason","invalid_inputs",
        "rotation_distance_m",0,"liftoff_distance_m",0,"climb_distance_m",0,
        "required_runway_m",0,"required_departure_m",0,"runway_margin_m",0,"liftoff_speed_mps",0,
        "departure_evidence","none","departure_status","unknown",
        "estimated_feasible",false,"screen_beyond_runway_m",0,
        "screen_height_m",model_config["screen_height_m"],
        "distance_margin_fraction",model_config["distance_margin_fraction"],
        "reference_stop_at_rotation_m",0,"stop_reference_valid",false,
        "roll_coefficient",0,"roll_model","legacy","roll_within_fit_bounds",false,"roll_evidence","none").
    if takeoff_mass_t <= 0 or remaining_runway_m <= 0 or rotation_speed_mps <= 0 or
       density_ratio <= 0 or thrust_ratio <= 0 { return result. }
    local mass_ratio is takeoff_mass_t / model_config["reference_mass_t"].
    local roll_fit is takeoff_roll_calibration(takeoff_mass_t,field_altitude_m,
        departure_site+"/"+runway_direction,rotation_speed_mps,"rotation",model_config).
    local roll_coefficient is roll_fit["coefficient"] * roll_fit["mass_scale"] / thrust_ratio.
    set result["roll_coefficient"] to roll_coefficient.
    set result["roll_model"] to roll_fit["model"].
    set result["roll_within_fit_bounds"] to roll_fit["within_fit_bounds"] and
        abs(density_ratio-1) < model_config["density_ratio_tolerance"] and
        abs(thrust_ratio-1) < model_config["thrust_ratio_tolerance"].
    set result["roll_evidence"] to roll_fit["evidence"].
    local lift_speed is max(rotation_speed_mps,
        model_config["lift_speed_mps"] * sqrt(mass_ratio / density_ratio)).
    local rotation_distance is roll_coefficient * rotation_speed_mps^2.
    // Pitch starts at Rotate; do not equate this to becoming airborne.
    local response_speed is rotation_speed_mps + model_config["rotation_response"] / (2 * roll_coefficient).
    set lift_speed to max(lift_speed,response_speed).
    local lift_distance is roll_coefficient * lift_speed^2.
    local climb_distance is model_config["climb_distance_m"] * mass_ratio^model_config["climb_mass_exponent"] /
        density_ratio / thrust_ratio.
    local required_distance is (lift_distance + climb_distance) * (1+model_config["distance_margin_fraction"]).
    set result["rotation_distance_m"] to rotation_distance.
    set result["liftoff_distance_m"] to lift_distance.
    set result["climb_distance_m"] to climb_distance.
    set result["required_runway_m"] to lift_distance * (1+model_config["distance_margin_fraction"]).
    set result["required_departure_m"] to required_distance.
    set result["runway_margin_m"] to remaining_runway_m - lift_distance * (1+model_config["distance_margin_fraction"]).
    set result["screen_beyond_runway_m"] to max(0,required_distance-remaining_runway_m).
    set result["liftoff_speed_mps"] to lift_speed.
    set result["liftoff_fits"] to lift_distance * (1+model_config["distance_margin_fraction"]) <= remaining_runway_m.
    set result["screen_fits"] to required_distance <= remaining_runway_m.
    set result["model_valid"] to takeoff_mass_t >= model_config["minimum_mass_t"] and
        takeoff_mass_t <= model_config["maximum_mass_t"] and
        abs(rotation_speed_mps-model_config["validated_rotation_speed_mps"]) < model_config["rotation_speed_tolerance_mps"] and
        abs(rotation_pitch_deg-model_config["validated_rotation_pitch_deg"]) < model_config["rotation_pitch_tolerance_deg"] and
        abs(density_ratio-1) < model_config["density_ratio_tolerance"] and
        abs(thrust_ratio-1) < model_config["thrust_ratio_tolerance"] and
        field_altitude_m >= model_config["minimum_altitude_m"] and
        field_altitude_m <= model_config["maximum_altitude_m"].
    set result["estimated_feasible"] to result["liftoff_fits"].
    set result["sufficient"] to result["model_valid"] and result["liftoff_fits"].
    set result["reason"] to "extrapolated".
    if result["model_valid"] {
        set result["reason"] to "estimated_runway_sufficient".
        if not result["liftoff_fits"] { set result["reason"] to "runway_margin_unconfirmed". }
    }
    if result["estimated_feasible"] { set result["departure_status"] to "estimated_feasible". }
    local evidence_config is model_config["demonstrated_departure"].
    if departure_site = evidence_config["site"] and runway_direction = evidence_config["direction"] and
       takeoff_mass_t >= evidence_config["minimum_mass_t"] and takeoff_mass_t <= evidence_config["maximum_mass_t"] and
       abs(start_offset_m) <= evidence_config["maximum_start_offset_m"] and
       remaining_runway_m >= evidence_config["minimum_runway_m"] and result["model_valid"] {
        set result["departure_evidence"] to evidence_config["evidence"] .
        set result["departure_status"] to "demonstrated_departure".
        set result["reason"] to "demonstrated_departure".
        set result["sufficient"] to true.
    }
    set result["reference_stop_at_rotation_m"] to model_config["stop_reference_slope"] * rotation_speed_mps^2 +
        model_config["stop_reference_margin_m"].
    set result["stop_reference_valid"] to rotation_speed_mps >= model_config["minimum_stop_reference_speed_mps"] and
        rotation_speed_mps <= model_config["maximum_stop_reference_speed_mps"].
    return result.
}

// Shared empirical altitude/mass ground-roll fit. It does not certify lift,
// climb, braking or obstacle clearance. Callers apply the returned mass scale.
function takeoff_roll_calibration {
    parameter craft_mass, field_altitude_m, runway_key, reference_speed_mps, fit_kind, model_config.
    local altitude_delta is max(0,field_altitude_m-model_config["v1_roll_reference_altitude_m"]).
    local quadratic_term is 0.
    local mass_exponent is 1.
    local fitted_delta is altitude_delta.
    if model_config:haskey("roll_altitude_quadratic") {
        set quadratic_term to model_config["roll_altitude_quadratic"].
        set mass_exponent to model_config["roll_mass_exponent"].
        set fitted_delta to min(altitude_delta,model_config["roll_fit_maximum_altitude_m"]-
            model_config["v1_roll_reference_altitude_m"]).
    }
    // Beyond the fit range continue the nonnegative endpoint slope, so the
    // quadratic can never turn around and predict a shorter high-altitude roll.
    local endpoint_slope is max(0,model_config["v1_roll_altitude_exponent"]+
        2*quadratic_term*fitted_delta).
    local altitude_log_factor is model_config["v1_roll_altitude_exponent"]*fitted_delta+
        quadratic_term*fitted_delta^2+endpoint_slope*(altitude_delta-fitted_delta).
    local altitude_k is model_config["v1_roll_fit_coefficient"] *
        2.718281828459045^altitude_log_factor.
    local runway_factor is 1.
    local fit_model is "three_field_v2".
    // Retain the previously measured Area-15 correction; the new altitude and
    // mass coefficients are shared by all runways, including Harvester.
    if model_config["v1_roll_runway_factors"]:haskey(runway_key) {
        set runway_factor to model_config["v1_roll_runway_factors"][runway_key].
        set fit_model to "runway_fit_v3".
    }
    local fitted_k is altitude_k*runway_factor*(1+model_config["v1_roll_margin_fraction"]).
    // Preserve the conservative low-field takeoff envelope used before this fit.
    if fit_kind = "rotation" { set fitted_k to max(model_config["roll_coefficient"],fitted_k). }
    local result is lex("coefficient",fitted_k,"mass_scale",(craft_mass/model_config["reference_mass_t"])^mass_exponent,
        "model",fit_model,"within_fit_bounds",false,"evidence","none","runway_factor",runway_factor).
    if model_config:haskey("roll_altitude_quadratic") {
        set result["model"] to "global_roll_v4".
        set result["evidence"] to model_config["roll_fit_evidence"].
        set result["within_fit_bounds"] to field_altitude_m >= model_config["roll_fit_minimum_altitude_m"] and
            field_altitude_m <= model_config["roll_fit_maximum_altitude_m"] and
            craft_mass >= model_config["roll_fit_minimum_mass_t"] and
            craft_mass <= model_config["roll_fit_maximum_mass_t"] and
            reference_speed_mps >= model_config["roll_fit_minimum_speed_mps"] and
            reference_speed_mps <= model_config["roll_fit_maximum_speed_mps"].
    }
    return result.
}

// Poseidon runway preflight assessment. Generic runway geometry is provided by
// lib_navigation; craft assumptions remain in AVES.
function assess_takeoff_runway {
    parameter selected_runway.
    local takeoff_config is AVES["Takeoff"].
    local estimate is takeoff_performance(ship:mass,0,AVES["Speed"]["Rotate"],AVES["Ascent"]["rotate_pitch"]).
    set estimate["remaining_runway_m"] to 0.
    set estimate["geometry_valid"] to false.
    set estimate["along_track_m"] to 0.
    set estimate["cross_track_m"] to 0.
    set estimate["facing_error_deg"] to 0.
    set estimate["runway_key"] to "".
    set estimate["field_altitude_m"] to ship:altitude.
    set estimate["mass_t"] to ship:mass.
    set estimate["nominal_propulsion_assumed"] to true.
    if ship:body:name <> takeoff_config["body"] or selected_runway["heading"] < 0 {
        set estimate["reason"] to "unknown_runway_or_body".
        return estimate.
    }
    local runway_length is calcdistance_m(selected_runway["start"],selected_runway["end"]).
    local start_distance is calcdistance_m(selected_runway["start"],ship:geoposition).
    local bearing_error is normalized_heading_error(heading_between(selected_runway["start"],ship:geoposition),selected_runway["heading"]).
    local facing_error is normalized_heading_error(compass_for(),selected_runway["heading"]).
    local geometry is takeoff_runway_geometry(runway_length,start_distance,bearing_error,facing_error,takeoff_config["geometry"]).
    set estimate to takeoff_performance(ship:mass,geometry["remaining_m"],AVES["Speed"]["Rotate"],AVES["Ascent"]["rotate_pitch"],
        1,1,selected_runway["location"],selected_runway["runway_num"],geometry["along_track_m"],takeoff_config,ship:altitude).
    set estimate["remaining_runway_m"] to geometry["remaining_m"].
    set estimate["runway_key"] to selected_runway["location"]+"/"+selected_runway["runway_num"].
    set estimate["field_altitude_m"] to ship:altitude.
    set estimate["mass_t"] to ship:mass.
    set estimate["nominal_propulsion_assumed"] to true.
    set estimate["geometry_valid"] to geometry["valid"].
    set estimate["facing_error_deg"] to facing_error.
    set estimate["along_track_m"] to geometry["along_track_m"].
    set estimate["cross_track_m"] to geometry["cross_track_m"].
    if not geometry["valid"] {
        set estimate["model_valid"] to false.
        set estimate["sufficient"] to false.
        set estimate["estimated_feasible"] to false.
        set estimate["departure_status"] to "unknown".
        set estimate["reason"] to "not_aligned_on_runway".
    }
    if ship:altitude < takeoff_config["minimum_altitude_m"] or ship:altitude > takeoff_config["maximum_altitude_m"] {
        set estimate["model_valid"] to false.
        set estimate["sufficient"] to false.
        set estimate["departure_status"] to "unknown".
        set estimate["reason"] to "unvalidated_atmosphere".
        if estimate["roll_within_fit_bounds"] {
            set estimate["reason"] to "ground_roll_fit_departure_unvalidated".
        }
    }
    return estimate.
}

function ask_abort_modes {
    parameter scenarios, phase.
    local ro is scenarios["rapiers_out"].
    local no is scenarios["nervs_out"].
    if phase = "apoapsis_build" or phase = "coast" or phase = "insertion" or phase = "circularize" or phase = "circ" or
       (defined recovery_nominal_cutoff and recovery_nominal_cutoff) {
        if no > 0 { return "edr". }
        return "ato".
    }
    if phase = "closed_cycle_climb" {
        if no > 0 {
            if ro < 4 { return "aed". }
            return "edr".
        }
        return "ato".
    }
    if phase = "nerv_assist" {
        if ro >= 4 { return "contingency_abort". }
        if no > 0 or ro >= 2 { return "aed". }
        return "ato".
    }
    if ro >= AVES["Abort"]["contingency_rapiers_out"] { return "contingency_abort". }
    if phase = "launch" { return "runway_abort". }
    if phase = "rotate" or phase = "ascent_alignment" { return "rtls". }
    return "atr".
}

function create_abort_state {
    parameter abort_info, origin_step, departure_runway.
    local lf_origin is ship:liquidfuel.
    local cutoff is false.
    if defined recovery_initial_lf { set lf_origin to recovery_initial_lf. }
    if defined recovery_nominal_cutoff { set cutoff to recovery_nominal_cutoff. }
    return lex(
        "active",abort_info["abort"],"mode",abort_info["mode"],
        "managed",abort_info["mode"] = "aed" or abort_info["mode"] = "ato" or abort_info["mode"] = "edr",
        "current_ascent_phase",origin_step,"nominal_cutoff",cutoff,
        // An abort must be able to use all remaining oxidizer in RAPIER
        // closed cycle. Preserve the LF floor for NERV/landing margins, but
        // do not strand oxidizer behind a recovery reserve.
        "lf_reserve",lf_origin*0.1,"ox_reserve",0,
        "orbit_attempted",false,"orbit_abandoned",false,"suppress_orbit",false,"rejected_targets",lex(),"committed",false,
        "submode",abort_info["scenario"]["rapiers_out"] + "RO",
        "phase","initialize","phase_entered",time:seconds,"source_step",origin_step,
        "scenario",abort_info["scenario"],"engines",abort_info["engines"],
        "departure_runway",departure_runway,"nervs_were_active",nervs,
        "runway_stop",lex("roll_distance_m",0,"required_stop_distance_m",0,"runway_remaining_m",0,"model_valid",false,"permitted",false),
        "target",lex("selected",false,"location","","runway_num","","start","","end","","heading",-1,"altitude",-1,"distance_m",0,"score",0),
        "policy",lex("use_nervs",false,"fuel_dump",false,"target_mass",ship:mass,"turn_bank",0),
        "handoff",lex("started",false,"complete",false),
        "result",lex("success",false,"reason",""),
        "last_failure_refresh",time:seconds
    ).
}

function abort_refresh_state {
    parameter state.
    local snapshot is abort_engine_snapshot().
    for kind in list("rapier","nerv") {
        local observe_kind is defined recovery_engines or (kind = "rapier" and rapiers) or (kind = "nerv" and nervs).
        if observe_kind and snapshot:haskey(kind) {
            if not state["engines"]:haskey(kind) { state["engines"]:add(kind,snapshot[kind]). }
            else {
                for identity in snapshot[kind]["failed_ids"]:keys {
                    set state["engines"][kind]["failed_ids"][identity] to true.
                }
                set state["engines"][kind]["failed"] to state["engines"][kind]["failed_ids"]:keys:length.
                set state["engines"][kind]["working"] to max(0,state["engines"][kind]["installed"]-state["engines"][kind]["failed"]).
            }
        }
    }
    set state["scenario"]["rapiers_out"] to state["engines"]["rapier"]["failed"].
    set state["scenario"]["nervs_out"] to state["engines"]["nerv"]["failed"].
    set state["submode"] to state["scenario"]["rapiers_out"]+"RO".
    set state["failure_summary"] to state["submode"]+","+state["scenario"]["nervs_out"]+"NO".
    set state["last_failure_refresh"] to time:seconds.
    recovery_apply_limits().
    if not (state:haskey("managed") and state["managed"]) and
       state["scenario"]["rapiers_out"] >= AVES["Abort"]["contingency_rapiers_out"] and
       state["mode"] <> "contingency_abort" {
        flight_log_event("contingency_escalation","from="+state["mode"]+"|rapiers_out="+state["scenario"]["rapiers_out"]).
        set state["mode"] to "contingency_abort".
        set state["phase"] to "initialize".
        set state["phase_entered"] to time:seconds.
        set state["target"]["selected"] to false.
        set state["handoff"]["started"] to false.
    }
    return state.
}

function abort_set_fuel_dump {
    parameter enabled.
    for drain_part in ship:partstitledpattern("FTE-1") {
        local drain_module is drain_part:getmodule("ModuleResourceDrain").
        if enabled {
            drain_module:setfield("Drain", "Started").
            drain_module:setfield("Drain Mode","Vessel").
        }else{
            drain_module:setfield("Drain", false).
        }
    }
}

function abort_select_runway {
    parameter config_select is AVES["Abort"]["RunwaySelection"].
    local candidate_rows is list().
    local selection_ut is time:seconds.
    local runways is location_constants["kerbin"].
    local best is lex("selected",false,"location","","runway_num","","start","","end","","heading",-1,"altitude",-1,"distance_m",0,"score",999999999999).
    for runway_key in runways:keys {
        if runway_key:endswith("_start") and runway_key:contains("_runway_") {
            local parts is runway_key:split("_runway_").
            local location_name is parts[0].
            local runway_number is parts[1]:split("_")[0].
            local end_key is location_name + "_runway_" + runway_number + "_end".
            if runways:haskey(end_key) and KerbinRunwayalt:haskey(location_name + "_runway") {
                local runway_start_ is runways[runway_key].
                local runway_end_ is runways[end_key].
                local distance_ is calcdistance_m(ship:geoposition,runway_start_).
                local candidate_row is lex("location",location_name,"runway_num",runway_number,
                    "distance_m",distance_,"heading_error",-1,"penalty_m",0,"score",-1,"eligible",false).
                candidate_rows:add(candidate_row).
                if distance_ <= config_select["maximum_distance"] {
                    local bearing_error is abs(normalized_heading_error(heading_to_target(runway_start_),compass_for_prograde())).
                    local score_ is distance_ + bearing_error * config_select["heading_weight"].
                    if bearing_error > config_select["ahead_angle"] { set score_ to score_ + config_select["behind_penalty"]. }
                    set candidate_row["heading_error"] to bearing_error.
                    set candidate_row["penalty_m"] to score_-distance_-bearing_error*config_select["heading_weight"].
                    set candidate_row["score"] to score_.
                    set candidate_row["eligible"] to true.
                    if score_ < best["score"] {
                        local altitude_ is KerbinRunwayalt[location_name + "_runway"].
                        set best to lex(
                            "selected",true,"location",location_name,"runway_num",runway_number,
                            "start",runway_start_,"end",runway_end_,"heading",heading_between(runway_start_,runway_end_),
                            "altitude",altitude_,"distance_m",distance_,"score",score_
                        ).
                    }
                }
            }
        }
    }
    if best["selected"] {
        flight_log_event("atr_runway_selected","location=" + best["location"] + "|runway=" + best["runway_num"] + "|distance_m=" + round(best["distance_m"]) + "|score=" + round(best["score"])).
    }else{
        flight_log_event("atr_runway_selection_failed","").
    }
    set best["candidates"] to candidate_rows.
    set best["assessment_ut"] to selection_ut.
    set best["search_complete"] to true.
    set best["selection_rule"] to "range_heading_penalty".
    if defined POS_LOG_LEVEL { flight_log_runway_candidates(best,"atr"). }
    return best.
}
local Poseidon_SSTO is lex().
Poseidon_SSTO:add("Speed",Lexicon("MaxSpeed",2400,"MinSpeed",100,"Rotate",110)).
// Aircraft-style ascent profile.  Keep all Poseidon-specific ascent tuning here
// so the flight logic remains readable and can be adjusted without hunting for
// thresholds in the state machine.
Poseidon_SSTO:add("Ascent",lex(
    // Display reference only: two measured rolls at 1252-1254 m reached
    // 113.6 m/s surface speed, near the V1 model's 1255 m validity limit.
    // Actual V1 remains the live runway_abort_feasibility decision.
    "liftoff_height_above_runway",13,
    "rotate_height_above_runway",30,
    "rotate_pitch",20,
    "display_altitude",70000,
    "display_speed",2100,
    "default_launch_heading",90,
    "shallow_climb_pitch",9,
    "speed_build_target",440,
    // When the orbital ascent course differs substantially from the runway,
    // turn at a manageable speed before starting the normal acceleration run.
    "runway_alignment_heading_threshold",10,
    "runway_alignment_completion_tolerance",5,
    "runway_alignment_throttle_ramp_start",200,
    "runway_alignment_speed_limit",300,
    "runway_alignment_target_aoa",10,
    "runway_alignment_bank",45,
    "alignment_min_vs",2,
    "alignment_full_bank_vs",15,
    "alignment_target_vs",12,
    "alignment_vs_gain",0.5,
    "alignment_max_aoa",20,
    "alignment_max_pitch",30,
    "speed_build_pitch",10,
    "climb_altitude",20000,
    "climb_target_speed",1500,
    "climb_pitch",12,
    "nerv_pitch", 9,
    "nerv_activation_altitude",20000,
    "minimum_climb_vertical_speed",5,
    "closed_cycle_min_altitude",23000,
    "closed_cycle_max_altitude",57000,
    "closed_cycle_pitch_start",10,
    "closed_cycle_pitch_rate",1,
    "closed_cycle_pitch_max",30,
    "rapier_cutoff_apoapsis",57000,
    "apoapsis_build_pitch",15,
    "space_altitude",70000,
    "heading_tolerance",5,
    "speed_gain_threshold",0.5,
    "vertical_speed_recovery_pitch",2,
    "vertical_speed_recovery_threshold",0,
    "apoapsis_margin",500,
    "inclination_heading_fallback",90,
    // Ground-hold phasing for an ascent that has a same-body rendezvous target.
    // Tune these from flight logs if the vehicle's normal insertion time changes.
    "rendezvous_nominal_insertion_time",480,
    "rendezvous_window_angle",3
)).
// Poseidon takeoff model coefficients and evidence limits. The model is
// advisory outside these measured conditions; update from logged flights.
Poseidon_SSTO:add("Takeoff",lex(
    // Local engine readiness, independent of the runway performance estimate.
    "Spool",lex("ready_fraction",0.90,"timeout_seconds",30,"minimum_available_kn",1),
    // true: run preflight checks but attempt takeoff despite a refusal.
    // Engine-failure aborts and in-flight terrain protection remain active.
    "override_preflight_refusals",false,
    "body","Kerbin",
    "reference_mass_t",69.5,"minimum_mass_t",68.72565,"maximum_mass_t",70.04567,
    "roll_coefficient",0.107,"lift_speed_mps",133,"rotation_response",3.6,
    // Shared log-quadratic altitude / power-law mass roll fit. Fit flights
    // 369/373/374/375/433/434; check flights 376/380/381/435 independently.
    // The last two failed heavy Harvester departures inform ground roll only.
    // Keep the original low-field floor and a separate 2% acceleration reserve.
    "v1_roll_fit_coefficient",0.09770677642386852,"v1_roll_reference_altitude_m",72.68,
    "v1_roll_altitude_exponent",0.00012206929617381205,"v1_roll_margin_fraction",0.02,
    "roll_altitude_quadratic",-0.00000001379891726,"roll_mass_exponent",0.9816286771949775,
    "roll_fit_minimum_altitude_m",72,"roll_fit_maximum_altitude_m",3956,
    "roll_fit_minimum_mass_t",38.21,"roll_fit_maximum_mass_t",72.30,
    "roll_fit_minimum_speed_mps",20,"roll_fit_maximum_speed_mps",110.75,
    "roll_fit_evidence","takeoff_global_20261024",
    // Flight 380 roll fit; checked against 381. Only the tested direction.
    // Correct local performance without treating altitude as its sole cause.
    "v1_roll_runway_factors",lex("Area-15/31",0.8437635112),
    "climb_distance_m",1230,"climb_mass_exponent",2,
    "distance_margin_fraction",0.15,"screen_height_m",35,
    "validated_rotation_speed_mps",110,"rotation_speed_tolerance_mps",0.01,
    "validated_rotation_pitch_deg",20,"rotation_pitch_tolerance_deg",0.01,
    "density_ratio_tolerance",0.001,"thrust_ratio_tolerance",0.001,
    "minimum_altitude_m",70,"maximum_altitude_m",325,
    "stop_reference_slope",0.055,"stop_reference_margin_m",30,
    "minimum_stop_reference_speed_mps",13,"maximum_stop_reference_speed_mps",113.6,
    // Allow the craft origin at the KSC spawn (flight_369: 8.54 m behind start).
    "geometry",lex("start_tolerance_m",15,"cross_track_tolerance_m",20,"facing_tolerance_deg",10),
    "demonstrated_departure",lex(
        "site","Nye-Island","direction","15","minimum_mass_t",68.72565,
        "maximum_mass_t",68.82,"maximum_start_offset_m",5,"minimum_runway_m",1515,
        "evidence","flight_20_22_and_maintainer_confirmation"
    )
)).
// Airless-body departure profile.  The RAPIERs are deliberately only a brief
// liftoff assist: once clear of the rear wheel/tail support, ascent is NERV-only.
Poseidon_SSTO:add("VacuumAscent",lex(
    "default_orbit_altitude",15000,"default_inclination",0,
    "minimum_orbit_altitude",5000,"minimum_nerv_twr",1.05,
    // The RAPIER kick only needs enough vertical thrust to unweight the rear
    // support. Do not wait for a mechanically constrained craft to stand
    // fully upright before permitting that kick.
    "minimum_liftoff_pitch",20,"vertical_timeout",12,
    "nerv_spool_time",1,"rapier_kick_duration",1.5,
    "liftoff_radar_altitude",3,"liftoff_vertical_speed",1,"gear_retract_time",1,
    "pitch_start_clearance",100,"minimum_vertical_speed",5,"vertical_recovery_pitch",65,
    "initial_pitch",75,"terminal_pitch",10,"prograde_blend_speed",450,
    "apoapsis_margin",100,"maximum_ascent_duration",900,
    "node_minimum_lead_time",20,"node_coast_lead_time",45,"node_alignment_timeout",35,
    "node_alignment_error",2,"node_completion_dv",0.25,"node_iterations",48,
    "node_error_gain",1000,"node_max_adjustment",20,"orbit_tolerance",300
)).
Poseidon_SSTO:add("Abort",lex(
    "contingency_rapiers_out",4,
    "RunwayStop",lex(
        "stop_speed",1,"command_pitch",-5,
        "distance_slope",0.54,"distance_margin_m",50,
        "validated_roll_distance_m",1255
    ),
    "RTLS",lex(
        "minimum_turn_speed",200,"turn_bank",55,"target_aoa_min",15,
        "reciprocal_heading_tolerance",5,"handoff_minimum_altitude",1000,
        "turnback_climb_aoa",18,"turnback_max_prograde_pitch",10,"gear_retract_distance",2000,
        "airborne_pitch_margin",1,"low_alt_pitch_margin",5,
        "1RO",lex("use_nervs",false,"fuel_dump",false,"target_mass",70),
        "2RO",lex("use_nervs",true,"fuel_dump",true,"target_mass",60),
        "3RO",lex("use_nervs",true,"fuel_dump",true,"target_mass",50)
    ),
    "RunwaySelection",lex("maximum_distance",400000,"heading_weight",350,"ahead_angle",100,"behind_penalty",50000)
)).
Poseidon_SSTO:add("MaxAeroturnAlt",60000).
Poseidon_SSTO:add("MaxRoll",40).
Poseidon_SSTO:add("MaxPitch",48).
Poseidon_SSTO:add("MinPitch",-30).
Poseidon_SSTO:add("MaxYaw",40).
Poseidon_SSTO:add("Rotation_rate",lex("high",10,"low",18)).
Poseidon_SSTO:add("Pitch_rate",lex("high",4,"low",9)).
// Fifteen-degree outer approach, gradual pull-up from 3.6 km to 1 km,
// then a three-degree reference aimed 100 m past the runway start. The existing
// flare carries touchdown just beyond that point. Choose the
// steep-line intercept so the Hermite join has constant positive curvature:
// height loss = span * mean(endpoint gradients). At 130 m/s this calls for
// about 1.40 m/s^2 upward acceleration over 20 s, before height-based flare.
Poseidon_SSTO:add("Glideslope",lex(
    "angle1",0.268,
    "angle2",0.0524077793,
    "target1",3600-((1000+100)*0.0524077793+2600*(0.268+0.0524077793)/2)/0.268,
    "preflare_start",3600,
    "preflare_end",1000,
    "shallow_aimpoint",100
)).
// Final flare controller.  A more negative touchdown_vertical_speed and a
// lower flare_start_altitude make a firmer, shorter landing; raising either
// makes the touchdown softer at the cost of more runway.
Poseidon_SSTO:add("Landing",lex(
    "flare_start_altitude",35,
    "touchdown_altitude",3,
    "approach_vertical_speed",-7,
    "touchdown_vertical_speed",-0.7,
    "pitch_gain",2.9,
    "minimum_turn_pitch",-2,
    "maximum_turn_pitch",25,
    "rollout_pitch",0,"rollout_pitch_rate",3,
    // Preserve the 125 m/s approach reference through the long preflare.
    "brake_on_speed",135,
    "brake_off_speed",130,
    "speed_gain",0.12,"speed_preview_seconds",3,"maximum_deceleration",5,
    "maximum_throttle",0.70,
    "wheel_brake_altitude",10
)).
Poseidon_SSTO:add("HacDistance",10000).
Poseidon_SSTO:add("HacRadius",1500).
Poseidon_SSTO:add("ERCLSpeed",150).
Poseidon_SSTO:add("Aeroturn_Radius",20000).
Poseidon_SSTO:add("TEAM_v_margin",20).
Poseidon_SSTO:add("TEAMAltitude",25000).
Poseidon_SSTO:add("TEAM_vvdot_t",5).
Poseidon_SSTO:add("Envelope",lex(
    "low_speed",115,
    "minimum_safe_speed",110,
    "low_speed_throttle",0.75,
    "high_speed",800,
    "entry_speed",1350,
    "max_aoa_low_speed",10,
    "max_aoa_normal",30,
    "max_aoa_high_speed",25,
    "max_aoa_entry",20,
    "max_aoa_recovery",8,
    "max_bank_low_speed",25,
    "max_bank_normal",90,
    "max_bank_high_speed",120,
    "max_bank_entry",120,
    "max_bank_recovery",0,
    "rcs_error_aoa",0.75,
    "rcs_error_general",1.5,
    "rcs_pitchdown_confirm_time",0.25,
    "rcs_general_confirm_time",0.5,
    "rcs_release_time",1.0,
    "upset_aoa",35,
    "upset_confirm_time",0.75,
    "recovery_safe_aoa",15,
    "recovery_exit_pitch",30,
    "departure_recovery_max_pitch",35,
    "departure_recovery_max_bank",30,
    "departure_recovery_min_speed",110,
    "departure_recovery_stable_time",2,
    "entry_recovery_max_bank",10,
    "entry_recovery_max_aoa_rate",2,
    "entry_recovery_stable_time",1.0,
    "Terrain",lex(
        "enabled",true,
        "arm_max_radar_altitude",10000,
        "arm_min_groundspeed",60,
        "scan_interval",0.5,
        "lookahead_seconds",list(2,4,7),
        "base_clearance",150,
        "warning_margin",100,
        "response_time",2,
        "release_margin",100,
        "recovery_min_climb_rate",2,
        "recovery_stable_time",1.5,
        // GPWS may stand down only for a captured final.  These are separate
        // from LandingCommit so final guidance can use the full safe descent
        // band without changing the touchdown handoff criteria.
        "final_inhibit_min_vertical_speed",-45,
        "final_inhibit_max_vertical_speed",-5,
        // Permit normal localizer convergence farther out; retain the tight
        // landing-commit corridor from preflare inward.
        "final_inhibit_outer_cross_track",300,"final_inhibit_alignment_distance",6000,
        // Being below glideslope is a terrain hazard; being above it is not.
        // GPWS therefore has only this lower bound, with no upper bound.  The
        // planned preflare intentionally flies below the geometric profile;
        // while that controller is active, use its wider demonstrated corridor
        // without relaxing any of the other final-capture gates.
        "final_inhibit_min_glideslope_error",-25,
        "final_inhibit_preflare_min_glideslope_error",-40,
        "pullup_aoa",20,
        "pullup_min_base_pitch",0,
        // Long-range paths include turn/roll delay and lateral terrain probes.
        // No lift/20-degree-AoA capability is assumed by this predictor.
        "Navigation",lex(
            "minimum_range",15000,"maximum_range",45000,"horizon_seconds",35,
            "sample_spacing",250,"corridor_width",60,"corridor_growth",0.005,
            "stations_per_update",12,"scan_pause",0.2,"maximum_age",4,
            "roll_hold_seconds",1,"rollout_seconds",3,
            "scan_acceleration",10,"response_seconds",7,"prediction_bank",15,
            "climb_credit",10,"turn_sink_reserve",3,"clearance",150,
            "escape_offsets",list(0,-5,5,-15,15,-30,30,-60,60),
            "escape_margin",50,"escape_bank",25,"escape_heading_gain",6,
            "departure_range",18000,"departure_dogleg_distance",6000,
            "departure_heading_gain",2,"departure_response_seconds",3,"departure_speed",300,"departure_gradient",0.20,"reference_mass",69.5,
            // Flight 405: established climb about 28–35% near 69 t.
            // Derate to 20%; retain weak initial climb for the first 1 km,
            // then ramp over 2 km instead of crediting full climb at liftoff.
            "departure_initial_gradient",0.025,"departure_climb_delay",1000,"departure_climb_ramp",2000,
            "departure_initial_clearance",5,"departure_clearance_ramp",10000,
            "liftoff_distance_fraction",0.75,"waypoint_capture",300,
            "departure_min_clearance",15
        )
    )
)).
Poseidon_SSTO:add("TerminalRoute",lex(
    "final_distance",10000,
    "base_offset",300,
    "downwind_extension",8000,
    "hold_radius",2500,
    "target_speed",132,
    "ApproachSpeed",lex(
        "activation_distance",10000,"target_speed",125,
        "brake_on_speed",130,"brake_off_speed",125
    ),
    "BrakeTiming",lex("engage_confirm",0.75,"release_dwell",6,"overspeed_margin",10),
    // Clean loss is energy-height metres lost per horizontal metre flown.
    // Flights 252-254 clean straight segments span roughly 0.20-0.27;
    // bounded online learning adapts this fallback, never from brake drag.
    "EnergyPlan",lex(
        "initial_clean_loss",0.22,"minimum_loss",0.08,"maximum_loss",0.45,
        "loss_uncertainty",0.03,"learning_time",30,"sample_interval",1,
        "clean_settle_time",3,"learning_max_speed",350,
        "planning_bank",35,"circuit_turn_speed",180,"induced_drag_fraction",0.5,
        "turn_reserve_deadband",12,"turn_reserve_max_distance",20000,
        "turn_model_min_bank",30,"turn_radius_safety_fraction",0.6,
        "turn_model_max_arc_distance",100000,"turn_model_max_work",4000,
        "turn_model_refresh_time",2,"turn_model_refresh_altitude",500,
        "turn_model_refresh_speed",50,"turn_model_far_calls_per_update",3,
        "turn_model_config_settle_time",2,
        "brake_lookahead",6,"brake_release_margin",50
    ),
    "minimum_speed",112,
    "low_energy_margin",220,
    "brake_energy",150,
    "hold_exit_energy",250,
    "rehold_energy",99999,
    "phase_change_delay",12,
    "hold_descent_rate",24,
    "downwind_descent_rate",20,
    "final_descent_rate",28,
    "final_profile_correction_time",3,
    "final_profile_min_vertical_speed",-45,
    "final_profile_max_vertical_speed",-4,
    "early_descent_margin",250,
    "hold_aoa_max",22,
    "bank_deadband",1,
    "bank_full_error",30,
    "bank_max",50,
    "intercept_hold_distance",1500,
    "downwind_to_base_distance",6000,
    "base_to_final_distance",6000,
    "final_lead_fraction",0.5,
    "final_lead_min",1500,
    "final_lead_max",8000,
    "pitch_bias_min",-20,
    "pitch_bias_max",20,
    "turn_pitch_bias_limit",5,
    "turn_pitch_bank_threshold",15,
    "fast_turn_min_speed",300,
    "fast_turn_min_bank",40,
    "fast_turn_bank_max",60,
    "fast_turn_target_aoa",20,
    "base_aoa_min",20,
    "base_aoa_max",25,
    "descent_min_aoa",12,
    "descent_aoa_max",17,
    "descent_aoa_gain",0.4,
    "time_to_go_min_speed",80,
    "time_to_go_min",5,
    "final_time_to_go_min",3,
    "hold_descent_time_limit",20,
    "downwind_descent_time_limit",20,
    "final_descent_time_limit",15,
    "final_pitch_trim_aoa",7,
    "final_pitch_vertical_speed_gain",0.8,
    "final_pitch_command_max",25,
    "final_pitch_command_min",-20,
    // Before GPWS becomes necessary, reproduce its 20-degree pull-up pitch.
    // Preview the upcoming profile over the bounded aircraft response delay.
    // Sink-arrest distance is an escape diagnostic, not a flare schedule.
    "final_preflare_pullup_start_error",5,
    "final_preflare_pullup_full_error",15,
    "final_preflare_pullup_pitch",20,
    "PreflarePrediction",lex(
        "response_delay_seconds",2.0,"heavy_mass_delay_seconds",1.0,
        "reference_vertical_deceleration",1.5,
        "minimum_capability_scale",0.60,"maximum_capability_scale",1.20,
        "maximum_preview_seconds",3.0,"above_profile_preview_fade",30,
        "far_sample_aoa",16,"far_refresh_seconds",1,"far_altitude_drift",100,
        "far_speed_drift",5,"far_configuration_settle",2,
        "far_acceleration_safety",0.65,"far_maximum_acceleration",8,
        "minimum_clearance",75
    ),
    "pitch_bias_gain",0.35,
    "nominal_target_aoa",16,
    "max_energy_aoa",20,
    "high_energy_threshold",300,
    "energy_aoa_gain_denominator",120,
    "final_alignment_heading_tolerance",1.5,
    "final_heading_correction",2,
    "final_aoa_offset",6,
    "HighEnergyFinal",lex(
        // Direct finals from the entry interface need a flight-path command,
        // not the low-speed final controller's fixed -45 m/s sink limit.
        "activation_speed",400,
        "activation_energy_margin",1000,
        "aim_distance",1500,
        "minimum_time_to_aim",1,
        "pitch_kp",0.08,
        "pitch_ki",0.002,
        "pitch_kd",0.02,
        "minimum_pitch",-30,
        "maximum_pitch",25,
        "exit_speed",250,
        "exit_desired_vertical_speed",-55,
        "profile_capture_tolerance",500
    ),
    "debug_log_interval",0.5,
    "max_landing_mass", 36,
    // Retain 300 LF for an airbreathing recovery if OX or CC engines are
    // unavailable. The managed abort's computed lf_reserve remains a higher
    // floor whenever needed. Above that, preserve LF for a bounded 300-unit
    // partial CC burn while excess LF drains; the 1.25 pairing plus margin
    // keeps this optional budget separate from the true recovery reserve.
    "RecoveryFuelDump",lex("minimum_lf",300,"minimum_ox",300,
        "stop_margin",25,"minimum_dump_clearance",500,
        "cc_lf_per_ox",1.25,"cc_lf_margin",100,
        "cc_partial_ox_budget",300,"cc_min_lf_burn",250,"cc_min_ox_burn",100,
        "cc_assist_throttle_limit",0.35),
    "Geometry",lex(
        "direct_final_cross_track",3000,"direct_final_heading_error",35,"direct_final_min_along_track",2500,
        "wide_final_distance",14000,"wide_base_offset",350,"wide_downwind_extension",14000,
        "waypoint_capture_distance",2600,"waypoint_overshoot_distance",1200,"overshoot_eligible_distance",6000,
        "final_target_lookahead",500
    ),
    "Propulsion",lex(
        "full_assist_energy_deficit",600,"maximum_throttle",0.70,
        "throttle_speed",120,"speed_assist_gain",0.04
    ),
    "GoAround",lex(
        "enabled",true,"decision_distance",3500,"minimum_altitude",15,
        // A low final with unarrested sink needs power before the landing gate.
        "vertical_decision_distance",10000,"vertical_profile_error",75,
        "vertical_sink_limit",-10,"vertical_tracking_error",8,
        "vertical_recovery_arrest_margin",200,"vertical_critical_arrest_margin",125,
        "vertical_persistence",3,"vertical_critical_persistence",0.25,"recovery_throttle",0.70,
        "minimum_turn_climb_rate",2,
        "maximum_heading_error",22,"maximum_cross_track",900,
        "minimum_reposition_energy",-500,"target_altitude",800,"target_climb_rate",8,"climb_aoa",20,
        "turn_altitude",350,"passed_threshold",0
    ),
    // Commit on the established curved preflare, while there is still height
    // to arrest sink. Waiting for shallow-glide sink before giving the landing
    // controller ownership prevented the actual pull-up in flights 385/409.
    "PreflareCommit",lex(
        "distance",3600,"minimum_height",75,"maximum_height",650,
        "gear_distance",4200,"gear_height",850,
        "maximum_glideslope_error",20,"maximum_cross_track",150,
        "maximum_heading_error",5,"maximum_bank",10,
        "minimum_vertical_speed",-45,"maximum_vertical_speed",-3,
        "stable_time",0.2,"minimum_exit_margin",15,"maximum_far_age",1.5,
        "brake_release_speed_margin",10,
        "escape_profile_error",60,"escape_bank",30,"escape_persistence",0.5
    ),
    "LandingGate",lex(
        "distance",1500,"altitude",120,"heading_error",8,"cross_track",300,
        // The shallow segment is only about 2.8 seconds long at approach
        // speed.  Handoff while the sink rate is still inside LandingCommit,
        // then let the height-based flare finish the pull-up.
        "minimum_speed",105,"maximum_speed",175,"minimum_along_track",-250,"stable_time",0.75,
        "gear_distance",2200,"gear_altitude",180,"airbrake_minimum_altitude",100
    ),
    "LandingCommit",lex(
        "maximum_cross_track",150,"maximum_heading_error",5,"maximum_glideslope_error",60,
        "minimum_vertical_speed",-12,"maximum_vertical_speed",-3,
        "minimum_speed",120,"maximum_speed",165,"maximum_bank",10,"minimum_along_track",0
    ),
    // A runway may be changed only while there is enough room to rebuild the
    // terminal pattern.  The phase lock prevents a reversal after final has
    // begun; the distance and altitude limits also cover unusual routes that
    // have not yet transitioned to final.
    "RunwayChange",lex(
        "lock_distance",6000,
        "lock_altitude",1500
    )
)).
Poseidon_SSTO:add("EG_rev°",5).
Poseidon_SSTO:add("EG_am_range",10).
Poseidon_SSTO:add("EntryHandoff",lex(
    "distance_tolerance",5000,
    "minimum_altitude_offset",-1000,
    "maximum_altitude_offset",1500,
    "maximum_airspeed",1500,
    "maximum_climb_rate",10,
    "stable_time",0.25,
    "passed_distance_growth",1000,
    "passed_maximum_altitude_offset",2500,
    "predictive_minimum_sensitivity",100,
    "transition_aoa_rate",0.75,
    "transition_bank_rate",3,
    "transition_capture_tolerance",0.25
)).
Poseidon_SSTO:add("EGAOA",{
parameter alt_ is ship:altitude.
    if alt_ <= 20000 {
        return 10.
    }

    if alt_ >= 60000 {
        return 20.
    }

    if alt_ < 35000 {
        local x is (alt_ - 30000) / 5000.
    
    return 7.716203
        + 10.098967 * alt_ / 100000
        + 4.1949411
        + 6.63635039 * x
        - 2.33703759 * x * x
        - 6.10762857 * x * x * x
        + 1.61617832 * x * x * x * x
        + 2.77708547 * x * x * x * x * x.
    }   

    return 7.716203
        + 10.098967 * alt_ / 100000
        + 6.632180.
    }).
Poseidon_SSTO:add("simulation",lex("timestep",5,"entry_ref_alt",60000,"max_iterations",10,"dist_tolerance",5000)).
local abort_modes is lex().
//abort_modes:add().


Poseidon_SSTO:add("AbortModes", abort_modes).

global AVES is Poseidon_SSTO.

// Rebuilt once for each launch, before monitoring. Registry identity survives
// missing parts and separates health from intentional recovery isolation.
function recovery_register_engines {
    global recovery_engines is lex().
    global recovery_nominal_cutoff is false.
    global recovery_initial_lf is ship:liquidfuel.
    global recovery_initial_ox is ship:oxidizer.
    for kind in list("rapier","nerv") {
        local pattern is "R.A.P.I.E.R".
        if kind = "nerv" { set pattern to "LV-N". }
        for engine_part in ship:partstitledpattern(pattern) {
            local side is 0.
            local lateral is vdot(engine_part:position-ship:position,ship:facing:starvector).
            if lateral < -0.1 { set side to -1. }
            if lateral > 0.1 { set side to 1. }
            recovery_engines:add("part_"+engine_part:uid,lex(
                "kind",kind,"part",engine_part,"failed",false,"isolated",false,
                "desired",engine_part:ignition,"original_limit",engine_part:thrustlimit,
                "side",side,"commanded_since",time:seconds,"fault_since",-1,"present",true,
                "failure_reason","","limit",engine_part:thrustlimit)).
        }
    }
}

function recovery_set_command {
    parameter engine_part, desired.
    if not(defined recovery_engines) { return. }
    local identity is "part_"+engine_part:uid.
    if not recovery_engines:haskey(identity) { return. }
    local entry is recovery_engines[identity].
    if desired and not entry["desired"] { set entry["commanded_since"] to time:seconds. }
    set entry["desired"] to desired.
    if not desired { set entry["fault_since"] to -1. }
}

function recovery_set_isolated {
    parameter kind, isolated.
    if not(defined recovery_engines){ return. }
    for identity in recovery_engines:keys {
        local entry is recovery_engines[identity].
        if entry["kind"] = kind and not entry["failed"] {
            if entry["isolated"] <> isolated {
                flight_log_event("recovery_engine_isolation","id="+identity+"|kind="+kind+"|isolated="+isolated).
            }
            set entry["isolated"] to isolated.
            if isolated {
                set entry["desired"] to false.
                set entry["fault_since"] to -1.
                if entry["present"] and entry["part"]:ignition { entry["part"]:shutdown. }
            }
        }
    }
}

function recovery_rapier_layout {
    local healthy is 0.
    local left_count is 0.
    local right_count is 0.
    local unknown is false.
    if defined recovery_engines {
        for identity in recovery_engines:keys {
            local entry is recovery_engines[identity].
            if entry["kind"] = "rapier" and not entry["failed"] and entry["present"] {
                set healthy to healthy+1.
                if entry["side"] < 0 { set left_count to left_count+1. }
                if entry["side"] > 0 { set right_count to right_count+1. }
                if entry["side"] = 0 { set unknown to true. }
            }
        }
    }
    return lex("healthy",healthy,"opposite_pair",left_count > 0 and right_count > 0,
        "unknown",unknown,"left",left_count,"right",right_count).
}

function recovery_apply_limits {
    local nerv_failures is 0.
    if defined recovery_engines {
        for identity in recovery_engines:keys {
            local entry is recovery_engines[identity].
            if entry["kind"] = "nerv" and entry["failed"] { set nerv_failures to nerv_failures+1. }
        }
        for identity in recovery_engines:keys {
            local entry is recovery_engines[identity].
            if entry["present"] and defined abort_state and abort_state:haskey("managed") and abort_state["managed"] {
                local reserve_stop is ship:liquidfuel <= abort_state["lf_reserve"].
                if entry["kind"] = "rapier" and entry["part"]:mode = "ClosedCycle" and
                   ship:oxidizer <= abort_state["ox_reserve"] { set reserve_stop to true. }
                if reserve_stop {
                    if (entry["desired"] or entry["part"]:ignition) {
                        flight_log_event("recovery_engine_reserve_stop","id="+identity+"|kind="+entry["kind"]+
                            "|lf="+ship:liquidfuel+"|ox="+ship:oxidizer).
                    }
                    set entry["desired"] to false.
                    set entry["fault_since"] to -1.
                    if entry["part"]:ignition { entry["part"]:shutdown. }
                }
            }
            if entry["kind"] = "nerv" and entry["present"] {
                local limit_pct is min(entry["original_limit"],entry["part"]:thrustlimit).
                if nerv_failures > 0 { set limit_pct to min(limit_pct,20). }
                if nerv_failures >= 2 or entry["failed"] { set limit_pct to 0. }
                if limit_pct <> entry["limit"] {
                    flight_log_event("recovery_engine_limit","id="+identity+"|kind=nerv|limit="+limit_pct+"|nervs_out="+nerv_failures).
                }
                set entry["part"]:thrustlimit to limit_pct.
                set entry["limit"] to limit_pct.
                if limit_pct = 0 {
                    set entry["desired"] to false.
                    if entry["part"]:ignition { entry["part"]:shutdown. }
                }
            }
        }
    } else if defined abort_state and abort_state:haskey("scenario") {
        // Older recovery entry points still preserve the lone-NERV restriction.
        set nerv_failures to abort_state["scenario"]["nervs_out"].
        if nerv_failures > 0 {
            for engine_part in ship:partstitledpattern("LV-N") {
                set engine_part:thrustlimit to min(engine_part:thrustlimit,20).
                if nerv_failures >= 2 { engine_part:shutdown. }
            }
        }
    }
}

function recovery_power {
    parameter state, use_rapiers, use_nervs.
    recovery_apply_limits().
    local force_kn is 0.
    local vacuum_force is 0.
    local mass_rate is 0.
    local vacuum_rate is 0.
    local lf_rate is 0.
    local ox_rate is 0.
    local healthy_rapiers is 0.
    local healthy_nervs is 0.
    local usable_lf is max(0,ship:liquidfuel-state["lf_reserve"]).
    local usable_ox is max(0,ship:oxidizer-state["ox_reserve"]).
    for kind in list("rapier","nerv") {
        local pattern is "R.A.P.I.E.R".
        if kind = "nerv" { set pattern to "LV-N". }
        if (kind = "rapier" and use_rapiers) or (kind = "nerv" and use_nervs) {
            for engine_part in ship:partstitledpattern(pattern) {
                if not engine_blocked_by_abort(kind,engine_part) and not engine_part:flameout {
                    // POSSIBLETHRUST includes the limiter and works before ignition.
                    local engine_force is engine_part:possiblethrust.
                    local engine_vacuum_force is engine_part:possiblethrustat(0).
                    local engine_rate is engine_force/(max(1,engine_part:isp)*constant:g0).
                    local lf_ratio is 0.
                    local ox_ratio is 0.
                    local lf_density is 0.005.
                    local ox_density is 0.005.
                    local resources_used is engine_part:consumedresources.
                    for resource_name in resources_used:keys {
                        local consumed is resources_used[resource_name].
                        if consumed:name = "LiquidFuel" {
                            set lf_ratio to consumed:ratio.
                            set lf_density to consumed:density.
                            if engine_part:ignition {
                                set usable_lf to min(usable_lf,max(0,consumed:amount-state["lf_reserve"])).
                            }
                        }
                        if consumed:name = "Oxidizer" {
                            set ox_ratio to consumed:ratio.
                            set ox_density to consumed:density.
                            if engine_part:ignition {
                                set usable_ox to min(usable_ox,max(0,consumed:amount-state["ox_reserve"])).
                            }
                        }
                    }
                    local mixture_mass is lf_ratio*lf_density+ox_ratio*ox_density.
                    if mixture_mass > 0 and engine_force > 0 and engine_part:isp > 0 and usable_lf > 0 and
                       (ox_ratio = 0 or usable_ox > 0) {
                        set force_kn to force_kn+engine_force.
                        set mass_rate to mass_rate+engine_rate.
                        set vacuum_force to vacuum_force+engine_vacuum_force.
                        set vacuum_rate to vacuum_rate+engine_vacuum_force/(max(1,engine_part:vacuumisp)*constant:g0).
                        set lf_rate to lf_rate+engine_rate*lf_ratio/mixture_mass.
                        set ox_rate to ox_rate+engine_rate*ox_ratio/mixture_mass.
                        if kind = "rapier" { set healthy_rapiers to healthy_rapiers+1. }
                        if kind = "nerv" { set healthy_nervs to healthy_nervs+1. }
                    }
                }
            }
        }
    }
    // One coupled burn duration spends the shared LF supply once, even when
    // RAPIERs and NERVs are simultaneously credited. Ox can be limiting first.
    local burn_time is 0.
    if lf_rate > 0 { set burn_time to usable_lf/lf_rate. }
    if ox_rate > 0 { set burn_time to min(burn_time,usable_ox/ox_rate). }
    local fuel_t is min(ship:mass*0.9,burn_time*mass_rate).
    local isp_s is 0.
    local vacuum_isp_s is 0.
    local dv is 0.
    local vacuum_dv is 0.
    if mass_rate > 0 {
        set isp_s to force_kn/(mass_rate*constant:g0).
        set dv to isp_s*constant:g0*ln(ship:mass/(ship:mass-fuel_t)).
    }
    if vacuum_rate > 0 {
        set vacuum_isp_s to vacuum_force/(vacuum_rate*constant:g0).
        set vacuum_dv to vacuum_isp_s*constant:g0*ln(ship:mass/(ship:mass-fuel_t)).
    }
    return lex("thrust",force_kn,"thrust_kn",force_kn,"acceleration",force_kn/max(0.001,ship:mass),
        "dv",dv,"vacuum_dv",vacuum_dv,"vacuum_thrust",vacuum_force,"isp",isp_s,"vacuum_isp",vacuum_isp_s,
        "mass_flow",mass_rate,"lf_flow",lf_rate,"ox_flow",ox_rate,"fuel_t",fuel_t,"burn_time",burn_time,
        "healthy_rapiers",healthy_rapiers,"healthy_nervs",healthy_nervs,"usable",force_kn > 0 and burn_time > 0).
}

function recovery_throttle {
    parameter requested, floor_ is 0.
    local command is max(requested,floor_).
    if defined abort_state and abort_state:haskey("managed") and abort_state["managed"] {
        // Preserve deliberate coast/alignment burn timing, but give terminal
        // flight and an active terrain escape their protective throttle floor.
        local terminal_flight is defined step and (step = "TEAM" or step = "landing").
        local terrain_escape is defined dap and dap:haskey("envelope") and
            dap["envelope"]:haskey("terrain_state") and dap["envelope"]["terrain_state"] = "pullup".
        if not(terminal_flight or terrain_escape) { set command to requested. }
        if ship:liquidfuel <= abort_state["lf_reserve"] { return 0. }
    }
    return max(0,min(1,command)).
}

function recovery_select_mode {
    parameter state, current_phase.
    if state["nominal_cutoff"] and state["scenario"]["nervs_out"] > 0 { return "edr". }
    // Return commitment is permanent: a changed failure count reconfigures
    // propulsion but cannot reopen the abandoned ascent/orbit attempt.
    if state["mode"] = "edr" { return "edr". }
    if state["mode"] = "aed" and state["scenario"]["rapiers_out"] >= 4 { return "edr". }
    local selected is ask_abort_modes(state["scenario"],current_phase).
    if selected = "ato" and (state["orbit_abandoned"] or
       (state:haskey("suppress_orbit") and state["suppress_orbit"])) {
        if state["mode"] = "aed" or state["mode"] = "contingency_abort" { return state["mode"]. }
        if state["scenario"]["rapiers_out"] < 4 { return "aed". }
        return "edr".
    }
    return selected.
}

// Shared ascent recovery lifecycle; guidance executes in Orbit Main steps.
function recovery_phase {
    parameter state, next_phase.
    if state["phase"] <> next_phase {
        flight_log_event("recovery_phase","mode="+state["mode"]+"|from="+state["phase"]+
            "|to="+next_phase+"|source="+state["source_step"]).
        set state["phase"] to next_phase.
        set state["phase_entered"] to time:seconds.
    }
}

function recovery_transition {
    parameter state, next_mode, reason.
    if state["mode"] = next_mode { return. }
    flight_log_event("recovery_mode","from="+state["mode"]+"|to="+next_mode+"|reason="+reason+
        "|source="+state["source_step"]+"|rapiers_out="+state["scenario"]["rapiers_out"]+
        "|nervs_out="+state["scenario"]["nervs_out"]).
    set state["display_from_mode"] to state["mode"].
    set state["display_mode_reason"] to reason.
    set state["mode"] to next_mode.
    set state["phase"] to "initialize".
    set state["phase_entered"] to time:seconds.
    set state["handoff_ready"] to false.
    set state["handoff"]["started"] to false.
    if next_mode <> "ato" {
        set state["orbit_abandoned"] to true.
        set state["suppress_orbit"] to true.
    }
    if next_mode = "contingency_abort" {
        recovery_set_isolated("nerv",false).
        // Allow the fallback to initialize its caches, but carry the original
        // reserves and the rejected-attempt history into that initialization.
        if state:haskey("orbit_eligible") { state:remove("orbit_eligible"). }
        set state["target"]["selected"] to false.
    }
    set step to next_mode.
}

function recovery_finish {
    parameter state, reason, success is false, pilot is true.
    abort_set_fuel_dump(false).
    set dapthrottle to 0.
    set dap["envelope"]["min_throttle"] to 0.
    set state["result"] to lex("success",success,"reason",reason,"pilot_control",pilot).
    set state["active"] to false.
    set state["controls_released"] to true.
    recovery_phase(state,"complete").
    flight_log_event("recovery_outcome","mode="+state["mode"]+"|reason="+reason+
        "|success="+success+"|pilot_control="+pilot+"|apoapsis="+ship:apoapsis+
        "|periapsis="+ship:periapsis+"|lf="+ship:liquidfuel+"|ox="+ship:oxidizer).
    recovery_apply_limits().
    set ship:control:pilotmainthrottle to 0.
    dap:set_off().
    unlock throttle.
    set ship:control:neutralize to true.
    if pilot { print "RECOVERY: PILOT CONTROL - "+reason. }
    set step to "end".
}
