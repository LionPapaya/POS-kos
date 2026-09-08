// Live Poseidon PDI mission, approvals, control handovers and telemetry.
// Pure guidance and prediction live in pdi_guidance.ks / pdi_terminal.ks.

global PDI_PLANNING_DISPLAY is false.
global PDI_PLANNING_STATUS_ACTIVE is false.
global PDI_PLANNING_NEXT_CONSOLE_TIME is -1.

function pdi_planning_status {
    parameter stage_label, detail.
    set Lastest_status to "PDI " + stage_label + ": " + detail.
    if PDI_PLANNING_STATUS_ACTIVE { set PDI_PLANNING_DISPLAY:text to Lastest_status. }
    if time:seconds >= PDI_PLANNING_NEXT_CONSOLE_TIME {
        print Lastest_status.
        set PDI_PLANNING_NEXT_CONSOLE_TIME to time:seconds+0.5.
    }
}

function vacuum_target_input {
    parameter target_lat, target_lng.
    local result is lex("valid",false,"lat",0,"lng",0).
    local dialog is GUI(430,210).
    dialog:addlabel("Poseidon PDI landing coordinates").
    dialog:addlabel("Latitude (-90..90)").
    local lat_field is dialog:addtextfield("").
    dialog:addlabel("Longitude (-180..180)").
    local lng_field is dialog:addtextfield("").
    if target_lat <> "ASK" { set lat_field:text to target_lat:tostring. }
    if target_lng <> "ASK" { set lng_field:text to target_lng:tostring. }
    local message is dialog:addlabel("").
    local done is false.
    local accept is dialog:addbutton("Use landing site").
    set accept:onclick to {
        local lat_value is lat_field:text:tonumber(-9999).
        local lng_value is lng_field:text:tonumber(-9999).
        if abs(lat_value) <= 90 and abs(lng_value) <= 180 {
            set result["lat"] to lat_value.
            set result["lng"] to lng_value.
            set result["valid"] to true.
            set done to true.
        }else{ set message:text to "Enter valid numeric latitude and longitude.". }
    }.
    local cancel is dialog:addbutton("Cancel").
    set cancel:onclick to { set done to true. }.
    dialog:show().
    until done { wait 0.1. }
    dialog:hide().
    return result.
}

function vacuum_phase {
    parameter mission, phase, reason.
    set mission["phase"] to phase.
    set mission["reason"] to reason.
    set step to phase.
    set substep to reason.
    set Lastest_status to reason.
    flight_log_event("pdi_phase","phase="+phase+"|reason="+reason).
}

function vacuum_command {
    parameter mission, thrust_direction, throttle_set.
    if thrust_direction:mag < 0.0001 { set thrust_direction to ship:up:vector. }
    set thrust_direction to thrust_direction:normalized.
    set dap["vector"]["targetVector"] to thrust_direction.
    set dapthrottle to pdi_clamp(throttle_set,0,1).
    if mission["flip_committed"] { set dapthrottle to 0. }
    set mission["telemetry"]["steer_x"] to thrust_direction:x.
    set mission["telemetry"]["steer_y"] to thrust_direction:y.
    set mission["telemetry"]["steer_z"] to thrust_direction:z.
}

function vacuum_tick {
    parameter mission.
    local surface_up is ship:up:vector.
    local surface_velocity is ship:velocity:surface.
    local lateral_velocity is surface_velocity-surface_up*vdot(surface_velocity,surface_up).
    local radius is -ship:body:position.
    local target_radius is mission["site"]:altitudeposition(mission["altitude"])-ship:body:position.
    set mission["distance"] to vang(radius,target_radius)*constant:degtorad*ship:body:radius.
    set mission["clearance"] to pdi_ground_clearance(mission["bounds"]).
    set mission["telemetry"]["horizontal_speed"] to lateral_velocity:mag.
    set mission["telemetry"]["flip_committed"] to mission["flip_committed"].
    dap:update().
    flight_log_capture_pdi(mission["telemetry"],mission["solver_reason"]).
    flight_log_capture_vacuum_guidance(mission["phase"],mission["distance"],mission["clearance"],surface_velocity:mag,
        mission["desired_vs"],dapthrottle,mission["stopping_distance"],mission["vehicle"]["thrust"]/max(0.001,ship:mass),
        ship:status = "LANDED",mission["pitch_target"]).
    flight_log_tick("vacuum_landing",mission["phase"],mission["reason"]).
    if time:seconds >= mission["next_display"] {
        local ignition_status is "".
        if mission["phase"] = "vacuum_coast" and mission["telemetry"]["ignition_ut"] > time:seconds {
            set ignition_status to " | PDI ignition in "+round(mission["telemetry"]["ignition_ut"]-time:seconds,1)+" s".
        }else if mission["phase"] = "vacuum_pdi" {
            set ignition_status to " | PDI ignition: NOW".
        }
        set mission["display"]:text to mission["phase"]+" | "+mission["reason"]+
            " | Range "+round(mission["distance"],1)+" m | Clearance "+round(mission["clearance"],1)+" m"+
            " | H "+round(lateral_velocity:mag,2)+" m/s | V "+round(ship:verticalspeed,2)+" m/s"+
            " | PDI "+mission["solver_reason"]+" | Tgo "+round(mission["telemetry"]["tgo"],1)+" s"+ignition_status.
        set mission["next_display"] to time:seconds+0.5.
    }
}

