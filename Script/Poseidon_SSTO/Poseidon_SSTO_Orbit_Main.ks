
// Poseidon_SSTO/Poseidon_SSTO_Orbit_Main.ks
// Purpose: ascent and orbital insertion script for Poseidon SSTO.
// - Loads the Poseidon libraries and runs the aircraft-style ascent/circularization flow.
// Recovery executives stay in Orbit Main; libraries provide observations and
// pure prediction services only. Exactly one mode writes commands per tick.
function recovery_phase {
    parameter state, next_phase.
    if state["phase"] <> next_phase {
        flight_log_event("recovery_phase","mode="+state["mode"]+"|from="+state["phase"]+
            "|to="+next_phase+"|source="+state["source_step"]).
        set state["phase"] to next_phase.
        set state["phase_entered"] to time:seconds.
    }
}

function recovery_transition {
    parameter state, next_mode, reason.
    if state["mode"] = next_mode { return. }
    flight_log_event("recovery_mode","from="+state["mode"]+"|to="+next_mode+"|reason="+reason+
        "|source="+state["source_step"]+"|rapiers_out="+state["scenario"]["rapiers_out"]+
        "|nervs_out="+state["scenario"]["nervs_out"]).
    set state["mode"] to next_mode.
    set state["phase"] to "initialize".
    set state["phase_entered"] to time:seconds.
    set state["handoff_ready"] to false.
    set state["handoff"]["started"] to false.
    if next_mode <> "ato" {
        set state["orbit_abandoned"] to true.
        set state["suppress_orbit"] to true.
    }
    if next_mode = "contingency_abort" {
        recovery_set_isolated("nerv",false).
        // Allow the fallback to initialize its caches, but carry the original
        // reserves and the rejected-attempt history into that initialization.
        if state:haskey("orbit_eligible") { state:remove("orbit_eligible"). }
        set state["target"]["selected"] to false.
    }
    set step to next_mode.
}

function recovery_finish {
    parameter state, reason, success is false, pilot is true.
    abort_set_fuel_dump(false).
    set dapthrottle to 0.
    set dap["envelope"]["min_throttle"] to 0.
    set state["result"] to lex("success",success,"reason",reason,"pilot_control",pilot).
    set state["active"] to false.
    set state["controls_released"] to true.
    recovery_phase(state,"complete").
    flight_log_event("recovery_outcome","mode="+state["mode"]+"|reason="+reason+
        "|success="+success+"|pilot_control="+pilot+"|apoapsis="+ship:apoapsis+
        "|periapsis="+ship:periapsis+"|lf="+ship:liquidfuel+"|ox="+ship:oxidizer).
    recovery_apply_limits().
    set ship:control:pilotmainthrottle to 0.
    dap:set_off().
    unlock throttle.
    set ship:control:neutralize to true.
    if pilot { print "RECOVERY: PILOT CONTROL - "+reason. }
    set step to "end".
}

function recovery_ato_reject {
    parameter state, reason.
    set state["orbit_abandoned"] to true.
    set state["suppress_orbit"] to true.
    flight_log_event("recovery_orbit_rejected","reason="+reason+"|phase="+state["phase"]).
    local layout is recovery_rapier_layout().
    if state["nominal_cutoff"] or ship:periapsis >= ship:body:atm:height {
        recovery_transition(state,"edr",reason).
    } else if layout["healthy"] > 0 {
        recovery_transition(state,"aed",reason).
    } else {
        recovery_transition(state,"contingency_abort",reason).
    }
}

function recovery_ato_assess {
    parameter state, cfg.
    if state["scenario"]["nervs_out"] > 0 {
        recovery_ato_reject(state,"nerv_failure").
        return.
    }
    local layout is recovery_rapier_layout().
    local rapier_continue is state["scenario"]["rapiers_out"] = 1 or
        (state["scenario"]["rapiers_out"] = 2 and layout["opposite_pair"]).
    if state["nominal_cutoff"] { set rapier_continue to false. }
    // A same-side pair and an uncalibrated single survivor are isolated. Their
    // identities stay healthy so a later diversion can deliberately reuse them.
    recovery_set_isolated("rapier",not rapier_continue).
    recovery_set_isolated("nerv",false).
    nervson().
    if rapier_continue {
        rapierson().
        if state["current_ascent_phase"] = "closed_cycle_climb" { togglerapiermode("CLOSED"). }
    }
    set state["power"] to recovery_power(state,rapier_continue,true).
    local power is state["power"].
    if not power["usable"] or power["acceleration"] < cfg["minimum_acceleration"] {
        recovery_ato_reject(state,"insufficient_permitted_thrust").
        return.
    }
    local radial_mps is vdot(ship:velocity:orbit,ship:up:vector).
    local tangent_mps is (ship:velocity:orbit-ship:up:vector*radial_mps):mag.
    if rapier_continue {
        set state["orbit_budget"] to contingency_orbit_budget(ship:body:mu,ship:body:radius,
            ship:altitude,ship:velocity:orbit:mag,radial_mps,cfg["target_ap"],power["vacuum_dv"],
            power["acceleration"],contingency_config()).
        if not state["orbit_budget"]["possible"] {
            recovery_ato_reject(state,"nominal_orbit_fuel_budget").
            return.
        }
        set state["rapier_continue"] to true.
        recovery_phase(state,"nominal_continue").
    } else {
        if ship:altitude < cfg["minimum_escape_height"] or tangent_mps < cfg["minimum_escape_horizontal_speed"] {
            recovery_ato_reject(state,"nerv_escape_too_early").
            return.
        }
        local best_prediction is lex("possible",false,"reason","no_pitch_candidate").
        local prediction_started is time:seconds.
        // Current measured drag is pessimistically held through the remaining
        // atmosphere. Fuel is reserved for a 200 m/s model-error allowance.
        local drag_bound is 0.
        if ship:altitude < ship:body:atm:height {
            local aero_live is cur_aeroaccel_ld().
            set drag_bound to max(0,-vdot(aero_live["load"],ship:velocity:surface:normalized)).
        }
        local fuel_seconds is min(power["burn_time"],cfg["timeout"])-
            cfg["loss_allowance"]/max(0.01,power["acceleration"]).
        for candidate_pitch in list(30,45,60) {
            dap:update().
            local predicted is recovery_escape_prediction(ship:body:mu,ship:body:radius,
                ship:body:atm:height,ship:altitude,radial_mps,tangent_mps,ship:mass,
                power["thrust"],power["mass_flow"],max(0,fuel_seconds),candidate_pitch,drag_bound,cfg).
            if predicted["possible"] {
                if not best_prediction["possible"] or predicted["burn_seconds"] < best_prediction["burn_seconds"] {
                    set best_prediction to predicted.
                }
            }
            wait 0.
            if time:seconds-prediction_started > 6 { break. }
        }
        set state["orbit_prediction"] to best_prediction.
        flight_log_event("recovery_orbit_prediction","possible="+best_prediction["possible"]+
            "|reason="+best_prediction["reason"]+"|duration="+(time:seconds-prediction_started)).
        if not best_prediction["possible"] {
            recovery_ato_reject(state,best_prediction["reason"]).
            return.
        }
        set state["rapier_continue"] to false.
        set state["escape_pitch"] to best_prediction["pitch"].
        recovery_phase(state,"nerv_only_escape").
    }
    set state["orbit_attempted"] to true.
    set state["orbit_started_ut"] to time:seconds.
    set state["progress_ut"] to time:seconds.
    set state["progress_value"] to ship:apoapsis.
    set state["pitch"] to pitch_for().
    set state["last_update_ut"] to time:seconds.
    set state["assist_speed_ut"] to time:seconds.
    set state["assist_speed"] to ship:airspeed.
    set state["assist_acceleration"] to 1e9.
    flight_log_event("recovery_orbit_attempt","rapier_continue="+state["rapier_continue"]+
        "|goal_ap="+cfg["target_ap"]+"|goal_pe="+(ship:body:atm:height+cfg["safe_clearance"])+
        "|dv_available="+power["dv"]+"|burn_time="+power["burn_time"]).
}

