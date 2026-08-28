// Poseidon_SSTO_Docking.ks
// Short-range rendezvous and docking assistant.  The target vessel must first
// be selected in KSP.  Start in space, within 1 km and below 5 m/s relative
// speed.  The program then selects a compatible port on that vessel.
//
// The translation controller deliberately starts at a stand-off point on the
// target port axis.  It will not command final closure until lateral alignment
// and relative speed are both small.

RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").

local docking_running is true.
local docking_paused is false.
local docking_phase is "setup".
local docking_result is "cancelled".
local docking_original_rcs is RCS.
local docking_original_sas is SAS.
local docking_original_control_part is ship:controlpart.
local docking_own_port is 0.
local docking_target_port is 0.
local docking_target_vessel is 0.
local docking_control_gui is 0.
local docking_pause_button is 0.
local docking_target_radius is 0.
local docking_own_radius is 0.
local docking_keepout_radius is 0.
local docking_route_radius is 0.
local docking_route_standoff is 0.

function docking_limit {
    parameter value, limit.
    return max(-limit,min(limit,value)).
}

function docking_vessel_radius {
    parameter vessel.
    // Build the relatively expensive vessel bounds once during setup. The
    // centre offset plus half-diagonal encloses every corner around the CoM.
    local vessel_bounds is vessel:bounds.
    local radius is (vessel_bounds:abscenter - vessel:position):mag
        + vessel_bounds:extents:mag.
    return max(5,radius).
}

// Return a waypoint on a safe shell around the target.  Recalculating this
// every update produces short great-circle segments rather than a chord that
// cuts through the target vessel.
function docking_shell_waypoint {
    parameter center, current_position, goal_position, shell_radius, fallback_up.
    local current_offset is current_position - center.
    local goal_offset is goal_position - center.
    if current_offset:mag < 0.1 {
        set current_offset to fallback_up.
    }
    local current_direction is current_offset:normalized.
    local goal_direction is goal_offset:normalized.

    if current_offset:mag < shell_radius - 2 {
        return center + current_direction * shell_radius.
    }

    local direction_dot is docking_limit(vdot(current_direction,goal_direction),1).
    local direction_angle is arccos(direction_dot).
    if direction_angle < 18 {
        return goal_position.
    }

    local route_normal is vcrs(current_direction,goal_direction).
    if route_normal:mag < 0.01 {
        set route_normal to vcrs(current_direction,fallback_up).
    }
    if route_normal:mag < 0.01 {
        set route_normal to vcrs(current_direction,v(0,1,0)).
    }
    local tangent is vcrs(route_normal:normalized,current_direction):normalized.
    local step_angle is 12.
    local waypoint_direction is
        (current_direction * cos(step_angle) + tangent * sin(step_angle)):normalized.
    return center + waypoint_direction * shell_radius.
}

function docking_port_label {
    parameter port, index.
    local label is index + ": " + port:title.
    if port:tag <> "" {
        set label to label + " [" + port:tag + "]".
    }
    return label + " | " + port:nodetype + " | " + port:state.
}

function docking_choose_port {
    parameter ports, prompt.
    clearScreen.
    print prompt.
    print "".
    local i is 0.
    for port in ports {
        print docking_port_label(port,i).
        set i to i + 1.
    }
    print "".
    print "Enter port number: ".
    local selected is round(terminal_input_number(19,i + 3,3," 0")).
    if selected < 0 or selected >= ports:length {
        return -1.
    }
    return selected.
}

