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
    "profile_region", "inactive",
    "profile_altitude", 0,
    "profile_gradient", 0,
    "profile_error", 0,
    "profile_feedforward_vs", 0,
    "profile_pitch_feedforward", 0,
    "pitch_saturated", false,
    "preflare_pullup_active", false,
    "preflare_pullup_fraction", 0,
    "landing_desired_vs", 0,
    "landing_flare_fraction", 0,
    "desired_vertical_speed", 0,
    "pitch_bias", 0,
    "turn_pitch_limit_active", false,
    "turn_pitch_raw_bias", 0,
    "turn_pitch_gs_altitude", 0,
    "turn_pitch_bank", 0,
    "fast_turn_active", false,
    "turn_model_mode", -1,
    "turn_model_rate", 0,
    "turn_model_radius", 0,
    "turn_model_loss", 0,
    "turn_model_required_radius", 0,
    "target_aoa", 0,
    "high_energy_final_active", false,
    "high_energy_desired_vs", 0,
    "high_energy_pitch_command", 0,
    "high_energy_pid_output", 0,
    "high_energy_time_to_aim", 0,
    "handoff_blend_active", false,
    "handoff_blend_elapsed", 0,
    "handoff_raw_target_aoa", 0,
    "handoff_raw_target_bank", 0,
    "energy_margin", 0,
    "target_energy", 0,
    "energy_capture", 0,
    "energy_drag_work", 0,
    "energy_turn_work", 0,
    "energy_reserve", 0,
    "energy_turn_extra_distance", 0,
    "energy_turn_reserve", 0,
    "energy_clean_loss", 0,
    "energy_margin_rate", 0,
    "energy_brake_margin", 0,

    "airbrake", false,
    "brake_mode", "inactive",
    "brake_reason", "inactive",
    "gear", false,
    "throttle", 0,
    "Pid_log", "none",
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
// The GUI only queues a request.  The reentry loop applies it between route
// updates, so every runway-dependent value changes together.
if not(defined terminal_route_runway_change_request) {
    global terminal_route_runway_change_request is "".
}

function terminal_route_available_runways {
    parameter location_name.
    local available is list().
    local runway_prefix is location_name + "_runway_".
    local runways is Location_constants["kerbin"].
    for key in runways:keys {
        if key:contains(runway_prefix) and key:endswith("_start") {
            local parts is key:split("_").
            if parts:length >= 3 {
                available:add(parts[2]).
            }
        }
    }
    return available.
}

// Changing runway direction late in the approach can require a turn through
// the touchdown area.  Keep the choice available early in TEAM, then make it
// irrevocable on final or inside the configured terminal envelope.
function terminal_route_runway_change_allowed {
    parameter route.
    local change_config is AVES["TerminalRoute"]["RunwayChange"].
    local geometry is terminal_route_geometry().
    if route["phase"] = "final" or route["phase"] = "go_around" {
        return false.
    }
    if geometry["distance"] <= change_config["lock_distance"] or
       geometry["altitude"] <= change_config["lock_altitude"] {
        return false.
    }
    return true.
}

function terminal_route_change_runway {
    parameter runway_number.
    if not(defined Location) or not Location_constants:haskey("kerbin") {
        return lex("success",false,"message","Runway change unavailable: landing location is not set").
    }
    if runway_number = runway_nr {
        return lex("success",false,"message","Runway " + runway_number + " is already selected").
    }

    local start_key is Location + "_runway_" + runway_number + "_start".
    local end_key is Location + "_runway_" + runway_number + "_end".
    local altitude_key is Location + "_runway".
    local runways is Location_constants["kerbin"].
    if not runways:haskey(start_key) or not runways:haskey(end_key) or not KerbinRunwayalt:haskey(altitude_key) {
        return lex("success",false,"message","Runway " + runway_number + " is not available at " + Location).
    }

    set runway_nr to runway_number.
    set runway_start to runways[start_key].
    set runway_end to runways[end_key].
    set runway_altitude to KerbinRunwayalt[altitude_key].
    set runway_heading to heading_between(runway_start,runway_end).
    set reentry_target to runway_start.
    if ADDONS:TR:available {
        ADDONS:TR:SETTARGET(runway_start).
        ADDONS:TR:RESETDESCENTPROFILE(20).
    }
    flight_log_set_runway(Location,runway_nr,runway_start,runway_end,runway_heading,runway_altitude).
    return lex("success",true,"message","Runway changed to " + Location + " runway " + runway_nr).
}

// Pure switching laws: keep logging and vessel access in the flight callers.
function approach_brake_band {
    parameter prior_brake, measured_speed, engage_speed, release_speed.
    if measured_speed > engage_speed { return true. }
    if measured_speed <= release_speed { return false. }
    return prior_brake.
}

function terminal_speed_control_active {
    parameter route_phase, route_distance, speed_config.
    return route_phase = "final" and route_distance <= speed_config["activation_distance"].
}

function terminal_brake_decision {
    parameter prior_brake, route_phase, speed_active, measured_speed, energy_error, config_TR, predicted_margin is 999999999.
    local brake_mode is "energy".
    local brake_reason is "energy_band".
    if predicted_margin = 999999999 { set predicted_margin to energy_error. }
    local brake_command is predicted_margin > config_TR["brake_energy"].
    if prior_brake { set brake_command to predicted_margin > config_TR["EnergyPlan"]["brake_release_margin"]. }
    if speed_active {
        set brake_mode to "approach_speed".
        set brake_reason to "speed_band".
        set brake_command to approach_brake_band(prior_brake,measured_speed,
            config_TR["ApproachSpeed"]["brake_on_speed"],config_TR["ApproachSpeed"]["brake_off_speed"]).
    }
    if predicted_margin <= 0 {
        set brake_command to false.
        set brake_reason to "route_reserve".
    }
    if energy_error < -config_TR["low_energy_margin"] {
        set brake_command to false.
        set brake_reason to "low_energy".
    }
    if measured_speed < config_TR["Propulsion"]["throttle_speed"] {
        set brake_command to false.
        set brake_reason to "low_speed".
    }
    if route_phase = "go_around" {
        set brake_command to false.
        set brake_reason to "go_around".
    }
    return lex("command",brake_command,"mode",brake_mode,"reason",brake_reason).
}

function landing_brake_decision {
    parameter prior_brake, measured_speed, on_ground, runway_height, landing_config.
    // Preserve wheel braking through low-altitude contact and bounce.
    if on_ground or runway_height <= landing_config["wheel_brake_altitude"] { return true. }
    return approach_brake_band(prior_brake,measured_speed,
        landing_config["brake_on_speed"],landing_config["brake_off_speed"]).
}

