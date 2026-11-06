// Passive synthetic function benchmark; no control or flight execution.

if defined dap or defined main_step or defined AVES { print "Benchmark needs a fresh idle CPU; reboot first.". until false { wait 1. } }

set CONFIG:IPU to 2000.

RUNONCEPATH("0:/Libraries/lib_math.ks").

RUNONCEPATH("0:/Libraries/lib_navigation.ks").

RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").

RUNONCEPATH("0:/Libraries/lib_aerostr.ks").

RUNONCEPATH("0:/Libraries/lib_navball.ks").

local bench_vessel is lex("facing",r(10,20,30),"velocity",lex("surface",v(100,200,300)),"north",r(0,0,0),"up",r(90,0,0)).

local bench_gs is lex("angle1",0.3,"angle2",0.0524,"preflare_start",2000,"preflare_end",500,"target1",0,"shallow_aimpoint",300).

global AVES is lex("TEAM_vvdot_t",5).

local bench_log is "0:/pos_function_bench_20261106.log".

log "START|"+time:seconds to bench_log.

function bench_original_positive_difference {
    parameter value1.
    parameter value2.

    // Calculate the difference and ensure it is positive
    local difference is abs(value1 - value2).

    return difference.
}

function bench_candidate_positive_difference {
parameter value1,value2. return abs(value1-value2).
}

function bench_run_original_positive_difference { parameter bench_case. return bench_original_positive_difference(bench_case[0],bench_case[1]). }

function bench_run_candidate_positive_difference { parameter bench_case. return bench_candidate_positive_difference(bench_case[0],bench_case[1]). }

function bench_run_production_positive_difference { parameter bench_case. return positive_difference(bench_case[0],bench_case[1]). }

FUNCTION bench_original_vecYZ {
	DECLARE PARAMETER input.	//	Expects a vector
	LOCAL output IS V(input:X, input:Z, input:Y).
	RETURN output.
}

FUNCTION bench_candidate_vecYZ {
parameter input. return v(input:x,input:z,input:y).
}

function bench_run_original_vecYZ { parameter bench_case. return bench_original_vecYZ(bench_case[0]). }

function bench_run_candidate_vecYZ { parameter bench_case. return bench_candidate_vecYZ(bench_case[0]). }

function bench_run_production_vecYZ { parameter bench_case. return vecYZ(bench_case[0]). }

function bench_original_time_to_alt {
  parameter cur_alt.
  parameter vv_dot.
  parameter tgt_alt.

  if vv_dot = 0 {
    return 0. // No movement, altitude won't change
  }

  if (tgt_alt > cur_alt and vv_dot < 0) or (tgt_alt < cur_alt and vv_dot > 0) {
    return 0. // Moving away from the target altitude
  }

  return (tgt_alt - cur_alt) / vv_dot.
}

function bench_candidate_time_to_alt {
parameter cur_alt,vv_dot,tgt_alt.
if vv_dot = 0 or (tgt_alt > cur_alt and vv_dot < 0) or (tgt_alt < cur_alt and vv_dot > 0) { return 0. }
return (tgt_alt-cur_alt)/vv_dot.
}

function bench_run_original_time_to_alt { parameter bench_case. return bench_original_time_to_alt(bench_case[0],bench_case[1],bench_case[2]). }

function bench_run_candidate_time_to_alt { parameter bench_case. return bench_candidate_time_to_alt(bench_case[0],bench_case[1],bench_case[2]). }

function bench_run_production_time_to_alt { parameter bench_case. return time_to_alt(bench_case[0],bench_case[1],bench_case[2]). }

function bench_original_avg{
  parameter a is list().
  parameter weight is "none".
  local sum is 0.
  local count is 0.
  for b in range(0,a:length-1){
    if weight = "none"{
      set sum to sum + a[b].
      set count to count + 1.
    }else{
      set sum to sum + a[b]*weight[b].
      set count to count + weight[b].
    }
  }
  return sum/count.

}

function bench_candidate_avg {
parameter a is list(), weight is "none".
local sum is 0.
local count is 0.
if weight = "none" {
  for b in range(0,a:length-1) { set sum to sum+a[b]. }
  set count to max(0,a:length-1).
} else {
  for b in range(0,a:length-1) {
    set sum to sum+a[b]*weight[b].
    set count to count+weight[b].
  }
}
return sum/count.
}

function bench_run_original_avg { parameter bench_case. return bench_original_avg(bench_case[0],bench_case[1]). }

function bench_run_candidate_avg { parameter bench_case. return bench_candidate_avg(bench_case[0],bench_case[1]). }

function bench_run_production_avg { parameter bench_case. return avg(bench_case[0],bench_case[1]). }

function bench_original_get_geoposition_along_heading {
    parameter starting_LATLNG, vec_heading, distance.
    local angular_deg is distance / SHIP:BODY:RADIUS * constant:radtodeg.
    local start_lat is starting_LATLNG:lat.
    local new_lat is arcsin(max(-1,min(1,
        sin(start_lat)*cos(angular_deg)+cos(start_lat)*sin(angular_deg)*cos(vec_heading)))).
    local longitude_offset is arctan2(
        sin(vec_heading)*sin(angular_deg)*cos(start_lat),
        cos(angular_deg)-sin(start_lat)*sin(new_lat)).
    return latlng(new_lat,navigation_longitude_delta(starting_LATLNG:lng+longitude_offset)).
}

function bench_candidate_get_geoposition_along_heading {
    parameter starting_LATLNG, vec_heading, distance.
    local angular_deg is distance / SHIP:BODY:RADIUS * constant:radtodeg.
    local start_lat is starting_LATLNG:lat.
    local sin_start is sin(start_lat).
    local cos_start is cos(start_lat).
    local sin_arc is sin(angular_deg).
    local cos_arc is cos(angular_deg).
    local new_lat is arcsin(max(-1,min(1,
        sin_start*cos_arc+cos_start*sin_arc*cos(vec_heading)))).
    local longitude_offset is arctan2(
        sin(vec_heading)*sin_arc*cos_start,
        cos_arc-sin_start*sin(new_lat)).
    return latlng(new_lat,navigation_longitude_delta(starting_LATLNG:lng+longitude_offset)).
}

function bench_run_original_get_geoposition_along_heading { parameter bench_case. return bench_original_get_geoposition_along_heading(bench_case[0],bench_case[1],bench_case[2]). }

function bench_run_candidate_get_geoposition_along_heading { parameter bench_case. return bench_candidate_get_geoposition_along_heading(bench_case[0],bench_case[1],bench_case[2]). }

function bench_run_production_get_geoposition_along_heading { parameter bench_case. return get_geoposition_along_heading(bench_case[0],bench_case[1],bench_case[2]). }

function bench_original_heading_between {
    parameter current_position, target_position.
    local delta_lng is navigation_longitude_delta(target_position:lng-current_position:lng).
    if abs(target_position:lat-current_position:lat) < 0.000000001 and abs(delta_lng) < 0.000000001 { return 0. }
    local bearing_y is sin(delta_lng)*cos(target_position:lat).
    local bearing_x is cos(current_position:lat)*sin(target_position:lat)-
        sin(current_position:lat)*cos(target_position:lat)*cos(delta_lng).
    local bearing_deg is arctan2(bearing_y,bearing_x).
    if bearing_deg < 0 { set bearing_deg to bearing_deg+360. }
    return bearing_deg.
}

function bench_candidate_heading_between {
    parameter current_position, target_position.
    local delta_lng is navigation_longitude_delta(target_position:lng-current_position:lng).
    if abs(target_position:lat-current_position:lat) < 0.000000001 and abs(delta_lng) < 0.000000001 { return 0. }
    local cos_target is cos(target_position:lat).
    local bearing_y is sin(delta_lng)*cos_target.
    local bearing_x is cos(current_position:lat)*sin(target_position:lat)-
        sin(current_position:lat)*cos_target*cos(delta_lng).
    local bearing_deg is arctan2(bearing_y,bearing_x).
    if bearing_deg < 0 { set bearing_deg to bearing_deg+360. }
    return bearing_deg.
}

function bench_run_original_heading_between { parameter bench_case. return bench_original_heading_between(bench_case[0],bench_case[1]). }

function bench_run_candidate_heading_between { parameter bench_case. return bench_candidate_heading_between(bench_case[0],bench_case[1]). }

function bench_run_production_heading_between { parameter bench_case. return heading_between(bench_case[0],bench_case[1]). }

function bench_original_calculate_glideslope_profile {
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

function bench_candidate_calculate_glideslope_profile {
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
    local t_squared is t^2.
    local t_cubed is t^3.
    local profile_height is
        (2*t_cubed - 3*t_squared + 1) * shallow_altitude +
        (t_cubed - 2*t_squared + t) * span * shallow_gradient +
        (-2*t_cubed + 3*t_squared) * steep_altitude +
        (t_cubed - t_squared) * span * steep_gradient.
    local altitude_derivative is
        (6*t_squared - 6*t) * shallow_altitude +
        (3*t_squared - 4*t + 1) * span * shallow_gradient +
        (-6*t_squared + 6*t) * steep_altitude +
        (3*t_squared - 2*t) * span * steep_gradient.
    return lex(
        "altitude",profile_height+rnw_alt,
        "gradient",altitude_derivative/span,
        "region","preflare"
    ).
}

function bench_run_original_calculate_glideslope_profile { parameter bench_case. return bench_original_calculate_glideslope_profile(bench_case[0],bench_case[1],bench_case[2]). }

function bench_run_candidate_calculate_glideslope_profile { parameter bench_case. return bench_candidate_calculate_glideslope_profile(bench_case[0],bench_case[1],bench_case[2]). }

function bench_run_production_calculate_glideslope_profile { parameter bench_case. return calculate_glideslope_profile(bench_case[0],bench_case[1],bench_case[2]). }

function bench_original_calculate_glideslope_alt {
    parameter distance,rnw_alt is runway_altitude, gs is AVES["glideslope"].
    return bench_original_calculate_glideslope_profile(distance,rnw_alt,gs)["altitude"].
}

function bench_candidate_calculate_glideslope_alt {
    parameter distance,rnw_alt is runway_altitude, gs is AVES["glideslope"].
    local steep_gradient is gs["angle1"].
    local shallow_gradient is gs["angle2"].
    local preflare_start is gs["preflare_start"].
    local preflare_end is gs["preflare_end"].

    if distance >= preflare_start {
        return ((distance - gs["target1"]) * steep_gradient)+rnw_alt.
    }
    if distance <= preflare_end {
        return ((distance + gs["shallow_aimpoint"]) * shallow_gradient)+rnw_alt.
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
    return profile_height+rnw_alt.
}

function bench_run_original_calculate_glideslope_alt { parameter bench_case. return bench_original_calculate_glideslope_alt(bench_case[0],bench_case[1],bench_case[2]). }

function bench_run_candidate_calculate_glideslope_alt { parameter bench_case. return bench_candidate_calculate_glideslope_alt(bench_case[0],bench_case[1],bench_case[2]). }

function bench_run_production_calculate_glideslope_alt { parameter bench_case. return calculate_glideslope_alt(bench_case[0],bench_case[1],bench_case[2]). }

function bench_original_calculate_distance_from_alt {
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
        if bench_original_calculate_glideslope_alt(middle_distance,rnw_alt,gs) < alt_ {
            set low_distance to middle_distance.
        }else{
            set high_distance to middle_distance.
        }
        set iterations to iterations + 1.
    }
    return (low_distance + high_distance) / 2.
}

function bench_candidate_calculate_distance_from_alt {
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
        if bench_candidate_calculate_glideslope_alt(middle_distance,rnw_alt,gs) < alt_ {
            set low_distance to middle_distance.
        }else{
            set high_distance to middle_distance.
        }
        set iterations to iterations + 1.
    }
    return (low_distance + high_distance) / 2.
}

