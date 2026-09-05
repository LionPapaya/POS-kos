function reset_sys{
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

function goto_target{
    if not(defined reentry_target){
            set ecrl_2hac to get_geoposition_along_heading(runway_start,runway_heading+180,Aves["HacDistance"]*2).
            if calcdistance(ship:geoposition,runway_start) > calcdistance(ship:geoposition,ecrl_2hac){
                set reentry_target to runway_start.
            }else{set reentry_target to ecrl_2hac.}

        }
    local sim is current_simstate().
    
    set dap["aoa"]["target_aoa"] to AVES["EGAOA"](ship:altitude).
    local y is sim_with_bank(sim,0,0,reentry_target).
    local x is y["final_state"]["latlong"].

    set distance_between_runway_start_IMPACTPOS to calcdistance(ship:geoposition,reentry_target) - calcdistance(ship:geoposition,x).



        // Calculate the total runway distance dynamically

        // Calculate the percentage difference
        set percentage_diff to calc_percentage(distance_between_runway_start_IMPACTPOS, calcdistance(ship:geoposition,reentry_target)).

        // Calculate dynamic pitch
        // Map the percentage difference (-7% to -2%) to a pitch range (e.g., 90 to 17 degrees)
        if percentage_diff >= -7 and percentage_diff <= -2 {
            set t_bank to 70 - ((70 - 0) * abs(percentage_diff) / 7). // Linearly interpolate
        } else if percentage_diff > -2 {
            set t_bank to 0. // Default to minimal pitch above -2%
        } else {
            set t_bank to 70. // Default to max pitch below -7%
        }

        // Calculate brake state based on percentage difference
        if percentage_diff <= -10 {
            brakes on.
        } else {
            brakes off.
        }    
        local heading_error is heading_to_target(reentry_target) - compass_for_prograde().

            // Normalisiere den Fehler
        if abs(heading_error) <= 180{
            if heading_error > 180 {
                set heading_error to heading_error - 360.
            } 
            if heading_error < -180 {
                set heading_error to heading_error + 360.
            }
        }
        if not (defined entry_turnside){
            if heading_error > 0{
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
    if not rapiers {
        set engines["rapier"]["failed"] to 0.
        set engines["rapier"]["failed_ids"] to lex().
    }
    if not nervs {
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

function ask_abort_modes{
    parameter scenarios, phase.
    
    if scenarios["rapiers_out"] >= AVES["Abort"]["contingency_rapiers_out"] {
        return "contingency_abort".
    }else if phase ="launch"{
        return "runway_abort".
    }else if phase = "rotate"{
        return "rtls".
    }else if phase ="speed_build" or phase ="high_altitude_climb"{
        return "atr".
    }else{
        return "ati".
    }
}

function create_abort_state {
    parameter abort_info, origin_step, departure_runway.
    return lex(
        "active",abort_info["abort"],"mode",abort_info["mode"],
        "submode",abort_info["scenario"]["rapiers_out"] + "RO",
        "phase","initialize","phase_entered",time:seconds,"source_step",origin_step,
        "scenario",abort_info["scenario"],"engines",abort_info["engines"],
        "departure_runway",departure_runway,
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
    // Failure counts are sticky and may only increase during an abort.
    if rapiers {
        for engine_id in snapshot["rapier"]["failed_ids"]:keys {
            if not state["engines"]["rapier"]["failed_ids"]:haskey(engine_id) {
                state["engines"]["rapier"]["failed_ids"]:add(engine_id,true).
            }
        }
        set state["engines"]["rapier"]["failed"] to state["engines"]["rapier"]["failed_ids"]:keys:length.
        set state["engines"]["rapier"]["working"] to state["engines"]["rapier"]["installed"] - state["engines"]["rapier"]["failed"].
    }
    if nervs {
        for engine_id in snapshot["nerv"]["failed_ids"]:keys {
            if not state["engines"]["nerv"]["failed_ids"]:haskey(engine_id) {
                state["engines"]["nerv"]["failed_ids"]:add(engine_id,true).
            }
        }
        set state["engines"]["nerv"]["failed"] to state["engines"]["nerv"]["failed_ids"]:keys:length.
        set state["engines"]["nerv"]["working"] to state["engines"]["nerv"]["installed"] - state["engines"]["nerv"]["failed"].
    }
    set state["scenario"]["rapiers_out"] to state["engines"]["rapier"]["failed"].
    set state["scenario"]["nervs_out"] to state["engines"]["nerv"]["failed"].
    set state["submode"] to state["scenario"]["rapiers_out"] + "RO".
    set state["last_failure_refresh"] to time:seconds.
    if state["scenario"]["rapiers_out"] >= AVES["Abort"]["contingency_rapiers_out"] {
        set state["mode"] to "contingency_abort".
        set state["phase"] to "unimplemented".
        set state["phase_entered"] to time:seconds.
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
                if distance_ <= config_select["maximum_distance"] {
                    local bearing_error is abs(normalized_heading_error(heading_to_target(runway_start_),compass_for_prograde())).
                    local score_ is distance_ + bearing_error * config_select["heading_weight"].
                    if bearing_error > config_select["ahead_angle"] { set score_ to score_ + config_select["behind_penalty"]. }
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
    return best.
}
function setup_landing_script{
    
    steeringManager:resetpids().
    set step to "Deorbit".
    set substep to "findStep".
    set running to true.
    clearScreen.  
    if maxThrust = 120{
        set nervs to true.
    } 
    else{
        set nervs to false.
    }

    set rapier_mode to "air".
    set rapiers to false.
    set Lastest_status to "Inizializing Script".
    set deorbit_start to false.
    set deorbit_calc to false.
    dap:setup().
    reset_sys().                                                                             
   
}

local Poseidon_SSTO is lex().
Poseidon_SSTO:add("Speed",Lexicon("MaxSpeed",2400,"MinSpeed",100,"Rotate",110)).
// Aircraft-style ascent profile.  Keep all Poseidon-specific ascent tuning here
// so the flight logic remains readable and can be adjusted without hunting for
// thresholds in the state machine.
Poseidon_SSTO:add("Ascent",lex(
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
    "inclination_heading_fallback",90
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
Poseidon_SSTO:add("Glideslope",lex("angle1",0.268,"angle2",0.0875,"target1",450,"switch12",700)).
// Final flare controller.  A more negative touchdown_vertical_speed and a
// lower flare_start_altitude make a firmer, shorter landing; raising either
// makes the touchdown softer at the cost of more runway.
Poseidon_SSTO:add("Landing",lex(
    "flare_start_altitude",35,
    "touchdown_altitude",3,
    "approach_vertical_speed",-8.5,
    "touchdown_vertical_speed",-0.7,
    "pitch_gain",2.9,
    "minimum_turn_pitch",-2,
    "maximum_turn_pitch",25,
    "target_touchdown_speed",120,
    "wheel_brake_altitude",10
)).
Poseidon_SSTO:add("StationaryThrottle",300).
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
    "recovery_exit_pitch",30
)).
Poseidon_SSTO:add("TerminalRoute",lex(
    "final_distance",10000,
    "base_offset",300,
    "downwind_extension",8000,
    "hold_radius",2500,
    "target_speed",132,
    "minimum_speed",112,
    "low_energy_margin",220,
    "brake_energy",150,
    "hold_exit_energy",250,
    "rehold_energy",99999,
    "phase_change_delay",12,
    "hold_descent_rate",24,
    "downwind_descent_rate",20,
    "final_descent_rate",28,
    "final_vs_distance_factor",0.7,
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
    "final_pitch_pid_p",0.5,
    "final_pitch_pid_i",0.2,
    "final_pitch_pid_d",0.4,
    "final_pitch_pid_max",15,
    "final_pitch_pid_min",-35,
    "pitch_bias_gain",0.35,
    "nominal_target_aoa",16,
    "max_energy_aoa",20,
    "high_energy_threshold",300,
    "energy_aoa_gain_denominator",120,
    "final_alignment_heading_tolerance",1.5,
    "final_heading_correction",2,
    "final_aoa_offset",6,
    "debug_log_interval",0.5,
    "max_landing_mass", 36,
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
        "enabled",true,"decision_distance",3500,"minimum_altitude",80,
        "maximum_heading_error",22,"maximum_cross_track",900,
        "minimum_reposition_energy",-500,"target_altitude",800,"target_climb_rate",8,"climb_aoa",20,
        "turn_altitude",350,"passed_threshold",0
    ),
    "LandingGate",lex(
        "distance",1500,"altitude",120,"heading_error",8,"cross_track",300,
        "minimum_speed",105,"maximum_speed",175,"minimum_along_track",-250,"stable_time",2,
        "gear_distance",2200,"gear_altitude",180,"airbrake_minimum_altitude",100
    ),
    "LandingCommit",lex(
        "maximum_cross_track",150,"maximum_heading_error",5,"maximum_glideslope_error",60,
        "minimum_vertical_speed",-45,"maximum_vertical_speed",-15,
        "minimum_speed",110,"maximum_speed",165,"maximum_bank",10,"minimum_along_track",0
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
Poseidon_SSTO:add("EG_am_range",20).
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
