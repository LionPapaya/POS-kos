// Single-stage powered descent guidance for Poseidon's NERV cluster.
// Adapted from Giulio Dondi's kOS-UPFG_PDI, e777fbbc29c2f63be907a5788da39da729f604a1:
// Ships/Script/UPFG_pdi/src/pdi_upfg_library.ks (thrust integrals, range
// correction, linear tangent steering) and pdi_targeting_library.ks.
// https://github.com/giuliodondi/kOS-UPFG_PDI
//
// Pure mathematics: no SHIP reads, controls, waits, file I/O or flight logger.
// Inputs use a body-centred INERTIAL frame, metres, seconds, tonnes and kN.
// Live adapters construct that frame; it does not rotate with kOS SHIP-RAW.
// The single-stage specialization removes staging, GUI and Shuttle globals.
// A numerical powered predictor replaces the small-angle burnout estimate.

function pdi_defaults {
    return lex(
        "minimum_twr",1.10,"planning_throttle",0.85,"minimum_throttle",0.08,
        // Planning is run in kOS before the de-orbit node is offered for
        // review.  Keep its numerical work bounded; the accepted command is
        // subsequently checked again at a higher resolution.
        "minimum_tgo",8,"maximum_tgo",1800,"planning_iterations",36,"post_node_iterations",80,
        "predictor_steps",32,"range_gain",0.25,"velocity_gain",0.7,
        "position_tolerance",15,"velocity_tolerance",0.6,
        "time_tolerance",0.5,"steering_tolerance",2,"convergence_passes",2,
        "guidance_interval",0.5,"live_iterations",3,"maximum_solution_age",3,
        "live_position_tolerance",250,"live_velocity_tolerance",2,
        "live_terrain_samples",16,
        "handover_altitude",500,"handover_speed",30,"handover_distance",200,
        "handover_vertical_speed",-3,"terrain_margin",100,"hull_margin",25,
        "reserve_delta_v",180,"deorbit_depth",2500,"node_lead_time",600,
        "node_time_iterations",10,"ignition_candidates",5,"plane_tolerance",0.5,
        // A node is an impulsive approximation.  Stop the finite correction
        // before its low-throttle tail moves the vehicle far from that state;
        // UPFG corrects the remaining residual from the measured state.
        "node_completion_dv",0.3,"node_terminal_time",2,"post_node_position_tolerance",1000,
        "maximum_plane_burn_fraction",0.08,"maximum_node_burn_fraction",0.08,
        "maximum_translation_speed",25,"maximum_lateral_acceleration",2,
        "maximum_terminal_tilt",25,"terminal_velocity_gain",0.7,
        "capture_distance",5,"capture_speed",0.4,"capture_height",30,
        "flip_clearance",0.4,"flip_vertical_speed",0.3,"flip_horizontal_speed",0.3,
        "flip_upright_error",4,"flip_stable_time",1,"flip_pitch_rate",10,
        "gear_pitch",5,"landed_pitch_tolerance",5,"landed_dwell",2
    ).
}

function pdi_clamp {
    parameter value, lower, upper.
    return max(lower,min(value,upper)).
}

function pdi_limit {
    parameter vec, limit.
    if vec:mag <= limit { return vec. }
    return vec:normalized * max(0,limit).
}

function pdi_cross {
    parameter a, b.
    return V(a:y*b:z-a:z*b:y,a:z*b:x-a:x*b:z,a:x*b:y-a:y*b:x).
}

function pdi_rotate {
    parameter vec, axis, angle.
    return vec*cos(angle) + pdi_cross(axis,vec)*sin(angle) + axis*vdot(axis,vec)*(1-cos(angle)).
}

function pdi_gravity {
    parameter radius, mu.
    return -mu*radius / max(1,radius:mag^3).
}

function pdi_target_at {
    parameter pdi_target, ut.
    local angle is (ut-pdi_target["ut"])*pdi_target["omega"]*constant:radtodeg.
    local trajectory_position is pdi_rotate(pdi_target["r"],V(0,0,1),angle).
    local vel is pdi_cross(V(0,0,pdi_target["omega"]),trajectory_position) + trajectory_position:normalized*pdi_target["vs"].
    return lex("r",trajectory_position,"v",vel).
}

