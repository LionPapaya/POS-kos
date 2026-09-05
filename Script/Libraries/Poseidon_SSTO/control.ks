

// Libraries/Poseidon_SSTO/control.ks
// Purpose: Poseidon autopilot and control helpers (the `dap` control lexicon).
// - Initializes `dap` with `dap:setup()` and updates via `dap:update()`.
// - Implements autopilot modes (auto/aoa/aerostr/vector/css/off), engine helpers and utility actions (execute_node, reset_sys).
// Notes: only comments inserted; no logic or code changed.
global dap is lex().
if not (dap:haskey("setup_done")) {
    dap:add("setup_done", false).
}
if not (dap:haskey("setup")) {
    dap:add("setup", {
    // Add variables to the lexicon
    if not (dap:haskey("aerostr")) {
        local aero_str is lexicon().
        aero_str:add("targetPitch", 0).
        aero_str:add("targetRoll", 0).
        aero_str:add("targetDirection", 90).
        aero_str:add("turn_pitch", 0).
        aero_str:add("turn_heading", 90).
        aero_str:add("turn_roll", 0).
        aero_str:add("distance_pitch", 0).
        aero_str:add("aerostr_pitch", 0).
        aero_str:add("aerostr_roll", 0).
        aero_str:add("aerostr_heading", 90).
        dap:add("aerostr", aero_str).
    }

    if not (dap:haskey("aoa")) {
        local aoa_str is lexicon().
        aoa_str:add("aoa_pitch", 0).
        aoa_str:add("aoa_yaw", 90).
        aoa_str:add("aoa_roll", 0).
        aoa_str:add("target_aoa", 0).
        aoa_str:add("target_bank", 0).
        aoa_str:add("smooth_target_aoa", 0).
        aoa_str:add("smooth_target_bank", 0).
        aoa_str:add("base_pitch", 0).
        dap:add("aoa", aoa_str).
    }

    if not (dap:haskey("vector")) {
        local vector_str is lexicon().
        vector_str:add("targetVector", ship:facing:vector).
        dap:add("vector", vector_str).
    }

    if not (dap:haskey("css")) {
        local css is lexicon().
        css:add("pitch_out", 0).
        css:add("yaw_out", 90).
        css:add("roll_out", 0).
        css:add("pitch_aoa_spd", 0.5).
        css:add("roll_aoa_spd", 1).
        css:add("pitch_aerostr_spd", 1).
        css:add("yaw_aerostr_spd", 0.8).
        css:add("roll_aerostr_spd", 0.7).
        css:add("last_roll",0).
        css:add("last_aoa",0).
        dap:add("css", css).

    }

    if not (dap:haskey("envelope")) {
        local envelope is lexicon().
        envelope:add("state", "normal").
        envelope:add("regime", "normal").
        envelope:add("max_aoa", 30).
        envelope:add("max_bank", 90).
        envelope:add("min_throttle", 0).
        envelope:add("last_aoa", calc_aoa()).
        envelope:add("last_speed", ship:airspeed).
        envelope:add("last_pitch_error", 0).
        envelope:add("pitchdown_timer", 0).
        envelope:add("authority_timer", 0).
        envelope:add("upset_timer", 0).
        envelope:add("stable_timer", 0).
        envelope:add("rcs_assist", false).
        envelope:add("restore_steering", false).
        envelope:add("last_control_log", -999999).
        envelope:add("control_log_header", false).
        // Terrain-protection state.  The Bounds object is intentionally
        // captured once: kOS keeps it live while avoiding the cost and noise
        // of constructing a new bounds structure each control tick.
        envelope:add("terrain_bounds", ship:bounds).
        envelope:add("terrain_state", "inhibited").
        envelope:add("terrain_next_scan", -999999).
        envelope:add("terrain_worst_clearance", 999999).
        envelope:add("terrain_required_clearance", 0).
        envelope:add("terrain_clear_timer", 0).
        dap:add("envelope", envelope).
    }

    if not (dap:haskey("dap_mode")) {
        dap:add("dap_mode", "auto").
    }

    if not (dap:haskey("str_mode")) {
        dap:add("str_mode", "aerostr").
    }

    if not (dap:haskey("dap_mode_set")) {
        dap:add("dap_mode_set", lex("str_mode", "aerostr", "dapmode", "auto")).
    }

    if not (dap:haskey("l_t")) {
        dap:add("l_t",time:seconds).
    }
        if not (dap:haskey("dt")) {
        dap:add("dt",0.1).
    }
    set steeringmanager:pitchtorquefactor to 1.
    set steeringmanager:yawtorquefactor to 1.
    set steeringmanager:rollcontrolanglerange to 100.
    steeringManager:resetpids().
    
    lock dap_steering to heading(dap["aerostr"]["targetDirection"], dap["aerostr"]["targetPitch"], dap["aerostr"]["targetRoll"]).
    lock steering to dap_steering.
    if not(defined(dapthrottle)){
        global dapthrottle is 0.
    }
    lock throttle to max(dapthrottle,dap["envelope"]["min_throttle"]).

    set dap["setup_done"] to true.
}).
}

