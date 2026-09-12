// Pure, body-agnostic mathematics for the live vacuum ascent executive.
// Keep this file free of vessel reads, GUI calls, and flight logging so its
// functions execute unchanged in the offline kOS runtime tests.

function vacuum_ascent_clamp {
    parameter unclamped_value, minimum_value, maximum_value.
    return max(minimum_value,min(unclamped_value,maximum_value)).
}

// Return the northbound launch heading for a requested inclination, or -1
// when the launch latitude cannot reach that orbital plane directly.
function vacuum_ascent_launch_heading {
    parameter requested_inclination, launch_site_latitude.
    local launch_latitude_cosine is cos(launch_site_latitude).
    if abs(launch_latitude_cosine) < 0.0001 { return -1. }
    local launch_heading_sine is cos(requested_inclination)/launch_latitude_cosine.
    if abs(launch_heading_sine) > 1 { return -1. }
    local computed_launch_heading is arcsin(launch_heading_sine).
    until computed_launch_heading >= 0 and computed_launch_heading < 360 {
        if computed_launch_heading < 0 { set computed_launch_heading to computed_launch_heading+360. }
        if computed_launch_heading >= 360 { set computed_launch_heading to computed_launch_heading-360. }
    }
    return computed_launch_heading.
}

// Blend from a protected climb to the horizontal acceleration pitch.  A low
// vertical-speed measurement always wins over the nominal pitch schedule.
function vacuum_ascent_pitch_target {
    parameter surface_clearance, climb_vertical_speed, climb_horizontal_speed, predicted_apoapsis, desired_apoapsis, ascent_config.
    if surface_clearance < ascent_config["pitch_start_clearance"] { return 90. }
    local speed_progress is vacuum_ascent_clamp(climb_horizontal_speed/max(1,ascent_config["prograde_blend_speed"]),0,1).
    local apoapsis_progress is vacuum_ascent_clamp(predicted_apoapsis/max(1,desired_apoapsis),0,1).
    // Either enough orbital-speed build or a near-target apoapsis justifies
    // the shallow end of the schedule.  Do not cap either contribution below
    // one: that would strand the vehicle at a needlessly steep pitch.
    local progress is max(speed_progress,apoapsis_progress).
    local commanded_pitch is ascent_config["initial_pitch"]-(ascent_config["initial_pitch"]-ascent_config["terminal_pitch"])*progress.
    if climb_vertical_speed < ascent_config["minimum_vertical_speed"] {
        set commanded_pitch to max(commanded_pitch,ascent_config["vertical_recovery_pitch"]).
    }
    return vacuum_ascent_clamp(commanded_pitch,ascent_config["terminal_pitch"],90).
}

// A landed craft need only be nose-up enough for the brief RAPIER kick to
// unload its tail/rear wheel. Vertical alignment is still commanded after
// this gate, but it is not required before liftoff.
function vacuum_ascent_liftoff_pitch_ready {
    parameter measured_nose_up_pitch, required_liftoff_pitch.
    return measured_nose_up_pitch >= max(0,required_liftoff_pitch).
}

function vacuum_ascent_circular_speed {
    parameter orbit_radius, body_gravitational_parameter.
    if orbit_radius <= 0 or body_gravitational_parameter <= 0 { return 0. }
    return sqrt(body_gravitational_parameter/orbit_radius).
}
