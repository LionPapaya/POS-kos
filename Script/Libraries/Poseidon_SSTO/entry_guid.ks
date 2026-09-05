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

    local hed is 0.
    if use_entry_sim_heading {
        set hed to entry_sim_heading_for_simstate(simstate).
    } else {
        set hed to compass_for_simstate(simstate).
    }
    local hed2tgt is heading_between(simstate["latlong"],target_latlong).
    local heading_error is hed - hed2tgt.
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
        set heading_error to hed - hed2tgt.
        if heading_error > AVES["EG_rev°"]{
            set bank_side to "right".
        }
        if heading_error < -AVES["EG_rev°"]{
            set bank_side to "left".
        }
        contrl:add(simstate["simtime"],lex("simstate",simstate,"inputs",lex("bank_side",bank_side,"bank_angle",bank_angle))).
        set simstate to simulate_trajectory_time(simstate,bank_angle,bank_side,timestep,"EGAOA",timestep,sim_context_mu,sim_context_radius,sim_context_angularvel,sim_context_mass,sim_context_vessel_fore,sim_context_vessel_top,sim_context_vessel_right).

    }
    out:add("control",contrl).
    out:add("final_state",simstate).
    return out.
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