function envelope_clamp {
    parameter value, lower, upper.
    return max(lower,min(value,upper)).
}

// Return the predicted clearance between the terrain and the vessel's lowest
// bounds corner after seconds_ahead.  The ground track is deliberately the
// horizontal component of surface velocity, rather than the craft's facing
// vector: a steep pitch attitude must not make the terrain probe look up into
// the sky or down into the ground.
function envelope_terrain_projected_clearance {
    parameter seconds_ahead, bounds_box.
    local surface_velocity is ship:velocity:surface.
    local up_vector is ship:up:vector.
    local ground_track is surface_velocity - up_vector * vdot(surface_velocity,up_vector).

    if ground_track:mag < 1 {
        return 999999.
    }

    local future_position is ship:position + ground_track:normalized * (ground_track:mag * seconds_ahead).
    local future_geoposition is ship:body:geopositionof(future_position).
    local bottom_offset is max(0,ship:altitude - bounds_box:bottomalt).
    local future_bottom_altitude is ship:altitude - bottom_offset + min(ship:verticalspeed,0) * seconds_ahead.
    return future_bottom_altitude - future_geoposition:terrainheight.
}

function envelope_terrain_reset {
    parameter envelope, terrain_state is "inhibited".
    set envelope["terrain_state"] to terrain_state.
    set envelope["terrain_next_scan"] to -999999.
    set envelope["terrain_worst_clearance"] to 999999.
    set envelope["terrain_required_clearance"] to 0.
    set envelope["terrain_clear_timer"] to 0.
}

// A normal, committed runway landing owns its last low-altitude segment.  Do
// not allow a seven-second terrain prediction to mistake the planned flare for
// an obstacle.  This inhibit is intentionally much narrower than "all final
// approaches": terrain protection remains active until the aircraft is below
// the LandingGate altitude, aligned, and inside the final corridor.
function envelope_terrain_landing_inhibit {
    if defined step and step = "landing" {
        return true.
    }
    if defined terminal_route and terminal_route:haskey("phase") and terminal_route:haskey("geometry") and terminal_route["phase"] = "final" {
        local landing_gate is AVES["TerminalRoute"]["LandingGate"].
        local geometry is terminal_route["geometry"].
        if geometry["altitude"] < landing_gate["altitude"] and
           abs(geometry["cross_track"]) < landing_gate["cross_track"] and
           abs(geometry["heading_error"]) < landing_gate["heading_error"] {
            return true.
        }
    }
    return false.
}

function envelope_terrain_inhibited {
    parameter terrain_config.
    if not terrain_config["enabled"] or ship:status <> "FLYING" {
        return true.
    }
    if defined step and (step = "launch" or step = "rotate") {
        return true.
    }
    if envelope_terrain_landing_inhibit() {
        return true.
    }

    local surface_velocity is ship:velocity:surface.
    local ground_track is surface_velocity - ship:up:vector * vdot(surface_velocity,ship:up:vector).
    if ground_track:mag < terrain_config["arm_min_groundspeed"] {
        return true.
    }
    return alt:radar > terrain_config["arm_max_radar_altitude"].
}

