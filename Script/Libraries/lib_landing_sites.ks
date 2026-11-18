global landing_sites_loaded is true.

// Landing sites for the body POS is currently flying.
// Kerbin continues to use Location_constants["kerbin"] and KerbinRunwayalt.
// Other atmospheres get surveyed strips. A coordinate alone is not a runway:
// each candidate is sampled for slope, roughness and water before it is offered.

function landing_runway_table {
    if defined landing_active_sites { return landing_active_sites. }
    if defined location_constants and location_constants:haskey("kerbin") {
        return location_constants["kerbin"].
    }
    return lexicon().
}

function landing_altitude_table {
    if defined landing_active_altitudes { return landing_active_altitudes. }
    if defined KerbinRunwayalt { return KerbinRunwayalt. }
    return lexicon().
}

function landing_runway_id {
    parameter heading_deg.
    local number is mod(round(heading_deg / 10), 36).
    if number = 0 { set number to 36. }
    if number < 10 { return "0" + number. }
    return "" + number.
}

function landing_offset_meters {
    parameter origin, north_m, east_m.
    local moved is origin.
    if north_m >= 0 {
        set moved to get_geoposition_along_heading(origin, 0, north_m).
    } else {
        set moved to get_geoposition_along_heading(origin, 180, -north_m).
    }
    if east_m >= 0 { return get_geoposition_along_heading(moved, 90, east_m). }
    return get_geoposition_along_heading(moved, 270, -east_m).
}

// One centerline. Positive slope is absolute degrees. Roughness is the largest
// deviation from the straight line between the threshold and the far end.
function landing_measure_strip {
    parameter origin, heading_deg, length_m.
    local far_end is get_geoposition_along_heading(origin, heading_deg, length_m).
    local start_h is origin:terrainheight.
    local end_h is far_end:terrainheight.
    local worst is 0.
    local min_h is min(start_h, end_h).
    local max_h is max(start_h, end_h).
    local wet is false.
    if ship:body:hasocean and min_h < 1 { set wet to true. }
    local intervals is max(16, ceiling(length_m / 200)).
    local station is 0.
    until station > intervals {
        local along is length_m * station / intervals.
        local sample is get_geoposition_along_heading(origin, heading_deg, along).
        local expected is start_h + (end_h - start_h) * (along / length_m).
        for offset_heading in list(-90, 0, 90) {
            local point is sample.
            if offset_heading <> 0 { set point to get_geoposition_along_heading(sample, heading_deg + offset_heading, 30). }
            local height is point:terrainheight.
            set min_h to min(min_h, height).
            set max_h to max(max_h, height).
            if ship:body:hasocean and height < 1 { set wet to true. }
            set worst to max(worst, abs(height - expected)).
        }
        set station to station + 1.
    }
    local slope is arctan(abs(end_h - start_h) / max(1, length_m)).
    return lex(
        "start", origin,
        "end", far_end,
        "heading", heading_deg,
        "length", length_m,
        "elevation", (min_h + max_h) / 2,
        "min_height", min_h,
        "max_height", max_h,
        "slope", slope,
        "roughness", worst,
        "wet", wet
    ).
}

function landing_strip_score {
    parameter strip.
    if strip["wet"] { return 1000000 + strip["roughness"]. }
    return strip["roughness"] + strip["slope"] * 40.
}

// Search a small patch around the seed and keep the flattest dry alignment.
function landing_survey_seed {
    parameter lat_, lng_, hint_heading, length_m.
    local seed is ship:body:geopositionlatlng(lat_, lng_).
    // Survey enough ground for the estimated rollout before scoring headings.
    local speed_estimate is min(165, landing_approach_speed(seed:terrainheight)).
    set length_m to max(length_m, 500 + speed_estimate^2 / (0.6 * body_local_gravity(seed:terrainheight))).
    local best is landing_measure_strip(seed, hint_heading, length_m).
    local best_score is landing_strip_score(best).
    local offsets is list(-800, 0, 800).
    local headings is list(hint_heading, hint_heading + 90).
    for north_m in offsets {
        for east_m in offsets {
            local origin is landing_offset_meters(seed, north_m, east_m).
            for heading_deg in headings {
                local wrapped is mod(heading_deg, 360).
                local strip is landing_measure_strip(origin, wrapped, length_m).
                local score is landing_strip_score(strip).
                if score < best_score {
                    set best to strip.
                    set best_score to score.
                }
            }
        }
    }
    // A powered pad can be shorter than a runway. Keep it when the long
    // strip is too rough to roll on but a piece of it is usable.
    if best["wet"] or best["slope"] > 2.5 or best["roughness"] > 12 {
        local pad is landing_measure_strip(best["start"], best["heading"], min(700, length_m)).
        if landing_strip_score(pad) + 1 < best_score {
            set best to pad.
        }
    }
    return best.
}