function vacuum_stop {
    parameter mission, success, reason.
    set dapthrottle to 0.
    set ship:control:pilotmainthrottle to 0.
    nervsoff().
    rapiersoff().
    flight_log_event("vacuum_landing_complete","success="+success+"|reason="+reason+"|target_distance="+mission["distance"]).
    set recovery_result to lex("complete",true,"success",success,"reason",reason).
    dap:set_off().
    unlock throttle.
    set vacuum_landing_active to false.
    set PDI_PLANNING_STATUS_ACTIVE to false.
    rcs off.
    set mission["running"] to false.
    mission["gui"]:hide().
    print "Poseidon PDI: "+reason.
}

function vacuum_node_fingerprint {
    parameter maneuver.
    return list(maneuver:time,maneuver:radialout,maneuver:normal,maneuver:prograde).
}

function vacuum_node_matches {
    parameter fingerprint.
    if allnodes:length <> 1 { return false. }
    return abs(nextnode:time-fingerprint[0]) < 0.01 and abs(nextnode:radialout-fingerprint[1]) < 0.001 and
        abs(nextnode:normal-fingerprint[2]) < 0.001 and abs(nextnode:prograde-fingerprint[3]) < 0.001.
}

function vacuum_approve_node {
    parameter mission, maneuver, purpose, details.
    set dapthrottle to 0.
    set warp to 0.
    local fingerprint is vacuum_node_fingerprint(maneuver).
    local decision is "pending".
    local dialog is GUI(470,270).
    dialog:addlabel("Review "+purpose+" node in the map").
    dialog:addlabel(details).
    dialog:addlabel("Target: "+round(mission["site"]:lat,5)+", "+round(mission["site"]:lng,5)).
    local summary is dialog:addlabel("").
    local approve is dialog:addbutton("Execute this node").
    set approve:onclick to { set decision to "execute". }.
    local replan is dialog:addbutton("Replan").
    set replan:onclick to { set decision to "replan". }.
    local cancel is dialog:addbutton("Cancel program (keep node)").
    set cancel:onclick to { set decision to "cancel". }.
    dialog:show().
    set mission["display"]:text to "Node ready. Use the separate review window to Execute, Replan, or Cancel.".
    set mission["telemetry"]["node_approved"] to false.
    set mission["telemetry"]["node_dv"] to maneuver:deltav:mag.
    vacuum_phase(mission,"vacuum_node_review",purpose+" approval required").
    flight_log_event("pdi_node_review","purpose="+purpose+"|ut="+maneuver:time+"|dv="+maneuver:deltav:mag+
        "|periapsis="+maneuver:orbit:periapsis+"|inclination="+maneuver:orbit:inclination).
    until decision <> "pending" {
        if mission["cancel"] { set decision to "cancel". }
        if not vacuum_node_matches(fingerprint) { set decision to "changed". }
        if maneuver:eta < pdi_node_duration(maneuver,mission["vehicle"])/2+45 { set decision to "expired". }
        set summary:text to "ETA "+round(maneuver:eta,1)+" s | Delta-v "+round(maneuver:deltav:mag,1)+
            " m/s | Inclination "+round(maneuver:orbit:inclination,2)+" deg | Pe "+round(maneuver:orbit:periapsis,0)+" m".
        vacuum_tick(mission).
        wait 0.1.
    }
    dialog:hide().
    if decision = "execute" and not vacuum_node_matches(fingerprint) { set decision to "changed". }
    if decision = "execute" and maneuver:eta < pdi_node_duration(maneuver,mission["vehicle"])/2+45 { set decision to "expired". }
    set mission["telemetry"]["node_approved"] to decision = "execute".
    flight_log_event("pdi_node_decision","purpose="+purpose+"|decision="+decision).
    return decision.
}

