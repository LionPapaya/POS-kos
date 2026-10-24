// Brake-release readiness only. This does not predict runway performance.
// Pure state transitions below are exercised through the real kOS runtime.
function takeoff_spool_init {
    parameter expected_ids, spool_config.
    return lex("expected_ids",expected_ids:copy,"config",spool_config,
        "status","waiting","reason","not_started","blocked_engine","",
        "started",-1,"stable_since",-1,"elapsed",0,"stable_elapsed",0,
        "anchors",lex(),"samples",lex(),"throttle_actual",0).
}

function takeoff_spool_engine_reason {
    parameter sample, spool_config.
    if not sample["ignition"] { return "engine_shutdown". }
    if sample["mode"] <> "AirBreathing" { return "wrong_engine_mode". }
    if sample["flameout"] { return "engine_flameout". }
    if sample["thrust_limit"] < 99.9 { return "engine_thrust_limited". }
    if sample["available_kn"] < spool_config["minimum_available_kn"] { return "no_available_thrust". }
    if sample["thrust_kn"] < spool_config["ready_fraction"]*sample["available_kn"] {
        return "engine_spooling".
    }
    return "ready".
}

function takeoff_spool_update {
    parameter spool_state, engine_samples, now_seconds, throttle_actual.
    if spool_state["status"] <> "waiting" { return spool_state. }
    local spool_config is spool_state["config"].
    if spool_state["started"] < 0 { set spool_state["started"] to now_seconds. }
    set spool_state["elapsed"] to now_seconds-spool_state["started"].
    set spool_state["samples"] to engine_samples.
    set spool_state["throttle_actual"] to throttle_actual.
    set spool_state["reason"] to "stabilizing".
    set spool_state["blocked_engine"] to "".
    local all_ready is true.
    if spool_state["expected_ids"]:length = 0 {
        set all_ready to false.
        set spool_state["reason"] to "no_engines".
    }
    for engine_id in spool_state["expected_ids"] {
        local engine_reason is "missing_engine".
        if engine_samples:haskey(engine_id) {
            set engine_reason to takeoff_spool_engine_reason(engine_samples[engine_id],spool_config).
            set engine_samples[engine_id]["reason"] to engine_reason.
        }
        if engine_reason <> "ready" and all_ready {
            set all_ready to false.
            set spool_state["reason"] to engine_reason.
            set spool_state["blocked_engine"] to engine_id.
        }
    }
    if throttle_actual < 0.99 and all_ready {
        set all_ready to false.
        set spool_state["reason"] to "waiting_full_throttle".
    }
    if not all_ready {
        set spool_state["stable_since"] to -1.
    } else {
        local stable_window is spool_state["stable_since"] >= 0.
        if stable_window {
            for engine_id in spool_state["expected_ids"] {
                local sample is engine_samples[engine_id].
                local anchor is spool_state["anchors"][engine_id].
                if abs(sample["thrust_kn"]-anchor["thrust_kn"]) >
                    spool_config["stability_fraction"]*anchor["thrust_kn"] or
                   abs(sample["available_kn"]-anchor["available_kn"]) >
                    spool_config["stability_fraction"]*anchor["available_kn"] {
                    set stable_window to false.
                }
            }
        }
        if not stable_window {
            set spool_state["stable_since"] to now_seconds.
            set spool_state["anchors"] to lex().
            for engine_id in spool_state["expected_ids"] {
                spool_state["anchors"]:add(engine_id,lex(
                    "thrust_kn",engine_samples[engine_id]["thrust_kn"],
                    "available_kn",engine_samples[engine_id]["available_kn"])).
            }
        }
    }
    set spool_state["stable_elapsed"] to 0.
    if spool_state["stable_since"] >= 0 {
        set spool_state["stable_elapsed"] to now_seconds-spool_state["stable_since"].
    }
    // Timeout wins at the boundary. Preserve the blocking reason for diagnosis.
    if spool_state["elapsed"] >= spool_config["timeout_seconds"] {
        set spool_state["status"] to "timeout".
    } else if all_ready and spool_state["stable_elapsed"] >= spool_config["stable_seconds"] {
        set spool_state["status"] to "ready".
        set spool_state["reason"] to "engines_ready".
    }
    return spool_state.
}

// Live sampling is separate from readiness math and from all predictors.
function takeoff_spool_samples {
    local engine_samples is lex().
    for engine_part in ship:partstitledpattern("R.A.P.I.E.R") {
        engine_samples:add("part_"+engine_part:uid,lex(
            "ignition",engine_part:ignition,"flameout",engine_part:flameout,
            "mode",engine_part:mode,"thrust_kn",engine_part:thrust,
            "available_kn",engine_part:availablethrust,"thrust_limit",engine_part:thrustlimit)).
    }
    return engine_samples.
}
