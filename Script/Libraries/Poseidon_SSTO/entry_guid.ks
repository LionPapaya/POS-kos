// Libraries/Poseidon_SSTO/entry_guid.ks
// Purpose: entry guidance helpers that integrate trajectory simulation with the TEAM interface.
// - Functions here run `simulate_trajectory*` and use `calc_entry_traj` solver to produce bank profiles.
// - Used by the reentry orchestration to compute and validate candidate entry trajectories.
// Notes: header comments only.
// is_within_team_interface(simstate, team_interface_box, target_latlong)
// Checks whether a simulated state is inside the TEAM (target) interface box.
// Inputs:
//  - simstate: lexicon with keys ["altitude", "latlong", ...] (see `current_simstate` contract).
//  - team_interface_box: lexicon with keys ["min_altitude", "max_altitude", "dist_tolerance"] describing
//      the acceptable altitude band and lateral tolerance (meters) for entering the TEAM box.
//  - target_latlong: geoposition (latlng) of the target center used to compute lateral distance.
// Returns: boolean true if simstate altitude is within [min_altitude, max_altitude]
// and the horizontal distance (meters) between simstate and target_latlong is less than dist_tolerance.
// Note: uses `calcdistance_m` (meters). This is a pure predicate helper used by the entry solver.
function is_within_team_interface {
    parameter simstate.
    parameter team_interface_box.
    parameter target_latlong.
    return simstate["altitude"] >= team_interface_box["min_altitude"] and
           simstate["altitude"] <= team_interface_box["max_altitude"] and
           calcdistance_m(target_latlong,simstate["latlong"]) < team_interface_box["dist_tolerance"].
}
// calculate_error(simstate, target_conditions)
// Small helper that computes a scalar error metric between a simulated state and desired target conditions.
// Inputs:
//  - simstate: lexicon with keys including "altitude", "velocity" (vector), "latlong".
//  - target_conditions: lexicon with keys "altitude", "velocity", "latlong" describing desired conditions.
// Output: scalar error (higher == worse). Currently a weighted sum of altitude, speed and position errors.
// Weights chosen heuristically: altitude *1.5, speed *5, position *500 (position uses km Haversine by default).
// Usage: used to compare candidate simulated endpoints to decide which is closest to desired interface conditions.
function calculate_error {
    parameter simstate.
    parameter target_conditions.

    local altitude_error is abs(simstate["altitude"] - target_conditions["altitude"]).
    local speed_error is abs(simstate["velocity"]:mag - target_conditions["velocity"]).
    local pos_error is calcdistance(simstate["latlong"], target_conditions["latlong"]).

    // Weighted sum of errors
    return altitude_error*1.5 + speed_error*5 + pos_error*500.
}

