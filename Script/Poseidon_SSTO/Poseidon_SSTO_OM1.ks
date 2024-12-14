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
    do_Circluarize().
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
    local apoapsis_options to get_inputs_apoapsis().

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