// Scan only at a fixed low rate and retain the result between scans.  The
// predicted clearance includes descent during the look-ahead interval and a
// response margin for the scan period plus the aircraft's pull-up delay.
function envelope_terrain_refresh {
    parameter envelope, terrain_config, dt.

    if envelope_terrain_inhibited(terrain_config) {
        envelope_terrain_reset(envelope,"inhibited").
        if envelope["state"] = "terrain_pullup" {
            set envelope["state"] to "normal".
            set envelope["restore_steering"] to true.
        }
        return.
    }

    if time:seconds >= envelope["terrain_next_scan"] {
        local worst_clearance is 999999.
        for seconds_ahead in terrain_config["lookahead_seconds"] {
            set worst_clearance to min(worst_clearance,envelope_terrain_projected_clearance(seconds_ahead,envelope["terrain_bounds"])).
        }
        set envelope["terrain_worst_clearance"] to worst_clearance.
        set envelope["terrain_next_scan"] to time:seconds + terrain_config["scan_interval"].
    }

    local vertical_closure_rate is max(-ship:verticalspeed,0).
    local required_clearance is terrain_config["base_clearance"] +
        vertical_closure_rate * (terrain_config["scan_interval"] + terrain_config["response_time"]).
    set envelope["terrain_required_clearance"] to required_clearance.

    if envelope["state"] = "terrain_pullup" {
        if envelope["terrain_worst_clearance"] >= required_clearance + terrain_config["release_margin"] and
           ship:verticalspeed >= terrain_config["recovery_min_climb_rate"] {
            set envelope["terrain_clear_timer"] to envelope["terrain_clear_timer"] + dt.
            if envelope["terrain_clear_timer"] >= terrain_config["recovery_stable_time"] {
                set envelope["state"] to "normal".
                set envelope["terrain_state"] to "normal".
                set envelope["terrain_clear_timer"] to 0.
                set envelope["restore_steering"] to true.
            }
        } else {
            set envelope["terrain_clear_timer"] to 0.
        }
        return.
    }

    if envelope["terrain_worst_clearance"] < required_clearance {
        set envelope["state"] to "terrain_pullup".
        set envelope["terrain_state"] to "pullup".
        set envelope["terrain_clear_timer"] to 0.
    } else if envelope["terrain_worst_clearance"] < required_clearance + terrain_config["warning_margin"] {
        set envelope["terrain_state"] to "caution".
    } else {
        set envelope["terrain_state"] to "normal".
    }
}

