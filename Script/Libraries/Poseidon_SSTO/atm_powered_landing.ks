// Atmospheric powered landing.
// This is not the vacuum tail-sit. The craft stays wings-level, uses lift
// while it exists, and uses NERV plus closed-cycle RAPIER thrust to hold a
// descent while drag and brakes take out the remaining groundspeed.
// Touchdown is on the landing gear, upright, at landing_touchdown_speed.
// Closed-cycle oxidizer is reserved for the final arrest. The NERVs carry
// the long descent, and RAPIER thrust limits supply only the deficit.
//
// These are planning estimates. Replace one only after landing_model_estimates
// is logged on a Laythe wheeled flight or a Duna powered flight.

if not (defined landing_model_estimates) {
    global landing_model_estimates is lex(
        "thrust_attitude_deg", 12,
        "min_aoa_deg", 12,
        "sink_arrest_attitude_deg", 22,
        "max_command_aoa_deg", 30,
        "glide_angle_deg", 3,
        "default_descent_vs", -8,
        "high_descent_agl_m", 8000,
        "high_descent_vs", -45,
        "mid_descent_agl_m", 3000,
        "mid_descent_vs", -18,
        "low_descent_agl_m", 800,
        "low_descent_vs", -7,
        "final_descent_agl_m", 200,
        "final_descent_vs", -6,
        "flare_descent_vs", -3,
        "rapier_always_agl_m", 500,
        "rapier_align_agl_m", 1600,
        "rapier_sink_agl_m", 1800,
        "no_lift_seconds", 30,
        "propellant_margin", 1.2,
        "rollout_margin", 1.2,
        "brake_mu", 0.4,
        "ox_mixture_fraction", 0.55,
        "lf_mixture_fraction", 0.45,
        "lift_support_fraction", 0.75,
        "support_weight_margin", 1.08,
        "hover_thrust_fraction", 1.05,
        "hover_touchdown_mps", 70,
        "wheeled_max_slope_deg", 2.5,
        "powered_max_slope_deg", 6,
        "wheeled_max_roughness_m", 12,
        "powered_max_roughness_m", 30,
        "wheeled_max_approach_mps", 165,
        "powered_max_touchdown_mps", 155,
        "kerbin_approach_mps", 125,
        "kerbin_gravity", 9.80665,
        "sample_min_speed_mps", 40,
        "sample_min_lift_kn", 1,
        "wet_terrain_m", 1,
        "speed_scale_cap", 1.35
    ).
}

function landing_estimate {
    parameter key, fallback.
    if defined landing_model_estimates and landing_model_estimates:haskey(key) {
        return landing_model_estimates[key].
    }
    return fallback.
}

function atm_powered_restore_limits {
    for item in atm_land["engines"] {
        set item["engine"]:thrustlimit to item["limit"].
    }
}

// One throttle is shared by every engine. Limit the RAPIERs to the force the
// NERVs cannot provide so a thin-air landing does not burn the oxidizer reserve
// holding the whole weight on rocket mode.
function atm_powered_apply_thrust {
    parameter needed, use_rapier.
    if defined abort_state and abort_state:haskey("managed") and abort_state["managed"] {
        local available is ship:availablethrust.
        if available < 1 { set dapthrottle to 0. }
        else { set dapthrottle to max(0, min(1, needed / available)). }
        return dapthrottle.
    }
    if use_rapier {
        togglerapiermode("CLOSED").
        rapierson().
    } else { rapiersoff(). }
    local pressure is 0.
    if body_has_atmosphere() { set pressure to ship:body:atm:altitudepressure(ship:altitude). }
    local nerv_max is 0.
    local rapier_max is 0.
    for item in atm_land["engines"] {
        local engine is item["engine"].
        local capacity is engine:maxthrustat(pressure) * item["limit"] / 100.
        if item["rapier"] { set rapier_max to rapier_max + capacity. }
        else { set nerv_max to nerv_max + capacity. }
    }
    if needed <= 0 {
        set dapthrottle to 0.
        atm_powered_restore_limits().
        return 0.
    }
    local nerv_limit is 100.
    local rapier_limit is 0.
    if not use_rapier or rapier_max < 1 {
        set nerv_limit to max(0, min(100, 100 * needed / max(1, nerv_max))).
    } else {
        if needed <= nerv_max {
            set nerv_limit to max(0, min(100, 100 * needed / max(1, nerv_max))).
        } else {
            set nerv_limit to 100.
            set rapier_limit to max(0, min(100, 100 * (needed - nerv_max) / max(1, rapier_max))).
        }
    }
    for item in atm_land["engines"] {
        local fraction is nerv_limit.
        if item["rapier"] { set fraction to rapier_limit. }
        set item["engine"]:thrustlimit to item["limit"] * fraction / 100.
    }
    set dapthrottle to 1.
    return max(nerv_limit, rapier_limit) / 100.
}

