set CONFIG:IPU to 2000.
reset_sys().
nervson().
rapiersoff().
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/orbital_maneuver.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/rendezvous.ks").
flight_log_begin("orbital_maneuver").
local om_mode_ is get_om_mode().
if om_mode_ = "Rendezvous" { do_orbital_rendezvous(). }
else if om_mode_ = "RSVP" { do_rsvp(). }
else if om_mode_ = "Execute node" {
    if hasnode { pos_om_review_node(nextnode). }
    else { print "No maneuver node to execute.". }
} else { pos_om_run(om_mode_). }

// Preserve RSVP as an independent planner; review each generated burn.
function do_rsvp {
    get_inputs_rsvp().
    if hasnode { print "Resolve existing nodes before planning with RSVP.". return. }
    local options is lexicon("create_maneuver_nodes",OM_Nodes,"final_orbit_type",OM_Orbit_Type,"final_orbit_orientation",OM_Orbit_Orientation,"verbose",true).
    local destination is 0.
    if OM_Target_type = "Body" { set destination to body(OM_Target). }
    else if OM_Target_type = "Vessel" { set destination to vessel(OM_Target). }
    else { print "Not a valid target type.". return. }
    local plan is rsvp:goto(destination,options).
    if not plan:success { print "RSVP planning failed.". return. }
    local planned_nodes is allnodes:copy.
    for maneuver in planned_nodes {
        if not pos_om_review_node(maneuver,"RSVP maneuver") { return. }
    }
}

function do_orbital_rendezvous {
    local target_name is get_rendezvous_target().
    if target_name = "None" {
        set Lastest_status to "Rendezvous cancelled: no target selected".
        flight_log_event("rendezvous_rejected","reason=no_target_selected").
        return.
    }
    local rendezvous_result is rendezvous_same_body(Vessel(target_name)).
    if rendezvous_result["docking_ready"] {
        print "Rendezvous complete. Start Docking to continue.".
    } else {
        print "Rendezvous did not reach the docking gate: "+rendezvous_result["reason"].
    }
}
