// Onboard pass planning uses FAR's force query. This is independent of the
// offline POS simulation environment. No logging occurs in forecast functions.
function aerobrake_entry_state {
    parameter position, velocity.
    local mu is BODY:mu. local radius is BODY:radius.
    local entry_r is radius+BODY:atm:height+5000.
    local h is vcrs(position,velocity).
    local energy is velocity:sqrmagnitude/2-mu/position:mag.
    local evec is ((velocity:sqrmagnitude-mu/position:mag)*position-vdot(position,velocity)*velocity)/mu.
    local eccentricity is evec:mag.
    if eccentricity < 0.00001 or h:mag < 1 { return 0. }
    local cos_nu is (h:sqrmagnitude/(mu*entry_r)-1)/eccentricity.
    if abs(cos_nu) > 1 { return 0. }
    local sin_nu is -sqrt(max(0,1-cos_nu^2)).
    local p_axis is evec:normalized.
    local q_axis is vcrs(h,p_axis):normalized.
    local radial is p_axis*cos_nu+q_axis*sin_nu.
    local tangent is -p_axis*sin_nu+q_axis*cos_nu.
    local radial_speed is mu/h:mag*eccentricity*sin_nu.
    local pos is radial*entry_r.
    local vel is radial*radial_speed+tangent*(h:mag/entry_r).
    return lex("simtime",0,"position",pos,"velocity",vel,
        "surfvel",vel-vcrs(BODY:angularvel,pos),"altitude",entry_r-radius,"latlong",vec2pos(pos)).
}

function aerobrake_forecast_q {
    parameter altitude, speed.
    local pressure_pa is BODY:atm:altitudepressure(max(0,altitude))*constant:atmtokpa*1000.
    local density is pressure_pa*BODY:atm:molarmass/(8.314462618*max(1,BODY:atm:altitudetemperature(max(0,altitude)))).
    return density*speed^2/2000.
}

function aerobrake_forecast {
    parameter start_state, target_pe, deadline_ut.
    local out is lex("valid",false,"reason","invalid_entry_state","peak_q",0,"peak_g",0,"peak_heat",0,"min_alt",1e9).
    if not start_state:istype("Lexicon") { return out. }
    local state is clone_simstate(start_state).
    local entered is false. local exiting is false.
    local mu is BODY:mu. local radius is BODY:radius.
    local cfg is AVES["Aerobrake"].
    local dt is cfg["prediction_step"].
    local aero is v(0,0,0).
    until state["simtime"] > AVES["Entry"]["max_prediction_time"] {
        if time:seconds >= deadline_ut { set out["reason"] to "planning_budget". return out. }
        local metrics is atmospheric_metrics(state["position"],state["velocity"],state["surfvel"],aero,
            aerobrake_forecast_q(state["altitude"],state["surfvel"]:mag),mu,radius).
        local command is aerobrake_command(metrics,target_pe,exiting,mu,radius).
        set exiting to command["exiting"].
        set aero to sim_aeroaccel_load(state["position"],state["surfvel"],list(command["aoa"],command["bank"]),radius).
        set out["peak_q"] to max(out["peak_q"],metrics["q_kpa"]).
        set out["peak_g"] to max(out["peak_g"],aero:mag/9.80665).
        set out["peak_heat"] to max(out["peak_heat"],metrics["heat_proxy"]).
        set out["min_alt"] to min(out["min_alt"],state["altitude"]).
        if state["altitude"] < BODY:atm:height { set entered to true. }
        if entered and state["altitude"] > BODY:atm:height+cfg["exit_margin"] and metrics["vertical_speed"] > 0 {
            local margin is cfg["planning_margin"].
            set out["valid"] to out["peak_q"] <= AVES["Entry"]["max_q_kpa"]*margin and
                out["peak_g"] <= AVES["Entry"]["max_aero_g"]*margin and
                out["peak_heat"] <= AVES["Entry"]["max_heat_proxy"]*margin and
                out["min_alt"] >= cfg["floor_altitude"] and
                (metrics["energy"] >= 0 or metrics["apoapsis"] >= cfg["exit_apoapsis_floor"]).
            set out["energy"] to metrics["energy"].
            set out["apoapsis"] to metrics["apoapsis"].
            set out["reason"] to "predicted_exit".
            if not out["valid"] { set out["reason"] to "prediction_limits". }
            return out.
        }
        if state["altitude"] < cfg["floor_altitude"]-1000 {
            set out["reason"] to "predicted_full_entry". return out.
        }
        set state to update_simstate_total_accel(state,aero+gravitacc(state["position"],mu),dt,BODY:angularvel,radius).
    }
    set out["reason"] to "no_predicted_exit".
    return out.
}

function aerobrake_plan {
    local cfg is AVES["Aerobrake"].
    local out is lex("valid",false,"reason","no_safe_pass","candidates",list()).
    if hasnode { set out["reason"] to "existing_maneuver_node". return out. }
    if ship:verticalspeed >= 0 or ship:altitude < BODY:atm:height+100000 {
        set out["reason"] to "start_inbound_above_170km". return out.
    }
    local burn_ut is time:seconds+cfg["node_lead"].
    if ship:orbit:hasnextpatch and ship:orbit:eta:transition < cfg["node_lead"] {
        set out["reason"] to "soi_transition_before_correction". return out.
    }
    local position is positionat(ship,burn_ut)-BODY:position.
    local velocity is velocityat(ship,burn_ut):orbit.
    if position:mag < BODY:radius+BODY:atm:height+50000 or vdot(position,velocity) >= 0 {
        set out["reason"] to "insufficient_approach_time". return out.
    }
    local deadline_ut is time:seconds+cfg["prediction_budget"].
    local best_energy is 1e30.
    local pe is cfg["max_pe"].
    // Every accepted candidate must actually leave the atmosphere in the FAR
    // forecast. Among them choose the lowest exit energy, including unbound
    // passes when capture cannot be attained within the load limits.
    until pe < cfg["min_pe"] or time:seconds >= deadline_ut {
        local correction is aerobrake_periapsis_velocity(position,velocity,BODY:radius+pe,BODY:mu).
        if correction["valid"] {
            local dv is correction["velocity"]-velocity.
            if dv:mag <= cfg["max_correction_dv"] {
                local forecast is aerobrake_forecast(aerobrake_entry_state(position,correction["velocity"]),pe,deadline_ut).
                forecast:add("pe",pe).
                out["candidates"]:add(forecast).
                if forecast["valid"] and forecast["energy"] < best_energy {
                    set best_energy to forecast["energy"].
                    set out["valid"] to true. set out["reason"] to "pass_selected".
                    set out["pe"] to pe. set out["dv"] to dv. set out["forecast"] to forecast.
                }
            }
        }
        set pe to pe-cfg["pe_step"].
    }
    if not out["valid"] { return out. }
    if burn_ut-time:seconds < 60 { set out["valid"] to false. set out["reason"] to "planning_too_late". return out. }
    local maneuver is pos_node_from_vector(burn_ut,out["dv"]).
    if abs(maneuver:orbit:periapsis-out["pe"]) > cfg["periapsis_tolerance"] or maneuver:orbit:body:name <> BODY:name {
        remove maneuver.
        set out["valid"] to false. set out["reason"] to "node_periapsis_mismatch". return out.
    }
    set out["node"] to maneuver.
    return out.
}
