// Terrain corridors shared by departure planning and GPWS. No flight logging
// or aerodynamic trajectory simulator calls belong in this library.
// These are conservative sampled paths, not a guarantee between terrain probes.
function terrain_heading_delta {
    parameter desired_course, current_course.
    local delta_course is desired_course-current_course.
    until delta_course >= -180 and delta_course <= 180 {
        if delta_course > 180 { set delta_course to delta_course-360. }
        if delta_course < -180 { set delta_course to delta_course+360. }
    }
    return delta_course.
}

// Distance-integrated climb envelope: weak initial climb, then a gradual
// transition to the derated established-climb gradient. Absolute evaluation
// keeps the result independent of the terrain sampling interval.
function terrain_departure_height_gain {
    parameter distance_m, navigation_config.
    local ramp_distance is max(1,navigation_config["departure_climb_ramp"]).
    local established_distance is max(0,distance_m-navigation_config["departure_climb_delay"]).
    local ramp_progress is min(ramp_distance,established_distance).
    local effective_distance is ramp_progress^2/(2*ramp_distance)+max(0,established_distance-ramp_distance).
    return navigation_config["departure_initial_gradient"]*distance_m+
        (navigation_config["departure_gradient"]-navigation_config["departure_initial_gradient"])*effective_distance.
}

// Freeze recovery inputs as values, including delay-list contents. A live
// configuration edit must not reuse clearance from the previous envelope.
function terrain_recovery_config_key {
    parameter navigation_config.
    local config_key is "".
    for field_key in list("response_seconds","recovery_climb_speed","clearance",
        "sample_spacing","corridor_width","corridor_growth","horizon_seconds",
        "minimum_range","maximum_range","scan_acceleration","recovery_force_safety",
        "recovery_max_acceleration","recovery_sample_aoa","recovery_speed_fraction",
        "escape_margin","escape_bank","prediction_bank","roll_hold_seconds",
        "rollout_seconds","climb_credit","recovery_tail_seconds") {
        set config_key to config_key+"|"+navigation_config[field_key].
    }
    for delay_seconds in navigation_config["recovery_delays"] {
        set config_key to config_key+"|delay="+delay_seconds.
    }
    return config_key.
}

// Recovery is a bounded performance assumption supported by a live FAR sample,
// never by commanded AoA alone. Absolute integration avoids station-size drift.
function terrain_recovery_height_gain {
    parameter elapsed_seconds, initial_vs, extra_delay, recovery_acceleration, navigation_config.
    local delayed_seconds is navigation_config["response_seconds"]+extra_delay.
    local initial_climb is min(initial_vs,navigation_config["climb_credit"]).
    local active_seconds is max(0,elapsed_seconds-delayed_seconds).
    local climb_limit is max(initial_climb,navigation_config["recovery_climb_speed"]).
    local accelerating_seconds is min(active_seconds,
        max(0,(climb_limit-initial_climb)/max(0.001,recovery_acceleration))).
    return initial_climb*elapsed_seconds + recovery_acceleration*
        (0.5*accelerating_seconds^2+accelerating_seconds*(active_seconds-accelerating_seconds)).
}

// Signed lift in the sampled relative-wind frame. kN / tonnes = m/s^2.
function terrain_recovery_acceleration {
    parameter sampled_force, sample_velocity, vessel_top, craft_mass, local_gravity,
        flight_path_fraction, navigation_config.
    local wind_direction is sample_velocity:normalized.
    local lift_axis is vessel_top-wind_direction*vdot(vessel_top,wind_direction).
    if lift_axis:mag < 0.001 { return 0. }
    local lift_force_kn is vdot(sampled_force,lift_axis:normalized).
    local vertical_fraction is sqrt(max(0,1-flight_path_fraction^2))*cos(navigation_config["escape_bank"]).
    local net_acceleration is lift_force_kn/max(0.001,craft_mass)*vertical_fraction-local_gravity.
    return max(0,min(navigation_config["recovery_max_acceleration"],
        net_acceleration*navigation_config["recovery_force_safety"])).
}

