// Passive ascent recovery display. No steering, throttle, selection or prediction.
// Bounded history and fixed widgets follow the ascent GUI's 2 Hz refresh.
function ascent_recovery_get {
    parameter record, field, fallback.
    if record:haskey(field) { return record[field]. }
    return fallback.
}

// Pure runway-frame projection and aspect-preserving screen mapping.
function ascent_recovery_xy {
    parameter range_m, bearing_deg, runway_deg.
    local relative_bearing is bearing_deg-runway_deg.
    return lex("along",range_m*cos(relative_bearing),"cross",range_m*sin(relative_bearing)).
}

function ascent_recovery_map {
    parameter points.
    local min_along is -1000. local max_along is 1000.
    local min_cross is -1000. local max_cross is 1000.
    local map_index is 0.
    until map_index >= points:length {
        local map_point is points[map_index].
        set min_along to min(min_along,map_point["along"]).
        set max_along to max(max_along,map_point["along"]).
        set min_cross to min(min_cross,map_point["cross"]).
        set max_cross to max(max_cross,map_point["cross"]).
        set map_index to map_index+1.
    }
    local metres_per_pixel is max((max_along-min_along)/568,(max_cross-min_cross)/150).
    local mapped is list().
    set map_index to 0.
    until map_index >= points:length {
        local map_point is points[map_index].
        mapped:add(lex("visible",true,"kind",map_point["kind"],
            "x",320+(map_point["along"]-(min_along+max_along)/2)/metres_per_pixel,
            "y",100+(map_point["cross"]-(min_cross+max_cross)/2)/metres_per_pixel)).
        set map_index to map_index+1.
    }
    return lex("points",mapped,"scale_m",568*metres_per_pixel).
}

// Rows are the evaluated snapshot returned by the selector, never a new search.
// Order the display only: source iteration / tie-breaking and flight target stay intact.
function ascent_recovery_candidate_order {
    parameter candidates.
    local ordered is list().
    local best_index is -1. local best_score is 1e30.
    local candidate_index is 0.
    until candidate_index >= candidates:length {
        local candidate_row is candidates[candidate_index].
        if candidate_row["eligible"] and candidate_row["score"] < best_score {
            set best_index to candidate_index. set best_score to candidate_row["score"].
        }
        set candidate_index to candidate_index+1.
    }
    if best_index >= 0 { ordered:add(candidates[best_index]). }
    // Linear passes: best evaluated first, other eligible rows in catalog order,
    // then excluded rows. Avoid an O(n^2) sort on the flight CPU.
    local eligibility_pass is 0.
    until eligibility_pass >= 2 {
        set candidate_index to 0.
        until candidate_index >= candidates:length {
            local candidate_row is candidates[candidate_index].
            if candidate_index <> best_index and candidate_row["eligible"] = (eligibility_pass = 0) {
                ordered:add(candidate_row).
            }
            set candidate_index to candidate_index+1.
        }
        set eligibility_pass to eligibility_pass+1.
    }
    return ordered.
}

