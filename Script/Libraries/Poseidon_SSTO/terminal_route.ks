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
    "preflare_pitch_floor_fraction", 0,
    "preflare_anticipation_active", false,
    "preflare_predictive_fraction", 0,
    "preflare_arrest_distance", 0,
    "preflare_profile_deficit_height", 0,
    "preflare_absolute_arrest_height", 0,
    "preflare_clearance_margin", 0,
    "preflare_clearance_used", 0,
    "preflare_target_vertical_speed", 0,
    "preflare_preview_seconds", 0,
    "preflare_preview_distance", 0,
    "preflare_preview_feedforward_vs", 0,
    "preflare_altitude_correction", 0,
    "preflare_response_delay", 0,
    "preflare_vertical_deceleration", 0,
    "pullup_far_valid", false,
    "pullup_far_age", -1,
    "pullup_far_time", -100,
    "pullup_far_altitude", 0,
    "pullup_far_speed", 0,
    "pullup_far_lift", 0,
    "pullup_far_raw_accel", 0,
    "pullup_far_accel", 0,
    "pullup_far_configuration_ut", -100,
    "pullup_far_brakes", false,
    "pullup_far_gear", false,
    "descent_recovery_active", false,
    "descent_recovery_elapsed", 0,
    "descent_tracking_error", 0,
    "descent_arrest_margin", 0,
    "descent_arrest_height", 0,
    "recovery_throttle_floor", 0,
    "propulsion_mode", "idle",
    "propulsion_throttle", 0,
    "mass_speed_scale", 1,
    "dump_lf_floor", 0,
    "dump_lf_paired_floor", 0,
    "dump_ox_floor", 0,
    "fuel_dump_active", false,
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
    "turn_sample_age", -1,
    "turn_sample_altitude", 0,
    "turn_sample_speed", 0,
    "turn_sample_pending", 0,
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
    "landing_handoff_kind", "none",
    "preflare_commit_stable", false,
    "preflare_commit_margin", 0,
    "landing_preflare_active", false,
    "landing_pullup_active", false,
    "landing_pullup_margin", 0,
    "landing_pullup_response_delay", 0,
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

// Equal lift at the same density/AoA requires speed proportional to sqrt(mass).
// Preserve normal light approaches; this heavy allowance still needs KSP/FAR
// validation, including the runway stopping distance.
function terminal_mass_speed_scale {
    parameter measured_mass, config_TR.
    return sqrt(max(1,measured_mass/max(1,config_TR["max_landing_mass"]))).
}

// Estimate how much runway-distance and height are needed to unwind sink
// toward a requested vertical speed.  The acceleration is intentionally
// derated and scales with dynamic pressure per unit mass.
function terminal_sink_arrest_prediction {
    parameter measured_vs, target_vs, horizontal_speed, measured_mass, measured_airspeed, config_TR,
        available_vertical_acceleration is -1, response_delay_credit is 0.
    local prediction_config is config_TR["PreflarePrediction"].
    local mass_scale is terminal_mass_speed_scale(measured_mass,config_TR).
    local reference_speed is config_TR["ApproachSpeed"]["target_speed"]*mass_scale.
    local capability_ratio is (measured_airspeed/max(reference_speed,1))^2.
    set capability_ratio to max(prediction_config["minimum_capability_scale"],
        min(prediction_config["maximum_capability_scale"],capability_ratio)).
    local heavy_ratio is max(0,measured_mass/max(1,config_TR["max_landing_mass"])-1).
    local response_delay is prediction_config["response_delay_seconds"]+
        heavy_ratio*prediction_config["heavy_mass_delay_seconds"].
    set response_delay to max(0,response_delay-max(0,response_delay_credit)).
    local vertical_deceleration is max(0.1,
        prediction_config["reference_vertical_deceleration"]*capability_ratio).
    if available_vertical_acceleration >= 0 {
        set vertical_deceleration to max(0.1,available_vertical_acceleration).
    }
    local sink_speed is max(0,-measured_vs).
    local target_sink_speed is max(0,-target_vs).
    local sink_excess is max(0,sink_speed-target_sink_speed).
    local arrest_time is sink_excess/vertical_deceleration.
    // Relative profile deficit integrates only sink in excess of the target.
    // Absolute height loss keeps target sink throughout delay and deceleration.
    local profile_deficit_height is sink_excess*response_delay+
        sink_excess^2/(2*vertical_deceleration).
    local absolute_arrest_height is sink_speed*response_delay+
        max(0,sink_speed^2-target_sink_speed^2)/(2*vertical_deceleration).
    local arrest_distance is max(0,horizontal_speed)*(response_delay+arrest_time).
    return lex("sink_excess",sink_excess,"arrest_time",arrest_time,
        "profile_deficit_height",profile_deficit_height,
        "absolute_arrest_height",absolute_arrest_height,"arrest_distance",arrest_distance,
        "response_delay",response_delay,"vertical_deceleration",vertical_deceleration,
        "capability_ratio",capability_ratio).
}

// Preview only the upcoming profile over the aircraft response delay. The
// full sink-arrest time belongs to escape protection, not the approach path.
// Altitude correction is always applied after the feedforward preview: even
// maximum anticipation must still command descent back toward the profile.
function terminal_final_profile_command {
    parameter distance_to_threshold, measured_altitude_asl, horizontal_speed,
        measured_mass, config_TR, glideslope_config, runway_height_asl,
        preview_enabled is true.
    local profile is calculate_glideslope_profile(distance_to_threshold,
        runway_height_asl,glideslope_config).
    local prediction_config is config_TR["PreflarePrediction"].
    local closure_speed is max(horizontal_speed,config_TR["time_to_go_min_speed"]).
    local heavy_ratio is max(0,measured_mass/max(1,config_TR["max_landing_mass"])-1).
    local lookahead_seconds is 0.
    if preview_enabled {
        set lookahead_seconds to max(0,min(prediction_config["maximum_preview_seconds"],
            prediction_config["response_delay_seconds"]+
            heavy_ratio*prediction_config["heavy_mass_delay_seconds"])).
    }
    local lookahead_distance is closure_speed*lookahead_seconds.
    local preview_profile is calculate_glideslope_profile(
        distance_to_threshold-lookahead_distance,runway_height_asl,glideslope_config).
    local profile_error is profile["altitude"]-measured_altitude_asl.
    // Release anticipation smoothly when above the reference. It must never
    // mask the need to descend back onto the path (flight 407).
    local preview_weight is max(0,min(1,1+profile_error/
        max(1,prediction_config["above_profile_preview_fade"]))).
    set preview_weight to preview_weight^2*(3-2*preview_weight).
    local feedforward_vs is -closure_speed*profile["gradient"].
    local preview_feedforward_vs is feedforward_vs+
        (-closure_speed*preview_profile["gradient"]-feedforward_vs)*preview_weight.
    local altitude_correction is profile_error/max(1,config_TR["final_profile_correction_time"]).
    local desired_vs is max(config_TR["final_profile_min_vertical_speed"],
        min(config_TR["final_profile_max_vertical_speed"],preview_feedforward_vs+altitude_correction)).
    local anticipation_fraction is min(1,abs(preview_feedforward_vs-feedforward_vs)/
        max(1,closure_speed*abs(glideslope_config["angle1"]-glideslope_config["angle2"]))).
    return lex("altitude",profile["altitude"],"gradient",profile["gradient"],
        "region",profile["region"],"profile_error",profile_error,
        "feedforward_vs",feedforward_vs,"preview_feedforward_vs",preview_feedforward_vs,
        "altitude_correction",altitude_correction,"desired_vs",desired_vs,
        "lookahead_seconds",lookahead_seconds,"lookahead_distance",lookahead_distance,
        "preview_weight",preview_weight,"fraction",anticipation_fraction).
}

// Lift is signed in the sampled relative-wind frame; never turn a negative
// FAR force into usable pull-up authority with ABS. kN / vessel tonnes = m/s^2.
function terminal_pullup_lift_force {
    parameter sampled_force, sample_velocity, vessel_top.
    local wind_direction is sample_velocity:normalized.
    local lift_axis is vessel_top-wind_direction*vdot(vessel_top,wind_direction).
    if lift_axis:mag < 0.001 { return 0. }
    return vdot(sampled_force,lift_axis:normalized).
}

function terminal_pullup_acceleration {
    parameter lift_force_kn, vessel_mass, gravity_value, surface_speed,
        measured_vs, bank_angle, prediction_config.
    local gamma_ratio is max(-1,min(1,measured_vs/max(1,surface_speed))).
    local vertical_lift_fraction is sqrt(max(0,1-gamma_ratio^2))*max(0,cos(bank_angle)).
    // Do not credit thrust or the upward component of drag in descent.
    local raw_acceleration is lift_force_kn/max(0.001,vessel_mass)*vertical_lift_fraction-gravity_value.
    return lex("raw",raw_acceleration,"usable",max(0,min(
        prediction_config["far_maximum_acceleration"],
        raw_acceleration*prediction_config["far_acceleration_safety"]))).
}