function pdi_coast {
    parameter trajectory_position, vel, duration, mu, steps is 32.
    // RK4 two-body propagation. Used only on bounded same-SOI coast arcs.
    local dt is duration/max(1,steps).
    local i is 0.
    until i >= steps {
        local a1 is pdi_gravity(trajectory_position,mu).
        local v2 is vel+a1*dt/2.
        local a2 is pdi_gravity(trajectory_position+vel*dt/2,mu).
        local v3 is vel+a2*dt/2.
        local a3 is pdi_gravity(trajectory_position+v2*dt/2,mu).
        local v4 is vel+a3*dt.
        local a4 is pdi_gravity(trajectory_position+v3*dt,mu).
        set trajectory_position to trajectory_position+(vel+2*v2+2*v3+v4)*dt/6.
        set vel to vel+(a1+2*a2+2*a3+a4)*dt/6.
        set i to i+1.
    }
    return lex("r",trajectory_position,"v",vel).
}

function pdi_predict_powered {
    parameter state, vehicle, duration, throttle_set, lambda, lambda_dot, jol, steps.
    local trajectory_position is state["r"].
    local vel is state["v"].
    local pdi_mass is state["mass"].
    local force is vehicle["thrust"]*throttle_set.
    local flow is force/vehicle["ve"].
    local result is lex("valid",false,"reason","fuel_reserve","path",list()).
    if duration <= 0 or pdi_mass-flow*duration < vehicle["reserve_mass"] { return result. }
    local dt is duration/steps.
    local rgrav is V(0,0,0).
    local vgrav is V(0,0,0).
    local rthrust is V(0,0,0).
    local vthrust is V(0,0,0).
    local min_radius is trajectory_position:mag.
    result["path"]:add(lex("t",0,"r",trajectory_position,"v",vel)).
    local i is 0.
    until i >= steps {
        local mid_time is (i+0.5)*dt.
        local thrust_direction is lambda+lambda_dot*(mid_time-jol).
        if thrust_direction:mag < 0.000001 {
            set result["reason"] to "zero_thrust_vector".
            return result.
        }
        local accel is thrust_direction:normalized*force/(pdi_mass-flow*mid_time).
        local grav is pdi_gravity(trajectory_position,vehicle["mu"]).
        local mid_r is trajectory_position+vel*dt/2+(grav+accel)*dt^2/8.
        set grav to pdi_gravity(mid_r,vehicle["mu"]).
        set trajectory_position to trajectory_position+vel*dt+(grav+accel)*dt^2/2.
        set vel to vel+(grav+accel)*dt.
        set rgrav to rgrav+vgrav*dt+grav*dt^2/2.
        set vgrav to vgrav+grav*dt.
        set rthrust to rthrust+vthrust*dt+accel*dt^2/2.
        set vthrust to vthrust+accel*dt.
        set min_radius to min(min_radius,min(trajectory_position:mag,mid_r:mag)).
        result["path"]:add(lex("t",(i+1)*dt,"r",trajectory_position,"v",vel)).
        set i to i+1.
    }
    set result["valid"] to true.
    set result["reason"] to "predicted".
    result:add("r",trajectory_position).
    result:add("v",vel).
    result:add("rgrav",rgrav).
    result:add("vgrav",vgrav).
    result:add("rthrust",rthrust).
    result:add("vthrust",vthrust).
    result:add("min_radius",min_radius).
    result:add("mass",pdi_mass-flow*duration).
    return result.
}

function pdi_seed {
    parameter state, pdi_target, vehicle, pdi_config.
    local throttle_set is pdi_config["planning_throttle"].
    local duration is max(pdi_config["minimum_tgo"],state["v"]:mag/(vehicle["thrust"]/state["mass"]*throttle_set)).
    set duration to min(duration,pdi_config["maximum_tgo"]).
    local arrival is pdi_target_at(pdi_target,state["ut"]+duration).
    local grav is pdi_gravity(state["r"],vehicle["mu"]).
    return lex(
        "valid",true,"converged",false,"reason","initializing","iterations",0,"stable",0,
        "ut",state["ut"],"last_v",state["v"],"tgo",duration,
        "vgo",arrival["v"]-state["v"]-grav*duration,
        "rgrav",grav*duration^2/2,"rbias",V(0,0,0),
        "throttle",throttle_set,"steering",-state["v"]:normalized,
        "lambda",V(1,0,0),"lambda_dot",V(0,0,0),"jol",0,
        "position_error",1e9,"velocity_error",1e9,"prediction",lex("valid",false)
    ).
}