function ascent_recovery_model {
    parameter snapshot.
    local state is snapshot["state"].
    local mode_name is state["mode"].
    local phase_name is state["phase"].
    local result is lex("mode",mode_name,"phase",phase_name,"owner",snapshot["owner"],
        "title",mode_name,"value",phase_name,"detail","Recovery active",
        "next","Follow active recovery guidance","note","","fraction",-1,
        "rows",list(),"map",false,"table",false,"clearance",snapshot["clearance"],
        "candidate_count",0,"target","No selected target",
        "decision",ascent_recovery_get(state,"display_mode_reason","engine failure recovery")).
    local target_site is ascent_recovery_get(state,"target",lex("selected",false)).
    if target_site["selected"] and target_site:haskey("location") {
        set result["target"] to target_site["location"]+" RWY "+target_site["runway_num"].
    }
    local rows is result["rows"].
    local phase_labels is lex("initialize","ASSESSMENT","takeoff_escape","TAKEOFF ESCAPE", "turnback","TURNBACK",
        "handoff","LANDING HANDOFF","nominal_continue","CONTINUE ASCENT","nerv_only_escape","NERV-ONLY ESCAPE",
        "apoapsis_build","APOAPSIS BUILD","coast_align","COAST / ALIGN","insert","INSERTION BURN",
        "orbital_hold","ORBITAL HOLD","select_runway","RUNWAY SEARCH","runway_selected","RUNWAY SELECTED",
        "energy_transit","ENERGY TRANSIT","powered_replan","POWERED REPLAN","capture","CAPTURE",
        "TEAM","TERMINAL GUIDANCE","passive_return","PASSIVE RETURN","align_return","ALIGN RETURN",
        "return_burn","RETURN BURN","verify_return","VERIFY RETURN","entry_handoff","ENTRY HANDOFF",
        "energy_assessment","ENERGY ASSESSMENT","orbit_raise","ORBIT RESCUE / RAISE",
        "orbit_coast","ORBIT RESCUE / COAST","orbit_insert","ORBIT RESCUE / INSERT",
        "entry_coast","ENTRY COAST","powered_entry","POWERED ENTRY","site_search","SITE SEARCH",
        "glide","GLIDE","emergency_glide","EMERGENCY GLIDE","final","FINAL",
        "emergency_final","EMERGENCY FINAL","ocean_approach","WATER APPROACH","ocean_ditch","WATER HOLD",
        "ground_stop","GROUND STOP","complete","COMPLETE").
    set result["phase_label"] to phase_name.
    if phase_labels:haskey(phase_name) { set result["phase_label"] to phase_labels[phase_name]. }
    if mode_name = "runway_abort" {
        local stop_record is ascent_recovery_get(state,"runway_stop",lex()).
        set result["title"] to "RUNWAY REMAINING".
        set result["value"] to round(snapshot["runway_remaining"])+" m".
        set result["detail"] to "Thrust cut / maintain runway heading / decelerate".
        set result["next"] to "Next: speed below "+snapshot["stop_speed"]+" m/s".
        rows:add(list("Surface speed",round(snapshot["surface_speed"],1)+" m/s","STOP" )).
        if stop_record:haskey("required_stop_distance_m") {
            rows:add(list("Required at selection",round(stop_record["required_stop_distance_m"])+" m","RECORDED" )).
            rows:add(list("Available at selection",round(stop_record["runway_remaining_m"])+" m","RECORDED" )).
            rows:add(list("Margin at selection",round(stop_record["runway_remaining_m"]-stop_record["required_stop_distance_m"])+" m","RECORDED" )).
            rows:add(list("Stop model at selection",""+stop_record["model_valid"],"VALIDITY" )).
            set result["fraction"] to max(0,min(1,snapshot["runway_remaining"]/max(1,stop_record["runway_remaining_m"]))).
        }
        set result["note"] to "Bar: remaining runway / selection distance. Stop estimate is recorded, not a live prediction.".
    } else if mode_name = "rtls" or mode_name = "atr" {
        set result["map"] to true.
        set result["title"] to "RECIPROCAL-HEADING ERROR".
        set result["value"] to round(snapshot["reciprocal_error"],1)+" deg".
        set result["detail"] to "Departure runway and flown track / handoff is not a runway".
        set result["next"] to "Next: reciprocal error <= "+snapshot["heading_tolerance"]+" deg AND altitude >= "+round(snapshot["handoff_altitude"])+" m ASL".
        rows:add(list("Altitude / handoff",round(snapshot["altitude"])+" m",round(snapshot["handoff_altitude"])+" m ASL" )).
        rows:add(list("Airspeed / turn gate",round(snapshot["airspeed"],1)+" m/s",snapshot["turn_speed"]+" m/s" )).
        rows:add(list("Vertical speed",round(snapshot["vertical_speed"],1)+" m/s","CLIMB" )).
        rows:add(list("Bank actual / command",round(snapshot["bank"],1)+" deg",round(snapshot["bank_command"],1)+" deg" )).
        if phase_name = "takeoff_escape" {
            set result["title"] to "CLEARANCE". set result["value"] to round(snapshot["clearance"])+" m".
            set result["next"] to "Next: clearly airborne, then minimum turn speed".
        }
        if phase_name = "handoff" { set result["next"] to "Next: stabilize 4 s, then landing guidance takes control". }
        if mode_name = "atr" {
            set result["title"] to "SELECTED RUNWAY". set result["value"] to result["target"].
            set result["detail"] to "Range + heading cost + behind penalty / lowest eligible score wins".
            set result["next"] to "Next: selected runway recovery / preserve survivor policy".
            set result["table"] to true.
            set result["rows"] to list(list("Runway range",snapshot["target_range"],"LIVE"),
                list("Selection score",ascent_recovery_get(target_site,"score","--"),"LOWER WINS"),
                list("Control owner",snapshot["owner"],"RECOVERY" )).
        }
        set result["note"] to "Runway frame / measured track dots. H/O marks the recorded transfer; route dots come from landing guidance.".
    } else if mode_name = "ato" {
        set result["title"] to "APOAPSIS / RECOVERY TARGET".
        set result["value"] to "OPEN".
        set result["detail"] to "Measured progress / not a probability of recovery".
        set result["next"] to "Next: supervised apoapsis build, then coast / align".
        if snapshot["orbit_valid"] {
            set result["value"] to round(snapshot["apoapsis"]/1000,1)+" / "+round(snapshot["orbit_target"]/1000,1)+" km".
            set result["fraction"] to max(0,min(1,snapshot["apoapsis"]/max(1,snapshot["orbit_target"]))).
        }
        local power is ascent_recovery_get(state,"power",lex()).
        rows:add(list("Permitted thrust",ascent_recovery_get(power,"usable","--"),"USABLE" )).
        local budget is ascent_recovery_get(state,"orbit_budget",lex()).
        rows:add(list("Orbit budget",ascent_recovery_get(budget,"possible","--"),"ACCEPTED" )).
        rows:add(list("Current strategy",result["phase_label"],"SUPERVISED" )).
        if phase_name = "coast_align" or phase_name = "insert" {
            set result["title"] to "INSERTION WINDOW". set result["value"] to "STALE / UNAVAILABLE".
            set result["fraction"] to -1.
            set result["next"] to "Next: safe altitude and window; thrust remains alignment-gated".
            if snapshot["insertion_valid"] {
                set result["value"] to ascent_display_clock(snapshot["burn_window_seconds"]).
                if phase_name = "insert" {
                    set result["title"] to "REMAINING INSERTION DV".
                    set result["value"] to round(snapshot["remaining_dv"])+" m/s".
                    if snapshot["initial_dv"] > 0 { set result["fraction"] to max(0,min(1,1-snapshot["remaining_dv"]/snapshot["initial_dv"])). }
                }
                rows:add(list("Safe-altitude gate",snapshot["insertion_altitude_ready"],"READY" )).
                rows:add(list("Window remaining",round(snapshot["burn_window_seconds"],1)+" s","0 s" )).
                rows:add(list("Alignment",round(snapshot["alignment"],1)+" deg",snapshot["alignment_limit"]+" deg" )).
            }
        }
        if phase_name = "orbital_hold" {
            set result["title"] to "ORBITAL HOLD". set result["value"] to "HOLD".
            set result["fraction"] to -1.
            set result["next"] to "Hold: inspect controller reason and actual orbit; no completion reported".
        }
        set result["note"] to "Bars measure apoapsis or delivered insertion dV. Rejected attempts / fallback reasons remain in status.".
    } else if mode_name = "aed" {
        set result["title"] to "TERMINAL ENERGY MARGIN".
        set result["value"] to "ASSESSING".
        if state:haskey("aed_energy_margin") {
            set result["value"] to round(state["aed_energy_margin"])+" m".
            set result["fraction"] to max(0,min(1,(state["aed_energy_margin"]-snapshot["energy_min"])/
                max(1,snapshot["energy_max"]-snapshot["energy_min"]))).
        }
        set result["detail"] to "Powered diversion retained while forecasts run".
        set result["next"] to "Next: stable forecast-approved OR live-powered capture gate".
        rows:add(list("Runway range",snapshot["target_range"],"LIVE" )).
        rows:add(list("Target status",ascent_recovery_get(target_site,"provisional",false),"PROVISIONAL" )).
        rows:add(list("Capture gate",ascent_recovery_get(state,"aed_capture_reason","not_ready"),"STABLE" )).
        rows:add(list("Desired vertical speed",ascent_recovery_get(state,"aed_desired_vs","--"),"m/s" )).
        rows:add(list("Bank limit",ascent_recovery_get(state,"aed_bank_limit","--"),"deg" )).
        local search_record is ascent_recovery_get(state,"aed_search",lex()).
        rows:add(list("Forecast search",ascent_recovery_get(search_record,"reason","pending"),"CACHED" )).
        set result["note"] to "Energy bar: "+snapshot["energy_min"]+".."+snapshot["energy_max"]+" m intake reference. Other capture gates still apply. Powered diversion survives forecast timeout.".
    } else if mode_name = "edr" {
        set result["title"] to "RETURN STATUS".
        set result["value"] to "PLANNED".
        set result["detail"] to "Geometric footprint screen / not a solved runway approach".
        set result["next"] to "Next: verify actual periapsis and return geometry before entry handoff".
        set result["table"] to true.
        if phase_name = "passive_return" { set result["value"] to "PASSIVE COAST". }
        if phase_name = "verify_return" { set result["value"] to "VERIFYING". }
        if ascent_recovery_get(state,"entry_verified",false) { set result["value"] to "VERIFIED RETURN". }
        rows:add(list("Periapsis",snapshot["periapsis_text"],"ACTUAL" )).
        rows:add(list("Alignment",ascent_recovery_get(state,"alignment","--"),"deg" )).
        rows:add(list("Entry verified",ascent_recovery_get(state,"entry_verified",false),"ACTUAL GEOMETRY" )).
        rows:add(list("Control owner",snapshot["owner"],"RETURN" )).
        set result["note"] to "Ranked by footprint offset, not aircraft range. Table retains its assessment UT; unsearched runways are unranked.".
    } else {
        set result["title"] to "CONTINGENCY / "+result["phase_label"].
        set result["value"] to round(snapshot["clearance"],1)+" m".
        set result["detail"] to "Terrain / hull clearance".
        set result["next"] to "Next: active contingency strategy / monitor clearance and sink".
        rows:add(list("Groundspeed",round(snapshot["surface_speed"],1)+" m/s","ACTUAL" )).
        rows:add(list("Vertical speed",round(snapshot["vertical_speed"],1)+" m/s","ACTUAL" )).
        rows:add(list("Usable NERV thrust",ascent_recovery_get(ascent_recovery_get(state,"nerv_power",lex()),"usable","--"),"CACHED" )).
        rows:add(list("Recovery reason",ascent_recovery_get(state,"recovery_reason",snapshot["reason"]),"STATE" )).
        if phase_name = "ground_stop" { set result["value"] to round(snapshot["surface_speed"],1)+" m/s". set result["detail"] to "Contact / stopping". }
        if phase_name = "orbit_raise" or phase_name = "orbit_coast" or phase_name = "orbit_insert" {
            set result["value"] to snapshot["periapsis_text"]. set result["detail"] to "Orbit rescue / measured periapsis".
        }
        if phase_name = "energy_assessment" or phase_name = "site_search" { set result["value"] to "ASSESSING". }
        set result["note"] to "Active recovery strategy only; no invented terrain or predicted route.".
    }
    set result["detail"] to result["detail"]+" | decision: "+result["decision"].
    if target_site:haskey("candidates") { set result["candidate_count"] to target_site["candidates"]:length. }
    if snapshot["owner"] <> "ASCENT" {
        set result["detail"] to "Owner: "+snapshot["owner"]+" / "+snapshot["receiver_phase"].
        set result["next"] to "Handoff: "+snapshot["receiver_phase"]+" / survivor restrictions retained".
    }
    if not state["active"] or snapshot["finished"] {
        if ascent_recovery_get(state,"controls_released",false) { set result["owner"] to "PILOT / RELEASED". }
        set result["title"] to "RECOVERY OUTCOME".
        set result["value"] to "RESULT UNAVAILABLE".
        local outcome is ascent_recovery_get(state,"result",lex()).
        if outcome:haskey("reason") { set result["value"] to outcome["reason"]. }
        set result["detail"] to "Reported success: "+ascent_recovery_get(outcome,"success",false).
        set result["next"] to "Recovery ended / inspect actual result and vehicle state".
        set result["fraction"] to -1.
    }
    return result.
}