function recovery_ato_update {
    parameter state.
    local cfg is recovery_orbit_config().
    if state:haskey("nominal_insertion") and state["nominal_insertion"] {
        set cfg["target_ap"] to TargetApoapsis.
    }
    set warp to 0.
    abort_set_fuel_dump(false).
    if state["phase"] = "initialize" { recovery_ato_assess(state,cfg). return. }
    local safe_height is ship:body:atm:height+cfg["safe_clearance"].
    if state:haskey("nominal_insertion") and state["nominal_insertion"] {
        set safe_height to max(ship:body:atm:height+5000,TargetPeriapsis-300).
    }
    if ship:orbit:eccentricity < 1 and ship:periapsis >= safe_height {
        recovery_phase(state,"orbital_hold").
        recovery_finish(state,"ato_orbit_complete",true,false).
        return.
    }
    local rapier_continue is state["rapier_continue"] and not state["nominal_cutoff"].
    set state["power"] to recovery_power(state,rapier_continue,true).
    local power is state["power"].
    local radial_mps is vdot(ship:velocity:orbit,ship:up:vector).
    if not power["usable"] or ship:liquidfuel <= state["lf_reserve"] or
       time:seconds-state["orbit_started_ut"] > cfg["timeout"] or
       ship:orbit:eccentricity >= 1 or (radial_mps < -100 and ship:altitude < safe_height) {
        recovery_ato_reject(state,"fuel_thrust_time_or_descent").
        return.
    }
    local dt_seconds is max(0,min(1,time:seconds-state["last_update_ut"])).
    set state["last_update_ut"] to time:seconds.
    set dap["dap_mode"] to "auto".
    brakes off.
    gear off.
    if state["phase"] = "nominal_continue" or state["phase"] = "nerv_only_escape" or
       state["phase"] = "apoapsis_build" {
        local desired_pitch is AVES["Ascent"]["nerv_pitch"].
        if state["phase"] = "nominal_continue" {
            if state["current_ascent_phase"] = "nerv_assist" {
                // Measure acceleration over elapsed time, independent of IPU
                // and prediction work, before giving up air-breathing thrust.
                if time:seconds-state["assist_speed_ut"] >= 1 {
                    set state["assist_acceleration"] to (ship:airspeed-state["assist_speed"])/
                        (time:seconds-state["assist_speed_ut"]).
                    set state["assist_speed"] to ship:airspeed.
                    set state["assist_speed_ut"] to time:seconds.
                }
                if ship:altitude >= AVES["Ascent"]["closed_cycle_min_altitude"] and
                   state["assist_acceleration"] <= cfg["assist_min_acceleration"] {
                    set state["current_ascent_phase"] to "closed_cycle_climb".
                    togglerapiermode("CLOSED").
                    flight_log_event("recovery_ascent_phase","to=closed_cycle_climb|acceleration="+
                        state["assist_acceleration"]+"|altitude="+ship:altitude).
                }
            }
            if state["current_ascent_phase"] = "closed_cycle_climb" {
                set desired_pitch to AVES["Ascent"]["closed_cycle_pitch_max"].
            }
            if ship:apoapsis >= AVES["Ascent"]["rapier_cutoff_apoapsis"] {
                set state["nominal_cutoff"] to true.
                set recovery_nominal_cutoff to true.
                recovery_set_isolated("rapier",true).
                set state["current_ascent_phase"] to "apoapsis_build".
                recovery_phase(state,"apoapsis_build").
            }
        }
        if state["phase"] = "apoapsis_build" { set desired_pitch to AVES["Ascent"]["apoapsis_build_pitch"]. }
        if state["phase"] = "nerv_only_escape" { set desired_pitch to state["escape_pitch"]. }
        if ship:altitude < ship:body:atm:height {
            set desired_pitch to min(desired_pitch,pitch_for_prograde()+cfg["pullup_aoa"]).
        }
        set state["pitch"] to state["pitch"]+max(-cfg["pitch_rate"]*dt_seconds,
            min(cfg["pitch_rate"]*dt_seconds,desired_pitch-state["pitch"])).
        set dap["str_mode"] to "aerostr".
        set dap["aerostr"]["turn_heading"] to compass_for_prograde().
        set dap["aerostr"]["turn_pitch"] to state["pitch"].
        set dap["aerostr"]["turn_roll"] to 0.
        set dapthrottle to 1.
        if ship:apoapsis >= cfg["target_ap"] {
            recovery_set_isolated("rapier",true).
            set state["nominal_cutoff"] to true.
            set recovery_nominal_cutoff to true.
            set state["current_ascent_phase"] to "circ".
            set dapthrottle to 0.
            recovery_phase(state,"coast_align").
            set state["progress_ut"] to time:seconds.
            set state["progress_value"] to ship:periapsis.
        }
    } else {
        local tangent is ship:velocity:orbit-ship:up:vector*radial_mps.
        if tangent:mag < 1 { recovery_ato_reject(state,"no_orbital_tangent"). return. }
        set dap["str_mode"] to "vector".
        set dap["vector"]["targetVector"] to tangent:normalized.
        set state["alignment"] to vang(ship:facing:vector,tangent).
        local radius_now is ship:body:radius+ship:altitude.
        local target_speed is sqrt(max(0,ship:body:mu*(2/radius_now-
            2/(radius_now+ship:body:radius+safe_height+100)))).
        local remaining_dv is max(0,target_speed-tangent:mag).
        set state["burn_seconds"] to remaining_dv/max(0.01,power["acceleration"]).
        set dapthrottle to 0.
        if state["phase"] = "coast_align" and ship:altitude >= safe_height and
           ship:orbit:eta:apoapsis <= state["burn_seconds"]/2+15 {
            recovery_phase(state,"insert").
        }
        if state["phase"] = "insert" and state["alignment"] <= cfg["alignment"] {
            set dapthrottle to min(1,remaining_dv/max(0.01,power["acceleration"]*5)).
        }
    }
    if time:seconds-state["progress_ut"] >= cfg["progress_seconds"] {
        local actual_progress is ship:apoapsis.
        if state["phase"] = "coast_align" or state["phase"] = "insert" { set actual_progress to ship:periapsis. }
        if state["phase"] <> "coast_align" and actual_progress-state["progress_value"] < cfg["minimum_gain"] {
            recovery_ato_reject(state,"orbit_not_progressing").
            return.
        }
        set state["progress_ut"] to time:seconds.
        set state["progress_value"] to actual_progress.
    }
}

function recovery_edr_select_target {
    parameter footprint, cfg.
    local selected is lex("selected",false,"score",1e12).
    local search_started is time:seconds.
    for runway_key in location_constants["kerbin"]:keys {
        if runway_key:endswith("_start") and runway_key:contains("_runway_") {
            local parts is runway_key:split("_runway_").
            local site_name is parts[0].
            local runway_num is parts[1]:split("_")[0].
            local finish_key is site_name+"_runway_"+runway_num+"_end".
            if location_constants["kerbin"]:haskey(finish_key) and KerbinRunwayalt:haskey(site_name+"_runway") {
                local start_site is location_constants["kerbin"][runway_key].
                local range_m is calcdistance_m(footprint,start_site).
                if range_m < 400000 and range_m < selected["score"] {
                    local finish_site is location_constants["kerbin"][finish_key].
                    set selected to lex("selected",true,"location",site_name,"runway_num",runway_num,
                        "start",start_site,"end",finish_site,"heading",heading_between(start_site,finish_site),
                        "altitude",KerbinRunwayalt[site_name+"_runway"],"score",range_m,"distance_m",range_m).
                }
            }
        }
        dap:update().
        wait 0.
        if time:seconds-search_started > 3 { break. }
    }
    return selected.
}

