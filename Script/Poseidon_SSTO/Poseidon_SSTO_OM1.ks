nervson().
rapiersoff().
get_inputs_OM().
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