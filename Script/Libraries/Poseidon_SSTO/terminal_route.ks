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
    "target_location", "unknown",
    "target_runway", "unknown",
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
    "along_track", 0,
    "cross_track", 0,
    "runway_heading_error", 0,
    "landing_stable", false,
    "go_around_reason", "",
    "last_log_time", -1
).

// Set true from the terminal to show the active route waypoint.  It defaults
// off so normal flights do not add navigation visuals.
if not(defined terminal_route_target_arrow_enabled) {
    global terminal_route_target_arrow_enabled is false.
}
if not(defined terminal_route_target_arrow_active) {
    global terminal_route_target_arrow_active is false.
}

function terminal_route_energy_height {
    // Specific kinetic energy expressed as an equivalent altitude in metres.
    local body_gravity is ship:body:mu / (ship:body:radius ^ 2).
    return ship:altitude - runway_altitude + (ship:airspeed ^ 2) / (2 * body_gravity).
}

// Express the aircraft position and direction in runway coordinates.  Positive
// along-track is on the approach side of the threshold; cross-track is signed.
function terminal_route_geometry {
    local distance is calcdistance_m(runway_start,ship:geoposition).
    local outward_heading is runway_heading + 180.
    local bearing_from_threshold is heading_between(runway_start,ship:geoposition).
    local bearing_error is normalized_heading_error(bearing_from_threshold,outward_heading).
    return lex(
        "distance",distance,
        "along_track",distance * cos(bearing_error),
        "cross_track",distance * sin(bearing_error),
        "bearing_error",bearing_error,
        "heading_error",normalized_heading_error(runway_heading,compass_for_prograde()),
        "altitude",ship:altitude - runway_altitude
    ).
}

function terminal_route_waypoint_captured {
    parameter route, target_distance.
    local geometry_config is AVES["TerminalRoute"]["Geometry"].
    set route["closest_target_distance"] to min(route["closest_target_distance"],target_distance).
    if target_distance < geometry_config["waypoint_capture_distance"] { return true. }
    if route["closest_target_distance"] < geometry_config["overshoot_eligible_distance"] and
       target_distance > route["closest_target_distance"] + geometry_config["waypoint_overshoot_distance"] {
        return true.
    }
    return false.
}

function terminal_route_change_phase {
    parameter route, new_phase.
    set route["phase"] to new_phase.
    set route["last_phase_change_time"] to time:seconds.
    set route["closest_target_distance"] to 999999999.
}

// This is intentionally a single-sample check. The normal LandingGate has
// already held the approach stable for its configured time before this is
// called; this check decides whether to commit to landing or fly the go-around.
function terminal_route_landing_commit_check {
    parameter route.
    local config_TR is AVES["TerminalRoute"].
    local commit_gate is config_TR["LandingCommit"].
    local geometry is route["geometry"].
    local glideslope_altitude is calculate_glideslope_alt(geometry["distance"]).
    local glideslope_error is ship:altitude - glideslope_altitude.
    local stable is abs(geometry["cross_track"]) <= commit_gate["maximum_cross_track"] and
        abs(geometry["heading_error"]) <= commit_gate["maximum_heading_error"] and
        abs(glideslope_error) <= commit_gate["maximum_glideslope_error"] and
        ship:verticalspeed >= commit_gate["minimum_vertical_speed"] and
        ship:verticalspeed <= commit_gate["maximum_vertical_speed"] and
        ship:airspeed >= commit_gate["minimum_speed"] and
        ship:airspeed <= commit_gate["maximum_speed"] and
        abs(roll_for()) <= commit_gate["maximum_bank"] and
        geometry["along_track"] > commit_gate["minimum_along_track"].
    return lex("stable",stable,"glideslope_error",glideslope_error).
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
    local geometry_config is config_TR["Geometry"].
    local arrival_geometry is terminal_route_geometry().
    local final_distance is geometry_config["wide_final_distance"].
    // Blend continuously between a straight-in setup and the full-width
    // circuit.  The cosine curve gives 0%, 50%, and 100% lateral offset at
    // heading errors of 0, 90, and 180 degrees respectively, while keeping
    // the change gentle near both endpoints.  Freeze the result at route
    // initialization so the waypoint cannot move inward while it is chased.
    local alignment_error is abs(arrival_geometry["heading_error"]).
    local alignment_factor is (1 - cos(alignment_error)) / 2.
    local base_offset is geometry_config["wide_base_offset"] * alignment_factor.
    local downwind_extension is geometry_config["wide_downwind_extension"].
    local hold_radius is config_TR["hold_radius"].

    local final_fix is get_geoposition_along_heading(runway_start, runway_heading + 180, final_distance).
    local left_base is get_geoposition_along_heading(final_fix, runway_heading - 90, base_offset).
    local right_base is get_geoposition_along_heading(final_fix, runway_heading + 90, base_offset).
    local middle_downwind is get_geoposition_along_heading(final_fix, runway_heading + 180, downwind_extension).
    local left_downwind is get_geoposition_along_heading(middle_downwind, runway_heading - 90, base_offset*30).
    local right_downwind is get_geoposition_along_heading(middle_downwind, runway_heading + 90 , base_offset*30).

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
        "phase", "reposition",
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
        "geometry", arrival_geometry,
        "closest_target_distance", 999999999,
        "landing_stable_since", -1,
        "go_around_count", 0,
        "go_around_reason", "",
        "last_phase_change_time", time:seconds
    ).

    // A well positioned arrival may join final directly.  All other arrival
    // orientations get a deliberately wide downwind/base/final setup.
    if arrival_geometry["along_track"] > geometry_config["direct_final_min_along_track"] and
       abs(arrival_geometry["cross_track"]) < geometry_config["direct_final_cross_track"] and
       abs(arrival_geometry["heading_error"]) < geometry_config["direct_final_heading_error"] {
        set route["phase"] to "final".
    }

    // Low-energy arrivals still enter through reposition and the circuit.
    // Skipping directly to base can demand an infeasible high-speed intercept
    // before the craft has established a usable approach geometry.
    set terminal_route_debug["active"] to true.
    set terminal_route_debug["phase"] to route["phase"].
    set terminal_route_debug["side"] to route["side"].
    return route.
}