function envelope_refresh {
    local envelope is dap["envelope"].
    local config_envelope is AVES["Envelope"].
    local dt is max(dap["dt"],0.01).
    local actual_aoa is calc_aoa().
    local aoa_rate is (actual_aoa - envelope["last_aoa"]) / dt.
    local speed_deceleration is max((envelope["last_speed"] - ship:airspeed) / dt,0).
    local requested_aoa is dap["aoa"]["target_aoa"].
    local requested_pitch is dap["aerostr"]["targetPitch"].

    // During launch or rotate phases, disable envelope upset interventions
    // to avoid interfering with ascent/initial rotation maneuvers.
    if defined step and (step = "launch" or step = "rotate") {
        envelope_terrain_reset(envelope).
        set envelope["rcs_assist"] to false.
        set envelope["pitchdown_timer"] to 0.
        set envelope["authority_timer"] to 0.
        set envelope["upset_timer"] to 0.
        set envelope["stable_timer"] to 0.
        set envelope["state"] to "normal".
        rcs off.
        return.
    }

    if dap["dap_mode"] = "css" and dap["str_mode"] = "aoa" {
        set requested_aoa to dap["css"]["last_aoa"].
    }
    if dap["dap_mode"] = "css" and dap["str_mode"] = "aerostr" {
        set requested_pitch to dap["css"]["pitch_out"].
    }

    if ship:altitude > 70000 {
        envelope_terrain_reset(envelope).
        set envelope["max_aoa"] to config_envelope["max_aoa_normal"].
        set envelope["max_bank"] to config_envelope["max_bank_normal"].
        set envelope["regime"] to "normal".
        set envelope["min_throttle"] to 0.
        set envelope["state"] to "normal".
        set envelope["rcs_assist"] to false.
        set envelope["pitchdown_timer"] to 0.
        set envelope["authority_timer"] to 0.
        set envelope["upset_timer"] to 0.
        set envelope["stable_timer"] to 0.
        set envelope["last_aoa"] to actual_aoa.
        set envelope["last_speed"] to ship:airspeed.
        set envelope["last_pitch_error"] to (requested_pitch - pitch_for()).
        return.
    }

    set envelope["max_aoa"] to config_envelope["max_aoa_normal"].
    set envelope["max_bank"] to config_envelope["max_bank_normal"].
    set envelope["regime"] to "normal".
    if ship:airspeed < config_envelope["entry_speed"] {
        if ship:airspeed >= config_envelope["high_speed"] {
            set envelope["max_aoa"] to config_envelope["max_aoa_high_speed"].
            set envelope["max_bank"] to config_envelope["max_bank_high_speed"].
            set envelope["regime"] to "high_speed".
        }
    } else {
        set envelope["max_aoa"] to config_envelope["max_aoa_entry"].
        set envelope["max_bank"] to config_envelope["max_bank_entry"].
        set envelope["regime"] to "entry".
    }
    if ship:airspeed < config_envelope["low_speed"] {
        set envelope["max_aoa"] to config_envelope["max_aoa_low_speed"].
        set envelope["max_bank"] to config_envelope["max_bank_low_speed"].
        set envelope["regime"] to "low_speed".
    }

    set envelope["min_throttle"] to 0.
    if ship:status = "FLYING" and ship:airspeed < config_envelope["low_speed"] {
        local speed_deficit is envelope_clamp((config_envelope["low_speed"] - ship:airspeed) / max(config_envelope["low_speed"] - config_envelope["minimum_safe_speed"],1),0,1).
        local deceleration_demand is envelope_clamp(speed_deceleration / 10,0,1).
        set envelope["min_throttle"] to min(1,config_envelope["low_speed_throttle"] + speed_deficit * 0.25 + deceleration_demand * 0.10).
    }

    envelope_terrain_refresh(envelope,config_envelope["Terrain"],dt).

    // RCS is reserved for the thin-atmosphere portion of flight.  The
    // pitch-down detector is deliberately very sensitive: a rising AoA while
    // the controller is commanding down can become unrecoverable quickly.
    local rcs_available is ship:body:atm:exists and ship:altitude >= AVES["TEAMAltitude"].
    if envelope["state"] = "terrain_pullup" {
        // GPWS is deliberately not routed through the upset recovery's
        // zero-AoA phase.  Terrain escape needs an immediate controlled pull-up.
        set envelope["max_aoa"] to config_envelope["max_aoa_recovery"].
        set envelope["max_bank"] to config_envelope["max_bank_recovery"].
        set envelope["min_throttle"] to 1.
        set envelope["rcs_assist"] to rcs_available.
        if envelope["rcs_assist"] {
            rcs on.
        } else {
            rcs off.
        }
        set envelope["last_aoa"] to actual_aoa.
        set envelope["last_speed"] to ship:airspeed.
        set envelope["last_pitch_error"] to (requested_pitch - pitch_for()).
        return.
    }

    local aoa_error is actual_aoa - requested_aoa.
    local pitch_error is requested_pitch - pitch_for().
    local pitchdown_failure is rcs_available and requested_aoa < actual_aoa and aoa_error > config_envelope["rcs_error_aoa"] and aoa_rate > 0.
    if pitchdown_failure {
        set envelope["pitchdown_timer"] to envelope["pitchdown_timer"] + dt.
    } else {
        set envelope["pitchdown_timer"] to 0.
    }

    local general_failure is rcs_available and dap["str_mode"] = "aerostr" and abs(pitch_error) > config_envelope["rcs_error_general"] and abs(pitch_error) >= abs(envelope["last_pitch_error"]).
    if general_failure {
        set envelope["authority_timer"] to envelope["authority_timer"] + dt.
    } else {
        set envelope["authority_timer"] to 0.
    }

    local upset_candidate is actual_aoa > config_envelope["upset_aoa"] and requested_aoa < actual_aoa - config_envelope["rcs_error_aoa"].
    if upset_candidate or (abs(roll_for()) > 135 and envelope["max_bank"] < 135) {
        set envelope["upset_timer"] to envelope["upset_timer"] + dt.
    } else if envelope["state"] = "normal" or envelope["state"] = "authority_assist" {
        set envelope["upset_timer"] to 0.
    }

    if (envelope["state"] = "normal" or envelope["state"] = "authority_assist") and envelope["upset_timer"] >= config_envelope["upset_confirm_time"] {
        set envelope["state"] to "upset_zero_aoa".
        set envelope["rcs_assist"] to rcs_available.
    }

    if envelope["state"] = "upset_zero_aoa" {
        set envelope["min_throttle"] to 1.
        set envelope["rcs_assist"] to rcs_available.
        if actual_aoa <= config_envelope["recovery_safe_aoa"] and aoa_rate <= 0 {
            set envelope["state"] to "upset_pullup".
        }
    } else if envelope["state"] = "upset_pullup" {
        set envelope["min_throttle"] to 1.
        set envelope["rcs_assist"] to rcs_available.
        if pitch_for() >= config_envelope["recovery_exit_pitch"] and actual_aoa <= envelope["max_aoa"] {
            set envelope["state"] to "normal".
            set envelope["restore_steering"] to true.
            set envelope["stable_timer"] to 0.
        }
    } else {
        if envelope["pitchdown_timer"] >= config_envelope["rcs_pitchdown_confirm_time"] or envelope["authority_timer"] >= config_envelope["rcs_general_confirm_time"] {
            set envelope["rcs_assist"] to true.
            set envelope["state"] to "authority_assist".
        }

        if envelope["rcs_assist"] {
            if actual_aoa <= requested_aoa + 0.25 and aoa_rate <= 0 {
                set envelope["stable_timer"] to envelope["stable_timer"] + dt.
                if envelope["stable_timer"] >= config_envelope["rcs_release_time"] {
                    set envelope["rcs_assist"] to false.
                    set envelope["state"] to "normal".
                }
            } else {
                set envelope["stable_timer"] to 0.
            }
        }
    }

    if not rcs_available and not(envelope["state"] = "upset_zero_aoa" or envelope["state"] = "upset_pullup") {
        set envelope["rcs_assist"] to false.
        if envelope["state"] = "authority_assist" {
            set envelope["state"] to "normal".
        }
    }
    if envelope["rcs_assist"] {
        rcs on.
    } else {
        rcs off.
    }

    set envelope["last_aoa"] to actual_aoa.
    set envelope["last_speed"] to ship:airspeed.
    set envelope["last_pitch_error"] to pitch_error.
}