function recovery_edr_update {
    parameter state.
    local cfg is recovery_orbit_config().
    set warp to 0.
    abort_set_fuel_dump(false).
    set dapthrottle to 0.
    if state["phase"] = "initialize" {
        set state["return_started_ut"] to time:seconds.
        set state["suppress_orbit"] to true.
        set state["orbit_abandoned"] to true.
        set state["entry_verified"] to false.
        set state["return_attempted"] to false.
        // An already-suborbital trajectory needs no automatic retrograde burn.
        if ship:periapsis < ship:body:atm:height {
            recovery_set_isolated("rapier",true).
            recovery_set_isolated("nerv",true).
            recovery_phase(state,"passive_return").
        } else {
            recovery_set_isolated("rapier",false).
            recovery_set_isolated("nerv",false).
            local layout is recovery_rapier_layout().
            if layout["healthy"] < 3 and not layout["opposite_pair"] { recovery_set_isolated("rapier",true). }
            togglerapiermode("CLOSED").
            rapierson().
            nervson().
            recovery_apply_limits().
            set state["power"] to recovery_power(state,true,true).
            local power is state["power"].
            local radial_mps is vdot(ship:velocity:orbit,ship:up:vector).
            local tangent_mps is (ship:velocity:orbit-ship:up:vector*radial_mps):mag.
            set state["return_plan"] to recovery_return_burn(ship:body:mu,ship:body:radius,
                ship:altitude,tangent_mps,cfg["deorbit_pe"],power["acceleration"],power["dv"]).
            // Long weak burns require a separate finite-duration margin. Reject
            // a burn that cannot fit the available propellant or recovery time.
            if not state["return_plan"]["possible"] or
               state["return_plan"]["burn_seconds"] > min(180,power["burn_time"]*0.8) {
                recovery_finish(state,"edr_deorbit_unavailable_orbit_hold",false,true).
                return.
            }
            local predicted is recovery_return_prediction(ship:body:mu,ship:body:radius,
                ship:body:atm:height,ship:altitude,radial_mps,
                max(0,tangent_mps-state["return_plan"]["dv"]),ship:body:angularvel:mag,1800).
            if not predicted["possible"] {
                recovery_finish(state,"edr_entry_prediction_rejected_orbit_hold",false,true).
                return.
            }
            local footprint is get_geoposition_along_heading(ship:geoposition,compass_for_prograde(),predicted["downrange"]).
            set state["target"] to recovery_edr_select_target(footprint,cfg).
            if not state["target"]["selected"] {
                recovery_finish(state,"edr_no_return_runway_orbit_hold",false,true).
                return.
            }
            set state["return_plan"]["footprint"] to footprint.
            set state["return_plan"]["entry_speed"] to predicted["entry_speed"].
            set state["return_plan"]["entry_slope"] to predicted["entry_slope"].
            set state["burn_started_ut"] to -1.
            recovery_phase(state,"align_return").
            flight_log_event("recovery_return_plan","dv="+state["return_plan"]["dv"]+
                "|burn_seconds="+state["return_plan"]["burn_seconds"]+
                "|runway="+state["target"]["location"]+"_"+state["target"]["runway_num"]+
                "|entry_slope="+predicted["entry_slope"]+"|model=ballistic_geometric_screen").
        }
        return.
    }
    if time:seconds-state["return_started_ut"] > cfg["return_timeout"] {
        recovery_finish(state,"edr_return_timeout",false,true).
        return.
    }
    local radial_mps is vdot(ship:velocity:orbit,ship:up:vector).
    local tangent is ship:velocity:orbit-ship:up:vector*radial_mps.
    if state["phase"] = "align_return" or state["phase"] = "return_burn" {
        if tangent:mag < 1 { recovery_finish(state,"edr_no_orbital_tangent",false,true). return. }
        set dap["str_mode"] to "vector".
        set dap["vector"]["targetVector"] to -tangent:normalized.
        set state["alignment"] to vang(ship:facing:vector,-tangent).
        set state["power"] to recovery_power(state,true,true).
        if ship:periapsis <= cfg["deorbit_pe"] {
            set dapthrottle to 0.
            recovery_set_isolated("rapier",true).
            recovery_set_isolated("nerv",true).
            recovery_phase(state,"verify_return").
        } else if state["alignment"] <= cfg["return_alignment"] and state["power"]["usable"] {
            if state["burn_started_ut"] < 0 { set state["burn_started_ut"] to time:seconds. }
            set state["return_attempted"] to true.
            recovery_phase(state,"return_burn").
            set dapthrottle to min(1,max(0.05,(ship:periapsis-cfg["deorbit_pe"])/10000)).
            if time:seconds-state["burn_started_ut"] > state["return_plan"]["burn_seconds"]*1.5+10 {
                set dapthrottle to 0.
                if ship:periapsis < ship:body:atm:height { recovery_phase(state,"verify_return"). }
                else { recovery_finish(state,"edr_burn_not_progressing_orbit_hold",false,true). }
            }
        } else if time:seconds-state["phase_entered"] > 60 {
            recovery_finish(state,"edr_alignment_or_thrust_unavailable",false,true).
        }
        return.
    }
    if ship:periapsis >= ship:body:atm:height {
        recovery_finish(state,"edr_return_trajectory_not_verified",false,true).
        return.
    }
    if not state["entry_verified"] or
       (state:haskey("entry_check_ut") and time:seconds-state["entry_check_ut"] > 30) {
        local actual_return is recovery_return_prediction(ship:body:mu,ship:body:radius,
            ship:body:atm:height,ship:altitude,radial_mps,tangent:mag,
            ship:body:angularvel:mag,1800).
        if not actual_return["possible"] {
            recovery_transition(state,"contingency_abort","edr_actual_entry_geometry_rejected").
            return.
        }
        local actual_footprint is get_geoposition_along_heading(ship:geoposition,
            compass_for_prograde(),actual_return["downrange"]).
        if ADDONS:TR:available and ADDONS:TR:hasimpact { set actual_footprint to ADDONS:TR:impactpos. }
        set state["target"] to recovery_edr_select_target(actual_footprint,cfg).
        set state["entry_verified"] to true.
        set state["entry_check_ut"] to time:seconds.
        set state["actual_return"] to actual_return.
        flight_log_event("recovery_return_verified","periapsis="+ship:periapsis+
            "|entry_slope="+actual_return["entry_slope"]+"|entry_speed="+actual_return["entry_speed"]+
            "|runway_available="+state["target"]["selected"]).
    }
    set dap["str_mode"] to "vector".
    set dap["vector"]["targetVector"] to ship:velocity:orbit:normalized.
    if ship:altitude <= ship:body:atm:height and radial_mps < 0 {
        if not state["target"]["selected"] {
            local footprint is ship:geoposition.
            if ADDONS:TR:available and ADDONS:TR:hasimpact { set footprint to ADDONS:TR:impactpos. }
            set state["target"] to recovery_edr_select_target(footprint,cfg).
        }
        if state["target"]["selected"] {
            // Normal entry starts only after a real descending atmosphere
            // crossing; it skips its deorbit setup and retains all restrictions.
            recovery_set_isolated("rapier",false).
            recovery_set_isolated("nerv",false).
            togglerapiermode("AIR").
            rapierson().
            nervsoff().
            recovery_apply_limits().
            set state["handoff_ready"] to true.
            set state["handoff_phase"] to "reentry_low".
            recovery_phase(state,"entry_handoff").
        } else { recovery_transition(state,"contingency_abort","edr_no_reachable_runway"). }
    }
}