function terrain_path_create {
    parameter origin_point, initial_course, first_course, final_course,
        path_speed, bottom_height, path_vs, local_gravity, navigation_config,
        departure_mode is false, initial_roll is 0, recovery_acceleration is 0.
    local path_range is min(navigation_config["maximum_range"],max(navigation_config["minimum_range"],
        path_speed*navigation_config["horizon_seconds"] +
        0.5*navigation_config["scan_acceleration"]*navigation_config["horizon_seconds"]^2)).
    if departure_mode { set path_range to navigation_config["departure_range"]. }
    local recovery_margins is list().
    for recovery_delay in navigation_config["recovery_delays"] { recovery_margins:add(999999). }
    return lex("point",origin_point,"origin",origin_point,"course",initial_course,
        "first_course",first_course,"final_course",final_course,
        "speed",max(path_speed,60),"bottom",bottom_height,"vs",path_vs,
        "gravity",local_gravity,"initial_roll",initial_roll,"departure",departure_mode,"distance",0,
        "elapsed",0,"range",path_range,"margin",999999,"clearance",999999,
        "conflict_time",999999,"threat_lat",0,"threat_lng",0,"threat_height",0,
        "done",false,"waypoints",list(),"next_waypoint",1000,
        "recovery_acceleration",recovery_acceleration,"recovery_margins",recovery_margins,
        "recovery_context",lex("valid",false),"recovery_threat_lat",0,"recovery_threat_lng",0,
        "recovery_threat_height",0,"initial_speed",path_speed,
        "initial_bottom",bottom_height,"worst_distance",0,"worst_bottom",bottom_height,
        "worst_required_clearance",0,"required_gradient",0).
}