function terminal_route_current_target {
    parameter route.
    local config_TR is AVES["TerminalRoute"].
    if route["phase"] = "reposition" or route["phase"] = "go_around" {
        return route["downwind_fix"].
    }
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
    local lead_distance is 0.
    if abs(normalized_heading_error(heading_to_target(runway_start),runway_heading)) < 3 {
        set lead_distance to distance * (config_TR["final_lead_fraction"] * 0.5).
    }else{
        set lead_distance to distance * config_TR["final_lead_fraction"].
    }
    set lead_distance to max(0,min(min(lead_distance,config_TR["final_lead_max"]),distance - config_TR["Geometry"]["final_target_lookahead"])).
    return get_geoposition_along_heading(runway_start, runway_heading + 180, lead_distance).
}

function terminal_route_remaining_distance {
    parameter route.
    local target is terminal_route_current_target(route).
    local distance is calcdistance_m(ship:geoposition, target).
    local final_distance is calcdistance_m(route["final_fix"], runway_start).
    local base_distance is calcdistance_m(route["base_fix"], route["final_fix"]).
    local downwind_distance is calcdistance_m(route["downwind_fix"], route["base_fix"]).

    if route["phase"] = "reposition" or route["phase"] = "go_around" {
        return distance + downwind_distance + base_distance + final_distance.
    }
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

    if defined abort_state and abort_state:haskey("active") and abort_state["active"] {
        set abort_state to abort_refresh_state(abort_state).
        if abort_state["mode"] = "contingency_abort" {
            abort_set_fuel_dump(false).
        }else{
            abort_set_fuel_dump(abort_state["policy"]["fuel_dump"] and ship:mass > abort_state["policy"]["target_mass"]).
        }
    }
    local target is terminal_route_current_target(route).
    local target_distance is calcdistance_m(ship:geoposition, target).
    local remaining_distance is terminal_route_remaining_distance(route).
    local profile_altitude is calculate_glideslope_alt(remaining_distance).
    local body_gravity is ship:body:mu / (ship:body:radius ^ 2).
    local target_energy is profile_altitude - runway_altitude + (config_TR["target_speed"] ^ 2) / (2 * body_gravity).
    local energy_margin is terminal_route_energy_height() - target_energy.

    local target_altitude is profile_altitude.
    local speed is max(ship:airspeed, config_TR["time_to_go_min_speed"]).
    if route["phase"] = "intercept" or route["phase"] = "hold" or route["phase"] = "reposition" or route["phase"] = "go_around" {
        local hold_time is max(remaining_distance / speed, config_TR["time_to_go_min"]).
        local descent_time is min(hold_time, config_TR["hold_descent_time_limit"]).
        local descent_target is ship:altitude - config_TR["hold_descent_rate"] * descent_time.
        set target_altitude to min(profile_altitude - config_TR["early_descent_margin"], descent_target).
        set target_altitude to max(target_altitude, runway_altitude + 500).
    } else if route["phase"] = "downwind" or route["phase"] = "base" {
        local downwind_time is max(remaining_distance / speed, config_TR["time_to_go_min"]).
        local descent_target is ship:altitude - config_TR["downwind_descent_rate"] * min(downwind_time, config_TR["downwind_descent_time_limit"]).
        set target_altitude to min(profile_altitude - config_TR["early_descent_margin"], descent_target).
        set target_altitude to max(target_altitude, runway_altitude + 300).
    } else if route["phase"] = "final" {
        local final_time is max(remaining_distance / speed, config_TR["final_time_to_go_min"]).
        local descent_target is ship:altitude - config_TR["final_descent_rate"] * min(final_time, config_TR["final_descent_time_limit"]).
        set target_altitude to min(profile_altitude, descent_target).
        set target_altitude to max(target_altitude, runway_altitude + 100).
    }
    if route["phase"] = "go_around" {
        set target_altitude to max(target_altitude,runway_altitude + config_TR["GoAround"]["target_altitude"]).
    }

    set route["remaining_distance"] to remaining_distance.
    set route["target_altitude"] to target_altitude.
    set route["energy_margin"] to energy_margin.

    local phase_elapsed is time:seconds - route["last_phase_change_time"].
    local captured_target is terminal_route_waypoint_captured(route,target_distance).
    local geometry is terminal_route_geometry().
    set route["geometry"] to geometry.

    if route["phase"] = "reposition" {
        if captured_target {
            terminal_route_change_phase(route,"base").
        }
    } else if route["phase"] = "go_around" {
        // Do not start the turn back toward the circuit until the descent has
        // been arrested and the craft has positive terrain clearance.  The
        // target remains the downwind fix, but terminal_route_fly holds wings
        // level during this climb-out.
        if geometry["altitude"] >= config_TR["GoAround"]["turn_altitude"] and captured_target {
            terminal_route_change_phase(route,"base").
        }
    } else if route["phase"] = "intercept" {
        // A low-energy craft must not spend more time intercepting a hold
        // point.  Go directly to the downwind leg and preserve its energy.
        if energy_margin < -config_TR["low_energy_margin"] {
            terminal_route_change_phase(route,"downwind").
        } else if phase_elapsed > config_TR["phase_change_delay"] and target_distance < config_TR["intercept_hold_distance"] {
            set route["phase"] to "hold".
            set route["hold_index"] to 1.
            set route["last_phase_change_time"] to time:seconds.
            set route["closest_target_distance"] to 999999999.
        }
    } else if route["phase"] = "hold" {
        // A low-energy aircraft leaves the hold immediately.  A high-energy
        // aircraft completes as many full circuits as necessary before exit.
        if energy_margin < -config_TR["low_energy_margin"] {
            terminal_route_change_phase(route,"downwind").
        } else if phase_elapsed > config_TR["phase_change_delay"] and target_distance < config_TR["intercept_hold_distance"] {
            set route["hold_index"] to route["hold_index"] + 1.
            if route["hold_index"] > 3 {
                set route["hold_index"] to 0.
                set route["hold_laps"] to route["hold_laps"] + 1.
                if energy_margin < config_TR["hold_exit_energy"] {
                    terminal_route_change_phase(route,"downwind").
                }
            }
        }
    } else if route["phase"] = "downwind" and phase_elapsed > config_TR["phase_change_delay"] and captured_target {
        terminal_route_change_phase(route,"base").
    } else if route["phase"] = "base" and phase_elapsed > config_TR["phase_change_delay"] and captured_target {
        terminal_route_change_phase(route,"final").
    }

    local go_around_config is config_TR["GoAround"].
    local unstable_final is abs(geometry["heading_error"]) > go_around_config["maximum_heading_error"] or
        abs(geometry["cross_track"]) > go_around_config["maximum_cross_track"] or
        geometry["along_track"] < go_around_config["passed_threshold"].
    if route["phase"] = "final" and go_around_config["enabled"] and geometry["distance"] < go_around_config["decision_distance"] and
       geometry["altitude"] > go_around_config["minimum_altitude"] and unstable_final and
       energy_margin > go_around_config["minimum_reposition_energy"] {
        set route["go_around_count"] to route["go_around_count"] + 1.
        set route["go_around_reason"] to "unstable_final".
        terminal_route_change_phase(route,"go_around").
    }

    // Do not re-enter intercept from downwind/base during the terminal phase.
    // This avoids oscillation and keeps the approach stable once the pattern
    // has already committed to downwind or base.
    local direct_distance is geometry["distance"].
    local landing_gate is config_TR["LandingGate"].
    // Thrust and brakes must represent opposite energy states.  In
    // particular, do not use airbrakes merely because speed crosses a target:
    // that previously caused brake/throttle chatter around 140 m/s.
    local low_energy is energy_margin < -config_TR["low_energy_margin"].
    local low_speed is ship:airspeed < config_TR["Propulsion"]["throttle_speed"].
    set route["airbrake"] to route["phase"] <> "go_around" and energy_margin > config_TR["brake_energy"] and not low_energy and not low_speed.
    set route["gear"] to direct_distance < landing_gate["gear_distance"] and geometry["altitude"] < landing_gate["gear_altitude"].
    local landing_stable is route["phase"] = "final" and direct_distance < landing_gate["distance"] and
        geometry["altitude"] < landing_gate["altitude"] and geometry["along_track"] > landing_gate["minimum_along_track"] and
        abs(geometry["heading_error"]) < landing_gate["heading_error"] and abs(geometry["cross_track"]) < landing_gate["cross_track"] and
        ship:airspeed > landing_gate["minimum_speed"] and ship:airspeed < landing_gate["maximum_speed"].
    if landing_stable {
        if route["landing_stable_since"] < 0 { set route["landing_stable_since"] to time:seconds. }
    }else{
        set route["landing_stable_since"] to -1.
    }
    set route["landing_ready"] to landing_stable and time:seconds - route["landing_stable_since"] >= landing_gate["stable_time"].

    set terminal_route_debug["active"] to true.
    set terminal_route_debug["phase"] to route["phase"].
    set terminal_route_debug["side"] to route["side"].
    local target_location is "unknown".
    local target_runway is "unknown".
    if defined Location { set target_location to Location. }
    if defined runway_nr { set target_runway to runway_nr. }
    set terminal_route_debug["target_location"] to target_location.
    set terminal_route_debug["target_runway"] to target_runway.
    set terminal_route_debug["hold_laps"] to route["hold_laps"].
    set terminal_route_debug["target_distance"] to target_distance.
    set terminal_route_debug["remaining_distance"] to remaining_distance.
    set terminal_route_debug["target_altitude"] to target_altitude.
    set terminal_route_debug["energy_margin"] to energy_margin.
    set terminal_route_debug["target_energy"] to target_energy.
    set terminal_route_debug["airbrake"] to route["airbrake"].
    set terminal_route_debug["gear"] to route["gear"].
    set terminal_route_debug["along_track"] to geometry["along_track"].
    set terminal_route_debug["cross_track"] to geometry["cross_track"].
    set terminal_route_debug["runway_heading_error"] to geometry["heading_error"].
    set terminal_route_debug["landing_stable"] to landing_stable.
    set terminal_route_debug["go_around_reason"] to route["go_around_reason"].
    return route.
}

