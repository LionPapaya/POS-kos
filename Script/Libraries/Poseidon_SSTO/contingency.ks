// Four-RAPIER-loss recovery with monitored NERV insertion and powered entry.
// Initial atmospheric margins require KSP/FAR flight calibration.
function contingency_config {
    return lex("glide_ratio",4,"range_reserve",0.35,"landing_speed",132,
        "capture_height",150,"bank",15,"maximum_range",60000,
        "maximum_descent_angle",30,"maximum_final_speed",175,
        "maximum_glide_altitude",15000,"maximum_glide_speed",550,
        "minimum_search_clearance",400,
        "corridor_length",1800,"corridor_half_width",100,
        "maximum_relief",8,"maximum_search_seconds",8,
        "entry_timeout",1200,"emergency_search_seconds",1,"emergency_scan_range",6000,"emergency_replan_seconds",5,
        "emergency_aoa_rate",3,"emergency_land_max_aoa",15,"emergency_low_speed_aoa",10,
        "ditch_clearance",3,"ditch_commit_height",15,"ditch_max_aoa",25,
        "water_approach_height",400,"water_flare_lead_seconds",10,"water_approach_max_aoa",25,
        "water_approach_sink",2,"water_expected_settle_speed",110,
        "sink_response_lead_seconds",3,
        "dump_lf_fraction",0.10,
        "ditch_height_gain",0.4,"ditch_aoa_gain",1.5,"ditch_aoa_rate",3,
        "activate_nervs_for_recovery",true,"lf_tonnes_per_unit",0.005,"lf_reserve_fraction",0.1,
        "orbit_target_altitude",100000,"orbit_clearance",10000,"orbit_pe_tolerance",100,"orbit_raise_pitch",60,
        "orbit_pullup_aoa",15,"orbit_dv_allowance",200,"orbit_min_acceleration",0.2,
        "orbit_timeout",480,"orbit_progress_seconds",30,"orbit_min_ap_gain",150,
        "orbit_min_pe_gain",100,"orbit_max_descending_speed",100,
        "orbit_alignment_deg",10,"orbit_burn_lead_seconds",15,"orbit_taper_seconds",5,
        "orbit_ap_rebuild_margin",5000,"assist_max_dv_credit",40,"assist_credit_seconds",20,
        "assist_credit_fraction",0.5,"assist_speed_reserve",20,"assist_speed_band",30,
        "assist_energy_reserve",250,"assist_energy_band",500,
        "entry_maximum_range",300000,"entry_capture_reserve",500,
        "entry_runway_distance",20000,"entry_height",10000).
}

// Specific mechanical energy above landing speed, expressed as height.
// Base energy excludes future thrust and energy below Vapp. A separately
// bounded, derated NERV burn credit may be supplied by the live executive.
function contingency_energy {
    parameter height_m, speed_mps, gravity_mps2, distance_m, turn_deg, cfg, assist_height is 0.
    local g is max(gravity_mps2,0.01).
    local usable is max(0,height_m-cfg["capture_height"])+
        max(0,speed_mps^2-cfg["landing_speed"]^2)/(2*g).
    local turn_radius is speed_mps^2/(g*tan(cfg["bank"])).
    local turn_arc is abs(turn_deg)*constant:degtorad*turn_radius.
    local required is (max(0,distance_m)+turn_arc)/cfg["glide_ratio"].
    local margin is (usable+max(0,assist_height))*(1-cfg["range_reserve"])-required.
    return lex("margin",margin,"usable",usable,"required",required,
        "reachable",height_m >= cfg["capture_height"] and
        speed_mps >= cfg["landing_speed"] and margin >= 0).
}

// Sample the full landing corridor, not merely its centre. PQS samples do
// not certify obstacles, trees, gear loading or local slopes between samples.
function contingency_corridor {
    parameter site, course, kind, cfg.
    local low_height is 999999999.
    local high_height is -999999999.
    for along_m in list(-cfg["corridor_length"]/3,0,cfg["corridor_length"]/3,2*cfg["corridor_length"]/3) {
        local centre is get_geoposition_along_heading(site,course,along_m).
        for cross_m in list(-cfg["corridor_half_width"],0,cfg["corridor_half_width"]) {
            local probe is get_geoposition_along_heading(centre,course+90,cross_m).
            local h is probe:terrainheight.
            if kind = "ocean" and h >= -2 { return lex("valid",false,"height",0,"relief",0). }
            if kind = "land" and h < 0 { return lex("valid",false,"height",0,"relief",0). }
            set low_height to min(low_height,h).
            set high_height to max(high_height,h).
        }
    }
    return lex("valid",kind = "ocean" or high_height-low_height <= cfg["maximum_relief"],
        "height",max(0,high_height),"relief",high_height-low_height).
}

function contingency_candidate {
    parameter site, finish, course, site_height, kind, cfg, assist_height is 0.
    local distance_m is calcdistance_m(ship:geoposition,site).
    local bearing is heading_to_target(site).
    local turn_deg is abs(normalized_heading_error(bearing,compass_for_prograde())).
    local alignment is abs(normalized_heading_error(course,bearing)).
    local g is ship:body:mu/(ship:body:radius+ship:altitude)^2.
    local energy is contingency_energy(ship:altitude-site_height,ship:airspeed,g,
        distance_m,turn_deg+alignment,cfg,assist_height).
    // Stay ahead: no speculative powerless turnback or short-base circuit.
    local accepted is energy["reachable"] and turn_deg <= 60 and alignment <= 30 and
        distance_m <= cfg["maximum_range"] and
        ship:altitude-site_height <= cfg["capture_height"]+distance_m*tan(cfg["maximum_descent_angle"]).
    if accepted {
        // Reject sampled ridges along the nominal descending approach.
        for fraction in list(0.25,0.5,0.75) {
            local probe is get_geoposition_along_heading(ship:geoposition,bearing,distance_m*fraction).
            local planned_height is ship:altitude*(1-fraction)+(site_height+cfg["capture_height"])*fraction.
            if planned_height-max(0,probe:terrainheight) < cfg["capture_height"] { set accepted to false. }
        }
    }
    return lex("selected",accepted,"kind",kind,"start",site,"end",finish,
        "heading",course,"altitude",site_height,"distance_m",distance_m,
        "margin",energy["margin"],"score",distance_m+turn_deg*100,
        "location","emergency","runway_num","").
}

function contingency_select {
    parameter cfg, assist_height is 0.
    local best is lex("selected",false,"score",999999999).
    local search_started is time:seconds.
    // Runways always outrank water and land, but must pass the energy gate.
    for key_name in location_constants["kerbin"]:keys {
        if time:seconds-search_started >= cfg["maximum_search_seconds"] or
           ship:altitude-max(0,ship:geoposition:terrainheight) < cfg["minimum_search_clearance"] { return best. }
        if key_name:endswith("_start") and key_name:split("_runway_"):length > 1 {
            local parts is key_name:split("_runway_").
            local place is parts[0].
            local number is parts[1]:split("_")[0].
            local end_key is place+"_runway_"+number+"_end".
            if location_constants["kerbin"]:haskey(end_key) and KerbinRunwayalt:haskey(place+"_runway") {
                local site is location_constants["kerbin"][key_name].
                local finish is location_constants["kerbin"][end_key].
                local candidate is contingency_candidate(site,finish,heading_between(site,finish),
                    KerbinRunwayalt[place+"_runway"],"runway",cfg,assist_height).
                set candidate["location"] to place.
                set candidate["runway_num"] to number.
                if candidate["selected"] and candidate["score"] < best["score"] { set best to candidate. }
            }
            dap:update().
            wait 0.
        }
    }
    if best["selected"] { return best. }
    local clearance is ship:altitude-max(0,ship:geoposition:terrainheight).
    if clearance < cfg["minimum_search_clearance"] { return best. }
    // Limit the geometric scan to the conservative available range.
    local scan_range is min(cfg["maximum_range"],max(1500,
        (clearance-cfg["capture_height"]+assist_height)*cfg["glide_ratio"]*(1-cfg["range_reserve"]))).
    for kind in list("ocean","land") {
        for fraction in list(0.25,0.5,0.75) {
            for offset_deg in list(0,-15,15,-30,30,-60,60) {
                if time:seconds-search_started >= cfg["maximum_search_seconds"] or
                   ship:altitude-max(0,ship:geoposition:terrainheight) < cfg["minimum_search_clearance"] { return best. }
                local course is compass_for_prograde()+offset_deg.
                local site is get_geoposition_along_heading(ship:geoposition,course,scan_range*fraction).
                local corridor is contingency_corridor(site,course,kind,cfg).
                if corridor["valid"] {
                    local finish is get_geoposition_along_heading(site,course,cfg["corridor_length"]).
                    local candidate is contingency_candidate(site,finish,course,corridor["height"],kind,cfg,assist_height).
                    set candidate["relief"] to corridor["relief"].
                    if candidate["selected"] and candidate["score"] < best["score"] { set best to candidate. }
                }
                dap:update().
                wait 0.
            }
        }
        if best["selected"] { return best. }
    }
    return best.
}