// One station samples the centre and both corridor edges. Flight code budgets
// stations per update; preflight yields between batches with brakes held.
function terrain_path_advance {
    parameter terrain_path_state, navigation_config.
    if terrain_path_state["done"] { return. }
    local station_distance is min(navigation_config["sample_spacing"],terrain_path_state["range"]-terrain_path_state["distance"]).
    local station_acceleration is navigation_config["scan_acceleration"].
    if terrain_path_state["departure"] { set station_acceleration to 0. }
    local next_speed is sqrt(terrain_path_state["speed"]^2+2*station_acceleration*station_distance).
    local station_dt is 2*station_distance/(terrain_path_state["speed"]+next_speed).
    local desired_course is terrain_path_state["first_course"].
    if terrain_path_state["departure"] and terrain_path_state["distance"] >= navigation_config["departure_dogleg_distance"] {
        set desired_course to terrain_path_state["final_course"].
    }
    local course_error is terrain_heading_delta(desired_course,terrain_path_state["course"]).
    local heading_gain is navigation_config["escape_heading_gain"].
    if terrain_path_state["departure"] { set heading_gain to navigation_config["departure_heading_gain"]. }
    local model_bank is min(navigation_config["prediction_bank"],abs(course_error)*heading_gain).
    local turn_rate is terrain_path_state["gravity"]*tan(model_bank)/next_speed*constant:radtodeg.
    local turn_angle is 0.
    local response_delay is navigation_config["response_seconds"].
    if terrain_path_state["departure"] { set response_delay to navigation_config["departure_response_seconds"]. }
    if not terrain_path_state["departure"] and terrain_path_state["elapsed"] < response_delay {
        // Retain the initial bank during sensing/command delay, then roll it
        // out. A lateral escape cannot start from an already level aircraft.
        local roll_fraction is max(0,min(1,1-max(0,terrain_path_state["elapsed"]-navigation_config["roll_hold_seconds"])/
            navigation_config["rollout_seconds"])).
        set turn_angle to terrain_path_state["gravity"]*tan(max(-60,min(60,terrain_path_state["initial_roll"]))*roll_fraction)/
            next_speed*constant:radtodeg*station_dt.
    }
    if terrain_path_state["elapsed"] >= response_delay {
        set turn_angle to max(-turn_rate*station_dt,min(turn_rate*station_dt,
            terrain_heading_delta(desired_course,terrain_path_state["course"]))).
    }
    // Midpoint integration approximates the curved track; corridor width
    // includes position/tracking uncertainty. Never teleport onto a new ray.
    set terrain_path_state["point"] to get_geoposition_along_heading(terrain_path_state["point"],terrain_path_state["course"]+turn_angle/2,station_distance).
    set terrain_path_state["course"] to terrain_path_state["course"]+turn_angle.
    set terrain_path_state["speed"] to next_speed.
    set terrain_path_state["elapsed"] to terrain_path_state["elapsed"]+station_dt.
    set terrain_path_state["distance"] to terrain_path_state["distance"]+station_distance.
    local station_floor is navigation_config["clearance"].
    local recovery_bottoms is list().
    if not terrain_path_state["departure"] and terrain_path_state["recovery_acceleration"] > 0 {
        for recovery_delay in navigation_config["recovery_delays"] {
            // Include the interval's nadir even if descent arrest falls between
            // terrain stations. Terrain sampling itself remains discrete.
            local nadir_seconds is navigation_config["response_seconds"]+recovery_delay+
                max(0,-terrain_path_state["vs"])/terrain_path_state["recovery_acceleration"].
            local minimum_seconds is terrain_path_state["elapsed"]-station_dt.
            if terrain_path_state["vs"] < 0 {
                set minimum_seconds to max(minimum_seconds,min(terrain_path_state["elapsed"],nadir_seconds)).
            }
            // The recovery curve decreases to its nadir then increases. One
            // clamped evaluation gives the exact interval minimum; do not
            // integrate or reevaluate both endpoints for every candidate.
            local interval_minimum is terrain_recovery_height_gain(minimum_seconds,
                terrain_path_state["vs"],recovery_delay,terrain_path_state["recovery_acceleration"],navigation_config).
            recovery_bottoms:add(terrain_path_state["initial_bottom"]+interval_minimum).
        }
    }
    if terrain_path_state["departure"] {
        set terrain_path_state["bottom"] to terrain_path_state["initial_bottom"]+
            terrain_departure_height_gain(terrain_path_state["distance"],navigation_config).
        set station_floor to navigation_config["departure_initial_clearance"] +
            (navigation_config["clearance"]-navigation_config["departure_initial_clearance"])*
            min(1,terrain_path_state["distance"]/navigation_config["departure_clearance_ramp"]).
    } else {
        // No credit for commanded AoA. Cap observed positive climb; turning
        // candidates additionally reserve sink while banked.
        set terrain_path_state["bottom"] to terrain_path_state["bottom"]+min(terrain_path_state["vs"],navigation_config["climb_credit"])*station_dt.
        if abs(turn_angle) > 0.01 {
            set terrain_path_state["bottom"] to terrain_path_state["bottom"]-navigation_config["turn_sink_reserve"]*station_dt.
        }
    }
    local corridor_width is navigation_config["corridor_width"] + terrain_path_state["distance"]*navigation_config["corridor_growth"].
    local highest_probe_height is -999999.
    local highest_probe_lat is 0.
    local highest_probe_lng is 0.
    local corridor_sides is list(0,-1,1).
    local corridor_index is 0.
    until corridor_index >= corridor_sides:length {
        local corridor_side is corridor_sides[corridor_index].
        set corridor_index to corridor_index+1.
        local probe_point is terrain_path_state["point"].
        if corridor_side <> 0 {
            set probe_point to get_geoposition_along_heading(terrain_path_state["point"],terrain_path_state["course"]+90,
                corridor_side*corridor_width).
        }
        local probe_height is probe_point:terrainheight.
        if ship:body:hasocean { set probe_height to max(0,probe_height). }
        local probe_clearance is terrain_path_state["bottom"]-probe_height.
        local probe_margin is probe_clearance-station_floor.
        if probe_height > highest_probe_height {
            set highest_probe_height to probe_height.
            set highest_probe_lat to probe_point:lat.
            set highest_probe_lng to probe_point:lng.
        }
        if terrain_path_state["departure"] {
            set terrain_path_state["required_gradient"] to max(terrain_path_state["required_gradient"],
                (probe_height+station_floor-terrain_path_state["initial_bottom"])/max(1,terrain_path_state["distance"])).
        }
        if probe_margin < terrain_path_state["margin"] {
            set terrain_path_state["margin"] to probe_margin.
            set terrain_path_state["clearance"] to probe_clearance.
            set terrain_path_state["worst_distance"] to terrain_path_state["distance"].
            set terrain_path_state["worst_bottom"] to terrain_path_state["bottom"].
            set terrain_path_state["worst_required_clearance"] to station_floor.
            set terrain_path_state["threat_lat"] to probe_point:lat.
            set terrain_path_state["threat_lng"] to probe_point:lng.
            set terrain_path_state["threat_height"] to probe_height.
        }
        if probe_margin < 0 { set terrain_path_state["conflict_time"] to min(terrain_path_state["conflict_time"],terrain_path_state["elapsed"]). }
    }
    // Every vertical candidate shares this station's footprint. Compare once
    // with its highest terrain probe instead of repeating candidate work for
    // the centre and both edges. All three terrain queries are retained.
    local recovery_index is 0.
    until recovery_index >= recovery_bottoms:length {
        local recovery_margin is recovery_bottoms[recovery_index]-highest_probe_height-station_floor.
        if recovery_index = 0 and recovery_margin < terrain_path_state["recovery_margins"][0] {
            set terrain_path_state["recovery_threat_lat"] to highest_probe_lat.
            set terrain_path_state["recovery_threat_lng"] to highest_probe_lng.
            set terrain_path_state["recovery_threat_height"] to highest_probe_height.
        }
        set terrain_path_state["recovery_margins"][recovery_index] to min(
            terrain_path_state["recovery_margins"][recovery_index],recovery_margin).
        set recovery_index to recovery_index+1.
    }
    if terrain_path_state["departure"] and (terrain_path_state["distance"] >= terrain_path_state["next_waypoint"] or terrain_path_state["distance"] >= terrain_path_state["range"]) {
        terrain_path_state["waypoints"]:add(terrain_path_state["point"]).
        set terrain_path_state["next_waypoint"] to terrain_path_state["next_waypoint"]+1000.
    }
    set terrain_path_state["done"] to terrain_path_state["distance"] >= terrain_path_state["range"].
}

