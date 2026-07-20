// Terminal-area route and energy manager for Poseidon.
//
// The planner deliberately separates energy management from final approach:
// a rectangular holding pattern absorbs excess energy, while the downwind,
// base, and final legs establish a repeatable localizer and glide-slope
// intercept from any arrival direction.

function terminal_route_energy_height {
    // Specific kinetic energy expressed as an equivalent altitude in metres.
    return ship:altitude - runway_altitude + (ship:airspeed ^ 2) / (2 * 9.81).
}

function terminal_route_init {
    local config is AVES["TerminalRoute"].
    local final_distance is config["final_distance"].
    local base_offset is config["base_offset"].
    local downwind_extension is config["downwind_extension"].
    local hold_radius is config["hold_radius"].

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
        "landing_ready", false
    ).

    // If the entry guidance has already removed most of the energy, do not
    // make an unnecessary detour through the holding pattern.
    local direct_distance is calcdistance_m(ship:geoposition, downwind_fix) +
        calcdistance_m(downwind_fix, base_fix) +
        calcdistance_m(base_fix, final_fix) + final_distance.
    local direct_target_energy is calculate_glideslope_alt(direct_distance) - runway_altitude + (config["target_speed"] ^ 2) / (2 * 9.81).
    if terminal_route_energy_height() < direct_target_energy - config["low_energy_margin"] {
        set route["phase"] to "downwind".
    }
    return route.
}

function terminal_route_current_target {
    parameter route.
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
    // shortens as the craft closes, which captures the localizer without a
    // late, abrupt turn toward the runway threshold.
    local distance is calcdistance_m(ship:geoposition, runway_start).
    local lead_distance is min(1500, max(300, distance * 0.45)).
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
    local config is AVES["TerminalRoute"].

    local target is terminal_route_current_target(route).
    local target_distance is calcdistance_m(ship:geoposition, target).
    local remaining_distance is terminal_route_remaining_distance(route).
    local target_altitude is calculate_glideslope_alt(remaining_distance).
    local target_energy is target_altitude - runway_altitude + (config["target_speed"] ^ 2) / (2 * 9.81).
    local energy_margin is terminal_route_energy_height() - target_energy.

    set route["remaining_distance"] to remaining_distance.
    set route["target_altitude"] to target_altitude.
    set route["energy_margin"] to energy_margin.

    if route["phase"] = "intercept" and target_distance < 900 {
        set route["phase"] to "hold".
        set route["hold_index"] to 1.
    } else if route["phase"] = "hold" {
        // A low-energy aircraft leaves the hold immediately.  A high-energy
        // aircraft completes as many full circuits as necessary before exit.
        if energy_margin < -config["low_energy_margin"] {
            set route["phase"] to "downwind".
        } else if target_distance < 900 {
            set route["hold_index"] to route["hold_index"] + 1.
            if route["hold_index"] > 3 {
                set route["hold_index"] to 0.
                set route["hold_laps"] to route["hold_laps"] + 1.
                if energy_margin < config["hold_exit_energy"] {
                    set route["phase"] to "downwind".
                }
            }
        }
    } else if route["phase"] = "downwind" and target_distance < 1100 {
        set route["phase"] to "base".
    } else if route["phase"] = "base" and target_distance < 1000 {
        set route["phase"] to "final".
    }

    // If a late energy estimate shows that the planned pattern was too short,
    // safely return to the holding box while there is still room to do so.
    if (route["phase"] = "downwind" or route["phase"] = "base") and energy_margin > config["rehold_energy"] and ship:altitude - runway_altitude > 1800 {
        set route["phase"] to "intercept".
        set route["hold_index"] to 0.
    }

    local direct_distance is calcdistance_m(ship:geoposition, runway_start).
    set route["airbrake"] to energy_margin > config["brake_energy"] or (route["phase"] = "final" and ship:airspeed > config["final_brake_speed"] and ship:altitude - runway_altitude > 100).
    set route["gear"] to direct_distance < 2200 and ship:altitude - runway_altitude < 180.
    set route["landing_ready"] to route["phase"] = "final" and direct_distance < 1400 and ship:altitude - runway_altitude < 110.
    return route.
}

function terminal_route_fly {
    parameter route.
    local config is AVES["TerminalRoute"].
    local target is terminal_route_current_target(route).
    local distance is route["remaining_distance"].
    local time_to_go is max(distance / max(ship:airspeed, 80), 5).
    local desired_vertical_speed is (route["target_altitude"] - ship:altitude) / time_to_go.
    local pitch_bias is max(-12, min(15, (desired_vertical_speed - ship:verticalspeed) * 0.35)).
    local target_aoa is 16.

    if route["energy_margin"] > 300 {
        set target_aoa to min(30, 16 + route["energy_margin"] / 120).
    }
    if route["energy_margin"] < -config["low_energy_margin"] {
        set target_aoa to 10.
        set dapthrottle to 0.25.
    } else if ship:airspeed < config["minimum_speed"] {
        set dapthrottle to 0.2.
    } else {
        set dapthrottle to 0.
    }

    set dap["str_mode"] to "aoa".
    aeroturn(heading_to_target(target), "calc", target_aoa).
    set dap["aoa"]["base_pitch"] to pitch_bias.
    set Lastest_status to "terminal " + route["phase"] + " | energy " + round(route["energy_margin"]) + "m | loop " + route["hold_laps"].
}
