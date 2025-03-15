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
    local grav_acc to -BODY:mu * pos:normalized / pos:sqrmagnitude.
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

    // Update velocity and position based on total acceleration and timestep
    local new_velocity to simstate["velocity"] + total_accel * timestep.
    local new_position to simstate["position"] + new_velocity * timestep.

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
function simulate_trajectory {
    parameter simstate.
    parameter bank_angle.
    parameter bank_side.
    parameter alt_.
    parameter max_alt is 70000.
    parameter aoa is AVES["EGAOA"].
    parameter timestep is AVES["simulation"]["timestep"].

    local temp_simstate is simstate.

    until temp_simstate["altitude"] < alt_ or temp_simstate["altitude"] > max_alt {
        // Calculate the air acceleration
        local air_acceleration is v(0, 0, 0).
        if bank_side = "left"{ 
            set air_acceleration to aeroaccel_ld(temp_simstate["position"],temp_simstate["surfvel"] ,list(aoa,-bank_angle)).
        } else {
            set air_acceleration to aeroaccel_ld(temp_simstate["position"],temp_simstate["surfvel"] ,list(aoa,bank_angle)).
        }

        // Calculate the gravitational acceleration
        local gravity_acceleration is gravitacc(temp_simstate["position"]).

        // Update the simstate with all accelerations
        set temp_simstate to update_simstate(temp_simstate, list(air_acceleration["load"], gravity_acceleration), timestep).
        log "altitude : "+temp_simstate["altitude"]+ " time :"+temp_simstate["simtime"]+ "velocity"+ temp_simstate["surfvel"]:mag  to "simstate.log".
    }
    if temp_simstate["altitude"] > max_alt {
        log "Simulation failed: altitude exceeded maximum altitude" to "simstate.log".
        return 0.
    }
    return temp_simstate.
}

function simulate_trajectory_time {
    parameter simstate.
    parameter bank_angle.
    parameter bank_side.
    parameter t.
    parameter aoa is AVES["EGAOA"].
    parameter timestep is AVES["simulation"]["timestep"].

    local temp_simstate is simstate.
    local t0 is simstate["simtime"].

    until temp_simstate["simtime"] - t0 > t {
        local remaining_time is t - (temp_simstate["simtime"] - t0).
        // Calculate the air acceleration
        local air_acceleration is v(0, 0, 0).
        if bank_side = "right"{ 
            set air_acceleration to aeroaccel_ld(temp_simstate["position"],temp_simstate["surfvel"] ,list(aoa,-bank_angle)).
        } else {
            set air_acceleration to aeroaccel_ld(temp_simstate["position"],temp_simstate["surfvel"] ,list(aoa,bank_angle)).
        }

        // Calculate the gravitational acceleration
        local gravity_acceleration is gravitacc(temp_simstate["position"]).

        // Update the simstate with all accelerations
        set temp_simstate to update_simstate(temp_simstate, list(air_acceleration["load"], gravity_acceleration), min(timestep,remaining_time+0.1)).
        log "altitude : "+temp_simstate["altitude"]+ " time :"+temp_simstate["simtime"]+ "velocity"+ temp_simstate["surfvel"]:mag  to "simstate.log".
        //log temp_simstate to "simstate.log".
       
    }

    return temp_simstate.
}
function simulate_trajectory_hed{
    parameter simstate.
    parameter hed.
    parameter toll is 1.
    parameter aoa is AVES["EGAOA"].
    parameter timestep is AVES["simulation"]["timestep"]/5.
    parameter min_alt is 0.
    parameter min_vel  is 100.
    

    local temp_simstate is simstate.

    until abs(compass_for_simstate(temp_simstate)-hed) < toll or temp_simstate["altitude"] < min_alt or temp_simstate["surfvel"]:mag < min_vel {
        local heading_error is compass_for_simstate(temp_simstate)-hed.
        until abs(heading_error) <= 180 {
            if heading_error > 180 {
                set heading_error to heading_error - 360.
            } 
            if heading_error < -180 {
                set heading_error to heading_error + 360.
            }
        }
        log "heading error : "+heading_error to "simstate.log".
        local bank_angle is 40 * tanh_approx(0.05 * heading_error).
        if bank_angle > 20 {
            set bank_angle to 20.
        }
        if bank_angle < -20 {
            set bank_angle to -20.
        }
        set bank_angle to -bank_angle.
        log "bank angle : "+bank_angle to "simstate.log".
        log "altitude : "+temp_simstate["altitude"]+ " time :"+temp_simstate["simtime"]+ "velocity"+ temp_simstate["surfvel"]:mag  to "simstate.log".
        // Calculate the air acceleration
        local air_acceleration is v(0, 0, 0).

        set air_acceleration to aeroaccel_ld(temp_simstate["position"],temp_simstate["surfvel"] ,list(aoa,bank_angle)).


        // Calculate the gravitational acceleration
        local gravity_acceleration is gravitacc(temp_simstate["position"]).

        // Update the simstate with all accelerations
        set temp_simstate to update_simstate(temp_simstate, list(air_acceleration["load"], gravity_acceleration), timestep).

        log temp_simstate["simtime"]+ ",(" +temp_simstate["latlong"]:lat+ ","+temp_simstate["latlong"]:lng+"),"+temp_simstate["altitude"]+","+temp_simstate["surfvel"]:mag to log_team_sim_.txt.

    }

    return temp_simstate.
}
function simulate_trajectory_hed_pos{
    parameter simstate.
    parameter pos.
    parameter toll is 1.
    parameter aoa is AVES["EGAOA"].
    parameter timestep is AVES["simulation"]["timestep"]/5.
    parameter min_alt is 0.
    parameter min_vel  is 100.
    

    local temp_simstate is simstate.
    local hed is heading_between(simstate["latlong"],pos).

    until abs(compass_for_simstate(temp_simstate)-hed) < toll or temp_simstate["altitude"] < min_alt or temp_simstate["surfvel"]:mag < min_vel {
        local heading_error is compass_for_simstate(temp_simstate)-hed.
        until abs(heading_error) <= 180 {
            if heading_error > 180 {
                set heading_error to heading_error - 360.
            } 
            if heading_error < -180 {
                set heading_error to heading_error + 360.
            }
        }
        log "heading error : "+heading_error to "simstate.log".
        local bank_angle is 40 * tanh_approx(0.05 * heading_error).
        if bank_angle > 20 {
            set bank_angle to 20.
        }
        if bank_angle < -20 {
            set bank_angle to -20.
        }
        set bank_angle to -bank_angle.
        log "bank angle : "+bank_angle to "simstate.log".
        log "altitude : "+temp_simstate["altitude"]+ " time :"+temp_simstate["simtime"]+ "velocity"+ temp_simstate["surfvel"]:mag  to "simstate.log".
        // Calculate the air acceleration
        local air_acceleration is v(0, 0, 0).

        set air_acceleration to aeroaccel_ld(temp_simstate["position"],temp_simstate["surfvel"] ,list(aoa,bank_angle)).


        // Calculate the gravitational acceleration
        local gravity_acceleration is gravitacc(temp_simstate["position"]).

        // Update the simstate with all accelerations
        set temp_simstate to update_simstate(temp_simstate, list(air_acceleration["load"], gravity_acceleration), timestep).

        log temp_simstate["simtime"]+ ",(" +temp_simstate["latlong"]:lat+ ","+temp_simstate["latlong"]:lng+"),"+temp_simstate["altitude"]+","+temp_simstate["surfvel"]:mag to log_team_sim_.txt.
        set hed to heading_between(simstate["latlong"],pos).
    }

    return temp_simstate.
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