// Record each escalation once; a failed plan changes strategy, never releases
// the controls. Cached reasons also explain the subsequent medium/high samples.
function contingency_degraded {
    parameter state, reason.
    if not state:haskey("degraded_reasons") { set state["degraded_reasons"] to lex(). }
    set state["recovery_reason"] to reason.
    if not state["degraded_reasons"]:haskey(reason) {
        set state["degraded_reasons"][reason] to true.
        flight_log_event("contingency_degraded","reason="+reason+"|phase="+state["phase"]+
            "|clearance="+(ship:altitude-max(0,ship:geoposition:terrainheight))+
            "|bottom_height="+ship:bounds:bottomalt+"|speed="+ship:airspeed+
            "|vs="+ship:verticalspeed+"|bank="+roll_for()+"|lf="+ship:liquidfuel).
    }
}

function contingency_release_reserve {
    parameter state, cfg, reason.
    if state["lf_reserve"] <= 0 { return. }
    set state["released_lf_reserve"] to state["lf_reserve"].
    set state["lf_reserve"] to 0.
    flight_log_event("contingency_reserve_released","reason="+reason+
        "|reserve="+state["released_lf_reserve"]+"|lf="+ship:liquidfuel).
    if ship:status <> "LANDED" and ship:status <> "SPLASHED" and state["phase"] <> "ocean_ditch" {
        nervson().
    }
    set state["nerv_power"] to contingency_nerv_power(state,cfg).
    local g is ship:body:mu/(ship:body:radius+ship:altitude)^2.
    set state["assist_height"] to contingency_assist_height(ship:airspeed,g,
        state["nerv_power"]["acceleration"],state["nerv_power"]["dv"],cfg).
}

// Survival ranking rather than certification. Ridge/energy penalties outweigh
// a preference for water; a distant ocean must not beat attainable nearby land.
function contingency_emergency_score {
    parameter distance_m, turn_deg, relief_m, ridge_m, energy_margin, water_fraction.
    return max(0,ridge_m)*10000+max(0,-energy_margin)*1000+
        relief_m*100+abs(turn_deg)*100+distance_m+(1-water_fraction)*2000+
        min(water_fraction,1-water_fraction)*10000.
}

function contingency_emergency_candidate {
    parameter site, course, cfg, assist_height.
    local distance_m is calcdistance_m(ship:geoposition,site).
    local turn_deg is normalized_heading_error(course,compass_for_prograde()).
    local site_h is max(0,site:terrainheight).
    local low_h is site_h.
    local high_h is site_h.
    local water_count is 0.
    if site:terrainheight < -2 { set water_count to 1. }
    local ridge_m is 0.
    // A short landing strip and approach samples keep the emergency scan cheap.
    local strip_m is min(cfg["corridor_length"],max(100,ship:airspeed*4)).
    for fraction in list(0.25,0.5,0.75,1) {
        local probe is get_geoposition_along_heading(ship:geoposition,course,distance_m*fraction).
        local predicted_h is ship:altitude*(1-fraction)+site_h*fraction.
        set ridge_m to max(ridge_m,max(0,probe:terrainheight)-predicted_h).
        local strip_probe is get_geoposition_along_heading(site,course,strip_m*fraction).
        set low_h to min(low_h,max(0,strip_probe:terrainheight)).
        set high_h to max(high_h,max(0,strip_probe:terrainheight)).
        if strip_probe:terrainheight < -2 { set water_count to water_count+1. }
    }
    local water_fraction is water_count/5.
    local kind is "land".
    if water_count = 5 { set kind to "ocean". }
    local g is ship:body:mu/(ship:body:radius+ship:altitude)^2.
    local energy is contingency_energy(ship:altitude-site_h,ship:airspeed,g,
        distance_m,turn_deg,cfg,assist_height).
    return lex("selected",true,"emergency",true,"kind",kind,"start",site,
        "end",get_geoposition_along_heading(site,course,strip_m),"heading",course,
        "altitude",site_h,"distance_m",distance_m,"margin",energy["margin"],
        "relief",high_h-low_h,"ridge",ridge_m,"water_fraction",water_fraction,
        "score",contingency_emergency_score(distance_m,turn_deg,high_h-low_h,
            ridge_m,energy["margin"],water_fraction),"location","emergency","runway_num","").
}

function contingency_select_emergency {
    parameter cfg, assist_height, quick is false.
    local clearance is ship:altitude-max(0,ship:geoposition:terrainheight).
    local course is compass_for_prograde().
    // Below capture height there is no time or bank authority for a new search.
    // Settle along the current track on the local surface, even without a pass.
    if quick or clearance <= cfg["capture_height"] {
        local kind is "land".
        local water_fraction is 0.
        if ship:geoposition:terrainheight < -2 { set kind to "ocean". set water_fraction to 1. }
        return lex("selected",true,"emergency",true,"kind",kind,"start",ship:geoposition,
            "end",ship:geoposition,"heading",course,"altitude",max(0,ship:geoposition:terrainheight),
            "distance_m",0,"margin",0,"score",0,"relief",0,"ridge",0,
            "water_fraction",water_fraction,"location","local_surface","runway_num","").
    }
    local scan_range is min(cfg["emergency_scan_range"],min(max(100,clearance*cfg["glide_ratio"]),
        max(100,ship:airspeed*clearance/max(4,-ship:verticalspeed)))).
    local search_start is time:seconds.
    local search_limit is min(cfg["emergency_search_seconds"],clearance/max(1,-ship:verticalspeed)*0.1).
    local best is contingency_emergency_candidate(
        get_geoposition_along_heading(ship:geoposition,course,scan_range*0.5),course,cfg,assist_height).
    dap:update().
    wait 0.
    for fraction in list(0.25,0.5,0.75) {
        for offset_deg in list(0,-15,15) {
            local live_clearance is ship:altitude-max(0,ship:geoposition:terrainheight).
            if live_clearance <= cfg["capture_height"] { return contingency_select_emergency(cfg,assist_height,true). }
            if time:seconds-search_start >= search_limit { return best. }
            local candidate is contingency_emergency_candidate(
                get_geoposition_along_heading(ship:geoposition,course+offset_deg,scan_range*fraction),
                course+offset_deg,cfg,assist_height).
            if candidate["score"] < best["score"] { set best to candidate. }
            dap:update().
            wait 0.
        }
    }
    return best.
}

function contingency_begin_emergency {
    parameter state, cfg, reason, quick is false.
    local terminal_owned is state["phase"] = "final" or state["phase"] = "emergency_final" or
        state["phase"] = "ground_stop" or state["phase"] = "ocean_ditch".
    contingency_degraded(state,reason).
    contingency_release_reserve(state,cfg,reason).
    // Establish a command before yielding to any terrain search.
    local initial_aoa is min(cfg["emergency_land_max_aoa"],contingency_water_initial_aoa(cfg)).
    if ship:geoposition:terrainheight < -2 and
       ship:bounds:bottomalt <= contingency_water_entry_height(ship:verticalspeed,cfg) {
        // At water-approach height a search must not postpone the flare.
        set quick to true.
        set initial_aoa to contingency_water_initial_aoa(cfg).
    }
    set dap["dap_mode"] to "auto".
    set dap["str_mode"] to "aoa".
    set dap["aoa"]["target_bank"] to 0.
    set dap["aoa"]["target_aoa"] to initial_aoa.
    set dap["aoa"]["smooth_target_aoa"] to initial_aoa.
    set dap["aoa"]["base_pitch"] to 0.
    set dapthrottle to contingency_recovery_throttle(ship:airspeed,0,state["nerv_power"]["usable"],"emergency_glide",cfg).
    contingency_phase(state,"emergency_glide").
    set state["emergency_committed"] to terminal_owned.
    set state["target"] to contingency_select_emergency(cfg,state["assist_height"],quick).
    set state["emergency_aoa"] to min(cfg["emergency_land_max_aoa"],initial_aoa).
    set state["emergency_last_ut"] to time:seconds.
    set state["emergency_last_vs"] to ship:verticalspeed.
    set state["emergency_replan_ut"] to time:seconds+cfg["emergency_replan_seconds"].
    local selected is state["target"].
    flight_log_event("contingency_emergency_target","reason="+reason+"|kind="+selected["kind"]+
        "|lat="+selected["start"]:lat+"|lng="+selected["start"]:lng+"|heading="+selected["heading"]+
        "|range="+selected["distance_m"]+"|energy_margin="+selected["margin"]+
        "|risk_score="+selected["score"]+"|relief="+selected["relief"]+
        "|ridge="+selected["ridge"]+"|water_fraction="+selected["water_fraction"]).
}