function terrain_navigation_config {
    // Copy so a mass-dependent departure gradient cannot mutate GPWS tuning.
    parameter source_config, departure_mass is 69.5.
    local result_config is lex().
    for config_key in source_config:keys { result_config:add(config_key,source_config[config_key]). }
    set result_config["departure_gradient"] to source_config["departure_gradient"]*
        min(1,(source_config["reference_mass"]/max(1,departure_mass))^2).
    set result_config["departure_initial_gradient"] to source_config["departure_initial_gradient"]*
        min(1,(source_config["reference_mass"]/max(1,departure_mass))^2).
    return result_config.
}

function terrain_departure_plan {
    parameter active_runway, takeoff_prediction, orbital_course, navigation_config.
    local result_plan is lex("valid",false,"reason","unknown_runway","waypoints",list(),
        "index",0,"margin",-999999,"first_course",0,"score",999999,
        "origin",ship:geoposition,"planned_ut",time:seconds,"mass",ship:mass,
        "model_gradient",navigation_config["departure_gradient"],"model_speed",navigation_config["departure_speed"],
        "model_initial_gradient",navigation_config["departure_initial_gradient"],
        "model_climb_delay",navigation_config["departure_climb_delay"],
        "model_climb_ramp",navigation_config["departure_climb_ramp"],
        "sample_spacing",navigation_config["sample_spacing"],"model_valid",false,
        "candidates",list(),"best_rejected",lex()).
    // find_active_runway() returns heading/altitude sentinels, not a
    // selected flag (that flag belongs to recovery runway candidates).
    if not(active_runway:haskey("heading")) or not(active_runway:haskey("altitude")) { return result_plan. }
    if active_runway["heading"] < 0 or active_runway["altitude"] < 0 { return result_plan. }
    if not(takeoff_prediction:haskey("liftoff_distance_m")) {
        set result_plan["reason"] to "invalid_takeoff_prediction".
        return result_plan.
    }
    if takeoff_prediction["liftoff_distance_m"] <= 0 {
        set result_plan["reason"] to "invalid_takeoff_prediction".
        return result_plan.
    }
    // Plan from the earliest plausible liftoff location as well as checking
    // the runway extension, rather than treating off-runway ground as clear.
    local start_point is get_geoposition_along_heading(ship:geoposition,active_runway["heading"],
        max(0,takeoff_prediction["liftoff_distance_m"]*navigation_config["liftoff_distance_fraction"])).
    set result_plan["origin"] to start_point.
    set result_plan["reason"] to "terrain_blocked".
    local local_gravity is ship:body:mu/(ship:body:radius+ship:altitude)^2.
    local candidate_offsets is list(0,-5,5,-15,15,-30,30,-60,60,-90,90).
    candidate_offsets:add(max(-90,min(90,terrain_heading_delta(orbital_course,active_runway["heading"])))).
    for candidate_offset in candidate_offsets {
        local candidate_course is active_runway["heading"]+candidate_offset.
        local candidate_path is terrain_path_create(start_point,active_runway["heading"],candidate_course,
            orbital_course,navigation_config["departure_speed"],active_runway["altitude"]+
            navigation_config["departure_initial_clearance"],0,local_gravity,navigation_config,true).
        until candidate_path["done"] {
            local batch_index is 0.
            until batch_index >= navigation_config["stations_per_update"] or candidate_path["done"] {
                terrain_path_advance(candidate_path,navigation_config).
                set batch_index to batch_index+1.
            }
            wait 0.
        }
        // Return diagnostics to the caller. No logging or I/O in path math.
        local candidate_diagnostic is lex("course",candidate_course,"offset",candidate_offset,
            "valid",candidate_path["margin"] >= 0,"margin",candidate_path["margin"],
            "clearance",candidate_path["clearance"],"distance",candidate_path["worst_distance"],
            "predicted_bottom",candidate_path["worst_bottom"],
            "required_clearance",candidate_path["worst_required_clearance"],
            "terrain_height",candidate_path["threat_height"],"latitude",candidate_path["threat_lat"],
            "longitude",candidate_path["threat_lng"],"first_conflict_seconds",candidate_path["conflict_time"],
            "required_gradient",candidate_path["required_gradient"],
            "turn_distance",navigation_config["departure_dogleg_distance"],"final_course",orbital_course).
        result_plan["candidates"]:add(candidate_diagnostic).
        if candidate_path["margin"] < 0 {
            if result_plan["best_rejected"]:length = 0 {
                set result_plan["best_rejected"] to candidate_diagnostic.
            } else if candidate_path["margin"] > result_plan["best_rejected"]["margin"] {
                set result_plan["best_rejected"] to candidate_diagnostic.
            }
        }
        local candidate_score is abs(terrain_heading_delta(orbital_course,candidate_course))+
            0.15*abs(candidate_offset).
        if candidate_path["margin"] >= 0 and candidate_score < result_plan["score"] {
            set result_plan["valid"] to true.
            set result_plan["reason"] to "sampled_corridor".
            set result_plan["score"] to candidate_score.
            set result_plan["margin"] to candidate_path["margin"].
            set result_plan["waypoints"] to candidate_path["waypoints"].
            set result_plan["first_course"] to candidate_course.
        }
    }
    return result_plan.
}

