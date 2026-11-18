// POS3 orchestration only. The analytic predictor remains free of control/logging.
function reentry_deorbit_phase {
    parameter apoapsis_m.
    if apoapsis_m < 500000 { return "reentry_low". }
    if apoapsis_m < 1000000 { return "reentry_mid". }
    if apoapsis_m < 10000000 { return "reentry_high". }
    return "reentry_int".
}
// GUI stores AUTO, Auto, Ex or Man. events.csv scores auto/Ex/Man.
function reentry_deorbit_mode {
    if not (defined Reentry_mode) { return "unknown". }
    if Reentry_mode = "auto" { return "auto". }
    if Reentry_mode = "ex" { return "Ex". }
    if Reentry_mode = "man" { return "Man". }
    return "unknown".
}
// "none" is the only stamp a search may keep. Add, delete and edit all differ.
function reentry_deorbit_node_stamp {
    if not hasnode { return "none". }
    local maneuver is nextnode.
    return allnodes:length+"|"+maneuver:time+"|"+maneuver:prograde+"|"+maneuver:normal+"|"+maneuver:radialout.
}
// A node that appears and later vanishes still poisons positionat samples.
function reentry_deorbit_nodes_changed {
    parameter scan_state.
    local stamp is reentry_deorbit_node_stamp().
    if not scan_state:haskey("node_stamp") { set scan_state["node_stamp"] to "none". }
    if stamp <> scan_state["node_stamp"] { set scan_state["node_changed"] to true. }
    if scan_state:haskey("node_changed") and scan_state["node_changed"] { return true. }
    return false.
}
function reentry_deorbit_reject {
    parameter why.
    set Lastest_status to "Deorbit unavailable: "+why.
    if why = "site_not_reachable_from_orbital_plane" or why = "target_outside_orbital_plane" {
        set Lastest_status to "Site not reachable from this orbital plane; no burn".
    }
    if why = "no_entry_pass_in_search_window" {
        set Lastest_status to "No reachable entry pass in six orbits; no burn".
    }
    print Lastest_status.
    flight_log_event("deorbit_rejected","reason="+why+"|mode="+reentry_deorbit_mode()).
    set recovery_result to lex("complete",true,"success",false,"reason",why).
    set step to "end".
}
// EX is a deliberate request to execute the next map node, without replanning it.
// It still cannot authorize an escape, plane change or non-entry maneuver.
function reentry_deorbit_node_reason {
    parameter maneuver, maximum_dv.
    if maneuver:deltav:mag < 0.2 { return "node_has_no_burn". }
    if maneuver:deltav:mag > maximum_dv { return "node_dv_limit". }
    if abs(maneuver:normal) > 1 { return "node_plane_change". }
    if maneuver:orbit:periapsis < -100000 or maneuver:orbit:periapsis >= ship:body:atm:height {
        return "node_not_atmospheric_entry".
    }
    if maneuver:orbit:eccentricity >= 1 { return "node_is_escape". }
    if maneuver:orbit:hasnextpatch { return "node_has_encounter". }
    return "".
}
// One feasibility check per run. Kerbin accepts the wheeled runway immediately.
// Other bodies refuse the burn when the surveyed site cannot be landed.
function reentry_deorbit_admit {
    if defined landing_admission_done and landing_admission_done { return true. }
    if not (defined landing_sites_loaded) {
        if defined landing_admission_done { set landing_admission_done to true. }
        else { global landing_admission_done is true. }
        return true.
    }
    local landing_admission is landing_admit_site().
    flight_log_event("landing_admission","valid="+landing_admission["valid"]+
        "|method="+landing_admission["method"]+"|reason="+landing_admission["reason"]+
        "|body="+ship:body:name).
    if not landing_admission["valid"] {
        reentry_deorbit_reject(landing_admission["reason"]).
        return false.
    }
    if defined landing_admission_done { set landing_admission_done to true. }
    else { global landing_admission_done is true. }
    set Lastest_status to "Landing method: " + landing_admission["method"].
    return true.
}
function reentry_deorbit_update {
    set console_mode to "DATA".
    local mode is reentry_deorbit_mode().
    local have_planned_node is false.
    local planned_node is 0.
    if not (defined deorbit_mode_announced) { global deorbit_mode_announced is false. }
    if not deorbit_mode_announced {
        set deorbit_mode_announced to true.
        flight_log_event("deorbit_mode_start","mode="+mode).
    }
    // setup_reentry_script waits for the GUI OK before this function is called.
    // A vehicle already on entry does not need a maneuver or Trajectories.
    // Kerbin keeps that immediate handoff. Other bodies still have to pass
    // the landing gate, including a suborbital start.
    if ship:periapsis < ship:body:atm:height {
        if defined body_environment_loaded and not body_is_kerbin() {
            if not reentry_deorbit_admit() { return. }
            set reentry_selected_site_locked to true.
        }
        set step to reentry_deorbit_phase(ship:apoapsis).
        set substep to "".
        return.
    }
    // An unrecognized mode must not be reported as a site or pilot failure.
    if mode <> "auto" and mode <> "Ex" and mode <> "Man" {
        reentry_deorbit_reject("unknown_deorbit_mode").
        return.
    }
    if mode = "Man" {
        if not reentry_deorbit_admit() { return. }
        set Lastest_status to "Pilot deorbit: waiting for atmospheric periapsis".
        if defined body_environment_loaded and not body_is_kerbin() and defined landing_method and landing_method <> "" {
            set Lastest_status to Lastest_status + " | " + landing_method.
        }
        return.
    }
    if abort_flag or dap["dap_mode"] <> "auto" {
        reentry_deorbit_reject("pilot_cancelled"). return.
    }
    if not reentry_deorbit_admit() { return. }
    if ship:orbit:eccentricity >= 1 or ship:orbit:hasnextpatch {
        reentry_deorbit_reject("requires_stable_closed_orbit"). return.
    }
    local cfg is deorbit_config().
    if defined landing_method and landing_method = "powered" {
        set cfg["lf_reserve_units"] to max(cfg["lf_reserve_units"], landing_powered_lf).
    }
    // No plane change: even the best longitude cannot overcome this latitude gap.
    local latitude_limit is min(ship:orbit:inclination,180-ship:orbit:inclination).
    local latitude_gap is max(0,abs(runway_start:lat)-latitude_limit)*constant:degtorad*ship:body:radius.
    if latitude_gap > cfg["max_crossrange"] {
        reentry_deorbit_reject("site_not_reachable_from_orbital_plane"). return.
    }
    if not deorbit_scan_active and mode = "auto" {
        if hasnode { reentry_deorbit_reject("resolve_existing_nodes_first"). return. }
        nervson(). rapiersoff().
        if ship:availablethrust <= 0 or ship_isp() <= 0 {
            reentry_deorbit_reject("no_nerv_thrust"). return.
        }
        // Leave the configured terminal reserve or 20% of existing LF.
        // Accessible fuel and finite-burn progress are rechecked by the executor.
        set cfg["available_dv"] to deorbit_usable_dv(ship:mass,ship:liquidfuel,ship_isp(),cfg).
        if cfg["available_dv"] <= 0 { reentry_deorbit_reject("insufficient_fuel_after_terminal_reserve"). return. }
        set cfg["lead_time"] to max(600,calculate_burn_time(min(cfg["max_dv"],cfg["available_dv"]),ship_isp(),ship:availablethrust)+90).
        set deorbit_scan to deorbit_begin(runway_start,cfg).
        set deorbit_scan["node_stamp"] to reentry_deorbit_node_stamp().
        set deorbit_scan["node_changed"] to false.
        set deorbit_scan_active to true.
        set substep to "planning".
        flight_log_event("deorbit_plan_started","target="+Location+"_"+runway_nr+
            "|lat="+runway_start:lat+"|lng="+runway_start:lng+"|apoapsis="+ship:apoapsis+
            "|periapsis="+ship:periapsis+"|inclination="+ship:orbit:inclination+
            "|available_dv="+cfg["available_dv"]+"|horizon_s="+(deorbit_scan["end_ut"]-time:seconds)).
    }
    if mode = "auto" {
        // Reject before another sample so a transient node cannot become the plan.
        if reentry_deorbit_nodes_changed(deorbit_scan) {
            reentry_deorbit_reject("nodes_changed_during_search"). return.
        }
        set deorbit_scan to deorbit_step(deorbit_scan).
        if reentry_deorbit_nodes_changed(deorbit_scan) {
            reentry_deorbit_reject("nodes_changed_during_search"). return.
        }
        set Lastest_status to "Searching entry passes: "+round(100*(deorbit_scan["next_ut"]-deorbit_scan["epoch"])/max(1,deorbit_scan["end_ut"]-deorbit_scan["epoch"]),0)+"%".
        if not deorbit_scan["done"] { return. }
        local plan is deorbit_scan["result"].
        flight_log_event("deorbit_search_finished","samples="+deorbit_scan["sample_count"]+
            "|feasible="+deorbit_scan["feasible_count"]+"|last_rejection="+deorbit_scan["last_rejection"]).
        if reentry_deorbit_nodes_changed(deorbit_scan) {
            reentry_deorbit_reject("nodes_changed_during_search"). return.
        }
        if not plan["valid"] { reentry_deorbit_reject(plan["reason"]). return. }
        if hasnode { reentry_deorbit_reject("nodes_changed_during_search"). return. }
        local node_result is deorbit_node(plan).
        if not node_result["valid"] {
            reentry_deorbit_reject(node_result["reason"]). return.
        }
        set planned_node to node_result["node"].
        set have_planned_node to true.
        flight_log_event("deorbit_plan_ready","node_ut="+plan["node_ut"]+"|dv="+plan["delta_v"]+
            "|entry_ut="+plan["entry_ut"]+"|entry_speed="+plan["entry_speed"]+
            "|entry_angle="+plan["entry_angle"]+"|range_m="+plan["range_m"]+
            "|crossrange_m="+plan["crossrange_m"]+"|predicted_pe="+planned_node:orbit:periapsis).
    } else if mode <> "Ex" {
        reentry_deorbit_reject("unknown_deorbit_mode"). return.
    }
    local maneuver is 0.
    if have_planned_node {
        // Execute the node this search added, never an earlier one that appeared later.
        if not deorbit_node_next(planned_node) {
            reentry_deorbit_reject("node_changed"). return.
        }
        set maneuver to planned_node.
    } else {
        if not hasnode { reentry_deorbit_reject("executor_requires_map_node"). return. }
        set maneuver to nextnode.
    }
    local rejection is reentry_deorbit_node_reason(maneuver,cfg["max_dv"]).
    if rejection <> "" { reentry_deorbit_reject(rejection). return. }
    nervson(). rapiersoff().
    if ship:availablethrust <= 0 or ship_isp() <= 0 { reentry_deorbit_reject("no_nerv_thrust"). return. }
    local usable_dv is deorbit_usable_dv(ship:mass,ship:liquidfuel,ship_isp(),cfg).
    if maneuver:deltav:mag > usable_dv { reentry_deorbit_reject("insufficient_fuel_after_terminal_reserve"). return. }
    set reentry_selected_site_locked to true.
    set substep to "executing".
    set Lastest_status to "Executing deorbit; DAP OFF/CSS or ABORT cancels".
    // Only the executor writes controls until it returns. Entry heartbeat is
    // phase-gated and does not run in Deorbit; this call yields internally.
    local outcome is deorbit_execute(maneuver).
    set dapthrottle to 0.
    local burn_seen is false.
    if outcome:haskey("burn_seen") { set burn_seen to outcome["burn_seen"]. }
    flight_log_event("deorbit_execution_result","success="+outcome["success"]+
        "|reason="+outcome["reason"]+"|mode="+mode+"|remaining_dv="+outcome["remaining_dv"]+
        "|burn_seen="+burn_seen+"|achieved_pe="+ship:periapsis+"|achieved_ap="+ship:apoapsis).
    if not outcome["success"] {
        // Once a partial burn commits us to atmosphere, retain entry control.
        // A pilot cancellation explicitly hands control back instead.
        if outcome["reason"] <> "cancelled" and dap["dap_mode"] = "auto" and
           ship:periapsis < ship:body:atm:height and not ship:orbit:hasnextpatch {
            // The burn already changed the orbit. Drop only our leftover node
            // so entry and Trajectories follow that orbit, then take controls.
            deorbit_remove_owned_node(maneuver).
            dap:setup().
            set step to reentry_deorbit_phase(ship:apoapsis).
            set substep to "partial_deorbit".
            set Lastest_status to "Partial deorbit: recovering on actual entry state".
            flight_log_event("deorbit_partial_entry","reason="+outcome["reason"]+
                "|mode="+mode+"|periapsis="+ship:periapsis+"|remaining_dv="+outcome["remaining_dv"]).
            return.
        }
        reentry_deorbit_reject(outcome["reason"]). return.
    }
    if ship:periapsis >= ship:body:atm:height or ship:orbit:hasnextpatch {
        reentry_deorbit_reject("burn_did_not_establish_entry"). return.
    }
    dap:setup().
    set step to reentry_deorbit_phase(ship:apoapsis).
    set substep to "".
    set Lastest_status to "Deorbit complete; coasting to entry guidance".
}