function ascent_recovery_collect {
    parameter sample, state.
    local nominal is ascent_recovery_get(state,"nominal_insertion",false).
    if nominal or not state:haskey("mode") { return. }
    local mode_name is state["mode"].
    if mode_name <> "runway_abort" and mode_name <> "rtls" and mode_name <> "atr" and mode_name <> "ato" and
       mode_name <> "aed" and mode_name <> "edr" and mode_name <> "contingency_abort" { return. }
    local receiver_phase is state["phase"]. local owner_name is "ASCENT".
    local handoff_state is ascent_recovery_get(state,"handoff",lex("started",false,"complete",false)).
    if handoff_state["started"] and not handoff_state["complete"] {
        set owner_name to "LANDING / ENTRY". set receiver_phase to step.
        if defined terminal_route and (step = "TEAM" or step = "landing") {
            set receiver_phase to ascent_recovery_get(terminal_route,"phase",step).
        }
    }
    local departure is ascent_recovery_get(state,"departure_runway",lex()).
    local runway_remaining is -1. local departure_heading is 0. local departure_altitude is 0.
    if departure:haskey("end") { set runway_remaining to calcdistance_m(ship:geoposition,departure["end"]). }
    if departure:haskey("heading") { set departure_heading to departure["heading"]. }
    if departure:haskey("altitude") { set departure_altitude to departure["altitude"]. }
    if departure:haskey("end") and departure:haskey("heading") {
        // Signed remaining distance: an overrun must not appear to gain runway.
        local end_offset is ascent_recovery_xy(calcdistance_m(ship:geoposition,departure["end"]),
            heading_between(ship:geoposition,departure["end"]),departure_heading).
        set runway_remaining to end_offset["along"].
    }
    local target_site is ascent_recovery_get(state,"target",lex("selected",false)).
    local target_range is "--".
    if target_site["selected"] and target_site:haskey("start") {
        set target_range to round(calcdistance_m(ship:geoposition,target_site["start"])/1000,1)+" km".
    }
    local rtls_cfg is AVES["Abort"]["RTLS"].
    local orbit_cfg is recovery_orbit_config().
    local clearance_m is alt:radar.
    if mode_name = "contingency_abort" { set clearance_m to ship:bounds:bottomalt. }
    local snapshot is lex("state",state,"owner",owner_name,"receiver_phase",receiver_phase,
        "reason",Lastest_status,"finished",sample["finished"],"clearance",clearance_m,
        "surface_speed",sample["surface_speed"],"airspeed",sample["airspeed"],"vertical_speed",sample["vertical_speed"],
        "altitude",sample["altitude"],"apoapsis",sample["apoapsis"],"orbit_valid",sample["orbit_valid"],
        "periapsis_text","OPEN","runway_remaining",runway_remaining,"target_range",target_range,
        "stop_speed",AVES["Abort"]["RunwayStop"]["stop_speed"],"bank",roll_for(),
        "bank_command",dap["aoa"]["target_bank"],
        "reciprocal_error",abs(normalized_heading_error(departure_heading+180,compass_for_prograde())),
        "heading_tolerance",rtls_cfg["reciprocal_heading_tolerance"],"turn_speed",rtls_cfg["minimum_turn_speed"],
        "handoff_altitude",departure_altitude+rtls_cfg["handoff_minimum_altitude"],
        "orbit_target",orbit_cfg["target_ap"],"alignment_limit",orbit_cfg["alignment"],
        "insertion_valid",sample["insertion_valid"],"burn_window_seconds",sample["burn_window_seconds"],
        "insertion_altitude_ready",sample["insertion_altitude_ready"],"remaining_dv",sample["remaining_dv"],
        "alignment",sample["alignment"],"initial_dv",-1).
    if mode_name = "aed" {
        local energy_cfg is recovery_aed_config().
        set snapshot["energy_min"] to energy_cfg["team_energy_minimum"].
        set snapshot["energy_max"] to energy_cfg["team_energy_maximum"].
    }
    if sample["orbit_valid"] { set snapshot["periapsis_text"] to round(sample["periapsis"]/1000,1)+" km". }
    if sample["insertion_valid"] {
        if not ascent_display_state:haskey("recovery_initial_dv") {
            set ascent_display_state["recovery_initial_dv"] to sample["remaining_dv"].
        }
        set snapshot["initial_dv"] to ascent_display_state["recovery_initial_dv"].
    }
    set sample["abort_display"] to ascent_recovery_model(snapshot).
    set sample["page"] to "RECOVERY / "+mode_name.
    set sample["phase"] to state["phase"].
    set sample["recovery"] to state["active"].
    set sample["abort_snapshot"] to snapshot.
    set sample["health"] to sample["page"]+" / "+sample["abort_display"]["phase_label"].
    if sample["dap_mode"] <> "auto" and sample["dap_mode"] <> "AUTO" {
        set sample["health"] to sample["health"]+" / MANUAL: "+sample["dap_mode"].
    }
    if sample["protection"] <> "normal" {
        set sample["health"] to sample["health"]+" / PROTECTION: "+sample["protection"].
    }
}