function pdi_rebase {
    parameter internal, state.
    // State vectors already share an inertial basis, even across kOS's
    // rotating-frame threshold. Remove delivered delta-v once per live update.
    set internal["vgo"] to internal["vgo"]-(state["v"]-internal["last_v"]).
    set internal["last_v"] to state["v"].
    local elapsed is max(0,state["ut"]-internal["ut"]).
    set internal["ut"] to state["ut"].
    if internal["tgo"] > elapsed+1 {
        set internal["rgrav"] to internal["rgrav"]*((internal["tgo"]-elapsed)/internal["tgo"])^2.
        set internal["tgo"] to internal["tgo"]-elapsed.
    }
    set internal["stable"] to 0.
    set internal["converged"] to false.
}

function pdi_fail {
    parameter internal, reason.
    set internal["valid"] to false.
    set internal["converged"] to false.
    set internal["reason"] to reason.
    return internal.
}

function pdi_iterate {
    parameter state, pdi_target, vehicle, internal, pdi_config.
    if not internal["valid"] { return internal. }
    set internal["iterations"] to internal["iterations"]+1.
    local throttle_set is internal["throttle"].
    if vehicle["thrust"] <= 0 or vehicle["ve"] <= 0 or throttle_set <= 0 {
        return pdi_fail(internal,"no_thrust").
    }
    local ve is vehicle["ve"].
    local tu is state["mass"]*ve/(vehicle["thrust"]*throttle_set).
    local impulse is internal["vgo"]:mag.
    local old_tgo is internal["tgo"].
    local duration is tu*(1-constant:e^(-impulse/ve)).
    if duration < pdi_config["minimum_tgo"] or duration > pdi_config["maximum_tgo"] or impulse < 0.01 {
        return pdi_fail(internal,"tgo_out_of_bounds").
    }
    // Single constant-thrust stage, with exact mass-depletion integrals.
    local jint is tu*impulse-ve*duration.
    local sint is duration*impulse-jint.
    local qint is sint*tu-ve*duration^2/2.
    local jol is jint/impulse.
    local qprime is qint-sint*jol.
    if abs(qprime) < 0.0001 { return pdi_fail(internal,"singular_thrust_integrals"). }
    local lambda is internal["vgo"]:normalized.
    local arrival is pdi_target_at(pdi_target,state["ut"]+duration).
    local ix is arrival["r"]:normalized.
    local plane is pdi_cross(arrival["r"],state["r"]).
    // Near-vertical terminal flight belongs to the position controller.
    if plane:mag < state["r"]:mag*arrival["r"]:mag*0.000001 {
        return pdi_fail(internal,"terminal_geometry").
    }
    local iy is plane:normalized.
    local iz is pdi_cross(ix,iy).
    local longitudinal is vdot(lambda,iz).
    if abs(longitudinal) < 0.015 { return pdi_fail(internal,"singular_range_geometry"). }
    local rgrav is internal["rgrav"]*(duration/max(1,old_tgo))^2.
    local rgo is arrival["r"]-(state["r"]+state["v"]*duration+rgrav)+internal["rbias"].
    local rgoxy is ix*vdot(ix,rgo)+iy*vdot(iy,rgo).
    set rgo to rgoxy+iz*(sint-vdot(lambda,rgoxy))/longitudinal.
    local lambda_dot is (rgo-sint*lambda)/qprime.
    local pdi_steering is lambda-lambda_dot*jol.
    if pdi_steering:mag < 0.000001 { return pdi_fail(internal,"zero_steering"). }
    set pdi_steering to pdi_steering:normalized.
    local prediction is pdi_predict_powered(state,vehicle,duration,throttle_set,lambda,lambda_dot,jol,pdi_config["predictor_steps"]).
    if not prediction["valid"] { return pdi_fail(internal,prediction["reason"]). }
    local position_error is (arrival["r"]-prediction["r"]):mag.
    local velocity_error is (arrival["v"]-prediction["v"]):mag.
    if position_error > vehicle["radius"]*2 or velocity_error > max(500,state["v"]:mag*2) {
        return pdi_fail(internal,"diverged").
    }
    local range_error is vdot(iz,arrival["r"]-prediction["r"]).
    local range_vgo is vdot(iz,internal["vgo"]).
    if abs(range_vgo) < 0.1 { return pdi_fail(internal,"singular_range_rate"). }
    local delta_tgo is -2*range_error/range_vgo.
    local gain is pdi_clamp(duration/max(1,duration+delta_tgo),0.5,1.5).
    // Upstream's /100 and angle multiplier are deliberately removed: throttle
    // is a fraction, and the numerical predictor already accounts for turns.
    local next_throttle is pdi_clamp(throttle_set*(1+pdi_config["range_gain"]*(gain-1)),pdi_config["minimum_throttle"],1).
    local stable is position_error <= pdi_config["position_tolerance"] and velocity_error <= pdi_config["velocity_tolerance"] and
        abs(duration-old_tgo) <= pdi_config["time_tolerance"] and vang(pdi_steering,internal["steering"]) <= pdi_config["steering_tolerance"].
    if stable { set internal["stable"] to internal["stable"]+1. }
    else { set internal["stable"] to 0. }
    set internal["converged"] to internal["stable"] >= pdi_config["convergence_passes"].
    set internal["reason"] to "iterating".
    if internal["converged"] { set internal["reason"] to "converged". }
    set internal["rgrav"] to prediction["rgrav"].
    set internal["rbias"] to rgo-prediction["rthrust"].
    set internal["vgo"] to internal["vgo"]+pdi_config["velocity_gain"]*(arrival["v"]-prediction["v"]).
    set internal["tgo"] to duration.
    set internal["throttle"] to next_throttle.
    // Command uses the throttle that was actually validated by the predictor.
    set internal["steering"] to pdi_steering.
    set internal["lambda"] to lambda.
    set internal["lambda_dot"] to lambda_dot.
    set internal["jol"] to jol.
    set internal["position_error"] to position_error.
    set internal["velocity_error"] to velocity_error.
    set internal["prediction"] to prediction.
    if not internal:haskey("command_throttle") { internal:add("command_throttle",throttle_set). }
    else { set internal["command_throttle"] to throttle_set. }
    return internal.
}