// closest_simstate(simstates, target_conditions)
// Given a list of simstate entries (each expected to be a lexicon with key "final_state"),
// returns the `final_state` whose error (according to `calculate_error`) is minimal.
// This is a simple utility used when several candidate simulations are produced and the algorithm
// must pick the best match to the target conditions.
function closest_simstate {
    parameter simstates.
    parameter target_conditions.

    local closest_simstate_ is simstates[0]["final_state"].
    local min_error is calculate_error(simstates[0]["final_state"], target_conditions).

    for simstate_ in simstates {
        local error is calculate_error(simstate_["final_state"], target_conditions).
        if error < min_error {
            set min_error to error.
            set closest_simstate_ to simstate_["final_state"].
        }
    }

    return closest_simstate_.
}
// check_cur_error(simstate, bank_side, bank_angle, target_latlong, target_altitude)
// - Runs a short simulation with the provided bank command and returns a percentage error that
//   indicates how much closer/farther the simulated state moved relative to the current distance to target.
// Inputs:
//  - simstate: starting simulated state (see `current_simstate`).
//  - bank_side: string "left" or "right" (which side to bank towards).
//  - bank_angle: scalar bank angle (degrees) to apply during the simulation.
//  - target_latlong: the target geoposition to measure against.
//  - target_altitude: altitude at which to stop the short sim.
// Returns: percentage (via `calc_percentage`) representing the change in distance as a percent of the original distance.
//   Positive values mean improvement (moved closer), negative means moved further away.
function check_cur_error {
    parameter simstate.
    parameter bank_side.
    parameter bank_angle.
    parameter target_latlong.
    parameter target_altitude.

    // Simulate the trajectory with the given bank_side and bank_angle
    local simulated_state is simulate_trajectory(simstate, bank_angle, bank_side, target_altitude).

    // Calculate the cur_state_error
    local cur_state_error is calcdistance(simstate["latlng"], target_latlong) - calcdistance(simstate["latlng"], simulated_state["latlong"]).

    // Calculate the cur_state_%error
    local cur_state_error_p is calc_percentage(cur_state_error, calcdistance(simstate["latlng"], target_latlong)).

    return cur_state_error_p.
}
// check_if_entry_possible(simstate, target_latlng, target_altitude, timestep)
// Performs a set of forward simulations to determine whether the vehicle, starting at `simstate`,
// can reach an entry corridor that allows an approach to `target_latlong`.
// Algorithm summary:
// 1. Simulate a set of coarse bank options and collect their endpoint lat/longs.
// 2. Use geometry (triangle or square region) to test whether `target_latlng` lies inside the reachability region.
// 3. Return a lexicon containing: left_pos, right_pos, max_pos, a boolean `is_inside` (set by `check_target_*`),
//    and summary min/max bank bounds (in degrees) describing search intervals for the solver.
// Inputs:
//  - simstate: starting simulation state (see `current_simstate`).
//  - target_latlong: geoposition of runway/target.
//  - timestep: simulation timestep (defaults to AVES["simulation"]["timestep"]).
// Notes on behavior:
//  - The function adapts between a triangular region (if a 45deg bank envelope is sufficient) and
//    a square region (when larger bank angles or reversed headings are required). This provides a
//    conservative reachable set for entry planning.
function check_if_entry_possible{
    parameter simstate.
    parameter target_latlong.
    parameter target_altitude is AVES["TEAMAltitude"].
    parameter timestep is AVES["simulation"]["timestep"].
    parameter sim_context_mu is BODY:mu.
    parameter sim_context_radius is BODY:radius.
    parameter sim_context_angularvel is BODY:angularvel.
    parameter sim_context_mass is SHIP:MASS.
    parameter sim_context_vessel_fore is SHIP:FACING:FOREVECTOR:NORMALIZED.
    parameter sim_context_vessel_top is SHIP:FACING:TOPVECTOR:NORMALIZED.
    parameter sim_context_vessel_right is VCRS(SHIP:FACING:TOPVECTOR:NORMALIZED,SHIP:FACING:FOREVECTOR:NORMALIZED):NORMALIZED.
    parameter use_entry_sim_heading is false.

    local check_45 is sim_with_bank(simstate, 45, target_altitude, target_latlong,timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right,use_entry_sim_heading)["final_state"].
    local c is false.
    // Use a probe point projected along the current simstate heading to avoid great-circle wrap-around
    // Compute the current heading and pick the closer of the 45deg-endpoint or the raw target.
    // Project a point from the simstate along its heading half-way to the closer point, then do the
    // distance comparison from that probe. This avoids misclassification when the naive distance from
    // the origin is warped by great-circle geometry.
    local sim_hed is compass_for_simstate(simstate).
    local d45 is calcdistance_m(check_45["latlong"], simstate["latlong"]).
    local dtarget is calcdistance_m(simstate["latlong"], target_latlong).
    local closer_pos is check_45["latlong"].
    if dtarget < d45 { set closer_pos to target_latlong. }
    local half_dist is calcdistance_m(closer_pos, simstate["latlong"]) / 2.
    local probe_pos is get_geoposition_along_heading(simstate["latlong"], sim_hed, half_dist).
    if calcdistance_m(check_45["latlong"], probe_pos) > calcdistance_m(probe_pos, target_latlong) {
        set c to true.
    }
    local check is 0.
    if not(c){
    local max_distance is sim_with_bank(simstate, 0, target_altitude, target_latlong,timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right,use_entry_sim_heading)["final_state"].
    local right_distance is simulate_trajectory(simstate, 45, "right", target_altitude,simstate["altitude"]+100,"EGAOA",timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right).
    local left_distance is simulate_trajectory(simstate, 45, "left", target_altitude,simstate["altitude"]+100,"EGAOA",timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right).
    local left_distance_t to left_distance["latlong"].
    local right_distance_t to right_distance["latlong"].
    set check to check_target_in_triangle(target_latlong,max_distance["latlong"],right_distance_t,left_distance_t).

    check:add("left_pos",left_distance_t).
    check:add("right_pos",right_distance_t).
    check:add("max_pos",max_distance["latlong"]).
    check:add("max",45).
    check:add("min",0).
    check:add("lower_bank_pos",max_distance["latlong"]).
    check:add("upper_bank_pos",check_45["latlong"]).


    }else{
        local min_distance is sim_with_bank(simstate, 90, target_altitude,target_latlong,timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right,use_entry_sim_heading)["final_state"].
        local right_distance is simulate_trajectory(simstate, 45, "right", target_altitude,simstate["altitude"]+100,"EGAOA",timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right).
        local left_distance is simulate_trajectory(simstate, 45, "left", target_altitude,simstate["altitude"]+100,"EGAOA",timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right).
        local left_distance_t to left_distance["latlong"].
        local right_distance_t to right_distance["latlong"].
        local hed is heading_between(left_distance_t,right_distance_t).
        local dist is calcdistance_m(left_distance_t,right_distance_t)/6.
        local back_right is get_geoposition_along_heading(min_distance["latlong"],hed,dist).
        local back_left is get_geoposition_along_heading(min_distance["latlong"],hed+180,dist).
        set check to check_target_in_square(target_latlong,left_distance_t,right_distance_t,back_right,back_left).

        
        check:add("left_pos",left_distance_t).
        check:add("right_pos",right_distance_t).
        check:add("max_pos",min_distance["latlong"]).
        check:add("max",90).
        check:add("min",45).
        check:add("lower_bank_pos",check_45["latlong"]).
        check:add("upper_bank_pos",min_distance["latlong"]).

    }
    return check.
}
// entry_possible_square(simstate, timestep)
// Convenience wrapper that returns a list of four forward-simulated states using bank angles [0,45,45,90].
// The returned list is used by upper-level logic to test which runways/targets fall within the reachable box.
function entry_possible_square{
    parameter simstate.
    parameter timestep is AVES["simulation"]["timestep"].
   
    local out is list(
        simulate_trajectory(simstate, 0, "right",   AVES["TEAMAltitude"],simstate["altitude"]+100,"EGAOA",timestep),
        simulate_trajectory(simstate, 45, "right",   AVES["TEAMAltitude"],simstate["altitude"]+100,"EGAOA",timestep),
        simulate_trajectory(simstate, 45, "left",   AVES["TEAMAltitude"],simstate["altitude"]+100,"EGAOA",timestep),
        simulate_trajectory(simstate, 90, "left",  AVES["TEAMAltitude"],simstate["altitude"]+100,"EGAOA",timestep),
        simulate_trajectory(simstate, 90, "right",  AVES["TEAMAltitude"],simstate["altitude"]+100,"EGAOA",timestep)

    ). 
    return out.
}
// sim_with_bank(simstate, bank_angle, target_altitude, target_latlong, timestep)
// Runs a time-stepping simulation that repeatedly applies the same bank_angle with the
// appropriate bank side (computed from heading error) until the simulated altitude falls below
// `target_altitude`. It records control steps (timestamped) and returns a lexicon {"control", "final_state"}.
// Inputs:
//  - simstate: starting simstate lexicon.
//  - bank_angle: scalar bank command (degrees).
//  - target_altitude: stop altitude for the simulation.
//  - target_latlong: final target geoposition used to compute heading error and bank side.
//  - timestep: simulation timestep (defaults to AVES["simulation"]["timestep"]).
// Output:
//  - lexicon with keys:
//     - "control": lex of time-indexed entries containing simstate snapshot and the inputs (bank_side, bank_angle)
//     - "final_state": the final simstate when altitude < target_altitude.
// Notes: This function is deterministic and used by the higher-level entry solver to predict final positions
// for a fixed bank profile.
// Project the same zero-acceleration heading sample that compass_for_simstate
// produces through update_simstate(simstate, list(), timestep).  This helper is
// intentionally entry-simulation-specific; generic compass_for_simstate remains
// available unchanged to its existing callers.
function entry_sim_heading_for_simstate {
    parameter simstate.

    // With an empty acceleration list, update_simstate computes exactly this
    // position before passing it to vec2pos.  Its other derived fields are not
    // read by heading_between.
    local projected_position is simstate["position"] + simstate["velocity"] * AVES["simulation"]["timestep"].
    local projected_latlong is vec2pos(projected_position).
    return heading_between(simstate["latlong"], projected_latlong).
}

// Select the irreversible EG -> TEAM handoff once the live vehicle captures
// the interface, has clearly passed it, or has fallen below it.  Keeping this
// decision separate from terminal control prevents TEAM commands from moving
// the aircraft out of the gate before the state transition is committed.
function entry_team_handoff_reason {
    parameter target_distance_m.
    parameter closest_distance_m.
    parameter current_altitude_m.
    parameter target_altitude_m.
    parameter current_airspeed_mps.
    parameter current_vertical_speed_mps.
    parameter gate_elapsed_s.
    parameter handoff_config.

    local inside_primary_gate is
        target_distance_m <= handoff_config["distance_tolerance"] and
        current_altitude_m >= target_altitude_m + handoff_config["minimum_altitude_offset"] and
        current_altitude_m <= target_altitude_m + handoff_config["maximum_altitude_offset"] and
        current_airspeed_mps <= handoff_config["maximum_airspeed"] and
        current_vertical_speed_mps <= handoff_config["maximum_climb_rate"].
    if inside_primary_gate and gate_elapsed_s >= handoff_config["stable_time"] {
        return "gate".
    }

    local passed_gate is
        closest_distance_m <= handoff_config["distance_tolerance"] and
        target_distance_m >= closest_distance_m + handoff_config["passed_distance_growth"] and
        current_altitude_m <= target_altitude_m + handoff_config["passed_maximum_altitude_offset"] and
        current_airspeed_mps <= handoff_config["maximum_airspeed"].
    if passed_gate { return "passed_gate". }

    if current_altitude_m < target_altitude_m + handoff_config["minimum_altitude_offset"] and
       current_airspeed_mps <= handoff_config["maximum_airspeed"] {
        return "below_interface".
    }
    return "".
}

