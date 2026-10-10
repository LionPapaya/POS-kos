// NERV-only PDI landing. Omitted coordinates open the target GUI. POS4 passes
// "suborbital" to wait for impact, then selects the current trajectory's site.
// Every inclination/deorbit node requires an explicit in-game Execute click.
// runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Vacuum_Landing.ks", 8.421, -74.230).
parameter target_latitude is "ASK".
parameter target_longitude is "ASK".
parameter target_altitude_override is -1.
parameter target_landing_heading is 90.
parameter landing_target_mode is "coordinate".
set CONFIG:IPU to 2000.

RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/PDI/pdi_navigation.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/PDI/pdi_terminal.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/PDI/pdi_executive.ks").

function pdi_run {
    parameter target_latitude, target_longitude, target_altitude_override, target_landing_heading, landing_target_mode.
    if ship:body:atm:exists or not ship:body:hassolidsurface {
        print "PDI requires an airless body with a solid surface.". return.
    }
    if landing_target_mode <> "coordinate" and landing_target_mode <> "convenient" and landing_target_mode <> "suborbital" {
        print "Target mode must be coordinate, convenient, or suborbital.". return.
    }
    if landing_target_mode <> "suborbital" and hasnode { print "PDI requires an empty maneuver plan. Existing nodes have been kept.". return. }
    if landing_target_mode = "suborbital" {
        print "POS4 armed: waiting for a suborbital trajectory before selecting a landing site.".
        until pdi_is_suborbital { wait 1. }
    }else if pdi_is_suborbital {
        print "Start PDI from a stable orbit clear of the terrain.". return.
    }
    local coordinates is lex("valid",true,"lat",0,"lng",0).
    if landing_target_mode = "coordinate" {
        if target_latitude = "ASK" or target_longitude = "ASK" { set coordinates to vacuum_target_input(target_latitude,target_longitude). }
        else {
            set coordinates["lat"] to target_latitude:tostring:tonumber(-9999).
            set coordinates["lng"] to target_longitude:tostring:tonumber(-9999).
            set coordinates["valid"] to abs(coordinates["lat"]) <= 90 and abs(coordinates["lng"]) <= 180.
        }
    }
    if not coordinates["valid"] { print "PDI target cancelled or invalid.". return. }
    local pdi_config is pdi_defaults().
    local site is latlng(coordinates["lat"],coordinates["lng"]).
    if landing_target_mode = "convenient" { set site to latlng(ship:geoposition:lat,ship:geoposition:lng). }
    local terrain_altitude is site:terrainheight.
    local suborbital_selection is lex().
    if landing_target_mode = "suborbital" {
        set suborbital_selection to pdi_suborbital_landing_site().
        if not suborbital_selection["valid"] {
            print "PDI could not find a terrain intersection: "+suborbital_selection["reason"]. return.
        }
        set site to suborbital_selection["site"].
        set terrain_altitude to suborbital_selection["altitude"].
    }
    if target_altitude_override >= 0 { set terrain_altitude to target_altitude_override. }
    if not (defined vacuum_landing_active) {
        global vacuum_landing_active is true.
    } else { set vacuum_landing_active to true. }
    if not (defined rapier_mode) { global rapier_mode is "off". }
    if not (defined POS_LOGGING_ENABLED) { global POS_LOGGING_ENABLED is false. }
    flight_log_begin("vacuum_landing").
    rapiersoff(). nervson().
    sas off. rcs on.
    dap:setup().
    set dapthrottle to 0.
    set dap["envelope"]["min_throttle"] to 0.
    set dap["vector"]["targetVector"] to ship:facing:vector.
    dap:set_vector_auto().
    wait 0.
    local nerv_engines is ship:partstitledpattern("LV-N").
    local fuel_parts is list().
    for part in ship:parts {
        local contains_fuel is false.
        for resource in part:resources { if resource:name = "LiquidFuel" { set contains_fuel to true. } }
        if contains_fuel { fuel_parts:add(part). }
    }
    local gui_ is GUI(470,220).
    local display is gui_:addlabel("Preparing Poseidon PDI").
    set PDI_PLANNING_DISPLAY to display.
    set PDI_PLANNING_STATUS_ACTIVE to true.
    set PDI_PLANNING_NEXT_CONSOLE_TIME to -1.
    local cancel is gui_:addbutton("Abort PDI / release controls").
    local data is lex().
    for field in POS_LOG_PDI_FIELDS { data:add(field,0). }
    local mission is lex("config",pdi_config,"site",site,"altitude",terrain_altitude,"heading",target_landing_heading,"target_mode",landing_target_mode,
        "engines",nerv_engines,"fuel_parts",fuel_parts,"vehicle",pdi_vehicle_snapshot(nerv_engines,fuel_parts,pdi_config),
        "bounds",ship:bounds,"running",true,"cancel",false,"diverted",false,"flip_committed",false,
        "phase","vacuum_plan","reason","planning","solver_reason","not_started","guidance_state","not_started","telemetry",data,
        "distance",0,"clearance",0,"desired_vs",0,"stopping_distance",0,"pitch_target",90,
        "ground_commit_logged",false,
        "last_solution_ut",time:seconds,"command",lex(),"next_display",0,"gui",gui_,"display",display).
    set cancel:onclick to { set mission["cancel"] to true. }.
    gui_:show().
    pdi_planning_status("setup","checking NERV capability and landing target").
    flight_log_set_vacuum_target(site,terrain_altitude,target_landing_heading).
    if landing_target_mode = "suborbital" {
        flight_log_event("pdi_suborbital_site","impact_ut="+suborbital_selection["impact_ut"]+"|periapsis_ut="+
            suborbital_selection["periapsis_ut"]+"|lat="+site:lat+"|lng="+site:lng+"|altitude="+terrain_altitude).
    }
    if nerv_engines:length = 0 or mission["vehicle"]["thrust"]/ship:mass < ship:body:mu/ship:body:radius^2*pdi_config["minimum_twr"] or
        ship:mass <= mission["vehicle"]["reserve_mass"] {
        vacuum_stop(mission,false,"insufficient_nerv_thrust_or_fuel_reserve"). return.
    }
    if landing_target_mode = "suborbital" {
        vacuum_phase(mission,"vacuum_suborbital_plan","solving immediate powered descent from current trajectory").
        // Begin the attitude slew before the first bounded UPFG solve.  The
        // locked retrograde target remains active while kOS evaluates the
        // predictor, avoiding a late turn from the previous flight mode.
        vacuum_command(mission,ship:velocity:orbit*-1,0).
        flight_log_event("pdi_suborbital_retrograde_hold","speed="+ship:velocity:orbit:mag).
        vacuum_tick(mission).
        wait 0.
        local direct_target is pdi_live_target(mission["site"],mission["altitude"],pdi_config).
        local direct_plan is pdi_suborbital_plan(direct_target,mission["vehicle"],pdi_config).
        if not direct_plan["valid"] {
            vacuum_solver_telemetry(mission,direct_plan["solution"]).
            flight_log_event("pdi_suborbital_solver","valid="+direct_plan["solution"]["valid"]+"|converged="+
                direct_plan["solution"]["converged"]+"|reason="+direct_plan["reason"]+"|iterations="+
                direct_plan["solution"]["iterations"]+"|position_error="+direct_plan["solution"]["position_error"]+
                "|velocity_error="+direct_plan["solution"]["velocity_error"]+"|mass="+direct_plan["state"]["mass"]+
                "|speed="+direct_plan["state"]["v"]:mag).
            local brake_plan is vacuum_suborbital_brake_plan(mission).
            if not brake_plan["valid"] { vacuum_stop(mission,false,brake_plan["reason"]). return. }
            set direct_plan to brake_plan["plan"].
        }
        set data["ignition_ut"] to direct_plan["ignition_ut"].
        set data["predicted_clearance"] to direct_plan["clearance"].
        vacuum_solver_telemetry(mission,direct_plan["solution"]).
        flight_log_event("pdi_plan_ready","mode=suborbital|ignition_ut="+data["ignition_ut"]+"|arrival_ut="+direct_plan["arrival_ut"]+
            "|clearance="+data["predicted_clearance"]+"|position_error="+direct_plan["position_error"]+"|velocity_error="+direct_plan["velocity_error"]+"|ignition_attempts=1|candidate_limit=1").
        vacuum_descent(mission,direct_plan).
        return.
    }
    local plane_passes is 0.
    local deorbit_complete is false.
    local plan is lex().
    until deorbit_complete or not mission["running"] {
        if mission["cancel"] { vacuum_stop(mission,false,"pilot_cancelled"). return. }
        local landing_target is pdi_live_target(mission["site"],mission["altitude"],pdi_config).
        local plane_pending is false.
        if landing_target_mode = "coordinate" {
            set display:text to "Checking the landing-site plane. A map node is provisional until its review window appears.".
            vacuum_phase(mission,"vacuum_plane_plan","checking landing-site orbital plane").
            local plane is pdi_plane_plan(landing_target,mission["vehicle"],pdi_config).
            if not plane["valid"] { vacuum_stop(mission,false,plane["reason"]). return. }
            set data["plane_error"] to plane["plane_error"].
            if plane["needed"] {
                set plane_pending to true.
                if plane_passes >= 3 { remove plane["node"]. vacuum_stop(mission,false,"plane_alignment_did_not_converge"). return. }
                local decision is vacuum_approve_node(mission,plane["node"],"inclination / landing-plane change","Align the orbit with the future landing site.").
                if decision = "execute" {
                    if not vacuum_execute_node(mission,plane["node"],"inclination") { vacuum_stop(mission,false,"inclination_burn_incomplete"). return. }
                    set plane_passes to plane_passes+1.
                }else if decision = "cancel" or decision = "changed" { vacuum_stop(mission,false,"node_kept_for_review"). return. }
                else { remove plane["node"]. }
            }
        }
        // Recompute after each real plane burn, not its instantaneous preview.
        if not plane_pending {
            set display:text to "Planning de-orbit and PDI ignition. The map node is provisional; wait for its review window.".
            vacuum_phase(mission,"vacuum_deorbit_plan","solving deorbit and powered arrival").
            set plan to pdi_plan_deorbit(landing_target,mission["altitude"],mission["vehicle"],pdi_config,landing_target_mode = "convenient").
            if not plan["valid"] { vacuum_stop(mission,false,plan["reason"]). return. }
            if plan:haskey("site") {
                set mission["site"] to plan["site"]. set mission["altitude"] to plan["altitude"].
                flight_log_set_vacuum_target(mission["site"],mission["altitude"],mission["heading"]).
            }
            set data["ignition_ut"] to plan["pdi"]["ignition_ut"].
            set data["predicted_clearance"] to plan["pdi"]["clearance"].
            vacuum_solver_telemetry(mission,plan["pdi"]["solution"]).
            flight_log_event("pdi_plan_ready","ignition_ut="+data["ignition_ut"]+"|arrival_ut="+plan["pdi"]["arrival_ut"]+
                "|clearance="+data["predicted_clearance"]+"|position_error="+plan["pdi"]["position_error"]+"|velocity_error="+plan["pdi"]["velocity_error"]+
                "|selected_score="+plan["pdi"]["score"]+"|ignition_attempts="+plan["pdi"]["attempts"]+"|candidate_limit="+pdi_config["ignition_candidates"]).
            local decision is vacuum_approve_node(mission,plan["node"],"deorbit","Execute this node, then automatically fly PDI and land at the displayed target.").
            if decision = "execute" {
                if not vacuum_execute_node(mission,plan["node"],"deorbit") { vacuum_stop(mission,false,"deorbit_burn_incomplete_manual_control"). return. }
                set deorbit_complete to true.
            }else if decision = "cancel" or decision = "changed" { vacuum_stop(mission,false,"node_kept_for_review"). return. }
            else { remove plan["node"]. }
        }
    }
    if deorbit_complete { vacuum_descent(mission,plan["pdi"]). }
}

pdi_run(target_latitude,target_longitude,target_altitude_override,target_landing_heading,landing_target_mode).