// The airborne AED executive owns commands until TEAM.
function recovery_aed_update {
    parameter state.
    local cfg is recovery_aed_config().
    if state["phase"] = "initialize" {
        set kuniverse:timewarp:warp to 0.
        abort_set_fuel_dump(false).
        set state["orbit_abandoned"] to true.
        set state["suppress_orbit"] to true.
        set state["aed_started"] to time:seconds.
        set state["aed_last_update"] to time:seconds.
        set state["aed_aoa"] to dap["aoa"]["smooth_target_aoa"].
        set state["aed_bank"] to dap["aoa"]["smooth_target_bank"].
        set state["aed_throttle"] to dapthrottle.
        set state["aed_capture_since"] to -1.
        set state["aed_assist_time"] to 0.
        set state["aed_assist_dv"] to 0.
        set state["aed_assist_lf"] to 0.
        set state["aed_assist_ox"] to 0.
        set state["aed_last_lf"] to ship:liquidfuel.
        set state["aed_last_ox"] to ship:oxidizer.
        set state["aed_last_search"] to time:seconds.
        set state["aed_intent"] to "ascending_coast".
        set state["aed_committed"] to false.
        recovery_set_isolated("rapier",false).
        recovery_set_isolated("nerv",true).
        togglerapiermode("CLOSED").
        rapierson().
        nervsoff().
        recovery_apply_limits().
        local power is recovery_power(state,true,false).
        local assist is recovery_aed_assist(power,ship:liquidfuel,ship:oxidizer,
            state["lf_reserve"],state["ox_reserve"],cfg).
        set state["aed_assist_budget"] to assist.
        set state["aed_search"] to recovery_aed_search(current_simstate(),state["rejected_targets"],assist,cfg).
        recovery_phase(state,"select_runway").
    }
    local dt_aed is max(0,min(0.25,time:seconds-state["aed_last_update"])).
    set state["aed_last_update"] to time:seconds.
    set state["aed_assist_lf"] to state["aed_assist_lf"]+max(0,state["aed_last_lf"]-ship:liquidfuel).
    set state["aed_assist_ox"] to state["aed_assist_ox"]+max(0,state["aed_last_ox"]-ship:oxidizer).
    set state["aed_last_lf"] to ship:liquidfuel.
    set state["aed_last_ox"] to ship:oxidizer.
    local power is recovery_power(state,true,false).
    if state["aed_throttle"] > 0 {
        set state["aed_assist_time"] to state["aed_assist_time"]+dt_aed.
        set state["aed_assist_dv"] to state["aed_assist_dv"]+
            power["acceleration"]*state["aed_throttle"]*dt_aed.
    }
    if power["healthy_rapiers"] = 0 or power["thrust"] <= 0 {
        recovery_transition(state,"edr","aed_rapier_unavailable"). return state.
    }
    if time:seconds-state["aed_started"] > cfg["maximum_duration"] {
        recovery_transition(state,"contingency_abort","aed_timeout"). return state.
    }
    local desired_aoa is cfg["low_drag_aoa"].
    local desired_bank is 0.
    local throttle_aed is 0.
    set dap["dap_mode"] to "auto".
    set dap["str_mode"] to "aoa".
    set dap["aoa"]["base_pitch"] to 0.
    // During a search preserve range and a climbing flight path. The predictor
    // advances only a small number of bounded steps after these live commands.
    if ship:verticalspeed > 5 { set desired_aoa to max(0,min(10,state["aed_aoa"])). }
    if state["target"]["selected"] {
        local target is state["target"].
        local intake is target["capture_interface"].
        local distance_aed is calcdistance_m(ship:geoposition,intake["target_latlng"]).
        local course_error is normalized_heading_error(heading_to_target(intake["target_latlng"]),compass_for_prograde()).
        set desired_bank to max(-cfg["maximum_bank"],min(cfg["maximum_bank"],-0.6*course_error)).
        local gravity_aed is ship:body:mu/ship:body:radius^2.
        local energy_aed is recovery_aed_energy(ship:altitude,ship:airspeed,
            intake["target_altitude"],cfg["capture_speed"],gravity_aed).
        local terminal_actual is ship:altitude-target["altitude"]+ship:airspeed^2/(2*gravity_aed).
        local terminal_margin is terminal_actual-intake["terminal_required"].
        set state["aed_energy"] to energy_aed.
        set state["aed_energy_margin"] to terminal_margin.
        set state["aed_distance"] to distance_aed.
        set state["aed_heading_error"] to course_error.
        local intent is state["aed_intent"].
        if ship:verticalspeed > 5 {
            set intent to "ascending_coast".
        } else if energy_aed > 2200 and ship:altitude < 35000 and ship:q > 0.1 {
            set intent to "energy_dissipation".
        } else if energy_aed < -500 or terminal_margin < -500 {
            set intent to "powered_extension".
        } else if intent <> "energy_dissipation" or energy_aed < 1200 {
            set intent to "descending_capture".
        }
        if intent <> state["aed_intent"] {
            set state["aed_intent"] to intent.
            flight_log_event("aed_intent","intent="+intent+"|energy="+round(energy_aed,1)).
        }
        if intent = "energy_dissipation" { set desired_aoa to cfg["drag_aoa"]. }
        if intent = "powered_extension" {
            set desired_aoa to 4.
            local assist is state["aed_assist_budget"].
            local assist_available is state["aed_assist_time"] < assist["time"] and
                state["aed_assist_dv"] < assist["dv"] and
                state["aed_assist_lf"] < assist["lf"] and
                (assist["ox"] <= 0 or state["aed_assist_ox"] < assist["ox"]) and
                ship:liquidfuel > state["lf_reserve"] and ship:oxidizer > state["ox_reserve"].
            if assist_available {
                set throttle_aed to cfg["assist_throttle"].
            } else {
                set state["rejected_targets"][target["location"]+"_"+target["runway_num"]] to "assist_budget_exhausted".
                set state["target"] to lex("selected",false).
                recovery_phase(state,"select_runway").
                set state["aed_search"] to recovery_aed_search(current_simstate(),state["rejected_targets"],
                    lex("time",0,"dv",0),cfg).
                set state["aed_last_search"] to time:seconds.
                flight_log_event("aed_target_rejected","reason=assist_budget_exhausted").
            }
        }
        // No high-speed TEAM holding turn: all capture conditions must hold
        // continuously before control leaves Orbit Main.
        local clearance_aed is ship:altitude-max(0,ship:geoposition:terrainheight).
        local gate is recovery_aed_capture_gate(distance_aed,ship:altitude-intake["target_altitude"],
            ship:airspeed,ship:verticalspeed,
            normalized_heading_error(target["heading"],compass_for_prograde()),roll_for(),
            clearance_aed,terminal_margin,0,cfg).
        if gate["valid"] {
            if state["aed_capture_since"] < 0 { set state["aed_capture_since"] to time:seconds. }
            recovery_phase(state,"capture").
            if time:seconds-state["aed_capture_since"] >= cfg["capture_settle"] {
                set state["aed_committed"] to true.
                set state["capture_interface"] to intake.
                set state["handoff_phase"] to "TEAM".
                set state["handoff_ready"] to true.
                recovery_phase(state,"TEAM").
            }
        } else {
            set state["aed_capture_since"] to -1.
            if state["phase"] = "capture" { recovery_phase(state,"energy_transit"). }
        }
        // Refresh forecasts in transit without interrupting the continuous
        // control law or replacing a target until the prior one is rejected.
        if not state["aed_committed"] and state["phase"] <> "capture" and time:seconds-state["aed_last_search"] > cfg["prediction_refresh"] and
            state["aed_search"]["complete"] {
            set state["aed_search"] to recovery_aed_search(current_simstate(),state["rejected_targets"],
                lex("time",max(0,state["aed_assist_budget"]["time"]-state["aed_assist_time"]),
                    "dv",max(0,state["aed_assist_budget"]["dv"]-state["aed_assist_dv"])),cfg,state["target"]).
            set state["aed_last_search"] to time:seconds.
        }
    }
    // Envelope DAP still owns q/thermal/terrain/stall protection. AED command
    // continuity uses actual/smoothed entry values instead of an abrupt reset.
    if ship:altitude > 35000 { set desired_aoa to min(desired_aoa,cfg["thin_aoa"]). }
    set state["aed_aoa"] to state["aed_aoa"]+max(-3*dt_aed,min(3*dt_aed,desired_aoa-state["aed_aoa"])).
    set state["aed_bank"] to state["aed_bank"]+max(-10*dt_aed,min(10*dt_aed,desired_bank-state["aed_bank"])).
    set dap["aoa"]["target_aoa"] to state["aed_aoa"].
    set dap["aoa"]["target_bank"] to state["aed_bank"].
    set state["aed_throttle"] to state["aed_throttle"]+
        max(-0.5*dt_aed,min(0.5*dt_aed,throttle_aed-state["aed_throttle"])).
    if ship:liquidfuel <= state["lf_reserve"] or ship:oxidizer <= state["ox_reserve"] or
        state["aed_assist_time"] >= state["aed_assist_budget"]["time"] or
        state["aed_assist_dv"] >= state["aed_assist_budget"]["dv"] { set state["aed_throttle"] to 0. }
    set dapthrottle to state["aed_throttle"].
    recovery_apply_limits().
    if not state["aed_search"]["complete"] {
        set state["aed_search"] to recovery_aed_search_step(state["aed_search"],cfg).
        if state["aed_search"]["complete"] {
            for rejected_key in state["aed_search"]["rejections"]:keys {
                flight_log_event("aed_candidate_rejected","target="+rejected_key+
                    "|reason="+state["aed_search"]["rejections"][rejected_key]).
            }
            if state["target"]["selected"] and not state["aed_committed"] and state["phase"] <> "capture" {
                local target_key is state["target"]["location"]+"_"+state["target"]["runway_num"].
                local retained_feasible is false.
                for reevaluated in state["aed_search"]["candidates"] {
                    if reevaluated:haskey("screen") and reevaluated["location"]+"_"+reevaluated["runway_num"] = target_key and
                        reevaluated["screen"]["feasible"] { set retained_feasible to true. }
                }
                if not retained_feasible and state["aed_search"]["rejections"]:haskey(target_key) {
                    set state["rejected_targets"][target_key] to "live_prediction_rejected".
                    flight_log_event("aed_target_rejected","target="+target_key+"|reason=live_prediction_rejected").
                    set state["target"] to lex("selected",false).
                    set state["aed_capture_since"] to -1.
                }
            }
            if not state["target"]["selected"] {
                if state["aed_search"]["best"]["selected"] {
                    set state["target"] to state["aed_search"]["best"].
                    recovery_phase(state,"energy_transit").
                    flight_log_event("aed_runway_selected","location="+state["target"]["location"]+
                        "|runway="+state["target"]["runway_num"]+
                        "|altitude="+state["target"]["capture_interface"]["target_altitude"]+
                        "|energy_margin="+state["target"]["screen"]["energy_margin"]).
                } else {
                    recovery_transition(state,"contingency_abort","aed_no_converged_runway").
                }
            }
        }
    }
    return state.
}