function ascent_recovery_create {
    parameter parent_box.
    global ascent_recovery_panel is parent_box:addvlayout().
    set ascent_recovery_panel:visible to false.
    global ascent_recovery_hero is ascent_recovery_panel:addlabel().
    ascent_display_label_style(ascent_recovery_hero,24,"center").
    set ascent_recovery_hero:style:width to 630.
    global ascent_recovery_detail is ascent_recovery_panel:addlabel().
    ascent_display_label_style(ascent_recovery_detail,13).
    set ascent_recovery_detail:style:width to 630.
    global ascent_recovery_bar is ascent_recovery_panel:addvlayout().
    set ascent_recovery_bar:style:width to 600. set ascent_recovery_bar:style:height to 8.
    set ascent_recovery_bar:style:bg to "Libraries/gui_images/ascent_track.png".
    set ascent_recovery_bar:style:padding:h to 0. set ascent_recovery_bar:style:padding:v to 0.
    global ascent_recovery_fill is ascent_recovery_bar:addvlayout().
    set ascent_recovery_fill:style:height to 8. set ascent_recovery_fill:style:hstretch to false.
    set ascent_recovery_fill:style:bg to "Libraries/gui_images/ascent_fill.png".
    global ascent_recovery_view_button is ascent_recovery_panel:addbutton("Show L/SIT").
    global ascent_recovery_view is "selection".
    global ascent_recovery_view_phase is "".
    set ascent_recovery_view_button:onclick to {
        if ascent_recovery_view = "selection" { set ascent_recovery_view to "spatial". }
        else { set ascent_recovery_view to "selection". }
    }.
    global ascent_recovery_map_box is ascent_recovery_panel:addvlayout().
    set ascent_recovery_map_box:style:width to 640. set ascent_recovery_map_box:style:height to 200.
    set ascent_recovery_map_box:style:bg to "Libraries/gui_images/ascent_panel.png".
    set ascent_recovery_map_box:style:padding:h to 0. set ascent_recovery_map_box:style:padding:v to 0.
    global ascent_recovery_markers is list().
    for marker_index in range(0,40) {
        local point_widget is ascent_recovery_map_box:addlabel().
        set point_widget:style:width to 12. set point_widget:style:height to 12.
        set point_widget:style:hstretch to false. set point_widget:style:vstretch to false.
        set point_widget:style:padding:h to 0. set point_widget:style:padding:v to 0.
        set point_widget:visible to false.
        ascent_recovery_markers:add(point_widget).
    }
    global ascent_recovery_map_legend is ascent_recovery_panel:addlabel().
    ascent_display_label_style(ascent_recovery_map_legend,11,"left",true).
    global ascent_recovery_rows is list().
    for row_index in range(0,6) { ascent_recovery_rows:add(ascent_display_row(ascent_recovery_panel,"" )). }
    global ascent_recovery_table is ascent_recovery_panel:addvlayout().
    global ascent_recovery_table_heading is ascent_recovery_table:addlabel().
    ascent_display_label_style(ascent_recovery_table_heading,12).
    global ascent_recovery_table_rows is list().
    for row_index in range(0,6) { ascent_recovery_table_rows:add(ascent_display_row(ascent_recovery_table,"" )). }
    global ascent_recovery_table_page is 0.
    global ascent_recovery_table_next is ascent_recovery_table:addbutton("Next candidates").
    set ascent_recovery_table_next:onclick to { set ascent_recovery_table_page to ascent_recovery_table_page+1. }.
    global ascent_recovery_note is ascent_recovery_panel:addlabel().
    set ascent_recovery_note:style:width to 630.
    ascent_display_label_style(ascent_recovery_note,11,"left",true).
}