// Rate-limit the first TEAM commands from the command actually being flown at
// handoff.  Unlike the old pre-handoff blend, this cannot change gate capture.
function entry_handoff_rate_limit {
    parameter current_command.
    parameter requested_command.
    parameter elapsed_s.
    parameter rate_per_s.
    local maximum_change is max(0,elapsed_s) * max(0,rate_per_s).
    return max(current_command-maximum_change,min(current_command+maximum_change,requested_command)).
}

function sim_with_bank{
    parameter simstate.
    parameter bank_angle.
    parameter target_altitude.
    parameter target_latlong.
    parameter timestep is AVES["simulation"]["timestep"].
    parameter sim_context_mu is BODY:mu.
    parameter sim_context_radius is BODY:radius.
    parameter sim_context_angularvel is BODY:angularvel.
    parameter sim_context_mass is SHIP:MASS.
    parameter sim_context_vessel_fore is SHIP:FACING:FOREVECTOR:NORMALIZED.
    parameter sim_context_vessel_top is SHIP:FACING:TOPVECTOR:NORMALIZED.
    parameter sim_context_vessel_right is VCRS(SHIP:FACING:TOPVECTOR:NORMALIZED,SHIP:FACING:FOREVECTOR:NORMALIZED):NORMALIZED.
    parameter use_entry_sim_heading is false.

    local out is lex().
    local contrl is lex().
    local bank_side is "left".

    local hed is 0.
    if use_entry_sim_heading {
        set hed to entry_sim_heading_for_simstate(simstate).
    } else {
        set hed to compass_for_simstate(simstate).
    }
    local hed2tgt is heading_between(simstate["latlong"],target_latlong).
    local heading_error is normalized_heading_error(hed,hed2tgt).
    if heading_error > 0{
        set bank_side to "right".
    }
    if heading_error < 0{
        set bank_side to "left".
    }
    until simstate["altitude"] < target_altitude{
        set hed to 0.
        if use_entry_sim_heading {
            set hed to entry_sim_heading_for_simstate(simstate).
        } else {
            set hed to compass_for_simstate(simstate).
        }
        set hed2tgt to heading_between(simstate["latlong"],target_latlong).
        set heading_error to normalized_heading_error(hed,hed2tgt).
        if heading_error > AVES["EG_rev°"]{
            set bank_side to "right".
        }
        if heading_error < -AVES["EG_rev°"]{
            set bank_side to "left".
        }
        contrl:add(simstate["simtime"],lex("simstate",simstate,"inputs",lex("bank_side",bank_side,"bank_angle",bank_angle))).
        set simstate to simulate_trajectory_time(simstate,bank_angle,bank_side,timestep,"EGAOA",timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right).

    }
    // Include the terminal point so even a one-step recovery trajectory has
    // a chronological segment for the live reference lookup.
    contrl:add(simstate["simtime"],lex("simstate",simstate,"inputs",lex("bank_side",bank_side,"bank_angle",bank_angle))).
    out:add("control",contrl).
    out:add("final_state",simstate).
    return out.
}

// Return the geometric miss distance from a simulated endpoint to the TEAM
// box. A state inside both tolerances has zero miss; an outside state combines
// its remaining horizontal and vertical miss.
function entry_team_box_miss {
    parameter final_state.
    parameter target_latlong.
    parameter team_interface_box.
    local horizontal_miss is max(0,calcdistance_m(final_state["latlong"],target_latlong)-team_interface_box["dist_tolerance"]).
    local altitude_miss is 0.
    if final_state["altitude"] < team_interface_box["min_altitude"] {
        set altitude_miss to team_interface_box["min_altitude"]-final_state["altitude"].
    } else if final_state["altitude"] > team_interface_box["max_altitude"] {
        set altitude_miss to final_state["altitude"]-team_interface_box["max_altitude"].
    }
    return sqrt(horizontal_miss*horizontal_miss+altitude_miss*altitude_miss).
}

// Signed downrange residual used to decide which side of the TEAM target a
// candidate reaches. This is the same range convention used by calc_entry_traj:
// positive travels farther than the target range; negative falls short.
function entry_predictive_range_error {
    parameter start_latlong.
    parameter final_latlong.
    parameter target_latlong.
    return calcdistance_m(start_latlong,final_latlong)-calcdistance_m(start_latlong,target_latlong).
}

// Use the signed range residuals to estimate the zero-crossing bank. TEAM-box
// misses remain the fallback when the local range sensitivity is degenerate.
// Every result is limited per update and by the total authority envelope.
function entry_predictive_bank_command {
    parameter current_bank.
    parameter lower_bank.
    parameter lower_range_error.
    parameter lower_miss.
    parameter upper_bank.
    parameter upper_range_error.
    parameter upper_miss.
    parameter minimum_bank.
    parameter maximum_bank.
    parameter maximum_change.

    local bank_span is upper_bank-lower_bank.
    local error_span is upper_range_error-lower_range_error.
    local valid_solution is abs(bank_span) > 0.001.
    local valid_range_sensitivity is valid_solution and abs(error_span) > 0.001.
    local next_bank is current_bank.
    local sensitivity is 0.
    if valid_range_sensitivity {
        set sensitivity to error_span/bank_span.
        // Secant extrapolation is intentional when both candidates miss on
        // the same side; that is precisely when unsigned miss cannot recover.
        set next_bank to lower_bank-lower_range_error/sensitivity.
        set next_bank to max(current_bank-maximum_change,min(current_bank+maximum_change,next_bank)).
        set next_bank to max(minimum_bank,min(maximum_bank,next_bank)).
    } else if valid_solution {
        if lower_miss < upper_miss-0.001 {
            set next_bank to lower_bank.
        } else if upper_miss < lower_miss-0.001 {
            set next_bank to upper_bank.
        }
        set next_bank to max(current_bank-maximum_change,min(current_bank+maximum_change,next_bank)).
        set next_bank to max(minimum_bank,min(maximum_bank,next_bank)).
    }
    return lex(
        "valid",valid_solution,
        "bank",next_bank,
        "sensitivity",sensitivity
    ).
}

