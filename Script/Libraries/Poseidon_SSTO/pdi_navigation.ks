// Live kOS adapters and bounded orbital planning for PDI.
// Numerical integration is in pdi_guidance.ks and has no live reads or logger.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/pdi_guidance.ks").
RUNONCEPATH("0:/Libraries/lib_orbital_nodes.ks").

function pdi_frame {
    // Equatorial meridian and its measured surface motion establish rotation
    // direction without assuming the sign of KSP's angular-velocity vector.
    local equator is latlng(0,0).
    local ex is (equator:altitudeposition(0)-ship:body:position):normalized.
    local ground_velocity is equator:velocity:orbit.
    local ey is (ground_velocity-ex*vdot(ex,ground_velocity)):normalized.
    local omega is abs(ship:body:angularvel:mag).
    if ey:mag < 0.5 {
        local north is (latlng(90,0):position-ship:body:position):normalized.
        set ey to vcrs(north,ex):normalized.
        set omega to 0.
    }
    local ez is vcrs(ex,ey):normalized.
    local ut is time:seconds.
    local angle is mod(ut*omega*constant:radtodeg,360).
    // Undo the body's rotation since UT=0. Stored guidance vectors therefore
    // survive both motion of the vessel origin and kOS raw-frame rotation.
    return lex("x",ex*cos(angle)-ey*sin(angle),"y",ex*sin(angle)+ey*cos(angle),"z",ez,"ut",ut,"omega",omega).
}

function pdi_to_inertial {
    parameter vec, frame.
    return V(vdot(vec,frame["x"]),vdot(vec,frame["y"]),vdot(vec,frame["z"])).
}

function pdi_to_raw {
    parameter vec, frame.
    return frame["x"]*vec:x+frame["y"]*vec:y+frame["z"]*vec:z.
}

function pdi_live_state {
    parameter frame.
    return lex("r",pdi_to_inertial(-ship:body:position,frame),"v",pdi_to_inertial(ship:velocity:orbit,frame),"mass",ship:mass,"ut",frame["ut"]).
}

function pdi_future_state {
    parameter ut, mass.
    local frame is pdi_frame().
    return lex("r",pdi_to_inertial(positionat(ship,ut)-ship:body:position,frame),
        "v",pdi_to_inertial(velocityat(ship,ut):orbit,frame),"mass",mass,"ut",ut).
}

function pdi_node_raw_state {
    parameter maneuver, ut.
    // POSITIONAT(SHIP,ut) deliberately ignores maneuver nodes.  Start at the
    // node's unburned state, apply its displayed delta-v, then propagate the
    // resulting two-body arc.  This keeps deorbit targeting tied to exactly
    // the node the pilot reviews in the map.
    if ut < maneuver:time { return lex("valid",false,"reason","before_maneuver"). }
    local r is positionat(ship,maneuver:time)-ship:body:position.
    local vel is velocityat(ship,maneuver:time):orbit+maneuver:deltav.
    local duration is ut-maneuver:time.
    local steps is max(12,min(120,floor(duration/30)+1)).
    local propagated is pdi_coast(r,vel,duration,ship:body:mu,steps).
    return lex("valid",true,"reason","propagated","r",propagated["r"],"v",propagated["v"],"ut",ut).
}

function pdi_node_state {
    parameter maneuver, ut, mass.
    local raw_state is pdi_node_raw_state(maneuver,ut).
    if not raw_state["valid"] { return raw_state. }
    local frame is pdi_frame().
    return lex("valid",true,"reason","propagated","r",pdi_to_inertial(raw_state["r"],frame),
        "v",pdi_to_inertial(raw_state["v"],frame),"mass",mass,"ut",ut).
}

function pdi_live_target {
    parameter site, altitude, config.
    local frame is pdi_frame().
    return lex("r",pdi_to_inertial(site:altitudeposition(altitude+config["handover_altitude"])-ship:body:position,frame),
        "ut",frame["ut"],"omega",frame["omega"],"vs",config["handover_vertical_speed"]).
}

function pdi_vehicle_snapshot {
    parameter engines, fuel_parts, config.
    local thrust_available is 0.
    local flow is 0.
    for engine in engines {
        if engine:ignition and not engine:flameout {
            local force is engine:availablethrust.
            if engine:vacuumisp > 0 {
                set thrust_available to thrust_available+force.
                set flow to flow+force/(engine:vacuumisp*constant:g0).
            }
        }
    }
    local fuel_mass is 0.
    for part in fuel_parts {
        for resource in part:resources {
            if resource:name = "LiquidFuel" and resource:enabled {
                set fuel_mass to fuel_mass+resource:amount*resource:density.
            }
        }
    }
    local ve is thrust_available/max(flow,0.000001).
    local dry_mass is ship:mass-fuel_mass.
    local reserve_mass is dry_mass*constant:e^(config["reserve_delta_v"]/max(1,ve)).
    return lex("thrust",thrust_available,"ve",ve,"mu",ship:body:mu,"radius",ship:body:radius,
        "fuel_mass",fuel_mass,"dry_mass",dry_mass,"reserve_mass",reserve_mass).
}

