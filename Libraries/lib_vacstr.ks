
function execute_node{
    
    set nd to nextnode.
    set Lastest_status to "Node in: " + round(nd:eta) + ", DeltaV: " + round(nd:deltav:mag).
    set max_acc to ship:maxthrust/ship:mass.
    update_readouts().
    set burn_duration to nd:deltav:mag/max_acc.
    set Lastest_status to "Crude Estimated burn duration: " + round(burn_duration) + "s".
    update_readouts().
    until nd:eta <= (burn_duration/2 + 60){
        WARPTO(time:seconds + (nd:eta-(burn_duration/2 + 60))).
        update_readouts().
    }
    
    set np to nd:deltav. //points to node, don't care about the roll direction.
    lock steering to np.

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
    unlock steering.
    unlock throttle.
    update_readouts().
    wait 1.

    //we no longer need the maneuver node
    remove nd.

    //set throttle to 0 just in case.
    SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
}