function terminal_route_fly {
    parameter route.
    local config_TR is AVES["TerminalRoute"].
    local target is terminal_route_current_target(route).
    local distance is route["remaining_distance"].
    local time_to_go is max(distance / max(ship:airspeed, config_TR["time_to_go_min_speed"]), config_TR["time_to_go_min"]).
    local desired_vertical_speed is 0.
    local pid_log is "none".
    if route["phase"] = "final" {
        local final_vs_dist is distance * config_TR["final_vs_distance_factor"].
        local alt_tgt is calculate_glideslope_alt(final_vs_dist).
        set desired_vertical_speed to calc_vvdot(final_vs_dist, ship:airspeed, alt_tgt, ship:altitude).
    } else {
        set desired_vertical_speed to (route["target_altitude"] - ship:altitude) / time_to_go.
    }

    if route["phase"] = "intercept" or route["phase"] = "hold" or route["phase"] = "reposition" {
        // Bleed excess energy in a controlled descent rather than trying to
        // climb onto the glideslope calculated from the entire holding route.
        set desired_vertical_speed to min(desired_vertical_speed, -config_TR["hold_descent_rate"]).
    }else if route["phase"] = "go_around" {
        set desired_vertical_speed to max(desired_vertical_speed,config_TR["GoAround"]["target_climb_rate"]).
    }

    local pitch_bias is 0.
    if route["phase"] = "final" {
        if not (defined final_pitch_bias_pid){
            set final_pitch_bias_pid to pidloop(config_TR["final_pitch_pid_p"],config_TR["final_pitch_pid_i"],config_TR["final_pitch_pid_d"]).
            set final_pitch_bias_pid:maxoutput to config_TR["final_pitch_pid_max"].
            set final_pitch_bias_pid:minoutput to config_TR["final_pitch_pid_min"].
        }
        set final_pitch_bias_pid:setpoint to desired_vertical_speed.
        set pitch_bias to final_pitch_bias_pid:update(time:seconds, ship:verticalspeed).
        set pid_log to pitch_bias.
    } else {
        set pitch_bias to max(config_TR["pitch_bias_min"], min(config_TR["pitch_bias_max"], (desired_vertical_speed - ship:verticalspeed) * config_TR["pitch_bias_gain"])).
    }
    local target_aoa is config_TR["nominal_target_aoa"].
    local max_energy_aoa is config_TR["max_energy_aoa"].
    local descent_min_aoa is config_TR["descent_min_aoa"].
    local descent_aoa_max is config_TR["descent_aoa_max"].
    if route["phase"] = "base" {
        set max_energy_aoa to config_TR["base_aoa_max"].
        set descent_min_aoa to config_TR["base_aoa_min"].
        set descent_aoa_max to config_TR["base_aoa_max"].
    }
    if route["phase"] = "intercept" or route["phase"] = "hold" {
        set max_energy_aoa to config_TR["hold_aoa_max"].
    }

    if route["energy_margin"] > config_TR["high_energy_threshold"] {
        set target_aoa to min(max_energy_aoa, config_TR["nominal_target_aoa"] + route["energy_margin"] / config_TR["energy_aoa_gain_denominator"]).
    }
    if route["energy_margin"] < -config_TR["low_energy_margin"] {
        set target_aoa to descent_min_aoa.
    }

    // Glide whenever possible.  Use engine power only to protect the 120 m/s
    // speed floor or recover a genuine low-energy state; that makes it
    // mutually exclusive with the high-energy airbrake state.
    local propulsion_config is config_TR["Propulsion"].
    local energy_throttle is 0.
    local speed_throttle is 0.
    if route["energy_margin"] < -config_TR["low_energy_margin"] {
        local energy_deficit is -route["energy_margin"] - config_TR["low_energy_margin"].
        set energy_throttle to energy_deficit / max(propulsion_config["full_assist_energy_deficit"],1).
    }
    if ship:airspeed < propulsion_config["throttle_speed"] {
        set speed_throttle to (propulsion_config["throttle_speed"] - ship:airspeed) * propulsion_config["speed_assist_gain"].
    }
    set dapthrottle to min(propulsion_config["maximum_throttle"],max(energy_throttle,speed_throttle)).
    if dapthrottle > 0 {
        rapierson().
        togglerapiermode("air").
        if defined abort_state and abort_state:haskey("policy") and abort_state["policy"]["use_nervs"] { nervson(). }
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
            set target_aoa to min(target_aoa, descent_aoa_max).
            set target_aoa to max(descent_min_aoa, target_aoa + descent_error * config_TR["descent_aoa_gain"]).
        }
    }
    // Restore the original final handoff: aerostr takes over once the bearing
    // to the threshold matches the runway heading.  Do not add a cross-track
    // or actual-prograde gate here; aerostr is responsible for the small
    // corrections that finish the alignment.
    local aerostr_final is route["phase"] = "final" and
        abs(heading_to_target(runway_start) - runway_heading) < config_TR["final_alignment_heading_tolerance"] and
        abs(compass_for_prograde()-heading_to_target(runway_start))<config_TR["final_alignment_heading_tolerance"] * 5.
    local go_around_climbout is route["phase"] = "go_around" and route["geometry"]["altitude"] < config_TR["GoAround"]["turn_altitude"].
    if go_around_climbout {
        // Wings level while the commanded climb takes effect.  Turning at low
        // altitude was allowing the route to keep descending toward terrain.
        set dap["str_mode"] to "aoa".
        set dap["aoa"]["target_aoa"] to max(target_aoa,config_TR["GoAround"]["climb_aoa"]).
        set dap["aoa"]["target_bank"] to 0.
    } else if not(aerostr_final) {
        set dap["str_mode"] to "aoa".
        
        set dap["aoa"]["target_aoa"] to target_aoa.
        set dap["aoa"]["target_bank"] to terminal_route_bank_command(heading_to_target(target), config_TR).

    }else{
        set dap["str_mode"] to "aerostr".
        local desired_heading is heading_to_target(target).
        local hed_error is normalized_heading_error(desired_heading,compass_for_prograde()).
        set dap["aerostr"]["turn_heading"] to desired_heading + hed_error * config_TR["final_heading_correction"].
        //if dap["aerostr"]["turn_heading"] > compass_for_prograde() + 2{
        //    set dap["aerostr"]["aerostr_Roll"] to 10.
        //}else if dap["aerostr"]["turn_heading"] < compass_for_prograde() - 2{
        //    set dap["aerostr"]["aerostr_Roll"] to -10.
        //}else{
            set dap["aerostr"]["aerostr_Roll"] to 0.
        //}
        set dap["aerostr"]["distance_pitch"] to pitch_bias.

    }

    // aoa_bank_management treats a nonzero base_pitch as an absolute pitch
    // baseline, replacing pitch_for_prograde().  Terminal-route pitch_bias is
    // therefore passed directly in every AoA phase; adding prograde here
    // would double-count the baseline and make the DAP command disagree with
    // the displayed bias.
    if route["phase"] ="final"{
        set dap["aoa"]["base_pitch"] to pitch_bias.
        set dap["aoa"]["target_aoa"] to target_aoa + config_TR["final_aoa_offset"].
    }else{
        set dap["aoa"]["base_pitch"] to pitch_bias.
    }
    set terminal_route_debug["desired_vertical_speed"] to desired_vertical_speed.
    set terminal_route_debug["pitch_bias"] to pitch_bias.
    set terminal_route_debug["target_aoa"] to target_aoa.
    set terminal_route_debug["throttle"] to dapthrottle.
    set terminal_route_debug["Pid_log"] to pid_log.

    // pos_arrow's length is the height above the surface waypoint.  Clearing
    // before each redraw guarantees one current marker at the target altitude.
    if terminal_route_target_arrow_enabled {
        clearVecDraws().
        pos_arrow(target,"TR " + route["phase"],route["target_altitude"],0.1).
        set terminal_route_target_arrow_active to true.
    } else if terminal_route_target_arrow_active {
        clearVecDraws().
        set terminal_route_target_arrow_active to false.
    }

    // Log at 2 Hz so a complete approach is inspectable without flooding the volume.
    if time:seconds - terminal_route_debug["last_log_time"] >= config_TR["debug_log_interval"] {
        if POS_LOGGING_ENABLED { log "TR phase=" + terminal_route_debug["phase"] + " side=" + terminal_route_debug["side"] + " laps=" + terminal_route_debug["hold_laps"] + " target_dist=" + round(terminal_route_debug["target_distance"],1) + " remain=" + round(terminal_route_debug["remaining_distance"],1) + " alt=" + round(ship:altitude,1) + " target_alt=" + round(terminal_route_debug["target_altitude"],1) + " vs=" + round(ship:verticalspeed,1) + " desired_vs=" + round(desired_vertical_speed,1) + " bias=" + round(pitch_bias,1) + " energy_margin=" + round(terminal_route_debug["energy_margin"],1) + " target_energy=" + round(terminal_route_debug["target_energy"],1) + " aoa=" + round(target_aoa,1) + " bank=" + round(dap["aoa"]["target_bank"],1) + " throttle=" + round(dapthrottle,2) + " brake=" + terminal_route_debug["airbrake"] + " gear=" + terminal_route_debug["gear"] + " pid_log=" + pid_log to "terminal_route.log". }
        set terminal_route_debug["last_log_time"] to time:seconds.
    }
    set Lastest_status to "terminal " + route["phase"] + " | energy " + round(route["energy_margin"]) + "m | loop " + route["hold_laps"].
}