function bench_run_original_calculate_distance_from_alt { parameter bench_case. return bench_original_calculate_distance_from_alt(bench_case[0],bench_case[1],bench_case[2]). }

function bench_run_candidate_calculate_distance_from_alt { parameter bench_case. return bench_candidate_calculate_distance_from_alt(bench_case[0],bench_case[1],bench_case[2]). }

function bench_run_production_calculate_distance_from_alt { parameter bench_case. return calculate_distance_from_alt(bench_case[0],bench_case[1],bench_case[2]). }

function bench_original_time_to_pos {
  parameter cur_pos. // Current position
  parameter tgt_pos. // Target position
  parameter gs is ship:airspeed. // Ground speed

  local distance to calcdistance_m(cur_pos,tgt_pos). // Compute distance to target

  if gs = 0 or distance = 0{
    return 0. // No movement, will never reach target
  }

  return distance / gs. // Time = Distance / Speed
}

function bench_candidate_time_to_pos {
  parameter cur_pos. // Current position
  parameter tgt_pos. // Target position
  parameter gs is ship:airspeed. // Ground speed

  if gs = 0 { return 0. }
  local distance to calcdistance_m(cur_pos,tgt_pos). // Compute distance to target

  if distance = 0{
    return 0. // No movement, will never reach target
  }

  return distance / gs. // Time = Distance / Speed
}

function bench_run_original_time_to_pos { parameter bench_case. return bench_original_time_to_pos(bench_case[0],bench_case[1],bench_case[2]). }

function bench_run_candidate_time_to_pos { parameter bench_case. return bench_candidate_time_to_pos(bench_case[0],bench_case[1],bench_case[2]). }

function bench_run_production_time_to_pos { parameter bench_case. return time_to_pos(bench_case[0],bench_case[1],bench_case[2]). }

function bench_original_compass_for {
  parameter ves is ship,thing is "default".

  local pointing is ves:facing:forevector.
  if not thing:istype("string") {
    set pointing to type_to_vector(ves,thing).
  }

  local east is east_for(ves).

  local trig_x is vdot(ves:north:vector, pointing).
  local trig_y is vdot(east, pointing).

  local result is arctan2(trig_y, trig_x).

  if result < 0 {
    return 360 + result.
  } else {
    return result.
  }
}

function bench_candidate_compass_for {
  parameter ves is ship,thing is "default".

  local pointing is 0.
  if thing:istype("string") {
    set pointing to ves:facing:forevector.
  } else {
    set pointing to type_to_vector(ves,thing).
  }

  local east is east_for(ves).

  local trig_x is vdot(ves:north:vector, pointing).
  local trig_y is vdot(east, pointing).

  local result is arctan2(trig_y, trig_x).

  if result < 0 {
    return 360 + result.
  } else {
    return result.
  }
}

function bench_run_original_compass_for { parameter bench_case. return bench_original_compass_for(bench_case[0],bench_case[1]). }

function bench_run_candidate_compass_for { parameter bench_case. return bench_candidate_compass_for(bench_case[0],bench_case[1]). }

function bench_run_production_compass_for { parameter bench_case. return compass_for(bench_case[0],bench_case[1]). }

function bench_original_compass_for_prograde {
  parameter ves is ship,thing is "default".

  // Set pointing to the Prograde vector of the vessel
  local pointing is ves:velocity:surface:normalized.

  if not thing:istype("string") {
    set pointing to type_to_vector(ves,thing).
  }

  local east is east_for(ves).

  local trig_x is vdot(ves:north:vector, pointing).
  local trig_y is vdot(east, pointing).

  local result is arctan2(trig_y, trig_x).

  if result < 0 {
    return 360 + result.
  } else {
    return result.
  }
}

function bench_candidate_compass_for_prograde {
  parameter ves is ship,thing is "default".

  // Set pointing to the Prograde vector of the vessel
  local pointing is 0.
  if thing:istype("string") {
    set pointing to ves:velocity:surface:normalized.
  } else {
    set pointing to type_to_vector(ves,thing).
  }

  local east is east_for(ves).

  local trig_x is vdot(ves:north:vector, pointing).
  local trig_y is vdot(east, pointing).

  local result is arctan2(trig_y, trig_x).

  if result < 0 {
    return 360 + result.
  } else {
    return result.
  }
}

function bench_run_original_compass_for_prograde { parameter bench_case. return bench_original_compass_for_prograde(bench_case[0],bench_case[1]). }

function bench_run_candidate_compass_for_prograde { parameter bench_case. return bench_candidate_compass_for_prograde(bench_case[0],bench_case[1]). }

function bench_run_production_compass_for_prograde { parameter bench_case. return compass_for_prograde(bench_case[0],bench_case[1]). }

function bench_original_pitch_for {
  parameter ves is ship,thing is "default".

  local pointing is ves:facing:forevector.
  if not thing:istype("string") {
    set pointing to type_to_vector(ves,thing).
  }

  return 90 - vang(ves:up:vector, pointing).
}

function bench_candidate_pitch_for {
  parameter ves is ship,thing is "default".

  local pointing is 0.
  if thing:istype("string") {
    set pointing to ves:facing:forevector.
  } else {
    set pointing to type_to_vector(ves,thing).
  }

  return 90 - vang(ves:up:vector, pointing).
}

function bench_run_original_pitch_for { parameter bench_case. return bench_original_pitch_for(bench_case[0],bench_case[1]). }

function bench_run_candidate_pitch_for { parameter bench_case. return bench_candidate_pitch_for(bench_case[0],bench_case[1]). }

function bench_run_production_pitch_for { parameter bench_case. return pitch_for(bench_case[0],bench_case[1]). }

function bench_original_pitch_for_prograde {
  parameter ves is ship,thing is "default".

  local pointing is ves:velocity:surface:normalized.
  if not thing:istype("string") {
    set pointing to type_to_vector(ves,thing).
  }

  return 90 - vang(ves:up:vector, pointing).
}

function bench_candidate_pitch_for_prograde {
  parameter ves is ship,thing is "default".

  local pointing is 0.
  if thing:istype("string") {
    set pointing to ves:velocity:surface:normalized.
  } else {
    set pointing to type_to_vector(ves,thing).
  }

  return 90 - vang(ves:up:vector, pointing).
}

function bench_run_original_pitch_for_prograde { parameter bench_case. return bench_original_pitch_for_prograde(bench_case[0],bench_case[1]). }

function bench_run_candidate_pitch_for_prograde { parameter bench_case. return bench_candidate_pitch_for_prograde(bench_case[0],bench_case[1]). }

function bench_run_production_pitch_for_prograde { parameter bench_case. return pitch_for_prograde(bench_case[0],bench_case[1]). }