function docking_select_own_port {
    local ready_ports is list().
    for port in ship:dockingports {
        if port:state = "Ready" {
            ready_ports:add(port).
        }
    }

    if ready_ports:length = 0 {
        print "No ready docking port found on this vessel.".
        print "Open the Mk2 inline docking port and try again.".
        return 0.
    }

    // Poseidon Block 2 has one Mk2 Clamp-O-Tron. Prefer it automatically,
    // while retaining selection support for related craft with several ports.
    local inline_matches is list().
    for port in ready_ports {
        local description is (port:name + " " + port:title + " " + port:tag):lower.
        if description:contains("mk2") or description:contains("inline") {
            inline_matches:add(port).
        }
    }
    if inline_matches:length = 1 {
        return inline_matches[0].
    }
    if ready_ports:length = 1 {
        return ready_ports[0].
    }
    local choice is docking_choose_port(ready_ports,"Select this vessel's docking port").
    if choice < 0 { return 0. }
    return ready_ports[choice].
}

function docking_get_target_vessel {
    if not hastarget { return 0. }
    if target:istype("DockingPort") or target:istype("Part") {
        return target:ship.
    }
    if target:istype("Vessel") {
        return target.
    }
    return 0.
}

function docking_select_target_port {
    parameter target_vessel, own_port.
    if not target_vessel:loaded or not target_vessel:unpacked {
        print "Target vessel is outside full physics range.".
        print "Move within loading range before running docking.".
        return 0.
    }
    local candidates is list().
    for port in target_vessel:dockingports {
        if port:state = "Ready" and port:targetable and port:nodetype = own_port:nodetype {
            candidates:add(port).
        }
    }
    if candidates:length = 0 {
        print "No ready, compatible target docking port found.".
        print "The target must be loaded and its port must be open.".
        return 0.
    }
    if candidates:length = 1 {
        return candidates[0].
    }
    local choice is docking_choose_port(candidates,"Select a port on " + target_vessel:name).
    if choice < 0 { return 0. }
    return candidates[choice].
}

function docking_release_controls {
    set ship:control:fore to 0.
    set ship:control:starboard to 0.
    set ship:control:top to 0.
    set ship:control:mainthrottle to 0.
    unlock steering.
    if docking_control_gui <> 0 {
        docking_control_gui:hide().
    }
    docking_original_control_part:controlfrom().
    if docking_original_rcs { RCS ON. } else { RCS OFF. }
    if docking_original_sas { SAS ON. } else { SAS OFF. }
}

function docking_toggle_pause {
    set docking_paused to not docking_paused.
    if docking_pause_button <> 0 {
        set docking_pause_button:text to choose "Resume" if docking_paused else "Pause / hold".
    }
}

function docking_abort {
    set docking_result to "aborted by operator".
    set docking_running to false.
}

function docking_create_control_gui {
    set docking_control_gui to GUI(260,90).
    set docking_control_gui:style:width to 260.
    set docking_control_gui:style:height to 90.
    local title_row is docking_control_gui:addhbox().
    title_row:addlabel("<b>POS Docking Control</b>").
    local button_row is docking_control_gui:addhbox().
    set docking_pause_button to button_row:addbutton("Pause / hold").
    local abort_button is button_row:addbutton("ABORT").
    set docking_pause_button:onclick to docking_toggle_pause@.
    set abort_button:onclick to docking_abort@.
    docking_control_gui:show().
}

function docking_read_keys {
    if terminal:input:haschar {
        local key is terminal:input:getchar():tostring():upper.
        if key = "Q" {
            set docking_result to "aborted by operator".
            set docking_running to false.
        }
        if key = "P" {
            docking_toggle_pause().
        }
    }
}

clearScreen.
print "POS Docking".
print "Select the target vessel in KSP before starting this program.".
print "Start in space within 1 km and below 5 m/s relative speed.".
print "Use the docking-control window to pause or abort.".
print "".

set docking_own_port to docking_select_own_port().
if docking_own_port <> 0 {
    set docking_target_vessel to docking_get_target_vessel().
    if docking_target_vessel = 0 {
        print "No target vessel selected. Docking cancelled.".
    } else if docking_target_vessel = ship {
        print "The target must be another vessel. Docking cancelled.".
    } else {
        set docking_target_port to docking_select_target_port(docking_target_vessel,docking_own_port).
    }
}

