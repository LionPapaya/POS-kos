// Live-flight UI and adapters for the unmodified SilverNuke911 library.
RUNONCEPATH("0:/Libraries/lib_vacstr.ks").

// Fields are [label, default, minimum, maximum], in the planner's input order.
function pos_om_catalog {
    local commands is list().
    commands:add(lex("label","Circularize","key","circularize","modes",list("at apoapsis","at periapsis","after fixed time","at altitude","at equatorial AN","at equatorial DN"),"fields",list(list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Change apoapsis","key","apoapsis","modes",list("at periapsis","at apoapsis","after fixed time","at altitude","at equatorial AN","at equatorial DN"),"fields",list(list("Target altitude (m)",100000,1,1000000000000.0),list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Change periapsis","key","periapsis","modes",list("at apoapsis","at periapsis","after fixed time","at altitude","at equatorial AN","at equatorial DN"),"fields",list(list("Target altitude (m)",100000,1,1000000000000.0),list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Change inclination","key","inclination","modes",list("at nearest node","at cheapest node","at AN","at DN"),"fields",list(list("Target inclination (deg)",0,0,180)),"target",false,"note","")).
    commands:add(lex("label","Change eccentricity","key","eccentricity","modes",list("at apoapsis","at periapsis","after fixed time","at altitude","at equatorial AN","at equatorial DN"),"fields",list(list("Target eccentricity",0.1,0,0.999999),list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Change LAN","key","lan","modes",list("at nearest apsis","at cheapest apsis","at periapsis","at apoapsis","at nearest peak latitude","at cheapest peak latitude","at north peak latitude","at south peak latitude"),"fields",list(list("Target angle (deg)",0,0,360)),"target",false,"note","")).
    commands:add(lex("label","Change periapsis and apoapsis","key","both_apses","modes",list("nearest","first half","second half"),"fields",list(list("Target periapsis (m)",100000,1,1000000000000.0),list("Target apoapsis (m)",200000,1,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Change semimajor axis","key","semimajoraxis","modes",list("at apoapsis","at periapsis","after fixed time","at altitude"),"fields",list(list("Semimajor axis from body center (m)",800000,1,1000000000000.0),list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Resonant orbit","key","resonance","modes",list("at apoapsis","at periapsis","after fixed time","at altitude"),"fields",list(list("Period ratio",1.5,0.001,1000),list("Base period (s); 0 = current orbit",0,0,1000000000000.0),list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Change argument of periapsis","key","argument","modes",list("nearest","first half","second half"),"fields",list(list("Target angle (deg)",0,0,360)),"target",false,"note","")).
    commands:add(lex("label","Return from current moon","key","return_from_moon","modes",list("at periapsis"),"fields",list(list("Target parent periapsis altitude (m)",80000,0,1000000000000.0)),"target",false,"note","Plans an escape burn at the current orbit's next periapsis. Review the parent-body trajectory before executing.")).
    commands:add(lex("label","Capture at current body","key","capture_at_body","modes",list("at periapsis"),"fields",list(),"target",false,"note","For an incoming hyperbolic trajectory: circularizes at the current body's next periapsis.")).
    commands:add(lex("label","Match target plane","key","match_planes","modes",list("at nearest node","at cheapest node","at AN","at DN"),"fields",list(),"target",true,"note","")).
    commands:add(lex("label","Match target velocity","key","match_velocity","modes",list("at closest approach","after fixed time"),"fields",list(list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",true,"note","")).
    commands:add(lex("label","Intercept at chosen time","key","intercept_time","modes",list("chosen time"),"fields",list(list("Departure delay (s)",240,30,1000000000000.0),list("Flight time after departure (s)",3600,1,1000000000000.0)),"target",true,"note","")).
    commands:add(lex("label","Fine tune closest approach","key","fine_tune","modes",list("closest approach"),"fields",list(list("Target distance (m)",100,1,1000000000000.0),list("Departure delay (s)",240,30,1000000000000.0),list("Search samples (integer)",60,2,200)),"target",true,"note","")).
    commands:add(lex("label","Hohmann transfer to target","key","hohmann_target","modes",list("transfer"),"fields",list(),"target",true,"note","Creates the departure node. Use Match target velocity for arrival.")).
    commands:add(lex("label","Lowest delta-v intercept","key","intercept","modes",list("lowest dv"),"fields",list(),"target",true,"note","Search cost includes arrival braking; only the departure node is created.")).
    commands:add(lex("label","Transfer window search 1","key","porkchop1","modes",list("lowest dv","as soon as possible"),"fields",list(list("Departure window start (s from now)",240,120,1000000000000.0),list("Departure window end (s from now)",3600,121,1000000000000.0),list("Minimum flight time (s)",600,1,1000000000000.0),list("Maximum flight time (s)",7200,2,1000000000000.0),list("Include arrival cost: 0 or 1",1,0,1),list("Samples per axis (integer)",25,2,100)),"target",true,"note","Search may take time at 2000 IPU. Creates departure only; arrival cost is optional.")).
    commands:add(lex("label","Transfer window search 2","key","porkchop2","modes",list("lowest dv","as soon as possible"),"fields",list(list("Departure window start (s from now)",240,120,1000000000000.0),list("Departure window end (s from now)",3600,121,1000000000000.0),list("Minimum flight time (s)",600,1,1000000000000.0),list("Maximum flight time (s)",7200,2,1000000000000.0),list("Include arrival cost: 0 or 1",1,0,1),list("Samples per axis (integer)",25,2,100)),"target",true,"note","Search may take time at 2000 IPU. Creates departure only; arrival cost is optional.")).
    commands:add(lex("label","Hohmann orbit change (two burns)","key","hohmann_orbit","modes",list("after fixed time"),"fields",list(list("Target altitude (m)",100000,1,1000000000000.0),list("Departure delay (s)",240,30,1000000000000.0)),"target",false,"note","Each burn is created and reviewed separately. Requires a nearly circular starting orbit.")).
    commands:add(lex("label","RCS apsis correction","key","rcs","modes",list("apoapsis","periapsis"),"fields",list(list("Target altitude (m)",100000,1,1000000000000.0),list("Tolerance (m)",10,0.1,10000)),"target",false,"note","Direct RCS correction: review the target before starting. No maneuver node is created.")).
    return commands.
}

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

function pos_om_inputs {
    parameter command.
    local panel is gui(550,500).
    panel:addlabel(command["label"]).
    if command["note"] <> "" {
        local maneuver_note is panel:addlabel(command["note"]).
        set maneuver_note:style:width to 520.
        set maneuver_note:style:wordwrap to true.
    }
    local mode_menu is panel:addpopupmenu().
    for mode_name in command["modes"] { mode_menu:addoption(mode_name). }
    local fields is list().
    for spec in command["fields"] {
        local row is panel:addhlayout().
        local field_label is row:addlabel(spec[0]).
        set field_label:style:width to 360.
        local field_input is row:addtextfield(""+spec[1]).
        set field_input:style:width to 140.
        fields:add(field_input).
    }
    if command["target"] {
        if hastarget { panel:addlabel("Selected map target: "+target:name). }
        else { panel:addlabel("Select a target in map view before creating the node."). }
    }
    local message is panel:addlabel("").
    set message:style:wordwrap to true.
    set message:style:width to 520.
    local result is lex("accepted",false,"mode","","numbers",list()).
    local done is false.
    local buttons is panel:addhlayout().
    local plan_button is buttons:addbutton("Create maneuver").
    if command["key"] = "rcs" { set plan_button:text to "Review correction". }
    local cancel_button is buttons:addbutton("Cancel").
    set cancel_button:onclick to { set done to true. }.
    set plan_button:onclick to {
        local numbers is list().
        local valid is true.
        local index is 0.
        for field in fields {
            local number is field:text:tonumber(-1e30).
            local spec is command["fields"][index].
            if number < spec[2] or number > spec[3] {
                set valid to false.
                set message:text to spec[0]+": enter a number from "+spec[2]+" to "+spec[3].
            }
            numbers:add(number).
            set index to index+1.
        }
        if valid {
            set result["numbers"] to numbers.
            set result["mode"] to mode_menu:value.
            set result["accepted"] to true.
            set done to true.
        }
    }.
    panel:show().
    until done { wait 0.1. }
    panel:dispose().
    return result.
}

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