// Bounded AoA changes reduce sink without the old low-speed nose-down command
// close to impact. Power rescues low speed above the engine-cutoff clearance;
// brakes are used only with a speed margin. Wings level owns the final.
function contingency_emergency_command {
    parameter clearance, speed_mps, vertical_mps, last_aoa, dt_seconds, power_usable, cfg, vertical_accel is 0.
    local desired_vs is -max(0.7,min(4,clearance*0.1)).
    local predicted_vs is vertical_mps+vertical_accel*cfg["sink_response_lead_seconds"].
    local rate is max(-cfg["emergency_aoa_rate"],min(cfg["emergency_aoa_rate"],
        (desired_vs-predicted_vs)*cfg["ditch_aoa_gain"])).
    local aoa_limit is cfg["emergency_land_max_aoa"].
    // Do not remove lift at the speed boundary while sink is still excessive.
    if speed_mps < cfg["landing_speed"] and predicted_vs >= desired_vs and vertical_mps >= desired_vs {
        set aoa_limit to cfg["emergency_low_speed_aoa"].
    }
    local dt is max(0,min(dt_seconds,0.2)).
    local desired_aoa is max(0,min(aoa_limit,last_aoa+rate*dt)).
    local aoa_cmd is max(last_aoa-cfg["emergency_aoa_rate"]*dt,
        min(last_aoa+cfg["emergency_aoa_rate"]*dt,desired_aoa)).
    local thrust_cmd is contingency_recovery_throttle(speed_mps,cfg["assist_energy_reserve"],
        power_usable,"emergency_glide",cfg).
    if clearance <= cfg["ditch_commit_height"] { set thrust_cmd to 0. }
    return lex("aoa",aoa_cmd,"throttle",thrust_cmd,
        "brakes",speed_mps > cfg["landing_speed"]+30 and vertical_mps >= desired_vs and predicted_vs >= desired_vs,
        "desired_vs",desired_vs,"predicted_vs",predicted_vs).
}

// Sensor differentiation is separate from pure guidance. Ignore stale or
// sub-tick observations rather than interpreting scheduling gaps as authority.
function contingency_vertical_acceleration {
    parameter current_vs, previous_vs, elapsed_s.
    if elapsed_s < 0.01 or elapsed_s > 1 { return 0. }
    return (current_vs-previous_vs)/elapsed_s.
}

// Begin flattening the descent with time for the attitude response. The old
// 15 m gate allowed less than a second at the flight_341 sink rate.
function contingency_water_entry_height {
    parameter vertical_mps, cfg.
    return max(cfg["water_approach_height"],max(0,-vertical_mps)*cfg["water_flare_lead_seconds"]).
}

// Transfer the existing lift command, including a GPWS pull-up, without a
// downward AoA step when the dedicated water controller takes ownership.
function contingency_water_initial_aoa {
    parameter cfg.
    local initial is max(0,calc_aoa()).
    if dap["aoa"]:haskey("smooth_target_aoa") {
        set initial to max(initial,dap["aoa"]["smooth_target_aoa"]).
    } else if dap["aoa"]:haskey("target_aoa") {
        set initial to max(initial,dap["aoa"]["target_aoa"]).
    }
    if dap["envelope"]["terrain_state"] = "pullup" and dap["envelope"]:haskey("max_aoa") {
        set initial to max(initial,dap["envelope"]["max_aoa"]).
        if AVES["Envelope"]:haskey("Terrain") {
            // GPWS uses a horizontal/climbing base pitch, while normal AoA
            // steering follows prograde. Transfer that pitch offset as well.
            local terrain_cfg is AVES["Envelope"]["Terrain"].
            set initial to max(initial,terrain_cfg["pullup_aoa"]+
                max(0,terrain_cfg["pullup_min_base_pitch"]-pitch_for_prograde())).
        }
    }
    return min(cfg["ditch_max_aoa"],initial).
}

// Pure water guidance: first arrest sink, then approach hull clearance at
// bounded sink. Anticipate clearance lost during the pitch response rather
// than continuing to descend into the hold target. Hold unpowered and reduce speed
// until lift runs out. The expected settling speed is telemetry, not a dive
// command or a forced contact gate. No low-speed AoA step removes lift.
function contingency_water_command {
    parameter bottom_height, speed_mps, vertical_mps, last_aoa, dt_seconds, power_usable, holding, cfg, vertical_accel is 0.
    local response_s is cfg["sink_response_lead_seconds"].
    local predicted_height is bottom_height+vertical_mps*response_s+0.5*vertical_accel*response_s^2.
    local desired_vs is max(-cfg["water_approach_sink"],min(1,
        (cfg["ditch_clearance"]-predicted_height)*cfg["ditch_height_gain"])).
    local predicted_vs is vertical_mps+vertical_accel*cfg["sink_response_lead_seconds"].
    local rate is max(-cfg["ditch_aoa_rate"],min(cfg["ditch_aoa_rate"],
        (desired_vs-predicted_vs)*cfg["ditch_aoa_gain"])).
    local aoa_limit is cfg["water_approach_max_aoa"].
    if holding { set aoa_limit to cfg["ditch_max_aoa"]. }
    // An existing pull-up above the approach limit is retained until sink
    // recovers, rather than clipping it on entry to this controller.
    if vertical_mps < desired_vs or predicted_vs < desired_vs { set aoa_limit to max(aoa_limit,last_aoa). }
    local dt is max(0,min(dt_seconds,0.2)).
    local desired_aoa is max(0,min(aoa_limit,last_aoa+rate*dt)).
    local aoa_cmd is max(last_aoa-cfg["ditch_aoa_rate"]*dt,
        min(last_aoa+cfg["ditch_aoa_rate"]*dt,desired_aoa)).
    local thrust_cmd is 0.
    if not holding and power_usable {
        // Preserve approach lift without accelerating towards Vapp+20.
        set thrust_cmd to max(0,min(1,(cfg["landing_speed"]-speed_mps)/cfg["assist_speed_band"])).
        // Low-speed lift recovery must not wait for further deceleration.
        // Do not add thrust to an already fast descending approach.
        if speed_mps < cfg["landing_speed"]+cfg["assist_speed_reserve"] {
            set thrust_cmd to max(thrust_cmd,max(0,min(1,
                (desired_vs-predicted_vs)/cfg["water_approach_sink"]))).
        }
    }
    local drag_cmd is (holding or speed_mps > cfg["landing_speed"]+cfg["assist_speed_reserve"]) and
        vertical_mps >= -cfg["water_approach_sink"] and predicted_vs >= -cfg["water_approach_sink"].
    return lex("aoa",aoa_cmd,"desired_vs",desired_vs,"predicted_vs",predicted_vs,
        "throttle",thrust_cmd,"brakes",drag_cmd,"clearance_target",cfg["ditch_clearance"],
        "predicted_height",predicted_height,
        "aoa_saturated",aoa_cmd >= aoa_limit).
}

