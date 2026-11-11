// Incremental aerobraking preview. No flight controls or shared sim settings
// are changed here. The caller services DAP and cancellation before each step.
function aerobrake_prediction_tracker {
    return lex("bank",0,"aoa",0,"schedule",true,"changed_at",0,
        "reference_bank",0,"reference_aoa",0,"reference_schedule",true,
        "last_start",-1).
}

function aerobrake_prediction_due {
    parameter tracker, bank, aoa, schedule, now.
    if bank <> tracker["bank"] or aoa <> tracker["aoa"] or schedule <> tracker["schedule"] {
        set tracker["bank"] to bank.
        set tracker["aoa"] to aoa.
        set tracker["schedule"] to schedule.
        set tracker["changed_at"] to now.
    }
    local significant is abs(bank-tracker["reference_bank"]) > 10 or
        (not schedule and abs(aoa-tracker["reference_aoa"]) > 10) or
        schedule <> tracker["reference_schedule"].
    return tracker["last_start"] < 0 or now-tracker["last_start"] >= 20 or
        (significant and now-tracker["changed_at"] >= 2).
}

function aerobrake_prediction_begin {
    parameter tracker, bank, aoa, schedule, now.
    set tracker["last_start"] to now.
    set tracker["reference_bank"] to bank.
    set tracker["reference_aoa"] to aoa.
    set tracker["reference_schedule"] to schedule.
    return lex("status","running","state",current_simstate(),
        "bank",bank,"aoa",aoa,"schedule",schedule,"deadline",now+2,
        "steps",0,"entered",SHIP:altitude < SHIP:BODY:atm:height,
        "top",SHIP:BODY:atm:height,"mu",SHIP:BODY:mu,
        "radius",SHIP:BODY:radius,"angularvel",SHIP:BODY:angularvel,
        "apoapsis",0).
}

function aerobrake_prediction_matches {
    parameter job, bank, aoa, schedule.
    return job["bank"] = bank and job["schedule"] = schedule and
        (schedule or job["aoa"] = aoa).
}

function aerobrake_prediction_apsis {
    parameter job.
    local state is job["state"].
    local energy is state["velocity"]:sqrmagnitude/2-job["mu"]/state["position"]:mag.
    if energy >= 0 {
        set job["status"] to "escape (unbound)".
        return.
    }
    local momentum is vcrs(state["position"],state["velocity"]).
    local eccentricity is sqrt(max(0,1+2*energy*momentum:sqrmagnitude/job["mu"]^2)).
    set job["apoapsis"] to -job["mu"]/(2*energy)*(1+eccentricity)-job["radius"].
    set job["status"] to "complete".
}

function aerobrake_prediction_step {
    parameter job.
    if job["status"] <> "running" { return. }
    // Wall time, not game UT: lag and time warp must not extend this budget.
    if KUNIVERSE:REALTIME >= job["deadline"] {
        set job["status"] to "timed out". return.
    }
    // Independent finite horizon even if the clock stalls or no exit occurs.
    if job["steps"] >= 2000 {
        set job["status"] to "step limit". return.
    }
    local state is job["state"].
    if state["altitude"] <= 0 or state["surfvel"]:mag < 1 {
        set job["status"] to "impact / stopped". return.
    }
    local aoa is job["aoa"].
    if job["schedule"] { set aoa to AVES["EGAOA"](state["altitude"]). }
    local acceleration is gravitacc(state["position"],job["mu"]).
    if state["altitude"] < job["top"] {
        set job["entered"] to true.
        set acceleration to acceleration + sim_aeroaccel_load(
            state["position"],state["surfvel"],list(aoa,job["bank"]),job["radius"]).
    }
    // Exactly one 10-second step; never call the unbounded trajectory solvers.
    set state to update_simstate_total_accel(state,acceleration,10,job["angularvel"],job["radius"]).
    set job["state"] to state.
    set job["steps"] to job["steps"]+1.
    if KUNIVERSE:REALTIME >= job["deadline"] {
        set job["status"] to "timed out". return.
    }
    if state["altitude"] <= 0 {
        set job["status"] to "impact / stopped".
    } else if job["entered"] and state["altitude"] >= job["top"] and
        vdot(state["position"],state["velocity"]) > 0 {
        aerobrake_prediction_apsis(job).
    }
}

function aerobrake_release {
    // The outgoing assistant owns no control after this point. OFF's normal
    // pilot-throttle lock is also released until the next owner selects a mode.
    dap:set_off().
    unlock throttle.
    unlock steering.
    unlock dap_steering.
    set dapthrottle to 0.
    set dap["handoff"]["active"] to false.
    set dap["handoff"]["protected"] to false.
    set dap["envelope"]["restore_steering"] to false.
    set dap["l_t"] to time:seconds.
}