function pdi_ground_clearance {
    parameter bounds.
    local terrain is ship:geoposition:terrainheight.
    if ship:body:hasocean { set terrain to max(0,terrain). }
    return max(0,bounds:bottomalt-terrain).
}

function pdi_path_clearance {
    parameter path, start_ut, config.
    local minimum is 1e9.
    for sample in path {
        local frame is pdi_frame().
        // Terrain is fixed to the rotating body, not the inertial trajectory.
        local angle is -(start_ut+sample["t"]-frame["ut"])*frame["omega"]*constant:radtodeg.
        local body_fixed is pdi_rotate(sample["r"],V(0,0,1),angle).
        local location is ship:body:geopositionof(pdi_to_raw(body_fixed,frame)+ship:body:position).
        local terrain is location:terrainheight.
        if ship:body:hasocean { set terrain to max(0,terrain). }
        set minimum to min(minimum,sample["r"]:mag-ship:body:radius-terrain-config["hull_margin"]).
    }
    return minimum.
}

function pdi_next_site_pass {
    parameter target, minimum_ut.
    local period is ship:orbit:period.
    local best_ut is minimum_ut.
    local best_error is 180.
    local i is 0.
    until i > 192 {
        local ut is minimum_ut+2*period*i/192.
        local state is pdi_future_state(ut,ship:mass).
        local arrival is pdi_target_at(target,ut).
        local error_angle is vang(state["r"],arrival["r"]).
        if error_angle < best_error { set best_error to error_angle. set best_ut to ut. }
        set i to i+1.
    }
    local interval is period/96.
    local iteration is 0.
    until iteration >= 12 {
        local candidates is list(max(minimum_ut,best_ut-interval),best_ut+interval).
        for ut in candidates {
            local state is pdi_future_state(ut,ship:mass).
            local arrival is pdi_target_at(target,ut).
            local error_angle is vang(state["r"],arrival["r"]).
            if error_angle < best_error { set best_error to error_angle. set best_ut to ut. }
        }
        set interval to interval/2.
        set iteration to iteration+1.
    }
    return lex("ut",best_ut,"angle",best_error).
}

function pdi_plane_plan {
    parameter target, vehicle, config.
    local pass is pdi_next_site_pass(target,time:seconds+config["node_lead_time"]+ship:orbit:period/2).
    local frame is pdi_frame().
    local state is pdi_live_state(frame).
    local orbit_normal is pdi_cross(state["r"],state["v"]):normalized.
    local site_direction is pdi_target_at(target,pass["ut"])["r"]:normalized.
    local plane_error is arcsin(pdi_clamp(abs(vdot(orbit_normal,site_direction)),0,1)).
    if plane_error <= config["plane_tolerance"] {
        return lex("valid",true,"needed",false,"plane_error",plane_error,"pass_ut",pass["ut"]).
    }
    local normal is orbit_normal-site_direction*vdot(orbit_normal,site_direction).
    if normal:mag < 0.01 { return lex("valid",false,"reason","target_plane_degenerate"). }
    local plan is pos_plan_inclination(0,"Nearest",config["node_lead_time"],pdi_to_raw(normal:normalized,frame)).
    if not plan["valid"] { return plan. }
    local duration is pdi_node_duration(plan["node"],vehicle).
    if duration > ship:orbit:period*config["maximum_plane_burn_fraction"] {
        remove plan["node"].
        return lex("valid",false,"reason","plane_change_burn_too_long").
    }
    plan:add("needed",true).
    plan:add("plane_error",plane_error).
    plan:add("pass_ut",pass["ut"]).
    return plan.
}

function pdi_trim_periapsis {
    parameter maneuver, target_altitude.
    set maneuver:prograde to 0.
    if maneuver:orbit:periapsis <= target_altitude { return false. }
    local speed is velocityat(ship,maneuver:time-0.01):orbit:mag.
    local lower is 0.
    local upper is speed*0.85.
    set maneuver:prograde to -upper.
    if maneuver:orbit:periapsis > target_altitude { return false. }
    local i is 0.
    until i >= 40 {
        local trial is (lower+upper)/2.
        set maneuver:prograde to -trial.
        if abs(maneuver:orbit:periapsis-target_altitude) < 5 { return true. }
        if maneuver:orbit:periapsis > target_altitude { set lower to trial. }
        else { set upper to trial. }
        set i to i+1.
    }
    return false.
}