function terrain_departure_course {
    parameter route_plan, current_point, orbital_course, navigation_config.
    if not route_plan["valid"] { return orbital_course. }
    local waypoints is route_plan["waypoints"].
    until route_plan["index"] >= waypoints:length {
        local route_waypoint is waypoints[route_plan["index"]].
        local leg_origin is route_plan["origin"].
        if route_plan["index"] > 0 { set leg_origin to waypoints[route_plan["index"]-1]. }
        local leg_course is heading_between(leg_origin,route_waypoint).
        local current_course is heading_between(current_point,route_waypoint).
        // Passed the route_waypoint's normal plane, or close enough to capture it.
        if calcdistance_m(current_point,route_waypoint) <= navigation_config["waypoint_capture"] or
           abs(terrain_heading_delta(current_course,leg_course)) > 90 {
            set route_plan["index"] to route_plan["index"]+1.
        } else { return current_course. }
    }
    return orbital_course.
}

function terrain_alignment_command {
    parameter course_error, current_vs, current_aoa, current_pitch, prograde_pitch,
        ascent_config.
    // Keep the early turn, but protect vertical lift before demanding bank.
    // Loss of climb continuously unloads the turn instead of pitching down.
    local climb_fraction is max(0,min(1,(current_vs-ascent_config["alignment_min_vs"])/
        (ascent_config["alignment_full_bank_vs"]-ascent_config["alignment_min_vs"]))).
    local bank_limit is ascent_config["runway_alignment_bank"]*climb_fraction.
    local bank_command is max(-bank_limit,min(bank_limit,-course_error*2)).
    // Use the configured lift target, not measured AoA: feeding measured AoA
    // back through bank compensation ratchets the request upward every tick.
    local lift_aoa is min(ascent_config["alignment_max_aoa"],
        ascent_config["runway_alignment_target_aoa"]/max(0.7,cos(bank_command))).
    local climb_bias is max(0,ascent_config["alignment_target_vs"]-current_vs)*ascent_config["alignment_vs_gain"].
    local pitch_command is max(0,prograde_pitch+lift_aoa+climb_bias).
    // The controller also clamps the FINAL normal command to alignment_max_pitch.
    return lex("bank",bank_command,"aoa",lift_aoa,"pitch_floor",min(ascent_config["alignment_max_pitch"],pitch_command)).
}