function vacuum_execute_node {
    parameter mission, maneuver, purpose.
    if not mission["telemetry"]["node_approved"] { return false. }
    local pdi_config is mission["config"].
    local duration is pdi_node_duration(maneuver,mission["vehicle"]).
    local fingerprint is vacuum_node_fingerprint(maneuver).
    vacuum_phase(mission,"vacuum_node_coast",purpose).
    vacuum_command(mission,maneuver:deltav,0).
    until maneuver:eta <= duration/2+60 {
        if mission["cancel"] or not vacuum_node_matches(fingerprint) { return false. }
        if maneuver:eta > duration/2+90 { warpto(maneuver:time-duration/2-60). }
        vacuum_tick(mission).
        wait 0.
    }
    set warp to 0.
    local alignment_deadline is min(time:seconds+40,maneuver:time-duration/2).
    until vang(maneuver:deltav,ship:facing:vector) < 2 {
        if mission["cancel"] or time:seconds >= alignment_deadline { return false. }
        vacuum_command(mission,maneuver:deltav,0).
        vacuum_tick(mission).
        wait 0.
    }
    until maneuver:eta <= duration/2 {
        if mission["cancel"] or not vacuum_node_matches(fingerprint) { return false. }
        vacuum_command(mission,maneuver:deltav,0).
        vacuum_tick(mission).
        wait 0.
    }
    local ignition_ut is time:seconds.
    local completed is false.
    vacuum_phase(mission,"vacuum_node_burn",purpose).
    flight_log_event("pdi_node_ignition","purpose="+purpose+"|dv="+maneuver:deltav:mag+"|estimated_duration="+duration).
    until completed {
        if mission["cancel"] or time:seconds > ignition_ut+duration*2+15 { set dapthrottle to 0. return false. }
        local available is ship:availablethrust/max(0.001,ship:mass).
        if available < 0.01 { set dapthrottle to 0. return false. }
        local residual is maneuver:deltav.
        local throttle_set is min(1,residual:mag/available).
        local alignment_limit is 15.
        if residual:mag < 1 {
            // In the terminal correction, ask for no more than a half
            // metre-per-second-scale impulse over node_terminal_time.  This
            // avoids a late control tick consuming the old 0.3 m/s allowance.
            set throttle_set to min(throttle_set,residual:mag/(available*pdi_config["node_terminal_time"])).
            set alignment_limit to 3.
        }
        if vang(residual,ship:facing:vector) > alignment_limit { set throttle_set to 0. }
        vacuum_command(mission,residual,throttle_set).
        vacuum_tick(mission).
        // A residual that reverses direction is still correctable.  Continue
        // the closed loop instead of accepting an overshoot.
        if residual:mag < pdi_config["node_completion_dv"] { set completed to true. }
        wait 0.
    }
    set dapthrottle to 0.
    flight_log_event("pdi_node_complete","purpose="+purpose+"|residual="+maneuver:deltav:mag+"|target_residual="+pdi_config["node_completion_dv"]+"|duration="+(time:seconds-ignition_ut)).
    remove maneuver.
    set mission["telemetry"]["node_approved"] to false.
    set mission["vehicle"] to pdi_vehicle_snapshot(mission["engines"],mission["fuel_parts"],pdi_config).
    return true.
}

function vacuum_accept_solution {
    parameter mission, solution, epoch.
    set mission["command"] to lex("ut",epoch,"lambda",solution["lambda"],"lambda_dot",solution["lambda_dot"],
        "jol",solution["jol"],"tgo",solution["tgo"],"throttle",solution["command_throttle"]).
    set mission["last_solution_ut"] to epoch.
}

function vacuum_solver_telemetry {
    parameter mission, solution.
    local data is mission["telemetry"].
    set data["valid"] to solution["valid"].
    set data["converged"] to solution["converged"].
    set data["tgo"] to solution["tgo"].
    set data["position_error"] to solution["position_error"].
    set data["velocity_error"] to solution["velocity_error"].
    set data["iterations"] to solution["iterations"].
    if solution["prediction"]["valid"] { set data["predicted_final_mass"] to solution["prediction"]["mass"]. }
    set mission["solver_reason"] to solution["reason"].
}

function vacuum_emergency {
    parameter mission, reason.
    if mission["phase"] = "vacuum_emergency_brake" { return. }
    vacuum_phase(mission,"vacuum_emergency_brake",reason).
    set mission["solver_reason"] to reason.
    set mission["telemetry"]["valid"] to false.
    set mission["telemetry"]["converged"] to false.
    set mission["diverted"] to true.
    flight_log_event("pdi_fallback","reason="+reason+"|clearance="+mission["clearance"]+"|speed="+ship:velocity:surface:mag).
}

