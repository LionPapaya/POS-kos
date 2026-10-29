// Analytic impulsive two-body planner. No nodes, controls, trajectory simulator,
// or logger calls: caller owns review, finite-burn admission and event logging.
// target_site is a GeoCoordinates on the current body. Distances are metres.
// available_dv is a caller-supplied usable-fuel budget (after reserves); the
// default is only a planning ceiling. Executor must independently admit fuel.
function deorbit_config {
    // Historical entry summaries place common ~2.1 km/s entries at 60 km
    // about 720-965 km from the runway, descending ~4-6 degrees. These include
    // incomplete flights: a useful planning corridor, not a certified envelope.
    // High-energy range scaling is deliberately a heuristic; live entry
    // guidance owns bank control and verifies the actual post-burn state.
    return lex("interface_altitude",60000,
        "min_range",650000,"max_range",1600000,
        "preferred_range",850000,"max_crossrange",120000,"max_dv",900,
        "lf_reserve_units",200,
        "available_dv",900,"lead_time",120,"orbits",6,"max_wait",86400,
        "samples_per_orbit",180,"max_entry_time",18000,
        "min_entry_angle",-18,"max_entry_angle",-0.1).
}
function deorbit_usable_dv {
    parameter craft_mass, lf_units, engine_isp, cfg.
    local reserve_mass is max(cfg["lf_reserve_units"]*0.005,lf_units*0.005*0.20).
    local usable_mass is max(0,lf_units*0.005-reserve_mass).
    if usable_mass <= 0 or craft_mass <= usable_mass or engine_isp <= 0 { return 0. }
    return min(cfg["max_dv"],engine_isp*constant:g0*ln(craft_mass/(craft_mass-usable_mass))).
}
function deorbit_empty {
    parameter why.
    return lex("valid",false,"reason",why,"node_ut",0,"prograde",0,
        "radial",0,"normal",0,"entry_ut",0,"range_m",0,"crossrange_m",0,
        "entry_speed",0,"entry_angle",0,"delta_v",0).
}
// Deeper low-orbit entries reproduce the historical starting corridor;
// raise periapsis with departure height to avoid a steep high-energy entry.
function deorbit_periapsis_for_height {
    parameter height_m.
    if height_m < 200000 { return -10000+20000*max(0,(height_m-80000)/120000). }
    return min(30000,10000+20000*(height_m-200000)/800000).
}
// Pure math; vectors share an inertial frame, times are seconds, angles degrees.
function deorbit_arc {
    parameter body_mu, burn_r, burn_v, peri_radius, interface_radius.
    local answer is deorbit_empty("no_inbound_interface").
    local burn_radius is burn_r:mag.
    if peri_radius <= 0 or interface_radius <= peri_radius or burn_radius <= interface_radius { return answer. }
    local radial_unit is burn_r:normalized.
    local radial_speed is vdot(burn_v,radial_unit).
    local tangent_squared is burn_v:sqrmagnitude-radial_speed^2.
    local denominator is tangent_squared*burn_radius^2/peri_radius^2-burn_v:sqrmagnitude.
    if denominator <= 0 { return answer. }
    local scale_squared is 2*body_mu*(1/peri_radius-1/burn_radius)/denominator.
    if scale_squared <= 0 or scale_squared >= 1 { return answer. }
    local after_v is burn_v*sqrt(scale_squared).
    local momentum is vcrs(burn_r,after_v).
    local eccentric_vector is vcrs(after_v,momentum)/body_mu-radial_unit.
    local eccentricity is eccentric_vector:mag.
    local semimajor is 1/(2/burn_radius-after_v:sqrmagnitude/body_mu).
    if semimajor <= 0 or eccentricity <= 0.000001 or eccentricity >= 1 { return answer. }
    local peri_unit is eccentric_vector:normalized.
    local orbit_normal is momentum:normalized.
    local transverse_unit is vcrs(orbit_normal,peri_unit).
    local parameter_m is momentum:sqrmagnitude/body_mu.
    local interface_cos is (parameter_m/interface_radius-1)/eccentricity.
    if abs(interface_cos) >= 1 { return answer. }
    local entry_anomaly is 360-arctan2(sqrt(1-interface_cos^2),interface_cos).
    local burn_anomaly is arctan2(vdot(radial_unit,transverse_unit),vdot(radial_unit,peri_unit)).
    local burn_eccentric is arctan2(sqrt(1-eccentricity^2)*sin(burn_anomaly),eccentricity+cos(burn_anomaly)).
    local entry_eccentric is arctan2(sqrt(1-eccentricity^2)*sin(entry_anomaly),eccentricity+cos(entry_anomaly)).
    local burn_mean is burn_eccentric*constant:degtorad-eccentricity*sin(burn_eccentric).
    local entry_mean is entry_eccentric*constant:degtorad-eccentricity*sin(entry_eccentric).
    local mean_delta is mod(entry_mean-burn_mean+2*constant:pi,2*constant:pi).
    local coast_time is mean_delta*sqrt(semimajor^3/body_mu).
    local entry_r is (peri_unit*cos(entry_anomaly)+transverse_unit*sin(entry_anomaly))*interface_radius.
    local entry_v is (peri_unit*(-sin(entry_anomaly))+transverse_unit*(eccentricity+cos(entry_anomaly)))*sqrt(body_mu/parameter_m).
    set answer["valid"] to true.
    set answer["reason"] to "analytic_arc".
    set answer["delta_v"] to burn_v:mag-after_v:mag.
    set answer["prograde"] to -answer["delta_v"].
    set answer["entry_r"] to entry_r.
    set answer["entry_v"] to entry_v.
    set answer["orbit_normal"] to orbit_normal.
    set answer["coast_time"] to coast_time.
    set answer["entry_speed"] to entry_v:mag.
    set answer["entry_angle"] to arcsin(vdot(entry_v,entry_r:normalized)/entry_v:mag).
    return answer.
}
function deorbit_rotate {
    parameter ground_r, spin_axis, rotation_degrees.
    return ground_r*cos(rotation_degrees)+vcrs(spin_axis,ground_r)*sin(rotation_degrees)+
        spin_axis*vdot(spin_axis,ground_r)*(1-cos(rotation_degrees)).
}
function deorbit_reason_rank {
    parameter why.
    if why = "target_outside_orbital_plane" { return 5. }
    if why = "dv_or_fuel_limit" { return 4. }
    if why = "entry_speed_limit" or why = "entry_energy_or_time_limit" { return 3. }
    if why = "outside_entry_envelope" { return 2. }
    if why = "no_inbound_interface" { return 1. }
    return 0.
}
function deorbit_score {
    parameter arc, target_r, body_radius, cfg.
    if not arc["valid"] { return arc. }
    set arc["crossrange_m"] to arcsin(max(-1,min(1,vdot(target_r:normalized,arc["orbit_normal"]))))*constant:degtorad*body_radius.
    local projected_target is target_r-arc["orbit_normal"]*vdot(target_r,arc["orbit_normal"]).
    if projected_target:mag < 1 {
        set arc["valid"] to false. set arc["reason"] to "target_outside_orbital_plane". return arc.
    }
    local entry_unit is arc["entry_r"]:normalized.
    set arc["range_m"] to arctan2(vdot(vcrs(entry_unit,projected_target:normalized),arc["orbit_normal"]),vdot(entry_unit,projected_target:normalized))*constant:degtorad*body_radius.
    if abs(arc["crossrange_m"]) > cfg["max_crossrange"] { set arc["valid"] to false. set arc["reason"] to "target_outside_orbital_plane". }
    if arc["range_m"] < cfg["min_range"] or arc["range_m"] > cfg["max_range"] { set arc["valid"] to false. set arc["reason"] to "outside_entry_envelope". }
    if arc["delta_v"] > min(cfg["max_dv"],cfg["available_dv"]) { set arc["valid"] to false. set arc["reason"] to "dv_or_fuel_limit". }
    if arc["coast_time"] > cfg["max_entry_time"] or arc["entry_angle"] < cfg["min_entry_angle"] or arc["entry_angle"] > cfg["max_entry_angle"] { set arc["valid"] to false. set arc["reason"] to "entry_energy_or_time_limit". }
    return arc.
}
function deorbit_begin {
    parameter target_site, cfg is deorbit_config().
    local now_ut is time:seconds.
    local spin_axis is ship:body:angularvel:normalized.
    local period_seconds is ship:orbit:period.
    local horizon is min(cfg["max_wait"],period_seconds*cfg["orbits"]).
    local result is deorbit_empty("no_entry_pass_in_search_window").
    local done_now is not ship:body:atm:exists or ship:periapsis < ship:body:atm:height or period_seconds <= 0.
    if done_now { set result["reason"] to "requires_bound_orbit_above_atmosphere". }
    return lex("done",done_now,"result",result,"cfg",cfg,"epoch",now_ut,
        "next_ut",now_ut+cfg["lead_time"],"end_ut",now_ut+horizon,
        "step_seconds",max(1,period_seconds/max(12,cfg["samples_per_orbit"])),
        "target_r",target_site:position-ship:body:position,"spin_axis",spin_axis,
        "spin_rate",ship:body:angularvel:mag,"best_cost",1e30,
        "sample_count",0,"feasible_count",0,"last_rejection","").
}
// One candidate per call. Caller must yield between calls at standard IPU.
function deorbit_step {
    parameter scan_state.
    if scan_state["done"] { return scan_state. }
    local cfg is scan_state["cfg"].
    set scan_state["sample_count"] to scan_state["sample_count"]+1.
    local burn_ut is scan_state["next_ut"].
    local burn_r is positionat(ship,burn_ut)-ship:body:position.
    local planned_pe is deorbit_periapsis_for_height(burn_r:mag-ship:body:radius).
    local arc is deorbit_arc(ship:body:mu,burn_r,
        velocityat(ship,burn_ut):orbit,ship:body:radius+planned_pe,ship:body:radius+cfg["interface_altitude"]).
    if arc["valid"] {
        set arc["planned_periapsis"] to planned_pe.
        set arc["node_ut"] to burn_ut.
        set arc["entry_ut"] to burn_ut+arc["coast_time"].
        local target_at_entry is deorbit_rotate(scan_state["target_r"],scan_state["spin_axis"],
            scan_state["spin_rate"]*(arc["entry_ut"]-scan_state["epoch"])*constant:radtodeg).
        set arc to deorbit_score(arc,target_at_entry,ship:body:radius,cfg).
        if not arc["valid"] { set scan_state["last_rejection"] to arc["reason"]. }
        else { set scan_state["feasible_count"] to scan_state["feasible_count"]+1. }
        // Account for rotating air and increased energy without an aero solve.
        local surface_entry_v is arc["entry_v"]-vcrs(ship:body:angularvel,arc["entry_r"]).
        local preferred is min(1400000,max(750000,cfg["preferred_range"]*(surface_entry_v:mag/2100)^2)).
        local candidate_cost is abs(arc["range_m"]-preferred)+abs(arc["crossrange_m"])*2+arc["delta_v"]*100+(burn_ut-scan_state["epoch"])*5.
        if arc["valid"] and candidate_cost < scan_state["best_cost"] {
            set scan_state["best_cost"] to candidate_cost.
            set scan_state["result"] to arc.
        }
    }
    if not arc["valid"] {
        set scan_state["last_rejection"] to arc["reason"].
        if not scan_state["result"]["valid"] and
           deorbit_reason_rank(arc["reason"]) > deorbit_reason_rank(scan_state["result"]["reason"]) {
            set scan_state["result"]["reason"] to arc["reason"].
        }
    }
    set scan_state["next_ut"] to burn_ut+scan_state["step_seconds"].
    if scan_state["next_ut"] > scan_state["end_ut"] { set scan_state["done"] to true. }
    return scan_state.
}
function deorbit_plan {
    parameter target_site.
    local scan_state is deorbit_begin(target_site).
    until scan_state["done"] { set scan_state to deorbit_step(scan_state). wait 0. }
    return scan_state["result"].
}
