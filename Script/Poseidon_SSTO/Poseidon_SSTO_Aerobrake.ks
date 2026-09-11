// One Kerbin aerobraking pass. There is no landing handoff, repeat pass, or
// post-pass periapsis burn. Begin on the inbound Kerbin patch above 170 km.
set CONFIG:IPU to 2000.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_navigation.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_aerosim.ks").
RUNONCEPATH("0:/Libraries/lib_orbital_nodes.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/aerobrake.ks").

function run_poseidon_aerobrake {
    local result is lex("success",false,"exited",false,"captured",false,"reason","not_started").
    if BODY:name <> "Kerbin" or not BODY:atm:exists {
        set result["reason"] to "requires_Kerbin". return result.
    }
    if not addons:available("FAR") {
        set result["reason"] to "requires_FAR". return result.
    }
    if defined terminal_route_debug { unset terminal_route_debug. }
    if defined terminal_route { unset terminal_route. }
    set rapier_mode to "unknown".
    for engine_part in ship:partstitledpattern("R.A.P.I.E.R") { set rapier_mode to engine_part:mode. }
    flight_log_begin("aerobrake").
    set aerobrake_active to true.
    set entry_flight_active to false.
    dap:setup().
    set dap["dap_mode"] to "auto".
    set dap["str_mode"] to "aoa".
    set dap["aoa"]["target_aoa"] to AVES["Aerobrake"]["aoa"].
    set dap["aoa"]["target_bank"] to 0.
    set dapthrottle to 0.
    nervsoff(). rapiersoff(). brakes off. gear off. rcs on.
    dap:update(). lock throttle to 0.
    local ab_gui is gui(390).
    ab_gui:addlabel("Poseidon: single aerobraking pass").
    local status_label is ab_gui:addlabel("Planning 35-50 km periapsis using FAR...").
    ab_gui:addlabel("Lowest forecast exit orbit within load limits.").
    ab_gui:addlabel("Heating is a load estimate; monitor part temperatures.").
    local begin_button is ab_gui:addbutton("Execute planned approach and aerobrake").
    set begin_button:enabled to false.
    local stop_button is ab_gui:addbutton("Stop / take control").
    local approved is false. local stopped is false.
    set begin_button:onclick to { set approved to true. }.
    set stop_button:onclick to { set stopped to true. }.
    ab_gui:show().
    local plan is aerobrake_plan().
    for candidate in plan["candidates"] {
        flight_log_event("aerobrake_candidate","pe="+candidate["pe"]+"|valid="+candidate["valid"]+
            "|reason="+candidate["reason"]+"|peak_q="+candidate["peak_q"]+
            "|peak_g="+candidate["peak_g"]+"|peak_heat_proxy="+candidate["peak_heat"]+"|min_alt="+candidate["min_alt"]).
    }
    if not plan["valid"] {
        set result["reason"] to plan["reason"].
    } else {
        set approved to false.
        set begin_button:enabled to true.
        local maneuver is plan["node"].
        local cfg is AVES["Aerobrake"].
        local predicted_ap is "escape / energy reduced".
        if plan["forecast"]["energy"] < 0 { set predicted_ap to round(plan["forecast"]["apoapsis"]/1000,1)+" km". }
        set status_label:text to "Pe "+round(plan["pe"]/1000,1)+" km; exit Ap "+predicted_ap+
            "; correction "+round(maneuver:deltav:mag,1)+" m/s".
        flight_log_event("aerobrake_plan","pe="+plan["pe"]+"|dv="+maneuver:deltav:mag+
            "|exit_apoapsis="+plan["forecast"]["apoapsis"]+"|no_post_pass_burn=true").
        until approved or stopped or maneuver:eta < 60 {
            dap:update(). lock throttle to 0.
            flight_log_tick("aerobrake","review","awaiting_start"). wait 0.
        }
        local burn_ok is approved and not stopped and maneuver:eta >= 60.
        if not burn_ok { set result["reason"] to "approach_cancelled_or_expired". }
        if burn_ok and maneuver:deltav:mag > 0.2 {
            nervson(). rapiersoff().
            local acceleration is ship:availablethrust/max(0.001,ship:mass).
            local duration is maneuver:deltav:mag/max(0.001,acceleration).
            if acceleration <= 0.01 or duration > cfg["burn_timeout"] or duration/2+15 > maneuver:eta {
                set burn_ok to false. set result["reason"] to "insufficient_correction_authority".
            } else {
                set dap["str_mode"] to "vector".
                local initial_dv is maneuver:deltav.
                set status_label:text to "Aligning for approach correction".
                until maneuver:eta <= duration/2 or stopped {
                    set dap["vector"]["targetVector"] to maneuver:deltav.
                    dap:update(). lock throttle to 0.
                    flight_log_tick("aerobrake","correction","align"). wait 0.
                }
                local burn_start is time:seconds.
                local last_progress is time:seconds.
                local previous_dv is maneuver:deltav:mag.
                local complete is false.
                until complete or stopped or not burn_ok {
                    local remaining is maneuver:deltav.
                    if remaining:mag < 0.2 or vdot(initial_dv,remaining) <= 0 { set complete to true. }
                    if time:seconds-burn_start > cfg["burn_timeout"] or time:seconds-last_progress > 10 or
                        ship:altitude <= BODY:atm:height+10000 {
                        set burn_ok to false. set result["reason"] to "correction_timeout_or_no_progress".
                    }
                    set dap["vector"]["targetVector"] to remaining.
                    set dapthrottle to 0.
                    if not complete and burn_ok and not stopped and vang(ship:facing:forevector,remaining) <= cfg["alignment_limit"] {
                        set dapthrottle to min(1,remaining:mag/max(0.01,ship:availablethrust/max(0.001,ship:mass)*2)).
                    }
                    if remaining:mag < previous_dv-0.1 { set last_progress to time:seconds. set previous_dv to remaining:mag. }
                    dap:update(). lock throttle to dapthrottle.
                    flight_log_tick("aerobrake","correction","burn"). wait 0.
                }
            }
        }
        set dapthrottle to 0. lock throttle to 0. nervsoff(). rapiersoff().
        remove maneuver.
        if stopped { set burn_ok to false. set result["reason"] to "pilot_stop". }
        if burn_ok and abs(ship:periapsis-plan["pe"]) > cfg["periapsis_tolerance"] {
            set burn_ok to false. set result["reason"] to "correction_missed_periapsis".
        }
        flight_log_event("aerobrake_correction","valid="+burn_ok+"|actual_pe="+ship:periapsis+"|reason="+result["reason"]).
        if burn_ok {
            set dap["str_mode"] to "aoa".
            local entered is false. local exiting is false. local exit_since is -1.
            local pass_started is time:seconds.
            local exit_reason is "normal".
            until stopped or result["exited"] or BODY:name <> "Kerbin" {
                local metrics is atmospheric_metrics(-BODY:position,ship:velocity:orbit,ship:velocity:surface,
                    ADDONS:FAR:AEROFORCE/max(0.001,ship:mass),ship:q*constant:atmtokpa,BODY:mu,BODY:radius).
                if ship:altitude < BODY:atm:height { set entered to true. }
                local command is aerobrake_command(metrics,plan["pe"],exiting,BODY:mu,BODY:radius).
                if not exiting and command["exiting"] { set exit_reason to command["reason"]. }
                set exiting to command["exiting"].
                set dap["aoa"]["target_aoa"] to command["aoa"].
                set dap["aoa"]["target_bank"] to command["bank"].
                if ship:altitude < BODY:atm:height+10000 { set warp to 0. }
                if entered and ship:altitude > BODY:atm:height+cfg["exit_margin"] and ship:verticalspeed > 0 {
                    if exit_since < 0 { set exit_since to time:seconds. }
                    if time:seconds-exit_since >= 3 {
                        set result["exited"] to true.
                        set result["success"] to true.
                        set result["captured"] to metrics["energy"] < 0 and metrics["apoapsis"]+BODY:radius < BODY:soiradius.
                        set result["reason"] to "atmosphere_exited".
                        if not result["captured"] { set result["reason"] to "exited_still_escaping". }
                    }
                } else { set exit_since to -1. }
                local phase is "coast".
                if entered { set phase to "pass". }
                if exiting { set phase to "exit". }
                set status_label:text to phase+"; alt "+round(ship:altitude/1000,1)+" km; Pe "+round(ship:periapsis/1000,1)+
                    " km; heat "+round(metrics["heat_proxy"],2)+"; "+exit_reason.
                if entered and ship:altitude < cfg["floor_altitude"] {
                    set status_label:text to "EXIT AT RISK: lift up; take control if needed".
                }
                dap:update(). lock throttle to 0.
                flight_log_capture_atmosphere("aerobrake",metrics,plan["pe"],exiting,exit_reason,true,
                    time:seconds-pass_started,0,result["exited"]).
                flight_log_tick("aerobrake",phase,exit_reason).
                // Do not wait forever on a missed atmosphere or a landed craft.
                if (not entered and ship:verticalspeed > 0) or ship:status = "LANDED" or ship:status = "SPLASHED" {
                    set stopped to true. set result["reason"] to "no_atmospheric_exit".
                }
                wait 0.
            }
            if not result["exited"] and result["reason"] = "not_started" { set result["reason"] to "pilot_stop_or_soi_change". }
        }
    }
    set dapthrottle to 0. lock throttle to 0.
    set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.
    nervsoff(). rapiersoff().
    set aerobrake_active to false.
    set dap["dap_mode"] to "off". dap:set_off().
    flight_log_event("aerobrake_complete","success="+result["success"]+"|exited="+result["exited"]+
        "|captured="+result["captured"]+"|reason="+result["reason"]+"|periapsis="+ship:periapsis+"|apoapsis="+ship:apoapsis).
    set result["final_periapsis"] to ship:periapsis.
    set result["final_apoapsis"] to ship:apoapsis.
    ab_gui:hide().
    return result.
}

set aerobrake_active to false.
set aerobrake_result to run_poseidon_aerobrake().
print "Aerobrake: "+aerobrake_result["reason"].
if aerobrake_result["exited"] {
    print "Coasting: Pe "+round(aerobrake_result["final_periapsis"]/1000,1)+" km; Ap "+round(aerobrake_result["final_apoapsis"]/1000,1)+" km".
    print "No post-pass burn. The next periapsis can re-enter; plan the next maneuver manually.".
}