function atm_powered_init {
    local support is 80.
    if defined landing_touchdown_speed { set support to max(50, landing_touchdown_speed). }
    global atm_land is lex(
        "support_speed", support,
        "gear", false,
        "engines", list(),
        "contact_on_strip", true,
        "started", time:seconds
    ).
    set dap["str_mode"] to "aoa".
    set dap["aoa"]["target_aoa"] to 16.
    set dap["aoa"]["target_bank"] to 0.
    set dapthrottle to 0.
    local eng_list is list().
    list engines in eng_list.
    for engine in eng_list {
        local title is engine:title.
        local rocket is title:contains("R.A.P.I.E.R") or title:contains("RAPIER").
        if rocket or title:contains("LV-N") or title:contains("Nerv") or title:contains("Atomic") {
            atm_land["engines"]:add(lex("engine", engine, "limit", engine:thrustlimit, "rapier", rocket)).
        }
    }
    nervson().
    rapiersoff().
    brakes off.
    gear off.
    rcs on.
    flight_log_event("atm_powered_start", "support_speed=" + round(support, 1) +
        "|breathable=" + body_breathable() + "|ox=" + round(ship:oxidizer, 1) +
        "|mass=" + round(ship:mass, 2) +
        "|thrust_attitude_deg=" + landing_estimate("thrust_attitude_deg", 12) +
        "|min_aoa_deg=" + landing_estimate("min_aoa_deg", 12) +
        "|sink_arrest_attitude_deg=" + landing_estimate("sink_arrest_attitude_deg", 22) +
        "|max_command_aoa_deg=" + landing_estimate("max_command_aoa_deg", 30) +
        "|glide_angle_deg=" + landing_estimate("glide_angle_deg", 3) +
        "|default_descent_vs=" + landing_estimate("default_descent_vs", -8) +
        "|high_descent_agl_m=" + landing_estimate("high_descent_agl_m", 8000) +
        "|high_descent_vs=" + landing_estimate("high_descent_vs", -45) +
        "|mid_descent_agl_m=" + landing_estimate("mid_descent_agl_m", 3000) +
        "|mid_descent_vs=" + landing_estimate("mid_descent_vs", -18) +
        "|low_descent_agl_m=" + landing_estimate("low_descent_agl_m", 800) +
        "|low_descent_vs=" + landing_estimate("low_descent_vs", -7) +
        "|final_descent_agl_m=" + landing_estimate("final_descent_agl_m", 200) +
        "|final_descent_vs=" + landing_estimate("final_descent_vs", -6) +
        "|flare_descent_vs=" + landing_estimate("flare_descent_vs", -3) +
        "|rapier_always_agl_m=" + landing_estimate("rapier_always_agl_m", 500) +
        "|rapier_align_agl_m=" + landing_estimate("rapier_align_agl_m", 1600) +
        "|rapier_sink_agl_m=" + landing_estimate("rapier_sink_agl_m", 1800)).
}

