// Terminal-area route and energy manager for Poseidon.
//
// The planner deliberately separates energy management from final approach:
// a rectangular holding pattern absorbs excess energy, while the downwind,
// base, and final legs establish a repeatable localizer and glide-slope
// intercept from any arrival direction.

// Shared telemetry for the terminal-route GUI and diagnostic log.
global terminal_route_debug is lex(
    "active", false,
    "phase", "inactive",
    "side", "",
    "hold_laps", 0,
    "target_distance", 0,
    "remaining_distance", 0,
    "target_altitude", 0,
    "desired_vertical_speed", 0,
    "pitch_bias", 0,
    "target_aoa", 0,
    "energy_margin", 0,
    "target_energy", 0,
    "airbrake", false,
    "gear", false,
    "throttle", 0,
    "last_log_time", -1
).

function terminal_route_energy_height {
    // Specific kinetic energy expressed as an equivalent altitude in metres.
    return ship:altitude - runway_altitude + (ship:airspeed ^ 2) / (2 * 9.81).
}

// Terminal-only lateral controller.  Unlike aeroturn's fixed-radius command,
// this fades bank to zero near the target heading so that small heading-error
// sign changes cannot command alternating full-bank turns.
function terminal_route_bank_command {
    parameter desired_heading, config_TR.
    local heading_error is desired_heading - compass_for_prograde().
    until abs(heading_error) <= 180 {
        if heading_error > 180 { set heading_error to heading_error - 360. }
        if heading_error < -180 { set heading_error to heading_error + 360. }
    }

    local deadband is config_TR["bank_deadband"].
    local full_error is max(config_TR["bank_full_error"], deadband + 1).
    local bank is 0.
    if abs(heading_error) > deadband {
        local magnitude is config_TR["bank_max"] * min(1, (abs(heading_error) - deadband) / (full_error - deadband)).
        // kOS roll convention: negative bank turns toward a positive heading error.
        if heading_error > 0 { set bank to -magnitude. }
        if heading_error < 0 { set bank to magnitude. }
    }
    return bank.
}

function terminal_route_init {
    local config_TR is AVES["TerminalRoute"].
    local final_distance is config_TR["final_distance"].
    local base_offset is config_TR["base_offset"].
    local downwind_extension is config_TR["downwind_extension"].
    local hold_radius is config_TR["hold_radius"].

    local final_fix is get_geoposition_along_heading(runway_start, runway_heading + 180, final_distance).
    local left_base is get_geoposition_along_heading(final_fix, runway_heading - 90, base_offset).
    local right_base is get_geoposition_along_heading(final_fix, runway_heading + 90, base_offset).
    local left_downwind is get_geoposition_along_heading(left_base, runway_heading + 180, downwind_extension).
    local right_downwind is get_geoposition_along_heading(right_base, runway_heading + 180, downwind_extension).

    // Use the nearer circuit side.  This makes the first intercept sensible
    // even when the craft reaches terminal guidance from the opposite side of
    // the runway or from behind it.
    local side is "left".
    local base_fix is left_base.
    local downwind_fix is left_downwind.
    if calcdistance_m(ship:geoposition, right_downwind) < calcdistance_m(ship:geoposition, left_downwind) {
        set side to "right".
        set base_fix to right_base.
        set downwind_fix to right_downwind.
    }

    // A four-point hold is less sensitive to an imperfect circular turn than
    // a pure orbit and gives the aircraft a clean exit back to downwind.
    local hold_points is list(
        get_geoposition_along_heading(downwind_fix, runway_heading + 180, hold_radius),
        get_geoposition_along_heading(downwind_fix, runway_heading - 90, hold_radius),
        get_geoposition_along_heading(downwind_fix, runway_heading, hold_radius),
        get_geoposition_along_heading(downwind_fix, runway_heading + 90, hold_radius)
    ).

    local route is lex(
        "phase", "intercept",
        "side", side,
        "final_fix", final_fix,
        "base_fix", base_fix,
        "downwind_fix", downwind_fix,
        "hold_points", hold_points,
        "hold_index", 0,
        "hold_laps", 0,
        "hold_radius", hold_radius,
        "hold_segment", hold_radius * 1.42,
        "target_altitude", ship:altitude,
        "remaining_distance", 0,
        "energy_margin", 0,
        "airbrake", false,
        "gear", false,
        "landing_ready", false,
        "last_phase_change_time", time:seconds
    ).

    // If the entry guidance has already removed most of the energy, do not
    // make an unnecessary detour through the holding pattern.
    local direct_distance is calcdistance_m(ship:geoposition, downwind_fix) +
        calcdistance_m(downwind_fix, base_fix) +
        calcdistance_m(base_fix, final_fix) + final_distance.
    local direct_target_energy is calculate_glideslope_alt(direct_distance) - runway_altitude + (config_TR["target_speed"] ^ 2) / (2 * 9.81).
    if terminal_route_energy_height() < direct_target_energy - config_TR["low_energy_margin"] {
        set route["phase"] to "downwind".
    }
    set terminal_route_debug["active"] to true.
    set terminal_route_debug["phase"] to route["phase"].
    set terminal_route_debug["side"] to route["side"].
    return route.
}