// Node axes can differ from the velocity frame on eccentric orbits. Measure
// the actual node basis and resolve the intended retrograde impulse in it.
// The caller owns the new node and checks its post-burn orbit before firing.
function deorbit_node_next {
    parameter maneuver.
    if not hasnode { return false. }
    return nextnode = maneuver.
}

function deorbit_remove_owned_node {
    parameter maneuver.
    for existing in allnodes {
        if existing = maneuver { remove maneuver. return. }
    }
}

function deorbit_node {
    parameter plan.
    local maneuver is node(plan["node_ut"],0,0,0).
    add maneuver.
    set maneuver:prograde to 1.
    wait 0.
    if step <> "Deorbit" or not running {
        deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","planning_cancelled").
    }
    if not deorbit_node_next(maneuver) {
        deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","node_changed").
    }
    local axis_prograde is maneuver:deltav.
    set maneuver:prograde to 0.
    set maneuver:radialout to 1.
    wait 0.
    if step <> "Deorbit" or not running {
        deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","planning_cancelled").
    }
    if not deorbit_node_next(maneuver) {
        deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","node_changed").
    }
    local axis_radial is maneuver:deltav.
    local a is vdot(axis_prograde,axis_prograde).
    local b is vdot(axis_prograde,axis_radial).
    local c is vdot(axis_radial,axis_radial).
    local det is a*c-b*b.
    if det < 0.0001 {
        deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","node_axes_unavailable").
    }
    local planned_velocity is velocityat(ship,plan["node_ut"]):orbit.
    local impulse is -planned_velocity:normalized*plan["delta_v"].
    local want_prograde is vdot(impulse,axis_prograde).
    local want_radial is vdot(impulse,axis_radial).
    set maneuver:prograde to (want_prograde*c-want_radial*b)/det.
    set maneuver:radialout to (want_radial*a-want_prograde*b)/det.
    wait 0.
    if step <> "Deorbit" or not running {
        deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","planning_cancelled").
    }
    if not deorbit_node_next(maneuver) {
        deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","node_changed").
    }
    local vector_error is (maneuver:deltav-impulse):mag.
    if vector_error > 0.1 {
        deorbit_remove_owned_node(maneuver).
        return lex("valid",false,"reason","node_vector_mismatch").
    }
    return lex("valid",true,"node",maneuver,"vector_error",vector_error).
}
