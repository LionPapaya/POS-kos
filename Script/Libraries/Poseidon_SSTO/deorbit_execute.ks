// Caller loads lib_vacstr, selects NERV, and grants exclusive control ownership.
// No staging, engine selection or warp. Failed nodes remain available for review.
function deorbit_execute_guard {
    parameter sample.
    if sample["cancelled"] { return "cancelled". }
    if not sample["owned"] { return "node_lost". }
    if sample["edited"] { return "node_edited". }
    if sample["available"] <= 0 { return "no_thrust". }
    if sample["fuel"] <= 0 { return "fuel_exhausted". }
    if sample["elapsed"] > sample["deadline"] { return "timeout". }
    if sample["burning"] and sample["stalled"] > 5 { return "no_progress". }
    if sample["burning"] and sample["unpowered"] > 2 { return "lost_thrust". }
    return "".
}

function deorbit_execute {
    parameter maneuver.
    lock throttle to 0.
    set ship:control:pilotmainthrottle to 0.
    local remaining_dv is -1.
    local reason is "node_lost".
    local owned is false.
    if hasnode { set owned to nextnode = maneuver. }
    if not owned {
        flight_log_event("deorbit_execute_return","success=false|reason=node_lost|remaining_dv=-1").
        return lex("success",false,"reason",reason,"remaining_dv",remaining_dv).
    }
    set remaining_dv to maneuver:deltav:mag.
    local node_ut is maneuver:time.
    local node_prograde is maneuver:prograde.
    local node_normal is maneuver:normal.
    local node_radial is maneuver:radialout.
    local started_ut is time:seconds.
    local steering_vector is maneuver:deltav.
    local initial_step is "".
    if defined step { set initial_step to step. }
    local half_time is 0.
    local duration is 0.
    set reason to "".
    if ship:availablethrust <= 0 or ship_isp() <= 0 { set reason to "no_thrust". }
    if reason = "" {
        // half_burn_time uses maxThrust; correct for selected/thrust-limited engines.
        set half_time to half_burn_time(maneuver)*ship:maxthrust/ship:availablethrust.
        set duration to calculate_burn_time(remaining_dv,ship_isp(),ship:availablethrust).
        if duration <= 0 or duration > 600 { set reason to "invalid_duration". }
        if maneuver:eta > 3600 { set reason to "excessive_coast". }
        if maneuver:eta < half_time+10 { set reason to "insufficient_lead_time". }
        // NERV consumes LF only; resource mass is 0.005 tonnes per unit.
        local required_fuel is ship:availablethrust/(ship_isp()*constant:g0)*duration/0.005.
        if ship:liquidfuel < required_fuel*1.02 { set reason to "insufficient_fuel". }
    }
    local evidence is lex("phase","aligning","next_sample",0,"remaining_dv",remaining_dv,"burn_seen",false).
    local burning is false.
    local burn_started is -1.
    local progress_ut is time:seconds.
    local best_dv is remaining_dv.
    local powered_ut is time:seconds.
    local burn_command is 0.
    local deadline is maneuver:eta+duration*2+30.
    flight_log_event("deorbit_execute_start","dv="+remaining_dv+"|half_burn_s="+half_time+"|duration_s="+duration).
    if reason = "" {
        sas off.
        lock steering to steering_vector.
    }
    until reason <> "" {
        set owned to false.
        if hasnode { set owned to nextnode = maneuver. }
        local cancelled is false.
        if defined abort_flag { if abort_flag { set cancelled to true. } }
        if defined running { if not running { set cancelled to true. } }
        if defined step { if step <> initial_step { set cancelled to true. } }
        if defined dap {
            local selected_dap_mode is dap["dap_mode"].
            if selected_dap_mode <> "auto" and selected_dap_mode <> "Auto" and selected_dap_mode <> "AUTO" {
                set cancelled to true.
            }
        }
        local edited is false.
        if owned {
            set edited to abs(maneuver:time-node_ut) > 0.01 or abs(maneuver:prograde-node_prograde) > 0.01 or
                abs(maneuver:normal-node_normal) > 0.01 or abs(maneuver:radialout-node_radial) > 0.01.
        }
        set reason to deorbit_execute_guard(lex("cancelled",cancelled,"owned",owned,"edited",edited,
            "available",ship:availablethrust,"fuel",ship:liquidfuel,"elapsed",time:seconds-started_ut,
            "deadline",deadline,"burning",burning,"stalled",time:seconds-progress_ut,"unpowered",time:seconds-powered_ut)).
        if reason = "" {
            set remaining_dv to maneuver:deltav:mag.
            set steering_vector to maneuver:deltav.
            if remaining_dv <= 0.2 { set reason to "complete". }
            else {
                local alignment_error is vang(ship:facing:vector,maneuver:deltav).
                set burn_command to 0.
                if not burning and maneuver:eta <= half_time {
                    if alignment_error > 2 { set reason to "not_aligned". }
                    else {
                        set burning to true.
                        set burn_started to time:seconds.
                        set progress_ut to time:seconds.
                        set powered_ut to time:seconds.
                    }
                }
                if burning {
                    if alignment_error > 10 { set reason to "alignment_lost". }
                    else { set burn_command to min(1,remaining_dv*ship:mass/ship:availablethrust/0.5). }
                    if remaining_dv < best_dv-0.05 { set best_dv to remaining_dv. set progress_ut to time:seconds. }
                    if ship:thrust > ship:availablethrust*burn_command*0.1 { set powered_ut to time:seconds. }
                    if time:seconds-burn_started > duration*2+10 { set reason to "burn_timeout". }
                    set evidence["burn_seen"] to true.
                }
                if reason = "" { lock throttle to burn_command. }
            }
            flight_log_maneuver_observe(maneuver,half_time,evidence).
        }
        if reason = "" { wait 0.05. }
    }
    lock throttle to 0.
    set ship:control:pilotmainthrottle to 0.
    unlock steering.
    local success is reason = "complete".
    if success { remove maneuver. }
    flight_log_event("deorbit_execute_return","success="+success+"|reason="+reason+"|remaining_dv="+remaining_dv).
    return lex("success",success,"reason",reason,"remaining_dv",remaining_dv).
}