function terminal_route_current_target {
    parameter route.
    local config_TR is AVES["TerminalRoute"].
    if route["phase"] = "intercept" or route["phase"] = "hold" {
        return route["hold_points"][route["hold_index"]].
    }
    if route["phase"] = "downwind" {
        return route["downwind_fix"].
    }
    if route["phase"] = "base" {
        return route["base_fix"].
    }

    // On final, aim at a point on the extended centreline.  The aim point
    // is now allowed to sit farther out when the aircraft is still distant,
    // so alignment begins sooner and is less likely to be a late correction.
    local distance is calcdistance_m(ship:geoposition, runway_start).
    local lead_distance is distance * config_TR["final_lead_fraction"].
    return get_geoposition_along_heading(runway_start, runway_heading + 180, lead_distance).
}

function terminal_route_remaining_distance {
    parameter route.
    local target is terminal_route_current_target(route).
    local distance is calcdistance_m(ship:geoposition, target).
    local final_distance is calcdistance_m(route["final_fix"], runway_start).
    local base_distance is calcdistance_m(route["base_fix"], route["final_fix"]).
    local downwind_distance is calcdistance_m(route["downwind_fix"], route["base_fix"]).

    if route["phase"] = "intercept" {
        return distance + route["hold_segment"] * 4 + calcdistance_m(route["hold_points"][0], route["downwind_fix"]) + downwind_distance + base_distance + final_distance.
    }
    if route["phase"] = "hold" {
        return distance + route["hold_segment"] * (4 - route["hold_index"]) + calcdistance_m(route["hold_points"][0], route["downwind_fix"]) + downwind_distance + base_distance + final_distance.
    }
    if route["phase"] = "downwind" {
        return distance + downwind_distance + base_distance + final_distance.
    }
    if route["phase"] = "base" {
        return distance + base_distance + final_distance.
    }
    return calcdistance_m(ship:geoposition, runway_start).
}