function landing_preset_seeds {
    local name is ship:body:name.
    if name = "Laythe" {
        // Forum-surveyed equatorial ground: the lagoon plain, then the
        // south coast of the isolated equatorial island. Survey still picks
        // the local alignment.
        return list(
            lex("name", "Lagoon", "lat", 5.0, "lng", -173.9, "heading", 90, "length", 2400),
            lex("name", "Island", "lat", -0.8, "lng", 110.0, "heading", 90, "length", 2200)
        ).
    }
    if name = "Duna" {
        return list(
            lex("name", "Lowlands", "lat", 0.4, "lng", -30.5, "heading", 90, "length", 2000),
            lex("name", "Plains", "lat", -28.5, "lng", 36.0, "heading", 90, "length", 2000)
        ).
    }
    local under is ship:geoposition.
    return list(
        lex("name", "Track", "lat", under:lat, "lng", under:lng, "heading", 90, "length", 2000),
        lex("name", "Equator", "lat", 0, "lng", 0, "heading", 90, "length", 2000)
    ).
}

function landing_install_strip {
    parameter site_name, strip.
    local runway_id is landing_runway_id(strip["heading"]).
    local reverse_heading is mod(strip["heading"] + 180, 360).
    local reverse_id is landing_runway_id(reverse_heading).
    local start_key is site_name + "_runway_" + runway_id + "_start".
    local end_key is site_name + "_runway_" + runway_id + "_end".
    local reverse_start is site_name + "_runway_" + reverse_id + "_start".
    local reverse_end is site_name + "_runway_" + reverse_id + "_end".
    local alt_key is site_name + "_runway".
    if not landing_active_sites:haskey(start_key) { landing_active_sites:add(start_key, strip["start"]). }
    else { set landing_active_sites[start_key] to strip["start"]. }
    if not landing_active_sites:haskey(end_key) { landing_active_sites:add(end_key, strip["end"]). }
    else { set landing_active_sites[end_key] to strip["end"]. }
    if not landing_active_sites:haskey(reverse_start) { landing_active_sites:add(reverse_start, strip["end"]). }
    else { set landing_active_sites[reverse_start] to strip["end"]. }
    if not landing_active_sites:haskey(reverse_end) { landing_active_sites:add(reverse_end, strip["start"]). }
    else { set landing_active_sites[reverse_end] to strip["start"]. }
    if not landing_active_altitudes:haskey(alt_key) { landing_active_altitudes:add(alt_key, strip["elevation"]). }
    else { set landing_active_altitudes[alt_key] to strip["elevation"]. }
    local record is lex(
        "name", site_name,
        "runway", runway_id,
        "lat", strip["start"]:lat,
        "lng", strip["start"]:lng,
        "heading", strip["heading"],
        "elevation", strip["elevation"],
        "slope", strip["slope"],
        "roughness", strip["roughness"],
        "wet", strip["wet"],
        "length", strip["length"]
    ).
    if landing_catalog:haskey(site_name) { set landing_catalog[site_name] to record. }
    else { landing_catalog:add(site_name, record). }
    return record.
}

function landing_approach_speed {
    parameter altitude_asl.
    local reference is 125.
    if defined AVES { set reference to AVES["TerminalRoute"]["ApproachSpeed"]["target_speed"]. }
    if body_is_kerbin() { return reference. }
    local pressure is 1.
    if body_has_atmosphere() { set pressure to max(0.000001, ship:body:atm:altitudepressure(altitude_asl)). }
    local gravity_ratio is body_local_gravity(altitude_asl) / 9.80665.
    return reference * sqrt(max(0.15, gravity_ratio) / pressure).
}

