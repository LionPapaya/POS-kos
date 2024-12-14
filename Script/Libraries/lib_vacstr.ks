
function execute_node{
    
    set nd to nextnode.
    set Lastest_status to "Node in: " + round(nd:eta) + ", DeltaV: " + round(nd:deltav:mag).
    set max_acc to ship:maxthrust/ship:mass.
    update_readouts().
    set burn_duration to nd:deltav:mag/max_acc+0.001.
    set Lastest_status to "Crude Estimated burn duration: " + round(burn_duration) + "s".
    update_readouts().
    until nd:eta <= (burn_duration/2 + 60){
        WARPTO(time:seconds + (nd:eta-(burn_duration/2 + 60))).
        update_readouts().
    }
    
    sas on.
    unlock steering.
    set sasMode to "MANEUVER".
   

    //now we need to wait until the burn vector and ship's facing are aligned
    until vang(np, ship:facing:vector) < 0.25{
        update_readouts().
    }

    //the ship is facing the right direction, let's wait for our burn time
    until nd:eta <= (burn_duration/2){
        update_readouts().
    }
    set tset to 0.
    lock throttle to tset.

    set done to False.
    //initial deltav
    set dv0 to nd:deltav.
    until done
    {
        //recalculate current max_acceleration, as it changes while we burn through fuel
        set max_acc to ship:maxthrust/ship:mass.
        update_readouts().
        //throttle is 100% until there is less than 1 second of time left to burn
        //when there is less than 1 second - decrease the throttle linearly
        set tset to min(nd:deltav:mag/max_acc, 1).

       //here's the tricky part, we need to cut the throttle as soon as our nd:deltav and initial deltav start facing opposite directions
       //this check is done via checking the dot product of those 2 vectors
       if vdot(dv0, nd:deltav) < 0
        {
            set Lastest_status to "End burn, remain dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).
            
            lock throttle to 0.
            break.
            
        }

        //we have very little left to burn, less then 0.1m/s
        if nd:deltav:mag < 0.1
        {
            set Lastest_status to  "Finalizing burn, remain dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).
            //we burn slowly until our node vector starts to drift significantly from initial vector
            //this usually means we are on point
            wait until vdot(dv0, nd:deltav) < 0.5.
            update_readouts().
            lock throttle to 0.
            set Lastest_status to  "End burn, remain dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).
            set done to True.
        }
    }
    
    update_readouts().
    wait 1.

    sas off.

    //we no longer need the maneuver node
    remove nd.

    //set throttle to 0 just in case.
    SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
}
function doHoverslam {
  lock dap_steering to srfRetrograde.
  lock pct to getstoppingDistance() / getdistanceToGround().
  set warp to 4.
  until pct > 0.1{update_readouts().}.
  set warp to 3.
  until pct > 0.4{update_readouts().}.
  set warp to 0.
  until pct > 1{update_readouts().}.
  set dapthrottle to pct.
  until getdistanceToGround() < 500{
    update_readouts().
    rapierson().
    if pct > 1.1{
        if rapier_mode = "air"{
                togglerapiermode().
                set rapier_mode to "closed".
            }
    }else{
                if rapier_mode = "closed"{
                togglerapiermode().
                set rapier_mode to "air".
            }
    }
  }
  rapiersoff().
  gear on.
  until ship:verticalSpeed > 0{
    update_readouts().
  }.
  reset_sys(). 
  gear on. 
  set dapthrottle to 0.
  rcs on.
  brakes on.
  until ship:airspeed < 1{
    update_readouts().
  }
  rcs off.

}

function getdistanceToGround {
  return ship:altitude - body:geopositionOf(ship:position):terrainHeight - 40.7.
}

function getstoppingDistance {
  local grav is constant():g * (body:mass / body:radius^2).
  local maxDeceleration is (ship:availableThrust / ship:mass) - grav.
  return ship:verticalSpeed^2 / (2 * maxDeceleration).
}
function getgroundSlope {
  local east is vectorCrossProduct(north:vector, up:vector).

  local center is ship:position.

  local a is body:geopositionOf(center + 5 * north:vector).
  local b is body:geopositionOf(center - 3 * north:vector + 4 * east).
  local c is body:geopositionOf(center - 3 * north:vector - 4 * east).

  local a_vec is a:altitudePosition(a:terrainHeight).
  local b_vec is b:altitudePosition(b:terrainHeight).
  local c_vec is c:altitudePosition(c:terrainHeight).

  return vectorCrossProduct(c_vec - a_vec, b_vec - a_vec):normalized.
}