// One live FAR query per refresh, only on normal final. Cached force is
// invalidated by configuration or state drift; no trajectory integration or
// logger is involved. The familiar calibrated kOS left-handed sampling
// frame is shared with POS_Calibrate, not with the independent test physics.
function terminal_route_refresh_pullup_force {
    parameter route, prediction_config, eligible.
    if not eligible or not addons:available("FAR") {
        set route["pullup_far_valid"] to false.
        return.
    }
    if not addons:far:hassuffix("AEROFORCEAT") {
        set route["pullup_far_valid"] to false.
        return.
    }
    local configuration_changed is brakes <> route["pullup_far_brakes"] or gear <> route["pullup_far_gear"].
    if configuration_changed {
        set route["pullup_far_brakes"] to brakes.
        set route["pullup_far_gear"] to gear.
        set route["pullup_far_configuration_ut"] to time:seconds.
    }
    local refresh_seconds is prediction_config["far_refresh_seconds"].
    local settling is time:seconds-route["pullup_far_configuration_ut"] < prediction_config["far_configuration_settle"].
    if settling { set refresh_seconds to min(refresh_seconds,0.25). }
    if route["pullup_far_valid"] and not configuration_changed and
       time:seconds-route["pullup_far_time"] < refresh_seconds and
       abs(ship:altitude-route["pullup_far_altitude"]) < prediction_config["far_altitude_drift"] and
       abs(ship:airspeed-route["pullup_far_speed"]) < prediction_config["far_speed_drift"] { return. }
    local vessel_forward is ship:facing:forevector:normalized.
    local vessel_top is ship:facing:topvector:normalized.
    local vessel_right is vcrs(vessel_top,vessel_forward):normalized.
    local pitch_axis is vcrs(vessel_right,vessel_forward):normalized.
    local sample_aoa is prediction_config["far_sample_aoa"].
    local sample_velocity is ship:airspeed*(vessel_forward*cos(sample_aoa)+pitch_axis*sin(sample_aoa)).
    local sampled_force is addons:far:aeroforceat(ship:altitude,sample_velocity).
    local measured_lift is terminal_pullup_lift_force(sampled_force,sample_velocity,vessel_top).
    if settling and route["pullup_far_valid"] and
       abs(ship:airspeed-route["pullup_far_speed"]) < prediction_config["far_speed_drift"] and
       abs(ship:altitude-route["pullup_far_altitude"]) < prediction_config["far_altitude_drift"] {
        set measured_lift to min(measured_lift,route["pullup_far_lift"]).
    }
    set route["pullup_far_lift"] to measured_lift.
    set route["pullup_far_time"] to time:seconds.
    set route["pullup_far_altitude"] to ship:altitude.
    set route["pullup_far_speed"] to ship:airspeed.
    set route["pullup_far_valid"] to true.
}

function terminal_route_surface_clearance {
    parameter altitude_asl, runway_altitude_asl, terrain_height_asl.
    return min(altitude_asl-runway_altitude_asl,altitude_asl-max(0,terrain_height_asl)).
}

function terminal_route_paired_lf_dump_floor {
    parameter lf_floor, ox_remaining, ox_floor, healthy_rapiers, config_TR.
    local dump_config is config_TR["RecoveryFuelDump"].
    local available_ox is max(0,ox_remaining-ox_floor).
    local preserved_ox is min(available_ox,dump_config["cc_partial_ox_budget"]).
    local paired_lf is 0.
    if healthy_rapiers > 0 and preserved_ox > 0 {
        set paired_lf to preserved_ox*dump_config["cc_lf_per_ox"]+dump_config["cc_lf_margin"].
    }
    return lf_floor+paired_lf.
}

function terminal_route_healthy_rapier_count {
    local healthy is 0.
    if defined recovery_engines {
        for identity in recovery_engines:keys {
            local entry is recovery_engines[identity].
            if entry["kind"] = "rapier" and entry["present"] and not entry["failed"] and
               not entry["isolated"] and entry["part"]:thrustlimit > 0 and not entry["part"]:flameout {
                set healthy to healthy+1.
            }
        }
        return healthy.
    }
    if defined abort_state and abort_state:haskey("active") and abort_state["active"] and
       abort_state:haskey("engines") and abort_state["engines"]:haskey("rapier") {
        return abort_state["engines"]["rapier"]["working"].
    }
    for engine_part in ship:partstitledpattern("R.A.P.I.E.R") {
        if engine_part:thrustlimit > 0 and not engine_part:flameout {
            set healthy to healthy+1.
        }
    }
    return healthy.
}

// Rocket mode is only an option when TEAM already requests thrust and enough
// paired propellant remains above the recovery/orbit floors. Engine health,
// isolation, and individual thrust limits are still applied by the engine
// command helpers used by terminal_route_fly.
function terminal_descent_rapier_mode {
    parameter flight_step, route_phase, requested_throttle, atmospheric_descent,
        clearance, healthy_rapiers, lf_remaining, ox_remaining, lf_floor, ox_floor, config_TR.
    if requested_throttle <= 0.05 { return "idle". }
    // AED/EDR reach this controller after the reentry handoff to TEAM. Keep
    // engine-mode changes inside atmospheric terminal phases; orbital, entry,
    // coast, and landing-flare owners retain their existing propulsion policy.
    local terminal_descent_phase is route_phase = "reposition" or route_phase = "intercept" or
        route_phase = "hold" or route_phase = "downwind" or route_phase = "base" or
        route_phase = "final" or route_phase = "go_around".
    local escape_phase is route_phase = "go_around".
    if flight_step <> "TEAM" or not terminal_descent_phase or not atmospheric_descent or
       (not escape_phase and clearance <= config_TR["LandingGate"]["altitude"]) or
       (escape_phase and clearance <= config_TR["GoAround"]["minimum_altitude"]) { return "air". }
    if healthy_rapiers <= 0 { return "air". }
    local dump_config is config_TR["RecoveryFuelDump"].
    local usable_ox is max(0,ox_remaining-ox_floor).
    local usable_lf is max(0,lf_remaining-lf_floor).
    local burnable_lf is min(usable_lf,usable_ox*dump_config["cc_lf_per_ox"]).
    if burnable_lf < dump_config["cc_min_lf_burn"] or
       usable_ox < dump_config["cc_min_ox_burn"] { return "air". }
    return "closed".
}

function terminal_fuel_dump_decision {
    parameter phase, measured_mass, lf_remaining, lf_floor, descent_recovery_active,
        atmospheric_descent, clearance, vertical_speed, config_TR.
    local stop_margin is config_TR["RecoveryFuelDump"]["stop_margin"].
    return atmospheric_descent and vertical_speed < 0 and
        clearance > config_TR["RecoveryFuelDump"]["minimum_dump_clearance"] and
        phase <> "go_around" and
        measured_mass > config_TR["max_landing_mass"] and
        lf_remaining > lf_floor+stop_margin.
}