// Estimate the terminal rocket configuration without starting engines. Restore
// each multi-mode engine immediately after reading its closed-cycle curve.
function landing_rocket_budget {
    parameter pressure.
    local nerv is 0.
    local rocket is 0.
    local nerv_flow is 0.
    local rocket_flow is 0.
    list engines in landing_engines.
    for engine in landing_engines {
        local title is engine:title.
        if title:contains("LV-N") or title:contains("Nerv") or title:contains("Atomic") {
            set nerv to nerv + engine:possiblethrustat(pressure).
            set nerv_flow to nerv_flow + engine:maxmassflow / 0.005.
        }
        if title:contains("R.A.P.I.E.R") or title:contains("RAPIER") {
            local switched is engine:mode <> "ClosedCycle".
            if switched { engine:togglemode(). }
            set rocket to rocket + engine:possiblethrustat(pressure).
            set rocket_flow to rocket_flow + engine:maxmassflow / 0.005.
            if switched { engine:togglemode(). }
        }
    }
    return lex("nerv", nerv, "rocket", rocket, "nerv_flow", nerv_flow, "rocket_flow", rocket_flow).
}

// Upward aerodynamic force, or -1 when FAR cannot answer. A weak sample is
// unknown so a vacuum query cannot veto an otherwise plausible runway.
function landing_lift_sample {
    parameter altitude_asl, speed, aoa_, geo.
    local min_speed is 40.
    local min_lift is 1.
    if defined landing_model_estimates {
        if landing_model_estimates:haskey("sample_min_speed_mps") { set min_speed to landing_model_estimates["sample_min_speed_mps"]. }
        if landing_model_estimates:haskey("sample_min_lift_kn") { set min_lift to landing_model_estimates["sample_min_lift_kn"]. }
    }
    if not addons:far:available { return -1. }
    if speed < min_speed { return -1. }
    local site_from_body is geo:altitudeposition(altitude_asl) - ship:body:position.
    if site_from_body:mag < ship:body:radius * 0.5 { return -1. }
    local local_up is site_from_body:normalized.
    local pole is latlng(90, 0):altitudeposition(altitude_asl) - ship:body:position.
    local local_north is vxcl(local_up, pole).
    if local_north:mag < 0.01 { return -1. }
    set local_north to local_north:normalized.
    // up × north is east. north × up points west and samples the reciprocal heading.
    local east is vcrs(local_up, local_north):normalized.
    local heading_deg is 90.
    if defined runway_heading { set heading_deg to runway_heading. }
    local horizontal is (local_north * cos(heading_deg) + east * sin(heading_deg)):normalized * speed.
    local force is aeroforce_ld(site_from_body, horizontal, list(aoa_, 0)).
    // aeroforce_ld["lift"] follows the ship roof now. Use the predicted-axis
    // load along site up. Below min_lift the sample stays unknown.
    local upward is vdot(force["load"], local_up).
    if upward < min_lift { return -1. }
    return upward.
}

function landing_lowest_support_speed {
    parameter weight, thrust, pressure, geo, altitude_asl.
    local attitude is 12.
    local margin is 1.08.
    local reference_speed is 125.
    local reference_gravity is 9.80665.
    if defined landing_model_estimates {
        if landing_model_estimates:haskey("thrust_attitude_deg") { set attitude to landing_model_estimates["thrust_attitude_deg"]. }
        if landing_model_estimates:haskey("support_weight_margin") { set margin to landing_model_estimates["support_weight_margin"]. }
        if landing_model_estimates:haskey("kerbin_approach_mps") { set reference_speed to landing_model_estimates["kerbin_approach_mps"]. }
        if landing_model_estimates:haskey("kerbin_gravity") { set reference_gravity to landing_model_estimates["kerbin_gravity"]. }
    }
    local speeds is list(70, 100, 130, 160, 200, 250, 320).
    for speed in speeds {
        local lift is 0.
        local sampled is landing_lift_sample(altitude_asl, speed, attitude, geo).
        if sampled > 0 {
            set lift to sampled.
        } else {
            // Kerbin sea-level flight near the approach speed is the lift reference.
            set lift to ship:mass * reference_gravity * (speed / reference_speed) ^ 2 * pressure.
        }
        if lift + thrust >= weight * margin { return speed. }
    }
    return 999.
}