function atm_powered_finished {
    parameter distance_m.
    set dapthrottle to 0.
    atm_powered_restore_limits().
    local on_pad is atm_land["contact_on_strip"].
    local reason is "powered_touchdown".
    if ship:status = "SPLASHED" { set reason to "splashed". set on_pad to false. }
    else if not on_pad { set reason to "powered_stop_off_site". }
    set recovery_result to lex("complete", true, "success", on_pad and ship:status = "LANDED", "reason", reason).
    flight_log_event("landing_outcome", "success=" + recovery_result["success"] + "|reason=" + reason +
        "|distance=" + round(distance_m, 1) + "|method=powered").
    if defined reentry_preserve_propulsion and reentry_preserve_propulsion and defined abort_state {
        set abort_state["active"] to false.
        set abort_state["result"] to lex("success", recovery_result["success"], "reason", reason).
        flight_log_event("recovery_outcome", "mode=" + abort_state["mode"] +
            "|success=" + recovery_result["success"] + "|reason=" + reason).
    }
    if recovery_result["success"] { log_status("Powered landing completed"). }
    else { log_status("Powered landing ended: " + reason). }
    return true.
}

// One guidance tick. Returns true when the reentry loop should end.
function atm_powered_update {
    if not (defined atm_land) { atm_powered_init(). }
    local agl is alt:radar.
    local geometry is terminal_route_geometry().
    local length_m is calcdistance_m(runway_start, runway_end).
    local aim is min(AVES["Landing"]["runway_touchdown_distance"], length_m * 0.3).
    local remaining is geometry["along_track"] + aim.
    local aim_point is get_geoposition_along_heading(runway_start, runway_heading, aim).
    if remaining > 1500 {
        local intercept is max(0, geometry["along_track"] - 1500).
        set aim_point to get_geoposition_along_heading(runway_start, runway_heading + 180, intercept).
    } else { set aim_point to runway_end. }
    local distance_m is calcdistance_m(ship:geoposition, runway_start).
    local local_up is (-ship:body:position):normalized.
    local gravity is body_local_gravity(ship:altitude).
    local ground_speed is ship:groundspeed.
    local support is atm_land["support_speed"].

    if ship:status = "LANDED" {
        if geometry["along_track"] > 0 or -geometry["along_track"] > length_m or abs(geometry["cross_track"]) > 30 {
            set atm_land["contact_on_strip"] to false.
        }
    }
    if ship:status = "LANDED" and ground_speed < 2 { return atm_powered_finished(distance_m). }
    if ship:status = "SPLASHED" { return atm_powered_finished(distance_m). }

    local default_vs is landing_estimate("default_descent_vs", -8).
    local high_agl is landing_estimate("high_descent_agl_m", 8000).
    local mid_agl is landing_estimate("mid_descent_agl_m", 3000).
    local low_agl is landing_estimate("low_descent_agl_m", 800).
    local final_agl is landing_estimate("final_descent_agl_m", 200).
    local glide_deg is landing_estimate("glide_angle_deg", 3).
    local min_aoa is landing_estimate("min_aoa_deg", 12).
    local thrust_attitude is landing_estimate("thrust_attitude_deg", 12).
    local max_aoa is landing_estimate("max_command_aoa_deg", 30).
    local sink_attitude is landing_estimate("sink_arrest_attitude_deg", 22).
    local rapier_always is landing_estimate("rapier_always_agl_m", 500).
    local rapier_align is landing_estimate("rapier_align_agl_m", 1600).
    local rapier_sink_agl is landing_estimate("rapier_sink_agl_m", 1800).
    local desired_vs is default_vs.
    if agl > high_agl { set desired_vs to landing_estimate("high_descent_vs", -45). }
    else if agl > mid_agl { set desired_vs to landing_estimate("mid_descent_vs", -18). }
    else if agl > low_agl { set desired_vs to landing_estimate("low_descent_vs", -7). }
    else if agl > final_agl { set desired_vs to landing_estimate("final_descent_vs", -6). }
    else { set desired_vs to landing_estimate("flare_descent_vs", -3). }
    // Fast and already low: do not dive, but do not demand a hover the NERVs
    // cannot pay for. The final arrest is the RAPIER segment below.
    if ground_speed > support + 35 and agl < 5000 and agl > 400 { set desired_vs to max(desired_vs, default_vs). }
    // Follow the threshold approach plane while protecting actual terrain clearance.
    local profile_height is max(0, remaining) * tan(glide_deg).
    local profile_error is ship:altitude - runway_altitude - profile_height.
    set desired_vs to max(desired_vs, min(15, -ground_speed * tan(glide_deg) - profile_error * 0.15)).
    if abs(geometry["cross_track"]) > 30 or remaining > aim {
        local clearance_floor is max(8, min(60, profile_height)).
        if abs(geometry["cross_track"]) > 30 { set clearance_floor to 60. }
        if agl < clearance_floor { set desired_vs to max(desired_vs, (clearance_floor - agl) * 0.3). }
    }
    local path_angle is arctan2(ship:verticalspeed, max(1,ground_speed)).
    local aoa is max(min_aoa, min(max_aoa, thrust_attitude - path_angle)).
    if ship:verticalspeed < desired_vs - 2 { set aoa to min(max_aoa, aoa + desired_vs - ship:verticalspeed). }

    local bank_limit is 25.
    if ground_speed < 140 { set bank_limit to 12. }
    if ground_speed < 45 or agl < 80 { set bank_limit to 0. }
    local bank is 0.
    if bank_limit > 0 {
        set bank to terminal_route_bank_command(heading_to_target(aim_point), AVES["TerminalRoute"]).
        set bank to max(-bank_limit, min(bank_limit, bank)).
    }

    set dap["str_mode"] to "aoa".
    set dap["aoa"]["target_aoa"] to aoa.
    set dap["aoa"]["target_bank"] to bank.

    nervson().
    local use_rapier is agl < rapier_always or (agl < rapier_align and ground_speed < support + 40).
    local lift_up is 0.
    if addons:far:available {
        set lift_up to cur_aeroforce_ld()["lift"] * vdot(ship:facing:topvector, local_up).
    }
    local weight is ship:mass * gravity.
    // Positive vertical-speed error means the craft is sinking faster than asked.
    local vs_error is desired_vs - ship:verticalspeed.
    local needed is weight - lift_up + ship:mass * vs_error * 0.4.
    if ship:status = "LANDED" { set needed to 0. }
    local projection is vdot(ship:facing:vector, local_up).
    local sink is max(0, -ship:verticalspeed).
    local net_accel is (lift_up + landing_powered_axial * max(0,projection) - weight) / ship:mass.
    if sink > 3 and agl < 5 * sink + sink^2 / (2 * max(0.1, net_accel)) {
        set use_rapier to true.
        set needed to max(needed, weight - lift_up + ship:mass * sink^2 / (2 * max(1, agl - 5 * sink))).
        if net_accel <= 0 {
            set dap["aoa"]["target_aoa"] to min(max_aoa, max(aoa, sink_attitude - path_angle)).
            set dap["aoa"]["target_bank"] to 0.
        }
    }
    local axial_force is 0.
    if projection > 0 { set axial_force to max(0, needed) / projection. }
    if ship:verticalspeed < desired_vs - 3 and agl < rapier_sink_agl { set use_rapier to true. }
    local command_fraction is atm_powered_apply_thrust(axial_force, use_rapier).

    if agl < 400 and ground_speed < max(150, support + 25) {
        gear on.
        set atm_land["gear"] to true.
    }
    if agl < 40 or ship:status = "LANDED" { gear on. }

    local use_airbrake is ground_speed > support + 15 and agl > 60 and command_fraction < 0.4 and ship:status <> "LANDED".
    if ship:status = "LANDED" { brakes on. }
    else if use_airbrake { brakes on. }
    else { brakes off. }

    set Lastest_status to "Powered landing " + round(distance_m) + " m | AGL " + round(agl) +
        " | GS " + round(ground_speed) + " | thr " + round(command_fraction, 2).
    return false.
}
