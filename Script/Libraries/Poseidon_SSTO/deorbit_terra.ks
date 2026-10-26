// Bounded, impulsive two-body deorbit search. The entry corridor is an
// empirical initial guess, not a prediction of atmospheric flight. The
// 60 km evidence is mostly 2.1 km/s and 720-990 km from TEAM; faster entries
// and crossrange are not calibrated. No logger or live reads in the math.
function terra_deorbit_orbit {
    parameter radius_vector, velocity_vector, mu_value.
    local radius_mag is radius_vector:mag.
    local angular_momentum is vcrs(radius_vector,velocity_vector).
    local energy is velocity_vector:mag^2/2-mu_value/radius_mag.
    if energy >= 0 or angular_momentum:mag < 1 { return lex("valid",false). }
    local eccentricity_vector is vcrs(velocity_vector,angular_momentum)/mu_value-radius_vector:normalized.
    local eccentricity is eccentricity_vector:mag.
    if eccentricity >= 1 { return lex("valid",false). }
    local semi_major is -mu_value/(2*energy).
    return lex("valid",true,"ecc",eccentricity,"axis",semi_major,
        "peri",semi_major*(1-eccentricity),"h",angular_momentum,
        "eccvec",eccentricity_vector).
}

function terra_deorbit_crossing {
    parameter radius_vector, velocity_vector, mu_value, crossing_radius.
    local conic is terra_deorbit_orbit(radius_vector,velocity_vector,mu_value).
    if not conic["valid"] { return lex("valid",false). }
    local eccentricity is conic["ecc"].
    local semi_major is conic["axis"].
    if eccentricity < 0.000001 { return lex("valid",false). }
    local p is semi_major*(1-eccentricity^2).
    local cos_crossing is (p/crossing_radius-1)/eccentricity.
    if cos_crossing < -1 or cos_crossing > 1 or radius_vector:mag <= crossing_radius { return lex("valid",false). }
    local ehat is conic["eccvec"]:normalized.
    local nhat is conic["h"]:normalized.
    local qhat is vcrs(nhat,ehat).
    local current_nu is arctan2(vdot(radius_vector,qhat),vdot(radius_vector,ehat)).
    local crossing_nu is 360-arccos(cos_crossing).
    local current_e is arctan2(sqrt(1-eccentricity^2)*sin(current_nu),eccentricity+cos(current_nu)).
    local crossing_e is arctan2(sqrt(1-eccentricity^2)*sin(crossing_nu),eccentricity+cos(crossing_nu)).
    local current_mean is current_e*constant:degtorad-eccentricity*sin(current_e).
    local crossing_mean is crossing_e*constant:degtorad-eccentricity*sin(crossing_e).
    local delta_mean is mod(crossing_mean-current_mean+2*constant:pi,2*constant:pi).
    local coast is delta_mean*sqrt(semi_major^3/mu_value).
    local direction is ehat*cos(crossing_nu)+qhat*sin(crossing_nu).
    return lex("valid",true,"coast",coast,"direction",direction,"normal",nhat,
        "speed",sqrt(mu_value*(2/crossing_radius-1/semi_major)),"peri",conic["peri"]).
}