// Energy-height work budget. Clean loss is energy-height loss per horizontal
// metre (approximately D/(mg) in a shallow glide). Circuit legs pay drag
// work instead of extending the steep landing slope around the whole route.
function terminal_energy_budget {
    parameter route_distance, final_leg_distance, capture_height, reference_speed,
        gravity_value, clean_loss, turn_allowance, energy_config.
    local cruise_distance is max(0,route_distance-final_leg_distance).
    local capture_energy is capture_height + reference_speed^2/(2*gravity_value).
    local drag_work is cruise_distance*clean_loss.
    return lex("required",capture_energy+drag_work+turn_allowance,
        "capture",capture_energy,"drag_work",drag_work,"turn_work",turn_allowance,
        "reserve",cruise_distance*energy_config["loss_uncertainty"]).
}

function terminal_energy_turn_work {
    parameter heading_change, planning_speed, gravity_value, clean_loss, energy_config.
    local turn_angle is min(180,abs(heading_change)).
    local radians_value is turn_angle*constant:degtorad.
    local turn_bank is energy_config["planning_bank"].
    local turn_radius is planning_speed^2/(gravity_value*tan(turn_bank)).
    // The waypoint polyline already pays for straight distance through each
    // corner. Add only bank-induced drag, not another full turn arc: rounded
    // corners can cut inside that polyline. Turn speed is the planned circuit
    // speed; entry-speed dissipation is handled by the measured margin trend.
    return clean_loss*turn_radius*energy_config["induced_drag_fraction"]*
        tan(turn_bank)^2*radians_value.
}

// The FAR grid is reduced offline to rate and drag per tonne. Only altitude
// and speed are interpolated in flight; AoA/bank are nine discrete choices.
function terminal_turn_environment {
    parameter turn_altitude, turn_speed.
    local altitude_index is 0.
    until altitude_index >= TEAM_TURN_ALTITUDES:length-2 or
          turn_altitude <= TEAM_TURN_ALTITUDES[altitude_index+1] {
        set altitude_index to altitude_index+1.
    }
    local speed_index is 0.
    until speed_index >= TEAM_TURN_SPEEDS:length-2 or
          turn_speed <= TEAM_TURN_SPEEDS[speed_index+1] {
        set speed_index to speed_index+1.
    }
    local altitude_fraction is max(0,min(1,
        (turn_altitude-TEAM_TURN_ALTITUDES[altitude_index])/
        (TEAM_TURN_ALTITUDES[altitude_index+1]-TEAM_TURN_ALTITUDES[altitude_index]))).
    local speed_fraction is max(0,min(1,
        (turn_speed-TEAM_TURN_SPEEDS[speed_index])/
        (TEAM_TURN_SPEEDS[speed_index+1]-TEAM_TURN_SPEEDS[speed_index]))).
    return lex("altitude_index",altitude_index,"speed_index",speed_index,
        "altitude_fraction",altitude_fraction,"speed_fraction",speed_fraction).
}

function terminal_turn_sample {
    parameter environment, turn_mode_index, turn_mass, turn_speed.
    local row_width is TEAM_TURN_SPEEDS:length.
    local cell_index is environment["altitude_index"]*row_width+environment["speed_index"].
    local altitude_fraction is environment["altitude_fraction"].
    local speed_fraction is environment["speed_fraction"].
    local rates is TEAM_TURN_RATE_MASS[turn_mode_index].
    local losses is TEAM_TURN_LOSS_MASS[turn_mode_index].
    local lower_rate is rates[cell_index]+(rates[cell_index+1]-rates[cell_index])*speed_fraction.
    local upper_rate is rates[cell_index+row_width]+
        (rates[cell_index+row_width+1]-rates[cell_index+row_width])*speed_fraction.
    local lower_loss is losses[cell_index]+(losses[cell_index+1]-losses[cell_index])*speed_fraction.
    local upper_loss is losses[cell_index+row_width]+
        (losses[cell_index+row_width+1]-losses[cell_index+row_width])*speed_fraction.
    local turn_rate_value is max(0,(lower_rate+(upper_rate-lower_rate)*altitude_fraction)/max(turn_mass,1)).
    local turn_loss_value is max(0,(lower_loss+(upper_loss-lower_loss)*altitude_fraction)/max(turn_mass,1)).
    local turn_radius_value is min(999999999,max(turn_speed,1)*constant:radTOdeg/max(turn_rate_value,0.0001)).
    return lex("rate",turn_rate_value,"radius",turn_radius_value,"loss",turn_loss_value).
}

// A constant-radius turn reaches a target at range d and bearing error e
// when r is roughly d/(2 sin e). Use a conservative fraction because actual
// bank and AoA take time to settle. Pick the lowest-drag feasible mode; if
// none can turn tightly enough, use the mode with the smallest radius.
function terminal_turn_choice {
    parameter environment, turn_speed, turn_mass, target_distance, heading_error,
        prior_mode, energy_config.
    local angle is min(90,max(1,abs(heading_error))).
    local required_radius is target_distance/(2*sin(angle)) *
        energy_config["turn_radius_safety_fraction"].
    local best_mode is -1.
    local best_cost is 999999999.
    local best_radius is 999999999.
    local best_feasible is false.
    local prior_result is lex("rate",0,"radius",999999999,"loss",999999999).
    local turn_mode_index is 0.
    until turn_mode_index >= TEAM_TURN_RATE_MASS:length {
        local result is terminal_turn_sample(environment,turn_mode_index,turn_mass,turn_speed).
        if turn_mode_index = prior_mode { set prior_result to result. }
        if result["rate"] > 0.01 {
            local feasible is result["radius"] <= required_radius.
            local cost is result["loss"]+
                0.03*max(0,1-result["radius"]/max(required_radius,1)).
            if feasible and (not best_feasible or cost < best_cost) {
                set best_mode to turn_mode_index.
                set best_cost to cost.
                set best_radius to result["radius"].
                set best_feasible to true.
            } else if not best_feasible and result["radius"] < best_radius {
                set best_mode to turn_mode_index.
                set best_cost to cost.
                set best_radius to result["radius"].
            }
        }
        set turn_mode_index to turn_mode_index+1.
    }
    // Avoid switching between adjacent AoA/bank modes on small sample noise.
    if prior_mode >= 0 and prior_result["rate"] > 0.01 {
        if best_feasible and prior_result["radius"] <= required_radius and
           prior_result["loss"] <= best_cost*1.08 {
            set best_mode to prior_mode.
        } else if not best_feasible and prior_result["radius"] <= best_radius*1.05 {
            set best_mode to prior_mode.
        }
    }
    if best_mode < 0 {
        return lex("valid",false,"mode",-1,"aoa",0,"bank",0,
            "rate",0,"radius",999999999,"loss",0,"required_radius",required_radius).
    }
    local chosen is terminal_turn_sample(environment,best_mode,turn_mass,turn_speed).
    return lex("valid",true,"mode",best_mode,
        "aoa",TEAM_TURN_AOAS[floor(best_mode/TEAM_TURN_BANKS:length)],
        "bank",TEAM_TURN_BANKS[mod(best_mode,TEAM_TURN_BANKS:length)],
        "rate",chosen["rate"],"radius",chosen["radius"],
        "loss",chosen["loss"],"required_radius",required_radius).
}