function ascent_recovery_spatial {
    parameter snapshot.
    local state is snapshot["state"].
    local origin_runway is ascent_recovery_get(state,"departure_runway",lex()).
    if state["mode"] = "atr" { set origin_runway to state["target"]. }
    set ascent_recovery_map_box:visible to origin_runway:haskey("start") and origin_runway:haskey("heading").
    if not ascent_recovery_map_box:visible { set ascent_recovery_map_legend:text to "Runway geometry unavailable". return. }
    local origin_point is origin_runway["start"].
    local raw_points is list(lex("along",0,"cross",0,"kind","runway")).
    if not ascent_display_state:haskey("recovery_track") {
        set ascent_display_state["recovery_track"] to list().
        set ascent_display_state["recovery_track_ut"] to -1.
    }
    local track_samples is ascent_display_state["recovery_track"].
    if time:seconds-ascent_display_state["recovery_track_ut"] >= 2 {
        track_samples:add(ship:geoposition).
        if track_samples:length > 24 { track_samples:remove(0). }
        set ascent_display_state["recovery_track_ut"] to time:seconds.
    }
    local positions is list(). local point_kinds is list().
    for track_position in track_samples { positions:add(track_position). point_kinds:add("track"). }
    if state:haskey("display_handoff_position") {
        positions:add(state["display_handoff_position"]). point_kinds:add("handoff").
    }
    local handoff_state is ascent_recovery_get(state,"handoff",lex("started",false,"complete",false)).
    if handoff_state["started"] and not handoff_state["complete"] and defined terminal_route and
       (step = "TEAM" or step = "landing") {
        local supplied_route is reentry_lsit_terminal_path().
        local route_count is 0.
        for route_position in supplied_route {
            if route_count < 10 { positions:add(route_position). point_kinds:add("fix"). }
            set route_count to route_count+1.
        }
    }
    positions:add(ship:geoposition). point_kinds:add("vehicle").
    for point_index in range(0,positions:length) {
        local measured_point is ascent_recovery_xy(calcdistance_m(origin_point,positions[point_index]),
            heading_between(origin_point,positions[point_index]),origin_runway["heading"]).
        set measured_point["kind"] to point_kinds[point_index]. raw_points:add(measured_point).
    }
    local mapped is ascent_recovery_map(raw_points).
    local previous_marker is "none". local previous_y is 0.
    for marker_index in range(0,ascent_recovery_markers:length) {
        local point_widget is ascent_recovery_markers[marker_index].
        set point_widget:visible to marker_index < mapped["points"]:length.
        if point_widget:visible {
            local mapped_point is mapped["points"][marker_index].
            local image_name is "ascent_path_dot".
            if mapped_point["kind"] = "vehicle" { set image_name to "ascent_vehicle". }
            if mapped_point["kind"] = "runway" { set image_name to "ascent_runway". }
            if mapped_point["kind"] = "handoff" { set image_name to "ascent_handoff". }
            if mapped_point["kind"] = "fix" { set image_name to "ascent_target". }
            set point_widget:image to "Libraries/gui_images/"+image_name+".png".
            ascent_display_place(point_widget,mapped_point,previous_marker,previous_y).
            set previous_marker to point_widget. set previous_y to mapped_point["y"].
        }
    }
    set ascent_recovery_map_legend:text to "Runway rectangle / track dots / vehicle dot / H/O diamond / guidance crosses"+
        "\nRunway frame span "+round(mapped["scale_m"]/1000,1)+" km. Symbols not to scale; no predicted turn path.".
}