function bench_original_calc_vvdot {
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

function bench_candidate_calc_vvdot {
    parameter distance.
    parameter speed.
    parameter t_alt.
    parameter alt_.
    if speed = 0 {
        return 0.

    }
    local t is distance / speed.
    set t to max( t/AVES["TEAM_vvdot_t"],AVES["TEAM_vvdot_t"]).

    return (t_alt - alt_) / t.
}

function bench_run_original_calc_vvdot { parameter bench_case. return bench_original_calc_vvdot(bench_case[0],bench_case[1],bench_case[2],bench_case[3]). }

function bench_run_candidate_calc_vvdot { parameter bench_case. return bench_candidate_calc_vvdot(bench_case[0],bench_case[1],bench_case[2],bench_case[3]). }

function bench_run_production_calc_vvdot { parameter bench_case. return calc_vvdot(bench_case[0],bench_case[1],bench_case[2],bench_case[3]). }

function bench_original_calc_turn_radius {
    parameter geopos1, hed1, geopos2, hed2.
    local hed1_rad to hed1 * constant:degtorad.
    local hed2_rad to hed2 * constant:degtorad.
    local distance is calcdistance_m(geopos1, geopos2).
    local delta_heading is abs(hed2_rad - hed1_rad).
    if delta_heading > constant:pi {
        set delta_heading to 2 * constant:pi - delta_heading.
    }
    // Protect against zero or near-zero heading difference which would produce
    // a division-by-zero (infinite radius). If the headings are effectively the
    // same (vehicle flying straight), return 0 as a sentinel (no meaningful turn).
    if abs(delta_heading) < 1e-6 {
        return 0.
    }

    // Calculate the turn radius using the formula: R = d / (2 * sin(Δθ / 2))
    local denom is 2 * sin(delta_heading / 2).
    if abs(denom) < 1e-9 {
        return 0.
    }
    local turn_radius is distance / denom.
    return turn_radius.
}

function bench_candidate_calc_turn_radius {
    parameter geopos1, hed1, geopos2, hed2.
    local hed1_rad to hed1 * constant:degtorad.
    local hed2_rad to hed2 * constant:degtorad.
    local distance is calcdistance_m(geopos1, geopos2).
    local delta_heading is abs(hed2_rad - hed1_rad).
    if delta_heading > constant:pi {
        set delta_heading to 2 * constant:pi - delta_heading.
    }
    // Protect against zero or near-zero heading difference which would produce
    // a division-by-zero (infinite radius). If the headings are effectively the
    // same (vehicle flying straight), return 0 as a sentinel (no meaningful turn).
    if abs(delta_heading) < 1e-6 {
        return 0.
    }

    // Calculate the turn radius using the formula: R = d / (2 * sin(Δθ / 2))
    local denom is 2 * sin(delta_heading / 2).
    if abs(denom) < 1e-9 {
        return 0.
    }
    return distance / denom.
}

function bench_run_original_calc_turn_radius { parameter bench_case. return bench_original_calc_turn_radius(bench_case[0],bench_case[1],bench_case[2],bench_case[3]). }

function bench_run_candidate_calc_turn_radius { parameter bench_case. return bench_candidate_calc_turn_radius(bench_case[0],bench_case[1],bench_case[2],bench_case[3]). }

function bench_run_production_calc_turn_radius { parameter bench_case. return calc_turn_radius(bench_case[0],bench_case[1],bench_case[2],bench_case[3]). }

FUNCTION bench_original_rodrigues {
	DECLARE PARAMETER inVector.	//	Expects a vector
	DECLARE PARAMETER zvec.		//	Expects a vector
	DECLARE PARAMETER alph.	//	Expects a scalar
	DECLARe PARAMETER swch IS 1.

	SET zvec TO zvec:NORMALIZED.

	IF (swch=1) {
		// ANGLEAXIS uses a lower-precision rotation representation. Preserve
		// the original zero-axis result, for which no rotation axis exists.
		IF zvec:SQRMAGNITUDE = 0 { RETURN inVector*COS(alph). }
		RETURN ANGLEAXIS(alph,zvec)*inVector.
	}
	ELSE {
		RETURN inVector*COS(alph) + CROSS(zvec, inVector)*SIN(alph) + zvec*VDOT(zvec, inVector)*(1-COS(alph)).
	}
}

FUNCTION bench_candidate_rodrigues {
	DECLARE PARAMETER inVector.	//	Expects a vector
	DECLARE PARAMETER zvec.		//	Expects a vector
	DECLARE PARAMETER alph.	//	Expects a scalar
	DECLARe PARAMETER swch IS 1.

	SET zvec TO zvec:NORMALIZED.

	IF (swch=1) {
		// ANGLEAXIS uses a lower-precision rotation representation. Preserve
		// the original zero-axis result, for which no rotation axis exists.
		IF zvec:SQRMAGNITUDE = 0 { RETURN inVector*COS(alph). }
		RETURN ANGLEAXIS(alph,zvec)*inVector.
	}
	ELSE {
		LOCAL cos_alph IS COS(alph).
		RETURN inVector*cos_alph + CROSS(zvec, inVector)*SIN(alph) + zvec*VDOT(zvec, inVector)*(1-cos_alph).
	}
}

function bench_run_original_rodrigues { parameter bench_case. return bench_original_rodrigues(bench_case[0],bench_case[1],bench_case[2],bench_case[3]). }

function bench_run_candidate_rodrigues { parameter bench_case. return bench_candidate_rodrigues(bench_case[0],bench_case[1],bench_case[2],bench_case[3]). }

function bench_run_production_rodrigues { parameter bench_case. return rodrigues(bench_case[0],bench_case[1],bench_case[2],bench_case[3]). }

function bench_original_compass_and_pitch_for {
  parameter ves is ship,thing is "default".

  local pointing is ves:facing:forevector.
  if not thing:istype("string") {
    set pointing to type_to_vector(ves,thing).
  }

  local east is east_for(ves).

  local trig_x is vdot(ves:north:vector, pointing).
  local trig_y is vdot(east, pointing).
  local trig_z is vdot(ves:up:vector, pointing).

  local compass is arctan2(trig_y, trig_x).
  if compass < 0 {
    set compass to 360 + compass.
  }
  local pitch is arctan2(trig_z, sqrt(trig_x^2 + trig_y^2)).

  return list(compass,pitch).
}

function bench_candidate_compass_and_pitch_for {
  parameter ves is ship,thing is "default".

  local pointing is ves:facing:forevector.
  if not thing:istype("string") {
    set pointing to type_to_vector(ves,thing).
  }

  local north_vector is ves:north:vector.
  local up_vector is ves:up:vector.
  local east is vcrs(up_vector,north_vector).

  local trig_x is vdot(north_vector, pointing).
  local trig_y is vdot(east, pointing).
  local trig_z is vdot(up_vector, pointing).

  local compass is arctan2(trig_y, trig_x).
  if compass < 0 {
    set compass to 360 + compass.
  }
  local pitch is arctan2(trig_z, sqrt(trig_x^2 + trig_y^2)).

  return list(compass,pitch).
}

function bench_run_original_compass_and_pitch_for { parameter bench_case. return bench_original_compass_and_pitch_for(bench_case[0],bench_case[1]). }

function bench_run_candidate_compass_and_pitch_for { parameter bench_case. return bench_candidate_compass_and_pitch_for(bench_case[0],bench_case[1]). }

function bench_run_production_compass_and_pitch_for { parameter bench_case. return compass_and_pitch_for(bench_case[0],bench_case[1]). }

function bench_equal {
parameter left_value,right_value,value_kind.
if value_kind = "vector" { return left_value:x = right_value:x and left_value:y = right_value:y and left_value:z = right_value:z. }
if value_kind = "geo" { return left_value:lat = right_value:lat and left_value:lng = right_value:lng. }
if value_kind = "profile" { return left_value["altitude"] = right_value["altitude"] and left_value["gradient"] = right_value["gradient"] and left_value["region"] = right_value["region"]. }
if value_kind = "pair" { return left_value[0] = right_value[0] and left_value[1] = right_value[1]. }
return left_value = right_value.
}

function bench_measure {
parameter callback,bench_cases,bench_count,bench_name,bench_variant,bench_round,bench_log.
local bench_value is 0.
local bench_start is time:seconds.
for bench_index in range(0,bench_count) { set bench_value to callback(bench_cases[mod(bench_index,bench_cases:length)]). }
local bench_end is time:seconds.
log "TIME|"+bench_name+"|"+bench_variant+"|"+bench_round+"|"+bench_count+"|"+(bench_end-bench_start) to bench_log.
}

{

print "Checking positive_difference".

local bench_cases is list(list(0,0),list(-12,30),list(1e12,-1e12),list(0.125,0.25)).

local bench_errors is 0.

local bench_production_errors is 0.

for extra_case in list(list(-72.85714285714286,-45.27272727272727),list(-53.28571428571428,-38.09090909090909),list(-33.71428571428572,-30.90909090909091),list(-14.14285714285714,-23.72727272727273),list(5.428571428571429,-16.54545454545455),list(25,-9.363636363636363),list(44.57142857142857,-2.181818181818182),list(64.14285714285714,5),list(-62.14285714285715,12.18181818181818),list(-42.57142857142857,19.36363636363636),list(-23,26.54545454545455),list(-3.428571428571428,33.72727272727273),list(16.14285714285714,40.90909090909091),list(35.71428571428572,-42.54545454545455),list(55.28571428571428,-35.36363636363637),list(-71,-28.18181818181818),list(-51.42857142857143,-21),list(-31.85714285714286,-13.81818181818182),list(-12.28571428571429,-6.636363636363637),list(7.285714285714286,0.5454545454545454),list(26.85714285714286,7.727272727272728),list(46.42857142857143,14.90909090909091),list(66,22.09090909090909),list(-60.28571428571428,29.27272727272727),list(-40.71428571428572,36.45454545454545),list(-21.14285714285714,43.63636363636363),list(-1.571428571428571,-39.81818181818182),list(18,-32.63636363636363),list(37.57142857142857,-25.45454545454545),list(57.14285714285715,-18.27272727272727),list(-69.14285714285714,-11.09090909090909),list(-49.57142857142857,-3.909090909090909),list(-30,3.272727272727273),list(-10.42857142857143,10.45454545454546),list(9.142857142857142,17.63636363636364),list(28.71428571428572,24.81818181818182),list(48.28571428571428,32),list(67.85714285714286,39.18181818181818),list(-58.42857142857143,-44.27272727272727),list(-38.85714285714285,-37.09090909090909),list(-19.28571428571428,-29.90909090909091),list(0.2857142857142857,-22.72727272727273),list(19.85714285714286,-15.54545454545454),list(39.42857142857143,-8.363636363636363),list(59,-1.181818181818182),list(-67.28571428571429,6),list(-47.71428571428572,13.18181818181818),list(-28.14285714285714,20.36363636363636),list(-8.571428571428571,27.54545454545455),list(11,34.72727272727273),list(30.57142857142857,41.90909090909091),list(50.14285714285715,-41.54545454545455),list(69.71428571428571,-34.36363636363637),list(-56.57142857142857,-27.18181818181818),list(-37,-20),list(-17.42857142857143,-12.81818181818182),list(2.142857142857143,-5.636363636363637),list(21.71428571428572,1.545454545454545),list(41.28571428571428,8.727272727272727),list(60.85714285714285,15.90909090909091),list(-65.42857142857143,23.09090909090909),list(-45.85714285714285,30.27272727272727),list(-26.28571428571428,37.45454545454545),list(-6.714285714285714,44.63636363636363)) { bench_cases:add(extra_case). }

for bench_case in bench_cases {

local expected_value is bench_run_original_positive_difference(bench_case).

if not bench_equal(expected_value,bench_run_candidate_positive_difference(bench_case),"scalar") { set bench_errors to bench_errors+1. }

if not bench_equal(expected_value,bench_run_production_positive_difference(bench_case),"scalar") { set bench_production_errors to bench_production_errors+1. }

}

log "CHECK|positive_difference|"+bench_cases:length+"|"+bench_errors+"|"+bench_production_errors to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_positive_difference@,bench_cases,2000,"positive_difference","production",bench_round,bench_log). }

bench_measure(bench_run_original_positive_difference@,bench_cases,2000,"positive_difference","original",bench_round,bench_log).

if bench_round <> 2 { bench_measure(bench_run_production_positive_difference@,bench_cases,2000,"positive_difference","production",bench_round,bench_log). }

}

}