function envelope_apply_aoa_limits {
    set dap["aoa"]["target_aoa"] to min(dap["aoa"]["target_aoa"],dap["envelope"]["max_aoa"]).
    set dap["aoa"]["target_bank"] to envelope_clamp(dap["aoa"]["target_bank"],-dap["envelope"]["max_bank"],dap["envelope"]["max_bank"]).
}

function envelope_apply_aerostr_limits {
    set dap["aerostr"]["targetPitch"] to envelope_clamp(dap["aerostr"]["targetPitch"],AVES["MinPitch"],AVES["MaxPitch"]).
    set dap["aerostr"]["targetRoll"] to envelope_clamp(dap["aerostr"]["targetRoll"],-dap["envelope"]["max_bank"],dap["envelope"]["max_bank"]).
}

function envelope_run_recovery {
    if dap["envelope"]["state"] = "upset_zero_aoa" {
        aoa_bank_management(0,0).
    } else {
        aoa_bank_management(dap["envelope"]["max_aoa"],0).
    }
    lock steering to heading(dap["aoa"]["aoa_yaw"],dap["aoa"]["aoa_pitch"],dap["aoa"]["aoa_roll"]).
}

if not (dap:haskey("update")) {
    dap:add("update", {
    if not dap["setup_done"]{
        setup_dap().
    }
    set dap["dt"] to time:seconds - dap["l_t"].
    set dap["l_t"] to time:seconds.
    envelope_refresh().
    if not(dap["dap_mode_set"]["dapmode"] = dap["dap_mode"] and dap["dap_mode_set"]["str_mode"] = dap["str_mode"]){
        if dap["dap_mode"] = "auto" and dap["str_mode"] = "aerostr"{
            dap:set_aerostr_auto().
        }else if dap["dap_mode"] = "auto" and dap["str_mode"] = "aoa"{
            dap:set_aoa_auto().
        }else if dap["dap_mode"] = "auto" and dap["str_mode"] = "vector"{
            dap:set_vector_auto().
        }else if dap["dap_mode"] = "css"{
            dap:set_css().
        }else if dap["dap_mode"] = "off"{ 
            dap:set_off().
        }
    }
    if dap["dap_mode"] = "auto"{
        if SAS{
            sas off.
        }
        if dap["str_mode"] = "aerostr"{
            aerostr().
                set dap["aerostr"]["targetDirection"] to dap["aerostr"]["turn_heading"].
                set dap["aerostr"]["targetPitch"] to dap["aerostr"]["turn_pitch"]+dap["aerostr"]["distance_pitch"].
                set dap["aerostr"]["targetRoll"] to dap["aerostr"]["turn_roll"].
                envelope_apply_aerostr_limits().
        }
        if dap["str_mode"] = "aoa"{
            envelope_apply_aoa_limits().
            if ship:altitude > aves["teamALTITUDE"] {
                set dap["aoa"]["smooth_target_aoa"] to changeRate(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["target_aoa"],dap["dt"], AVES["Pitch_rate"]["high"]).
                set dap["aoa"]["smooth_target_bank"] to changeRate(dap["aoa"]["smooth_target_bank"], dap["aoa"]["target_bank"],dap["dt"], AVES["Rotation_rate"]["high"]).
            } else {
                set dap["aoa"]["smooth_target_aoa"] to changeRate(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["target_aoa"],dap["dt"], AVES["Pitch_rate"]["low"]).
                set dap["aoa"]["smooth_target_bank"] to changeRate(dap["aoa"]["smooth_target_bank"], dap["aoa"]["target_bank"],dap["dt"], AVES["Rotation_rate"]["low"]).
            }
            set dap["aoa"]["smooth_target_aoa"] to min(dap["aoa"]["smooth_target_aoa"],dap["envelope"]["max_aoa"]).
            set dap["aoa"]["smooth_target_bank"] to envelope_clamp(dap["aoa"]["smooth_target_bank"],-dap["envelope"]["max_bank"],dap["envelope"]["max_bank"]).
            if dap["aoa"]["base_pitch"] = 0 {
                aoa_bank_management(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["smooth_target_bank"]).
            } else {
                aoa_bank_management(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["smooth_target_bank"], dap["aoa"]["base_pitch"]).
                set dap["aoa"]["base_pitch"] to 0.
            }
            
             
        
        }
        if dap["str_mode"] = "vector"{
            lock steering to dap["vector"]["targetVector"].
        }
    }
    if dap["dap_mode"] = "css"{
        if SAS{
            sas off.
        }
        local css_in is lex().
        css_in:add("pitch", SHIP:CONTROL:PILOTPITCH).
        css_in:add("yaw", SHIP:CONTROL:PILOTYAW).
        css_in:add("roll", SHIP:CONTROL:PILOTROLL).

        if dap["str_mode"] = "aoa"{
            if css_in["roll"] = 0{
                set css_in["roll"] to css_in["yaw"].
            }

            local aoa is dap["css"]["last_aoa"].
            local bank is dap["css"]["last_roll"].
            if css_in["pitch"] > 0.5{
                if ship:altitude > aves["teamALTITUDE"] {
                    set aoa to changeRate(dap["css"]["last_aoa"], dap["css"]["last_aoa"]+AVES["Pitch_rate"]["high"],dap["dt"], AVES["Pitch_rate"]["high"]).
                } else {
                    set aoa to changeRate(dap["css"]["last_aoa"], dap["css"]["last_aoa"]+AVES["Pitch_rate"]["low"],dap["dt"], AVES["Pitch_rate"]["low"]).
                }
            }else if css_in["pitch"] < -0.5{
                if ship:altitude > aves["teamALTITUDE"] {
                    set aoa to changeRate(dap["css"]["last_aoa"], dap["css"]["last_aoa"]-AVES["Pitch_rate"]["high"],dap["dt"], AVES["Pitch_rate"]["high"]).
                } else {
                    set aoa to changeRate(dap["css"]["last_aoa"], dap["css"]["last_aoa"]-AVES["Pitch_rate"]["low"],dap["dt"], AVES["Pitch_rate"]["low"]).
                }
            }else{
                set aoa to dap["css"]["last_aoa"].
            }
            if css_in["roll"] > 0.5{
                if ship:altitude > aves["teamALTITUDE"] {
                    set bank to changeRate(dap["css"]["last_roll"], dap["css"]["last_roll"]-AVES["Rotation_rate"]["high"],dap["dt"], AVES["Rotation_rate"]["high"]).
                } else {
                    set bank to changeRate(dap["css"]["last_roll"], dap["css"]["last_roll"]-AVES["Rotation_rate"]["low"],dap["dt"], AVES["Rotation_rate"]["low"]).
                }
            }else if css_in["roll"] < -0.5{
                if ship:altitude > aves["teamALTITUDE"] {
                    set bank to changeRate(dap["css"]["last_roll"], dap["css"]["last_roll"]+AVES["Rotation_rate"]["high"],dap["dt"], AVES["Rotation_rate"]["high"]).
                } else {
                    set bank to changeRate(dap["css"]["last_roll"], dap["css"]["last_roll"]+AVES["Rotation_rate"]["low"],dap["dt"], AVES["Rotation_rate"]["low"]).
                }
            }else{
                set bank to dap["css"]["last_roll"].
            }
            set aoa to min(aoa,dap["envelope"]["max_aoa"]).
            set bank to envelope_clamp(bank,-dap["envelope"]["max_bank"],dap["envelope"]["max_bank"]).
            set dap["css"]["last_roll"] to bank.
            set dap["css"]["last_aoa"] to aoa.
            aoa_bank_management(aoa,bank,0,true).

            
        }
        if dap["str_mode"] = "aerostr"{
            set css_in["pitch"] to css_in["pitch"] * dap["css"]["pitch_aerostr_spd"].
            set css_in["yaw"] to css_in["yaw"] * dap["css"]["yaw_aerostr_spd"].
            set css_in["roll"] to css_in["roll"] * dap["css"]["roll_aerostr_spd"].

            SET dap["css"]["pitch_out"] TO css_in["pitch"] * 5 + pitch_for().
            SET dap["css"]["YAW_out"] TO css_in["yaw"] * 5 + compass_for().
            SET dap["css"]["roll_out"] TO css_in["roll"] * 5 + roll_for().
            SET dap["css"]["pitch_out"] TO envelope_clamp(dap["css"]["pitch_out"],AVES["MinPitch"],AVES["MaxPitch"]).
            SET dap["css"]["roll_out"] TO envelope_clamp(dap["css"]["roll_out"],-dap["envelope"]["max_bank"],dap["envelope"]["max_bank"]).


        }
    }
    if ((dap["envelope"]["state"] = "upset_zero_aoa" or dap["envelope"]["state"] = "upset_pullup") and dap["str_mode"] <> "vector") or dap["envelope"]["state"] = "terrain_pullup" {
        envelope_run_recovery().
    } else if dap["envelope"]["restore_steering"] {
        lock steering to dap_steering.
        set dap["envelope"]["restore_steering"] to false.
    }
}).
}
if not (dap:haskey("set_aoa_auto")) {
    dap:add("set_aoa_auto", {
    if not dap["setup_done"]{
        setup_dap().
    }
    lock dap_steering to heading(dap["aoa"]["aoa_yaw"], dap["aoa"]["aoa_pitch"], dap["aoa"]["aoa_roll"]).
    lock steering to dap_steering.
    lock throttle to max(dapthrottle,dap["envelope"]["min_throttle"]).
    set dap["dap_mode"] to "auto".
    set dap["str_mode"] to "aoa".
    set dap["dap_mode_set"]["dapmode"] to "auto".
    set dap["dap_mode_set"]["str_mode"] to "aoa".


}).
}
if not (dap:haskey("set_aerostr_auto")) {
    dap:add("set_aerostr_auto", {
    if not dap["setup_done"]{
        setup_dap().
    }
    lock dap_steering to heading(dap["aerostr"]["targetDirection"], dap["aerostr"]["targetPitch"], dap["aerostr"]["targetRoll"]).
    lock steering to dap_steering.
    lock throttle to max(dapthrottle,dap["envelope"]["min_throttle"]).
    set dap["dap_mode"] to "auto".
    set dap["str_mode"] to "aerostr".
    set dap["dap_mode_set"]["dapmode"] to "auto".
    set dap["dap_mode_set"]["str_mode"] to "aerostr".

}).
}
if not (dap:haskey("set_vector_auto")) {
    dap:add("set_vector_auto", {
    if not dap["setup_done"]{
        setup_dap().
    }
    lock dap_steering to dap["vector"]["targetVector"].
    lock steering to dap_steering.
    lock throttle to max(dapthrottle,dap["envelope"]["min_throttle"]).
    set dap["dap_mode"] to "auto".
    set dap["str_mode"] to "vector".
    set dap["dap_mode_set"]["dapmode"] to "auto".
    set dap["dap_mode_set"]["str_mode"] to "vector".

}).
}
if not (dap:haskey("set_off")) {
    dap:add("set_off", {
    if not dap["setup_done"]{
        setup_dap().
    }
    set dap["dap_mode"] to "off".
    set dap["dap_mode_set"]["dapmode"] to "off".
    set dap["dap_mode_set"]["str_mode"] to dap["str_mode"].
    lock throttle to SHIP:CONTROL:PILOTMAINTHROTTLE.
    set dapthrottle to 0.
    unlock steering.
    sas on.

}).
}