// Apply after AoA/bank steering has produced its pitch demand, so the limit
// constrains the final normal command rather than only a minimum pitch floor.
function terrain_alignment_pitch {
    parameter requested_pitch, alignment_command, ascent_config.
    return min(ascent_config["alignment_max_pitch"],max(requested_pitch,alignment_command["pitch_floor"])).
}

function terrain_scan_state {
    return lex("paths",list(),"phase","central","candidate_index",1,"active_offset",0,"started_ut",-999999,"completed_ut",-999999,
        "central_ut",-999999,"central_course",0,"trigger_reason","not_scanned","central_margin",999999,"conflict_ut",999999,
        "threat_lat",0,"threat_lng",0,"threat_height",0,"range",0,
        "escape_course",0,"escape_offset",0,"escape_margin",-999999,
        "recovery_context",lex("valid",false),"recovery_margin",-999999,"safe_delay",-1,
        "recovery_acceleration",0,"recovery_reason","not_scanned",
        "recovery_threat_lat",0,"recovery_threat_lng",0,"recovery_threat_height",0,
        "escape_valid",false,"escape_snapshot_course",0,"snapshot_course",0,"mode","idle","next_start",0).
}

function terrain_scan_start {
    parameter scan, origin_point, track_course, path_speed, bottom_height, path_vs,
        local_gravity, navigation_config, scan_ut, initial_roll is 0, recovery_acceleration is 0.
    set scan["started_ut"] to scan_ut.
    set scan["snapshot_course"] to track_course.
    local candidate_offset is 0.
    if scan["phase"] = "candidate" {
        set candidate_offset to navigation_config["escape_offsets"][scan["candidate_index"]].
    }
    set scan["active_offset"] to candidate_offset.
    set scan["paths"] to list(terrain_path_create(origin_point,track_course,track_course+candidate_offset,
        track_course+candidate_offset,path_speed,bottom_height,path_vs,local_gravity,navigation_config,false,initial_roll,recovery_acceleration)).
}