function terminal_aero_turn_work {
    parameter heading_change, turn_speed, turn_rate, turn_loss, clean_loss,
        energy_config.
    if turn_rate <= 0 { return 0. }
    local arc_distance is min(energy_config["turn_model_max_arc_distance"],
        turn_speed*min(180,abs(heading_change))/turn_rate).
    return min(energy_config["turn_model_max_work"],
        max(0,turn_loss-clean_loss)*arc_distance).
}

// The remaining-route polyline assumes immediate progress toward the next
// waypoint. During a wide turn the aircraft can fly a long arc while that
// distance barely closes. Reserve only the extra arc length beyond the direct
// waypoint distance; planned bank drag is already in turn_work. This reserve
// protects the brake decision, not the nominal engine-assist threshold.
function terminal_energy_current_turn {
    parameter target_distance, heading_error, measured_speed, measured_bank,
        gravity_value, clean_loss, energy_config, calibrated_radius is -1.
    local turn_angle is min(120,abs(heading_error)).
    if target_distance <= 0 or turn_angle <= energy_config["turn_reserve_deadband"] {
        return lex("extra_distance",0,"reserve",0).
    }
    local bank_angle is max(energy_config["planning_bank"],abs(measured_bank)).
    set bank_angle to min(60,bank_angle).
    local turn_radius_value is measured_speed^2/(gravity_value*tan(bank_angle)).
    if calibrated_radius > 0 { set turn_radius_value to calibrated_radius. }
    local radians_value is turn_angle*constant:degtorad.
    // Rotate the local frame toward the target. Target is initially at
    // (distance*sin(angle), distance*cos(angle)); the arc ends at
    // (radius*(1-cos(angle)), radius*sin(angle)).
    local remaining_x is target_distance*sin(turn_angle)-turn_radius_value*(1-cos(turn_angle)).
    local remaining_y is target_distance*cos(turn_angle)-turn_radius_value*sin(turn_angle).
    local arc_distance is turn_radius_value*radians_value.
    local extra_distance is max(0,arc_distance+sqrt(remaining_x^2+remaining_y^2)-target_distance).
    set extra_distance to min(extra_distance,energy_config["turn_reserve_max_distance"]).
    return lex("extra_distance",extra_distance,"reserve",extra_distance*clean_loss).
}

// Keep a large bank turn flyable when the glide slope at the current waypoint
// is above the aircraft. This applies to the ordinary circuit pitch law;
// final and go-around retain their dedicated vertical controllers.
function terminal_turn_pitch_limit {
    parameter raw_bias, commanded_bank, actual_bank, glideslope_altitude,
        actual_altitude, config_TR.
    local turning is max(abs(commanded_bank),abs(actual_bank)) >=
        config_TR["turn_pitch_bank_threshold"].
    local active is turning and glideslope_altitude > actual_altitude.
    local command is raw_bias.
    if active {
        local limit is config_TR["turn_pitch_bias_limit"].
        set command to max(-limit,min(limit,raw_bias)).
    }
    return lex("command",command,"active",active).
}

function terminal_fast_turn_command {
    parameter nominal_bank, measured_speed, glideslope_altitude,
        actual_altitude, config_TR.
    local active is abs(nominal_bank) >= config_TR["fast_turn_min_bank"] and
        measured_speed >= config_TR["fast_turn_min_speed"] and
        glideslope_altitude > actual_altitude.
    local command is nominal_bank.
    if active {
        set command to nominal_bank*config_TR["fast_turn_bank_max"]/
            max(config_TR["bank_max"],1).
        set command to max(-config_TR["fast_turn_bank_max"],
            min(config_TR["fast_turn_bank_max"],command)).
    }
    return lex("command",command,"active",active).
}

function terminal_energy_throttle {
    parameter energy_margin, measured_speed, config_TR.
    local propulsion_config is config_TR["Propulsion"].
    local energy_request is max(0,(-energy_margin-config_TR["low_energy_margin"])/
        max(propulsion_config["full_assist_energy_deficit"],1)).
    local speed_request is max(0,(propulsion_config["throttle_speed"]-measured_speed)*propulsion_config["speed_assist_gain"]).
    return lex("energy",energy_request,"speed",speed_request,
        "command",min(propulsion_config["maximum_throttle"],max(energy_request,speed_request))).
}

function terminal_energy_loss_filter {
    parameter previous_loss, energy_change, travelled_distance, elapsed, eligible, energy_config.
    if not eligible or travelled_distance <= 0 or elapsed <= 0 { return previous_loss. }
    local observed_loss is -energy_change/travelled_distance.
    if observed_loss < energy_config["minimum_loss"] or observed_loss > energy_config["maximum_loss"] {
        return previous_loss.
    }
    local weight is elapsed/(energy_config["learning_time"]+elapsed).
    return previous_loss+(observed_loss-previous_loss)*weight.
}

function terminal_energy_brake_margin {
    parameter energy_margin, reserve_height, margin_rate, energy_config.
    return energy_margin-reserve_height+min(0,margin_rate)*energy_config["brake_lookahead"].
}

function terminal_route_energy_plan {
    parameter route, reference_speed.
    local config_TR is AVES["TerminalRoute"].
    local energy_config is config_TR["EnergyPlan"].
    local gravity_value is ship:body:mu/(ship:body:radius^2).
    local route_distance is terminal_route_remaining_distance(route).
    local final_leg_distance is calcdistance_m(route["final_fix"],runway_start).
    if route["phase"] = "final" { set final_leg_distance to route_distance. }
    local capture_profile is calculate_glideslope_profile(min(route_distance,final_leg_distance)).
    local points is list(terminal_route_current_target(route)).
    if route["phase"] = "intercept" or route["phase"] = "hold" {
        local point_index is route["hold_index"]+1.
        until point_index > 4 {
            points:add(route["hold_points"][mod(point_index,4)]).
            set point_index to point_index+1.
        }
        points:add(route["downwind_fix"]).
    }
    if route["phase"] <> "final" {
        if route["phase"] <> "base" { points:add(route["base_fix"]). }
        points:add(route["final_fix"]).
        points:add(runway_start).
    }
    local last_point is ship:geoposition.
    local previous_heading is compass_for_prograde().
    local turn_work is 0.
    local first_turn is true.
    for next_point in points {
        if calcdistance_m(last_point,next_point) > 1 {
            local leg_heading is heading_between(last_point,next_point).
            local planning_speed is max(reference_speed,min(ship:airspeed,energy_config["circuit_turn_speed"])).
            local heading_change is normalized_heading_error(leg_heading,previous_heading).
            if first_turn and route["turn_model_valid"] {
                set turn_work to turn_work+terminal_aero_turn_work(
                    heading_change,ship:airspeed,route["turn_model_rate"],
                    route["turn_model_loss"],route["clean_energy_loss"],energy_config).
            } else {
                set turn_work to turn_work+terminal_energy_turn_work(
                    heading_change,planning_speed,gravity_value,
                    route["clean_energy_loss"],energy_config).
            }
            set previous_heading to leg_heading.
            set first_turn to false.
        }
        set last_point to next_point.
    }
    return terminal_energy_budget(route_distance,final_leg_distance,
        capture_profile["altitude"]-runway_altitude,reference_speed,gravity_value,
        route["clean_energy_loss"],turn_work,energy_config).
}