if not(dap:haskey("set_css")) {
    dap:add("set_css", {
    if not dap["setup_done"]{
        setup_dap().
    }
    set dap["dap_mode"] to "css".
    set dap["css"]["yaw_out"] to compass_for().
    set dap["css"]["pitch_out"] to pitch_for().
    set dap["css"]["roll_out"] to roll_for().
    set dap["css"]["last_roll"] to -roll_for().
    set dap["css"]["last_aoa"] to calc_aoa().
    lock dap_steering to heading(dap["css"]["yaw_out"], dap["css"]["pitch_out"], dap["css"]["roll_out"]).
    // set_off() deliberately unlocks steering.  Every managed-mode setter
    // must reattach it so CSS/auto handoffs always regain control.
    lock steering to dap_steering.
    lock throttle to max(SHIP:CONTROL:PILOTMAINTHROTTLE,dap["envelope"]["min_throttle"]).
    set dap["dap_mode_set"]["dapmode"] to "css".
    set dap["dap_mode_set"]["str_mode"] to dap["str_mode"].
}).
}




function engine_blocked_by_abort {
    parameter engine_type, engine_part.
    if not(defined abort_state) { return false. }
    if not abort_state:haskey("engines") { return false. }
    if not abort_state["engines"]:haskey(engine_type) { return false. }
    if not abort_state["engines"][engine_type]:haskey("failed_ids") { return false. }
    return abort_state["engines"][engine_type]["failed_ids"]:haskey("part_" + engine_part:uid).
}

