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
        log "Error: Division by zero in calc_vvdot" to log.txt.
        log "Distance: " + distance + ", Speed: " + speed + ", Target altitude: " + t_alt + ", Current altitude: " + alt_ to log.txt.
        return 0.

    }
    local t is distance / speed.
    set t to max( t/AVES["TEAM_vvdot_t"],AVES["TEAM_vvdot_t"]).
    
    local vvdot is (t_alt - alt_) / t.
    return vvdot.
}
function calculate_glideslope_alt {
    parameter distance,rnw_alt is runway_altitude, gs is AVES["glideslope"].//angle1, target1, switch12, angle2.
    
    if distance >= gs["switch12"] {
        return ((distance - gs["target1"]) * gs["angle1"])+rnw_alt.
    }else {
        return (distance *  gs["angle2"])+rnw_alt.
    }
}
function calculate_distance_from_alt {
    parameter alt_, rnw_alt is runway_altitude, gs is AVES["glideslope"]. // angle1, target1, switch12, angle2.

    // Calculate the altitude difference
    local alt_diff is alt_ - rnw_alt.

    // Determine which segment of the glideslope the altitude falls into
    if alt_diff >= gs["switch12"] * gs["angle1"] {
        return (alt_diff / gs["angle1"]) + gs["target1"].
    } else {
        return alt_diff / gs["angle2"].
    }
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