// Learn only from uninterrupted clean, unpowered, nearly straight glides.
// Braking, powered recovery, gear drag and hard turns must not teach the
// planner that their extra losses are unavoidable on every remaining leg.
function terminal_route_measure_energy {
    parameter route.
    local energy_config is AVES["TerminalRoute"]["EnergyPlan"].
    local now_energy is terminal_route_energy_height().
    local now_time is time:seconds.
    local elapsed is now_time-route["energy_sample_time"].
    local clean_sample is not brakes and not gear and ship:thrust < 0.1 and
        throttle < 0.01 and abs(roll_for()) < 15 and abs(calc_aoa()) < 18 and
        ship:airspeed >= 120 and ship:airspeed <= energy_config["learning_max_speed"].
    if not clean_sample {
        set route["energy_clean_since"] to now_time.
    }
    if elapsed >= energy_config["sample_interval"] {
        local travelled_distance is calcdistance_m(route["energy_sample_position"],ship:geoposition).
        local eligible is clean_sample and now_time-route["energy_clean_since"] >=
            elapsed+energy_config["clean_settle_time"] and elapsed <= 5.
        set route["clean_energy_loss"] to terminal_energy_loss_filter(route["clean_energy_loss"],
            now_energy-route["energy_sample_height"],travelled_distance,elapsed,eligible,energy_config).
        set route["energy_sample_time"] to now_time.
        set route["energy_sample_height"] to now_energy.
        set route["energy_sample_position"] to ship:geoposition.
    }
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

// Convert the remaining altitude and distance to the preflare intercept into
// a high-speed final command.  This remains pure guidance mathematics so the
// real KerboScript implementation is exercised directly by offline tests.
function calculate_high_energy_final_command {
    parameter altitude_above_runway.
    parameter remaining_distance.
    parameter horizontal_closure_speed.
    parameter aim_altitude_above_runway.
    parameter high_energy_config.

    local distance_to_aim is max(
        remaining_distance-high_energy_config["aim_distance"],1
    ).
    local time_to_aim is max(
        distance_to_aim/max(horizontal_closure_speed,1),
        high_energy_config["minimum_time_to_aim"]
    ).
    local desired_vertical_speed is
        (aim_altitude_above_runway-altitude_above_runway)/time_to_aim.
    return lex(
        "desired_vertical_speed",desired_vertical_speed,
        "time_to_aim",time_to_aim,
        "distance_to_aim",distance_to_aim
    ).
}

function terminal_route_change_phase {
    parameter route, new_phase.
    if route["phase"] <> new_phase {
        flight_log_event("terminal_phase","from=" + route["phase"] + "|to=" + new_phase).
    }
    set route["phase"] to new_phase.
    set route["last_phase_change_time"] to time:seconds.
    set route["closest_target_distance"] to 999999999.
}

// The strict approach-capture test is shared by the landing handoff and GPWS.
// It uses fresh runway geometry, so a control tick cannot inherit a stale
// "final" route state after the aircraft has already left the localizer or
// glideslope.
function terminal_route_final_approach_capture {
    parameter route, minimum_vertical_speed is AVES["TerminalRoute"]["LandingCommit"]["minimum_vertical_speed"], maximum_vertical_speed is AVES["TerminalRoute"]["LandingCommit"]["maximum_vertical_speed"], minimum_glideslope_error is -AVES["TerminalRoute"]["LandingCommit"]["maximum_glideslope_error"], maximum_glideslope_error is AVES["TerminalRoute"]["LandingCommit"]["maximum_glideslope_error"], use_upper_glideslope_limit is true.
    local config_TR is AVES["TerminalRoute"].
    local commit_gate is config_TR["LandingCommit"].
    local geometry is terminal_route_geometry().
    local glideslope_altitude is calculate_glideslope_alt(geometry["distance"]).
    local glideslope_error is ship:altitude - glideslope_altitude.
    local glideslope_captured is glideslope_error >= minimum_glideslope_error.
    if use_upper_glideslope_limit {
        set glideslope_captured to glideslope_captured and glideslope_error <= maximum_glideslope_error.
    }
    local captured is route["phase"] = "final" and
        abs(geometry["cross_track"]) <= commit_gate["maximum_cross_track"] and
        abs(geometry["heading_error"]) <= commit_gate["maximum_heading_error"] and
        glideslope_captured and
        ship:verticalspeed >= minimum_vertical_speed and
        ship:verticalspeed <= maximum_vertical_speed and
        ship:airspeed >= commit_gate["minimum_speed"] and
        ship:airspeed <= commit_gate["maximum_speed"] and
        abs(roll_for()) <= commit_gate["maximum_bank"] and
        geometry["along_track"] > commit_gate["minimum_along_track"].
    return lex("captured",captured,"glideslope_error",glideslope_error).
}

// This is intentionally a single-sample check. The normal LandingGate has
// already held the approach stable for its configured time before this is
// called; this check decides whether to commit to landing or fly the go-around.
function terminal_route_landing_commit_check {
    parameter route.
    local capture is terminal_route_final_approach_capture(route).
    return lex("stable",capture["captured"],"glideslope_error",capture["glideslope_error"]).
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

    local high_energy_config is config_TR["HighEnergyFinal"].
    local high_energy_pitch_pid is pidloop(
        high_energy_config["pitch_kp"],
        high_energy_config["pitch_ki"],
        high_energy_config["pitch_kd"]
    ).
    set high_energy_pitch_pid:minoutput to high_energy_config["minimum_pitch"].
    set high_energy_pitch_pid:maxoutput to high_energy_config["maximum_pitch"].

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
        "profile_region", "inactive",
        "profile_altitude", 0,
        "profile_gradient", 0,
        "pitch_saturated", false,
        "turn_pitch_limit_active", false,
        "fast_turn_active", false,
        "turn_model_valid", false,
        "turn_model_mode", -1,
        "turn_model_aoa", 0,
        "turn_model_bank", 0,
        "turn_model_rate", 0,
        "turn_model_radius", 0,
        "turn_model_loss", 0,
        "turn_model_required_radius", 0,
        "preflare_pullup_active", false,
        "energy_margin", 0,
        "clean_energy_loss", config_TR["EnergyPlan"]["initial_clean_loss"],
        "energy_sample_time", time:seconds,
        "energy_sample_height", terminal_route_energy_height(),
        "energy_sample_position", ship:geoposition,
        "energy_clean_since", time:seconds,
        "margin_sample_time", time:seconds,
        "margin_sample_value", 0,
        "margin_sample_phase", "inactive",
        "margin_rate", 0,
        "brake_energy_margin", 0,
        "energy_assist_reason", "idle",
        "airbrake", false,
        "brake_mode", "inactive",
        "brake_reason", "inactive",
        "gear", false,
        "landing_ready", false,
        "geometry", arrival_geometry,
        "closest_target_distance", 999999999,
        "landing_stable_since", -1,
        "go_around_count", 0,
        "go_around_reason", "",
        "high_energy_final_active", false,
        "high_energy_pitch_pid", high_energy_pitch_pid,
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

function terminal_route_choose_turn {
    parameter route, turn_target, target_distance.
    local prior_mode is route["turn_model_mode"].
    set route["turn_model_valid"] to false.
    set route["turn_model_mode"] to -1.
    set route["turn_model_aoa"] to 0.
    set route["turn_model_bank"] to 0.
    set route["turn_model_rate"] to 0.
    set route["turn_model_radius"] to 0.
    set route["turn_model_loss"] to 0.
    set route["turn_model_required_radius"] to 0.
    if route["phase"] = "final" or route["phase"] = "go_around" or
       ship:altitude < 7000 or ship:altitude >= 70000 or
       ship:airspeed < 100 or ship:airspeed > 1500 or
       ship:body:name <> "Kerbin" {
        if prior_mode >= 0 { flight_log_event("terminal_turn_model","mode=-1|reason=outside_envelope"). }
        return.
    }
    local heading_error is normalized_heading_error(
        heading_between(ship:geoposition,turn_target),compass_for_prograde()).
    local nominal_bank is terminal_route_bank_command(heading_to_target(turn_target),AVES["TerminalRoute"]).
    if abs(nominal_bank) < AVES["TerminalRoute"]["EnergyPlan"]["turn_model_min_bank"] {
        if prior_mode >= 0 { flight_log_event("terminal_turn_model","mode=-1|reason=small_turn"). }
        return.
    }
    local environment is terminal_turn_environment(ship:altitude,ship:airspeed).
    local choice is terminal_turn_choice(environment,ship:airspeed,ship:mass,
        target_distance,heading_error,prior_mode,AVES["TerminalRoute"]["EnergyPlan"]).
    if choice["valid"] {
        set route["turn_model_valid"] to true.
        set route["turn_model_mode"] to choice["mode"].
        set route["turn_model_aoa"] to choice["aoa"].
        set route["turn_model_bank"] to choice["bank"].
        set route["turn_model_rate"] to choice["rate"].
        set route["turn_model_radius"] to choice["radius"].
        set route["turn_model_loss"] to choice["loss"].
        set route["turn_model_required_radius"] to choice["required_radius"].
    }
    if route["turn_model_mode"] <> prior_mode {
        flight_log_event("terminal_turn_model","phase="+route["phase"]+
            "|mode="+route["turn_model_mode"]+"|aoa="+route["turn_model_aoa"]+
            "|bank="+route["turn_model_bank"]+"|rate="+round(route["turn_model_rate"],3)+
            "|radius="+round(route["turn_model_radius"],1)+
            "|distance="+round(target_distance,1)).
    }
}

function terminal_route_remaining_distance {
    parameter route.
    local route_target is terminal_route_current_target(route).
    local distance is calcdistance_m(ship:geoposition, route_target).
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
    terminal_route_measure_energy(route).
    local energy_phase is route["phase"].
    local energy_hold_index is route["hold_index"].
    local route_target is terminal_route_current_target(route).
    local target_distance is calcdistance_m(ship:geoposition, route_target).
    terminal_route_choose_turn(route,route_target,target_distance).
    local remaining_distance is terminal_route_remaining_distance(route).
    local profile is calculate_glideslope_profile(remaining_distance).
    local profile_altitude is profile["altitude"].
    local speed_active is terminal_speed_control_active(route["phase"],remaining_distance,config_TR["ApproachSpeed"]).
    local reference_speed is config_TR["target_speed"].
    if speed_active { set reference_speed to config_TR["ApproachSpeed"]["target_speed"]. }
    local energy_plan is terminal_route_energy_plan(route,reference_speed).
    local target_energy is energy_plan["required"].
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
    local direct_profile is calculate_glideslope_profile(direct_distance).
    local active_profile_region is "inactive".
    if route["phase"] = "final" { set active_profile_region to direct_profile["region"]. }
    if active_profile_region <> route["profile_region"] {
        flight_log_event("terminal_profile_region","from="+route["profile_region"]+"|to="+active_profile_region+
            "|distance="+round(direct_distance,1)+"|altitude="+round(geometry["altitude"],1)+
            "|vertical_speed="+round(ship:verticalspeed,2)).
        set route["profile_region"] to active_profile_region.
    }
    set route["profile_altitude"] to direct_profile["altitude"].
    set route["profile_gradient"] to direct_profile["gradient"].
    // Phase changes alter the route immediately; do not command brakes or
    // thrust using the discarded leg's energy budget for one more update.
    if route["phase"] <> energy_phase or route["hold_index"] <> energy_hold_index {
        set route_target to terminal_route_current_target(route).
        set target_distance to calcdistance_m(ship:geoposition,route_target).
        terminal_route_choose_turn(route,route_target,target_distance).
        set remaining_distance to terminal_route_remaining_distance(route).
        set route["remaining_distance"] to remaining_distance.
        set speed_active to terminal_speed_control_active(route["phase"],remaining_distance,config_TR["ApproachSpeed"]).
        set reference_speed to config_TR["target_speed"].
        if speed_active { set reference_speed to config_TR["ApproachSpeed"]["target_speed"]. }
        set energy_plan to terminal_route_energy_plan(route,reference_speed).
        set target_energy to energy_plan["required"].
        set energy_margin to terminal_route_energy_height()-target_energy.
        set route["energy_margin"] to energy_margin.
    }
    local energy_config is config_TR["EnergyPlan"].
    local margin_elapsed is time:seconds-route["margin_sample_time"].
    if route["margin_sample_phase"] <> route["phase"] or route["hold_index"] <> energy_hold_index {
        set route["margin_rate"] to 0.
        set route["margin_sample_time"] to time:seconds.
        set route["margin_sample_value"] to energy_margin.
        set route["margin_sample_phase"] to route["phase"].
    } else if margin_elapsed >= energy_config["sample_interval"] {
        set route["margin_rate"] to (energy_margin-route["margin_sample_value"])/max(margin_elapsed,0.01).
        set route["margin_sample_time"] to time:seconds.
        set route["margin_sample_value"] to energy_margin.
    }
    set route["brake_energy_margin"] to terminal_energy_brake_margin(
        energy_margin,energy_plan["reserve"],route["margin_rate"],energy_config).
    local current_turn is lex("extra_distance",0,"reserve",0).
    if route["phase"] <> "final" and route["phase"] <> "go_around" {
        local calibrated_radius is -1.
        if route["turn_model_valid"] { set calibrated_radius to route["turn_model_radius"]. }
        set current_turn to terminal_energy_current_turn(target_distance,
            normalized_heading_error(heading_between(ship:geoposition,route_target),compass_for_prograde()),
            ship:airspeed,roll_for(),ship:body:mu/(ship:body:radius^2),
            route["clean_energy_loss"],energy_config,calibrated_radius).
        set route["brake_energy_margin"] to route["brake_energy_margin"]-current_turn["reserve"].
    }
    set terminal_route_debug["energy_capture"] to energy_plan["capture"].
    set terminal_route_debug["energy_drag_work"] to energy_plan["drag_work"].
    set terminal_route_debug["energy_turn_work"] to energy_plan["turn_work"].
    set terminal_route_debug["energy_reserve"] to energy_plan["reserve"].
    set terminal_route_debug["energy_turn_extra_distance"] to current_turn["extra_distance"].
    set terminal_route_debug["energy_turn_reserve"] to current_turn["reserve"].
    set terminal_route_debug["energy_clean_loss"] to route["clean_energy_loss"].
    set terminal_route_debug["energy_margin_rate"] to route["margin_rate"].
    set terminal_route_debug["energy_brake_margin"] to route["brake_energy_margin"].
    set terminal_route_debug["turn_model_mode"] to route["turn_model_mode"].
    set terminal_route_debug["turn_model_rate"] to route["turn_model_rate"].
    set terminal_route_debug["turn_model_radius"] to route["turn_model_radius"].
    set terminal_route_debug["turn_model_loss"] to route["turn_model_loss"].
    set terminal_route_debug["turn_model_required_radius"] to route["turn_model_required_radius"].
    local landing_gate is config_TR["LandingGate"].
    // Final/preflare use speed hysteresis; early descent retains energy control.
    // Use the same activation/reference as this update's energy calculation.
    // Go-around releases immediately even if the phase changed above.
    local brake_decision is terminal_brake_decision(route["airbrake"],route["phase"],speed_active,
        ship:airspeed,energy_margin,config_TR,route["brake_energy_margin"]).
    if brake_decision["command"] <> route["airbrake"] or brake_decision["mode"] <> route["brake_mode"] or
       brake_decision["reason"] <> route["brake_reason"] {
        flight_log_approach_brake(brake_decision["mode"],brake_decision["reason"],brake_decision["command"],
            reference_speed,config_TR["ApproachSpeed"]["brake_on_speed"],config_TR["ApproachSpeed"]["brake_off_speed"],energy_margin,
            route["brake_energy_margin"],target_energy,current_turn["extra_distance"],current_turn["reserve"]).
    }
    set route["airbrake"] to brake_decision["command"].
    set route["brake_mode"] to brake_decision["mode"].
    set route["brake_reason"] to brake_decision["reason"].
    set terminal_route_debug["brake_reason"] to route["brake_reason"].
    set terminal_route_debug["brake_mode"] to route["brake_mode"].
    set route["gear"] to direct_distance < landing_gate["gear_distance"] and geometry["altitude"] < landing_gate["gear_altitude"].
    // Do not start the landing handoff timer until the preflare is complete
    // and the aircraft is established on the three-degree shallow segment.
    local landing_stable is route["phase"] = "final" and route["profile_region"] = "shallow" and
        direct_distance < landing_gate["distance"] and
        geometry["altitude"] < landing_gate["altitude"] and geometry["along_track"] > landing_gate["minimum_along_track"] and
        abs(geometry["heading_error"]) < landing_gate["heading_error"] and abs(geometry["cross_track"]) < landing_gate["cross_track"] and
        ship:airspeed > landing_gate["minimum_speed"] and ship:airspeed < landing_gate["maximum_speed"].
    if landing_stable {
        if route["landing_stable_since"] < 0 { set route["landing_stable_since"] to time:seconds. }
    }else{
        set route["landing_stable_since"] to -1.
    }
    local landing_was_ready is route["landing_ready"].
    set route["landing_ready"] to landing_stable and time:seconds - route["landing_stable_since"] >= landing_gate["stable_time"].
    if route["landing_ready"] and not landing_was_ready {
        flight_log_event("landing_gate_ready","distance="+round(direct_distance,1)+
            "|altitude="+round(geometry["altitude"],1)+"|vertical_speed="+round(ship:verticalspeed,2)+
            "|profile_region="+route["profile_region"]+"|stable_time="+round(landing_gate["stable_time"],2)).
    }

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
    set terminal_route_debug["profile_region"] to route["profile_region"].
    set terminal_route_debug["profile_altitude"] to route["profile_altitude"].
    set terminal_route_debug["profile_gradient"] to route["profile_gradient"].
    set terminal_route_debug["profile_error"] to route["profile_altitude"] - ship:altitude.
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
    local route_target is terminal_route_current_target(route).
    local target_distance is calcdistance_m(ship:geoposition,route_target).
    local turn_bank_command is terminal_route_bank_command(heading_to_target(route_target),config_TR).
    local turn_pitch_gs_altitude is 0.
    local fast_turn_active is false.
    if route["phase"] <> "final" and route["phase"] <> "go_around" {
        set turn_pitch_gs_altitude to calculate_glideslope_alt(target_distance).
        if route["turn_model_valid"] {
            if turn_bank_command > 0 { set turn_bank_command to route["turn_model_bank"]. }
            if turn_bank_command < 0 { set turn_bank_command to -route["turn_model_bank"]. }
            set fast_turn_active to true.
        } else {
            local fast_turn_solution is terminal_fast_turn_command(
                turn_bank_command,ship:airspeed,turn_pitch_gs_altitude,
                ship:altitude,config_TR).
            set turn_bank_command to fast_turn_solution["command"].
            set fast_turn_active to fast_turn_solution["active"].
        }
    }
    local distance is route["remaining_distance"].
    local time_to_go is max(distance / max(ship:airspeed, config_TR["time_to_go_min_speed"]), config_TR["time_to_go_min"]).
    local desired_vertical_speed is 0.
    local profile_feedforward_vs is 0.
    local profile_altitude_error is 0.
    local active_profile_region is "inactive".
    local pid_log is "none".
    local high_energy_config is config_TR["HighEnergyFinal"].
    local high_energy_aim_profile is calculate_glideslope_profile(high_energy_config["aim_distance"]).
    local high_energy_horizontal_speed is sqrt(max(0,ship:velocity:surface:mag^2 - ship:verticalspeed^2)).
    local high_energy_closure_speed is high_energy_horizontal_speed *
        max(0,cos(route["geometry"]["heading_error"])).
    local high_energy_solution is calculate_high_energy_final_command(
        route["geometry"]["altitude"],distance,high_energy_closure_speed,
        high_energy_aim_profile["altitude"]-runway_altitude,high_energy_config
    ).
    local high_energy_was_active is route["high_energy_final_active"].
    if route["phase"] = "final" and not route["high_energy_final_active"] and
       ship:airspeed >= high_energy_config["activation_speed"] and
       route["energy_margin"] >= high_energy_config["activation_energy_margin"] and
       distance > high_energy_config["aim_distance"] {
        set route["high_energy_final_active"] to true.
        set route["high_energy_pitch_pid"] to pidloop(
            high_energy_config["pitch_kp"],
            high_energy_config["pitch_ki"],
            high_energy_config["pitch_kd"]
        ).
        set route["high_energy_pitch_pid"]:minoutput to high_energy_config["minimum_pitch"].
        set route["high_energy_pitch_pid"]:maxoutput to high_energy_config["maximum_pitch"].
    }
    if route["high_energy_final_active"] {
        local high_energy_profile_error is route["profile_altitude"]-ship:altitude.
        local high_energy_captured is
            ship:airspeed <= high_energy_config["exit_speed"] and
            high_energy_solution["desired_vertical_speed"] >= high_energy_config["exit_desired_vertical_speed"] and
            abs(high_energy_profile_error) <= high_energy_config["profile_capture_tolerance"].
        if route["phase"] <> "final" or high_energy_captured {
            set route["high_energy_final_active"] to false.
        }
    }
    if route["high_energy_final_active"] <> high_energy_was_active {
        flight_log_event("terminal_high_energy_final","active="+route["high_energy_final_active"]+
            "|distance="+round(distance,1)+"|altitude="+round(route["geometry"]["altitude"],1)+
            "|airspeed="+round(ship:airspeed,1)+"|vertical_speed="+round(ship:verticalspeed,2)+
            "|desired_vertical_speed="+round(high_energy_solution["desired_vertical_speed"],2)+
            "|profile_error="+round(route["profile_altitude"]-ship:altitude,1)).
    }

    if route["phase"] = "final" and route["high_energy_final_active"] {
        set desired_vertical_speed to high_energy_solution["desired_vertical_speed"].
        set profile_feedforward_vs to desired_vertical_speed.
        set profile_altitude_error to route["profile_altitude"]-ship:altitude.
        set active_profile_region to route["profile_region"].
        set pid_log to "high_energy_final".
    } else if route["phase"] = "final" {
        local profile is calculate_glideslope_profile(distance).
        local horizontal_groundspeed is sqrt(max(0,ship:velocity:surface:mag^2 - ship:verticalspeed^2)).
        local runway_closure_speed is horizontal_groundspeed * max(0,cos(route["geometry"]["heading_error"])).
        set runway_closure_speed to max(runway_closure_speed,config_TR["time_to_go_min_speed"]).
        set profile_feedforward_vs to -runway_closure_speed * profile["gradient"].
        local altitude_error is profile["altitude"] - ship:altitude.
        set profile_altitude_error to altitude_error.
        set active_profile_region to profile["region"].
        set desired_vertical_speed to profile_feedforward_vs + altitude_error / config_TR["final_profile_correction_time"].
        set desired_vertical_speed to max(config_TR["final_profile_min_vertical_speed"],
            min(config_TR["final_profile_max_vertical_speed"],desired_vertical_speed)).
        set route["profile_altitude"] to profile["altitude"].
        set route["profile_gradient"] to profile["gradient"].
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
    local profile_pitch_feedforward is 0.
    local pitch_saturated is false.
    local preflare_pullup_active is false.
    local preflare_pullup_fraction is 0.
    local high_energy_pid_output is 0.
    local turn_pitch_raw_bias is 0.
    local turn_pitch_limit_active is false.
    if route["phase"] = "final" and route["high_energy_final_active"] {
        set route["high_energy_pitch_pid"]:setpoint to desired_vertical_speed.
        set high_energy_pid_output to route["high_energy_pitch_pid"]:update(time:seconds,ship:verticalspeed).
        set pitch_bias to high_energy_pid_output.
        set pitch_saturated to
            pitch_bias <= high_energy_config["minimum_pitch"] or
            pitch_bias >= high_energy_config["maximum_pitch"].
        set route["pitch_saturated"] to pitch_saturated.
        set route["preflare_pullup_active"] to false.
        set pid_log to high_energy_pid_output.
    } else if route["phase"] = "final" {
        local pitch_solution is calculate_glideslope_pitch_command(
            desired_vertical_speed,ship:verticalspeed,ship:velocity:surface:mag,
            config_TR["final_pitch_trim_aoa"],config_TR["final_pitch_vertical_speed_gain"],
            config_TR["final_pitch_command_min"],config_TR["final_pitch_command_max"]
        ).
        set pitch_bias to pitch_solution["command"].
        set profile_pitch_feedforward to pitch_solution["feedforward"].
        set pitch_saturated to pitch_solution["saturated"].
        set pid_log to pitch_solution["correction"].
        local pullup_solution is calculate_preflare_pullup_command(
            active_profile_region,profile_altitude_error,pitch_bias,
            config_TR["final_preflare_pullup_start_error"],config_TR["final_preflare_pullup_full_error"],
            config_TR["final_preflare_pullup_pitch"]
        ).
        set pitch_bias to pullup_solution["command"].
        set preflare_pullup_active to pullup_solution["active"].
        set preflare_pullup_fraction to pullup_solution["fraction"].
        if preflare_pullup_active <> route["preflare_pullup_active"] {
            flight_log_event("terminal_preflare_pullup","active="+preflare_pullup_active+
                "|distance="+round(distance,1)+"|altitude="+round(ship:altitude-runway_altitude,1)+
                "|profile_error="+round(profile_altitude_error,1)+"|vertical_speed="+round(ship:verticalspeed,2)+
                "|pitch_command="+round(pitch_bias,2)+"|fraction="+round(preflare_pullup_fraction,2)).
        }
        set route["preflare_pullup_active"] to preflare_pullup_active.
        if pitch_saturated <> route["pitch_saturated"] {
            flight_log_event("terminal_pitch_saturation","active="+pitch_saturated+
                "|distance="+round(distance,1)+"|altitude="+round(ship:altitude-runway_altitude,1)+
                "|vertical_speed="+round(ship:verticalspeed,2)+"|target_vertical_speed="+round(desired_vertical_speed,2)+
                "|pitch_command="+round(pitch_bias,2)).
        }
        set route["pitch_saturated"] to pitch_saturated.
    } else {
        set pitch_bias to max(config_TR["pitch_bias_min"], min(config_TR["pitch_bias_max"], (desired_vertical_speed - ship:verticalspeed) * config_TR["pitch_bias_gain"])).
        set turn_pitch_raw_bias to pitch_bias.
        if route["phase"] <> "go_around" {
            local turn_pitch_solution is terminal_turn_pitch_limit(
                pitch_bias,turn_bank_command,roll_for(),turn_pitch_gs_altitude,
                ship:altitude,config_TR).
            set pitch_bias to turn_pitch_solution["command"].
            set turn_pitch_limit_active to turn_pitch_solution["active"].
        }
        set route["pitch_saturated"] to false.
        if route["preflare_pullup_active"] {
            flight_log_event("terminal_preflare_pullup","active=False|reason=left_final").
        }
        set route["preflare_pullup_active"] to false.
    }
    if turn_pitch_limit_active <> route["turn_pitch_limit_active"] {
        flight_log_event("terminal_turn_pitch_limit","active="+turn_pitch_limit_active+
            "|phase="+route["phase"]+"|target_distance="+round(target_distance,1)+
            "|glideslope_altitude="+round(turn_pitch_gs_altitude,1)+
            "|altitude="+round(ship:altitude,1)+"|turn_bank="+round(turn_bank_command,1)+
            "|actual_bank="+round(roll_for(),1)+"|raw_bias="+round(turn_pitch_raw_bias,2)+
            "|command="+round(pitch_bias,2)).
    }
    set route["turn_pitch_limit_active"] to turn_pitch_limit_active.
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

    if route["brake_energy_margin"] > config_TR["high_energy_threshold"] {
        set target_aoa to min(max_energy_aoa, config_TR["nominal_target_aoa"] + route["brake_energy_margin"] / config_TR["energy_aoa_gain_denominator"]).
    }
    if route["energy_margin"] < -config_TR["low_energy_margin"] {
        set target_aoa to descent_min_aoa.
    }

    // Glide whenever possible.  Use engine power only to protect the 120 m/s
    // speed floor or recover a genuine low-energy state; that makes it
    // mutually exclusive with both energy and approach-speed brake commands.
    local assist is terminal_energy_throttle(route["energy_margin"],ship:airspeed,config_TR).
    local energy_throttle is assist["energy"].
    local speed_throttle is assist["speed"].
    set dapthrottle to assist["command"].
    local assist_reason is "idle".
    if energy_throttle > 0 { set assist_reason to "route_deficit". }
    if speed_throttle > energy_throttle { set assist_reason to "speed_floor". }
    if assist_reason <> route["energy_assist_reason"] {
        flight_log_event("terminal_energy_assist","from="+route["energy_assist_reason"]+"|to="+assist_reason+
            "|margin="+round(route["energy_margin"],1)+"|energy_request="+round(energy_throttle,3)+
            "|speed_request="+round(speed_throttle,3)+"|throttle="+round(dapthrottle,3)).
        set route["energy_assist_reason"] to assist_reason.
    }
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
    if route["turn_model_valid"] {
        set target_aoa to route["turn_model_aoa"].
    } else if fast_turn_active {
        set target_aoa to max(target_aoa,config_TR["fast_turn_target_aoa"]).
    }
    if fast_turn_active <> route["fast_turn_active"] {
        flight_log_event("terminal_fast_turn","active="+fast_turn_active+
            "|phase="+route["phase"]+"|target_distance="+round(target_distance,1)+
            "|airspeed="+round(ship:airspeed,1)+"|glideslope_altitude="+
            round(turn_pitch_gs_altitude,1)+"|altitude="+round(ship:altitude,1)+
            "|bank="+round(turn_bank_command,1)+"|aoa="+round(target_aoa,1)+
            "|energy_margin="+round(route["energy_margin"],1)).
    }
    set route["fast_turn_active"] to fast_turn_active.
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
        set dap["aoa"]["target_bank"] to turn_bank_command.

    }else{
        set dap["str_mode"] to "aerostr".
        local desired_heading is heading_to_target(route_target).
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
    set terminal_route_debug["profile_altitude"] to route["profile_altitude"].
    set terminal_route_debug["profile_gradient"] to route["profile_gradient"].
    set terminal_route_debug["profile_error"] to route["profile_altitude"] - ship:altitude.
    set terminal_route_debug["profile_feedforward_vs"] to profile_feedforward_vs.
    set terminal_route_debug["profile_pitch_feedforward"] to profile_pitch_feedforward.
    set terminal_route_debug["pitch_saturated"] to pitch_saturated.
    set terminal_route_debug["preflare_pullup_active"] to preflare_pullup_active.
    set terminal_route_debug["preflare_pullup_fraction"] to preflare_pullup_fraction.
    set terminal_route_debug["pitch_bias"] to pitch_bias.
    set terminal_route_debug["turn_pitch_limit_active"] to turn_pitch_limit_active.
    set terminal_route_debug["turn_pitch_raw_bias"] to turn_pitch_raw_bias.
    set terminal_route_debug["turn_pitch_gs_altitude"] to turn_pitch_gs_altitude.
    set terminal_route_debug["turn_pitch_bank"] to turn_bank_command.
    set terminal_route_debug["fast_turn_active"] to fast_turn_active.
    set terminal_route_debug["target_aoa"] to target_aoa.
    set terminal_route_debug["high_energy_final_active"] to route["high_energy_final_active"].
    set terminal_route_debug["high_energy_desired_vs"] to high_energy_solution["desired_vertical_speed"].
    set terminal_route_debug["high_energy_pitch_command"] to pitch_bias.
    set terminal_route_debug["high_energy_pid_output"] to high_energy_pid_output.
    set terminal_route_debug["high_energy_time_to_aim"] to high_energy_solution["time_to_aim"].
    set terminal_route_debug["throttle"] to dapthrottle.
    set terminal_route_debug["Pid_log"] to pid_log.

    // pos_arrow's length is the height above the surface waypoint.  Clearing
    // before each redraw guarantees one current marker at the target altitude.
    if terminal_route_target_arrow_enabled {
        clearVecDraws().
        pos_arrow(route_target,"TR " + route["phase"],route["target_altitude"],0.1).
        set terminal_route_target_arrow_active to true.
    } else if terminal_route_target_arrow_active {
        clearVecDraws().
        set terminal_route_target_arrow_active to false.
    }

    set Lastest_status to "terminal " + route["phase"] + " | energy " + round(route["energy_margin"]) + "m | loop " + route["hold_laps"].
}