function terra_deorbit_candidate {
    parameter radius_vector, velocity_vector, mu_value, planet_radius, crossing_radius,
        peri_radius, target_vector, spin_axis, spin_rate, burn_delay, entry_duration.
    local speed is velocity_vector:mag.
    if speed < 1 { return lex("valid",false). }
    local lo is 0.
    local hi is speed*0.8.
    local initial is terra_deorbit_orbit(radius_vector,velocity_vector,mu_value).
    local deep is terra_deorbit_orbit(radius_vector,velocity_vector-velocity_vector:normalized*hi,mu_value).
    if not initial["valid"] or initial["peri"] <= peri_radius or not deep["valid"] or deep["peri"] > peri_radius { return lex("valid",false). }
    local i is 0.
    until i >= 26 {
        local trial is (lo+hi)/2.
        local trial_orbit is terra_deorbit_orbit(radius_vector,velocity_vector-velocity_vector:normalized*trial,mu_value).
        if not trial_orbit["valid"] { return lex("valid",false). }
        if trial_orbit["peri"] > peri_radius { set lo to trial. } else { set hi to trial. }
        set i to i+1.
    }
    local dv is (lo+hi)/2.
    local crossing is terra_deorbit_crossing(radius_vector,velocity_vector-velocity_vector:normalized*dv,mu_value,crossing_radius).
    if not crossing["valid"] { return lex("valid",false). }
    local angle is (burn_delay+crossing["coast"]+entry_duration)*spin_rate*constant:radtodeg.
    local unit_target is target_vector:normalized.
    local rotated_target is unit_target*cos(angle)+vcrs(spin_axis,unit_target)*sin(angle)+spin_axis*vdot(spin_axis,unit_target)*(1-cos(angle)).
    local entry_dir is crossing["direction"].
    local plane_normal is crossing["normal"].
    local tangent is vcrs(plane_normal,entry_dir).
    local along is arctan2(vdot(rotated_target,tangent),vdot(rotated_target,entry_dir))*constant:degtorad*planet_radius.
    local crossrange is arcsin(max(-1,min(1,vdot(rotated_target,plane_normal))))*constant:degtorad*planet_radius.
    // The observed 60 km starts cluster near 900 km. Scale modestly with
    // energy; this extrapolation must be validated against KSP flight logs.
    local desired_range is 900000*max(0.8,min(1.25,crossing["speed"]/2200)).
    return lex("valid",true,"dv",dv,"coast",crossing["coast"],"entry_speed",crossing["speed"],
        "along",along,"crossrange",crossrange,"desired",desired_range,
        "score",abs(along-desired_range)+2*abs(crossrange)).
}

function terra_deorbit_in_envelope {
    parameter candidate.
    return candidate["valid"] and abs(candidate["crossrange"]) <= 100000 and
        abs(candidate["along"]-candidate["desired"]) <= 150000.
}

function terra_deorbit_better {
    parameter candidate, incumbent.
    if not candidate["valid"] { return false. }
    if not incumbent["valid"] { return true. }
    local candidate_ok is terra_deorbit_in_envelope(candidate).
    local incumbent_ok is terra_deorbit_in_envelope(incumbent).
    if candidate_ok and not incumbent_ok { return true. }
    if incumbent_ok and not candidate_ok { return false. }
    return candidate["score"] < incumbent["score"].
}