function terminal_brake_decision {
    parameter prior_brake, route_phase, speed_active, measured_speed, energy_error, config_TR, predicted_margin is 999999999,
        speed_scale is 1.
    local brake_mode is "energy".
    local brake_reason is "energy_band".
    if predicted_margin = 999999999 { set predicted_margin to energy_error. }
    local brake_command is predicted_margin > config_TR["brake_energy"].
    if prior_brake { set brake_command to predicted_margin > config_TR["EnergyPlan"]["brake_release_margin"]. }
    if speed_active {
        set brake_mode to "approach_speed".
        set brake_reason to "speed_band".
        set brake_command to approach_brake_band(prior_brake,measured_speed,
            config_TR["ApproachSpeed"]["brake_on_speed"]*speed_scale,config_TR["ApproachSpeed"]["brake_off_speed"]*speed_scale).
    }
    if predicted_margin <= 0 {
        set brake_command to false.
        set brake_reason to "route_reserve".
    }
    if energy_error < -config_TR["low_energy_margin"] {
        set brake_command to false.
        set brake_reason to "low_energy".
    }
    if measured_speed < config_TR["Propulsion"]["throttle_speed"]*speed_scale {
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
    parameter prior_brake, measured_speed, on_ground, runway_height, landing_config, speed_scale is 1.
    // Preserve wheel braking through low-altitude contact and bounce.
    if on_ground or runway_height <= landing_config["wheel_brake_altitude"] { return true. }
    return approach_brake_band(prior_brake,measured_speed,
        landing_config["brake_on_speed"]*speed_scale,landing_config["brake_off_speed"]*speed_scale).
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

// FAR evaluates the current craft at a synthetic relative-wind vector.
// Match POS_Calibrate's left-handed basis and bank convention exactly.
// Each result is stored per tonne so changing fuel mass needs no FAR refresh.
function terminal_turn_force_metrics {
    parameter far_force, vessel_right, vessel_top, vessel_forward,
        sample_aoa, sample_bank, sample_speed, gravity_value.
    local force_right is vdot(vessel_right,far_force).
    local force_top is vdot(vessel_top,far_force).
    local force_forward is vdot(vessel_forward,far_force).
    local lateral_force is -(force_right*cos(sample_bank)+force_top*sin(sample_bank)).
    local drag_force is -(force_forward*cos(sample_aoa)+
        (-force_top*cos(sample_bank)+force_right*sin(sample_bank))*sin(sample_aoa)).
    local signed_rate_mass is lateral_force*constant:radTOdeg/max(sample_speed,1).
    // FAR samples have produced both signs for this projection. The route
    // supplies turn direction separately through nominal_bank; candidate
    // feasibility needs the magnitude of turn authority.
    return lex("signed_rate_mass",signed_rate_mass,
        "rate_mass",abs(signed_rate_mass),
        "loss_mass",max(0,drag_force)/gravity_value).
}

// This string is assembled only for an event, never for the turn planner.
// Mode order is AoA 12/16/20 degrees, with bank 30/45/60 in each group.
function terminal_turn_sample_detail {
    parameter route.
    local signed_rates is "".
    local loss_masses is "".
    local mode_index is 0.
    until mode_index >= route["turn_force_signed_rates"]:length {
        if mode_index > 0 {
            set signed_rates to signed_rates+"/".
            set loss_masses to loss_masses+"/".
        }
        set signed_rates to signed_rates+round(route["turn_force_signed_rates"][mode_index],2).
        set loss_masses to loss_masses+round(route["turn_force_losses"][mode_index],2).
        set mode_index to mode_index+1.
    }
    return "signed_rate_mass="+signed_rates+"|loss_mass="+loss_masses.
}

function terminal_turn_sample {
    parameter rate_masses, loss_masses, turn_mode_index, turn_mass, turn_speed.
    local turn_rate_value is max(0,rate_masses[turn_mode_index]/max(turn_mass,1)).
    local turn_loss_value is max(0,loss_masses[turn_mode_index]/max(turn_mass,1)).
    local turn_radius_value is min(999999999,max(turn_speed,1)*constant:radTOdeg/max(turn_rate_value,0.0001)).
    return lex("rate",turn_rate_value,"radius",turn_radius_value,"loss",turn_loss_value).
}

// A constant-radius turn reaches a target at range d and bearing error e
// when r is roughly d/(2 sin e). Use a conservative fraction because actual
// bank and AoA take time to settle. Pick the lowest-drag feasible mode; if
// none can turn tightly enough, use the mode with the smallest radius.
function terminal_turn_choice {
    parameter rate_masses, loss_masses, turn_speed, turn_mass, target_distance, heading_error,
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
    until turn_mode_index >= rate_masses:length {
        local result is terminal_turn_sample(rate_masses,loss_masses,turn_mode_index,turn_mass,turn_speed).
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
    local chosen is terminal_turn_sample(rate_masses,loss_masses,best_mode,turn_mass,turn_speed).
    return lex("valid",true,"mode",best_mode,
        "aoa",12+4*floor(best_mode/3),
        "bank",30+15*mod(best_mode,3),
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

// Profile error alone is expected during preflare. Require both substantial
// sink and failure to track the requested vertical speed before intervening.
function terminal_final_descent_recovery {
    parameter phase, profile_error, wanted_vs, measured_vs, config_TR,
        sink_arrest_margin is 999999, clearance is 999999, contact is false.
    local config_GA is config_TR["GoAround"].
    local clearance_valid is clearance = 999999 or clearance > config_GA["minimum_altitude"].
    local profile_recovery is profile_error >= config_GA["vertical_profile_error"].
    local arrest_recovery is sink_arrest_margin <= config_GA["vertical_recovery_arrest_margin"] and
        (clearance = 999999 or clearance > config_GA["minimum_altitude"]).
    return phase = "final" and not contact and clearance_valid and (profile_recovery or arrest_recovery) and
        measured_vs < config_GA["vertical_sink_limit"] and
        wanted_vs - measured_vs >= config_GA["vertical_tracking_error"].
}

function terminal_vertical_go_around_decision {
    parameter descent_recovery_active, distance_to_threshold, recovery_elapsed,
        sink_arrest_margin, clearance, contact, config_TR.
    local config_GA is config_TR["GoAround"].
    local critical is sink_arrest_margin <= config_GA["vertical_critical_arrest_margin"].
    return descent_recovery_active and not contact and
        distance_to_threshold < config_GA["vertical_decision_distance"] and
        clearance > config_GA["minimum_altitude"] and
        (recovery_elapsed >= config_GA["vertical_persistence"] or
         (critical and recovery_elapsed >= config_GA["vertical_critical_persistence"])).
}

function terminal_recovery_throttle_floor {
    parameter phase, descent_recovery_active, config_TR.
    if phase = "go_around" or descent_recovery_active {
        return config_TR["GoAround"]["recovery_throttle"].
    }
    return 0.
}

function terminal_energy_throttle {
    parameter energy_margin, measured_speed, config_TR, speed_scale is 1.
    local propulsion_config is config_TR["Propulsion"].
    local energy_request is max(0,(-energy_margin-config_TR["low_energy_margin"])/
        max(propulsion_config["full_assist_energy_deficit"],1)).
    local speed_request is max(0,(propulsion_config["throttle_speed"]*speed_scale-measured_speed)*propulsion_config["speed_assist_gain"]).
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
    local speed_scale is terminal_mass_speed_scale(ship:mass,config_TR).
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
        ship:airspeed >= commit_gate["minimum_speed"]*speed_scale and
        ship:airspeed <= commit_gate["maximum_speed"]*speed_scale and
        abs(roll_for()) <= commit_gate["maximum_bank"] and
        geometry["along_track"] > commit_gate["minimum_along_track"].
    return lex("captured",captured,"glideslope_error",glideslope_error).
}

// This is intentionally a single-sample check. The normal LandingGate has
// already held the approach stable for its configured time before this is
// called; this check decides whether to commit to landing or fly the go-around.
// Pure acceptance test. Geometry alone cannot authorize a preflare handoff:
// FAR must show enough height to reach the shallow sink before final flare.
function terminal_preflare_commit_decision {
    parameter sample, config_TR.
    local commit_config is config_TR["PreflareCommit"].
    local landing_commit is config_TR["LandingCommit"].
    return sample["phase"] = "final" and sample["region"] = "preflare" and
        not sample["high_energy"] and not sample["contact"] and not sample["terrain_pullup"] and sample["gear"] and
        sample["distance"] <= commit_config["distance"] and sample["along_track"] > 0 and
        sample["height"] >= commit_config["minimum_height"] and sample["height"] <= commit_config["maximum_height"] and
        abs(sample["profile_error"]) <= commit_config["maximum_glideslope_error"] and
        abs(sample["cross_track"]) <= commit_config["maximum_cross_track"] and
        abs(sample["heading_error"]) <= commit_config["maximum_heading_error"] and
        abs(sample["bank"]) <= commit_config["maximum_bank"] and
        sample["speed"] >= landing_commit["minimum_speed"]*sample["speed_scale"] and
        sample["speed"] <= landing_commit["maximum_speed"]*sample["speed_scale"] and
        sample["vertical_speed"] >= commit_config["minimum_vertical_speed"] and
        sample["vertical_speed"] <= commit_config["maximum_vertical_speed"] and
        sample["far_valid"] and sample["far_age"] >= 0 and sample["far_age"] <= commit_config["maximum_far_age"] and
        sample["exit_margin"] >= commit_config["minimum_exit_margin"].
}

function terminal_route_preflare_commit_check {
    parameter route.
    local config_TR is AVES["TerminalRoute"].
    local geometry is terminal_route_geometry().
    local profile is calculate_glideslope_profile(geometry["distance"]).
    local clearance is terminal_route_surface_clearance(ship:altitude,runway_altitude,ship:geoposition:terrainheight).
    local closure_speed is sqrt(max(0,ship:velocity:surface:mag^2-ship:verticalspeed^2))*max(0,cos(geometry["heading_error"])).
    local target_vs is -max(closure_speed,config_TR["time_to_go_min_speed"])*AVES["glideslope"]["angle2"].
    local available_acceleration is 0.
    local raw_acceleration is 0.
    if route["pullup_far_valid"] {
        local gravity_value is ship:body:mu/(ship:body:radius+ship:altitude)^2.
        local capability is terminal_pullup_acceleration(route["pullup_far_lift"],ship:mass,
            gravity_value,ship:velocity:surface:mag,ship:verticalspeed,roll_for(),config_TR["PreflarePrediction"]).
        set available_acceleration to capability["usable"].
        set raw_acceleration to capability["raw"].
    }
    local arrest is terminal_sink_arrest_prediction(ship:verticalspeed,target_vs,closure_speed,
        ship:mass,ship:airspeed,config_TR,available_acceleration).
    local exit_margin is clearance-arrest["absolute_arrest_height"]-AVES["Landing"]["flare_start_altitude"].
    local terrain_pullup is false.
    if defined dap and dap:haskey("envelope") {
        if dap["envelope"]:haskey("terrain_state") {
            set terrain_pullup to dap["envelope"]["terrain_state"] = "pullup".
        }
    }
    local sample is lex("phase",route["phase"],"region",profile["region"],
        "high_energy",route["high_energy_final_active"],"contact",ship:status = "LANDED" or ship:status = "SPLASHED",
        "terrain_pullup",terrain_pullup,"gear",gear,"distance",geometry["distance"],"along_track",geometry["along_track"],
        "height",geometry["altitude"],"profile_error",profile["altitude"]-ship:altitude,
        "cross_track",geometry["cross_track"],"heading_error",geometry["heading_error"],"bank",roll_for(),
        "speed",ship:airspeed,"speed_scale",terminal_mass_speed_scale(ship:mass,config_TR),
        "vertical_speed",ship:verticalspeed,"far_valid",route["pullup_far_valid"],
        "far_age",time:seconds-route["pullup_far_time"],"exit_margin",exit_margin).
    return lex("stable",terminal_preflare_commit_decision(sample,config_TR),
        "glideslope_error",ship:altitude-profile["altitude"],"exit_margin",exit_margin,
        "arrest_height",arrest["absolute_arrest_height"],"target_vertical_speed",target_vs,
        "usable_acceleration",available_acceleration,"raw_acceleration",raw_acceleration,
        "clearance",clearance,"closure_speed",closure_speed).
}

// Use the landing controller's existing bounded pitch gain during committed
// preflare too; terminal's gentle tracking controller is no longer the owner.
function terminal_landing_pitch_command {
    parameter desired_vs, measured_vs, landing_config.
    return max(landing_config["minimum_turn_pitch"],min(landing_config["maximum_turn_pitch"],
        (desired_vs-measured_vs)*landing_config["pitch_gain"])).
}

// Keep the configuration whose FAR lift supported commitment. A low-speed
// release is latched by the caller so speed recovery cannot cycle the flaps.
function terminal_landing_config_brake {
    parameter committed_brakes, measured_airspeed, speed_scale, config_TR.
    return committed_brakes and measured_airspeed >
        (config_TR["LandingCommit"]["minimum_speed"]+
         config_TR["PreflareCommit"]["brake_release_speed_margin"])*speed_scale.
}

// Committed preflare continues to follow the same curved reference, using
// the landing pitch controller rather than switching early to a fixed -7 m/s.
function terminal_landing_preflare_guidance {
    parameter route.
    local config_TR is AVES["TerminalRoute"].
    local geometry is terminal_route_geometry().
    local horizontal_speed is sqrt(max(0,ship:velocity:surface:mag^2-ship:verticalspeed^2))*max(0,cos(geometry["heading_error"])).
    terminal_route_refresh_pullup_force(route,config_TR["PreflarePrediction"],ship:status = "FLYING").
    local command is terminal_final_profile_command(geometry["distance"],ship:altitude,
        horizontal_speed,ship:mass,config_TR,AVES["glideslope"],runway_altitude,true).
    local check is terminal_route_preflare_commit_check(route).
    local far_age is -1.
    if route["pullup_far_valid"] { set far_age to time:seconds-route["pullup_far_time"]. }
    set terminal_route_debug["pullup_far_valid"] to route["pullup_far_valid"].
    set terminal_route_debug["pullup_far_age"] to far_age.
    set terminal_route_debug["pullup_far_lift"] to route["pullup_far_lift"].
    set terminal_route_debug["preflare_commit_margin"] to check["exit_margin"].
    set terminal_route_debug["preflare_commit_stable"] to check["stable"].
    set terminal_route_debug["pullup_far_accel"] to check["usable_acceleration"].
    set terminal_route_debug["pullup_far_raw_accel"] to check["raw_acceleration"].
    set terminal_route_debug["landing_preflare_active"] to true.
    // TEAM no longer updates its route after ownership transfers. Keep the
    // logged geometry live during committed preflare instead of freezing it
    // at the handoff point.
    local live_profile is calculate_glideslope_profile(geometry["distance"]).
    set terminal_route_debug["remaining_distance"] to geometry["distance"].
    set terminal_route_debug["along_track"] to geometry["along_track"].
    set terminal_route_debug["cross_track"] to geometry["cross_track"].
    set terminal_route_debug["runway_heading_error"] to geometry["heading_error"].
    set terminal_route_debug["profile_region"] to live_profile["region"].
    set terminal_route_debug["profile_altitude"] to live_profile["altitude"].
    set terminal_route_debug["profile_gradient"] to live_profile["gradient"].
    set terminal_route_debug["profile_error"] to command["profile_error"].
    set terminal_route_debug["desired_vertical_speed"] to command["desired_vs"].
    set terminal_route_debug["preflare_preview_feedforward_vs"] to command["preview_feedforward_vs"].
    set terminal_route_debug["preflare_altitude_correction"] to command["altitude_correction"].
    // The full-delay margin is a request to finish the pull-up, not an
    // immediate abandonment of an otherwise aligned landing. Once requested,
    // keep the shallow-sink command through the final flare. Only this active
    // command earns response-time credit; ordinary profile tracking does not.
    local fresh_force is route["pullup_far_valid"] and far_age >= 0 and
        far_age <= config_TR["PreflareCommit"]["maximum_far_age"].
    if route["landing_pullup_since"] < 0 and fresh_force and
       check["exit_margin"] < config_TR["PreflareCommit"]["minimum_exit_margin"] {
        set route["landing_pullup_since"] to time:seconds.
        flight_log_event("landing_pullup_start","height="+round(geometry["altitude"],1)+
            "|vertical_speed="+round(ship:verticalspeed,2)+"|profile_error="+round(command["profile_error"],1)+
            "|full_delay_margin="+round(check["exit_margin"],1)).
    }
    local pullup_active is route["landing_pullup_since"] >= 0.
    local pullup_margin is check["exit_margin"].
    local remaining_delay is 0.
    if pullup_active {
        set command["desired_vs"] to max(command["desired_vs"],check["target_vertical_speed"]).
        local arrest is terminal_sink_arrest_prediction(ship:verticalspeed,check["target_vertical_speed"],
            check["closure_speed"],ship:mass,ship:airspeed,config_TR,check["usable_acceleration"],
            time:seconds-route["landing_pullup_since"]).
        set remaining_delay to arrest["response_delay"].
        set pullup_margin to check["clearance"]-arrest["absolute_arrest_height"]-AVES["Landing"]["flare_start_altitude"].
    }
    set terminal_route_debug["landing_pullup_active"] to pullup_active.
    set terminal_route_debug["landing_pullup_margin"] to pullup_margin.
    set terminal_route_debug["landing_pullup_response_delay"] to remaining_delay.
    set terminal_route_debug["desired_vertical_speed"] to command["desired_vs"].
    local escape_reason is "".
    if abs(command["profile_error"]) > config_TR["PreflareCommit"]["escape_profile_error"] {
        set escape_reason to "profile_error".
    }
    if abs(roll_for()) > config_TR["PreflareCommit"]["escape_bank"] or
       abs(geometry["heading_error"]) > 15 or abs(geometry["cross_track"]) > 150 {
        set escape_reason to "alignment".
    }
    if fresh_force and pullup_active and pullup_margin < 0 {
        set escape_reason to "pullup_clearance".
    }
    return lex("desired_vs",command["desired_vs"],"unsafe",escape_reason <> "",
        "escape_reason",escape_reason,"pullup_margin",pullup_margin,"response_delay",remaining_delay,
        "profile_error",command["profile_error"],"exit_margin",check["exit_margin"]).
}

function terminal_route_landing_commit_check {
    parameter route.
    if route:haskey("landing_handoff_kind") and route["landing_handoff_kind"] = "preflare" {
        return terminal_route_preflare_commit_check(route).
    }
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
        "turn_choice_time", -100,
        "turn_choice_distance", 0,
        "turn_choice_heading_error", 0,
        "turn_choice_sample_time", -100,
        "turn_force_rates", list(),
        "turn_force_signed_rates", list(),
        "turn_force_losses", list(),
        "turn_force_valid", false,
        "turn_force_time", -100,
        "turn_force_altitude", 0,
        "turn_force_speed", 0,
        "turn_force_brakes", brakes,
        "turn_force_gear", gear,
        "turn_force_config_change_time", -100,
        "turn_force_config_refresh", false,
        "turn_force_pending_rates", list(),
        "turn_force_pending_signed_rates", list(),
        "turn_force_pending_losses", list(),
        "turn_force_pending_index", -1,
        "turn_force_pending_time", -100,
        "turn_force_pending_altitude", 0,
        "turn_force_pending_speed", 0,
        "turn_force_calls_time", -1,
        "turn_force_calls_count", 0,
        "turn_diagnostic_reason", "",
        "turn_diagnostic_time", -100,
        "preflare_pullup_active", false,
        "preflare_anticipation_active", false,
        "preflare_predictive_fraction", 0,
        "preflare_pitch_floor_fraction", 0,
        "preflare_arrest_distance", 0,
        "preflare_profile_deficit_height", 0,
        "preflare_absolute_arrest_height", 0,
        "preflare_clearance_margin", 0,
        "preflare_clearance_used", 0,
        "preflare_target_vertical_speed", 0,
    "preflare_preview_seconds", 0,
    "preflare_preview_distance", 0,
    "preflare_preview_feedforward_vs", 0,
    "preflare_altitude_correction", 0,
        "preflare_response_delay", 0,
        "preflare_vertical_deceleration", 0,
    "pullup_far_valid", false,
    "pullup_far_age", -1,
    "pullup_far_time", -100,
    "pullup_far_altitude", 0,
    "pullup_far_speed", 0,
    "pullup_far_lift", 0,
    "pullup_far_raw_accel", 0,
    "pullup_far_accel", 0,
    "pullup_far_configuration_ut", -100,
    "pullup_far_brakes", brakes,
    "pullup_far_gear", gear,
        "descent_recovery_active", false,
        "descent_recovery_since", -1,
        "descent_recovery_elapsed", 0,
        "descent_tracking_error", 0,
        "descent_arrest_margin", 0,
        "descent_arrest_height", 0,
        "recovery_throttle_floor", 0,
        "propulsion_mode", "idle",
        "propulsion_throttle", 0,
        "dump_lf_floor", config_TR["RecoveryFuelDump"]["minimum_lf"],
        "dump_lf_paired_floor", config_TR["RecoveryFuelDump"]["minimum_lf"],
        "dump_ox_floor", config_TR["RecoveryFuelDump"]["minimum_ox"],
        "fuel_dump", false,
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
        "preflare_stable_since", -1,
        "landing_handoff_kind", "none",
        "landing_pullup_since", -1,
        "go_around_count", 0,
        "go_around_reason", "",
        "high_energy_final_active", false,
        "high_energy_pitch_pid", high_energy_pitch_pid,
        "last_phase_change_time", time:seconds
    ).

    if defined abort_state and abort_state:haskey("active") and abort_state["active"] {
        local dump_config is config_TR["RecoveryFuelDump"].
        set route["dump_lf_floor"] to max(abort_state["lf_reserve"],
            dump_config["minimum_lf"]).
        set route["dump_ox_floor"] to max(abort_state["ox_reserve"],
            dump_config["minimum_ox"]).
    }
    set route["dump_lf_paired_floor"] to terminal_route_paired_lf_dump_floor(
        route["dump_lf_floor"],ship:oxidizer,route["dump_ox_floor"],0,config_TR).

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

// Refresh three of the nine candidates per guidance update. A complete set
// uses one altitude/speed/configuration; the previous set remains available
// during routine refreshes. No trajectory integration is involved.
function terminal_route_refresh_turn_forces {
    parameter route, energy_config.
    if not addons:available("FAR") {
        set route["turn_force_valid"] to false.
        set route["turn_force_pending_index"] to -1.
        return.
    }
    if not addons:far:hassuffix("AEROFORCEAT") {
        set route["turn_force_valid"] to false.
        set route["turn_force_pending_index"] to -1.
        return.
    }
    if brakes <> route["turn_force_brakes"] or gear <> route["turn_force_gear"] {
        local previous_age is -1.
        if route["turn_force_valid"] {
            set previous_age to round(time:seconds-route["turn_force_time"],1).
        }
        flight_log_event("terminal_turn_far_refresh","reason=configuration_change|from_brakes="+
            route["turn_force_brakes"]+"|to_brakes="+brakes+
            "|from_gear="+route["turn_force_gear"]+"|to_gear="+gear+
            "|retained_prediction="+route["turn_force_valid"]+
            "|previous_age="+previous_age).
        set route["turn_force_brakes"] to brakes.
        set route["turn_force_gear"] to gear.
        set route["turn_force_config_change_time"] to time:seconds.
        set route["turn_force_config_refresh"] to true.
        set route["turn_force_pending_index"] to -1.
    }
    // Keep the last completed prediction while FAR's new configuration
    // settles, subject to a bounded age and flight-state drift.
    local altitude_drift is abs(ship:altitude-route["turn_force_altitude"]).
    local speed_drift is abs(ship:airspeed-route["turn_force_speed"]).
    local stale_multiplier is 2.
    local stale_time_multiplier is 2.
    if route["turn_force_config_refresh"] {
        set stale_multiplier to 3.
        set stale_time_multiplier to 4.
    }
    if route["turn_force_pending_index"] >= 0 and (
       time:seconds-route["turn_force_pending_time"] > 1 or
       abs(ship:altitude-route["turn_force_pending_altitude"]) >
           energy_config["turn_model_refresh_altitude"] or
       abs(ship:airspeed-route["turn_force_pending_speed"]) >
           energy_config["turn_model_refresh_speed"]) {
        set route["turn_force_pending_index"] to -1.
    }
    if route["turn_force_valid"] and (
       altitude_drift > stale_multiplier*energy_config["turn_model_refresh_altitude"] or
       speed_drift > stale_multiplier*energy_config["turn_model_refresh_speed"] or
       time:seconds-route["turn_force_time"] >
           stale_time_multiplier*energy_config["turn_model_refresh_time"]) {
        set route["turn_force_valid"] to false.
    }
    // Start a new set after FAR's brake or gear animation has settled.
    if time:seconds-route["turn_force_config_change_time"] <
       energy_config["turn_model_config_settle_time"] { return. }
    if route["turn_force_pending_index"] < 0 and (
       route["turn_force_config_refresh"] or not route["turn_force_valid"] or
       altitude_drift > energy_config["turn_model_refresh_altitude"] or
       speed_drift > energy_config["turn_model_refresh_speed"] or
       time:seconds-route["turn_force_time"] >= energy_config["turn_model_refresh_time"]) {
        set route["turn_force_pending_index"] to 0.
        set route["turn_force_pending_time"] to time:seconds.
        set route["turn_force_pending_rates"] to list().
        set route["turn_force_pending_signed_rates"] to list().
        set route["turn_force_pending_losses"] to list().
        set route["turn_force_pending_altitude"] to ship:altitude.
        set route["turn_force_pending_speed"] to ship:airspeed.
    }
    if route["turn_force_pending_index"] < 0 { return. }
    if route["turn_force_calls_time"] <> time:seconds {
        set route["turn_force_calls_time"] to time:seconds.
        set route["turn_force_calls_count"] to 0.
    }
    local vessel_forward is ship:facing:forevector:normalized.
    local vessel_top is ship:facing:topvector:normalized.
    local vessel_right is vcrs(vessel_top,vessel_forward):normalized.
    local pitch_axis is vcrs(vessel_right,vessel_forward):normalized.
    local gravity_value is ship:body:mu/(ship:body:radius^2).
    until route["turn_force_calls_count"] >= energy_config["turn_model_far_calls_per_update"] or
          route["turn_force_pending_index"] >= 9 {
        local mode_index is route["turn_force_pending_index"].
        local sample_aoa is 12+4*floor(mode_index/3).
        local sample_bank is 30+15*mod(mode_index,3).
        local bank_axis is pitch_axis*cos(sample_bank)+vessel_right*sin(sample_bank).
        local sample_velocity is route["turn_force_pending_speed"]*(
            vessel_forward*cos(sample_aoa)+bank_axis*sin(sample_aoa)).
        local far_force is addons:far:aeroforceat(route["turn_force_pending_altitude"],sample_velocity).
        local metrics is terminal_turn_force_metrics(far_force,vessel_right,vessel_top,
            vessel_forward,sample_aoa,sample_bank,route["turn_force_pending_speed"],gravity_value).
        route["turn_force_pending_rates"]:add(metrics["rate_mass"]).
        route["turn_force_pending_signed_rates"]:add(metrics["signed_rate_mass"]).
        route["turn_force_pending_losses"]:add(metrics["loss_mass"]).
        set route["turn_force_pending_index"] to mode_index+1.
        set route["turn_force_calls_count"] to route["turn_force_calls_count"]+1.
    }
    if route["turn_force_pending_index"] >= 9 {
        local first_valid is not route["turn_force_valid"] or
            route["turn_force_config_refresh"].
        set route["turn_force_rates"] to route["turn_force_pending_rates"].
        set route["turn_force_signed_rates"] to route["turn_force_pending_signed_rates"].
        set route["turn_force_losses"] to route["turn_force_pending_losses"].
        set route["turn_force_altitude"] to route["turn_force_pending_altitude"].
        set route["turn_force_speed"] to route["turn_force_pending_speed"].
        set route["turn_force_valid"] to true.
        set route["turn_force_config_refresh"] to false.
        set route["turn_force_time"] to time:seconds.
        set route["turn_force_pending_index"] to -1.
        if first_valid {
            flight_log_event("terminal_turn_far_sample","valid=true|altitude="+
                round(route["turn_force_altitude"],1)+"|airspeed="+
                round(route["turn_force_speed"],1)+"|brakes="+brakes+
                "|gear="+gear+"|"+terminal_turn_sample_detail(route)).
        }
    }
}

function terminal_route_clear_turn_model {
    parameter route.
    set route["turn_model_valid"] to false.
    set route["turn_model_mode"] to -1.
    set route["turn_model_aoa"] to 0.
    set route["turn_model_bank"] to 0.
    set route["turn_model_rate"] to 0.
    set route["turn_model_radius"] to 0.
    set route["turn_model_loss"] to 0.
    set route["turn_model_required_radius"] to 0.
}

// Report the first rejection and then at most once every 15 seconds while
// the same reason persists. The full signed sample is included only when
// a completed FAR set still produces no usable turn mode.
function terminal_route_log_turn_rejection {
    parameter route, reason, nominal_bank, heading_error, target_distance.
    if reason = route["turn_diagnostic_reason"] and
       time:seconds-route["turn_diagnostic_time"] < 15 { return. }
    set route["turn_diagnostic_reason"] to reason.
    set route["turn_diagnostic_time"] to time:seconds.
    local detail is "reason="+reason+"|phase="+route["phase"]+
        "|altitude="+round(ship:altitude,1)+"|airspeed="+round(ship:airspeed,1)+
        "|mass="+round(ship:mass,2)+"|distance="+round(target_distance,1)+
        "|heading_error="+round(heading_error,1)+"|nominal_bank="+round(nominal_bank,1)+
        "|sample_valid="+route["turn_force_valid"]+
        "|sample_age="+round(time:seconds-route["turn_force_time"],1)+
        "|pending="+route["turn_force_pending_index"]+
        "|brakes="+brakes+"|gear="+gear.
    if reason = "no_usable_rate" {
        set detail to detail+"|sample_altitude="+round(route["turn_force_altitude"],1)+
            "|sample_speed="+round(route["turn_force_speed"],1)+
            "|"+terminal_turn_sample_detail(route).
    }
    flight_log_event("terminal_turn_reject",detail).
}

function terminal_route_choose_turn {
    parameter route, turn_target, target_distance.
    local prior_mode is route["turn_model_mode"].
    if route["phase"] = "final" or route["phase"] = "go_around" or
       ship:altitude < 7000 or not ship:body:atm:exists or
       ship:altitude >= ship:body:atm:height or
       ship:airspeed < 100 {
        terminal_route_clear_turn_model(route).
        if prior_mode >= 0 { flight_log_event("terminal_turn_model","mode=-1|reason=outside_envelope"). }
        return.
    }
    local heading_error is normalized_heading_error(
        heading_between(ship:geoposition,turn_target),compass_for_prograde()).
    local nominal_bank is terminal_route_bank_command(heading_to_target(turn_target),AVES["TerminalRoute"]).
    if abs(nominal_bank) < AVES["TerminalRoute"]["EnergyPlan"]["turn_model_min_bank"] {
        terminal_route_log_turn_rejection(route,"small_turn",nominal_bank,heading_error,target_distance).
        terminal_route_clear_turn_model(route).
        if prior_mode >= 0 { flight_log_event("terminal_turn_model","mode=-1|reason=small_turn"). }
        return.
    }
    terminal_route_refresh_turn_forces(route,AVES["TerminalRoute"]["EnergyPlan"]).
    if not route["turn_force_valid"] {
        terminal_route_log_turn_rejection(route,"far_sample_pending",nominal_bank,heading_error,target_distance).
        terminal_route_clear_turn_model(route).
        if prior_mode >= 0 { flight_log_event("terminal_turn_model","mode=-1|reason=far_sample_pending"). }
        return.
    }
    if route["turn_model_valid"] and route["turn_force_time"] = route["turn_choice_sample_time"] and
       time:seconds-route["turn_choice_time"] < 0.5 and
       abs(target_distance-route["turn_choice_distance"]) < 250 and
       abs(heading_error-route["turn_choice_heading_error"]) < 3 {
        local cached is terminal_turn_sample(route["turn_force_rates"],route["turn_force_losses"],
            prior_mode,ship:mass,ship:airspeed).
        set route["turn_model_rate"] to cached["rate"].
        set route["turn_model_radius"] to cached["radius"].
        set route["turn_model_loss"] to cached["loss"].
        set route["turn_model_required_radius"] to target_distance/
            (2*sin(min(90,max(1,abs(heading_error))))) *
            AVES["TerminalRoute"]["EnergyPlan"]["turn_radius_safety_fraction"].
        return.
    }
    local choice is terminal_turn_choice(route["turn_force_rates"],route["turn_force_losses"],
        ship:airspeed,ship:mass,
        target_distance,heading_error,prior_mode,AVES["TerminalRoute"]["EnergyPlan"]).
    terminal_route_clear_turn_model(route).
    set route["turn_choice_time"] to time:seconds.
    set route["turn_choice_distance"] to target_distance.
    set route["turn_choice_heading_error"] to heading_error.
    set route["turn_choice_sample_time"] to route["turn_force_time"].
    if choice["valid"] {
        set route["turn_diagnostic_reason"] to "".
        set route["turn_model_valid"] to true.
        set route["turn_model_mode"] to choice["mode"].
        set route["turn_model_aoa"] to choice["aoa"].
        set route["turn_model_bank"] to choice["bank"].
        set route["turn_model_rate"] to choice["rate"].
        set route["turn_model_radius"] to choice["radius"].
        set route["turn_model_loss"] to choice["loss"].
        set route["turn_model_required_radius"] to choice["required_radius"].
    } else {
        terminal_route_log_turn_rejection(route,"no_usable_rate",nominal_bank,heading_error,target_distance).
    }
    if route["turn_model_mode"] <> prior_mode {
        local signed_rate_mass is 0.
        if route["turn_model_mode"] >= 0 {
            set signed_rate_mass to route["turn_force_signed_rates"][route["turn_model_mode"]].
        }
        flight_log_event("terminal_turn_model","phase="+route["phase"]+
            "|mode="+route["turn_model_mode"]+"|aoa="+route["turn_model_aoa"]+
            "|bank="+route["turn_model_bank"]+"|rate="+round(route["turn_model_rate"],3)+
            "|signed_rate_mass="+round(signed_rate_mass,2)+
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
    local dump_config is config_TR["RecoveryFuelDump"].

    set route["dump_lf_floor"] to dump_config["minimum_lf"].
    set route["dump_ox_floor"] to dump_config["minimum_ox"].
    if defined abort_state and abort_state:haskey("active") and abort_state["active"] {
        set abort_state to abort_refresh_state(abort_state).
        set route["dump_lf_floor"] to max(abort_state["lf_reserve"],dump_config["minimum_lf"]).
        set route["dump_ox_floor"] to max(abort_state["ox_reserve"],dump_config["minimum_ox"]).
    }
    local atmospheric_descent is false.
    if defined step and step = "TEAM" and ship:body:atm:exists and
       ship:altitude < ship:body:atm:height and ship:verticalspeed < 0 and
       ship:status <> "LANDED" and ship:status <> "SPLASHED" {
        set atmospheric_descent to true.
    }
    local healthy_rapiers is 0.
    if atmospheric_descent { set healthy_rapiers to terminal_route_healthy_rapier_count(). }
    set route["dump_lf_paired_floor"] to terminal_route_paired_lf_dump_floor(
        route["dump_lf_floor"],ship:oxidizer,route["dump_ox_floor"],healthy_rapiers,config_TR).
    local speed_scale is terminal_mass_speed_scale(ship:mass,config_TR).
    set terminal_route_debug["mass_speed_scale"] to speed_scale.
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
    set reference_speed to reference_speed*speed_scale.
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

    local direct_distance is geometry["distance"].
    local direct_profile is calculate_glideslope_profile(direct_distance).
    local recovery_closure_speed is sqrt(max(0,ship:velocity:surface:mag^2-ship:verticalspeed^2)) *
        max(0,cos(geometry["heading_error"])).
    local contact is ship:status = "LANDED" or ship:status = "SPLASHED".
    local preview_enabled is route["phase"] = "final" and
        not route["high_energy_final_active"] and not route["landing_ready"] and not contact.
    local final_profile_command is terminal_final_profile_command(direct_distance,ship:altitude,
        recovery_closure_speed,ship:mass,config_TR,AVES["glideslope"],runway_altitude,preview_enabled).
    local recovery_wanted_vs is final_profile_command["desired_vs"].
    if route["high_energy_final_active"] {
        local recovery_aim_profile is calculate_glideslope_profile(config_TR["HighEnergyFinal"]["aim_distance"]).
        local recovery_high_energy is calculate_high_energy_final_command(geometry["altitude"],direct_distance,
            recovery_closure_speed,recovery_aim_profile["altitude"]-runway_altitude,config_TR["HighEnergyFinal"]).
        set recovery_wanted_vs to recovery_high_energy["desired_vertical_speed"].
    }
    local preflare_end_distance is AVES["glideslope"]["preflare_end"].
    local shallow_profile is calculate_glideslope_profile(preflare_end_distance).
    local preflare_target_vs is -max(recovery_closure_speed,config_TR["time_to_go_min_speed"])*
        shallow_profile["gradient"].
    local prior_far_valid is route["pullup_far_valid"].
    terminal_route_refresh_pullup_force(route,config_TR["PreflarePrediction"],preview_enabled).
    local pullup_acceleration is -1.
    set route["pullup_far_age"] to -1.
    set route["pullup_far_raw_accel"] to 0.
    set route["pullup_far_accel"] to 0.
    if route["pullup_far_valid"] {
        local gravity_value is ship:body:mu/(ship:body:radius+ship:altitude)^2.
        local capability is terminal_pullup_acceleration(route["pullup_far_lift"],ship:mass,
            gravity_value,ship:velocity:surface:mag,ship:verticalspeed,roll_for(),config_TR["PreflarePrediction"]).
        set route["pullup_far_age"] to time:seconds-route["pullup_far_time"].
        set route["pullup_far_raw_accel"] to capability["raw"].
        set route["pullup_far_accel"] to capability["usable"].
        set pullup_acceleration to capability["usable"].
    }
    if prior_far_valid <> route["pullup_far_valid"] {
        flight_log_event("terminal_pullup_capability","far_valid="+route["pullup_far_valid"]+
            "|sample_aoa="+config_TR["PreflarePrediction"]["far_sample_aoa"]+
            "|lift_kn="+round(route["pullup_far_lift"],2)+
            "|raw_acceleration="+round(route["pullup_far_raw_accel"],2)+
            "|usable_acceleration="+round(route["pullup_far_accel"],2)+
            "|mass="+round(ship:mass,2)+"|airspeed="+round(ship:airspeed,1)).
    }
    local preflare_prediction is terminal_sink_arrest_prediction(ship:verticalspeed,
        preflare_target_vs,recovery_closure_speed,ship:mass,ship:airspeed,config_TR,pullup_acceleration).
    local anticipation_fraction is 0.
    if preview_enabled { set anticipation_fraction to final_profile_command["fraction"]. }
    set preflare_prediction["fraction"] to anticipation_fraction.
    // No predictive pitch floor: retain only the existing below-profile
    // feedback floor in terminal_route_fly. A short feedforward preview is
    // enough to anticipate the curve without an independent pitch schedule.
    set preflare_prediction["pitch_floor_fraction"] to 0.
    set preflare_prediction["response_fraction"] to 0.
    set preflare_prediction["preview_fraction"] to anticipation_fraction.
    set route["preflare_preview_seconds"] to final_profile_command["lookahead_seconds"].
    set route["preflare_preview_distance"] to final_profile_command["lookahead_distance"].
    set route["preflare_preview_feedforward_vs"] to final_profile_command["preview_feedforward_vs"].
    set route["preflare_altitude_correction"] to final_profile_command["altitude_correction"].
    // Escape margin uses the absolute height to reach near-zero sink, not the
    // smaller relative profile-deficit height used for preflare anticipation.
    local sink_arrest is terminal_sink_arrest_prediction(ship:verticalspeed,0,
        recovery_closure_speed,ship:mass,ship:airspeed,config_TR,pullup_acceleration).
    local surface_clearance is terminal_route_surface_clearance(ship:altitude,runway_altitude,
        ship:geoposition:terrainheight).
    local sink_arrest_margin is surface_clearance-sink_arrest["absolute_arrest_height"]-
        config_TR["PreflarePrediction"]["minimum_clearance"].
    set route["preflare_predictive_fraction"] to preflare_prediction["fraction"].
    set route["preflare_pitch_floor_fraction"] to preflare_prediction["pitch_floor_fraction"].
    set route["preflare_arrest_distance"] to preflare_prediction["arrest_distance"].
    set route["preflare_profile_deficit_height"] to preflare_prediction["profile_deficit_height"].
    set route["preflare_absolute_arrest_height"] to preflare_prediction["absolute_arrest_height"].
    set route["preflare_clearance_used"] to surface_clearance.
    set route["preflare_clearance_margin"] to surface_clearance-
        preflare_prediction["absolute_arrest_height"]-config_TR["PreflarePrediction"]["minimum_clearance"].
    set route["preflare_target_vertical_speed"] to final_profile_command["desired_vs"].
    set route["preflare_response_delay"] to preflare_prediction["response_delay"].
    set route["preflare_vertical_deceleration"] to preflare_prediction["vertical_deceleration"].
    local preflare_anticipation_active is preflare_prediction["fraction"] > 0.05.
    if preflare_anticipation_active <> route["preflare_anticipation_active"] {
        flight_log_event("terminal_preflare_anticipation","active="+preflare_anticipation_active+
            "|distance="+round(direct_distance,1)+"|altitude="+round(geometry["altitude"],1)+
            "|clearance="+round(surface_clearance,1)+"|vertical_speed="+round(ship:verticalspeed,2)+
            "|target_vertical_speed="+round(final_profile_command["desired_vs"],2)+
            "|preview_seconds="+round(final_profile_command["lookahead_seconds"],2)+
            "|preview_distance="+round(final_profile_command["lookahead_distance"],1)+
            "|profile_error="+round(final_profile_command["profile_error"],1)+
            "|altitude_correction="+round(final_profile_command["altitude_correction"],2)+
            "|fraction="+round(preflare_prediction["fraction"],3)+
            "|pitch_floor_fraction="+round(preflare_prediction["pitch_floor_fraction"],3)+
            "|response_fraction="+round(preflare_prediction["response_fraction"],3)+
            "|preview_fraction="+round(preflare_prediction["preview_fraction"],3)+
            "|profile_deficit_height="+round(preflare_prediction["profile_deficit_height"],1)+
            "|absolute_arrest_height="+round(preflare_prediction["absolute_arrest_height"],1)+
            "|mass="+round(ship:mass,2)+"|airspeed="+round(ship:airspeed,1)).
    }
    set route["preflare_anticipation_active"] to preflare_anticipation_active.
    local descent_recovery_active is terminal_final_descent_recovery(route["phase"],
        direct_profile["altitude"]-ship:altitude,recovery_wanted_vs,ship:verticalspeed,config_TR,
        sink_arrest_margin,surface_clearance,contact).
    if descent_recovery_active {
        if route["descent_recovery_since"] < 0 { set route["descent_recovery_since"] to time:seconds. }
        set route["descent_recovery_elapsed"] to time:seconds-route["descent_recovery_since"].
    } else {
        set route["descent_recovery_since"] to -1.
        set route["descent_recovery_elapsed"] to 0.
    }
    set route["descent_tracking_error"] to recovery_wanted_vs-ship:verticalspeed.
    set route["descent_arrest_margin"] to sink_arrest_margin.
    set route["descent_arrest_height"] to sink_arrest["absolute_arrest_height"].
    if descent_recovery_active <> route["descent_recovery_active"] {
        flight_log_event("terminal_descent_recovery","active="+descent_recovery_active+
            "|distance="+round(direct_distance,1)+"|profile_error="+round(direct_profile["altitude"]-ship:altitude,1)+
            "|vertical_speed="+round(ship:verticalspeed,2)+"|target_vertical_speed="+round(recovery_wanted_vs,2)+
            "|clearance="+round(surface_clearance,1)+
            "|arrest_height="+round(sink_arrest["absolute_arrest_height"],1)+
            "|arrest_margin="+round(sink_arrest_margin,1)+"|response_delay="+round(sink_arrest["response_delay"],2)+
            "|vertical_deceleration="+round(sink_arrest["vertical_deceleration"],2)).
    }
    set route["descent_recovery_active"] to descent_recovery_active.

    local go_around_config is config_TR["GoAround"].
    local unstable_final is abs(geometry["heading_error"]) > go_around_config["maximum_heading_error"] or
        abs(geometry["cross_track"]) > go_around_config["maximum_cross_track"] or
        geometry["along_track"] < go_around_config["passed_threshold"].
    local vertical_critical is sink_arrest_margin <= go_around_config["vertical_critical_arrest_margin"].
    local vertical_unstable is terminal_vertical_go_around_decision(descent_recovery_active,
        direct_distance,route["descent_recovery_elapsed"],sink_arrest_margin,
        surface_clearance,contact,config_TR).
    local lateral_unstable is unstable_final and direct_distance < go_around_config["decision_distance"].
    local powered_vertical_escape is false.
    if vertical_unstable and defined abort_state and abort_state:haskey("active") and abort_state["active"] {
        set powered_vertical_escape to abort_state["engines"]["rapier"]["working"] > 0 and
            ship:liquidfuel > abort_state["lf_reserve"].
    }
    if route["phase"] = "final" and go_around_config["enabled"] and
       surface_clearance > go_around_config["minimum_altitude"] and not contact and
       (vertical_unstable or lateral_unstable) and
       (energy_margin > go_around_config["minimum_reposition_energy"] or powered_vertical_escape) {
        set route["go_around_count"] to route["go_around_count"] + 1.
        set route["go_around_reason"] to "unstable_final".
        if vertical_unstable { set route["go_around_reason"] to "unrecovered_descent". }
        if vertical_unstable and sink_arrest_margin <= go_around_config["vertical_recovery_arrest_margin"] {
            set route["go_around_reason"] to "sink_arrest_margin".
        }
        flight_log_event("terminal_go_around","reason="+route["go_around_reason"]+
            "|distance="+round(direct_distance,1)+"|altitude="+round(geometry["altitude"],1)+
            "|clearance="+round(surface_clearance,1)+
            "|profile_error="+round(direct_profile["altitude"]-ship:altitude,1)+
            "|vertical_speed="+round(ship:verticalspeed,2)+"|tracking_error="+round(route["descent_tracking_error"],2)+
            "|recovery_elapsed="+round(route["descent_recovery_elapsed"],2)+"|arrest_height="+
            round(sink_arrest["absolute_arrest_height"],1)+"|arrest_margin="+round(sink_arrest_margin,1)+
            "|critical="+vertical_critical+"|powered_escape="+powered_vertical_escape).
        terminal_route_change_phase(route,"go_around").
    }

    // Do not re-enter intercept from downwind/base during the terminal phase.
    // This avoids oscillation and keeps the approach stable once the pattern
    // has already committed to downwind or base.
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
        set reference_speed to reference_speed*speed_scale.
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
    set terminal_route_debug["turn_sample_age"] to -1.
    if route["turn_force_valid"] {
        set terminal_route_debug["turn_sample_age"] to time:seconds-route["turn_force_time"].
    }
    set terminal_route_debug["turn_sample_altitude"] to route["turn_force_altitude"].
    set terminal_route_debug["turn_sample_speed"] to route["turn_force_speed"].
    set terminal_route_debug["turn_sample_pending"] to route["turn_force_pending_index"].
    local landing_gate is config_TR["LandingGate"].
    // Final/preflare use speed hysteresis; early descent retains energy control.
    // Use the same activation/reference as this update's energy calculation.
    // Go-around releases immediately even if the phase changed above.
    local brake_decision is terminal_brake_decision(route["airbrake"],route["phase"],speed_active,
        ship:airspeed,energy_margin,config_TR,route["brake_energy_margin"],speed_scale).
    if descent_recovery_active {
        set brake_decision to lex("command",false,"mode","recovery","reason","unrecovered_descent").
    }
    set route["recovery_throttle_floor"] to terminal_recovery_throttle_floor(route["phase"],descent_recovery_active,config_TR).
    set terminal_route_debug["descent_recovery_active"] to descent_recovery_active.
    set terminal_route_debug["descent_recovery_elapsed"] to route["descent_recovery_elapsed"].
    set terminal_route_debug["descent_tracking_error"] to route["descent_tracking_error"].
    set terminal_route_debug["descent_arrest_margin"] to route["descent_arrest_margin"].
    set terminal_route_debug["descent_arrest_height"] to route["descent_arrest_height"].
    set terminal_route_debug["pullup_far_valid"] to route["pullup_far_valid"].
    set terminal_route_debug["pullup_far_age"] to route["pullup_far_age"].
    set terminal_route_debug["pullup_far_lift"] to route["pullup_far_lift"].
    set terminal_route_debug["pullup_far_raw_accel"] to route["pullup_far_raw_accel"].
    set terminal_route_debug["pullup_far_accel"] to route["pullup_far_accel"].
    set terminal_route_debug["recovery_throttle_floor"] to route["recovery_throttle_floor"].
    local propulsion_assist is terminal_energy_throttle(route["energy_margin"],ship:airspeed,
        config_TR,speed_scale).
    local requested_throttle is max(propulsion_assist["command"],route["recovery_throttle_floor"]).
    local propulsion_mode is "idle".
    if requested_throttle > 0.05 { set propulsion_mode to "air". }
    if atmospheric_descent and requested_throttle > 0.05 {
        set propulsion_mode to terminal_descent_rapier_mode(step,route["phase"],requested_throttle,
            atmospheric_descent,surface_clearance,healthy_rapiers,ship:liquidfuel,
            ship:oxidizer,route["dump_lf_floor"],route["dump_ox_floor"],config_TR).
    }
    local commanded_propulsion_throttle is requested_throttle.
    if propulsion_mode = "closed" and
       route["phase"] <> "go_around" and not descent_recovery_active {
        set commanded_propulsion_throttle to min(requested_throttle,
            config_TR["RecoveryFuelDump"]["cc_assist_throttle_limit"]).
    }
    if propulsion_mode <> route["propulsion_mode"] {
        flight_log_event("terminal_propulsion_mode","from="+route["propulsion_mode"]+
            "|to="+propulsion_mode+"|phase="+route["phase"]+
            "|requested_throttle="+round(requested_throttle,3)+
            "|commanded_throttle="+round(commanded_propulsion_throttle,3)+
            "|healthy_rapiers="+healthy_rapiers+
            "|lf="+round(ship:liquidfuel,1)+"|ox="+round(ship:oxidizer,1)+
            "|lf_floor="+round(route["dump_lf_floor"],1)+
            "|lf_paired_floor="+round(route["dump_lf_paired_floor"],1)+
            "|ox_floor="+round(route["dump_ox_floor"],1)).
    }
    set route["propulsion_mode"] to propulsion_mode.
    set route["propulsion_throttle"] to commanded_propulsion_throttle.
    set terminal_route_debug["propulsion_mode"] to propulsion_mode.
    local dump_command is false.
    if propulsion_mode <> "closed" {
        // Dump only LF that is above both the true recovery floor and a
        // bounded reserve for a future partial CC burn. OX remains untouched.
        set dump_command to terminal_fuel_dump_decision(route["phase"],ship:mass,
            ship:liquidfuel,route["dump_lf_paired_floor"],descent_recovery_active,
            atmospheric_descent,surface_clearance,ship:verticalspeed,config_TR).
    }
    if dump_command <> route["fuel_dump"] {
        flight_log_event("terminal_fuel_dump","active="+dump_command+"|phase="+route["phase"]+
            "|mass="+round(ship:mass,2)+"|lf="+round(ship:liquidfuel,1)+"|ox="+round(ship:oxidizer,1)+
            "|lf_floor="+round(route["dump_lf_floor"],1)+
            "|lf_paired_floor="+round(route["dump_lf_paired_floor"],1)+
            "|ox_floor="+round(route["dump_ox_floor"],1)+
            "|speed_scale="+round(speed_scale,3)+"|descent_recovery="+descent_recovery_active+
            "|propulsion_mode="+propulsion_mode).
    }
    set route["fuel_dump"] to dump_command.
    abort_set_fuel_dump(dump_command).
    set terminal_route_debug["dump_lf_floor"] to route["dump_lf_floor"].
    set terminal_route_debug["dump_lf_paired_floor"] to route["dump_lf_paired_floor"].
    set terminal_route_debug["dump_ox_floor"] to route["dump_ox_floor"].
    set terminal_route_debug["fuel_dump_active"] to route["fuel_dump"].
    if brake_decision["command"] <> route["airbrake"] or brake_decision["mode"] <> route["brake_mode"] or
       brake_decision["reason"] <> route["brake_reason"] {
        flight_log_approach_brake(brake_decision["mode"],brake_decision["reason"],brake_decision["command"],
            reference_speed,config_TR["ApproachSpeed"]["brake_on_speed"]*speed_scale,config_TR["ApproachSpeed"]["brake_off_speed"]*speed_scale,energy_margin,
            route["brake_energy_margin"],target_energy,current_turn["extra_distance"],current_turn["reserve"]).
    }
    set route["airbrake"] to brake_decision["command"].
    set route["brake_mode"] to brake_decision["mode"].
    set route["brake_reason"] to brake_decision["reason"].
    set terminal_route_debug["brake_reason"] to route["brake_reason"].
    set terminal_route_debug["brake_mode"] to route["brake_mode"].
    set route["gear"] to direct_distance < landing_gate["gear_distance"] and geometry["altitude"] < landing_gate["gear_altitude"].
    if route["phase"] = "final" and not route["high_energy_final_active"] and
       direct_distance < config_TR["PreflareCommit"]["gear_distance"] and
       geometry["altitude"] < config_TR["PreflareCommit"]["gear_height"] {
        set route["gear"] to true.
    }
    // Do not start the landing handoff timer until the preflare is complete
    // and the aircraft is established on the three-degree shallow segment.
    local landing_stable is route["phase"] = "final" and route["profile_region"] = "shallow" and
        direct_distance < landing_gate["distance"] and
        geometry["altitude"] < landing_gate["altitude"] and geometry["along_track"] > landing_gate["minimum_along_track"] and
        abs(geometry["heading_error"]) < landing_gate["heading_error"] and abs(geometry["cross_track"]) < landing_gate["cross_track"] and
        ship:airspeed > landing_gate["minimum_speed"]*speed_scale and ship:airspeed < landing_gate["maximum_speed"]*speed_scale.
    if landing_stable {
        if route["landing_stable_since"] < 0 { set route["landing_stable_since"] to time:seconds. }
    }else{
        set route["landing_stable_since"] to -1.
    }
    local preflare_commit is lex("stable",false,"exit_margin",0).
    if route["phase"] = "final" and not route["high_energy_final_active"] and
       direct_profile["region"] = "preflare" and direct_distance <= config_TR["PreflareCommit"]["distance"] {
        set preflare_commit to terminal_route_preflare_commit_check(route).
    }
    if preflare_commit["stable"] {
        if route["preflare_stable_since"] < 0 { set route["preflare_stable_since"] to time:seconds. }
    } else { set route["preflare_stable_since"] to -1. }
    local preflare_ready is preflare_commit["stable"] and
        time:seconds-route["preflare_stable_since"] >= config_TR["PreflareCommit"]["stable_time"].
    local shallow_ready is landing_stable and
        time:seconds-route["landing_stable_since"] >= landing_gate["stable_time"].
    local landing_was_ready is route["landing_ready"].
    set route["landing_ready"] to preflare_ready or shallow_ready.
    set route["landing_handoff_kind"] to "none".
    if shallow_ready { set route["landing_handoff_kind"] to "shallow". }
    if preflare_ready { set route["landing_handoff_kind"] to "preflare". }
    set terminal_route_debug["landing_handoff_kind"] to route["landing_handoff_kind"].
    set terminal_route_debug["preflare_commit_stable"] to preflare_commit["stable"].
    set terminal_route_debug["preflare_commit_margin"] to preflare_commit["exit_margin"].
    if route["landing_ready"] and not landing_was_ready {
        flight_log_event("landing_gate_ready","distance="+round(direct_distance,1)+
            "|altitude="+round(geometry["altitude"],1)+"|vertical_speed="+round(ship:verticalspeed,2)+
            "|profile_region="+route["profile_region"]+"|handoff_kind="+route["landing_handoff_kind"]+
            "|exit_margin="+round(preflare_commit["exit_margin"],1)).
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
        local horizontal_groundspeed is sqrt(max(0,ship:velocity:surface:mag^2 - ship:verticalspeed^2)).
        local runway_closure_speed is horizontal_groundspeed * max(0,cos(route["geometry"]["heading_error"])).
        local profile_command is terminal_final_profile_command(distance,ship:altitude,
            runway_closure_speed,ship:mass,config_TR,AVES["glideslope"],runway_altitude,
            not route["landing_ready"] and ship:status <> "LANDED" and ship:status <> "SPLASHED").
        set profile_feedforward_vs to profile_command["feedforward_vs"].
        set profile_altitude_error to profile_command["profile_error"].
        set active_profile_region to profile_command["region"].
        set desired_vertical_speed to profile_command["desired_vs"].
        set route["profile_altitude"] to profile_command["altitude"].
        set route["profile_gradient"] to profile_command["gradient"].
        set route["preflare_preview_seconds"] to profile_command["lookahead_seconds"].
        set route["preflare_preview_distance"] to profile_command["lookahead_distance"].
        set route["preflare_preview_feedforward_vs"] to profile_command["preview_feedforward_vs"].
        set route["preflare_altitude_correction"] to profile_command["altitude_correction"].
        set route["preflare_predictive_fraction"] to profile_command["fraction"].
        set route["preflare_target_vertical_speed"] to desired_vertical_speed.
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
                "|pitch_command="+round(pitch_bias,2)+"|fraction="+round(preflare_pullup_fraction,2)+
                "|predictive_fraction="+round(route["preflare_predictive_fraction"],2)+
                "|pitch_floor_fraction="+round(route["preflare_pitch_floor_fraction"],2)+
                "|arrest_distance="+round(route["preflare_arrest_distance"],1)+
                "|profile_deficit_height="+round(route["preflare_profile_deficit_height"],1)+
                "|absolute_arrest_height="+round(route["preflare_absolute_arrest_height"],1)+
                "|clearance="+round(route["preflare_clearance_used"],1)+
                "|clearance_margin="+round(route["preflare_clearance_margin"],1)+
                "|response_delay="+round(route["preflare_response_delay"],2)+
                "|vertical_deceleration="+round(route["preflare_vertical_deceleration"],2)+
                "|mass="+round(ship:mass,2)+"|airspeed="+round(ship:airspeed,1)).
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

    // Protect the mass-adjusted speed floor and energy budget. Unarrested
    // descent and go-around also require power, even with positive energy.
    local assist is terminal_energy_throttle(route["energy_margin"],ship:airspeed,config_TR,
        terminal_mass_speed_scale(ship:mass,config_TR)).
    local energy_throttle is assist["energy"].
    local speed_throttle is assist["speed"].
    set dapthrottle to assist["command"].
    set dapthrottle to max(dapthrottle,route["recovery_throttle_floor"]).
    if route["propulsion_mode"] = "closed" {
        set dapthrottle to min(dapthrottle,route["propulsion_throttle"]).
    }
    local assist_reason is "idle".
    if energy_throttle > 0 { set assist_reason to "route_deficit". }
    if speed_throttle > energy_throttle { set assist_reason to "speed_floor". }
    if route["recovery_throttle_floor"] > 0 { set assist_reason to "descent_recovery". }
    if route["phase"] = "go_around" { set assist_reason to "go_around". }
    if assist_reason <> route["energy_assist_reason"] {
        flight_log_event("terminal_energy_assist","from="+route["energy_assist_reason"]+"|to="+assist_reason+
            "|margin="+round(route["energy_margin"],1)+"|energy_request="+round(energy_throttle,3)+
            "|speed_request="+round(speed_throttle,3)+"|throttle="+round(dapthrottle,3)).
        set route["energy_assist_reason"] to assist_reason.
    }
    if route["propulsion_mode"] = "closed" and dapthrottle > 0 {
        rapierson().
        togglerapiermode("closed").
    } else if dapthrottle > 0 {
        rapierson().
        togglerapiermode("air").
    } else if defined rapier_mode and rapier_mode = "ClosedCycle" {
        // Return to air mode after the requested descent assist ends; do not
        // keep the vessel in rocket mode while the route is coasting.
        togglerapiermode("air").
    }
    if dapthrottle > 0 {
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
        abs(normalized_heading_error(heading_to_target(runway_start),runway_heading)) < config_TR["final_alignment_heading_tolerance"] and
        abs(normalized_heading_error(heading_to_target(runway_start),compass_for_prograde())) < config_TR["final_alignment_heading_tolerance"] * 5.
    local go_around_climbout is route["phase"] = "go_around" and
        (route["geometry"]["altitude"] < config_TR["GoAround"]["turn_altitude"] or
         ship:verticalspeed < config_TR["GoAround"]["minimum_turn_climb_rate"]).
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
        // The final controller supplies an absolute pitch; ascent trim must
        // not be added again by aerostr.
        set dap["aerostr"]["turn_pitch"] to 0.
        set dap["aerostr"]["turn_roll"] to 0.

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
    set terminal_route_debug["preflare_anticipation_active"] to route["preflare_anticipation_active"].
    set terminal_route_debug["preflare_predictive_fraction"] to route["preflare_predictive_fraction"].
    set terminal_route_debug["preflare_pitch_floor_fraction"] to route["preflare_pitch_floor_fraction"].
    set terminal_route_debug["preflare_arrest_distance"] to route["preflare_arrest_distance"].
    set terminal_route_debug["preflare_profile_deficit_height"] to route["preflare_profile_deficit_height"].
    set terminal_route_debug["preflare_absolute_arrest_height"] to route["preflare_absolute_arrest_height"].
    set terminal_route_debug["preflare_clearance_margin"] to route["preflare_clearance_margin"].
    set terminal_route_debug["preflare_clearance_used"] to route["preflare_clearance_used"].
    set terminal_route_debug["preflare_target_vertical_speed"] to route["preflare_target_vertical_speed"].
    set terminal_route_debug["preflare_preview_seconds"] to route["preflare_preview_seconds"].
    set terminal_route_debug["preflare_preview_distance"] to route["preflare_preview_distance"].
    set terminal_route_debug["preflare_preview_feedforward_vs"] to route["preflare_preview_feedforward_vs"].
    set terminal_route_debug["preflare_altitude_correction"] to route["preflare_altitude_correction"].
    set terminal_route_debug["preflare_response_delay"] to route["preflare_response_delay"].
    set terminal_route_debug["preflare_vertical_deceleration"] to route["preflare_vertical_deceleration"].
    set terminal_route_debug["descent_arrest_margin"] to route["descent_arrest_margin"].
    set terminal_route_debug["descent_arrest_height"] to route["descent_arrest_height"].
    set terminal_route_debug["pullup_far_valid"] to route["pullup_far_valid"].
    set terminal_route_debug["pullup_far_age"] to route["pullup_far_age"].
    set terminal_route_debug["pullup_far_lift"] to route["pullup_far_lift"].
    set terminal_route_debug["pullup_far_raw_accel"] to route["pullup_far_raw_accel"].
    set terminal_route_debug["pullup_far_accel"] to route["pullup_far_accel"].
    set terminal_route_debug["propulsion_mode"] to route["propulsion_mode"].
    set terminal_route_debug["propulsion_throttle"] to route["propulsion_throttle"].
    set terminal_route_debug["dump_lf_floor"] to route["dump_lf_floor"].
    set terminal_route_debug["dump_lf_paired_floor"] to route["dump_lf_paired_floor"].
    set terminal_route_debug["dump_ox_floor"] to route["dump_ox_floor"].
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