{

print "Checking vecYZ".

local bench_cases is list(list(v(0,0,0)),list(v(1,2,3)),list(v(-123.4,0.125,1000000))).

local bench_errors is 0.

local bench_production_errors is 0.

for extra_case in list(list(v(-72.85714285714286,-45.27272727272727,-27.58441558441559)),list(v(-53.28571428571428,-38.09090909090909,-15.19480519480519)),list(v(-33.71428571428572,-30.90909090909091,-2.805194805194805)),list(v(-14.14285714285714,-23.72727272727273,9.584415584415584)),list(v(5.428571428571429,-16.54545454545455,21.97402597402598)),list(v(25,-9.363636363636363,34.36363636363636)),list(v(44.57142857142857,-2.181818181818182,46.75324675324675)),list(v(64.14285714285714,5,59.14285714285714)),list(v(-62.14285714285715,12.18181818181818,-74.32467532467533)),list(v(-42.57142857142857,19.36363636363636,-61.93506493506493)),list(v(-23,26.54545454545455,-49.54545454545455)),list(v(-3.428571428571428,33.72727272727273,-37.15584415584416)),list(v(16.14285714285714,40.90909090909091,-24.76623376623376)),list(v(35.71428571428572,-42.54545454545455,78.25974025974025)),list(v(55.28571428571428,-35.36363636363637,90.64935064935065)),list(v(-71,-28.18181818181818,-42.81818181818181)),list(v(-51.42857142857143,-21,-30.42857142857143)),list(v(-31.85714285714286,-13.81818181818182,-18.03896103896104)),list(v(-12.28571428571429,-6.636363636363637,-5.64935064935065)),list(v(7.285714285714286,0.5454545454545454,6.74025974025974)),list(v(26.85714285714286,7.727272727272728,19.12987012987013)),list(v(46.42857142857143,14.90909090909091,31.51948051948052)),list(v(66,22.09090909090909,43.90909090909091)),list(v(-60.28571428571428,29.27272727272727,-89.55844155844156)),list(v(-40.71428571428572,36.45454545454545,-77.16883116883116)),list(v(-21.14285714285714,43.63636363636363,-64.77922077922078)),list(v(-1.571428571428571,-39.81818181818182,38.24675324675325)),list(v(18,-32.63636363636363,50.63636363636363)),list(v(37.57142857142857,-25.45454545454545,63.02597402597402)),list(v(57.14285714285715,-18.27272727272727,75.41558441558442)),list(v(-69.14285714285714,-11.09090909090909,-58.05194805194805)),list(v(-49.57142857142857,-3.909090909090909,-45.66233766233766)),list(v(-30,3.272727272727273,-33.27272727272727)),list(v(-10.42857142857143,10.45454545454546,-20.88311688311688)),list(v(9.142857142857142,17.63636363636364,-8.493506493506494)),list(v(28.71428571428572,24.81818181818182,3.896103896103899)),list(v(48.28571428571428,32,16.28571428571428)),list(v(67.85714285714286,39.18181818181818,28.67532467532468)),list(v(-58.42857142857143,-44.27272727272727,-14.15584415584416)),list(v(-38.85714285714285,-37.09090909090909,-1.766233766233761)),list(v(-19.28571428571428,-29.90909090909091,10.62337662337663)),list(v(0.2857142857142857,-22.72727272727273,23.01298701298701)),list(v(19.85714285714286,-15.54545454545454,35.4025974025974)),list(v(39.42857142857143,-8.363636363636363,47.79220779220779)),list(v(59,-1.181818181818182,60.18181818181818)),list(v(-67.28571428571429,6,-73.28571428571429)),list(v(-47.71428571428572,13.18181818181818,-60.8961038961039)),list(v(-28.14285714285714,20.36363636363636,-48.50649350649351)),list(v(-8.571428571428571,27.54545454545455,-36.11688311688312)),list(v(11,34.72727272727273,-23.72727272727273)),list(v(30.57142857142857,41.90909090909091,-11.33766233766233)),list(v(50.14285714285715,-41.54545454545455,91.6883116883117)),list(v(69.71428571428571,-34.36363636363637,104.0779220779221)),list(v(-56.57142857142857,-27.18181818181818,-29.38961038961039)),list(v(-37,-20,-17)),list(v(-17.42857142857143,-12.81818181818182,-4.610389610389609)),list(v(2.142857142857143,-5.636363636363637,7.779220779220779)),list(v(21.71428571428572,1.545454545454545,20.16883116883117)),list(v(41.28571428571428,8.727272727272727,32.55844155844156)),list(v(60.85714285714285,15.90909090909091,44.94805194805195)),list(v(-65.42857142857143,23.09090909090909,-88.51948051948052)),list(v(-45.85714285714285,30.27272727272727,-76.12987012987013)),list(v(-26.28571428571428,37.45454545454545,-63.74025974025974)),list(v(-6.714285714285714,44.63636363636363,-51.35064935064935))) { bench_cases:add(extra_case). }

for bench_case in bench_cases {

local expected_value is bench_run_original_vecYZ(bench_case).

if not bench_equal(expected_value,bench_run_candidate_vecYZ(bench_case),"vector") { set bench_errors to bench_errors+1. }

if not bench_equal(expected_value,bench_run_production_vecYZ(bench_case),"vector") { set bench_production_errors to bench_production_errors+1. }

}

log "CHECK|vecYZ|"+bench_cases:length+"|"+bench_errors+"|"+bench_production_errors to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_vecYZ@,bench_cases,2000,"vecYZ","production",bench_round,bench_log). }

bench_measure(bench_run_original_vecYZ@,bench_cases,2000,"vecYZ","original",bench_round,bench_log).

if bench_round <> 2 { bench_measure(bench_run_production_vecYZ@,bench_cases,2000,"vecYZ","production",bench_round,bench_log). }

}

}

{

print "Checking avg".

local bench_cases is list(list(list(1,2,3,4,5),"none"),list(list(-1,2,-3,4),list(1,2,3,4)),list(list(0.1,0.2,0.3),"none")).

local bench_errors is 0.

local bench_production_errors is 0.

for extra_case in list(list(list(-72.85714285714286,-45.27272727272727,0,7,-2),list(1,3,2,0,7)),list(list(-53.28571428571428,-38.09090909090909,0,7,-2),"none"),list(list(-33.71428571428572,-30.90909090909091,0,7,-2),list(1,3,2,0,7)),list(list(-14.14285714285714,-23.72727272727273,0,7,-2),"none"),list(list(5.428571428571429,-16.54545454545455,0,7,-2),list(1,3,2,0,7)),list(list(25,-9.363636363636363,0,7,-2),"none"),list(list(44.57142857142857,-2.181818181818182,0,7,-2),list(1,3,2,0,7)),list(list(64.14285714285714,5,0,7,-2),"none"),list(list(-62.14285714285715,12.18181818181818,0,7,-2),list(1,3,2,0,7)),list(list(-42.57142857142857,19.36363636363636,0,7,-2),"none"),list(list(-23,26.54545454545455,0,7,-2),list(1,3,2,0,7)),list(list(-3.428571428571428,33.72727272727273,0,7,-2),"none"),list(list(16.14285714285714,40.90909090909091,0,7,-2),list(1,3,2,0,7)),list(list(35.71428571428572,-42.54545454545455,0,7,-2),"none"),list(list(55.28571428571428,-35.36363636363637,0,7,-2),list(1,3,2,0,7)),list(list(-71,-28.18181818181818,0,7,-2),"none"),list(list(-51.42857142857143,-21,0,7,-2),list(1,3,2,0,7)),list(list(-31.85714285714286,-13.81818181818182,0,7,-2),"none"),list(list(-12.28571428571429,-6.636363636363637,0,7,-2),list(1,3,2,0,7)),list(list(7.285714285714286,0.5454545454545454,0,7,-2),"none"),list(list(26.85714285714286,7.727272727272728,0,7,-2),list(1,3,2,0,7)),list(list(46.42857142857143,14.90909090909091,0,7,-2),"none"),list(list(66,22.09090909090909,0,7,-2),list(1,3,2,0,7)),list(list(-60.28571428571428,29.27272727272727,0,7,-2),"none"),list(list(-40.71428571428572,36.45454545454545,0,7,-2),list(1,3,2,0,7)),list(list(-21.14285714285714,43.63636363636363,0,7,-2),"none"),list(list(-1.571428571428571,-39.81818181818182,0,7,-2),list(1,3,2,0,7)),list(list(18,-32.63636363636363,0,7,-2),"none"),list(list(37.57142857142857,-25.45454545454545,0,7,-2),list(1,3,2,0,7)),list(list(57.14285714285715,-18.27272727272727,0,7,-2),"none"),list(list(-69.14285714285714,-11.09090909090909,0,7,-2),list(1,3,2,0,7)),list(list(-49.57142857142857,-3.909090909090909,0,7,-2),"none"),list(list(-30,3.272727272727273,0,7,-2),list(1,3,2,0,7)),list(list(-10.42857142857143,10.45454545454546,0,7,-2),"none"),list(list(9.142857142857142,17.63636363636364,0,7,-2),list(1,3,2,0,7)),list(list(28.71428571428572,24.81818181818182,0,7,-2),"none"),list(list(48.28571428571428,32,0,7,-2),list(1,3,2,0,7)),list(list(67.85714285714286,39.18181818181818,0,7,-2),"none"),list(list(-58.42857142857143,-44.27272727272727,0,7,-2),list(1,3,2,0,7)),list(list(-38.85714285714285,-37.09090909090909,0,7,-2),"none"),list(list(-19.28571428571428,-29.90909090909091,0,7,-2),list(1,3,2,0,7)),list(list(0.2857142857142857,-22.72727272727273,0,7,-2),"none"),list(list(19.85714285714286,-15.54545454545454,0,7,-2),list(1,3,2,0,7)),list(list(39.42857142857143,-8.363636363636363,0,7,-2),"none"),list(list(59,-1.181818181818182,0,7,-2),list(1,3,2,0,7)),list(list(-67.28571428571429,6,0,7,-2),"none"),list(list(-47.71428571428572,13.18181818181818,0,7,-2),list(1,3,2,0,7)),list(list(-28.14285714285714,20.36363636363636,0,7,-2),"none"),list(list(-8.571428571428571,27.54545454545455,0,7,-2),list(1,3,2,0,7)),list(list(11,34.72727272727273,0,7,-2),"none"),list(list(30.57142857142857,41.90909090909091,0,7,-2),list(1,3,2,0,7)),list(list(50.14285714285715,-41.54545454545455,0,7,-2),"none"),list(list(69.71428571428571,-34.36363636363637,0,7,-2),list(1,3,2,0,7)),list(list(-56.57142857142857,-27.18181818181818,0,7,-2),"none"),list(list(-37,-20,0,7,-2),list(1,3,2,0,7)),list(list(-17.42857142857143,-12.81818181818182,0,7,-2),"none"),list(list(2.142857142857143,-5.636363636363637,0,7,-2),list(1,3,2,0,7)),list(list(21.71428571428572,1.545454545454545,0,7,-2),"none"),list(list(41.28571428571428,8.727272727272727,0,7,-2),list(1,3,2,0,7)),list(list(60.85714285714285,15.90909090909091,0,7,-2),"none"),list(list(-65.42857142857143,23.09090909090909,0,7,-2),list(1,3,2,0,7)),list(list(-45.85714285714285,30.27272727272727,0,7,-2),"none"),list(list(-26.28571428571428,37.45454545454545,0,7,-2),list(1,3,2,0,7)),list(list(-6.714285714285714,44.63636363636363,0,7,-2),"none")) { bench_cases:add(extra_case). }

for bench_case in bench_cases {

local expected_value is bench_run_original_avg(bench_case).

if not bench_equal(expected_value,bench_run_candidate_avg(bench_case),"scalar") { set bench_errors to bench_errors+1. }

if not bench_equal(expected_value,bench_run_production_avg(bench_case),"scalar") { set bench_production_errors to bench_production_errors+1. }

}

log "CHECK|avg|"+bench_cases:length+"|"+bench_errors+"|"+bench_production_errors to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_avg@,bench_cases,2000,"avg","production",bench_round,bench_log). }

bench_measure(bench_run_original_avg@,bench_cases,2000,"avg","original",bench_round,bench_log).

if bench_round <> 2 { bench_measure(bench_run_production_avg@,bench_cases,2000,"avg","production",bench_round,bench_log). }

}

}