// Convert one already-computed guidance prediction to energy/range samples.
// This only reads the trace returned by sim_with_bank; it never runs a search.
function entry_display_prediction_samples {
    parameter prediction.
    parameter target_latlong.
    local samples is list().
    if not prediction:haskey("control") { return samples. }
    local controls is prediction["control"].
    local control_times is controls:keys.
    local sample_count is min(16,control_times:length).
    if sample_count < 2 { return samples. }
    for sample_index in range(0,sample_count) {
        local control_index is 0.
        if sample_count > 1 {
            set control_index to round(sample_index*(control_times:length-1)/(sample_count-1)).
        }
        // Each trace is sampled independently. These indices are never paired
        // between low/high predictions; entry_display_blend_path matches them
        // later by energy height.
        local state is controls[control_times[control_index]]["simstate"].
        local speed is state["surfvel"]:mag.
        local energy_height is state["altitude"] + speed*speed/(2*9.81).
        local remaining_range is calcdistance_m(state["latlong"],target_latlong).
        samples:add(lex("energy",energy_height,"range",remaining_range)).
    }
    return samples.
}

function entry_display_empty_path {
    parameter reason.
    return lex("valid",false,"reason",reason,"points",list(),
        "weight",0,"energy_min",0,"energy_max",0).
}

// The prediction traces are chronological, so energy height should be
// monotonic apart from sub-metre integration noise. Larger reversals make the
// energy-to-range mapping ambiguous; hide the path instead of drawing a loop.
function entry_display_samples_monotonic {
    parameter samples.
    if samples:length < 2 { return false. }
    local direction is 0.
    local sample_index is 1.
    until sample_index >= samples:length {
        local change is samples[sample_index]["energy"]-samples[sample_index-1]["energy"].
        if change > 1 {
            if direction < 0 { return false. }
            set direction to 1.
        } else if change < -1 {
            if direction > 0 { return false. }
            set direction to -1.
        }
        set sample_index to sample_index+1.
    }
    return direction <> 0.
}

// Interpolate range on a trajectory at an energy height shared by both bank
// predictions. Different sample counts and timestamps are deliberately ignored.
function entry_display_range_at_energy {
    parameter samples.
    parameter energy_height.
    local result is lex("valid",false,"range",0,"reason","outside_coverage").
    if not entry_display_samples_monotonic(samples) {
        set result["reason"] to "nonmonotonic_energy".
        return result.
    }
    local minimum_energy is min(samples[0]["energy"],samples[samples:length-1]["energy"]).
    local maximum_energy is max(samples[0]["energy"],samples[samples:length-1]["energy"]).
    if energy_height < minimum_energy or energy_height > maximum_energy { return result. }
    local sample_index is 1.
    until sample_index >= samples:length {
        local energy0 is samples[sample_index-1]["energy"].
        local energy1 is samples[sample_index]["energy"].
        if (energy_height >= energy0 and energy_height <= energy1) or
           (energy_height >= energy1 and energy_height <= energy0) {
            local range0 is samples[sample_index-1]["range"].
            local range1 is samples[sample_index]["range"].
            if abs(energy1-energy0) <= 1 {
                set result["range"] to (range0+range1)/2.
            } else {
                local fraction is (energy_height-energy0)/(energy1-energy0).
                set result["range"] to range0+(range1-range0)*fraction.
            }
            set result["valid"] to true.
            set result["reason"] to "ok".
            return result.
        }
        set sample_index to sample_index+1.
    }
    return result.
}

// Advance through a monotonic trace from the prior segment. The full path
// builder calls this once per displayed point, keeping trace work linear in
// the number of prediction samples instead of rescanning the trace each time.
function entry_display_range_at_energy_cursor {
    parameter samples.
    parameter energy_height.
    parameter start_index.
    parameter descending.
    local index is start_index.
    local result is lex("valid",false,"range",0,"index",index).
    if descending {
        until index >= samples:length-1 {
            local energy0 is samples[index]["energy"].
            local energy1 is samples[index+1]["energy"].
            if energy_height <= energy0 and energy_height >= energy1 {
                local range0 is samples[index]["range"].
                local range1 is samples[index+1]["range"].
                if abs(energy1-energy0) <= 1 {
                    set result["range"] to (range0+range1)/2.
                } else {
                    local fraction is (energy_height-energy0)/(energy1-energy0).
                    set result["range"] to range0+(range1-range0)*fraction.
                }
                set result["valid"] to true.
                set result["index"] to index.
                return result.
            }
            set index to index+1.
        }
    } else {
        until index < 0 {
            local energy0 is samples[index]["energy"].
            local energy1 is samples[index+1]["energy"].
            if energy_height >= energy0 and energy_height <= energy1 {
                local range0 is samples[index]["range"].
                local range1 is samples[index+1]["range"].
                if abs(energy1-energy0) <= 1 {
                    set result["range"] to (range0+range1)/2.
                } else {
                    local fraction is (energy_height-energy0)/(energy1-energy0).
                    set result["range"] to range0+(range1-range0)*fraction.
                }
                set result["valid"] to true.
                set result["index"] to index.
                return result.
            }
            set index to index-1.
        }
    }
    return result.
}

// Blend the two already-computed bank traces at common energy heights using
// the bank command selected by guidance. A collapsed bank span uses the lower
// (identical-bank) trace with weight zero instead of dividing by zero.
function entry_display_blend_path {
    parameter lower_samples.
    parameter upper_samples.
    parameter lower_bank.
    parameter upper_bank.
    parameter selected_bank.
    parameter requested_point_count is 16.
    local result is lex("valid",false,"reason","short_path","points",list(),
        "weight",0,"energy_min",0,"energy_max",0).
    if lower_samples:length < 2 or upper_samples:length < 2 { return result. }
    if not entry_display_samples_monotonic(lower_samples) or
       not entry_display_samples_monotonic(upper_samples) {
        set result["reason"] to "nonmonotonic_energy".
        return result.
    }
    local lower_minimum is min(lower_samples[0]["energy"],lower_samples[lower_samples:length-1]["energy"]).
    local lower_maximum is max(lower_samples[0]["energy"],lower_samples[lower_samples:length-1]["energy"]).
    local upper_minimum is min(upper_samples[0]["energy"],upper_samples[upper_samples:length-1]["energy"]).
    local upper_maximum is max(upper_samples[0]["energy"],upper_samples[upper_samples:length-1]["energy"]).
    local shared_minimum is max(lower_minimum,upper_minimum).
    local shared_maximum is min(lower_maximum,upper_maximum).
    if shared_maximum <= shared_minimum {
        set result["reason"] to "no_shared_energy".
        return result.
    }
    local bank_span is upper_bank-lower_bank.
    local weight is 0.
    if abs(bank_span) > 0.001 {
        set weight to (selected_bank-lower_bank)/bank_span.
        set weight to max(0,min(1,weight)).
    }
    local point_count is max(2,min(20,round(requested_point_count))).
    local points is list().
    local lower_descending is lower_samples[0]["energy"] > lower_samples[lower_samples:length-1]["energy"].
    local upper_descending is upper_samples[0]["energy"] > upper_samples[upper_samples:length-1]["energy"].
    local lower_index is lower_samples:length-2.
    local upper_index is upper_samples:length-2.
    if lower_descending { set lower_index to 0. }
    if upper_descending { set upper_index to 0. }
    local sample_index is 0.
    until sample_index >= point_count {
        local energy_height is shared_maximum -
            (shared_maximum-shared_minimum)*sample_index/(point_count-1).
        local lower_range is entry_display_range_at_energy_cursor(
            lower_samples,energy_height,lower_index,lower_descending).
        local upper_range is entry_display_range_at_energy_cursor(
            upper_samples,energy_height,upper_index,upper_descending).
        if not lower_range["valid"] or not upper_range["valid"] {
            set result["reason"] to "missing_energy_sample".
            return result.
        }
        set lower_index to lower_range["index"].
        set upper_index to upper_range["index"].
        local blended_range is lower_range["range"]+
            (upper_range["range"]-lower_range["range"])*weight.
        points:add(lex("energy",energy_height,"range",blended_range)).
        set sample_index to sample_index+1.
    }
    set result["valid"] to true.
    set result["reason"] to "ok".
    set result["points"] to points.
    set result["weight"] to weight.
    set result["energy_min"] to shared_minimum.
    set result["energy_max"] to shared_maximum.
    return result.
}

