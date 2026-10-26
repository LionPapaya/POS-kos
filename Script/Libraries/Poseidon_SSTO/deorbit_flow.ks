// POS3 orchestration only. The analytic predictor remains free of control/logging.
function reentry_deorbit_phase {
    parameter apoapsis_m.
    if apoapsis_m < 500000 { return "reentry_low". }
    if apoapsis_m < 1000000 { return "reentry_mid". }
    if apoapsis_m < 10000000 { return "reentry_high". }
    return "reentry_int".
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
    flight_log_event("deorbit_rejected","reason="+why+"|mode="+Reentry_mode).
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
function reentry_deorbit_update {
    set console_mode to "DATA".
    // setup_reentry_script waits for the GUI OK before this function is called.
    // A vehicle already on entry does not need a maneuver or Trajectories.
    if ship:periapsis < ship:body:atm:height {
        set step to reentry_deorbit_phase(ship:apoapsis).
        set substep to "".
        return.
    }
    if Reentry_mode = "Man" {
        set Lastest_status to "Pilot deorbit: waiting for atmospheric periapsis".
        return.
    }
    if abort_flag or dap["dap_mode"] <> "auto" {
        reentry_deorbit_reject("pilot_cancelled"). return.
    }
    if ship:body:name <> "Kerbin" {
        reentry_deorbit_reject("entry_envelope_requires_kerbin"). return.
    }
    if ship:orbit:eccentricity >= 1 or ship:orbit:hasnextpatch {
        reentry_deorbit_reject("requires_stable_closed_orbit"). return.
    }
    local cfg is deorbit_config().
    // No plane change: even the best longitude cannot overcome this latitude gap.
    local latitude_limit is min(ship:orbit:inclination,180-ship:orbit:inclination).
    local latitude_gap is max(0,abs(runway_start:lat)-latitude_limit)*constant:degtorad*ship:body:radius.
    if latitude_gap > cfg["max_crossrange"] {
        reentry_deorbit_reject("site_not_reachable_from_orbital_plane"). return.
    }
    if not deorbit_scan_active and Reentry_mode = "auto" {
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
        set deorbit_scan_active to true.
        set substep to "planning".
        flight_log_event("deorbit_plan_started","target="+Location+"_"+runway_nr+
            "|lat="+runway_start:lat+"|lng="+runway_start:lng+"|apoapsis="+ship:apoapsis+
            "|periapsis="+ship:periapsis+"|inclination="+ship:orbit:inclination+
            "|available_dv="+cfg["available_dv"]+"|horizon_s="+(deorbit_scan["end_ut"]-time:seconds)).
    }
    if Reentry_mode = "auto" {
        set deorbit_scan to deorbit_step(deorbit_scan).
        set Lastest_status to "Searching entry passes: "+round(100*(deorbit_scan["next_ut"]-deorbit_scan["epoch"])/max(1,deorbit_scan["end_ut"]-deorbit_scan["epoch"]),0)+"%".
        if not deorbit_scan["done"] { return. }
        local plan is deorbit_scan["result"].
        flight_log_event("deorbit_search_finished","samples="+deorbit_scan["sample_count"]+
            "|feasible="+deorbit_scan["feasible_count"]+"|last_rejection="+deorbit_scan["last_rejection"]).
        if not plan["valid"] { reentry_deorbit_reject(plan["reason"]). return. }
        if hasnode { reentry_deorbit_reject("nodes_changed_during_search"). return. }
        local planned_node is node(plan["node_ut"],plan["radial"],plan["normal"],plan["prograde"]).
        add planned_node.
        flight_log_event("deorbit_plan_ready","node_ut="+plan["node_ut"]+"|dv="+plan["delta_v"]+
            "|entry_ut="+plan["entry_ut"]+"|entry_speed="+plan["entry_speed"]+
            "|entry_angle="+plan["entry_angle"]+"|range_m="+plan["range_m"]+
            "|crossrange_m="+plan["crossrange_m"]+"|predicted_pe="+planned_node:orbit:periapsis).
    } else if Reentry_mode <> "Ex" {
        reentry_deorbit_reject("unknown_deorbit_mode"). return.
    }
    if not hasnode { reentry_deorbit_reject("executor_requires_map_node"). return. }
    local maneuver is nextnode.
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
    dap:setup().
    flight_log_event("deorbit_execution_result","success="+outcome["success"]+
        "|reason="+outcome["reason"]+"|remaining_dv="+outcome["remaining_dv"]+
        "|achieved_pe="+ship:periapsis+"|achieved_ap="+ship:apoapsis).
    if not outcome["success"] {
        // Once a partial burn commits us to atmosphere, retain entry control.
        // A pilot cancellation explicitly hands control back instead.
        if outcome["reason"] <> "cancelled" and dap["dap_mode"] = "auto" and
           ship:periapsis < ship:body:atm:height and not ship:orbit:hasnextpatch {
            set step to reentry_deorbit_phase(ship:apoapsis).
            set substep to "partial_deorbit".
            set Lastest_status to "Partial deorbit: recovering on actual entry state".
            flight_log_event("deorbit_partial_entry","reason="+outcome["reason"]+
                "|periapsis="+ship:periapsis+"|remaining_dv="+outcome["remaining_dv"]).
            return.
        }
        reentry_deorbit_reject(outcome["reason"]). return.
    }
    if ship:periapsis >= ship:body:atm:height or ship:orbit:hasnextpatch {
        reentry_deorbit_reject("burn_did_not_establish_entry"). return.
    }
    set step to reentry_deorbit_phase(ship:apoapsis).
    set substep to "".
    set Lastest_status to "Deorbit complete; coasting to entry guidance".
}
