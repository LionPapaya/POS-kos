// Libraries/lib_aerosim.ks
// Purpose: simple simulation helpers and aerodynamic wrappers used by guidance and control code.
// - Provides simstate creation/cloning (`current_simstate`, `clone_simstate`).
// - Simple physics helpers: `gravitacc`, `update_simstate` (Euler integration).
// - Trajectory simulators (`simulate_trajectory*`) which use aerodynamic sampling via `aeroforce_ld`.
// Notes: Comments added only — no behavior changes.
FUNCTION current_simstate {
    RETURN  LEXICON(
        "simtime",0,
        "position",-SHIP:ORBIT:BODY:POSITION,
        "velocity",SHIP:VELOCITY:ORBIT,
        "surfvel",SHIP:VELOCITY:SURFACE,
        "altitude",SHIP:ORBIT:BODY:POSITION:MAG - BODY:RADIUS,
        "latlong",SHIP:geoposition
        ).
}

FUNCTION clone_simstate {
    PARAMETER simstate.

    RETURN  LEXICON(
        "simtime",simstate["simtime"],
        "position",simstate["position"],
        "velocity",simstate["velocity"],
        "surfvel",simstate["surfvel"],
        "altitude",simstate["altitude"],
        "latlong",simstate["latlong"]
    ).
}

function gravitacc {
    parameter pos.
    parameter sim_context_mu is BODY:mu.
    local grav_acc to -sim_context_mu * pos:normalized / pos:sqrmagnitude.
    //log "Gravitational acceleration: " + grav_acc to "simstate.log".
    return grav_acc.
}

function update_simstate {
    parameter simstate.
    parameter acc_list is list().// List of accelerations
    parameter timestep is AVES["simulation"]["timestep"].

    // Calculate the total acceleration
    local total_accel to V(0, 0, 0).
    for acc in acc_list {
        set total_accel to total_accel + acc.
    }

    // Update velocity and position assuming constant acceleration over the timestep
    local new_velocity to simstate["velocity"] + total_accel * timestep.
    local new_position to simstate["position"] + simstate["velocity"] * timestep + 0.5 * total_accel * timestep^2.

    // Return the new simstate with updated data
    return lexicon(
        "simtime", simstate["simtime"] + timestep,
        "position", new_position,
        "velocity", new_velocity,
        "surfvel", new_velocity - vcrs(BODY:angularvel, new_position),
        "altitude", new_position:mag - BODY:radius,
        "latlong", vec2pos(new_position)

    ).
}

// Entry trajectory integration always combines exactly aerodynamic and
// gravitational acceleration.  Accept the already-summed vector directly so
// the hot simulation loops do not allocate a list or run a generic summation.
function update_simstate_total_accel {
    parameter simstate.
    parameter total_accel.
    parameter timestep is AVES["simulation"]["timestep"].
    parameter sim_context_angularvel is BODY:angularvel.
    parameter sim_context_radius is BODY:radius.

    // Keep the same constant-acceleration Euler equations as update_simstate.
    local new_velocity to simstate["velocity"] + total_accel * timestep.
    local new_position to simstate["position"] + simstate["velocity"] * timestep + 0.5 * total_accel * timestep^2.

    return lexicon(
        "simtime", simstate["simtime"] + timestep,
        "position", new_position,
        "velocity", new_velocity,
        "surfvel", new_velocity - vcrs(sim_context_angularvel, new_position),
        "altitude", new_position:mag - sim_context_radius,
        "latlong", vec2pos(new_position)
    ).
}

function simulate_trajectory {
    parameter simstate.
    parameter bank_angle.
    parameter bank_side.
    parameter alt_.
    parameter max_alt is 70000.
    parameter aoa_temp is "EGAOA".
    parameter timestep is AVES["simulation"]["timestep"].
    parameter sim_context_mu is BODY:mu.
    parameter sim_context_radius is BODY:radius.
    parameter sim_context_angularvel is BODY:angularvel.
    parameter sim_context_mass is SHIP:MASS.
    parameter sim_context_vessel_fore is SHIP:FACING:FOREVECTOR:NORMALIZED.
    parameter sim_context_vessel_top is SHIP:FACING:TOPVECTOR:NORMALIZED.
    parameter sim_context_vessel_right is VCRS(SHIP:FACING:TOPVECTOR:NORMALIZED,SHIP:FACING:FOREVECTOR:NORMALIZED):NORMALIZED.
    //if EGAOA it has to check every timestep to get the new aoa for that alt using AVES["EGAOA"](simstate["altitude"])


    local temp_simstate is simstate.
    // Preserve the established constant-bank probe convention exactly:
    // "left" maps to negative roll; every other side maps to positive roll.
    local signed_bank_angle is bank_angle.
    if bank_side = "left" {
        set signed_bank_angle to -bank_angle.
    }

    until temp_simstate["altitude"] < alt_ or temp_simstate["altitude"] > max_alt {
        if aoa_temp = "EGAOA"{
            set aoa to AVES["EGAOA"](temp_simstate["altitude"]).
        }else{
            set aoa to aoa_temp.
        }
        // Calculate the air acceleration
        local air_acceleration is v(0, 0, 0).
        set air_acceleration to sim_aeroaccel_load(temp_simstate["position"],temp_simstate["surfvel"] ,list(aoa,signed_bank_angle),sim_context_radius).

        // Calculate the gravitational acceleration
        local gravity_acceleration is gravitacc(temp_simstate["position"],sim_context_mu).

        // Entry simulation has exactly aerodynamic plus gravitational acceleration.
        set temp_simstate to update_simstate_total_accel(temp_simstate, air_acceleration + gravity_acceleration, timestep, sim_context_angularvel, sim_context_radius).
    }
    if temp_simstate["altitude"] > max_alt {
        return 0.
    }
    return temp_simstate.
}