function pdi_node_radius_crossing {
    parameter maneuver, radius.
    // Node:orbit supplies the patched periapsis time.  Bracket only the
    // descending leg from the burn to that periapsis, then refine using the
    // actual node delta-v above.
    local left_ut is maneuver:time+0.1.
    local right_ut is time:seconds+maneuver:orbit:eta:periapsis.
    if right_ut <= left_ut { return -1. }
    local left_state is pdi_node_raw_state(maneuver,left_ut).
    local right_state is pdi_node_raw_state(maneuver,right_ut).
    if not left_state["valid"] or not right_state["valid"] or left_state["r"]:mag <= radius or right_state["r"]:mag > radius { return -1. }
    local iteration is 0.
    until iteration >= 26 or right_ut-left_ut < 0.02 {
        local mid_ut is (left_ut+right_ut)/2.
        local mid_state is pdi_node_raw_state(maneuver,mid_ut).
        if mid_state["r"]:mag > radius { set left_ut to mid_ut. }
        else { set right_ut to mid_ut. }
        set iteration to iteration+1.
    }
    return (left_ut+right_ut)/2.
}

function pdi_burn_guess {
    parameter state, vehicle.
    local gravity is vehicle["mu"]/state["r"]:mag^2.
    local acceleration is vehicle["thrust"]/state["mass"].
    local lateral_accel is sqrt(max(0.01,acceleration^2-gravity^2)).
    return vehicle["ve"]/lateral_accel*(1-constant:e^(-state["v"]:mag/vehicle["ve"])).
}

function pdi_find_ignition {
    parameter target, vehicle, config, maneuver, earliest_ut, impact_ut, mass.
    local impact_state is pdi_node_state(maneuver,impact_ut,mass).
    local guess is pdi_burn_guess(impact_state,vehicle).
    local lower_ut is max(earliest_ut,impact_ut-2*guess).
    local upper_ut is impact_ut-max(20,0.3*guess).
    local best is lex("valid",false,"reason","no_feasible_powered_descent","score",1e9).
    if upper_ut <= lower_ut { return best. }
    local i is 0.
    until i >= config["ignition_candidates"] {
        local ignition_ut is lower_ut+(upper_ut-lower_ut)*i/(config["ignition_candidates"]-1).
        set Lastest_status to "PDI ignition candidate " + (i+1) + "/" + config["ignition_candidates"].
        local state is pdi_node_state(maneuver,ignition_ut,mass).
        local solve is pdi_solve(state,target,vehicle,config).
        if solve["valid"] and solve["converged"] and solve["command_throttle"] <= 0.98 {
            // Validate at finer resolution before accepting a plan.
            local prediction is pdi_predict_powered(state,vehicle,solve["tgo"],solve["command_throttle"],solve["lambda"],solve["lambda_dot"],solve["jol"],config["predictor_steps"]*3).
            local arrival is pdi_target_at(target,ignition_ut+solve["tgo"]).
            local position_error is (prediction["r"]-arrival["r"]):mag.
            local velocity_error is (prediction["v"]-arrival["v"]):mag.
            local clearance is pdi_path_clearance(prediction["path"],ignition_ut,config).
            local coast_path is list().
            local j is 0.
            until j > 16 {
                local sample_ut is earliest_ut+(ignition_ut-earliest_ut)*j/16.
                local sample_state is pdi_node_state(maneuver,sample_ut,mass).
                coast_path:add(lex("t",sample_ut-earliest_ut,"r",sample_state["r"])).
                set j to j+1.
            }
            set clearance to min(clearance,pdi_path_clearance(coast_path,earliest_ut,config)).
            local score is abs(solve["command_throttle"]-config["planning_throttle"])+solve["tgo"]/10000.
            if clearance >= config["terrain_margin"] and position_error < 100 and velocity_error < 2 and score < best["score"] {
                set best to lex("valid",true,"reason","powered_descent_ready","score",score,"ignition_ut",ignition_ut,
                    "arrival_ut",ignition_ut+solve["tgo"],"solution",solve,"clearance",clearance,
                    "position_error",position_error,"velocity_error",velocity_error,"state",state).
            }
        }
        set i to i+1.
        wait 0.
    }
    return best.
}