function recovery_update {
    parameter state.
        local failures_before is state["scenario"]["rapiers_out"]+state["scenario"]["nervs_out"].
        set state to abort_refresh_state(state).
        recovery_apply_limits().
        local failures_after is state["scenario"]["rapiers_out"]+state["scenario"]["nervs_out"].
        if failures_after > failures_before {
            // An engine failure abandons the original mission orbit and rendezvous.
            if state:haskey("nominal_insertion") { state:remove("nominal_insertion"). }
            local selected_mode is recovery_select_mode(state,state["current_ascent_phase"]).
            if selected_mode <> state["mode"] {
                recovery_transition(state,selected_mode,"new_engine_failure").
            }
        }
        // Snapshot ownership: a transfer never executes the old controller
        // afterward, and a same-mode failure gets one explicit reassessment.
        local active_recovery_mode is state["mode"].
        if active_recovery_mode = "ato" {
            if failures_after > failures_before and state["mode"] = "ato" {
                recovery_phase(state,"initialize").
            }
            recovery_ato_update(state).
        } else if active_recovery_mode = "aed" { recovery_aed_update(state). }
        else if active_recovery_mode = "edr" { recovery_edr_update(state). }
    return state.
}

set CONFIG:IPU to 2000.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/contingency.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/recovery_orbit.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/recovery_aed.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/terminal_route.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/rendezvous.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_aerosim.ks").
RUNONCEPATH("0:/Libraries/lib_location_constants.ks").

global abort_state is lex("active",false).
if defined recovery_engines { unset recovery_engines. }
set step to "launch".
set running to true.
clearScreen.  
                
set nervs to false.
set rapier_mode to "air".
set rapiers to false.
set circ_done to false.
set Lastest_status to "launching".
set orbitcalc to false.
local ascent is AVES["Ascent"].
local launch_heading is AVES["Ascent"]["default_launch_heading"].
local runway_heading is AVES["Ascent"]["default_launch_heading"].
local runway_altitude is 0.
local liftoff_altitude is ascent["liftoff_height_above_runway"] + runway_altitude.
local rotate_altitude is ascent["rotate_height_above_runway"] + runway_altitude.
local previous_speed is 0.
local speed_trend is 0.
local ascent_orbit_complete is false.


local Target_orbit is create_assent_gui().
set TargetPeriapsis to Target_orbit["Periapsis"].
set TargetApoapsis to Target_orbit["Apoapsis"].
set TargetInclination to Target_orbit["inclination"].
local ascent_rendezvous_target is 0.
local ascent_rendezvous_enabled is Target_orbit["RendezvousTarget"] <> "None".
if ascent_rendezvous_enabled {
    set ascent_rendezvous_target to Vessel(Target_orbit["RendezvousTarget"]).
    if ascent_rendezvous_target:body = ship:body and ascent_rendezvous_target:orbit:eccentricity < 1 {
        // The selected vessel's orbit is the insertion orbit.  The wait below
        // selects the phase; the same-body rendezvous routine removes the
        // remaining dispersions and performs the docking handoff.
        set TargetPeriapsis to ascent_rendezvous_target:orbit:periapsis.
        set TargetApoapsis to ascent_rendezvous_target:orbit:apoapsis.
        set TargetInclination to ascent_rendezvous_target:orbit:inclination.
    } else {
        set ascent_rendezvous_enabled to false.
    }
}
flight_log_begin("ascent").
flight_log_event("orbit_target","periapsis=" + TargetPeriapsis + "|apoapsis=" + TargetApoapsis + "|inclination=" + TargetInclination).
if ascent_rendezvous_enabled {
    flight_log_event("ascent_rendezvous_target","name="+ascent_rendezvous_target:name+"|body="+ship:body:name+"|insertion_periapsis="+TargetPeriapsis+"|insertion_apoapsis="+TargetApoapsis).
}

check_inputs().

reset_sys().
dap:setup().
print("1").
local active_runway is find_active_runway().
print("2").
if active_runway["heading"] >= 0 {
    set runway_heading to active_runway["heading"].
}
if active_runway["altitude"] >= 0 {
    set runway_altitude to active_runway["altitude"].
    set liftoff_altitude to runway_altitude + ascent["liftoff_height_above_runway"].
    set rotate_altitude to runway_altitude + ascent["rotate_height_above_runway"].
}
if active_runway["heading"] >= 0 {
    flight_log_set_runway(active_runway["location"],active_runway["runway_num"],active_runway["start"],active_runway["end"],active_runway["heading"],active_runway["altitude"]).
}
set dap["aerostr"]["turn_heading"] to runway_heading.
set launch_heading to calculate_heading(TargetInclination, ship:latitude).
if launch_heading < 0 {
    set launch_heading to ascent["inclination_heading_fallback"].
}
set previous_speed to ship:airspeed.
set t0 to -1.
local takeoff_start_position is ship:geoposition.
local takeoff_estimate is assess_takeoff_runway(active_runway).
local takeoff_evidence is lex("released",false,"rotated",false,"airborne",false,
    "screen_reached",false,"next_sample",0,"base_altitude_m",ship:altitude).
print("Takeoff estimate: " + takeoff_estimate["reason"]).
print("Runway requirement " + round(takeoff_estimate["required_runway_m"]) + " m; available " +
    round(takeoff_estimate["remaining_runway_m"]) + " m; departure to 35m " + round(takeoff_estimate["required_departure_m"]) + " m").