{

print "Checking calculate_glideslope_profile".

local bench_cases is list(list(-100,100,bench_gs),list(0,100,bench_gs),list(499,100,bench_gs),list(500,100,bench_gs),list(501,100,bench_gs),list(750,100,bench_gs),list(1250,100,bench_gs),list(1999,100,bench_gs),list(2000,100,bench_gs),list(3000,100,bench_gs)).

local bench_errors is 0.

local bench_production_errors is 0.

for extra_case in list(list(-100,-10,lex("angle1",0.2,"angle2",0.03,"preflare_start",1000,"preflare_end",100,"target1",0,"shallow_aimpoint",200)),list(-51,-5,lex("angle1",0.201,"angle2",0.0305,"preflare_start",1100,"preflare_end",150,"target1",3,"shallow_aimpoint",202)),list(-2,0,lex("angle1",0.202,"angle2",0.031,"preflare_start",1200,"preflare_end",200,"target1",6,"shallow_aimpoint",204)),list(47,5,lex("angle1",0.203,"angle2",0.0315,"preflare_start",1300,"preflare_end",250,"target1",9,"shallow_aimpoint",206)),list(96,10,lex("angle1",0.204,"angle2",0.032,"preflare_start",1400,"preflare_end",300,"target1",12,"shallow_aimpoint",208)),list(145,15,lex("angle1",0.205,"angle2",0.0325,"preflare_start",1500,"preflare_end",100,"target1",15,"shallow_aimpoint",210)),list(194,20,lex("angle1",0.206,"angle2",0.033,"preflare_start",1600,"preflare_end",150,"target1",18,"shallow_aimpoint",212)),list(243,25,lex("angle1",0.207,"angle2",0.0335,"preflare_start",1700,"preflare_end",200,"target1",21,"shallow_aimpoint",214)),list(292,30,lex("angle1",0.208,"angle2",0.034,"preflare_start",1800,"preflare_end",250,"target1",24,"shallow_aimpoint",216)),list(341,35,lex("angle1",0.209,"angle2",0.0345,"preflare_start",1900,"preflare_end",300,"target1",27,"shallow_aimpoint",218)),list(390,40,lex("angle1",0.21,"angle2",0.035,"preflare_start",1000,"preflare_end",100,"target1",30,"shallow_aimpoint",220)),list(439,45,lex("angle1",0.211,"angle2",0.0355,"preflare_start",1100,"preflare_end",150,"target1",33,"shallow_aimpoint",222)),list(488,50,lex("angle1",0.212,"angle2",0.036,"preflare_start",1200,"preflare_end",200,"target1",36,"shallow_aimpoint",224)),list(537,55,lex("angle1",0.213,"angle2",0.0365,"preflare_start",1300,"preflare_end",250,"target1",39,"shallow_aimpoint",226)),list(586,60,lex("angle1",0.214,"angle2",0.037,"preflare_start",1400,"preflare_end",300,"target1",42,"shallow_aimpoint",228)),list(635,65,lex("angle1",0.215,"angle2",0.0375,"preflare_start",1500,"preflare_end",100,"target1",45,"shallow_aimpoint",230)),list(684,70,lex("angle1",0.216,"angle2",0.038,"preflare_start",1600,"preflare_end",150,"target1",48,"shallow_aimpoint",232)),list(733,75,lex("angle1",0.217,"angle2",0.0385,"preflare_start",1700,"preflare_end",200,"target1",51,"shallow_aimpoint",234)),list(782,80,lex("angle1",0.218,"angle2",0.039,"preflare_start",1800,"preflare_end",250,"target1",54,"shallow_aimpoint",236)),list(831,85,lex("angle1",0.219,"angle2",0.0395,"preflare_start",1900,"preflare_end",300,"target1",57,"shallow_aimpoint",238)),list(880,90,lex("angle1",0.22,"angle2",0.04,"preflare_start",1000,"preflare_end",100,"target1",60,"shallow_aimpoint",240)),list(929,95,lex("angle1",0.221,"angle2",0.0405,"preflare_start",1100,"preflare_end",150,"target1",63,"shallow_aimpoint",242)),list(978,100,lex("angle1",0.222,"angle2",0.04099999999999999,"preflare_start",1200,"preflare_end",200,"target1",66,"shallow_aimpoint",244)),list(1027,105,lex("angle1",0.223,"angle2",0.0415,"preflare_start",1300,"preflare_end",250,"target1",69,"shallow_aimpoint",246)),list(1076,110,lex("angle1",0.224,"angle2",0.042,"preflare_start",1400,"preflare_end",300,"target1",72,"shallow_aimpoint",248)),list(1125,115,lex("angle1",0.225,"angle2",0.0425,"preflare_start",1500,"preflare_end",100,"target1",75,"shallow_aimpoint",250)),list(1174,120,lex("angle1",0.226,"angle2",0.043,"preflare_start",1600,"preflare_end",150,"target1",78,"shallow_aimpoint",252)),list(1223,125,lex("angle1",0.227,"angle2",0.0435,"preflare_start",1700,"preflare_end",200,"target1",81,"shallow_aimpoint",254)),list(1272,130,lex("angle1",0.228,"angle2",0.044,"preflare_start",1800,"preflare_end",250,"target1",84,"shallow_aimpoint",256)),list(1321,135,lex("angle1",0.229,"angle2",0.0445,"preflare_start",1900,"preflare_end",300,"target1",87,"shallow_aimpoint",258)),list(1370,140,lex("angle1",0.23,"angle2",0.045,"preflare_start",1000,"preflare_end",100,"target1",90,"shallow_aimpoint",260)),list(1419,145,lex("angle1",0.231,"angle2",0.0455,"preflare_start",1100,"preflare_end",150,"target1",93,"shallow_aimpoint",262)),list(1468,150,lex("angle1",0.232,"angle2",0.046,"preflare_start",1200,"preflare_end",200,"target1",96,"shallow_aimpoint",264)),list(1517,155,lex("angle1",0.233,"angle2",0.0465,"preflare_start",1300,"preflare_end",250,"target1",99,"shallow_aimpoint",266)),list(1566,160,lex("angle1",0.234,"angle2",0.047,"preflare_start",1400,"preflare_end",300,"target1",102,"shallow_aimpoint",268)),list(1615,165,lex("angle1",0.235,"angle2",0.0475,"preflare_start",1500,"preflare_end",100,"target1",105,"shallow_aimpoint",270)),list(1664,170,lex("angle1",0.236,"angle2",0.048,"preflare_start",1600,"preflare_end",150,"target1",108,"shallow_aimpoint",272)),list(1713,175,lex("angle1",0.237,"angle2",0.0485,"preflare_start",1700,"preflare_end",200,"target1",111,"shallow_aimpoint",274)),list(1762,180,lex("angle1",0.238,"angle2",0.049,"preflare_start",1800,"preflare_end",250,"target1",114,"shallow_aimpoint",276)),list(1811,185,lex("angle1",0.239,"angle2",0.0495,"preflare_start",1900,"preflare_end",300,"target1",117,"shallow_aimpoint",278)),list(1860,190,lex("angle1",0.24,"angle2",0.05,"preflare_start",1000,"preflare_end",100,"target1",120,"shallow_aimpoint",280)),list(1909,195,lex("angle1",0.241,"angle2",0.0505,"preflare_start",1100,"preflare_end",150,"target1",123,"shallow_aimpoint",282)),list(1958,200,lex("angle1",0.242,"angle2",0.051,"preflare_start",1200,"preflare_end",200,"target1",126,"shallow_aimpoint",284)),list(2007,205,lex("angle1",0.243,"angle2",0.0515,"preflare_start",1300,"preflare_end",250,"target1",129,"shallow_aimpoint",286)),list(2056,210,lex("angle1",0.244,"angle2",0.052,"preflare_start",1400,"preflare_end",300,"target1",132,"shallow_aimpoint",288)),list(2105,215,lex("angle1",0.245,"angle2",0.0525,"preflare_start",1500,"preflare_end",100,"target1",135,"shallow_aimpoint",290)),list(2154,220,lex("angle1",0.246,"angle2",0.053,"preflare_start",1600,"preflare_end",150,"target1",138,"shallow_aimpoint",292)),list(2203,225,lex("angle1",0.247,"angle2",0.0535,"preflare_start",1700,"preflare_end",200,"target1",141,"shallow_aimpoint",294)),list(2252,230,lex("angle1",0.248,"angle2",0.054,"preflare_start",1800,"preflare_end",250,"target1",144,"shallow_aimpoint",296)),list(2301,235,lex("angle1",0.249,"angle2",0.0545,"preflare_start",1900,"preflare_end",300,"target1",147,"shallow_aimpoint",298)),list(2350,240,lex("angle1",0.25,"angle2",0.055,"preflare_start",1000,"preflare_end",100,"target1",150,"shallow_aimpoint",300)),list(2399,245,lex("angle1",0.251,"angle2",0.0555,"preflare_start",1100,"preflare_end",150,"target1",153,"shallow_aimpoint",302)),list(2448,250,lex("angle1",0.252,"angle2",0.056,"preflare_start",1200,"preflare_end",200,"target1",156,"shallow_aimpoint",304)),list(2497,255,lex("angle1",0.253,"angle2",0.05649999999999999,"preflare_start",1300,"preflare_end",250,"target1",159,"shallow_aimpoint",306)),list(2546,260,lex("angle1",0.254,"angle2",0.057,"preflare_start",1400,"preflare_end",300,"target1",162,"shallow_aimpoint",308)),list(2595,265,lex("angle1",0.255,"angle2",0.0575,"preflare_start",1500,"preflare_end",100,"target1",165,"shallow_aimpoint",310)),list(2644,270,lex("angle1",0.256,"angle2",0.058,"preflare_start",1600,"preflare_end",150,"target1",168,"shallow_aimpoint",312)),list(2693,275,lex("angle1",0.257,"angle2",0.0585,"preflare_start",1700,"preflare_end",200,"target1",171,"shallow_aimpoint",314)),list(2742,280,lex("angle1",0.258,"angle2",0.059,"preflare_start",1800,"preflare_end",250,"target1",174,"shallow_aimpoint",316)),list(2791,285,lex("angle1",0.259,"angle2",0.0595,"preflare_start",1900,"preflare_end",300,"target1",177,"shallow_aimpoint",318)),list(2840,290,lex("angle1",0.26,"angle2",0.06,"preflare_start",1000,"preflare_end",100,"target1",180,"shallow_aimpoint",320)),list(2889,295,lex("angle1",0.261,"angle2",0.0605,"preflare_start",1100,"preflare_end",150,"target1",183,"shallow_aimpoint",322)),list(2938,300,lex("angle1",0.262,"angle2",0.061,"preflare_start",1200,"preflare_end",200,"target1",186,"shallow_aimpoint",324)),list(2987,305,lex("angle1",0.263,"angle2",0.0615,"preflare_start",1300,"preflare_end",250,"target1",189,"shallow_aimpoint",326))) { bench_cases:add(extra_case). }

for bench_case in bench_cases {

local expected_value is bench_run_original_calculate_glideslope_profile(bench_case).

if not bench_equal(expected_value,bench_run_candidate_calculate_glideslope_profile(bench_case),"profile") { set bench_errors to bench_errors+1. }

if not bench_equal(expected_value,bench_run_production_calculate_glideslope_profile(bench_case),"profile") { set bench_production_errors to bench_production_errors+1. }

}

log "CHECK|calculate_glideslope_profile|"+bench_cases:length+"|"+bench_errors+"|"+bench_production_errors to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_calculate_glideslope_profile@,bench_cases,1000,"calculate_glideslope_profile","production",bench_round,bench_log). }

bench_measure(bench_run_original_calculate_glideslope_profile@,bench_cases,1000,"calculate_glideslope_profile","original",bench_round,bench_log).

if bench_round <> 2 { bench_measure(bench_run_production_calculate_glideslope_profile@,bench_cases,1000,"calculate_glideslope_profile","production",bench_round,bench_log). }

}

}

