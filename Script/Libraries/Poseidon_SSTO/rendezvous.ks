// Same-body orbital rendezvous for Poseidon.
//
// This is deliberately a live-flight adapter around RSVP's Lambert planner:
// RSVP owns the transfer mathematics, while this file owns the operational
// checks, burn execution, logging, and the docking handoff contract.
RUNONCEPATH("0:/Libraries/rsvp/main.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").

function rendezvous_same_body {
    parameter target_vessel, options is lex().
    local result is lex("success",false,"docking_ready",false,"reason","invalid_target").
    local docking_distance is 1000.
    // The docking program rejects 5 m/s or more, so leave a small margin.
    local docking_relative_speed is 4.5.
    if options:haskey("docking_distance") { set docking_distance to options["docking_distance"]. }
    if options:haskey("docking_relative_speed") { set docking_relative_speed to options["docking_relative_speed"]. }

    if target_vessel = 0 or not target_vessel:istype("vessel") {
        flight_log_event("rendezvous_rejected","reason=target_is_not_a_vessel").
        return result.
    }
    if target_vessel = ship {
        flight_log_event("rendezvous_rejected","reason=target_is_active_vessel").
        return result.
    }
    if target_vessel:body <> ship:body {
        set result["reason"] to "target_is_not_orbiting_current_body".
        flight_log_event("rendezvous_rejected","reason="+result["reason"]).
        return result.
    }
    if ship:orbit:eccentricity >= 1 or target_vessel:orbit:eccentricity >= 1 {
        set result["reason"] to "both_vessels_must_be_in_closed_orbits".
        flight_log_event("rendezvous_rejected","reason="+result["reason"]).
        return result.
    }

    local initial_distance is (target_vessel:position-ship:position):mag.
    local initial_relative_speed is (target_vessel:velocity:orbit-ship:velocity:orbit):mag.
    flight_log_capture_rendezvous(target_vessel,"planning",0,false).
    flight_log_event("rendezvous_target","name="+target_vessel:name+"|body="+ship:body:name+"|distance_m="+round(initial_distance,1)+"|relative_speed="+round(initial_relative_speed,2)).

    // Let RSVP search one current-orbit period for an inexpensive same-body
    // intercept.  Creating both nodes means the second burn matches the
    // target velocity rather than merely flying past it.
    local transfer_options is lex(
        "create_maneuver_nodes","both",
        "earliest_departure",time:seconds+120,
        "search_duration",ship:orbit:period,
        "search_interval",max(30,ship:orbit:period/48),
        "max_time_of_flight",ship:orbit:period*2,
        "verbose",true
    ).
    local plan is rsvp:goto(target_vessel,transfer_options).
    if not plan:success {
        set result["reason"] to "transfer_planning_failed".
        flight_log_event("rendezvous_plan_failed","reason="+result["reason"]).
        flight_log_capture_rendezvous(target_vessel,"failed",0,false).
        return result.
    }

    set Lastest_status to "Rendezvous transfer: departure burn".
    flight_log_event("rendezvous_plan_ready","nodes=2").
    flight_log_capture_rendezvous(target_vessel,"departure_burn",2,false).
    flight_log_tick("orbital_maneuver","rendezvous","departure_burn").
    execute_node().

    set Lastest_status to "Rendezvous transfer: matching target velocity".
    flight_log_event("rendezvous_departure_complete","").
    flight_log_capture_rendezvous(target_vessel,"arrival_burn",1,false).
    flight_log_tick("orbital_maneuver","rendezvous","arrival_burn").
    execute_node().

    local final_distance is (target_vessel:position-ship:position):mag.
    local final_relative_speed is (target_vessel:velocity:orbit-ship:velocity:orbit):mag.
    local ready is final_distance <= docking_distance and final_relative_speed <= docking_relative_speed.
    set result["success"] to ready.
    set result["docking_ready"] to ready.
    set result["distance"] to final_distance.
    set result["relative_speed"] to final_relative_speed.
    if ready {
        set result["reason"] to "docking_handoff_ready".
        set Lastest_status to "Rendezvous complete: ready for docking".
        // Docking accepts a vessel target and will ask for a compatible port.
        // Preserve the rendezvous target so the next program can continue
        // without asking the pilot to select it again in map view.
        set target to target_vessel.
        flight_log_event("rendezvous_docking_handoff","distance_m="+round(final_distance,1)+"|relative_speed="+round(final_relative_speed,2)).
    } else {
        set result["reason"] to "intercept_complete_outside_docking_gate".
        set Lastest_status to "Rendezvous complete: refine before docking".
        flight_log_event("rendezvous_handoff_blocked","distance_m="+round(final_distance,1)+"|relative_speed="+round(final_relative_speed,2)).
    }
    flight_log_capture_rendezvous(target_vessel,"complete",0,ready).
    flight_log_tick("orbital_maneuver","rendezvous","complete").
    return result.
}