// Temporary entry-solver diagnostics.  This intentionally does not use the
// structured flight logger: those logs describe the live vehicle and exclude
// the synchronous simulation that calc_entry_traj performs.  The one call in
// calc_entry_traj below is the only activation point.  Comment out that call
// when this investigation is complete; then this function performs no work,
// creates no file, and consumes no runtime opcodes.
function entry_traj_debug_iteration {
    parameter iteration.
    parameter start_sim.
    parameter target_altitude.
    parameter target_latlong.
    parameter team_interface_box.
    parameter reachable.
    parameter bank_side.
    parameter target_distance.
    parameter lower_bound.
    parameter upper_bound.
    parameter lower_error_before.
    parameter upper_error_before.
    parameter predicted_bank.
    parameter predict.
    parameter predicted_distance.
    parameter candidate_error.
    parameter inside_interface.

    local final_state is predict["final_state"].
    local target_error is calcdistance_m(final_state["latlong"],target_latlong).
    local final_speed is final_state["surfvel"]:mag.
    local trace_file is "entry_traj_debug.log".

    log "--- ENTRY TRAJ ITERATION " + iteration + " ---" to trace_file.
    log "target|lat=" + target_latlong:lat + "|lng=" + target_latlong:lng + "|alt=" + target_altitude + "|box_min_alt=" + team_interface_box["min_altitude"] + "|box_max_alt=" + team_interface_box["max_altitude"] + "|box_tolerance=" + team_interface_box["dist_tolerance"] to trace_file.
    log "start|time=" + start_sim["simtime"] + "|lat=" + start_sim["latlong"]:lat + "|lng=" + start_sim["latlong"]:lng + "|alt=" + start_sim["altitude"] + "|speed=" + start_sim["surfvel"]:mag + "|target_distance=" + target_distance + "|bank_side=" + bank_side to trace_file.
    log "reachable|inside=" + reachable["is_inside"] + "|bank_min=" + reachable["min"] + "|bank_max=" + reachable["max"] + "|max=" + reachable["max_pos"] + "|left=" + reachable["left_pos"] + "|right=" + reachable["right_pos"] + "|lower_endpoint=" + reachable["lower_bank_pos"] + "|upper_endpoint=" + reachable["upper_bank_pos"] to trace_file.
    log "bracket|lower_bank=" + lower_bound["bank"] + "|lower_dist=" + lower_bound["dist"] + "|upper_bank=" + upper_bound["bank"] + "|upper_dist=" + upper_bound["dist"] + "|lower_error_before=" + lower_error_before + "|upper_error_before=" + upper_error_before to trace_file.
    log "candidate|bank=" + predicted_bank + "|path_dist=" + predicted_distance + "|path_error=" + candidate_error + "|final_target_error=" + target_error + "|inside_interface=" + inside_interface + "|final_time=" + final_state["simtime"] + "|final_lat=" + final_state["latlong"]:lat + "|final_lng=" + final_state["latlong"]:lng + "|final_alt=" + final_state["altitude"] + "|final_speed=" + final_speed to trace_file.
}
// calc_entry_traj(input_simstate, target_altitude, target_latlong, team_interface_box, wait_mode, wait_value)
// High level entry trajectory solver. Attempts to find a single bank profile (a scalar bank angle plus bank side)
// that guides the vehicle from `input_simstate` into the TEAM interface box around `target_latlong` at `target_altitude`.
//
// Overview of the algorithm:
// 1) Create a short "start_sim" by simulating forward to a reference altitude or time (controlled by `wait_mode`).
//    This provides the origin of the entry search (it defines the point from which bank profiles are applied).
// 2) Use `check_if_entry_possible` to build a conservative reachable region (left/right/max positions). If target is
//    not inside that region, report failure immediately.
// 3) Initialize lower/upper bank bounds from the reachability result and compute a target distance `tgt_dist` to the runway.
// 4) Iteratively (bounded by `AVES["simulation"]["max_iterations"]`) predict a bank angle `pred_b` using `find_zero_input`
//    to map the expected change-in-distance to the desired `tgt_dist`. For each candidate `pred_b`:
//    a) simulate forward using `sim_with_bank(simstate, pred_b, ...)` to get a predicted final state and control trace.
//    b) compare the predicted distance to `tgt_dist` and tighten the bank bounds accordingly (binary/predictive search).
//    c) If the predicted final state lies inside `team_interface_box` (checked with `is_within_team_interface`), the solver
//       has converged — it returns a lexicon with `converged_sim`, `final_state`, `bank`, and `error` information.
// 5) If iterations exceed the max allowed without convergence, return with `converged=false` and an error description.
//
// Inputs:
//  - input_simstate: starting simstate lexicon (from `current_simstate()` or a pre-simulated state).
//  - target_altitude: scalar altitude that the solver aims to reach when entering the TEAM box.
//  - target_latlong: geoposition for the TEAM target.
//  - team_interface_box: lexicon describing acceptable altitudes and lateral tolerance.
//  - wait_mode: "alt" (default) or "time"; determines whether initial forward integration stops at a reference altitude or after
//       a fixed time interval.
//  - wait_value: value used by wait_mode. Typical default is `AVES["simulation"]["entry_ref_alt"]`.
//
// Output: lexicon with keys:
//  - `converged` (bool): whether the solver found a valid bank profile.
//  - `converged_sim`: if converged, a lexicon mapping time steps to control inputs and simstates (used to replay the plan).
//  - `final_state`: simulated final state at convergence.
//  - `bank`: predicted bank angle (degrees) to use.
//  - `error`: lexicon describing failure mode or the converged message and the left/right/max positions used.
//
// Edge cases and notes:
//  - The method relies on `simulate_trajectory`/`simulate_trajectory_time` and therefore on aerodynamic sampling.
//    Accuracy depends on `AVES["simulation"]["timestep"]`. The solver temporarily reduces timestep to 1 for the start_sim
//    forward propagation to get a deterministic starting point.
//  - If `check_if_entry_possible` reports `is_inside=false` we abort early (target unreachable).
//  - The search is effectively a root-finding on distance vs bank angle using `find_zero_input` to predict a candidate bank.
//  - Returned `converged_sim` contains the control trace which can be merged into a flight plan and executed/visualized.
//
// Implementation: only comment changes were made here; logic unchanged.
function calc_entry_traj {
    parameter input_simstate.
    parameter target_altitude.
    parameter target_latlong.
    parameter team_interface_box.
    parameter wait_mode is "alt".
    parameter wait_value is  AVES["simulation"]["entry_ref_alt"].

    // Capture the live values once so every candidate within this solve uses
    // the same body, mass, and vessel-frame reference.
    local sim_context_mu is BODY:mu.
    local sim_context_radius is BODY:radius.
    local sim_context_angularvel is BODY:angularvel.
    local sim_context_mass is SHIP:MASS.
    local sim_context_vessel_fore is SHIP:FACING:FOREVECTOR:NORMALIZED.
    local sim_context_vessel_top is SHIP:FACING:TOPVECTOR:NORMALIZED.
    local sim_context_vessel_right is VCRS(sim_context_vessel_top,sim_context_vessel_fore):NORMALIZED.

    local output is lex("converged",false).
    output:add("iterations",1).
    local org_timestep is AVES["simulation"]["timestep"].
    set AVES["simulation"]["timestep"] to 1.
    local start_sim is 0.
    if wait_mode = "ALT"{
        set start_sim to simulate_trajectory(input_simstate, 0, "left", wait_value,input_simstate["altitude"]+100,"EGAOA",AVES["simulation"]["timestep"],sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right).
    }else{
        set start_sim to simulate_trajectory_time(input_simstate, 0, "left", wait_value,"EGAOA",AVES["simulation"]["timestep"],sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right).
    }
    set AVES["simulation"]["timestep"] to org_timestep.
    local is_eg_pos is check_if_entry_possible(start_sim,target_latlong,target_altitude,org_timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right,true).
    local bank_angle is 0.
    local tgt_dist is calcdistance_m(start_sim["latlong"],target_latlong).
    local lower_bound is lex("bank",is_eg_pos["min"],"dist",99999999999).
    local upper_bound is lex("bank",is_eg_pos["max"],"dist",99999999999).
    output:add("crossrange",calcdistance_m(is_eg_pos["left_pos"],is_eg_pos["right_pos"]) / 2). // Crossrange is the distance between the left and right positions / 2
    if not is_eg_pos["is_inside"]{
        output:add("error",lex("str","Target not reachable", "max", is_eg_pos["max_pos"],"left",is_eg_pos["left_pos"],"right",is_eg_pos["right_pos"], "target",target_latlong,"min_bank", is_eg_pos["min"])).

        set output:converged to false.
        return output.
    }else{
        if is_eg_pos["distance2"] < is_eg_pos["distance3"]{
            set bank_side to "right".
        }else{
            set bank_side to "left".
        }
        // Seed the solver with endpoints produced by the same dynamically
        // bank-reversing model and the same target altitude used below.
        set lower_bound["dist"] to calcdistance_m(
            start_sim["latlong"],is_eg_pos["lower_bank_pos"]
        ).
        set upper_bound["dist"] to calcdistance_m(
            start_sim["latlong"],is_eg_pos["upper_bank_pos"]
        ).

    }

    until output:converged  or output["iterations"] > AVES["simulation"]["max_iterations"]{
                
        set simstate to clone_simstate(start_sim).
        local control_outputs is lex(0,lex("simstate",simstate,"inputs",lex("bank_side",bank_side,"bank_angle",bank_angle))).

        local d_u is upper_bound["dist"] - tgt_dist.
        local d_l is lower_bound["dist"] - tgt_dist.

        // A secant estimate is valid only while the endpoint errors bracket
        // zero. If they do not, expand to the physical 0..90 degree limits
        // and re-simulate rather than extrapolating to a negative bank.
        if d_l * d_u > 0 {
            if lower_bound["bank"] > 0 {
                set lower_bound["bank"] to 0.
                local lower_predict is sim_with_bank(
                    clone_simstate(start_sim),0,target_altitude,target_latlong,org_timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right,true
                ).
                set lower_bound["dist"] to calcdistance_m(
                    lower_predict["final_state"]["latlong"],start_sim["latlong"]
                ).
            }
            if (lower_bound["dist"] - tgt_dist) * d_u > 0
                and upper_bound["bank"] < 90 {
                set upper_bound["bank"] to 90.
                local upper_predict is sim_with_bank(
                    clone_simstate(start_sim),90,target_altitude,target_latlong,org_timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right,true
                ).
                set upper_bound["dist"] to calcdistance_m(
                    upper_predict["final_state"]["latlong"],start_sim["latlong"]
                ).
            }
            set d_l to lower_bound["dist"] - tgt_dist.
            set d_u to upper_bound["dist"] - tgt_dist.
        }

        local pred_b is (lower_bound["bank"] + upper_bound["bank"]) / 2.
        if d_l * d_u <= 0 and abs(d_u - d_l) > 0.001 {
            set pred_b to find_zero_input(lower_bound["bank"],d_l,upper_bound["bank"],d_u).
        }
        set pred_b to max(
            max(0,lower_bound["bank"]),
            min(min(90,upper_bound["bank"]),pred_b)
        ).
        local predict is sim_with_bank(simstate, pred_b, target_altitude, target_latlong,org_timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right,true).
        local dist is calcdistance_m(predict["final_state"]["latlong"], simstate["latlong"]).

        local candidate_error is dist - tgt_dist.
        if d_l * candidate_error <= 0 {
            set upper_bound["bank"] to pred_b.
            set upper_bound["dist"] to dist.
        } else {
            set lower_bound["bank"] to pred_b.
            set lower_bound["dist"] to dist.
        }
        if output["iterations"] > 4 and lower_bound["bank"] > 44 and upper_bound["bank"] < 46{
            set upper_bound["bank"] to 70.
            local upper_predict is sim_with_bank(simstate, upper_bound["bank"], target_altitude, target_latlong,org_timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right,true).
            set upper_bound["dist"] to calcdistance_m(upper_predict["final_state"]["latlong"], simstate["latlong"]).

        }
        local inside_interface is is_within_team_interface(predict["final_state"],team_interface_box,target_latlong).

        // ENTRY_TRAJ_DEBUG: comment out this single line after diagnosing the solver.
        entry_traj_debug_iteration(output["iterations"],start_sim,target_altitude,target_latlong,team_interface_box,is_eg_pos,bank_side,tgt_dist,lower_bound,upper_bound,d_l,d_u,pred_b,predict,dist,candidate_error,inside_interface).

        if inside_interface{
            set output:converged to true.
            set control_outputs to merge_lex(control_outputs,predict["control"]). // Merge the control outputs
            local converged_sim is lex("controll_inputs", control_outputs).
            output:add ("converged_sim",converged_sim).
            set output:final_state to predict["final_state"].
            output:add("bank",pred_b).
            output:add("error",lex("str","Converged", "max", is_eg_pos["max_pos"],"left",is_eg_pos["left_pos"],"right",is_eg_pos["right_pos"], "target",target_latlong)).
            return output.

        }


        set output["iterations"] to output["iterations"] + 1.

    }
    output:add("error",lex("str","To many iteration", "max", is_eg_pos["max_pos"],"left",is_eg_pos["left_pos"],"right",is_eg_pos["right_pos"], "target",target_latlong)).
    set output:converged to false.
    return output.
}