// Decide wheeled vs powered, or refuse the deorbit. Kerbin is not re-judged.
function landing_admit_site {
    if body_is_kerbin() {
        global landing_method is "wheeled".
        global landing_speed_scale is 1.
        global landing_touchdown_speed is 80.
        return lex("valid", true, "method", "wheeled", "reason", "kerbin").
    }
    if not (defined runway_start) or not (defined runway_altitude) {
        return lex("valid", false, "method", "", "reason", "no_landing_site").
    }
    local site is lexicon().
    if defined landing_catalog and defined Location and landing_catalog:haskey(Location) {
        set site to landing_catalog[Location].
    }
    if not site:haskey("length") { return lex("valid", false, "method", "", "reason", "unsurveyed_landing_site"). }
    // Fallbacks match landing_model_estimates. A flight replaces that lexicon.
    local est is lex(
        "thrust_attitude_deg", 12,
        "brake_mu", 0.4,
        "rollout_margin", 1.2,
        "propellant_margin", 1.2,
        "no_lift_seconds", 30,
        "lf_mixture_fraction", 0.45,
        "ox_mixture_fraction", 0.55,
        "lift_support_fraction", 0.75,
        "hover_thrust_fraction", 1.05,
        "hover_touchdown_mps", 70,
        "wheeled_max_slope_deg", 2.5,
        "powered_max_slope_deg", 6,
        "wheeled_max_roughness_m", 12,
        "powered_max_roughness_m", 30,
        "wheeled_max_approach_mps", 165,
        "powered_max_touchdown_mps", 155,
        "kerbin_approach_mps", 125,
        "speed_scale_cap", 1.35,
        "wet_terrain_m", 1,
        "sample_min_lift_kn", 1,
        "high_descent_agl_m", 8000,
        "mid_descent_agl_m", 3000,
        "low_descent_agl_m", 800,
        "final_descent_agl_m", 200,
        "mid_descent_vs", -18,
        "low_descent_vs", -7,
        "final_descent_vs", -6,
        "flare_descent_vs", -3,
        "rapier_align_agl_m", 1600
    ).
    if defined landing_model_estimates {
        for estimate_key in est:keys {
            if landing_model_estimates:haskey(estimate_key) { set est[estimate_key] to landing_model_estimates[estimate_key]. }
        }
    }
    local site_is_wet is false.
    if site:haskey("wet") and site["wet"] { set site_is_wet to true. }
    // Survey marks water when any sample is below 1 m on an ocean body.
    // Re-read the runway ends so a stale dry flag cannot admit the sea.
    if ship:body:hasocean {
        if runway_start:terrainheight < est["wet_terrain_m"] { set site_is_wet to true. }
        if defined runway_end and runway_end:terrainheight < est["wet_terrain_m"] { set site_is_wet to true. }
    }
    local altitude_asl is runway_altitude + 400.
    local pressure is max(0.000001, ship:body:atm:altitudepressure(altitude_asl)).
    local weight is ship:mass * body_local_gravity(altitude_asl).
    local approach is landing_approach_speed(runway_altitude).
    local engines is landing_rocket_budget(pressure).
    // Gear approach attitude, with both propulsion groups along the fuselage.
    global landing_powered_axial is engines["nerv"] + engines["rocket"].
    local attitude is est["thrust_attitude_deg"].
    local thrust is landing_powered_axial * sin(attitude).
    local gravity is body_local_gravity(runway_altitude).
    // Specific brake is mu - sin(slope). Non-positive brake does not stop the craft.
    local brake_specific is est["brake_mu"] - sin(site["slope"]).
    local brake_accel is 0.
    local aim is min(AVES["Landing"]["runway_touchdown_distance"], site["length"] * 0.3).
    local wheeled_roll_fits is false.
    if brake_specific > 0 {
        set brake_accel to gravity * brake_specific.
        set wheeled_roll_fits to aim + approach^2 / (2 * brake_accel) * est["rollout_margin"] <= site["length"].
    }
    local wheeled is not site_is_wet and site["slope"] <= est["wheeled_max_slope_deg"] and site["roughness"] <= est["wheeled_max_roughness_m"] and approach <= est["wheeled_max_approach_mps"].
    if not wheeled_roll_fits { set wheeled to false. }
    local lift_at_approach is landing_lift_sample(altitude_asl, min(est["wheeled_max_approach_mps"], approach), attitude, runway_start).
    if wheeled and lift_at_approach > est["sample_min_lift_kn"] and lift_at_approach < weight * est["lift_support_fraction"] {
        set wheeled to false.
    }
    local support_speed is landing_lowest_support_speed(weight, thrust, pressure, runway_start, altitude_asl).
    local touchdown is support_speed.
    if thrust >= weight * est["hover_thrust_fraction"] { set touchdown to est["hover_touchdown_mps"]. }
    local powered is landing_powered_axial > 0 and not site_is_wet and site["slope"] <= est["powered_max_slope_deg"] and site["roughness"] <= est["powered_max_roughness_m"] and touchdown <= est["powered_max_touchdown_mps"].

    // One clock per altitude band. 1600 m to 800 m used to sit in both the
    // 2200 m / 7 m/s term and the terminal clock, so NERV liquid fuel paid
    // it twice. Oxidizer uses only the terminal window, once.
    local align_agl is est["rapier_align_agl_m"].
    local nerv_only_seconds is (est["high_descent_agl_m"] - est["mid_descent_agl_m"]) / abs(est["mid_descent_vs"]) + (est["mid_descent_agl_m"] - align_agl) / abs(est["low_descent_vs"]).
    local terminal_seconds is (align_agl - est["low_descent_agl_m"]) / abs(est["low_descent_vs"]) + (est["low_descent_agl_m"] - est["final_descent_agl_m"]) / abs(est["final_descent_vs"]) + est["final_descent_agl_m"] / abs(est["flare_descent_vs"]).
    local descent_seconds is nerv_only_seconds + terminal_seconds.
    local lift is landing_lift_sample(altitude_asl, touchdown, attitude, runway_start).
    local axial_demand is max(0, weight - max(0,lift)) / sin(attitude).
    local nerv_fraction is min(1, axial_demand / max(1, engines["nerv"])).
    local rocket_fraction is min(1, max(0, axial_demand - engines["nerv"]) / max(1, engines["rocket"])).
    local rocket_units is engines["rocket_flow"] * (est["no_lift_seconds"] + terminal_seconds * rocket_fraction) * est["propellant_margin"].
    local lf_budget is engines["nerv_flow"] * (est["no_lift_seconds"] + descent_seconds * nerv_fraction) * est["propellant_margin"] + rocket_units * est["lf_mixture_fraction"].
    local ox_budget is rocket_units * est["ox_mixture_fraction"].
    local powered_roll_fits is false.
    if brake_specific > 0 {
        set powered_roll_fits to aim + touchdown^2 / (2 * brake_accel) * est["rollout_margin"] <= site["length"].
    }
    global landing_powered_lf is lf_budget.
    global landing_powered_ox is ox_budget.
    if not powered_roll_fits or ship:liquidfuel < lf_budget or ship:oxidizer < ox_budget { set powered to false. }
    global landing_powered_available is powered.
    global landing_touchdown_speed is touchdown.
    global landing_speed_scale is 1.
    local result is lex("valid", false, "method", "", "reason", "site_not_landable").
    if wheeled {
        global landing_method is "wheeled".
        set landing_speed_scale to max(1, min(est["speed_scale_cap"], approach / est["kerbin_approach_mps"])).
        set result to lex("valid", true, "method", "wheeled", "reason", "wheeled",
            "approach", approach, "touchdown", touchdown, "thrust", thrust, "weight", weight).
    } else if powered {
        global landing_method is "powered".
        set result to lex("valid", true, "method", "powered", "reason", "powered",
            "approach", approach, "touchdown", touchdown, "thrust", thrust, "weight", weight).
    } else {
        local why is "site_not_landable".
        if site_is_wet { set why to "landing_site_is_water". }
        else if site["slope"] > est["powered_max_slope_deg"] or site["roughness"] > est["powered_max_roughness_m"] { set why to "landing_terrain_too_rough". }
        else if ship:oxidizer < ox_budget or ship:liquidfuel < lf_budget {
            set why to "insufficient_powered_landing_propellant".
        } else if touchdown <= est["powered_max_touchdown_mps"] and not powered_roll_fits {
            set why to "insufficient_surveyed_rollout_distance".
        } else if touchdown > est["powered_max_touchdown_mps"] {
            set why to "cannot_slow_to_gear_limit".
        }
        global landing_method is "".
        set result to lex("valid", false, "method", "", "reason", why,
            "approach", approach, "touchdown", touchdown, "thrust", thrust, "weight", weight,
            "slope", site["slope"], "roughness", site["roughness"]).
    }
    local log_key is ship:body:name.
    if defined Location { set log_key to log_key + "|" + Location. }
    local log_estimates is defined flight_log_event.
    if log_estimates and defined landing_model_logged and landing_model_logged = log_key { set log_estimates to false. }
    if log_estimates {
        if defined landing_model_logged { set landing_model_logged to log_key. }
        else { global landing_model_logged is log_key. }
        local wet_bit is 0.
        if site_is_wet { set wet_bit to 1. }
        local detail is "body=" + ship:body:name + "|method=" + landing_method + "|reason=" + result["reason"] + "|wet=" + wet_bit.
        set detail to detail + "|brake_specific=" + brake_specific + "|brake_accel=" + brake_accel.
        set detail to detail + "|nerv_only_s=" + nerv_only_seconds + "|terminal_s=" + terminal_seconds + "|descent_s=" + descent_seconds.
        set detail to detail + "|lf_budget=" + lf_budget + "|ox_budget=" + ox_budget + "|rocket_units=" + rocket_units.
        set detail to detail + "|approach=" + approach + "|touchdown=" + touchdown + "|thrust=" + thrust + "|weight=" + weight.
        local logged is est.
        if defined landing_model_estimates { set logged to landing_model_estimates. }
        for logged_key in logged:keys {
            set detail to detail + "|" + logged_key + "=" + logged[logged_key].
        }
        if defined deorbit_config { deorbit_config(). }
        if defined deorbit_body_estimates {
            for deorbit_key in deorbit_body_estimates:keys {
                set detail to detail + "|deorbit_" + deorbit_key + "=" + deorbit_body_estimates[deorbit_key].
            }
        }
        flight_log_event("landing_model_estimates", detail).
    }
    return result.
}