function rapierson{
    for rapiers_ in ship:partstitledpattern("R.A.P.I.E.R"){
        if not rapiers_:ignition and not engine_blocked_by_abort("rapier",rapiers_){
            rapiers_:ACTIVATE.
        }
    }
    set rapiers to true.

}
function rapiersoff{
    for rapiers_ in ship:partstitledpattern("R.A.P.I.E.R"){
        if rapiers_:ignition{
            rapiers_:SHUTDOWN.
        }
    }
     set rapiers to false.
}
function togglerapiermode{
    PARAMETER TGT_MODE IS "TOGGEL".
    if TGT_MODE = "TOGGEL"{
        for rapiers_ in ship:partstitledpattern("R.A.P.I.E.R"){
            if not engine_blocked_by_abort("rapier",rapiers_) {
                rapiers_:TOGGLEMODE().
                SET rapier_mode to RAPIERS_:MODE.
            }
        }

    }ELSE IF TGT_MODE = "AIR"{
        
        for rapiers_ in ship:partstitledpattern("R.A.P.I.E.R"){
            IF NOT engine_blocked_by_abort("rapier",rapiers_) {
                IF NOT (rapiers_:MODE = "AirBreathing") { rapiers_:TOGGLEMODE(). }
                SET rapier_mode to "AirBreathing".
            }
        }
    }ELSE IF TGT_MODE = "CLOSED"{
        for rapiers_ in ship:partstitledpattern("R.A.P.I.E.R"){
            IF NOT engine_blocked_by_abort("rapier",rapiers_) {
                IF NOT (rapiers_:MODE = "ClosedCycle") { rapiers_:TOGGLEMODE(). }
                SET rapier_mode to "ClosedCycle".
            }
        }
    }
}   
function nervson{
    for nervs_ in  ship:partstitledpattern("LV-N"){
        if not nervs_:ignition and not engine_blocked_by_abort("nerv",nervs_){
        nervs_:ACTIVATE.
        }
    }
    set nervs to true.
}
function nervsoff{
    for nervs_ in  ship:partstitledpattern("LV-N"){
        if nervs_:ignition{
            nervs_:SHUTDOWN.
        }
    }
    set nervs to false.
}
