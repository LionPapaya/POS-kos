// Pure terminal-control decisions. Live steering, engines, gear and events
// remain in the mission executive; this module is also exercised by tests.
function pdi_terminal_command {
    parameter offset, surface_velocity, up, clearance, gravity, available, config.
    local horizontal_velocity is surface_velocity-up*vdot(surface_velocity,up).
    local horizontal_offset is offset-up*vdot(offset,up).
    local distance is horizontal_offset:mag.
    local speed is horizontal_velocity:mag.
    local vertical_speed is vdot(surface_velocity,up).
    local vertical_budget is max(0,available-gravity).
    local lateral_limit is min(config["maximum_lateral_acceleration"],sqrt(max(0,available^2-gravity^2))*0.8).
    local target_horizontal_velocity is V(0,0,0).
    if distance > 0.3 {
        local target_speed is min(config["maximum_translation_speed"],sqrt(2*lateral_limit*distance)*0.6).
        // Linear capture close to the target avoids a discontinuous 1 m/s
        // velocity command at the deadband while trying to commit pitch-over.
        set target_speed to min(target_speed,distance*0.35).
        set target_horizontal_velocity to horizontal_offset:normalized*target_speed.
    }
    local lateral is pdi_limit((target_horizontal_velocity-horizontal_velocity)*config["terminal_velocity_gain"],lateral_limit).
    local captured is distance <= config["capture_distance"] and speed <= config["capture_speed"].
    local desired_vs is 0.
    if captured {
        set desired_vs to -min(3,max(0.12,sqrt(max(0,clearance)*0.12))).
    }else{
        local hold_height is max(config["capture_height"],min(config["handover_altitude"],distance*0.4+speed^2/max(0.1,2*lateral_limit))).
        set desired_vs to pdi_clamp((hold_height-clearance)*0.25,-8,3).
    }
    // Never demand a descent that consumes the remaining vertical stopping
    // reserve. This gate uses vertical speed and actual local gravity.
    local safe_descent is sqrt(max(0,2*vertical_budget*max(0,clearance-1)))*0.6.
    set desired_vs to max(desired_vs,-max(0.12,safe_descent)).
    local vertical is gravity+(desired_vs-vertical_speed)*0.9.
    local requested is up*max(0,vertical)+lateral.
    local achieved is pdi_vertical_priority(up,requested,available,config["maximum_terminal_tilt"]).
    return lex("acceleration",achieved,"desired_vs",desired_vs,"distance",distance,"horizontal_speed",speed,
        "captured",captured,"saturated",requested:mag > available or (achieved-requested):mag > 0.01,
        "vertical_margin",available-gravity).
}

function pdi_flip_gate {
    parameter clearance, horizontal_speed, vertical_speed, distance, upright_error, angular_rate, landed, config.
    // Once this gate is accepted, the executive latches engine cutoff.
    // No powered arrest or automatic re-ignition is permitted after pitch-over.
    return (landed or clearance <= config["flip_clearance"]) and
        horizontal_speed <= config["flip_horizontal_speed"] and
        abs(vertical_speed) <= config["flip_vertical_speed"] and
        distance <= config["capture_distance"] and
        upright_error <= config["flip_upright_error"] and angular_rate < 2.
}