{

print "Checking calculate_glideslope_alt".

local bench_cases is list(list(-100,100,bench_gs),list(0,100,bench_gs),list(499,100,bench_gs),list(500,100,bench_gs),list(501,100,bench_gs),list(750,100,bench_gs),list(1250,100,bench_gs),list(1999,100,bench_gs),list(2000,100,bench_gs),list(3000,100,bench_gs)).

local bench_errors is 0.

local bench_production_errors is 0.

for extra_case in list(list(-100,-10,lex("angle1",0.2,"angle2",0.03,"preflare_start",1000,"preflare_end",100,"target1",0,"shallow_aimpoint",200)),list(-51,-5,lex("angle1",0.201,"angle2",0.0305,"preflare_start",1100,"preflare_end",150,"target1",3,"shallow_aimpoint",202)),list(-2,0,lex("angle1",0.202,"angle2",0.031,"preflare_start",1200,"preflare_end",200,"target1",6,"shallow_aimpoint",204)),list(47,5,lex("angle1",0.203,"angle2",0.0315,"preflare_start",1300,"preflare_end",250,"target1",9,"shallow_aimpoint",206)),list(96,10,lex("angle1",0.204,"angle2",0.032,"preflare_start",1400,"preflare_end",300,"target1",12,"shallow_aimpoint",208)),list(145,15,lex("angle1",0.205,"angle2",0.0325,"preflare_start",1500,"preflare_end",100,"target1",15,"shallow_aimpoint",210)),list(194,20,lex("angle1",0.206,"angle2",0.033,"preflare_start",1600,"preflare_end",150,"target1",18,"shallow_aimpoint",212)),list(243,25,lex("angle1",0.207,"angle2",0.0335,"preflare_start",1700,"preflare_end",200,"target1",21,"shallow_aimpoint",214)),list(292,30,lex("angle1",0.208,"angle2",0.034,"preflare_start",1800,"preflare_end",250,"target1",24,"shallow_aimpoint",216)),list(341,35,lex("angle1",0.209,"angle2",0.0345,"preflare_start",1900,"preflare_end",300,"target1",27,"shallow_aimpoint",218)),list(390,40,lex("angle1",0.21,"angle2",0.035,"preflare_start",1000,"preflare_end",100,"target1",30,"shallow_aimpoint",220)),list(439,45,lex("angle1",0.211,"angle2",0.0355,"preflare_start",1100,"preflare_end",150,"target1",33,"shallow_aimpoint",222)),list(488,50,lex("angle1",0.212,"angle2",0.036,"preflare_start",1200,"preflare_end",200,"target1",36,"shallow_aimpoint",224)),list(537,55,lex("angle1",0.213,"angle2",0.0365,"preflare_start",1300,"preflare_end",250,"target1",39,"shallow_aimpoint",226)),list(586,60,lex("angle1",0.214,"angle2",0.037,"preflare_start",1400,"preflare_end",300,"target1",42,"shallow_aimpoint",228)),list(635,65,lex("angle1",0.215,"angle2",0.0375,"preflare_start",1500,"preflare_end",100,"target1",45,"shallow_aimpoint",230)),list(684,70,lex("angle1",0.216,"angle2",0.038,"preflare_start",1600,"preflare_end",150,"target1",48,"shallow_aimpoint",232)),list(733,75,lex("angle1",0.217,"angle2",0.0385,"preflare_start",1700,"preflare_end",200,"target1",51,"shallow_aimpoint",234)),list(782,80,lex("angle1",0.218,"angle2",0.039,"preflare_start",1800,"preflare_end",250,"target1",54,"shallow_aimpoint",236)),list(831,85,lex("angle1",0.219,"angle2",0.0395,"preflare_start",1900,"preflare_end",300,"target1",57,"shallow_aimpoint",238)),list(880,90,lex("angle1",0.22,"angle2",0.04,"preflare_start",1000,"preflare_end",100,"target1",60,"shallow_aimpoint",240)),list(929,95,lex("angle1",0.221,"angle2",0.0405,"preflare_start",1100,"preflare_end",150,"target1",63,"shallow_aimpoint",242)),list(978,100,lex("angle1",0.222,"angle2",0.04099999999999999,"preflare_start",1200,"preflare_end",200,"target1",66,"shallow_aimpoint",244)),list(1027,105,lex("angle1",0.223,"angle2",0.0415,"preflare_start",1300,"preflare_end",250,"target1",69,"shallow_aimpoint",246)),list(1076,110,lex("angle1",0.224,"angle2",0.042,"preflare_start",1400,"preflare_end",300,"target1",72,"shallow_aimpoint",248)),list(1125,115,lex("angle1",0.225,"angle2",0.0425,"preflare_start",1500,"preflare_end",100,"target1",75,"shallow_aimpoint",250)),list(1174,120,lex("angle1",0.226,"angle2",0.043,"preflare_start",1600,"preflare_end",150,"target1",78,"shallow_aimpoint",252)),list(1223,125,lex("angle1",0.227,"angle2",0.0435,"preflare_start",1700,"preflare_end",200,"target1",81,"shallow_aimpoint",254)),list(1272,130,lex("angle1",0.228,"angle2",0.044,"preflare_start",1800,"preflare_end",250,"target1",84,"shallow_aimpoint",256)),list(1321,135,lex("angle1",0.229,"angle2",0.0445,"preflare_start",1900,"preflare_end",300,"target1",87,"shallow_aimpoint",258)),list(1370,140,lex("angle1",0.23,"angle2",0.045,"preflare_start",1000,"preflare_end",100,"target1",90,"shallow_aimpoint",260)),list(1419,145,lex("angle1",0.231,"angle2",0.0455,"preflare_start",1100,"preflare_end",150,"target1",93,"shallow_aimpoint",262)),list(1468,150,lex("angle1",0.232,"angle2",0.046,"preflare_start",1200,"preflare_end",200,"target1",96,"shallow_aimpoint",264)),list(1517,155,lex("angle1",0.233,"angle2",0.0465,"preflare_start",1300,"preflare_end",250,"target1",99,"shallow_aimpoint",266)),list(1566,160,lex("angle1",0.234,"angle2",0.047,"preflare_start",1400,"preflare_end",300,"target1",102,"shallow_aimpoint",268)),list(1615,165,lex("angle1",0.235,"angle2",0.0475,"preflare_start",1500,"preflare_end",100,"target1",105,"shallow_aimpoint",270)),list(1664,170,lex("angle1",0.236,"angle2",0.048,"preflare_start",1600,"preflare_end",150,"target1",108,"shallow_aimpoint",272)),list(1713,175,lex("angle1",0.237,"angle2",0.0485,"preflare_start",1700,"preflare_end",200,"target1",111,"shallow_aimpoint",274)),list(1762,180,lex("angle1",0.238,"angle2",0.049,"preflare_start",1800,"preflare_end",250,"target1",114,"shallow_aimpoint",276)),list(1811,185,lex("angle1",0.239,"angle2",0.0495,"preflare_start",1900,"preflare_end",300,"target1",117,"shallow_aimpoint",278)),list(1860,190,lex("angle1",0.24,"angle2",0.05,"preflare_start",1000,"preflare_end",100,"target1",120,"shallow_aimpoint",280)),list(1909,195,lex("angle1",0.241,"angle2",0.0505,"preflare_start",1100,"preflare_end",150,"target1",123,"shallow_aimpoint",282)),list(1958,200,lex("angle1",0.242,"angle2",0.051,"preflare_start",1200,"preflare_end",200,"target1",126,"shallow_aimpoint",284)),list(2007,205,lex("angle1",0.243,"angle2",0.0515,"preflare_start",1300,"preflare_end",250,"target1",129,"shallow_aimpoint",286)),list(2056,210,lex("angle1",0.244,"angle2",0.052,"preflare_start",1400,"preflare_end",300,"target1",132,"shallow_aimpoint",288)),list(2105,215,lex("angle1",0.245,"angle2",0.0525,"preflare_start",1500,"preflare_end",100,"target1",135,"shallow_aimpoint",290)),list(2154,220,lex("angle1",0.246,"angle2",0.053,"preflare_start",1600,"preflare_end",150,"target1",138,"shallow_aimpoint",292)),list(2203,225,lex("angle1",0.247,"angle2",0.0535,"preflare_start",1700,"preflare_end",200,"target1",141,"shallow_aimpoint",294)),list(2252,230,lex("angle1",0.248,"angle2",0.054,"preflare_start",1800,"preflare_end",250,"target1",144,"shallow_aimpoint",296)),list(2301,235,lex("angle1",0.249,"angle2",0.0545,"preflare_start",1900,"preflare_end",300,"target1",147,"shallow_aimpoint",298)),list(2350,240,lex("angle1",0.25,"angle2",0.055,"preflare_start",1000,"preflare_end",100,"target1",150,"shallow_aimpoint",300)),list(2399,245,lex("angle1",0.251,"angle2",0.0555,"preflare_start",1100,"preflare_end",150,"target1",153,"shallow_aimpoint",302)),list(2448,250,lex("angle1",0.252,"angle2",0.056,"preflare_start",1200,"preflare_end",200,"target1",156,"shallow_aimpoint",304)),list(2497,255,lex("angle1",0.253,"angle2",0.05649999999999999,"preflare_start",1300,"preflare_end",250,"target1",159,"shallow_aimpoint",306)),list(2546,260,lex("angle1",0.254,"angle2",0.057,"preflare_start",1400,"preflare_end",300,"target1",162,"shallow_aimpoint",308)),list(2595,265,lex("angle1",0.255,"angle2",0.0575,"preflare_start",1500,"preflare_end",100,"target1",165,"shallow_aimpoint",310)),list(2644,270,lex("angle1",0.256,"angle2",0.058,"preflare_start",1600,"preflare_end",150,"target1",168,"shallow_aimpoint",312)),list(2693,275,lex("angle1",0.257,"angle2",0.0585,"preflare_start",1700,"preflare_end",200,"target1",171,"shallow_aimpoint",314)),list(2742,280,lex("angle1",0.258,"angle2",0.059,"preflare_start",1800,"preflare_end",250,"target1",174,"shallow_aimpoint",316)),list(2791,285,lex("angle1",0.259,"angle2",0.0595,"preflare_start",1900,"preflare_end",300,"target1",177,"shallow_aimpoint",318)),list(2840,290,lex("angle1",0.26,"angle2",0.06,"preflare_start",1000,"preflare_end",100,"target1",180,"shallow_aimpoint",320)),list(2889,295,lex("angle1",0.261,"angle2",0.0605,"preflare_start",1100,"preflare_end",150,"target1",183,"shallow_aimpoint",322)),list(2938,300,lex("angle1",0.262,"angle2",0.061,"preflare_start",1200,"preflare_end",200,"target1",186,"shallow_aimpoint",324)),list(2987,305,lex("angle1",0.263,"angle2",0.0615,"preflare_start",1300,"preflare_end",250,"target1",189,"shallow_aimpoint",326))) { bench_cases:add(extra_case). }

for bench_case in bench_cases {

local expected_value is bench_run_original_calculate_glideslope_alt(bench_case).

if not bench_equal(expected_value,bench_run_candidate_calculate_glideslope_alt(bench_case),"scalar") { set bench_errors to bench_errors+1. }

if not bench_equal(expected_value,bench_run_production_calculate_glideslope_alt(bench_case),"scalar") { set bench_production_errors to bench_production_errors+1. }

}

log "CHECK|calculate_glideslope_alt|"+bench_cases:length+"|"+bench_errors+"|"+bench_production_errors to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_calculate_glideslope_alt@,bench_cases,1000,"calculate_glideslope_alt","production",bench_round,bench_log). }