function vacuum_reconverge {
    parameter mission, reason.
    local pdi_config is mission["config"].
    // First retain the requested landing site.  A fresh solve starts from the
    // measured vehicle state, rather than from an invalidated tangent law.
    flight_log_event("pdi_reconvergence_start","reason="+reason+"|target=requested").
    local landing_target is pdi_live_target(mission["site"],mission["altitude"],pdi_config).
    local recovery_plan is pdi_suborbital_plan(landing_target,mission["vehicle"],pdi_config).
    local retargeted is false.
    if not recovery_plan["valid"] {
        // The current ballistic impact point is the closest practical site
        // when the original target is no longer reachable.  Solve and fully
        // validate it before committing the mission to the diversion.
        local alternate is pdi_suborbital_landing_site().
        local alternate_target is pdi_live_target(alternate["site"],alternate["altitude"],pdi_config).
        set recovery_plan to pdi_suborbital_plan(alternate_target,mission["vehicle"],pdi_config).
        if recovery_plan["valid"] {
            set mission["site"] to alternate["site"].
            set mission["altitude"] to alternate["altitude"].
            set mission["diverted"] to true.
            set retargeted to true.
            flight_log_set_vacuum_target(mission["site"],mission["altitude"],mission["heading"]).
            flight_log_event("pdi_retarget","reason="+reason+"|lat="+mission["site"]:lat+
                "|lng="+mission["site"]:lng+"|altitude="+mission["altitude"]+"|impact_ut="+alternate["impact_ut"]).
        }
    }
    if not recovery_plan["valid"] {
        flight_log_event("pdi_reconvergence_failed","reason="+reason+"|solver_reason="+recovery_plan["reason"]).
        return false.
    }
    vacuum_accept_solution(mission,recovery_plan["solution"],time:seconds).
    set mission["pdi_internal"] to recovery_plan["solution"].
    vacuum_solver_telemetry(mission,recovery_plan["solution"]).
    set mission["telemetry"]["predicted_clearance"] to recovery_plan["clearance"].
    set mission["last_solution_ut"] to time:seconds.
    set mission["solver_reason"] to "reconverged".
    local target_label is "requested".
    if retargeted { set target_label to "alternate". }
    flight_log_event("pdi_reconverged","reason="+reason+"|target="+target_label+
        "|tgo="+recovery_plan["solution"]["tgo"]+"|clearance="+recovery_plan["clearance"]+
        "|position_error="+recovery_plan["position_error"]+"|velocity_error="+recovery_plan["velocity_error"]).
    return true.
}

function pdi_is_suborbital {
    return ship:orbit:eccentricity >= 1 or ship:orbit:periapsis < ship:geoposition:terrainheight+500.
}