function ascent_recovery_render {
    parameter sample.
    local model is sample["abort_display"]. local snapshot is sample["abort_snapshot"].
    local state is snapshot["state"].
    set ascent_display_chart:visible to false. set ascent_display_hero:visible to false.
    set ascent_display_summary:visible to false. set ascent_display_columns["box"]:visible to false.
    for field_name in ascent_display_rows:keys { set ascent_display_rows[field_name]["box"]:visible to false. }
    set ascent_recovery_panel:visible to true.
    set ascent_display_phase:text to "<b>"+model["phase_label"]+"</b>".
    set ascent_display_target:text to model["target"].
    local failures is ascent_recovery_get(state,"scenario",lex("rapiers_out",0,"nervs_out",0)).
    set ascent_display_engines:text to failures["rapiers_out"]+" RAPIER OUT / "+failures["nervs_out"]+" NERV OUT".
    set ascent_recovery_hero:text to model["title"]+"\n<b>"+model["value"]+"</b>".
    set ascent_recovery_detail:text to model["detail"].
    set ascent_recovery_bar:visible to model["fraction"] >= 0.
    set ascent_recovery_fill:visible to model["fraction"] > 0.
    set ascent_recovery_fill:style:width to max(1,round(600*max(0,model["fraction"]))).
    if ascent_recovery_view_phase <> model["mode"]+"|"+model["phase"]+"|"+model["owner"] {
        set ascent_recovery_view to "selection". set ascent_recovery_table_page to 0.
        if model["owner"] <> "ASCENT" { set ascent_recovery_view to "spatial". }
        set ascent_recovery_view_phase to model["mode"]+"|"+model["phase"]+"|"+model["owner"].
    }
    set ascent_recovery_view_button:visible to model["mode"] = "atr".
    set ascent_recovery_view_button:text to "Show L/SIT".
    if ascent_recovery_view = "spatial" { set ascent_recovery_view_button:text to "Show runway decision". }
    local spatial_visible is model["map"] and (model["mode"] <> "atr" or ascent_recovery_view = "spatial").
    set ascent_recovery_map_box:visible to spatial_visible.
    set ascent_recovery_map_legend:visible to spatial_visible.
    if spatial_visible { ascent_recovery_spatial(snapshot). }
    for row_index in range(0,ascent_recovery_rows:length) {
        local row_widget is ascent_recovery_rows[row_index].
        set row_widget["box"]:visible to row_index < model["rows"]:length.
        if row_widget["box"]:visible {
            local row_data is model["rows"][row_index].
            set row_widget["caption"]:text to ""+row_data[0].
            set row_widget["now"]:text to ""+row_data[1]. set row_widget["goal"]:text to ""+row_data[2].
        }
    }
    set ascent_recovery_table:visible to model["table"] and (model["mode"] <> "atr" or ascent_recovery_view = "selection").
    if ascent_recovery_table:visible {
        local target_site is ascent_recovery_get(state,"target",lex()).
        local candidates is ascent_recovery_get(target_site,"candidates",list()).
        // Linear display ordering is cached by assessment UT.
        local cache_key is model["mode"]+"|"+ascent_recovery_get(target_site,"assessment_ut",-1).
        if not ascent_display_state:haskey("candidate_key") or ascent_display_state["candidate_key"] <> cache_key {
            set ascent_display_state["candidate_key"] to cache_key.
            set ascent_display_state["candidate_rows"] to ascent_recovery_candidate_order(candidates).
        }
        local ordered is ascent_display_state["candidate_rows"].
        local page_count is max(1,ceiling(ordered:length/6)).
        set ascent_recovery_table_page to mod(ascent_recovery_table_page,page_count).
        set ascent_recovery_table_heading:text to "RUNWAY / RANGE / DECISION ("+(ascent_recovery_table_page+1)+"/"+page_count+
            ") | assessment UT "+ascent_recovery_get(target_site,"assessment_ut","--").
        if model["mode"] = "edr" { set ascent_recovery_table_heading:text to "FOOTPRINT OFFSET / evaluated candidates only | UT "+ascent_recovery_get(target_site,"assessment_ut","--"). }
        set ascent_recovery_table_next:visible to page_count > 1.
        for row_index in range(0,6) {
            local row_widget is ascent_recovery_table_rows[row_index].
            local source_index is ascent_recovery_table_page*6+row_index.
            set row_widget["box"]:visible to source_index < ordered:length.
            if row_widget["box"]:visible {
                local candidate_row is ordered[source_index].
                local reason_text is "outside range".
                if candidate_row["eligible"] { set reason_text to "higher score". }
                if model["mode"] = "edr" and candidate_row["eligible"] { set reason_text to "farther footprint". }
                if candidate_row["eligible"] and target_site:haskey("score") and candidate_row["score"] = target_site["score"] { set reason_text to "tie / earlier wins". }
                if ascent_recovery_get(target_site,"selected",false) and candidate_row["location"] = target_site["location"] and candidate_row["runway_num"] = target_site["runway_num"] { set reason_text to "SELECTED". }
                set row_widget["caption"]:text to candidate_row["location"]+" "+candidate_row["runway_num"].
                set row_widget["now"]:text to round(candidate_row["distance_m"]/1000,1)+" km".
                set row_widget["goal"]:text to reason_text.
                if model["mode"] = "atr" and candidate_row["eligible"] {
                    set row_widget["now"]:text to round(candidate_row["distance_m"]/1000,1)+"km / "+round(candidate_row["heading_error"])+"deg".
                    set row_widget["goal"]:text to round(candidate_row["score"]/1000,1)+" / "+reason_text.
                }
            }
        }
        if candidates:length = 0 { set ascent_recovery_table_heading:text to "No evaluated runway snapshot available". }
        if not ascent_recovery_get(target_site,"search_complete",true) {
            set ascent_recovery_table_heading:text to ascent_recovery_table_heading:text+"\nSearch budget ended; unsearched runways are not ranked.".
        }
    }
    set ascent_recovery_note:text to model["note"].
    if model["mode"] = "atr" {
        set ascent_recovery_note:text to "ATR: range + heading cost + behind penalty. Table: range / track error; score / reason.\n"+model["note"].
    }
    set ascent_display_next:text to model["next"].
    local dump_text is "not cached".
    if state:haskey("fuel_dump_active") { set dump_text to "active="+state["fuel_dump_active"]. }
    else {
        local engine_policy is ascent_recovery_get(state,"policy",lex()).
        if engine_policy:haskey("fuel_dump") { set dump_text to "policy="+engine_policy["fuel_dump"]. }
    }
    set ascent_display_footer:text to "OWNER "+model["owner"]+" / "+snapshot["receiver_phase"]+
        " | THR "+round(sample["throttle"]*100)+"% | LF "+round(ship:liquidfuel)+" / Ox "+round(ship:oxidizer)+
        "\nRAPIER "+sample["rapier_mode"]+"/"+sample["rapiers"]+" | NERV "+sample["nervs"]+
        " | DUMP "+dump_text+" | reserves LF "+ascent_recovery_get(state,"lf_reserve","--")+
        " / Ox "+ascent_recovery_get(state,"ox_reserve","--")+
        "\n"+Lastest_status.
}

// Shared HUD ticks keep the existing ascent window current during synchronous
// landing / entry calls. No GUI is created for standalone landing missions.
function ascent_recovery_handoff_tick {
    if not defined ascent_display_state or not defined abort_state or not defined ascent_recovery_panel { return. }
    if not abort_state:haskey("mode") or not abort_state:haskey("handoff") { return. }
    if not abort_state["handoff"]["started"] or abort_state["handoff"]["complete"] { return. }
    if ascent_recovery_get(abort_state,"nominal_insertion",false) { return. }
    update_assent_gui().
    if defined POS_LOG_LEVEL { flight_log_ascent_display_observe(ascent_display_data,ascent_display_log). }
}