bench_measure(bench_run_original_calculate_glideslope_alt@,bench_cases,1000,"calculate_glideslope_alt","original",bench_round,bench_log).

if bench_round <> 2 { bench_measure(bench_run_production_calculate_glideslope_alt@,bench_cases,1000,"calculate_glideslope_alt","production",bench_round,bench_log). }

}

}

{

print "Checking calculate_distance_from_alt".

local bench_cases is list(list(90,100,bench_gs),list(100,100,bench_gs),list(142,100,bench_gs),list(200,100,bench_gs),list(300,100,bench_gs),list(450,100,bench_gs),list(650,100,bench_gs),list(1000,100,bench_gs)).

local bench_errors is 0.

local bench_production_errors is 0.

for extra_case in list(list(-20,-10,lex("angle1",0.2,"angle2",0.03,"preflare_start",1000,"preflare_end",100,"target1",0,"shallow_aimpoint",200)),list(-7,-5,lex("angle1",0.201,"angle2",0.0305,"preflare_start",1100,"preflare_end",150,"target1",3,"shallow_aimpoint",202)),list(6,0,lex("angle1",0.202,"angle2",0.031,"preflare_start",1200,"preflare_end",200,"target1",6,"shallow_aimpoint",204)),list(19,5,lex("angle1",0.203,"angle2",0.0315,"preflare_start",1300,"preflare_end",250,"target1",9,"shallow_aimpoint",206)),list(32,10,lex("angle1",0.204,"angle2",0.032,"preflare_start",1400,"preflare_end",300,"target1",12,"shallow_aimpoint",208)),list(45,15,lex("angle1",0.205,"angle2",0.0325,"preflare_start",1500,"preflare_end",100,"target1",15,"shallow_aimpoint",210)),list(58,20,lex("angle1",0.206,"angle2",0.033,"preflare_start",1600,"preflare_end",150,"target1",18,"shallow_aimpoint",212)),list(71,25,lex("angle1",0.207,"angle2",0.0335,"preflare_start",1700,"preflare_end",200,"target1",21,"shallow_aimpoint",214)),list(84,30,lex("angle1",0.208,"angle2",0.034,"preflare_start",1800,"preflare_end",250,"target1",24,"shallow_aimpoint",216)),list(97,35,lex("angle1",0.209,"angle2",0.0345,"preflare_start",1900,"preflare_end",300,"target1",27,"shallow_aimpoint",218)),list(110,40,lex("angle1",0.21,"angle2",0.035,"preflare_start",1000,"preflare_end",100,"target1",30,"shallow_aimpoint",220)),list(123,45,lex("angle1",0.211,"angle2",0.0355,"preflare_start",1100,"preflare_end",150,"target1",33,"shallow_aimpoint",222)),list(136,50,lex("angle1",0.212,"angle2",0.036,"preflare_start",1200,"preflare_end",200,"target1",36,"shallow_aimpoint",224)),list(149,55,lex("angle1",0.213,"angle2",0.0365,"preflare_start",1300,"preflare_end",250,"target1",39,"shallow_aimpoint",226)),list(162,60,lex("angle1",0.214,"angle2",0.037,"preflare_start",1400,"preflare_end",300,"target1",42,"shallow_aimpoint",228)),list(175,65,lex("angle1",0.215,"angle2",0.0375,"preflare_start",1500,"preflare_end",100,"target1",45,"shallow_aimpoint",230)),list(188,70,lex("angle1",0.216,"angle2",0.038,"preflare_start",1600,"preflare_end",150,"target1",48,"shallow_aimpoint",232)),list(201,75,lex("angle1",0.217,"angle2",0.0385,"preflare_start",1700,"preflare_end",200,"target1",51,"shallow_aimpoint",234)),list(214,80,lex("angle1",0.218,"angle2",0.039,"preflare_start",1800,"preflare_end",250,"target1",54,"shallow_aimpoint",236)),list(227,85,lex("angle1",0.219,"angle2",0.0395,"preflare_start",1900,"preflare_end",300,"target1",57,"shallow_aimpoint",238)),list(240,90,lex("angle1",0.22,"angle2",0.04,"preflare_start",1000,"preflare_end",100,"target1",60,"shallow_aimpoint",240)),list(253,95,lex("angle1",0.221,"angle2",0.0405,"preflare_start",1100,"preflare_end",150,"target1",63,"shallow_aimpoint",242)),list(266,100,lex("angle1",0.222,"angle2",0.04099999999999999,"preflare_start",1200,"preflare_end",200,"target1",66,"shallow_aimpoint",244)),list(279,105,lex("angle1",0.223,"angle2",0.0415,"preflare_start",1300,"preflare_end",250,"target1",69,"shallow_aimpoint",246)),list(292,110,lex("angle1",0.224,"angle2",0.042,"preflare_start",1400,"preflare_end",300,"target1",72,"shallow_aimpoint",248)),list(305,115,lex("angle1",0.225,"angle2",0.0425,"preflare_start",1500,"preflare_end",100,"target1",75,"shallow_aimpoint",250)),list(318,120,lex("angle1",0.226,"angle2",0.043,"preflare_start",1600,"preflare_end",150,"target1",78,"shallow_aimpoint",252)),list(331,125,lex("angle1",0.227,"angle2",0.0435,"preflare_start",1700,"preflare_end",200,"target1",81,"shallow_aimpoint",254)),list(344,130,lex("angle1",0.228,"angle2",0.044,"preflare_start",1800,"preflare_end",250,"target1",84,"shallow_aimpoint",256)),list(357,135,lex("angle1",0.229,"angle2",0.0445,"preflare_start",1900,"preflare_end",300,"target1",87,"shallow_aimpoint",258)),list(370,140,lex("angle1",0.23,"angle2",0.045,"preflare_start",1000,"preflare_end",100,"target1",90,"shallow_aimpoint",260)),list(383,145,lex("angle1",0.231,"angle2",0.0455,"preflare_start",1100,"preflare_end",150,"target1",93,"shallow_aimpoint",262)),list(396,150,lex("angle1",0.232,"angle2",0.046,"preflare_start",1200,"preflare_end",200,"target1",96,"shallow_aimpoint",264)),list(409,155,lex("angle1",0.233,"angle2",0.0465,"preflare_start",1300,"preflare_end",250,"target1",99,"shallow_aimpoint",266)),list(422,160,lex("angle1",0.234,"angle2",0.047,"preflare_start",1400,"preflare_end",300,"target1",102,"shallow_aimpoint",268)),list(435,165,lex("angle1",0.235,"angle2",0.0475,"preflare_start",1500,"preflare_end",100,"target1",105,"shallow_aimpoint",270)),list(448,170,lex("angle1",0.236,"angle2",0.048,"preflare_start",1600,"preflare_end",150,"target1",108,"shallow_aimpoint",272)),list(461,175,lex("angle1",0.237,"angle2",0.0485,"preflare_start",1700,"preflare_end",200,"target1",111,"shallow_aimpoint",274)),list(474,180,lex("angle1",0.238,"angle2",0.049,"preflare_start",1800,"preflare_end",250,"target1",114,"shallow_aimpoint",276)),list(487,185,lex("angle1",0.239,"angle2",0.0495,"preflare_start",1900,"preflare_end",300,"target1",117,"shallow_aimpoint",278)),list(500,190,lex("angle1",0.24,"angle2",0.05,"preflare_start",1000,"preflare_end",100,"target1",120,"shallow_aimpoint",280)),list(513,195,lex("angle1",0.241,"angle2",0.0505,"preflare_start",1100,"preflare_end",150,"target1",123,"shallow_aimpoint",282)),list(526,200,lex("angle1",0.242,"angle2",0.051,"preflare_start",1200,"preflare_end",200,"target1",126,"shallow_aimpoint",284)),list(539,205,lex("angle1",0.243,"angle2",0.0515,"preflare_start",1300,"preflare_end",250,"target1",129,"shallow_aimpoint",286)),list(552,210,lex("angle1",0.244,"angle2",0.052,"preflare_start",1400,"preflare_end",300,"target1",132,"shallow_aimpoint",288)),list(565,215,lex("angle1",0.245,"angle2",0.0525,"preflare_start",1500,"preflare_end",100,"target1",135,"shallow_aimpoint",290)),list(578,220,lex("angle1",0.246,"angle2",0.053,"preflare_start",1600,"preflare_end",150,"target1",138,"shallow_aimpoint",292)),list(591,225,lex("angle1",0.247,"angle2",0.0535,"preflare_start",1700,"preflare_end",200,"target1",141,"shallow_aimpoint",294)),list(604,230,lex("angle1",0.248,"angle2",0.054,"preflare_start",1800,"preflare_end",250,"target1",144,"shallow_aimpoint",296)),list(617,235,lex("angle1",0.249,"angle2",0.0545,"preflare_start",1900,"preflare_end",300,"target1",147,"shallow_aimpoint",298)),list(630,240,lex("angle1",0.25,"angle2",0.055,"preflare_start",1000,"preflare_end",100,"target1",150,"shallow_aimpoint",300)),list(643,245,lex("angle1",0.251,"angle2",0.0555,"preflare_start",1100,"preflare_end",150,"target1",153,"shallow_aimpoint",302)),list(656,250,lex("angle1",0.252,"angle2",0.056,"preflare_start",1200,"preflare_end",200,"target1",156,"shallow_aimpoint",304)),list(669,255,lex("angle1",0.253,"angle2",0.05649999999999999,"preflare_start",1300,"preflare_end",250,"target1",159,"shallow_aimpoint",306)),list(682,260,lex("angle1",0.254,"angle2",0.057,"preflare_start",1400,"preflare_end",300,"target1",162,"shallow_aimpoint",308)),list(695,265,lex("angle1",0.255,"angle2",0.0575,"preflare_start",1500,"preflare_end",100,"target1",165,"shallow_aimpoint",310)),list(708,270,lex("angle1",0.256,"angle2",0.058,"preflare_start",1600,"preflare_end",150,"target1",168,"shallow_aimpoint",312)),list(721,275,lex("angle1",0.257,"angle2",0.0585,"preflare_start",1700,"preflare_end",200,"target1",171,"shallow_aimpoint",314)),list(734,280,lex("angle1",0.258,"angle2",0.059,"preflare_start",1800,"preflare_end",250,"target1",174,"shallow_aimpoint",316)),list(747,285,lex("angle1",0.259,"angle2",0.0595,"preflare_start",1900,"preflare_end",300,"target1",177,"shallow_aimpoint",318)),list(760,290,lex("angle1",0.26,"angle2",0.06,"preflare_start",1000,"preflare_end",100,"target1",180,"shallow_aimpoint",320)),list(773,295,lex("angle1",0.261,"angle2",0.0605,"preflare_start",1100,"preflare_end",150,"target1",183,"shallow_aimpoint",322)),list(786,300,lex("angle1",0.262,"angle2",0.061,"preflare_start",1200,"preflare_end",200,"target1",186,"shallow_aimpoint",324)),list(799,305,lex("angle1",0.263,"angle2",0.0615,"preflare_start",1300,"preflare_end",250,"target1",189,"shallow_aimpoint",326))) { bench_cases:add(extra_case). }

for bench_case in bench_cases {

local expected_value is bench_run_original_calculate_distance_from_alt(bench_case).

if not bench_equal(expected_value,bench_run_candidate_calculate_distance_from_alt(bench_case),"scalar") { set bench_errors to bench_errors+1. }

if not bench_equal(expected_value,bench_run_production_calculate_distance_from_alt(bench_case),"scalar") { set bench_production_errors to bench_production_errors+1. }

}

log "CHECK|calculate_distance_from_alt|"+bench_cases:length+"|"+bench_errors+"|"+bench_production_errors to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_calculate_distance_from_alt@,bench_cases,100,"calculate_distance_from_alt","production",bench_round,bench_log). }