if docking_own_port <> 0 and docking_target_port <> 0 {
    local initial_target_distance is
        (docking_target_vessel:position - ship:position):mag.
    local initial_relative_speed is
        (ship:velocity:orbit - docking_target_vessel:velocity:orbit):mag.
    local docking_in_space is true.
    if ship:body:atm:exists and ship:altitude <= ship:body:atm:height {
        set docking_in_space to false.
    }
    if not docking_in_space {
        set docking_result to "start outside the atmosphere".
        print "Docking cancelled: Poseidon is still inside the atmosphere.".
    } else if initial_target_distance > 1000 {
        set docking_result to "target is farther than 1 km".
        print "Docking cancelled: target is " + round(initial_target_distance) + " m away.".
    } else if initial_relative_speed >= 5 {
        set docking_result to "relative speed is 5 m/s or greater".
        print "Docking cancelled: relative speed is " + round(initial_relative_speed,2) + " m/s.".
    } else {
        set docking_target_radius to docking_vessel_radius(docking_target_vessel).
        set docking_own_radius to docking_vessel_radius(ship).
        set docking_keepout_radius to docking_target_radius + docking_own_radius + 8.
        set docking_route_radius to docking_keepout_radius + max(15,docking_own_radius * 0.5).
        set docking_route_standoff to max(30,docking_own_radius + 15).
        local initial_route_goal is docking_target_port:nodeposition
            + docking_target_port:portfacing:vector:normalized * docking_route_standoff.
        local initial_goal_radius is
            (initial_route_goal - docking_target_vessel:position):mag.
        if initial_goal_radius < docking_route_radius + 5 {
            set docking_route_standoff to docking_route_standoff
                + docking_route_radius + 5 - initial_goal_radius.
        }
        set docking_phase to "velocity match".
        set docking_result to "running".
    }
}