flight_log_takeoff_prediction(takeoff_estimate,"preflight").
local v1_announced is false.
local abort_info is lex().
set dap_mode to "auto".
set dap["str_mode"] to "aerostr".
if ascent_rendezvous_enabled { set step to "rendezvous_window". }
print("3").
global recovery_nominal_cutoff is false.
recovery_register_engines().
rapierson().
until running = false{
    update_readouts().
    dap:update().
    update_assent_gui().

    if ship:altitude < ascent["display_altitude"] and ship:airspeed < ascent["display_speed"]{
        set console_mode to "assent".
    }else{
         set console_mode to "Data".
    }
    set speed_trend to ship:airspeed - previous_speed.
    set previous_speed to ship:airspeed.

    if step = "rendezvous_window" {
        // Predict the target's location at nominal insertion time. Holding
        // here keeps the vehicle on the runway until the target crosses the
        // launch-site corridor, instead of departing at an arbitrary phase.
        local nominal_insertion_time is time:seconds+ascent["rendezvous_nominal_insertion_time"].
        local predicted_target_radius is positionat(ascent_rendezvous_target,nominal_insertion_time)-ship:body:position.
        local launch_site_radius is ship:position-ship:body:position.
        local launch_phase_error is vang(predicted_target_radius,launch_site_radius).
        brakes on.
        set dapthrottle to 0.
        set Lastest_status to "Waiting for rendezvous launch window ("+round(launch_phase_error,1)+" deg)".
        flight_log_capture_rendezvous(ascent_rendezvous_target,"launch_window",0,false).
        if launch_phase_error <= ascent["rendezvous_window_angle"] {
            brakes off.
            set step to "launch".
            set Lastest_status to "Rendezvous launch window open".
            flight_log_event("ascent_rendezvous_window","phase_error_deg="+round(launch_phase_error,2)+"|nominal_insertion_ut="+round(nominal_insertion_time,1)).
        }
    }
    if step = "launch"{ 
        update_team_dap_gui().
         
        if ship:altitude < liftoff_altitude{
            set dap["aerostr"]["targetPitch"] to 0.
            set dap["aerostr"]["turn_heading"] to runway_heading.
            
            set dapthrottle to 1.
        }   
        if ship:thrust > AVES["StationaryThrottle"]{
            brakes off.
            if t0 = -1{
                set t0 to time:seconds.
                set takeoff_start_position to ship:geoposition.
                set takeoff_evidence["base_altitude_m"] to ship:altitude.
                set takeoff_estimate to assess_takeoff_runway(active_runway).
                flight_log_takeoff_prediction(takeoff_estimate,"brake_release").
            }
        }

        // Once the brakes have released, keep monitoring engine health even
        // if an engine loss pulls total thrust back below StationaryThrottle.
        // The threshold is an arming condition, not an abort-monitor gate.
        if t0 <> -1 {
            // V1 is the last point at which the empirical runway-stop model
            // permits a rejected takeoff.  Beyond it, an engine failure uses
            // the RTLS path, which can first fly the vehicle clear of the
            // runway before turning back.
            if not v1_announced {
                local v1_check is runway_abort_feasibility(takeoff_start_position,active_runway["end"]).
                if not v1_check["permitted"] {
                    set v1_announced to true.
                    set Lastest_status to "V1 - RTLS preferred".
                    flight_log_event("v1","rolled_m=" + round(v1_check["roll_distance_m"]) + "|required_m=" + round(v1_check["required_stop_distance_m"]) + "|remaining_m=" + round(v1_check["runway_remaining_m"]) + "|model_valid=" + v1_check["model_valid"] + "|preferred_abort=rtls").
                }
            }
            if ship:airspeed > AVES["Speed"]["Rotate"]{
                set step to "rotate".
                set Lastest_status to "rotating".
                Set warpmode to "physics".
            }
            set abort_info to check_abort(step).
            if abort_info["abort"]{
                set abort_state to create_abort_state(abort_info,step,active_runway).
                if abort_state["mode"] = "runway_abort" {
                    local runway_abort_check is runway_abort_feasibility(takeoff_start_position,active_runway["end"]).
                    set abort_state["runway_stop"] to runway_abort_check.
                    if not runway_abort_check["permitted"] {
                        set abort_state["mode"] to "rtls".
                        flight_log_event("runway_abort_rejected","rolled_m=" + round(runway_abort_check["roll_distance_m"]) + "|required_m=" + round(runway_abort_check["required_stop_distance_m"]) + "|remaining_m=" + round(runway_abort_check["runway_remaining_m"])).
                    }
                }
                set step to abort_state["mode"].
            }
        }

        
    if step = "launch" and ship:altitude > liftoff_altitude and ship:airspeed <= AVES["Speed"]["Rotate"]{
        set Lastest_status to "not in lift off conditon".
        set step to "end".
    }
    }
    if step = "rotate"{
        update_team_dap_gui().
        set dap["aerostr"]["targetPitch"] to ascent["rotate_pitch"].
        set dap["aerostr"]["turn_pitch"] to ascent["rotate_pitch"].
        set dap["aerostr"]["turn_heading"] to runway_heading.
        //decide_abort_mode().
        set abort_info to check_abort(step).
        if abort_info["abort"]{
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        }
        if step = "rotate" and ship:altitude > rotate_altitude{
            gear off.
            set warp to 0.
            set assent_heading to launch_heading.
            local runway_to_ascent_error is abs(normalized_heading_error(launch_heading,runway_heading)).
            if runway_to_ascent_error > ascent["runway_alignment_heading_threshold"] {
                set step to "ascent_alignment".
                set Lastest_status to "aligning ascent heading".
                set dap["str_mode"] to "aoa".
            }else{
                set step to "speed_build".
                set dap["str_mode"] to "aerostr".
            }
        }
    }
    if step = "ascent_alignment"{
        update_team_dap_gui().
        set assent_heading to calculate_heading(TargetInclination, ship:latitude).
        if assent_heading < 0 {
            set assent_heading to ascent["inclination_heading_fallback"].
        }

        // AoA steering turns through bank.  A positive heading error is a turn
        // to the right, which uses a negative bank in the kOS steering convention.
        local alignment_heading_error is normalized_heading_error(assent_heading,compass_for_prograde()).
        local alignment_bank is min(ascent["runway_alignment_bank"],max(10,abs(alignment_heading_error) * 2)).
        set dap["str_mode"] to "aoa".
        set dap["aoa"]["target_aoa"] to ascent["runway_alignment_target_aoa"].
        if alignment_heading_error > 0 {
            set dap["aoa"]["target_bank"] to -alignment_bank.
        }else{
            set dap["aoa"]["target_bank"] to alignment_bank.
        }

        // Do not build speed while making the initial cross-runway turn.
        // Ramp from full to idle between 200 and 300 m/s, rather than
        // abruptly cutting thrust, to hold the turn below the speed limit.
        local throttle_ramp_width is ascent["runway_alignment_speed_limit"] - ascent["runway_alignment_throttle_ramp_start"].
        set dapthrottle to max(0,min(1,(ascent["runway_alignment_speed_limit"] - ship:airspeed) / throttle_ramp_width)).

        set abort_info to check_abort(step).
        if abort_info["abort"]{
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        }
        if step = "ascent_alignment" and abs(alignment_heading_error) <= ascent["runway_alignment_completion_tolerance"] {
            set dap["aoa"]["target_bank"] to 0.
            set dapthrottle to 1.
            set dap["str_mode"] to "aerostr".
            set step to "speed_build".
            set Lastest_status to "ascent heading aligned".
        }
    }
    if step = "speed_build"{
        update_team_dap_gui().
        set assent_heading to calculate_heading(TargetInclination, ship:latitude).  
        set dap["aerostr"]["turn_heading"] to assent_heading.
        set dap["aerostr"]["targetPitch"] to ascent["shallow_climb_pitch"].
        set dap["aerostr"]["turn_pitch"] to ascent["shallow_climb_pitch"].
        set abort_info to check_abort(step).
        if abort_info["abort"]{
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        }
        if step = "speed_build" and (ship:airspeed >= ascent["speed_build_target"] or ship:altitude >= ascent["climb_altitude"]) {
            set step to "high_altitude_climb".
            set Lastest_status to "speed target reached".
        }
    }
    if step = "high_altitude_climb"{
        update_team_dap_gui().
        set abort_info to check_abort(step).
        if abort_info["abort"]{
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        }
        set dap["str_mode"] to "aerostr".
        set assent_heading to calculate_heading(TargetInclination, ship:latitude).  
        set dap["aerostr"]["turn_heading"] to assent_heading.
        //set dap["aerostr"]["targetPitch"] to ascent["climb_pitch"].
        //calc time to alt climb alt
        local climb_time is time_to_alt(ship:altitude,ship:verticalspeed,ascent["climb_altitude"]).
        //time to speed
        //local accel_v is ship:sensors:acc.

        //local accel_in_prograde is vectorDotProduct(accel_v,ship:velocity:surface)/accel_v:mag.

        local accel_in_prograde is ship:sensors:acc:mag.
        local speed_time is time_to_alt(ship:airspeed,accel_in_prograde,ascent["climb_target_speed"]).
        
        // calculate the prograde pitch needed to make the altitude gain and speed gain finish at the same time.
        // assume the same constant acceleration over the speed build window, and model the vertical climb as the
        // prograde path distance times sin(pitch). this gives a target pitch in degrees so the vessel reaches
        // climb_altitude at the same time it reaches climb_target_speed.
        local alt_to_climb is ascent["climb_altitude"] - ship:altitude.
        local avg_speed is (ship:airspeed + ascent["climb_target_speed"]) / 2.
        local tvs is alt_to_climb / speed_time.
        local pfp_tgt is arcsin(tvs / avg_speed).
        local aoa_ascent is calc_aoa().
        local pitch_tgt is pfp_tgt + aoa_ascent.
        if pitch_tgt > dap["aerostr"]["turn_pitch"]{
            if pitch_tgt > dap["aerostr"]["turn_pitch"] + 0.1{
                set dap["aerostr"]["turn_pitch"] to dap["aerostr"]["turn_pitch"] + 0.1.
                
            }else{
                set dap["aerostr"]["turn_pitch"] to pitch_tgt.
            }
        }else if pitch_tgt < dap["aerostr"]["turn_pitch"]{
            if pitch_tgt < dap["aerostr"]["targetPitch"] - 0.1{
                set dap["aerostr"]["turn_pitch"] to dap["aerostr"]["turn_pitch"] - 0.1.
            }else{
                set dap["aerostr"]["turn_pitch"] to pitch_tgt.
            }
        }
        //set dap["aerostr"]["targetPitch"] to pitch_tgt.
        if step = "high_altitude_climb" and ship:altitude >= ascent["climb_altitude"] {
            nervson().
            set step to "nerv_assist".
            set Lastest_status to "nervs on".
        }
    }
    if step = "nerv_assist"{
        update_team_dap_gui().
        set abort_info to check_abort(step).
        if abort_info["abort"] {
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        } else {
            set dap["str_mode"] to "aerostr".
            set assent_heading to calculate_heading(TargetInclination, ship:latitude).
            set dap["aerostr"]["turn_heading"] to assent_heading.
            set dap["aerostr"]["turn_pitch"] to ascent["nerv_pitch"].
            if ship:verticalspeed <= ascent["vertical_speed_recovery_threshold"] {
                set dap["aerostr"]["turn_pitch"] to ascent["nerv_pitch"] + ascent["vertical_speed_recovery_pitch"].
            }
            if step = "nerv_assist" and speed_trend <= ascent["speed_gain_threshold"] and ship:altitude >= ascent["closed_cycle_min_altitude"] {
                set step to "closed_cycle_climb".
                set Lastest_status to "transitioning to closed cycle".
            }
        }
    }
    if step = "closed_cycle_climb"{
            set abort_info to check_abort(step).
            if abort_info["abort"] {
                set abort_state to create_abort_state(abort_info,step,active_runway).
                set step to abort_state["mode"].
            } else {
                togglerapiermode("CLOSED").
                update_team_dap_gui().
                set Lastest_status to "rapiers in closed cycle".
                set dap["str_mode"] to "aerostr".
                set assent_heading to calculate_heading(TargetInclination, ship:latitude).
                set dap["aerostr"]["turn_heading"] to assent_heading.
                if dap["aerostr"]["turn_pitch"] < ascent["closed_cycle_pitch_max"]{
                    set dap["aerostr"]["turn_pitch"] to dap["aerostr"]["turn_pitch"] + ascent["closed_cycle_pitch_rate"].
                }else{
                    set warp to 1.
                }
                rcs on.
                if step = "closed_cycle_climb" and ship:apoapsis > ascent["rapier_cutoff_apoapsis"] {
                    set recovery_nominal_cutoff to true.
                    rapiersoff().
                    set dap["aerostr"]["turn_pitch"] to ascent["apoapsis_build_pitch"].
                    set step to "apoapsis_build".
                    set Lastest_status to "nerv apoapsis build".
                }
            }
    }
    if step = "apoapsis_build"{
        update_team_dap_gui().
        set abort_info to check_abort(step).
        if abort_info["abort"] {
            set abort_state to create_abort_state(abort_info,step,active_runway).
            set step to abort_state["mode"].
        } else {
            set dap["str_mode"] to "aerostr".
            set dap["aerostr"]["turn_heading"] to assent_heading.
            set assent_heading to calculate_heading(TargetInclination, ship:latitude).
            set dap["aerostr"]["turn_pitch"] to ascent["apoapsis_build_pitch"].
            if ship:verticalspeed <= ascent["vertical_speed_recovery_threshold"] {
                set dap["aerostr"]["turn_pitch"] to ascent["apoapsis_build_pitch"] + ascent["vertical_speed_recovery_pitch"].
            }
            if step = "apoapsis_build" and ship:apoapsis > TargetApoapsis + ascent["apoapsis_margin"] {
                set Step to "circ".
                togglerapiermode("AIR").
                rapiersoff().
                set dapthrottle to 0.
                wait 2.
            }
        }
    }
    if ship:altitude > ascent["space_altitude"] and (step = "apoapsis_build" or step = "closed_cycle_climb"){
            lock dap_steering to prograde.
            set Lastest_status to "Space".
            ag5 on.
    }
    
    if step = "circ" {
        set abort_info to check_abort("circ").
        if abort_info["abort"] {
            set abort_state to create_abort_state(abort_info,"circ",active_runway).
            set step to abort_state["mode"].
        } else {
            // A zero-loss managed context uses the same insertion monitor.
            set abort_info to lex("abort",true,"mode","ato","scenario",lex("rapiers_out",0,"nervs_out",0),
                "engines",abort_engine_snapshot()).
            set abort_state to create_abort_state(abort_info,"circ",active_runway).
            set abort_state["nominal_cutoff"] to true.
            set abort_state["nominal_insertion"] to true.
            set abort_state["mode"] to "ato".
            set abort_state["phase"] to "coast_align".
            set abort_state["rapier_continue"] to false.
            set abort_state["orbit_started_ut"] to time:seconds.
            set abort_state["progress_ut"] to time:seconds.
            set abort_state["progress_value"] to ship:periapsis.
            set abort_state["last_update_ut"] to time:seconds.
            set step to "ato".
        }
    }
    if step = "runway_abort"{
        set abort_state to abort_refresh_state(abort_state).
        if abort_state["mode"] = "contingency_abort" {
            set step to "contingency_abort".
        } else {
        set Lastest_status to "Runway abort".
        brakes on.
        set dapthrottle to 0.
        rapiersoff().
        set dap["aerostr"]["targetPitch"] to AVES["Abort"]["RunwayStop"]["command_pitch"].
        if ship:airspeed < AVES["Abort"]["RunwayStop"]["stop_speed"]{
            set Lastest_status to "abort complete".
            set abort_state["result"]["success"] to true.
            set abort_state["result"]["reason"] to "stopped_on_runway".
            set abort_state["active"] to false.
            set step to "end".
        }
        }
    }if step = "rtls"{
        set abort_state to abort_refresh_state(abort_state).
        if not(defined rtls_handoff_time){
            set rtls_handoff_time to 0.
        }
        if abort_state["mode"] = "contingency_abort" {
            set step to "contingency_abort".
        }else{
            local rtls_config is AVES["Abort"]["RTLS"].
            local rtls_policy is rtls_config[max(1,min(3,abort_state["scenario"]["rapiers_out"]))+"RO"].
            set abort_state["policy"] to lex(
                "use_nervs",rtls_policy["use_nervs"],"fuel_dump",rtls_policy["fuel_dump"],
                "target_mass",rtls_policy["target_mass"],"turn_bank",rtls_config["turn_bank"]
            ).
            if abort_state["phase"] = "initialize" {
                // Alignment may have ramped thrust to idle. RTLS owns thrust
                // from entry onward, including an already-airborne turnback.
                set dapthrottle to 1.
                set rtls_log_evidence to lex("phase","","active",true,"next_sample",0).
                set abort_state["target"] to lex(
                    "selected",true,"location",active_runway["Location"],"runway_num",active_runway["runway_num"],
                    "start",active_runway["start"],"end",active_runway["end"],"heading",active_runway["heading"],
                    "altitude",active_runway["altitude"],"distance_m",calcdistance_m(ship:geoposition,active_runway["start"]),"score",0
                ).
                // An RTLS chosen during launch, or just after the rotate
                // command, must first fly away from the runway.  Turning on
                // the ground is neither controllable nor recoverable.
                if ship:altitude <= liftoff_altitude {
                    set abort_state["phase"] to "takeoff_escape".
                }else{
                    set abort_state["phase"] to "turnback".
                }
                set abort_state["phase_entered"] to time:seconds.
            }
            set Lastest_status to "Abort RTLS " + abort_state["submode"] + " | " + abort_state["phase"].
            rapierson().
            if abort_state["policy"]["use_nervs"] { nervson(). }else{ nervsoff(). }
            local oxidizer_available is false.
            for res in ship:resources {
                if res:name = "Oxidizer" and res:amount > 0 { set oxidizer_available to true. }
            }
            if oxidizer_available { togglerapiermode("closed"). }else{ togglerapiermode("air"). }
            abort_set_fuel_dump(abort_state["policy"]["fuel_dump"] and ship:mass > abort_state["policy"]["target_mass"]).
            if abort_state["phase"] = "takeoff_escape" {
                // Use the ordinary takeoff controls until clearly airborne.
                // This covers an RTLS selected late in launch and an engine
                // failure immediately after rotation but before liftoff.
                // Keep the RTLS policy selected above: healthy RAPIERs are
                // in closed cycle when oxidizer is available, NERVs follow
                // the 1RO/2RO/3RO policy, and fuel dumping is already active.
                // A severe RAPIER-out case needs that full configured thrust
                // before it can safely lift off.
                rapierson().
                brakes off.
                gear on.
                set dap["str_mode"] to "aerostr".
                set dapthrottle to 1.
                set dap["aerostr"]["turn_heading"] to runway_heading.
                set dap["aerostr"]["targetPitch"] to ascent["rotate_pitch"].
                set dap["aerostr"]["turn_pitch"] to ascent["rotate_pitch"].
                if ship:altitude > liftoff_altitude {
                    set abort_state["phase"] to "turnback".
                    set abort_state["phase_entered"] to time:seconds.
                }
            }else if abort_state["phase"]= "turnback"{
                if calcdistance_m(ship:geoposition,active_runway["end"]) > rtls_config["gear_retract_distance"] { gear off. }
                if ship:altitude > rotate_altitude {
                    set dap["aerostr"]["turn_pitch"] to calc_aoa() - pitch_for_prograde() + rtls_config["airborne_pitch_margin"].
                }else{
                    set dap["aerostr"]["turn_pitch"] to calc_aoa() - pitch_for_prograde() + rtls_config["low_alt_pitch_margin"].
                }
                if ship:airspeed > rtls_config["minimum_turn_speed"] {
                    set abort_state["phase"] to "turnback".
                    set dap["str_mode"] to "aoa".
                    local rtls_heading_error is normalized_heading_error(heading_to_target(active_runway["start"]),compass_for_prograde()).
                    if rtls_heading_error > 0 {
                        set dap["aoa"]["target_bank"] to -rtls_config["turn_bank"].
                    }else{
                        set dap["aoa"]["target_bank"] to rtls_config["turn_bank"].
                    }
                    // Climb through the turnaround and hand reentry a stable
                    // reciprocal departure, rather than handing off part-way
                    // through the turn based only on heading change.
                    set dap["aoa"]["target_aoa"] to max(rtls_config["turnback_climb_aoa"],max(rtls_config["target_aoa_min"],-pitch_for_prograde())).
                    if pitch_for_prograde() > rtls_config["turnback_max_prograde_pitch"] {
                        set dap["aoa"]["base_pitch"] to rtls_config["turnback_max_prograde_pitch"].
                    }else if ship:verticalspeed < 0{
                        set dap["aoa"]["base_pitch"] to ((ship:verticalspeed)*(-1))/2.
                    }else{
                        set dap["aoa"]["base_pitch"] to 0.
                    }
                    local reciprocal_heading is runway_heading + 180.
                    if reciprocal_heading >= 360 { set reciprocal_heading to reciprocal_heading - 360. }
                    local reciprocal_heading_error is abs(normalized_heading_error(reciprocal_heading,compass_for_prograde())).
                    local handoff_altitude is runway_altitude + rtls_config["handoff_minimum_altitude"].
                    if reciprocal_heading_error <= rtls_config["reciprocal_heading_tolerance"] and ship:altitude >= handoff_altitude and not abort_state["handoff"]["started"] {

                        set abort_state["phase"] to "handoff".
                        set abort_state["phase_entered"] to time:seconds.
                        set rtls_handoff_time to time:seconds.

                    }
                }else{
                    set dap["str_mode"] to "aerostr".
                }
            }else{
                //now phase is handoff
                if time:seconds - rtls_handoff_time < 4{
                    set dap["str_mode"] to "aerostr".
                    set dap["aerostr"]["turn_pitch"] to 5.
                    set dap["aerostr"]["turn_heading"] to compass_for_prograde().
                    set dap["aerostr"]["turn_roll"] to 0.

                }else{
                    set abort_state["handoff"]["started"] to true.
                    set dap["aoa"]["target_bank"] to 0.
                    set dap["aoa"]["target_aoa"] to 0.
                    set dap["aoa"]["base_pitch"] to 0.
                    set dap["str_mode"] to "aoa".
                    RUN "0:/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks"(lex(
                            "force",TRUE,"Location",active_runway["Location"],"Runway",active_runway["runway_num"],
                            "context",lex("mission","abort","abort_mode","rtls","preserve_propulsion",true,"allow_go_around",true)
                    )).
                    set abort_state["handoff"]["complete"] to true.
                    set abort_state["result"]["success"] to recovery_result["success"].
                    set abort_state["result"]["reason"] to recovery_result["reason"].
                    set abort_state["active"] to false.
                    set abort_state["phase"] to "complete".
                    set abort_state["phase_entered"] to time:seconds.
                    set step to "end".
                }    
            }
            flight_log_rtls_observe(abort_state,rtls_log_evidence).
        }
    }
    if step = "atr"{
        set abort_state to abort_refresh_state(abort_state).
        if abort_state["mode"] = "contingency_abort" {
            set step to "contingency_abort".
        }else{
            if not abort_state["target"]["selected"] {
                set abort_state["target"] to abort_select_runway().
                set abort_state["phase"] to "runway_selected".
            }
            if abort_state["target"]["selected"] and not abort_state["handoff"]["started"] {
                local atr_policy is AVES["Abort"]["RTLS"][max(1,min(3,abort_state["scenario"]["rapiers_out"]))+"RO"].
                set abort_state["policy"] to lex(
                    "use_nervs",atr_policy["use_nervs"],"fuel_dump",atr_policy["fuel_dump"],
                    "target_mass",atr_policy["target_mass"],"turn_bank",0
                ).
                abort_set_fuel_dump(abort_state["policy"]["fuel_dump"] and ship:mass > abort_state["policy"]["target_mass"]).
                set Lastest_status to "ATR " + abort_state["submode"] + " to " + abort_state["target"]["location"] + " " + abort_state["target"]["runway_num"].
                set abort_state["handoff"]["started"] to true.
                RUN "0:/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks"(lex(
                    "force",TRUE,"Location",abort_state["target"]["location"],"Runway",abort_state["target"]["runway_num"],
                    "context",lex("mission","abort","abort_mode","atr","preserve_propulsion",true,"allow_go_around",true)
                )).
                set abort_state["handoff"]["complete"] to true.
                set abort_state["result"]["success"] to recovery_result["success"].
                set abort_state["result"]["reason"] to recovery_result["reason"].
                set abort_state["active"] to false.
                set step to "end".
            }else if not abort_state["target"]["selected"] {
                set Lastest_status to "ATR: no runway inside geometric search range".
            }
        }
    }
    if step = "ato" or step = "aed" or step = "edr" {
        set abort_state to recovery_update(abort_state).
        set Lastest_status to abort_state["mode"]+": "+abort_state["phase"].
        if abort_state["active"] and abort_state:haskey("handoff_ready") and abort_state["handoff_ready"] {
            set abort_state["handoff"]["started"] to true.
            local handoff_context is lex("mission","abort","abort_mode",abort_state["mode"],
                "preserve_propulsion",true,"allow_go_around",true,"initial_phase",abort_state["handoff_phase"]).
            if abort_state:haskey("capture_interface") {
                set handoff_context["capture_interface"] to abort_state["capture_interface"].
            }
            flight_log_event("recovery_handoff","mode="+abort_state["mode"]+
                "|phase="+abort_state["handoff_phase"]+"|runway="+abort_state["target"]["location"]+
                "_"+abort_state["target"]["runway_num"]).
            runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks",lex("force",true,
                "Location",abort_state["target"]["location"],"Runway",abort_state["target"]["runway_num"],
                "context",handoff_context)).
            set abort_state["handoff"]["complete"] to true.
            recovery_finish(abort_state,recovery_result["reason"],recovery_result["success"],
                not recovery_result["success"]).
        }
        if not abort_state["active"] and abort_state["result"]["success"] and
           abort_state["mode"] = "ato" and abort_state:haskey("nominal_insertion") {
            set ascent_orbit_complete to true.
        }
    }
    if step = "contingency_abort"{
        set abort_state to abort_refresh_state(abort_state).
        contingency_update(abort_state).
        set Lastest_status to "Contingency: " + abort_state["phase"].
        if not abort_state["active"] {
            set Lastest_status to "Contingency: " + abort_state["result"]["reason"].
            set step to "end".
        }
    }
    if step = "end"{
        set running to false.
        //set Lastest_status to "ending".
        if abort_state:haskey("managed") and abort_state["managed"] or
           (abort_state:haskey("mode") and abort_state["mode"] = "contingency_abort") {
            // The contingency executive already secured or released controls.
            // reset_sys would re-enable engines/gear and overwrite pilot throttle.
        } else { reset_sys(). }
        set warp to 0.
        update_readouts().
        assent_gui:hide().
    }
    if t0 >= 0 and not takeoff_evidence["screen_reached"] {
        flight_log_takeoff_observe(takeoff_evidence,takeoff_estimate,takeoff_start_position,t0,step).
    }
    flight_log_tick("ascent",step,"").
    wait 0.
    //check_abort().
}
if ascent_rendezvous_enabled and ascent_orbit_complete {
    set Lastest_status to "Refining rendezvous for docking handoff".
    local ascent_rendezvous_result is rendezvous_same_body(ascent_rendezvous_target).
    if not ascent_rendezvous_result["docking_ready"] {
        set Lastest_status to "Rendezvous needs refinement: "+ascent_rendezvous_result["reason"].
    }
}