function contingency_water_hold {
    parameter state, cfg.
    if state["phase"] <> "ocean_ditch" and state["phase"] <> "ocean_approach" {
        set state["ditch_aoa"] to contingency_water_initial_aoa(cfg).
        // GPWS steers directly, bypassing the AoA smoother. Seed that smoother
        // with the command being transferred, rather than its stale low value.
        set dap["aoa"]["smooth_target_aoa"] to state["ditch_aoa"].
        set dap["aoa"]["base_pitch"] to 0.
        set state["ditch_last_ut"] to time:seconds.
        set state["ditch_last_vs"] to ship:verticalspeed.
        flight_log_event("contingency_water_capture","bottom_height="+ship:bounds:bottomalt+
            "|speed="+ship:airspeed+"|vs="+ship:verticalspeed+"|initial_aoa="+state["ditch_aoa"]+
            "|entry_height="+contingency_water_entry_height(ship:verticalspeed,cfg)+
            "|terrain_height="+ship:geoposition:terrainheight).
    }
    local hold_gate is cfg["ditch_commit_height"]+
        min(cfg["water_approach_sink"],max(0,-ship:verticalspeed))*cfg["sink_response_lead_seconds"].
    local holding is state["phase"] = "ocean_ditch" or ship:bounds:bottomalt <= hold_gate.
    if holding and state["phase"] <> "ocean_ditch" {
        flight_log_event("contingency_water_hold","bottom_height="+ship:bounds:bottomalt+
            "|clearance_target="+cfg["ditch_clearance"]+"|hold_gate="+hold_gate+
            "|speed="+ship:airspeed+"|vs="+ship:verticalspeed).
    }
    if holding { contingency_phase(state,"ocean_ditch"). }
    else { contingency_phase(state,"ocean_approach"). }
    if not state:haskey("ditch_last_vs") { set state["ditch_last_vs"] to ship:verticalspeed. }
    set state["water_vertical_acceleration"] to contingency_vertical_acceleration(ship:verticalspeed,
        state["ditch_last_vs"],time:seconds-state["ditch_last_ut"]).
    local command is contingency_water_command(ship:bounds:bottomalt,ship:airspeed,
        ship:verticalspeed,state["ditch_aoa"],time:seconds-state["ditch_last_ut"],
        state["nerv_power"]["usable"],holding,cfg,state["water_vertical_acceleration"]).
    set state["ditch_aoa"] to command["aoa"].
    set state["water_desired_vs"] to command["desired_vs"].
    set state["water_predicted_vs"] to command["predicted_vs"].
    set state["water_throttle"] to command["throttle"].
    set state["water_brakes"] to command["brakes"].
    set state["water_clearance_target"] to command["clearance_target"].
    set state["water_predicted_height"] to command["predicted_height"].
    set state["water_hold_gate"] to hold_gate.
    set state["water_aoa_saturated"] to command["aoa_saturated"].
    set state["water_aoa_tracking_error"] to state["ditch_aoa"]-calc_aoa().
    set state["water_entry_height"] to contingency_water_entry_height(ship:verticalspeed,cfg).
    set state["water_expected_settle_speed"] to cfg["water_expected_settle_speed"].
    set state["ditch_last_ut"] to time:seconds.
    set state["ditch_last_vs"] to ship:verticalspeed.
    set dap["dap_mode"] to "auto".
    set dap["str_mode"] to "aoa".
    set dap["aoa"]["target_aoa"] to state["ditch_aoa"].
    set dap["aoa"]["target_bank"] to 0.
    gear off.
    if command["brakes"] { brakes on. } else { brakes off. }
    if holding { nervsoff(). }
    set dapthrottle to command["throttle"].
}

function contingency_emergency_update {
    parameter state, cfg.
    local selected is state["target"].
    local clearance is ship:altitude-max(0,ship:geoposition:terrainheight).
    if ship:geoposition:terrainheight < -2 and
       ship:bounds:bottomalt <= contingency_water_entry_height(ship:verticalspeed,cfg) {
        if selected["kind"] <> "ocean" {
            contingency_degraded(state,"emergency_water_surface_detected").
            set selected["kind"] to "ocean".
            set selected["start"] to ship:geoposition.
            set selected["end"] to ship:geoposition.
            set selected["altitude"] to 0.
            set selected["distance_m"] to 0.
            set selected["heading"] to compass_for_prograde().
        }
        contingency_water_hold(state,cfg).
        return.
    }
    local turn_error is normalized_heading_error(heading_to_target(selected["start"]),compass_for_prograde()).
    local g is ship:body:mu/(ship:body:radius+ship:altitude)^2.
    local range_m is calcdistance_m(ship:geoposition,selected["start"]).
    local energy is contingency_energy(ship:altitude-selected["altitude"],ship:airspeed,g,
        range_m,turn_error,cfg,state["assist_height"]).
    set selected["margin"] to energy["margin"].
    local unpowered is contingency_energy(ship:altitude-selected["altitude"],ship:airspeed,g,range_m,turn_error,cfg).
    set selected["unpowered_margin"] to unpowered["margin"].
    local bank_cmd is max(-cfg["bank"],min(cfg["bank"],-turn_error*0.5)).
    if abs(turn_error) > 60 { set bank_cmd to 0. }
    if state["phase"] = "emergency_glide" and clearance >= cfg["minimum_search_clearance"] and
       time:seconds >= state["emergency_replan_ut"] and
       (abs(turn_error) > 60 or energy["margin"] < -100) {
        contingency_begin_emergency(state,cfg,"emergency_target_lost").
        contingency_emergency_update(state,cfg).
        return.
    }
    // Approach sampling stays active through emergency_glide. Once close to
    // either local terrain or the target, choose minimum-sink touchdown ahead.
    // A low abort can begin while still climbing off the runway. Do not
    // disable GPWS as a committed final merely because height is low.
    // Once committed, retain ownership through an upward contact bounce.
    if state["phase"] = "emergency_final" or
       (state:haskey("emergency_committed") and state["emergency_committed"]) or
       (ship:verticalspeed <= 0 and (clearance <= cfg["capture_height"] or
        ship:altitude-selected["altitude"] <= cfg["capture_height"])) {
        contingency_phase(state,"emergency_final").
        set state["emergency_committed"] to true.
        set bank_cmd to 0.
    }
    local bottom_clearance is ship:bounds:bottomalt-max(0,ship:geoposition:terrainheight).
    set state["emergency_bottom_clearance"] to bottom_clearance.
    if not state:haskey("emergency_last_vs") { set state["emergency_last_vs"] to ship:verticalspeed. }
    set state["emergency_vertical_acceleration"] to contingency_vertical_acceleration(ship:verticalspeed,
        state["emergency_last_vs"],time:seconds-state["emergency_last_ut"]).
    local command is contingency_emergency_command(bottom_clearance,ship:airspeed,
        ship:verticalspeed,state["emergency_aoa"],time:seconds-state["emergency_last_ut"],
        state["nerv_power"]["usable"],cfg,state["emergency_vertical_acceleration"]).
    set state["emergency_aoa"] to command["aoa"].
    set state["emergency_desired_vs"] to command["desired_vs"].
    set state["emergency_predicted_vs"] to command["predicted_vs"].
    set state["emergency_last_ut"] to time:seconds.
    set state["emergency_last_vs"] to ship:verticalspeed.
    set dap["dap_mode"] to "auto".
    set dap["str_mode"] to "aoa".
    set dap["aoa"]["target_aoa"] to command["aoa"].
    set dap["aoa"]["target_bank"] to bank_cmd.
    set dapthrottle to command["throttle"].
    if command["brakes"] { brakes on. } else { brakes off. }
    if ship:geoposition:terrainheight < 0 { gear off. } else if clearance < 500 { gear on. }
    set selected["distance_m"] to calcdistance_m(ship:geoposition,selected["start"]).
}

function contingency_phase {
    parameter state, next_phase.
    if state["phase"] <> next_phase {
        flight_log_event("contingency_phase","from="+state["phase"]+"|to="+next_phase).
        set state["phase"] to next_phase.
        set state["phase_entered"] to time:seconds.
    }
}

// Cache the last airborne observation before the hull first reaches the
// surface. KSP water drag can erase the impact speed before STATUS changes.
function contingency_contact_observe {
    parameter state.
    if state:haskey("contact_observed") and state["contact_observed"] { return. }
    local bottom_clearance is ship:bounds:bottomalt-max(0,ship:geoposition:terrainheight).
    if ship:status = "LANDED" or ship:status = "SPLASHED" or bottom_clearance <= 0 {
        if state:haskey("last_airborne") {
            set state["contact_observed"] to true.
            local before is state["last_airborne"].
            flight_log_event("contingency_contact","status="+ship:status+"|phase="+state["phase"]+
                "|precontact_ut="+before["ut"]+"|precontact_speed="+before["speed"]+
                "|precontact_vs="+before["vs"]+"|precontact_bottom_clearance="+before["clearance"]+
                "|precontact_aoa="+before["aoa"]+"|precontact_mass="+before["mass"]+
                "|precontact_throttle_command="+before["throttle"]+"|mass_now="+ship:mass).
        }
        return.
    }
    set state["last_airborne"] to lex("ut",time:seconds,"speed",ship:airspeed,
        "vs",ship:verticalspeed,"clearance",bottom_clearance,"aoa",calc_aoa(),
        "mass",ship:mass,"throttle",dapthrottle).
    set state["contact_observed"] to false.
}

