// Pure terminal-control decisions. Live steering, engines, gear and events
// remain in the mission executive; this module is also exercised by tests.
function pdi_terminal_command {
    parameter offset, surface_velocity, terminal_up, clearance, gravity, available, terminal_config.
    local horizontal_velocity is surface_velocity-terminal_up*vdot(surface_velocity,terminal_up).
    local horizontal_offset is offset-terminal_up*vdot(offset,terminal_up).
    local terminal_distance is horizontal_offset:mag.
    local speed is horizontal_velocity:mag.
    local vertical_speed is vdot(surface_velocity,terminal_up).
    local vertical_budget is max(0,available-gravity).
    // Target speeds must use the same lateral authority that the final tilt
    // limiter can actually deliver.  Otherwise low-gravity bodies plan a
    // braking distance for 2 m/s^2 while a 25-degree command supplies only a
    // small fraction of that acceleration.
    local lateral_limit is min(terminal_config["maximum_lateral_acceleration"],sqrt(max(0,available^2-gravity^2))*0.8).
    set lateral_limit to min(lateral_limit,max(0.01,gravity*tan(terminal_config["maximum_terminal_tilt"]))).
    local target_horizontal_velocity is V(0,0,0).
    if terminal_distance > 0.3 {
        local target_speed is min(terminal_config["maximum_translation_speed"],sqrt(2*lateral_limit*terminal_distance)*0.6).
        // Linear capture close to the target avoids a discontinuous 1 m/s
        // velocity command at the deadband while trying to commit pitch-over.
        set target_speed to min(target_speed,terminal_distance*0.35).
        set target_horizontal_velocity to horizontal_offset:normalized*target_speed.
    }
    local lateral is pdi_limit((target_horizontal_velocity-horizontal_velocity)*terminal_config["terminal_velocity_gain"],lateral_limit).
    local captured is terminal_distance <= terminal_config["capture_distance"] and speed <= terminal_config["capture_speed"].
    local desired_vs is 0.
    local hold_height is 0.
    if captured {
        set desired_vs to -min(3,max(0.12,sqrt(max(0,clearance)*0.12))).
    }else{
        // capture_height is a ceiling for the lateral-braking hold, not a
        // hard altitude floor.  Flight 63 reached the floor with residual
        // translation error and then consumed its reserve hovering there.
        // Let the hold height contract with the remaining lateral energy so
        // the vehicle keeps descending while it completes that translation.
        set hold_height to min(terminal_config["capture_height"],min(terminal_config["handover_altitude"],terminal_distance*0.4+speed^2/max(0.1,2*lateral_limit))).
        // Terminal translation may arrest descent to shed genuinely large
        // lateral energy, but it must never climb to regain the hold height.
        set desired_vs to pdi_clamp((hold_height-clearance)*0.25,-terminal_config["maximum_terminal_descent_speed"],0).
    }
    if clearance <= terminal_config["ground_commit_clearance"] {
        // In the final metres, use a deliberate low-speed descent.  The
        // executive cuts thrust as soon as the ground-commit envelope holds.
        set desired_vs to -terminal_config["ground_commit_descent_speed"].
    } else {
        // Never demand a descent that consumes the remaining vertical
        // stopping reserve. This gate uses vertical speed and local gravity.
        local safe_descent is sqrt(max(0,2*vertical_budget*max(0,clearance-1)))*0.6.
        set desired_vs to max(desired_vs,-max(0.12,safe_descent)).
    }
    local vertical is gravity+(desired_vs-vertical_speed)*0.9.
    local requested is terminal_up*max(0,vertical)+lateral.
    local achieved is pdi_vertical_priority(terminal_up,requested,available,terminal_config["maximum_terminal_tilt"]).
    return lex("acceleration",achieved,"desired_vs",desired_vs,"distance",terminal_distance,"horizontal_speed",speed,
        "captured",captured,"saturated",requested:mag > available or (achieved-requested):mag > 0.01,
        "vertical_margin",available-gravity,"hold_height",hold_height,
        "descent_committed",not captured and desired_vs < -0.12).
}

function pdi_flip_gate {
    parameter clearance, horizontal_speed, vertical_speed, terminal_distance, upright_error, angular_rate, landed, terminal_config.
    // Once this gate is accepted, the executive latches engine cutoff.
    // No powered arrest or automatic re-ignition is permitted after pitch-over.
    return (landed or clearance <= terminal_config["flip_clearance"]) and
        horizontal_speed <= terminal_config["flip_horizontal_speed"] and
        abs(vertical_speed) <= terminal_config["flip_vertical_speed"] and
        terminal_distance <= terminal_config["capture_distance"] and
        upright_error <= terminal_config["flip_upright_error"] and angular_rate < 2.
}

function pdi_ground_commit_gate {
    parameter clearance, horizontal_speed, vertical_speed, terminal_distance, angular_rate, terminal_config.
    // Relax upright/position capture at the last metres: pitch-over is the
    // next phase, while speed and rotation limits still protect touchdown.
    return clearance <= terminal_config["ground_commit_clearance"] and
        vertical_speed <= -terminal_config["ground_commit_min_vertical_speed"] and
        vertical_speed >= -terminal_config["ground_commit_max_vertical_speed"] and
        horizontal_speed <= terminal_config["ground_commit_max_horizontal_speed"] and
        terminal_distance <= terminal_config["ground_commit_max_distance"] and
        angular_rate < terminal_config["ground_commit_max_angular_rate"].
}

function pdi_terminal_aligned_throttle {
    parameter requested_throttle, alignment_error, terminal_config.
    // A translational command can reverse faster than the vehicle can turn.
    // Taper thrust through the useful projection hemisphere, and cut it once
    // the current attitude would accelerate opposite the requested vector.
    local full_error is terminal_config["terminal_alignment_full_thrust"].
    local cutoff_error is terminal_config["terminal_alignment_thrust_cutoff"].
    local alignment_factor is pdi_clamp((cutoff_error-alignment_error)/max(0.1,cutoff_error-full_error),0,1).
    return pdi_clamp(requested_throttle,0,1)*alignment_factor.
}