function pdi_solve {
    parameter state, pdi_target, vehicle, pdi_config.
    local internal is pdi_seed(state,pdi_target,vehicle,pdi_config).
    until internal["converged"] or not internal["valid"] or internal["iterations"] >= pdi_config["planning_iterations"] {
        pdi_iterate(state,pdi_target,vehicle,internal,pdi_config).
    }
    if not internal["converged"] and internal["valid"] { set internal["reason"] to "iteration_limit". }
    return internal.
}

function pdi_command_predict {
    parameter state, vehicle, command, steps.
    // Validate the remaining segment of an already accepted guidance command.
    // The reference time is retained so the tangent steering schedule remains
    // continuous as propellant is consumed and the body rotates beneath it.
    local elapsed is max(0,state["ut"]-command["ut"]).
    local duration is command["tgo"]-elapsed.
    if duration <= 0 { return lex("valid",false,"reason","command_expired"). }
    return pdi_predict_powered(state,vehicle,duration,command["throttle"],
        command["lambda"],command["lambda_dot"],command["jol"]-elapsed,steps).
}

function pdi_vertical_priority {
    parameter pdi_up, requested, available, tilt_limit.
    // Preserve vertical force before assigning any of the remaining thrust to
    // translation. A final scalar throttle clamp alone cannot do this.
    local vertical is pdi_clamp(vdot(requested,pdi_up),0,available).
    local lateral is requested-pdi_up*vdot(requested,pdi_up).
    local budget is sqrt(max(0,available^2-vertical^2)).
    set budget to min(budget,vertical*tan(tilt_limit)).
    return pdi_up*vertical+pdi_limit(lateral,budget).
}