// Signed distance from the target to the convex hull of every usable probe
// endpoint. Interior points are negative, with deeper points more negative.
// Project about the target using great-circle distance/bearing, so longitude
// wrap and endpoint ordering cannot corrupt the hull test.
function entry_envelope_miss {
    parameter target_position, endpoints.
    local points is list().
    for endpoint in endpoints {
        if endpoint:istype("lexicon") {
            if endpoint:haskey("latlong") {
                local range_m is calcdistance_m(target_position,endpoint["latlong"]).
                local bearing_deg is heading_between(target_position,endpoint["latlong"]).
                points:add(lex("x",range_m*sin(bearing_deg),"y",range_m*cos(bearing_deg))).
            }
        }
    }
    local best_miss is 999999999.
    local inside_hull is false.
    for a in points {
        for b in points {
            local dx is b["x"]-a["x"].
            local dy is b["y"]-a["y"].
            local length_sq is dx^2+dy^2.
            if length_sq > 0.001 {
                // Only convex-hull boundary pairs contribute to the depth.
                local has_positive_side is false.
                local has_negative_side is false.
                for point in points {
                    local side is dx*(point["y"]-a["y"])-dy*(point["x"]-a["x"]).
                    if side > 0.001 { set has_positive_side to true. }
                    if side < -0.001 { set has_negative_side to true. }
                }
                if not (has_positive_side and has_negative_side) {
                    local fraction is max(0,min(1,-(a["x"]*dx+a["y"]*dy)/length_sq)).
                    set best_miss to min(best_miss,sqrt((a["x"]+fraction*dx)^2+(a["y"]+fraction*dy)^2)).
                }
                for c in points {
                    local area_twice is dx*(c["y"]-a["y"])-dy*(c["x"]-a["x"]).
                    if abs(area_twice) > 0.001 {
                        local side_ab is a["x"]*b["y"]-a["y"]*b["x"].
                        local side_bc is b["x"]*c["y"]-b["y"]*c["x"].
                        local side_ca is c["x"]*a["y"]-c["y"]*a["x"].
                        if (side_ab >= 0 and side_bc >= 0 and side_ca >= 0) or
                           (side_ab <= 0 and side_bc <= 0 and side_ca <= 0) {
                            set inside_hull to true.
                        }
                    }
                }
            }
        }
    }
    if inside_hull { return -best_miss. }
    return best_miss.
}