function simulate_trajectory_time {
    parameter simstate.
    parameter bank_angle.
    parameter bank_side.
    parameter t.
    parameter aoa_temp is "EGAOA".
    parameter timestep is AVES["simulation"]["timestep"].
    parameter sim_context_mu is BODY:mu.
    parameter sim_context_radius is BODY:radius.
    parameter sim_context_angularvel is BODY:angularvel.
    parameter sim_context_mass is SHIP:MASS.
    parameter sim_context_vessel_fore is SHIP:FACING:FOREVECTOR:NORMALIZED.
    parameter sim_context_vessel_top is SHIP:FACING:TOPVECTOR:NORMALIZED.
    parameter sim_context_vessel_right is VCRS(SHIP:FACING:TOPVECTOR:NORMALIZED,SHIP:FACING:FOREVECTOR:NORMALIZED):NORMALIZED.

    local temp_simstate is simstate.
    local t0 is simstate["simtime"].
    // Preserve the established guided-entry convention exactly:
    // "right" maps to negative roll; every other side maps to positive roll.
    local signed_bank_angle is bank_angle.
    if bank_side = "right" {
        set signed_bank_angle to -bank_angle.
    }

    until temp_simstate["simtime"] - t0 >= t {
        if aoa_temp = "EGAOA"{
            set aoa to AVES["EGAOA"](temp_simstate["altitude"]).
        }else{
            set aoa to aoa_temp.
        }
        local remaining_time is t - (temp_simstate["simtime"] - t0).
        // Calculate the air acceleration
        local air_acceleration is v(0, 0, 0).
        set air_acceleration to sim_aeroaccel_load(temp_simstate["position"],temp_simstate["surfvel"] ,list(aoa,signed_bank_angle),sim_context_radius).

        // Calculate the gravitational acceleration
        local gravity_acceleration is gravitacc(temp_simstate["position"],sim_context_mu).

        // Entry simulation has exactly aerodynamic plus gravitational acceleration.
        set temp_simstate to update_simstate_total_accel(temp_simstate, air_acceleration + gravity_acceleration, min(timestep,remaining_time), sim_context_angularvel, sim_context_radius).
        //log temp_simstate to "simstate.log".
       
    }

    return temp_simstate.
}
function simulate_trajectory_hed{
    parameter simstate.
    parameter hed.
    parameter toll is 1.
    parameter aoa_temp is "EGAOA".
    parameter timestep is AVES["simulation"]["timestep"]/5.
    parameter min_alt is 0.
    parameter min_vel  is 100.
    

    local temp_simstate is simstate.

    until abs(compass_for_simstate(temp_simstate)-hed) < toll or temp_simstate["altitude"] < min_alt or temp_simstate["surfvel"]:mag < min_vel {
        if aoa_temp = "EGAOA"{
            set aoa to AVES["EGAOA"](temp_simstate["altitude"]).
        }else{
            set aoa to aoa_temp.
        }
        local heading_error is compass_for_simstate(temp_simstate)-hed.
        until abs(heading_error) <= 180 {
            if heading_error > 180 {
                set heading_error to heading_error - 360.
            } 
            if heading_error < -180 {
                set heading_error to heading_error + 360.
            }
        }
        local bank_angle is 40 * tanh_approx(0.05 * heading_error).
        if bank_angle > 20 {
            set bank_angle to 20.
        }
        if bank_angle < -20 {
            set bank_angle to -20.
        }
        set bank_angle to -bank_angle.
        // Calculate the air acceleration
        local air_acceleration is v(0, 0, 0).

        set air_acceleration to aeroaccel_ld(temp_simstate["position"],temp_simstate["surfvel"] ,list(aoa,bank_angle)).


        // Calculate the gravitational acceleration
        local gravity_acceleration is gravitacc(temp_simstate["position"]).

        // Update the simstate with all accelerations
        set temp_simstate to update_simstate(temp_simstate, list(air_acceleration["load"], gravity_acceleration), timestep).


    }

    return temp_simstate.
}
function simulate_trajectory_hed_pos{
    parameter simstate.
    parameter pos.
    parameter toll is 1.
    parameter aoa_temp is "EGAOA".
    parameter timestep is AVES["simulation"]["timestep"]/5.
    parameter min_alt is 0.
    parameter min_vel  is 100.
    

    local temp_simstate is simstate.
    local hed is heading_between(simstate["latlong"],pos).

    until abs(compass_for_simstate(temp_simstate)-hed) < toll or temp_simstate["altitude"] < min_alt or temp_simstate["surfvel"]:mag < min_vel {
        if aoa_temp = "EGAOA"{
            set aoa to AVES["EGAOA"](temp_simstate["altitude"]).
        }else{
            set aoa to aoa_temp.
        }
        local heading_error is compass_for_simstate(temp_simstate)-hed.
        until abs(heading_error) <= 180 {
            if heading_error > 180 {
                set heading_error to heading_error - 360.
            } 
            if heading_error < -180 {
                set heading_error to heading_error + 360.
            }
        }
        local bank_angle is 40 * tanh_approx(0.05 * heading_error).
        if bank_angle > 20 {
            set bank_angle to 20.
        }
        if bank_angle < -20 {
            set bank_angle to -20.
        }
        set bank_angle to -bank_angle.
        // Calculate the air acceleration
        local air_acceleration is v(0, 0, 0).

        set air_acceleration to aeroaccel_ld(temp_simstate["position"],temp_simstate["surfvel"] ,list(aoa,bank_angle)).


        // Calculate the gravitational acceleration
        local gravity_acceleration is gravitacc(temp_simstate["position"]).

        // Update the simstate with all accelerations
        set temp_simstate to update_simstate(temp_simstate, list(air_acceleration["load"], gravity_acceleration), timestep).

        set hed to heading_between(simstate["latlong"],pos).
    }

    return temp_simstate.
}
// Entry-trajectory-only acceleration sampler.  It preserves the aeroforce_ld
// load-vector transformation but avoids producing lift/drag values that the
// entry simulators never consume.
declare function sim_aeroaccel_load {
    parameter pos.
    parameter surfvel.
    parameter attitude.
    parameter sim_context_radius is BODY:radius.

    local roll is attitude[1].
    local aoa is attitude[0].

    local altt is pos:mag-sim_context_radius.

    // Do not freeze the craft frame for a full entry solve.  The solver can
    // yield across physics ticks while the real vehicle is steering into entry,
    // so its FAR query and force conversion must use the live frame just as
    // aeroforce_ld did before the entry-simulation optimization.
    local vesselfore is SHIP:FACING:FOREVECTOR:NORMALIZED.
    local vesseltop is SHIP:FACING:TOPVECTOR:NORMALIZED.
    local vesselright is VCRS(vesseltop,vesselfore):NORMALIZED.

    local airspeedaoa is surfvel:MAG*rodrigues(vesselfore,vesselright,aoa):NORMALIZED.
    local totalforce is ADDONS:FAR:AEROFORCEAT(altt,airspeedaoa).

    // Convert the aerodynamic force into the frame defined by the vessel orientation vectors.
    local localforce is V(VDOT(vesselright,totalforce),VDOT(vesseltop,totalforce),VDOT(vesselfore,totalforce)).

    // Build a frame of reference centered about the surface velocity and local up direction.
    local velforward is surfvel:NORMALIZED.
    local velup is pos:NORMALIZED.
    local velright is VCRS(velup,velforward).
    if velright:MAG < 0.001 {
        set velright to VCRS(vesseltop,velforward).
        if velright:MAG < 0.001 {
            set velright to VCRS(vesselfore,velforward):NORMALIZED.
        }
        else {
            set velright to velright:NORMALIZED.
        }
    }
    else {
        set velright to velright:NORMALIZED.
    }
    set velup to VCRS(velforward,velright):NORMALIZED.

    // Build the predicted vessel orientation vectors using the existing AoA and roll convention.
    local pred_vesseltop is rodrigues(velup,velforward,-roll).
    local pred_vesselright is VCRS(pred_vesseltop,velforward):NORMALIZED.
    local pred_vesselfore is rodrigues(velforward,pred_vesselright,-aoa).
    set pred_vesseltop to rodrigues(pred_vesseltop,pred_vesselright,-aoa).

    return (pred_vesselright*localforce:X + pred_vesseltop*localforce:Y + pred_vesselfore*localforce:Z) / SHIP:MASS.
}

