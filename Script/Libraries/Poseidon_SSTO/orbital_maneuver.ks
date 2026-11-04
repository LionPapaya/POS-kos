RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui_dialogs.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui_style.ks").
// Live-flight UI and adapters for the unmodified SilverNuke911 library.
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").

// Fields are [label, default, minimum, maximum], in the planner's input order.
// Passive dialog moved to gui_dialogs.ks.


function pos_om_plan {
    parameter key, mode, n.
    if key = "circularize" { return circularize(mode,n[0]). }
    if key = "apoapsis" { return change_apoapsis(n[0],mode,n[1]). }
    if key = "periapsis" { return change_periapsis(n[0],mode,n[1]). }
    if key = "inclination" { return change_inclination(n[0],mode). }
    if key = "eccentricity" { return change_eccentricity(n[0],mode,n[1]). }
    if key = "lan" { return change_LAN(n[0],mode). }
    if key = "both_apses" { return change_pe_and_ap(n[0],n[1],mode). }
    if key = "semimajoraxis" { return change_semimajoraxis(n[0],mode,n[1]). }
    local base_period is ship:orbit:period.
    if key = "resonance" { if n[1] > 0 { set base_period to n[1]. } }
    if key = "resonance" { return change_resonant_orbit(n[0],mode,base_period,n[2]). }
    if key = "argument" { return change_argument_of_periapsis(n[0],mode). }
    if key = "return_from_moon" { return pos_return_from_a_moon(n[0]). }
    if key = "capture_at_body" { return pos_capture_at_body(). }
    if key = "match_planes" { return match_planes_with_target(mode). }
    if key = "match_velocity" { return match_velocities_with_target(mode,n[0]). }
    if key = "intercept_time" { return intercept_target_at_chosen_time(n[0],n[1]). }
    if key = "fine_tune" { return fine_tune_closest_approach_to_target(n[0],n[1],n[2]). }
    if key = "hohmann_target" { return hohmann_transfer_to_target(). }
    if key = "intercept" { return intercept_target("lowest dv",0,true). }
    if key = "porkchop1" { return porkchop_evaluation1(time:seconds+n[0],time:seconds+n[1],n[2],n[3],mode,n[4]=1,time:seconds+n[0],n[5],n[5]). }
    if key = "porkchop2" { return porkchop_evaluation2(time:seconds+n[0],time:seconds+n[1],n[2],n[3],mode,n[4]=1,0,time:seconds+n[0],n[5],n[5]). }
    return null_mnv("Unknown maneuver command").
}

// Passive dialog moved to gui_dialogs.ks.


function pos_om_validate {
    parameter command, mode, n.
    local key is command["key"].
    if command["target"] {
        if not hastarget { return "Select a vessel or celestial body as the map target.". }
        if not target:istype("vessel") and not target:istype("body") { return "Select a vessel or celestial body, not a docking port.". }
        if target = ship or target = ship:body { return "Select a different object orbiting the current body.". }
        if target:orbit:body <> ship:body { return "Target must orbit the same central body.". }
        if target:orbit:eccentricity >= 1 { return "This target workflow requires a closed target orbit.". }
    }
    // The exposed planners use finite orbital periods. Hyperbolic variants
    // remain available in the copied library for direct use.
    if ship:orbit:eccentricity >= 1 and key <> "capture_at_body" { return "This UI requires a closed starting orbit.". }
    if mode = "at altitude" {
        local altitude_value is n[0].
        if key <> "circularize" { set altitude_value to n[1]. }
        if key = "resonance" { set altitude_value to n[2]. }
        if altitude_value < ship:periapsis or altitude_value > ship:apoapsis {
            return "Burn altitude must lie between the current periapsis and apoapsis.".
        }
        if ship:orbit:eccentricity < 0.000001 { return "For a circular starting orbit, choose an apsis or a time delay.". }
    }
    if key = "both_apses" and n[0] > n[1] { return "Periapsis must not exceed apoapsis.". }
    if key = "semimajoraxis" and n[0] <= ship:body:radius { return "Semimajor axis must exceed the body radius.". }
    if key = "return_from_moon" and ship:body:body = ship:body { return "Return from a moon requires the vessel to orbit a moon with a parent body.". }
    if key = "capture_at_body" and ship:orbit:eccentricity < 1 { return "Body capture requires an incoming hyperbolic trajectory.". }
    if key = "capture_at_body" and ship:periapsis < 0 { return "Capture periapsis must be above the current body's surface.". }
    if key = "fine_tune" and n[2] <> round(n[2]) { return "Search samples must be an integer.". }
    if key = "porkchop1" or key = "porkchop2" {
        if n[1] <= n[0] or n[3] <= n[2] { return "Window end and maximum flight time must exceed their start values.". }
        if n[4] <> round(n[4]) or n[5] <> round(n[5]) { return "Arrival cost and sample count must be integers.". }
    }
    if key = "hohmann_orbit" and ship:orbit:eccentricity > 0.01 { return "Hohmann orbit change requires eccentricity <= 0.01.". }
    if key = "hohmann_target" {
        if abs(ship:orbit:semimajoraxis-target:orbit:semimajoraxis) < 1 { return "Equal orbit sizes have no Hohmann phasing solution. Use an intercept.". }
    }
    return "".
}