// FTE-1 vessel mode drains its configured resources. Only LF powers the remaining
// NERVs. Keep a fixed 10% LF floor, available to engines rather than locked
// behind the old protected reserve. Never dump during orbit preservation.
function contingency_dump_decision {
    parameter lf_remaining, lf_floor, atmospheric, landing_committed.
    return atmospheric and landing_committed and lf_remaining > lf_floor.
}

function contingency_dump_update {
    parameter state, cfg.
    if not state:haskey("dump_lf_floor") {
        set state["dump_lf_floor"] to ship:liquidfuel*cfg["dump_lf_fraction"].
    }
    local enabled is contingency_dump_decision(ship:liquidfuel,state["dump_lf_floor"],
        ship:altitude < ship:body:atm:height,
        not state["orbit_eligible"] or state["orbit_abandoned"]).
    if enabled and state["lf_reserve"] > 0 {
        contingency_release_reserve(state,cfg,"landing_fuel_dump").
    }
    if enabled <> state["fuel_dump_active"] {
        flight_log_event("contingency_fuel_dump","active="+enabled+"|phase="+state["phase"]+
            "|lf="+ship:liquidfuel+"|ox="+ship:oxidizer+"|lf_floor="+state["dump_lf_floor"]+
            "|mass="+ship:mass).
        abort_set_fuel_dump(enabled).
    }
    set state["fuel_dump_active"] to enabled.
}

function contingency_finish {
    parameter state, reason, success is false, pilot is false.
    abort_set_fuel_dump(false).
    set state["fuel_dump_active"] to false.
    set dapthrottle to 0.
    set dap["envelope"]["min_throttle"] to 0.
    set state["result"] to lex("success",success,"reason",reason,"pilot_control",pilot).
    set state["active"] to false.
    contingency_phase(state,"complete").
    flight_log_event("contingency_outcome","reason="+reason+"|success="+success+
        "|pilot_control="+pilot+"|status="+ship:status+"|speed="+ship:airspeed+"|vs="+ship:verticalspeed+
        "|apoapsis="+ship:apoapsis+"|periapsis="+ship:periapsis).
    // success means the requested terminal condition was reached; impact
    // severity is carried separately instead of reporting post-impact zeros.
    if state:haskey("last_airborne") and (ship:status = "LANDED" or ship:status = "SPLASHED") {
        flight_log_event("contingency_touchdown_summary","precontact_speed="+state["last_airborne"]["speed"]+
            "|precontact_vs="+state["last_airborne"]["vs"]+"|precontact_ut="+state["last_airborne"]["ut"]+
            "|contact_observed="+state["contact_observed"]+"|mass_now="+ship:mass).
    }
    if ship:status = "LANDED" or ship:status = "SPLASHED" { nervsoff(). }
    set ship:control:pilotmainthrottle to 0.
    dap:set_off().
    unlock throttle.
    set ship:control:neutralize to true.
    if pilot { print "CONTINGENCY: PILOT CONTROL - "+reason. }
}

function contingency_corridor_capture {
    parameter distance_m, bearing_from_site, course, cfg.
    local angle is normalized_heading_error(bearing_from_site,course).
    local along_m is distance_m*cos(angle).
    local cross_m is distance_m*sin(angle).
    return along_m >= -cfg["corridor_length"]/3 and along_m <= 2*cfg["corridor_length"]/3 and
        abs(cross_m) <= cfg["corridor_half_width"].
}

// Water clearance uses the lowest vessel point, not the centre of mass.
// At maximum AoA, loss of lift is allowed to settle the aircraft onto water.
function contingency_ditch_command {
    parameter bottom_height, vertical_mps, last_aoa, dt_seconds, cfg.
    local desired_vs is max(-2,min(1,(cfg["ditch_clearance"]-bottom_height)*cfg["ditch_height_gain"])).
    local rate is max(-cfg["ditch_aoa_rate"],min(cfg["ditch_aoa_rate"],
        (desired_vs-vertical_mps)*cfg["ditch_aoa_gain"])).
    return max(0,min(cfg["ditch_max_aoa"],last_aoa+rate*max(0,min(dt_seconds,0.2)))).
}

// Fuel/thrust observations are live only; no logger or engine activation is
// called from energy or trajectory mathematics.
function contingency_nerv_power {
    parameter state, cfg.
    local total_force is 0.
    local mass_flow is 0.
    local healthy is 0.
    local vacuum_isp_s is 999999.
    for engine_part in ship:partstitledpattern("LV-N") {
        if engine_part:ignition and not engine_part:flameout and
           not engine_blocked_by_abort("nerv",engine_part) {
            local force_kn is engine_part:availablethrust.
            if force_kn > 0 and engine_part:isp > 0 {
                set healthy to healthy+1.
                set vacuum_isp_s to min(vacuum_isp_s,engine_part:vacuumisp).
                set total_force to total_force+force_kn.
                set mass_flow to mass_flow+force_kn/(engine_part:isp*constant:g0).
            }
        }
    }
    local isp_s is 0.
    if mass_flow > 0 { set isp_s to total_force/(mass_flow*constant:g0). }
    local fuel_t is max(0,ship:liquidfuel-state["lf_reserve"])*cfg["lf_tonnes_per_unit"].
    set fuel_t to min(fuel_t,ship:mass*0.9).
    local remaining_dv is 0.
    if fuel_t > 0 and isp_s > 0 {
        set remaining_dv to isp_s*constant:g0*ln(ship:mass/(ship:mass-fuel_t)).
    }
    local vacuum_dv is 0.
    if healthy > 0 and vacuum_isp_s > 0 and fuel_t > 0 {
        set vacuum_dv to vacuum_isp_s*constant:g0*ln(ship:mass/(ship:mass-fuel_t)).
    } else { set vacuum_isp_s to 0. }
    local acceleration is total_force/max(0.001,ship:mass).
    return lex("healthy",healthy,"thrust_kn",total_force,"acceleration",acceleration,
        "isp",isp_s,"vacuum_isp",vacuum_isp_s,"fuel_t",fuel_t,"dv",remaining_dv,"vacuum_dv",vacuum_dv,
        "usable",total_force > 0 and fuel_t > 0).
}

// Optimistic impulsive lower bound plus an explicit loss allowance. A pass
// permits a monitored attempt, not a promise of insertion with low TWR.
function contingency_orbit_budget {
    parameter body_mu, radius_m, altitude_m, orbit_speed_mps, radial_mps,
        target_height_m, available_dv, acceleration, cfg.
    local current_radius is radius_m+altitude_m.
    local target_r is radius_m+target_height_m.
    local required_speed is sqrt(max(0,body_mu*(2/current_radius-1/target_r))).
    local needed is max(0,required_speed-orbit_speed_mps)+cfg["orbit_dv_allowance"].
    return lex("required_dv",needed,"margin",available_dv-needed,
        "possible",available_dv >= needed and acceleration >= cfg["orbit_min_acceleration"]).
}

function contingency_orbit_pitch {
    parameter flight_path_pitch, speed_mps, altitude_m, atmosphere_top, cfg.
    local desired is cfg["orbit_raise_pitch"].
    if altitude_m < atmosphere_top {
        set desired to min(desired,flight_path_pitch+cfg["orbit_pullup_aoa"]).
        if speed_mps < cfg["landing_speed"] { set desired to min(desired,flight_path_pitch). }
    }
    return max(-10,min(cfg["orbit_raise_pitch"],desired)).
}

// Only a short, derated burn is credited in the atmospheric range screen.
// Live energy and available thrust are checked again on every guidance tick.
function contingency_assist_height {
    parameter speed_mps, gravity_mps2, acceleration, available_dv, cfg.
    local dv_credit is min(cfg["assist_max_dv_credit"],
        min(available_dv,acceleration*cfg["assist_credit_seconds"])*cfg["assist_credit_fraction"]).
    return max(0,((speed_mps+dv_credit)^2-speed_mps^2)/(2*max(0.01,gravity_mps2))).
}