function vacuum_descent {
    parameter mission, plan.
    local pdi_config is mission["config"].
    local ignition_ut is plan["ignition_ut"].
    set mission["telemetry"]["ignition_ut"] to ignition_ut.
    set mission["telemetry"]["predicted_clearance"] to plan["clearance"].
    local landing_target is pdi_live_target(mission["site"],mission["altitude"],pdi_config).
    local solution is plan["solution"].
    local post_node_within_live_limits is false.
    // Re-converge against the actual post-node orbit: a finite burn does not
    // reproduce KSP's instantaneous maneuver prediction exactly.  A POS4
    // suborbital plan is already based on the live state and must ignite now.
    if not plan:haskey("immediate") {
        // Candidate planning is deliberately bounded for kOS responsiveness.
        // This one correction occurs only after the approved node has been
        // executed and has ample coast time, so retain the original solver
        // budget to avoid rejecting a sound plan at its 36-iteration cutoff.
        local planning_iterations is pdi_config["planning_iterations"].
        set pdi_config["planning_iterations"] to pdi_config["post_node_iterations"].
        pdi_planning_status("post-node","revalidating the actual post-burn trajectory").
        set solution to pdi_solve(pdi_future_state(max(time:seconds+1,ignition_ut),ship:mass),landing_target,mission["vehicle"],pdi_config).
        set pdi_config["planning_iterations"] to planning_iterations.
        local post_node_position_error is -1.
        local post_node_velocity_error is -1.
        if solution:haskey("position_error") { set post_node_position_error to solution["position_error"]. }
        if solution:haskey("velocity_error") { set post_node_velocity_error to solution["velocity_error"]. }
        if solution["valid"] and solution:haskey("position_error") and solution:haskey("velocity_error") {
            // The post-node state can differ from the instantaneous-node
            // prediction by the finite burn's travel.  Permit this bounded
            // handoff; powered descent applies the strict live limits after
            // rebasing UPFG to the measured state.
            set post_node_within_live_limits to post_node_position_error <= pdi_config["post_node_position_tolerance"] and
                post_node_velocity_error <= pdi_config["live_velocity_tolerance"].
        }
        flight_log_event("pdi_post_node_solution","valid="+solution["valid"]+"|converged="+solution["converged"]+
            "|reason="+solution["reason"]+"|iterations="+solution["iterations"]+"|position_error="+post_node_position_error+
            "|velocity_error="+post_node_velocity_error+"|within_post_node_limits="+post_node_within_live_limits+
            "|position_limit="+pdi_config["post_node_position_tolerance"]+"|budget="+pdi_config["post_node_iterations"]).
    }
    vacuum_solver_telemetry(mission,solution).
    if solution["valid"] and (solution["converged"] or post_node_within_live_limits) and
        (plan:haskey("immediate") or time:seconds < ignition_ut-10) {
        vacuum_accept_solution(mission,solution,ignition_ut).
        set mission["pdi_internal"] to solution.
        if post_node_within_live_limits and not solution["converged"] {
            set mission["solver_reason"] to "post_node_command_within_live_limits".
            flight_log_event("pdi_post_node_fallback","reason=within_post_node_limits|position_error="+solution["position_error"]+
                "|velocity_error="+solution["velocity_error"]+"|ignition_ut="+ignition_ut).
        }
        if plan:haskey("immediate") {
            vacuum_phase(mission,"vacuum_pdi","suborbital guided NERV powered descent").
            flight_log_event("pdi_ignition","planned_ut="+ignition_ut+"|actual_ut="+time:seconds+"|mode=suborbital").
        }else{ vacuum_phase(mission,"vacuum_coast","coast to predicted PDI ignition"). }
    }else{ vacuum_emergency(mission,"post_deorbit_solution_unavailable"). }
    local next_guidance is ignition_ut.
    local next_vehicle is time:seconds.
    local next_terrain is time:seconds.
    local flip_since is -1.
    local landed_since is -1.
    local ignition_alignment_wait_logged is false.
    local next_coast_guidance is max(time:seconds,ignition_ut-pdi_config["coast_update_lead"]).
    local coast_replan_logged is false.
    until not mission["running"] {
        if mission["cancel"] { vacuum_stop(mission,false,"pilot_cancelled"). return. }
        local now is time:seconds.
        local surface_up is ship:up:vector.
        local surface_velocity is ship:velocity:surface.
        local vertical_speed is vdot(surface_velocity,surface_up).
        local horizontal_speed is (surface_velocity-surface_up*vertical_speed):mag.
        local clearance is pdi_ground_clearance(mission["bounds"]).
        local gravity is ship:body:mu/(ship:body:radius+ship:altitude)^2.
        if now >= next_vehicle and not mission["flip_committed"] {
            set mission["vehicle"] to pdi_vehicle_snapshot(mission["engines"],mission["fuel_parts"],pdi_config).
            set next_vehicle to now+1.
        }
        local available is mission["vehicle"]["thrust"]/max(0.001,ship:mass).
        local vertical_reserve is max(0,available-gravity).
        set mission["stopping_distance"] to max(0,-vertical_speed)^2/max(0.02,2*vertical_reserve).
        set mission["telemetry"]["vertical_margin"] to available-gravity.
        set mission["telemetry"]["solution_age"] to max(0,now-mission["last_solution_ut"]).
        if not mission["flip_committed"] and available < 0.01 {
            vacuum_stop(mission,false,"no_nerv_thrust_manual_control"). return.
        }
        if mission["phase"] = "vacuum_coast" {
            if now >= ignition_ut-pdi_config["coast_update_lead"] and now >= next_coast_guidance {
                // Propagate from the measured coast state to the scheduled
                // ignition instant, then update the attitude command from
                // that forecast.  POSITIONAT cannot include the finite node
                // burn, so it would repeat the original alignment error.
                local frame is pdi_frame().
                local live_state is pdi_live_state(frame).
                local coast_duration is max(0,ignition_ut-now).
                local forecast is pdi_coast(live_state["r"],live_state["v"],coast_duration,mission["vehicle"]["mu"],32).
                local ignition_state is lex("r",forecast["r"],"v",forecast["v"],"mass",ship:mass,"ut",ignition_ut).
                set landing_target to pdi_live_target(mission["site"],mission["altitude"],pdi_config).
                local saved_iterations is pdi_config["planning_iterations"].
                set pdi_config["planning_iterations"] to pdi_config["coast_iterations"].
                local coast_solution is pdi_solve(ignition_state,landing_target,mission["vehicle"],pdi_config).
                set pdi_config["planning_iterations"] to saved_iterations.
                if coast_solution["valid"] {
                    vacuum_accept_solution(mission,coast_solution,ignition_ut).
                    set mission["pdi_internal"] to coast_solution.
                    vacuum_solver_telemetry(mission,coast_solution).
                    if not coast_replan_logged {
                        flight_log_event("pdi_coast_replan","lead_time="+coast_duration+"|iterations="+
                            coast_solution["iterations"]+"|reason="+coast_solution["reason"]).
                        set coast_replan_logged to true.
                    }
                }
                set next_coast_guidance to time:seconds+pdi_config["coast_update_interval"].
            }
            local command is mission["command"].
            // Track the tangent steering law at the current coast time.  The
            // previous implementation held the t=0 vector for the entire
            // coast, so the vessel could reach ignition pointing at a stale
            // direction while UPFG immediately requested a large reversal.
            local command_elapsed is max(0,now-command["ut"]).
            local thrust_direction is command["lambda"]+command["lambda_dot"]*(command_elapsed-command["jol"]).
            local coast_direction is pdi_to_raw(thrust_direction,pdi_frame()).
            vacuum_command(mission,coast_direction,0).
            if now >= ignition_ut {
                local ignition_alignment_error is vang(coast_direction,ship:facing:vector).
                if ignition_alignment_error > 8 {
                    if not ignition_alignment_wait_logged {
                        flight_log_event("pdi_ignition_alignment_wait","planned_ut="+ignition_ut+
                            "|actual_ut="+now+"|error_deg="+ignition_alignment_error).
                        set ignition_alignment_wait_logged to true.
                    }
                }else {
                    if ignition_alignment_wait_logged {
                        flight_log_event("pdi_ignition_alignment_ready","actual_ut="+now+
                            "|delay="+(now-ignition_ut)+"|error_deg="+ignition_alignment_error).
                    }
                    vacuum_phase(mission,"vacuum_pdi","guided NERV powered descent").
                    flight_log_event("pdi_ignition","planned_ut="+ignition_ut+"|actual_ut="+now).
                }
            }
        }
        if mission["phase"] = "vacuum_pdi" {
            local target_offset is mission["site"]:altitudeposition(mission["altitude"])-ship:position.
            local range_to_tgt is (target_offset-surface_up*vdot(target_offset,surface_up)):mag.
            // Position, velocity and altitude must all be inside the terminal
            // capture region. Time-to-go alone cannot establish safe handover.
            if clearance < pdi_config["handover_altitude"]*1.6 and range_to_tgt < pdi_config["handover_distance"] and
                surface_velocity:mag < pdi_config["handover_speed"] and vang(ship:facing:vector,surface_up) < 45 {
                vacuum_phase(mission,"vacuum_translate","terminal position capture").
                gear on. brakes on.
            }else if now >= next_guidance {
                local frame is pdi_frame().
                local state is pdi_live_state(frame).
                set landing_target to pdi_live_target(mission["site"],mission["altitude"],pdi_config).
                // Rebase and iterate the UPFG state against the measured
                // vehicle, as in Dondi's live landing loop.  The pre-node
                // command remains the seed, while each update corrects for
                // finite node-burn timing, mass flow and state drift.
                local internal is mission["pdi_internal"].
                pdi_rebase(internal,state).
                local live_iteration is 0.
                until live_iteration >= pdi_config["live_iterations"] or not internal["valid"] {
                    pdi_iterate(state,landing_target,mission["vehicle"],internal,pdi_config).
                    set live_iteration to live_iteration+1.
                }
                set mission["pdi_internal"] to internal.
                local command is mission["command"].
                if internal["valid"] {
                    vacuum_accept_solution(mission,internal,state["ut"]).
                    set command to mission["command"].
                    set mission["telemetry"]["valid"] to internal["valid"].
                    set mission["telemetry"]["converged"] to internal["converged"].
                    set mission["telemetry"]["tgo"] to internal["tgo"].
                    set mission["telemetry"]["position_error"] to internal["position_error"].
                    set mission["telemetry"]["velocity_error"] to internal["velocity_error"].
                    set mission["telemetry"]["iterations"] to internal["iterations"].
                    set mission["solver_reason"] to "live_"+internal["reason"].
                }else{ set mission["solver_reason"] to internal["reason"]. }
                // UPFG's linear tangent law is one continuous burn. Validate
                // the rebased command using measured mass/state before
                // applying its new steering.
                local prediction is pdi_command_predict(state,mission["vehicle"],command,pdi_config["predictor_steps"]*2).
                local acceptable is prediction["valid"].
                local position_error is 1e9.
                local velocity_error is 1e9.
                if acceptable {
                    local arrival is pdi_target_at(landing_target,state["ut"]+command["tgo"]-(state["ut"]-command["ut"])).
                    set position_error to (prediction["r"]-arrival["r"]):mag.
                    set velocity_error to (prediction["v"]-arrival["v"]):mag.
                    set acceptable to position_error < pdi_config["live_position_tolerance"] and velocity_error < pdi_config["live_velocity_tolerance"].
                    set mission["telemetry"]["position_error"] to position_error.
                    set mission["telemetry"]["velocity_error"] to velocity_error.
                    set mission["telemetry"]["predicted_final_mass"] to prediction["mass"].
                    set mission["telemetry"]["iterations"] to internal["iterations"].
                    set mission["telemetry"]["valid"] to acceptable.
                    set mission["telemetry"]["converged"] to acceptable.
                    set mission["solver_reason"] to "command_validated".
                }else{ set mission["solver_reason"] to prediction["reason"]. }
                if acceptable and now >= next_terrain {
                    local terrain_scan_started is time:seconds.
                    local predicted_clearance is pdi_path_clearance(prediction["path"],state["ut"],pdi_config,pdi_config["live_terrain_samples"]).
                    set mission["telemetry"]["predicted_clearance"] to predicted_clearance.
                    if predicted_clearance < pdi_config["terrain_margin"] { set acceptable to false. vacuum_emergency(mission,"predicted_terrain_conflict"). }
                    local terrain_scan_duration is time:seconds-terrain_scan_started.
                    if terrain_scan_duration > pdi_config["guidance_interval"] {
                        flight_log_event("pdi_terrain_scan_slow","duration="+terrain_scan_duration+"|samples="+pdi_config["live_terrain_samples"]+"|clearance="+predicted_clearance).
                    }
                    set next_terrain to time:seconds+2.
                }
                // Record the completed validation time.  The former state
                // timestamp could be several seconds old after terrain API
                // calls, falsely tripping stale guidance immediately after
                // ignition even though the command had validated correctly.
                if acceptable { set mission["last_solution_ut"] to time:seconds. }
                if time:seconds-mission["last_solution_ut"] > pdi_config["maximum_solution_age"] {
                    local recovery_reason is mission["solver_reason"].
                    if not vacuum_reconverge(mission,recovery_reason) { vacuum_emergency(mission,"stale_or_diverged_guidance"). }
                    set next_terrain to time:seconds.
                }
                set next_guidance to time:seconds+pdi_config["guidance_interval"].
            }
            if mission["phase"] = "vacuum_pdi" {
                local command is mission["command"].
                local elapsed is time:seconds-command["ut"].
                local thrust_direction is command["lambda"]+command["lambda_dot"]*(elapsed-command["jol"]).
                vacuum_command(mission,pdi_to_raw(thrust_direction,pdi_frame()),command["throttle"]).
            }
        }
        if mission["phase"] = "vacuum_emergency_brake" {
            local requested is surface_up*(gravity+max(0,-vertical_speed)*0.8)-(surface_velocity-surface_up*vertical_speed)*0.25.
            local acceleration is pdi_vertical_priority(surface_up,requested,available,70).
            vacuum_command(mission,acceleration,acceleration:mag/max(0.001,available)).
            if horizontal_speed < 20 and abs(vertical_speed) < 10 {
                set mission["site"] to latlng(ship:geoposition:lat,ship:geoposition:lng).
                set mission["altitude"] to mission["site"]:terrainheight.
                flight_log_set_vacuum_target(mission["site"],mission["altitude"],mission["heading"]).
                flight_log_event("pdi_emergency_site","reason="+mission["reason"]+"|lat="+mission["site"]:lat+"|lng="+mission["site"]:lng).
                vacuum_phase(mission,"vacuum_translate","emergency landing at current site").
            }
        }
        if mission["phase"] = "vacuum_translate" {
            gear on. brakes on.
            local offset is mission["site"]:altitudeposition(mission["altitude"])-ship:position.
            local terminal_command is pdi_terminal_command(offset,surface_velocity,surface_up,clearance,gravity,available,pdi_config).
            set mission["desired_vs"] to terminal_command["desired_vs"].
            set mission["telemetry"]["saturated"] to terminal_command["saturated"].
            local thrust_command is terminal_command["acceleration"].
            vacuum_command(mission,thrust_command,thrust_command:mag/max(0.001,available)).
            // Establish wheel heading and roll before committing engine cutoff.
            if thrust_command:mag > 0.01 {
                local wheel_top is heading(mission["heading"],0):vector*-1.
                set dap["vector"]["targetVector"] to lookdirup(thrust_command:normalized,wheel_top).
            }
            local ready is pdi_flip_gate(clearance,horizontal_speed,vertical_speed,terminal_command["distance"],
                vang(ship:facing:vector,surface_up),ship:angularvel:mag*constant:radtodeg,ship:status = "LANDED",pdi_config).
            set mission["telemetry"]["flip_ready"] to ready.
            if ready { if flip_since < 0 { set flip_since to now. } }
            else { set flip_since to -1. }
            if flip_since >= 0 and now-flip_since >= pdi_config["flip_stable_time"] {
                set mission["flip_committed"] to true.
                set mission["pitch_target"] to pitch_for().
                set dapthrottle to 0.
                nervsoff().
                vacuum_phase(mission,"vacuum_pitch_over","engines off; pitch onto wheels").
                flight_log_event("pdi_flip_commit","clearance="+clearance+"|horizontal_speed="+horizontal_speed+
                    "|vertical_speed="+vertical_speed+"|tail_contact="+(ship:status = "LANDED")+"|pitch="+pitch_for()).
            }
        }
        if mission["phase"] = "vacuum_pitch_over" {
            // Latched cutoff: no solver or protection may re-ignite during tip.
            set dapthrottle to 0.
            nervsoff().
            gear on. brakes on.
            set mission["pitch_target"] to changeRate(mission["pitch_target"],pdi_config["gear_pitch"],min(0.1,max(0.01,dap["dt"])),pdi_config["flip_pitch_rate"]).
            set dap["vector"]["targetVector"] to heading(mission["heading"],mission["pitch_target"],0):vector.
            local settled is ship:status = "LANDED" and surface_velocity:mag < 0.8 and clearance < 1.5 and
                abs(pitch_for()-pdi_config["gear_pitch"]) < pdi_config["landed_pitch_tolerance"] and abs(roll_for()) < 8.
            if settled { if landed_since < 0 { set landed_since to now. } }
            else { set landed_since to -1. }
            if landed_since >= 0 and now-landed_since >= pdi_config["landed_dwell"] {
                vacuum_tick(mission).
                local success is not mission["diverted"].
                local reason is "gear_touchdown".
                if not success { set reason to "emergency_site_touchdown". }
                vacuum_stop(mission,success,reason).
                return.
            }
        }
        vacuum_tick(mission).
        wait 0.
    }
}

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
    local mission is lex("config",pdi_config,"site",site,"altitude",terrain_altitude,"heading",target_landing_heading,
        "engines",nerv_engines,"fuel_parts",fuel_parts,"vehicle",pdi_vehicle_snapshot(nerv_engines,fuel_parts,pdi_config),
        "bounds",ship:bounds,"running",true,"cancel",false,"diverted",false,"flip_committed",false,
        "phase","vacuum_plan","reason","planning","solver_reason","not_started","telemetry",data,
        "distance",0,"clearance",0,"desired_vs",0,"stopping_distance",0,"pitch_target",90,
        "last_solution_ut",time:seconds,"command",lex(),"next_display",0,"gui",gui_,"display",display).
    set cancel:onclick to { set mission["cancel"] to true. }.
    gui_:show().
    pdi_planning_status("setup","checking NERV capability and landing target").
    flight_log_set_vacuum_target(site,terrain_altitude,target_landing_heading).
    if landing_target_mode = "suborbital" {
        flight_log_event("pdi_suborbital_site","impact_ut="+suborbital_selection["impact_ut"]+"|lat="+site:lat+"|lng="+site:lng+"|altitude="+terrain_altitude).
    }
    if nerv_engines:length = 0 or mission["vehicle"]["thrust"]/ship:mass < ship:body:mu/ship:body:radius^2*pdi_config["minimum_twr"] or
        ship:mass <= mission["vehicle"]["reserve_mass"] {
        vacuum_stop(mission,false,"insufficient_nerv_thrust_or_fuel_reserve"). return.
    }
    if landing_target_mode = "suborbital" {
        vacuum_phase(mission,"vacuum_suborbital_plan","solving immediate powered descent from current trajectory").
        local direct_target is pdi_live_target(mission["site"],mission["altitude"],pdi_config).
        local direct_plan is pdi_suborbital_plan(direct_target,mission["vehicle"],pdi_config).
        if not direct_plan["valid"] { vacuum_stop(mission,false,direct_plan["reason"]). return. }
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
                "|ignition_attempts="+plan["pdi"]["attempts"]+"|candidate_limit="+pdi_config["ignition_candidates"]).
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