function terra_deorbit_plan {
    parameter site.
    if hasnode { return lex("valid",false,"reason","existing_maneuver_nodes"). }
    if ship:orbit:eccentricity >= 1 or ship:orbit:hasnextpatch { return lex("valid",false,"reason","unsupported_orbit"). }
    if ship:body:name <> "Kerbin" { return lex("valid",false,"reason","uncalibrated_body"). }
    local planet_radius is ship:body:radius.
    local target_vec is site:altitudeposition(0)-ship:body:position.
    local equator is latlng(0,0).
    local equator_vec is (equator:altitudeposition(0)-ship:body:position):normalized.
    local ground_vel is equator:velocity:orbit.
    local spin_axis is vcrs(equator_vec,ground_vel):normalized.
    if spin_axis:mag < 0.5 { set spin_axis to (latlng(90,0):position-ship:body:position):normalized. }
    local spin_rate is ship:body:angularvel:mag.
    local search_ut is time:seconds.
    local orbit_period is ship:orbit:period.
    local best is lex("valid",false,"score",1e12).
    local best_ut is 0.
    local increment is orbit_period/96.
    local i is 0.
    until i > 384 {
        local burn_ut is search_ut+600+i*increment.
        local rv is positionat(ship,burn_ut)-ship:body:position.
        local vv is velocityat(ship,burn_ut):orbit.
        local result is terra_deorbit_candidate(rv,vv,ship:body:mu,planet_radius,planet_radius+60000,
            planet_radius+18000,target_vec,spin_axis,spin_rate,burn_ut-search_ut,800).
        if terra_deorbit_better(result,best) { set best to result. set best_ut to burn_ut. }
        if mod(i,16) = 0 {
            set Lastest_status to "Searching up to four orbits for a deorbit window".
            wait 0.
            if step <> "Deorbit" or not running { return lex("valid",false,"reason","planning_cancelled"). }
        }
        set i to i+1.
    }
    if not best["valid"] { return lex("valid",false,"reason","no_ballistic_entry"). }
    local refine is increment/2.
    set i to 0.
    until i >= 8 {
        for burn_ut in list(best_ut-refine,best_ut+refine) {
            if burn_ut >= search_ut+600 {
                local rv is positionat(ship,burn_ut)-ship:body:position.
                local vv is velocityat(ship,burn_ut):orbit.
                local result is terra_deorbit_candidate(rv,vv,ship:body:mu,planet_radius,planet_radius+60000,
                    planet_radius+18000,target_vec,spin_axis,spin_rate,burn_ut-search_ut,800).
                if terra_deorbit_better(result,best) { set best to result. set best_ut to burn_ut. }
            }
        }
        set refine to refine/2.
        set i to i+1.
        wait 0.
    }
    if not terra_deorbit_in_envelope(best) {
        return lex("valid",false,"reason","no_window_in_entry_envelope","along",best["along"],"crossrange",best["crossrange"],"desired",best["desired"]).
    }
    if best["dv"] > velocityat(ship,best_ut):orbit:mag*0.5 { return lex("valid",false,"reason","burn_exceeds_limit"). }
    if best_ut <= time:seconds+60 { return lex("valid",false,"reason","planning_window_expired"). }
    best:add("ut",best_ut).
    return best.
}

// Node axes can differ from the velocity frame on eccentric orbits. Measure
// the actual node basis and resolve the intended retrograde impulse in it.
// The caller owns the new node and checks its post-burn orbit before firing.
function terra_deorbit_node_next {
    parameter maneuver.
    if not hasnode { return false. }
    return nextnode = maneuver.
}

function terra_deorbit_remove_owned_node {
    parameter maneuver.
    for existing in allnodes {
        if existing = maneuver { remove maneuver. return. }
    }
}

function terra_deorbit_node {
    parameter plan.
    local maneuver is node(plan["ut"],0,0,0).
    add maneuver.
    set maneuver:prograde to 1.
    wait 0.
    if step <> "Deorbit" or not running {
        terra_deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","planning_cancelled").
    }
    if not terra_deorbit_node_next(maneuver) {
        terra_deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","node_changed").
    }
    local axis_prograde is maneuver:deltav.
    set maneuver:prograde to 0.
    set maneuver:radialout to 1.
    wait 0.
    if step <> "Deorbit" or not running {
        terra_deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","planning_cancelled").
    }
    if not terra_deorbit_node_next(maneuver) {
        terra_deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","node_changed").
    }
    local axis_radial is maneuver:deltav.
    local a is vdot(axis_prograde,axis_prograde).
    local b is vdot(axis_prograde,axis_radial).
    local c is vdot(axis_radial,axis_radial).
    local det is a*c-b*b.
    if det < 0.0001 { remove maneuver. return lex("valid",false,"reason","node_axes_unavailable"). }
    local planned_velocity is velocityat(ship,plan["ut"]):orbit.
    local impulse is -planned_velocity:normalized*plan["dv"].
    local want_prograde is vdot(impulse,axis_prograde).
    local want_radial is vdot(impulse,axis_radial).
    set maneuver:prograde to (want_prograde*c-want_radial*b)/det.
    set maneuver:radialout to (want_radial*a-want_prograde*b)/det.
    wait 0.
    if step <> "Deorbit" or not running {
        terra_deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","planning_cancelled").
    }
    if not terra_deorbit_node_next(maneuver) {
        terra_deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","node_changed").
    }
    local vector_error is (maneuver:deltav-impulse):mag.
    if vector_error > 0.1 { remove maneuver. return lex("valid",false,"reason","node_vector_mismatch"). }
    return lex("valid",true,"node",maneuver,"vector_error",vector_error).
}