function terrain_scan_advance {
    parameter scan, navigation_config, scan_ut.
    if scan["paths"]:length = 0 { return. }
    local active_path is scan["paths"][0].
    local station_count is 0.
    until station_count >= navigation_config["stations_per_update"] or active_path["done"] {
        terrain_path_advance(active_path,navigation_config).
        set station_count to station_count+1.
    }
    if not active_path["done"] { return. }
    if scan["phase"] = "central" {
        set scan["central_course"] to scan["snapshot_course"].
        set scan["central_margin"] to active_path["margin"].
        set scan["central_ut"] to scan["started_ut"].
        set scan["conflict_ut"] to scan["started_ut"]+active_path["conflict_time"].
        set scan["threat_lat"] to active_path["threat_lat"].
        set scan["threat_lng"] to active_path["threat_lng"].
        set scan["threat_height"] to active_path["threat_height"].
        set scan["range"] to active_path["range"].
        set scan["recovery_context"] to active_path["recovery_context"].
        set scan["recovery_acceleration"] to active_path["recovery_acceleration"].
        set scan["recovery_margin"] to -999999.
        set scan["safe_delay"] to -1.
        set scan["recovery_threat_lat"] to active_path["recovery_threat_lat"].
        set scan["recovery_threat_lng"] to active_path["recovery_threat_lng"].
        set scan["recovery_threat_height"] to active_path["recovery_threat_height"].
        if active_path["recovery_acceleration"] > 0 {
            set scan["recovery_margin"] to active_path["recovery_margins"][0].
            local delay_index is 0.
            for recovery_delay in navigation_config["recovery_delays"] {
                local arrest_seconds is navigation_config["response_seconds"]+recovery_delay+
                    max(0,-active_path["vs"])/active_path["recovery_acceleration"].
                // An unfinished recovery cannot authorize further delay. Keep
                // scanning the complete corridor, past any first impact.
                if active_path["recovery_margins"][delay_index] >= navigation_config["escape_margin"] and
                   arrest_seconds+navigation_config["recovery_tail_seconds"] <= active_path["elapsed"] {
                    set scan["safe_delay"] to recovery_delay.
                }
                set delay_index to delay_index+1.
            }
        }
        // While a supported delayed recovery remains safe, prioritize fresh
        // central terrain over unnecessary lateral searches. Otherwise the
        // candidate interleave can age a valid descent scan into a fallback.
        // Urgent/unsupported threats retain the existing lateral search.
        if scan["central_margin"] < 0 and
           (not active_path["recovery_context"]["valid"] or
            scan["safe_delay"] <= navigation_config["recovery_reserve_seconds"]) {
            set scan["phase"] to "candidate".
            // Recheck the selected side between central scans rather than
            // allowing a good escape to age while searching other headings.
            if scan["escape_valid"] {
                local option_index is 1.
                until option_index >= navigation_config["escape_offsets"]:length {
                    if navigation_config["escape_offsets"][option_index] = scan["escape_offset"] {
                        set scan["candidate_index"] to option_index.
                    }
                    set option_index to option_index+1.
                }
            }
        }
    } else {
        if scan["active_offset"] = scan["escape_offset"] and active_path["margin"] < navigation_config["escape_margin"] {
            set scan["escape_valid"] to false.
        }
        local old_fresh is scan["escape_valid"] and scan_ut-scan["completed_ut"] <= navigation_config["maximum_age"] and
            abs(terrain_heading_delta(scan["snapshot_course"],scan["escape_snapshot_course"])) <= 5.
        local candidate_cost is abs(scan["active_offset"]).
        if abs(scan["active_offset"]-scan["escape_offset"]) < 1 { set candidate_cost to candidate_cost-3. }
        if active_path["margin"] >= navigation_config["escape_margin"] and
           (not old_fresh or candidate_cost < abs(scan["escape_offset"])) {
            set scan["escape_valid"] to true.
            set scan["escape_course"] to scan["snapshot_course"]+scan["active_offset"].
            set scan["escape_offset"] to scan["active_offset"].
            set scan["escape_margin"] to active_path["margin"].
            set scan["escape_snapshot_course"] to scan["snapshot_course"].
            set scan["completed_ut"] to scan["started_ut"].
        }
        set scan["phase"] to "central".
        set scan["candidate_index"] to scan["candidate_index"]+1.
        if scan["candidate_index"] >= navigation_config["escape_offsets"]:length {
            set scan["candidate_index"] to 1.
        }
    }
    set scan["next_start"] to scan_ut+navigation_config["scan_pause"].
    set scan["paths"] to list().
}
