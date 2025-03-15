reset_sys().
nervson().
rapiersoff().
local om_mode_ is get_om_mode().
if om_mode_ = "rsvp"{
    do_rsvp().
} else if om_mode_ = "execute Node"{
    execute_node().
} else if om_mode_ = "change Apoapsis"{
    do_change_Apoapsis().
} else if om_mode_ = "change Periapsis"{
    do_change_Periapsis().
} else if om_mode_ = "change Inclination"{
    do_change_Inclination().
} else if om_mode_ = "Circluarize"{
    do_circularization().
}
function do_rsvp{
get_inputs_rsvp().
set config:ipu to 2000.
local correct_nr_nodes is false.

local options is lexicon("create_maneuver_nodes",OM_Nodes,"final_orbit_type",OM_Orbit_Type,"final_orbit_orientation",OM_Orbit_Orientation,"verbose", true).

if OM_Target_type = "BODY"{
    set OM_target_b to Body(OM_Target).
    rsvp:goto(OM_Target_b, options).
}else if OM_Target_type = "Vessel"{
    set Om_target_v to Vessel(OM_Target).
    rsvp:goto(vessel(OM_Target_v), options).
}else{
    print ("Not a valid Target Type").
    
}
until correct_nr_nodes{
    set nr_nodes to 0.
    for all_Nodes in allNodes{
        set nr_nodes to nr_nodes + 1.
    }
    if OM_Nodes ="both"{
        set correct_nr_nodes_nr to 2.
    }else{
        set correct_nr_nodes_nr to 1.
    }
    if nr_nodes = correct_nr_nodes_nr{
        set correct_nr_nodes to true.
    }
}
wait 5.
check_om_nodes().
set Step to "executing Manuver".
set Lastest_status to "burning to "+OM_Target+"".
if OM_Execute ="true"{
    if options["create_maneuver_nodes"] = "first"{
        execute_node().
    }else if options["create_maneuver_nodes"] = "both"{
        execute_node().
        wait 5.
        execute_node().
    }
}else{
    until not(HASNODE) {
    remove nextnode.
    }
}
}

