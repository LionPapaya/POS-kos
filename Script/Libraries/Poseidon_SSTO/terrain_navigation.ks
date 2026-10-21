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

function terrain_path_create {
    parameter origin_point, initial_course, first_course, final_course,
        path_speed, bottom_height, path_vs, local_gravity, navigation_config,
        departure_mode is false, initial_roll is 0.
    local path_range is min(navigation_config["maximum_range"],max(navigation_config["minimum_range"],
        path_speed*navigation_config["horizon_seconds"] +
        0.5*navigation_config["scan_acceleration"]*navigation_config["horizon_seconds"]^2)).
    if departure_mode { set path_range to navigation_config["departure_range"]. }
    return lex("point",origin_point,"origin",origin_point,"course",initial_course,
        "first_course",first_course,"final_course",final_course,
        "speed",max(path_speed,60),"bottom",bottom_height,"vs",path_vs,
        "gravity",local_gravity,"initial_roll",initial_roll,"departure",departure_mode,"distance",0,
        "elapsed",0,"range",path_range,"margin",999999,"clearance",999999,
        "conflict_time",999999,"threat_lat",0,"threat_lng",0,"threat_height",0,
        "done",false,"waypoints",list(),"next_waypoint",1000).
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
    if terrain_path_state["departure"] {
        set terrain_path_state["bottom"] to terrain_path_state["bottom"]+navigation_config["departure_gradient"]*station_distance.
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
        if probe_margin < terrain_path_state["margin"] {
            set terrain_path_state["margin"] to probe_margin.
            set terrain_path_state["clearance"] to probe_clearance.
            set terrain_path_state["threat_lat"] to probe_point:lat.
            set terrain_path_state["threat_lng"] to probe_point:lng.
            set terrain_path_state["threat_height"] to probe_height.
        }
        if probe_margin < 0 { set terrain_path_state["conflict_time"] to min(terrain_path_state["conflict_time"],terrain_path_state["elapsed"]). }
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
    return result_config.
}

function terrain_departure_plan {
    parameter active_runway, takeoff_prediction, orbital_course, navigation_config.
    local result_plan is lex("valid",false,"reason","unknown_runway","waypoints",list(),
        "index",0,"margin",-999999,"first_course",0,"score",999999,
        "origin",ship:geoposition,"planned_ut",time:seconds,"mass",ship:mass,
        "model_gradient",navigation_config["departure_gradient"],"model_speed",navigation_config["departure_speed"],
        "sample_spacing",navigation_config["sample_spacing"],"model_valid",false).
    if not active_runway["selected"] { return result_plan. }
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
    local preserved_aoa is max(ascent_config["runway_alignment_target_aoa"],current_aoa).
    local lift_aoa is min(ascent_config["alignment_max_aoa"],preserved_aoa/max(0.7,cos(bank_command))).
    local climb_bias is max(0,ascent_config["alignment_target_vs"]-current_vs)*ascent_config["alignment_vs_gain"].
    local pitch_command is max(current_pitch,prograde_pitch+lift_aoa+climb_bias).
    // This is an attitude floor, not a claim that the aircraft can attain it.
    return lex("bank",bank_command,"aoa",lift_aoa,"pitch_floor",min(ascent_config["alignment_max_pitch"],pitch_command)).
}

function terrain_scan_state {
    return lex("paths",list(),"phase","central","candidate_index",1,"active_offset",0,"started_ut",-999999,"completed_ut",-999999,
        "central_ut",-999999,"central_margin",999999,"conflict_ut",999999,
        "threat_lat",0,"threat_lng",0,"threat_height",0,"range",0,
        "escape_course",0,"escape_offset",0,"escape_margin",-999999,
        "escape_valid",false,"escape_snapshot_course",0,"snapshot_course",0,"mode","idle","next_start",0).
}

function terrain_scan_start {
    parameter scan, origin_point, track_course, path_speed, bottom_height, path_vs,
        local_gravity, navigation_config, scan_ut, initial_roll is 0.
    set scan["started_ut"] to scan_ut.
    set scan["snapshot_course"] to track_course.
    local candidate_offset is 0.
    if scan["phase"] = "candidate" {
        set candidate_offset to navigation_config["escape_offsets"][scan["candidate_index"]].
    }
    set scan["active_offset"] to candidate_offset.
    set scan["paths"] to list(terrain_path_create(origin_point,track_course,track_course+candidate_offset,
        track_course+candidate_offset,path_speed,bottom_height,path_vs,local_gravity,navigation_config,false,initial_roll)).
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
        set scan["central_margin"] to active_path["margin"].
        set scan["central_ut"] to scan["started_ut"].
        set scan["conflict_ut"] to scan["started_ut"]+active_path["conflict_time"].
        set scan["threat_lat"] to active_path["threat_lat"].
        set scan["threat_lng"] to active_path["threat_lng"].
        set scan["threat_height"] to active_path["threat_height"].
        set scan["range"] to active_path["range"].
        // Spend escape-search work only while there is a long-range threat.
        if scan["central_margin"] < 0 {
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
