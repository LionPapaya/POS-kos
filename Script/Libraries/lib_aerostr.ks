// Libraries/lib_aerostr.ks
// Purpose: high-level aerodynamic steering helpers and AoA/bank management.
// - Computes bank/aoa targets for turns (`aeroturn`).
// - Provides `aerostr()` and `aoa_bank_management()` to populate `dap` steering targets.
// Notes: non-functional comments only.
function aeroturn {
    parameter desired_heading.     // The desired heading in degrees
    parameter turn_side is "calc". // left / right / auto
    parameter aoa is 20.           // fixed target AoA
    parameter radius is "default". // turn radius or default steering

    local cur_heading is compass_for().
    local heading_error to desired_heading - cur_heading.

    // Normalize error to -180..180
    until abs(heading_error) <= 180 {
        if heading_error > 180  { set heading_error to heading_error - 360. }
        if heading_error < -180 { set heading_error to heading_error + 360. }
    }

    local bank_angle is 0.

    // If radius is the string "default" then use the configured default radius value
    // from AVES. The user requested that default behavior be a fixed radius rather than
    // the previous sigmoid logic.
    if radius = "default" {
        set radius to AVES["Aeroturn_Radius"].
    }

    // ----------------------------------------------------
    // RADIUS-BASED TURN: compute required bank from v^2/(g * R)
    // If radius is invalid (<= 0) fall back to the sigmoid-style tanh approximation.
    // ----------------------------------------------------
    if radius <= 0 {
        // fallback: smooth sigmoid-style bank proportional to heading error
        set bank_angle to 40 * tanh_approx(0.05 * heading_error).

        // limit bank
        if bank_angle > AVES["MaxRoll"]  { set bank_angle to AVES["MaxRoll"]. }
        if bank_angle < -AVES["MaxRoll"] { set bank_angle to -AVES["MaxRoll"]. }

    } else {
        // local gravity (m/s^2)
        local gravity is SHIP:BODY:MU / (SHIP:BODY:RADIUS ^ 2).


        // required bank in degrees (arctan returns radians)
        local req_bank is arctan((ship:airspeed * ship:airspeed) / (gravity * radius)) * (180 / constant:pi).

        // choose sign from heading error (positive: turn right)
        if heading_error > 0 { set req_bank to abs(req_bank). }
        else                 { set req_bank to -abs(req_bank). }

        // Limit by aircraft roll capability
        if req_bank > AVES["MaxRoll"]  { set req_bank to AVES["MaxRoll"]. }
        if req_bank < -AVES["MaxRoll"] { set req_bank to -AVES["MaxRoll"]. }

        set bank_angle to req_bank.
    }

    // ----------------------------------------------------
    // TURN DIRECTION OVERRIDE
    // ----------------------------------------------------
    if turn_side = "calc" {
        if heading_error > 0  { set turn_side to "right". }
        else                  { set turn_side to "left". }
    }

    if turn_side = "right" or turn_side = "clockwise" {
        set bank_angle to -abs(bank_angle).
    } else if turn_side = "left" or turn_side = "Anticlockwise" {
        set bank_angle to abs(bank_angle).
    }

    // ----------------------------------------------------
    // APPLY CONTROL OUTPUT (NO GUIDANCE ADDED)
    // ----------------------------------------------------
    set dap["aoa"]["target_aoa"] to aoa.
    set dap["aoa"]["target_bank"] to bank_angle.
}
function aerostr{
  if not(defined turn_roll){
    set turn_roll to 0.
  }
   set dap["aerostr"]["aerostr_pitch"] to (dap["aerostr"]["distance_pitch"]+dap["aerostr"]["turn_pitch"]).
   set dap["aerostr"]["aerostr_heading"] to dap["aerostr"]["turn_heading"].
    set dap["aerostr"]["aerostr_Roll"] to dap["aerostr"]["turn_roll"].

  checksrt_inputs(dap["aerostr"]["aerostr_pitch"],dap["aerostr"]["aerostr_heading"],dap["aerostr"]["aerostr_Roll"]).  
  set dap["aerostr"]["targetPitch"] to dap["aerostr"]["aerostr_pitch"].
  set dap["aerostr"]["targetDirection"] to dap["aerostr"]["aerostr_heading"].
  set dap["aerostr"]["targetRoll"] to dap["aerostr"]["aerostr_Roll"].
}
function checksrt_inputs{
  declare parameter input_pitch, input_heading, input_roll.
  local heading_err to input_heading - compass_for_prograde().
  if input_roll < -AVES["MaxRoll"]{
    set dap["aerostr"]["aerostr_Roll"] to -AVES["MaxRoll"].
  }
  if input_roll > AVES["MaxRoll"]{
    set dap["aerostr"]["aerostr_Roll"] to AVES["MaxRoll"].
  }
  if roll_for() < -AVES["MaxRoll"]{
    set dap["aerostr"]["aerostr_Roll"] to -AVES["MaxRoll"].
  }
  if roll_for() > AVES["MaxRoll"]{
    set dap["aerostr"]["aerostr_Roll"] to AVES["MaxRoll"].
  }
  if heading_err > AVES["MaxYaw"]{
    set dap["aerostr"]["aerostr_heading"] to compass_for_prograde() +AVES["MaxYaw"].
  }
  if heading_err < -AVES["MaxYaw"]{
    set dap["aerostr"]["aerostr_heading"] to compass_for_prograde() -AVES["MaxYaw"].
  }
  if input_pitch > AVES["MaxPitch"]{
    set dap["aerostr"]["aerostr_pitch"] to AVES["MaxPitch"].
  }
  if input_pitch < AVES["MinPitch"]{
    set dap["aerostr"]["aerostr_pitch"] to AVES["MinPitch"].
  }
  


}
function calc_vvdot {
    parameter distance.
    parameter speed.
    parameter t_alt.
    parameter alt_.
    if speed = 0 {
        return 0.

    }
    local t is distance / speed.
    set t to max( t/AVES["TEAM_vvdot_t"],AVES["TEAM_vvdot_t"]).
    
    local vvdot is (t_alt - alt_) / t.
    return vvdot.
}
// Return the continuously differentiable final-approach profile.  The steep
// line is joined to a three-degree shallow glide with a cubic Hermite curve,
// so both altitude and flight-path angle are continuous through preflare.
// The shallow aimpoint is beyond the runway threshold; this leaves room to
// establish the shallow glide before the height-based final flare begins.
function calculate_glideslope_profile {
    parameter distance,rnw_alt is runway_altitude, gs is AVES["glideslope"].
    local steep_gradient is gs["angle1"].
    local shallow_gradient is gs["angle2"].
    local preflare_start is gs["preflare_start"].
    local preflare_end is gs["preflare_end"].

    if distance >= preflare_start {
        return lex(
            "altitude",((distance - gs["target1"]) * steep_gradient)+rnw_alt,
            "gradient",steep_gradient,
            "region","steep"
        ).
    }
    if distance <= preflare_end {
        return lex(
            "altitude",((distance + gs["shallow_aimpoint"]) * shallow_gradient)+rnw_alt,
            "gradient",shallow_gradient,
            "region","shallow"
        ).
    }

    local span is preflare_start - preflare_end.
    local t is (distance - preflare_end) / span.
    local shallow_altitude is (preflare_end + gs["shallow_aimpoint"]) * shallow_gradient.
    local steep_altitude is (preflare_start - gs["target1"]) * steep_gradient.
    local profile_height is
        (2*t^3 - 3*t^2 + 1) * shallow_altitude +
        (t^3 - 2*t^2 + t) * span * shallow_gradient +
        (-2*t^3 + 3*t^2) * steep_altitude +
        (t^3 - t^2) * span * steep_gradient.
    local altitude_derivative is
        (6*t^2 - 6*t) * shallow_altitude +
        (3*t^2 - 4*t + 1) * span * shallow_gradient +
        (-6*t^2 + 6*t) * steep_altitude +
        (3*t^2 - 2*t) * span * steep_gradient.
    return lex(
        "altitude",profile_height+rnw_alt,
        "gradient",altitude_derivative/span,
        "region","preflare"
    ).
}
function calculate_glideslope_alt {
    parameter distance,rnw_alt is runway_altitude, gs is AVES["glideslope"].
    return calculate_glideslope_profile(distance,rnw_alt,gs)["altitude"].
}
// Convert the desired flight-path vertical speed into an absolute pitch trim,
// then add immediate closed-loop correction for sink-rate error.  Keeping the
// trim out of an integral controller prevents the steep-glide nose-down trim
// from taking most of the preflare to unwind.
function calculate_glideslope_pitch_command {
    parameter desired_vertical_speed, actual_vertical_speed, surface_speed_value,
        trim_aoa, vertical_speed_gain, minimum_pitch, maximum_pitch.
    local protected_speed is max(abs(surface_speed_value),1).
    local path_ratio is max(-1,min(1,desired_vertical_speed/protected_speed)).
    local path_pitch is arcsin(path_ratio) + trim_aoa.
    local sink_correction is (desired_vertical_speed - actual_vertical_speed) * vertical_speed_gain.
    local raw_pitch_command is path_pitch + sink_correction.
    local pitch_command is max(minimum_pitch,min(maximum_pitch,raw_pitch_command)).
    return lex(
        "command",pitch_command,
        "feedforward",path_pitch,
        "correction",sink_correction,
        "saturated",pitch_command <> raw_pitch_command
    ).
}
function calculate_distance_from_alt {
    parameter alt_, rnw_alt is runway_altitude, gs is AVES["glideslope"].

    local alt_diff is alt_ - rnw_alt.
    local shallow_boundary is (gs["preflare_end"] + gs["shallow_aimpoint"]) * gs["angle2"].
    local steep_boundary is (gs["preflare_start"] - gs["target1"]) * gs["angle1"].
    if alt_diff <= shallow_boundary {
        return (alt_diff / gs["angle2"]) - gs["shallow_aimpoint"].
    }
    if alt_diff >= steep_boundary {
        return (alt_diff / gs["angle1"]) + gs["target1"].
    }

    // The Hermite segment is monotonic but has no useful simple inverse.
    // A bounded bisection keeps this helper consistent with the real profile.
    local low_distance is gs["preflare_end"].
    local high_distance is gs["preflare_start"].
    local iterations is 0.
    until iterations >= 18 {
        local middle_distance is (low_distance + high_distance) / 2.
        if calculate_glideslope_alt(middle_distance,rnw_alt,gs) < alt_ {
            set low_distance to middle_distance.
        }else{
            set high_distance to middle_distance.
        }
        set iterations to iterations + 1.
    }
    return (low_distance + high_distance) / 2.
}
function calculate_vertical_glideslope_distance {
    parameter distance is calcdistance_m(ship:geoposition,runway_start),alt_ is ship:altitude, gs is AVES["glideslope"].
    return calculate_glideslope_alt(distance)- alt_.
}
function aggressive_overcorrect_for_prograde {
    parameter target_heading. // Target heading for runway_start alignment

    // Monitor the current prograde vector heading
    local prograde_heading is compass_for_prograde().

    // Calculate the difference between current heading and prograde
    local heading_difference is target_heading - prograde_heading.

    // More aggressive overcorrection if the prograde is not aligned with the target heading
    if abs(heading_difference) > 1 {
        // If the prograde is significantly to the left, turn right more aggressively
        if heading_difference > 0 {
            set dap["aerostr"]["turn_heading"] to compass_for() + 10.  // Larger adjustment
        }
        // If the prograde is significantly to the right, turn left more aggressively
        if heading_difference < 0 {
            set dap["aerostr"]["turn_heading"] to compass_for() - 10.  // Larger adjustment
        }
        log_status("Aggressive overcorrection for prograde alignment: heading difference: " + heading_difference).
    } else {
        // If the heading difference is small, maintain the target heading
        set dap["aerostr"]["turn_heading"] to runway_heading.
    }
}
function aoa_bank_management {
    parameter target_aoa, target_bank.
    parameter base_pitch is  pitch_for_prograde().
    parameter css is false.


    local theta to (target_bank / 90) * (constant:pi / 2).

    local aoa_pitch to target_aoa * cos(theta*constant:radtodeg).
    local aoa_yaw to target_aoa * sin(theta*constant:radtodeg) .

    local new_pitch to base_pitch + aoa_pitch.
    local new_yaw to compass_for_prograde() - aoa_yaw.

    if not(css){
        set dap["aoa"]["aoa_pitch"] to new_pitch.
        set dap["aoa"]["aoa_yaw"] to new_yaw.
        set dap["aoa"]["aoa_roll"] to target_bank.
    }else{
        set dap["css"]["pitch_out"] to new_pitch.
        set dap["css"]["yaw_out"] to new_yaw.
        set dap["css"]["roll_out"] to target_bank.
    }
}