function terminal_route_update {
    parameter route.
    local config_TR is AVES["TerminalRoute"].

    local target is terminal_route_current_target(route).
    local target_distance is calcdistance_m(ship:geoposition, target).
    local remaining_distance is terminal_route_remaining_distance(route).
    local profile_altitude is calculate_glideslope_alt(remaining_distance).
    local target_energy is profile_altitude - runway_altitude + (config_TR["target_speed"] ^ 2) / (2 * 9.81).
    local energy_margin is terminal_route_energy_height() - target_energy.

    local target_altitude is profile_altitude.
    local speed is max(ship:airspeed, 80).
    if route["phase"] = "intercept" or route["phase"] = "hold" {
        local hold_time is max(remaining_distance / speed, 5).
        local descent_time is min(hold_time, 20).
        local descent_target is ship:altitude - config_TR["hold_descent_rate"] * descent_time.
        set target_altitude to min(profile_altitude - config_TR["early_descent_margin"], descent_target).
        set target_altitude to max(target_altitude, runway_altitude + 500).
    } else if route["phase"] = "downwind" or route["phase"] = "base" {
        local downwind_time is max(remaining_distance / speed, 5).
        local descent_target is ship:altitude - config_TR["downwind_descent_rate"] * min(downwind_time, 20).
        set target_altitude to min(profile_altitude - config_TR["early_descent_margin"], descent_target).
        set target_altitude to max(target_altitude, runway_altitude + 300).
    } else if route["phase"] = "final" {
        local final_time is max(remaining_distance / speed, 3).
        local descent_target is ship:altitude - config_TR["final_descent_rate"] * min(final_time, 15).
        set target_altitude to min(profile_altitude, descent_target).
        set target_altitude to max(target_altitude, runway_altitude + 100).
    }

    set route["remaining_distance"] to remaining_distance.
    set route["target_altitude"] to target_altitude.
    set route["energy_margin"] to energy_margin.

    local phase_elapsed is time:seconds - route["last_phase_change_time"].

    if route["phase"] = "intercept" {
        // A low-energy craft must not spend more time intercepting a hold
        // point.  Go directly to the downwind leg and preserve its energy.
        if energy_margin < -config_TR["low_energy_margin"] {
            set route["phase"] to "downwind".
            set route["last_phase_change_time"] to time:seconds.
        } else if phase_elapsed > config_TR["phase_change_delay"] and target_distance < config_TR["intercept_hold_distance"] {
            set route["phase"] to "hold".
            set route["hold_index"] to 1.
            set route["last_phase_change_time"] to time:seconds.
        }
    } else if route["phase"] = "hold" {
        // A low-energy aircraft leaves the hold immediately.  A high-energy
        // aircraft completes as many full circuits as necessary before exit.
        if energy_margin < -config_TR["low_energy_margin"] {
            set route["phase"] to "downwind".
            set route["last_phase_change_time"] to time:seconds.
        } else if phase_elapsed > config_TR["phase_change_delay"] and target_distance < config_TR["intercept_hold_distance"] {
            set route["hold_index"] to route["hold_index"] + 1.
            if route["hold_index"] > 3 {
                set route["hold_index"] to 0.
                set route["hold_laps"] to route["hold_laps"] + 1.
                if energy_margin < config_TR["hold_exit_energy"] {
                    set route["phase"] to "downwind".
                    set route["last_phase_change_time"] to time:seconds.
                }
            }
        }
    } else if route["phase"] = "downwind" and phase_elapsed > config_TR["phase_change_delay"] and target_distance < config_TR["downwind_to_base_distance"] {
        set route["phase"] to "base".
        set route["last_phase_change_time"] to time:seconds.
    } else if route["phase"] = "base" and phase_elapsed > config_TR["phase_change_delay"] and target_distance < config_TR["base_to_final_distance"]{
        //and abs(ship:heading - heading_to_target(route["final_fix"])) < 20 
        set route["phase"] to "final".
        set route["last_phase_change_time"] to time:seconds.
    }

    // Do not re-enter intercept from downwind/base during the terminal phase.
    // This avoids oscillation and keeps the approach stable once the pattern
    // has already committed to downwind or base.
    local direct_distance is calcdistance_m(ship:geoposition, runway_start).
    set route["airbrake"] to energy_margin > config_TR["brake_energy"] or (route["phase"] = "final" and ship:airspeed > config_TR["final_brake_speed"] and ship:altitude - runway_altitude > 100).
    set route["gear"] to direct_distance < 2200 and ship:altitude - runway_altitude < 180.
    set route["landing_ready"] to route["phase"] = "final" and direct_distance < 1400 and ship:altitude - runway_altitude < 110.

    set terminal_route_debug["active"] to true.
    set terminal_route_debug["phase"] to route["phase"].
    set terminal_route_debug["side"] to route["side"].
    set terminal_route_debug["hold_laps"] to route["hold_laps"].
    set terminal_route_debug["target_distance"] to target_distance.
    set terminal_route_debug["remaining_distance"] to remaining_distance.
    set terminal_route_debug["target_altitude"] to target_altitude.
    set terminal_route_debug["energy_margin"] to energy_margin.
    set terminal_route_debug["target_energy"] to target_energy.
    set terminal_route_debug["airbrake"] to route["airbrake"].
    set terminal_route_debug["gear"] to route["gear"].
    return route.
}