function contingency_recovery_throttle {
    parameter speed_mps, energy_margin, power_usable, phase_name, cfg.
    if not power_usable or phase_name = "final" or phase_name = "ocean_ditch" or phase_name = "ground_stop" { return 0. }
    local demand is (cfg["landing_speed"]+cfg["assist_speed_reserve"]-speed_mps)/cfg["assist_speed_band"].
    if energy_margin < cfg["assist_energy_reserve"] {
        set demand to max(demand,(cfg["assist_energy_reserve"]-energy_margin)/cfg["assist_energy_band"]).
    }
    return max(0,min(1,demand)).
}

function contingency_abandon_orbit {
    parameter state, reason.
    set dapthrottle to 0.
    set state["orbit_attempted"] to true.
    set state["orbit_abandoned"] to true.
    set state["target"]["selected"] to false.
    flight_log_event("contingency_orbit_rejected","reason="+reason+
        "|apoapsis="+ship:apoapsis+"|periapsis="+ship:periapsis+
        "|dv_margin="+state["orbit_budget"]["margin"]).
    contingency_phase(state,"energy_assessment").
}

function contingency_orbit_update {
    parameter state, cfg.
    if state["orbit_abandoned"] { return false. }
    if not state["orbit_eligible"] { return false. }
    local power is state["nerv_power"].
    local radial_mps is vdot(ship:velocity:orbit,ship:up:vector).
    local safe_height is ship:body:atm:height+cfg["orbit_clearance"].
    local goal_height is max(safe_height+10000,cfg["orbit_target_altitude"]).
    if ship:periapsis >= safe_height-cfg["orbit_pe_tolerance"] and ship:orbit:eccentricity < 1 {
        contingency_finish(state,"nerv_orbit_complete",true).
        return true.
    }
    set state["orbit_budget"] to contingency_orbit_budget(ship:body:mu,ship:body:radius,
        ship:altitude,ship:velocity:orbit:mag,radial_mps,goal_height,
        power["vacuum_dv"],power["acceleration"],cfg).
    if not power["usable"] or not state["orbit_budget"]["possible"] {
        contingency_release_reserve(state,cfg,"orbit_budget").
        set power to state["nerv_power"].
        set state["orbit_budget"] to contingency_orbit_budget(ship:body:mu,ship:body:radius,
            ship:altitude,ship:velocity:orbit:mag,radial_mps,goal_height,
            power["vacuum_dv"],power["acceleration"],cfg).
    }
    if not power["usable"] or not state["orbit_budget"]["possible"] {
        contingency_abandon_orbit(state,"fuel_or_thrust_budget").
        return false.
    }
    if not state["orbit_attempted"] {
        set state["orbit_attempted"] to true.
        set state["orbit_started_ut"] to time:seconds.
        set state["orbit_progress_ut"] to time:seconds.
        set state["orbit_progress_value"] to ship:apoapsis.
        contingency_phase(state,"orbit_raise").
        flight_log_event("contingency_orbit_attempt","goal_ap="+goal_height+
            "|goal_pe="+safe_height+"|dv_available="+power["vacuum_dv"]+
            "|dv_required="+state["orbit_budget"]["required_dv"]+
            "|acceleration="+power["acceleration"]).
    }
    if time:seconds-state["orbit_started_ut"] > cfg["orbit_timeout"] or
       ship:orbit:eccentricity >= 1 or
       (radial_mps < -cfg["orbit_max_descending_speed"] and ship:altitude < safe_height) {
        contingency_abandon_orbit(state,"timeout_escape_or_descent").
        return false.
    }
    set dap["dap_mode"] to "auto".
    if state["phase"] = "orbit_raise" {
        brakes off.
        gear off.
        set dap["str_mode"] to "aerostr".
        set dap["aerostr"]["turn_heading"] to compass_for_prograde().
        set dap["aerostr"]["turn_roll"] to 0.
        set dap["aerostr"]["distance_pitch"] to 0.
        set state["orbit_pitch"] to contingency_orbit_pitch(pitch_for_prograde(),ship:airspeed,
            ship:altitude,ship:body:atm:height,cfg).
        set dap["aerostr"]["turn_pitch"] to state["orbit_pitch"].
        set dapthrottle to 1.
        if time:seconds-state["orbit_progress_ut"] >= cfg["orbit_progress_seconds"] {
            if ship:apoapsis-state["orbit_progress_value"] < cfg["orbit_min_ap_gain"] {
                contingency_abandon_orbit(state,"apoapsis_not_growing").
                return false.
            }
            set state["orbit_progress_ut"] to time:seconds.
            set state["orbit_progress_value"] to ship:apoapsis.
        }
        if ship:apoapsis >= goal_height {
            set dapthrottle to 0.
            contingency_phase(state,"orbit_coast").
        }
        return true.
    }
    local up_vec is ship:up:vector.
    local tangent is ship:velocity:orbit-up_vec*radial_mps.
    if tangent:mag < 1 {
        contingency_abandon_orbit(state,"no_orbital_tangent").
        return false.
    }
    set dap["str_mode"] to "vector".
    set dap["vector"]["targetVector"] to tangent:normalized.
    local radius_m is ship:body:radius+ship:altitude.
    local required_tangent is sqrt(max(0,ship:body:mu*(2/radius_m-
        2/(radius_m+ship:body:radius+safe_height)))).
    local circularize_dv is max(0,required_tangent-tangent:mag).
    local burn_seconds is circularize_dv/max(0.01,power["acceleration"]).
    if state["phase"] = "orbit_coast" {
        set dapthrottle to 0.
        if ship:altitude >= safe_height and
           ship:orbit:eta:apoapsis <= burn_seconds/2+cfg["orbit_burn_lead_seconds"] {
            contingency_phase(state,"orbit_insert").
            set state["orbit_progress_ut"] to time:seconds.
            set state["orbit_progress_value"] to ship:periapsis.
        } else if ship:apoapsis < goal_height-cfg["orbit_ap_rebuild_margin"] and radial_mps > 0 {
            contingency_phase(state,"orbit_raise").
            set state["orbit_progress_ut"] to time:seconds.
            set state["orbit_progress_value"] to ship:apoapsis.
        }
        return true.
    }
    if state["phase"] = "orbit_insert" {
        set dapthrottle to 0.
        local alignment is vang(ship:facing:vector,tangent).
        set state["orbit_alignment"] to alignment.
        if alignment <= cfg["orbit_alignment_deg"] {
            set dapthrottle to max(0,min(1,circularize_dv/max(0.01,power["acceleration"]*cfg["orbit_taper_seconds"]))).
        }
        if time:seconds-state["orbit_progress_ut"] >= cfg["orbit_progress_seconds"] {
            if ship:periapsis-state["orbit_progress_value"] < cfg["orbit_min_pe_gain"] {
                contingency_abandon_orbit(state,"periapsis_not_growing").
                return false.
            }
            set state["orbit_progress_ut"] to time:seconds.
            set state["orbit_progress_value"] to ship:periapsis.
        }
        return true.
    }
    return false.
}

// Aim for an upstream runway entry before committing to a low-speed glide.
// This screen is a conservative powered energy approximation, not a solved
// hypersonic entry trajectory. Live losses and loss of clearance can reject it.
function contingency_select_entry {
    parameter state, cfg.
    local best is lex("selected",false,"score",999999999).
    local search_started is time:seconds.
    local entry_cfg is lex().
    for config_key in cfg:keys { entry_cfg:add(config_key,cfg[config_key]). }
    set entry_cfg["maximum_range"] to cfg["entry_maximum_range"].
    set entry_cfg["capture_height"] to cfg["entry_capture_reserve"].
    for key_name in location_constants["kerbin"]:keys {
        if time:seconds-search_started >= cfg["maximum_search_seconds"] { return best. }
        if key_name:endswith("_start") and key_name:split("_runway_"):length > 1 {
            local parts is key_name:split("_runway_").
            local place is parts[0].
            local number is parts[1]:split("_")[0].
            local end_key is place+"_runway_"+number+"_end".
            if location_constants["kerbin"]:haskey(end_key) and KerbinRunwayalt:haskey(place+"_runway") {
                local site is location_constants["kerbin"][key_name].
                local finish is location_constants["kerbin"][end_key].
                local course is heading_between(site,finish).
                local entry_point is get_geoposition_along_heading(site,course+180,cfg["entry_runway_distance"]).
                local candidate is contingency_candidate(entry_point,site,course,
                    KerbinRunwayalt[place+"_runway"]+cfg["entry_height"],"runway_entry",entry_cfg,state["assist_height"]).
                if candidate["selected"] and candidate["score"] < best["score"] {
                    set candidate["location"] to place.
                    set candidate["runway_num"] to number.
                    set best to candidate.
                }
            }
            dap:update().
            wait 0.
        }
    }
    return best.
}

