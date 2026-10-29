// Analytic impulsive two-body planner. No nodes, controls, trajectory simulator,
// or logger calls: caller owns review, finite-burn admission and event logging.
// target_site is a GeoCoordinates on the current body. Distances are metres.
// available_dv is a caller-supplied usable-fuel budget (after reserves); the
// default is only a planning ceiling. Executor must independently admit fuel.
function deorbit_config {
    // Flight 210 records an entry reference about 0.94 Mm from Nye Island at
    // 2.14 km/s. That single entry sample is not a complete deorbit calibration,
    // so these broad bounds are a planning gate, not a landing promise. The
    // live entry guidance still checks reachability after the actual burn.
    return lex("periapsis",30000,"periapsis_min",10000,"periapsis_max",40000,
        "periapsis_step",10000,"min_range",150000,"max_range",2200000,
        "preferred_range",950000,"max_crossrange",120000,"max_dv",900,
        "available_dv",900,"lead_time",120,"orbits",3,"max_wait",86400,
        "samples_per_orbit",120,"max_entry_time",18000,
        "min_entry_speed",1200,"max_entry_speed",3500,
        "min_entry_angle",-20,"max_entry_angle",-0.1).
}
function deorbit_empty {
    parameter why.
    return lex("valid",false,"reason",why,"node_ut",0,"prograde",0,
        "radial",0,"normal",0,"entry_ut",0,"range_m",0,"crossrange_m",0,
        "entry_speed",0,"entry_angle",0,"delta_v",0,"periapsis_m",0).
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
function deorbit_score {
    parameter arc, target_r, body_radius, cfg.
    if not arc["valid"] { return arc. }
    set arc["crossrange_m"] to arcsin(max(-1,min(1,vdot(target_r:normalized,arc["orbit_normal"]))))*constant:degtorad*body_radius.
    local projected_target is target_r-arc["orbit_normal"]*vdot(target_r,arc["orbit_normal"]).
    local entry_unit is arc["entry_r"]:normalized.
    set arc["range_m"] to arctan2(vdot(vcrs(entry_unit,projected_target:normalized),arc["orbit_normal"]),vdot(entry_unit,projected_target:normalized))*constant:degtorad*body_radius.
    local rejection_reason is "".
    if abs(arc["crossrange_m"]) > cfg["max_crossrange"] { set rejection_reason to "target_outside_orbital_plane". }
    if (arc["range_m"] < cfg["min_range"] or arc["range_m"] > cfg["max_range"]) and
       deorbit_reason_rank("outside_entry_envelope") > deorbit_reason_rank(rejection_reason) {
        set rejection_reason to "outside_entry_envelope".
    }
    if arc["delta_v"] > min(cfg["max_dv"],cfg["available_dv"]) and
       deorbit_reason_rank("dv_or_fuel_limit") > deorbit_reason_rank(rejection_reason) {
        set rejection_reason to "dv_or_fuel_limit".
    }
    if (arc["entry_speed"] < cfg["min_entry_speed"] or arc["entry_speed"] > cfg["max_entry_speed"]) and
       deorbit_reason_rank("entry_speed_limit") > deorbit_reason_rank(rejection_reason) {
        set rejection_reason to "entry_speed_limit".
    }
    if (arc["coast_time"] > cfg["max_entry_time"] or arc["entry_angle"] < cfg["min_entry_angle"] or
       arc["entry_angle"] > cfg["max_entry_angle"]) and
       deorbit_reason_rank("entry_energy_or_time_limit") > deorbit_reason_rank(rejection_reason) {
        set rejection_reason to "entry_energy_or_time_limit".
    }
    if rejection_reason <> "" { set arc["valid"] to false. set arc["reason"] to rejection_reason. }
    return arc.
}
function deorbit_begin {
    parameter target_site, cfg is deorbit_config().
    local now_ut is time:seconds.
    local equator is latlng(0,0).
    local equator_r is equator:position-ship:body:position.
    local spin_axis is vcrs(equator_r,equator:velocity:orbit):normalized.
    local period_seconds is ship:orbit:period.
    local horizon is min(cfg["max_wait"],period_seconds*cfg["orbits"]).
    local result is deorbit_empty("no_candidate").
    local done_now is not ship:body:atm:exists or ship:periapsis < ship:body:atm:height or period_seconds <= 0.
    if done_now { set result["reason"] to "requires_bound_orbit_above_atmosphere". }
    return lex("done",done_now,"result",result,"cfg",cfg,"epoch",now_ut,
        "next_ut",now_ut+cfg["lead_time"],"end_ut",now_ut+horizon,
        "step_seconds",max(1,period_seconds/max(12,cfg["samples_per_orbit"])),
        "target_r",target_site:position-ship:body:position,"spin_axis",spin_axis,
        "spin_rate",ship:body:angularvel:mag,"best_cost",1e30,
        "candidate_count",0,"periapsis_index",0,"rejection_rank",0).
}
// One candidate per call. Caller must yield between calls at standard IPU.
function deorbit_step {
    parameter scan_state.
    if scan_state["done"] { return scan_state. }
    local cfg is scan_state["cfg"].
    local burn_ut is scan_state["next_ut"].
    local periapsis_m is cfg["periapsis"].
    local periapsis_index is 0.
    local periapsis_count is 1.
    if scan_state:haskey("periapsis_index") and cfg:haskey("periapsis_min") and
       cfg:haskey("periapsis_max") and cfg:haskey("periapsis_step") {
        set periapsis_index to scan_state["periapsis_index"].
        set periapsis_count to round((cfg["periapsis_max"]-cfg["periapsis_min"])/cfg["periapsis_step"])+1.
        set periapsis_m to cfg["periapsis_min"]+periapsis_index*cfg["periapsis_step"].
    }
    local arc is deorbit_arc(ship:body:mu,positionat(ship,burn_ut)-ship:body:position,
        velocityat(ship,burn_ut):orbit,ship:body:radius+periapsis_m,ship:body:radius+ship:body:atm:height).
    set scan_state["candidate_count"] to scan_state["candidate_count"]+1.
    if arc["valid"] {
        set arc["node_ut"] to burn_ut.
        set arc["entry_ut"] to burn_ut+arc["coast_time"].
        set arc["periapsis_m"] to periapsis_m.
        local target_at_entry is deorbit_rotate(scan_state["target_r"],scan_state["spin_axis"],
            scan_state["spin_rate"]*(arc["entry_ut"]-scan_state["epoch"])*constant:radtodeg).
        set arc to deorbit_score(arc,target_at_entry,ship:body:radius,cfg).
        if not arc["valid"] and not scan_state["result"]["valid"] { set scan_state["result"] to arc. }
        local candidate_cost is abs(arc["range_m"]-cfg["preferred_range"])+abs(arc["crossrange_m"])*2+arc["delta_v"]*100.
        if arc["valid"] and candidate_cost < scan_state["best_cost"] {
            set scan_state["best_cost"] to candidate_cost.
            set scan_state["result"] to arc.
        }
        if not arc["valid"] and deorbit_reason_rank(arc["reason"]) > scan_state["rejection_rank"] {
            set scan_state["rejection_rank"] to deorbit_reason_rank(arc["reason"]).
            if not scan_state["result"]["valid"] { set scan_state["result"]["reason"] to arc["reason"]. }
        }
    } else if deorbit_reason_rank(arc["reason"]) > scan_state["rejection_rank"] {
        set scan_state["rejection_rank"] to deorbit_reason_rank(arc["reason"]).
        if not scan_state["result"]["valid"] { set scan_state["result"]["reason"] to arc["reason"]. }
    }
    if periapsis_count > 1 and periapsis_index+1 < periapsis_count {
        set scan_state["periapsis_index"] to periapsis_index+1.
    } else {
        set scan_state["periapsis_index"] to 0.
        set scan_state["next_ut"] to burn_ut+scan_state["step_seconds"].
    }
    if scan_state["next_ut"] > scan_state["end_ut"] { set scan_state["done"] to true. }
    if scan_state["done"] and not scan_state["result"]["valid"] and
       scan_state["result"]["reason"] = "no_candidate" {
        set scan_state["result"]["reason"] to "no_entry_window".
    }
    return scan_state.
}
function deorbit_plan {
    parameter target_site.
    parameter cfg is deorbit_config().
    local scan_state is deorbit_begin(target_site,cfg).
    until scan_state["done"] { set scan_state to deorbit_step(scan_state). wait 0. }
    set scan_state["result"]["candidate_count"] to scan_state["candidate_count"].
    return scan_state["result"].
}