function landing_can_fly_now {
    if not body_has_atmosphere() { return false. }
    local weight is ship:mass * body_local_gravity(ship:altitude).
    if not addons:far:available { return ship:dynamicpressure > 0 and ship:airspeed > 80. }
    local lift is cur_aeroforce_ld()["lift"].
    local local_up is (-ship:body:position):normalized.
    set lift to lift * max(0, vdot(ship:facing:topvector, local_up)).
    local limit is 175.
    if defined AVES { set limit to AVES["TerminalRoute"]["LandingGate"]["maximum_speed"]. }
    return lift > weight * 0.85 and ship:groundspeed <= limit.
}

function landing_can_thrust_now {
    return defined landing_powered_available and landing_powered_available and
        ship:liquidfuel >= landing_powered_lf and ship:oxidizer >= landing_powered_ox.
}

function landing_prepare_body {
    if body_is_kerbin() {
        global landing_active_sites is location_constants["kerbin"].
        global landing_active_altitudes is KerbinRunwayalt.
        global landing_catalog is lexicon().
        global landing_method is "wheeled".
        global landing_speed_scale is 1.
        global landing_touchdown_speed is 80.
        return.
    }
    global landing_active_sites is lexicon().
    global landing_active_altitudes is lexicon().
    global landing_catalog is lexicon().
    global landing_method is "".
    global landing_speed_scale is 1.
    global landing_touchdown_speed is 80.
    print "Surveying " + ship:body:name + " landing sites.".
    local best_name is "".
    local best_score is 1e12.
    for seed in landing_preset_seeds() {
        print "  " + seed["name"] + " " + round(seed["lat"], 2) + ", " + round(seed["lng"], 2).
        local strip is landing_survey_seed(seed["lat"], seed["lng"], seed["heading"], seed["length"]).
        local record is landing_install_strip(seed["name"], strip).
        local score is strip["roughness"] + strip["slope"] * 40.
        if strip["wet"] { set score to score + 1000000. }
        print "    elev " + round(record["elevation"]) + " m, slope " + round(record["slope"], 1) +
            " deg, rough " + round(record["roughness"]) + " m, hdg " + round(record["heading"]).
        if score < best_score {
            set best_score to score.
            set best_name to seed["name"].
        }
    }
    if best_name <> "" and landing_catalog:haskey(best_name) {
        global landing_preferred_site is best_name.
    }
}

// Rebuild one site from the coordinate fields and make it the active target.
function landing_commit_coordinates {
    parameter lat_, lng_, heading_deg.
    if lat_ < -90 or lat_ > 90 or lng_ < -180 or lng_ > 180 {
        return lex("ok", false, "location", "", "runway", "", "reason", "coordinates_out_of_range").
    }
    print "Surveying custom site " + round(lat_, 3) + ", " + round(lng_, 3) + " hdg " + round(heading_deg).
    local strip is landing_survey_seed(lat_, lng_, heading_deg, 2000).
    local record is landing_install_strip("Custom", strip).
    print "  elev " + round(record["elevation"]) + " m, slope " + round(record["slope"], 1) +
        " deg, rough " + round(record["roughness"]) + " m.".
    return lex("ok", true, "location", "Custom", "runway", record["runway"], "reason", "surveyed").
}