function terminal_route_fly {
    parameter route.
    local config_TR is AVES["TerminalRoute"].
    local target is terminal_route_current_target(route).
    local distance is route["remaining_distance"].
    local time_to_go is max(distance / max(ship:airspeed, 80), 5).
    local desired_vertical_speed is 0.
    local pid_log is "none".
    if route["phase"] = "final" {
        local final_vs_dist is distance * config_TR["final_vs_distance_factor"].
        local alt_tgt is calculate_glideslope_alt(final_vs_dist).
        set desired_vertical_speed to calc_vvdot(final_vs_dist, ship:airspeed, alt_tgt, ship:altitude).
    } else {
        set desired_vertical_speed to (route["target_altitude"] - ship:altitude) / time_to_go.
    }

    if route["phase"] = "intercept" or route["phase"] = "hold" {
        // Bleed excess energy in a controlled descent rather than trying to
        // climb onto the glideslope calculated from the entire holding route.
        set desired_vertical_speed to min(desired_vertical_speed, -config_TR["hold_descent_rate"]).
    }

    local pitch_bias is 0.
    if route["phase"] = "final" {
        if not (defined final_pitch_bias_pid){
            set final_pitch_bias_pid to pidloop(0.5,0.2,0.4).
            set final_pitch_bias_pid:maxoutput to 15.
            set final_pitch_bias_pid:minoutput to -30.
        }
        set final_pitch_bias_pid:setpoint to desired_vertical_speed.
        set pitch_bias to final_pitch_bias_pid:update(time:seconds, ship:verticalspeed).
        set pid_log to pitch_bias.
    } else {
        set pitch_bias to max(config_TR["pitch_bias_min"], min(config_TR["pitch_bias_max"], (desired_vertical_speed - ship:verticalspeed) * 0.35)).
    }
    local target_aoa is 16.
    local max_energy_aoa is 30.
    if route["phase"] = "intercept" or route["phase"] = "hold" {
        set max_energy_aoa to config_TR["hold_aoa_max"].
    }

    if route["energy_margin"] > 300 {
        set target_aoa to min(max_energy_aoa, 16 + route["energy_margin"] / 120).
    }
    if route["energy_margin"] < -config_TR["low_energy_margin"] {
        set target_aoa to config_TR["descent_min_aoa"].
        set dapthrottle to 0.
    } else if ship:airspeed < config_TR["minimum_speed"] {
        set dapthrottle to 0.
    } else {
        set dapthrottle to 0.
    }

    // AoA is lift as well as drag.  When the vertical controller needs more
    // descent, unload AoA instead of relying on pitch bias to fight a large
    // positive AoA command.  Low-energy cases keep their protective AoA and
    // throttle logic above.
    if route["energy_margin"] > config_TR["brake_energy"] {
        local descent_error is min(0, desired_vertical_speed - ship:verticalspeed).
        if descent_error < 0 {
            // Once the craft is descending too slowly, unload to a low-drag
            // descent AoA first, then reduce further as the error grows.
            set target_aoa to min(target_aoa, config_TR["descent_aoa_max"]).
            set target_aoa to max(config_TR["descent_min_aoa"], target_aoa + descent_error * config_TR["descent_aoa_gain"]).
        }
    }

    set dap["str_mode"] to "aoa".
    set dap["aoa"]["target_aoa"] to target_aoa.
    set dap["aoa"]["target_bank"] to terminal_route_bank_command(heading_to_target(target), config_TR).
    // aoa_bank_management treats base_pitch as an absolute pitch baseline.
    // Supply prograde plus the terminal correction so pitch_bias stays a bias.
    if route["phase"] ="final"{
        set dap["aoa"]["base_pitch"] to pitch_bias.
    }else{
        set dap["aoa"]["base_pitch"] to pitch_for_prograde() + pitch_bias.
    }
    set terminal_route_debug["desired_vertical_speed"] to desired_vertical_speed.
    set terminal_route_debug["pitch_bias"] to pitch_bias.
    set terminal_route_debug["target_aoa"] to target_aoa.
    set terminal_route_debug["throttle"] to dapthrottle.
    set terminal_route_debug["Pid_log"] to pid_log.

    // Log at 2 Hz so a complete approach is inspectable without flooding the volume.
    if time:seconds - terminal_route_debug["last_log_time"] >= 0.5 {
        log "TR phase=" + terminal_route_debug["phase"] + " side=" + terminal_route_debug["side"] + " laps=" + terminal_route_debug["hold_laps"] + " target_dist=" + round(terminal_route_debug["target_distance"],1) + " remain=" + round(terminal_route_debug["remaining_distance"],1) + " alt=" + round(ship:altitude,1) + " target_alt=" + round(terminal_route_debug["target_altitude"],1) + " vs=" + round(ship:verticalspeed,1) + " desired_vs=" + round(desired_vertical_speed,1) + " bias=" + round(pitch_bias,1) + " energy_margin=" + round(terminal_route_debug["energy_margin"],1) + " target_energy=" + round(terminal_route_debug["target_energy"],1) + " aoa=" + round(target_aoa,1) + " bank=" + round(dap["aoa"]["target_bank"],1) + " throttle=" + round(dapthrottle,2) + " brake=" + terminal_route_debug["airbrake"] + " gear=" + terminal_route_debug["gear"] + " pid_log=" + pid_log to "terminal_route.log".
        set terminal_route_debug["last_log_time"] to time:seconds.
    }
    set Lastest_status to "terminal " + route["phase"] + " | energy " + round(route["energy_margin"]) + "m | loop " + route["hold_laps"].
}