bench_measure(bench_run_original_calculate_distance_from_alt@,bench_cases,100,"calculate_distance_from_alt","original",bench_round,bench_log).

if bench_round <> 2 { bench_measure(bench_run_production_calculate_distance_from_alt@,bench_cases,100,"calculate_distance_from_alt","production",bench_round,bench_log). }

}

}

{

print "Checking calc_vvdot".

local bench_cases is list(list(1000,100,200,100),list(0,100,0,100),list(100,0,100,0),list(-100,50,0,100)).

local bench_errors is 0.

local bench_production_errors is 0.

for extra_case in list(list(-200,0,0,0),list(-100,20,13,7),list(0,40,26,14),list(100,60,39,21),list(200,80,52,28),list(300,100,65,35),list(400,120,78,42),list(500,140,91,49),list(600,160,104,56),list(700,180,117,63),list(800,200,130,70),list(900,0,143,77),list(1000,20,156,84),list(1100,40,169,91),list(1200,60,182,98),list(1300,80,195,105),list(1400,100,208,112),list(1500,120,221,119),list(1600,140,234,126),list(1700,160,247,133),list(1800,180,260,140),list(1900,200,273,147),list(2000,0,286,154),list(2100,20,299,161),list(2200,40,312,168),list(2300,60,325,175),list(2400,80,338,182),list(2500,100,351,189),list(2600,120,364,196),list(2700,140,377,203),list(2800,160,390,210),list(2900,180,403,217),list(3000,200,416,224),list(3100,0,429,231),list(3200,20,442,238),list(3300,40,455,245),list(3400,60,468,252),list(3500,80,481,259),list(3600,100,494,266),list(3700,120,507,273),list(3800,140,520,280),list(3900,160,533,287),list(4000,180,546,294),list(4100,200,559,301),list(4200,0,572,308),list(4300,20,585,315),list(4400,40,598,322),list(4500,60,611,329),list(4600,80,624,336),list(4700,100,637,343),list(4800,120,650,350),list(4900,140,663,357),list(5000,160,676,364),list(5100,180,689,371),list(5200,200,702,378),list(5300,0,715,385),list(5400,20,728,392),list(5500,40,741,399),list(5600,60,754,406),list(5700,80,767,413),list(5800,100,780,420),list(5900,120,793,427),list(6000,140,806,434),list(6100,160,819,441)) { bench_cases:add(extra_case). }

for bench_case in bench_cases {

local expected_value is bench_run_original_calc_vvdot(bench_case).

if not bench_equal(expected_value,bench_run_candidate_calc_vvdot(bench_case),"scalar") { set bench_errors to bench_errors+1. }

if not bench_equal(expected_value,bench_run_production_calc_vvdot(bench_case),"scalar") { set bench_production_errors to bench_production_errors+1. }

}

log "CHECK|calc_vvdot|"+bench_cases:length+"|"+bench_errors+"|"+bench_production_errors to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_calc_vvdot@,bench_cases,2000,"calc_vvdot","production",bench_round,bench_log). }

bench_measure(bench_run_original_calc_vvdot@,bench_cases,2000,"calc_vvdot","original",bench_round,bench_log).

if bench_round <> 2 { bench_measure(bench_run_production_calc_vvdot@,bench_cases,2000,"calc_vvdot","production",bench_round,bench_log). }

}

}

{

print "Checking compass_and_pitch_for".

local bench_cases is list(list(bench_vessel,"default"),list(bench_vessel,v(1,2,3)),list(bench_vessel,v(-2,0,7)),list(bench_vessel,r(20,40,60))).

local bench_errors is 0.

local bench_production_errors is 0.

for extra_case in list(list(bench_vessel,v(-72.85714285714286,-45.27272727272727,1)),list(bench_vessel,v(-53.28571428571428,-38.09090909090909,1)),list(bench_vessel,v(-33.71428571428572,-30.90909090909091,1)),list(bench_vessel,v(-14.14285714285714,-23.72727272727273,1)),list(bench_vessel,v(5.428571428571429,-16.54545454545455,1)),list(bench_vessel,v(25,-9.363636363636363,1)),list(bench_vessel,v(44.57142857142857,-2.181818181818182,1)),list(bench_vessel,v(64.14285714285714,5,1)),list(bench_vessel,v(-62.14285714285715,12.18181818181818,1)),list(bench_vessel,v(-42.57142857142857,19.36363636363636,1)),list(bench_vessel,v(-23,26.54545454545455,1)),list(bench_vessel,v(-3.428571428571428,33.72727272727273,1)),list(bench_vessel,v(16.14285714285714,40.90909090909091,1)),list(bench_vessel,v(35.71428571428572,-42.54545454545455,1)),list(bench_vessel,v(55.28571428571428,-35.36363636363637,1)),list(bench_vessel,v(-71,-28.18181818181818,1)),list(bench_vessel,v(-51.42857142857143,-21,1)),list(bench_vessel,v(-31.85714285714286,-13.81818181818182,1)),list(bench_vessel,v(-12.28571428571429,-6.636363636363637,1)),list(bench_vessel,v(7.285714285714286,0.5454545454545454,1)),list(bench_vessel,v(26.85714285714286,7.727272727272728,1)),list(bench_vessel,v(46.42857142857143,14.90909090909091,1)),list(bench_vessel,v(66,22.09090909090909,1)),list(bench_vessel,v(-60.28571428571428,29.27272727272727,1)),list(bench_vessel,v(-40.71428571428572,36.45454545454545,1)),list(bench_vessel,v(-21.14285714285714,43.63636363636363,1)),list(bench_vessel,v(-1.571428571428571,-39.81818181818182,1)),list(bench_vessel,v(18,-32.63636363636363,1)),list(bench_vessel,v(37.57142857142857,-25.45454545454545,1)),list(bench_vessel,v(57.14285714285715,-18.27272727272727,1)),list(bench_vessel,v(-69.14285714285714,-11.09090909090909,1)),list(bench_vessel,v(-49.57142857142857,-3.909090909090909,1)),list(bench_vessel,v(-30,3.272727272727273,1)),list(bench_vessel,v(-10.42857142857143,10.45454545454546,1)),list(bench_vessel,v(9.142857142857142,17.63636363636364,1)),list(bench_vessel,v(28.71428571428572,24.81818181818182,1)),list(bench_vessel,v(48.28571428571428,32,1)),list(bench_vessel,v(67.85714285714286,39.18181818181818,1)),list(bench_vessel,v(-58.42857142857143,-44.27272727272727,1)),list(bench_vessel,v(-38.85714285714285,-37.09090909090909,1)),list(bench_vessel,v(-19.28571428571428,-29.90909090909091,1)),list(bench_vessel,v(0.2857142857142857,-22.72727272727273,1)),list(bench_vessel,v(19.85714285714286,-15.54545454545454,1)),list(bench_vessel,v(39.42857142857143,-8.363636363636363,1)),list(bench_vessel,v(59,-1.181818181818182,1)),list(bench_vessel,v(-67.28571428571429,6,1)),list(bench_vessel,v(-47.71428571428572,13.18181818181818,1)),list(bench_vessel,v(-28.14285714285714,20.36363636363636,1)),list(bench_vessel,v(-8.571428571428571,27.54545454545455,1)),list(bench_vessel,v(11,34.72727272727273,1)),list(bench_vessel,v(30.57142857142857,41.90909090909091,1)),list(bench_vessel,v(50.14285714285715,-41.54545454545455,1)),list(bench_vessel,v(69.71428571428571,-34.36363636363637,1)),list(bench_vessel,v(-56.57142857142857,-27.18181818181818,1)),list(bench_vessel,v(-37,-20,1)),list(bench_vessel,v(-17.42857142857143,-12.81818181818182,1)),list(bench_vessel,v(2.142857142857143,-5.636363636363637,1)),list(bench_vessel,v(21.71428571428572,1.545454545454545,1)),list(bench_vessel,v(41.28571428571428,8.727272727272727,1)),list(bench_vessel,v(60.85714285714285,15.90909090909091,1)),list(bench_vessel,v(-65.42857142857143,23.09090909090909,1)),list(bench_vessel,v(-45.85714285714285,30.27272727272727,1)),list(bench_vessel,v(-26.28571428571428,37.45454545454545,1)),list(bench_vessel,v(-6.714285714285714,44.63636363636363,1))) { bench_cases:add(extra_case). }

for bench_case in bench_cases {

local expected_value is bench_run_original_compass_and_pitch_for(bench_case).

if not bench_equal(expected_value,bench_run_candidate_compass_and_pitch_for(bench_case),"pair") { set bench_errors to bench_errors+1. }

if not bench_equal(expected_value,bench_run_production_compass_and_pitch_for(bench_case),"pair") { set bench_production_errors to bench_production_errors+1. }

}

log "CHECK|compass_and_pitch_for|"+bench_cases:length+"|"+bench_errors+"|"+bench_production_errors to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_compass_and_pitch_for@,bench_cases,1000,"compass_and_pitch_for","production",bench_round,bench_log). }

bench_measure(bench_run_original_compass_and_pitch_for@,bench_cases,1000,"compass_and_pitch_for","original",bench_round,bench_log).

if bench_round <> 2 { bench_measure(bench_run_production_compass_and_pitch_for@,bench_cases,1000,"compass_and_pitch_for","production",bench_round,bench_log). }

}

}

{
local mutable_samples is list().
for sample_index in range(0,4000) { mutable_samples:add(1). }
local appended_sample is false.
local append_deadline is time:seconds+0.06.
when time:seconds > append_deadline then {
    mutable_samples:add(1).
    set appended_sample to true.
}
local mutable_result is bench_original_avg(mutable_samples,"none").
log "MUTATION|original|"+appended_sample+"|"+mutable_samples:length+"|"+mutable_result to bench_log.
}

{
local mutable_samples is list().
for sample_index in range(0,4000) { mutable_samples:add(1). }
local appended_sample is false.
local append_deadline is time:seconds+0.06.
when time:seconds > append_deadline then {
    mutable_samples:add(1).
    set appended_sample to true.
}
local mutable_result is avg(mutable_samples,"none").
log "MUTATION|production|"+appended_sample+"|"+mutable_samples:length+"|"+mutable_result to bench_log.
}

log "DONE|"+time:seconds to bench_log.

print "FUNCTION BENCHMARK DONE".
