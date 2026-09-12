// Pure, body-agnostic mathematics for the live vacuum ascent executive.
// Keep this file free of vessel reads, GUI calls, and flight logging so its
// functions execute unchanged in the offline kOS runtime tests.

function vacuum_ascent_clamp {
    parameter value, lower, upper.
    return max(lower,min(value,upper)).
}

// Return the northbound launch heading for a requested inclination, or -1
// when the launch latitude cannot reach that orbital plane directly.
function vacuum_ascent_launch_heading {
    parameter target_inclination, latitude.
    local latitude_cosine is cos(latitude).
    if abs(latitude_cosine) < 0.0001 { return -1. }
    local heading_sine is cos(target_inclination)/latitude_cosine.
    if abs(heading_sine) > 1 { return -1. }
    local heading is arcsin(heading_sine).
    until heading >= 0 and heading < 360 {
        if heading < 0 { set heading to heading+360. }
        if heading >= 360 { set heading to heading-360. }
    }
    return heading.
}

// Blend from a protected climb to the horizontal acceleration pitch.  A low
// vertical-speed measurement always wins over the nominal pitch schedule.
function vacuum_ascent_pitch_target {
    parameter clearance, vertical_speed, horizontal_speed, predicted_apoapsis, target_apoapsis, config.
    if clearance < config["pitch_start_clearance"] { return 90. }
    local speed_progress is vacuum_ascent_clamp(horizontal_speed/max(1,config["prograde_blend_speed"]),0,1).
    local apoapsis_progress is vacuum_ascent_clamp(predicted_apoapsis/max(1,target_apoapsis),0,1).
    // Either enough orbital-speed build or a near-target apoapsis justifies
    // the shallow end of the schedule.  Do not cap either contribution below
    // one: that would strand the vehicle at a needlessly steep pitch.
    local progress is max(speed_progress,apoapsis_progress).
    local target_pitch is config["initial_pitch"]-(config["initial_pitch"]-config["terminal_pitch"])*progress.
    if vertical_speed < config["minimum_vertical_speed"] {
        set target_pitch to max(target_pitch,config["vertical_recovery_pitch"]).
    }
    return vacuum_ascent_clamp(target_pitch,config["terminal_pitch"],90).
}

function vacuum_ascent_circular_speed {
    parameter radius, mu.
    if radius <= 0 or mu <= 0 { return 0. }
    return sqrt(mu/radius).
}