// Rank actual TEAM positions rather than runway thresholds. Candidates inside
// the coarse probe hull come first, deepest inside first; outside candidates
// follow by distance to the hull. This remains an ordering hint, never a
// reachability veto: calc_entry_traj checks each candidate at its exact altitude.
function entry_select_runway {
    parameter input_state.
    parameter preferred_location is "".
    parameter preferred_runway is "".
    parameter rejected_runways is lexicon().
    local endpoints is entry_possible_square(input_state,AVES["simulation"]["timestep"]).
    local usable_endpoints is list().
    for endpoint in endpoints {
        if endpoint:istype("lexicon") {
            if endpoint:haskey("latlong") { usable_endpoints:add(endpoint). }
        }
    }
    local prediction_valid is usable_endpoints:length > 0.
    if not prediction_valid { usable_endpoints:add(input_state). }
    local best_any is lex("selected",false,"score",999999999,"endpoint_miss",999999999,"heading_error",180).
    local best_allowed is best_any.
    local table is Location_constants["kerbin"].
    for key in table:keys {
        if key:endswith("_start") {
            local parts is key:split("_").
            if parts:length = 4 {
                local site_name is parts[0].
                local runway_id is parts[2].
                local end_key is site_name+"_runway_"+runway_id+"_end".
                local height_key is site_name+"_runway".
                if table:haskey(end_key) and KerbinRunwayalt:haskey(height_key) {
                    local candidate_heading is heading_between(table[key],table[end_key]).
                    local candidate_interface is define_TEAM_interface(table[key],candidate_heading,KerbinRunwayalt[height_key]).
                    local candidate_score is entry_envelope_miss(candidate_interface["target_latlng"],usable_endpoints).
                    local endpoint_miss is 999999999.
                    for endpoint in usable_endpoints {
                        set endpoint_miss to min(endpoint_miss,
                            calcdistance_m(candidate_interface["target_latlng"],endpoint["latlong"])).
                    }
                    local heading_miss is abs(normalized_heading_error(candidate_heading,compass_for_prograde())).
                    local candidate is lex("selected",true,"location",site_name,"runway",runway_id,
                        "runway_start",table[key],"runway_end",table[end_key],
                        "runway_heading",candidate_heading,"runway_altitude",KerbinRunwayalt[height_key],
                        "team_interface",candidate_interface,"score",candidate_score,
                        "endpoint_miss",endpoint_miss,"heading_error",heading_miss,
                        "inside_envelope",prediction_valid and candidate_score <= 0,
                        "envelope_depth",max(0,-candidate_score),
                        "prediction_valid",prediction_valid,"cycle_reset",false).
                    if entry_candidate_better(candidate,best_any) { set best_any to candidate. }
                    if not rejected_runways:haskey(site_name+"_"+runway_id) {
                        if entry_candidate_better(candidate,best_allowed) { set best_allowed to candidate. }
                    }
                }
            }
        }
    }
    if not best_allowed["selected"] {
        if best_any["selected"] { set best_any["cycle_reset"] to true. }
        return entry_selection_result(best_any,best_any).
    }
    return entry_selection_result(best_allowed,best_any).
}

function entry_candidate_better {
    parameter candidate, incumbent.
    if not incumbent["selected"] { return true. }
    if candidate["inside_envelope"] and not incumbent["inside_envelope"] { return true. }
    if incumbent["inside_envelope"] and not candidate["inside_envelope"] { return false. }
    if candidate["score"] < incumbent["score"]-0.01 { return true. }
    if abs(candidate["score"]-incumbent["score"]) > 0.01 { return false. }
    if candidate["endpoint_miss"] < incumbent["endpoint_miss"]-0.01 { return true. }
    if abs(candidate["endpoint_miss"]-incumbent["endpoint_miss"]) > 0.01 { return false. }
    return candidate["heading_error"] < incumbent["heading_error"].
}

// Copy the candidate wrapper so best_effort cannot create a self-reference.
function entry_selection_result {
    parameter candidate, best_effort.
    local result is lexicon().
    for field in candidate:keys { result:add(field,candidate[field]). }
    result:add("best_effort",best_effort).
    return result.
}