function contingency_entry_update {
    parameter state, cfg.
    if not state["entry_searched"] {
        set state["entry_searched"] to true.
        set state["entry_target"] to contingency_select_entry(state,cfg).
        if state["entry_target"]["selected"] {
            flight_log_event("contingency_runway_entry","location="+state["entry_target"]["location"]+
                "|runway="+state["entry_target"]["runway_num"]+"|range="+state["entry_target"]["distance_m"]+
                "|height="+state["entry_target"]["altitude"]+"|margin="+state["entry_target"]["margin"]).
        }
    }
    if not state["entry_target"]["selected"] { return false. }
    if time:seconds-state["started_ut"] > cfg["entry_timeout"] {
        set state["entry_target"]["selected"] to false.
        flight_log_event("contingency_entry_rejected","reason=entry_timeout").
        contingency_degraded(state,"entry_timeout").
        return false.
    }
    local target_site is state["entry_target"].
    local range_m is calcdistance_m(ship:geoposition,target_site["start"]).
    local turn_error is normalized_heading_error(heading_to_target(target_site["start"]),compass_for_prograde()).
    local g is ship:body:mu/(ship:body:radius+ship:altitude)^2.
    local budget is contingency_energy(ship:altitude-target_site["altitude"],ship:airspeed,g,
        range_m,turn_error,cfg,state["assist_height"]).
    set target_site["distance_m"] to range_m.
    set target_site["margin"] to budget["margin"].
    local unpowered is contingency_energy(ship:altitude-target_site["altitude"],ship:airspeed,g,
        range_m,turn_error,cfg).
    set target_site["unpowered_margin"] to unpowered["margin"].
    if ship:altitude < target_site["altitude"]-cfg["entry_capture_reserve"] or budget["margin"] < -100 {
        set target_site["selected"] to false.
        flight_log_event("contingency_entry_rejected","reason=lost_energy_or_height").
        return false.
    }
    contingency_phase(state,"powered_entry").
    set dap["dap_mode"] to "auto".
    set dap["str_mode"] to "aoa".
    set dap["aoa"]["target_aoa"] to 15.
    set dap["aoa"]["target_bank"] to max(-cfg["bank"],min(cfg["bank"],-turn_error*0.5)).
    set dapthrottle to contingency_recovery_throttle(ship:airspeed,unpowered["margin"],
        state["nerv_power"]["usable"],"powered_entry",cfg).
    return true.
}