function pos_om_review_node {
    parameter maneuver, title is "Review maneuver".
    local panel is gui(520,360).
    pos_gui_window_style(panel,520).
    panel:addlabel(title).
    panel:addlabel("Inspect the orbit in map view, then choose an action.").
    local reviewed_ut is maneuver:time.
    local reviewed_prograde is maneuver:prograde.
    local reviewed_radial is maneuver:radialout.
    local reviewed_normal is maneuver:normal.
    local summary is panel:addlabel(pos_om_node_summary(maneuver)).
    local decision is "pending".
    local buttons is panel:addhlayout().
    local execute_button is buttons:addbutton("Execute this node").
    local keep_button is buttons:addbutton("Keep node; do not execute").
    local delete_button is buttons:addbutton("Delete this node").
    set execute_button:onclick to { set decision to "execute". }.
    set keep_button:onclick to { set decision to "keep". }.
    set delete_button:onclick to { set decision to "delete". }.
    panel:show().
    until decision <> "pending" {
        local present is false.
        for candidate in allnodes { if candidate = maneuver { set present to true. } }
        if not present { set decision to "missing". }
        else {
            set reviewed_ut to maneuver:time.
            set reviewed_prograde to maneuver:prograde.
            set reviewed_radial to maneuver:radialout.
            set reviewed_normal to maneuver:normal.
            set summary:text to pos_om_node_summary(maneuver).
        }
        wait 0.1.
    }
    panel:dispose().
    flight_log_event("maneuver_review","decision="+decision+"|command="+title).
    if decision = "delete" {
        for candidate in allnodes { if candidate = maneuver { remove candidate. } }
    }
    if decision <> "execute" { return false. }
    if not hasnode { return false. }
    if nextnode <> maneuver {
        print "This is not the next node. Execute earlier nodes first.".
        return false.
    }
    if maneuver:time <> reviewed_ut or maneuver:prograde <> reviewed_prograde or maneuver:radialout <> reviewed_radial or maneuver:normal <> reviewed_normal {
        print "Node changed since the displayed review; review it again before execution.".
        flight_log_event("maneuver_review_invalidated","reason=node_changed").
        return false.
    }
    nervson().
    rapiersoff().
    return pos_execute_node().
}

function pos_om_create_review {
    parameter plan, title.
    if not plan:istype("list") { print "Planner did not return a maneuver.". return false. }
    if plan:length <> 4 { print "Planner returned an invalid maneuver.". return false. }
    if plan[0] <= time:seconds {
        flight_log_event("maneuver_plan_rejected","command="+title+"|reason=no_future_solution").
        print "No future maneuver was produced. Check the planner message in the terminal.".
        return false.
    }
    if hasnode { print "Resolve existing nodes before creating a new maneuver.". return false. }
    create_node(plan).
    if not hasnode { return false. }
    flight_log_event("maneuver_created","command="+title+"|ut="+nextnode:time+"|dv="+nextnode:deltav:mag+"|predicted_ap="+nextnode:orbit:apoapsis+"|predicted_pe="+nextnode:orbit:periapsis+"|predicted_inc="+nextnode:orbit:inclination).
    return pos_om_review_node(nextnode,title).
}

