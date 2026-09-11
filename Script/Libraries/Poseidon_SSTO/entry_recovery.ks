function entry_regime {
    if ship:orbit:eccentricity >= 1 { return "reentry_int". }
    if ship:apoapsis >= 10000000 { return "reentry_int". }
    if ship:apoapsis >= 1000000 { return "reentry_high". }
    if ship:apoapsis >= 500000 { return "reentry_mid". }
    return "reentry_low".
}

// Live POS3 recovery executive. Only this layer changes targets or logs;
// entry_guid.ks and the FAR integration remain passive prediction functions.
function entry_reset_plan {
    set entry_traj to lex("converged",false,"iterations",0,"error",lex("str","not_planned"),"entry_pos_square",list()).
    set basice_reentry_guidance to true.
    set entry_plan_index to 0.
    set entry_next_solve to time:seconds.
    set entry_turnside to "left".
}

function entry_reference {
    parameter plan, elapsed.
    if not plan["converged"] or not plan:haskey("samples") { return lex("valid",false,"reason","no_valid_plan"). }
    local samples is plan["samples"].
    if samples:length < 2 { return lex("valid",false,"reason","short_plan"). }
    if elapsed > AVES["Entry"]["plan_max_age"] or elapsed > samples[samples:length-1]["simtime"]+5 {
        return lex("valid",false,"reason","plan_expired").
    }
    until entry_plan_index >= samples:length-2 or samples[entry_plan_index+1]["simtime"] >= elapsed {
        set entry_plan_index to entry_plan_index+1.
    }
    local a is samples[entry_plan_index]. local b is samples[entry_plan_index+1].
    local fraction is max(0,min(1,(elapsed-a["simtime"])/max(0.001,b["simtime"]-a["simtime"]))).
    local ref is lex("simtime",elapsed,"altitude",a["altitude"]+(b["altitude"]-a["altitude"])*fraction,
        "position",a["position"]+(b["position"]-a["position"])*fraction,
        "velocity",a["velocity"]+(b["velocity"]-a["velocity"])*fraction,
        "surfvel",a["surfvel"]+(b["surfvel"]-a["surfvel"])*fraction,
        "latlong",latlng(a["latlong"]:lat+(b["latlong"]:lat-a["latlong"]:lat)*fraction,
            a["latlong"]:lng+entry_heading_error(b["latlong"]:lng-a["latlong"]:lng)*fraction)).
    if abs(ref["altitude"]-ship:altitude) > AVES["Entry"]["plan_alt_error"] or
        abs(ref["surfvel"]:mag-ship:airspeed) > AVES["Entry"]["plan_speed_error"] {
        return lex("valid",false,"reason","plan_diverged").
    }
    return lex("valid",true,"state",ref).
}

function entry_land_strip {
    parameter threshold, heading_value, deadline_ut.
    local cfg is AVES["Entry"].
    local low is 1e9. local high is -1e9. local previous_height is threshold:terrainheight.
    local along is 0.
    until along > cfg["offfield_length"] {
        if time:seconds >= deadline_ut { return lex("valid",false). }
        local centre is get_geoposition_along_heading(threshold,heading_value,along).
        local height is centre:terrainheight.
        if height <= 2 or (along > 0 and abs(height-previous_height)/250 > cfg["offfield_grade"]) {
            return lex("valid",false).
        }
        for offset in list(-50,0,50) {
            local point is get_geoposition_along_heading(centre,heading_value+90,offset).
            local terrain is point:terrainheight.
            if terrain <= 2 { return lex("valid",false). }
            set low to min(low,terrain). set high to max(high,terrain).
        }
        if high-low > cfg["offfield_relief"] { return lex("valid",false). }
        set previous_height to height. set along to along+250.
    }
    return lex("valid",true,"altitude",high,"end",get_geoposition_along_heading(threshold,heading_value,cfg["offfield_length"])).
}