function pdi_plan_deorbit {
    parameter target, altitude, vehicle, config, convenient is false.
    local result is lex("valid",false,"reason","deorbit_unsolved").
    if hasnode { set result["reason"] to "existing_maneuver_nodes". return result. }
    local period is ship:orbit:period.
    local pass is pdi_next_site_pass(target,time:seconds+config["node_lead_time"]+period/2).
    local node_ut is max(time:seconds+config["node_lead_time"],pass["ut"]-period*0.37).
    if convenient { set node_ut to time:seconds+config["node_lead_time"]. }
    local maneuver is node(node_ut,0,0,0).
    add maneuver.
    local impact_ut is -1.
    local iteration is 0.
    local aim_error is 1e9.
    until iteration >= config["node_time_iterations"] {
        if not pdi_trim_periapsis(maneuver,altitude-config["deorbit_depth"]) {
            remove maneuver.
            set result["reason"] to "deorbit_periapsis_unsolved".
            return result.
        }
        set impact_ut to pdi_node_radius_crossing(maneuver,ship:body:radius+altitude).
        if impact_ut < 0 { remove maneuver. set result["reason"] to "no_descending_intercept". return result. }
        local mass is ship:mass*constant:e^(-maneuver:deltav:mag/vehicle["ve"]).
        local impact_state is pdi_node_state(maneuver,impact_ut,mass).
        local orbit_normal is pdi_cross(impact_state["r"],impact_state["v"]):normalized.
        local burn_guess is pdi_burn_guess(impact_state,vehicle).
        local advance is min(0.4,0.55*impact_state["v"]:mag*burn_guess/impact_state["r"]:mag).
        local predicted_stop is pdi_rotate(impact_state["r"],orbit_normal,-advance*constant:radtodeg).
        if convenient {
            // Choose a site before the ballistic impact by the estimated
            // braking displacement, then solve the same guided landing.
            local frame is pdi_frame().
            local fixed_stop is pdi_rotate(predicted_stop,V(0,0,1),-(impact_ut-frame["ut"])*frame["omega"]*constant:radtodeg).
            local site is ship:body:geopositionof(pdi_to_raw(fixed_stop,frame)+ship:body:position).
            set altitude to site:terrainheight.
            set target to pdi_live_target(site,altitude,config).
            result:add("site",site).
            result:add("altitude",altitude).
            break.
        }
        local arrival is pdi_target_at(target,impact_ut).
        local angle is arctan2(vdot(orbit_normal,pdi_cross(predicted_stop,arrival["r"])),vdot(predicted_stop,arrival["r"])).
        set aim_error to abs(angle)*constant:degtorad*ship:body:radius.
        if aim_error < 500 { break. }
        local angular_rate is pdi_cross(impact_state["r"],impact_state["v"]):mag/impact_state["r"]:mag^2.
        set angular_rate to angular_rate-target["omega"]*vdot(orbit_normal,V(0,0,1)).
        if abs(angular_rate) < 0.000001 { break. }
        local correction is pdi_clamp(angle*constant:degtorad/angular_rate,-period/8,period/8).
        local next_ut is maneuver:time+correction.
        if next_ut < time:seconds+config["node_lead_time"] { set next_ut to next_ut+period. }
        set maneuver:time to next_ut.
        set iteration to iteration+1.
        wait 0.
    }
    // Recompute after the final timing edit, including a non-converged search.
    if not pdi_trim_periapsis(maneuver,altitude-config["deorbit_depth"]) {
        remove maneuver. return result.
    }
    set impact_ut to pdi_node_radius_crossing(maneuver,ship:body:radius+altitude).
    local duration is pdi_node_duration(maneuver,vehicle).
    if impact_ut < 0 or duration > period*config["maximum_node_burn_fraction"] {
        remove maneuver. set result["reason"] to "deorbit_burn_or_intercept_invalid". return result.
    }
    local mass is ship:mass*constant:e^(-maneuver:deltav:mag/vehicle["ve"]).
    local plan is pdi_find_ignition(target,vehicle,config,maneuver,maneuver:time+duration/2+30,impact_ut,mass).
    if not plan["valid"] { remove maneuver. set result["reason"] to plan["reason"]. return result. }
    set result["valid"] to true.
    set result["reason"] to "deorbit_and_pdi_ready".
    result:add("node",maneuver).
    result:add("pdi",plan).
    result:add("target",target).
    result:add("impact_ut",impact_ut).
    return result.
}

function pdi_node_duration {
    parameter maneuver, vehicle.
    if vehicle["thrust"] <= 0 { return 1e9. }
    return ship:mass*vehicle["ve"]/vehicle["thrust"]*(1-constant:e^(-maneuver:deltav:mag/vehicle["ve"])).
}