//wrapper that converts everything to acceleration
function aeroaccel_ld {
	parameter pos.
	parameter surfvel.
	parameter attitude.
	
	LOCAL aeroforce_out IS aeroforce_ld(pos, surfvel, attitude).
	
	RETURN LEXICON(
						"load",aeroforce_out["load"]/(ship:mass),
						"lift",aeroforce_out["lift"]/(ship:mass),
						"drag",aeroforce_out["drag"]/(ship:mass)
						).

}

declare function aeroforce_ld {
	parameter pos.
	parameter surfvel.
	parameter attitude.
	
	LOCAL roll IS attitude[1].
	LOCAL aoa IS attitude[0].
	
	LOCAL out IS LEXICON(
						"load",v(0,0,0),
						"lift",0,
						"drag",0
						).
	
	LOCAL altt IS pos:mag-BODY:radius.
	
	LOCAL vesselfore IS SHIP:FACING:FOREVECTOR:NORMALIZED.
	LOCAL vesseltop IS SHIP:FACING:TOPVECTOR:NORMALIZED.
	LOCAL vesselright IS VCRS(vesseltop,vesselfore):NORMALIZED.
	
	LOCAL airspeedaoa IS surfvel:MAG*rodrigues(vesselfore,vesselright,aoa):NORMALIZED.
	
	LOCAL totalforce IS ADDONS:FAR:AEROFORCEAT(altt,airspeedaoa).
	
	
	
	//convert the aerodynamic force into the frame defined by the vessel orientation vectors
	 LOCAL localforce IS V( VDOT(vesselright,totalforce) ,VDOT(vesseltop,totalforce)  , VDOT(vesselfore,totalforce) ).
	 
	//build a frame of reference centered about the survace velocity and the local up direction
	LOCAL velforward IS surfvel:NORMALIZED.
	LOCAL velup IS pos:NORMALIZED.
	LOCAL velright IS VCRS( velup, velforward).
	IF (velright:MAG < 0.001) {
		SET velright TO VCRS( vesseltop, velforward).
		IF (velright:MAG < 0.001) {
			SET velright TO VCRS( vesselfore, velforward):NORMALIZED.
		}
		ELSE {
			SET velright TO velright:NORMALIZED.
		}
	}
	ELSE {
		SET velright TO velright:NORMALIZED.
	}
	SET velup TO VCRS( velforward, velright):NORMALIZED.
	
	//build the pedicted vessel orientation vectors using aoa and roll information
	LOCAL pred_vesseltop IS rodrigues(velup,velforward,-roll).
	LOCAL pred_vesselright IS VCRS(pred_vesseltop,velforward):NORMALIZED.
	LOCAL pred_vesselfore IS rodrigues(velforward,pred_vesselright,-aoa).
	SET pred_vesseltop TO rodrigues(pred_vesseltop,pred_vesselright,-aoa).
	

	
	//rotate the local force vector to the new frame
	SET out["load"] TO (pred_vesselright*localforce:X + pred_vesseltop*localforce:Y + pred_vesselfore*localforce:Z ).
	//compute lift asnd drag components
	
	SET out["drag"] TO -VDOT(totalforce,airspeedaoa:NORMALIZED).
	SET out["lift"] TO VDOT(VXCL(airspeedaoa:NORMALIZED,totalforce),vesseltop:NORMALIZED).
	

	RETURN out.
	
}
function cur_aeroaccel_ld {
	
	LOCAL aeroforce_out IS cur_aeroforce_ld().
	
	RETURN LEXICON(
						"load",aeroforce_out["load"]/(ship:mass),
						"lift",aeroforce_out["lift"]/(ship:mass),
						"drag",aeroforce_out["drag"]/(ship:mass)
						).

}

//samples aeroforce for the vessel right now 
declare function cur_aeroforce_ld {

	LOCAL out IS LEXICON(
						"load",v(0,0,0),
						"lift",0,
						"drag",0
						).

	//vector is already in the current ship_raw frame 
	LOCAL totalforce IS ADDONS:FAR:AEROFORCE().
	
	
	SET out["load"] TO totalforce.
	//compute lift asnd drag components
	
	LOCAL airspeedaoa IS SHIP:VELOCITY:SURFACE:NORMALIZED.
	LOCAL vesseltop IS SHIP:FACING:TOPVECTOR:NORMALIZED.
	
	SET out["drag"] TO -VDOT(totalforce,airspeedaoa).
	SET out["lift"] TO VDOT(VXCL(airspeedaoa,totalforce),vesseltop).
	
	return out.

}