function entry_choose_alternate {
    parameter failure, attempted.
    local best is lex("valid",false).
    if not failure:haskey("entry_pos_square") { return best. }
    local polygon is failure["entry_pos_square"].
    if polygon:length < 3 { return best. }
    local deadline_ut is time:seconds+2.
    local score is 1e30.
    local runways is Location_constants["kerbin"].
    // Test the TEAM interface, not just the runway threshold. Rebuild all
    // runway metadata together and skip every already-attempted destination.
    for key in runways:keys {
        if time:seconds >= deadline_ut { return best. }
        if key:endswith("_start") {
            local parts is key:split("_").
            if parts:length = 4 {
                local id is parts[0]+"_"+parts[2].
                local end_key is parts[0]+"_runway_"+parts[2]+"_end".
                local alt_key is parts[0]+"_runway".
                if not attempted:contains(id) and runways:haskey(end_key) and KerbinRunwayalt:haskey(alt_key) {
                    local threshold is runways[key]. local runway_finish is runways[end_key].
                    if calcdistance_m(threshold,runway_finish) > 1000 {
                        local heading_value is heading_between(threshold,runway_finish).
                        local altitude is KerbinRunwayalt[alt_key].
                        local interface is define_TEAM_interface(threshold,heading_value,altitude).
                        if entry_point_in_footprint(interface["target_latlng"],polygon) {
                            local distance is calcdistance_m(interface["target_latlng"],entry_original_target).
                            if distance < score {
                                set score to distance.
                                set best to lex("valid",true,"id",id,"location",parts[0],"number",parts[2],
                                    "start",threshold,"end",runway_finish,"heading",heading_value,"altitude",altitude,
                                    "interface",interface,"kind","runway").
                            }
                        }
                    }
                }
            }
        }
    }
    if best["valid"] { return best. }
    // No catalog runway is reachable. Sample interior TEAM points and screen
    // a land strip ahead of each one. This is coarse terrain screening, not a
    // guarantee about surface objects, gear suspension or local roughness.
    local centre_vector is v(0,0,0).
    for vertex in polygon { set centre_vector to centre_vector+entry_geo_unit(vertex). }
    if centre_vector:mag < 0.001 { return best. }
    set centre_vector to centre_vector:normalized.
    local candidates is list(centre_vector).
    for vertex in polygon { candidates:add((centre_vector*0.65+entry_geo_unit(vertex)*0.35):normalized). }
    if failure:haskey("best_state") {
        candidates:add((centre_vector*0.3+entry_geo_unit(failure["best_state"]["latlong"])*0.7):normalized).
    }
    local index is 0.
    for point_vector in candidates {
        if time:seconds >= deadline_ut { return best. }
        local point is latlng(arcsin(point_vector:y),arctan2(point_vector:z,point_vector:x)).
        local id is "offfield_"+round(point:lat,2)+"_"+round(point:lng,2).
        if not attempted:contains(id) and entry_point_in_footprint(point,polygon) {
            local heading_value is heading_between(ship:geoposition,point).
            local threshold is get_geoposition_along_heading(point,heading_value,calculate_distance_from_alt(AVES["TEAMAltitude"],0)).
            local strip is entry_land_strip(threshold,heading_value,deadline_ut).
            if strip["valid"] {
                local interface is define_TEAM_interface(threshold,heading_value,strip["altitude"]).
                if entry_point_in_footprint(interface["target_latlng"],polygon) {
                    return lex("valid",true,"id",id,"location","Off-field","number","AUTO",
                        "start",threshold,"end",strip["end"],"heading",heading_value,"altitude",strip["altitude"],
                        "interface",interface,"kind","screened_land").
                }
            }
        }
        set index to index+1.
    }
    return best.
}

function entry_apply_alternate {
    parameter candidate.
    local old_location is Location+" "+runway_nr.
    set Location to candidate["location"]. set runway_nr to candidate["number"].
    set runway_start to candidate["start"]. set runway_end to candidate["end"].
    set runway_heading to candidate["heading"]. set runway_altitude to candidate["altitude"].
    set Team_interface to candidate["interface"]. set reentry_target to Team_interface["target_latlng"].
    if defined terminal_route { unset terminal_route. }
    set terminal_route_runway_change_request to "".
    if ADDONS:TR:available and ADDONS:TR:hasimpact { ADDONS:TR:SETTARGET(runway_start). }
    entry_attempted_targets:add(candidate["id"]).
    set entry_retarget_count to entry_retarget_count+1.
    entry_reset_plan().
    flight_log_set_runway(Location,runway_nr,runway_start,runway_end,runway_heading,runway_altitude).
    flight_log_set_entry_target(Team_interface).
    flight_log_event("entry_retarget","from="+old_location+"|to="+Location+" "+runway_nr+
        "|kind="+candidate["kind"]+"|count="+entry_retarget_count+"|lat="+Team_interface["target_latlng"]:lat+
        "|lng="+Team_interface["target_latlng"]:lng+"|inside_footprint=true").
    set Lastest_status to "Alternate: "+Location+" "+runway_nr.
}

function entry_update_plan {
    parameter metrics.
    local target_alt is Team_interface["target_altitude"].
    local can_solve is ship:altitude < BODY:atm:height+2000 and ship:altitude > target_alt+2000 and ship:verticalspeed < 0.
    local reference is lex("valid",false,"reason","basic_guidance").
    if entry_traj["converged"] {
        set reference to entry_reference(entry_traj,time:seconds-entry_traj["solve_ut"]).
        if not reference["valid"] {
            flight_log_event("entry_plan_invalid","reason="+reference["reason"]).
            set entry_traj["converged"] to false. set basice_reentry_guidance to true.
            set entry_next_solve to max(entry_next_solve,time:seconds+1).
        }
    }
    if not entry_traj["converged"] and can_solve and time:seconds >= entry_next_solve and atmospheric_load_reason(metrics) = "normal" {
        set dap["aoa"]["target_bank"] to 0.
        dap:update().
        local result is calc_entry_traj(current_simstate(),target_alt,Team_interface["target_latlng"],Team_interface["team_interface_box"],"time",0).
        flight_log_entry_solver_result(result).
        set entry_traj to result.
        set entry_plan_index to 0.
        set entry_next_solve to time:seconds+AVES["Entry"]["retry_interval"].
        if result["converged"] {
            set basice_reentry_guidance to false.
            set alpha_md_pid to pidloop(0.26,0.31,0.65).
            set alpha_md_pid:maxoutput to min(AVES["Entry"]["max_bank"],result["bank"]+AVES["EG_am_range"]).
            set alpha_md_pid:minoutput to max(0,result["bank"]-AVES["EG_am_range"]).
            set alpha_md_pid:setpoint to 0.
            set reference to entry_reference(result,time:seconds-result["solve_ut"]).
            set Lastest_status to "Entry plan converged".
        } else {
            set basice_reentry_guidance to true.
            set Lastest_status to "Basic entry: "+result["error"]["str"].
            if entry_retarget_count < AVES["Entry"]["max_retargets"] {
                local alternate is entry_choose_alternate(result,entry_attempted_targets).
                if alternate["valid"] { entry_apply_alternate(alternate). }
                else { flight_log_event("entry_alternate_unavailable","reason="+result["error"]["str"]). }
            }
        }
    }
    return reference.
}