function pos_om_rcs_review {
    parameter mode, n.
    local panel is gui(500,240).
    pos_gui_window_style(panel,500).
    panel:addlabel("RCS correction: "+mode+" to "+n[0]+" m; tolerance "+n[1]+" m").
    panel:addlabel("This directly controls RCS; no maneuver node is created.").
    local decision is "pending".
    local go_button is panel:addbutton("Start RCS correction").
    local cancel_button is panel:addbutton("Cancel").
    set go_button:onclick to { set decision to "execute". }.
    set cancel_button:onclick to { set decision to "cancel". }.
    panel:show().
    until decision <> "pending" { wait 0.1. }
    panel:dispose().
    flight_log_event("rcs_correction_review","decision="+decision+"|apsis="+mode+"|target_m="+n[0]+"|tolerance_m="+n[1]).
    if decision <> "execute" { return. }
    local current_apsis is ship:apoapsis.
    if mode = "periapsis" { set current_apsis to ship:periapsis. }
    // Avoid the upstream error/abs(error) singularity when already on target.
    if abs(current_apsis-n[0]) <= n[1] { print "Already within tolerance.". return. }
    if rcs_total_thrust() <= 0 { print "No available RCS thrust.". return. }
    flight_log_event("rcs_correction_started","apsis="+mode+"|target_m="+n[0]).
    local observing_rcs is true.
    local rcs_evidence is lex("next_sample",0).
    when true then {
        if not observing_rcs { return false. }
        flight_log_rcs_observe(mode,n[0],rcs_evidence).
        return observing_rcs.
    }
    rcs_corrector(mode,n[0],n[1],false).
    set observing_rcs to false.
    set ship:control:fore to 0.
    unlock steering.
    rcs off.
    sas off.
    if defined dap { dap:setup(). }
    flight_log_event("rcs_correction_returned","apoapsis="+ship:apoapsis+"|periapsis="+ship:periapsis).
}

function pos_om_run {
    parameter label.
    for command in pos_om_catalog() {
        if command["label"] = label {
            if hasnode { print "Execute or delete existing nodes first.". return. }
            local inputs is pos_om_inputs(command).
            if not inputs["accepted"] { return. }
            local mode is inputs["mode"].
            local n is inputs["numbers"].
            local reason is pos_om_validate(command,mode,n).
            if reason <> "" {
                print reason.
                flight_log_event("maneuver_plan_rejected","command="+label+"|reason="+reason).
                return.
            }
            flight_log_event("maneuver_plan_requested","command="+label+"|mode="+mode+"|inputs="+n).
            if command["key"] = "rcs" { pos_om_rcs_review(mode,n). return. }
            if command["key"] = "hohmann_orbit" {
                local raising is n[0] > ship:apoapsis.
                local plan is null_mnv("",false).
                if raising { set plan to change_apoapsis(n[0],mode,n[1]). }
                else { set plan to change_periapsis(n[0],mode,n[1]). }
                if not pos_om_create_review(plan,"Hohmann departure") { return. }
                local arrival_mode is "at periapsis".
                if raising { set arrival_mode to "at apoapsis". }
                pos_om_create_review(circularize(arrival_mode),"Hohmann circularization").
                return.
            }
            pos_om_create_review(pos_om_plan(command["key"],mode,n),label).
            return.
        }
    }
}

function pos_om_node_summary {
    parameter maneuver.
    return "Burn UT: "+round(maneuver:time,1)+"  |  In: "+round(maneuver:eta,1)+" s"+char(10)+
        "Delta-v: "+round(maneuver:deltav:mag,2)+" m/s"+char(10)+
        "Periapsis: "+round(maneuver:orbit:periapsis,1)+" m  |  Apoapsis: "+round(maneuver:orbit:apoapsis,1)+" m"+char(10)+
        "Inclination: "+round(maneuver:orbit:inclination,3)+" deg".
}
