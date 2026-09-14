// Poseidon adapter; the upstream execute_node implementation lives unchanged
// in lib_orbital_nodes.ks. All existing flight programs call this adapter.
RUNONCEPATH("0:/Libraries/lib_orbital_nodes.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").

function pos_execute_node {
    parameter warp_to_node is true.
    lock throttle to 0.
    set ship:control:pilotmainthrottle to 0.
    if not hasnode {
        flight_log_event("maneuver_rejected","reason=no_node").
        return false.
    }
    local maneuver is nextnode.
    if maneuver:deltav:mag < 0.1 {
        flight_log_event("maneuver_no_burn_needed","dv="+maneuver:deltav:mag).
        remove maneuver.
        return true.
    }
    // Poseidon activates its selected engines before reaching this adapter.
    // Reject unavailable propulsion rather than triggering upstream auto-stage.
    if ship:availablethrust <= 0 or ship_isp() <= 0 {
        flight_log_event("maneuver_rejected","reason=no_active_engine_thrust").
        print "Maneuver retained: activate engines before execution.".
        return false.
    }
    local half_time is half_burn_time(maneuver).
    if maneuver:eta <= half_time+10 {
        flight_log_event("maneuver_rejected","reason=insufficient_lead_time|eta="+maneuver:eta+"|half_burn_s="+half_time).
        print "Maneuver retained: insufficient time to start this burn.".
        return false.
    }
    local observing is true.
    local evidence is lex("phase","aligning","next_sample",0,"remaining_dv",maneuver:deltav:mag,"burn_seen",false).
    flight_log_event("maneuver_execute_requested","ut="+maneuver:time+"|dv="+maneuver:deltav:mag+"|half_burn_s="+half_time+"|executor=silvernuke911").
    // A passive flight observer leaves the imported control loop unchanged.
    // No trigger or logging work is installed by the planning library.
    when true then {
        if not observing { return false. }
        if hasnode {
            if nextnode = maneuver {
                if ship:control:mainthrottle > 0 { set evidence["burn_seen"] to true. }
                set evidence["remaining_dv"] to maneuver:deltav:mag.
                flight_log_maneuver_observe(maneuver,half_time,evidence).
            }
        }
        return observing.
    }
    // Manual kOS steering preserves support for pilots without maneuver SAS.
    execute_node(false,warp_to_node,"engine",true).
    set observing to false.
    lock throttle to 0.
    set ship:control:pilotmainthrottle to 0.
    unlock steering.
    sas off.
    if defined dap { dap:setup(). }
    local removed is true.
    for remaining_node in allnodes {
        if remaining_node = maneuver { set removed to false. }
    }
    local completed is removed and evidence["burn_seen"].
    flight_log_event("maneuver_execution_returned","completed="+completed+"|node_removed="+removed+"|last_remaining_dv="+evidence["remaining_dv"]+"|apoapsis="+ship:apoapsis+"|periapsis="+ship:periapsis+"|inclination="+ship:orbit:inclination).
    return completed.
}