function contingency_update {
    parameter state.
    if not state["active"] { return. }
    local cfg is contingency_config().
    set state["local_terrain_height"] to ship:geoposition:terrainheight.
    contingency_contact_observe(state).
    set warp to 0.
    if not state:haskey("fuel_dump_active") {
        set state["fuel_dump_active"] to false.
        abort_set_fuel_dump(false).
    }
    // Keep the previous accepted command while calculating its replacement.
    // THROTTLE is a live lock: a temporary zero here could be applied on a
    // scheduler yield even when the eventual guidance command requested power.
    rapiersoff().
    if defined recovery_engines { recovery_apply_limits(). }
    if not state:haskey("orbit_eligible") {
        local were_active is nervs.
        if state:haskey("nervs_were_active") { set were_active to state["nervs_were_active"]. }
        if state:haskey("suppress_orbit") and state["suppress_orbit"] { set were_active to false. }
        if state["scenario"]["nervs_out"] > 0 { set were_active to false. }
        set state["orbit_eligible"] to were_active.
        if not state:haskey("orbit_attempted") { set state["orbit_attempted"] to false. }
        if not state:haskey("orbit_abandoned") { set state["orbit_abandoned"] to false. }
        set state["orbit_budget"] to lex("required_dv",0,"margin",0,"possible",false).
        if not state:haskey("lf_reserve") {
            set state["lf_reserve"] to ship:liquidfuel*cfg["lf_reserve_fraction"].
        }
        set state["entry_searched"] to false.
        set state["entry_target"] to lex("selected",false).
        flight_log_event("contingency_nerv_policy","orbit_first="+were_active+
            "|activate_for_recovery="+cfg["activate_nervs_for_recovery"]+"|lf_reserve="+state["lf_reserve"]).
    }
    // A bound atmosphere-clear orbit is already a successful recovery. Cut
    // thrust and finish without deorbiting or depending on orbit eligibility.
    if ship:body:name = "Kerbin" and ship:status <> "LANDED" and ship:status <> "SPLASHED" and
       ship:altitude >= ship:body:atm:height and ship:periapsis >= ship:body:atm:height and
       ship:orbit:eccentricity < 1 and
       (not state["orbit_eligible"] or state["orbit_abandoned"] or
        ship:periapsis >= ship:body:atm:height+cfg["orbit_clearance"]-cfg["orbit_pe_tolerance"]) {
        local reason is "stable_orbit_preserved".
        if state["orbit_attempted"] and not state["orbit_abandoned"] { set reason to "nerv_orbit_complete". }
        contingency_finish(state,reason,true).
        return.
    }
    if ship:body:name = "Kerbin" and ship:status <> "LANDED" and ship:status <> "SPLASHED" and
       state["phase"] <> "ocean_ditch" and ship:liquidfuel <= state["lf_reserve"] {
        contingency_release_reserve(state,cfg,"reserve_needed_for_recovery").
    }
    // Only healthy parts may be activated; failed engine IDs remain blocked.
    if ship:status <> "LANDED" and ship:status <> "SPLASHED" and state["phase"] <> "ocean_ditch" and
       ship:liquidfuel > state["lf_reserve"] {
        if state["orbit_eligible"] or cfg["activate_nervs_for_recovery"] { nervson(). }
    }
    if ship:liquidfuel <= state["lf_reserve"] { nervsoff(). }
    set state["nerv_power"] to contingency_nerv_power(state,cfg).
    if not state:haskey("last_nerv_usable") or state["last_nerv_usable"] <> state["nerv_power"]["usable"] {
        flight_log_event("contingency_nerv_status","usable="+state["nerv_power"]["usable"]+
            "|healthy="+state["nerv_power"]["healthy"]+"|available_thrust_kn="+state["nerv_power"]["thrust_kn"]+
            "|lf="+ship:liquidfuel+"|dv="+state["nerv_power"]["dv"]).
        set state["last_nerv_usable"] to state["nerv_power"]["usable"].
    }
    local g is ship:body:mu/(ship:body:radius+ship:altitude)^2.
    set state["assist_height"] to contingency_assist_height(ship:airspeed,g,
        state["nerv_power"]["acceleration"],state["nerv_power"]["dv"],cfg).
    if not state:haskey("started_ut") { set state["started_ut"] to time:seconds. }
    if ship:status = "SPLASHED" {
        contingency_finish(state,"ocean_contact",true).
        return.
    }
    if ship:status = "LANDED" {
        set dapthrottle to 0.
        brakes on.
        gear on.
        nervsoff().
        contingency_phase(state,"ground_stop").
        set dap["dap_mode"] to "auto".
        set dap["str_mode"] to "aerostr".
        set dap["aerostr"]["turn_heading"] to compass_for_prograde().
        set dap["aerostr"]["turn_pitch"] to 0.
        set dap["aerostr"]["turn_roll"] to 0.
        set dap["aerostr"]["distance_pitch"] to 0.
        if ship:groundspeed < 1 { contingency_finish(state,"ground_stop",true). }
        else if time:seconds-state["started_ut"] > cfg["entry_timeout"] {
            contingency_degraded(state,"ground_stop_timeout").
        }
        return.
    }
    if ship:body:name <> "Kerbin" {
        contingency_finish(state,"unsupported_body",false,true).
        return.
    }
    if state["phase"] <> "ocean_approach" and state["phase"] <> "ocean_ditch" { brakes off. }
    local clearance is ship:altitude-max(0,ship:geoposition:terrainheight).
    if state["phase"] = "initialize" {
        set state["started_ut"] to time:seconds.
        contingency_phase(state,"energy_assessment").
    }
    if contingency_orbit_update(state,cfg) { return. }
    contingency_dump_update(state,cfg).
    if time:seconds-state["started_ut"] > cfg["entry_timeout"] {
        contingency_degraded(state,"recovery_timeout").
        if state["phase"] = "glide" or state["phase"] = "site_search" {
            contingency_begin_emergency(state,cfg,"recovery_timeout").
        }
    }
    if state["phase"] = "ground_stop" {
        // Retain terminal ownership through a wheel-contact bounce.
        contingency_begin_emergency(state,cfg,"ground_contact_bounce",true).
    }
    if state["phase"] = "emergency_glide" or state["phase"] = "emergency_final" {
        contingency_emergency_update(state,cfg).
        return.
    }
    if ship:altitude > cfg["maximum_glide_altitude"] or ship:airspeed > cfg["maximum_glide_speed"] {
        if contingency_entry_update(state,cfg) { return. }
        contingency_phase(state,"entry_coast").
        set dap["dap_mode"] to "auto".
        set dap["str_mode"] to "aoa".
        set dap["aoa"]["target_aoa"] to 30.
        set dap["aoa"]["target_bank"] to 0.
        // Coast preserves fuel at adequate speed; an arbitrary range deficit
        // must not command a continuous burn while waiting for the atmosphere.
        set dapthrottle to contingency_recovery_throttle(ship:airspeed,cfg["assist_energy_reserve"],
            state["nerv_power"]["usable"],"entry_coast",cfg).
        if time:seconds-state["started_ut"] > cfg["entry_timeout"] {
            contingency_degraded(state,"entry_timeout").
        }
        return.
    }
    if not state["target"]["selected"] {
        if clearance < cfg["minimum_search_clearance"] {
            contingency_begin_emergency(state,cfg,"insufficient_height_to_search").
            contingency_emergency_update(state,cfg).
            return.
        }
        // Establish a glide command before a scan that consumes live time.
        set dap["dap_mode"] to "auto".
        set dap["str_mode"] to "aerostr".
        set dap["aerostr"]["turn_heading"] to compass_for_prograde().
        set dap["aerostr"]["turn_roll"] to 0.
        set dap["aerostr"]["turn_pitch"] to -5.
        set dap["aerostr"]["distance_pitch"] to 0.
        contingency_phase(state,"site_search").
        set dapthrottle to contingency_recovery_throttle(ship:airspeed,0,state["nerv_power"]["usable"],"site_search",cfg).
        set state["target"] to contingency_select(cfg,state["assist_height"]).
        if not state["target"]["selected"] {
            contingency_begin_emergency(state,cfg,"no_reachable_verified_corridor").
            contingency_emergency_update(state,cfg).
            return.
        }
        local target_site is state["target"].
        flight_log_event("contingency_target","kind="+target_site["kind"]+
            "|location="+target_site["location"]+"|runway="+target_site["runway_num"]+
            "|lat="+target_site["start"]:lat+"|lng="+target_site["start"]:lng+
            "|heading="+target_site["heading"]+"|height="+target_site["altitude"]+
            "|range="+target_site["distance_m"]+"|energy_margin="+target_site["margin"]).
        contingency_phase(state,"glide").
    }
    local selected is state["target"].
    local height_m is ship:altitude-selected["altitude"].
    local captured is contingency_corridor_capture(calcdistance_m(selected["start"],ship:geoposition),
        heading_between(selected["start"],ship:geoposition),selected["heading"],cfg).
    // A selected water corridor under the aircraft can capture the water
    // approach before the normal 150 m final or a passed-target rescan.
    if selected["kind"] = "ocean" and ship:geoposition:terrainheight < -2 and
       (state["phase"] = "ocean_approach" or state["phase"] = "ocean_ditch" or
        (captured and ship:bounds:bottomalt <= contingency_water_entry_height(ship:verticalspeed,cfg))) {
        contingency_water_hold(state,cfg).
        if time:seconds-state["started_ut"] > cfg["entry_timeout"] { contingency_degraded(state,"ditch_timeout"). }
        return.
    }
    if state["phase"] <> "ocean_ditch" and state["phase"] <> "ocean_approach" and height_m <= cfg["capture_height"] {
        if not captured {
            contingency_begin_emergency(state,cfg,"landing_corridor_not_captured",true).
            contingency_emergency_update(state,cfg).
            return.
        }
        if ship:airspeed > cfg["maximum_final_speed"] or abs(roll_for()) > cfg["bank"] or
           ship:airspeed < AVES["Envelope"]["minimum_safe_speed"] {
            contingency_begin_emergency(state,cfg,"final_energy_or_bank_unsafe",true).
            contingency_emergency_update(state,cfg).
            return.
        }
    }
    if selected["kind"] <> "ocean" and ship:geoposition:terrainheight < -2 and
       ship:bounds:bottomalt <= contingency_water_entry_height(ship:verticalspeed,cfg) {
        contingency_begin_emergency(state,cfg,"emergency_water_surface_detected",true).
        contingency_emergency_update(state,cfg).
        return.
    }
    if selected["kind"] = "ocean" and
       (state["phase"] = "ocean_ditch" or state["phase"] = "ocean_approach" or ship:bounds:bottomalt <= cfg["ditch_commit_height"]) {
        if ship:geoposition:terrainheight >= -2 {
            contingency_begin_emergency(state,cfg,"ditch_corridor_left_water",true).
            contingency_emergency_update(state,cfg).
            return.
        }
        contingency_water_hold(state,cfg).
        if time:seconds-state["started_ut"] > cfg["entry_timeout"] {
            contingency_degraded(state,"ditch_timeout").
        }
        return.
    }
    local distance_m is calcdistance_m(ship:geoposition,selected["start"]).
    local turn_deg is normalized_heading_error(heading_to_target(selected["start"]),compass_for_prograde()).
    local energy is contingency_energy(height_m,ship:airspeed,g,distance_m,turn_deg,cfg,state["assist_height"]).
    set selected["margin"] to energy["margin"].
    local unpowered is contingency_energy(height_m,ship:airspeed,g,distance_m,turn_deg,cfg).
    set selected["unpowered_margin"] to unpowered["margin"].
    set selected["distance_m"] to distance_m.
    // Once committed close to the surface, stop chasing the touchdown point.
    if state["phase"] = "glide" and height_m > 150 and energy["margin"] < -100 {
        contingency_degraded(state,"landing_target_energy_lost").
        set selected["selected"] to false.
        contingency_phase(state,"energy_assessment").
        set dapthrottle to 0.
        return.
    }
    set dap["dap_mode"] to "auto".
    set dap["str_mode"] to "aerostr".
    set dap["aerostr"]["turn_roll"] to max(-cfg["bank"],min(cfg["bank"],-turn_deg*0.5)).
    set dap["aerostr"]["distance_pitch"] to 0.
    // Speed above Vapp raises the nose; below Vapp lowers it rather than
    // trying to stretch a glide with a stall-inducing flare.
    local pitch_cmd is max(-12,min(5,-5+(ship:airspeed-cfg["landing_speed"])*0.08)).
    set dap["aerostr"]["turn_heading"] to heading_to_target(selected["start"]).
    if state["phase"] = "final" or height_m <= 150 {
        contingency_phase(state,"final").
        set dap["aerostr"]["turn_roll"] to 0.
        set dap["aerostr"]["turn_heading"] to selected["heading"].
        if state["phase"] = "final" and abs(normalized_heading_error(selected["heading"],compass_for_prograde())) > 30 {
            contingency_begin_emergency(state,cfg,"final_alignment_unsafe",true).
            contingency_emergency_update(state,cfg).
            return.
        }
        local landing_cfg is AVES["Landing"].
        local fraction is max(0,min(1,(landing_cfg["flare_start_altitude"]-height_m)/
            max(1,landing_cfg["flare_start_altitude"]-landing_cfg["touchdown_altitude"]))).
        local desired_vs is landing_cfg["approach_vertical_speed"]+
            (landing_cfg["touchdown_vertical_speed"]-landing_cfg["approach_vertical_speed"])*fraction.
        set pitch_cmd to max(-12,min(landing_cfg["maximum_turn_pitch"],
            (desired_vs-ship:verticalspeed)*landing_cfg["pitch_gain"])).
        if ship:airspeed < AVES["Envelope"]["minimum_safe_speed"] {
            contingency_begin_emergency(state,cfg,"final_low_speed",true).
            contingency_emergency_update(state,cfg).
            return.
        }
    }
    set dapthrottle to contingency_recovery_throttle(ship:airspeed,unpowered["margin"],
        state["nerv_power"]["usable"],state["phase"],cfg).
    if ship:airspeed > cfg["landing_speed"]+30 and energy["margin"] > 250 { brakes on. }
    if selected["kind"] = "ocean" { gear off. } else if height_m < 500 { gear on. }
    set dap["aerostr"]["turn_pitch"] to pitch_cmd.
}