// Recovery orchestration only. Live control and logging never enter predictors.
function reentry_live_control_update {
    if not(defined entry_control_next_update) { set entry_control_next_update to -1. }
    if not(defined entry_control_busy) { set entry_control_busy to false. }
    if entry_control_busy or time:seconds < entry_control_next_update { return. }
    set entry_control_busy to true.
    set entry_control_next_update to time:seconds+0.1.
    dap:update().
    set entry_control_busy to false.
}

function reentry_start_control_heartbeat {
    set entry_control_next_update to -1.
    set entry_control_busy to false.
    when time:seconds >= entry_control_next_update then {
        if running and (step = "reentry_low" or step = "reentry_mid" or
            step = "reentry_high" or step = "reentry_int") {
            reentry_live_control_update().
        } else { set entry_control_next_update to time:seconds+0.1. }
        if running { preserve. }
    }
}

function reentry_apply_target {
    parameter selection.
    local runway_changed is Location <> selection["location"] or runway_nr <> selection["runway"].
    local target_changed is runway_changed or not(defined Team_interface).
    if not target_changed {
        set target_changed to calcdistance_m(Team_interface["target_latlng"],selection["team_interface"]["target_latlng"]) > 1 or
            Team_interface["target_altitude"] <> selection["team_interface"]["target_altitude"].
    }
    set Location to selection["location"].
    set runway_nr to selection["runway"].
    set runway_start to selection["runway_start"].
    set runway_end to selection["runway_end"].
    set runway_heading to selection["runway_heading"].
    set runway_altitude to selection["runway_altitude"].
    set Team_interface to selection["team_interface"].
    set reentry_target to Team_interface["target_latlng"].
    if target_changed {
        set entry_team_closest_distance to 999999999.
        set entry_team_gate_since to -1.
        set entry_reference_time to -1.
        set entry_turnside to "".
        set entry_display_prediction_path to entry_display_empty_path("target_reset").
    }
    if runway_changed {
        set reentry_tr_target_pending to true.
        flight_log_set_runway(Location,runway_nr,runway_start,runway_end,runway_heading,runway_altitude).
    }
    flight_log_set_entry_target(Team_interface).
}

function reentry_basic_update {
    goto_target().
    flight_log_entry_recovery("basic_update",0).
    set entry_basic_next_update to time:seconds+5.
}

function reentry_recovery_update {
    if not(defined Team_interface) {
        set Team_interface to define_TEAM_interface(runway_start,runway_heading,runway_altitude).
        set reentry_target to Team_interface["target_latlng"].
        flight_log_set_entry_target(Team_interface).
    }
    // Steering refresh does not depend on the solver retry clock or convergence.
    if time:seconds >= entry_basic_next_update {
        reentry_basic_update().
        reentry_live_control_update().
    }
    if time:seconds < entry_solver_next_retry_time { return. }
    // Once at/below the interface, retain entry control while the existing
    // handoff speed gate is pending. There is no descending entry plan to solve.
    if ship:altitude <= AVES["TEAMAltitude"] {
        set entry_solver_next_retry_time to time:seconds+10.
        return.
    }

    local retry_started is time:seconds.
    local selection is entry_select_runway(current_simstate(),Location,runway_nr,entry_rejected_runways).
    if not selection["selected"] {
        flight_log_event("entry_target_search","reason=no_valid_runway_data").
        set entry_solver_next_retry_time to time:seconds+10.
        return.
    }
    if selection["cycle_reset"] {
        set entry_rejected_runways to lexicon().
        flight_log_event("entry_candidate_cycle_reset","runway="+selection["location"]+"_"+selection["runway"]).
    }
    // Keep flying the best available approach even when the solver is testing
    // a more distant alternative. Commit that alternative only on convergence.
    reentry_apply_target(selection["best_effort"]).
    local search_reason is "candidate".
    if not selection["inside_envelope"] { set search_reason to "best_effort". }
    local envelope_depth is 0.
    if selection:haskey("envelope_depth") { set envelope_depth to selection["envelope_depth"]. }
    flight_log_event("entry_target_search","reason="+search_reason+
        "|candidate="+selection["location"]+"_"+selection["runway"]+
        "|flight_target="+Location+"_"+runway_nr+"|coarse_miss="+round(selection["score"],1)+
        "|inside_envelope="+selection["inside_envelope"]+
        "|envelope_depth="+round(envelope_depth,1)+
        "|prediction_valid="+selection["prediction_valid"]+
        "|selection_duration="+round(time:seconds-retry_started,2)).
    reentry_basic_update().
    reentry_live_control_update().
    local solver_interface is selection["team_interface"].
    // Recheck after selection/basic prediction: both consume real flight time.
    if ship:altitude <= solver_interface["target_altitude"] {
        set entry_rejected_runways[selection["location"]+"_"+selection["runway"]] to true.
        set entry_solver_next_retry_time to time:seconds+10.
        flight_log_event("entry_candidate_rejected","runway="+selection["location"]+"_"+selection["runway"]+
            "|reason=interface_already_passed|retry_ut="+entry_solver_next_retry_time).
        return.
    }
    local solve_started is time:seconds.
    set entry_traj to calc_entry_traj(current_simstate(),solver_interface["target_altitude"],
        solver_interface["target_latlng"],solver_interface["team_interface_box"],"time",0).
    flight_log_entry_solver_result(entry_traj).
    flight_log_entry_recovery("solver_complete",time:seconds-solve_started).
    set entry_solver_next_retry_time to time:seconds+10.
    set entry_reference_time to -1.
    if entry_traj["converged"] {
        reentry_apply_target(selection).
        set val_tgt to true.
        set basice_reentry_guidance to false.
        set entry_predictive_plan_bank to entry_traj["bank"].
        set entry_predictive_bank to entry_traj["bank"].
        set entry_predictive_next_update to time:seconds+10.
        set entry_predictive_valid to false.
        set entry_predictive_frozen to false.
        local heading_error is normalized_heading_error(
            heading_to_target(Team_interface["target_latlng"]),compass_for_prograde()).
        if heading_error >= 0 { set entry_turnside to "right". }
        else { set entry_turnside to "left". }
        if entry_turnside = "right" { set dap["aoa"]["target_bank"] to -entry_predictive_bank. }
        else { set dap["aoa"]["target_bank"] to entry_predictive_bank. }
        flight_log_event("entry_guidance_mode","from=basic|to=predictive|bank="+
            round(entry_predictive_bank,2)+"|heading_error="+round(heading_error,2)).
    } else {
        set val_tgt to false.
        set entry_rejected_runways[selection["location"]+"_"+selection["runway"]] to true.
        set basice_reentry_guidance to true.
        set entry_display_prediction_path to entry_display_empty_path("basic_guidance").
        flight_log_event("entry_candidate_rejected","runway="+selection["location"]+"_"+selection["runway"]+
            "|reason="+entry_traj["error"]["str"]+"|retry_ut="+entry_solver_next_retry_time).
        reentry_basic_update().
    }
}