function do_change_Apoapsis{
    parameter apoapsis_options_force is "ASK".
    LOCAL apoapsis_options to 0.
    if apoapsis_options_force = "ASK"{
        SET apoapsis_options to get_inputs_apoapsis().
    }else{
        SET apoapsis_options to apoapsis_options_force.
    }

    if apoapsis_options[0]= "Apoapsis"{
        local mnv_calc is false.
        local mnv_start is false.
        until mnv_calc{
                if mnv_start = false{
                    set mnv to node(time+eta:apoapsis, 0, 0, 0).
                    add mnv.
                    set mnv_start to true.
                    set mnv_apoapsis to apoapsis_options[1].
                } 
                if mnv:orbit:apoapsis < mnv_apoapsis and mnv_calc = false{
                    if  mnv:orbit:apoapsis + 100000 < mnv_apoapsis{
                        set mnv:prograde to mnv:prograde + 0.1.
                    }
                    if mnv:orbit:apoapsis + 10000 < mnv_apoapsis{
                        set mnv:prograde to mnv:prograde + 0.01.
                    }
                    if mnv:orbit:apoapsis + 1000 < mnv_apoapsis{
                        set mnv:prograde to mnv:prograde + 0.001.
                    }
                }
                if mnv:orbit:apoapsis > mnv_apoapsis and mnv_calc = false{
                    if  mnv:orbit:apoapsis - 100000 > mnv_apoapsis{
                        set mnv:prograde to mnv:prograde - 0.1.
                    }
                    if mnv:orbit:apoapsis - 10000 > mnv_apoapsis{
                        set mnv:prograde to mnv:prograde - 0.01.
                    }
                    if mnv:orbit:apoapsis - 1000 > mnv_apoapsis{
                        set mnv:prograde to mnv:prograde - 0.001.
                    }
                } 
                if mnv:orbit:apoapsis + 1000 > mnv_apoapsis and mnv:orbit:apoapsis - 1000 < mnv_apoapsis and mnv_calc = false{
                    set mnv_calc to true.
                }
                if mnv_calc = true{
                    nervson().
                    rapiersoff().
                    execute_node().
                }
        }
    }else{
        local mnv_calc is false.
        local mnv_start is false.
        until mnv_calc{
                if mnv_start = false{
                    set mnv to node(time+eta:periapsis, 0, 0, 0).
                    add mnv.
                    set mnv_start to true.
                    set mnv_apoapsis to apoapsis_options[1].
                } 
                if mnv:orbit:apoapsis < mnv_apoapsis and mnv_calc = false{
                    if  mnv:orbit:apoapsis + 10000 < mnv_apoapsis{
                        set mnv:prograde to mnv:prograde + 1.
                    }
                    if mnv:orbit:apoapsis + 1000 < mnv_apoapsis{
                        set mnv:prograde to mnv:prograde + 0.1.
                    }
                    if mnv:orbit:apoapsis + 100 < mnv_apoapsis{
                        set mnv:prograde to mnv:prograde + 0.01.
                    }
                }
                if mnv:orbit:apoapsis > mnv_apoapsis and mnv_calc = false{
                    if  mnv:orbit:apoapsis - 10000 > mnv_apoapsis{
                        set mnv:prograde to mnv:prograde - 1.
                    }
                    if mnv:orbit:apoapsis - 1000 > mnv_apoapsis{
                        set mnv:prograde to mnv:prograde - 0.1.
                    }
                    if mnv:orbit:apoapsis - 100 > mnv_apoapsis{
                        set mnv:prograde to mnv:prograde - 0.01.
                    }
                } 
                if mnv:orbit:apoapsis + 1000 > mnv_apoapsis and mnv:orbit:apoapsis - 1000 < mnv_apoapsis and mnv_calc = false{
                    set mnv_calc to true.
                }
                if mnv_calc = true{
                    nervson().
                    rapiersoff().
                    execute_node().
                }
        }
    }
}
function do_change_Periapsis {
    parameter PERIAPSIS_options_force is "ASK".
    local PERIAPSIS_options to 0.
    if PERIAPSIS_options_force = "ASK"{
        SET PERIAPSIS_options to get_inputs_PERIAPSIS().
    }else{
        SET PERIAPSIS_options to PERIAPSIS_options_force.
    }


    if periapsis_options[0] = "Periapsis" {
        local mnv_calc is false.
        local mnv_start is false.
        until mnv_calc {
            if mnv_start = false {
                set mnv to node(time + eta:periapsis, 0, 0, 0).
                add mnv.
                set mnv_start to true.
                set mnv_periapsis to periapsis_options[1].
            }
            if mnv:orbit:periapsis < mnv_periapsis and mnv_calc = false {
                if mnv:orbit:periapsis + 100000 < mnv_periapsis {
                    set mnv:prograde to mnv:prograde + 0.1.
                }
                if mnv:orbit:periapsis + 10000 < mnv_periapsis {
                    set mnv:prograde to mnv:prograde + 0.01.
                }
                if mnv:orbit:periapsis + 1000 < mnv_periapsis {
                    set mnv:prograde to mnv:prograde + 0.001.
                }
            }
            if mnv:orbit:periapsis > mnv_periapsis and mnv_calc = false {
                if mnv:orbit:periapsis - 100000 > mnv_periapsis {
                    set mnv:prograde to mnv:prograde - 0.1.
                }
                if mnv:orbit:periapsis - 10000 > mnv_periapsis {
                    set mnv:prograde to mnv:prograde - 0.01.
                }
                if mnv:orbit:periapsis - 1000 > mnv_periapsis {
                    set mnv:prograde to mnv:prograde - 0.001.
                }
            }
            if mnv:orbit:periapsis + 1000 > mnv_periapsis and mnv:orbit:periapsis - 1000 < mnv_periapsis and mnv_calc = false {
                set mnv_calc to true.
            }
            if mnv_calc = true {
                nervson().
                rapiersoff().
                execute_node().
            }
        }
    } else {
        local mnv_calc is false.
        local mnv_start is false.
        until mnv_calc {
            if mnv_start = false {
                set mnv to node(time + eta:apoapsis, 0, 0, 0).
                add mnv.
                set mnv_start to true.
                set mnv_periapsis to periapsis_options[1].
            }
            if mnv:orbit:periapsis < mnv_periapsis and mnv_calc = false {
                if mnv:orbit:periapsis + 10000 < mnv_periapsis {
                    set mnv:prograde to mnv:prograde + 1.
                }
                if mnv:orbit:periapsis + 1000 < mnv_periapsis {
                    set mnv:prograde to mnv:prograde + 0.1.
                }
                if mnv:orbit:periapsis + 100 < mnv_periapsis {
                    set mnv:prograde to mnv:prograde + 0.01.
                }
            }
            if mnv:orbit:periapsis > mnv_periapsis and mnv_calc = false {
                if mnv:orbit:periapsis - 10000 > mnv_periapsis {
                    set mnv:prograde to mnv:prograde - 1.
                }
                if mnv:orbit:periapsis - 1000 > mnv_periapsis {
                    set mnv:prograde to mnv:prograde - 0.1.
                }
                if mnv:orbit:periapsis - 100 > mnv_periapsis {
                    set mnv:prograde to mnv:prograde - 0.01.
                }
            }
            if mnv:orbit:periapsis + 1000 > mnv_periapsis and mnv:orbit:periapsis - 1000 < mnv_periapsis and mnv_calc = false {
                set mnv_calc to true.
            }
            if mnv_calc = true {
                nervson().
                rapiersoff().
                execute_node().
            }
        }
    }
}
function do_change_Inclination {
    local inclination_options_force is "ASK".
    local inclination_options to 0.
    if inclination_options_force = "ASK" {
        set inclination_options to get_inputs_Inclination().
    } else {
        set inclination_options to inclination_options_force.
    }

    local target_type is inclination_options[0].
    local target_inclination is inclination_options[1]:tonumber().

    local mnv_calc is false.
    local mnv_start is false.

    function time_to_next_node {
        parameter node_type.
        local next_node_time is 0.
        local current_time is time:seconds.
        local orbit_period is ship:orbit:period.
        local node_longitude is 0.

        if node_type = "Ascending" {
            set node_longitude to ship:orbit:lan.
        } else {
            set node_longitude to ship:orbit:lan + 180.
            if node_longitude >= 360 {
                set node_longitude to node_longitude - 360.
            }
        }

        until next_node_time > current_time {
            set next_node_time to next_node_time + orbit_period.
        }

        return next_node_time.
    }

    until mnv_calc {
        if mnv_start = false {
            local node_time is time_to_next_node(target_type).
            set mnv to node(node_time, 0, 0, 0).
            add mnv.
            set mnv_start to true.
        }

        local current_inclination is ship:orbit:inclination.
        local inclination_diff is target_inclination - current_inclination.

        if abs(inclination_diff) > 0.1 {
            if inclination_diff > 0 {
                set mnv:normal to mnv:normal + 0.01.
            } else {
                set mnv:normal to mnv:normal - 0.01.
            }
        } else {
            set mnv_calc to true.
        }

        if mnv_calc = true {
            nervson().
            rapiersoff().
            execute_node().
        }
    }
}
function do_circularization {
    parameter circularization_location_force is "ASK".
    local circularization_location to 0.
    if circularization_location_force = "ASK" {
        set circularization_location to get_inputs_circliurisation().
    } else {
        set circularization_location to circularization_location_force.
    }


    local mnv_calc is false.
    local mnv_start is false.

    until mnv_calc {
        if mnv_start = false {
            if circularization_location = "Periapsis" {
                set mnv to node(time + eta:periapsis, 0, 0, 0).
            } else {
                set mnv to node(time + eta:apoapsis, 0, 0, 0).
            }
            add mnv.
            set mnv_start to true.
        }



        if circularization_location = "Periapsis" {
            do_change_Apoapsis(list("PERIAPSIS",SHIP:periapsis)).
        } else {
            do_change_Periapsis(list("APOAPSIS",SHIP:apoapsis)).
        }


        if mnv_calc = true {
            nervson().
            rapiersoff().
            execute_node().
        }
    }
}