if docking_result = "running" {
    docking_own_port:controlfrom().
    set target to docking_target_port.
    SAS OFF.
    RCS ON.
    docking_create_control_gui().

    until not docking_running {
        docking_read_keys().
        if not docking_running { break. }

        if docking_target_port:state:contains("Docked") or docking_own_port:state:contains("Docked") {
            set docking_result to "docked".
            set docking_running to false.
        }
        if not docking_running { break. }

        local target_axis is docking_target_port:portfacing:vector:normalized.
        local target_top is docking_target_port:portfacing:topvector:normalized.
        // NODEPOSITION is the actual mating face; POSITION is only the part's
        // centre and is notably wrong for the inline Mk2 docking-port part.
        local port_delta is docking_target_port:nodeposition - docking_own_port:nodeposition.
        // Positive axial distance means Poseidon is in front of the target
        // port (the target port's facing vector points toward Poseidon).
        local axial_distance is -vdot(port_delta,target_axis).
        local lateral_error is (port_delta + target_axis * axial_distance):mag.
        local alignment_error is
            vang(docking_own_port:portfacing:vector,-target_axis).
        local relative_velocity is ship:velocity:orbit - docking_target_vessel:velocity:orbit.
        local relative_speed is relative_velocity:mag.

        if docking_phase = "final" and (axial_distance < -1 or lateral_error > 2) {
            set docking_result to "final approach corridor lost".
            set docking_running to false.
        }
        if not docking_running { break. }

        // Both docking-port faces must oppose each other. CONTROLFROM makes
        // the ship axes and RCS translation axes relative to Poseidon's port.
        lock steering to lookdirup(-target_axis,target_top).

        local target_center is docking_target_vessel:position.
        local own_position is docking_own_port:nodeposition.
        local center_offset is own_position - target_center.
        local center_distance is center_offset:mag.
        local route_goal is
            docking_target_port:nodeposition + target_axis * docking_route_standoff.
        local aim_point is own_position.
        local max_closure is 0.8.

        if docking_phase = "velocity match" {
            // First remove the inherited relative velocity. Holding the current
            // position here avoids adding a large translation demand while RCS
            // is still cancelling as much as 5 m/s.
            set aim_point to own_position.
            set max_closure to 1.25.
            if relative_speed < 0.3 {
                set docking_phase to choose "clear target" if center_distance < docking_route_radius - 2 else "route around".
            }
        } else if docking_phase = "clear target" {
            // Move radially away before going around; this prevents a route
            // chord from passing through the target or clipping its appendages.
            local escape_direction is center_offset.
            if escape_direction:mag < 0.1 { set escape_direction to target_top. }
            set aim_point to target_center + escape_direction:normalized * docking_route_radius.
            set max_closure to 0.8.
            if center_distance >= docking_route_radius - 2 and relative_speed < 0.5 {
                set docking_phase to "route around".
            }
        } else if docking_phase = "route around" {
            set aim_point to docking_shell_waypoint(
                target_center,own_position,route_goal,docking_route_radius,target_top
            ).
            set max_closure to 1.2.
            if (own_position - route_goal):mag < 4 and relative_speed < 0.5 {
                set docking_phase to "stand-off".
            }
        } else if docking_phase = "stand-off" {
            set aim_point to docking_target_port:nodeposition + target_axis * 25.
            set max_closure to 0.8.
            if lateral_error < 1.5 and abs(axial_distance - 25) < 2
                and relative_speed < 0.5 and alignment_error < 3 {
                set docking_phase to "approach gate".
            }
        } else if docking_phase = "approach gate" {
            set aim_point to docking_target_port:nodeposition + target_axis * 7.
            set max_closure to 0.4.
            if lateral_error < 0.35 and abs(axial_distance - 7) < 0.8
                and relative_speed < 0.25 and alignment_error < 1 {
                set docking_phase to "final".
            }
        } else {
            set aim_point to docking_target_port:nodeposition.
            set max_closure to 0.18.
        }

        if docking_paused {
            set ship:control:fore to docking_limit(-vdot(relative_velocity,ship:facing:forevector) * 2,0.35).
            set ship:control:starboard to docking_limit(-vdot(relative_velocity,ship:facing:starvector) * 2,0.35).
            set ship:control:top to docking_limit(-vdot(relative_velocity,ship:facing:topvector) * 2,0.35).
        } else {
            local position_error is aim_point - docking_own_port:nodeposition.
            local desired_velocity is docking_target_vessel:velocity:orbit + position_error * 0.08.
            local velocity_command is desired_velocity - ship:velocity:orbit.

            // Limit commanded speed independently of controller gain.
            if velocity_command:mag > max_closure {
                set velocity_command to velocity_command:normalized * max_closure.
            }
            set ship:control:fore to docking_limit(vdot(velocity_command,ship:facing:forevector) * 2.5,1).
            set ship:control:starboard to docking_limit(vdot(velocity_command,ship:facing:starvector) * 2.5,1).
            set ship:control:top to docking_limit(vdot(velocity_command,ship:facing:topvector) * 2.5,1).
        }

        local pause_text is choose " (PAUSED)" if docking_paused else "          ".
        print ("Phase: " + docking_phase + pause_text):padright(52) at(0,7).
        print ("Port distance: " + round(port_delta:mag,2) + " m"):padright(52) at(0,8).
        print ("Axial / lateral: " + round(axial_distance,2) + " / " + round(lateral_error,2) + " m"):padright(52) at(0,9).
        print ("Relative speed: " + round(relative_speed,3) + " m/s"):padright(52) at(0,10).
        print ("Target clearance: " + round(center_distance - docking_keepout_radius,1) + " m"):padright(52) at(0,11).
        print ("Port alignment error: " + round(alignment_error,2) + " deg"):padright(52) at(0,12).
        print "Use docking-control window | terminal P/Q also work" at(0,13).

        if port_delta:mag > 2000 {
            set docking_result to "target moved outside safe physics range".
            set docking_running to false.
        }
        wait 0.
    }
}

docking_release_controls().
print ("Docking program ended: " + docking_result):padright(60) at(0,14).
